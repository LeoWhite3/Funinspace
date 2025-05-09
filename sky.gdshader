shader_type sky;

uniform float star_density = 200.0; // Higher = more stars
uniform float star_threshold = 0.997;
uniform float star_brightness = 1.0;

// Hash return 0-1 if the hash is above the threshold it will become a star
float hash(ivec3 cell) {
    int n = cell.x * 73856093 ^ cell.y * 19349663 ^ cell.z * 83492791;
    return fract(sin(float(n)) * 43758.5453123);
}

vec3 starfield(vec3 dir) {
    // Convert direction to a fixed grid cell in 3D
    vec3 sample_dir = normalize(dir);
    ivec3 cell = ivec3(floor(sample_dir * star_density));
    float star = hash(cell);
    float visible = smoothstep(star_threshold, star_threshold + 0.002, star);
    return vec3(visible * star_brightness);
}

void sky() {
    vec3 dir = EYEDIR;
    COLOR = starfield(dir); // perfectly static stars
}
