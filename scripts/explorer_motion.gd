class_name ExplorerMotion
extends RefCounted
## Presentation only. Gait advances from rendered displacement, never wall time.
const DIRECTIONS := ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]
const WALK_STRIDE := 92.0
const WADE_STRIDE := 70.0
const GAITS := ["walk", "carry_walk", "relic_walk", "lantern_walk", "dual_walk", "wade"]
const SETTLED := {"walk": "idle", "wade": "idle", "carry_walk": "carry_idle", "relic_walk": "relic_idle", "lantern_walk": "lantern_idle", "dual_walk": "dual_idle"}
var facing := "south"
var gait := 0.0
var clock := 0.0
var stationary_time := 1.0
var action := "idle"
func look_towards(direction: Vector2) -> void:
	if direction.length_squared() < 0.0001: return
	facing = DIRECTIONS[posmod(roundi(direction.angle() / (PI / 4.0)), 8)]
func advance(delta: float, displacement: Vector2, requested_action: String, aim := Vector2.ZERO) -> void:
	var distance := displacement.length()
	var was_stationary := stationary_time
	if distance > 0.01:
		look_towards(displacement)
		stationary_time = 0.0
		gait = fposmod(gait + distance / (WADE_STRIDE if requested_action == "wade" else WALK_STRIDE), 1.0)
	else:
		stationary_time += delta
	if requested_action == "use": look_towards(aim)
	var next := requested_action
	if requested_action in GAITS and stationary_time >= 0.09:
		next = SETTLED[requested_action]
	if next != action:
		clock = 0.0
		if next in GAITS and was_stationary > 0.15:
			gait = fposmod(distance / (WADE_STRIDE if next == "wade" else WALK_STRIDE), 1.0)
		action = next
	clock += delta
func texture(frames: SpriteFrames, reduced_motion: bool = false) -> Texture2D:
	var animation := StringName(action + "_" + facing)
	var count := frames.get_frame_count(animation)
	if count == 0: return null
	if reduced_motion and action.ends_with("idle"):
		return frames.get_frame_texture(animation, 0)
	var total := 0.0
	for i in range(count): total += frames.get_frame_duration(animation, i)
	var phase := clock * frames.get_animation_speed(animation)
	if action in GAITS:
		phase = gait * total
	elif action == "down" or not frames.get_animation_loop(animation):
		phase = minf(phase, total - 0.00001)
	else:
		phase = fposmod(phase, total)
	for i in range(count):
		phase -= frames.get_frame_duration(animation, i)
		if phase < 0: return frames.get_frame_texture(animation, i)
	return frames.get_frame_texture(animation, count - 1)
