@tool
class_name DepthLayer
extends Sprite2D
## Reusable background art layer. Motion is explicitly opt-in, with a 3px limit.
## Do not distort interactive floors or objects whose hitboxes need pixel alignment.

const ArtResource = preload("res://scripts/assets/depth_art.gd")
const DEPTH_SHADER = preload("res://shaders/depth_parallax.gdshader")

var _view_offset := Vector2.ZERO

@export var art: ArtResource:
	set(value):
		art = value
		if is_inside_tree(): _apply_art()
@export_range(0.0, 3.0, 0.1) var relief_pixels := 3.0:
	set(value):
		relief_pixels = clampf(value, 0.0, 3.0)
		if is_inside_tree(): set_view_offset(_view_offset)
@export var motion_enabled := false:
	set(value):
		motion_enabled = value
		if is_inside_tree(): set_view_offset(_view_offset)
@export var reduced_motion := true:
	set(value):
		reduced_motion = value
		if is_inside_tree(): set_view_offset(_view_offset)

func _ready() -> void:
	_apply_art()

func _apply_art() -> void:
	if art == null or not art.is_valid():
		texture = null
		material = null
		return
	texture = art.image
	var depth_material := ShaderMaterial.new()
	depth_material.shader = DEPTH_SHADER
	depth_material.set_shader_parameter("depth_map", art.depth)
	depth_material.set_shader_parameter("near_is_white", art.near_is_white)
	material = depth_material
	set_view_offset(Vector2.ZERO)

func set_view_offset(offset: Vector2) -> void:
	_view_offset = offset.limit_length(1.0)
	if material == null: return
	var displacement := Vector2.ZERO
	if motion_enabled and not reduced_motion:
		displacement = _view_offset * clampf(relief_pixels, 0.0, 3.0)
	material.set_shader_parameter("offset_pixels", displacement)

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if enabled: set_view_offset(Vector2.ZERO)
