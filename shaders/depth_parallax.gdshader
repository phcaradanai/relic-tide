shader_type canvas_item;

// Numeric grayscale depth: deliberately no source_color hint.
uniform sampler2D depth_map : filter_linear, repeat_disable;
uniform bool near_is_white = true;
uniform vec2 offset_pixels = vec2(0.0);
uniform float focus_depth : hint_range(0.0, 1.0) = 0.5;
uniform float soft_focus : hint_range(0.0, 4.0) = 0.0;
uniform float desaturation : hint_range(0.0, 1.0) = 0.0;

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
	vec4 painted = texture(TEXTURE, sample_uv);
	if (soft_focus > 0.0) {
		vec2 blur = TEXTURE_PIXEL_SIZE * soft_focus;
		painted = painted * 0.4
			+ texture(TEXTURE, sample_uv + vec2(blur.x, 0.0)) * 0.15
			+ texture(TEXTURE, sample_uv - vec2(blur.x, 0.0)) * 0.15
			+ texture(TEXTURE, sample_uv + vec2(0.0, blur.y)) * 0.15
			+ texture(TEXTURE, sample_uv - vec2(0.0, blur.y)) * 0.15;
	}
	float value = dot(painted.rgb, vec3(0.2126, 0.7152, 0.0722));
	painted.rgb = mix(painted.rgb, vec3(value), desaturation);
	COLOR = painted * vertex_modulate;
}
