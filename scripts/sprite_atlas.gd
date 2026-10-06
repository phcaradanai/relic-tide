extends RefCounted
## Isolate painted figures before sampling an irregular generated atlas.
## This copies existing artwork; it never draws replacement character parts.
static func extract(image: Image, columns: int, rows: int) -> Array[Dictionary]:
	var width := image.get_width()
	var height := image.get_height()
	var labels := PackedInt32Array()
	labels.resize(width * height)
	labels.fill(-1)
	var opaque := PackedByteArray()
	opaque.resize(labels.size())
	for y in range(height):
		for x in range(width):
			opaque[y * width + x] = int(image.get_pixel(x, y).a > 0.5)
	var components: Array[Dictionary] = []
	for pixel in range(labels.size()):
		if opaque[pixel] == 0 or labels[pixel] >= 0: continue
		var id := components.size()
		var queue := PackedInt32Array([pixel])
		labels[pixel] = id
		var head := 0
		var bounds := Rect2i(Vector2i(pixel % width, pixel / width), Vector2i.ONE)
		while head < queue.size():
			var current := queue[head]
			head += 1
			var point := Vector2i(current % width, current / width)
			bounds = bounds.expand(point)
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next: Vector2i = point + direction
				if next.x < 0 or next.x >= width or next.y < 0 or next.y >= height: continue
				var index: int = next.y * width + next.x
				if opaque[index] == 0 or labels[index] >= 0: continue
				labels[index] = id
				queue.append(index)
		components.append({"bounds": bounds, "pixels": queue})
	var cell := Vector2i(width / columns, height / rows)
	var bodies: Array[int] = []
	bodies.resize(columns * rows)
	bodies.fill(-1)
	for id in range(components.size()):
		var center: Vector2i = components[id].bounds.get_center()
		var slot := mini(rows - 1, center.y / cell.y) * columns + mini(columns - 1, center.x / cell.x)
		if bodies[slot] < 0 or components[id].pixels.size() > components[bodies[slot]].pixels.size(): bodies[slot] = id
	var owners := PackedInt32Array()
	owners.resize(components.size())
	for id in range(components.size()):
		var center: Vector2 = components[id].bounds.get_center()
		var best_distance := INF
		for slot in range(bodies.size()):
			if bodies[slot] < 0: continue
			var distance := center.distance_squared_to(Vector2(components[bodies[slot]].bounds.get_center()))
			if distance < best_distance:
				best_distance = distance
				owners[id] = slot
	var frames: Array[Dictionary] = []
	for slot in range(bodies.size()):
		assert(bodies[slot] >= 0, "Atlas must contain one painted figure per slot")
		var bounds: Rect2i = components[bodies[slot]].bounds
		for id in range(components.size()):
			if owners[id] == slot: bounds = bounds.merge(components[id].bounds)
		bounds = bounds.grow(1).intersection(Rect2i(0, 0, width, height))
		var clean := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
		for id in range(components.size()):
			if owners[id] != slot: continue
			for pixel in components[id].pixels:
				var point := Vector2i(pixel % width, pixel / width)
				# Preserve one antialiased edge pixel around this figure only.
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var sample := point + Vector2i(dx, dy)
						if not bounds.has_point(sample): continue
						var label := labels[sample.y * width + sample.x]
						if label >= 0 and owners[label] != slot: continue
						clean.set_pixelv(sample - bounds.position, image.get_pixelv(sample))
		frames.append({"texture": ImageTexture.create_from_image(clean), "bounds": bounds, "cell_origin": Vector2i(slot % columns, slot / columns) * cell})
	return frames
