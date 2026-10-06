extends Node2D
## Raster water uses normal canvas lighting, so unseen floor stays black.
const Map = preload("res://scripts/level_map.gd")
var depths: Dictionary = {}
var texture: Texture2D
func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture = load("res://assets/flood-water.png")
func set_depths(value: Dictionary) -> void:
	depths = value.duplicate()
	queue_redraw()
func _draw() -> void:
	if texture == null: return
	for region in depths:
		var depth: float = depths[region]
		if depth < 0.01: continue
		var alpha := clampf(0.12 + depth / Map.MAX_WATER_DEPTH * 0.33, 0.0, 0.45)
		for floor_rect: Rect2 in Map.floors(region):
			var points := PackedVector2Array([floor_rect.position, Vector2(floor_rect.end.x, floor_rect.position.y), floor_rect.end, Vector2(floor_rect.position.x, floor_rect.end.y)])
			var uvs := PackedVector2Array()
			for point in points: uvs.append(point / 230.0)
			draw_polygon(points, PackedColorArray([Color(0.72, 0.91, 1.0, alpha)]), uvs, texture)
