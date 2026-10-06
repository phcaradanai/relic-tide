class_name MovementPrediction
extends RefCounted
## Local fixed-step prediction. Only direction/sequence go over the wire.
const Map = preload("res://scripts/level_map.gd")
const STEP := 0.05
const MAX_PENDING := 12
var position := Vector2.ZERO
var sequence := -1
var pending: Array[Dictionary] = []
var match_id := ""
var tick := -1
var correction_distance := 0.0
var closed_doors: Array[String] = []
var water_depths: Dictionary = {}
func reset(snapshot: Dictionary) -> void:
	match_id = snapshot.match_id
	position = snapshot.explorers[snapshot.you].position
	sequence = snapshot.ack_sequence
	tick = snapshot.tick
	pending.clear()
	correction_distance = 0
	_set_world(snapshot)

func _set_world(snapshot: Dictionary) -> void:
	water_depths = snapshot.get("water_depths", {}).duplicate()
	closed_doors.clear()
	for door_id in snapshot.get("doors", {}):
		if snapshot.doors[door_id].progress <= 0.0001: closed_doors.append(door_id)

func _move(direction: Vector2) -> void:
	var region := Map.region_at(position)
	position = Map.move(position, direction, STEP, closed_doors, water_depths.get(region, 0.0), water_depths)
func advance(direction: Vector2) -> Dictionary:
	sequence += 1
	var command := {"direction": direction.limit_length(1), "sequence": sequence, "match_id": match_id}
	# Stop prediction during a stalled connection; authority still expires input.
	if pending.size() < MAX_PENDING:
		pending.append(command)
		_move(command.direction)
	return command
func reconcile(snapshot: Dictionary) -> bool:
	if snapshot.match_id != match_id:
		reset(snapshot)
		return true
	if snapshot.tick <= tick: return false
	tick = snapshot.tick
	_set_world(snapshot)
	var before := position
	pending = pending.filter(func(command): return command.sequence > snapshot.ack_sequence)
	position = snapshot.explorers[snapshot.you].position
	for command in pending: _move(command.direction)
	correction_distance = before.distance_to(position)
	return true
