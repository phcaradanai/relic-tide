class_name TideGame
extends RefCounted
## Pure fixed-step expedition rules. Transport owns time and event order.
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
const VAULT_HOLD_SECONDS := 1.5
const EXTRACTION_HOLD_SECONDS := 2.0
const HOLD_TIMEOUT_TICKS := 10
const BREATH_MAX := 12.0
const RELIC_VALUE := 100
var tick := 0
var explorers: Array[Dictionary] = []
var inputs: Array[Dictionary] = []
var event_sequences: Array[int] = []
var doors: Dictionary = {}
var water_depths: Dictionary = {}
var region_areas: Dictionary = {}
var valve_mode := "main"
var valve_holds: Dictionary = {}
var vault_holds: Dictionary = {}
var vault_progress := 0.0
var extraction_holds: Dictionary = {}
var relic := {"state": "pedestal", "holder": -1, "position": Map.relic_position()}
var finished := false
var finish_reason := ""
var results: Array[Dictionary] = []
var winners: Array[int] = []
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
		explorers.append({"name": "P%d" % (who + 1), "position": Map.spawn(who), "velocity": Vector2.ZERO, "region": "R0", "state": "exploring", "has_light": false, "has_relic": false, "breath": BREATH_MAX, "score": 0})
		inputs.append({"direction": Vector2.ZERO, "sequence": -1, "applied_sequence": -1, "received_tick": -100})
		event_sequences.append(-1)
func _active(who: int) -> bool:
	return not finished and who >= 0 and who < explorers.size() and explorers[who].state == "exploring"
func _claim_event(who: int, sequence: int) -> bool:
	if not _active(who) or sequence < 0 or sequence <= event_sequences[who]: return false
	event_sequences[who] = sequence
	return true
func _closed_doors(except_id: String = "") -> Array[String]:
	var result := Map.closed_door_ids(doors)
	result.erase(except_id)
	return result
func _can_reach(who: int, point: Vector2, closed_doors: Array = []) -> bool:
	if not _active(who): return false
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
	_clear_holds(who)
	valve_holds[who] = {"elapsed": 0.0, "received_tick": tick}
	return true
func _clear_holds(who: int) -> void:
	valve_holds.erase(who)
	extraction_holds.erase(who)
	for control in vault_holds.keys():
		if vault_holds[control].who == who:
			vault_holds.erase(control)
			vault_progress = 0.0
func interaction(who: int) -> Dictionary:
	if valve_holds.has(who): return {"kind": "begin_valve", "progress": valve_holds[who].elapsed / VALVE_HOLD_SECONDS}
	if extraction_holds.has(who): return {"kind": "begin_extraction", "progress": extraction_holds[who].elapsed / EXTRACTION_HOLD_SECONDS}
	for control in vault_holds:
		if vault_holds[control].who == who: return {"kind": "begin_vault", "target": control, "progress": vault_progress / VAULT_HOLD_SECONDS}
	return {}
func keep_interaction(who: int, sequence: int) -> bool:
	if not _claim_event(who, sequence): return false
	if valve_holds.has(who): valve_holds[who].received_tick = tick
	elif extraction_holds.has(who): extraction_holds[who].received_tick = tick
	else:
		for control in vault_holds:
			if vault_holds[control].who == who:
				vault_holds[control].received_tick = tick
				return true
		return false
	return true
func begin_vault(who: int, control: String, sequence: int) -> bool:
	if not Map.VAULT_CONTROLS.has(control) or not _claim_event(who, sequence): return false
	if not doors.D4.locked or vault_holds.has(control) or not interaction(who).is_empty(): return false
	if not _at_control(who, control): return false
	vault_holds[control] = {"who": who, "received_tick": tick}
	return true
func _at_control(who: int, control: String) -> bool:
	return _can_reach(who, Map.vault_control_position(control), _closed_doors()) and explorers[who].region == "C1" and explorers[who].position.distance_to(Map.vault_control_position(control)) <= Map.CONTROL_RADIUS
func use_relic(who: int, kind: String, sequence: int) -> bool:
	if not _claim_event(who, sequence): return false
	if kind == "take_relic":
		if relic.state not in ["pedestal", "ground"] or not _can_reach(who, relic.position, _closed_doors()): return false
		if relic.state == "pedestal" and doors.D4.locked: return false
		relic.state = "carried"
		relic.holder = who
		explorers[who].has_relic = true
		return true
	if kind == "drop_relic" and relic.state == "carried" and relic.holder == who:
		_clear_holds(who)
		_drop_relic(who)
		return true
	return false
func _drop_relic(who: int) -> void:
	if relic.state != "carried" or relic.holder != who: return
	relic.state = "ground"
	relic.holder = -1
	relic.position = explorers[who].position
	explorers[who].has_relic = false
func _at_extraction(who: int) -> bool:
	return _active(who) and explorers[who].region == "R0" and Map.extraction_rect().has_point(explorers[who].position)
