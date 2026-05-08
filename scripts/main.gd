extends Node2D

const TILE_SIZE: int = 16
const WorkerAntScene: PackedScene = preload("res://scenes/ants/worker_ant.tscn")
const SoldierAntScene: PackedScene = preload("res://scenes/ants/soldier_ant.tscn")
const GameOverScene: PackedScene = preload("res://scenes/ui/game_over_screen.tscn")
const EnemySpawnerScript: GDScript = preload("res://scripts/core/enemy_spawner.gd")
const WorldGeneratorScript: GDScript = preload("res://scripts/core/world_generator.gd")
const ROOM_TYPE_ORDER: Array[String] = [
	"nursery",
	"food_storage",
	"mushroom_farm",
	"guard_post",
	"soldier_barracks",
]

# World dimensions and layout — all read from colony_config.json at startup.
var _world_w: int = 60
var _world_h: int = 40
var _surface_row: int = 5
var _queen_col: int = 30
var _queen_row: int = 27
var _starting_workers: int = 3
var _camera_zoom: float = 1.0
var _camera_min_zoom: float = 0.45
var _camera_max_zoom: float = 2.25
var _camera_zoom_step: float = 0.12
var _camera_move_speed: float = 520.0
var _selected_room_index: int = 0
var _selected_room_type: String = "nursery"

# Tile source IDs assigned by Godot when sources are added to the TileSet.
var _sid: Dictionary = {}  # "dirt" | "tunnel" | "stone" | "queen" -> int

# Tile positions that cannot receive Dig Markers.
var _protected: Dictionary = {}  # Vector2i -> true

# Active dig marker visuals.
var _dig_marker_nodes: Dictionary = {}  # Vector2i -> Control
var _room_plan_nodes: Dictionary = {}  # plan_id -> Control
var _room_nodes: Dictionary = {}  # plan_id -> Node2D

# Food source positions generated inside reachable underground pockets.
var _food_positions: Array = []

@onready var _tile_map: TileMapLayer = $TileMapLayer
@onready var _ants_root: Node2D = $Ants
@onready var _enemies_root: Node2D = $Enemies
@onready var _dig_markers_root: Node2D = $DigMarkers
@onready var _food_markers_root: Node2D = $FoodMarkers
@onready var _room_plans_root: Node2D = $RoomPlans
@onready var _rooms_root: Node2D = $Rooms
@onready var _rally_markers_root: Node2D = $RallyMarkers
@onready var _camera: Camera2D = $Camera2D
@onready var _hud: CanvasLayer = $HUD

var _enemy_spawner: Node = null
var _game_over_layer: CanvasLayer = null
var _rally_marker_nodes: Dictionary = {}  # job_id -> Panel
var _room_picker: Node = null


func _ready() -> void:
	_load_config()
	_load_camera_config()
	_setup_tileset()
	_ensure_runtime_nodes()
	_build_world()
	_place_food_sources()
	_spawn_starting_workers()
	_center_camera()
	_setup_enemy_spawner()
	_setup_game_over_screen()
	_connect_room_picker()
	AudioManager.play_music_mode("peace")
	_connect_room_manager()
	GameManager.job_queue.job_completed.connect(_on_job_completed)
	print("Main: world ready. %d×%d tiles." % [_world_w, _world_h])


func _ensure_runtime_nodes() -> void:
	# Enemies and RallyMarkers may not exist in the .tscn yet — create lazily.
	if _enemies_root == null:
		_enemies_root = Node2D.new()
		_enemies_root.name = "Enemies"
		add_child(_enemies_root)
	if _rally_markers_root == null:
		_rally_markers_root = Node2D.new()
		_rally_markers_root.name = "RallyMarkers"
		add_child(_rally_markers_root)


func _setup_enemy_spawner() -> void:
	_enemy_spawner = EnemySpawnerScript.new()
	add_child(_enemy_spawner)
	_enemy_spawner.configure(
			_tile_map,
			_enemies_root,
			_world_w,
			_world_h,
			_surface_row,
			Vector2i(_queen_col, _queen_row),
			_sid["tunnel"],
			_sid["queen"],
			_sid["dirt"],
			_sid["stone"])
	_enemy_spawner.start()


