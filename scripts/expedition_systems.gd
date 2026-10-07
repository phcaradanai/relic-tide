class_name ExpeditionSystems
extends RefCounted
## Seeded survival rules. No scenes, wall clock, input devices or rendering.
const STEP := 0.05
const BREATH := 20.0
const TANK_CAPACITY := 55.0
const WARNING_SECONDS := 24.0
const SHOT_RANGE := 330.0
const SHOT_WIDTH := 20.0
const STUN_SECONDS := 7.0
const ITEM_NAMES := ["map", "chart", "oxygen", "mask", "medkit", "gun"]
var rng := RandomNumberGenerator.new()
var duration := 900.0
var escape_grace := 90.0
var chests: Dictionary = {}
var puzzles: Dictionary = {}
var breaches: Array[Dictionary] = []
var monsters: Array[Dictionary] = []
var gas: Dictionary = {}
var blackout: Dictionary = {}
var next_breach := 0.0
var next_hunt := 0.0
var hunt_end := 0.0
var next_atmosphere := 0.0
var final_announced := false
var alarm_serial := 0
var shot_serial := 0
var shots: Array[Dictionary] = []
var monster_serial := 0

func _init(seed_value: int, map) -> void:
	rng.seed = seed_value
	# Weather is rolled once per expedition; its severity sets both cadence and
	# a 10–30 minute duration. All clients observe authority's same clock.
	var weather := rng.randf()
	duration = float(roundi(600.0 + weather * 1200.0))
	escape_grace = float(rng.randi_range(60, 120))
	next_breach = 55.0 + weather * 25.0
	next_hunt = 115.0 + weather * 65.0
	next_atmosphere = 85.0 + weather * 30.0
	var index := 0
	for chest_id in map.chest_anchors:
		var anchor: Dictionary = map.chest_anchors[chest_id]
		# Early provision chests deliberately share map/chart knowledge and supply
		# breathing gear before routes can be cut. Later rewards are seeded.
		var loot: String = ITEM_NAMES[index % ITEM_NAMES.size()]
		chests[chest_id] = {"id": chest_id, "position": anchor.position, "region": anchor.region, "opened": false, "claimed": [], "kind": ["runes", "circuit", "pressure"][index % 3], "loot": loot, "treasure": rng.randi_range(20, 45)}
		index += 1

func prepare_player(explorer: Dictionary) -> void:
	explorer.merge({"health": 3, "breath": BREATH, "breath_max": BREATH, "gear": {"map": false, "chart": false, "oxygen": false, "mask": false, "medkit": 0, "gun": false}, "tank": 0.0, "ammo": 0, "treasure": 0, "stun_until": -1, "hurt_until": -1, "shot_until": -1, "facing": Vector2.DOWN, "last_loot": "", "loot_serial": 0}, true)

func movement_factor(game, who: int) -> float:
	var explorer: Dictionary = game.explorers[who]
	if explorer.stun_until > game.tick: return 0.0
	return 0.86 if explorer.health == 1 else 1.0

func has_oxygen(game, who: int) -> bool:
	return game.explorers[who].gear.oxygen and game.explorers[who].tank > 0.0

func _can_act(game, who: int) -> bool:
	return game._active(who) and game.explorers[who].stun_until <= game.tick

func event(game, who: int, kind: String, target: String, sequence: int) -> bool:
	if not game._claim_event(who, sequence) or not _can_act(game, who): return false
	match kind:
		"chest": return _open_puzzle(game, who, target)
		"puzzle": return _puzzle_action(game, who, target)
		"heal":
			var explorer: Dictionary = game.explorers[who]
			if explorer.gear.medkit < 1 or explorer.health >= 3: return false
			explorer.gear.medkit -= 1
			explorer.health += 1
			return true
		"fire": return _fire(game, who, target)
		"cancel_puzzle":
			puzzles.erase(who)
			return true
	return false

func _near_chest(game, who: int, chest: Dictionary) -> bool:
	return game._can_reach(who, chest.position, game._closed_doors())

func _open_puzzle(game, who: int, chest_id: String) -> bool:
	if not chests.has(chest_id): return false
	var chest: Dictionary = chests[chest_id]
	if not _near_chest(game, who, chest): return false
	if chest.opened:
		# A solved supply chest permits each explorer to collect one provision;
		# its treasure belongs only to the solver, never multiplied per visitor.
		if who in chest.claimed: return false
		_award(game, who, chest_id, false)
		return true
	for owner in puzzles:
		if int(owner) != who and puzzles[owner].chest == chest_id: return false
	game._clear_holds(who)
	var sequence: Array[int] = []
	for i in range(4): sequence.append(rng.randi_range(0, 3))
	puzzles[who] = {"chest": chest_id, "nonce": rng.randi_range(1000, 999999), "kind": chest.kind, "sequence": sequence, "progress": 0, "bits": 0, "target_bits": rng.randi_range(1, 7), "pressure_target": rng.randf_range(0.35, 0.65), "hits": 0, "started_tick": game.tick, "last_tick": game.tick, "action_tick": -100, "failures": 0}
	return true

