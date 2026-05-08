extends Node2D
class_name EnemyBase

const TILE_SIZE: int = 16
const DIRS: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const ENEMY_GROUP: String = "enemies"
const SOLDIER_GROUP: String = "soldiers"
const WORKER_GROUP: String = "workers"

# Stats — overridden from JSON
var _max_hp: int = 18
var _damage: int = 6
var _attack_cooldown: float = 0.9
var _move_time: float = 0.18
var _dig_duration: float = 3.5
var _enemy_color: Color = Color(0.85, 0.25, 0.25, 1.0)
var _config_path: String = ""
var _enemy_kind: String = "spider"

# State
var _hp: int = 18
var _attack_cooldown_remaining: float = 0.0
var _is_moving: bool = false
var _is_digging: bool = false
var _move_tween: Tween
var _think_cooldown: float = 0.0

# World
var _tile_map: TileMapLayer = null
var _sid_tunnel: int = -1
var _sid_queen: int = -1
var _sid_dirt: int = -1
var _sid_stone: int = -1
var _world_w: int = 60
var _world_h: int = 40
var _surface_row: int = 5
var _tile_pos: Vector2i = Vector2i.ZERO
var _queen_tile: Vector2i = Vector2i.ZERO

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _hp_bar_bg: ColorRect = $HpBarBg
@onready var _hp_bar_fill: ColorRect = $HpBarFill


func _ready() -> void:
	add_to_group(ENEMY_GROUP)
	if _sprite != null:
		_sprite.texture = AssetLoader.get_enemy_sprite(_enemy_kind)
		_sprite.modulate = _enemy_color
		_fit_sprite_to_tile()


func setup(
		tile_map: TileMapLayer,
		sid_tunnel: int,
		sid_queen: int,
		sid_dirt: int,
		sid_stone: int,
		start_tile: Vector2i,
		queen_tile: Vector2i,
		world_w: int,
		world_h: int,
		surface_row: int) -> void:
	_tile_map = tile_map
	_sid_tunnel = sid_tunnel
	_sid_queen = sid_queen
	_sid_dirt = sid_dirt
	_sid_stone = sid_stone
	_tile_pos = start_tile
	_queen_tile = queen_tile
	_world_w = world_w
	_world_h = world_h
	_surface_row = surface_row
	position = _tile_to_world(start_tile)
	_load_config()
	_hp = _max_hp
	if _sprite != null:
		_sprite.modulate = _enemy_color
		_fit_sprite_to_tile()
	_update_hp_bar()


func _load_config() -> void:
	if _config_path == "" or not FileAccess.file_exists(_config_path):
		return
	var file := FileAccess.open(_config_path, FileAccess.READ)
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
	_dig_duration = float(data.get("dig_duration", _dig_duration))
	if "color" in data:
		var c = data["color"]
		if c is Array and c.size() >= 4:
			_enemy_color = Color(float(c[0]), float(c[1]), float(c[2]), float(c[3]))


func _fit_sprite_to_tile() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var tex_size := _sprite.texture.get_size()
	var largest_axis: float = maxf(tex_size.x, tex_size.y)
	if largest_axis <= 0.0:
		return
	var fit_scale: float = float(TILE_SIZE - 2) / largest_axis
	_sprite.scale = Vector2(fit_scale, fit_scale)


func _process(delta: float) -> void:
	if _attack_cooldown_remaining > 0.0:
		_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	if _think_cooldown > 0.0:
		_think_cooldown = maxf(0.0, _think_cooldown - delta)
	_update_state(delta)


func _update_state(_delta: float) -> void:
	if not is_instance_valid(_tile_map):
		return
	# Priority 1: attack adjacent soldier first.
	var adjacent_soldier: Node2D = _find_adjacent_soldier()
	if adjacent_soldier != null:
		_attack_target_if_ready(adjacent_soldier)
		return
	if _is_adjacent_to_queen():
		_attack_queen_if_ready()
		return
	# Priority 2: damage any adjacent built room (nursery, food storage, etc.).
	var damaged_room_tile: Vector2i = _find_adjacent_damageable_room()
	if damaged_room_tile != Vector2i(-1, -1):
		_attack_room_if_ready(damaged_room_tile)
		return
	# Priority 3: move closer to queen via straight-line greedy step.
	if _is_moving:
		return
	if _think_cooldown > 0.0:
		return
	_take_step_toward_queen()


func _find_adjacent_damageable_room() -> Vector2i:
	for dir in DIRS:
		var n: Vector2i = _tile_pos + dir
		var room: Dictionary = GameManager.room_manager.get_room_at(n)
		if not room.is_empty() and String(room.get("type", "")) != "queen_chamber":
			return n
	return Vector2i(-1, -1)


func _attack_room_if_ready(room_tile: Vector2i) -> void:
	if _attack_cooldown_remaining > 0.0:
		return
	GameManager.room_manager.damage_room_at(room_tile, _damage)
	_attack_cooldown_remaining = _attack_cooldown


