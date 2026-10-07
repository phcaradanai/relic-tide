extends PanelContainer
## A private, live puzzle display. Authority validates every button action.
signal action(kind: String, target: String)
var font: Font
var icons
var heading: Label
var hint: Label
var sequence_row: HBoxContainer
var controls: HBoxContainer
var pressure: ProgressBar
var progress: ProgressBar
var challenge: Dictionary = {}
var tick := 0
var local_clock := 0.0
var buttons: Array[Button] = []
var seals := ["wave", "treasure", "refuge", "air"]

func _ready() -> void:
	position = Vector2(505, 245)
	custom_minimum_size = Vector2(430, 325)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0a202b")
	style.set_corner_radius_all(12)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	add_child(column)
	heading = Label.new()
	heading.add_theme_font_override("font", font)
	heading.add_theme_font_size_override("font_size", 25)
	heading.add_theme_color_override("font_color", Color("edc47b"))
	column.add_child(heading)
	hint = Label.new()
	hint.add_theme_font_override("font", font)
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color("b9d3d3"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 378
	column.add_child(hint)
	sequence_row = HBoxContainer.new()
	sequence_row.add_theme_constant_override("separation", 15)
	column.add_child(sequence_row)
	for i in range(4):
		var seal := TextureRect.new()
		seal.custom_minimum_size = Vector2(60, 60)
		seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sequence_row.add_child(seal)
	pressure = ProgressBar.new()
	pressure.custom_minimum_size = Vector2(378, 24)
	pressure.max_value = 1.0
	pressure.show_percentage = false
	pressure.draw.connect(_draw_pressure)
	column.add_child(pressure)
	controls = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 15)
	column.add_child(controls)
	for i in range(4):
		var button := Button.new()
		button.custom_minimum_size = Vector2(78, 63)
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 18)
		button.expand_icon = true
		button.icon = icons.icon(seals[i])
		var slot := i
		button.pressed.connect(func(): submit(slot))
		controls.add_child(button)
		buttons.append(button)
	progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(378, 6)
	progress.show_percentage = false
	progress.max_value = 1.0
	column.add_child(progress)
	var leave := Button.new()
	leave.text = "Close [Esc]"
	leave.custom_minimum_size.y = 36
	leave.pressed.connect(func(): action.emit("cancel_puzzle", ""))
	column.add_child(leave)
	hide()

func submit(index: int) -> void:
	if challenge.is_empty() or not visible: return
	if challenge.kind == "pressure": index = 0
	action.emit("puzzle", "%s:%d:%d" % [challenge.chest, challenge.nonce, index])

func update_state(view) -> void:
	challenge = view.puzzle.duplicate(true)
	tick = view.tick
	local_clock = 0.0
	visible = view.phase == "running" and not challenge.is_empty()
	if not visible: return
	var kind: String = challenge.kind
	heading.text = {"runes": "Ancient seals", "circuit": "Restore the circuit", "pressure": "Balance the pressure"}[kind]
	hint.text = {"runes": "Remember the four seals, then repeat their order.", "circuit": "Match the three switches to the lit seals above.", "pressure": "Press while the gauge is between the two markers. Three steady hits."}[kind]
	pressure.visible = kind == "pressure"
	sequence_row.visible = kind != "pressure"
	for i in range(4):
		var seal: TextureRect = sequence_row.get_child(i)
		seal.texture = icons.icon(seals[challenge.sequence[i]]) if kind == "runes" else icons.icon("refuge")
		seal.visible = kind == "runes" or i < 3
		if kind == "circuit": seal.modulate = Color("edc47b") if challenge.target_bits & (1 << i) else Color(0.2, 0.35, 0.38, 1)
		buttons[i].visible = kind == "runes" or (kind == "circuit" and i < 3) or (kind == "pressure" and i == 0)
		buttons[i].text = "Hit [Space]" if kind == "pressure" and i == 0 else ""
		buttons[i].custom_minimum_size.x = 180 if kind == "pressure" and i == 0 else 78
		buttons[i].disabled = false
		buttons[i].modulate = Color("edc47b") if kind == "circuit" and challenge.bits & (1 << i) else Color.WHITE
	progress.value = float(challenge.progress) / 4.0 if kind == "runes" else float(challenge.hits) / 3.0 if kind == "pressure" else 0.0
	_render_phase()

func advance(delta: float) -> void:
	if not visible: return
	local_clock += delta
	_render_phase()

func _render_phase() -> void:
	if challenge.is_empty(): return
	var since: float = (tick - challenge.started_tick) * 0.05 + minf(local_clock, 0.1)
	if challenge.kind == "runes":
		for seal in sequence_row.get_children(): seal.modulate = Color.WHITE if since < 2.5 else Color(0.1, 0.2, 0.24, 1)
		for button in buttons: button.disabled = since < 2.5
	elif challenge.kind == "pressure":
		var phase_value := fmod(since / 2.6, 2.0)
		pressure.value = phase_value if phase_value <= 1.0 else 2.0 - phase_value
		hint.text = "Target %d–%d · %d / 3" % [roundi((challenge.pressure_target - 0.14) * 100), roundi((challenge.pressure_target + 0.14) * 100), challenge.hits]
		pressure.queue_redraw()

func _draw_pressure() -> void:
	if challenge.is_empty() or challenge.kind != "pressure" or not pressure.visible: return
	for edge in [challenge.pressure_target - 0.14, challenge.pressure_target + 0.14]:
		var x: float = pressure.size.x * edge
		pressure.draw_line(Vector2(x, 0), Vector2(x, pressure.size.y), Color("edc47b"), 3.0)
