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

void vertex() {
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	VERTEX += NORMAL * width * -VERTEX.z;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
