// The finishing pass over the 3D picture (View3D's screen): lights bloom,
// the dark keeps a deep indigo instead of going flat black, and colour is
// lifted in the half-lights so a lantern's amber and a flare's green read
// rich. The glow is smooth, so the picture stays clean.
shader_type canvas_item;

uniform float night = 1.0;        // 1 = deep night .. 0 = full day
uniform float bloom = 0.6;
uniform vec3 deep : source_color = vec3(0.045, 0.03, 0.1);   // what darkness is made of
uniform float vignette = 0.35;
uniform float px_scale = 1.0;    // real pixels per game pixel (the glow keeps its size)

vec3 bright(vec3 s) {
	float l = max(s.r, max(s.g, s.b));
	return s * smoothstep(0.55, 1.0, l);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * px_scale;
	vec3 c = texture(TEXTURE, UV).rgb;
	// bloom: bright pixels nearby bleed their colour, nearer ones more
	vec3 b = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398 + 0.39;
		vec2 d = vec2(cos(a), sin(a));
		b += bright(texture(TEXTURE, UV + d * 1.5 * px).rgb) * 0.5;
		b += bright(texture(TEXTURE, UV + d * 3.5 * px).rgb) * 0.3;
		b += bright(texture(TEXTURE, UV + d * 6.5 * px).rgb) * 0.2;
	}
	b /= 8.0;
	c += b * 1.6 * bloom * mix(0.25, 1.0, night);
	// the dark: deep indigo, warmest right next to the light
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	c += deep * pow(1.0 - clamp(lum * 4.0, 0.0, 1.0), 2.0) * night;
	// colour: lifted most in the half-lights, kept off the near-blacks
	vec3 grey = vec3(lum);
	c = mix(grey, c, 1.0 + 0.3 * smoothstep(0.04, 0.35, lum) * (1.0 - 0.4 * smoothstep(0.7, 1.0, lum)));
	// by day: a touch richer and warmer, like a painted scene in sunlight
	float l2 = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(vec3(l2), c, 1.0 + 0.2 * (1.0 - night));
	c *= mix(vec3(1.0), vec3(1.045, 1.01, 0.94), 1.0 - night);
	// a little darker toward the corners (more at night)
	vec2 v = (UV - 0.5) * vec2(1.25, 1.0);
	c *= 1.0 - vignette * night * smoothstep(0.35, 0.85, length(v));
	COLOR = vec4(c, 1.0);
}
