shader_type canvas_item;
// Lightweight neon tint effect for chess pieces - WebGL compatible

uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Simple color tint - no expensive sampling
	vec3 tinted = tex.rgb + glow_color.rgb * glow_intensity;

	COLOR = vec4(tinted, tex.a);
}