func _setup_game_over_screen() -> void:
	_game_over_layer = GameOverScene.instantiate()
	add_child(_game_over_layer)


func _connect_room_picker() -> void:
	_room_picker = _hud.get_node_or_null("RoomPicker")
	if _room_picker == null:
		return
	_room_picker.set_selection(_selected_room_index)
	_room_picker.selection_changed.connect(_on_room_picker_changed)


func _on_room_picker_changed(room_type: String) -> void:
	_selected_room_type = room_type
	var idx: int = ROOM_TYPE_ORDER.find(room_type)
	if idx != -1:
		_selected_room_index = idx


func _process(delta: float) -> void:
	_update_camera_movement(delta)


# ── Config ────────────────────────────────────────────────────────────────────

func _load_config() -> void:
	var config_path := "res://data/colony/colony_config.json"
	if not FileAccess.file_exists(config_path):
		return
	var file := FileAccess.open(config_path, FileAccess.READ)
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
	GameManager.colony.max_workers = int(data.get("max_workers", GameManager.colony.max_workers))
	GameManager.room_manager.debug_instant_build = bool(data.get("debug_instant_build", false))
	GameManager.colony.food = clampi(
			int(data.get("starting_food", GameManager.colony.food)),
			0,
			GameManager.colony.max_food)
	GameManager.colony.queen_max_hp = int(data.get("queen_max_hp", GameManager.colony.queen_max_hp))
	GameManager.colony.queen_hp = clampi(
			int(data.get("queen_hp", GameManager.colony.queen_max_hp)),
			0,
			GameManager.colony.queen_max_hp)
	GameManager.food_changed.emit(GameManager.colony.food)


func _load_camera_config() -> void:
	var config_path := "res://data/camera/camera_config.json"
	if not FileAccess.file_exists(config_path):
		return
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return
	_camera_zoom = maxf(0.1, float(data.get("camera_zoom", _camera_zoom)))
	_camera_min_zoom = maxf(0.1, float(data.get("min_zoom", _camera_min_zoom)))
	_camera_max_zoom = maxf(_camera_min_zoom, float(data.get("max_zoom", _camera_max_zoom)))
	_camera_zoom_step = maxf(0.01, float(data.get("zoom_step", _camera_zoom_step)))
	_camera_move_speed = maxf(0.0, float(data.get("move_speed", _camera_move_speed)))


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
	_tile_map.clear()
	_protected.clear()
	_food_positions.clear()

	var generator: WorldGenerator = WorldGeneratorScript.new()
	var world_data: Dictionary = generator.generate(
			_world_w,
			_world_h,
			_surface_row,
			_queen_col,
			_queen_row)
	_apply_generated_world(world_data)


func _apply_generated_world(world_data: Dictionary) -> void:
	for tile_pos in world_data.get("dirt_tiles", []):
		_tile_map.set_cell(Vector2i(tile_pos), _sid["dirt"], Vector2i(0, 0))
	for tile_pos in world_data.get("stone_tiles", []):
		_tile_map.set_cell(Vector2i(tile_pos), _sid["stone"], Vector2i(0, 0))
	for tile_pos in world_data.get("tunnel_tiles", []):
		_tile_map.set_cell(Vector2i(tile_pos), _sid["tunnel"], Vector2i(0, 0))
	for tile_pos in world_data.get("queen_tiles", []):
		_tile_map.set_cell(Vector2i(tile_pos), _sid["queen"], Vector2i(0, 0))
	for tile_pos in world_data.get("protected_tiles", []):
		_protected[Vector2i(tile_pos)] = true
	for food_pos in world_data.get("food_positions", []):
		_food_positions.append(Vector2i(food_pos))


func _place_food_sources() -> void:
	for food_pos in _food_positions:
		_spawn_food_visual(Vector2i(food_pos))


