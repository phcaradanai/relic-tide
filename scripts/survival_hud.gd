extends Control
## Authored raster icons + compact gauges. Inventory is the local private view.
signal action(kind: String, target: String)
const SHEET = preload("res://assets/generated/environment/survival-icons-v1.png")
const ICON_NAMES := ["heart", "empty_heart", "air", "wave", "map", "chart", "oxygen", "mask", "medkit", "gun", "dart", "treasure", "closed_door", "open_door", "monster", "refuge"]
const ITEMS := ["map", "chart", "oxygen", "mask", "medkit", "gun"]
const ITEM_HOTKEYS := {"medkit": "1", "map": "2", "gun": "F"}
var icons: Dictionary = {}
var view = null
var Map
var font: Font
var tide: ProgressBar
var air: ProgressBar
var item_buttons: Dictionary = {}
var item_badges: Dictionary = {}
var key_hint_style: StyleBoxFlat
var final_panel: PanelContainer
var alarm_number := -1
var alarm_clock := 0.0
var flash_clock := 0.0
var prompt_active := false
var prompt_point := Vector2.ZERO
var prompt_progress := 0.0
var prompt_hold := false

func icon(name: String) -> Texture2D:
	if not icons.has(name):
		var index: int = ICON_NAMES.find(name)
		var cell := SHEET.get_size() / 4.0
		var crop := AtlasTexture.new()
		crop.atlas = SHEET
		crop.region = Rect2(Vector2(index % 4, index / 4) * cell, cell)
		icons[name] = crop
	return icons[name]

