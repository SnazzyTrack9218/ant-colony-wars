extends Node2D

const TILE_SIZE: int = 16
const DIRS: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const ENEMY_GROUP: String = "enemies"
const SOLDIER_GROUP: String = "soldiers"

enum State { IDLE_PATROL, ENGAGE, RETURN, MOVE_TO_RALLY, AT_RALLY }

# Config (overridden from soldier_config.json)
var _max_hp: int = 28
var _damage: int = 7
var _attack_cooldown: float = 0.7
var _move_time: float = 0.10
var _detection_radius: int = 8
var _patrol_radius: int = 6
var _sprite_max_size: float = 12.0

# State
var _hp: int = 28
var _state: int = State.IDLE_PATROL
var _path: Array = []
var _is_moving: bool = false
var _move_tween: Tween
var _attack_cooldown_remaining: float = 0.0
var _patrol_anchor: Vector2i = Vector2i.ZERO
var _current_target: Node2D = null
var _current_rally_job = null

# World references
var _tile_map: TileMapLayer
var _sid_tunnel: int = -1
var _sid_queen: int = -1
var _world_w: int = 60
var _world_h: int = 40
var _surface_row: int = 5
var _tile_pos: Vector2i = Vector2i.ZERO

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _hp_bar_bg: ColorRect = $HpBarBg
@onready var _hp_bar_fill: ColorRect = $HpBarFill


func _ready() -> void:
	_sprite.texture = AssetLoader.get_ant_sprite("soldier")
	_fit_sprite_to_tile()
	add_to_group(SOLDIER_GROUP)


func setup(
		tile_map: TileMapLayer,
		sid_tunnel: int,
		sid_queen: int,
		start_tile: Vector2i,
		world_w: int,
		world_h: int,
		surface_row: int) -> void:
	_tile_map = tile_map
	_sid_tunnel = sid_tunnel
	_sid_queen = sid_queen
	_tile_pos = start_tile
	_patrol_anchor = start_tile
	_world_w = world_w
	_world_h = world_h
	_surface_row = surface_row
	position = _tile_to_world(start_tile)
	_load_config()
	_hp = _max_hp
	_update_hp_bar()
	_fit_sprite_to_tile()
	GameManager.register_soldier()


func _load_config() -> void:
	var path := "res://data/ants/soldier_config.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return
	_max_hp = int(data.get("max_hp", _max_hp))
	_damage = int(data.get("damage", _damage))
	_attack_cooldown = float(data.get("attack_cooldown", _attack_cooldown))
	_move_time = float(data.get("move_time", _move_time))
	_detection_radius = int(data.get("detection_radius", _detection_radius))
	_patrol_radius = int(data.get("patrol_radius", _patrol_radius))
	_sprite_max_size = float(data.get("sprite_max_size", _sprite_max_size))


func _fit_sprite_to_tile() -> void:
	if _sprite.texture == null:
		return
	var tex_size := _sprite.texture.get_size()
	var largest_axis: float = maxf(tex_size.x, tex_size.y)
	if largest_axis <= 0.0:
		return
	var fit_scale: float = minf(1.0, _sprite_max_size / largest_axis)
	_sprite.scale = Vector2(fit_scale, fit_scale)


func _exit_tree() -> void:
	if _current_rally_job != null:
		GameManager.job_queue.release_job(_current_rally_job.id)
		_current_rally_job = null
	GameManager.unregister_soldier()


func _process(delta: float) -> void:
	if _attack_cooldown_remaining > 0.0:
		_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	_update_state(delta)


# ── FSM ───────────────────────────────────────────────────────────────────────

