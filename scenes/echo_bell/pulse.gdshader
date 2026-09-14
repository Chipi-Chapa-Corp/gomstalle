shader_type spatial;
render_mode unshaded, cull_disabled, blend_add;

uniform vec4 pulse_color : source_color = vec4(1.0, 0.47, 0.12, 1.0);
uniform float opacity = 0.0;

void fragment() {
	ALBEDO = pulse_color.rgb;
	EMISSION = pulse_color.rgb * 2.5;
	ALPHA = opacity;
}
