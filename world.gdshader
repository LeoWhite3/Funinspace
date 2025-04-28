shader_type spatial;//  means the shader  is used for 3d objects.

uniform vec3 sand_color : source_color = vec3(0.75, 0.35, 0.25); //The tone/color of the sand
uniform float noise_scale = 700.0;//this is the size of the  grain of sand
uniform float grain_intensity = 0.2; // adds specs to the sand created

// just for producing values for grainy affect, just returns some random value to apply to each grain
float rand(vec2 co){
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233)))*43758.5453);//sine scrambles the result because its not linear, the dot product returns a 1d float val,fract only keeps the decimal
}

//Fragment runs for every pixle on the 3d surface
void fragment(){
	vec2  uv = UV *  noise_scale;// gets the current pixels uv and scales it based of of noise_scale
	float grain = rand(floor(uv)) * grain_intensity; //rand is used  to help make the grain of the sand, use floor to get 1 grain per tile if we didnt iot would do it for each sub pixel.

	vec3 final_color = sand_color + vec3(grain);//adds the grain noise to the base sand color to simulate a texxtured surface, adding the grain vector lightes or darkens the color based on the grain values.
	ALBEDO = final_color; // final output of the sand
}