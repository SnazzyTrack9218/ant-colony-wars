extends Node
class_name PheromoneMap

# Tracks how often workers traverse each tile. Frequently-walked tiles get a
# small movement-speed bonus, encouraging emergent highways through the
# tunnel network. Decays over time so abandoned paths fade.

signal trail_decayed()

const TICK_INTERVAL: float = 1.5
const DECAY_PER_TICK: float = 0.93   # ~50% in ~10s
const PRUNE_THRESHOLD: float = 0.10
const DEPOSIT_PER_STEP: float = 1.0
const MAX_LEVEL: float = 30.0
const FULL_BONUS_LEVEL: float = 18.0  # tiles at/above this run at the max bonus
const MAX_SPEED_MULTIPLIER: float = 0.70  # i.e. up to 30% faster

var _level: Dictionary = {}  # Vector2i -> float
var _accumulator: float = 0.0


func _process(delta: float) -> void:
	_accumulator += delta
	if _accumulator < TICK_INTERVAL:
		return
	_accumulator = 0.0
	_decay()


func deposit(tile: Vector2i) -> void:
	var current: float = float(_level.get(tile, 0.0))
	_level[tile] = minf(MAX_LEVEL, current + DEPOSIT_PER_STEP)


func get_speed_multiplier(tile: Vector2i) -> float:
	# 1.0 = base speed; lower = faster (multiplier on move_time).
	var lvl: float = float(_level.get(tile, 0.0))
	if lvl <= 0.0:
		return 1.0
	var t: float = clampf(lvl / FULL_BONUS_LEVEL, 0.0, 1.0)
	return lerp(1.0, MAX_SPEED_MULTIPLIER, t)


func get_level(tile: Vector2i) -> float:
	return float(_level.get(tile, 0.0))


func _decay() -> void:
	var to_prune: Array = []
	for tile in _level.keys():
		_level[tile] = float(_level[tile]) * DECAY_PER_TICK
		if float(_level[tile]) < PRUNE_THRESHOLD:
			to_prune.append(tile)
	for tile in to_prune:
		_level.erase(tile)
	trail_decayed.emit()
