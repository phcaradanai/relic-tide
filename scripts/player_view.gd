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
var relic: Dictionary = {}
var vault: Dictionary = {}
var extraction: Dictionary = {}
var interaction: Dictionary = {}
var results: Array = []
var winners: Array = []
var finish_reason := ""
var map_id := "prototype"
var duration := 360.0
var escape_grace := 90.0
var final_alarm := false
var alarm_serial := 0
var power: Dictionary = {}
var chests: Dictionary = {}
var puzzle: Dictionary = {}
var breaches: Array = []
var monsters: Array = []
var gas: Array = []
var shots: Array = []
var treasure_bearing: Dictionary = {}
var hunt_active := false
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
	relic = snapshot.get("relic", {}).duplicate(true)
	vault = snapshot.get("vault", {}).duplicate(true)
	extraction = snapshot.get("extraction", {}).duplicate(true)
	interaction = snapshot.get("interaction", {}).duplicate(true)
	results = snapshot.get("results", []).duplicate(true)
	winners = snapshot.get("winners", []).duplicate()
	finish_reason = snapshot.get("finish_reason", "")
	map_id = snapshot.get("map_id", "prototype")
	duration = snapshot.get("duration", 360.0)
	escape_grace = snapshot.get("escape_grace", 90.0)
	final_alarm = snapshot.get("final_alarm", false)
	alarm_serial = snapshot.get("alarm_serial", 0)
	power = snapshot.get("power", {}).duplicate()
	chests = snapshot.get("chests", {}).duplicate(true)
	puzzle = snapshot.get("puzzle", {}).duplicate(true)
	breaches = snapshot.get("breaches", []).duplicate(true)
	monsters = snapshot.get("monsters", []).duplicate(true)
	gas = snapshot.get("gas", []).duplicate()
	shots = snapshot.get("shots", []).duplicate(true)
	treasure_bearing = snapshot.get("treasure_bearing", {}).duplicate(true)
	hunt_active = snapshot.get("hunt_active", false)
