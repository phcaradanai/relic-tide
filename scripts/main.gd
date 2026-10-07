extends Node2D
## Raster presentation and input. Authority owns positions and regional visibility.
const Rules = preload("res://scripts/game.gd")
const View = preload("res://scripts/player_view.gd")
const Network = preload("res://scripts/session.gd")
const Maps = preload("res://scripts/expedition_map.gd")
const Prediction = preload("res://scripts/movement_client.gd")
const MovementView = preload("res://scripts/movement_view.gd")
const Vision = preload("res://scripts/vision_layer.gd")
const Water = preload("res://scripts/water_layer.gd")
const ExplorerSprite = preload("res://scripts/explorer_sprite.gd")
const Mechanisms = preload("res://scripts/world_mechanisms.gd")
const World = preload("res://scripts/expedition_world.gd")
const HUD = preload("res://scripts/survival_hud.gd")
const Puzzle = preload("res://scripts/expedition_puzzle.gd")
const Blueprint = preload("res://scripts/expedition_blueprint.gd")
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
var movement_view := MovementView.new()
var fixture = null
var Map = Maps.new()
var world
var hud
var puzzle_panel
var blueprint
var start_screen: PanelContainer
var waiting_panel: PanelContainer
var waiting_label: Label
var ready_button: Button
var map_buttons: Array[Button] = []
var selected_map := "lagoon"
var lobby_ready := false
var lobby_info: Dictionary = {}
var monster_sprites: Dictionary = {}
var monster_frames: SpriteFrames
var frame_tick := 0.0
var ui: CanvasLayer
var art: TextureRect
var camera: Camera2D
var vision
var mechanisms
var lantern_texture: Texture2D
var water_layer
var interaction_sequence := -1
var interaction_hold_active := false
var hold_refresh_ticks := 0
var relic_texture: Texture2D
var results_panel: PanelContainer
var results_label: Label
var survival_label: Label
var prompt_label: Label
var tide_label: Label
var opening: PanelContainer
var city_caption: Label
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
var title_label: Label
var controls_label: Label
var available_rooms: Array = []
var explorer_frames: Array[SpriteFrames] = []
var explorer_sprites: Array[Node2D] = []
var token_positions: Dictionary = {}
var remote_from: Dictionary = {}
var remote_to: Dictionary = {}
var remote_clock: Dictionary = {}
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
	var local_material := ShaderMaterial.new()
	local_material.shader = load("res://shaders/local_scene.gdshader")
	local_material.set_shader_parameter("floor_mask", load("res://assets/ruin-floor-mask-v2.png"))
	local_material.set_shader_parameter("is_floor_pass", true)
	art.material = local_material
	art.hide()
	add_child(art)
	water_layer = Water.new()
	water_layer.z_index = -1
	water_layer.hide()
	add_child(water_layer)
	vision = Vision.new()
	vision.hide()
	add_child(vision)
	mechanisms = Mechanisms.new()
	add_child(mechanisms)
	camera = Camera2D.new()
	camera.zoom = Vector2(1.65, 1.65)
	camera.position = Map.spawn(0)
	add_child(camera)
	vision.update_view(camera.position, Map.vision_radius(camera.position))
	var lantern_source: Texture2D = load("res://assets/lantern-grip-v2.png")
	var lantern_crop := AtlasTexture.new()
	lantern_crop.atlas = lantern_source
	lantern_crop.region = Rect2(lantern_source.get_image().get_used_rect())
	lantern_texture = lantern_crop
	relic_texture = _raster_crop("res://assets/relic-grip-v2.png")
	for i in range(4):
		var frames: SpriteFrames = load("res://assets/generated/sprites/explorer-holding-p%d-v2/frames.tres" % (i + 1))
		explorer_frames.append(frames)
		var actor = ExplorerSprite.new()
		actor.configure(frames, i, COLORS[i], font)
		actor.hide()
		add_child(actor)
		explorer_sprites.append(actor)
	session = Network.new()
	session.name = "Session"
	add_child(session)
	session.view_changed.connect(_on_state)
	session.lobby_changed.connect(_on_lobby)
	session.rooms_changed.connect(_on_rooms)
	session.connection_error.connect(_connection_error)
	_build_ui()
	_build_expansion_ui()
	_show_start()
	var demo := false
	var host_count := 0
	var join_code := ""
	var demo_count := 4
	var demo_map := "prototype"
	for arg in OS.get_cmdline_user_args():
		if arg == "--demo" or arg == "--demo-private": demo = true
		elif arg.begins_with("--players="): demo_count = clampi(int(arg.substr(10)), 2, 4)
		elif arg.begins_with("--map=") and Maps.valid_id(arg.substr(6)): demo_map = arg.substr(6)
		elif arg.begins_with("--host="): host_count = clampi(int(arg.substr(7)), 2, 4)
		elif arg.begins_with("--join="): join_code = arg.substr(7)
		elif arg.begins_with("--server-url="): session.server_url = arg.substr(13)
		elif arg.begins_with("--capture="): capture_path = arg.substr(10)
	if demo: _start(demo_count, demo_map)
	elif host_count > 0:
		count_picker.select(host_count - 2)
		_host()
	elif not join_code.is_empty():
		code_field.text = join_code
		_join()
	elif auto_connect: _refresh_rooms()
	if not capture_path.is_empty(): _capture.call_deferred()
