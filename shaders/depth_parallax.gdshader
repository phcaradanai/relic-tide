shader_type canvas_item;

// Numeric grayscale depth: deliberately no source_color hint.
uniform sampler2D depth_map : filter_linear, repeat_disable;
uniform bool near_is_white = true;
uniform vec2 offset_pixels = vec2(0.0);
uniform float focus_depth : hint_range(0.0, 1.0) = 0.5;

varying vec4 vertex_modulate;

void vertex() {
	vertex_modulate = COLOR;
}

void fragment() {
	float relief = texture(depth_map, UV).r;
	if (!near_is_white) { relief = 1.0 - relief; }
	vec2 sample_uv = UV + offset_pixels * TEXTURE_PIXEL_SIZE * (relief - focus_depth);
	sample_uv = clamp(sample_uv, TEXTURE_PIXEL_SIZE * 0.5, vec2(1.0) - TEXTURE_PIXEL_SIZE * 0.5);
	// Keep vertex tint and CanvasItem lighting; do not multiply two texture samples.
	COLOR = texture(TEXTURE, sample_uv) * vertex_modulate;
}
