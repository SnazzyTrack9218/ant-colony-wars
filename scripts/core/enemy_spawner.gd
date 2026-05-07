extends Node
class_name EnemySpawner

const SpiderScene: PackedScene = preload("res://scenes/enemies/spider.tscn")
const BeetleScene: PackedScene = preload("res://scenes/enemies/beetle.tscn")
const CONFIG_PATH: String = "res://data/colony/enemy_spawn_config.json"
const SCENES_BY_KIND: Dictionary = {}  # populated in _ready

var _spawn_interval_start: float = 24.0
var _spawn_interval_min: float = 9.0
var _spawn_interval_decay: float = 0.85
var _wave_grow_after: float = 60.0
var _max_concurrent: int = 12
var _first_spawn_delay: float = 25.0
var _spawn_chances: Dictionary = {"spider": 0.7, "beetle": 0.3}

var _enabled: bool = false
var _elapsed: float = 0.0
var _next_spawn_in: float = 0.0
var _current_interval: float = 24.0

# Set by main.gd via configure().
var _world_w: int = 0
var _world_h: int = 0
var _surface_row: int = 0
var _tile_map: TileMapLayer = null
var _sid_tunnel: int = -1
var _sid_queen: int = -1
var _sid_dirt: int = -1
var _sid_stone: int = -1
var _queen_tile: Vector2i = Vector2i.ZERO
var _enemies_root: Node = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_load_config()
	_rng.randomize()
	_next_spawn_in = _first_spawn_delay
	_current_interval = _spawn_interval_start


func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return
	_spawn_interval_start = float(data.get("spawn_interval_start", _spawn_interval_start))
	_spawn_interval_min = float(data.get("spawn_interval_min", _spawn_interval_min))
	_spawn_interval_decay = float(data.get("spawn_interval_decay", _spawn_interval_decay))
	_wave_grow_after = float(data.get("wave_grow_after_seconds", _wave_grow_after))
	_max_concurrent = int(data.get("max_concurrent_enemies", _max_concurrent))
	_first_spawn_delay = float(data.get("first_spawn_delay", _first_spawn_delay))
	if data.get("spawn_chances", null) is Dictionary:
		_spawn_chances = data["spawn_chances"]


func configure(
		tile_map: TileMapLayer,
		enemies_root: Node,
		world_w: int,
		world_h: int,
		surface_row: int,
		queen_tile: Vector2i,
		sid_tunnel: int,
		sid_queen: int,
		sid_dirt: int,
		sid_stone: int) -> void:
	_tile_map = tile_map
	_enemies_root = enemies_root
	_world_w = world_w
	_world_h = world_h
	_surface_row = surface_row
	_queen_tile = queen_tile
	_sid_tunnel = sid_tunnel
	_sid_queen = sid_queen
	_sid_dirt = sid_dirt
	_sid_stone = sid_stone


func start() -> void:
	_enabled = true
	_elapsed = 0.0
	_next_spawn_in = _first_spawn_delay
	_current_interval = _spawn_interval_start


func stop() -> void:
	_enabled = false


func _process(delta: float) -> void:
	if not _enabled:
		return
	if _tile_map == null or _enemies_root == null:
		return
	_elapsed += delta
	_next_spawn_in -= delta
	if _next_spawn_in > 0.0:
		return
	if _enemies_root.get_child_count() >= _max_concurrent:
		# Skip this spawn but keep timer ticking.
		_next_spawn_in = _current_interval
		return
	_spawn_one()
	# Decay interval over time toward min.
	if _elapsed >= _wave_grow_after:
		_current_interval = maxf(_spawn_interval_min, _current_interval * _spawn_interval_decay)
	_next_spawn_in = _current_interval


func _spawn_one() -> void:
	var kind: String = _pick_kind()
	var spawn_tile: Vector2i = _pick_spawn_tile()
	if spawn_tile == Vector2i(-1, -1):
		return
	var scene: PackedScene = SpiderScene if kind == "spider" else BeetleScene
	var enemy: Node2D = scene.instantiate()
	_enemies_root.add_child(enemy)
	enemy.setup(
			_tile_map,
			_sid_tunnel,
			_sid_queen,
			_sid_dirt,
			_sid_stone,
			spawn_tile,
			_queen_tile,
			_world_w,
			_world_h,
			_surface_row)


func _pick_kind() -> String:
	var total: float = 0.0
	for v in _spawn_chances.values():
		total += float(v)
	if total <= 0.0:
		return "spider"
	var roll: float = _rng.randf() * total
	var acc: float = 0.0
	for k in _spawn_chances.keys():
		acc += float(_spawn_chances[k])
		if roll <= acc:
			return String(k)
	return "spider"


func _pick_spawn_tile() -> Vector2i:
	# Try edge tiles in randomized order: left/right columns above ground or surface-adjacent rows.
	for attempt in 30:
		var edge: int = _rng.randi() % 4
		var tile: Vector2i
		match edge:
			0: # left edge
				tile = Vector2i(0, _rng.randi_range(_surface_row - 2, _world_h - 1))
			1: # right edge
				tile = Vector2i(_world_w - 1, _rng.randi_range(_surface_row - 2, _world_h - 1))
			2: # top (sky) edge
				tile = Vector2i(_rng.randi_range(0, _world_w - 1), 0)
			_:
				tile = Vector2i(_rng.randi_range(0, _world_w - 1), _world_h - 1)
		if _is_valid_spawn_tile(tile):
			return tile
	# Fallback: top-center of map.
	return Vector2i(_world_w / 2, 0)


func _is_valid_spawn_tile(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.x >= _world_w or tile.y < 0 or tile.y >= _world_h:
		return false
	if tile.y < _surface_row:
		return true  # Open sky.
	var src_id: int = _tile_map.get_cell_source_id(tile)
	return src_id == _sid_tunnel
