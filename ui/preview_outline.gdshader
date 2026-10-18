shader_type canvas_item;
// A dark outline around whatever a SubViewport shows; its transparent background stays clear.
// Set it as the material of a SubViewportContainer (the ToolPreview in the request bubble).
// Works in screen pixels, so even a thin scalpel gets a clear outline.

uniform vec4 outline_color : source_color = vec4(0.05, 0.05, 0.06, 1.0);
uniform float width_px = 5.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = 0.0;
	for (int i = 0; i < 16; i++) {
		float angle = float(i) * TAU / 16.0;
		a = max(a, texture(TEXTURE, UV + vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE * width_px).a);
	}
	COLOR = vec4(mix(outline_color.rgb, c.rgb, c.a), max(c.a, a * outline_color.a));
}
