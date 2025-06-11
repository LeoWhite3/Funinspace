shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.05, 0.05, 0.1, 0.5);
uniform vec4 edge_glow_color : source_color = vec4(0.2, 0.6, 1.0, 0.3);
uniform float edge_thickness : hint_range(0.0, 0.5) = 0.05;
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
