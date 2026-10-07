extends Node2D
## Held props, fingers and occlusion are authored together in each raster pose.
const Motion = preload("res://scripts/explorer_motion.gd")
const Map = preload("res://scripts/level_map.gd")
var motion := Motion.new()
var frames: SpriteFrames
var feet := Vector2.ZERO
var art_scale := 1.0
var has_relic := false
var has_light := false
var drowned := false
var reduced_motion := false
var water_depth := 0.0
var number := 1
var identity := Color.WHITE
var font: Font
var pickup_action := ""
var pickup_clock := 0.0
func configure(resource: SpriteFrames, player: int, color: Color, label_font: Font) -> void:
	frames = resource
	feet = frames.get_meta("foot_anchor")
	art_scale = frames.get_meta("display_scale")
	number = player + 1
	identity = color
	font = label_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unlit
func reset_visual() -> void:
	motion = Motion.new()
	has_relic = false
	has_light = false
	pickup_action = ""
	pickup_clock = 0.0
func set_inventory(relic_present: bool, light_present: bool, pickup_kind := "", aim := Vector2.ZERO) -> void:
	var changed := has_relic != relic_present or has_light != light_present
	if picking_up() and changed:
		pickup_action = ""
	has_relic = relic_present
	has_light = light_present
	if changed:
		motion.action = "dual_idle" if has_relic and has_light else "relic_idle" if has_relic else "lantern_idle" if has_light else "idle"
		motion.clock = 0.0
		queue_redraw()
	if pickup_kind.is_empty(): return
	if (pickup_kind == "relic" and not has_relic) or (pickup_kind == "lantern" and not has_light): return
	pickup_action = "pickup_" + pickup_kind
	if pickup_kind == "relic" and has_light: pickup_action += "_light"
	elif pickup_kind == "lantern" and has_relic: pickup_action += "_relic"
	pickup_clock = 0.0
	motion.look_towards(aim)
	motion.action = pickup_action
	motion.clock = 0.0
	queue_redraw()
func picking_up() -> bool:
	return not pickup_action.is_empty()
func advance_visual(delta: float, displacement: Vector2, requested_action: String, aim := Vector2.ZERO) -> void:
	if picking_up():
		# Death, ownership loss and substantial movement interrupt presentation.
		# This never assigns an owner or delays the authoritative inventory update.
		if requested_action in ["down", "use"] or displacement.length() > 5.0:
			pickup_action = ""
		else:
			pickup_clock += delta
			var animation := pickup_action + "_" + motion.facing
			var duration := 0.0
			for i in range(frames.get_frame_count(animation)):
				duration += frames.get_frame_duration(animation, i) / frames.get_animation_speed(animation)
			if pickup_clock < duration:
				motion.action = pickup_action
				motion.clock = pickup_clock
				return
			pickup_action = ""
	motion.advance(delta, displacement, requested_action, aim)
func _draw() -> void:
	if frames == null: return
	var pose: Texture2D = motion.texture(frames, reduced_motion)
	if pose == null: return
	var body := Rect2(-feet * art_scale, pose.get_size() * art_scale)
	if water_depth >= Map.WADING_DEPTH and not drowned:
		var cut := clampf(feet.y - minf(water_depth * 9, 16) / art_scale, 0, pose.get_height())
		draw_texture_rect_region(pose, Rect2(body.position, Vector2(body.size.x, cut * art_scale)), Rect2(0, 0, pose.get_width(), cut))
		# Keep the actual authored boots visible through the raster water surface.
		draw_texture_rect_region(pose, Rect2(body.position + Vector2(0, cut * art_scale), Vector2(body.size.x, (pose.get_height() - cut) * art_scale)), Rect2(0, cut, pose.get_width(), pose.get_height() - cut), Color(0.65, 0.82, 0.94, 0.45))
	else:
		draw_texture_rect(pose, body, false)
	if drowned:
		draw_string(font, Vector2(-25, 14), "DROWNED", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, identity)
	else:
		draw_string(font, Vector2(-10, -51), "P%d" % number, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, identity)
