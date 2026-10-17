// The 3D view's characters and things (SpriteHost, Interior3D): the 2D sprite
// on a billboard turned square to the camera (so one sprite pixel is exactly
// one screen pixel) -- but hidden by the world as if it were a flat cut-out
// standing upright where the thing stands. Each fragment's depth is the depth
// of the point on that upright plane behind it, so a wall in front covers the
// legs and body the way it would a real figure, while the head never sinks
// into the wall behind (as a tilted billboard's would).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D atlas : source_color, filter_nearest;
// how far in front of the thing's tile centre the upright plane stands (tiles):
// just past the front edge, so walls beside it never cut into its sides
uniform float ahead = 0.55;

void vertex() {
	// billboard, keeping the node's scale (the pixel-exact size SpriteHost sets)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 t = texture(atlas, UV);
	if (t.a < 0.5) {
		discard;
	}
	ALBEDO = t.rgb * COLOR.rgb;
	// where this pixel would be on the upright plane through the thing's feet
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 d = p - cam;
	float zf = MODEL_MATRIX[3].z + ahead;
	vec3 q = cam + d * ((zf - cam.z) / d.z);
	vec4 c = PROJECTION_MATRIX * VIEW_MATRIX * vec4(q, 1.0);
	DEPTH = c.z / c.w * 0.5 + 0.5;
}
