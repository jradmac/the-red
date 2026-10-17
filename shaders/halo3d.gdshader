// The glow in the air round a flame (View3D): a billboard of light, added
// over the picture, hidden by walls in front of it like the flame itself.
// Its falloff comes in dithered steps like the light on the ground.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.7, 0.4);
uniform float strength = 0.4;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(floor(p), 4.0));
	return (BAYER[i.x + i.y * 4] + 0.5) / 16.0;
}

void vertex() {
	// face the camera
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = pow(clamp(1.0 - d, 0.0, 1.0), 1.8);
	float f = a * 4.0;
	float q = (floor(f) + step(bayer4(FRAGCOORD.xy), fract(f))) / 4.0;
	// hot at the middle, the colour deepening outward
	vec3 edge = pow(tint, vec3(1.8));
	edge /= max(max(edge.r, max(edge.g, edge.b)), 1e-4);
	vec3 col = mix(edge, mix(tint, vec3(1.0), 0.5), q * q);
	ALBEDO = col * q * strength;
}