func _spawn_food_visual(tile_pos: Vector2i) -> void:
	# Food sources: outlined amber square — sourced from ui_theme palette so the
	# whole world UI uses one color language.
	var marker := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(ColonyUITheme.ACCENT_AMBER.r, ColonyUITheme.ACCENT_AMBER.g, ColonyUITheme.ACCENT_AMBER.b, 0.55)
	style.border_color = ColonyUITheme.ACCENT_AMBER
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	marker.add_theme_stylebox_override("panel", style)
	marker.size = Vector2(TILE_SIZE, TILE_SIZE)
	marker.position = Vector2(tile_pos.x * TILE_SIZE, tile_pos.y * TILE_SIZE)
	_food_markers_root.add_child(marker)


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
			_sid["dirt"],
			_sid["tunnel"],
			_sid["queen"],
			tile_pos,
			_world_w,
			_world_h,
			_surface_row,
			_food_positions)
	AudioManager.play_ant_spawned()


func _spawn_soldier(tile_pos: Vector2i) -> void:
	var soldier: Node2D = SoldierAntScene.instantiate()
	_ants_root.add_child(soldier)
	soldier.setup(
			_tile_map,
			_sid["tunnel"],
			_sid["queen"],
			tile_pos,
			_world_w,
			_world_h,
			_surface_row)
	AudioManager.play_ant_spawned()


func _on_soldier_spawn_requested(tile_pos: Vector2i) -> void:
	var spawn_tile: Vector2i = _find_spawn_tile_near(tile_pos)
	if spawn_tile != Vector2i(-1, -1):
		_spawn_soldier(spawn_tile)


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_room_selection_key(event.keycode)
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(_camera_zoom_step, event.position)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(-_camera_zoom_step, event.position)
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var right_tile_pos: Vector2i = _tile_map.local_to_map(_tile_map.to_local(get_global_mouse_position()))
			# Shift+right-click → Emergency Marker; plain right-click → Room Plan.
			if event.shift_pressed:
				_try_place_emergency_marker(right_tile_pos)
			else:
				_try_place_room_plan(right_tile_pos)
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			var rally_tile_pos: Vector2i = _tile_map.local_to_map(_tile_map.to_local(get_global_mouse_position()))
			_try_place_rally_marker(rally_tile_pos)
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var tile_pos := _tile_map.local_to_map(_tile_map.to_local(get_global_mouse_position()))
		# Shift+left-click on damaged room → Repair Marker; otherwise → Dig Marker.
		if event.shift_pressed and GameManager.room_manager.is_room_damaged(tile_pos):
			_try_place_repair_marker(tile_pos)
		else:
			_try_place_dig_target(tile_pos)


func _handle_room_selection_key(keycode: int) -> void:
	if keycode == KEY_B:
		_selected_room_index = posmod(_selected_room_index + 1, ROOM_TYPE_ORDER.size())
		_selected_room_type = ROOM_TYPE_ORDER[_selected_room_index]
		if _room_picker != null:
			_room_picker.set_selection(_selected_room_index)
		return
	if keycode >= KEY_1 and keycode <= KEY_5:
		_selected_room_index = int(keycode - KEY_1)
		_selected_room_type = ROOM_TYPE_ORDER[_selected_room_index]
		if _room_picker != null:
			_room_picker.set_selection(_selected_room_index)


func _try_place_dig_target(target: Vector2i) -> void:
	if target.x < 0 or target.x >= _world_w or target.y < 0 or target.y >= _world_h:
		return
	if _tile_map.get_cell_source_id(target) != _sid["dirt"]:
		return
	if target in _protected:
		return
	if target in _food_positions:
		return
	if target in _dig_marker_nodes:
		return
	_add_dig_marker(target)
	AudioManager.play_marker_placed()
	GameManager.job_queue.add_job(JobQueue.TYPE_DIG, target)


