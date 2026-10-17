// The light model for everything in the 3D view (View3D / LightStyle).
//
// Light is life in the labyrinth, so it gets drawn like a painter would,
// not like a physics textbook -- but it follows the physics where it shows:
//   * distance falloff and shadows are the engine's own (ATTENUATION), so a
//     wall really blocks a flare and the light really fades with distance;
//   * the falloff is cut into a few BANDS, each edge broken by a 4x4 ordered
//     dither: the crisp rings of light of hand-drawn pixel art;
//   * colour shifts with strength, like a flame: the heart of a light runs
//     hot toward white, its edge deep and saturated (amber -> ember red,
//     a green flare -> deep emerald); so two lights never just turn grey
//     where they meet, they mix as colours;
//   * light wraps a little round edges, and spills a faint bounce onto the
//     faces turned away from it, so a wall beside your lantern isn't a black
//     cut-out on its dark side;
//   * the sun / moon gets just a lit side and a shaded side (two bands).

const float BANDS = 5.0;          // steps of light from a lamp's heart to its edge
const float DITHER_EDGE = 0.32;   // how much of each step is dithered into the next
const float WRAP = 0.55;          // light reaching round an edge (0 = hard Lambert)
const float BOUNCE = 0.14;        // faint light on the faces turned away
const float HEART = 0.42;         // how far the heart of a light whitens

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(floor(p), 4.0));
	return (BAYER[i.x + i.y * 4] + 0.5) / 16.0;
}

// strength k (0..1+) cut into steps; the last part of every step dithered
float banded(float k, float bands, vec2 frag) {
	float f = k * bands;
	float base = floor(f);
	float t = fract(f);
	// the faintest step fades out as a stipple instead of stopping dead
	float edge = base < 0.5 ? t * t : clamp((t - (1.0 - DITHER_EDGE)) / DITHER_EDGE, 0.0, 1.0);
	float up = step(bayer4(frag), edge);
	return (base + up) / bands;
}

// a light's colour at strength q: deep and saturated at the edge, hot at the heart
vec3 flame(vec3 hue, float q) {
	vec3 edge = pow(hue, vec3(1.9));
	edge /= max(max(edge.r, max(edge.g, edge.b)), 1e-4);
	vec3 heart = mix(hue, vec3(1.0, 0.97, 0.9), HEART);
	return mix(edge, heart, smoothstep(0.3, 1.0, q));
}

void light() {
	vec3 lc = LIGHT_COLOR / PI;
	float e = max(lc.r, max(lc.g, lc.b));
	vec3 hue = lc / max(e, 1e-4);
	float ndl = dot(NORMAL, LIGHT);
	if (LIGHT_IS_DIRECTIONAL) {
		// sun or moon: a lit side and a shaded side, the edge dithered
		float k = clamp((ndl + WRAP) / (1.0 + WRAP), 0.0, 1.0) * ATTENUATION;
		float q = banded(k, 2.0, FRAGCOORD.xy);
		DIFFUSE_LIGHT += lc * q;
	} else {
		float lit = clamp((ndl + WRAP) / (1.0 + WRAP), 0.0, 1.0);
		float back = clamp(-ndl, 0.0, 1.0) * BOUNCE;
		// distance falloff (and shadow) from the engine, eased so the pool of
		// light keeps a broad bright middle and a short dim fringe
		float k = pow(clamp(ATTENUATION, 0.0, 1.0), 0.75) * (lit + back);
		float q = banded(min(k, 1.0), BANDS, FRAGCOORD.xy);
		DIFFUSE_LIGHT += flame(hue, q) * e * q;
	}
}
