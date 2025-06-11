shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.1, 0.02, 0.05, 0.5); // deep reddish-purple
uniform vec4 edge_glow_color : source_color = vec4(1.0, 0.5, 0.0, 0.25); // glowing orange
uniform float edge_thickness : hint_range(0.0, 0.5) = 0.04;
uniform bool use_scanlines = false;

void fragment() {
    vec2 uv = UV;

    float edge_mask = smoothstep(0.0, edge_thickness, uv.x)
                    * smoothstep(0.0, edge_thickness, uv.y)
                    * smoothstep(0.0, edge_thickness, 1.0 - uv.x)
                    * smoothstep(0.0, edge_thickness, 1.0 - uv.y);

    vec4 col = base_color;

    if (use_scanlines) {
        float scanline = sin(UV.y * 300.0) * 0.03;
        col.rgb += scanline;
    }

    col.rgb += edge_glow_color.rgb * (1.0 - edge_mask);
    COLOR = col;
}


//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