func _try_place_room_plan(target: Vector2i) -> void:
	if target.x < 0 or target.x >= _world_w or target.y < 0 or target.y >= _world_h:
		return
	if _tile_map.get_cell_source_id(target) != _sid["tunnel"]:
		return
	if target in _protected:
		return
	var plan_id: int = GameManager.room_manager.create_room_plan(_selected_room_type, target)
	if plan_id >= 0:
		AudioManager.play_marker_placed()


func _try_place_rally_marker(target: Vector2i) -> void:
	if target.x < 0 or target.x >= _world_w or target.y < 0 or target.y >= _world_h:
		return
	# Rally only on tunnel tiles (no dirt, stone, queen-chamber).
	if _tile_map.get_cell_source_id(target) != _sid["tunnel"]:
		return
	# Avoid duplicates at the same spot.
	if GameManager.job_queue.has_job(JobQueue.TYPE_RALLY, target):
		return
	var job = GameManager.job_queue.add_job(JobQueue.TYPE_RALLY, target)
	if job == null:
		return
	_add_rally_marker_visual(job.id, target)
	AudioManager.play_marker_placed()


func _add_rally_marker_visual(job_id: int, tile_pos: Vector2i) -> void:
	var marker := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(ColonyUITheme.ACCENT_RED.r, ColonyUITheme.ACCENT_RED.g, ColonyUITheme.ACCENT_RED.b, 0.10)
	style.border_color = ColonyUITheme.ACCENT_RED
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	marker.add_theme_stylebox_override("panel", style)
	marker.size = Vector2(TILE_SIZE, TILE_SIZE)
	marker.pivot_offset = marker.size * 0.5
	marker.position = Vector2(tile_pos.x * TILE_SIZE, tile_pos.y * TILE_SIZE)
	_rally_markers_root.add_child(marker)
	_rally_marker_nodes[job_id] = marker
	var tween: Tween = create_tween()
	tween.tween_property(marker, "scale", Vector2(1.20, 1.20), 0.10)
	tween.tween_property(marker, "scale", Vector2.ONE, 0.14)


func _remove_rally_marker_visual(job_id: int) -> void:
	if job_id in _rally_marker_nodes:
		_rally_marker_nodes[job_id].queue_free()
		_rally_marker_nodes.erase(job_id)


func _try_place_repair_marker(target: Vector2i) -> void:
	if not GameManager.room_manager.is_room_damaged(target):
		return
	if GameManager.job_queue.has_job(JobQueue.TYPE_REPAIR, target):
		return
	GameManager.job_queue.add_job(JobQueue.TYPE_REPAIR, target)
	AudioManager.play_marker_placed()


func _try_place_emergency_marker(target: Vector2i) -> void:
	if target.x < 0 or target.x >= _world_w or target.y < 0 or target.y >= _world_h:
		return
	# Emergency only places on diggable dirt.
	if _tile_map.get_cell_source_id(target) != _sid["dirt"]:
		return
	if target in _protected:
		return
	if target in _food_positions:
		return
	if target in _dig_marker_nodes:
		return
	_add_dig_marker(target, true)
	AudioManager.play_marker_placed()
	var job = GameManager.job_queue.add_job(JobQueue.TYPE_DIG, target)
	if job != null:
		job.data["emergency"] = true
	# Auto-clear after 30 seconds even if not completed.
	get_tree().create_timer(30.0).timeout.connect(func():
		if target in _dig_marker_nodes and GameManager.job_queue.has_job(JobQueue.TYPE_DIG, target):
			# Find and release the job; remove visual.
			GameManager.job_queue.cancel_job_at(JobQueue.TYPE_DIG, target)
			_remove_dig_marker(target)
	)