static func project(game, who: int, token: String = "fixture", phase: String = "running") -> Dictionary:
	if phase == "running" and game.finished: phase = "finished"
	var visible: Array = []
	var observer: Dictionary = game.explorers[who]
	var map = game.Map
	var closed: Array[String] = map.closed_door_ids(game.doors)
	var radius: float = map.vision_radius(observer.position, observer.has_light, closed)
	for i in range(game.explorers.size()):
		var p: Dictionary = game.explorers[i]
		if i == who or (p.state != "escaped" and map.can_see_with_radius(observer.position, p.position, radius, closed, observer.has_light)):
			var actor := {"name": p.name, "position": p.position, "velocity": p.velocity, "region": p.region, "state": p.state, "has_light": p.has_light, "has_relic": p.has_relic}
			if i == who:
				actor["breath"] = p.breath
				actor["score"] = p.score
				actor["region_depth"] = game.water_depths[p.region]
				if game.expedition != null:
					for field in ["health", "breath_max", "gear", "tank", "ammo", "treasure", "facing", "last_loot", "loot_serial"]: actor[field] = p[field].duplicate(true) if p[field] is Dictionary else p[field]
					actor["move_factor"] = game.expedition.movement_factor(game, who)
					actor["oxygen_enabled"] = game.expedition.has_oxygen(game, who)
			if game.expedition != null:
				actor["stunned"] = p.stun_until > game.tick
				actor["hurt"] = p.hurt_until > game.tick
			visible.append(actor)
		else:
			visible.append({"name": p.name, "state": "hidden"})
	var ground_light: Dictionary = {}
	if game.lantern.holder == -1 and map.can_see_with_radius(observer.position, game.lantern.position, radius, closed, observer.has_light): ground_light = {"position": game.lantern.position}
	var visible_doors: Dictionary = {}
	for door_id in game.doors:
		var sight_without_door: Array[String] = closed.duplicate()
		sight_without_door.erase(door_id)
		var location: Vector2 = map.door_position(door_id)
		if not map.can_see_with_radius(observer.position, location, radius, sight_without_door, observer.has_light): continue
		var state: Dictionary = game.doors[door_id]
		var is_refuge: bool = map.DOORS[door_id].refuge
		visible_doors[door_id] = {"position": location, "horizontal": map.DOORS[door_id].horizontal, "progress": state.progress, "target_open": state.target_open, "state": state.state, "locked": state.locked, "refuge": is_refuge, "sealed_safe": is_refuge and observer.region == "R4" and state.progress <= 0.0001 and game.water_depths.R4 <= 0.000001}
	var visible_water: Dictionary = {}
	for region in map.REGIONS:
		if map.region_visible(observer.position, region, observer.has_light, closed): visible_water[region] = game.water_depths[region]
	var valve_view: Dictionary = {}
	var valve_position: Vector2 = map.valve_position()
	if map.can_see_with_radius(observer.position, valve_position, radius, closed, observer.has_light):
		var progress := 0.0
		for hold in game.valve_holds.values(): progress = maxf(progress, hold.elapsed / game.VALVE_HOLD_SECONDS)
		valve_view = {"mode": game.valve_mode, "progress": progress}
	var ground_relic: Dictionary = {}
	if game.relic.state in ["pedestal", "ground"] and map.can_see_with_radius(observer.position, game.relic.position, radius, closed, observer.has_light): ground_relic = {"position": game.relic.position, "state": game.relic.state}
	var vault_view: Dictionary = {}
	for control in map.VAULT_CONTROLS:
		var location: Vector2 = map.vault_control_position(control)
		if map.can_see_with_radius(observer.position, location, radius, closed, observer.has_light):
			vault_view[control] = {"position": location, "held": game.vault_holds.has(control), "progress": game.vault_progress / game.VAULT_HOLD_SECONDS, "locked": game.doors.D4.locked}
	var extraction_view: Dictionary = {}
	if map.can_see_with_radius(observer.position, map.extraction_position(), radius, closed, observer.has_light): extraction_view = {"position": map.extraction_position()}
	var snapshot := {"you": who, "tick": game.tick, "match_id": token, "phase": phase, "ack_sequence": game.inputs[who].applied_sequence, "explorers": visible, "vision_radius": radius, "lantern": ground_light, "doors": visible_doors, "water_depths": visible_water, "region_depth": game.water_depths[observer.region], "tide_level": game.tide_level, "tide_seconds": float(game.tick) * game.STEP, "valve": valve_view, "relic": ground_relic, "vault": vault_view, "extraction": extraction_view, "interaction": game.interaction(who)}
	snapshot["map_id"] = map.id
	if game.expedition != null:
		var systems = game.expedition
		snapshot.merge({"duration": systems.duration, "escape_grace": systems.escape_grace, "final_alarm": systems.final_announced, "alarm_serial": systems.alarm_serial, "chests": systems.chest_projection(game, who), "puzzle": systems.puzzle_projection(who), "treasure_bearing": systems.treasure_bearing(game, who), "hunt_active": not systems.monsters.is_empty(), "power": {}, "breaches": [], "monsters": [], "gas": [], "shots": []})
		for region in map.REGIONS:
			if not map.region_visible(observer.position, region, observer.has_light, closed): continue
			snapshot.power[region] = map.room_power[region]
			if systems.gas.has(region): snapshot.gas.append(region)
			for breach in systems.breaches:
				if breach.region == region and game.tick * game.STEP < breach.end: snapshot.breaches.append({"region": region, "warned": breach.warned, "start": breach.start, "end": breach.end})
		for monster in systems.monsters:
			if map.can_see_with_radius(observer.position, monster.position, radius, closed, observer.has_light): snapshot.monsters.append({"id": monster.id, "position": monster.position, "velocity": monster.velocity, "stunned": monster.stun_until > game.tick, "attacking": monster.attack_until > game.tick})
		for shot in systems.shots:
			if map.can_see_with_radius(observer.position, shot.position, radius, closed, observer.has_light) and map.can_see_with_radius(observer.position, shot.end, radius, closed, observer.has_light): snapshot.shots.append({"id": shot.id, "position": shot.position, "end": shot.end})
	if phase == "finished" and game.finished:
		snapshot["results"] = game.results.duplicate(true)
		snapshot["winners"] = game.winners.duplicate()
		snapshot["finish_reason"] = game.finish_reason
	return snapshot
