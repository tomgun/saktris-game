shader_type canvas_item;
// Strong 3D effect for chess pieces - bevel/emboss style

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	if (tex_color.a < 0.01) {
		COLOR = tex_color;
		return;
	}

	// Sample neighboring pixels for edge detection
	vec2 pixel_size = vec2(1.0) / vec2(textureSize(TEXTURE, 0));

	float top_left = texture(TEXTURE, UV + vec2(-pixel_size.x, -pixel_size.y) * 2.0).a;
	float bottom_right = texture(TEXTURE, UV + vec2(pixel_size.x, pixel_size.y) * 2.0).a;

	// Bevel effect: light edge top-left, dark edge bottom-right
	float bevel = (top_left - bottom_right) * 0.6;

	// Position-based lighting
	vec2 from_center = UV - vec2(0.5, 0.5);
	vec2 dir = normalize(from_center + vec2(0.001, 0.001));
	vec2 light_dir = normalize(vec2(-1.0, -1.0));
	float light_factor = (dot(dir, light_dir) + 1.0) * 0.5;

	// Strong directional shading
	float shading = mix(-0.35, 0.35, light_factor);

	// Bright specular highlight
	float spec_dist = distance(UV, vec2(0.28, 0.28));
	float specular = smoothstep(0.2, 0.0, spec_dist) * 0.5;

	// Secondary softer highlight
	float spec2_dist = distance(UV, vec2(0.35, 0.35));
	float specular2 = smoothstep(0.25, 0.05, spec2_dist) * 0.25;

	// Edge rim darkening
	float rim = smoothstep(0.25, 0.48, length(from_center)) * 0.3;

	// Inner glow/ambient
	float inner = (1.0 - length(from_center) * 1.5) * 0.1;

	// Combine all effects
	vec3 result = tex_color.rgb;
	result += shading;
	result += bevel;
	result += specular + specular2;
	result += inner;
	result -= rim;

	COLOR = vec4(clamp(result, 0.0, 1.0), tex_color.a);
}