func _raster_crop(path: String) -> Texture2D:
	var source: Texture2D = load(path)
	var crop := AtlasTexture.new()
	crop.atlas = source
	crop.region = Rect2(source.get_image().get_used_rect())
	return crop
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
	title_label = _label("RELIC TIDE", 26, GOLD)
	title_label.position = Vector2(24, 10)
	ui.add_child(title_label)
	status_label = _label("2–4 explorers online", 18)
	status_label.position = Vector2(485, 15)
	ui.add_child(status_label)
	var help := _button("Guide", _toggle_help, 96)
	help.position = Vector2(1205, 12)
	ui.add_child(help)
	var leave := _button("Leave", _restart, 96)
	leave.position = Vector2(1315, 12)
	ui.add_child(leave)
	controls_label = _label("WASD / arrows · walk    E · use / hold    Q · drop relic / lantern    H · guide    V · reduced motion    R · leave", 17, MUTED)
	controls_label.position = Vector2(24, 836)
	controls_label.hide()
	ui.add_child(controls_label)
	tide_label = _label("", 17, MUTED)
	tide_label.position = Vector2(24, 48)
	tide_label.custom_minimum_size.x = 470
	tide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tide_label.hide()
	ui.add_child(tide_label)
	survival_label = _label("", 18, GOLD)
	survival_label.position = Vector2(24, 100)
	survival_label.hide()
	ui.add_child(survival_label)
	results_panel = PanelContainer.new()
	results_panel.position = Vector2(440, 260)
	results_panel.custom_minimum_size = Vector2(560, 0)
	results_panel.add_theme_stylebox_override("panel", _style(GLASS, EDGE))
	ui.add_child(results_panel)
	var result_box := VBoxContainer.new()
	result_box.add_theme_constant_override("separation", 20)
	results_panel.add_child(result_box)
	result_box.add_child(_label("EXPEDITION COMPLETE", 24, GOLD))
	results_label = _label("", 19)
	results_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	results_label.custom_minimum_size.x = 520
	result_box.add_child(results_label)
	result_box.add_child(_button("Return to rooms [R]", _restart, 240))
	results_panel.hide()
	prompt_label = _label("", 19, GOLD)
	prompt_label.position = Vector2(570, 550)
	ui.add_child(prompt_label)
	opening = PanelContainer.new()
	opening.position = Vector2(430, 270)
	opening.size = Vector2(580, 515)
	opening.add_theme_stylebox_override("panel", _style(GLASS, EDGE))
	ui.add_child(opening)
	city_caption = _label("ATLANTIS\nThe Sluice Vault", 22, GOLD)
	city_caption.position = Vector2(42, 708)
	ui.add_child(city_caption)
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
	help_panel.position = Vector2(390, 520)
	help_panel.size = Vector2(660, 240)
	help_panel.add_theme_stylebox_override("panel", _style(GLASS, EDGE))
	ui.add_child(help_panel)
	var guide := VBoxContainer.new()
	guide.add_theme_constant_override("separation", 10)
	help_panel.add_child(guide)
	guide.add_child(_label("Explore together", 24, GOLD))
	guide.add_child(_label("WASD / arrows: walk. E: use objects and solve treasure chests.\nQ: drop carried relic or lantern. M: open a collected map.\nF: fire a tranquilizer toward the pointer. 1: use a medkit.\nOxygen lets you cross flooded routes; a mask protects from gas.\nClose gates when the wave warning appears to stop the spread.\nHold separate vault controls together to release the great relic.\nReturn to the Landing boat and hold E to bank treasure and escape.\nA sealed dry refuge stays safe, but does not bank your treasure.", 18))
	guide.add_child(_button("Return to exploration [H]", _toggle_help, 270))
	help_panel.hide()
func _host() -> void:
	var error: Error = session.create_room(count_picker.selected + 2, selected_map)
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
	lobby_info = info
	selected_map = info.get("map_id", "lagoon")
	lobby_ready = info.get("ready", [false])[info.player]
	if info.has("staging_view"): _on_state(info.staging_view)
	lobby_label.text = "Room %s · %d/%d explorers · You are P%d\n%s" % [info.code, info.count, info.limit, info.player + 1, "Share this code, then enter together." if info.is_host else "Waiting for the room creator to start."]
	waiting_label.text = "%s\n%d / %d explorers · P%d" % [info.code, info.count, info.limit, info.player + 1]
	waiting_panel.show()
	opening.hide()
	start_screen.hide()
	ready_button.text = "Ready" if not lobby_ready else "Ready · undo"
	for i in range(map_buttons.size()):
		map_buttons[i].disabled = not info.is_host
		map_buttons[i].modulate = GOLD if Maps.PRODUCTION_IDS[i] == selected_map else Color.WHITE
	code_field.text = info.code
	code_field.editable = false
	for button in [host_button, join_button, refresh_button, count_picker]: button.disabled = true
	room_list.hide()
	start_button.visible = info.is_host
	start_button.disabled = not info.get("can_start", info.count >= 2)
func _connection_error(message: String) -> void:
	if phase == "waiting":
		_restart()
		_open_rooms()
		lobby_label.text = message
		return
	if not intro:
		phase = "aborted"
		_stop_movement()
		status_label.text = message
		status_label.show()
		results_label.text = message
		results_panel.show()
		hud.hide()
		puzzle_panel.hide()
		return
	lobby_label.text = message
	for button in [host_button, join_button, refresh_button, count_picker]: button.disabled = false
	code_field.editable = true
	room_list.show()
	start_button.hide()
