extends Node
class_name UpgradeManager

# Upgrade Manager — single source of truth for all colony-wide upgrades.
#
# Levels are stored as integers; effects are looked up via getters that other
# systems call (worker_ant for dig_duration, room_manager for hatch_interval, etc.).
# Effects multiply or replace base values — see _apply_modifier().

signal upgrade_purchased(upgrade_id: String, new_level: int)
signal upgrade_changed(upgrade_id: String, new_level: int)

const CONFIG_PATH: String = "res://data/upgrades/upgrades_config.json"

var _configs: Dictionary = {}
var _levels: Dictionary = {}  # upgrade_id -> int


func _ready() -> void:
	_load_configs()


func _load_configs() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null or not (data is Dictionary):
		return
	_configs = data
	for upgrade_id in _configs.keys():
		_levels[upgrade_id] = 0


func get_upgrade_ids() -> Array:
	return _configs.keys()


func get_config(upgrade_id: String) -> Dictionary:
	return _configs.get(upgrade_id, {})


func get_level(upgrade_id: String) -> int:
	return int(_levels.get(upgrade_id, 0))


func get_max_level(upgrade_id: String) -> int:
	return int(_configs.get(upgrade_id, {}).get("max_level", 0))


func is_maxed(upgrade_id: String) -> bool:
	return get_level(upgrade_id) >= get_max_level(upgrade_id)


func get_next_cost(upgrade_id: String) -> int:
	if is_maxed(upgrade_id):
		return -1
	var config: Dictionary = _configs.get(upgrade_id, {})
	var costs = config.get("cost_per_level", [])
	var level: int = get_level(upgrade_id)
	if level >= costs.size():
		return -1
	return int(costs[level])


func can_purchase(upgrade_id: String) -> bool:
	if is_maxed(upgrade_id):
		return false
	var cost: int = get_next_cost(upgrade_id)
	if cost < 0:
		return false
	return GameManager.colony.food >= cost


func purchase(upgrade_id: String) -> bool:
	if not can_purchase(upgrade_id):
		return false
	var cost: int = get_next_cost(upgrade_id)
	if not GameManager.spend_food(cost):
		return false
	_levels[upgrade_id] = get_level(upgrade_id) + 1
	upgrade_purchased.emit(upgrade_id, _levels[upgrade_id])
	upgrade_changed.emit(upgrade_id, _levels[upgrade_id])
	# When ant_limit changes, push the new cap into colony immediately.
	if upgrade_id == "ant_limit":
		GameManager.colony.max_workers = get_max_workers_value()
		GameManager.worker_count_changed.emit(GameManager.colony.worker_count, GameManager.colony.max_workers)
	return true


# ── Effect lookups (called by other systems) ───────────────────────────────────

func get_dig_duration_multiplier() -> float:
	return _multiplier_at_level("dig_speed")


func get_food_per_gather() -> int:
	return _value_at_level_int("carry_capacity", 1)


func get_max_workers_value() -> int:
	return _value_at_level_int("ant_limit", 20)


func get_hatch_interval_multiplier() -> float:
	return _multiplier_at_level("faster_hatch")


func get_soldier_damage_multiplier() -> float:
	return _multiplier_at_level("soldier_damage")


# ── Internals ─────────────────────────────────────────────────────────────────

func _multiplier_at_level(upgrade_id: String, default_value: float = 1.0) -> float:
	var config: Dictionary = _configs.get(upgrade_id, {})
	var multipliers = config.get("multiplier_per_level", [])
	var level: int = get_level(upgrade_id)
	if level < multipliers.size():
		return float(multipliers[level])
	return default_value


func _value_at_level_int(upgrade_id: String, default_value: int) -> int:
	var config: Dictionary = _configs.get(upgrade_id, {})
	var values = config.get("multiplier_per_level", [])
	var level: int = get_level(upgrade_id)
	if level < values.size():
		return int(values[level])
	return default_value
