shader_type spatial;
render_mode unshaded;

uniform vec3 panel_color = vec3(0.1, 0.1, 0.1);
uniform vec3 line_color = vec3(0.0, 0.0, 0.0);
uniform float line_thickness : hint_range(0.0, 0.5) = 0.055;
uniform float panel_scale : hint_range(0.1, 10.0) = 3;

void fragment() {
    vec2 grid_uv = UV * panel_scale;
    vec2 frac_uv = fract(grid_uv);

    float line_x = step(frac_uv.x, line_thickness) + step(1.0 - frac_uv.x, line_thickness);
    float line_y = step(frac_uv.y, line_thickness) + step(1.0 - frac_uv.y, line_thickness);
    float is_line = clamp(line_x + line_y, 0.0, 1.0);

    ALBEDO = mix(panel_color, line_color, is_line);
}

