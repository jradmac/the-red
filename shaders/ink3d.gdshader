// Ink lines over the 3D world, like the lines of a hand-drawn illustration:
// wherever the depth of the picture jumps (the silhouette of a block, a wall
// against the floor, a terrace's edge) or bends sharply (where a wall's top
// meets its face), a soft dark line is drawn. A full-screen pass, drawn last.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, blend_mix, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 ink : source_color = vec3(0.06, 0.04, 0.08);
uniform float strength = 0.75;
uniform float width = 1.5;          // in rendered pixels
uniform float jump = 0.02;         // relative depth change that makes a line
uniform float crease = 0.006;      // how sharp a bend makes a line

float lin(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
	return -v.z / v.w;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 0.0, 1.0);
}

void fragment() {
	vec2 px = width / VIEWPORT_SIZE;
	mat4 ip = INV_PROJECTION_MATRIX;
	float c = lin(SCREEN_UV, ip);
	float l = lin(SCREEN_UV - vec2(px.x, 0.0), ip);
	float r = lin(SCREEN_UV + vec2(px.x, 0.0), ip);
	float u = lin(SCREEN_UV - vec2(0.0, px.y), ip);
	float d = lin(SCREEN_UV + vec2(0.0, px.y), ip);
	// a jump: the nearest side of it gets the line (so lines hug the front shape)
	float j = max(max(l, r), max(u, d)) - c;
	float e1 = smoothstep(jump, jump * 2.5, j / c);
	// a bend: the second difference of depth
	float lap = abs(l + r + u + d - 4.0 * c) / c;
	float e2 = smoothstep(crease, crease * 2.5, lap) * 0.6;
	float e = max(e1, e2);
	if (c > 150.0) {
		e = 0.0;   // the empty sky
	}
	ALBEDO = ink;
	ALPHA = e * strength;
}
