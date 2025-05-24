shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 screen_color : source_color = vec4(0.0, 1.0, 1.0, 1.0); // Cyan glow
uniform float scanline_intensity = 0.05;
uniform float scanline_density = 300.0;
uniform float pulse_speed = 2.0;
uniform float pulse_strength = 0.1;

void fragment() {
	vec2 uv = UV;

	// Moving horizontal scanlines
	float scanline = sin((uv.y + TIME * 0.5) * scanline_density) * scanline_intensity;

	// Breathing pulse overlay
	float pulse = sin(TIME * pulse_speed) * pulse_strength;

	// Combine effects
	vec3 color = screen_color.rgb + scanline + pulse;
	color = clamp(color, 0.0, 1.0);

	ALBEDO = color;
}


//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
