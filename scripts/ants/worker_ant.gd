extends Node2D

const TILE_SIZE: int = 16
const INVALID_TILE: Vector2i = Vector2i(-1, -1)
const WORKER_JOB_TYPES: Array = [JobQueue.TYPE_DIG, JobQueue.TYPE_GATHER, JobQueue.TYPE_BUILD, JobQueue.TYPE_REPAIR]
const WORKER_JOB_CATEGORIES: Array[String] = ["digging", "food", "building", "repair"]
const FOOD_ROUTE_PURPOSE: String = "food_route"
const DIRS: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const WORKER_GROUP: String = "workers"
const ENEMY_GROUP: String = "enemies"
const FLEE_DANGER_RADIUS: int = 2
const FLEE_SAFE_RADIUS: int = 4
# Throttle the per-frame enemy distance scan — was O(workers × enemies) every frame.
const ENEMY_SCAN_INTERVAL: float = 0.2

enum State { IDLE, MOVING, WORKING, IDLE_WANDER, FLEE }

# Config (overridden from worker_config.json)
var _move_time: float = 0.12
var _dig_duration: float = 1.2
var _gather_duration: float = 0.8
var _build_duration: float = 0.9
var _food_per_gather: int = 1
var _wander_delay: float = 0.35
var _sprite_max_size: float = 12.0
var _max_hp: int = 12
var _auto_gather_enabled: bool = true
var _auto_explore_enabled: bool = true
var _auto_explore_candidate_limit: int = 24
var _auto_food_route_enabled: bool = true
var _auto_food_route_food_ratio: float = 0.35

# HP
var _hp: int = 12
# Throttled enemy distance — refreshed every ENEMY_SCAN_INTERVAL.
var _enemy_scan_timer: float = 0.0
var _cached_nearest_enemy_dist: int = 100000
var _cached_nearest_enemy_tile: Vector2i = Vector2i(-1, -1)

# FSM
var _state: State = State.IDLE
var _current_job = null
var _path: Array = []
var _is_moving: bool = false
var _rescore_requested: bool = false
var _moving_to_tile: Vector2i = Vector2i.ZERO
var _move_tween: Tween

# World references set by main.gd via setup()
var _tile_map: TileMapLayer
var _sid_dirt: int = -1
var _sid_tunnel: int = -1
var _sid_queen: int = -1
var _world_w: int = 60
var _world_h: int = 40
var _surface_row: int = 5
var _tile_pos: Vector2i = Vector2i.ZERO
var _food_positions: Array = []

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _hp_bar_bg: ColorRect = get_node_or_null("HpBarBg")
@onready var _hp_bar_fill: ColorRect = get_node_or_null("HpBarFill")


func _ready() -> void:
	_sprite.texture = AssetLoader.get_ant_sprite("worker")
	_fit_sprite_to_tile()


func _fit_sprite_to_tile() -> void:
	if _sprite.texture == null:
		return
	var tex_size := _sprite.texture.get_size()
	var largest_axis: float = maxf(tex_size.x, tex_size.y)
	if largest_axis <= 0.0:
		return
	var fit_scale: float = minf(1.0, _sprite_max_size / largest_axis)
	_sprite.scale = Vector2(fit_scale, fit_scale)


func setup(
		tile_map: TileMapLayer,
		sid_dirt: int,
		sid_tunnel: int,
		sid_queen: int,
		start_tile: Vector2i,
		world_w: int,
		world_h: int,
		surface_row: int,
		food_positions: Array) -> void:
	_tile_map = tile_map
	_sid_dirt = sid_dirt
	_sid_tunnel = sid_tunnel
	_sid_queen = sid_queen
	_tile_pos = start_tile
	_world_w = world_w
	_world_h = world_h
	_surface_row = surface_row
	_food_positions = food_positions.duplicate()
	position = _tile_to_world(start_tile)
	_load_config()
	_hp = _max_hp
	_update_hp_bar()
	_fit_sprite_to_tile()
	add_to_group(WORKER_GROUP)
	GameManager.register_worker()
	GameManager.priority_changed.connect(_on_priority_changed)
	if GameManager.upgrades != null:
		GameManager.upgrades.upgrade_changed.connect(_on_upgrade_changed)
		_apply_upgrades()
	_enter_idle()


