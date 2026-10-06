extends SceneTree
## Renderer proof for local vision, light expansion and native wall shadows.
const Map = preload("res://scripts/level_map.gd")
const View = preload("res://scripts/player_view.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _init() -> void:
	call_deferred("run")
func capture(scene, name: String) -> Image:
	scene._update_vision()
	scene.camera.force_update_scroll()
	scene.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://test-output/%s.png" % name)
	return image
func world_pixel(scene, image: Image, point: Vector2) -> Color:
	var pixel: Vector2 = scene.get_global_transform_with_canvas() * point
	return image.get_pixel(clampi(int(pixel.x), 0, image.get_width() - 1), clampi(int(pixel.y), 0, image.get_height() - 1))
func set_position(scene, art_point: Vector2, held: bool = false) -> void:
	var position := Map.from_art(art_point)
	scene.fixture.explorers[0].position = position
	scene.fixture.explorers[0].region = Map.region_at(position)
	scene.fixture.explorers[0].has_light = held
	scene.fixture.tick += 1
	scene._on_state(View.project(scene.fixture, 0))
	scene.prediction.position = position
	scene.token_positions[0] = position
func run() -> void:
	root.size = Vector2i(1440, 900)
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.auto_connect = false
	root.add_child(scene)
	scene.set_process(false)
	scene._start(4)
	scene._process(0.0)
	var landing := await capture(scene, "realtime-landing")
	check(not landing.is_empty() and landing.get_pixel(720, 450).get_luminance() > 0.02, "Local player and floor render")
	check(landing.get_pixel(100, 450).get_luminance() < 0.01 and landing.get_pixel(1370, 600).get_luminance() < 0.01, "Map outside local light remains black")
	check(scene.art.size == Map.SIZE, "Art and collision share logical coordinates")
	check(scene.lantern_texture is AtlasTexture, "Lantern uses transparent raster crop")
	for i in range(7): scene._step_movement(Vector2.RIGHT)
	scene.token_positions[0] = scene.prediction.position
	scene.walking[0] = true
	scene.elapsed = 0.35
	var walking := await capture(scene, "realtime-walking")
	check(landing.get_data() != walking.get_data(), "Actual movement/pose/camera change rendered view")
	set_position(scene, Vector2(1030, 460))
	var dark := await capture(scene, "vision-no-lantern")
	var distant := Map.from_art(Vector2(1230, 460))
	check(world_pixel(scene, dark, distant).get_luminance() < 0.01, "Distant floor hidden without lantern")
	set_position(scene, Vector2(1030, 460), true)
	var lit := await capture(scene, "vision-with-lantern")
	check(world_pixel(scene, lit, distant).get_luminance() > 0.04, "Held lantern reveals farther floor")
	set_position(scene, Vector2(850, 460), true)
	var shadow := await capture(scene, "vision-wall-shadow")
	check(world_pixel(scene, shadow, Map.from_art(Vector2(850, 266))).get_luminance() < 0.01, "Wall hides close Workshop floor despite light range")
	set_position(scene, Vector2(790, 355))
	await capture(scene, "vision-near-torch")
	check(scene.vision.light.texture_scale * 128 > Map.LANTERN_VISION, "Nearby torch expands view beyond lantern radius")
	scene.fixture.doors.D3.progress = 0.0
	scene.fixture.doors.D3.target_open = false
	set_position(scene, Vector2(790, 280), true)
	var gate_closed := await capture(scene, "door-closed")
	var across_gate := Map.from_art(Vector2(790, 340))
	check(world_pixel(scene, gate_closed, across_gate).get_luminance() < 0.01, "Closed gate casts a real shadow across doorway")
	scene.fixture.doors.D3.progress = 1.0
	scene.fixture.doors.D3.target_open = true
	set_position(scene, Vector2(790, 280), true)
	var gate_open := await capture(scene, "door-open")
	check(world_pixel(scene, gate_open, across_gate).get_luminance() > 0.04, "Opening gate restores visible floor without stale shadow")
	set_position(scene, Vector2(1030, 460), true)
	var dry := await capture(scene, "flood-dry")
	scene.fixture.water_depths.C1 = 1.0
	scene.fixture.tide_level = 1.2
	scene.fixture.tick = int(180.0 / scene.fixture.STEP)
	set_position(scene, Vector2(1030, 460), true)
	var wet := await capture(scene, "flood-wading")
	var sample := Map.from_art(Vector2(1080, 460))
	check(absf(world_pixel(scene, dry, sample).b - world_pixel(scene, wet, sample).b) > 0.01, "Regional depth changes the actual raster floor surface")
	check(wet.get_pixel(100, 450).get_luminance() < 0.01, "Flooding does not expose the full map")
	scene.fixture.doors.D5.progress = 0.0
	scene.fixture.doors.D5.target_open = false
	scene.fixture.water_depths.C1 = Map.MAX_WATER_DEPTH
	scene.fixture.tide_level = Map.MAX_WATER_DEPTH
	scene.fixture.tick = int(360.0 / scene.fixture.STEP)
	set_position(scene, Vector2(1297, 742), true)
	var refuge := await capture(scene, "refuge-sealed")
	check(scene.game.doors.D5.sealed_safe and scene.game.water_depths.R4 == 0.0, "Refuge presents its local sealed dry state")
	check(world_pixel(scene, refuge, Map.from_art(Vector2(1260, 560))).get_luminance() < 0.01, "Refuge door conceals flooded corridor floor beyond gate art and label")
	scene._restart()
	await capture(scene, "realtime-lobby")
	check(scene.opening.visible and scene.room_list.visible, "Online lobby still renders")
	scene.queue_free()
	await process_frame
	print("Render: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
