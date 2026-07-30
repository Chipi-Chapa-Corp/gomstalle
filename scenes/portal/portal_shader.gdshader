shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_prepass_alpha;

uniform vec4 void_color : source_color = vec4(0.006, 0.002, 0.014, 1.0);
uniform vec4 color_a : source_color = vec4(0.11, 0.015, 0.28, 1.0);
uniform vec4 color_b : source_color = vec4(0.52, 0.06, 0.72, 1.0);
uniform vec4 color_c : source_color = vec4(0.78, 0.12, 0.28, 1.0);
uniform float emission_strength = 1.35;
uniform float swirl_speed = 0.42;
uniform float swirl_strength = 1.8;
uniform float noise_scale = 3.8;
uniform float reveal_progress : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 position) {
	return fract(sin(dot(position, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 position) {
	vec2 base = floor(position);
	vec2 fraction = fract(position);
	float a = hash(base);
	float b = hash(base + vec2(1.0, 0.0));
	float c = hash(base + vec2(0.0, 1.0));
	float d = hash(base + vec2(1.0, 1.0));
	vec2 smooth_factor = fraction * fraction * (3.0 - 2.0 * fraction);
	return mix(mix(a, b, smooth_factor.x), mix(c, d, smooth_factor.x), smooth_factor.y);
}

float layered_noise(vec2 position) {
	float value = 0.0;
	float amplitude = 0.55;
	for (int octave = 0; octave < 3; octave++) {
		value += noise(position) * amplitude;
		position = position * 2.07 + vec2(3.1, 1.7);
		amplitude *= 0.45;
	}
	return value;
}

float rounded_box_distance(vec2 point, vec2 bounds, float corner_radius) {
	vec2 offset = abs(point) - bounds + corner_radius;
	return min(max(offset.x, offset.y), 0.0) + length(max(offset, vec2(0.0))) - corner_radius;
}

mat2 rotation_matrix(float angle) {
	float sine = sin(angle);
	float cosine = cos(angle);
	return mat2(vec2(cosine, -sine), vec2(sine, cosine));
}

void fragment() {
	vec2 portal_uv = UV * 2.0 - 1.0;
	float square_radius = max(abs(portal_uv.x), abs(portal_uv.y));
	float shape_distance = rounded_box_distance(portal_uv, vec2(0.82), 0.09);
	float shape_mask = 1.0 - smoothstep(-0.015, 0.015, shape_distance);
	float reveal_eased = reveal_progress * reveal_progress * (3.0 - 2.0 * reveal_progress);
	float reveal_radius = reveal_eased * 1.18;
	float reveal_mask = 1.0 - smoothstep(reveal_radius - 0.1, reveal_radius, square_radius);

	float rotation = TIME * swirl_speed + (1.0 - square_radius) * swirl_strength;
	vec2 flow_uv = rotation_matrix(rotation) * portal_uv * noise_scale;
	float flow = layered_noise(flow_uv + vec2(TIME * 0.14, -TIME * 0.1));
	float radial_distance = max(length(portal_uv), 0.025);
	float angle = atan(portal_uv.y, portal_uv.x);
	float filament_wave = sin(angle * 4.0 - log(radial_distance) * 6.2 - TIME * 1.15 + flow * 3.4) * 0.5 + 0.5;
	float filament = smoothstep(0.48, 0.92, filament_wave) * (0.42 + flow * 0.58);
	float tunnel_phase = fract(-log(radial_distance) * 1.15 - TIME * 0.16);
	float depth_ring = pow(1.0 - abs(tunnel_phase * 2.0 - 1.0), 3.0);
	depth_ring *= smoothstep(0.06, 0.26, radial_distance) * (1.0 - smoothstep(0.56, 0.82, radial_distance));
	float inner_rim = 1.0 - smoothstep(0.0, 0.035, abs(square_radius - 0.73));
	float outer_rim = 1.0 - smoothstep(0.0, 0.035, abs(shape_distance));
	float center_fade = smoothstep(0.04, 0.5, square_radius);
	float pulse = sin(TIME * 1.7 + flow * 2.0) * 0.5 + 0.5;

	vec3 portal_color = mix(void_color.rgb, color_a.rgb, flow * 0.16 * center_fade);
	portal_color += mix(color_a.rgb, color_b.rgb, flow) * filament * (0.08 + center_fade * 0.34);
	portal_color += color_c.rgb * depth_ring * 0.09;
	portal_color += mix(color_b.rgb, color_c.rgb, 0.12 + flow * 0.08) * inner_rim * 0.42;
	portal_color += color_b.rgb * outer_rim * 0.2;
	portal_color *= 0.88 + pulse * 0.12;

	float energy = 0.32 + filament * 0.42 + depth_ring * 0.16 + inner_rim * 0.62 + outer_rim * 0.28;
	ALBEDO = portal_color;
	EMISSION = portal_color * emission_strength * energy;
	ALPHA = shape_mask * reveal_mask;
}