func _apply_upgrades() -> void:
	# Refresh tunable stats from current upgrade levels.
	var base_dig: float = _move_time  # not used; placeholder
	pass


func _on_upgrade_changed(_upgrade_id: String, _new_level: int) -> void:
	# No-op — workers query the upgrade manager on demand for dig duration / carry capacity.
	pass


func get_effective_dig_duration() -> float:
	if GameManager.upgrades == null:
		return _dig_duration
	return _dig_duration * GameManager.upgrades.get_dig_duration_multiplier()


func get_effective_food_per_gather() -> int:
	if GameManager.upgrades == null:
		return _food_per_gather
	return maxi(1, GameManager.upgrades.get_food_per_gather())


func _load_config() -> void:
	var config_path := "res://data/ants/worker_config.json"
	if not FileAccess.file_exists(config_path):
		return
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return
	_move_time = float(data.get("move_speed", _move_time))
	_dig_duration = float(data.get("dig_duration", _dig_duration))
	_gather_duration = float(data.get("gather_duration", _gather_duration))
	_build_duration = float(data.get("build_duration", _build_duration))
	_food_per_gather = int(data.get("food_per_gather", _food_per_gather))
	_wander_delay = float(data.get("wander_delay", _wander_delay))
	_sprite_max_size = float(data.get("sprite_max_size", _sprite_max_size))
	_max_hp = int(data.get("max_hp", _max_hp))
	_auto_gather_enabled = bool(data.get("auto_gather_enabled", _auto_gather_enabled))
	_auto_explore_enabled = bool(data.get("auto_explore_enabled", _auto_explore_enabled))
	_auto_explore_candidate_limit = maxi(
			1,
			int(data.get("auto_explore_candidate_limit", _auto_explore_candidate_limit)))
	_auto_food_route_enabled = bool(data.get("auto_food_route_enabled", _auto_food_route_enabled))
	_auto_food_route_food_ratio = clampf(
			float(data.get("auto_food_route_food_ratio", _auto_food_route_food_ratio)),
			0.0,
			1.0)


func _exit_tree() -> void:
	if _current_job != null:
		GameManager.job_queue.release_job(_current_job.id)
	GameManager.unregister_worker()


func _process(delta: float) -> void:
	if not is_instance_valid(_tile_map):
		return
	# Throttle the enemy scan — was the per-frame O(N) hotspot at 30+ ants.
	_enemy_scan_timer -= delta
	if _enemy_scan_timer <= 0.0:
		_enemy_scan_timer = ENEMY_SCAN_INTERVAL
		_refresh_nearest_enemy()
	if _state == State.FLEE:
		if _cached_nearest_enemy_dist > FLEE_SAFE_RADIUS:
			# All clear — return to idle and re-score work.
			_state = State.IDLE
			_enter_idle()
			return
		_flee_tick()
		return
	if _cached_nearest_enemy_dist <= FLEE_DANGER_RADIUS:
		_enter_flee()


func _refresh_nearest_enemy() -> void:
	var enemies: Array = get_tree().get_nodes_in_group(ENEMY_GROUP)
	var best_dist: int = 100000
	var best_tile: Vector2i = Vector2i(-1, -1)
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var et: Vector2i = Vector2i(int(e.global_position.x / TILE_SIZE), int(e.global_position.y / TILE_SIZE))
		var d: int = abs(et.x - _tile_pos.x) + abs(et.y - _tile_pos.y)
		if d < best_dist:
			best_dist = d
			best_tile = et
	_cached_nearest_enemy_dist = best_dist
	_cached_nearest_enemy_tile = best_tile


# ── HP / damage ───────────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	_hp = maxi(0, _hp - amount)
	_update_hp_bar()
	if _hp == 0:
		_die()


func _die() -> void:
	if is_instance_valid(_move_tween):
		_move_tween.kill()
	if _current_job != null:
		GameManager.job_queue.release_job(_current_job.id)
		_current_job = null
	queue_free()


func _update_hp_bar() -> void:
	if _hp_bar_bg == null or _hp_bar_fill == null:
		return
	var ratio: float = 0.0 if _max_hp <= 0 else clampf(float(_hp) / float(_max_hp), 0.0, 1.0)
	_hp_bar_fill.size.x = _hp_bar_bg.size.x * ratio


