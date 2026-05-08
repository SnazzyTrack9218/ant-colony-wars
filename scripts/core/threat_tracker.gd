extends Node
class_name ThreatTracker

# Tracks where enemies have been recently. Each tile accumulates "heat" when an
# enemy stands on it; heat decays over time so old positions fade out.
#
# Used by the colony director for:
#   - smart guard-post placement (cluster at choke points enemies actually use)
#   - reactive auto-rally (place a rally at the closest active threat to the queen)

const TILE_SIZE: int = 16
const TICK_INTERVAL: float = 1.0
const HEAT_PER_VISIT: float = 1.0
const DECAY_PER_TICK: float = 0.90  # 10% decay each second; ~0.05 after ~30s
const PRUNE_THRESHOLD: float = 0.05

var _heat: Dictionary = {}  # Vector2i -> float
var _accumulator: float = 0.0


func _process(delta: float) -> void:
	_accumulator += delta
	if _accumulator < TICK_INTERVAL:
		return
	_accumulator = 0.0
	_decay()
	_record_active_enemies()


func _decay() -> void:
	var to_prune: Array = []
	for tile in _heat.keys():
		_heat[tile] = float(_heat[tile]) * DECAY_PER_TICK
		if float(_heat[tile]) < PRUNE_THRESHOLD:
			to_prune.append(tile)
	for tile in to_prune:
		_heat.erase(tile)


func _record_active_enemies() -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var et: Vector2i = _world_to_tile(e.global_position)
		_heat[et] = float(_heat.get(et, 0.0)) + HEAT_PER_VISIT


func get_heat_at(tile: Vector2i) -> float:
	return float(_heat.get(tile, 0.0))


func get_heat_around(center: Vector2i, radius: int) -> float:
	var total: float = 0.0
	for tile in _heat:
		var dist: int = abs(tile.x - center.x) + abs(tile.y - center.y)
		if dist <= radius:
			total += float(_heat[tile])
	return total


func get_hottest_tile() -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_heat: float = 0.0
	for tile in _heat:
		var h: float = float(_heat[tile])
		if h > best_heat:
			best_heat = h
			best = tile
	return best


func count_active_enemies_near(target: Vector2i, radius: int) -> int:
	var count: int = 0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var et: Vector2i = _world_to_tile(e.global_position)
		var dist: int = abs(et.x - target.x) + abs(et.y - target.y)
		if dist <= radius:
			count += 1
	return count


func get_closest_enemy_tile_to(target: Vector2i) -> Vector2i:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var best: Vector2i = Vector2i(-1, -1)
	var best_dist: int = 100000
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var et: Vector2i = _world_to_tile(e.global_position)
		var dist: int = abs(et.x - target.x) + abs(et.y - target.y)
		if dist < best_dist:
			best_dist = dist
			best = et
	return best


func _world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE))