func _take_step_toward_queen() -> void:
	# Order of preference, queen-direction first:
	#   1. Walk queen-direction if traversable.
	#   2. Dig queen-direction if it's dirt.
	#   3. Walk sideways toward queen (perpendicular axis).
	#   4. Dig sideways through dirt.
	#   5. Walk any remaining direction (don't get stuck).
	# This prevents enemies from wandering sky/tunnels horizontally while
	# the queen is one dirt tile away below them.
	var primary: Array = _queen_direction_steps()

	# 1 & 2: prioritized queen-direction steps — walk first, then dig.
	for step in primary:
		var n: Vector2i = _tile_pos + step
		if _is_traversable(n):
			_move_into(n)
			return
		if _is_dirt(n):
			_start_digging(n)
			return

	# 3: sideways walk (any direction not in primary).
	for step in DIRS:
		if step in primary:
			continue
		var n: Vector2i = _tile_pos + step
		if _is_traversable(n):
			_move_into(n)
			return

	# 4: sideways dig.
	for step in DIRS:
		if step in primary:
			continue
		var n: Vector2i = _tile_pos + step
		if _is_dirt(n):
			_start_digging(n)
			return

	# 5: surrounded by stone / world edge — wait briefly and re-think.
	_think_cooldown = 0.6


func _queen_direction_steps() -> Array:
	# Returns the up-to-2 directional steps that point toward the queen,
	# longer-axis first (e.g. queen far below and slightly right → [(0,1), (1,0)]).
	var dx: int = sign(_queen_tile.x - _tile_pos.x)
	var dy: int = sign(_queen_tile.y - _tile_pos.y)
	var steps: Array = []
	if abs(_queen_tile.x - _tile_pos.x) >= abs(_queen_tile.y - _tile_pos.y):
		if dx != 0:
			steps.append(Vector2i(dx, 0))
		if dy != 0:
			steps.append(Vector2i(0, dy))
	else:
		if dy != 0:
			steps.append(Vector2i(0, dy))
		if dx != 0:
			steps.append(Vector2i(dx, 0))
	return steps


func _move_into(next_tile: Vector2i) -> void:
	_is_moving = true
	_tile_pos = next_tile
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", _tile_to_world(next_tile), _move_time)
	_move_tween.tween_callback(_on_step_done)


func _start_digging(target: Vector2i) -> void:
	_is_digging = true
	_think_cooldown = _dig_duration
	# After dig_duration, convert dirt → tunnel and step into it.
	get_tree().create_timer(_dig_duration).timeout.connect(func():
		if not is_instance_valid(self) or not is_instance_valid(_tile_map):
			return
		# Re-validate: tile may have been changed by a worker in the meantime.
		if not _is_dirt(target):
			_is_digging = false
			return
		_tile_map.set_cell(target, _sid_tunnel, Vector2i(0, 0))
		_is_digging = false
		# Move into the freshly-dug tile next think-tick.
	)


func _is_dirt(pos: Vector2i) -> bool:
	if not _is_in_bounds(pos):
		return false
	if pos.y < _surface_row:
		return false  # Sky is not dirt.
	return _tile_map.get_cell_source_id(pos) == _sid_dirt


func _is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < _world_w and pos.y >= 0 and pos.y < _world_h


func _on_step_done() -> void:
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
	if is_instance_valid(_move_tween):
		_move_tween.kill()
	queue_free()


func _attack_target_if_ready(target: Node2D) -> void:
	if _attack_cooldown_remaining > 0.0:
		return
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("take_damage"):
		target.take_damage(_damage)
		_attack_cooldown_remaining = _attack_cooldown


func _attack_queen_if_ready() -> void:
	if _attack_cooldown_remaining > 0.0:
		return
	GameManager.damage_queen(_damage)
	_attack_cooldown_remaining = _attack_cooldown


func _find_adjacent_soldier() -> Node2D:
	var soldiers: Array = get_tree().get_nodes_in_group(SOLDIER_GROUP)
	for s in soldiers:
		if not is_instance_valid(s):
			continue
		var st: Vector2i = _world_to_tile(s.global_position)
		if _manhattan(_tile_pos, st) == 1:
			return s
	return null


func _is_adjacent_to_queen() -> bool:
	# Adjacent if any neighbor is a queen-chamber tile.
	for dir in DIRS:
		var n: Vector2i = _tile_pos + dir
		if n.x < 0 or n.x >= _world_w or n.y < 0 or n.y >= _world_h:
			continue
		if _tile_map.get_cell_source_id(n) == _sid_queen:
			return true
	return false


# ── HP bar ────────────────────────────────────────────────────────────────────

func _update_hp_bar() -> void:
	if _hp_bar_bg == null or _hp_bar_fill == null:
		return
	var ratio: float = 0.0 if _max_hp <= 0 else clampf(float(_hp) / float(_max_hp), 0.0, 1.0)
	_hp_bar_fill.size.x = _hp_bar_bg.size.x * ratio


# ── Utility ───────────────────────────────────────────────────────────────────

func _is_traversable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= _world_w or pos.y < 0 or pos.y >= _world_h:
		return false
	if pos.y < _surface_row:
		return true
	var src_id := _tile_map.get_cell_source_id(pos)
	# Enemies walk through tunnel tiles (and cross queen-chamber edge to attack queen).
	return src_id == _sid_tunnel or src_id == _sid_queen


func _tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE_SIZE + TILE_SIZE / 2.0, tile.y * TILE_SIZE + TILE_SIZE / 2.0)


func _world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE))


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
