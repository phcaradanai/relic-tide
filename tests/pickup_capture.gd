extends SceneTree
## The actual actor lifecycle: confirmed pickup, planted crouch, lift, held idle.
const Actor = preload("res://scripts/explorer_sprite.gd")
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var close_up := OS.get_cmdline_user_args().has("--close-up")
	root.size = Vector2i(1280,800) if close_up else Vector2i(1440,960)
	var font := SystemFont.new()
	var actors: Array[Node2D] = []
	var actions := ["pickup_relic", "pickup_lantern", "pickup_relic_light", "pickup_lantern_relic"]
	for row in range(2 if close_up else 4):
		for column in range(4 if close_up else 8):
			var variant := column if close_up else row
			var pickup := not close_up or row == 1
			var actor := Actor.new()
			actor.configure(load("res://assets/generated/sprites/explorer-holding-p%d-v2/frames.tres" % (variant + 1)), variant, Color.WHITE, font)
			actor.motion.facing = ["south","south","south_east","south_west"][column] if close_up else Actor.Motion.DIRECTIONS[column]
			actor.has_relic = variant in [0,2,3]
			actor.has_light = variant in [1,2,3]
			actor.pickup_action = actions[variant] if pickup else ""
			actor.motion.action = actor.pickup_action if pickup else "dual_walk" if actor.has_relic and actor.has_light else "relic_walk" if actor.has_relic else "lantern_walk"
			actor.position = Vector2(180 + column*300,280 + row*370) if close_up else Vector2(105 + column*176,180 + row*220)
			actor.scale = Vector2(3,3) if close_up else Vector2(2,2)
			actor.set_meta("walk_preview",not pickup)
			root.add_child(actor)
			actors.append(actor)
			var label := Label.new()
			label.text = ("Hold" if row == 0 else "Pick up")+" · "+["Relic","Lantern","Relic + light","Light + relic"][column] if close_up else Actor.Motion.DIRECTIONS[column].replace("_", " ")
			label.position = actor.position + Vector2(-35,22)
			root.add_child(label)
	var output := "res://.asset-work/grip-close-up" if close_up else "res://.asset-work/pickup-capture"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for step in range(24):
		for actor in actors:
			var action := "dual_walk" if actor.has_relic and actor.has_light else "relic_walk" if actor.has_relic else "lantern_walk"
			if actor.get_meta("walk_preview"):
				actor.motion.gait = fposmod(float(step)/12,1.0)
			else: actor.advance_visual(0 if step == 0 else 1.0/18.0, Vector2.ZERO, action)
			actor.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_png(output+"/%02d.png" % step)
		if step == 8: image.save_png("res://test-output/grip-pickup-close-up.png" if close_up else "res://test-output/pickup-crouch-directions.png")
	quit()
