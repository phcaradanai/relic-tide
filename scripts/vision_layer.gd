extends Node2D
## Native lighting/shadows. The radial texture is an invisible light mask,
## and occluder polygons are invisible geometry, never replacement scenery.
const Maps = preload("res://scripts/expedition_map.gd")
var Map = Maps.new()
var light: PointLight2D
var wall_light: PointLight2D
var wall_faces: Sprite2D
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
	light.shadow_filter_smooth = 3.0
	light.range_item_cull_mask = 1
	# Feet-based ordering spans the large map's complete height. Godot's
	# default +1024 light range otherwise turns southern props into silhouettes.
	light.range_z_min = -4096
	light.range_z_max = 4096
	add_child(light)
	# A separate raster surface reveals local wall material and obstacle faces.
	# Its light cannot illuminate floors behind walls, or unseen actors.
	wall_faces = Sprite2D.new()
	wall_faces.texture = load("res://assets/ruin-wall-faces-v2.png")
	wall_faces.position = Map.SIZE * 0.5
	wall_faces.scale = Map.SIZE / wall_faces.texture.get_size()
	wall_faces.light_mask = 2
	wall_faces.z_index = -1
	var wall_material := ShaderMaterial.new()
	wall_material.shader = load("res://shaders/local_scene.gdshader")
	wall_faces.material = wall_material
	add_child(wall_faces)
	wall_faces.visible = Map.id == "prototype"
	wall_light = PointLight2D.new()
	wall_light.texture = mask
	wall_light.range_item_cull_mask = 2
	wall_light.range_z_min = -4096
	wall_light.range_z_max = 4096
	wall_light.energy = 0.85
	add_child(wall_light)
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
		polygon.polygon = Map.door_shadow_polygon(door_id)
		polygon.closed = true
		polygon.cull_mode = OccluderPolygon2D.CULL_DISABLED
		var occluder := LightOccluder2D.new()
		occluder.occluder = polygon
		add_child(occluder)
		door_occluders.append(occluder)
func update_view(point: Vector2, radius: float) -> void:
	light.position = point
	light.texture_scale = radius / 128.0
	if wall_light:
		wall_light.position = point
		wall_light.texture_scale = radius / 128.0
	if wall_faces and wall_faces.visible:
		wall_faces.material.set_shader_parameter("view_center", point)
		wall_faces.material.set_shader_parameter("view_radius", radius)
