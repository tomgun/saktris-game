shader_type canvas_item;
// CRT scanlines effect for retrofuturistic theme

uniform float line_density : hint_range(100.0, 500.0) = 200.0;
uniform float line_opacity : hint_range(0.0, 0.5) = 0.15;
uniform float flicker_speed : hint_range(0.0, 10.0) = 2.0;
uniform float flicker_amount : hint_range(0.0, 0.1) = 0.02;

void fragment() {
	// Base scanline pattern
	float scanline = sin(UV.y * line_density * 3.14159) * 0.5 + 0.5;

	// Subtle flicker effect
	float flicker = 1.0 - (sin(TIME * flicker_speed) * 0.5 + 0.5) * flicker_amount;

	// Apply scanline darkening
	float darkness = scanline * line_opacity * flicker;

	// Output semi-transparent black with scanline pattern
	COLOR = vec4(0.0, 0.0, 0.0, darkness);
}
