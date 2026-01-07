shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_prepass_alpha;

uniform vec4 color_a : source_color = vec4(0.25, 0.05, 0.7, 1.0);
uniform vec4 color_b : source_color = vec4(0.2, 0.7, 1.0, 1.0);
uniform vec4 color_c : source_color = vec4(0.7, 0.2, 1.0, 1.0);
uniform float emission_strength = 2.6;
uniform float swirl_speed = 0.7;
uniform float swirl_strength = 2.6;
uniform float radius = 0.48;
uniform float edge_softness = 0.08;
uniform float noise_scale = 6.5;
uniform float pulse_strength = 0.35;

float hash2(vec2 position) {
	return fract(sin(dot(position, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise2(vec2 position) {
	vec2 base = floor(position);
	vec2 fraction = fract(position);
	float a = hash2(base);
	float b = hash2(base + vec2(1.0, 0.0));
	float c = hash2(base + vec2(0.0, 1.0));
	float d = hash2(base + vec2(1.0, 1.0));
	vec2 smooth_factor = fraction * fraction * (3.0 - 2.0 * fraction);
	float mix_ab = mix(a, b, smooth_factor.x);
	float mix_cd = mix(c, d, smooth_factor.x);
	return mix(mix_ab, mix_cd, smooth_factor.y);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	vec2 uv_swirl = uv * 1.41421356;
	float distance = length(uv_swirl);
	float angle = atan(uv_swirl.y, uv_swirl.x);
	float swirl = angle * 3.0 + distance * (swirl_strength * 6.0) - TIME * swirl_speed;
	vec2 flow_uv = vec2(cos(swirl), sin(swirl)) * distance + uv_swirl;
	float flow = noise2(flow_uv * noise_scale + TIME * 0.2);
	float wave = sin(swirl + flow * 3.0) * 0.5 + 0.5;
	float pulse = sin(TIME * 2.2 + length(uv) * 10.0) * 0.5 + 0.5;
	float square_distance = max(abs(uv.x), abs(uv.y));
	float edge = smoothstep(radius + edge_softness, radius - edge_softness, square_distance);
	float center_fade = smoothstep(0.0, radius * 0.08, length(uv));
	float mask = edge * center_fade;
	vec3 base_color = mix(color_a.rgb, color_b.rgb, wave);
	base_color = mix(base_color, color_c.rgb, flow * 0.7);
	base_color *= 0.7 + pulse_strength * pulse;
	float alpha = mask * (0.8 + 0.2 * wave);
	ALBEDO = base_color;
	EMISSION = base_color * emission_strength * mask;
	ALPHA = alpha;
}
