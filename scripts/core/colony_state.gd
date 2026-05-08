extends Node
class_name ColonyState

signal priority_changed(category: String, level: String)
signal emergency_priority_set(category: String)

const PRIORITY_ORDER: Array[String] = ["low", "normal", "high", "emergency"]

var food: int = 0
var max_food: int = 200
var worker_count: int = 0
var soldier_count: int = 0
var max_workers: int = 20
var queen_hp: int = 100
var queen_max_hp: int = 100
var _priority_weights: Dictionary = {}

# Emergency auto-escalation: when a category is auto-raised, the original level
# is stashed here so we can restore it when the crisis ends. Player-set changes
# always update both this dict and `priorities` (see set_priority).
var _player_priorities: Dictionary = {}
var _auto_escalated: Dictionary = {}  # category -> bool

var priorities: Dictionary = {
	"food": "normal",
	"digging": "normal",
	"building": "normal",
	"nursery": "normal",
	"soldiers": "normal",
	"defense": "normal",
	"raid": "low",
	"repair": "normal",
}


func _ready() -> void:
	_load_priority_weights()
	# Snapshot initial priorities so emergency auto-escalation has somewhere to restore to.
	for k in priorities.keys():
		_player_priorities[k] = priorities[k]


func _load_priority_weights() -> void:
	var config_path := "res://data/colony/priority_weights.json"
	if not FileAccess.file_exists(config_path):
		_priority_weights = {"low": 0.5, "normal": 1.0, "high": 1.5, "emergency": 2.5}
		return
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		_priority_weights = {"low": 0.5, "normal": 1.0, "high": 1.5, "emergency": 2.5}
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		_priority_weights = {"low": 0.5, "normal": 1.0, "high": 1.5, "emergency": 2.5}
		return
	_priority_weights = data


func get_priority_weight(category: String) -> float:
	var level: String = priorities.get(category, "normal")
	return float(_priority_weights.get(level, 1.0))


func set_priority(category: String, level: String) -> void:
	if not (category in priorities):
		return
	if not (level in _priority_weights):
		return
	if priorities[category] == level:
		return
	# Player setting overrides any auto-escalation; clear that flag.
	_auto_escalated[category] = false
	_player_priorities[category] = level
	priorities[category] = level
	priority_changed.emit(category, level)
	if level == "emergency":
		emergency_priority_set.emit(category)


func auto_escalate(category: String) -> void:
	# Director-only: temporarily force a category to emergency without touching
	# the player's chosen level. Restored via auto_restore().
	if not (category in priorities):
		return
	if priorities[category] == "emergency":
		return
	_auto_escalated[category] = true
	priorities[category] = "emergency"
	priority_changed.emit(category, "emergency")
	emergency_priority_set.emit(category)


func auto_restore(category: String) -> void:
	# Restore the player's chosen level if (and only if) we were the ones who escalated.
	if not bool(_auto_escalated.get(category, false)):
		return
	_auto_escalated[category] = false
	var restored: String = String(_player_priorities.get(category, "normal"))
	priorities[category] = restored
	priority_changed.emit(category, restored)


func is_auto_escalated(category: String) -> bool:
	return bool(_auto_escalated.get(category, false))


func cycle_priority(category: String, direction: int) -> void:
	if not (category in priorities):
		return
	var current_level: String = priorities[category]
	var index := PRIORITY_ORDER.find(current_level)
	if index == -1:
		index = PRIORITY_ORDER.find("normal")
	var next_index := posmod(index + direction, PRIORITY_ORDER.size())
	set_priority(category, PRIORITY_ORDER[next_index])


func get_resource_urgency(category: String) -> float:
	if category == "food":
		if max_food <= 0:
			return 0.0
		return clamp(1.0 - (float(food) / float(max_food)), 0.0, 1.0)
	return 0.0


func get_total_ant_count() -> int:
	return worker_count + soldier_count


func can_hatch_worker() -> bool:
	return worker_count < max_workers
