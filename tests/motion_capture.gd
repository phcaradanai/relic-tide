extends SceneTree
func _init() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900)
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.auto_connect = false
	root.add_child(scene)
	scene._start(4)
	await create_timer(0.5).timeout
	scene._step_movement(Vector2.RIGHT)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/motion.png")
	quit()
