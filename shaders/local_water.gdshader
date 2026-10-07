shader_type canvas_item;
uniform vec2 view_center = vec2(720.0, 450.0);
uniform float view_radius = 105.0;
varying vec2 world_point;
varying vec4 tint;
void vertex() { world_point = VERTEX; tint = COLOR; }
void fragment() {
	COLOR = texture(TEXTURE, UV) * tint;
	COLOR.a *= 1.0 - smoothstep(view_radius * 0.78, view_radius * 1.07, distance(world_point, view_center));
}
