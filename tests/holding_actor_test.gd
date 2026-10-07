extends SceneTree
const Actor = preload("res://scripts/explorer_sprite.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",message)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var frames: SpriteFrames=load("res://assets/generated/sprites/explorer-holding-p1-v2/frames.tres")
	var actor=Actor.new()
	root.add_child(actor)
	actor.configure(frames,0,Color.WHITE,SystemFont.new())
	actor.set_inventory(false,false,"relic")
	check(not actor.picking_up(),"An unconfirmed owner cannot display a pickup")
	for direction: String in Actor.Motion.DIRECTIONS:
		for action: String in ["pickup_relic","pickup_lantern","pickup_relic_light","pickup_lantern_relic"]:
			check(not frames.get_animation_loop(action+"_"+direction),"Pickup %s %s never loops"%[action,direction])
			actor.reset_visual()
			actor.motion.facing=direction
			actor.set_inventory(action!="pickup_lantern",action!="pickup_relic","relic" if action.begins_with("pickup_relic") else "lantern")
			check(actor.pickup_action==action,"The companion item selects the right physical pickup")
			actor.advance_visual(0.4,Vector2.ZERO,"dual_walk" if actor.has_relic and actor.has_light else "relic_walk" if actor.has_relic else "lantern_walk")
			check(actor.picking_up() and actor.motion.action==action,"Confirmed pickup keeps the crouch until the clip completes")
			actor.advance_visual(0.6,Vector2.ZERO,"dual_walk" if actor.has_relic and actor.has_light else "relic_walk" if actor.has_relic else "lantern_walk")
			check(not actor.picking_up() and actor.motion.action.ends_with("idle"),"Pickup finishes in a planted pose with the item")
			var ending: Texture2D=frames.get_frame_texture(action+"_"+direction,15)
			check(ending.get_image().get_data()==actor.motion.texture(frames,true).get_image().get_data(),"Artist's gripping endpoint exactly matches held idle")
	actor.set_inventory(true,true,"relic")
	actor.set_inventory(false,true)
	check(not actor.picking_up() and actor.motion.action=="lantern_idle","Dropping relic immediately removes its art while retaining the lantern")
	actor.set_inventory(true,true,"relic")
	actor.advance_visual(0.1,Vector2.ZERO,"down")
	check(not actor.picking_up() and actor.motion.action=="down","Death interrupts the pickup lifecycle")
	actor.set_inventory(true,false,"relic")
	actor.advance_visual(0.1,Vector2(10,0),"relic_walk")
	check(not actor.picking_up() and actor.motion.action=="relic_walk","Substantial remote movement cannot slide a crouching body")
	actor.reset_visual()
	check(not actor.picking_up() and not actor.has_relic and not actor.has_light,"Hiding or changing match clears held-art caches")
	actor.queue_free()
	await process_frame
	print("Holding actor: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