func _add_dig_marker(tile_pos: Vector2i, emergency: bool = false) -> void:
	var marker := Panel.new()
	if emergency:
		marker.add_theme_stylebox_override("panel", _make_emergency_marker_style())
	else:
		marker.add_theme_stylebox_override("panel", _make_dig_marker_style())
	marker.size = Vector2(TILE_SIZE, TILE_SIZE)
	marker.pivot_offset = marker.size * 0.5
	marker.position = Vector2(tile_pos.x * TILE_SIZE, tile_pos.y * TILE_SIZE)
	_dig_markers_root.add_child(marker)
	_dig_marker_nodes[tile_pos] = marker
	var tween: Tween = create_tween()
	if emergency:
		tween.tween_property(marker, "scale", Vector2(1.35, 1.35), 0.10)
		tween.tween_property(marker, "scale", Vector2.ONE, 0.18)
	else:
		tween.tween_property(marker, "scale", Vector2(1.18, 1.18), 0.11)
		tween.tween_property(marker, "scale", Vector2.ONE, 0.14)


func _make_emergency_marker_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(ColonyUITheme.ACCENT_RED.r, ColonyUITheme.ACCENT_RED.g, ColonyUITheme.ACCENT_RED.b, 0.18)
	style.border_color = ColonyUITheme.ACCENT_RED
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	return style


func _remove_dig_marker(tile_pos: Vector2i) -> void:
	if tile_pos in _dig_marker_nodes:
		_dig_marker_nodes[tile_pos].queue_free()
		_dig_marker_nodes.erase(tile_pos)


func _make_dig_marker_style() -> StyleBoxFlat:
	return ColonyUITheme.marker_style()


func _on_job_completed(job: JobQueue.Job) -> void:
	if job.type == JobQueue.TYPE_DIG:
		_remove_dig_marker(job.tile_pos)
	elif job.type == JobQueue.TYPE_RALLY:
		_remove_rally_marker_visual(job.id)


func _connect_room_manager() -> void:
	GameManager.room_manager.room_plan_created.connect(_on_room_plan_created)
	GameManager.room_manager.room_plan_updated.connect(_on_room_plan_updated)
	GameManager.room_manager.room_completed.connect(_on_room_completed)
	GameManager.room_manager.worker_spawn_requested.connect(_on_worker_spawn_requested)
	GameManager.room_manager.soldier_spawn_requested.connect(_on_soldier_spawn_requested)
	GameManager.room_manager.room_destroyed.connect(_on_room_destroyed)


func _on_room_destroyed(room_id: int, _room_type: String, _tile_pos: Vector2i) -> void:
	if room_id in _room_nodes:
		_room_nodes[room_id].queue_free()
		_room_nodes.erase(room_id)


func _on_room_plan_created(plan_id: int, room_type: String, tile_pos: Vector2i, _build_cost: int) -> void:
	var marker := Panel.new()
	marker.add_theme_stylebox_override("panel", _make_room_plan_style(0.0))
	marker.size = Vector2(TILE_SIZE, TILE_SIZE)
	marker.position = Vector2(tile_pos.x * TILE_SIZE, tile_pos.y * TILE_SIZE)
	marker.tooltip_text = GameManager.room_manager.get_display_name(room_type)
	_room_plans_root.add_child(marker)
	_room_plan_nodes[plan_id] = marker


func _on_room_plan_updated(plan_id: int, progress: int, build_cost: int) -> void:
	if not (plan_id in _room_plan_nodes):
		return
	var ratio: float = 1.0 if build_cost <= 0 else clampf(float(progress) / float(build_cost), 0.0, 1.0)
	_room_plan_nodes[plan_id].add_theme_stylebox_override("panel", _make_room_plan_style(ratio))


func _on_room_completed(plan_id: int, room_type: String, tile_pos: Vector2i) -> void:
	if plan_id in _room_plan_nodes:
		_room_plan_nodes[plan_id].queue_free()
		_room_plan_nodes.erase(plan_id)
	_spawn_room_visual(plan_id, room_type, tile_pos)


func _on_worker_spawn_requested(tile_pos: Vector2i) -> void:
	var spawn_tile: Vector2i = _find_spawn_tile_near(tile_pos)
	if spawn_tile != Vector2i(-1, -1):
		_spawn_worker(spawn_tile)


