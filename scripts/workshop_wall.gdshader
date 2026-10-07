shader_type canvas_item;
uniform sampler2D wall_mask : filter_linear;
varying vec2 mask_uv;
void vertex() {
	mask_uv = VERTEX / vec2(402.0, 382.0);
}
void fragment() {
	COLOR.a *= texture(wall_mask, mask_uv).a;
}
