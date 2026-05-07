extends Node2D

const TILE_SIZE: int = 16
const WORKER_JOB_TYPES: Array = [JobQueue.JobType.DIG, JobQueue.JobType.GATHER]
const DIRS: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

enum State { IDLE, MOVING, WORKING, IDLE_WANDER }

# Config (overridden from worker_config.json)
var _move_time: float = 0.12
var _dig_duration: float = 1.2

# FSM
var _state: State = State.IDLE
var _current_job: JobQueue.Job = null
var _path: Array = []
var _is_moving: bool = false

# World references set by main.gd via setup()
var _tile_map: TileMapLayer
var _sid_tunnel: int = -1
var _sid_queen: int = -1
var _world_w: int = 60
var _world_h: int = 40
var _surface_row: int = 5
var _tile_pos: Vector2i = Vector2i.ZERO

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_sprite.texture = AssetLoader.get_ant_sprite("worker")


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
	_world_w = world_w
	_world_h = world_h
	_surface_row = surface_row
	position = _tile_to_world(start_tile)
	_load_config()
	GameManager.register_ant()
	_enter_idle()


func _load_config() -> void:
	var path := "res://data/ants/worker_config.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return
	_move_time = float(data.get("move_speed", _move_time))
	_dig_duration = float(data.get("dig_duration", _dig_duration))


func _exit_tree() -> void:
	if _current_job != null:
		GameManager.job_queue.release_job(_current_job.id)
	GameManager.unregister_ant()


# ── FSM ───────────────────────────────────────────────────────────────────────

func _enter_idle() -> void:
	_state = State.IDLE
	_path.clear()
	_is_moving = false
	_try_claim_job()


func _try_claim_job() -> void:
	if not is_instance_valid(_tile_map):
		return
	var job: JobQueue.Job = GameManager.job_queue.claim_best_job(
			_tile_pos, self, WORKER_JOB_TYPES)
	if job != null:
		_current_job = job
		_start_moving_to_job()
	else:
		_start_wander()


func _start_moving_to_job() -> void:
	if _current_job == null:
		_enter_idle()
		return
	_path = _find_path(_tile_pos, _current_job.tile_pos)
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
	for dir: Vector2i in DIRS:
		var n := _tile_pos + dir
		if _is_traversable(n):
			neighbors.append(n)
	if neighbors.is_empty():
		_retry_idle_after_delay()
		return
	_path = [neighbors[randi() % neighbors.size()]]
	_move_step()


func _retry_idle_after_delay() -> void:
	await get_tree().create_timer(0.4).timeout
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
	_tile_pos = next_tile
	var tween := create_tween()
	tween.tween_property(self, "position", _tile_to_world(next_tile), _move_time)
	tween.tween_callback(_on_step_done)


func _on_step_done() -> void:
	_is_moving = false
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
		JobQueue.JobType.DIG:
			_do_dig()
		JobQueue.JobType.GATHER:
			_do_gather()


func _do_dig() -> void:
	await get_tree().create_timer(_dig_duration).timeout
	if not is_instance_valid(self) or _current_job == null or not is_instance_valid(_tile_map):
		return
	_tile_map.set_cell(_current_job.tile_pos, _sid_tunnel, Vector2i(0, 0))
	GameManager.job_queue.complete_job(_current_job.id)
	_current_job = null
	_enter_idle()


func _do_gather() -> void:
	var food_tile := _current_job.tile_pos
	GameManager.add_food(1)
	GameManager.job_queue.complete_job(_current_job.id)
	# Re-add gather job so the source is persistent.
	GameManager.job_queue.add_job(JobQueue.JobType.GATHER, food_tile)
	_current_job = null
	_enter_idle()


# ── BFS pathfinding ───────────────────────────────────────────────────────────

func _find_path(from: Vector2i, to: Vector2i) -> Array:
	# If target is traversable, path straight to it (GATHER on surface).
	if _is_traversable(to):
		return _bfs(from, [to])
	# Otherwise find traversable neighbors (DIG: reach adjacent tunnel).
	var targets: Array = []
	for dir: Vector2i in DIRS:
		var n := to + dir
		if _is_traversable(n):
			targets.append(n)
	if targets.is_empty():
		return []
	return _bfs(from, targets)


func _bfs(from: Vector2i, goal_tiles: Array) -> Array:
	var goal_set: Dictionary = {}
	for g: Vector2i in goal_tiles:
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
		for dir: Vector2i in DIRS:
			var neighbor := current + dir
			if neighbor in came_from:
				continue
			if not _is_traversable(neighbor):
				continue
			came_from[neighbor] = current
			queue.append(neighbor)

	if found == null:
		return []

	var path: Array = []
	var node: Vector2i = found
	while came_from[node] != null:
		path.push_front(node)
		node = came_from[node]
	return path


func _is_traversable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= _world_w or pos.y < 0 or pos.y >= _world_h:
		return false
	if pos.y < _surface_row:
		return true  # Open sky above ground.
	var src_id := _tile_map.get_cell_source_id(pos)
	return src_id == -1 or src_id == _sid_tunnel or src_id == _sid_queen


# ── Utility ───────────────────────────────────────────────────────────────────

func _tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE_SIZE + TILE_SIZE / 2.0, tile.y * TILE_SIZE + TILE_SIZE / 2.0)
