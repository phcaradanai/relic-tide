extends Node2D
## Native lighting/shadows. The radial texture is an invisible light mask,
## and occluder polygons are invisible geometry, never replacement scenery.
const Map = preload("res://scripts/level_map.gd")
var light: PointLight2D
var door_occluders: Array[LightOccluder2D] = []
var last_closed_doors: Array[String] = []
func _ready() -> void:
	var darkness := CanvasModulate.new()
	darkness.color = Color.BLACK
	add_child(darkness)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.78, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	var mask := GradientTexture2D.new()
	mask.width = 256
	mask.height = 256
	mask.gradient = gradient
	mask.fill = GradientTexture2D.FILL_RADIAL
	mask.fill_from = Vector2(0.5, 0.5)
	mask.fill_to = Vector2(1.0, 0.5)
	light = PointLight2D.new()
	light.texture = mask
	light.shadow_enabled = true
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	light.shadow_color = Color.BLACK
	add_child(light)
	for segment: PackedVector2Array in Map.wall_segments():
		var polygon := OccluderPolygon2D.new()
		polygon.polygon = segment
		polygon.closed = false
		polygon.cull_mode = OccluderPolygon2D.CULL_DISABLED
		var occluder := LightOccluder2D.new()
		occluder.occluder = polygon
		add_child(occluder)
func set_closed_doors(closed_doors: Array) -> void:
	var next: Array[String] = []
	for door_id: String in closed_doors:
		if Map.DOORS.has(door_id): next.append(door_id)
	next.sort()
	if next == last_closed_doors: return
	last_closed_doors = next
	for occluder in door_occluders:
		remove_child(occluder)
		occluder.queue_free()
	door_occluders.clear()
	for door_id in next:
		var polygon := OccluderPolygon2D.new()
		polygon.polygon = Map.door_segment(door_id)
		polygon.closed = false
		polygon.cull_mode = OccluderPolygon2D.CULL_DISABLED
		var occluder := LightOccluder2D.new()
		occluder.occluder = polygon
		add_child(occluder)
		door_occluders.append(occluder)
func update_view(point: Vector2, radius: float) -> void:
	light.position = point
	light.texture_scale = radius / 128.0
