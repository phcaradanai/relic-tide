extends Node2D
## Raster water uses normal canvas lighting, so unseen floor stays black.
const Maps = preload("res://scripts/expedition_map.gd")
var Map = Maps.new()
var depths: Dictionary = {}
var texture: Texture2D
var view_center := Vector2.ZERO
var view_radius := 1250.0
var dark_radius := 180.0
var regions: Dictionary = {}
class FloodRegion extends Node2D:
	var rects: Array[Rect2] = []
	var texture: Texture2D
	var depth := 0.0
	func _draw() -> void:
		if depth < 0.01: return
		var alpha := clampf(0.16 + depth / 2.2 * 0.46, 0.0, 0.62)
		for rect in rects:
			var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
			var uvs := PackedVector2Array()
			for point in points: uvs.append(point / 230.0)
			draw_polygon(points, PackedColorArray([Color(0.60, 0.90, 1.0, alpha)]), uvs, texture)
func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture = load("res://assets/flood-water.png")
	var local_material := ShaderMaterial.new()
	local_material.shader = load("res://shaders/local_water.gdshader")
	material = local_material
	if Map.id != "prototype":
		for region: String in Map.REGIONS:
			var surface := FloodRegion.new()
			surface.rects.assign(Map.floors(region))
			surface.texture = texture
			surface.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			var fog := ShaderMaterial.new()
			fog.shader = load("res://shaders/expedition_floor.gdshader")
			surface.material = fog
			add_child(surface)
			regions[region] = surface
func update_view(point: Vector2, radius: float, has_light: bool = false) -> void:
	view_center = point
	view_radius = radius
	material.set_shader_parameter("view_center", point)
	material.set_shader_parameter("view_radius", radius)
	for region: String in regions:
		regions[region].material.set_shader_parameter("view_center", point)
		regions[region].material.set_shader_parameter("view_radius", radius)
		regions[region].material.set_shader_parameter("region_radius", 1250.0 if Map.room_power.get(region, true) else 360.0 if has_light else 180.0)
func set_depths(value: Dictionary) -> void:
	depths = value.duplicate()
	for region: String in regions:
		regions[region].depth = depths.get(region, 0.0)
		regions[region].queue_redraw()
	queue_redraw()
func _draw() -> void:
	if Map.id != "prototype": return
	if texture == null: return
	for region in depths:
		var depth: float = depths[region]
		if depth < 0.01: continue
		var alpha := clampf(0.12 + depth / Map.MAX_WATER_DEPTH * 0.33, 0.0, 0.45)
		for floor_rect: Rect2 in Map.floors(region):
			if not floor_rect.intersects(Rect2(view_center - Vector2.ONE * view_radius, Vector2.ONE * view_radius * 2)): continue
			var points := PackedVector2Array([floor_rect.position, Vector2(floor_rect.end.x, floor_rect.position.y), floor_rect.end, Vector2(floor_rect.position.x, floor_rect.end.y)])
			var uvs := PackedVector2Array()
			for point in points: uvs.append(point / 230.0)
			draw_polygon(points, PackedColorArray([Color(0.72, 0.91, 1.0, alpha)]), uvs, texture)
