extends SceneTree
## Geometry-only alpha/light masks from shared floors. No scenery is generated.
const Map = preload("res://scripts/level_map.gd")
func _init() -> void:
	var source := Image.load_from_file("res://assets/ruin-movement.png")
	source.convert(Image.FORMAT_RGBA8)
	var floor_mask := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_L8)
	var floors := Map.floors()
	for y in source.get_height():
		for x in source.get_width():
			var point := Map.from_art(Vector2(x, y))
			var on_floor := false
			var alpha := 0.0
			for rect: Rect2 in floors:
				if rect.has_point(point): on_floor = true
				# Keep the Landing's original pier/boat as painted scenery.
				var pier := Map.floors("R0")[0] == rect
				var band := rect.grow_individual(40, 130, 40, 145 if pier else 28)
				if band.has_point(point):
					var edge := minf(minf(point.x - band.position.x, band.end.x - point.x), minf(point.y - band.position.y, band.end.y - point.y))
					alpha = maxf(alpha, clampf(edge / 9.0, 0.0, 1.0))
			if on_floor:
				alpha = 0.0
				floor_mask.set_pixel(x, y, Color.WHITE)
			var color := source.get_pixel(x, y)
			color.a = alpha
			source.set_pixel(x, y, color)
	source.save_png("res://assets/ruin-wall-faces-v2.png")
	floor_mask.save_png("res://assets/ruin-floor-mask-v2.png")
	print("Fixed raster wall faces and shared floor mask exported; no furniture sight boxes.")
	quit()
