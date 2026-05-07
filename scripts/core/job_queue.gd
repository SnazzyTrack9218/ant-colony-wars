extends Node
class_name JobQueue

signal job_completed(job)

# Plain int constants instead of an enum to avoid inner-class circular refs.
const TYPE_DIG := 0
const TYPE_GATHER := 1

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
	job.category = "food" if type == TYPE_GATHER else "digging"
	job.tile_pos = tile_pos
	job.claimed_by = null
	_jobs.append(job)
	return job


func claim_best_job(ant_tile: Vector2i, ant_ref, valid_types: Array):
	var best_job = null
	var best_score := -1.0
	for job in _jobs:
		if job.claimed_by != null:
			continue
		if not (job.type in valid_types):
			continue
		var score := _score_job(job, ant_tile)
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


func _score_job(job, ant_tile: Vector2i) -> float:
	if GameManager == null or GameManager.colony == null:
		return 1.0
	var dist := (Vector2(job.tile_pos) - Vector2(ant_tile)).length()
	var w := GameManager.colony.get_priority_weight(job.category)
	return w + (10.0 / (dist + 1.0))
