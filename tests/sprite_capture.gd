extends SceneTree
class Gallery extends Node2D:
	var frames: Array[Dictionary]
	func _draw() -> void:
		for index in range(frames.size()):
			var frame: Dictionary = frames[index]
			var scale_factor := Vector2(0.7, 0.7)
			var origin := Vector2(120 + (index % 6) * 230, 220 + (index / 6) * 220)
			var offset := Vector2(frame.bounds.position - frame.cell_origin) - Vector2(128, 256)
			draw_texture_rect(frame.texture, Rect2(origin + offset * scale_factor, Vector2(frame.bounds.size) * scale_factor), false)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 960)
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.auto_connect = false
	root.add_child(scene)
	scene.hide()
	scene.ui.hide()
	var gallery := Gallery.new()
	gallery.frames = scene.walk_frames
	root.add_child(gallery)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://test-output/sprites-clean.png"))
	quit()
