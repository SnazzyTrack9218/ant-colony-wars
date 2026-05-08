extends RefCounted
class_name WorldGenerator

const CONFIG_PATH: String = "res://data/world/world_generation_config.json"
const TILE_DIRT: String = "dirt"
const TILE_STONE: String = "stone"
const TILE_TUNNEL: String = "tunnel"
const TILE_QUEEN: String = "queen"
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

var _config: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func generate(
		world_w: int,
		world_h: int,
		surface_row: int,
		queen_col: int,
		queen_row: int) -> Dictionary:
	_load_config()
	_rng.seed = int(_config.get("world_seed", 12345))

	var tile_types: Dictionary = {}
	for y in range(surface_row, world_h):
		for x in range(world_w):
			tile_types[Vector2i(x, y)] = TILE_DIRT

	_add_stone_veins(tile_types, world_w, world_h, surface_row, queen_col, queen_row)
	_add_cave_pockets(tile_types, world_w, world_h, surface_row, queen_col, queen_row)

	var protected_tiles: Array = []
	_carve_starting_colony(tile_types, protected_tiles, world_w, surface_row, queen_col, queen_row)

	var food_positions: Array = _generate_food_positions(tile_types, world_w, world_h, surface_row, queen_col, queen_row)
	return _build_result(tile_types, protected_tiles, food_positions, world_w, world_h, surface_row, queen_col, queen_row)


func _load_config() -> void:
	_config = {
		"world_seed": 12345,
		"stone_vein_count": 18,
		"stone_vein_min_length": 5,
		"stone_vein_max_length": 18,
		"cave_pocket_count": 10,
		"cave_pocket_min_radius": 2,
		"cave_pocket_max_radius": 5,
		"queen_safe_radius": 8,
		"starting_surface_shaft": false,
		"starting_hall_half_width": 5,
		"food_source_min_count": 5,
		"food_source_max_count": 12,
		"food_min_depth": 8,
		"food_max_depth_padding": 8,
		"food_min_horizontal_distance": 10,
		"food_max_horizontal_distance": 34,
		"food_dirt_padding_radius": 1
	}
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return
	for key in data:
		_config[key] = data[key]


func _add_stone_veins(
		tile_types: Dictionary,
		world_w: int,
		world_h: int,
		surface_row: int,
		queen_col: int,
		queen_row: int) -> void:
	var vein_count: int = int(_config.get("stone_vein_count", 18))
	var min_length: int = int(_config.get("stone_vein_min_length", 5))
	var max_length: int = int(_config.get("stone_vein_max_length", 18))
	for _i in range(vein_count):
		var pos: Vector2i = Vector2i(
				_rng.randi_range(0, world_w - 1),
				_rng.randi_range(surface_row + 2, world_h - 1))
		var vein_length: int = _rng.randi_range(min_length, max_length)
		for _step in range(vein_length):
			if _can_place_terrain_feature(pos, world_w, world_h, surface_row, queen_col, queen_row):
				tile_types[pos] = TILE_STONE
			var dir: Vector2i = DIRS[_rng.randi_range(0, DIRS.size() - 1)]
			pos = _clamp_world(pos + dir, world_w, world_h, surface_row)


func _add_cave_pockets(
		tile_types: Dictionary,
		world_w: int,
		world_h: int,
		surface_row: int,
		queen_col: int,
		queen_row: int) -> void:
	var pocket_count: int = int(_config.get("cave_pocket_count", 10))
	var min_radius: int = int(_config.get("cave_pocket_min_radius", 2))
	var max_radius: int = int(_config.get("cave_pocket_max_radius", 5))
	for _i in range(pocket_count):
		var center: Vector2i = Vector2i(
				_rng.randi_range(0, world_w - 1),
				_rng.randi_range(surface_row + 4, world_h - 1))
		var radius: int = _rng.randi_range(min_radius, max_radius)
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				var pos: Vector2i = Vector2i(x, y)
				if not _can_place_terrain_feature(pos, world_w, world_h, surface_row, queen_col, queen_row):
					continue
				var delta: Vector2 = Vector2(pos.x - center.x, pos.y - center.y)
				var dist: float = delta.length()
				if dist <= float(radius) + _rng.randf_range(-0.35, 0.35):
					tile_types[pos] = TILE_TUNNEL


func _carve_starting_colony(
		tile_types: Dictionary,
		protected_tiles: Array,
		world_w: int,
		surface_row: int,
		queen_col: int,
		queen_row: int) -> void:
	if bool(_config.get("starting_surface_shaft", false)):
		for y in range(surface_row, queen_row):
			tile_types[Vector2i(queen_col, y)] = TILE_TUNNEL

	var hall_half_width: int = maxi(1, int(_config.get("starting_hall_half_width", 5)))
	for x in range(maxi(0, queen_col - hall_half_width), mini(world_w, queen_col + hall_half_width + 1)):
		tile_types[Vector2i(x, queen_row - 1)] = TILE_TUNNEL

	for dy in range(3):
		for dx in range(3):
			var pos: Vector2i = Vector2i(queen_col - 1 + dx, queen_row + dy)
			tile_types[pos] = TILE_QUEEN
			protected_tiles.append(pos)


