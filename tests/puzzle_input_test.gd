extends SceneTree
## Native GUI probe: opening/solving uses input events, never emitted signals.
## Run without --headless to exercise rendered controls and canvas stretching.
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

func settle(scene) -> void:
	scene._process(0.0)
	scene.camera.force_update_scroll()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func key_e() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_E
		event.keycode = KEY_E
		event.pressed = pressed
		root.push_input(event)
		await process_frame

func mouse_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	# Physical window coordinates are converted by Viewport.push_input.
	root.push_input(event, false)
	await process_frame

func click(button: Button) -> Vector2:
	var local_center := button.size * 0.5
	var point: Vector2 = root.get_final_transform() * button.get_global_transform_with_canvas() * local_center
	check(button.is_visible_in_tree() and not button.disabled, "Clicked circuit switch is visible and enabled")
	check(Rect2(Vector2.ZERO, Vector2(root.size)).has_point(point), "Rendered circuit switch lies inside the native window")
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, false)
	await process_frame
	check(root.gui_get_hovered_control() == button, "Native GUI hit testing selects the intended circuit switch")
	await mouse_button(point, true)
	await mouse_button(point, false)
	return point

func advance_ticks(scene, count: int = 4) -> void:
	for i in range(count): scene.fixture.step()
	scene._on_state(View.project(scene.fixture, 0))
	await settle(scene)

func open_circuit(scene, window_size: Vector2i) -> Dictionary:
	root.size = window_size
	scene._restart()
	scene._start(2, "foundry")
	# QA placement and target variation stay inside the offline authority fixture.
	var point: Vector2 = scene.Map.chest_anchors.T1.position + Vector2(0, 20)
	var own: Dictionary = scene.fixture.explorers[0]
	own.position = point
	own.region = scene.Map.region_at(point)
	scene._on_state(View.project(scene.fixture, 0))
	scene.prediction.position = point
	scene.movement_view.reset(point)
	scene.token_positions[0] = point
	await settle(scene)
	check(scene._nearby_interaction().get("target", "") == "T1", "QA placement reaches authored circuit chest T1")
	await key_e()
	await settle(scene)
	check(scene.puzzle_panel.visible and scene.fixture.expedition.puzzles.has(0), "Native E opens the production private circuit puzzle")
	if not scene.fixture.expedition.puzzles.has(0): return {}
	var challenge: Dictionary = scene.fixture.expedition.puzzles[0]
	check(challenge.kind == "circuit", "Authored T1 puzzle is a circuit")
	return challenge

func test_circuit(scene, window_size: Vector2i, target_bits: int) -> void:
	var challenge: Dictionary = await open_circuit(scene, window_size)
	if challenge.is_empty(): return
	var own: Dictionary = scene.fixture.explorers[0]
	challenge.target_bits = target_bits
	scene._on_state(View.project(scene.fixture, 0))
	await settle(scene)
	var chest: Dictionary = scene.fixture.expedition.chests.T1
	var expected_treasure: int = chest.treasure
	check(chest.loot == "chart", "Circuit probe preserves T1's authored chart reward")
	var last_point := Vector2.ZERO
	var bits := 0
	for index in range(3):
		if target_bits & (1 << index) == 0: continue
		await advance_ticks(scene)
		last_point = await click(scene.puzzle_panel.buttons[index])
		bits |= 1 << index
		print("CIRCUIT ", window_size, " target=", target_bits, " switch=", index, " window_point=", last_point, " tick=", scene.fixture.tick, " bits=", challenge.bits, " treasure=", own.treasure)
		check(challenge.bits == bits, "Mouse release toggles exactly the intended switch")
		if bits != target_bits:
			check(scene.puzzle_panel.visible and not chest.opened, "Incomplete circuit remains open without granting treasure")
			# A second actual click at the same authority tick must be rejected.
			await click(scene.puzzle_panel.buttons[index])
			check(challenge.bits == bits and own.treasure == 0, "Native click burst obeys the four-tick authority rate limit")
	check(chest.opened and not scene.fixture.expedition.puzzles.has(0) and not scene.puzzle_panel.visible, "Solved circuit closes only after authority opens the chest")
	check(own.gear.chart and not own.gear.oxygen and own.tank == 0.0, "Chart reward changes the intended gear and preserves the oxygen tank")
	check(own.treasure == expected_treasure and own.loot_serial == 1 and chest.claimed == [0], "Circuit grants its authored treasure and provision exactly once")
	check(scene.game.explorers[0].treasure == expected_treasure, "Recipient view displays the authoritative circuit treasure")
	await mouse_button(last_point, true)
	await mouse_button(last_point, false)
	await key_e()
	check(own.treasure == expected_treasure and own.loot_serial == 1 and chest.claimed == [0], "Repeated native clicks/E cannot duplicate the solved chest reward")
	check(scene.phase == "running" and not scene.start_screen.visible, "Circuit clicks never return the expedition to Start")

func test_idle_expiry(scene) -> void:
	var challenge: Dictionary = await open_circuit(scene, Vector2i(1440, 900))
	if challenge.is_empty(): return
	var own: Dictionary = scene.fixture.explorers[0]
	var chest: Dictionary = scene.fixture.expedition.chests.T1
	var button: Button = scene.puzzle_panel.buttons[2]
	var point: Vector2 = root.get_final_transform() * button.get_global_transform_with_canvas() * (button.size * 0.5)
	await advance_ticks(scene, 500)
	check(scene.puzzle_panel.visible and scene.fixture.expedition.puzzles.has(0), "An idle circuit remains live at exactly 25 seconds")
	await advance_ticks(scene, 1)
	check(scene.puzzle_panel.visible, "Tick-start cleanup permits exactly 500 inactive ticks")
	await advance_ticks(scene, 1)
	check(not scene.puzzle_panel.visible and not scene.fixture.expedition.puzzles.has(0), "Tick-start cleanup expires the circuit beyond 500 inactive ticks")
	check(not chest.opened and own.treasure == 0 and own.loot_serial == 0 and chest.claimed.is_empty(), "Idle expiry closes the puzzle without awarding the chest")
	await mouse_button(point, true)
	await mouse_button(point, false)
	check(not chest.opened and own.treasure == 0 and own.loot_serial == 0, "A late native click cannot solve the expired challenge")
	check(scene.phase == "running" and not scene.start_screen.visible, "Idle expiry and late clicks keep the expedition running")
	print("CIRCUIT idle_expiry tick=", scene.fixture.tick, " visible=", scene.puzzle_panel.visible, " treasure=", own.treasure, " phase=", scene.phase)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("puzzle_input_test requires the native graphics renderer")
		quit(1)
		return
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.auto_connect = false
	root.add_child(scene)
	scene.set_process(false)
	for window_size in [Vector2i(1440, 900), Vector2i(960, 600)]:
		for target_bits in [4, 7]: await test_circuit(scene, window_size, target_bits)
	await test_idle_expiry(scene)
	print("Puzzle input: ", checks, " checks, ", failures, " failures")
	scene.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
