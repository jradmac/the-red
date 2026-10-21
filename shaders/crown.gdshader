// Tree crowns in the 3D view. The leaf texture is laid on from the side
// (object space, so it never smears round the ball), lit in a few crisp
// bands; the underside of every clump sits in shade, and the rim darkens
// to an outline -- so each tree reads as its own tree, as in hand-drawn art.
shader_type spatial;
render_mode specular_disabled, cull_back, shadows_disabled;
#include "res://shaders/light3d.gdshaderinc"

uniform sampler2D leaves : source_color, filter_linear_mipmap, repeat_enable;

// crisp texels without the crawl (see light_style.gd)
vec2 sharp_uv(vec2 uv, vec2 size) {
	vec2 p = uv * size;
	vec2 seam = floor(p + 0.5);
	vec2 w = max(fwidth(p), vec2(1e-4));
	p = seam + clamp((p - seam) / w, -0.5, 0.5);
	return p / size;
}
uniform float uv_scale = 1.0;
varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	// project from the side the surface faces most (no stretching)
	vec3 an = abs(ln);
	vec2 uv = an.y > 0.75 ? lp.xz : (an.x > an.z ? lp.zy : lp.xy);
	uv.y = -uv.y;
	// painted, not speckled: the leaf pattern softened toward its own broad
	// colour, so a crown reads as soft clumps of green, as in concept art
	vec2 tuv = uv * uv_scale;
	vec3 fine = texture(leaves, tuv).rgb;
	vec3 broad = textureLod(leaves, tuv, 3.0).rgb;
	vec3 t = mix(broad, fine, 0.35);
	// shade under each clump (the foliage above it keeps the sky off), and a
	// sunny top: two clear tones, like painted foliage
	float under = mix(0.66, 1.0, smoothstep(-0.6, 0.35, ln.y));
	float top = smoothstep(0.35, 0.85, ln.y);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = mix(0.62, 1.0, smoothstep(0.08, 0.5, facing));
	vec3 lit = t * COLOR.rgb * under * rim * 1.6;
	ALBEDO = mix(lit, lit * vec3(1.1, 1.12, 1.02) + vec3(0.01, 0.015, 0.0), top * 0.8);
	ROUGHNESS = 1.0;
}