func _update_state(_delta: float) -> void:
	if not is_instance_valid(_tile_map):
		return
	# Detect threats every tick regardless of current state (except at rally hold).
	var nearest: Node2D = _find_nearest_enemy()
	if nearest != null and _can_engage(nearest):
		_set_target(nearest)
		if _state != State.ENGAGE:
			_enter_engage()
		_engage_tick()
		return

	# No enemies — fall back to assignment-driven behavior.
	match _state:
		State.IDLE_PATROL:
			_patrol_tick()
		State.ENGAGE:
			# Target lost.
			_current_target = null
			_enter_return()
		State.RETURN:
			_return_tick()
		State.MOVE_TO_RALLY:
			_rally_move_tick()
		State.AT_RALLY:
			# Hold position; refresh path if rally tile changed.
			_at_rally_tick()


func _enter_engage() -> void:
	_state = State.ENGAGE
	_kill_tween()
	_path.clear()


func _enter_return() -> void:
	_state = State.RETURN
	_path.clear()


func _patrol_tick() -> void:
	if _is_moving:
		return
	# Try to claim a Rally job if any exist.
	var rally: Variant = _claim_rally_job()
	if rally != null:
		_current_rally_job = rally
		_state = State.MOVE_TO_RALLY
		_rally_move_tick()
		return
	# Wander within patrol radius around anchor.
	_wander_within_patrol_radius()


func _wander_within_patrol_radius() -> void:
	var neighbors: Array = []
	for dir in DIRS:
		var n: Vector2i = _tile_pos + dir
		if not _is_traversable(n):
			continue
		if _manhattan(n, _patrol_anchor) > _patrol_radius:
			continue
		neighbors.append(n)
	if neighbors.is_empty():
		# Already at edge of patrol radius — step back toward anchor.
		_path = _bfs(_tile_pos, [_patrol_anchor])
		if _path.is_empty():
			return
		_move_step()
		return
	_path = [neighbors[randi() % neighbors.size()]]
	_move_step()


func _engage_tick() -> void:
	if _current_target == null or not is_instance_valid(_current_target):
		_current_target = null
		_enter_return()
		return
	var target_tile: Vector2i = _world_to_tile(_current_target.global_position)
	if _is_adjacent(_tile_pos, target_tile):
		_attack_target_if_ready()
		return
	# Move toward target if not already moving.
	if _is_moving:
		return
	_path = _path_to_adjacent(target_tile)
	if _path.is_empty():
		# Cannot reach target.
		_current_target = null
		_enter_return()
		return
	_move_step()


func _return_tick() -> void:
	if _is_moving:
		return
	if _tile_pos == _patrol_anchor:
		_state = State.IDLE_PATROL
		return
	_path = _bfs(_tile_pos, [_patrol_anchor])
	if _path.is_empty():
		_state = State.IDLE_PATROL
		return
	_move_step()


func _rally_move_tick() -> void:
	if _is_moving:
		return
	if _current_rally_job == null:
		_state = State.IDLE_PATROL
		return
	var goal: Vector2i = _current_rally_job.tile_pos
	if _tile_pos == goal:
		_patrol_anchor = goal  # Hold around the rally point.
		_state = State.AT_RALLY
		return
	_path = _bfs(_tile_pos, [goal])
	if _path.is_empty():
		_release_rally()
		_state = State.IDLE_PATROL
		return
	_move_step()


func _at_rally_tick() -> void:
	if _is_moving:
		return
	# Hold near rally; small wander allowed within patrol_radius around anchor.
	if randf() < 0.10:
		_wander_within_patrol_radius()


# ── Movement ──────────────────────────────────────────────────────────────────

func _move_step() -> void:
	if _path.is_empty():
		return
	if _is_moving:
		return
	var next_tile: Vector2i = _path.pop_front()
	if not _is_traversable(next_tile):
		_path.clear()
		return
	_is_moving = true
	_tile_pos = next_tile
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", _tile_to_world(next_tile), _move_time)
	_move_tween.tween_callback(_on_step_done)


func _on_step_done() -> void:
	_is_moving = false


func _kill_tween() -> void:
	if is_instance_valid(_move_tween):
		_move_tween.kill()
	_is_moving = false


# ── Combat ────────────────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	_hp = maxi(0, _hp - amount)
	_update_hp_bar()
	if _hp == 0:
		_die()


