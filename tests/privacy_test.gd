extends SceneTree
const Rules = preload("res://scripts/game.gd")
const View = preload("res://scripts/player_view.gd")
const Map = preload("res://scripts/level_map.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _init() -> void:
	var game := Rules.new(1, 4)
	game.explorers[1].position = Map.from_art(Vector2(280, 450))
	game.explorers[1].region = "C0"
	game.explorers[2].position = Map.from_art(Vector2(1295, 742))
	game.explorers[2].region = "R4"
	for who in range(4):
		var packet: Dictionary = bytes_to_var(var_to_bytes(View.project(game, who, "token")))
		check(packet.you == who and packet.match_id == "token", "Recipient and match scope")
		for i in range(4):
			var p: Dictionary = packet.explorers[i]
			var local: bool = i == who or Map.can_see(game.explorers[who].position, game.explorers[i].position, game.explorers[who].has_light)
			check(p.has("position") == local, "Serialized remote coordinates omitted")
			check(p.has("region") == local and p.has("velocity") == local, "Remote region and velocity omitted")
			check(not p.has("input") and not p.has("inventory") and not p.has("bank"), "Private simulation/inventory/score not sent")
		check(not packet.has("inputs") and not packet.has("game"), "No full rules packet")
	game.explorers[1].position = Map.spawn(1)
	game.explorers[1].region = "R0"
	var together := View.project(game, 0)
	check(together.explorers[1].has("position"), "Arrival makes local rival visible")
	game.explorers[1].region = "C0"
	game.explorers[1].position = Map.from_art(Vector2(280, 450))
	var apart := View.project(game, 0)
	check(apart.explorers[1] == {"name": "P2", "state": "hidden"}, "Leaving sight removes all location data")
	together.explorers[0].position = Vector2.ZERO
	check(game.explorers[0].position != Vector2.ZERO, "Projection is independent of authority")
	game.explorers[0].position = Map.from_art(Vector2(1030, 460))
	game.explorers[0].region = "C1"
	game.explorers[1].position = Map.from_art(Vector2(1230, 460))
	game.explorers[1].region = "C1"
	check(View.project(game, 0).explorers[1].state == "hidden", "Same corridor outside dark vision stays private")
	game.explorers[0].has_light = true
	check(View.project(game, 0).explorers[1].has("position"), "Carried light reveals a farther rival")
	game.explorers[0].position = Map.from_art(Vector2(850, 460))
	game.explorers[1].position = Map.from_art(Vector2(850, 266))
	game.explorers[1].region = "R2"
	check(View.project(game, 0).explorers[1].state == "hidden", "Wall conceals nearby rival within light radius")
	game.explorers[0].position = Map.from_art(Vector2(790, 320))
	game.explorers[1].position = Map.from_art(Vector2(790, 280))
	check(View.project(game, 0).explorers[1].has("position"), "Open doorway permits physical sight across region ids")
	check(View.project(game, 0).lantern.is_empty(), "Distant ground light coordinates omitted")
	game.doors.D3.progress = 0.0
	game.doors.D3.target_open = false
	var behind_gate := bytes_to_var(var_to_bytes(View.project(game, 0))) as Dictionary
	check(behind_gate.explorers[1].state == "hidden", "Closed physical door removes rival coordinates")
	check(not behind_gate.water_depths.has("R2"), "Closed door conceals the room's water state")
	check(behind_gate.doors.has("D3") and not behind_gate.doors.has("D5"), "Visible door state sent without distant gate state")
	game.doors.D5.progress = 0.0
	game.doors.D5.target_open = false
	game.explorers[0].position = Map.door_position("D5") - Vector2(0, 35)
	game.explorers[0].region = "C1"
	var outside := View.project(game, 0)
	check(not outside.water_depths.has("R4") and not outside.doors.D5.sealed_safe, "Outside observer receives no refuge interior water indicator")
	game.explorers[0].position = Map.door_position("D5") + Vector2(0, 35)
	game.explorers[0].region = "R4"
	var inside := View.project(game, 0)
	check(inside.water_depths.has("R4") and inside.doors.D5.sealed_safe, "Sheltered observer sees own dry sealed refuge")
	game.explorers[0].position = Map.relic_position()
	game.explorers[0].region = "R3"
	game.explorers[1].position = Map.relic_position() + Vector2(20, 0)
	game.explorers[1].region = "R3"
	game.doors.D4.locked = false
	game.use_relic(1, "take_relic", 0)
	var held := bytes_to_var(var_to_bytes(View.project(game, 0))) as Dictionary
	check(held.explorers[1].has_relic and held.relic.is_empty(), "Visible holder shows relic artwork without a second ground relic")
	check(not held.explorers[1].has("score") and not held.explorers[1].has("breath") and not held.has("results"), "Even visible rivals retain private breath and score until final results")
	game.explorers[0].position = Map.spawn(0)
	game.explorers[0].region = "R0"
	var remote := bytes_to_var(var_to_bytes(View.project(game, 0))) as Dictionary
	check(remote.explorers[1] == {"name": "P2", "state": "hidden"} and remote.relic.is_empty() and remote.vault.is_empty(), "Unseen relic holder and remote vault controls reveal no data")
	game.use_relic(1, "drop_relic", 1)
	check(View.project(game, 0).relic.is_empty(), "Unseen dropped relic coordinates remain private")
	game.explorers[0].position = Map.door_position("D4") + Vector2(0, 35)
	game.explorers[0].region = "C1"
	game.doors.D4.progress = 0.0
	check(View.project(game, 0).relic.is_empty(), "Shut gate conceals nearby pedestal or dropped relic")
	game.explorers[1].state = "escaped"
	check(View.project(game, 0).explorers[1].state == "hidden", "Remote escape outcome stays private during the expedition")
	game.tick = int(game.EXPEDITION_LENGTH / game.STEP) - 1
	game.step()
	var final := bytes_to_var(var_to_bytes(View.project(game, 0))) as Dictionary
	check(final.phase == "finished" and final.results.size() == 4 and final.results[1].state == "escaped", "Final scores and outcomes become public at completion")
	check(not final.results[1].has("position") and not final.results[1].has("inventory"), "Public results do not disclose full simulation or coordinates")
	print("Privacy: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
