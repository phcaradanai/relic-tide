extends Node2D
## Painted physical parts, with feet-based depth ordering and local visibility.
const Maps = preload("res://scripts/expedition_map.gd")
var Map = Maps.new()
const SHEET = preload("res://assets/generated/environment/sluice-set-v2.png")
const FRAME := Rect2(80, 25, 710, 411)
const PANEL := Rect2(855, 151, 590, 248)
const SIDE_PANEL := Rect2(370, 462, 195, 510)
const WHEEL := Rect2(887, 506, 483, 455)
var doors: Dictionary = {}
var wheels: Dictionary = {}
func _crop(region: Rect2) -> AtlasTexture:
	var crop := AtlasTexture.new()
	crop.atlas = SHEET
	crop.region = region
	return crop
func _ready() -> void:
	for id: String in Map.DOORS:
		var anchor := Node2D.new()
		anchor.position = Map.door_position(id)
		anchor.z_index = roundi(anchor.position.y) + 1
		add_child(anchor)
		var horizontal: bool = Map.DOORS[id].horizontal
		var width: float = Map.DOORS[id].width * Map.SIZE.x / Map.ART_SIZE.x
		if horizontal:
			var frame := NinePatchRect.new()
			var size_scale := 55.0 / FRAME.size.y
			frame.texture = _crop(FRAME)
			frame.patch_margin_left = 186
			frame.patch_margin_right = 186
			frame.patch_margin_top = 120
			frame.patch_margin_bottom = 55
			frame.size = Vector2(width / size_scale + 372, FRAME.size.y)
			frame.scale = Vector2.ONE * size_scale
			frame.position = Vector2(-frame.size.x * size_scale / 2, -55)
			frame.light_mask = 2
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.z_index = 1
			anchor.add_child(frame)
		var panel := Sprite2D.new()
		panel.centered = false
		panel.light_mask = 2
		panel.texture = _crop(PANEL if horizontal else SIDE_PANEL)
		anchor.add_child(panel)
		anchor.hide()
		doors[id] = {"anchor": anchor, "panel": panel, "width": width}
	for id: String in Map.VAULT_CONTROLS:
		var wheel := Sprite2D.new()
		wheel.texture = _crop(WHEEL)
		wheel.centered = false
		wheel.scale = Vector2.ONE * (34.0 / WHEEL.size.y)
		wheel.position = Map.vault_control_position(id) - Vector2(WHEEL.size.x * wheel.scale.x / 2, 42)
		wheel.z_index = roundi(Map.vault_control_position(id).y) - 8
		wheel.light_mask = 2
		add_child(wheel)
		wheel.hide()
		wheels[id] = wheel
func update_view(game, point: Vector2, has_light: bool) -> void:
	var blocked := Map.closed_door_ids(game.doors)
	for id: String in doors:
		var part: Dictionary = doors[id]
		var sight_blocks := blocked.duplicate()
		sight_blocks.erase(id)
		part.anchor.visible = game.doors.has(id) and Map.can_see(point, Map.door_position(id), has_light, sight_blocks)
		if not part.anchor.visible: continue
		var progress: float = clampf(game.doors[id].progress, 0.0, 1.0)
		var panel: Sprite2D = part.panel
		panel.visible = progress < 0.995
		if not panel.visible: continue
		var horizontal: bool = Map.DOORS[id].horizontal
		var source: Rect2 = PANEL if horizontal else SIDE_PANEL
		var height: float = 42.0 if horizontal else part.width + 10.0
		var width: float = part.width + 4.0 if horizontal else 25.0
		var region := Rect2(source.position + Vector2(0, source.size.y * progress), Vector2(source.size.x, source.size.y * (1.0 - progress)))
		panel.texture.region = region
		panel.scale = Vector2(width / source.size.x, height / source.size.y)
		panel.position = Vector2(-width / 2, -height if horizontal else -height / 2)
	for id: String in wheels:
		var wheel: Sprite2D = wheels[id]
		wheel.visible = game.vault.has(id) and Map.can_see(point, Map.vault_control_position(id), has_light, blocked)
		wheel.modulate = Color(1.0, 0.91, 0.72) if game.vault.get(id, {}).get("held", false) else Color.WHITE
