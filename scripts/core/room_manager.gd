extends Node
class_name RoomManager

signal room_plan_created(plan_id: int, room_type: String, tile_pos: Vector2i, build_cost: int)
signal room_plan_updated(plan_id: int, progress: int, build_cost: int)
signal room_completed(plan_id: int, room_type: String, tile_pos: Vector2i)
signal worker_spawn_requested(tile_pos: Vector2i)
signal soldier_spawn_requested(tile_pos: Vector2i)

const CONFIG_DIR: String = "res://data/rooms"
const CONFIG_SUFFIX: String = "_config.json"

var _configs: Dictionary = {}
var _plans: Dictionary = {}
var _rooms: Dictionary = {}
var _occupied_tiles: Dictionary = {}
var _next_plan_id: int = 0


func _ready() -> void:
	_load_configs()


func _process(delta: float) -> void:
	for room_id in _rooms.keys():
		if not (room_id in _rooms):
			continue
		var room: Dictionary = _rooms[room_id]
		_tick_room_effect(room, delta)


func get_placeable_room_types() -> Array[String]:
	var room_types: Array[String] = []
	for room_type in _configs:
		if bool(_configs[room_type].get("placeable", true)):
			room_types.append(String(room_type))
	room_types.sort()
	return room_types


func get_display_name(room_type: String) -> String:
	var config: Dictionary = _configs.get(room_type, {})
	return String(config.get("display_name", room_type.capitalize()))


func can_place_room(room_type: String, tile_pos: Vector2i) -> bool:
	if not (room_type in _configs):
		return false
	if not bool(_configs[room_type].get("placeable", true)):
		return false
	return not (tile_pos in _occupied_tiles)


func create_room_plan(room_type: String, tile_pos: Vector2i) -> int:
	if not can_place_room(room_type, tile_pos):
		return -1
	var config: Dictionary = _configs[room_type]
	var plan_id: int = _next_plan_id
	_next_plan_id += 1
	var build_cost: int = maxi(0, int(config.get("build_cost", 0)))
	_plans[plan_id] = {
		"id": plan_id,
		"type": room_type,
		"tile_pos": tile_pos,
		"build_cost": build_cost,
		"progress": 0,
	}
	_occupied_tiles[tile_pos] = true
	var job = GameManager.job_queue.add_job(JobQueue.TYPE_BUILD, tile_pos)
	job.data["plan_id"] = plan_id
	job.data["room_type"] = room_type
	room_plan_created.emit(plan_id, room_type, tile_pos, build_cost)
	return plan_id


func apply_build_work(plan_id: int) -> String:
	if not (plan_id in _plans):
		return "missing"
	var plan: Dictionary = _plans[plan_id]
	var config: Dictionary = _configs.get(String(plan["type"]), {})
	var food_per_tick: int = maxi(0, int(config.get("build_food_per_tick", 1)))
	if food_per_tick > 0 and not GameManager.spend_food(food_per_tick):
		return "no_food"
	plan["progress"] = int(plan["progress"]) + maxi(1, food_per_tick)
	_plans[plan_id] = plan
	var progress: int = int(plan["progress"])
	var build_cost: int = int(plan["build_cost"])
	room_plan_updated.emit(plan_id, progress, build_cost)
	if progress >= build_cost:
		_complete_plan(plan_id)
		return "complete"
	return "progress"


func _complete_plan(plan_id: int) -> void:
	var plan: Dictionary = _plans[plan_id]
	_plans.erase(plan_id)
	var room_type: String = String(plan["type"])
	var tile_pos: Vector2i = Vector2i(plan["tile_pos"])
	_rooms[plan_id] = {
		"id": plan_id,
		"type": room_type,
		"tile_pos": tile_pos,
		"timer": 0.0,
	}
	_apply_completion_effect(room_type)
	room_completed.emit(plan_id, room_type, tile_pos)


func _apply_completion_effect(room_type: String) -> void:
	var config: Dictionary = _configs.get(room_type, {})
	if room_type == "food_storage":
		GameManager.colony.max_food += maxi(0, int(config.get("max_food_bonus", 0)))
		GameManager.food_changed.emit(GameManager.colony.food)


func _tick_room_effect(room: Dictionary, delta: float) -> void:
	var room_type: String = String(room.get("type", ""))
	if room_type != "nursery" and room_type != "mushroom_farm" and room_type != "soldier_barracks":
		return
	var config: Dictionary = _configs.get(room_type, {})
	var interval_key: String = "hatch_interval"
	if room_type == "mushroom_farm":
		interval_key = "food_interval"
	elif room_type == "soldier_barracks":
		interval_key = "training_interval"
	var interval: float = maxf(0.1, float(config.get(interval_key, 10.0)))
	room["timer"] = float(room.get("timer", 0.0)) + delta
	if float(room["timer"]) < interval:
		_rooms[int(room["id"])] = room
		return
	room["timer"] = 0.0
	_rooms[int(room["id"])] = room
	if room_type == "nursery":
		_try_hatch_worker(room, config)
	elif room_type == "mushroom_farm":
		GameManager.add_food(maxi(0, int(config.get("food_amount", 1))))
	elif room_type == "soldier_barracks":
		_try_train_soldier(room, config)


func _try_hatch_worker(room: Dictionary, config: Dictionary) -> void:
	var food_cost: int = maxi(0, int(config.get("hatch_food_cost", 0)))
	if food_cost > 0 and not GameManager.spend_food(food_cost):
		return
	worker_spawn_requested.emit(Vector2i(room["tile_pos"]))


func _try_train_soldier(room: Dictionary, config: Dictionary) -> void:
	# Only train when soldiers priority is at least normal.
	var soldiers_priority: String = String(GameManager.colony.priorities.get("soldiers", "normal"))
	if soldiers_priority == "low":
		return
	var food_cost: int = maxi(0, int(config.get("training_food_cost", 0)))
	if food_cost > 0 and not GameManager.spend_food(food_cost):
		return
	soldier_spawn_requested.emit(Vector2i(room["tile_pos"]))


func _load_configs() -> void:
	_configs.clear()
	var dir := DirAccess.open(CONFIG_DIR)
	if dir == null:
		push_warning("RoomManager: missing room config dir '%s'." % CONFIG_DIR)
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(CONFIG_SUFFIX):
			_load_config_file(CONFIG_DIR + "/" + file_name, file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_config_file(config_path: String, file_name: String) -> void:
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return
	var room_type: String = file_name.trim_suffix(CONFIG_SUFFIX)
	_configs[room_type] = data