func _start(count: int, map_id: String = "prototype") -> void:
	# Offline QA fixture only; the public lobby always uses the central service.
	fixture = Rules.new(1, count, map_id)
	_on_state(View.project(fixture, 0))
func _on_state(snapshot: Dictionary) -> void:
	var fresh: bool = game == null or intro or prediction.match_id != snapshot.match_id or active_player != snapshot.you
	if not fresh and snapshot.tick < game.tick: return
	_bind_map(snapshot.get("map_id", "prototype"))
	var previous = game
	game = View.new(snapshot)
	for region in game.power: Map.room_power[region] = game.power[region]
	water_layer.set_depths(game.water_depths)
	active_player = game.player
	phase = game.phase
	# Lobby membership may shrink without changing the host's match token.
	# Remove departing slots before light/camera updates visit cached feet.
	for i in range(game.explorers.size(), explorer_sprites.size()):
		explorer_sprites[i].hide()
		explorer_sprites[i].reset_visual()
		for cache in [token_positions, remote_from, remote_to, remote_clock, walking]: cache.erase(i)
	interaction_hold_active = not game.interaction.is_empty()
	if fresh:
		prediction.reset(snapshot)
		movement_view.reset(prediction.position)
		interaction_sequence = -1
		token_positions.clear()
		accumulator = 0
		for actor in explorer_sprites:
			actor.hide()
			actor.reset_visual()
	else:
		var before: Vector2 = prediction.position
		if prediction.reconcile(snapshot): movement_view.reconcile(before, prediction.position)
	intro = false
	opening.hide()
	start_screen.hide()
	waiting_panel.visible = phase == "waiting"
	city_caption.hide()
	art.visible = Map.id == "prototype"
	if world: world.show()
	water_layer.show()
	vision.show()
	mechanisms.show()
	controls_label.visible = Map.id == "prototype"
	tide_label.visible = Map.id == "prototype"
	survival_label.visible = Map.id == "prototype"
	status_label.visible = Map.id == "prototype"
	title_label.visible = Map.id == "prototype" or phase == "waiting"
	hud.update_state(game)
	puzzle_panel.update_state(game)
	camera.zoom = Vector2.ONE * (1.65 if Map.id == "prototype" else 1.18 if phase == "waiting" else 2.6)
	for i in range(game.explorers.size()):
		var p: Dictionary = game.explorers[i]
		if p.state == "hidden":
			explorer_sprites[i].hide()
			explorer_sprites[i].reset_visual()
			token_positions.erase(i)
			remote_from.erase(i)
			remote_to.erase(i)
			remote_clock.erase(i)
			continue
		if i == active_player:
			if not token_positions.has(i): token_positions[i] = p.position
		else:
			if not token_positions.has(i): token_positions[i] = p.position
			remote_from[i] = token_positions.get(i, p.position)
			remote_to[i] = p.position
			remote_clock[i] = 0.0
		var pickup_kind := ""
		var pickup_aim := Vector2.ZERO
		if not fresh and i < previous.explorers.size() and p.state == "exploring" and previous.explorers[i].state not in ["hidden", "escaped", "drowned"]:
			var before: Dictionary = previous.explorers[i]
			if p.has_relic and not before.has_relic:
				pickup_kind = "relic"
				pickup_aim = previous.relic.get("position", p.position) - p.position
			elif p.has_light and not before.has_light:
				pickup_kind = "lantern"
				pickup_aim = previous.lantern.get("position", p.position) - p.position
		explorer_sprites[i].set_inventory(p.has_relic, p.has_light, pickup_kind, pickup_aim)
	status_label.text = "P%d · %s" % [active_player + 1, Map.NAMES[game.explorers[active_player].region]] if phase == "running" else snapshot.get("notice", "Expedition ended. Leave to return to the room list.")
	if phase not in ["running", "waiting"]: _stop_movement()
	results_panel.visible = phase in ["finished", "aborted"]
	if phase == "aborted": results_label.text = snapshot.get("notice", "Connection ended. Return to rooms.")
	if phase == "finished":
		var lines: Array[String] = []
		for result in game.results: lines.append("%s · %s · %d points" % [result.name, result.state.capitalize(), result.score])
		var names: Array[String] = []
		for who in game.winners: names.append("P%d" % (who + 1))
		lines.append("\nTreasure extracted · %s wins" % ", ".join(names) if not names.is_empty() else "\nNo treasure extracted")
		if game.finish_reason == "deadline": lines.append("The tide deadline passed. Sheltered survivors remain alive.")
		results_label.text = "\n".join(lines)
	_update_vision()
	vision.set_closed_doors(Map.closed_door_ids(game.doors))
	queue_redraw()
