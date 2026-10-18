// The growth layer: moss, ivy, lichen growing over the land's own blocks.
//
// Drawn over a copy of the walls, wall tops and floors, a hair above them
// (world_mesh.gd, _growth). Where it grows is decided here in world space, on
// the 16-pixels-per-tile grid, so it sits with the pixel art, never repeats,
// and runs on from one block to the next:
//   - patches from a slow noise, a little more on top of walls;
//   - over the edge of a wall top that's grown over, it drips down the face;
//   - on the faces it also creeps up from the damp floor;
//   - each landscape has its own growth and amount (by the biome map).
// Shading is a few flat cartoon bands: a dark edge where it meets the stone,
// a lit rim along its upper-left side, and the odd speck (a pale fungus, a
// flower, a fleck of orange lichen).
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_back;

uniform sampler2D biome_map : filter_nearest;
uniform vec2 map_size;
uniform float floor_mode = 0.0;   // 1: drawn over the floor

varying vec3 wp;
varying vec3 wn;
varying float vh;   // on a face: 0 at its foot .. 1 at its top (from the face's vertex shading)

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
	return vnoise(p) * 0.55 + vnoise(p * 2.13 + 7.3) * 0.3 + vnoise(p * 4.37 - 3.1) * 0.15;
}

vec3 lin(vec3 c) {
	return pow(c, vec3(2.2));
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vh = clamp((COLOR.r - 0.42) / 0.58, 0.0, 1.0);
	VERTEX += NORMAL * 0.012;
}

void fragment() {
	// whose growth: the land of the tile this surface belongs to
	vec2 cell = floor(wp.xz - wn.xz * 0.25);
	int bi = int(texture(biome_map, (cell + 0.5) / map_size).r * 8.0 + 0.5);
	float cov;      // how much of it is covered (0..1)
	float sc;       // patch size (tiles)
	vec3 c0; vec3 c1; vec3 c2; vec3 c3; vec3 sp; float sp_amt;
	if (bi == 0) {          // crypt: moss
		cov = 0.25; sc = 1.4;
		c0 = vec3(0.13, 0.17, 0.13); c1 = vec3(0.24, 0.33, 0.22); c2 = vec3(0.30, 0.41, 0.26); c3 = vec3(0.42, 0.53, 0.33);
		sp = vec3(0.85, 0.82, 0.69); sp_amt = 0.004;
	} else if (bi == 2) {   // courtyard: grass and ivy
		cov = 0.22; sc = 1.3;
		c0 = vec3(0.11, 0.165, 0.078); c1 = vec3(0.227, 0.333, 0.149); c2 = vec3(0.322, 0.447, 0.184); c3 = vec3(0.463, 0.596, 0.247);
		sp = vec3(0.91, 0.78, 0.38); sp_amt = 0.01;
	} else if (bi == 3) {   // mountain: lichen
		cov = 0.18; sc = 1.1;
		c0 = vec3(0.227, 0.22, 0.125); c1 = vec3(0.416, 0.416, 0.204); c2 = vec3(0.541, 0.529, 0.259); c3 = vec3(0.698, 0.667, 0.361);
		sp = vec3(0.78, 0.47, 0.23); sp_amt = 0.012;
	} else {
		discard;
	}
	// on the pixel grid (16 to a tile)
	vec3 p = floor(wp * 16.0 + 0.001) / 16.0 + 1.0 / 32.0;
	bool top = abs(wn.y) > 0.5;
	vec2 q = top ? p.xz : (abs(wn.x) > 0.5 ? vec2(p.z, p.y) : vec2(p.x, p.y));
	if (floor_mode > 0.5) {
		cov *= 0.55;
	} else if (top) {
		cov += 0.06;
	}
	float edge = 1.0 - cov;
	float n = fbm(q / sc);
	float m = n - edge;
	if (!top && floor_mode < 0.5) {
		// creeping up from the damp floor
		m = max(m, n - edge - 0.14 + (1.0 - vh) * (1.0 - vh) * 0.2);
		// dripping over the edge from a grown-over top
		float nt = fbm(p.xz / sc) - (edge - 0.06);
		if (nt > 0.0) {
			float col_len = 0.06 + hash(vec2(floor(p.x * 16.0 + p.z * 16.0), 3.0)) * 0.3;
			float down = (1.0 - vh) * 1.0;     // tiles below the top
			float d = col_len * clamp(nt * 6.0, 0.0, 1.0) - down;
			m = max(m, d * 0.25);
		}
	}
	if (m < 0.0) {
		discard;
	}
	// cartoon bands: dark edge, lit upper-left rim, two interior tones, specks
	vec3 col;
	vec2 step_ul = top ? vec2(-1.0, -1.0) / 16.0 : vec2(-1.0, 1.0) / 16.0;
	float n_ul = fbm((q + step_ul) / sc) - edge;
	if (m < 0.018) {
		col = c0;
	} else if (n_ul < 0.018) {
		col = c3;
	} else {
		float t = vnoise(q * 5.0) + m * 2.0;
		col = t > 0.85 ? c2 : c1;
		if (hash(q * 16.0 + 0.37) < sp_amt) {
			col = sp;
		}
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
