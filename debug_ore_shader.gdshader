shader_type spatial;
render_mode cull_back;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Basic hash function for randomness
float rand(vec3 co) {
	return fract(sin(dot(co, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

void fragment() {
	vec3 color = vec3(0.4, 0.25, 0.1); // default dirt

	float r = rand(world_position * 0.25);

	// Simulated ore logic
	if (world_position.y < -20.0 && r < 0.03) {
		color = vec3(0.2, 0.6, 1.0); // Diamond
	} else if (world_position.y < 0.0 && r < 0.08) {
		color = vec3(1.0, 0.85, 0.2); // Gold
	} else if (world_position.y < 10.0 && r < 0.15) {
		color = vec3(0.8); // Silver
	} else if (world_position.y < 20.0 && r < 0.3) {
		color = vec3(0.9, 0.4, 0.1); // Copper
	}

	ALBEDO = color;
}
