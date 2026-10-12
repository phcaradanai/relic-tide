extends "res://tests/environment_render_test.gd"
## Close-threshold GPU regression; legal feet must never enter a shadow caster.
func run() -> void:
	root.size = Vector2i(1440, 900)
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.auto_connect = false
	root.add_child(scene)
	scene.set_process(false)
	for map_id in Maps.PRODUCTION_IDS:
		scene._restart()
		scene._start(2, map_id)
		var representatives: Array[String] = []
		for horizontal in [false, true]:
			for door_id: String in scene.Map.DOORS:
				if scene.Map.DOORS[door_id].horizontal == horizontal:
					representatives.append(door_id)
					break
		check(representatives.size() == 2, "Both gate orientations are covered: " + map_id)
		for id: String in representatives:
			for state: Dictionary in scene.fixture.doors.values():
				state.progress = 1.0
				state.target_open = true
			var gate: Vector2 = scene.Map.door_position(id)
			var normal := Vector2.DOWN if scene.Map.DOORS[id].horizontal else Vector2.RIGHT
			var tangent := Vector2.RIGHT if scene.Map.DOORS[id].horizontal else Vector2.DOWN
			scene.fixture.doors[id].progress = 0.0
			scene.fixture.doors[id].target_open = false
			for side in [-1, 1]:
				for offset in [0.0, -40.0, 40.0]:
					var feet: Vector2 = gate + normal * 14.01 * side + tangent * offset
					check(scene.Map.walkable(feet, [id]), "Closest door source is legal: %s %s %d %d" % [map_id, id, side, offset])
					place(scene, feet)
					var image := await capture(scene, "door-%s-%s-%d-%d" % [map_id, id, side, offset])
					check(pixel(scene, image, gate + normal * 80.0 * side + tangent * offset).get_luminance() > 0.025, "Own-side floor remains lit at closest closed gate: %s %s %d %d" % [map_id, id, side, offset])
					check(pixel(scene, image, gate - normal * 70.0 * side + tangent * offset).get_luminance() < 0.01, "Opposite floor stays hidden by closed gate: %s %s %d %d" % [map_id, id, side, offset])
					scene.fixture.doors[id].progress = 1.0
					scene.fixture.doors[id].target_open = true
					place(scene, feet)
					var opened := await capture(scene, "door-%s-%s-open-%d-%d" % [map_id, id, side, offset])
					check(pixel(scene, opened, gate - normal * 70.0 * side + tangent * offset).get_luminance() > 0.025, "Opening restores connected floor at close range: %s %s %d %d" % [map_id, id, side, offset])
					scene.fixture.doors[id].progress = 0.0
					scene.fixture.doors[id].target_open = false
		# The chest must occlude a person behind it, and yield to one in front.
		var chest: Vector2 = scene.Map.chest_anchors.T0.position
		place(scene, chest - Vector2(60, 0))
		var baseline := await capture(scene, "object-%s-chest-reference" % map_id)
		var sample := chest - Vector2(0, 22)
		var chest_color := pixel(scene, baseline, sample)
		place(scene, chest - Vector2(0, 15))
		var behind := await capture(scene, "object-%s-chest-behind" % map_id)
		check(pixel(scene, behind, sample).is_equal_approx(chest_color), "Chest paints over explorer behind its ground base: " + map_id)
		place(scene, chest + Vector2(0, 8))
		var front := await capture(scene, "object-%s-chest-front" % map_id)
		check(not pixel(scene, front, sample).is_equal_approx(chest_color), "Explorer in front paints over chest: " + map_id)
		check(scene.world.chest_sprites.T0.visible, "Recipient-visible chest has a standing raster sprite: " + map_id)
		check(scene.world.chest_sprites.T0.z_index == roundi(chest.y), "Chest participates in world ground-depth order: " + map_id)
		scene.world.update_objects({"chests": {}, "relic": {}, "lantern": {}}, scene.relic_texture, scene.lantern_texture)
		check(not scene.world.chest_sprites.values().any(func(sprite): return sprite.visible), "Empty recipient view hides every cached chest: " + map_id)
		check(scene.world.ground_lantern == null or not scene.world.ground_lantern.visible, "Empty recipient view hides dropped lantern: " + map_id)
		# A foreground wall may hide scenery, but must leave the local body readable.
		var center: Vector2 = scene.Map.region_center("R0")
		var feet := center + Vector2(120, scene.Map.ROOM_SIZE.y * 0.5 - 10)
		place(scene, feet)
		var enabled: Array[ShaderMaterial] = []
		for material in scene.world.wall_materials:
			if material.get_shader_parameter("foreground_cutaway"):
				enabled.append(material)
				material.set_shader_parameter("foreground_cutaway", false)
		var opaque := await capture(scene, "object-%s-wall-opaque" % map_id)
		for material in enabled: material.set_shader_parameter("foreground_cutaway", true)
		var cutaway := await capture(scene, "object-%s-wall-cutaway" % map_id)
		check(not pixel(scene, opaque, feet - Vector2(0, 5)).is_equal_approx(pixel(scene, cutaway, feet - Vector2(0, 5))), "Local foreground cutaway reveals grounded feet: " + map_id)
		check(scene.Map.walkable(feet) and scene.explorer_sprites[0].visible, "Cutaway does not move explorer or change legal feet: " + map_id)
	print("Door render: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
