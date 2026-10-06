extends SceneTree
## Real directory smoke: create, browser join, full-room rejection and screenshots.
var role := "browser"
var port := 24620
var scene
var ending := false
var joining := false
var failures := 0
var checks := 0
var began := 0
func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.substr(7)
		elif arg.begins_with("--port="): port = int(arg.substr(7))
	call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func run() -> void:
	began = Time.get_ticks_msec()
	root.size = Vector2i(960, 600)
	scene = load("res://scenes/main.tscn").instantiate()
	scene.auto_connect = false
	root.add_child(scene)
	scene.session.server_url = "ws://127.0.0.1:%d" % port
	scene.session.rooms_changed.connect(rooms)
	scene.session.lobby_changed.connect(lobby)
	scene.session.connection_error.connect(error)
	if role == "host":
		scene.count_picker.select(0)
		scene._host()
	else: scene._refresh_rooms()
func _process(_delta: float) -> bool:
	if began > 0 and Time.get_ticks_msec() - began > 12000 and not ending:
		check(false, "Lobby scenario timed out")
		finish()
	return false
func rooms(list: Array) -> void:
	if list.is_empty() or joining or role == "host": return
	if role == "browser" and list[0].count < 2: return
	joining = true
	check(scene.room_list.item_count > 0, "Live rooms render in native browser")
	check(list[0].code.length() == 6 and not list[0].has("address"), "Directory exposes code without IP")
	scene.room_list.item_selected.emit(0)
	check(scene.code_field.text == list[0].code, "Selecting browser room fills code")
	if role == "client": scene.room_list.item_activated.emit(0)
	else:
		check(not list[0].joinable, "Full room advertised truthfully")
		await capture("rooms-browser-small")
		scene._join.call_deferred()
func lobby(info: Dictionary) -> void:
	if ending: return
	check(scene.lobby_label.text.contains(info.code), "Room code visible for sharing")
	check(scene.start_button.visible == info.is_host, "Only creator sees start control")
	if info.count == 2:
		check(not scene.code_field.editable and not scene.room_list.visible, "Lobby contains own room without stale browser")
		if role == "host": check(not scene.start_button.disabled, "Two players unlock creator start")
		capture("rooms-lobby-%s-small" % role)
		finish()
func error(message: String) -> void:
	if ending: return
	check(role == "browser" and message.contains("full"), "Full room join rejected by authority")
	check(scene.host_button.disabled == false and scene.session.room_code.is_empty(), "Rejection preserves browser and allows retry")
	finish()
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/%s.png" % name)
func finish() -> void:
	if ending: return
	ending = true
	await create_timer(5.0 if role != "browser" and DisplayServer.get_name() != "headless" else 1.0).timeout
	scene.session.close()
	print("Online lobby %s: %d checks, %d failures" % [role, checks, failures])
	quit(0 if failures == 0 else 1)
