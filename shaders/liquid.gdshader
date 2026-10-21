// The rare lands' liquids (rare3d.gd), each moving in its own way:
//   0 sea      deep blue swell, lighter crests, foam where it meets the sand
//   1 murky    the jungle's still brown-green water, slow ripples, a scum
//   2 ice      frozen: pale blue, cracked, a cold sheen
//   3 lava     slow-crawling molten rock: dark crust over a glowing heart
//   4 gold     molten gold: bright, rolling, glinting
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_back;

uniform int kind = 0;
uniform sampler2D shore_map : filter_linear;   // r: 1 near the land (for foam / crust)
uniform vec4 map_rect;                           // x0, z0, width, height of shore_map in tiles

varying vec3 wp;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.07 + 3.1) * 0.3 + vnoise(p * 4.3 - 1.7) * 0.15;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (kind == 0) {
		// the swell rides above the sea floor (never dipping through it)
		VERTEX.y += 0.05 + sin(wp.x * 0.9 + TIME * 1.3) * 0.025 + sin(wp.z * 1.3 - TIME * 0.9) * 0.02;
	}
}

void fragment() {
	vec2 p = wp.xz;
	float t = TIME;
	float shore = texture(shore_map, (p - map_rect.xy) / map_rect.zw).r;
	vec3 col;
	vec3 em = vec3(0.0);
	if (kind == 0) {
		float n = fbm(p * 0.45 + vec2(t * 0.12, t * 0.05));
		// crests: thin lines of white riding the swell toward the shore
		float crest = smoothstep(0.74, 0.8, fbm(vec2(p.x * 0.6, p.y * 2.6) - vec2(t * 0.15, -t * 0.35)));
		col = mix(vec3(0.05, 0.22, 0.42), vec3(0.12, 0.42, 0.62), n);
		col = mix(col, vec3(0.8, 0.93, 0.97), crest * 0.35);
		float foam = smoothstep(0.35, 0.9, shore + sin(t * 1.4 + dot(p, vec2(0.3, 0.7))) * 0.12);
		col = mix(col, vec3(0.92, 0.97, 1.0), foam * 0.85);
	} else if (kind == 1) {
		float n = fbm(p * 0.6 + vec2(t * 0.03, 0.0));
		float ring = 0.5 + 0.5 * sin(length(fract(p * 0.35) - 0.5) * 28.0 - t * 1.5);
		col = mix(vec3(0.07, 0.1, 0.05), vec3(0.17, 0.2, 0.08), n) + ring * 0.015;
		col = mix(col, vec3(0.25, 0.32, 0.1), smoothstep(0.62, 0.8, fbm(p * 1.4)) * 0.7);   // scum
	} else if (kind == 2) {
		float n = fbm(p * 0.7);
		float crack = smoothstep(0.02, 0.0, abs(fbm(p * 1.6) - 0.5)) * 0.8;
		col = mix(vec3(0.62, 0.78, 0.9), vec3(0.86, 0.95, 1.0), n) - crack * vec3(0.3, 0.2, 0.1);
		col += smoothstep(0.7, 0.95, vnoise(p * 0.3 + vec2(t * 0.02, 0.0))) * 0.08;
	} else if (kind == 3) {
		vec2 flow = p * 0.5 + vec2(t * 0.06, t * 0.035);
		float heat = fbm(flow);
		float crust = smoothstep(0.42, 0.6, fbm(p * 0.9 - vec2(t * 0.03, 0.0))) * (0.4 + 0.6 * shore);
		vec3 glow = mix(vec3(0.95, 0.25, 0.03), vec3(1.0, 0.82, 0.25), smoothstep(0.35, 0.8, heat));
		col = mix(glow, vec3(0.08, 0.05, 0.05), crust);
		em = glow * (1.0 - crust) * 2.2;
	} else {
		float roll = fbm(p * 0.55 + vec2(t * 0.08, -t * 0.05));
		vec3 g = mix(vec3(0.75, 0.48, 0.08), vec3(1.0, 0.86, 0.38), roll);
		float glint = smoothstep(0.82, 0.9, vnoise(p * 2.2 + vec2(t * 0.6, t * 0.3)));
		col = g + glint * 0.45;
		em = g * 0.55 + glint * vec3(1.0, 0.95, 0.7) * 1.2;
	}
	ALBEDO = col;
	EMISSION = em;
	ROUGHNESS = 1.0;
}
