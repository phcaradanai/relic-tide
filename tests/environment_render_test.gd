extends SceneTree
## Native renderer acceptance for production maps. Placements are QA only.
const Maps = preload("res://scripts/expedition_map.gd")
const View = preload("res://scripts/player_view.gd")
const Directory = preload("res://scripts/room_directory.gd")
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
	scene._process(0.0)
	scene._update_vision()
	scene.camera.force_update_scroll()
	scene.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://test-output/%s.png" % name)
	image.save_png("res://.impeccable/review/%s.png" % name)
	return image
func pixel(scene, image: Image, point: Vector2) -> Color:
	var p: Vector2 = scene.get_global_transform_with_canvas() * point
	return image.get_pixel(clampi(roundi(p.x), 0, image.get_width() - 1), clampi(roundi(p.y), 0, image.get_height() - 1))
func place(scene, point: Vector2, lantern: bool = false) -> void:
	var own: Dictionary = scene.fixture.explorers[0]
	own.position = point
	own.region = scene.Map.region_at(point)
	own.has_light = lantern
	if lantern:
		scene.fixture.lantern.holder = 0
		scene.fixture.lantern.position = point
	else: scene.fixture.lantern.holder = -1
	scene.fixture.tick += 1
	scene._on_state(View.project(scene.fixture, 0))
	scene.prediction.position = point
	scene.token_positions[0] = point
	scene.movement_view.reset(point)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.impeccable/review")
	root.size = Vector2i(1440, 900)
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.auto_connect = false
	root.add_child(scene)
	scene.set_process(false)
	var start := await capture(scene, "expansion-start-desktop")
	check(scene.start_screen.visible and not scene.opening.visible, "Start is the first playable entry")
	check(scene.world != null and scene.world.waiting and not scene.art.visible, "Start scenery is the actual Landing floor")
	check(not "background" in scene, "No decorative city/video background remains")
	check(not start.is_empty(), "Start screen captured in actual renderer")
	root.size = Vector2i(960, 600)
	await capture(scene, "expansion-start-small")
	root.size = Vector2i(1440, 900)
	var directory := Directory.new()
	var info: Dictionary = {}
	directory.packet.connect(func(peer, kind, data):
		if peer == 101 and kind == "lobby": info.assign(data))
	directory.create_room(101, 3, "lagoon")
	directory.join_room(202, directory.members[101])
	directory.set_ready(101, true)
	directory.set_ready(202, true)
	scene._on_lobby(info)
	await capture(scene, "expansion-waiting-desktop")
	check(scene.phase == "waiting" and scene.waiting_panel.visible and not scene.start_button.disabled, "Walkable waiting room has a real readiness gate")
	check(scene.map_buttons.size() == 3 and not scene.hud.visible, "Waiting room exposes three map choices without survival HUD")
	root.size = Vector2i(960, 600)
	await capture(scene, "expansion-waiting-small")
	root.size = Vector2i(1440, 900)
	for map_id in Maps.PRODUCTION_IDS:
		scene._restart()
		scene._start(3, map_id)
		var center: Vector2 = scene.Map.region_center("R0")
		place(scene, center)
		var floor_sample := center + Vector2(215, 35)
		var lit := await capture(scene, "expansion-%s-desktop" % map_id)
		check(scene.camera.zoom == Vector2.ONE * 2.6, "Production camera matches supplied actor screen proportion: " + map_id)
		check(scene.world.floor_nodes.size() == scene.Map.REGIONS.size() and scene.Map.SIZE == Vector2(3840, 2560), "All floor regions share large-map geometry: " + map_id)
		check(scene.hud.visible and not scene.title_label.visible and not scene.controls_label.visible, "Icon HUD replaces prototype diagnostic text: " + map_id)
		check(scene.vision.wall_light.range_z_max >= scene.Map.SIZE.y and scene.vision.light.range_z_max >= scene.Map.SIZE.y, "Lighting covers feet ordering throughout the entire level: " + map_id)
		check(pixel(scene, lit, floor_sample).get_luminance() > 0.025, "Powered floor is visible across the room: " + map_id)
		for offset in range(-140, 141, 20):
			check(pixel(scene, lit, center + Vector2(220, offset)).get_luminance() > 0.02, "Opaque floor crop has no black gutters: " + map_id)
		scene.fixture.Map.room_power.R0 = false
		place(scene, center)
		var dark := await capture(scene, "expansion-%s-blackout" % map_id)
		check(pixel(scene, dark, floor_sample).get_luminance() < 0.01, "Blackout narrows actual floor visibility: " + map_id)
		place(scene, center, true)
		var lantern := await capture(scene, "expansion-%s-lantern" % map_id)
		check(pixel(scene, lantern, floor_sample).get_luminance() > 0.025, "Held lantern restores distant dark floor: " + map_id)
		scene.fixture.Map.room_power.R0 = true
		var gate: Vector2 = scene.Map.door_position("D0")
		var along: Vector2 = center.direction_to(scene.Map.region_center("C0"))
		var across := gate + along * 65
		scene.fixture.doors.D0.progress = 0.0
		scene.fixture.doors.D0.target_open = false
		place(scene, gate - along * 70)
		var closed := await capture(scene, "expansion-%s-gate-closed" % map_id)
		check(pixel(scene, closed, across).get_luminance() < 0.01, "Closed gate blocks native floor light: " + map_id)
		scene.fixture.doors.D0.progress = 1.0
		scene.fixture.doors.D0.target_open = true
		place(scene, gate - along * 70)
		var opened := await capture(scene, "expansion-%s-gate-open" % map_id)
		check(pixel(scene, opened, across).get_luminance() > 0.025, "Opening gate restores connected floor: " + map_id)
		place(scene, scene.Map.region_center("R1"))
		var dry := await capture(scene, "expansion-%s-archive-dry" % map_id)
		var sample: Vector2 = scene.prediction.position + Vector2(30, 45)
		scene.fixture.water_depths.R1 = 1.4
		scene.fixture.explorers[0].breath = 12.0
		scene.fixture.explorers[0].gear.oxygen = true
		scene.fixture.explorers[0].tank = 35.0
		scene.fixture.expedition.warn_breach(scene.fixture, "R1")
		place(scene, scene.Map.region_center("R1"))
		var wet := await capture(scene, "expansion-%s-water" % map_id)
		check(absf(pixel(scene, dry, sample).b - pixel(scene, wet, sample).b) > 0.01 and scene.hud.air.visible, "Regional water changes floor surface and activates air gauge: " + map_id)
		place(scene, scene.Map.region_center("R4"))
		scene.fixture.doors.D5.progress = 0.0
		scene.fixture.doors.D5.target_open = false
		place(scene, scene.Map.region_center("R4"))
		await capture(scene, "expansion-%s-refuge" % map_id)
		check(scene.game.doors.D5.sealed_safe and scene.game.water_depths.R4 == 0.0, "Sealed refuge stays dry: " + map_id)
	var chest: Vector2 = scene.Map.chest_anchors.T2.position
	place(scene, chest + Vector2(0, 20))
	scene._send_interaction("chest", "T2")
	await capture(scene, "expansion-puzzle-desktop")
	check(scene.puzzle_panel.visible and scene.puzzle_panel.challenge.kind == "pressure", "Rule-backed pressure puzzle is displayed")
	var nonce: int = scene.puzzle_panel.challenge.nonce
	scene._use_nearest()
	check(scene.puzzle_panel.challenge.nonce == nonce, "Repeated E cannot restart an open puzzle")
	root.size = Vector2i(960, 600)
	await capture(scene, "expansion-puzzle-small")
	root.size = Vector2i(1440, 900)
	scene._send_interaction("cancel_puzzle")
	scene.fixture.explorers[0].gear.map = true
	place(scene, scene.Map.region_center("R1"))
	scene._toggle_map()
	await capture(scene, "expansion-blueprint-desktop")
	check(scene.blueprint.visible and scene.blueprint.Map.id == scene.Map.id, "Collected map opens the selected static layout")
	scene._toggle_map()
	check(scene.monster_frames != null, "Complete original PixelLab monster is bundled")
	if scene.monster_frames != null:
		check(scene.monster_frames.get_animation_names().size() == 32, "Monster has four actions in eight directions")
		var own: Vector2 = scene.prediction.position
		scene.fixture.expedition.monsters.append({"id": 77, "position": own + Vector2(90, 0), "velocity": Vector2(40, -40), "stun_until": -1, "attack_until": -1})
		place(scene, own)
		await capture(scene, "expansion-hunter-desktop")
		check(scene.monster_sprites[77].sprite.animation == "walk_north_east", "Diagonal hunter plays its authored facing")
	scene.fixture.tick = ceili((scene.fixture.expedition.duration - scene.fixture.expedition.escape_grace + 1.0) / scene.fixture.STEP)
	scene.fixture.expedition.before_water(scene.fixture)
	place(scene, scene.Map.region_center("R0"))
	await capture(scene, "expansion-finale-desktop")
	check(scene.hud.final_panel.visible and scene.game.final_alarm, "Final escape announcement precedes game over")
	check(scene.hud.tide.get_theme_stylebox("fill").bg_color == Color("ef786f"), "Deadline gauge turns red during escape grace")
	root.size = Vector2i(960, 600)
	await capture(scene, "expansion-finale-small")
	scene.reduced_motion = true
	scene.hud.advance(5.1, true)
	check(not scene.hud.final_panel.visible, "Announcement clears while escape play remains active")
	print("Environment render: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
