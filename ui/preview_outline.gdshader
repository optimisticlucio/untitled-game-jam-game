shader_type canvas_item;
// A dark outline around whatever a SubViewport shows; its transparent background stays clear.
// Set it as the material of a SubViewportContainer (the ToolPreview in the request bubble).
// The width is a share of the preview's size, not pixels, so the outline keeps its look at any
// resolution; the preview frames each tool to fill it, so even a thin scalpel gets a clear one.

uniform vec4 outline_color : source_color = vec4(0.05, 0.05, 0.06, 1.0);
// Share of the preview's shorter side (0.033 = 5 px on the 150 px bubble).
uniform float width = 0.033;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float side_px = 1.0 / max(TEXTURE_PIXEL_SIZE.x, TEXTURE_PIXEL_SIZE.y);
	float a = 0.0;
	for (int i = 0; i < 16; i++) {
		float angle = float(i) * TAU / 16.0;
		a = max(a, texture(TEXTURE, UV + vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE * width * side_px).a);
	}
	COLOR = vec4(mix(outline_color.rgb, c.rgb, c.a), max(c.a, a * outline_color.a));
}
