extends SceneTree
## Production round over real sockets: walk in lobby, select map, solve/claim
## chests, reveal only owned knowledge, and physically extract. No teleports.
var role := "client"
var count := 2
var port := 24630
var map_id := "lagoon"
var scene
var ending := false
var joining := false
var selected := false
var ready_sent := false
var started := false
var began := 0
var waiting_steps := 0
var waiting_origin := Vector2.ZERO
var accumulator := 0.0
var stage := "waiting"
var path: Array[Vector2] = []
var next_action_tick := -1
var checks := 0
var failures := 0
var loot_value := 0
var saw_private_puzzle := false
var checked_lobby := false
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.substr(7)
		elif arg.begins_with("--count="): count = int(arg.substr(8))
		elif arg.begins_with("--port="): port = int(arg.substr(7))
		elif arg.begins_with("--map="): map_id = arg.substr(6)
	call_deferred("run")
func run() -> void:
	began = Time.get_ticks_msec()
	scene = load("res://scenes/main.tscn").instantiate()
	scene.auto_connect = false
	root.add_child(scene)
	scene.set_process(false)
	check(scene.start_screen.visible, "Public game begins on Start")
	scene.session.server_url = "ws://127.0.0.1:%d" % port
	scene.session.rooms_changed.connect(func(rooms):
		if role != "host" and not joining and not rooms.is_empty():
			joining = true
			scene.session.join_room(rooms[0].code))
	scene.session.lobby_changed.connect(lobby)
	scene.session.view_changed.connect(view)
	scene.session.connection_error.connect(func(message):
		check(false, message)
		finish())
	if role == "host": scene.session.create_room(count, "lagoon")
	else: scene.session.refresh_rooms()
func lobby(info: Dictionary) -> void:
	if ending: return
	if role == "host" and info.map_id != map_id and not selected:
		selected = true
		scene.session.select_map(map_id)
	if info.map_id != map_id: return
	if not checked_lobby:
		checked_lobby = true
		waiting_origin = info.staging_view.explorers[info.player].position
		check(info.staging_view.phase == "waiting" and scene.Map.id == map_id, "Selected large map binds waiting room")
		check(scene.waiting_panel.visible and scene.map_buttons.size() == 3, "Lobby has native ready and three-map selection")
	if waiting_steps >= 30 and not ready_sent:
		ready_sent = true
		check(info.staging_view.explorers[info.player].position.distance_to(waiting_origin) > 80.0, "Lobby walking is acknowledged by authority")
		check(info.staging_view.ack_sequence >= 20, "Lobby uses direction/sequence acknowledgements")
		scene.session.set_ready(true)
	if role == "host" and info.count == count and info.can_start and not started:
		started = true
		scene.session.start_match()
func follow_path() -> Vector2:
	while not path.is_empty() and scene.prediction.position.distance_to(path[0]) < 5.0 and scene.game.explorers[scene.active_player].position.distance_to(path[0]) < 5.0:
		path.pop_front()
	return Vector2.ZERO if path.is_empty() else (path[0] - scene.prediction.position) / 8.5
func set_goal(chest_id: String) -> void:
	path.assign([scene.Map.chest_anchors[chest_id].position + Vector2(0, 24)])
func solve() -> void:
	var challenge: Dictionary = scene.game.puzzle
	if challenge.is_empty(): return
	saw_private_puzzle = true
	var action := -1
	match challenge.kind:
		"runes":
			if scene.game.tick - challenge.started_tick >= 52:
				action = challenge.sequence[challenge.progress]
		"circuit":
			for bit in range(3):
				if (challenge.bits ^ challenge.target_bits) & (1 << bit):
					action = bit
					break
		"pressure":
			var phase_value := fmod(float(scene.game.tick - challenge.started_tick) * 0.05 / 2.6, 2.0)
			var value := phase_value if phase_value <= 1.0 else 2.0 - phase_value
			if absf(value - challenge.pressure_target) < 0.06: action = 0
	if action >= 0:
		scene._send_interaction("puzzle", "%s:%d:%d" % [challenge.chest, challenge.nonce, action])
