shader_type spatial;
// Oak plank floor laid along Z, generated from world position so every room lines up.

uniform vec3 oak_light : source_color = vec3(0.64, 0.47, 0.31);
uniform vec3 oak_dark : source_color = vec3(0.4, 0.27, 0.16);
uniform float plank_width = 0.19;
uniform float plank_length = 2.1;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float column = floor(p.x / plank_width);
	float along = p.y + hash(vec2(column, 7.0)) * plank_length;
	vec2 id = vec2(column, floor(along / plank_length));
	float h = hash(id);

	vec3 wood = mix(oak_dark, oak_light, 0.45 + 0.35 * h);
	float grain = value_noise(vec2(p.x * 55.0 + h * 13.0, along * 1.6))
		* 0.6 + value_noise(vec2(p.x * 160.0, along * 4.0)) * 0.4;
	wood *= 0.88 + 0.2 * grain;

	// dark seams between boards, softened with distance so they don't shimmer
	float ex = min(fract(p.x / plank_width), 1.0 - fract(p.x / plank_width)) * plank_width;
	float ez = min(fract(along / plank_length), 1.0 - fract(along / plank_length)) * plank_length;
	float aa = fwidth(p.x) + fwidth(p.y);
	float seam = smoothstep(0.0015, 0.0015 + aa, ex) * smoothstep(0.0015, 0.0015 + aa, ez);
	wood *= mix(0.62, 1.0, seam);

	ALBEDO = wood;
	ROUGHNESS = mix(0.42, 0.6, grain);
	SPECULAR = 0.5;
}
