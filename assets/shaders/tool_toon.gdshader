shader_type spatial;
render_mode ambient_light_disabled;
// Stylised tool metal (Surgeon Simulator 2 look), ported from Julia's browser shader lab.
// Uses the tool's own textures: albedo, and ORM (R = AO, G = roughness, B = metallic), plus one
// shared wear texture (R = scratches, G = stains, B = soft hue patches).
// Per-tool randomness (tint, wear offset/angle, scratch and stain amounts) is set from code each
// time a tool spawns, so a tool can't be recognised by a mark.

#include "res://assets/shaders/toon_common.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap;
uniform sampler2D wear_tex : hint_default_black, filter_linear_mipmap, repeat_enable;

group_uniforms per_tool;
// Keep the tint within a few percent: lookalike pairs must not differ by colour.
uniform vec3 tint : source_color = vec3(1.0);
uniform vec2 wear_offset = vec2(0.0);
uniform float wear_angle = 0.0;
uniform vec2 patch_offset = vec2(0.0);
uniform float scratch_amount = 0.0;
uniform float stain_amount = 0.0;

group_uniforms wear;
uniform float scratch_scale = 22.0;
uniform float stain_scale = 30.5;
uniform vec3 stain_color : source_color = vec3(0.635, 0.588, 0.525);
uniform float patch_strength = 0.24;
uniform float patch_scale = 10.5;
uniform vec3 patch_a : source_color = vec3(1.000, 0.824, 0.780);
uniform vec3 patch_b : source_color = vec3(0.722, 0.800, 1.000);

group_uniforms glint;
// A small lamp reflection that slides over a tool as it moves or tilts (world direction to the lamp).
uniform vec3 glint_dir = vec3(0.12, 0.93, -0.35);
uniform float glint_strength : hint_range(0.0, 10.0) = 2.2;
uniform float glint_cos : hint_range(0.99, 1.0) = 0.999286;
group_uniforms;

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	vec3 orm = texture(orm_tex, UV).rgb;
	v_rough = orm.g;
	v_metal = orm.b;
	v_ao = orm.r;

	// Wear, projected from above in the tool's own space (tools lie flat), so it ignores UV seams.
	vec2 p = rot2(v_local.xz, wear_angle);
	float scratch = clamp(texture(wear_tex, p * scratch_scale + wear_offset).r * scratch_amount, 0.0, 1.0);
	float stain = clamp(texture(wear_tex, p * stain_scale + wear_offset * 1.7).g * stain_amount, 0.0, 1.0);
	float patchv = texture(wear_tex, p * patch_scale / 8.0 + patch_offset).b;
	base *= mix(vec3(1.0), mix(patch_a, patch_b, smoothstep(0.3, 0.7, patchv)), patch_strength);
	base *= tint;
	base = mix(base, base * stain_color, stain);
	v_rough = clamp(v_rough + stain * 0.3 + scratch * 0.25, 0.0, 1.0);
	v_ao *= 1.0 - 0.5 * scratch * v_metal;
	v_gloss = 1.0 + scratch * 0.6;
	v_blood = 0.0;
	v_edges = 1.0;
	v_sheen = 0.0;

	ALBEDO = base;
	ROUGHNESS = v_rough;
	// The shader draws all highlights itself; the engine adds no reflections.
	METALLIC = 0.0;
	SPECULAR = 0.0;

	vec3 n_w = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v_w = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 r = reflect(-v_w, n_w);
	v_env = room_reflection(r, base);
	float gc = mix(glint_cos, glint_cos - 0.002, v_rough);
	v_glint = smoothstep(gc, mix(gc, 1.0, 0.5), dot(r, normalize(glint_dir))) * glint_strength * pow(1.0 - v_rough, 3.0) * v_metal;

	EMISSION = rim_color * rim_light(NORMAL, VIEW);
}
