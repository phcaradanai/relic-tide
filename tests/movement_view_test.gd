extends SceneTree
const Rules = preload("res://scripts/game.gd")
const View = preload("res://scripts/player_view.gd")
const Map = preload("res://scripts/level_map.gd")
const Prediction = preload("res://scripts/movement_client.gd")
const Presentation = preload("res://scripts/movement_view.gd")
var checks := 0
var failures := 0

class InputScene:
	extends "res://scripts/main.gd"
	var held_direction := Vector2.UP
	func _direction() -> Vector2: return held_direction

class Transport:
	extends RefCounted
	var commands: Array[Dictionary] = []
	func movement(command: Dictionary) -> void: commands.append(command.duplicate())

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void: run.call_deferred()

func _trace(fps: int, mode: String) -> Dictionary:
	var client := InputScene.new()
	client.auto_connect = false
	root.add_child(client)
	client.set_process(false)
	var wire := Transport.new()
	client.session = wire
	var rules := Rules.new(1, 2)
	rules.explorers[0].position = Map.from_art(Vector2(283, 730))
	rules.explorers[0].region = "R0"
	client._on_state(View.project(rules, 0))
	var inputs: Array[Dictionary] = []
	var views: Array[Dictionary] = []
	var next_tick := Rules.STEP
	var last_input_arrival := 0.0
	var last_view_arrival := 0.0
	var backwards := 0
	var backwards_max := 0.0
	var wrong_facing := 0
	var idle_motion := 0
	var correction_max := 0.0
	var offset_max := 0.0
	var valid_feet := true
	var before: Vector2 = client.token_positions.get(0, client.prediction.position)
	for frame in range(1, fps * 2 + 1):
		var now := float(frame) / fps
		if mode == "turn-stop": client.held_direction = Vector2.UP if now <= 0.75 else Vector2.DOWN if now <= 1.25 else Vector2.ZERO
		while not inputs.is_empty() and inputs.front().at <= now + 0.000001:
			var delivered: Dictionary = inputs.pop_front()
			rules.set_input(0, delivered.command.direction, delivered.command.sequence)
		while next_tick <= now + 0.000001:
			rules.step()
			if rules.tick % 2 == 0:
				var lag: float = 0.015 if mode == "steady" else 0.025 + (rules.tick % 6) * 0.009
				if mode == "200ms-stall": lag += 0.085 + (0.18 if rules.tick % 12 == 0 else 0.0)
				if mode == "200ms-burst": lag = 0.1 + (0.18 if rules.tick % 34 == 0 else 0.0)
				last_view_arrival = maxf(last_view_arrival, next_tick + lag)
				views.append({"at": last_view_arrival, "snapshot": View.project(rules, 0)})
			next_tick += Rules.STEP
		while not views.is_empty() and views.front().at <= now + 0.000001:
			client._on_state(views.pop_front().snapshot)
			correction_max = maxf(correction_max, client.prediction.correction_distance)
		client._process(1.0 / fps)
		for command: Dictionary in wire.commands:
			var lag: float = 0.008 if mode == "steady" else 0.006 + (command.sequence % 4) * 0.008
			if mode != "steady" and command.sequence % 9 == 3: lag += 0.105
			if mode == "200ms-stall": lag += 0.092
			if mode == "200ms-burst": lag = 0.1 + (0.18 if command.sequence % 17 == 8 else 0.0)
			last_input_arrival = maxf(last_input_arrival, now + lag)
			inputs.append({"at": last_input_arrival, "command": command})
		wire.commands.clear()
		var point: Vector2 = client.token_positions[0]
		var reverse := -(point - before).dot(client.held_direction)
		if reverse > 0.01:
			backwards += 1
			backwards_max = maxf(backwards_max, reverse)
		if client.walking[0]:
			var facing: String = client.explorer_sprites[0].motion.facing
			if (client.held_direction == Vector2.UP and facing != "north") or (client.held_direction == Vector2.DOWN and facing != "south"): wrong_facing += 1
			if client.held_direction.is_zero_approx(): idle_motion += 1
		offset_max = maxf(offset_max, client.movement_view.offset.length())
		valid_feet = valid_feet and Map.walkable(point, client.prediction.closed_doors)
		before = point
	var result := {"fps": fps, "mode": mode, "backwards": backwards, "backwards_max": backwards_max, "wrong_facing": wrong_facing, "idle_motion": idle_motion, "correction_max": correction_max, "offset_max": offset_max, "valid_feet": valid_feet, "settled_error": before.distance_to(rules.explorers[0].position)}
	client.queue_free()
	await process_frame
	return result

func run() -> void:
	var traces: Array[Dictionary] = []
	for fps: int in [30, 60, 120]:
		for mode: String in ["steady", "jitter", "200ms-stall", "200ms-burst", "turn-stop"]:
			var result := await _trace(fps, mode)
			traces.append(result)
			var label := "%s at %dHz" % [mode, fps]
			check(result.backwards == 0, "Held direction never produces a backwards render frame: " + label)
			check(result.wrong_facing == 0 and result.idle_motion == 0, "Corrections do not turn or animate stationary feet: " + label)
			check(result.valid_feet, "Rendered feet respect shared geometry: " + label)
			check(result.offset_max <= Presentation.MAX_ERROR + 0.001, "Visual correction remains bounded: " + label)
			if mode == "turn-stop": check(result.settled_error < 0.1, "Released motion settles to authority: " + label)
	# A newly closed gate must invalidate even a small visual lead across it.
	var rules := Rules.new(1, 2)
	var door := Map.door_position("D0")
	rules.explorers[0].position = door + Vector2(0, 18)
	rules.explorers[0].region = "R0"
	rules.doors.D0.progress = 0.0
	rules.doors.D0.target_open = false
	rules.doors.D0.state = "closed"
	var prediction := Prediction.new()
	prediction.reset(View.project(rules, 0))
	var presentation := Presentation.new()
	var stale_point := door - Vector2(0, 14)
	presentation.reset(stale_point)
	presentation.reconcile(stale_point, prediction.position)
	var rendered := presentation.sample(prediction, Vector2.UP, 0.02, 1.0 / 60)
	check(rendered.y > door.y and Map.walkable(rendered, ["D0"]), "Closed gates cannot be crossed by correction blending")
	presentation.reconcile(rendered, prediction.position + Vector2(0, 100))
	check(presentation.offset.is_zero_approx(), "A large authority correction discards visual lag")
	# During an acknowledgement stall, rendering cannot bypass the pending cap.
	presentation.reset(prediction.position)
	for i in range(50): prediction.advance(Vector2.DOWN)
	var held := presentation.sample(prediction, Vector2.DOWN, 0.01, 1.0 / 60)
	for i in range(30): rendered = presentation.sample(prediction, Vector2.DOWN, 0.04, 1.0 / 60)
	check(prediction.pending.size() == Prediction.MAX_PENDING and held.distance_to(rendered) < 0.001, "Connection stalls stop the visual preview as well as fixed prediction")
	DirAccess.make_dir_recursive_absolute("res://test-output")
	var report := FileAccess.open("res://test-output/movement-view-traces.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(traces, "\t"))
	print("Movement view: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
