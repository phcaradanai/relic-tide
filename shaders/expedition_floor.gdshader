shader_type canvas_item;
uniform vec2 view_center = vec2(480.0, 440.0);
uniform float view_radius = 1250.0;
uniform float region_radius = 1250.0;
varying vec2 world_point;
varying vec4 tint;
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	tint = COLOR;
}
void fragment() {
	COLOR = texture(TEXTURE, UV) * tint;
	float reach = min(view_radius, region_radius);
	COLOR.a *= 1.0 - smoothstep(reach * 0.90, reach, distance(world_point, view_center));
}
