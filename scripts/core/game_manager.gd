extends Node

signal food_changed(amount: int)
signal ant_count_changed(count: int)
signal priority_changed(category: String, level: String)
signal emergency_priority_set(category: String)
signal queen_damaged(current_hp: int, max_hp: int)

var colony: ColonyState
var job_queue: JobQueue
var room_manager: RoomManager


func _ready() -> void:
	colony = ColonyState.new()
	add_child(colony)
	colony.priority_changed.connect(_on_priority_changed)
	colony.emergency_priority_set.connect(_on_emergency_priority_set)
	job_queue = JobQueue.new()
	add_child(job_queue)
	room_manager = RoomManager.new()
	add_child(room_manager)
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


func damage_queen(amount: int) -> void:
	if amount <= 0:
		return
	colony.queen_hp = maxi(0, colony.queen_hp - amount)
	queen_damaged.emit(colony.queen_hp, colony.queen_max_hp)
	AudioManager.play_queen_damaged()


func register_ant() -> void:
	colony.ant_count += 1
	ant_count_changed.emit(colony.ant_count)


func unregister_ant() -> void:
	colony.ant_count = maxi(0, colony.ant_count - 1)
	ant_count_changed.emit(colony.ant_count)


func set_priority(category: String, level: String) -> void:
	colony.set_priority(category, level)


func cycle_priority(category: String, direction: int) -> void:
	colony.cycle_priority(category, direction)


func _on_priority_changed(category: String, level: String) -> void:
	priority_changed.emit(category, level)


func _on_emergency_priority_set(category: String) -> void:
	emergency_priority_set.emit(category)
