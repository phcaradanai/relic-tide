extends SceneTree
const Directory = preload("res://scripts/room_directory.gd")
var checks := 0
var failures := 0
var packets: Array = []
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _init() -> void:
	var directory := Directory.new()
	directory.packet.connect(func(peer, kind, data): packets.append({"peer": peer, "kind": kind, "data": data}))
	check(not directory.create_room(10, 1) and not directory.create_room(10, 5), "Capacity constrained")
	check(directory.create_room(10, 4), "Creator room")
	var code: String = directory.members[10]
	check(code.length() == 6, "Six-character code")
	check(not directory.start_room(10), "No single-player online match")
	check(directory.join_room(20, code.to_lower()), "Code join")
	check(not directory.start_room(20), "Only creator starts")
	check(directory.start_room(10), "Two humans start")
	var room: Dictionary = directory.rooms[code]
	var command := {"direction": Vector2.RIGHT, "sequence": 0, "match_id": room.match_id}
	check(not directory.accept_input(99, command), "Outsider cannot control a seat")
	check(directory.accept_input(20, command), "Connection controls its own seat")
	check(not directory.accept_input(20, command), "Duplicate input ignored")
	command.sequence = 1
	command.position = Vector2.ZERO
	check(not directory.accept_input(20, command), "Client position injection rejected")
	command.erase("position")
	command.player = 0
	check(not directory.accept_input(20, command), "Identity injection rejected")
	command.erase("player")
	command.match_id = "stale"
	check(not directory.accept_input(20, command), "Previous match packet rejected")
	command.match_id = room.match_id
	command.direction = Vector2(NAN, 0)
	check(not directory.accept_input(20, command), "NaN input rejected")
	command.direction = Vector2(10, 0)
	check(not directory.accept_input(20, command), "Overspeed rejected")
	command.direction = "right"
	check(not directory.accept_input(20, command), "Wrong direction type rejected")
	var event := {"kind": "take_light", "target": "", "sequence": 0, "match_id": room.match_id}
	check(not directory.accept_event(99, event), "Outsider cannot claim a light")
	check(directory.accept_event(10, event), "Connection claims nearby lantern")
	check(not directory.accept_event(20, event), "Another peer cannot duplicate held lantern")
	event.kind = "drop_light"
	event.sequence = 1
	event.player = 0
	check(not directory.accept_event(20, event), "Light-holder identity cannot be injected")
	event.erase("player")
	check(not directory.accept_event(20, event), "Nonholder cannot drop another player's light")
	check(directory.accept_event(10, event), "Holder drop accepted by authority")
	check(not directory.accept_event(10, event), "Repeated event rejected")
	var door_event := {"kind": "toggle_door", "target": "D5", "sequence": 2, "match_id": room.match_id}
	check(not directory.accept_event(10, door_event), "Remote door command rejected")
	room.game.explorers[0].position = Directory.Rules.Map.door_position("D5") + Vector2(0, 35)
	room.game.explorers[0].region = "R4"
	door_event.sequence = 3
	check(directory.accept_event(10, door_event), "Server derives the nearby door operator from the connection")
	door_event.sequence = 4
	door_event.progress = 0.0
	check(not directory.accept_event(10, door_event), "Client cannot inject authoritative door progress")
	door_event.erase("progress")
	door_event.target = 5
	check(not directory.accept_event(10, door_event), "Wrong target type rejected")
	room.game.explorers[0].position = Directory.Rules.Map.spawn(0)
	room.game.explorers[0].region = "R0"
	var before: Vector2 = room.game.explorers[1].position
	for i in range(2): directory.step()
	check(room.game.tick == 2 and room.game.explorers[1].position.x > before.x, "Clock progresses without all-player input")
	check(room.game.explorers[0].position == Directory.Rules.Map.spawn(0), "Silent creator remains still")
	check(packets.any(func(p): return p.peer == 10 and p.kind == "view" and p.data.tick == 2), "10Hz addressed snapshots")
	check(not directory.join_room(30, code), "Running room cannot be joined")
	packets.clear()
	directory.disconnected(20)
	check(room.phase == "aborted", "Participant disconnect ends this match")
	check(packets.any(func(p): return p.peer == 10 and p.kind == "view" and p.data.phase == "aborted"), "Remaining member notified")
	var last_tick: int = room.game.tick
	directory.step()
	check(room.game.tick == last_tick, "Aborted room no longer advances")
	directory.disconnected(10)
	check(directory.rooms.is_empty() and directory.members.is_empty(), "Empty running room cleaned up")
	check(directory.create_room(40, 2) and directory.join_room(50, directory.members[40]), "New lobby after cleanup")
	packets.clear()
	directory.disconnected(40)
	check(not directory.members.has(50) and packets.any(func(p): return p.peer == 50 and p.kind == "closed"), "Creator leave closes lobby")
	# Rate limiting drops floods without slowing simulation or sharing buckets.
	directory.create_room(60, 2)
	directory.join_room(70, directory.members[60])
	directory.start_room(60)
	room = directory.rooms[directory.members[60]]
	for i in range(100): directory.request(60, "input", {"direction": Vector2.ZERO, "sequence": i, "match_id": room.match_id})
	check(room.game.inputs[0].sequence == 39, "Movement packet budget")
	packets.clear()
	directory.request(60, "list", {})
	check(packets.any(func(p): return p.kind == "rooms"), "Movement flood does not consume lobby budget")
	var loop := Directory.new()
	loop.create_room(80, 2)
	loop.join_room(90, loop.members[80])
	loop.start_room(80)
	var expedition: Dictionary = loop.rooms[loop.members[80]]
	var rules = expedition.game
	var map = Directory.Rules.Map
	var use := {"kind": "begin_vault", "target": "A", "sequence": 0, "match_id": expedition.match_id}
	rules.explorers[0].position = map.vault_control_position("A")
	rules.explorers[0].region = "C1"
	rules.explorers[1].position = map.vault_control_position("B")
	rules.explorers[1].region = "C1"
	check(loop.accept_event(80, use), "Connection-derived first vault operator")
	use.target = "B"
	use.sequence = 1
	check(not loop.accept_event(80, use), "A connection cannot claim both cooperative controls")
	use.sequence = 0
	check(loop.accept_event(90, use), "Distinct peer claims the second control")
	for i in range(30):
		for peer in [80, 90]:
			var who: int = expedition.peers.find(peer)
			loop.accept_event(peer, {"kind": "keep_interaction", "target": "", "sequence": rules.event_sequences[who] + 1, "match_id": expedition.match_id})
		loop.step()
	check(not rules.doors.D4.locked, "Authority advances two-peer unlocking without client progress")
	rules.doors.D4.progress = 1.0
	rules.explorers[0].position = map.relic_position()
	rules.explorers[0].region = "R3"
	use.kind = "take_relic"
	use.target = ""
	use.sequence = rules.event_sequences[0] + 1
	use.score = 10000
	check(not loop.accept_event(80, use), "Injected relic score rejected by exact event schema")
	use.erase("score")
	use.match_id = "stale"
	check(not loop.accept_event(80, use), "Stale relic event rejected")
	use.match_id = expedition.match_id
	check(loop.accept_event(80, use) and rules.relic.holder == 0, "Validated pickup owns one server relic")
	check(not loop.accept_event(80, use), "Duplicate relic packet cannot duplicate ownership")
	rules.explorers[0].position = map.extraction_position()
	rules.explorers[0].region = "R0"
	use.kind = "begin_extraction"
	use.sequence += 1
	check(loop.accept_event(80, use), "Peer begins nearby extraction")
	for i in range(40):
		loop.accept_event(80, {"kind": "keep_interaction", "target": "", "sequence": rules.event_sequences[0] + 1, "match_id": expedition.match_id})
		loop.step()
	check(rules.explorers[0].score == 100 and rules.explorers[0].state == "escaped", "Authority alone banks completed extraction")
	use.kind = "drop_relic"
	use.sequence = rules.event_sequences[0] + 1
	check(not loop.accept_event(80, use), "Terminal peer cannot create another relic")
	rules.tick = int(rules.EXPEDITION_LENGTH / rules.STEP) - 1
	loop.step()
	check(expedition.phase == "finished", "Room lifecycle transitions to finished at deadline")
	loop.disconnected(80)
	check(expedition.phase == "finished" and rules.results[0].score == 100, "Completed results survive peer departure")
	loop.disconnected(90)
	check(loop.rooms.is_empty(), "Completed room is removed after its last member leaves")
	print("Authority: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
