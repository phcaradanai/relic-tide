extends SceneTree
## A complete expedition through real WebSocket clients, without server teleports.
const Map = preload("res://scripts/level_map.gd")
var role := "client"
var count := 2
var port := 24610
var scene
var joining := false
var ending := false
var began := 0
var accumulator := 0.0
var stage := "approach"
var path: Array[Vector2] = []
var checks := 0
var failures := 0
var first_holder := -1
var attempted_pickup := false
var dropped := false
var reclaimed := false
var saw_unlock := false
var saw_relic := false
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
	call_deferred("run")
func run() -> void:
	began = Time.get_ticks_msec()
	scene = load("res://scenes/main.tscn").instantiate()
	scene.auto_connect = false
	root.add_child(scene)
	scene.set_process(false)
	scene.session.server_url = "ws://127.0.0.1:%d" % port
	scene.session.rooms_changed.connect(func(rooms):
		if role != "host" and not joining and not rooms.is_empty():
			joining = true
			scene.session.join_room(rooms[0].code))
	scene.session.lobby_changed.connect(func(info):
		if role == "host" and info.count == count: scene.session.start_match())
	scene.session.view_changed.connect(view)
	scene.session.connection_error.connect(func(message):
		check(false, message)
		finish())
	if role == "host": scene.session.create_room(count)
	else: scene.session.refresh_rooms()
func follow_path() -> Vector2:
	while not path.is_empty() and scene.prediction.position.distance_to(path[0]) < 3 and scene.game.explorers[scene.active_player].position.distance_to(path[0]) < 3:
		path.pop_front()
	if path.is_empty(): return Vector2.ZERO
	return (path[0] - scene.prediction.position) / 8.5
func _process(delta: float) -> bool:
	if ending: return false
	if began > 0 and Time.get_ticks_msec() - began > 95000:
		check(false, "Expedition timed out at %s position %s" % [stage, scene.prediction.position])
		finish()
	if scene == null or scene.intro or scene.phase != "running": return false
	if scene.game.explorers[scene.active_player].state != "exploring": return false
	accumulator += minf(delta, 0.25)
	while accumulator >= 0.05:
		accumulator -= 0.05
		var direction := follow_path()
		var who: int = scene.active_player
		if path.is_empty():
			match stage:
				"approach":
					stage = "control"
					if who < 2:
						scene.interaction_hold_active = true
						scene._send_interaction("begin_vault", "A" if who == 0 else "B")
				"control":
					if saw_unlock:
						stage = "vault"
						path = [Map.from_art(Vector2(1297, 350)), Map.relic_position()]
				"vault": stage = "contest"
				"contest":
					if scene.game.tick >= 600 and who < 2 and not attempted_pickup:
						attempted_pickup = true
						scene._send_interaction("take_relic")
					if scene.game.tick >= 620 and scene.game.explorers[who].has_relic and not dropped and first_holder == who:
						dropped = true
						scene._drop_carried()
					if scene.game.tick >= 640 and who < 2 and first_holder >= 0 and first_holder != who and not reclaimed:
						reclaimed = true
						scene._send_interaction("take_relic")
					if scene.game.tick >= 660:
						stage = "return"
						path = [Map.from_art(Vector2(1297, 350)), Map.from_art(Vector2(1297, 460)), Map.from_art(Vector2(280, 460)), Map.from_art(Vector2(280, 741)), Map.extraction_position()]
				"return":
					stage = "extract"
					# Exercise the same nearest-object hold path as a human using E.
					scene._use_nearest()
		scene._step_movement(direction)
	return false
func view(snapshot: Dictionary) -> void:
	if ending: return
	var who: int = snapshot.you
	if snapshot.tick == 0 and path.is_empty():
		path = [Map.from_art(Vector2(280, 741)), Map.from_art(Vector2(280, 460)), Map.from_art(Vector2(1297, 460)), Map.vault_control_position("A" if who == 0 else "B") if who < 2 else Map.from_art(Vector2(1297, 405))]
	if snapshot.phase == "aborted":
		check(false, "Unexpected expedition abort")
		finish()
		return
	if snapshot.doors.has("D4") and not snapshot.doors.D4.locked: saw_unlock = true
	var holders := 0
	for i in range(snapshot.explorers.size()):
		var actor: Dictionary = snapshot.explorers[i]
		if actor.get("has_relic", false):
			holders += 1
			saw_relic = true
			if first_holder < 0: first_holder = i
		if i != who: check(not actor.has("score") and not actor.has("breath"), "Private rival stats absent from actual packets")
		if actor.state == "hidden": check(actor.size() == 2, "Unseen actor packet reveals no location or carried art")
	check(holders <= 1, "Actual packets never show two relic holders")
	if snapshot.phase == "finished":
		check(saw_unlock and saw_relic, "Online clients observe cooperative unlock and physical relic")
		check(first_holder >= 0 and snapshot.winners.size() == 1 and snapshot.winners[0] != first_holder, "Dropped relic is claimed and extracted by the other explorer")
		var total := 0
		for result in snapshot.results:
			total += result.score
			check(result.state == "escaped", "Every human completes the expedition")
		check(total == 100 and snapshot.results.size() == count, "All clients agree on one banked relic and 2/3/4-person outcomes")
		check(scene.results_panel.visible, "Online final panel appears")
		finish()
func finish() -> void:
	if ending: return
	ending = true
	await create_timer(0.5).timeout
	scene.session.close()
	print("Online expedition %d %s: %d checks, %d failures" % [count, role, checks, failures])
	quit(0 if failures == 0 else 1)
