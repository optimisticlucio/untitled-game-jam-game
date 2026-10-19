shader_type canvas_item;
// A soft diagonal light that sweeps once across a button (ButtonFx animates sweep from 0 to 1 when
// the pointer enters it). It brightens only the button's own light pixels, so its rounded corners,
// outline and text stay clean. Positions are a share of the button's size, so it looks the same on any button.

// Where the band is: 0 = at the left edge, 1 = past the right edge; outside 0..1 = no glare.
uniform float sweep = -1.0;
// The button's size in pixels (set when the glare starts).
uniform vec2 size = vec2(600.0, 130.0);
// The band's width, as a share of the button's width, how much it leans, and how bright it is.
uniform float width = 0.16;
uniform float slant = 0.6;
uniform float strength = 0.28;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 p = local / max(size, vec2(1.0));
	// Leaning band: further right at the top than at the bottom.
	float x = p.x + (0.5 - p.y) * slant * size.y / max(size.x, 1.0);
	float centre = mix(-width, 1.0 + width, sweep);
	float band = 1.0 - smoothstep(0.0, width, abs(x - centre));
	band *= step(0.0, sweep) * step(sweep, 1.0);
	// Only on the button's light parts: its black outline and dark text stay as they are.
	float light = smoothstep(0.15, 0.4, max(COLOR.r, max(COLOR.g, COLOR.b)));
	COLOR.rgb += band * strength * light * COLOR.a;
}
