extends Node2D
## Isolated art QA. Nothing in the live expedition uses this scene.

@onready var layer: DepthLayer = $Art
@onready var status: Label = $Caption
var phase := 0.0
var capture_path := ""
var capture_motion := false

func _ready() -> void:
	var fit := minf(1350.0 / layer.texture.get_width(), 840.0 / layer.texture.get_height())
	layer.scale = Vector2.ONE * fit
	var relic: AnimatedSprite2D = $ImportedRelic
	var relic_texture := relic.sprite_frames.get_frame_texture("idle", 0)
	relic.scale = Vector2.ONE * (90.0 / relic_texture.get_height())
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="): capture_path = argument.trim_prefix("--capture=")
		if argument == "--preview-motion": capture_motion = true
	_update_caption()
	if not capture_path.is_empty(): _capture()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		layer.motion_enabled = not layer.motion_enabled
		layer.set_reduced_motion(not layer.motion_enabled)
		layer.set_view_offset(Vector2.ZERO)
		_update_caption()

func _process(delta: float) -> void:
	phase += delta * 0.3
	layer.set_view_offset(Vector2(sin(phase), 0.0))

func _update_caption() -> void:
	status.text = "Depth preview · original ruin art · Space: " + ("turn motion off" if layer.motion_enabled else "try gentle motion (off by default)")

func _capture() -> void:
	if capture_motion:
		layer.motion_enabled = true
		layer.set_reduced_motion(false)
		set_process(false)
		layer.set_view_offset(Vector2.ONE.normalized())
		_update_caption()
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(capture_path)
	get_tree().quit(0 if error == OK else 1)
