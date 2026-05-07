extends Node
class_name ColonyState

signal priority_changed(category: String, level: String)
signal emergency_priority_set(category: String)

const PRIORITY_ORDER: Array[String] = ["low", "normal", "high", "emergency"]

var food: int = 0
var max_food: int = 200
var ant_count: int = 0
var _priority_weights: Dictionary = {}

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


func _load_priority_weights() -> void:
	var path := "res://data/colony/priority_weights.json"
	if not FileAccess.file_exists(path):
		_priority_weights = {"low": 0.5, "normal": 1.0, "high": 1.5, "emergency": 2.5}
		return
	var file := FileAccess.open(path, FileAccess.READ)
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
	priorities[category] = level
	priority_changed.emit(category, level)
	if level == "emergency":
		emergency_priority_set.emit(category)


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
