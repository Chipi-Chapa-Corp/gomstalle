shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

uniform vec4 arrow_color : source_color = vec4(0.23, 0.85, 0.33, 0.85);
uniform float edge_softness = 0.02;

void fragment() {
	vec2 position = UV * 2.0 - 1.0;
	float tip_y = 0.85;
	float base_y = -0.6;
	float half_base_width = 0.28;
	float base_radius = 0.3;
	float slope = half_base_width / (tip_y - base_y);
	float triangle_edge = slope * (tip_y - position.y) - abs(position.x);
	float triangle_shape = min(triangle_edge, min(position.y - base_y, tip_y - position.y));
	float circle_edge = base_radius - length(vec2(position.x, position.y - base_y));
	float shape = max(triangle_shape, circle_edge);
	float edge_width = fwidth(shape) + edge_softness;
	float alpha = smoothstep(0.0, edge_width, shape);
	ALBEDO = arrow_color.rgb;
	ALPHA = arrow_color.a * alpha;
}