func _die() -> void:
	_kill_tween()
	if _current_rally_job != null:
		GameManager.job_queue.release_job(_current_rally_job.id)
		_current_rally_job = null
	queue_free()


func _attack_target_if_ready() -> void:
	if _attack_cooldown_remaining > 0.0:
		return
	if _current_target == null or not is_instance_valid(_current_target):
		return
	if _current_target.has_method("take_damage"):
		_current_target.take_damage(_damage)
		_attack_cooldown_remaining = _attack_cooldown


func _set_target(target: Node2D) -> void:
	_current_target = target


func _can_engage(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var defense_level: String = GameManager.colony.priorities.get("defense", "normal")
	if defense_level == "low":
		# Only engage if directly adjacent — minimal aggression.
		return _is_adjacent(_tile_pos, _world_to_tile(target.global_position))
	var radius: int = _detection_radius
	if defense_level == "high":
		radius = int(_detection_radius * 1.5)
	elif defense_level == "emergency":
		radius = _detection_radius * 3
	var target_tile: Vector2i = _world_to_tile(target.global_position)
	return _manhattan(_tile_pos, target_tile) <= radius


func _find_nearest_enemy() -> Node2D:
	var enemies: Array = get_tree().get_nodes_in_group(ENEMY_GROUP)
	var best: Node2D = null
	var best_dist: int = 100000
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var et: Vector2i = _world_to_tile(e.global_position)
		var d: int = _manhattan(_tile_pos, et)
		if d < best_dist:
			best_dist = d
			best = e
	return best


# ── Rally jobs ────────────────────────────────────────────────────────────────

func _claim_rally_job():
	# Soldiers only score RALLY jobs by manhattan distance.
	var job = GameManager.job_queue.claim_best_job(
			_tile_pos,
			self,
			[JobQueue.TYPE_RALLY],
			Callable(self, "_get_job_distance"))
	return job


func _get_job_distance(job) -> int:
	if not _is_traversable(job.tile_pos):
		# Rally point may be on tunnel only.
		return -1
	var path := _bfs(_tile_pos, [job.tile_pos])
	if path.is_empty() and _tile_pos != job.tile_pos:
		return -1
	return path.size()


func _release_rally() -> void:
	if _current_rally_job != null:
		GameManager.job_queue.release_job(_current_rally_job.id)
		_current_rally_job = null


# ── HP bar ────────────────────────────────────────────────────────────────────

func _update_hp_bar() -> void:
	if _hp_bar_bg == null or _hp_bar_fill == null:
		return
	var ratio: float = 0.0 if _max_hp <= 0 else clampf(float(_hp) / float(_max_hp), 0.0, 1.0)
	_hp_bar_fill.size.x = _hp_bar_bg.size.x * ratio


# ── Pathfinding ───────────────────────────────────────────────────────────────

func _path_to_adjacent(target: Vector2i) -> Array:
	var goals: Array = []
	for dir in DIRS:
		var n: Vector2i = target + dir
		if _is_traversable(n):
			goals.append(n)
	if goals.is_empty():
		return []
	if _tile_pos in goals:
		return []
	return _bfs(_tile_pos, goals)


func _bfs(from: Vector2i, goal_tiles: Array) -> Array:
	var goal_set: Dictionary = {}
	for g in goal_tiles:
		goal_set[g] = true
	if from in goal_set:
		return []

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

	var path: Array = []
	var node = found
	while came_from[node] != null:
		path.push_front(node)
		node = came_from[node]
	return path


func _is_traversable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= _world_w or pos.y < 0 or pos.y >= _world_h:
		return false
	if pos.y < _surface_row:
		return true
	var src_id := _tile_map.get_cell_source_id(pos)
	return src_id == _sid_tunnel or src_id == _sid_queen


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return _manhattan(a, b) == 1


# ── Utility ───────────────────────────────────────────────────────────────────

func _tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE_SIZE + TILE_SIZE / 2.0, tile.y * TILE_SIZE + TILE_SIZE / 2.0)


func _world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE))
