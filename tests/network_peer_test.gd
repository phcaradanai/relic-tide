extends SceneTree
## Separate processes exercise actual WebSocket authority and private movement.
const Map = preload("res://scripts/level_map.gd")
const Prediction = preload("res://scripts/movement_client.gd")
var role := "client"
var count := 2
var port := 24602
var scenario := "match"
var scene
var ending := false
var joining := false
var checks := 0
var failures := 0
var began := 0
var accumulator := 0.0
var last_tick := -1
var initial := Vector2.ZERO
var saw_movement := false
var saw_hidden := false
var max_prediction_error := 0.0
var max_correction := 0.0
var tried_light := false
var saw_carried_light := false
var tried_door_close := false
var tried_door_open := false
var saw_closed_door := false
var saw_reopened_door := false
func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.substr(7)
		elif arg.begins_with("--count="): count = int(arg.substr(8))
		elif arg.begins_with("--port="): port = int(arg.substr(7))
		elif arg.begins_with("--case="): scenario = arg.substr(7)
	call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func run() -> void:
	began = Time.get_ticks_msec()
	scene = load("res://scenes/main.tscn").instantiate()
	scene.auto_connect = false
	root.add_child(scene)
	scene.set_process(false)
	scene.session.server_url = "ws://127.0.0.1:%d" % port
	scene.session.rooms_changed.connect(rooms)
	scene.session.lobby_changed.connect(lobby)
	scene.session.view_changed.connect(view)
	scene.session.connection_error.connect(func(message):
		check(false, message)
		finish())
	if role == "host": scene.session.create_room(count)
	else: scene.session.refresh_rooms()
func rooms(list: Array) -> void:
	if role == "host" or joining or list.is_empty(): return
	joining = true
	scene.session.join_room(list[0].code)
func lobby(info: Dictionary) -> void:
	if role == "host" and info.count == count: scene.session.start_match()
func _process(delta: float) -> bool:
	if ending: return false
	if began > 0 and Time.get_ticks_msec() - began > 14000:
		check(false, "Movement scenario timed out")
		finish()
	if scene == null or scene.intro or scene.phase != "running": return false
	accumulator += delta
	while accumulator >= 0.05:
		accumulator -= 0.05
		var direction := Vector2.ZERO
		if scenario == "doors" and scene.active_player == 0:
			var destination := Map.door_position("D0") + Vector2(0, 35)
			direction = (destination - scene.prediction.position) / 8.5
			if scene.prediction.position.distance_to(destination) < 2:
				direction = Vector2.ZERO
				if not tried_door_close:
					tried_door_close = true
					scene._send_interaction("toggle_door", "D0")
		elif scenario == "doors":
			direction = Vector2.ZERO
		elif scene.active_player == 0:
			var destination := Map.from_art(Vector2(280, 350))
			if scene.prediction.position.y > Map.from_art(Vector2(0, 695)).y:
				destination = Map.from_art(Vector2(280, 741))
				if absf(destination.x - scene.prediction.position.x) < 2: destination = Map.from_art(Vector2(280, 350))
			direction = (destination - scene.prediction.position) / 8.5
		elif scene.active_player < count - 1:
			direction = Vector2.RIGHT if scene.active_player == 1 else Vector2.LEFT
		scene._step_movement(direction)
	return false
func view(snapshot: Dictionary) -> void:
	if ending: return
	check(snapshot.you == scene.active_player, "Addressed recipient")
	if snapshot.phase == "aborted":
		check(scenario in ["disconnect", "host-leave"], "Only disconnect scenarios abort")
		check(snapshot.notice.contains("left"), "Disconnect reason visible")
		finish()
		return
	check(snapshot.phase == "running" and snapshot.tick >= last_tick, "Continuous authority ticks")
	last_tick = snapshot.tick
	var self_view: Dictionary = snapshot.explorers[snapshot.you]
	if snapshot.you == 0 and self_view.has_light: saw_carried_light = true
	check(Map.walkable(self_view.position), "Authoritative feet remain on floor")
	max_prediction_error = maxf(max_prediction_error, scene.prediction.position.distance_to(self_view.position))
	max_correction = maxf(max_correction, scene.prediction.correction_distance)
	if snapshot.tick == 0:
		initial = self_view.position
		check(snapshot.explorers.size() == count, "All human seats present")
		# Neither coordinates nor identity can be injected into movement.
		scene.session.movement({"direction": Vector2.ZERO, "sequence": 900000, "match_id": snapshot.match_id, "position": Vector2.ZERO})
		scene.session.movement({"direction": Vector2(100, 0), "sequence": 900001, "match_id": snapshot.match_id})
		if snapshot.you == 0 and not tried_light:
			tried_light = true
			scene._use_light("take_light")
	for p in snapshot.explorers:
		if p.state == "hidden":
			saw_hidden = true
			check(not p.has("position") and not p.has("region") and not p.has("velocity"), "Remote location absent from actual packet")
	if self_view.position.distance_to(initial) > 20: saw_movement = true
	if scenario == "doors" and snapshot.doors.has("D0"):
		if snapshot.doors.D0.state == "closed":
			saw_closed_door = true
			if snapshot.you == 0 and not tried_door_open:
				tried_door_open = true
				scene._send_interaction("toggle_door", "D0")
		if saw_closed_door and snapshot.doors.D0.state == "open": saw_reopened_door = true
	if scenario in ["disconnect", "host-leave"] and snapshot.tick >= 30:
		var leaver: bool = (role == "host") if scenario == "host-leave" else snapshot.you == count - 1
		if leaver:
			scene.session.close()
			finish()
			return
	if scenario in ["match", "latency", "doors"] and snapshot.tick >= 120:
		if snapshot.you == count - 1:
			check(self_view.position.distance_to(initial) < 0.01, "Silent human stays still while others move")
		else: check(saw_movement, "Independent human movement observed")
		if scenario == "doors":
			check(saw_closed_door and saw_reopened_door, "Separate online clients see authoritative closure and reopening")
		else: check(saw_hidden, "Leaving sight hides remote explorer")
		check(max_prediction_error <= (Prediction.MAX_PENDING * 8.5 + 8.5 if scenario == "latency" else 35), "Prediction lead respects bounded pending window")
		check(max_correction <= (85 if scenario == "latency" else 35), "Actual reconciliation correction stays bounded")
		if snapshot.you == 0: check(saw_carried_light, "Physical lantern pickup reaches authoritative online view")
		check(snapshot.ack_sequence < 900000, "Spoofed packets did not poison sequence")
		finish()
func finish() -> void:
	if ending: return
	ending = true
	await create_timer(0.5).timeout
	scene.session.close()
	print("Online movement %s %d %s: %d checks, %d failures; max lead %.1fpx, correction %.1fpx" % [scenario, count, role, checks, failures, max_prediction_error, max_correction])
	quit(0 if failures == 0 else 1)
