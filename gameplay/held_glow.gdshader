shader_type spatial;
// Overlay for a held tool: a soft rim glow on top of its normal material.
render_mode unshaded, blend_add, depth_draw_never;

uniform vec4 glow_color : source_color = vec4(0.7, 1.0, 0.2, 1.0);
uniform float rim_power = 2.0;
// Glow across the whole surface, so thin tools seen face-on still light up.
uniform float base_strength = 0.25;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	ALBEDO = glow_color.rgb * (base_strength + rim);
}
