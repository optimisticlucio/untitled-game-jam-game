shader_type spatial;
// Outline for a highlighted tool: the mesh pushed out along its normals and
// drawn back faces only, so a band of colour shows around the silhouette.
// Use it on a copy of the mesh with smoothed normals (ToolGrabber makes one):
// with a model's hard-edged normals the band splits apart at every corner.
render_mode unshaded, cull_front, skip_vertex_transform;

uniform vec4 outline_color : source_color = vec4(0.7, 1.0, 0.2, 1.0);
// Width as a fraction of the distance to the camera, so the band stays about
// the same thickness on screen however close the tool is.
uniform float width = 0.008;
// How far (metres) the band is drawn toward the camera, so the tray cloth a
// resting tool lies on doesn't hide it. Must stay under the thinnest tool's
// thickness, or the band would cover the tool itself.
uniform float lift = 0.0003;

void vertex() {
	// Tools lie flat with their thin side along local Y. Push only sideways in
	// that plane: on a flat tool the smoothed normals point mostly up and down,
	// and pushed along them the band sank into the cloth on one side and showed
	// as a stray line on the other.
	vec3 flat_normal = vec3(NORMAL.x, 0.0, NORMAL.z);
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (length(flat_normal) > 0.0001) {
		vec3 view_normal = normalize((MODELVIEW_MATRIX * vec4(flat_normal, 0.0)).xyz);
		VERTEX += view_normal * width * -VERTEX.z;
	}
	VERTEX += normalize(-VERTEX) * lift;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
