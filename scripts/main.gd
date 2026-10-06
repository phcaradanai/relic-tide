extends Node2D
## Raster presentation and input. Authority owns positions and regional visibility.
const Rules = preload("res://scripts/game.gd")
const View = preload("res://scripts/player_view.gd")
const Network = preload("res://scripts/session.gd")
const Map = preload("res://scripts/level_map.gd")
const Prediction = preload("res://scripts/movement_client.gd")
const Atlas = preload("res://scripts/sprite_atlas.gd")
const Vision = preload("res://scripts/vision_layer.gd")
const Water = preload("res://scripts/water_layer.gd")
const TIDE_LEAD_IN := 45.0
const INK := Color("f1ead6")
const MUTED := Color("b9d3d3")
const GOLD := Color("edc47b")
const COLORS := [Color("85e1d1"), Color("ffb29f"), Color("f3d17e"), Color("d6bfff")]
const GLASS := Color(0.025, 0.07, 0.10, 0.78)
const EDGE := Color(0.72, 0.88, 0.92, 0.38)
var auto_connect := true
var intro := true
var phase := "lobby"
var active_player := 0
var reduced_motion := false
var show_help := false
var focused := true
var session
var game = null
var prediction := Prediction.new()
var fixture = null
var ui: CanvasLayer
var art: TextureRect
var camera: Camera2D
var vision
var lantern_texture: Texture2D
var water_layer
var gate_texture: Texture2D
var interaction_sequence := -1
var valve_hold_active := false
var prompt_label: Label
var tide_label: Label
var opening: PanelContainer
var help_panel: PanelContainer
var count_picker: OptionButton
var code_field: LineEdit
var room_list: ItemList
var host_button: Button
var join_button: Button
var refresh_button: Button
var start_button: Button
var lobby_label: Label
var status_label: Label
var controls_label: Label
var available_rooms: Array = []
var sprite_atlas: Texture2D
var walk_frames: Array[Dictionary] = []
var walk_cell := Vector2.ZERO
var sprite_regions: Array[Rect2] = []
var token_positions: Dictionary = {}
var remote_from: Dictionary = {}
var remote_to: Dictionary = {}
var remote_clock: Dictionary = {}
var facing_left: Dictionary = {}
var walking: Dictionary = {}
var font: SystemFont
var elapsed := 0.0
var accumulator := 0.0
var capture_path := ""
func _ready() -> void:
	# Visible actors are filtered by authority/LOS, then drawn above floor shadows.
	# Their heads must not disappear merely because feet are near a north wall.
	var actor_material := CanvasItemMaterial.new()
	actor_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = actor_material
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Verdana"])
	art = TextureRect.new()
	art.texture = load("res://assets/ruin-movement.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.size = Map.SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.show_behind_parent = true
	art.z_index = -2
	add_child(art)
	water_layer = Water.new()
	water_layer.z_index = -1
	add_child(water_layer)
	var gate_source: Texture2D = load("res://assets/sluice-gate.png")
	var gate_crop := AtlasTexture.new()
	gate_crop.atlas = gate_source
	gate_crop.region = Rect2(gate_source.get_image().get_used_rect())
	gate_texture = gate_crop
	vision = Vision.new()
	add_child(vision)
	camera = Camera2D.new()
	camera.zoom = Vector2(1.65, 1.65)
	camera.position = Map.spawn(0)
	add_child(camera)
	vision.update_view(camera.position, Map.vision_radius(camera.position))
	var lantern_source: Texture2D = load("res://assets/lantern.png")
	var lantern_crop := AtlasTexture.new()
	lantern_crop.atlas = lantern_source
	lantern_crop.region = Rect2(lantern_source.get_image().get_used_rect())
	lantern_texture = lantern_crop
	sprite_atlas = load("res://assets/explorers-unlit.png")
	var cell := sprite_atlas.get_size() / Vector2(4, 1)
	for i in range(4): sprite_regions.append(Rect2(Vector2(i * cell.x, 0), cell))
	var walk_atlas: Texture2D = load("res://assets/explorers-unlit-walk.png")
	walk_cell = walk_atlas.get_size() / Vector2(6, 4)
	walk_frames = Atlas.extract(walk_atlas.get_image(), 6, 4)
	session = Network.new()
	session.name = "Session"
	add_child(session)
	session.view_changed.connect(_on_state)
	session.lobby_changed.connect(_on_lobby)
	session.rooms_changed.connect(_on_rooms)
	session.connection_error.connect(_connection_error)
	_build_ui()
	var demo := false
	var host_count := 0
	var join_code := ""
	var demo_count := 4
	for arg in OS.get_cmdline_user_args():
		if arg == "--demo" or arg == "--demo-private": demo = true
		elif arg.begins_with("--players="): demo_count = clampi(int(arg.substr(10)), 2, 4)
		elif arg.begins_with("--host="): host_count = clampi(int(arg.substr(7)), 2, 4)
		elif arg.begins_with("--join="): join_code = arg.substr(7)
		elif arg.begins_with("--server-url="): session.server_url = arg.substr(13)
		elif arg.begins_with("--capture="): capture_path = arg.substr(10)
	if demo: _start(demo_count)
	elif host_count > 0:
		count_picker.select(host_count - 2)
		_host()
	elif not join_code.is_empty():
		code_field.text = join_code
		_join()
	elif auto_connect: _refresh_rooms()
	if not capture_path.is_empty(): _capture.call_deferred()
func _style(fill: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0 else 0)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style
func _label(text_value: String, size: int = 18, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.01, 0.04, 0.06, 0.95))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
func _glass_input(control: Control, theme_type: String) -> void:
	var theme := Theme.new()
	for state in ["normal", "hover", "pressed", "disabled", "read_only", "panel"]:
		theme.set_stylebox(state, theme_type, _style(GLASS, EDGE))
	theme.set_stylebox("focus", theme_type, _style(Color.TRANSPARENT, GOLD))
	for state in ["font_color", "font_hover_color", "font_selected_color"]: theme.set_color(state, theme_type, INK)
	theme.set_color("font_disabled_color", theme_type, MUTED)
	theme.set_color("font_placeholder_color", theme_type, MUTED)
	theme.set_stylebox("panel", "PopupMenu", _style(GLASS, EDGE))
	control.theme = theme
