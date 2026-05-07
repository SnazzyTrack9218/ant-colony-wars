extends Node
class_name JobQueue

signal job_completed(job)

# Plain int constants instead of an enum to avoid inner-class circular refs.
const TYPE_DIG := 0
const TYPE_GATHER := 1

const CATEGORY_BY_TYPE: Dictionary = {
	TYPE_DIG: "digging",
	TYPE_GATHER: "food",
}

class Job:
	var id: int = 0
	var type: int = 0
	var category: String = ""
	var tile_pos: Vector2i = Vector2i.ZERO
	var claimed_by = null  # null or the claiming ant node

var _jobs: Array = []
var _next_id: int = 0


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
			job.claimed_by = null
			return


func complete_job(job_id: int) -> void:
	for i in range(_jobs.size()):
		if _jobs[i].id == job_id:
			job_completed.emit(_jobs[i])
			_jobs.remove_at(i)
			return


func get_job_count() -> int:
	return _jobs.size()


func _score_job(job, ant_tile: Vector2i, distance_lookup: Callable = Callable()) -> float:
	if GameManager == null or GameManager.colony == null:
		return 1.0
	var dist := _get_job_distance(job, ant_tile, distance_lookup)
	if dist < 0:
		return 0.0
	var priority_weight := GameManager.colony.get_priority_weight(job.category)
	var danger_level := 0.0
	var resource_urgency := GameManager.colony.get_resource_urgency(job.category)
	var solo_bonus := 1.0 if not _has_claimed_job_in_category(job.category) else 0.0
	return priority_weight \
			+ (10.0 / (float(dist) + 1.0)) \
			- (danger_level * 5.0) \
			+ (resource_urgency * 3.0) \
			+ (solo_bonus * 2.0)


func _get_job_distance(job, ant_tile: Vector2i, distance_lookup: Callable) -> int:
	if distance_lookup.is_valid():
		return int(distance_lookup.call(job))
	return int(abs(job.tile_pos.x - ant_tile.x) + abs(job.tile_pos.y - ant_tile.y))


func _has_claimed_job_in_category(category: String) -> bool:
	for job in _jobs:
		if job.category == category and job.claimed_by != null:
			return true
	return false
