extends Node
class_name JobQueue

signal job_completed(job: Job)

enum JobType { DIG, GATHER }

const JOB_CATEGORY: Dictionary = {
	JobType.DIG: "digging",
	JobType.GATHER: "food",
}

class Job:
	var id: int
	var type: JobQueue.JobType
	var category: String
	var tile_pos: Vector2i
	var claimed_by  # null or ant node

var _jobs: Array = []
var _next_id: int = 0


func add_job(type: JobType, tile_pos: Vector2i) -> Job:
	# Don't add a duplicate job for the same tile and type.
	for existing in _jobs:
		if existing.type == type and existing.tile_pos == tile_pos:
			return existing
	var job := Job.new()
	job.id = _next_id
	_next_id += 1
	job.type = type
	job.category = JOB_CATEGORY.get(type, "misc")
	job.tile_pos = tile_pos
	job.claimed_by = null
	_jobs.append(job)
	return job


func claim_best_job(ant_tile: Vector2i, ant_ref: Object, valid_types: Array) -> Job:
	var best_job: Job = null
	var best_score: float = -1.0
	for job: Job in _jobs:
		if job.claimed_by != null:
			continue
		if job.type not in valid_types:
			continue
		var score := _score_job(job, ant_tile)
		if score > best_score:
			best_score = score
			best_job = job
	if best_job != null:
		best_job.claimed_by = ant_ref
	return best_job


func release_job(job_id: int) -> void:
	for job: Job in _jobs:
		if job.id == job_id:
			job.claimed_by = null
			return


func complete_job(job_id: int) -> void:
	for i in range(_jobs.size()):
		if _jobs[i].id == job_id:
			job_completed.emit(_jobs[i])
			_jobs.remove_at(i)
			return


func has_unclaimed_jobs(valid_types: Array) -> bool:
	for job: Job in _jobs:
		if job.claimed_by == null and job.type in valid_types:
			return true
	return false


func get_job_count() -> int:
	return _jobs.size()


func _score_job(job: Job, ant_tile: Vector2i) -> float:
	var dist := (Vector2(job.tile_pos) - Vector2(ant_tile)).length()
	var priority_w := GameManager.colony.get_priority_weight(job.category)
	return priority_w + (10.0 / (dist + 1.0))
