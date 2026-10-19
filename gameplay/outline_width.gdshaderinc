// For outlines pushed out along the smoothed normals of ToolGrabber's outline mesh.
// The width is a fraction of the distance to the camera, so the band is equally thick on screen on
// every tool, big or small, and on any screen size. In vertex(), before transforming VERTEX and
// NORMAL:
//   vec3 direction = outline_direction(NORMAL, MODELVIEW_MATRIX);
// and after:
//   VERTEX = outline_vertex(VERTEX, direction, width);

// Metres toward the camera, so the cloth under a resting tool can't hide the band.
uniform float lift = 0.0003;

// Which way to push a vertex, in view space: its normal without the mesh's own Y, so on a tool
// lying flat the band grows sideways and not down into the cloth (zero where the normal points
// straight up or down).
vec3 outline_direction(vec3 normal, mat4 modelview) {
	vec3 flat_normal = vec3(normal.x, 0.0, normal.z);
	if (dot(flat_normal, flat_normal) < 1e-6) {
		return vec3(0.0);
	}
	return normalize((modelview * vec4(normalize(flat_normal), 0.0)).xyz);
}

// The view-space vertex pushed out by the band's width, then lifted toward the camera.
vec3 outline_vertex(vec3 vertex, vec3 direction, float width) {
	vertex += direction * width * -vertex.z;
	return vertex + normalize(-vertex) * lift;
}
