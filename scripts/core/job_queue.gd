extends Node
class_name JobQueue

signal job_completed(job)

# Plain int constants instead of an enum to avoid inner-class circular refs.
const TYPE_DIG := 0
const TYPE_GATHER := 1
const TYPE_BUILD := 2
const TYPE_RALLY := 3

const CATEGORY_BY_TYPE: Dictionary = {
	TYPE_DIG: "digging",
	TYPE_GATHER: "food",
	TYPE_BUILD: "building",
	TYPE_RALLY: "defense",
}

var _priority_weight_scale: float = 100.0
var _distance_bonus_scale: float = 10.0
var _danger_penalty_scale: float = 5.0
var _resource_urgency_scale: float = 3.0
var _solo_category_bonus: float = 2.0

class Job:
	var id: int = 0
	var type: int = 0
	var category: String = ""
	var tile_pos: Vector2i = Vector2i.ZERO
	var claimed_by = null  # null or the claiming ant node
	var data: Dictionary = {}

var _jobs: Array = []
var _next_id: int = 0


func _ready() -> void:
	_load_scoring_config()


func _load_scoring_config() -> void:
	var config_path := "res://data/colony/job_scoring_config.json"
	if not FileAccess.file_exists(config_path):
		return
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return
	_priority_weight_scale = float(data.get("priority_weight_scale", _priority_weight_scale))
	_distance_bonus_scale = float(data.get("distance_bonus_scale", _distance_bonus_scale))
	_danger_penalty_scale = float(data.get("danger_penalty_scale", _danger_penalty_scale))
	_resource_urgency_scale = float(data.get("resource_urgency_scale", _resource_urgency_scale))
	_solo_category_bonus = float(data.get("solo_category_bonus", _solo_category_bonus))


func add_job(type: int, tile_pos: Vector2i):
	# Guard: don't add a duplicate job for the same tile+type.
	for existing in _jobs:
		if existing.type == type and existing.tile_pos == tile_pos:
			return existing
	var job := Job.new()
	job.id = _next_id
	_next_id += 1
	job.type = type
	job.category = CATEGORY_BY_TYPE.get(type, "")
	job.tile_pos = tile_pos
	job.claimed_by = null
	_jobs.append(job)
	return job


func claim_best_job(
		ant_tile: Vector2i,
		ant_ref,
		valid_types: Array,
		distance_lookup: Callable = Callable()):
	var best_job = null
	var best_score := 0.0
	for job in _jobs:
		if job.claimed_by != null:
			continue
		if not (job.type in valid_types):
			continue
		var score := _score_job(job, ant_tile, distance_lookup)
		if score > best_score:
			best_score = score
			best_job = job
	if best_job != null:
		best_job.claimed_by = ant_ref
	return best_job


func release_job(job_id: int) -> void:
	for job in _jobs:
		if job.id == job_id:
			var preserved_data: Dictionary = _get_persistent_job_data(job)
			job.claimed_by = null
			job.data.clear()
			for key in preserved_data:
				job.data[key] = preserved_data[key]
			return


func complete_job(job_id: int) -> void:
	for i in range(_jobs.size()):
		if _jobs[i].id == job_id:
			job_completed.emit(_jobs[i])
			_jobs.remove_at(i)
			return


func get_job_count() -> int:
	return _jobs.size()


func has_job(type: int, tile_pos: Vector2i) -> bool:
	for job in _jobs:
		if job.type == type and job.tile_pos == tile_pos:
			return true
	return false


func _get_persistent_job_data(job) -> Dictionary:
	var preserved: Dictionary = {}
	for key in ["purpose", "plan_id", "room_type"]:
		if key in job.data:
			preserved[key] = job.data[key]
	return preserved


func _score_job(job, ant_tile: Vector2i, distance_lookup: Callable = Callable()) -> float:
	if GameManager == null or GameManager.colony == null:
		return 1.0
	var dist: int = _get_job_distance(job, ant_tile, distance_lookup)
	if dist < 0:
		return 0.0
	var priority_weight := GameManager.colony.get_priority_weight(job.category)
	var danger_level := 0.0
	var resource_urgency := GameManager.colony.get_resource_urgency(job.category)
	var solo_bonus := 1.0 if not _has_claimed_job_in_category(job.category) else 0.0
	return (priority_weight * _priority_weight_scale) \
			+ (_distance_bonus_scale / (float(dist) + 1.0)) \
			- (danger_level * _danger_penalty_scale) \
			+ (resource_urgency * _resource_urgency_scale) \
			+ (solo_bonus * _solo_category_bonus)


func _get_job_distance(job, ant_tile: Vector2i, distance_lookup: Callable) -> int:
	if distance_lookup.is_valid():
		return int(distance_lookup.call(job))
	return int(abs(job.tile_pos.x - ant_tile.x) + abs(job.tile_pos.y - ant_tile.y))


func _has_claimed_job_in_category(category: String) -> bool:
	for job in _jobs:
		if job.category == category and job.claimed_by != null:
			return true
	return false