func _bar(location: Vector2, dimensions: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = location
	bar.size = dimensions
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = Color("0a202b")
	track.set_corner_radius_all(5)
	track.border_color = Color("b9d3d3")
	track.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	add_child(bar)
	return bar

func _ready() -> void:
	size = Vector2(1440, 900)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tide = _bar(Vector2(538, 30), Vector2(420, 15), Color("85e1d1"))
	tide.tooltip_text = "Tide deadline · evacuate before this fills"
	air = _bar(Vector2(72, 93), Vector2(142, 12), Color("b9e8f0"))
	air.hide()
	key_hint_style = StyleBoxFlat.new()
	key_hint_style.bg_color = Color("102630")
	key_hint_style.border_color = Color("edc47b")
	key_hint_style.set_border_width_all(1)
	key_hint_style.set_corner_radius_all(4)
	for index in range(ITEMS.size()):
		var item: String = ITEMS[index]
		var button := Button.new()
		button.position = Vector2(24 + index * 61, 819)
		button.size = Vector2(50, 50)
		button.icon = icon(item)
		button.expand_icon = true
		button.tooltip_text = {"map": "Map [2] · reveal structure", "chart": "Treasure bearing", "oxygen": "Oxygen · cross submerged routes", "mask": "Gas mask · toxic air protection", "medkit": "Heal one heart [1]", "gun": "Tranquilizer [F] · aim toward mouse"}[item]
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.025, 0.07, 0.10, 0.86)
		style.set_corner_radius_all(6)
		style.content_margin_left = 4
		style.content_margin_right = 4
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("disabled", style)
		var focus := style.duplicate()
		focus.border_color = Color("edc47b")
		focus.set_border_width_all(2)
		button.add_theme_stylebox_override("focus", focus)
		button.pressed.connect(func(): action.emit("heal" if item == "medkit" else "show_map" if item == "map" else "fire" if item == "gun" else "", ""))
		if ITEM_HOTKEYS.has(item):
			var badge := Panel.new()
			badge.position = Vector2(29, 1)
			badge.size = Vector2(19, 18)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.add_theme_stylebox_override("panel", key_hint_style)
			badge.visible = false
			var key_label := Label.new()
			key_label.text = ITEM_HOTKEYS[item]
			key_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			key_label.add_theme_font_override("font", font)
			key_label.add_theme_font_size_override("font_size", 13)
			key_label.add_theme_color_override("font_color", Color("f1ead6"))
			key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.add_child(key_label)
			button.add_child(badge)
			item_badges[item] = badge
		add_child(button)
		item_buttons[item] = button
	final_panel = PanelContainer.new()
	final_panel.position = Vector2(390, 275)
	final_panel.custom_minimum_size = Vector2(660, 190)
	final_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var alarm_style := StyleBoxFlat.new()
	alarm_style.bg_color = Color("491e29")
	alarm_style.set_corner_radius_all(12)
	final_panel.add_theme_stylebox_override("panel", alarm_style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	final_panel.add_child(row)
	var wave := TextureRect.new()
	wave.texture = icon("wave")
	wave.custom_minimum_size = Vector2(145, 145)
	wave.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wave.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(wave)
	var label := Label.new()
	label.text = "EVACUATE\nReturn to the Landing"
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color("f1ead6"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	add_child(final_panel)
	final_panel.hide()

func update_state(snapshot) -> void:
	view = snapshot
	visible = view != null and view.phase == "running" and view.map_id != "prototype"
	if not visible: return
	var own: Dictionary = view.explorers[view.player]
	tide.value = clampf(view.tide_seconds / view.duration, 0.0, 1.0)
	var fill: StyleBoxFlat = tide.get_theme_stylebox("fill")
	fill.bg_color = Color("ef786f") if view.final_alarm else Color("edc47b") if tide.value > 0.70 else Color("85e1d1")
	air.visible = own.region_depth >= 1.2
	air.value = own.breath / own.get("breath_max", 20.0)
	if own.get("oxygen_enabled", false): air.value = own.tank / 55.0
	for item in ITEMS:
		var owned: bool = bool(own.gear.get(item, false))
		if item == "medkit": owned = int(own.gear.get(item, 0)) > 0
		var button: Button = item_buttons[item]
		button.modulate = Color.WHITE if owned else Color(0.6, 0.72, 0.74, 0.38)
		button.disabled = not owned or item in ["chart", "oxygen", "mask"] or (item == "gun" and own.ammo <= 0) or (item == "medkit" and own.health >= 3)
		if item_badges.has(item): item_badges[item].visible = owned
	if view.alarm_serial != alarm_number:
		alarm_number = view.alarm_serial
		if view.final_alarm:
			alarm_clock = 0.0
			final_panel.show()
	queue_redraw()

func advance(delta: float, reduced: bool) -> void:
	flash_clock += delta
	if final_panel.visible:
		alarm_clock += delta
		if alarm_clock > (5.0 if reduced else 3.2): final_panel.hide()
	queue_redraw()

func set_prompt(location: Vector2, progress: float = 0.0, hold: bool = false) -> void:
	prompt_active = true
	prompt_point = Vector2(clampf(location.x, 50, 1390), clampf(location.y, 140, 760))
	prompt_progress = progress
	prompt_hold = hold
	queue_redraw()

func clear_prompt() -> void:
	prompt_active = false
	prompt_progress = 0.0
	prompt_hold = false
	queue_redraw()

func _icon_draw(name: String, location: Vector2, dimensions: Vector2, tint: Color = Color.WHITE) -> void:
	draw_texture_rect(icon(name), Rect2(location, dimensions), false, tint)

func _draw() -> void:
	if view == null or not visible: return
	var own: Dictionary = view.explorers[view.player]
	for heart in range(3): _icon_draw("heart" if heart < own.health else "empty_heart", Vector2(24 + heart * 46, 23), Vector2(40, 40))
	_icon_draw("wave", Vector2(485, 12), Vector2(46, 46))
	_icon_draw("open_door", Vector2(975, 15), Vector2(38, 38))
	if air.visible: _icon_draw("air", Vector2(24, 75), Vector2(39, 39))
	if own.get("tank", 0.0) > 0:
		draw_string(font, Vector2(151, 810), "%ds" % ceili(own.tank), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("b9e8f0"))
	if own.get("ammo", 0) > 0: draw_string(font, Vector2(341, 810), str(own.ammo), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f1ead6"))
	if own.gear.medkit > 0: draw_string(font, Vector2(283, 810), str(own.gear.medkit), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f1ead6"))
	_icon_draw("treasure", Vector2(1301, 819), Vector2(40, 40))
	draw_string(font, Vector2(1354, 850), str(own.treasure + (100 if own.has_relic else 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("edc47b"))
	if view.hunt_active: _icon_draw("monster", Vector2(1045, 14), Vector2(44, 44))
	if own.get("stunned", false): _icon_draw("dart", Vector2(164, 23), Vector2(36, 36))
	if not view.treasure_bearing.is_empty() or view.final_alarm:
		var direction: Vector2 = view.treasure_bearing.get("direction", Vector2.UP)
		if view.final_alarm:
			direction = own.position.direction_to(Map.extraction_position())
		_icon_draw("open_door" if view.final_alarm else "chart", Vector2(693, 791), Vector2(54, 54))
		# A simple directional UI arrow, not scenery or a remote actor marker.
		var centre := Vector2(720, 862)
		var side := Vector2(-direction.y, direction.x)
		draw_colored_polygon(PackedVector2Array([centre + direction * 16, centre - direction * 9 + side * 7, centre - direction * 9 - side * 7]), Color("ef786f") if view.final_alarm else Color("edc47b"))
	if view.final_alarm:
		var remaining := maxi(0, ceili(view.duration - view.tide_seconds))
		draw_rect(Rect2(654, 57, 136, 34), Color("0a202b"))
		draw_string(font, Vector2(673, 78), "%d:%02d" % [remaining / 60, remaining % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("ef9990"))
	if prompt_active:
		var box := Rect2(prompt_point - Vector2(17, 16), Vector2(34, 32))
		draw_style_box(key_hint_style, box)
		draw_string(font, Vector2(box.position.x, box.position.y + 22), "E", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 19, Color("f1ead6"))
		if prompt_hold: draw_rect(Rect2(box.position + Vector2(0, 35), Vector2(34 * clampf(prompt_progress, 0, 1), 3)), Color("edc47b"))
