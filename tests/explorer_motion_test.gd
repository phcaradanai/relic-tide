extends SceneTree
const Motion = preload("res://scripts/explorer_motion.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _init() -> void:
	var fast := Motion.new()
	var slow := Motion.new()
	for step in range(60): fast.advance(1.0 / 60.0, Vector2(1.5, 0), "walk")
	for step in range(20): slow.advance(1.0 / 20.0, Vector2(4.5, 0), "walk")
	check(is_equal_approx(fast.gait, slow.gait), "Same distance gives the same stride at 20 and 60fps")
	var phase: float = fast.gait
	for step in range(60): fast.advance(1.0 / 60.0, Vector2.ZERO, "walk")
	check(fast.action == "idle" and is_equal_approx(fast.gait, phase), "Walking against a wall settles with planted feet")
	fast.advance(0.2, Vector2.ZERO, "carry_walk")
	check(fast.action == "carry_idle", "A stationary carrier retains the carrying pose")
	for kind: String in ["relic", "lantern", "dual"]:
		fast.advance(0.2, Vector2.ZERO, kind + "_walk")
		check(fast.action == kind + "_idle", "%s keeps its actual grip with planted feet" % kind)
	var directions := [Vector2.RIGHT, Vector2(1, 1), Vector2.DOWN, Vector2(-1, 1), Vector2.LEFT, Vector2(-1, -1), Vector2.UP, Vector2(1, -1)]
	for i in range(8):
		fast.advance(0.016, directions[i], "walk")
		check(fast.facing == Motion.DIRECTIONS[i], "Movement chooses authored direction %s" % Motion.DIRECTIONS[i])
	fast.advance(0.016, Vector2.ZERO, "use", Vector2.UP)
	check(fast.action == "use" and fast.facing == "north", "Using a mechanism faces the mechanism")
	var frames := SpriteFrames.new()
	frames.add_animation("down_north")
	frames.set_animation_speed("down_north", 8)
	for i in range(8):
		var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		image.fill(Color(float(i) / 8, 0, 0))
		frames.add_frame("down_north", ImageTexture.create_from_image(image))
	fast.advance(5, Vector2.ZERO, "down")
	check(fast.texture(frames) == frames.get_frame_texture("down_north", 7), "Collapse stays on the final pose without standing up again")
	frames.add_animation("idle_north")
	frames.set_animation_speed("idle_north", 1000)
	frames.add_frame("idle_north", frames.get_frame_texture("down_north", 0), 100)
	frames.add_frame("idle_north", frames.get_frame_texture("down_north", 1), 200)
	fast.advance(0.15, Vector2.ZERO, "idle")
	check(fast.texture(frames) == frames.get_frame_texture("idle_north", 1), "Aseprite millisecond durations preserve an artist's longer pose hold")
	check(fast.texture(frames, true) == frames.get_frame_texture("idle_north", 0), "Reduced motion keeps idle still without changing game time")
	frames.add_animation("pickup_lantern_north")
	frames.set_animation_speed("pickup_lantern_north", 18)
	frames.set_animation_loop("pickup_lantern_north", false)
	for i in range(8): frames.add_frame("pickup_lantern_north", frames.get_frame_texture("down_north", i))
	fast.advance(5, Vector2.ZERO, "pickup_lantern")
	check(fast.texture(frames) == frames.get_frame_texture("pickup_lantern_north", 7), "An authored pickup is one-shot and holds its standing endpoint")
	print("Explorer motion: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
