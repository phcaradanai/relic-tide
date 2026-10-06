extends SceneTree

const Art = preload("res://scripts/assets/depth_art.gd")
const Layer = preload("res://scripts/assets/depth_layer.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var art: Art = load("res://assets/generated/depth/ruin-preview/art.tres")
	check(art != null and art.is_valid(), "Imported source and depth must match dimensions")
	check(art.near_is_white, "Normalized DA-V2 depth uses near-white encoding")
	var depth_image := art.depth.get_image()
	check(depth_image != null, "Imported depth is a real texture")
	var min_depth := 1.0
	var max_depth := 0.0
	for y in range(0, depth_image.get_height(), 32):
		for x in range(0, depth_image.get_width(), 32):
			var pixel := depth_image.get_pixel(x, y)
			check(is_equal_approx(pixel.r, pixel.g) and is_equal_approx(pixel.g, pixel.b), "Depth is grayscale")
			min_depth = minf(min_depth, pixel.r)
			max_depth = maxf(max_depth, pixel.r)
	check(max_depth - min_depth > 0.1, "Real inference must have non-flat relief")
	var first := Layer.new()
	first.art = art
	root.add_child(first)
	var second := Layer.new()
	second.art = art
	root.add_child(second)
	check(first.material != second.material, "Layers own independent material parameters")
	first.set_view_offset(Vector2.ONE)
	check(first.material.get_shader_parameter("offset_pixels") == Vector2.ZERO, "Motion is off by default")
	first.motion_enabled = true
	first.set_view_offset(Vector2.ONE)
	check(first.material.get_shader_parameter("offset_pixels") == Vector2.ZERO, "Reduced motion blocks decorative offsets")
	first.set_reduced_motion(false)
	first.set_view_offset(Vector2(500, 0))
	var active_offset: Vector2 = first.material.get_shader_parameter("offset_pixels")
	check(is_equal_approx(active_offset.length(), 3.0), "Explicit motion is bounded to three source pixels")
	check(second.material.get_shader_parameter("offset_pixels") == Vector2.ZERO, "One layer cannot move another")
	first.motion_enabled = false
	check(first.material.get_shader_parameter("offset_pixels") == Vector2.ZERO, "Disabling motion resets the active displacement")
	first.motion_enabled = true
	first.set_reduced_motion(true)
	check(first.material.get_shader_parameter("offset_pixels") == Vector2.ZERO, "Reduced motion immediately restores original sampling")
	var frames: SpriteFrames = load("res://assets/generated/sprites/relic-preview/frames.tres")
	check(frames.has_animation("idle") and frames.get_frame_count("idle") == 1, "Imported idol has a native idle frame")
	var source: Texture2D = load("res://assets/relic.png")
	var frame: AtlasTexture = frames.get_frame_texture("idle", 0)
	check(frame.region.size == Vector2(source.get_size()), "Imported frame retains full canvas alignment")
	var fixture: PackedScene = load("res://scenes/samples/depth_preview.tscn")
	check(fixture != null, "Separate art QA scene imports")
	var preview := fixture.instantiate()
	root.add_child(preview)
	check(not preview.get_node("Art").motion_enabled, "Preview starts static")
	preview.queue_free()
	first.queue_free()
	second.queue_free()
	await process_frame
	print("Asset pipeline: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
