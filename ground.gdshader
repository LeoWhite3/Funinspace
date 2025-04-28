shader_type spatial; //tells godot its a 3d surface material
render_mode cull_back;// hides the back faces of the geometry

uniform sampler2D surface_texture;
uniform sampler2D wall_texture;

uniform vec3 surface_tint : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 wall_tint : source_color = vec3(0.7, 0.7, 0.7);

uniform float blend_height = 1.0; // y cord where blending between surface and wall surface occurs
uniform float blend_range = 2.0;// how soft or hard the transition is from textures 
uniform float texture_scale = 0.5; // how tiled the textures appeasr smaller == more tilling

varying vec3 world_position; // world space position of the pixel
varying vec3 world_normal; // normal vector in the world space for lighting and blending

void vertex() {
	//converts the vertex position from local object to world space, so we know the terrains actual location in the game world
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	//transorms the surface normal into world space used for triplanar texturte blending
    world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

// projects a 2d texture onto three exis based on the surfaces normal direction
vec3 triplanar_texture(sampler2D tex, vec3 pos, vec3 norm) {
    norm = abs(normalize(norm));
	//computes the uvs scaled off of the texture sscale
    vec2 uv_x = pos.zy * texture_scale;
    vec2 uv_y = pos.xz * texture_scale;
    vec2 uv_z = pos.xy * texture_scale;
	
	
    vec3 x = texture(tex, uv_x).rgb;
    vec3 y = texture(tex, uv_y).rgb;
    vec3 z = texture(tex, uv_z).rgb;
	
	//returns the blend between each axis projectionn based on how alligned the surface is wityh each axis
    return (x * norm.x + y * norm.y + z * norm.z) / (norm.x + norm.y + norm.z);
}

void fragment() {
	//calculate how far or below the pixel is from blend height
    float height_diff = world_position.y - blend_height;
	//creates the smooth transition between textures
    float blend = smoothstep(-blend_range, blend_range, height_diff);
	
	//tripingualr mapping and the tints for the texture
    vec3 surface_color = triplanar_texture(surface_texture, world_position, world_normal) * surface_tint;
    vec3 wall_color = triplanar_texture(wall_texture, world_position, world_normal) * wall_tint;
	
	//ALBEDO = vec3(blend);
   	//ALBEDO = mix(wall_color, surface_color, blend);
	ALBEDO = mix(surface_color, wall_color, blend);
}





//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
