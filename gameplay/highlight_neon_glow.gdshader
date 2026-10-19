shader_type spatial;
// Soft glow around the held tool's neon outline (highlight_neon.gdshader): the same moving
// rainbow, fading out away from the tool, with small sparkles that twinkle around it.
// Pushed out along smoothed normals, back faces only, added on top (light, not paint).
render_mode unshaded, cull_front, skip_vertex_transform, depth_draw_never, blend_add;

// Width as a fraction of the distance to the camera (wider than the outline).
uniform float width = 0.014;
uniform float strength = 0.6;
// Higher = the glow fades sooner.
uniform float softness = 2.0;
// Mix toward white: higher = brighter and softer (pastel) colours.
uniform float whiteness = 0.5;
// Keep these equal to the outline's, so the colours line up.
uniform float band_px = 900.0;
uniform float speed = 0.35;
// Sparkles: share of screen cells that hold one, cell size in pixels, twinkles per second.
uniform float sparkle_density = 0.07;
uniform float sparkle_cell_px = 24.0;
uniform float sparkle_speed = 3.0;

vec3 hue_to_rgb(float h) {
	return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	VERTEX += NORMAL * width * -VERTEX.z;
}

void fragment() {
	// Facing the camera = close to the tool; edge-on = the outer rim of the glow.
	float facing = abs(dot(NORMAL, VIEW));
	float h = fract((FRAGCOORD.x + FRAGCOORD.y) / band_px - TIME * speed);
	vec3 glow = mix(hue_to_rgb(h), vec3(1.0), whiteness) * strength * pow(facing, softness);

	// A four-pointed twinkle in a few random screen cells.
	vec2 cell = floor(FRAGCOORD.xy / sparkle_cell_px);
	float r = hash2(cell);
	float sparkle = 0.0;
	if (r > 1.0 - sparkle_density) {
		vec2 p = fract(FRAGCOORD.xy / sparkle_cell_px) - 0.5;
		float star = max(0.0, 1.0 - abs(p.x) * 16.0) * max(0.0, 1.0 - abs(p.y) * 2.4)
				+ max(0.0, 1.0 - abs(p.y) * 16.0) * max(0.0, 1.0 - abs(p.x) * 2.4);
		float twinkle = 0.5 + 0.5 * sin(TIME * sparkle_speed + r * 40.0);
		sparkle = star * twinkle * twinkle;
	}
	ALBEDO = glow + vec3(sparkle);
}
