class_name ExpeditionView
extends RefCounted
## Only local explorers have coordinates. No full state crosses the wire.
var player := 0
var tick := 0
var phase := "running"
var match_id := ""
var ack_sequence := -1
var explorers: Array = []
var lantern: Dictionary = {}
var doors: Dictionary = {}
var water_depths: Dictionary = {}
var vision_radius := 105.0
var tide_level := 0.0
var tide_seconds := 0.0
var valve: Dictionary = {}
func _init(snapshot: Dictionary = {}) -> void:
	if snapshot.is_empty(): return
	player = snapshot.you
	tick = snapshot.tick
	phase = snapshot.phase
	match_id = snapshot.match_id
	ack_sequence = snapshot.ack_sequence
	explorers = snapshot.explorers.duplicate(true)
	lantern = snapshot.get("lantern", {}).duplicate(true)
	doors = snapshot.get("doors", {}).duplicate(true)
	water_depths = snapshot.get("water_depths", {}).duplicate(true)
	vision_radius = snapshot.vision_radius
	tide_level = snapshot.get("tide_level", 0.0)
	tide_seconds = snapshot.get("tide_seconds", 0.0)
	valve = snapshot.get("valve", {}).duplicate(true)
static func project(game, who: int, token: String = "fixture", phase: String = "running") -> Dictionary:
	var visible: Array = []
	var observer: Dictionary = game.explorers[who]
	var map = preload("res://scripts/level_map.gd")
	var closed := map.closed_door_ids(game.doors)
	var radius: float = map.vision_radius(observer.position, observer.has_light, closed)
	for i in range(game.explorers.size()):
		var p: Dictionary = game.explorers[i]
		if i == who or map.can_see_with_radius(observer.position, p.position, radius, closed):
			visible.append({"name": p.name, "position": p.position, "velocity": p.velocity, "region": p.region, "state": p.state, "has_light": p.has_light})
		else:
			visible.append({"name": p.name, "state": "hidden"})
	var ground_light: Dictionary = {}
	if game.lantern.holder == -1 and map.can_see_with_radius(observer.position, game.lantern.position, radius, closed): ground_light = {"position": game.lantern.position}
	var visible_doors: Dictionary = {}
	for door_id in game.doors:
		var sight_without_door := closed.duplicate()
		sight_without_door.erase(door_id)
		var location: Vector2 = map.door_position(door_id)
		if not map.can_see_with_radius(observer.position, location, radius, sight_without_door): continue
		var state: Dictionary = game.doors[door_id]
		var is_refuge: bool = map.DOORS[door_id].refuge
		visible_doors[door_id] = {"position": location, "horizontal": map.DOORS[door_id].horizontal, "progress": state.progress, "target_open": state.target_open, "state": state.state, "locked": state.locked, "refuge": is_refuge, "sealed_safe": is_refuge and observer.region == "R4" and state.progress <= 0.0001 and game.water_depths.R4 <= 0.000001}
	var visible_water: Dictionary = {}
	for region in map.REGIONS:
		if map.region_visible(observer.position, region, observer.has_light, closed): visible_water[region] = game.water_depths[region]
	var valve_view: Dictionary = {}
	var valve_position: Vector2 = map.valve_position()
	if map.can_see_with_radius(observer.position, valve_position, radius, closed):
		var progress := 0.0
		for hold in game.valve_holds.values(): progress = maxf(progress, hold.elapsed / game.VALVE_HOLD_SECONDS)
		valve_view = {"mode": game.valve_mode, "progress": progress}
	return {"you": who, "tick": game.tick, "match_id": token, "phase": phase, "ack_sequence": game.inputs[who].applied_sequence, "explorers": visible, "vision_radius": radius, "lantern": ground_light, "doors": visible_doors, "water_depths": visible_water, "region_depth": game.water_depths[observer.region], "tide_level": game.tide_level, "tide_seconds": float(game.tick) * game.STEP, "valve": valve_view}
