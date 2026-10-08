extends Node2D
## Painted physical parts, with feet-based depth ordering and local visibility.
const Maps = preload("res://scripts/expedition_map.gd")
var Map = Maps.new()
const SHEET = preload("res://assets/generated/environment/sluice-set-v2.png")
const SIDE_SHEET = preload("res://assets/generated/environment/sluice-side-v3.png")
const SIDE_BULKHEAD := Rect2(324, 17, 154, 1221)
const SIDE_JAMB := Rect2(758, 462, 283, 315)
const FRAME := Rect2(80, 25, 710, 411)
const PANEL := Rect2(855, 151, 590, 248)
const SIDE_PANEL := Rect2(370, 462, 195, 510)
const WHEEL := Rect2(887, 506, 483, 455)
var doors: Dictionary = {}
var wheels: Dictionary = {}
func _crop(region: Rect2, sheet: Texture2D = SHEET) -> AtlasTexture:
	var crop := AtlasTexture.new()
	crop.atlas = sheet
	crop.region = region
	return crop
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for id: String in Map.DOORS:
		var anchor := Node2D.new()
		anchor.position = Map.door_position(id)
		anchor.z_index = roundi(anchor.position.y) + 1
		add_child(anchor)
		var horizontal: bool = Map.DOORS[id].horizontal
		var width: float = Map.DOORS[id].width * Map.SIZE.x / Map.ART_SIZE.x
		if not horizontal and Map.id != "prototype":
			_add_side_door(id, anchor, width)
			continue
		var face_material := ShaderMaterial.new()
		face_material.shader = load("res://shaders/local_scene.gdshader")
		if horizontal:
			var frame := NinePatchRect.new()
			var frame_height := 55.0 if Map.id == "prototype" else 36.0
			var size_scale := frame_height / FRAME.size.y
			frame.texture = _crop(FRAME)
			frame.patch_margin_left = 186
			frame.patch_margin_right = 186
			frame.patch_margin_top = 120
			frame.patch_margin_bottom = 55
			frame.size = Vector2(width / size_scale + 372, FRAME.size.y)
			frame.scale = Vector2.ONE * size_scale
			frame.position = Vector2(-frame.size.x * size_scale / 2, -frame_height)
			frame.light_mask = 2
			if Map.id != "prototype": frame.material = face_material
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.z_index = 1
			anchor.add_child(frame)
		var panel := Sprite2D.new()
		panel.centered = false
		panel.light_mask = 2
		panel.texture = _crop(PANEL if horizontal else SIDE_PANEL)
		if Map.id != "prototype": panel.material = face_material
		anchor.add_child(panel)
		anchor.hide()
		doors[id] = {"anchor": anchor, "panel": panel, "width": width, "material": face_material}
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

func _add_side_door(id: String, anchor: Node2D, width: float) -> void:
	# A north-south bulkhead is a low wall in plan, not an upright portrait door.
	# Sort short raster strips at their own ground edge along the entire opening.
	anchor.z_index = 0
	var height := width + 4.0
	var strips: Array[Sprite2D] = []
	for index in range(10):
		var strip := Sprite2D.new()
		strip.centered = false
		strip.texture = _crop(SIDE_BULKHEAD, SIDE_SHEET)
		strip.light_mask = 2
		strip.position = Vector2(-10.0, -height * 0.5 - 13.0 + height * index / 10.0)
		strip.scale = Vector2(20.0 / SIDE_BULKHEAD.size.x, height / SIDE_BULKHEAD.size.y)
		strip.z_as_relative = false
		strip.z_index = roundi(anchor.position.y - height * 0.5 + height * (index + 1) / 10.0)
		anchor.add_child(strip)
		strips.append(strip)
	for side in [-1, 1]:
		var jamb := Sprite2D.new()
		jamb.texture = _crop(SIDE_JAMB, SIDE_SHEET)
		jamb.scale = Vector2(28, 30) / SIDE_JAMB.size
		jamb.position = Vector2(0, side * width * 0.5 - 13.0)
		jamb.z_as_relative = false
		jamb.z_index = roundi(anchor.position.y + side * width * 0.5)
		jamb.light_mask = 2
		anchor.add_child(jamb)
	anchor.hide()
	doors[id] = {"anchor": anchor, "strips": strips, "width": width}

func _update_side_door(part: Dictionary, progress: float, point: Vector2) -> void:
	var height: float = part.width + 4.0
	var remaining := height * (1.0 - progress)
	var actor_bounds := Rect2(point - Vector2(14, 44), Vector2(28, 44))
	for index in range(part.strips.size()):
		var strip: Sprite2D = part.strips[index]
		var start: float = height * index / part.strips.size()
		var length := clampf(remaining - start, 0.0, height / part.strips.size())
		strip.visible = length > 0.01
		if not strip.visible: continue
		strip.texture.region = Rect2(SIDE_BULKHEAD.position + Vector2(0, SIDE_BULKHEAD.size.y * (progress + start / height)), Vector2(SIDE_BULKHEAD.size.x, SIDE_BULKHEAD.size.y * length / height))
		var bounds := Rect2(strip.global_position, Vector2(20, length))
		strip.modulate.a = 0.4 if strip.z_index > roundi(point.y) + 1 and bounds.intersects(actor_bounds) else 1.0

func update_view(game, point: Vector2, has_light: bool) -> void:
	var blocked := Map.closed_door_ids(game.doors)
	for id: String in doors:
		var part: Dictionary = doors[id]
		var sight_blocks := blocked.duplicate()
		sight_blocks.erase(id)
		part.anchor.visible = game.doors.has(id) and Map.can_see(point, Map.door_position(id), has_light, sight_blocks)
		if not part.anchor.visible: continue
		var progress: float = clampf(game.doors[id].progress, 0.0, 1.0)
		if part.has("strips"):
			_update_side_door(part, progress, point)
			continue
		if Map.id != "prototype":
			part.material.set_shader_parameter("view_center", point)
			part.material.set_shader_parameter("view_radius", Map.vision_radius(point, has_light, blocked))
			part.material.set_shader_parameter("foreground_cutaway", point.y < part.anchor.position.y)
		var panel: Sprite2D = part.panel
		panel.visible = progress < 0.995
		if not panel.visible: continue
		var horizontal: bool = Map.DOORS[id].horizontal
		var source: Rect2 = PANEL if horizontal else SIDE_PANEL
		var height: float = (42.0 if Map.id == "prototype" else 29.0) if horizontal else part.width + 10.0
		var width: float = part.width + 4.0 if horizontal else 25.0
		var region := Rect2(source.position + Vector2(0, source.size.y * progress), Vector2(source.size.x, source.size.y * (1.0 - progress)))
		panel.texture.region = region
		panel.scale = Vector2(width / source.size.x, height / source.size.y)
		panel.position = Vector2(-width / 2, -height if horizontal else -height / 2)
	for id: String in wheels:
		var wheel: Sprite2D = wheels[id]
		wheel.visible = game.vault.has(id) and Map.can_see(point, Map.vault_control_position(id), has_light, blocked)
		wheel.modulate = Color(1.0, 0.91, 0.72) if game.vault.get(id, {}).get("held", false) else Color.WHITE
