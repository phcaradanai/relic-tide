extends CanvasLayer
## Independent far scenery: local DA-V2 relief, never a moving playable room.
const CITY = preload("res://assets/generated/depth/atlantis-background-v1/art.tres")
const DEPTH_SHADER = preload("res://shaders/depth_parallax.gdshader")
var image: Sprite2D
var clock := 0.0
var reduced_motion := false
func _ready() -> void:
	layer = -5
	image = Sprite2D.new()
	image.texture = CITY.image
	image.position = Vector2(720, 450)
	var cover := maxf(1460.0 / CITY.image.get_width(), 920.0 / CITY.image.get_height())
	image.scale = Vector2.ONE * cover
	var relief := ShaderMaterial.new()
	relief.shader = DEPTH_SHADER
	relief.set_shader_parameter("depth_map", CITY.depth)
	relief.set_shader_parameter("near_is_white", CITY.near_is_white)
	relief.set_shader_parameter("focus_depth", 0.25)
	image.material = relief
	add_child(image)
	set_playing(false)
	set_time(0.0)
func _process(delta: float) -> void:
	if reduced_motion: return
	clock = fmod(clock + minf(delta, 0.1), 24.0)
	set_time(clock)
func set_time(seconds: float) -> void:
	var phase := seconds / 24.0 * TAU
	var offset := Vector2.ZERO if reduced_motion else Vector2(sin(phase), cos(phase) * 0.32) * 10.0
	image.material.set_shader_parameter("offset_pixels", offset)
func set_reduced_motion(enabled: bool) -> void:
	if enabled == reduced_motion: return
	reduced_motion = enabled
	set_time(clock)
func set_playing(playing: bool) -> void:
	image.modulate = Color(0.16, 0.25, 0.32) if playing else Color(0.82, 0.88, 0.94)
	image.material.set_shader_parameter("soft_focus", 2.2 if playing else 0.0)
	image.material.set_shader_parameter("desaturation", 0.28 if playing else 0.0)