func _enter_flee() -> void:
	# Drop current job; abandon claimed plan.
	if _current_job != null:
		GameManager.job_queue.release_job(_current_job.id)
		_current_job = null
	if is_instance_valid(_move_tween):
		_move_tween.kill()
	_is_moving = false
	_path.clear()
	_state = State.FLEE


func _flee_tick() -> void:
	if _is_moving:
		return
	# Use the cached nearest enemy from _refresh_nearest_enemy.
	var enemy_pos: Vector2i = _cached_nearest_enemy_tile
	if enemy_pos == Vector2i(-1, -1):
		_state = State.IDLE
		_enter_idle()
		return
	var best_step: Vector2i = Vector2i.ZERO
	var best_dist: int = -1
	for dir in DIRS:
		var n: Vector2i = _tile_pos + dir
		if not _is_traversable(n):
			continue
		var d: int = abs(n.x - enemy_pos.x) + abs(n.y - enemy_pos.y)
		if d > best_dist:
			best_dist = d
			best_step = dir
	if best_step == Vector2i.ZERO:
		# Cornered — wait a beat and retry.
		await get_tree().create_timer(0.2).timeout
		return
	_path = [_tile_pos + best_step]
	_move_step()


# ── FSM ───────────────────────────────────────────────────────────────────────

func _enter_idle() -> void:
	_state = State.IDLE
	_path.clear()
	_is_moving = false
	_rescore_requested = false
	_try_claim_job()


func _try_claim_job() -> void:
	if not is_instance_valid(_tile_map):
		return
	var valid_types: Array = _valid_job_types()
	if _should_prioritize_food_work():
		var food_job = _claim_available_job([JobQueue.TYPE_GATHER])
		if food_job != null:
			_current_job = food_job
			_start_moving_to_job()
			return
		if _try_add_auto_gather_job(true):
			food_job = _claim_available_job([JobQueue.TYPE_GATHER])
			if food_job != null:
				_current_job = food_job
				_start_moving_to_job()
				return
		food_job = _claim_food_route_dig_job()
		if food_job != null:
			_current_job = food_job
			_start_moving_to_job()
			return
		if _try_add_food_route_dig_job():
			food_job = _claim_food_route_dig_job()
			if food_job != null:
				_current_job = food_job
				_start_moving_to_job()
				return

	var job = _claim_available_job(valid_types)
	if job != null:
		_current_job = job
		_start_moving_to_job()
		return

	if JobQueue.TYPE_GATHER in valid_types and _try_add_auto_gather_job(_is_food_emergency()):
		job = _claim_available_job(valid_types)
		if job != null:
			_current_job = job
			_start_moving_to_job()
			return

	if JobQueue.TYPE_DIG in valid_types and _try_add_auto_explore_job():
		job = _claim_available_job(valid_types)
		if job != null:
			_current_job = job
			_start_moving_to_job()
			return

	_start_wander()


func _claim_available_job(valid_types: Array):
	return GameManager.job_queue.claim_best_job(
			_tile_pos, self, valid_types, Callable(self, "_get_job_distance"))


func _claim_food_route_dig_job():
	return GameManager.job_queue.claim_best_job(
			_tile_pos, self, [JobQueue.TYPE_DIG], Callable(self, "_get_food_route_dig_distance"))


func _valid_job_types() -> Array:
	var emergency_types: Array = _worker_emergency_job_types()
	if not emergency_types.is_empty():
		return emergency_types
	if GameManager.colony.food >= GameManager.colony.max_food:
		return [JobQueue.TYPE_DIG, JobQueue.TYPE_BUILD]
	return WORKER_JOB_TYPES


func _worker_emergency_job_types() -> Array:
	if _is_food_emergency():
		return [JobQueue.TYPE_GATHER]
	if GameManager.colony.priorities.get("digging", "normal") == "emergency":
		return [JobQueue.TYPE_DIG]
	if GameManager.colony.priorities.get("building", "normal") == "emergency":
		return [JobQueue.TYPE_BUILD]
	var types: Array = []
	return types


func _start_moving_to_job() -> void:
	if _current_job == null:
		_enter_idle()
		return
	if _current_job.type == JobQueue.TYPE_DIG:
		_move_toward_dig_dest()
		return
	if _current_job.type == JobQueue.TYPE_GATHER:
		_path = _find_path_to_gather(_current_job.tile_pos)
	else:
		_path = _find_path(_tile_pos, _current_job.tile_pos)
	if _path.is_empty():
		if _can_work_current_job_from_here():
			_start_working()
		else:
			GameManager.job_queue.release_job(_current_job.id)
			_current_job = null
			_start_wander()
		return
	_state = State.MOVING
	_move_step()