func _update_vision() -> void:
	if game == null: return
	var closed := Map.closed_door_ids(game.doors)
	var point: Vector2 = token_positions.get(active_player, prediction.position)
	var radius := Map.vision_radius(point, game.explorers[active_player].has_light, closed)
	vision.update_view(point, radius)
	vision.set_closed_doors(closed)
	art.material.set_shader_parameter("view_center", point)
	art.material.set_shader_parameter("view_radius", radius)
	water_layer.update_view(point, radius, game.explorers[active_player].has_light)
	mechanisms.update_view(game, point, game.explorers[active_player].has_light)
	if world: world.update_view(game, point, radius, game.explorers[active_player].has_light, phase == "waiting")
	blueprint.own_position = point
	blueprint.queue_redraw()
	for i: int in token_positions:
		_update_explorer(i, 0.0, Vector2.ZERO)
	camera.position = token_positions.get(active_player, prediction.position)
	camera.force_update_scroll()
	var region: String = Map.region_at(prediction.position)
	var depth: float = game.water_depths.get(region, game.explorers[active_player].get("region_depth", 0.0))
	status_label.text = "P%d · %s · %s" % [active_player + 1, Map.NAMES.get(region, "Ruin"), "Lantern" if game.explorers[active_player].has_light else "No lantern"] if phase == "running" else status_label.text
	if game.tide_level <= 0.0001:
		tide_label.text = "Tide reaches the ruin in %ds · this area dry" % maxi(0, ceili(TIDE_LEAD_IN - game.tide_seconds))
	else:
		tide_label.text = "Outer tide %0.2f · local depth %0.2f · %s" % [game.tide_level, depth, "passage submerged" if depth >= Map.BLOCKING_DEPTH else "dangerous water" if depth >= Map.DEEP_DEPTH else "wading" if depth >= Map.WADING_DEPTH else "shallow" if depth >= Map.SHALLOW_DEPTH else "dry"]
	var self_view: Dictionary = game.explorers[active_player]
	survival_label.text = "Breath %.1fs / 12 · %s · Banked %d · %ds left" % [self_view.breath, "Relic carried · slower" if self_view.has_relic else "No relic", self_view.score, maxi(0, ceili(Rules.EXPEDITION_LENGTH - game.tide_seconds))]
	survival_label.modulate = COLORS[1] if self_view.breath < 4.0 else Color.WHITE
	prompt_label.text = ""
	hud.set_prompt("", Vector2.ZERO)
	if show_help or phase != "running": return
	if self_view.state != "exploring":
		prompt_label.text = "Escaped · waiting for expedition results" if self_view.state == "escaped" else "Drowned · waiting for expedition results"
		prompt_label.position = Vector2(450, 700)
		return
	var nearby := _nearby_interaction()
	if nearby.is_empty(): return
	if Map.id != "prototype":
		if not puzzle_panel.visible and not blueprint.visible:
			var name: String = {"take_relic": "treasure", "take_light": "oxygen", "begin_extraction": "open_door", "begin_vault": "refuge", "begin_valve": "wave", "toggle_door": "closed_door", "chest": "treasure"}.get(nearby.kind, "treasure")
			var screen_point: Vector2 = get_global_transform_with_canvas() * nearby.position
			hud.set_prompt(name, screen_point + Vector2(0, 42), game.interaction.get("progress", 0.0), nearby.kind.begins_with("begin_"))
		return
	prompt_label.text = nearby.text
	if not game.interaction.is_empty(): prompt_label.text += " · %d%%" % roundi(game.interaction.progress * 100)
	var canvas_point: Vector2 = get_global_transform_with_canvas() * nearby.position
	var prompt_width := font.get_string_size(prompt_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	prompt_label.position = Vector2(clampf(canvas_point.x - prompt_width / 2, 24, 1440 - prompt_width - 24), clampf(canvas_point.y + 30, 155, 790))
func _nearby_interaction() -> Dictionary:
	var options: Array[Dictionary] = []
	var position: Vector2 = prediction.position
	var closed := Map.closed_door_ids(game.doors)
	for chest_id in game.chests:
		var chest: Dictionary = game.chests[chest_id]
		if not chest.claimed: options.append({"kind": "chest", "target": chest_id, "position": chest.position, "radius": Map.USE_RADIUS, "text": "E · Chest"})
	if game.relic.has("position") and not game.explorers[active_player].has_relic:
		options.append({"kind": "take_relic", "target": "", "position": game.relic.position, "radius": Map.USE_RADIUS, "text": "E · Take relic"})
	if game.lantern.has("position"):
		options.append({"kind": "take_light", "target": "", "position": game.lantern.position, "radius": 38.0, "text": "E · Pick up lantern"})
	if game.extraction.has("position") and Map.extraction_rect().has_point(position):
		options.append({"kind": "begin_extraction", "target": "", "position": game.extraction.position, "radius": Map.USE_RADIUS, "text": "Hold E · Escape with relic" if game.explorers[active_player].has_relic else "Hold E · Escape empty-handed"})
	for control in game.vault:
		var state: Dictionary = game.vault[control]
		if state.locked: options.append({"kind": "begin_vault", "target": control, "position": state.position, "radius": Map.CONTROL_RADIUS, "text": "Hold E · Vault control %s · partner holds the other" % control})
	if not game.valve.is_empty():
		options.append({"kind": "begin_valve", "target": "", "position": Map.valve_position(), "radius": Map.USE_RADIUS, "text": "Hold E · Feed %s" % ("service passage" if game.valve.mode == "main" else "main crossing")})
	for door_id in game.doors:
		var state: Dictionary = game.doors[door_id]
		if state.locked: continue
		var text_value := "E · Close door" if state.target_open else "E · Open door"
		if state.state == "obstructed": text_value = "Door blocked · clear doorway · E to open"
		elif state.refuge: text_value = "E · Open sealed dry refuge" if state.sealed_safe else "E · Close refuge before water arrives" if state.target_open else "E · Open refuge door"
		options.append({"kind": "toggle_door", "target": door_id, "position": state.position, "radius": Map.USE_RADIUS, "text": text_value})
	var best: Dictionary = {}
	var distance := INF
	for option in options:
		var blocked := closed.duplicate()
		if option.kind == "toggle_door": blocked.erase(option.target)
		var reach := position.distance_to(option.position)
		if reach > option.radius or reach >= distance or not Map.line_of_sight(position, option.position, blocked): continue
		distance = reach
		best = option
	return best
func _use_light(kind: String) -> void:
	if intro or phase != "running" or show_help or not focused or game.explorers[active_player].state != "exploring": return
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
			"begin_vault": accepted = fixture.begin_vault(active_player, target, interaction_sequence)
			"take_relic", "drop_relic": accepted = fixture.use_relic(active_player, kind, interaction_sequence)
			"begin_extraction": accepted = fixture.begin_extraction(active_player, interaction_sequence)
			"keep_interaction": accepted = fixture.keep_interaction(active_player, interaction_sequence)
			"cancel_interaction": accepted = fixture.cancel_interaction(active_player, interaction_sequence)
			"chest", "puzzle", "heal", "fire", "cancel_puzzle":
				if fixture.expedition != null: accepted = fixture.expedition.event(fixture, active_player, kind, target, interaction_sequence)
		if accepted: _on_state(View.project(fixture, active_player))
	else: session.interaction(command)
func _use_nearest() -> void:
	if intro or phase != "running" or show_help or not focused or game.explorers[active_player].state != "exploring": return
	if puzzle_panel.visible or blueprint.visible: return
	var nearby := _nearby_interaction()
	if nearby.is_empty(): return
	interaction_hold_active = nearby.kind in ["begin_valve", "begin_vault", "begin_extraction"]
	hold_refresh_ticks = 0
	_send_interaction(nearby.kind, nearby.target)
func _drop_carried() -> void:
	if intro or phase != "running" or show_help or not focused or game.explorers[active_player].state != "exploring": return
	if game.explorers[active_player].has_relic: _send_interaction("drop_relic")
	else: _use_light("drop_light")
func _cancel_interaction_hold() -> void:
	if not interaction_hold_active: return
	interaction_hold_active = false
	if not intro and phase == "running": _send_interaction("cancel_interaction")
func _direction() -> Vector2:
	if intro or phase not in ["running", "waiting"] or show_help or not focused or game.explorers[active_player].state != "exploring": return Vector2.ZERO
	if puzzle_panel.visible or blueprint.visible: return Vector2.ZERO
	if explorer_sprites[active_player].picking_up(): return Vector2.ZERO
	if get_viewport().gui_get_focus_owner() is LineEdit: return Vector2.ZERO
	return Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).limit_length(1)
