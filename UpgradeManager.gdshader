shader_type canvas_item;

uniform vec4 background_color : source_color = vec4(0.08, 0.01, 0.02, 0.65); // dark crimson/brick
uniform vec4 border_color : source_color = vec4(1.0, 0.6, 0.2, 0.3); // soft orange border
uniform float border_size : hint_range(0.0, 0.2) = 0.025;

void fragment() {
    vec2 uv = UV;

    float fade_start = border_size * 0.0001;
    float fade_end = border_size;

    float edge_x = smoothstep(fade_start, fade_end, uv.x) * smoothstep(fade_start, fade_end, 1.0 - uv.x);
    float edge_y = smoothstep(fade_start, fade_end, uv.y) * smoothstep(fade_start, fade_end, 1.0 - uv.y);

    float edge = edge_x * edge_y;

    vec4 col = background_color + border_color * (1.0 - edge);
    COLOR = col;
}


//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
