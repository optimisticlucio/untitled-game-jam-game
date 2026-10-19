shader_type spatial;
// Soft glow around the held tool's neon outline (highlight_neon.gdshader): the same moving
// rainbow, fading out away from the tool, with small sparkles that twinkle around it.
// Pushed out like the outline (outline_width.gdshaderinc), back faces only, added on top (light,
// not paint).
render_mode unshaded, cull_front, skip_vertex_transform, depth_draw_never, blend_add;

#include "res://gameplay/outline_width.gdshaderinc"

// Width as a fraction of the distance to the camera (wider than the outline; see
// outline_width.gdshaderinc).
uniform float width = 0.014;
uniform float strength = 0.6;
// Higher = the glow fades sooner.
uniform float softness = 2.0;
// Mix toward white: higher = brighter and softer (pastel) colours.
uniform float whiteness = 0.5;
// Keep these equal to the outline's, so the colours line up (screen widths per run of colours).
uniform float band_screens = 1.25;
uniform float speed = 0.35;
// Sparkles: share of screen cells that hold one, cell size in screen widths, twinkles per second.
uniform float sparkle_density = 0.07;
uniform float sparkle_cell = 0.033;
uniform float sparkle_speed = 3.0;

vec3 hue_to_rgb(float h) {
	return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec3 direction = outline_direction(NORMAL, MODELVIEW_MATRIX);
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	VERTEX = outline_vertex(VERTEX, direction, width);
}

void fragment() {
	// Facing the camera = close to the tool; edge-on = the outer rim of the glow.
	float facing = abs(dot(NORMAL, VIEW));
	float h = fract((FRAGCOORD.x + FRAGCOORD.y) / (band_screens * VIEWPORT_SIZE.x) - TIME * speed);
	vec3 glow = mix(hue_to_rgb(h), vec3(1.0), whiteness) * strength * pow(facing, softness);

	// A four-pointed twinkle in a few random screen cells.
	float cell_px = sparkle_cell * VIEWPORT_SIZE.x;
	vec2 cell = floor(FRAGCOORD.xy / cell_px);
	float r = hash2(cell);
	float sparkle = 0.0;
	if (r > 1.0 - sparkle_density) {
		vec2 p = fract(FRAGCOORD.xy / cell_px) - 0.5;
		float star = max(0.0, 1.0 - abs(p.x) * 16.0) * max(0.0, 1.0 - abs(p.y) * 2.4)
				+ max(0.0, 1.0 - abs(p.y) * 16.0) * max(0.0, 1.0 - abs(p.x) * 2.4);
		float twinkle = 0.5 + 0.5 * sin(TIME * sparkle_speed + r * 40.0);
		sparkle = star * twinkle * twinkle;
	}
	ALBEDO = glow + vec3(sparkle);
}
