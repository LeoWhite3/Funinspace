shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 base_color : source_color = vec4(0.05, 0.05, 0.1, 1.0); // Slightly cool black (blueish tint)

void fragment() {
	ALBEDO = base_color.rgb;
}




