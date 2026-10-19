shader_type spatial;
render_mode ambient_light_disabled;
// The tray (the model is Julia's): a silver tray whose floor is covered with a turquoise
// surgical cloth, or (tray_cloth off) dark cartoon wood; plastic-looking blood on top.
// The blood texture (made in the browser lab) covers exactly the floor, as a 2 x 2 atlas of four
// layouts with nothing near the edges, so no splat is cut off by a wall. Each tray picks a cell
// (blood_cell) and may mirror it (blood_flip). blood_amount sets where the soft field is cut, so
// blobs grow smoothly.

#include "res://assets/shaders/toon_common.gdshaderinc"

uniform sampler2D blood_tex : hint_default_black, filter_linear, repeat_disable;

group_uniforms cloth;
uniform bool tray_cloth = true;
uniform vec3 cloth_color : source_color = vec3(0.275, 0.753, 0.714);
uniform float cloth_wrinkles = 0.9;
uniform float cloth_wrinkle_scale = 14.0;
uniform float cloth_mottle = 0.125;
uniform float cloth_sheen = 0.3;
uniform float tray_silver = 0.9;
uniform float tray_rough = 0.35;

group_uniforms wood;
uniform vec3 wood_dark : source_color = vec3(0.169, 0.102, 0.063);
uniform vec3 wood_light : source_color = vec3(0.294, 0.184, 0.114);
uniform float wood_grain = 32.0;
uniform float wood_warp = 2.05;
uniform float wood_gloss = 0.9;

group_uniforms blood;
uniform vec3 blood_color : source_color = vec3(0.847, 0.071, 0.122);
uniform vec3 blood_edge : source_color = vec3(0.549, 0.027, 0.071);
uniform float blood_amount : hint_range(0.0, 1.0) = 0.62;
uniform float blood_gloss = 0.1;
uniform float blood_bump = 0.25;
uniform vec2 blood_cell = vec2(0.0);
uniform vec2 blood_flip = vec2(0.0);
// The tray mesh's bounds and its floor's bounds, in the mesh's space (set from code).
uniform vec3 tray_min = vec3(-0.15, 0.0, -0.21);
uniform vec3 tray_size = vec3(0.3, 0.03, 0.42);
uniform vec3 floor_min = vec3(-0.135, 0.0, -0.195);
uniform vec3 floor_size = vec3(0.27, 0.0, 0.39);
group_uniforms;

varying vec3 v_local;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

// vnoise at p, where fw is how much p changes across one pixel: it fades to its average where its
// cells get smaller than a few pixels (a small screen, or seen from far away), so the fine grain
// stays a grain instead of turning into pixel noise.
float vnoise_aa(vec2 p, vec2 fw) {
	return mix(vnoise(p), 0.5, smoothstep(0.2, 0.7, length(fw)));
}

