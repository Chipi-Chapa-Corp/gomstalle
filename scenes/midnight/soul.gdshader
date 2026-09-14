shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float clock = 0.0;
uniform float strength = 0.2;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float cloud_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 fraction = fract(point);
	vec2 blend = fraction * fraction * (3.0 - 2.0 * fraction);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), blend.x), blend.y);
}

void fragment() {
	float latitude = UV.y * 3.14159265;
	float longitude = UV.x * 6.2831853;
	float swirl = longitude + latitude * 1.8 - clock * 0.18;
	vec2 flow = vec2(cos(swirl), sin(swirl)) * (1.0 + sin(latitude) * 2.0) + vec2(latitude * 1.3, clock * 0.12);
	float cloud = cloud_noise(flow * 2.0) * 0.65 + cloud_noise(flow * 4.1) * 0.35;
	float ribbons = pow(0.5 + 0.5 * sin(latitude * 12.0 + longitude * 2.0 + cloud * 5.0 - clock * 0.8), 7.0);
	vec3 core = mix(vec3(0.012, 0.035, 0.07), vec3(0.025, 0.17, 0.16), cloud);
	float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 2.0);
	ALBEDO = core;
	EMISSION = (core * 0.5 + vec3(0.16, 0.8, 0.58) * ribbons) * (1.0 + strength * 1.6) + vec3(0.1, 0.4, 0.55) * rim * 0.65;
}
