// The light model for everything in the 3D view (View3D / LightStyle).
//
// Light is life in the labyrinth, so it gets drawn like a painter would,
// on top of the physics:
//   * distance falloff and shadows are the engine's own (ATTENUATION), so a
//     wall really blocks a flare and the light really fades with distance --
//     smoothly, no steps or dither, so the picture stays clean;
//   * colour shifts with strength, like a flame: the heart of a light runs
//     hot toward white, its edge deep and saturated (amber -> ember red,
//     a green flare -> deep emerald); so two lights never just turn grey
//     where they meet, they mix as colours;
//   * light wraps a little round edges, and spills a faint bounce onto the
//     faces turned away from it, so a wall beside your lantern isn't a black
//     cut-out on its dark side;
//   * the sun / moon gives a lit side and a shaded side with a soft, clear edge.

const float WRAP = 0.55;          // light reaching round an edge (0 = hard Lambert)
const float BOUNCE = 0.14;        // faint light on the faces turned away
const float HEART = 0.3;          // how far the heart of a light whitens

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
		// sun or moon: a lit side and a shaded side, the edge soft but clear
		float k = clamp((ndl + WRAP) / (1.0 + WRAP), 0.0, 1.0) * ATTENUATION;
		DIFFUSE_LIGHT += lc * smoothstep(0.0, 0.45, k);
	} else {
		float lit = clamp((ndl + WRAP) / (1.0 + WRAP), 0.0, 1.0);
		float back = clamp(-ndl, 0.0, 1.0) * BOUNCE;
		// distance falloff (and shadow) from the engine, eased so the pool of
		// light keeps a broad bright middle and a short dim fringe
		float k = pow(clamp(ATTENUATION, 0.0, 1.0), 0.75) * (lit + back);
		float q = min(k, 1.0);
		DIFFUSE_LIGHT += flame(hue, q) * e * q;
	}
}
