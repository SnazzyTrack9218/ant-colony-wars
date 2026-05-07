extends Node2D

const TILE_SIZE: int = 16
const WorkerAntScene: PackedScene = preload("res://scenes/ants/worker_ant.tscn")

# World dimensions and layout — all read from colony_config.json at startup.
var _world_w: int = 60
var _world_h: int = 40
var _surface_row: int = 5
var _queen_col: int = 30
var _queen_row: int = 27
var _starting_workers: int = 3

# Tile source IDs assigned by Godot when sources are added to the TileSet.
var _sid: Dictionary = {}  # "dirt" | "tunnel" | "stone" | "queen" -> int

# Tile positions that cannot receive Dig Markers.
var _protected: Dictionary = {}  # Vector2i -> true

# Active dig marker visuals.
var _dig_marker_nodes: Dictionary = {}  # Vector2i -> ColorRect

# Food source positions (sky area, always traversable).
var _food_positions: Array = []

@onready var _tile_map: TileMapLayer = $TileMapLayer
@onready var _ants_root: Node2D = $Ants
@onready var _dig_markers_root: Node2D = $DigMarkers
@onready var _food_markers_root: Node2D = $FoodMarkers
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	_load_config()
	_setup_tileset()
	_build_world()
	_place_food_sources()
	_spawn_starting_workers()
	_center_camera()
	GameManager.job_queue.job_completed.connect(_on_job_completed)
	print("Main: world ready. %d×%d tiles." % [_world_w, _world_h])


# ── Config ────────────────────────────────────────────────────────────────────

func _load_config() -> void:
	var path := "res://data/colony/colony_config.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return
	_world_w = int(data.get("world_width", _world_w))
	_world_h = int(data.get("world_height", _world_h))
	_surface_row = int(data.get("surface_row", _surface_row))
	_queen_col = int(data.get("queen_col", _queen_col))
	_queen_row = int(data.get("queen_row", _queen_row))
	_starting_workers = int(data.get("starting_workers", _starting_workers))
	GameManager.colony.max_food = int(data.get("max_food", GameManager.colony.max_food))


# ── Tileset setup ─────────────────────────────────────────────────────────────

func _setup_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	for tile_name: String in ["dirt", "tunnel", "stone"]:
		var tex: Texture2D = AssetLoader.get_tile_sprite(tile_name)
		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		src.create_tile(Vector2i(0, 0))
		_sid[tile_name] = ts.add_source(src)

	# Queen chamber tile — gold placeholder created in code.
	var queen_src := TileSetAtlasSource.new()
	queen_src.texture = _make_color_tile(Color(1.0, 0.78, 0.0))
	queen_src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	queen_src.create_tile(Vector2i(0, 0))
	_sid["queen"] = ts.add_source(queen_src)

	_tile_map.tile_set = ts


func _make_color_tile(color: Color) -> ImageTexture:
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


# ── World generation ──────────────────────────────────────────────────────────

func _build_world() -> void:
	# Fill underground with dirt.
	for y in range(_surface_row, _world_h):
		for x in range(_world_w):
			_tile_map.set_cell(Vector2i(x, y), _sid["dirt"], Vector2i(0, 0))

	# Vertical access shaft from surface to queen area.
	for y in range(_surface_row, _queen_row):
		_tile_map.set_cell(Vector2i(_queen_col, y), _sid["tunnel"], Vector2i(0, 0))

	# Horizontal starting corridor just above queen chamber.
	for x in range(_queen_col - 5, _queen_col + 6):
		_tile_map.set_cell(Vector2i(x, _queen_row - 1), _sid["tunnel"], Vector2i(0, 0))

	# Queen chamber — 3×3 protected tiles.
	for dy in range(3):
		for dx in range(3):
			var pos := Vector2i(_queen_col - 1 + dx, _queen_row + dy)
			_tile_map.set_cell(pos, _sid["queen"], Vector2i(0, 0))
			_protected[pos] = true


func _place_food_sources() -> void:
	var food_row := _surface_row - 3  # Rows above ground are open sky.
	var spacing: int = _world_w / 5
	for i in range(4):
		var food_pos := Vector2i(spacing + i * spacing, food_row)
		_food_positions.append(food_pos)
		GameManager.job_queue.add_job(JobQueue.JobType.GATHER, food_pos)
		_spawn_food_visual(food_pos)


func _spawn_food_visual(tile_pos: Vector2i) -> void:
	var rect := ColorRect.new()
	rect.color = Color(0.2, 0.85, 0.2)
	rect.size = Vector2(TILE_SIZE, TILE_SIZE)
	rect.position = Vector2(tile_pos.x * TILE_SIZE, tile_pos.y * TILE_SIZE)
	_food_markers_root.add_child(rect)


# ── Worker spawning ───────────────────────────────────────────────────────────

func _spawn_starting_workers() -> void:
	# Spawn workers in the corridor just above the queen chamber.
	for i in range(_starting_workers):
		var col := _queen_col - 2 + i
		var spawn_tile := Vector2i(col, _queen_row - 1)
		_spawn_worker(spawn_tile)


func _spawn_worker(tile_pos: Vector2i) -> void:
	var worker: Node2D = WorkerAntScene.instantiate()
	_ants_root.add_child(worker)
	worker.setup(
			_tile_map,
			_sid["tunnel"],
			_sid["queen"],
			tile_pos,
			_world_w,
			_world_h,
			_surface_row)


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var tile_pos := _tile_map.local_to_map(_tile_map.to_local(get_global_mouse_position()))
		_try_place_dig_marker(tile_pos)


func _try_place_dig_marker(tile_pos: Vector2i) -> void:
	# Bounds check.
	if tile_pos.x < 0 or tile_pos.x >= _world_w or tile_pos.y < 0 or tile_pos.y >= _world_h:
		return
	# Only place on dirt tiles.
	if _tile_map.get_cell_source_id(tile_pos) != _sid["dirt"]:
		return
	# Protected tiles (queen chamber) cannot be dug.
	if tile_pos in _protected:
		return
	# Duplicate marker guard.
	if tile_pos in _dig_marker_nodes:
		return
	_add_dig_marker(tile_pos)
	GameManager.job_queue.add_job(JobQueue.JobType.DIG, tile_pos)


func _add_dig_marker(tile_pos: Vector2i) -> void:
	var rect := ColorRect.new()
	rect.color = Color(1.0, 0.5, 0.0, 0.55)
	rect.size = Vector2(TILE_SIZE, TILE_SIZE)
	rect.position = Vector2(tile_pos.x * TILE_SIZE, tile_pos.y * TILE_SIZE)
	_dig_markers_root.add_child(rect)
	_dig_marker_nodes[tile_pos] = rect


func _remove_dig_marker(tile_pos: Vector2i) -> void:
	if tile_pos in _dig_marker_nodes:
		_dig_marker_nodes[tile_pos].queue_free()
		_dig_marker_nodes.erase(tile_pos)


func _on_job_completed(job: JobQueue.Job) -> void:
	if job.type == JobQueue.JobType.DIG:
		_remove_dig_marker(job.tile_pos)


# ── Camera ────────────────────────────────────────────────────────────────────

func _center_camera() -> void:
	var queen_center := Vector2(
			_queen_col * TILE_SIZE + TILE_SIZE / 2.0,
			_queen_row * TILE_SIZE + TILE_SIZE / 2.0)
	_camera.position = queen_center
