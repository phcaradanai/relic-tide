extends Node2D
## The entire environment is playable raster floor/wall/prop artwork.
const KIT = preload("res://assets/generated/environment/expedition-kit-v1.png")
const PROP_SHEET = preload("res://assets/generated/environment/expedition-props-v1.png")
const FURNITURE_SHEET = preload("res://assets/generated/environment/expedition-furniture-v1.png")
const DETAIL_SHEET = preload("res://assets/generated/environment/expedition-floor-details-v1.png")
const DETAIL_RECTS := {
	"rug": Rect2(13, 169, 387, 275), "grate": Rect2(412, 190, 365, 254),
	"stone_chips": Rect2(802, 155, 355, 300), "mineral": Rect2(1170, 153, 360, 345),
	"papers": Rect2(5, 580, 390, 325), "tools": Rect2(402, 580, 410, 317),
	"pottery": Rect2(813, 626, 316, 255), "netting": Rect2(1146, 566, 387, 376),
}
const PROP_RECTS := {"boat": Rect2(9, 120, 420, 360), "valve": Rect2(465, 105, 332, 355), "shelf": Rect2(820, 117, 403, 335), "pedestal": Rect2(1235, 202, 300, 257), "urns": Rect2(135, 615, 259, 320), "sarcophagus": Rect2(528, 530, 246, 409), "torch": Rect2(894, 575, 137, 342), "engine": Rect2(1162, 529, 353, 403)}
# Individual silhouettes have generous alpha gutters; the source is not an exact grid.
const FURNITURE_RECTS := {
	"writing_desk": Rect2(14, 92, 312, 221), "chair": Rect2(385, 73, 164, 241),
	"bookcase": Rect2(615, 51, 328, 268), "cot": Rect2(948, 141, 292, 174),
	"crates": Rect2(11, 355, 323, 245), "barrels": Rect2(352, 353, 260, 249),
	"rope": Rect2(627, 409, 309, 200), "sacks": Rect2(950, 364, 293, 243),
	"workbench": Rect2(10, 637, 326, 284), "anvil": Rect2(372, 701, 216, 219),
	"pump": Rect2(661, 624, 230, 300), "chart_table": Rect2(921, 684, 323, 239),
	"planter": Rect2(30, 932, 284, 288), "armillary": Rect2(368, 928, 216, 295),
	"altar": Rect2(638, 950, 257, 269), "ossuary": Rect2(935, 984, 304, 229),
}
const FLOOR_RECTS := [Rect2(67, 86, 400, 395), Rect2(567, 86, 404, 395), Rect2(1067, 86, 400, 395)]
const WALL_NORTH := Rect2(30, 690, 465, 157)
const WALL_SOUTH := Rect2(552, 690, 501, 153)
const CHEST := Rect2(1137, 649, 298, 263)
var Map
var floor_nodes: Dictionary = {}
var props: Array[Dictionary] = []
var wall_materials: Array[ShaderMaterial] = []
var chest_texture: Texture2D
var chest_sprites: Dictionary = {}
var ground_relic: Sprite2D
var ground_lantern: Sprite2D
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
		fog.set_shader_parameter("foreground_cutaway", horizontal and not floor_below)
		wall.material = fog
		wall_materials.append(fog)
		add_child(wall)
	var textures: Dictionary = {}
	for spec: Dictionary in Map.prop_specs:
		var kind: String = spec.kind
		if not textures.has(kind):
			if spec.floor_detail: textures[kind] = crop(DETAIL_RECTS[kind], DETAIL_SHEET)
			else: textures[kind] = crop(PROP_RECTS[kind], PROP_SHEET) if PROP_RECTS.has(kind) else crop(FURNITURE_RECTS[kind], FURNITURE_SHEET)
		add_prop(textures[kind], spec.position, spec.height, spec.region, spec.floor_detail)
		props[-1].kind = kind
		props[-1].floor_detail = spec.floor_detail

func add_prop(texture: Texture2D, location: Vector2, height: float, region: String, floor_detail: bool = false) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2.ONE * (height / texture.get_height())
	sprite.position = location if floor_detail else location - Vector2(0, height * 0.43)
	sprite.z_index = -2 if floor_detail else roundi(location.y)
	sprite.light_mask = 1 if floor_detail else 2
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

func update_objects(view, relic_texture: Texture2D, lantern_texture: Texture2D) -> void:
	# Build only objects supplied by the recipient view, never hidden map anchors.
	for sprite: Sprite2D in chest_sprites.values(): sprite.hide()
	for chest_id: String in view.chests:
		var chest: Dictionary = view.chests[chest_id]
		if not chest_sprites.has(chest_id):
			var sprite := Sprite2D.new()
			sprite.texture = chest_texture
			sprite.centered = false
			sprite.scale = Vector2(43.0, 38.0) / chest_texture.get_size()
			sprite.light_mask = 2
			add_child(sprite)
			chest_sprites[chest_id] = sprite
		var sprite: Sprite2D = chest_sprites[chest_id]
		sprite.position = chest.position - Vector2(21.5, 30)
		sprite.z_index = roundi(chest.position.y)
		sprite.modulate = Color(0.7, 0.8, 0.76) if chest.claimed else Color.WHITE
		sprite.show()
	if ground_relic != null: ground_relic.hide()
	if view.relic.has("position"):
		if ground_relic == null:
			ground_relic = Sprite2D.new()
			ground_relic.texture = relic_texture
			ground_relic.centered = false
			ground_relic.scale = Vector2.ONE * (44.0 / 60.0)
			ground_relic.light_mask = 2
			add_child(ground_relic)
		var dimensions := relic_texture.get_size() * ground_relic.scale
		ground_relic.position = view.relic.position - Vector2(dimensions.x / 2, dimensions.y)
		ground_relic.z_index = roundi(view.relic.position.y)
		ground_relic.show()
	if ground_lantern != null: ground_lantern.hide()
	if view.lantern.has("position"):
		if ground_lantern == null:
			ground_lantern = Sprite2D.new()
			ground_lantern.texture = lantern_texture
			ground_lantern.centered = false
			ground_lantern.scale = Vector2.ONE * (44.0 / 60.0)
			ground_lantern.light_mask = 2
			add_child(ground_lantern)
		var dimensions := lantern_texture.get_size() * ground_lantern.scale
		ground_lantern.position = view.lantern.position - Vector2(dimensions.x / 2, dimensions.y)
		ground_lantern.z_index = roundi(view.lantern.position.y)
		ground_lantern.show()
