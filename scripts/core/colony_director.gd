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
var _auto_rally_enabled: bool = true
var _auto_rally_threat_radius: int = 14
var _auto_rally_min_relocate_dist: int = 4
var _accumulator: float = 0.0
var _auto_rally_tile: Vector2i = Vector2i(-1, -1)

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
	_auto_rally_enabled = bool(data.get("auto_rally_enabled", _auto_rally_enabled))
	_auto_rally_threat_radius = int(data.get("auto_rally_threat_radius", _auto_rally_threat_radius))
	_auto_rally_min_relocate_dist = int(data.get("auto_rally_min_relocate_dist", _auto_rally_min_relocate_dist))


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
	_try_auto_rally()


# ── Auto-build ─────────────────────────────────────────────────────────────────

func _try_auto_build() -> void:
	# Walk build_order; first under-target room with affordable cost gets queued.
	for room_type in _build_order:
		var target: Dictionary = _find_target_config(String(room_type))
		if target.is_empty():
			continue
		var max_count: int = int(target.get("max_count", 1))
		var food_floor: int = int(target.get("food_floor", 0))
		var room_type_str: String = String(room_type)
		if _count_room(room_type_str) >= max_count:
			continue
		if _count_pending_plans(room_type_str) > 0:
			continue
		if GameManager.colony.food < food_floor:
			continue
		var tile: Vector2i
		if room_type_str == "guard_post":
			tile = _find_guard_post_tile()
		else:
			tile = _find_buildable_tunnel_tile()
		if tile == Vector2i(-1, -1):
			continue
		GameManager.room_manager.create_room_plan(room_type_str, tile)
		return  # one build per tick keeps the queue manageable


func _find_guard_post_tile() -> Vector2i:
	# Smart placement: prefer hot tunnel tiles (where enemies have been seen).
	# Falls back to a tile adjacent to the queen choke when no threats exist.
	var room_manager: RoomManager = GameManager.room_manager
	var threat: ThreatTracker = GameManager.threat
	var candidates: Array = _enumerate_unoccupied_tunnels(room_manager)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	# If there's threat heat, score by heat near each candidate.
	if threat != null:
		var best: Vector2i = candidates[0]
		var best_score: float = -INF
		for tile in candidates:
			var heat: float = threat.get_heat_around(tile, 3)
			# Slight preference for tiles closer to queen so guards aren't stranded.
			var dist: int = abs(tile.x - _queen_tile.x) + abs(tile.y - _queen_tile.y)
			var score: float = heat * 10.0 - float(dist) * 0.2
			if score > best_score:
				best_score = score
				best = tile
		# Only use threat-driven placement if any heat was found.
		if best_score > 0.0:
			return best
	# No threats yet — put the first guard right on the queen's choke.
	var anchor: Vector2i = _queen_tile + Vector2i(0, -1)
	var nearest: Vector2i = candidates[0]
	var nearest_dist: int = 100000
	for tile in candidates:
		var dist: int = abs(tile.x - anchor.x) + abs(tile.y - anchor.y)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = tile
	return nearest


func _enumerate_unoccupied_tunnels(room_manager: RoomManager) -> Array:
	# BFS from the starting hall through tunnels; collect every unoccupied tile.
	var start: Vector2i = _queen_tile + Vector2i(0, -1)
	if not _tile_is_tunnel(start):
		for dy in range(-3, 1):
			for dx in range(-5, 6):
				var c: Vector2i = _queen_tile + Vector2i(dx, dy)
				if _tile_is_tunnel(c):
					start = c
					break
			if _tile_is_tunnel(start):
				break
	if not _tile_is_tunnel(start):
		return []
	var queue: Array = [start]
	var visited: Dictionary = {start: true}
	var out: Array = []
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if not _is_occupied(current, room_manager):
			out.append(current)
		for dir in DIRS:
			var n: Vector2i = current + dir
			if n in visited:
				continue
			if not _tile_is_tunnel(n):
				continue
			visited[n] = true
			queue.append(n)
	return out


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
	# Smarter placement: BFS through tunnel tiles, score every candidate, pick
	# the best one. Scoring prefers:
	# - close-ish to queen (but not adjacent — leave the choke point clear)
	# - tiles with at least 2 tunnel neighbors (so we don't dead-end a corridor)
	# - tiles not directly between queen and the nearest tunnel-frontier
	var room_manager: RoomManager = GameManager.room_manager
	var start: Vector2i = _queen_tile + Vector2i(0, -1)
	if not _tile_is_tunnel(start):
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

	# BFS to enumerate candidate tunnel tiles within reach.
	var queue: Array = [start]
	var visited: Dictionary = {start: true}
	var candidates: Array = []
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if not _is_occupied(current, room_manager):
			candidates.append(current)
		for dir in DIRS:
			var n: Vector2i = current + dir
			if n in visited:
				continue
			if not _tile_is_tunnel(n):
				continue
			visited[n] = true
			queue.append(n)

	if candidates.is_empty():
		return Vector2i(-1, -1)

	# Score each candidate; lower is better.
	var best: Vector2i = candidates[0]
	var best_score: float = INF
	for tile in candidates:
		var score: float = _score_room_tile(tile)
		if score < best_score:
			best_score = score
			best = tile
	return best


