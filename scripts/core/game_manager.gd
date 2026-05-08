extends Node

signal food_changed(amount: int)
signal worker_count_changed(count: int, max_count: int)
signal soldier_count_changed(count: int)
signal priority_changed(category: String, level: String)
signal emergency_priority_set(category: String)
signal queen_damaged(current_hp: int, max_hp: int)

var colony: ColonyState
var job_queue: JobQueue
var room_manager: RoomManager
var upgrades: UpgradeManager
# Untyped to avoid class-load-order parse errors when other scripts read these
# via GameManager.* before the corresponding class_name has been registered.
var threat
var pheromones
var director


func _ready() -> void:
	colony = ColonyState.new()
	add_child(colony)
	colony.priority_changed.connect(_on_priority_changed)
	colony.emergency_priority_set.connect(_on_emergency_priority_set)
	job_queue = JobQueue.new()
	add_child(job_queue)
	room_manager = RoomManager.new()
	add_child(room_manager)
	upgrades = UpgradeManager.new()
	add_child(upgrades)
	threat = ThreatTracker.new()
	add_child(threat)
	pheromones = PheromoneMap.new()
	add_child(pheromones)
	director = ColonyDirector.new()
	add_child(director)
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


func register_worker() -> void:
	colony.worker_count += 1
	worker_count_changed.emit(colony.worker_count, colony.max_workers)


func unregister_worker() -> void:
	colony.worker_count = maxi(0, colony.worker_count - 1)
	worker_count_changed.emit(colony.worker_count, colony.max_workers)


func register_soldier() -> void:
	colony.soldier_count += 1
	soldier_count_changed.emit(colony.soldier_count)


func unregister_soldier() -> void:
	colony.soldier_count = maxi(0, colony.soldier_count - 1)
	soldier_count_changed.emit(colony.soldier_count)


func can_hatch_worker() -> bool:
	return colony.can_hatch_worker()


func set_priority(category: String, level: String) -> void:
	colony.set_priority(category, level)


func cycle_priority(category: String, direction: int) -> void:
	colony.cycle_priority(category, direction)


func _on_priority_changed(category: String, level: String) -> void:
	priority_changed.emit(category, level)


func _on_emergency_priority_set(category: String) -> void:
	emergency_priority_set.emit(category)
