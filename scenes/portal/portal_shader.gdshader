shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float clock = 0.0;
uniform float opening : hint_range(0.0, 1.0) = 1.0;
uniform vec4 deep_color : source_color = vec4(0.007, 0.021, 0.05, 1.0);
uniform vec4 soul_color : source_color = vec4(0.12, 0.87, 0.7, 1.0);
uniform vec4 rim_color : source_color = vec4(0.84, 0.72, 0.35, 1.0);

float hash(vec2 position) {
	return fract(sin(dot(position, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 position) {
	vec2 cell = floor(position);
	vec2 fraction = fract(position);
	vec2 blend = fraction * fraction * (3.0 - 2.0 * fraction);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), blend.x), blend.y);
}

float turbulence(vec2 position) {
	return noise(position) * 0.55 + noise(position * 2.07 + 13.1) * 0.28 + noise(position * 4.13 - 7.6) * 0.17;
}

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float radius = length(centered);
	if (radius > 0.955) {
		discard;
	}
	float aperture = smoothstep(0.0, 1.0, opening);
	float boundary = 0.91 * aperture;
	float angle = atan(centered.y, centered.x);
	float depth = -log(max(radius, 0.035));
	float swirl = angle + depth * 0.7 - clock * 0.24;
	vec2 tunnel = vec2(cos(swirl), sin(swirl)) * (3.0 + depth * 2.4) + vec2(clock * 0.12);
	float cloud = turbulence(tunnel);
	float ribbon = pow(0.5 + 0.5 * sin(angle * 5.0 + depth * 12.0 - clock * 1.4 + cloud * 4.0), 5.0);
	float distance_fade = smoothstep(0.08, 0.5, radius);
	float inside = 1.0 - smoothstep(boundary - 0.025, boundary, radius);
	float rim = exp(-abs(radius - boundary) * 95.0) * aperture;
	float inner_ring = exp(-abs(radius - boundary * 0.83) * 140.0) * 0.4;
	vec3 color = deep_color.rgb + soul_color.rgb * (ribbon * 0.5 + cloud * cloud * 0.12) * distance_fade * inside;
	vec2 star_cell = floor(tunnel * 24.0);
	float star = step(0.987, hash(star_cell)) * pow(max(0.0, 1.0 - length(fract(tunnel * 24.0) - 0.5) * 3.0), 3.0);
	color += vec3(0.55, 0.9, 0.85) * star * inside * distance_fade;
	ALBEDO = color * aperture;
	EMISSION = color * 1.5 * aperture + rim_color.rgb * rim * 2.5 + soul_color.rgb * inner_ring * inside;
}