func pressure_phase(puzzle: Dictionary, tick: int) -> float:
	var phase_value := fmod(float(tick - puzzle.started_tick) * STEP / 2.6, 2.0)
	return phase_value if phase_value <= 1.0 else 2.0 - phase_value

func _puzzle_action(game, who: int, target: String) -> bool:
	if not puzzles.has(who): return false
	var puzzle: Dictionary = puzzles[who]
	var chest: Dictionary = chests[puzzle.chest]
	var parts := target.split(":")
	if parts.size() != 3 or parts[0] != puzzle.chest or not parts[1].is_valid_int() or int(parts[1]) != puzzle.nonce or not parts[2].is_valid_int(): return false
	if not _near_chest(game, who, chest) or game.tick - puzzle.action_tick < 4: return false
	var action := int(parts[2])
	puzzle.action_tick = game.tick
	puzzle.last_tick = game.tick
	var complete := false
	match puzzle.kind:
		"runes":
			# The initial memorization period prevents packet bursts instantly
			# opening a chest; every subsequent rune is rate-checked at authority.
			if action < 0 or action > 3 or game.tick - puzzle.started_tick < 50: return false
			if action == puzzle.sequence[puzzle.progress]: puzzle.progress += 1
			else:
				puzzle.progress = 0
				puzzle.failures += 1
			complete = puzzle.progress >= 4
		"circuit":
			if action < 0 or action > 2: return false
			puzzle.bits = puzzle.bits ^ (1 << action)
			complete = puzzle.bits == puzzle.target_bits
		"pressure":
			if action != 0: return false
			if absf(pressure_phase(puzzle, game.tick) - puzzle.pressure_target) <= 0.14: puzzle.hits += 1
			else:
				puzzle.hits = 0
				puzzle.failures += 1
			complete = puzzle.hits >= 3
	if complete:
		chest.opened = true
		_award(game, who, puzzle.chest, true)
		puzzles.erase(who)
	return true

func _award(game, who: int, chest_id: String, solver: bool) -> void:
	var chest: Dictionary = chests[chest_id]
	if who in chest.claimed: return
	chest.claimed.append(who)
	var explorer: Dictionary = game.explorers[who]
	var loot: String = chest.loot
	match loot:
		"oxygen":
			explorer.gear.oxygen = true
			explorer.tank = minf(TANK_CAPACITY * 2.0, explorer.tank + TANK_CAPACITY)
		"medkit": explorer.gear.medkit += 1
		"gun":
			explorer.gear.gun = true
			explorer.ammo += 4
		_: explorer.gear[loot] = true
	if solver: explorer.treasure += chest.treasure
	explorer.last_loot = loot
	explorer.loot_serial += 1

func _fire(game, who: int, target: String) -> bool:
	var shooter: Dictionary = game.explorers[who]
	if not shooter.gear.gun or shooter.ammo <= 0 or shooter.shot_until > game.tick: return false
	if not target.is_valid_int(): return false
	var direction_id := int(target)
	if direction_id < 0 or direction_id > 7: return false
	var direction := Vector2.DOWN.rotated(float(direction_id) * TAU / 8.0)
	var origin: Vector2 = shooter.position
	var nearest_distance := SHOT_RANGE + 1.0
	var hit: Dictionary = {}
	var hit_player := -1
	for player_id in range(game.explorers.size()):
		if player_id == who or not game._active(player_id): continue
		var other: Dictionary = game.explorers[player_id]
		var distance := _shot_distance(game, origin, direction, other.position)
		if distance >= 0.0 and distance < nearest_distance:
			nearest_distance = distance
			hit = other
			hit_player = player_id
	for monster: Dictionary in monsters:
		var distance := _shot_distance(game, origin, direction, monster.position)
		if distance >= 0.0 and distance < nearest_distance:
			nearest_distance = distance
			hit = monster
			hit_player = -1
	shooter.ammo -= 1
	shooter.shot_until = game.tick + 30
	shooter.facing = direction
	if not hit.is_empty():
		hit.stun_until = game.tick + int(STUN_SECONDS / STEP)
		if hit_player >= 0:
			game._clear_holds(hit_player)
			puzzles.erase(hit_player)
	shot_serial += 1
	shots.append({"id": shot_serial, "position": origin, "end": origin + direction * minf(SHOT_RANGE, nearest_distance), "until_tick": game.tick + 5})
	return true