func _move_toward_dig_dest() -> void:
	if _current_job == null:
		_enter_idle()
		return
	var dest: Vector2i = _current_job.tile_pos
	if _is_traversable(dest):
		GameManager.job_queue.complete_job(_current_job.id)
		_current_job = null
		_enter_idle()
		return
	var next_tile: Vector2i = _get_current_dig_tile(dest)
	if next_tile == INVALID_TILE:
		GameManager.job_queue.release_job(_current_job.id)
		_current_job = null
		_start_wander()
		return
	var dig_from: Array = []
	for dir in DIRS:
		var n: Vector2i = next_tile + dir
		if _is_traversable(n):
			dig_from.append(n)
	if dig_from.is_empty():
		GameManager.job_queue.release_job(_current_job.id)
		_current_job = null
		_start_wander()
		return
	if _tile_pos in dig_from:
		_start_working()
		return
	_path = _bfs(_tile_pos, dig_from)
	if _path.is_empty():
		GameManager.job_queue.release_job(_current_job.id)
		_current_job = null
		_start_wander()
		return
	_state = State.MOVING
	_move_step()


func _start_wander() -> void:
	_state = State.IDLE_WANDER
	var neighbors: Array = []
	for dir in DIRS:
		var n: Vector2i = _tile_pos + dir
		if _is_traversable(n):
			neighbors.append(n)
	if neighbors.is_empty():
		_retry_idle_after_delay()
		return
	_path = [neighbors[randi() % neighbors.size()]]
	_move_step()


func _retry_idle_after_delay() -> void:
	await get_tree().create_timer(_wander_delay).timeout
	if is_instance_valid(self):
		_enter_idle()


# ── Movement ──────────────────────────────────────────────────────────────────

func _move_step() -> void:
	if _path.is_empty():
		_on_path_complete()
		return
	if _is_moving:
		return
	_is_moving = true
	var next_tile: Vector2i = _path.pop_front()
	_moving_to_tile = next_tile
	# Pheromone speedup: tiles workers traverse a lot get a step-time bonus.
	var step_time: float = _move_time
	if GameManager.pheromones != null:
		step_time *= GameManager.pheromones.get_speed_multiplier(next_tile)
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", _tile_to_world(next_tile), step_time)
	_move_tween.tween_callback(_on_step_done)
	# Walk bob runs in parallel via a separate one-shot tween — no chain conflicts.
	if _sprite != null:
		var bob := create_tween()
		bob.tween_property(_sprite, "position:y", -1.5, step_time * 0.5)
		bob.tween_property(_sprite, "position:y", 0.0, step_time * 0.5)


func _on_step_done() -> void:
	_tile_pos = _moving_to_tile
	position = _tile_to_world(_tile_pos)
	_is_moving = false
	# Drop pheromone on the tile we just landed on so highways emerge.
	if GameManager.pheromones != null:
		GameManager.pheromones.deposit(_tile_pos)
	if _try_deferred_rescore():
		return
	_move_step()


func _on_path_complete() -> void:
	match _state:
		State.MOVING:
			_start_working()
		State.IDLE_WANDER:
			_retry_idle_after_delay()


# ── Working ───────────────────────────────────────────────────────────────────

func _start_working() -> void:
	if _current_job == null:
		_enter_idle()
		return
	_state = State.WORKING
	match _current_job.type:
		JobQueue.TYPE_DIG:
			_do_dig()
		JobQueue.TYPE_GATHER:
			_do_gather()
		JobQueue.TYPE_BUILD:
			_do_build()
		JobQueue.TYPE_REPAIR:
			_do_repair()


