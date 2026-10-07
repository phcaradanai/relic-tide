extends SceneTree
const Rules = preload("res://scripts/game.gd")
const View = preload("res://scripts/player_view.gd")
const Maps = preload("res://scripts/expedition_map.gd")
const Prediction = preload("res://scripts/movement_client.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func packet(game, who: int) -> Dictionary:
	# Assert actual transport-serializable data, rather than trusting node hiding.
	return bytes_to_var(var_to_bytes(View.project(game, who, "private-test")))
func place(game, who: int, position: Vector2) -> void:
	game.explorers[who].position = position
	game.explorers[who].region = game.Map.region_at(position)
func _init() -> void:
	for map_id in Maps.PRODUCTION_IDS:
		var game := Rules.new(7, 3, map_id)
		var own: Dictionary = game.explorers[0]
		var other: Dictionary = game.explorers[1]
		place(game, 0, game.Map.region_center("R0"))
		place(game, 1, own.position + Vector2(0, 110))
		# R3 is distant from R0 on all three layouts; R11 neighbours R0 on
		# the foundry and catacomb routes and is legitimately observable.
		place(game, 2, game.Map.region_center("R3"))
		own.gear.map = true
		own.gear.chart = true
		other.health = 1
		other.gear.gun = true
		other.ammo = 12
		other.treasure = 999
		game.expedition.monsters.assign([{"id": 1, "position": own.position + Vector2(80, 0), "velocity": Vector2.LEFT, "stun_until": -1, "attack_until": -1, "route": [game.Map.region_center("R3")], "target": 2}, {"id": 2, "position": game.Map.region_center("R3"), "velocity": Vector2.ZERO, "stun_until": -1, "attack_until": -1, "route": [own.position], "target": 0}])
		game.expedition.puzzles[1] = {"chest": "T0", "nonce": 778899, "kind": "runes", "sequence": [0, 1, 2, 3], "progress": 1}
		var data := packet(game, 0)
		check(data.map_id == map_id and data.duration >= 600 and data.duration <= 1800, "Public map and clock metadata is accurate")
		check(data.explorers[0].health == 3 and data.explorers[0].gear.map, "Own survival inventory is available")
		check(data.explorers[1].has("position"), "Nearby lit rival is observable")
		for field in ["health", "gear", "ammo", "treasure", "tank", "breath", "score", "stun_until", "hurt_until"]:
			check(not data.explorers[1].has(field), "Rival private field excluded: " + field)
		check(data.explorers[2].size() == 2 and data.explorers[2].state == "hidden", "Unseen player has only identity/hidden state")
		check(data.monsters.size() == 1 and data.monsters[0].id == 1, "Hidden monster position never enters packet")
		for field in ["route", "target", "path_tick", "stun_until", "attack_until"]: check(not data.monsters[0].has(field), "Visible monster internals remain private")
		check(data.puzzle.is_empty(), "Another player's puzzle/nonce is not broadcast")
		check(not data.has("inputs") and not data.has("region_areas") and not data.has("event_sequences"), "Snapshot never includes full simulation")
		check(not data.chests.has("T7"), "Hidden treasure chest is not disclosed")
		check(not data.chests.T0.has("loot") and not data.chests.T0.has("treasure"), "Unsolved chest does not disclose inventory reward")
		var rival := packet(game, 1)
		check(rival.puzzle.get("nonce", 0) == 778899 and rival.treasure_bearing.is_empty(), "Owner alone receives challenge and owned chart")
		game.relic.state = "carried"
		game.relic.holder = 2
		game.explorers[2].has_relic = true
		var bearing_a: Dictionary = packet(game, 0).treasure_bearing
		place(game, 2, game.Map.region_center("R8"))
		var bearing_b: Dictionary = packet(game, 0).treasure_bearing
		check(bearing_a == bearing_b, "Chart never tracks hidden relic carrier")
		game.doors.D0.progress = 0.0
		game.doors.D0.target_open = false
		place(game, 1, game.Map.region_center("C0"))
		check(packet(game, 0).explorers[1].state == "hidden", "Shut physical gate hides a corridor actor")
		game.doors.D0.progress = 1.0
		game.doors.D0.target_open = true
		var room_center: Vector2 = game.Map.region_center("R0")
		var passage_center: Vector2 = game.Map.region_center("C0")
		var along := room_center.direction_to(passage_center)
		place(game, 0, game.Map.door_position("D0") - along * 70)
		place(game, 1, game.Map.door_position("D0") + along * 220)
		game.Map.room_power.C0 = false
		check(packet(game, 0).explorers[1].state == "hidden", "Powered observer cannot reveal distant dark target")
		game.explorers[0].has_light = true
		check(packet(game, 0).explorers[1].has("position"), "Physically held lantern extends into dark passage")
		game.Map.room_power.C0 = true
		game.explorers[0].has_light = false
		check(packet(game, 0).explorers[1].has("position"), "Restored power expands normal visibility")
		var prediction := Prediction.new()
		prediction.reset(packet(game, 0))
		check(prediction.Map.id == map_id and prediction.Map.SIZE == Vector2(3840, 2560), "Prediction binds the authoritative map")
		var different := Rules.new(7, 2, "catacombs" if map_id != "catacombs" else "foundry")
		var next := packet(different, 0)
		next.match_id = "different"
		prediction.reconcile(next)
		check(prediction.Map.id == different.Map.id and game.Map.id == map_id, "New match cannot mutate another map instance")
	print("Large expedition privacy: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
