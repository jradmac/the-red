shader_type canvas_item;
// Two players' views, side by side along a line that follows them.
// view1 / view2 are each player's camera (360x240), drawn 2x over the screen.
// `dir` points from player 1 towards player 2: pixels on player 1's side of
// the line through the middle show view1, the rest view2.

uniform sampler2D view1 : filter_nearest;
uniform sampler2D view2 : filter_nearest;
uniform vec2 dir = vec2(1.0, 0.0);
uniform float split = 0.0;       // 0 = one shared view .. 1 = split
uniform bool forced = false;     // a straight split down the middle (someone's in a menu)
uniform bool black1 = false;     // player 1's half is covered by a menu
uniform bool black2 = false;
uniform vec2 view_px = vec2(360.0, 240.0);

void fragment() {
	vec2 uv = UV;
	vec2 p = (uv - 0.5) * view_px;
	float side = forced ? (uv.x - 0.5) * view_px.x : dot(p, dir);
	bool two = split > 0.0 && side > 0.0;
	vec4 c = two ? texture(view2, uv) : texture(view1, uv);
	if ((two && black2) || (!two && black1)) {
		c = vec4(0.02, 0.012, 0.035, 1.0);
	}
	// the dividing line: dark, with a faint pale edge
	float d = abs(side);
	if (split > 0.0) {
		if (d < 0.75) {
			c = mix(c, vec4(0.03, 0.02, 0.05, 1.0), split);
		} else if (d < 1.25) {
			c = mix(c, vec4(0.55, 0.5, 0.7, 1.0), split * 0.5);
		}
	}
	COLOR = c;
}