float cloth_height(vec2 q) {
	return 0.7 * vnoise(q * vec2(1.0, 2.5)) + 0.3 * vnoise(q * 2.3 + 7.0);
}

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	// How far one pixel spans on the tray, taken here: derivatives are unreliable inside the
	// per-pixel branches below.
	vec2 px = fwidth(v_local.xz);
	vec3 n_w = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float on_floor = step(0.8, n_w.y) * (1.0 - step(tray_min.y + 0.012, v_local.y));
	vec3 base;
	v_ao = 1.0;
	v_edges = 0.0;
	float cloth = 0.0;
	if (tray_cloth) {
		base = vec3(0.78, 0.8, 0.83) * tray_silver;
		v_rough = tray_rough;
		v_metal = 1.0;
		v_gloss = 1.0;
		if (on_floor > 0.5) {
			// Turquoise surgical cloth with soft wrinkles.
			vec2 q = v_local.xz * cloth_wrinkle_scale;
			float h = cloth_height(q);
			float e = 0.05;
			vec2 g = vec2(cloth_height(q + vec2(e, 0.0)) - cloth_height(q - vec2(e, 0.0)),
					cloth_height(q + vec2(0.0, e)) - cloth_height(q - vec2(0.0, e))) / (2.0 * e);
			n_w = normalize(vec3(-g.x * cloth_wrinkles * 0.25, 1.0, -g.y * cloth_wrinkles * 0.25));
			float mottle = vnoise_aa(v_local.xz * 400.0, px * 400.0) * 0.6 + vnoise_aa(v_local.xz * 90.0, px * 90.0) * 0.4;
			base = cloth_color * (0.88 + 0.24 * h) * (1.0 - cloth_mottle * mottle);
			v_rough = 1.0;
			v_metal = 0.0;
			v_gloss = 0.0;
			cloth = 1.0;
		}
	} else {
		vec2 q = v_local.xz;
		float warp = (vnoise(q * vec2(6.0, 1.5)) + 0.3 * vnoise(q * vec2(22.0, 4.0))) * wood_warp;
		float ring_pos = q.x * wood_grain + warp;
		float rings = fract(ring_pos);
		float band = smoothstep(0.0, 0.12, rings) * (1.0 - smoothstep(0.5, 0.7, rings));
		// Rings closer than a few pixels fade to their average, like the noise.
		band = mix(band, 0.54, smoothstep(0.2, 0.7, fwidth(ring_pos)));
		float fine = vnoise_aa(q * vec2(160.0, 10.0), px * vec2(160.0, 10.0));
		base = mix(wood_dark, wood_light, clamp(band * 0.8 + fine * 0.25, 0.0, 1.0));
		v_rough = 0.55;
		v_metal = 0.0;
		v_gloss = wood_gloss;
	}

	vec2 fuv = (v_local.xz - floor_min.xz) / floor_size.xz;
	float on_blood_floor = step(0.0, fuv.x) * step(fuv.x, 1.0) * step(0.0, fuv.y) * step(fuv.y, 1.0);
	fuv = mix(fuv, 1.0 - fuv, blood_flip);
	vec2 buv = (clamp(fuv, 0.0, 1.0) + blood_cell) * 0.5;
	float f = texture(blood_tex, buv).r * on_blood_floor;
	float th = 1.0 - blood_amount;
	float aa = fwidth(f) * 1.5 + 0.002;
	v_blood = smoothstep(th - aa, th + aa, f) * on_floor * step(0.001, blood_amount);
	if (v_blood > 0.0) {
		float e = 1.0 / 1024.0;
		vec2 g = vec2(texture(blood_tex, buv + vec2(e, 0.0)).r - texture(blood_tex, buv - vec2(e, 0.0)).r,
				texture(blood_tex, buv + vec2(0.0, e)).r - texture(blood_tex, buv - vec2(0.0, e)).r);
		g *= mix(vec2(1.0), vec2(-1.0), blood_flip) * 0.5 * blood_bump * 25.0 * (1.0 - smoothstep(th, th + 0.3, f) * 0.7);
		vec3 bumped = normalize(vec3(-g.x, 1.0, -g.y));
		n_w = normalize(mix(n_w, bumped, v_blood));
		base = mix(base, mix(blood_edge, blood_color, smoothstep(th, th + 0.12, f)), v_blood);
		v_rough = mix(v_rough, 0.06, v_blood);
		v_gloss = mix(v_gloss, blood_gloss, v_blood);
	}

	NORMAL = normalize((VIEW_MATRIX * vec4(n_w, 0.0)).xyz);
	v_aa = normal_aa(n_w);
	ALBEDO = base;
	ROUGHNESS = v_rough;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	vec3 v_w = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	v_env = room_reflection(reflect(-v_w, n_w), base);
	v_glint = 0.0;
	// Soft light at grazing angles on the cloth (velvet-like).
	v_sheen = cloth * (1.0 - v_blood) * cloth_sheen;
}
