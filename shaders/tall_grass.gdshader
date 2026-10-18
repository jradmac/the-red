// Tall grass (tall_grass.gd): clumps of pixel blades that sway, with gusts
// rolling across the field in waves, and part around whoever walks through.
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec2 atlas = vec2(2.0, 6.0);        // clumps across, lands down
uniform vec4 pushers[8];                    // x, z, running (0/1), strength
uniform float ahead = 0.55;                 // as sprite3d_depth.gdshader: the upright plane's place past the roots

varying vec2 cell_uv;
varying float wave;
varying float tip;
varying float root_z;

const vec2 WIND = vec2(0.91, 0.41);

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = 1.0 - UV.y;                   // 0 at the root .. 1 at the tips
	float ph = INSTANCE_CUSTOM.z;
	// a steady breeze, every clump a little out of step
	float sway = sin(TIME * 1.7 + ph + base.x * 0.6) * 0.035 + sin(TIME * 2.9 + base.z * 1.3 + ph) * 0.015;
	// gusts: bands rolling across the field
	float g = dot(base.xz, WIND) * 0.11 - TIME * 0.35;
	wave = pow(max(0.0, sin(g * 6.2832)), 8.0);
	vec2 bend = WIND * (sway + wave * 0.17);
	float press = 0.0;
	for (int i = 0; i < 8; i++) {
		vec4 p = pushers[i];
		vec2 d = base.xz - p.xy;
		float l = length(d);
		float k = p.w * clamp(1.0 - l / 0.9, 0.0, 1.0);
		if (k > 0.0) {
			bend += (d / max(l, 0.05)) * k * 0.3;
			bend.x += sin(TIME * 34.0 + ph) * 0.05 * k * p.z;   // shivering as they run through
			press = max(press, k);
		}
	}
	vec3 off = vec3(bend.x, -press * 0.22 - length(bend) * 0.25, bend.y) * h;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(off, 0.0)).xyz;
	// lit like the ground it grows from
	NORMAL = normalize((inverse(MODEL_MATRIX) * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	cell_uv = (vec2(INSTANCE_CUSTOM.y, INSTANCE_CUSTOM.x) + UV) / atlas;
	tip = h;
	root_z = base.z;
}

void fragment() {
	vec4 c = texture(tex, cell_uv);
	if (c.a < 0.5) {
		discard;
	}
	// the tips catch the light as a gust goes over
	ALBEDO = c.rgb * (0.9 + wave * 0.35 * tip);
	ROUGHNESS = 1.0;
	// hidden and hiding like the characters (sprite3d_depth.gdshader): each
	// clump an upright cut-out standing at its roots, so a blade rooted in
	// front of your feet covers you and one behind you never does
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 d = p - cam;
	vec3 q = cam + d * ((root_z + ahead - cam.z) / d.z);
	vec4 cl = PROJECTION_MATRIX * VIEW_MATRIX * vec4(q, 1.0);
	DEPTH = cl.z / cl.w * 0.5 + 0.5;
}
