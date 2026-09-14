shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform float clock = 0.0;
uniform float opening = 1.0;

void fragment() {
	float filament = pow(0.5 + 0.5 * sin(UV.x * 94.24778 + UV.y * 10.0 - clock * 1.6), 18.0);
	float ribbons = pow(0.5 + 0.5 * sin(UV.x * 25.13274 - UV.y * 8.0 + clock), 9.0);
	float fade = pow(1.0 - UV.y, 2.6) * smoothstep(0.0, 0.12, UV.y);
	vec3 color = mix(vec3(0.03, 0.35, 0.32), vec3(0.42, 0.92, 0.71), filament);
	ALBEDO = color;
	EMISSION = color * 1.6;
	ALPHA = (filament * 0.45 + ribbons * 0.08) * fade * opening;
}