func _do_dig() -> void:
	if _current_job == null:
		_enter_idle()
		return
	var job_id: int = _current_job.id
	var dest: Vector2i = _current_job.tile_pos
	if _is_traversable(dest):
		GameManager.job_queue.complete_job(_current_job.id)
		_current_job = null
		_enter_idle()
		return
	var next_tile: Vector2i = _get_current_dig_tile(dest)
	if next_tile == INVALID_TILE:
		GameManager.job_queue.release_job(_current_job.id)
		_current_job = null
		_enter_idle()
		return
	# Verify adjacency — if not adjacent, re-position.
	if abs(_tile_pos.x - next_tile.x) + abs(_tile_pos.y - next_tile.y) != 1:
		_move_toward_dig_dest()
		return
	await get_tree().create_timer(get_effective_dig_duration()).timeout
	if not is_instance_valid(self) or _current_job == null or not is_instance_valid(_tile_map):
		return
	if _current_job.id != job_id:
		return
	if _state != State.WORKING:
		return
	if _is_traversable(dest):
		GameManager.job_queue.complete_job(_current_job.id)
		_current_job = null
		_enter_idle()
		return
	if not _is_diggable(next_tile):
		_move_toward_dig_dest()
		return
	if abs(_tile_pos.x - next_tile.x) + abs(_tile_pos.y - next_tile.y) != 1:
		_move_toward_dig_dest()
		return
	_tile_map.set_cell(next_tile, _sid_tunnel, Vector2i(0, 0))
	AudioManager.play_dig_complete()
	_current_job.data.erase("next_dig_tile")
	_current_job.data["last_dig_tile"] = next_tile
	if _try_deferred_rescore():
		return
	# Continue toward destination (loops until dest is reached or unreachable).
	_move_toward_dig_dest()


func _do_gather() -> void:
	if _current_job == null:
		_enter_idle()
		return
	var job_id: int = _current_job.id
	await get_tree().create_timer(_gather_duration).timeout
	if not is_instance_valid(self) or _current_job == null:
		return
	if _current_job.id != job_id:
		return
	if _state != State.WORKING:
		return
	GameManager.add_food(get_effective_food_per_gather())
	AudioManager.play_food_gathered()
	GameManager.job_queue.complete_job(_current_job.id)
	_current_job = null
	# Re-enter idle after the gather delay, so auto-gather cannot recurse on
	# the same tile in a single call stack.
	_enter_idle()


func _do_build() -> void:
	if _current_job == null:
		_enter_idle()
		return
	var job_id: int = _current_job.id
	var plan_id: int = int(_current_job.data.get("plan_id", -1))
	await get_tree().create_timer(_build_duration).timeout
	if not is_instance_valid(self) or _current_job == null:
		return
	if _current_job.id != job_id or _state != State.WORKING:
		return
	var result: String = GameManager.room_manager.apply_build_work(plan_id)
	if result == "complete" or result == "missing":
		GameManager.job_queue.complete_job(_current_job.id)
		_current_job = null
		_enter_idle()
		return
	if result == "no_food":
		GameManager.job_queue.release_job(_current_job.id)
		_current_job = null
		_enter_idle()
		return
	call_deferred("_start_working")


func _do_repair() -> void:
	if _current_job == null:
		_enter_idle()
		return
	var job_id: int = _current_job.id
	var room_tile: Vector2i = _current_job.tile_pos
	await get_tree().create_timer(_build_duration).timeout
	if not is_instance_valid(self) or _current_job == null:
		return
	if _current_job.id != job_id or _state != State.WORKING:
		return
	var result: String = GameManager.room_manager.apply_repair_work(room_tile)
	if result == "complete" or result == "missing" or result == "full":
		GameManager.job_queue.complete_job(_current_job.id)
		_current_job = null
		_enter_idle()
		return
	if result == "no_food":
		GameManager.job_queue.release_job(_current_job.id)
		_current_job = null
		_enter_idle()
		return
	call_deferred("_start_working")


func _on_priority_changed(category: String, level: String) -> void:
	if not _can_handle_category(category):
		return
	if level != "high" and level != "emergency":
		return
	if _current_job != null and _current_job.category == category:
		return
	if _state == State.IDLE:
		_try_claim_job()
		return
	if category == "food" and level == "emergency" and _state != State.WORKING:
		_rescore_now()
		return
	_rescore_requested = true


func _try_deferred_rescore() -> bool:
	if not _rescore_requested:
		return false
	_rescore_requested = false
	_rescore_now()
	return true


func _rescore_now() -> void:
	if is_instance_valid(_move_tween):
		_move_tween.kill()
	_is_moving = false
	position = _tile_to_world(_tile_pos)
	if _current_job != null:
		GameManager.job_queue.release_job(_current_job.id)
		_current_job = null
	_enter_idle()


