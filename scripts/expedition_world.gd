extends Node2D
## The entire environment is playable raster floor/wall/prop artwork.
const KIT = preload("res://assets/generated/environment/expedition-kit-v1.png")
const FLOOR_RECTS := [Rect2(67, 86, 400, 395), Rect2(567, 86, 404, 395), Rect2(1067, 86, 400, 395)]
const WALL_NORTH := Rect2(30, 690, 465, 157)
const WALL_SOUTH := Rect2(552, 690, 501, 153)
const CHEST := Rect2(1137, 649, 298, 263)
var Map
var floor_nodes: Dictionary = {}
var props: Array[Dictionary] = []
var wall_materials: Array[ShaderMaterial] = []
var chest_texture: Texture2D
var waiting := false
var point := Vector2.ZERO
var radius := 1250.0
var has_light := false

class RasterFloor extends Node2D:
	var rects: Array[Rect2] = []
	var raster: Texture2D
	func _draw() -> void:
		for rect in rects:
			var vertices := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
			var uvs := PackedVector2Array()
			for vertex in vertices: uvs.append(vertex / 132.0)
			draw_polygon(vertices, PackedColorArray([Color.WHITE]), uvs, raster)

func crop(rect: Rect2, sheet: Texture2D = KIT) -> Texture2D:
	# Crop authored raster pixels at runtime; do not synthesize floor materials.
	return ImageTexture.create_from_image(sheet.get_image().get_region(Rect2i(rect)))

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chest_texture = crop(CHEST)
	var theme_index: int = ["lagoon", "foundry", "catacombs"].find(Map.id)
	var floor_texture := crop(FLOOR_RECTS[maxi(0, theme_index)])
	for region: String in Map.REGIONS:
		var floor_node := RasterFloor.new()
		floor_node.rects.assign(Map.floors(region))
		floor_node.raster = floor_texture
		floor_node.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		floor_node.z_index = -3
		var fog := ShaderMaterial.new()
		fog.shader = load("res://shaders/expedition_floor.gdshader")
		floor_node.material = fog
		add_child(floor_node)
		floor_nodes[region] = floor_node
	var north := crop(WALL_NORTH)
	var south := crop(WALL_SOUTH)
	for segment: PackedVector2Array in Map.wall_segments():
		var first := segment[0]
		var last := segment[1]
		var horizontal := absf(first.y - last.y) < 0.1
		var midpoint := (first + last) * 0.5
		var floor_below: bool = Map.contains_floor(midpoint + Vector2(0, 2)) if horizontal else Map.contains_floor(midpoint + Vector2(2, 0))
		var wall := Sprite2D.new()
		wall.texture = north if floor_below else south
		wall.position = midpoint - Vector2(0, 13) if horizontal else midpoint + Vector2(-11 if floor_below else 11, 0)
		wall.rotation = 0.0 if horizontal else PI * 0.5
		wall.scale = Vector2(first.distance_to(last) / wall.texture.get_width(), 29.0 / wall.texture.get_height())
		wall.z_index = roundi(midpoint.y) + (8 if not floor_below else -45)
		wall.light_mask = 2
		var fog := ShaderMaterial.new()
		fog.shader = load("res://shaders/local_scene.gdshader")
		wall.material = fog
		wall_materials.append(fog)
		add_child(wall)

func add_prop(texture: Texture2D, location: Vector2, height: float, region: String, order: int = 0) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2.ONE * (height / texture.get_height())
	sprite.position = location - Vector2(0, height * 0.43)
	sprite.z_index = roundi(location.y) + order
	sprite.light_mask = 2
	add_child(sprite)
	props.append({"sprite": sprite, "position": location, "region": region})
	return sprite

func update_view(view, location: Vector2, reach: float, held_light: bool = false, is_waiting: bool = false) -> void:
	point = location
	radius = reach
	has_light = held_light
	waiting = is_waiting
	for region: String in floor_nodes:
		var node: RasterFloor = floor_nodes[region]
		node.visible = not waiting or region == "R0"
		var fog: ShaderMaterial = node.material
		fog.set_shader_parameter("view_center", point)
		fog.set_shader_parameter("view_radius", radius)
		fog.set_shader_parameter("region_radius", 1250.0 if Map.room_power.get(region, true) else 360.0 if has_light else 180.0)
	for fog in wall_materials:
		fog.set_shader_parameter("view_center", point)
		fog.set_shader_parameter("view_radius", radius)
	var closed: Array = Map.closed_door_ids(view.doors) if view != null else []
	for prop in props:
		prop.sprite.visible = (not waiting or prop.region == "R0") and Map.can_see(point, prop.position, has_light, closed)
	queue_redraw()
