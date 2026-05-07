extends Node

signal food_changed(amount: int)
signal ant_count_changed(count: int)

var colony: ColonyState
var job_queue: JobQueue


func _ready() -> void:
	colony = ColonyState.new()
	add_child(colony)
	job_queue = JobQueue.new()
	add_child(job_queue)
	print("GameManager: initialized")


func add_food(amount: int) -> void:
	colony.food = mini(colony.food + amount, colony.max_food)
	food_changed.emit(colony.food)


func spend_food(amount: int) -> bool:
	if colony.food < amount:
		return false
	colony.food -= amount
	food_changed.emit(colony.food)
	return true


func register_ant() -> void:
	colony.ant_count += 1
	ant_count_changed.emit(colony.ant_count)


func unregister_ant() -> void:
	colony.ant_count = maxi(0, colony.ant_count - 1)
	ant_count_changed.emit(colony.ant_count)
