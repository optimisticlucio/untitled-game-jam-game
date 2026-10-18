shader_type spatial;
// Overlay for a highlighted tool: a light glow on top of its normal material.
// The outline is drawn separately (highlight_outline.gdshader).
render_mode unshaded, blend_add, depth_draw_never;

uniform vec4 glow_color : source_color = vec4(0.7, 1.0, 0.2, 1.0);
uniform float rim_power = 2.0;
// Glow toward the silhouette.
uniform float rim_strength = 0.35;
// Glow across the whole surface.
uniform float base_strength = 0.15;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	ALBEDO = glow_color.rgb * (base_strength + rim * rim_strength);
}