func _shot_distance(game, origin: Vector2, direction: Vector2, point: Vector2) -> float:
	var relative := point - origin
	var along := relative.dot(direction)
	if along < 8.0 or along > SHOT_RANGE or absf(relative.cross(direction)) > SHOT_WIDTH: return -1.0
	if not game.Map.line_of_sight(origin, point, game._closed_doors()): return -1.0
	return along

func _pick_region(game, exclude: Array = []) -> String:
	var candidates: Array = []
	for region in game.Map.REGIONS:
		if region == "R4" or region in exclude: continue
		if region == "R0" and float(game.tick) * STEP < duration - escape_grace: continue
		candidates.append(region)
	return "" if candidates.is_empty() else candidates[rng.randi_range(0, candidates.size() - 1)]

func warn_breach(game, region: String, warning_seconds: float = WARNING_SECONDS) -> bool:
	if region not in game.Map.REGIONS or region == "R4": return false
	for breach in breaches:
		if breach.region == region and breach.end > game.tick * STEP: return false
	var seconds: float = game.tick * STEP
	breaches.append({"region": region, "warned": seconds, "start": seconds + warning_seconds, "end": seconds + warning_seconds + rng.randf_range(90.0, 155.0), "rate": rng.randf_range(0.055, 0.080)})
	return true

func before_water(game) -> void:
	var seconds: float = game.tick * STEP
	if seconds >= next_breach:
		var excluded: Array = []
		for breach in breaches:
			if breach.end > seconds: excluded.append(breach.region)
		warn_breach(game, _pick_region(game, excluded))
		next_breach = seconds + rng.randf_range(65.0, 105.0) * (0.8 + duration / 3000.0)
	if not final_announced and seconds >= duration - escape_grace:
		final_announced = true
		alarm_serial += 1
		# The last surge remains regional and respects shut gates/refuge. It does
		# not replace water with a global plane or flood protected occupants.
		for region in game.Map.REGIONS:
			if region != "R4": warn_breach(game, region, minf(24.0, escape_grace * 0.3))
	if seconds >= next_atmosphere:
		var region := _pick_region(game, ["R0"])
		if not region.is_empty():
			if rng.randf() < 0.55:
				blackout[region] = seconds + rng.randf_range(35.0, 65.0)
			else: gas[region] = seconds + rng.randf_range(35.0, 55.0)
		next_atmosphere = seconds + rng.randf_range(100.0, 170.0)
	for region in blackout.keys():
		if seconds >= blackout[region]: blackout.erase(region)
	for region in gas.keys():
		if seconds >= gas[region]: gas.erase(region)
	for region in game.Map.REGIONS: game.Map.room_power[region] = not blackout.has(region)
	shots = shots.filter(func(shot): return shot.until_tick > game.tick)
	for who in puzzles.keys():
		var puzzle: Dictionary = puzzles[who]
		if not _can_act(game, int(who)) or not _near_chest(game, int(who), chests[puzzle.chest]) or game.tick - puzzle.last_tick > 500: puzzles.erase(who)

func feed_water(game, previous: Dictionary, next: Dictionary) -> void:
	var seconds := float(game.tick + 1) * STEP
	game.tide_level = game.Map.MAX_WATER_DEPTH * clampf(seconds / duration, 0.0, 1.0)
	for breach in breaches:
		if seconds < breach.start or seconds >= breach.end: continue
		var region: String = breach.region
		# An exterior breach admits water only here. Connected rooms fill solely
		# via shared gates in game.gd's simultaneous volume-conserving transfer.
		next[region] += minf(game.Map.MAX_WATER_DEPTH - previous[region], breach.rate * STEP)
	if game.valve_mode == "service": next.C1 = maxf(0.0, next.C1 - 0.014 * STEP)

func damage(game, who: int, amount: int = 1) -> bool:
	if not game._active(who): return false
	var explorer: Dictionary = game.explorers[who]
	if explorer.hurt_until > game.tick: return false
	explorer.health = maxi(0, explorer.health - amount)
	explorer.hurt_until = game.tick + 60
	game._clear_holds(who)
	puzzles.erase(who)
	if explorer.health == 0: _kill(game, who, "injured")
	return true

func _kill(game, who: int, reason: String) -> void:
	game._drop_relic(who)
	game._release_light(who)
	game._clear_holds(who)
	puzzles.erase(who)
	game.explorers[who].state = reason
	game.explorers[who].health = 0
	game.explorers[who].velocity = Vector2.ZERO