func _process(delta: float) -> bool:
	if ending: return false
	if began > 0 and Time.get_ticks_msec() - began > 65000:
		check(false, "Production expedition timed out at %s" % stage)
		finish()
	if scene == null or scene.game == null: return false
	accumulator += minf(delta, 0.25)
	while accumulator >= 0.05:
		accumulator -= 0.05
		if scene.phase == "waiting":
			if scene.Map.id != map_id: continue
			var direction := Vector2.UP if waiting_steps < 20 else Vector2.RIGHT if waiting_steps < 28 else Vector2.ZERO
			waiting_steps += 1
			scene._step_movement(direction)
			continue
		if scene.phase != "running": continue
		var own: Dictionary = scene.game.explorers[scene.active_player]
		if own.state != "exploring": continue
		var direction := follow_path()
		if path.is_empty():
			var chest_id := "T0" if stage == "map" else "T1"
			if stage in ["map", "chart"]:
				var item := "map" if stage == "map" else "chart"
				if own.gear[item]:
					check(own.last_loot == item, "Provision collected once through validated chest event")
					stage = "chart" if stage == "map" else "return"
					if stage == "chart": set_goal("T1")
					else:
						loot_value = own.treasure
						check(own.gear.map and own.gear.chart, "Both exploration tools are owned")
						check(not scene.game.treasure_bearing.is_empty(), "Owned chart supplies a static treasure goal")
						path.assign([scene.Map.extraction_position()])
				elif scene.game.tick >= next_action_tick:
					next_action_tick = scene.game.tick + 8
					if role == "host" and not scene.game.puzzle.is_empty(): solve()
					elif scene.game.chests.get(chest_id, {}).get("opened", false) or role == "host":
						scene._send_interaction("chest", chest_id)
			elif stage == "return":
				stage = "extract"
				scene._use_nearest()
				check(scene.interaction_hold_active, "Extraction requires a physical held interaction at the boat")
		scene._step_movement(direction)
	return false
func view(snapshot: Dictionary) -> void:
	if ending: return
	if snapshot.phase == "aborted":
		check(false, "Unexpected production abort")
		finish()
		return
	var who: int = snapshot.you
	if stage == "waiting" and snapshot.phase == "running":
		stage = "map"
		check(snapshot.map_id == map_id and snapshot.duration >= 600 and snapshot.duration <= 1800, "Authority starts selected 10–30 minute level")
		check(scene.camera.zoom == Vector2.ONE * 2.6 and scene.hud.visible, "Production camera uses the approved reference scale and icon HUD")
		check(snapshot.match_id != scene.lobby_info.staging_view.match_id, "Round uses a fresh match token")
		set_goal("T0")
	for i in range(snapshot.explorers.size()):
		if i == who: continue
		var other: Dictionary = snapshot.explorers[i]
		for field in ["gear", "health", "ammo", "tank", "treasure", "score", "breath"]:
			check(not other.has(field), "Actual rival packet excludes private survival field")
		if other.state == "hidden": check(other.size() == 2, "Hidden actual packet contains no position")
	if role != "host": check(snapshot.puzzle.is_empty(), "Owner's private puzzle never enters other sockets")
	if snapshot.phase == "finished":
		check(snapshot.results.size() == count and snapshot.winners == [0], "Clients agree on one treasure solver and complete outcome")
		for i in range(count):
			var result: Dictionary = snapshot.results[i]
			check(result.state == "escaped", "Every player physically escaped")
			check(result.score > 0 if i == 0 else result.score == 0, "Shared provisions never duplicate treasure value")
		check(snapshot.results[who].score == loot_value, "Only physically extracted treasure is banked")
		check(saw_private_puzzle if role == "host" else not saw_private_puzzle, "Private puzzle delivery matches its owner")
		check(scene.results_panel.visible and not scene.hud.visible, "Finished round replaces play HUD with real outcome")
		finish()
func finish() -> void:
	if ending: return
	ending = true
	await create_timer(0.5).timeout
	scene.session.close()
	print("Online large-expedition %s %d %s: %d checks, %d failures" % [map_id, count, role, checks, failures])
	quit(1 if failures else 0)
