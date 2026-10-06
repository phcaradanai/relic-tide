extends Node2D
## Isolated asset inspection. The production expedition never loads this scene.
const CARRY = preload("res://assets/generated/sprites/explorer-p1-carry-e-v2/frames.tres")
const ROOM = preload("res://assets/generated/depth/workshop-reference-v1/art.tres")
const Layer = preload("res://scripts/assets/depth_layer.gd")

var art: Sprite2D
var explorer: AnimatedSprite2D
var caption: Label
var paused := false
var clock := 0.0
var capture_path := ""
var capture_frame := 0
var pixel_candidate := false

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--pixel-candidate": pixel_candidate = true
	art = Sprite2D.new()
	art.set_script(Layer)
	art.art = ROOM
	art.position = Vector2(720, 468)
	art.scale = Vector2.ONE * (680.0 / 380.0)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(art)
	explorer = AnimatedSprite2D.new()
	explorer.sprite_frames = CARRY
	if pixel_candidate:
		explorer.sprite_frames = load("res://assets/generated/sprites/explorer-p1-carry-east-pixel-v2/frames.tres")
	explorer.animation = &"carry_e"
	# Aligned source canvas: original cell + 16px border, authored foot (144,264).
	explorer.offset = Vector2(0, -120)
	if pixel_candidate: explorer.offset = Vector2(0, -90)
	explorer.position = Vector2(698, 633)
	explorer.scale = Vector2.ONE * 0.55
	if pixel_candidate: explorer.scale /= 0.75
	explorer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(explorer)
	explorer.play()
	caption = Label.new()
	caption.position = Vector2(80, 44)
	caption.size = Vector2(1280, 56)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 21)
	caption.add_theme_color_override("font_color", Color("f1ead6"))
	add_child(caption)
	_update_caption()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="): capture_path = argument.trim_prefix("--capture=")
		if argument.begins_with("--pose="): capture_frame = clampi(int(argument.trim_prefix("--pose=")), 0, explorer.sprite_frames.get_frame_count(&"carry_e")-1)
	if not capture_path.is_empty(): _capture()

func _process(delta: float) -> void:
	if paused: return
	clock += delta
	# Walk a short room-local path at the slower carrier pace; camera stays fixed.
	var progress := fposmod(clock * 31.0, 180.0)
	explorer.position.x = 680 + (progress if progress < 90.0 else 180.0 - progress)
	explorer.flip_h = progress >= 90.0

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_SPACE:
		paused = not paused
		if paused: explorer.pause()
		else: explorer.play()
		_update_caption()
	elif event.keycode == KEY_RIGHT and paused:
		explorer.frame = (explorer.frame + 1) % explorer.sprite_frames.get_frame_count(&"carry_e")
	elif event.keycode == KEY_ESCAPE:
		get_tree().quit()

func _update_caption() -> void:
	caption.text = "Workshop · %s carry study\nSpace: %s  ·  Right: step a paused pose  ·  Esc: close" % ["PixelLab" if pixel_candidate else "Aseprite", "play" if paused else "pause"]

func _capture() -> void:
	paused = true
	explorer.pause()
	explorer.frame = capture_frame
	explorer.position.x = 715
	_update_caption()
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(capture_path)
	get_tree().quit(0 if result == OK else 1)