func _step_movement(direction: Vector2) -> void:
	if interaction_hold_active:
		hold_refresh_ticks += 1
		if hold_refresh_ticks >= 4:
			hold_refresh_ticks = 0
			_send_interaction("keep_interaction")
	var command := prediction.advance(direction)
	if fixture != null:
		fixture.set_input(active_player, command.direction, command.sequence)
		fixture.step()
		if fixture.finished or fixture.tick % 2 == 0: _on_state(View.project(fixture, active_player))
	elif phase == "waiting": session.lobby_movement(command)
	else: session.movement(command)
func _stop_movement() -> void:
	if intro or game == null: return
	var command := prediction.advance(Vector2.ZERO)
	prediction.pending.clear()
	prediction.position = game.explorers[active_player].position
	movement_view.reset(prediction.position)
	if fixture != null: fixture.set_input(active_player, Vector2.ZERO, command.sequence)
	elif phase == "waiting": session.lobby_movement(command)
	else: session.movement(command)
func _process(delta: float) -> void:
	city_caption.hide()
	elapsed += delta
	hud.advance(delta, reduced_motion)
	puzzle_panel.advance(delta)
	if intro or game == null: return
	if phase in ["running", "waiting"]:
		accumulator += minf(delta, 0.25)
		while accumulator >= Rules.STEP:
			accumulator -= Rules.STEP
			_step_movement(_direction())
	var direction := _direction()
	for i in range(game.explorers.size()):
		var p: Dictionary = game.explorers[i]
		if p.state == "hidden":
			explorer_sprites[i].hide()
			continue
		var target: Vector2
		if i == active_player:
			target = movement_view.sample(prediction, direction, accumulator, delta)
		else:
			remote_clock[i] = minf(remote_clock.get(i, 0.0) + delta, 0.1)
			target = remote_from[i].lerp(remote_to[i], remote_clock[i] / 0.1)
		var before: Vector2 = token_positions.get(i, target)
		var displacement := target - before
		if i == active_player:
			# A correction while still/turning is not a step or a pickup cancellation.
			var axis := direction.normalized()
			displacement = axis * maxf(0.0, displacement.dot(axis))
		walking[i] = displacement.length() > 0.1
		token_positions[i] = target
		_update_explorer(i, delta, displacement)
	_update_vision()
	_update_monsters(delta)
	queue_redraw()
