class_name TideGame
extends RefCounted
## Pure, fixed-step doors and regional water. Transport owns the clock.
const Map = preload("res://scripts/level_map.gd")
const STEP := 0.05
const INPUT_TIMEOUT_TICKS := 5
const TIDE_LEAD_IN := 45.0
const EXPEDITION_LENGTH := 360.0
const SOURCE_RATE := 0.34
const BYPASS_DRAIN_RATE := 0.2
const DOOR_OPEN_SECONDS := 0.6
const DOOR_CLOSE_SECONDS := 0.75
const DOOR_OBSTRUCTION_PROGRESS := 0.2
const VALVE_HOLD_SECONDS := 1.5
var tick := 0
var explorers: Array[Dictionary] = []
var inputs: Array[Dictionary] = []
var event_sequences: Array[int] = []
var doors: Dictionary = {}
var water_depths: Dictionary = {}
var region_areas: Dictionary = {}
var valve_mode := "main"
var valve_holds: Dictionary = {}
var tide_level := 0.0
var lantern := {"holder": -1, "position": Map.from_art(Vector2(205, 741))}
func _init(_seed: int = 1, count: int = 2) -> void:
	for region in Map.REGIONS:
		water_depths[region] = 0.0
		var area := 0.0
		for rect: Rect2 in Map.floors(region): area += rect.get_area()
		region_areas[region] = area
	for door_id in Map.DOORS:
		var spec: Dictionary = Map.DOORS[door_id]
		var progress := 1.0 if spec.initially_open else 0.0
		doors[door_id] = {"progress": progress, "target_open": spec.initially_open, "locked": spec.locked, "obstructed": false, "state": "open" if progress >= 1.0 else "locked" if spec.locked else "closed"}
	for who in range(clampi(count, 2, 4)):
		explorers.append({"name": "P%d" % (who + 1), "position": Map.spawn(who), "velocity": Vector2.ZERO, "region": "R0", "state": "exploring", "has_light": false})
		inputs.append({"direction": Vector2.ZERO, "sequence": -1, "applied_sequence": -1, "received_tick": -100})
		event_sequences.append(-1)
func _claim_event(who: int, sequence: int) -> bool:
	if who < 0 or who >= explorers.size() or sequence < 0 or sequence <= event_sequences[who]: return false
	event_sequences[who] = sequence
	return true
func _closed_doors(except_id: String = "") -> Array[String]:
	var result := Map.closed_door_ids(doors)
	result.erase(except_id)
	return result
func _can_reach(who: int, point: Vector2, closed_doors: Array = []) -> bool:
	if who < 0 or who >= explorers.size(): return false
	var position: Vector2 = explorers[who].position
	return position.distance_to(point) <= Map.USE_RADIUS and Map.line_of_sight(position, point, closed_doors)
func use_light(who: int, kind: String, sequence: int) -> bool:
	if not _claim_event(who, sequence): return false
	var explorer: Dictionary = explorers[who]
	if kind == "take_light":
		if lantern.holder != -1 or explorer.position.distance_to(lantern.position) > 38 or not Map.line_of_sight(explorer.position, lantern.position, _closed_doors()): return false
		lantern.holder = who
		explorer.has_light = true
		return true
	if kind == "drop_light" and lantern.holder == who:
		lantern.holder = -1
		lantern.position = explorer.position
		explorer.has_light = false
		return true
	return false
func toggle_door(who: int, door_id: String, sequence: int) -> bool:
	if not Map.DOORS.has(door_id) or not _claim_event(who, sequence): return false
	var door: Dictionary = doors[door_id]
	if door.locked or not _can_reach(who, Map.door_position(door_id), _closed_doors(door_id)): return false
	door.target_open = not door.target_open
	return true
func begin_valve(who: int, sequence: int) -> bool:
	if not _claim_event(who, sequence) or not valve_holds.is_empty(): return false
	if not _can_reach(who, Map.valve_position(), _closed_doors()): return false
	valve_holds[who] = {"elapsed": 0.0}
	return true
func cancel_interaction(who: int, sequence: int) -> bool:
	if not _claim_event(who, sequence): return false
	return valve_holds.erase(who)
func set_input(who: int, direction: Vector2, sequence: int) -> bool:
	if who < 0 or who >= inputs.size() or not direction.is_finite(): return false
	if absf(direction.x) > 1 or absf(direction.y) > 1 or sequence < 0 or sequence <= inputs[who].sequence: return false
	inputs[who].direction = direction.limit_length(1)
	inputs[who].sequence = sequence
	inputs[who].received_tick = tick
	return true
func _door_permeability(door_id: String) -> float:
	var door: Dictionary = doors[door_id]
	var progress: float = door.progress
	if Map.DOORS[door_id].refuge:
		return 0.0 if progress <= 0.0001 else progress
	return 0.08 + 0.92 * progress
