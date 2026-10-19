shader_type spatial;
// The held tool's outline, after Julia's reference video: a thin neon band whose colour runs
// through the rainbow (yellow, green, cyan, blue, pink) and slides along the silhouette over
// time. Same trick as highlight_outline.gdshader (pushed out along smoothed normals, back faces
// only), on the same outline mesh.
render_mode unshaded, cull_front, skip_vertex_transform;

// Width as a fraction of the distance to the camera.
uniform float width = 0.004;
// Screen pixels for one full run through the colours, and how many runs pass per second.
uniform float band_px = 900.0;
uniform float speed = 0.35;
// Mix toward white: higher = brighter and softer (pastel) colours.
uniform float whiteness = 0.55;

vec3 hue_to_rgb(float h) {
	return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

void vertex() {
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	VERTEX += NORMAL * width * -VERTEX.z;
}

void fragment() {
	float h = fract((FRAGCOORD.x + FRAGCOORD.y) / band_px - TIME * speed);
	ALBEDO = mix(hue_to_rgb(h), vec3(1.0), whiteness);
}