func _button(text_value: String, callback: Callable, width: float = 110) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(width, 42)
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_disabled_color", MUTED)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, _style(GLASS, GOLD if state == "focus" else EDGE))
	button.pressed.connect(callback)
	return button
func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var title := _label("RELIC TIDE", 26, GOLD)
	title.position = Vector2(24, 10)
	ui.add_child(title)
	status_label = _label("2–4 explorers online", 18)
	status_label.position = Vector2(485, 15)
	ui.add_child(status_label)
	var help := _button("Guide", _toggle_help, 96)
	help.position = Vector2(1205, 12)
	ui.add_child(help)
	var leave := _button("Leave", _restart, 96)
	leave.position = Vector2(1315, 12)
	ui.add_child(leave)
	controls_label = _label("WASD / arrows · walk    E · door/light · hold at valve    Q · drop light    H · guide    R · leave", 17, MUTED)
	controls_label.position = Vector2(432, 836)
	controls_label.hide()
	ui.add_child(controls_label)
	tide_label = _label("", 17, MUTED)
	tide_label.position = Vector2(24, 48)
	tide_label.custom_minimum_size.x = 470
	tide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tide_label.hide()
	ui.add_child(tide_label)
	prompt_label = _label("", 19, GOLD)
	prompt_label.position = Vector2(570, 550)
	ui.add_child(prompt_label)
	opening = PanelContainer.new()
	opening.position = Vector2(430, 270)
	opening.size = Vector2(580, 515)
	opening.add_theme_stylebox_override("panel", _style(GLASS, EDGE))
	ui.add_child(opening)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	opening.add_child(box)
	box.add_child(_label("Take the relic. Trust no one. Beat the tide.", 21, GOLD))
	box.add_child(_label("The tide is rising · seal the refuge before it arrives", 17, MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	count_picker = OptionButton.new()
	_glass_input(count_picker, "OptionButton")
	count_picker.custom_minimum_size = Vector2(145, 42)
	for count in range(2, 5): count_picker.add_item("%d players" % count)
	count_picker.select(2)
	row.add_child(count_picker)
	host_button = _button("Create room", _host, 170)
	row.add_child(host_button)
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	code_field = LineEdit.new()
	_glass_input(code_field, "LineEdit")
	code_field.placeholder_text = "Six-character room code"
	code_field.max_length = 6
	code_field.custom_minimum_size = Vector2(325, 42)
	code_field.text_submitted.connect(func(_text): _join())
	row.add_child(code_field)
	join_button = _button("Join", _join, 150)
	row.add_child(join_button)
	refresh_button = _button("Refresh available rooms", _refresh_rooms, 260)
	box.add_child(refresh_button)
	room_list = ItemList.new()
	_glass_input(room_list, "ItemList")
	room_list.custom_minimum_size = Vector2(520, 145)
	room_list.add_theme_font_size_override("font_size", 18)
	room_list.item_selected.connect(func(index): code_field.text = available_rooms[index].code)
	room_list.item_activated.connect(func(index):
		code_field.text = available_rooms[index].code
		_join())
	box.add_child(room_list)
	lobby_label = _label("Create a room or join a friend.", 17)
	lobby_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_label.custom_minimum_size.x = 520
	box.add_child(lobby_label)
	start_button = _button("Enter the ruin", session.start_match, 220)
	start_button.hide()
	box.add_child(start_button)
	help_panel = PanelContainer.new()
	help_panel.position = Vector2(440, 570)
	help_panel.size = Vector2(560, 200)
	help_panel.add_theme_stylebox_override("panel", _style(GLASS, EDGE))
	ui.add_child(help_panel)
	var guide := VBoxContainer.new()
	guide.add_theme_constant_override("separation", 10)
	help_panel.add_child(guide)
	guide.add_child(_label("Explore together", 24, GOLD))
	guide.add_child(_label("WASD / arrows: walk. E: use a nearby door or pick up the lantern.\nHold E at the Workshop valve to redirect incoming water.\nQ: drop your lantern. Torches expand vision; walls block it.\nClosed doors slow water. The sealed refuge stays dry.", 18))
	guide.add_child(_button("Return to exploration [H]", _toggle_help, 270))
	help_panel.hide()
func _host() -> void:
	var error: Error = session.create_room(count_picker.selected + 2)
	if error != OK: _connection_error("Could not connect to the room service.")
	else: lobby_label.text = "Creating room…"
func _join() -> void:
	var error: Error = session.join_room(code_field.text)
	if error != OK: _connection_error("Could not connect to the room service.")
	else: lobby_label.text = "Joining room…"
func _refresh_rooms() -> void:
	if session.refresh_rooms() != OK: _connection_error("Could not connect to the room service.")
func _on_rooms(rooms: Array) -> void:
	available_rooms = rooms
	room_list.clear()
	for room in rooms:
		room_list.add_item("%s     %d / %d     %s" % [room.code, room.count, room.limit, "Join" if room.joinable else "Full"])
func _on_lobby(info: Dictionary) -> void:
	lobby_label.text = "Room %s · %d/%d explorers · You are P%d\n%s" % [info.code, info.count, info.limit, info.player + 1, "Share this code, then enter together." if info.is_host else "Waiting for the room creator to start."]
	code_field.text = info.code
	code_field.editable = false
	for button in [host_button, join_button, refresh_button, count_picker]: button.disabled = true
	room_list.hide()
	start_button.visible = info.is_host
	start_button.disabled = info.count < 2
func _connection_error(message: String) -> void:
	if not intro:
		phase = "aborted"
		_stop_movement()
		status_label.text = message
		return
	lobby_label.text = message
	for button in [host_button, join_button, refresh_button, count_picker]: button.disabled = false
	code_field.editable = true
	room_list.show()
	start_button.hide()
func _start(count: int) -> void:
	# Offline QA fixture only; the public lobby always uses the central service.
	fixture = Rules.new(1, count)
	_on_state(View.project(fixture, 0))
func _on_state(snapshot: Dictionary) -> void:
	var fresh: bool = intro or prediction.match_id != snapshot.match_id
	if not fresh and snapshot.tick < game.tick: return
	game = View.new(snapshot)
	water_layer.set_depths(game.water_depths)
	active_player = game.player
	phase = game.phase
	if fresh:
		prediction.reset(snapshot)
		interaction_sequence = -1
		token_positions.clear()
		accumulator = 0
	else: prediction.reconcile(snapshot)
	intro = false
	opening.hide()
	controls_label.show()
	tide_label.show()
	for i in range(game.explorers.size()):
		var p: Dictionary = game.explorers[i]
		if p.state == "hidden":
			token_positions.erase(i)
			remote_from.erase(i)
			remote_to.erase(i)
			remote_clock.erase(i)
			continue
		if i == active_player:
			if not token_positions.has(i): token_positions[i] = p.position
		else:
			remote_from[i] = token_positions.get(i, p.position)
			remote_to[i] = p.position
			remote_clock[i] = 0.0
	status_label.text = "P%d · %s" % [active_player + 1, Map.NAMES[game.explorers[active_player].region]] if phase == "running" else snapshot.get("notice", "Expedition ended. Leave to return to the room list.")
	if phase != "running": _stop_movement()
	_update_vision()
	vision.set_closed_doors(Map.closed_door_ids(game.doors))
	queue_redraw()
func _update_vision() -> void:
	if game == null: return
	var closed := Map.closed_door_ids(game.doors)
	var radius := Map.vision_radius(prediction.position, game.explorers[active_player].has_light, closed)
	vision.update_view(prediction.position, radius)
	vision.set_closed_doors(closed)
	camera.position = token_positions.get(active_player, prediction.position)
	var region: String = Map.region_at(prediction.position)
	var depth: float = game.water_depths.get(region, game.explorers[active_player].get("region_depth", 0.0))
	status_label.text = "P%d · %s · %s" % [active_player + 1, Map.NAMES.get(region, "Ruin"), "Lantern" if game.explorers[active_player].has_light else "No lantern"] if phase == "running" else status_label.text
	if game.tide_level <= 0.0001:
		tide_label.text = "Tide reaches the ruin in %ds · this area dry" % maxi(0, ceili(TIDE_LEAD_IN - game.tide_seconds))
	else:
		tide_label.text = "Outer tide %0.2f · local depth %0.2f · %s" % [game.tide_level, depth, "passage submerged" if depth >= Map.BLOCKING_DEPTH else "dangerous water" if depth >= Map.DEEP_DEPTH else "wading" if depth >= Map.WADING_DEPTH else "shallow" if depth >= Map.SHALLOW_DEPTH else "dry"]
	prompt_label.text = ""
	if show_help or phase != "running": return
	if game.lantern.has("position") and prediction.position.distance_to(game.lantern.position) <= 38:
		prompt_label.text = "E · Pick up lantern"
		return
	var nearest := ""
	var nearest_distance := Map.USE_RADIUS + 1.0
	for door_id in game.doors:
		var location: Vector2 = game.doors[door_id].position
		var distance := prediction.position.distance_to(location)
		var sight_without_door := closed.duplicate()
		sight_without_door.erase(door_id)
		if distance <= nearest_distance and Map.line_of_sight(prediction.position, location, sight_without_door):
			nearest = door_id
			nearest_distance = distance
	if not nearest.is_empty():
		var state: Dictionary = game.doors[nearest]
		if state.locked: prompt_label.text = "Locked gate · requires cooperation"
		elif state.state == "obstructed": prompt_label.text = "Door blocked · clear the doorway · E to open"
		elif state.refuge:
			if state.sealed_safe: prompt_label.text = "E · Open sealed refuge"
			elif state.target_open: prompt_label.text = "E · Close refuge door · seal before water arrives"
			else: prompt_label.text = "E · Open refuge door"
		else: prompt_label.text = "E · Close door" if state.target_open else "E · Open door"
		return
	if not game.valve.is_empty() and prediction.position.distance_to(Map.valve_position()) <= Map.USE_RADIUS:
		prompt_label.text = "Hold E · Redirect water to %s" % ("service passage" if game.valve.mode == "main" else "main crossing")
		if game.valve.progress > 0.0: prompt_label.text += " · %d%%" % roundi(game.valve.progress * 100.0)
func _use_light(kind: String) -> void:
	if intro or phase != "running" or show_help or not focused: return
	_send_interaction(kind)
	if kind == "take_light" or kind == "drop_light": return
func _send_interaction(kind: String, target: String = "") -> void:
	interaction_sequence += 1
	var command := {"kind": kind, "target": target, "sequence": interaction_sequence, "match_id": prediction.match_id}
	if fixture != null:
		var accepted := false
		match kind:
			"take_light", "drop_light": accepted = fixture.use_light(active_player, kind, interaction_sequence)
			"toggle_door": accepted = fixture.toggle_door(active_player, target, interaction_sequence)
			"begin_valve": accepted = fixture.begin_valve(active_player, interaction_sequence)
			"cancel_interaction": accepted = fixture.cancel_interaction(active_player, interaction_sequence)
		if accepted: _on_state(View.project(fixture, active_player))
	else: session.interaction(command)
func _use_nearest() -> void:
	if intro or phase != "running" or show_help or not focused: return
	if game.lantern.has("position") and prediction.position.distance_to(game.lantern.position) <= 38:
		_use_light("take_light")
		return
	var nearest := ""
	var nearest_distance := Map.USE_RADIUS + 1.0
	var closed := Map.closed_door_ids(game.doors)
	for door_id in game.doors:
		var location: Vector2 = game.doors[door_id].position
		var distance := prediction.position.distance_to(location)
		var sight_without_door := closed.duplicate()
		sight_without_door.erase(door_id)
		if distance <= nearest_distance and Map.line_of_sight(prediction.position, location, sight_without_door):
			nearest = door_id
			nearest_distance = distance
	if not nearest.is_empty():
		if not game.doors[nearest].locked: _send_interaction("toggle_door", nearest)
		return
	if not game.valve.is_empty() and prediction.position.distance_to(Map.valve_position()) <= Map.USE_RADIUS:
		valve_hold_active = true
		_send_interaction("begin_valve")
func _cancel_interaction_hold() -> void:
	if not valve_hold_active: return
	valve_hold_active = false
	if not intro and phase == "running": _send_interaction("cancel_interaction")
func _direction() -> Vector2:
	if intro or phase != "running" or show_help or not focused: return Vector2.ZERO
	if get_viewport().gui_get_focus_owner() is LineEdit: return Vector2.ZERO
	return Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).limit_length(1)
func _step_movement(direction: Vector2) -> void:
	var command := prediction.advance(direction)
	if fixture != null:
		fixture.set_input(active_player, command.direction, command.sequence)
		fixture.step()
		if fixture.tick % 2 == 0: _on_state(View.project(fixture, active_player))
	else: session.movement(command)
func _stop_movement() -> void:
	if intro or game == null: return
	var command := prediction.advance(Vector2.ZERO)
	prediction.pending.clear()
	prediction.position = game.explorers[active_player].position
	if fixture != null: fixture.set_input(active_player, Vector2.ZERO, command.sequence)
	else: session.movement(command)
func _process(delta: float) -> void:
	elapsed += delta
	if intro or game == null: return
	if phase == "running":
		accumulator += minf(delta, 0.25)
		while accumulator >= Rules.STEP:
			accumulator -= Rules.STEP
			_step_movement(_direction())
	for i in range(game.explorers.size()):
		var p: Dictionary = game.explorers[i]
		if p.state == "hidden": continue
		var target: Vector2
		if i == active_player:
			var current: Vector2 = token_positions.get(i, prediction.position)
			target = current.lerp(prediction.position, minf(delta * 30, 1))
			if not Map.walkable(target): target = prediction.position
		else:
			remote_clock[i] = minf(remote_clock.get(i, 0.0) + delta, 0.1)
			target = remote_from[i].lerp(remote_to[i], remote_clock[i] / 0.1)
		var before: Vector2 = token_positions.get(i, target)
		walking[i] = target.distance_to(before) > 0.1
		if absf(target.x - before.x) > 0.1: facing_left[i] = target.x < before.x
		token_positions[i] = target
	_update_vision()
	queue_redraw()
func _draw() -> void:
	if intro or game == null: return
	_draw_doors()
	var closed := Map.closed_door_ids(game.doors)
	var order := token_positions.keys()
	order.sort_custom(func(a, b): return token_positions[a].y < token_positions[b].y)
	if lantern_texture and game.lantern.has("position") and Map.can_see(prediction.position, game.lantern.position, game.explorers[active_player].has_light, closed):
		draw_texture_rect(lantern_texture, Rect2(game.lantern.position - Vector2(8, 27), Vector2(16, 28)), false)
	for i: int in order:
		var p: Dictionary = game.explorers[i]
		if p.state == "hidden" or (i != active_player and not Map.can_see(prediction.position, p.position, game.explorers[active_player].has_light, closed)): continue
		var pos: Vector2 = token_positions[i]
		var moving: bool = walking.get(i, false)
		var region: Rect2 = sprite_regions[i]
		var texture: Texture2D = sprite_atlas
		var size := Vector2(45, minf(66, 45 * region.size.y / region.size.x))
		var offset := Vector2(-size.x / 2, -size.y)
		if moving:
			var frame: Dictionary = walk_frames[i * 6 + (int(elapsed * 10) % 6)]
			texture = frame.texture
			region = Rect2(Vector2.ZERO, texture.get_size())
			var cell := walk_cell
			var full_size := Vector2(56, 72)
			offset = Vector2(frame.bounds.position - frame.cell_origin) * full_size / cell + Vector2(-full_size.x / 2, -full_size.y)
			size = Vector2(frame.bounds.size) * full_size / cell
		draw_set_transform(pos, 0, Vector2(-1, 1) if facing_left.get(i, false) else Vector2.ONE)
		draw_texture_rect_region(texture, Rect2(offset, size), region)
		draw_set_transform(Vector2.ZERO)
		if p.has_light and lantern_texture: draw_texture_rect(lantern_texture, Rect2(pos + Vector2(12, -36), Vector2(12, 22)), false)
		draw_string(font, pos + Vector2(-11, -76), "P%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLORS[i])
func _draw_doors() -> void:
	if gate_texture == null: return
	for door_id in game.doors:
		var door: Dictionary = game.doors[door_id]
		var progress: float = door.progress
		if progress >= 0.995: continue
		var width: float = Map.DOORS[door_id].width * Map.SIZE.x / Map.ART_SIZE.x + 20.0
		var height := 60.0
		var shown_height := maxf(4.0, height * (1.0 - progress))
		var rotation := 0.0 if door.horizontal else PI / 2.0
		draw_set_transform(door.position + Vector2(0, -height / 2), rotation, Vector2.ONE)
		draw_texture_rect(gate_texture, Rect2(Vector2(-width / 2, -height / 2), Vector2(width, shown_height)), false)
		draw_set_transform(Vector2.ZERO)
		if door.sealed_safe: draw_string(font, door.position + Vector2(-18, -height - 6), "DRY", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD)
func _toggle_help() -> void:
	if intro: return
	show_help = not show_help
	help_panel.visible = show_help
	if show_help: _stop_movement()
func _restart() -> void:
	_stop_movement()
	session.close()
	fixture = null
	game = null
	water_layer.set_depths({})
	intro = true
	phase = "lobby"
	show_help = false
	valve_hold_active = false
	help_panel.hide()
	opening.show()
	controls_label.hide()
	tide_label.hide()
	prompt_label.text = ""
	camera.position = Map.spawn(0)
	vision.update_view(camera.position, Map.vision_radius(camera.position))
	vision.set_closed_doors([])
	token_positions.clear()
	prediction = Prediction.new()
	code_field.text = ""
	code_field.editable = true
	for button in [host_button, join_button, refresh_button, count_picker]: button.disabled = false
	start_button.hide()
	room_list.show()
	room_list.clear()
	available_rooms.clear()
	lobby_label.text = "Create a room or join a friend."
	status_label.text = "2–4 explorers online"
	if auto_connect: _refresh_rooms()
	queue_redraw()
func _input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	if event.physical_keycode == KEY_E and not event.pressed:
		_cancel_interaction_hold()
		return
	if not event.pressed or event.echo: return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	match event.physical_keycode:
		KEY_E: _use_nearest()
		KEY_Q: _use_light("drop_light")
		KEY_H: _toggle_help()
		KEY_V: reduced_motion = not reduced_motion
		KEY_R: _restart()
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		focused = false
		_cancel_interaction_hold()
		_stop_movement()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN: focused = true
func _capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(capture_path)
	get_tree().quit()
