shader_type spatial;
// The held tool's outline, after Julia's reference video: a thin neon band whose colour runs
// through the rainbow (yellow, green, cyan, blue, pink) and slides along the silhouette over
// time. Pushed out sideways along smoothed normals, back faces only (outline_width.gdshaderinc), on
// ToolGrabber's outline mesh; it also works on a tool resting on the cloth.
render_mode unshaded, cull_front, skip_vertex_transform;

#include "res://gameplay/outline_width.gdshaderinc"

// Width as a fraction of the distance to the camera (see outline_width.gdshaderinc).
uniform float width = 0.004;
// One full run through the colours, in screen widths, and how many runs pass per second.
uniform float band_screens = 1.25;
uniform float speed = 0.35;
// Mix toward white: higher = brighter and softer (pastel) colours.
uniform float whiteness = 0.55;

vec3 hue_to_rgb(float h) {
	return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

void vertex() {
	vec3 direction = outline_direction(NORMAL, MODELVIEW_MATRIX);
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	VERTEX = outline_vertex(VERTEX, direction, width);
}

void fragment() {
	float h = fract((FRAGCOORD.x + FRAGCOORD.y) / (band_screens * VIEWPORT_SIZE.x) - TIME * speed);
	ALBEDO = mix(hue_to_rgb(h), vec3(1.0), whiteness);
}
