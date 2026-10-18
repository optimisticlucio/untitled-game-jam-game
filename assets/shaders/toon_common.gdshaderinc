// Shared light model for the lab's tool and tray shaders (mirrors Julia's browser shader lab).
// The including shader's fragment() must fill the varyings below.
// Use render_mode ambient_light_disabled: the room light is added here, so the shade colour tints it.
// Brightness matches the browser lab: light terms are LIGHT_COLOR (which already includes PI) times
// light_scale, measured against the page on 2026-10-18.

group_uniforms light;
uniform float light_scale : hint_range(0.0, 1.0) = 0.3;
uniform float dark_level : hint_range(0.0, 1.0) = 0.0;
uniform vec3 shadow_tint : source_color = vec3(0.514, 0.584, 0.627);
uniform float band_softness : hint_range(0.001, 0.5) = 0.429;
uniform float metal_diffuse : hint_range(0.0, 1.0) = 0.18;
uniform vec3 ambient_color : source_color = vec3(0.851, 0.902, 0.949);
uniform float ambient_energy : hint_range(0.0, 2.0) = 0.4;
uniform float spec_strength : hint_range(0.0, 6.0) = 0.65;
uniform float edge_strength : hint_range(0.0, 4.0) = 0.95;
uniform float edge_width : hint_range(0.0, 1.0) = 0.34;

group_uniforms room;
uniform vec3 room_floor : source_color = vec3(0.102, 0.271, 0.286);
uniform vec3 room_drape : source_color = vec3(0.220, 0.522, 0.541);
uniform vec3 room_ceiling : source_color = vec3(0.749, 0.800, 0.839);
uniform float lamp_strength : hint_range(0.0, 4.0) = 0.8;
uniform float env_strength : hint_range(0.0, 2.0) = 0.7;
uniform float env_in_shadow : hint_range(0.0, 1.0) = 0.2;
uniform float mirror_dark : hint_range(0.0, 1.0) = 0.67;

group_uniforms rim;
uniform vec3 rim_color : source_color = vec3(0.549, 0.851, 0.851);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.66;
uniform float rim_width : hint_range(0.0, 1.0) = 0.35;
group_uniforms;

varying vec3 v_env;     // room reflection, before shadow
varying float v_glint;  // small lamp glint, before shadow
varying float v_metal;
varying float v_rough;
varying float v_ao;
varying float v_gloss;  // highlight multiplier
varying float v_blood;  // plastic blood mask (tray only)
varying float v_edges;  // 1 = draw the white edge line
varying float v_sheen;  // soft grazing light on cloth

vec2 rot2(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

vec3 room_reflection(vec3 r, vec3 base) {
	float s = mix(0.03, 0.4, v_rough);
	vec3 env = mix(room_floor, room_drape, smoothstep(-0.25 - s, -0.25 + s, r.y));
	env = mix(env, room_ceiling * mix(mirror_dark, 1.0, v_rough), smoothstep(0.35 - s, 0.35 + s, r.y));
	env += vec3(lamp_strength) * smoothstep(0.95 - s, 0.95 + s, r.y) * (1.0 - 0.7 * v_rough);
	return env * mix(vec3(1.0), base, v_metal) * v_metal * v_ao * env_strength;
}

float rim_light(vec3 normal, vec3 view) {
	float fres = 1.0 - clamp(dot(normal, view), 0.0, 1.0);
	return smoothstep(1.0 - rim_width, 1.0, fres) * rim_strength * v_edges;
}

void light() {
	float lit = smoothstep(-band_softness, band_softness, dot(NORMAL, LIGHT)) * ATTENUATION;
	vec3 shade = mix(shadow_tint, vec3(1.0), lit);
	vec3 diffuse = mix(vec3(dark_level), vec3(1.0), lit) * shade * mix(1.0, metal_diffuse * mix(0.4, 1.0, v_rough), v_metal);
	DIFFUSE_LIGHT += LIGHT_COLOR * diffuse * light_scale;

	vec3 h = normalize(LIGHT + VIEW);
	float ndh = clamp(dot(NORMAL, h), 0.0, 1.0);
	float size = mix(0.993, 0.955, v_rough);
	float edge = mix(0.002, 0.02, v_rough);
	float spec = smoothstep(size - edge, size + edge, ndh) * spec_strength * ATTENUATION * mix(0.35, 1.0, v_metal) * v_gloss;
	spec += v_blood * ATTENUATION * v_gloss * (0.25 * smoothstep(0.9, 0.97, ndh) + smoothstep(0.985, 0.99, ndh));
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	spec += smoothstep(1.0 - edge_width, 1.0, fres) * clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * edge_strength * v_edges;
	spec += v_sheen * fres * fres * clamp(dot(NORMAL, LIGHT) + 0.3, 0.0, 1.0) * ATTENUATION;
	SPECULAR_LIGHT += LIGHT_COLOR * spec * mix(vec3(1.0), ALBEDO, v_metal * 0.6) * light_scale;

	if (LIGHT_IS_DIRECTIONAL) {
		// Room light and room reflection are added once, with the sun's shadow and shade colour.
		DIFFUSE_LIGHT += ambient_color * ambient_energy * v_ao * shade;
		SPECULAR_LIGHT += (v_env * mix(env_in_shadow, 1.0, ATTENUATION) * shade + vec3(v_glint * ATTENUATION)) * PI * light_scale;
	}
}