func _update_explorer(i: int, delta: float, displacement: Vector2) -> void:
	var p: Dictionary = game.explorers[i]
	var closed := Map.closed_door_ids(game.doors)
	var actor = explorer_sprites[i]
	actor.visible = p.state not in ["hidden", "escaped"] and (i == active_player or Map.can_see(prediction.position, p.position, game.explorers[active_player].has_light, closed))
	if not actor.visible: return
	actor.position = token_positions[i]
	actor.z_index = roundi(actor.position.y) + 1
	actor.has_relic = p.has_relic
	actor.has_light = p.has_light
	actor.drowned = p.state in ["drowned", "injured"]
	actor.modulate = Color(1.0, 0.66, 0.64) if p.get("hurt", false) else Color(0.7, 0.85, 0.95) if p.get("stunned", false) else Color.WHITE
	actor.reduced_motion = reduced_motion
	var carrying: bool = p.has_relic or p.has_light
	var action := "dual_walk" if p.has_relic and p.has_light else "relic_walk" if p.has_relic else "lantern_walk" if p.has_light else "walk"
	var aim := Vector2.ZERO
	var using_mechanism := false
	var depth: float = game.water_depths.get(p.region, p.get("region_depth", 0.0))
	actor.water_depth = depth
	if depth >= Map.WADING_DEPTH and not carrying: action = "wade"
	if i == active_player and interaction_hold_active:
		using_mechanism = true
		var target_kind: String = game.interaction.get("kind", "")
		var control: String = game.interaction.get("target", "")
		if target_kind == "begin_valve": aim = Map.valve_position() - actor.position
		elif target_kind == "begin_vault" and Map.VAULT_CONTROLS.has(control): aim = Map.vault_control_position(control) - actor.position
	else:
		for control in game.vault:
			var mechanism: Dictionary = game.vault[control]
			if mechanism.held and actor.position.distance_to(mechanism.position) < Map.CONTROL_RADIUS and not walking.get(i, false):
				using_mechanism = true
				aim = mechanism.position - actor.position
	if using_mechanism:
		if not carrying: action = "use"
		elif not actor.picking_up(): actor.motion.look_towards(aim)
	if actor.drowned: action = "down"
	if p.state == "injured" or p.get("stunned", false): action = "down"
	if i == active_player and puzzle_panel.visible and not carrying:
		action = "use"
		aim = Map.chest_anchors[game.puzzle.chest].position - actor.position
	actor.advance_visual(delta, displacement, action, aim)
	actor.queue_redraw()
func _draw() -> void:
	if intro or game == null: return
	_draw_objects()
	var closed := Map.closed_door_ids(game.doors)
	if lantern_texture and game.lantern.has("position") and Map.can_see(prediction.position, game.lantern.position, game.explorers[active_player].has_light, closed):
		var size: Vector2 = lantern_texture.get_size() * (44.0 / 60.0)
		draw_texture_rect(lantern_texture, Rect2(game.lantern.position - Vector2(size.x / 2, size.y), size), false)