func _score_room_tile(tile: Vector2i) -> float:
	# Lower = better. Distance is the base; the rest are penalties/bonuses.
	var dist_to_queen: int = abs(tile.x - _queen_tile.x) + abs(tile.y - _queen_tile.y)
	var score: float = float(dist_to_queen)
	# Don't fill the queen's choke point — soldiers need to hold there.
	if dist_to_queen <= 2:
		score += 50.0
	# Count tunnel neighbors to figure out tile type.
	var tunnel_neighbors: int = 0
	for dir in DIRS:
		if _tile_is_tunnel(tile + dir):
			tunnel_neighbors += 1
	# Stubs (1 neighbor): great — natural room alcove.
	# Corridors (2 neighbors): bad — would block traffic. Big penalty.
	# Junctions (3+ neighbors): okay — usually have room around them.
	if tunnel_neighbors == 2:
		score += 20.0
	elif tunnel_neighbors >= 3:
		score -= 3.0
	return score


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

func _try_auto_rally() -> void:
	# Reactive defense: when an enemy gets within threat radius of the queen,
	# automatically place a single Rally Marker at the closest defendable tunnel
	# tile near it. Soldiers will converge there. When the threat clears, the
	# auto-rally is removed.
	if not _auto_rally_enabled:
		_clear_auto_rally()
		return
	var threat: ThreatTracker = GameManager.threat
	if threat == null:
		return
	var enemy_count: int = threat.count_active_enemies_near(_queen_tile, _auto_rally_threat_radius)
	if enemy_count == 0:
		_clear_auto_rally()
		return
	# Find an active enemy near the queen.
	var enemy_tile: Vector2i = threat.get_closest_enemy_tile_to(_queen_tile)
	if enemy_tile == Vector2i(-1, -1):
		_clear_auto_rally()
		return
	# Pick a tunnel tile to rally at — prefer the enemy's tile if it's already
	# tunnel (enemy is in our halls); otherwise the nearest tunnel tile to it.
	var rally_tile: Vector2i = _nearest_tunnel_to(enemy_tile)
	if rally_tile == Vector2i(-1, -1):
		# No reachable tunnel — fall back to the choke point.
		rally_tile = _queen_tile + Vector2i(0, -1)
		if not _tile_is_tunnel(rally_tile):
			return
	# Don't churn: if we already auto-rallied close to this tile, leave it alone.
	if _auto_rally_tile != Vector2i(-1, -1):
		var existing_dist: int = abs(_auto_rally_tile.x - rally_tile.x) + abs(_auto_rally_tile.y - rally_tile.y)
		if existing_dist < _auto_rally_min_relocate_dist \
				and GameManager.job_queue.has_job(JobQueue.TYPE_RALLY, _auto_rally_tile):
			return
	# Replace previous auto-rally.
	_clear_auto_rally()
	var job = GameManager.job_queue.add_job(JobQueue.TYPE_RALLY, rally_tile)
	if job != null:
		job.data["auto"] = true
		_auto_rally_tile = rally_tile


func _clear_auto_rally() -> void:
	if _auto_rally_tile == Vector2i(-1, -1):
		return
	# Only cancel the job if it's still the auto-rally we placed.
	for job in GameManager.job_queue._jobs:
		if job.type == JobQueue.TYPE_RALLY and job.tile_pos == _auto_rally_tile \
				and job.data.get("auto", false):
			var job_id: int = job.id
			# Release any soldier holding this rally so they go back to patrol.
			for soldier in get_tree().get_nodes_in_group("soldiers"):
				if soldier.has_method("release_rally_externally") \
						and "_current_rally_job" in soldier \
						and soldier._current_rally_job != null \
						and soldier._current_rally_job.id == job_id:
					soldier.release_rally_externally()
			GameManager.job_queue.cancel_job_at(JobQueue.TYPE_RALLY, _auto_rally_tile)
			break
	_auto_rally_tile = Vector2i(-1, -1)


func _nearest_tunnel_to(tile: Vector2i) -> Vector2i:
	# BFS through any tile up to a small radius to find a tunnel.
	if _tile_is_tunnel(tile):
		return tile
	var queue: Array = [tile]
	var visited: Dictionary = {tile: true}
	var attempts: int = 0
	while not queue.is_empty() and attempts < 80:
		var current: Vector2i = queue.pop_front()
		attempts += 1
		if _tile_is_tunnel(current):
			return current
		for dir in DIRS:
			var n: Vector2i = current + dir
			if n in visited:
				continue
			if n.x < 0 or n.x >= _world_w or n.y < 0 or n.y >= _world_h:
				continue
			visited[n] = true
			queue.append(n)
	return Vector2i(-1, -1)


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