# ── BFS pathfinding ───────────────────────────────────────────────────────────

func _find_path(from: Vector2i, to: Vector2i) -> Array:
	if _is_traversable(to):
		return _bfs(from, [to])
	var targets: Array = []
	for dir in DIRS:
		var n: Vector2i = to + dir
		if _is_traversable(n):
			targets.append(n)
	if targets.is_empty():
		return []
	return _bfs(from, targets)


func _find_path_to_gather(food_tile: Vector2i) -> Array:
	var stand_tiles: Array = _get_gather_stand_tiles(food_tile)
	if stand_tiles.is_empty():
		return []
	return _bfs(_tile_pos, stand_tiles)


func _get_job_distance(job) -> int:
	if job.type == JobQueue.TYPE_DIG:
		return _get_path_distance_to_dig_target(job.tile_pos)
	if job.type == JobQueue.TYPE_GATHER:
		return _get_path_distance_to_gather(job.tile_pos)
	if _can_work_job_from_tile(job, _tile_pos):
		return 0
	var job_path: Array = _find_path(_tile_pos, job.tile_pos)
	if job_path.is_empty():
		return -1
	return job_path.size()


func _get_food_route_dig_distance(job) -> int:
	if job.type != JobQueue.TYPE_DIG:
		return -1
	if String(job.data.get("purpose", "")) != FOOD_ROUTE_PURPOSE:
		return -1
	return _get_path_distance_to_dig_target(job.tile_pos)


func _get_path_distance_to_dig_target(dest: Vector2i) -> int:
	var next_tile: Vector2i = _find_next_dig_tile(dest)
	if next_tile == INVALID_TILE:
		return -1
	return _get_distance_to_dig_tile(next_tile)


func _get_distance_to_dig_tile(next_tile: Vector2i) -> int:
	var dig_from: Array = []
	for dir in DIRS:
		var n: Vector2i = next_tile + dir
		if _is_traversable(n):
			dig_from.append(n)
	if dig_from.is_empty():
		return -1
	if _tile_pos in dig_from:
		return 0
	var route_path: Array = _bfs(_tile_pos, dig_from)
	return route_path.size() if not route_path.is_empty() else -1


func _can_work_current_job_from_here() -> bool:
	return _current_job != null and _can_work_job_from_tile(_current_job, _tile_pos)


func _can_work_job_from_tile(job, tile: Vector2i) -> bool:
	match job.type:
		JobQueue.TYPE_DIG:
			return abs(job.tile_pos.x - tile.x) + abs(job.tile_pos.y - tile.y) == 1
		JobQueue.TYPE_GATHER:
			return abs(job.tile_pos.x - tile.x) + abs(job.tile_pos.y - tile.y) == 1
		JobQueue.TYPE_BUILD:
			return job.tile_pos == tile
		JobQueue.TYPE_REPAIR:
			return job.tile_pos == tile
	return false


func _find_next_dig_tile(dest: Vector2i) -> Vector2i:
	# BFS outward from dest through non-traversable tiles.
	# Returns the non-traversable tile closest to dest that borders existing tunnel.
	var queue: Array = [dest]
	var visited: Dictionary = {dest: true}
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if _is_diggable(current):
			for dir in DIRS:
				var n: Vector2i = current + dir
				if _is_traversable(n):
					return current
		for dir in DIRS:
			var n: Vector2i = current + dir
			if n in visited:
				continue
			if n.x < 0 or n.x >= _world_w or n.y < 0 or n.y >= _world_h:
				continue
			if _is_diggable(n):
				visited[n] = true
				queue.append(n)
	return INVALID_TILE


func _find_reachable_dig_tile_toward(dest: Vector2i) -> Vector2i:
	var queue: Array = [_tile_pos]
	var visited: Dictionary = {_tile_pos: true}
	var distance_by_tile: Dictionary = {_tile_pos: 0}
	var best_tile: Vector2i = INVALID_TILE
	var best_target_distance: int = 999999
	var best_travel_distance: int = 999999
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var current_distance: int = int(distance_by_tile[current])
		for dir in DIRS:
			var n: Vector2i = current + dir
			if _is_diggable(n):
				var target_distance: int = abs(n.x - dest.x) + abs(n.y - dest.y)
				if target_distance < best_target_distance \
						or (target_distance == best_target_distance and current_distance < best_travel_distance):
					best_tile = n
					best_target_distance = target_distance
					best_travel_distance = current_distance
				continue
			if n in visited:
				continue
			if n.x < 0 or n.x >= _world_w or n.y < 0 or n.y >= _world_h:
				continue
			if _is_traversable(n):
				visited[n] = true
				distance_by_tile[n] = current_distance + 1
				queue.append(n)
	return best_tile