func breathe(game, who: int, depth: float) -> void:
	var explorer: Dictionary = game.explorers[who]
	if depth >= game.Map.DEEP_DEPTH:
		if has_oxygen(game, who): explorer.tank = maxf(0.0, explorer.tank - STEP)
		else: explorer.breath = maxf(0.0, explorer.breath - STEP)
	elif depth < game.Map.SHALLOW_DEPTH: explorer.breath = minf(BREATH, explorer.breath + STEP * 2.0)
	if gas.has(explorer.region) and not explorer.gear.mask: damage(game, who)
	if explorer.breath <= 0.000001: _kill(game, who, "drowned")

func bank(game, who: int) -> void:
	game.explorers[who].score += game.explorers[who].treasure
	game.explorers[who].treasure = 0
	puzzles.erase(who)

func _region_center(game, region: String) -> Vector2:
	var floors: Array = game.Map.floors(region)
	return floors[0].get_center()

func _spawn_hunt(game) -> void:
	var candidates: Array = []
	for region in game.Map.REGIONS:
		if region == "R4" or region == "R0": continue
		var position := _region_center(game, region)
		var clear := true
		for explorer in game.explorers:
			if explorer.state == "exploring" and explorer.position.distance_to(position) < 620.0: clear = false
		if clear: candidates.append(position)
	if candidates.is_empty(): return
	monster_serial += 1
	var position: Vector2 = candidates[rng.randi_range(0, candidates.size() - 1)]
	monsters.append({"id": monster_serial, "position": position, "velocity": Vector2.ZERO, "stun_until": -1, "route": [], "target": -1, "path_tick": -100, "attack_until": -1})
	hunt_end = game.tick * STEP + rng.randf_range(38.0, 58.0)

func advance_hunters(game) -> void:
	var seconds: float = game.tick * STEP
	if seconds >= next_hunt and monsters.is_empty():
		_spawn_hunt(game)
		next_hunt = maxf(seconds, hunt_end) + rng.randf_range(125.0, 200.0)
	if not monsters.is_empty() and seconds >= hunt_end:
		monsters.clear()
		return
	var closed: Array[String] = game._closed_doors()
	for monster in monsters:
		monster.velocity = Vector2.ZERO
		if monster.stun_until > game.tick: continue
		var target := -1
		var nearest := INF
		for who in range(game.explorers.size()):
			if not game._active(who): continue
			var distance: float = monster.position.distance_to(game.explorers[who].position)
			if distance < nearest:
				nearest = distance
				target = who
		if target < 0: continue
		var destination: Vector2 = game.explorers[target].position
		if game.Map.line_of_sight(monster.position, destination, closed): monster.route = [destination]
		elif monster.target != target or game.tick - monster.path_tick >= 12:
			monster.route = game.Map.find_route(monster.position, destination, closed)
			monster.path_tick = game.tick
		monster.target = target
		while not monster.route.is_empty() and monster.position.distance_to(monster.route[0]) < 14.0: monster.route.pop_front()
		if not monster.route.is_empty():
			var direction: Vector2 = monster.position.direction_to(monster.route[0])
			var before: Vector2 = monster.position
			monster.position = game.Map.move(before, direction * 0.76, STEP, closed, 0.0, {}, false, true)
			monster.velocity = (monster.position - before) / STEP
		if monster.position.distance_to(destination) < 32.0 and game.Map.line_of_sight(monster.position, destination, closed):
			if damage(game, target): monster.attack_until = game.tick + 10

func chest_projection(game, who: int) -> Dictionary:
	var result := {}
	var observer: Dictionary = game.explorers[who]
	for chest_id in chests:
		var chest: Dictionary = chests[chest_id]
		if game.Map.can_see_with_radius(observer.position, chest.position, game.Map.vision_radius(observer.position, observer.has_light), game._closed_doors(), observer.has_light):
			result[chest_id] = {"position": chest.position, "opened": chest.opened, "claimed": who in chest.claimed, "kind": chest.kind}
	return result

func puzzle_projection(who: int) -> Dictionary:
	return puzzles[who].duplicate(true) if puzzles.has(who) else {}

func treasure_bearing(game, who: int) -> Dictionary:
	var explorer: Dictionary = game.explorers[who]
	if not explorer.gear.chart: return {}
	var target: Vector2 = game.Map.relic_position()
	var nearest := INF
	for chest in chests.values():
		if chest.opened: continue
		var distance: float = explorer.position.distance_to(chest.position)
		if distance < nearest:
			nearest = distance
			target = chest.position
	# Only a static treasure bearing; never the coordinates of a hidden carrier.
	return {"direction": explorer.position.direction_to(target), "distance": explorer.position.distance_to(target)}