func begin_extraction(who: int, sequence: int) -> bool:
	if not _claim_event(who, sequence) or not _at_extraction(who) or extraction_holds.has(who): return false
	_clear_holds(who)
	extraction_holds[who] = {"elapsed": 0.0, "received_tick": tick}
	return true
func cancel_interaction(who: int, sequence: int) -> bool:
	if not _claim_event(who, sequence): return false
	_clear_holds(who)
	return true
func set_input(who: int, direction: Vector2, sequence: int) -> bool:
	if not _active(who) or not direction.is_finite(): return false
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
				if explorer.state != "exploring": continue
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
		if tick - valve_holds[who].received_tick >= HOLD_TIMEOUT_TICKS or not _can_reach(int(who), Map.valve_position(), _closed_doors()):
			valve_holds.erase(who)
			continue
		valve_holds[who].elapsed += STEP
		if valve_holds[who].elapsed + 0.000001 >= VALVE_HOLD_SECONDS:
			valve_mode = "service" if valve_mode == "main" else "main"
			valve_holds.erase(who)
func _advance_vault_holds() -> void:
	for control in vault_holds.keys():
		var hold: Dictionary = vault_holds[control]
		if tick - hold.received_tick >= HOLD_TIMEOUT_TICKS or not _at_control(hold.who, control): vault_holds.erase(control)
	if vault_holds.size() != 2:
		vault_progress = 0.0
		return
	vault_progress += STEP
	if vault_progress + 0.000001 >= VAULT_HOLD_SECONDS:
		doors.D4.locked = false
		doors.D4.target_open = true
		vault_holds.clear()
		vault_progress = 0.0
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
func _advance_survival_and_extraction() -> void:
	for who in range(explorers.size()):
		if not _active(who): continue
		var explorer: Dictionary = explorers[who]
		var depth: float = water_depths[explorer.region]
		if depth >= Map.DEEP_DEPTH: explorer.breath = maxf(0.0, explorer.breath - STEP)
		elif depth < Map.SHALLOW_DEPTH: explorer.breath = minf(BREATH_MAX, explorer.breath + STEP * 2.0)
		if explorer.breath <= 0.000001:
			_drop_relic(who)
			_release_light(who)
			_clear_holds(who)
			explorer.state = "drowned"
			explorer.velocity = Vector2.ZERO
			continue
		if not extraction_holds.has(who): continue
		var hold: Dictionary = extraction_holds[who]
		if not _at_extraction(who) or tick - hold.received_tick >= HOLD_TIMEOUT_TICKS:
			extraction_holds.erase(who)
			continue
		hold.elapsed += STEP
		if hold.elapsed + 0.000001 < EXTRACTION_HOLD_SECONDS: continue
		if relic.state == "carried" and relic.holder == who:
			relic.state = "extracted"
			explorer.has_relic = false
			explorer.score += RELIC_VALUE
		_release_light(who)
		_clear_holds(who)
		explorer.state = "escaped"
		explorer.velocity = Vector2.ZERO
func _release_light(who: int) -> void:
	if lantern.holder != who: return
	lantern.holder = -1
	lantern.position = explorers[who].position
	explorers[who].has_light = false
func _finish(reason: String) -> void:
	finished = true
	finish_reason = reason
	var highest := 0
	for who in range(explorers.size()):
		var explorer: Dictionary = explorers[who]
		if explorer.state == "exploring": explorer.state = "stranded"
		explorer.velocity = Vector2.ZERO
		_clear_holds(who)
		results.append({"name": explorer.name, "state": explorer.state, "score": explorer.score})
		highest = maxi(highest, explorer.score)
	if highest > 0:
		for who in range(explorers.size()):
			if explorers[who].score == highest: winners.append(who)
	if relic.state != "extracted":
		if relic.state == "carried": relic.position = explorers[relic.holder].position
		relic.state = "unrecoverable"
		relic.holder = -1
		for explorer in explorers: explorer.has_relic = false
func step() -> void:
	if finished: return
	# Door closure advances before same-tick transfer. A dry, fully sealed R4
	# therefore has exactly zero incoming flow on the threshold tick.
	_advance_vault_holds()
	_advance_doors()
	_advance_valve_holds()
	_advance_water()
	var closed := _closed_doors()
	for who in range(explorers.size()):
		var input: Dictionary = inputs[who]
		var explorer: Dictionary = explorers[who]
		if not _active(who): continue
		var direction: Vector2 = input.direction if tick - input.received_tick < INPUT_TIMEOUT_TICKS else Vector2.ZERO
		var before: Vector2 = explorer.position
		var start_depth: float = water_depths[explorer.region]
		explorer.position = Map.move(before, direction, STEP, closed, start_depth, water_depths, explorer.has_relic)
		explorer.velocity = (explorer.position - before) / STEP
		explorer.region = Map.region_at(explorer.position)
		input.applied_sequence = input.sequence
	_advance_survival_and_extraction()
	tick += 1
	if not explorers.any(func(explorer): return explorer.state == "exploring"): _finish("all_terminal")
	elif float(tick) * STEP >= EXPEDITION_LENGTH: _finish("deadline")
