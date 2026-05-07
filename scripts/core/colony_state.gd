extends Node
class_name ColonyState

const PRIORITY_WEIGHTS: Dictionary = {
	"low": 0.5, "normal": 1.0, "high": 1.5, "emergency": 2.5
}

var food: int = 0
var max_food: int = 200
var ant_count: int = 0

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


func get_priority_weight(category: String) -> float:
	var level: String = priorities.get(category, "normal")
	return PRIORITY_WEIGHTS.get(level, 1.0)


func set_priority(category: String, level: String) -> void:
	if category in priorities and level in PRIORITY_WEIGHTS:
		priorities[category] = level
