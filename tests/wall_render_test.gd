extends SceneTree
## Real renderer proof: painted wall faces stay readable without revealing floors.
const Map = preload("res://scripts/level_map.gd")
const Vision = preload("res://scripts/vision_layer.gd")
var stage: Node2D
var vision: Node2D
var camera: Camera2D
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _init() -> void:
	call_deferred("run")
func capture(name: String) -> Image:
	camera.force_update_scroll()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://test-output/%s.png" % name)
	return image
func sample(image: Image, art_point: Vector2) -> Color:
	var pixel: Vector2 = stage.get_global_transform_with_canvas() * Map.from_art(art_point)
	return image.get_pixel(int(pixel.x), int(pixel.y))
func run() -> void:
	root.size = Vector2i(1440, 900)
	stage = Node2D.new()
	root.add_child(stage)
	var art := Sprite2D.new()
	art.texture = load("res://assets/ruin-movement.png")
	art.position = Map.SIZE * 0.5
	art.scale = Map.SIZE / art.texture.get_size()
	art.z_index = -2
	stage.add_child(art)
	vision = Vision.new()
	stage.add_child(vision)
	camera = Camera2D.new()
	camera.position = Map.from_art(Vector2(255, 742))
	camera.zoom = Vector2(1.65, 1.65)
	stage.add_child(camera)
	vision.update_view(camera.position, Map.DARK_VISION)
	vision.wall_faces.hide()
	var before := await capture("wall-material-before")
	vision.wall_faces.show()
	var after := await capture("wall-material-after")
	var wall_point := Vector2(205, 665)
	check(sample(after, wall_point).get_luminance() > sample(before, wall_point).get_luminance() + 0.015, "Painted north wall is visible instead of a black cutout")
	check(sample(before, Vector2(190, 740)).is_equal_approx(sample(after, Vector2(190, 740))), "Wall pass does not change visible floor lighting")
	camera.position = Map.from_art(Vector2(850, 460))
	vision.update_view(camera.position, Map.LANTERN_VISION)
	var shadow := await capture("wall-material-privacy")
	check(sample(shadow, Vector2(850, 266)).get_luminance() < 0.01, "Nearby Workshop floor remains hidden behind the wall")
	camera.position = Map.from_art(Vector2(850, 266))
	vision.update_view(camera.position, Map.LANTERN_VISION)
	var room_a := await capture("workshop-fixed-a")
	var room_b := await capture("workshop-fixed-b")
	check(room_a.get_data() == room_b.get_data(), "Workshop painting remains fixed between frames")
	check(not vision.get_children().any(func(child): return child is AnimatedSprite2D), "No animated video surface remains in the playable room")
	print("Wall render proof: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
