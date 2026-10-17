// Tree crowns in the 3D view. The leaf texture is laid on from the side
// (object space, so it never smears round the ball), lit in a few crisp
// bands; the underside of every clump sits in shade, and the rim darkens
// to an outline -- so each tree reads as its own tree, as in hand-drawn art.
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_back, shadows_disabled;

uniform sampler2D leaves : source_color, filter_nearest, repeat_enable;
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
	vec3 t = texture(leaves, uv * uv_scale).rgb;
	// shade under each clump (the foliage above it keeps the sky off)
	float under = mix(0.62, 1.0, smoothstep(-0.6, 0.35, ln.y));
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = mix(0.5, 1.0, smoothstep(0.08, 0.5, facing));
	ALBEDO = t * COLOR.rgb * under * rim * 1.6;
	ROUGHNESS = 1.0;
}