func _draw_objects() -> void:
	if Map.id != "prototype":
		_draw_expansion_objects()
		return
	for id in game.doors:
		if game.doors[id].sealed_safe and mechanisms.doors[id].anchor.visible:
			draw_string(font, Map.door_position(id) + Vector2(-14, -64), "DRY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
	if game.relic.has("position"):
		var size: Vector2 = relic_texture.get_size() * (44.0 / 60.0)
		draw_texture_rect(relic_texture, Rect2(game.relic.position - Vector2(size.x / 2, size.y), size), false)
	for control in game.vault:
		var state: Dictionary = game.vault[control]
		if not state.locked: continue
		if not mechanisms.wheels[control].visible: continue
		var cue: String = "%s %d%%" % [control, roundi(state.progress * 100)] if state.held else str(control)
		draw_string(font, state.position + Vector2(-8, -46), cue, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
	if game.extraction.has("position"):
		draw_string(font, game.extraction.position + Vector2(-25, 17), "ESCAPE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
func _toggle_help() -> void:
	show_help = not show_help
	help_panel.visible = show_help
	if show_help:
		_cancel_interaction_hold()
		_stop_movement()
func _restart() -> void:
	_stop_movement()
	session.close()
	fixture = null
	game = null
	water_layer.set_depths({})
	intro = true
	phase = "lobby"
	show_help = false
	interaction_hold_active = false
	help_panel.hide()
	results_panel.hide()
	survival_label.hide()
	opening.show()
	city_caption.show()
	art.hide()
	water_layer.hide()
	vision.hide()
	mechanisms.hide()
	controls_label.hide()
	tide_label.hide()
	prompt_label.text = ""
	camera.position = Map.spawn(0)
	vision.update_view(camera.position, Map.vision_radius(camera.position))
	vision.set_closed_doors([])
	token_positions.clear()
	for actor in explorer_sprites:
		actor.hide()
		actor.reset_visual()
	prediction = Prediction.new()
	movement_view = MovementView.new()
	code_field.text = ""
	code_field.editable = true
	for button in [host_button, join_button, refresh_button, count_picker]: button.disabled = false
	start_button.hide()
	room_list.show()
	room_list.clear()
	available_rooms.clear()
	lobby_label.text = "Create a room or join a friend."
	status_label.text = "2–4 explorers online"
	_show_start()
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
		KEY_Q: _drop_carried()
		KEY_H: _toggle_help()
		KEY_V: reduced_motion = not reduced_motion
		KEY_R: _restart()
		KEY_M: _toggle_map()
		KEY_1: _hud_action("heal", "")
		KEY_F: _fire()
		KEY_SPACE:
			if phase == "waiting": session.set_ready(not lobby_ready)
			elif puzzle_panel.visible and game.puzzle.get("kind", "") == "pressure": puzzle_panel.submit(0)
		KEY_ESCAPE:
			if puzzle_panel.visible: _send_interaction("cancel_puzzle")
			elif blueprint.visible: blueprint.hide()
			elif show_help: _toggle_help()
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

func _build_expansion_ui() -> void:
	city_caption.hide()
	opening.position = Vector2(70, 175)
	opening.size = Vector2(580, 515)
	opening.hide()
	start_screen = PanelContainer.new()
	start_screen.position = Vector2(85, 220)
	start_screen.custom_minimum_size = Vector2(515, 275)
	start_screen.add_theme_stylebox_override("panel", _style(Color(0.025, 0.07, 0.10, 0.95)))
	ui.add_child(start_screen)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 23)
	start_screen.add_child(column)
	column.add_child(_label("RELIC TIDE", 54, GOLD))
	column.add_child(_label("Take the relic. Trust no one. Beat the tide.", 20))
	column.add_child(_button("START", _open_rooms, 260))
	column.add_child(_label("2–4 explorers · online", 17, MUTED))
	waiting_panel = PanelContainer.new()
	waiting_panel.position = Vector2(25, 230)
	waiting_panel.custom_minimum_size = Vector2(275, 0)
	waiting_panel.add_theme_stylebox_override("panel", _style(GLASS))
	ui.add_child(waiting_panel)
	var waiting_box := VBoxContainer.new()
	waiting_box.add_theme_constant_override("separation", 18)
	waiting_panel.add_child(waiting_box)
	waiting_label = _label("", 22, GOLD)
	waiting_box.add_child(waiting_label)
	for entry in Maps.catalogue():
		var map_id: String = entry.id
		var name: String = entry.name.replace("The ", "")
		var button := _button(name, func(): session.select_map(map_id), 238)
		button.tooltip_text = entry.description
		waiting_box.add_child(button)
		map_buttons.append(button)
	ready_button = _button("Ready", func(): session.set_ready(not lobby_ready), 238)
	waiting_box.add_child(ready_button)
	start_button.get_parent().remove_child(start_button)
	waiting_box.add_child(start_button)
	waiting_panel.hide()
	help_panel.position = Vector2(390, 225)
	hud = HUD.new()
	hud.font = font
	hud.Map = Map
	ui.add_child(hud)
	hud.hide()
	hud.action.connect(_hud_action)
	blueprint = Blueprint.new()
	blueprint.font = font
	blueprint.Map = Map
	ui.add_child(blueprint)
	puzzle_panel = Puzzle.new()
	puzzle_panel.font = font
	puzzle_panel.icons = hud
	ui.add_child(puzzle_panel)
	puzzle_panel.action.connect(_hud_action)
	if ResourceLoader.exists("res://assets/generated/sprites/brine-stalker-v1/frames.tres"):
		monster_frames = load("res://assets/generated/sprites/brine-stalker-v1/frames.tres")

func _bind_map(map_id: String) -> void:
	if Map.id == map_id: return
	Map = Maps.new(map_id)
	for layer in [world, water_layer, vision, mechanisms]:
		if layer != null:
			remove_child(layer)
			layer.queue_free()
	world = null
	if Map.id != "prototype":
		world = World.new()
		world.Map = Map
		add_child(world)
		var sheet: Texture2D = load("res://assets/generated/environment/expedition-props-v1.png")
		var regions := {"boat": Rect2(9, 120, 420, 360), "valve": Rect2(465, 105, 332, 355), "shelf": Rect2(820, 117, 403, 335), "pedestal": Rect2(1235, 202, 300, 257), "urns": Rect2(135, 615, 259, 320), "sarcophagus": Rect2(528, 530, 246, 409), "torch": Rect2(894, 575, 137, 342), "engine": Rect2(1162, 529, 353, 403)}
		for prop in Map.prop_specs:
			world.add_prop(world.crop(regions[prop.kind], sheet), prop.position, prop.height, prop.region)
	water_layer = Water.new()
	water_layer.Map = Map
	water_layer.z_index = -1
	add_child(water_layer)
	vision = Vision.new()
	vision.Map = Map
	add_child(vision)
	mechanisms = Mechanisms.new()
	mechanisms.Map = Map
	add_child(mechanisms)
	hud.Map = Map
	blueprint.Map = Map
	blueprint.hide()
	for monster in monster_sprites.values(): monster.sprite.queue_free()
	monster_sprites.clear()

func _show_start() -> void:
	_bind_map("lagoon")
	start_screen.show()
	opening.hide()
	waiting_panel.hide()
	hud.hide()
	puzzle_panel.hide()
	blueprint.hide()
	status_label.hide()
	title_label.hide()
	city_caption.hide()
	art.hide()
	water_layer.hide()
	mechanisms.hide()
	vision.show()
	camera.zoom = Vector2.ONE * 1.05
	camera.position = Map.region_center("R0") - Vector2(280, 0)
	vision.update_view(Map.region_center("R0"), 1250.0)
	vision.set_closed_doors(Map.DOORS.keys())
	if world:
		world.show()
		world.update_view(null, Map.region_center("R0"), 1250.0, false, true)

func _open_rooms() -> void:
	start_screen.hide()
	opening.show()
	_refresh_rooms()

func _hud_action(kind: String, target: String) -> void:
	if kind == "show_map":
		_toggle_map()
		return
	if kind == "fire":
		_fire()
		return
	if kind.is_empty() or game == null or phase != "running" or show_help: return
	_send_interaction(kind, target)

func _toggle_map() -> void:
	if game == null or phase != "running" or not game.explorers[active_player].get("gear", {}).get("map", false): return
	blueprint.visible = not blueprint.visible
	if blueprint.visible:
		_cancel_interaction_hold()
		_stop_movement()
	blueprint.queue_redraw()

func _fire() -> void:
	if game == null or phase != "running" or show_help or puzzle_panel.visible or blueprint.visible or not focused: return
	var own: Dictionary = game.explorers[active_player]
	if not own.get("gear", {}).get("gun", false): return
	var aim := prediction.position.direction_to(get_global_mouse_position())
	if aim.is_zero_approx(): aim = own.get("facing", Vector2.DOWN)
	var direction_id := posmod(roundi((aim.angle() - PI * 0.5) / (TAU / 8.0)), 8)
	_send_interaction("fire", str(direction_id))

func _draw_expansion_objects() -> void:
	if world == null: return
	for chest_id in game.chests:
		var chest: Dictionary = game.chests[chest_id]
		var dimensions := Vector2(43, 38)
		draw_texture_rect(world.chest_texture, Rect2(chest.position - Vector2(21.5, 30), dimensions), false, Color(0.7, 0.8, 0.76) if chest.claimed else Color.WHITE)
		if not chest.opened: draw_texture_rect(hud.icon("treasure"), Rect2(chest.position + Vector2(-9, -50), Vector2(18, 18)), false)
	for breach in game.breaches:
		var location: Vector2 = Map.region_center(breach.region)
		var warning: bool = game.tide_seconds < breach.start
		var tint := Color("edc47b") if warning else Color("ef786f")
		draw_texture_rect(hud.icon("wave"), Rect2(location + Vector2(-20, -44), Vector2(40, 40)), false, tint)
		if warning:
			var progress: float = clampf((game.tide_seconds - breach.warned) / maxf(0.1, breach.start - breach.warned), 0.0, 1.0)
			draw_rect(Rect2(location + Vector2(-17, -1), Vector2(34 * progress, 3)), tint)
	for region in game.gas:
		var location: Vector2 = Map.region_center(region)
		draw_texture_rect(hud.icon("mask"), Rect2(location + Vector2(-20, -50), Vector2(40, 40)), false, Color("85e1d1"))
	for control in game.vault:
		var state: Dictionary = game.vault[control]
		if not state.locked: continue
		draw_texture_rect(hud.icon("refuge"), Rect2(state.position + Vector2(-10, -55), Vector2(20, 20)), false, GOLD if state.held else MUTED)
	if game.extraction.has("position"):
		draw_texture_rect(hud.icon("open_door"), Rect2(game.extraction.position + Vector2(-18, 12), Vector2(36, 36)), false)
	for id in game.doors:
		if game.doors[id].get("sealed_safe", false): draw_texture_rect(hud.icon("refuge"), Rect2(Map.door_position(id) + Vector2(-17, -68), Vector2(34, 34)), false)
	if game.relic.has("position"):
		var dimensions: Vector2 = relic_texture.get_size() * (44.0 / 60.0)
		draw_texture_rect(relic_texture, Rect2(game.relic.position - Vector2(dimensions.x / 2, dimensions.y), dimensions), false)
	for shot in game.shots:
		var direction: Vector2 = shot.position.direction_to(shot.end)
		draw_set_transform(shot.position.lerp(shot.end, 0.7), direction.angle(), Vector2.ONE)
		draw_texture_rect(hud.icon("dart"), Rect2(-14, -5, 28, 10), false)
		draw_set_transform(Vector2.ZERO)
	if phase == "waiting" and not lobby_info.is_empty():
		for i in range(game.explorers.size()):
			var location: Vector2 = token_positions.get(i, game.explorers[i].position)
			draw_texture_rect(hud.icon("refuge"), Rect2(location + Vector2(-12, -80), Vector2(24, 24)), false, GOLD if lobby_info.ready[i] else Color(0.5, 0.7, 0.75, 0.4))

func _update_monsters(delta: float) -> void:
	if monster_frames == null or game == null: return
	var observed: Array[int] = []
	for monster in game.monsters:
		observed.append(monster.id)
		if not monster_sprites.has(monster.id):
			var sprite := AnimatedSprite2D.new()
			sprite.sprite_frames = monster_frames
			sprite.centered = false
			sprite.scale = Vector2.ONE * monster_frames.get_meta("display_scale", 0.72)
			sprite.offset = -monster_frames.get_meta("foot_anchor", Vector2(60, 99))
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var unlit := CanvasItemMaterial.new()
			unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
			sprite.material = unlit
			add_child(sprite)
			monster_sprites[monster.id] = {"sprite": sprite, "tick": -1, "from": monster.position, "to": monster.position, "clock": 0.0, "facing": "south"}
		var state: Dictionary = monster_sprites[monster.id]
		var sprite: AnimatedSprite2D = state.sprite
		if state.tick != game.tick:
			state.from = sprite.position if state.tick >= 0 else monster.position
			state.to = monster.position
			state.clock = 0.0
			state.tick = game.tick
		state.clock = minf(0.1, state.clock + delta)
		sprite.position = state.from.lerp(state.to, state.clock / 0.1)
		sprite.z_index = roundi(sprite.position.y) + 1
		if monster.velocity.length() > 1.0:
			var direction: Vector2 = monster.velocity.normalized()
			state.facing = ["south", "south-west", "west", "north-west", "north", "north-east", "east", "south-east"][posmod(roundi((direction.angle() - PI * 0.5) / (TAU / 8.0)), 8)]
		var action: String = "stun" if monster.stunned else "attack" if monster.attacking else "walk" if monster.velocity.length() > 1.0 else "idle"
		var animation: String = action + "_" + state.facing.replace("-", "_")
		if sprite.animation != animation: sprite.play(animation)
	for id in monster_sprites.keys():
		if id not in observed:
			monster_sprites[id].sprite.queue_free()
			monster_sprites.erase(id)
