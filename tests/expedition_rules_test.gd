extends SceneTree
const Rules = preload("res://scripts/game.gd")
const Maps = preload("res://scripts/expedition_map.gd")
const Directory = preload("res://scripts/room_directory.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func fixture(map_id: String = "lagoon", seed_value: int = 42):
	var game := Rules.new(seed_value, 2, map_id)
	game.expedition.next_breach = INF
	game.expedition.next_hunt = INF
	game.expedition.next_atmosphere = INF
	return game
func place(game, who: int, position: Vector2) -> void:
	game.explorers[who].position = position
	game.explorers[who].region = game.Map.region_at(position)
func event(game, who: int, kind: String, target: String = "") -> bool:
	return game.expedition.event(game, who, kind, target, game.event_sequences[who] + 1)
func puzzle_press(game, who: int, index: int) -> bool:
	var puzzle: Dictionary = game.expedition.puzzles[who]
	return event(game, who, "puzzle", "%s:%d:%d" % [puzzle.chest, puzzle.nonce, index])
func _init() -> void:
	test_seed_and_clock()
	test_doors_water_refuge()
	test_puzzles_and_loot()
	test_survival_and_equipment()
	test_shots_hunts_and_extraction()
	test_directory()
	print("Large expedition rules: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func test_seed_and_clock() -> void:
	var durations: Dictionary = {}
	for seed_value in range(30):
		for map_id in Maps.PRODUCTION_IDS:
			var first := Rules.new(seed_value, 2, map_id)
			var second := Rules.new(seed_value, 2, map_id)
			check(first.expedition.duration >= 600 and first.expedition.duration <= 1800, "10–30 minute seeded clock")
			check(first.expedition.escape_grace >= 60 and first.expedition.escape_grace <= 120, "1–2 minute evacuation grace")
			check(first.expedition.duration == second.expedition.duration and first.expedition.chests == second.expedition.chests, "Identical seed reproduces weather/loot")
			durations[first.expedition.duration] = true
	check(durations.size() > 10, "Different seeds vary the expedition")
	var game = fixture()
	game.tick = int((game.expedition.duration - game.expedition.escape_grace) / Rules.STEP)
	game.step()
	check(game.expedition.final_announced and not game.finished, "Final alarm precedes game over")
	check(game.expedition.alarm_serial == 1, "One final alarm event")
	game.tick = int(game.expedition.duration / Rules.STEP) - 1
	game.step()
	check(game.finished and game.finish_reason == "deadline", "Deadline fills gauge and ends round")
func test_doors_water_refuge() -> void:
	for map_id in Maps.PRODUCTION_IDS:
		var game = fixture(map_id)
		check(game.expedition.warn_breach(game, "C0"), "Corridor breach is announced")
		check(not game.expedition.warn_breach(game, "R4"), "Refuge has no hidden source")
		for i in range(479): game.step()
		check(game.water_depths.C0 == 0.0, "No ingress throughout warning")
		for i in range(4): game.step()
		check(game.water_depths.C0 > 0.0, "Ingress starts after warning")
		game.doors.D0.progress = 0.0
		game.doors.D0.target_open = false
		game.doors.D1.progress = 0.0
		game.doors.D1.target_open = false
		game.water_depths.C0 = 2.2
		for i in range(60): game.step()
		check(game.water_depths.R0 == 0.0 and game.water_depths.R1 == 0.0, "Both closed hall gates isolate water")
		game.water_depths.R1 = 0.42
		# Seal every R1 entrance, so retained water can neither escape nor enter.
		for id in game.doors:
			if "R1" in game.Map.DOORS[id].regions:
				game.doors[id].progress = 0.0
				game.doors[id].target_open = false
		for i in range(30): game.step()
		check(is_equal_approx(game.water_depths.R1, 0.42), "Late closure never erases admitted water")
		place(game, 0, game.Map.region_center("R4"))
		game.doors.D5.progress = 0.0
		game.doors.D5.target_open = false
		for region in game.Map.REGIONS:
			if region != "R4": game.water_depths[region] = 2.2
		game.explorers[1].state = "escaped"
		game.expedition.duration = 1800.0
		game.tick = 1800 * 20 - 2500
		for i in range(2500): game.step()
		check(game.water_depths.R4 == 0.0 and game.explorers[0].breath == 20.0, "Sealed refuge dry through maximum exterior and finale")
		check(game.finished and game.explorers[0].state == "stranded", "Shelter survives water but is not extraction")
func test_puzzles_and_loot() -> void:
	var game = fixture()
	var systems = game.expedition
	check(not event(game, 0, "chest", "T7"), "Remote chest cannot be opened")
	place(game, 0, systems.chests.T0.position + Vector2(0, 30))
	check(event(game, 0, "chest", "T0"), "Nearby rune puzzle opens")
	var puzzle: Dictionary = systems.puzzles[0]
	var nonce: int = puzzle.nonce
	check(not puzzle_press(game, 0, puzzle.sequence[0]), "Runes require memorization interval")
	game.tick += 50
	check(not event(game, 0, "puzzle", "T0:0:0"), "Puzzle nonce injection rejected")
	for index in range(4):
		game.tick += 4
		check(puzzle_press(game, 0, puzzle.sequence[index]), "Ordered rune press accepted")
	check(systems.chests.T0.opened and game.explorers[0].gear.map, "Rune solution grants actual map")
	var treasure: int = game.explorers[0].treasure
	check(treasure > 0 and not event(game, 0, "chest", "T0"), "Solved chest cannot multiply treasure")
	place(game, 1, systems.chests.T0.position + Vector2(20, 30))
	check(event(game, 1, "chest", "T0") and game.explorers[1].gear.map, "Companion collects one shared provision")
	check(game.explorers[1].treasure == 0, "Shared provision does not duplicate solver treasure")
	place(game, 0, systems.chests.T1.position + Vector2(0, 25))
	check(event(game, 0, "chest", "T1"), "Circuit puzzle opens")
	puzzle = systems.puzzles[0]
	for index in range(3):
		if puzzle.target_bits & (1 << index):
			game.tick += 4
			check(puzzle_press(game, 0, index), "Circuit switch is authoritative")
	check(game.explorers[0].gear.chart and systems.chests.T1.opened, "Circuit yields treasure bearing")
	place(game, 0, systems.chests.T2.position + Vector2(0, 25))
	check(event(game, 0, "chest", "T2"), "Pressure puzzle opens")
	puzzle = systems.puzzles[0]
	check(not puzzle_press(game, 0, 9), "Pressure rejects forged control")
	for hit in range(3):
		game.tick = puzzle.started_tick + int((2.6 * puzzle.pressure_target + hit * 5.2) / Rules.STEP)
		check(puzzle_press(game, 0, 0), "Actual pressure phase accepts timed hit")
	check(systems.chests.T2.opened and game.explorers[0].tank == 55.0, "Pressure solution supplies oxygen")
	check(not event(game, 0, "puzzle", "T2:%d:0" % nonce), "Finished puzzle lease is gone")
	place(game, 0, systems.chests.T3.position + Vector2(0, 25))
	check(event(game, 0, "chest", "T3"), "Another rune chest opens")
	place(game, 0, game.Map.spawn(0))
	game.step()
	check(not systems.puzzles.has(0), "Walking away releases puzzle lease")
func test_survival_and_equipment() -> void:
	var game = fixture()
	var player: Dictionary = game.explorers[0]
	var door: Vector2 = game.Map.door_position("D0")
	var direction: Vector2 = game.Map.region_center("C0").direction_to(game.Map.region_center("R0"))
	place(game, 0, door + direction * 22)
	game.water_depths.C0 = 2.2
	var before: Vector2 = player.position
	var no_tank: Vector2 = game.Map.move(before, -direction, 0.25, [], 0.0, game.water_depths, false, false)
	check(game.Map.region_at(no_tank) == "R0", "Submerged route blocks an unequipped explorer")
	var with_tank: Vector2 = game.Map.move(before, -direction, 0.25, [], 0.0, game.water_depths, false, true)
	check(game.Map.region_at(with_tank) == "C0", "Oxygen permits submerged entry")
	check(game.Map.move(before, -direction, 0.25, ["D0"], 0.0, game.water_depths, false, true) != with_tank, "Oxygen does not bypass shut gates")
	place(game, 0, game.Map.region_center("R0"))
	game.water_depths.R0 = 1.5
	player.gear.oxygen = true
	player.tank = 0.1
	game.expedition.breathe(game, 0, 1.5)
	check(is_equal_approx(player.tank, 0.05) and player.breath == 20.0, "Tank is consumed before natural breath")
	game.expedition.breathe(game, 0, 1.5)
	game.expedition.breathe(game, 0, 1.5)
	check(player.tank <= 0.0 and player.breath < 20.0, "Tank exhaustion drains breath")
	game.expedition.gas.R0 = 100.0
	player.gear.mask = true
	game.expedition.breathe(game, 0, 0.0)
	check(player.health == 3, "Mask protects against toxic air")
	player.gear.mask = false
	game.expedition.breathe(game, 0, 0.0)
	check(player.health == 2, "Unprotected gas causes injury")
	player.gear.medkit = 1
	check(event(game, 0, "heal") and player.health == 3 and player.gear.medkit == 0, "Medkit heals one heart and is consumed")
	check(not event(game, 0, "heal"), "No free repeated healing")
	game.lantern.holder = 0
	player.has_light = true
	game.relic.state = "carried"
	game.relic.holder = 0
	player.has_relic = true
	player.breath = 0.01
	player.tank = 0
	game.expedition.breathe(game, 0, 2.2)
	check(player.state == "drowned" and not player.has_light and not player.has_relic, "Drowning releases held objects")
func test_shots_hunts_and_extraction() -> void:
	var game = fixture()
	var own: Dictionary = game.explorers[0]
	var other: Dictionary = game.explorers[1]
	own.gear.gun = true
	own.ammo = 4
	place(game, 0, game.Map.region_center("R0"))
	place(game, 1, own.position + Vector2(0, 100))
	check(event(game, 0, "fire", "0") and other.stun_until > game.tick and own.ammo == 3, "Dart stuns nearby player and consumes ammunition")
	check(not event(game, 0, "fire", "0"), "Shot cooldown cannot be bypassed")
	check(game.expedition.movement_factor(game, 1) == 0.0, "Stunned player loses movement briefly")
	game.tick += 140
	check(game.expedition.movement_factor(game, 1) == 1.0, "Stun expires to normal movement")
	place(game, 1, game.Map.region_center("R1"))
	game.tick += 30
	check(event(game, 0, "fire", "6") and other.stun_until <= game.tick, "Shot cannot cross wall or exceed range")
	var monster := {"id": 99, "position": own.position + Vector2(0, 100), "velocity": Vector2.ZERO, "stun_until": -1, "route": [], "target": 0, "path_tick": -100, "attack_until": -1, "spawned_tick": game.tick, "last_seen_tick": game.tick, "last_seen_position": own.position}
	game.expedition.monsters.append(monster)
	game.tick += 30
	check(event(game, 0, "fire", "0") and monster.stun_until > game.tick, "Dart also stuns a monster")
	game.tick += 140
	game.expedition.advance_hunters(game)
	check(monster.velocity.length() > 0, "Hunter moves toward a survivor")
	game.tick += 1200
	game.expedition.advance_hunters(game)
	check(game.expedition.monsters.size() == 1 and monster.target == 0, "Visible assigned hunter stays beyond the old wave duration")
	place(game, 0, game.Map.region_center("R11"))
	game.expedition.advance_hunters(game)
	check(game.expedition.monsters.is_empty(), "Escaping pursuit range permits a rest phase")
	own.health = 1
	check(game.expedition.movement_factor(game, 0) < 1.0, "Serious injury changes movement")
	own.health = 3
	place(game, 0, game.Map.extraction_position())
	own.treasure = 73
	check(game.begin_extraction(0, game.event_sequences[0] + 1), "Treasure can be extracted at physical boat")
	for i in range(40):
		game.keep_interaction(0, game.event_sequences[0] + 1)
		game.step()
	check(own.state == "escaped" and own.score == 73 and own.treasure == 0, "Only completed extraction banks treasure once")
	check(not game.begin_extraction(0, game.event_sequences[0] + 1) and own.score == 73, "Banking cannot repeat")
func test_directory() -> void:
	var directory := Directory.new()
	check(directory.create_room(10, 4, "lagoon") and directory.join_room(20, directory.members[10]), "Production waiting room joins")
	check(not directory.start_room(10), "Ready states precede starting")
	check(not directory.select_map(20, "foundry"), "Only host chooses map")
	check(directory.select_map(10, "foundry"), "Host changes among three maps")
	check(directory.set_ready(10, true) and directory.set_ready(20, true), "Each connection readies itself")
	check(directory.start_room(10), "Ready humans enter chosen level")
	var room: Dictionary = directory.rooms[directory.members[10]]
	check(room.game.Map.id == "foundry", "Authority runs selected map")
	check(directory.create_room(30, 2, "catacombs"), "Independent second room")
	check(directory.rooms[directory.members[30]].staging_map.id == "catacombs" and room.game.Map.id == "foundry", "Concurrent map choice never mutates another room")
	var command := {"kind": "heal", "target": "", "sequence": 0, "match_id": room.match_id, "health": 3}
	check(not directory.accept_event(10, command), "Client cannot inject health")
	command.erase("health")
	command.match_id = "old"
	check(not directory.accept_event(10, command), "Stale gear event cannot affect match")
