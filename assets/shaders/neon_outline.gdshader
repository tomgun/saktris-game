shader_type canvas_item;
// Neon glow outline effect for chess pieces in retrofuturistic theme

uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float glow_width : hint_range(1.0, 10.0) = 3.0;
uniform float glow_intensity : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 pixel_size = vec2(1.0) / vec2(textureSize(TEXTURE, 0));

	// Sample neighboring pixels for edge detection
	float alpha_sum = 0.0;
	float samples = 0.0;

	// Sample in a circle pattern for smooth glow
	for (float angle = 0.0; angle < 6.28; angle += 0.5) {
		for (float dist = 1.0; dist <= glow_width; dist += 1.0) {
			vec2 offset = vec2(cos(angle), sin(angle)) * dist * pixel_size;
			alpha_sum += texture(TEXTURE, UV + offset).a;
			samples += 1.0;
		}
	}

	// Calculate glow based on nearby alpha
	float nearby_alpha = alpha_sum / samples;
	float glow = nearby_alpha * glow_intensity * (1.0 - tex.a);

	// Combine original texture with glow
	vec3 final_color = tex.rgb;
	float final_alpha = tex.a;

	// Add glow for transparent pixels near edges
	if (glow > 0.01 && tex.a < 0.5) {
		float falloff = 1.0 - (nearby_alpha * 0.5);
		final_color = glow_color.rgb;
		final_alpha = glow * falloff * glow_color.a;
	} else if (tex.a > 0.5) {
		// Brighten the piece slightly for neon effect
		final_color = tex.rgb + glow_color.rgb * 0.1 * glow_intensity;
		final_alpha = tex.a;
	}

	COLOR = vec4(final_color, final_alpha);
}
