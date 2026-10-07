shader_type canvas_item;

// Raster material in world coordinates, shared by prototype and large maps.
uniform sampler2D floor_mask : filter_nearest, repeat_disable;
uniform bool is_floor_pass = false;
uniform vec2 view_center = vec2(720.0, 450.0);
uniform float view_radius = 105.0;
varying vec4 tint;
varying vec2 world_point;
void vertex() { tint = COLOR; world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	vec4 painted = texture(TEXTURE, UV);
	float distance_from_view = distance(world_point, view_center);
	float local_window = 1.0 - smoothstep(view_radius * 0.78, view_radius * 1.07, distance_from_view);
	float floor_coverage = is_floor_pass ? texture(floor_mask, UV).r : 0.0;
	// Remove only the painting's dark exterior void, keeping opaque hidden floors.
	float material_coverage = smoothstep(0.045, 0.10, max(painted.r, max(painted.g, painted.b)));
	COLOR = painted * tint;
	COLOR.a *= local_window * max(floor_coverage, material_coverage);
}
