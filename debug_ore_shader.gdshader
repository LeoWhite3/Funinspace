shader_type spatial;

uniform vec4 ore_color : source_color;
uniform float sparkle_intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 base_color = ore_color.rgb;

	// Sparkle: based on view angle and UV noise (cheap pseudo sparkle)
	float sparkle = pow(abs(dot(NORMAL, VIEW)), 10.0) * sparkle_intensity;

	// Blend base color with white based on sparkle
	ALBEDO = mix(base_color, vec3(1.0), sparkle);
	METALLIC = 0.3 + sparkle * 0.7;
	ROUGHNESS = 1.0 - sparkle;
}