func _get_current_dig_tile(dest: Vector2i) -> Vector2i:
	if _current_job == null:
		return INVALID_TILE

	var locked_tile: Vector2i = Vector2i(_current_job.data.get("next_dig_tile", INVALID_TILE))
	if locked_tile != INVALID_TILE:
		if _is_diggable(locked_tile):
			return locked_tile
		if _is_traversable(locked_tile):
			_current_job.data["last_dig_tile"] = locked_tile
		_current_job.data.erase("next_dig_tile")

	var last_tile: Vector2i = Vector2i(_current_job.data.get("last_dig_tile", INVALID_TILE))
	var next_from_last: Vector2i = _find_next_dig_tile_from_last(last_tile, dest)
	if next_from_last != INVALID_TILE:
		_current_job.data["next_dig_tile"] = next_from_last
		return next_from_last

	var next_tile: Vector2i = _find_next_dig_tile(dest)
	if next_tile != INVALID_TILE:
		_current_job.data["next_dig_tile"] = next_tile
	return next_tile


func _find_next_dig_tile_from_last(last_tile: Vector2i, dest: Vector2i) -> Vector2i:
	if last_tile == INVALID_TILE or not _is_traversable(last_tile):
		return INVALID_TILE

	var best_tile: Vector2i = INVALID_TILE
	var best_dist: int = 999999
	for dir in DIRS:
		var candidate: Vector2i = last_tile + dir
		if not _is_diggable(candidate):
			continue
		var dist: int = abs(candidate.x - dest.x) + abs(candidate.y - dest.y)
		if dist < best_dist:
			best_dist = dist
			best_tile = candidate
	return best_tile


func _try_add_auto_explore_job() -> bool:
	if not _auto_explore_enabled:
		return false
	var target: Vector2i = _find_auto_explore_target()
	if target == INVALID_TILE:
		return false
	GameManager.job_queue.add_job(JobQueue.TYPE_DIG, target)
	return true


func _try_add_auto_gather_job(force: bool = false) -> bool:
	if not _auto_gather_enabled and not force:
		return false
	if GameManager.colony.food >= GameManager.colony.max_food:
		return false

	var best_food: Vector2i = INVALID_TILE
	var best_distance: int = 999999
	for food_pos in _food_positions:
		var tile_pos: Vector2i = Vector2i(food_pos)
		if GameManager.job_queue.has_job(JobQueue.TYPE_GATHER, tile_pos):
			continue
		var distance: int = _get_path_distance_to_gather(tile_pos)
		if distance < 0 or distance >= best_distance:
			continue
		best_distance = distance
		best_food = tile_pos

	if best_food == INVALID_TILE:
		return false
	GameManager.job_queue.add_job(JobQueue.TYPE_GATHER, best_food)
	return true


func _try_add_food_route_dig_job() -> bool:
	if not _should_prioritize_food_work():
		return false
	var best_route_tile: Vector2i = INVALID_TILE
	var best_distance: int = 999999
	for food_pos in _food_positions:
		var food_tile: Vector2i = Vector2i(food_pos)
		if _get_path_distance_to_gather(food_tile) >= 0:
			continue
		var route_tile: Vector2i = _find_reachable_dig_tile_toward(food_tile)
		if route_tile == INVALID_TILE:
			continue
		if GameManager.job_queue.has_job(JobQueue.TYPE_DIG, route_tile):
			continue
		var distance: int = _get_distance_to_dig_tile(route_tile)
		if distance < 0 or distance >= best_distance:
			continue
		best_distance = distance
		best_route_tile = route_tile
	if best_route_tile == INVALID_TILE:
		return false
	var route_job = GameManager.job_queue.add_job(JobQueue.TYPE_DIG, best_route_tile)
	route_job.data["purpose"] = FOOD_ROUTE_PURPOSE
	return true


