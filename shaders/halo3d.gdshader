// The glow in the air round a flame (View3D): a billboard of light, added
// over the picture, hidden by walls in front of it like the flame itself.
// Its falloff is smooth, hottest in the middle.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.7, 0.4);
uniform float strength = 0.4;

void vertex() {
	// face the camera
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = pow(clamp(1.0 - d, 0.0, 1.0), 1.8);
	float q = a;
	// hot at the middle, the colour deepening outward
	vec3 edge = pow(tint, vec3(1.8));
	edge /= max(max(edge.r, max(edge.g, edge.b)), 1e-4);
	vec3 col = mix(edge, mix(tint, vec3(1.0), 0.5), q * q);
	ALBEDO = col * q * strength;
}
