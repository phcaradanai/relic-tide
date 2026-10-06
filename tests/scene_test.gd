extends SceneTree
const Rules = preload("res://scripts/game.gd")
const View = preload("res://scripts/player_view.gd")
const Map = preload("res://scripts/level_map.gd")
const Prediction = preload("res://scripts/movement_client.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.auto_connect = false
	root.add_child(scene)
	scene.set_process(false)
	check(scene.intro and scene.opening.visible, "Native online lobby opens")
	check(scene.room_list is ItemList and scene.code_field is LineEdit, "Directory controls retained")
	check(scene.walk_frames.size() == 24, "All isolated raster walk poses loaded")
	check(scene.art.texture.resource_path == "res://assets/ruin-movement.png", "New raster floor is actual runtime background")
	check(not scene.has_method("_commit") and not scene.has_method("_select"), "No turn-lock or action planner remains")
	scene._start(4)
	check(not scene.intro and not scene.opening.visible and scene.phase == "running", "Movement scene starts immediately")
	var start: Vector2 = scene.prediction.position
	for i in range(4): scene._step_movement(Vector2.RIGHT)
	check(scene.prediction.position.x > start.x + 30, "Local movement responds without plans")
	check(scene.fixture.explorers[1].position == Map.spawn(1), "Other human can stand still")
	scene._toggle_help()
	check(scene.show_help and scene._direction() == Vector2.ZERO, "Help pauses local intention")
	check(scene.fixture.inputs[0].direction == Vector2.ZERO, "Help sends a stop")
	scene._toggle_help()
	scene.reduced_motion = true
	scene._step_movement(Vector2.LEFT)
	check(scene.fixture.explorers[0].velocity.x < 0, "Reduced motion retains gameplay movement")
	var snapshot := View.project(scene.fixture, 0)
	snapshot.tick += 10
	snapshot.explorers[1] = {"name": "P2", "state": "hidden"}
	scene._on_state(snapshot)
	check(not scene.token_positions.has(1) and not scene.remote_to.has(1), "Hidden rival has no cached render position")
	scene._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not scene.focused and scene.fixture.inputs[0].direction == Vector2.ZERO, "Focus loss sends neutral input")
	scene._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	check(scene.focused, "Focus restored")
	scene._restart()
	check(scene.intro and scene.game == null and scene.session.mode == "idle", "Leaving clears match and transport")
	check(scene.code_field.editable and scene.room_list.visible and not scene.host_button.disabled, "Lobby reusable after leaving")
	check(scene.art.position == Vector2.ZERO and scene.art.scale == Vector2.ONE, "Artwork has no mouse parallax")
	check(scene.camera.position == Map.spawn(0) and not scene.camera.position_smoothing_enabled, "Camera follows player without decorative drift")
	scene._start(2)
	scene._use_light("take_light")
	check(scene.game.explorers[0].has_light and scene.game.lantern.is_empty(), "Physical pickup reaches local scene through authority")
	scene._use_light("drop_light")
	check(not scene.game.explorers[0].has_light and scene.game.lantern.has("position"), "Dropped light reappears in visible ground state")
	scene.vision.set_closed_doors(["D5"])
	check(scene.vision.door_occluders.size() == 1, "Closed gate installs one light shadow")
	scene.vision.set_closed_doors([])
	check(scene.vision.door_occluders.is_empty(), "Opening gate removes its light shadow")
	var wall_count: int = scene.vision.get_child_count()
	for i in range(4):
		scene.vision.set_closed_doors(["D5"])
		scene.vision.set_closed_doors([])
	check(scene.vision.get_child_count() == wall_count, "Door shadow lifecycle cannot accumulate stale occluders")
	scene.fixture.explorers[0].position = Map.valve_position()
	scene.fixture.explorers[0].region = "R2"
	scene.fixture.tick += 1
	scene._on_state(View.project(scene.fixture, 0))
	scene._use_nearest()
	check(scene.valve_hold_active and scene.fixture.valve_holds.has(0), "Nearby use begins authoritative valve hold")
	scene._cancel_interaction_hold()
	check(not scene.valve_hold_active and scene.fixture.valve_holds.is_empty(), "Key release clears client and server hold")
	# Reconcile delayed snapshots, then prove bounded prediction during a stall.
	var rules := Rules.new()
	var predictor := Prediction.new()
	predictor.reset(View.project(rules, 0))
	var delayed: Array[Dictionary] = []
	for i in range(20):
		var command := predictor.advance(Vector2.RIGHT)
		rules.set_input(0, command.direction, command.sequence)
		rules.step()
		delayed.append(View.project(rules, 0))
		if delayed.size() > 4: predictor.reconcile(delayed.pop_front())
		check(predictor.position.distance_to(rules.explorers[0].position) < 0.01, "200ms delayed acknowledgements reconcile correctly")
	predictor.reconcile(View.project(rules, 0))
	check(predictor.pending.is_empty(), "Acknowledged inputs released")
	var stale := View.project(rules, 0)
	stale.tick -= 1
	stale.explorers[0].position = Vector2.ZERO
	check(not predictor.reconcile(stale), "Old snapshots ignored")
	for i in range(100): predictor.advance(Vector2.UP)
	check(predictor.pending.size() <= Prediction.MAX_PENDING, "Connection stall cannot grow unbounded prediction")
	check(Map.walkable(predictor.position), "Prediction shares authoritative walls")
	scene.queue_free()
	await process_frame
	print("Scene: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