func _get_path_distance_to_gather(food_tile: Vector2i) -> int:
	if abs(food_tile.x - _tile_pos.x) + abs(food_tile.y - _tile_pos.y) == 1:
		return 0
	var route_path: Array = _find_path_to_gather(food_tile)
	return route_path.size() if not route_path.is_empty() else -1


func _get_gather_stand_tiles(food_tile: Vector2i) -> Array:
	var stand_tiles: Array = []
	for dir in DIRS:
		var stand_tile: Vector2i = food_tile + dir
		if _is_traversable(stand_tile):
			stand_tiles.append(stand_tile)
	return stand_tiles


func _find_auto_explore_target() -> Vector2i:
	var queue: Array = [_tile_pos]
	var visited: Dictionary = {_tile_pos: true}
	var frontier_candidates: Array = []
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var dirs: Array = DIRS.duplicate()
		dirs.shuffle()
		for dir in dirs:
			var n: Vector2i = current + dir
			if _is_tunnel_network_tile(current) \
					and _is_diggable(n) \
					and not GameManager.job_queue.has_job(JobQueue.TYPE_DIG, n):
				frontier_candidates.append(n)
				if frontier_candidates.size() >= _auto_explore_candidate_limit:
					frontier_candidates.shuffle()
					return frontier_candidates[0]
				continue
			if n in visited:
				continue
			if _is_traversable(n):
				visited[n] = true
				queue.append(n)
	if not frontier_candidates.is_empty():
		frontier_candidates.shuffle()
		return frontier_candidates[0]
	return INVALID_TILE


func _bfs(from: Vector2i, goal_tiles: Array) -> Array:
	var goal_set: Dictionary = {}
	for g in goal_tiles:
		goal_set[g] = true
	if from in goal_set:
		return []  # Already at destination, no movement needed.

	var queue: Array = [from]
	var came_from: Dictionary = {from: null}
	var found: Variant = null

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current in goal_set:
			found = current
			break
		for dir in DIRS:
			var neighbor: Vector2i = current + dir
			if neighbor in came_from:
				continue
			if not _is_traversable(neighbor):
				continue
			came_from[neighbor] = current
			queue.append(neighbor)

	if found == null:
		return []

	var result_path: Array = []
	var node = found
	while came_from[node] != null:
		result_path.push_front(node)
		node = came_from[node]
	return result_path


func _is_traversable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= _world_w or pos.y < 0 or pos.y >= _world_h:
		return false
	if _is_food_source_tile(pos):
		return false
	if pos.y < _surface_row:
		return true  # Open sky above ground.
	var src_id := _tile_map.get_cell_source_id(pos)
	return src_id == -1 or src_id == _sid_tunnel or src_id == _sid_queen


func _is_diggable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= _world_w or pos.y < _surface_row or pos.y >= _world_h:
		return false
	if _is_food_source_tile(pos):
		return false
	return _tile_map.get_cell_source_id(pos) == _sid_dirt


func _is_tunnel_network_tile(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= _world_w or pos.y < _surface_row or pos.y >= _world_h:
		return false
	var src_id := _tile_map.get_cell_source_id(pos)
	return src_id == _sid_tunnel or src_id == _sid_queen


func _is_food_source_tile(pos: Vector2i) -> bool:
	for food_pos in _food_positions:
		if Vector2i(food_pos) == pos:
			return true
	return false


func _can_handle_category(category: String) -> bool:
	return category in WORKER_JOB_CATEGORIES


func _is_food_emergency() -> bool:
	return GameManager.colony.priorities.get("food", "normal") == "emergency" \
			and GameManager.colony.food < GameManager.colony.max_food


# ── Utility ───────────────────────────────────────────────────────────────────

func _should_prioritize_food_work() -> bool:
	if GameManager.colony.food >= GameManager.colony.max_food:
		return false
	var food_priority: String = String(GameManager.colony.priorities.get("food", "normal"))
	if food_priority == "high" or food_priority == "emergency":
		return true
	if not _auto_food_route_enabled:
		return false
	if GameManager.colony.max_food <= 0:
		return false
	var food_ratio: float = float(GameManager.colony.food) / float(GameManager.colony.max_food)
	return food_ratio <= _auto_food_route_food_ratio


func _tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE_SIZE + TILE_SIZE / 2.0, tile.y * TILE_SIZE + TILE_SIZE / 2.0)
