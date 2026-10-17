// The 3D walls and cliffs (scripts/terrain3d.gd).
// Model space is in tiles: x east, y height, z south. Tops lean out from the
// middle of the screen in proportion to their height: the depth cue that lets
// you see a wall's side as it slides past the edge of the screen.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D tex : source_color, filter_nearest;
uniform float cam_x = 0.0;
uniform float parallax = 0.03;
uniform float cam_z = 0.0;
uniform float depth = 0.0;
uniform bool over_pass = false;
uniform sampler2D detail : source_color, filter_nearest, repeat_disable;
uniform float detail_mix = 0.0;

varying vec2 tile_xz;
varying float biome;

varying float flat_y;
varying float line_y;
varying float tile_z;

void vertex() {
	// further up the screen (north of the middle), a wall shows a taller front;
	// nearer the bottom, more of its top -- the camera looks down at an angle
	VERTEX.y *= max(0.2, 1.0 + (cam_z - VERTEX.z) * depth);
	float h = VERTEX.y;
	VERTEX.x += (VERTEX.x - cam_x) * h * parallax;
	flat_y = VERTEX.z - h;   // where this point shows on the flat 2D map, in rows
	float level = floor(COLOR.a * 4.0 + 0.5);
	line_y = level > 0.5 ? -(level - 1.0) * 0.75 - 0.3 : 0.0;   // added to the tile row below (cliffs: a little less, so heads up there are not clipped)
	tile_z = VERTEX.z;
	tile_xz = VERTEX.xz;
	biome = floor(COLOR.g * 8.0 + 0.5);
}

void fragment() {
	// the over-layer keeps only what rises above its tile's own north edge
	if (over_pass && flat_y >= floor(tile_z - 0.01) + line_y - 0.001) {
		discard;
	}
	vec4 t = texture(tex, UV);
	if (t.a < 0.5) {
		discard;
	}
	vec3 col = t.rgb;
	if (detail_mix > 0.0) {
		// a ground tile of this landscape, one per tile: env.png columns/rows
		vec2 cell = vec2(0.0, 0.0);   // crypt floor
		if (biome > 1.5 && biome < 2.5) cell = vec2(0.0, 10.0);   // courtyard
		if (biome > 2.5 && biome < 3.5) cell = vec2(0.0, 12.0);   // mountain
		vec2 f = fract(tile_xz);
		vec2 duv = (cell + vec2(mod(floor(tile_xz.x), 2.0), 0.0) + f) * vec2(16.0 / 128.0, 16.0 / 256.0);
		vec3 d = texture(detail, duv).rgb;
		float lum = dot(d, vec3(0.3, 0.5, 0.2));
		col *= mix(1.0, clamp(lum * 2.4, 0.55, 1.35), detail_mix);
	}
	ALBEDO = col * COLOR.r;
}
