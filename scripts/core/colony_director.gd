extends Node
class_name ColonyDirector

# Autonomous colony brain. Periodically:
# - places room blueprints adjacent to known tunnel space when below targets
# - purchases the next available upgrade when food exceeds the reserve floor
#
# Player can still place markers / buy upgrades manually — the director only
# acts on idle time.
#
# Configured by data/colony/autopilot_config.json. Disable by setting "enabled": false.

const CONFIG_PATH: String = "res://data/colony/autopilot_config.json"
const DIRS: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var enabled: bool = true
var _tick_interval: float = 4.0
var _build_targets: Array = []
var _build_order: Array = []
var _upgrade_food_reserve: int = 30
var _upgrade_priority: Array = []
var _accumulator: float = 0.0

var _tile_map: TileMapLayer = null
var _sid_tunnel: int = -1
var _world_w: int = 0
var _world_h: int = 0
var _queen_tile: Vector2i = Vector2i.ZERO


func _ready() -> void:
	_load_config()


func configure(
		tile_map: TileMapLayer,
		sid_tunnel: int,
		queen_tile: Vector2i,
		world_w: int,
		world_h: int) -> void:
	_tile_map = tile_map
	_sid_tunnel = sid_tunnel
	_queen_tile = queen_tile
	_world_w = world_w
	_world_h = world_h


func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null or not (data is Dictionary):
		return
	enabled = bool(data.get("enabled", true))
	_tick_interval = float(data.get("tick_interval", _tick_interval))
	_build_targets = data.get("build_targets", [])
	_build_order = data.get("build_order", [])
	_upgrade_food_reserve = int(data.get("upgrade_food_reserve", _upgrade_food_reserve))
	_upgrade_priority = data.get("auto_upgrade_priority", [])


func _process(delta: float) -> void:
	if not enabled or _tile_map == null:
		return
	_accumulator += delta
	if _accumulator < _tick_interval:
		return
	_accumulator = 0.0
	_tick_autopilot()


func _tick_autopilot() -> void:
	_try_auto_build()
	_try_auto_upgrade()


# ── Auto-build ─────────────────────────────────────────────────────────────────

func _try_auto_build() -> void:
	# Walk build_order; first under-target room with affordable cost gets queued.
	for room_type in _build_order:
		var target: Dictionary = _find_target_config(String(room_type))
		if target.is_empty():
			continue
		var max_count: int = int(target.get("max_count", 1))
		var food_floor: int = int(target.get("food_floor", 0))
		if _count_room(String(room_type)) >= max_count:
			continue
		if _count_pending_plans(String(room_type)) > 0:
			continue
		if GameManager.colony.food < food_floor:
			continue
		var tile: Vector2i = _find_buildable_tunnel_tile()
		if tile == Vector2i(-1, -1):
			continue
		GameManager.room_manager.create_room_plan(String(room_type), tile)
		return  # one build per tick keeps the queue manageable


func _find_target_config(room_type: String) -> Dictionary:
	for entry in _build_targets:
		if String(entry.get("room_type", "")) == room_type:
			return entry
	return {}


func _count_room(room_type: String) -> int:
	var count: int = 0
	for room_id in GameManager.room_manager._rooms:
		var room: Dictionary = GameManager.room_manager._rooms[room_id]
		if String(room.get("type", "")) == room_type:
			count += 1
	return count


func _count_pending_plans(room_type: String) -> int:
	var count: int = 0
	for plan_id in GameManager.room_manager._plans:
		var plan: Dictionary = GameManager.room_manager._plans[plan_id]
		if String(plan.get("type", "")) == room_type:
			count += 1
	return count


func _find_buildable_tunnel_tile() -> Vector2i:
	# BFS outward from the starting hall (one tile above queen) through tunnel
	# tiles; first unoccupied tunnel wins.
	var start: Vector2i = _queen_tile + Vector2i(0, -1)
	if not _tile_is_tunnel(start):
		# Fall back: scan a small box around queen for any tunnel tile.
		for dy in range(-3, 1):
			for dx in range(-5, 6):
				var c: Vector2i = _queen_tile + Vector2i(dx, dy)
				if _tile_is_tunnel(c):
					start = c
					break
			if _tile_is_tunnel(start):
				break
	if not _tile_is_tunnel(start):
		return Vector2i(-1, -1)
	var queue: Array = [start]
	var visited: Dictionary = {start: true}
	var room_manager: RoomManager = GameManager.room_manager
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if not _is_occupied(current, room_manager):
			return current
		for dir in DIRS:
			var n: Vector2i = current + dir
			if n in visited:
				continue
			if not _tile_is_tunnel(n):
				continue
			visited[n] = true
			queue.append(n)
	return Vector2i(-1, -1)


func _tile_is_tunnel(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= _world_w or pos.y < 0 or pos.y >= _world_h:
		return false
	return _tile_map.get_cell_source_id(pos) == _sid_tunnel


func _is_occupied(pos: Vector2i, room_manager: RoomManager) -> bool:
	# Tile already has a room plan or completed room.
	for plan_id in room_manager._plans:
		var plan: Dictionary = room_manager._plans[plan_id]
		if Vector2i(plan.get("tile_pos", Vector2i.ZERO)) == pos:
			return true
	for room_id in room_manager._rooms:
		var room: Dictionary = room_manager._rooms[room_id]
		if Vector2i(room.get("tile_pos", Vector2i.ZERO)) == pos:
			return true
	return false


# ── Auto-upgrade ───────────────────────────────────────────────────────────────

func _try_auto_upgrade() -> void:
	if GameManager.upgrades == null:
		return
	# Only spend food beyond the reserve so the colony doesn't starve hatching.
	if GameManager.colony.food < _upgrade_food_reserve:
		return
	for upgrade_id in _upgrade_priority:
		var id: String = String(upgrade_id)
		if GameManager.upgrades.is_maxed(id):
			continue
		var cost: int = GameManager.upgrades.get_next_cost(id)
		if cost < 0:
			continue
		if GameManager.colony.food - cost < _upgrade_food_reserve:
			continue
		if GameManager.upgrades.purchase(id):
			return  # one purchase per tick