func _spawn_room_visual(room_id: int, room_type: String, tile_pos: Vector2i) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = AssetLoader.get_room_sprite(room_type)
	sprite.position = Vector2(
			tile_pos.x * TILE_SIZE + TILE_SIZE / 2.0,
			tile_pos.y * TILE_SIZE + TILE_SIZE / 2.0)
	_fit_sprite_to_tile(sprite)
	_rooms_root.add_child(sprite)
	_room_nodes[room_id] = sprite


func _find_spawn_tile_near(tile_pos: Vector2i) -> Vector2i:
	if _tile_map.get_cell_source_id(tile_pos) == _sid["tunnel"]:
		return tile_pos
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var candidate: Vector2i = tile_pos + dir
		if _tile_map.get_cell_source_id(candidate) == _sid["tunnel"]:
			return candidate
	return Vector2i(-1, -1)


func _fit_sprite_to_tile(sprite: Sprite2D) -> void:
	if sprite.texture == null:
		return
	var texture_size: Vector2 = sprite.texture.get_size()
	var largest_axis: float = maxf(texture_size.x, texture_size.y)
	if largest_axis <= 0.0:
		return
	var fit_scale: float = float(TILE_SIZE) / largest_axis
	sprite.scale = Vector2(fit_scale, fit_scale)


func _make_room_plan_style(progress_ratio: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(
			ColonyUITheme.ACCENT_PURPLE.r,
			ColonyUITheme.ACCENT_PURPLE.g,
			ColonyUITheme.ACCENT_PURPLE.b,
			0.12 + progress_ratio * 0.32)
	style.border_color = ColonyUITheme.ACCENT_PURPLE
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	return style


# ── Camera ────────────────────────────────────────────────────────────────────

func _center_camera() -> void:
	_set_camera_zoom(_camera_zoom)
	_camera.position = Vector2(
			_world_w * TILE_SIZE / 2.0,
			_world_h * TILE_SIZE / 2.0)
	_clamp_camera_to_world()


func _zoom_camera(zoom_delta: float, screen_pos: Vector2) -> void:
	var before_zoom_world_pos: Vector2 = _camera.get_screen_center_position() \
			+ (screen_pos - get_viewport_rect().size * 0.5) / _camera.zoom
	_set_camera_zoom(_camera.zoom.x + zoom_delta)
	var after_zoom_world_pos: Vector2 = _camera.get_screen_center_position() \
			+ (screen_pos - get_viewport_rect().size * 0.5) / _camera.zoom
	_camera.position += before_zoom_world_pos - after_zoom_world_pos
	_clamp_camera_to_world()


func _set_camera_zoom(zoom_value: float) -> void:
	var clamped_zoom: float = clampf(zoom_value, _camera_min_zoom, _camera_max_zoom)
	_camera_zoom = clamped_zoom
	_camera.zoom = Vector2(clamped_zoom, clamped_zoom)


func _update_camera_movement(delta: float) -> void:
	var move_dir: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_dir.y += 1.0
	if move_dir == Vector2.ZERO:
		return
	_camera.position += move_dir.normalized() * _camera_move_speed * delta
	_clamp_camera_to_world()


func _clamp_camera_to_world() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var visible_size: Vector2 = Vector2(
			viewport_size.x / _camera.zoom.x,
			viewport_size.y / _camera.zoom.y)
	var world_size: Vector2 = Vector2(_world_w * TILE_SIZE, _world_h * TILE_SIZE)
	var half_visible: Vector2 = visible_size * 0.5
	var world_center: Vector2 = world_size * 0.5
	if world_size.x <= visible_size.x:
		_camera.position.x = world_center.x
	else:
		_camera.position.x = clampf(_camera.position.x, half_visible.x, world_size.x - half_visible.x)
	if world_size.y <= visible_size.y:
		_camera.position.y = world_center.y
	else:
		_camera.position.y = clampf(_camera.position.y, half_visible.y, world_size.y - half_visible.y)