func _generate_food_positions(
		tile_types: Dictionary,
		world_w: int,
		world_h: int,
		surface_row: int,
		queen_col: int,
		queen_row: int) -> Array:
	var food_positions: Array = []
	var min_food_count: int = int(_config.get("food_source_min_count", 5))
	var max_food_count: int = int(_config.get("food_source_max_count", 12))
	var food_count: int = _rng.randi_range(min_food_count, maxi(min_food_count, max_food_count))
	var min_depth: int = int(_config.get("food_min_depth", 8))
	var max_depth_padding: int = int(_config.get("food_max_depth_padding", 8))
	var min_horizontal_distance: int = int(_config.get("food_min_horizontal_distance", 10))
	var max_horizontal_distance: int = int(_config.get("food_max_horizontal_distance", 34))
	var min_y: int = clampi(surface_row + min_depth, surface_row + 1, world_h - 2)
	var max_y: int = clampi(queen_row - max_depth_padding, min_y, world_h - 2)
	var attempts: int = 0
	while food_positions.size() < food_count and attempts < food_count * 80:
		attempts += 1
		var side: int = -1 if attempts % 2 == 0 else 1
		if _rng.randf() < 0.5:
			side *= -1
		var horizontal_distance: int = _rng.randi_range(
				min_horizontal_distance,
				maxi(min_horizontal_distance, max_horizontal_distance))
		var food_pos: Vector2i = Vector2i(
				queen_col + side * horizontal_distance,
				_rng.randi_range(min_y, max_y))
		if food_pos.x < 1 or food_pos.x >= world_w - 1:
			continue
		if food_pos in food_positions:
			continue
		_bury_food_source(tile_types, food_pos, world_w, world_h, surface_row)
		food_positions.append(food_pos)
	if food_positions.size() < food_count:
		_add_fallback_food_positions(
				tile_types,
				food_positions,
				food_count,
				world_w,
				world_h,
				surface_row,
				queen_col,
				min_y,
				min_horizontal_distance)
	return food_positions


func _add_fallback_food_positions(
		tile_types: Dictionary,
		food_positions: Array,
		food_count: int,
		world_w: int,
		world_h: int,
		surface_row: int,
		queen_col: int,
		food_y: int,
		min_horizontal_distance: int) -> void:
	var candidates: Array = []
	for i in range(food_count * 2):
		var fallback_side: int = -1 if i % 2 == 0 else 1
		var branch_index: int = int(floor(float(i) * 0.5))
		var horizontal_distance: int = min_horizontal_distance + branch_index * 4
		var food_x: int = queen_col + fallback_side * horizontal_distance
		if food_x <= 0 or food_x >= world_w - 1:
			continue
		candidates.append(Vector2i(food_x, food_y + (i % 3) - 1))
	for candidate in candidates:
		if food_positions.size() >= food_count:
			return
		var candidate_pos: Vector2i = Vector2i(candidate)
		if candidate_pos in food_positions:
			continue
		_bury_food_source(tile_types, candidate_pos, world_w, world_h, surface_row)
		food_positions.append(candidate_pos)


func _bury_food_source(
		tile_types: Dictionary,
		food_pos: Vector2i,
		world_w: int,
		world_h: int,
		surface_row: int) -> void:
	var padding_radius: int = maxi(0, int(_config.get("food_dirt_padding_radius", 1)))
	for y in range(maxi(surface_row, food_pos.y - padding_radius), mini(world_h, food_pos.y + padding_radius + 1)):
		for x in range(maxi(0, food_pos.x - padding_radius), mini(world_w, food_pos.x + padding_radius + 1)):
			tile_types[Vector2i(x, y)] = TILE_DIRT


func _build_result(
		tile_types: Dictionary,
		protected_tiles: Array,
		food_positions: Array,
		world_w: int,
		world_h: int,
		surface_row: int,
		queen_col: int,
		queen_row: int) -> Dictionary:
	var dirt_tiles: Array = []
	var stone_tiles: Array = []
	var tunnel_tiles: Array = []
	var queen_tiles: Array = []
	for pos in tile_types:
		match tile_types[pos]:
			TILE_DIRT:
				dirt_tiles.append(pos)
			TILE_STONE:
				stone_tiles.append(pos)
			TILE_TUNNEL:
				tunnel_tiles.append(pos)
			TILE_QUEEN:
				queen_tiles.append(pos)
	return {
		"world_width": world_w,
		"world_height": world_h,
		"surface_row": surface_row,
		"queen_col": queen_col,
		"queen_row": queen_row,
		"dirt_tiles": dirt_tiles,
		"stone_tiles": stone_tiles,
		"tunnel_tiles": tunnel_tiles,
		"queen_tiles": queen_tiles,
		"protected_tiles": protected_tiles,
		"food_positions": food_positions
	}


func _can_place_terrain_feature(
		pos: Vector2i,
		world_w: int,
		world_h: int,
		surface_row: int,
		queen_col: int,
		queen_row: int) -> bool:
	if pos.x < 0 or pos.x >= world_w or pos.y < surface_row or pos.y >= world_h:
		return false
	var safe_radius: int = int(_config.get("queen_safe_radius", 8))
	var queen_center: Vector2i = Vector2i(queen_col, queen_row + 1)
	return abs(pos.x - queen_center.x) + abs(pos.y - queen_center.y) > safe_radius


func _clamp_world(pos: Vector2i, world_w: int, world_h: int, surface_row: int) -> Vector2i:
	return Vector2i(
			clampi(pos.x, 0, world_w - 1),
			clampi(pos.y, surface_row, world_h - 1))
