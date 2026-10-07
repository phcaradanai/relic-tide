extends Control
## Static geography unlocked by a collected map. No remote actor data.
var Map
var own_position := Vector2.ZERO
var font: Font
const INSET := Vector2(380, 178)
const SCALE := 0.18
func _ready() -> void:
	size = Vector2(1440, 900)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
func _draw() -> void:
	if Map == null or not visible: return
	draw_rect(Rect2(345, 110, 750, 665), Color(0.025, 0.09, 0.12, 0.97))
	draw_string(font, Vector2(380, 153), "RUIN MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color("edc47b"))
	for region: String in Map.REGIONS:
		for rect: Rect2 in Map.floors(region):
			var projected := Rect2(INSET + rect.position * SCALE, rect.size * SCALE)
			draw_rect(projected, Color("487277"))
			draw_rect(projected, Color("b9d3d3"), false, 1.0)
	for region: String in Map.room_specs:
		var centre: Vector2 = INSET + Map.room_specs[region].centre * SCALE
		var short_name: String = Map.NAMES[region]
		short_name = short_name.replace(" Room", "").replace("Inner ", "").replace(" Gallery", "")
		var width := font.get_string_size(short_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, centre - Vector2(width * 0.5, 4), short_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f1ead6"))
	draw_circle(INSET + own_position * SCALE, 5.0, Color("edc47b"))
	draw_string(font, Vector2(380, 740), "M · close", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("b9d3d3"))