func _advance_doors() -> void:
	for door_id in doors:
		var door: Dictionary = doors[door_id]
		door.obstructed = false
		if door.target_open:
			door.progress = minf(1.0, door.progress + STEP / DOOR_OPEN_SECONDS)
		else:
			var occupied := false
			for explorer: Dictionary in explorers:
				if Map.door_distance(explorer.position, door_id) <= Map.FOOT_RADIUS + 5.0:
					occupied = true
					break
			if occupied and door.progress > DOOR_OBSTRUCTION_PROGRESS:
				door.progress = maxf(DOOR_OBSTRUCTION_PROGRESS, door.progress - STEP / DOOR_CLOSE_SECONDS)
				door.obstructed = true
			elif occupied and door.progress > 0.0001:
				door.progress = DOOR_OBSTRUCTION_PROGRESS
				door.obstructed = true
			else:
				door.progress = maxf(0.0, door.progress - STEP / DOOR_CLOSE_SECONDS)
		if door.progress >= 1.0:
			door.state = "open"
		elif door.obstructed:
			door.state = "obstructed"
		elif door.progress <= 0.0001:
			door.state = "locked" if door.locked else "closed"
		else:
			door.state = "opening" if door.target_open else "closing"
func _advance_valve_holds() -> void:
	for who in valve_holds.keys():
		if not _can_reach(int(who), Map.valve_position(), _closed_doors()):
			valve_holds.erase(who)
			continue
		valve_holds[who].elapsed += STEP
		if valve_holds[who].elapsed >= VALVE_HOLD_SECONDS:
			valve_mode = "service" if valve_mode == "main" else "main"
			valve_holds.erase(who)
func _advance_water() -> void:
	var previous: Dictionary = water_depths.duplicate()
	var next: Dictionary = previous.duplicate()
	var elapsed := float(tick + 1) * STEP
	tide_level = 0.0 if elapsed <= TIDE_LEAD_IN else Map.MAX_WATER_DEPTH * clampf((elapsed - TIDE_LEAD_IN) / (EXPEDITION_LENGTH - TIDE_LEAD_IN), 0.0, 1.0)
	var feed_region := "C1" if valve_mode == "main" else "C2"
	var feed_volume: float = maxf(0.0, tide_level - previous[feed_region]) * region_areas[feed_region] * SOURCE_RATE * STEP
	next[feed_region] += feed_volume / region_areas[feed_region]
	if valve_mode == "service":
		# Explicit passive outlet from the main crossing; this only removes water
		# that is already there and is disabled while the main feed is selected.
		var drain_volume: float = previous.C1 * region_areas.C1 * BYPASS_DRAIN_RATE * STEP
		next.C1 = maxf(0.0, next.C1 - drain_volume / region_areas.C1)
	var transfers: Array[Dictionary] = []
	var requested_out: Dictionary = {}
	for connection: Dictionary in Map.CONNECTIONS:
		var a: String = connection.a
		var b: String = connection.b
		var threshold: float = connection.threshold
		var head_a := maxf(previous[a] - threshold, 0.0)
		var head_b := maxf(previous[b] - threshold, 0.0)
		if is_equal_approx(head_a, head_b): continue
		var donor := a if head_a > head_b else b
		var receiver := b if head_a > head_b else a
		var door_id: String = connection.door
		var permeability := 1.0 if door_id.is_empty() else _door_permeability(door_id)
		if permeability <= 0.0: continue
		var volume: float = absf(head_a - head_b) * minf(region_areas[a], region_areas[b]) * connection.conductance * STEP * permeability
		transfers.append({"donor": donor, "receiver": receiver, "volume": volume})
		requested_out[donor] = requested_out.get(donor, 0.0) + volume
	for transfer: Dictionary in transfers:
		var donor: String = transfer.donor
		var available: float = maxf(0.0, next[donor]) * region_areas[donor]
		var total_requested: float = requested_out[donor]
		var moved: float = transfer.volume * minf(1.0, available / maxf(total_requested, 0.0001))
		transfer["moved"] = moved
	var volume_delta: Dictionary = {}
	for region in Map.REGIONS: volume_delta[region] = 0.0
	for transfer: Dictionary in transfers:
		volume_delta[transfer.donor] -= transfer.moved
		volume_delta[transfer.receiver] += transfer.moved
	for region in Map.REGIONS:
		next[region] += volume_delta[region] / region_areas[region]
	for region in Map.REGIONS: next[region] = clampf(next[region], 0.0, Map.MAX_WATER_DEPTH)
	water_depths = next
func step() -> void:
	# Door closure advances before same-tick transfer. A dry, fully sealed R4
	# therefore has exactly zero incoming flow on the threshold tick.
	_advance_doors()
	_advance_valve_holds()
	_advance_water()
	var closed := _closed_doors()
	for who in range(explorers.size()):
		var input: Dictionary = inputs[who]
		var explorer: Dictionary = explorers[who]
		var direction: Vector2 = input.direction if tick - input.received_tick < INPUT_TIMEOUT_TICKS else Vector2.ZERO
		var before: Vector2 = explorer.position
		var start_depth: float = water_depths[explorer.region]
		explorer.position = Map.move(before, direction, STEP, closed, start_depth, water_depths)
		explorer.velocity = (explorer.position - before) / STEP
		explorer.region = Map.region_at(explorer.position)
		input.applied_sequence = input.sequence
	tick += 1
