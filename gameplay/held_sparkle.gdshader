shader_type spatial;
// One star of the held tool's sparkles (held_sparkles.tscn): a soft dot with four thin rays,
// facing the camera, in the particle's pastel colour. It grows, then shrinks away over its life.
// Added on top (light, not paint).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform;

// Size as a fraction of the distance to the camera, like the outline's width, so stars look the
// same on every tool.
uniform float size = 0.03;
uniform float brightness = 1.3;
// How white the centre is (0 = all the particle's colour).
uniform float white_core = 0.4;
// Length of the four rays, as a share of the star.
uniform float ray_length = 1.0;

void vertex() {
	// The particle's centre in view space; the quad is laid out around it, facing the camera.
	vec3 center = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// x = its random angle, y = how far through its life it is (0 to 1).
	float angle = INSTANCE_CUSTOM.x;
	float grow = sin(clamp(INSTANCE_CUSTOM.y, 0.0, 1.0) * PI);
	vec2 corner = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * VERTEX.xy;
	VERTEX = center + vec3(corner * size * -center.z * grow, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float core = exp(-dot(p, p) * 30.0);
	float halo = exp(-dot(p, p) * 6.0) * 0.25;
	float taper = max(ray_length, 0.001);
	float rays = max(0.0, 1.0 - abs(p.y) * 14.0) * max(0.0, 1.0 - abs(p.x) / taper)
			+ max(0.0, 1.0 - abs(p.x) * 14.0) * max(0.0, 1.0 - abs(p.y) / taper);
	vec3 tint = mix(COLOR.rgb, vec3(1.0), clamp(core * white_core * 2.0, 0.0, 1.0));
	ALBEDO = tint * (core + rays * 0.9 + halo) * brightness * COLOR.a;
}
