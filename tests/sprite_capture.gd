extends SceneTree
## Eight real directions and carrying poses, using the production resources.
const Actor = preload("res://scripts/explorer_sprite.gd")
func _init() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 960)
	var font := SystemFont.new()
	var actors: Array[Node2D] = []
	for row in range(4):
		for column in range(8):
			var actor := Actor.new()
			var resource: SpriteFrames = load("res://assets/generated/sprites/explorer-holding-p%d-v2/frames.tres" % (row + 1))
			actor.configure(resource, row, Color.WHITE, font)
			actor.motion.facing = Actor.Motion.DIRECTIONS[column]
			actor.motion.action = ["walk", "relic_walk", "lantern_walk", "dual_walk"][row]
			actor.has_relic = row in [1, 3]
			actor.has_light = row in [2, 3]
			actor.motion.gait = 0.25
			actor.position = Vector2(105 + column * 176, 180 + row * 220)
			actor.scale = Vector2(2, 2)
			root.add_child(actor)
			actors.append(actor)
			var label := Label.new()
			label.text = Actor.Motion.DIRECTIONS[column].replace("_", " ")
			label.position = actor.position + Vector2(-35, 22)
			root.add_child(label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.asset-work/direction-capture"))
	for step in range(12):
		for actor in actors:
			actor.motion.gait = float(step) / 12
			actor.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_png("res://.asset-work/direction-capture/%02d.png" % step)
		if step == 3: image.save_png("res://test-output/sprites-eight-directions.png")
	quit()
