// Darkness overlay. Multiplies the whole screen by (ambient + lights).
//
// - Walls cast shadows: each pixel marches toward each light through a small
//   wall mask of the tiles on screen. Wall faces still catch light (a pixel
//   never shadows itself), wall tops fall into shadow, so walls read as solid
//   blocks.
// - Smooth falloff with a dithered, banded edge so it stays pixel art.
// - A faint spill past the radius lets you sense the shape of the room.
// - ADDITIVE mode (a second overlay) adds a warm bloom near the flames.

const int MAX_LIGHTS = 24;
uniform int light_count = 0;
uniform vec4 lights[MAX_LIGHTS];        // x, y (screen pixels), radius, energy
uniform vec4 light_colors[MAX_LIGHTS];  // rgb, w = casts shadows (1) or not (0)
uniform vec3 ambient = vec3(0.028, 0.028, 0.06);
uniform vec2 screen_size = vec2(360.0, 240.0);
uniform float vignette = 0.6;
uniform float bands = 7.0;
uniform float spill = 0.10;      // brightness of the light just past its radius
uniform bool additive = false;
uniform float daylight = 0.0;                  // 0 night .. 1 full day
uniform vec3 day_tint = vec3(1.0);             // warm at sunrise / sunset

uniform sampler2D wall_mask : filter_nearest;  // r = 1 wall top, 0.5 wall face, 0 open
uniform sampler2D outdoor_mask : filter_linear; // g = 1 under the open sky (same texture)
uniform vec3 moon = vec3(0.17, 0.19, 0.27);  // ambient light outdoors
uniform vec2 mask_origin;   // screen pixel of the mask's top-left tile corner
uniform vec2 mask_cells;    // mask size in tiles
uniform float tile_px = 16.0;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

float mask_at(vec2 cell) {
	if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= mask_cells.x || cell.y >= mask_cells.y) {
		return 0.0;
	}
	return texture(wall_mask, (cell + 0.5) / mask_cells).r;
}

// Stone walls, cliffs and closed doors block light; trees only dim it.
bool wall_at(vec2 cell) {
	return mask_at(cell) > 0.4;
}

// 1.0 = lit, 0.0 = a wall stands between p and the light.
float ray(vec2 p, vec2 l, vec2 own, vec2 lcell) {
	float d = distance(p, l);
	int steps = int(clamp(d / 4.0, 1.0, 32.0));
	float v = 1.0;
	for (int s = 1; s < 32; s++) {
		if (s >= steps) { break; }
		vec2 q = mix(p, l, float(s) / float(steps));
		vec2 c = floor((q - mask_origin) / tile_px);
		if (c != own && c != lcell) {
			float m = mask_at(c);
			if (m > 0.4) {
				return 0.0;
			}
			if (m > 0.1) {
				v *= 0.82;   // foliage: light filters through, dimmer
			}
		}
	}
	return v;
}

// Soft shadows: three rays toward points spread across the flame, averaged.
float visibility(vec2 p, vec2 l) {
	vec2 own = floor((p - mask_origin) / tile_px);
	// A wall face is lit exactly when the floor right in front of it is.
	if (abs(mask_at(own) - 0.5) < 0.2) {
		own.y += 1.0;
		p.y = mask_origin.y + own.y * tile_px + 1.0;
	}
	vec2 lcell = floor((l - mask_origin) / tile_px);
	vec2 dir = normalize(l - p + vec2(0.001));
	vec2 side = vec2(-dir.y, dir.x) * 4.0;
	float v = ray(p, l, own, lcell);
	v += ray(p, l + side, own, lcell);
	v += ray(p, l - side, own, lcell);
	return v / 3.0;
}

void fragment() {
	vec2 px = floor(SCREEN_UV * screen_size);
	vec2 p = px + 0.5;
	int bi = int(mod(px.x, 4.0)) + int(mod(px.y, 4.0)) * 4;
	float dither = BAYER[bi] / 16.0;

	vec3 col = vec3(0.0);
	if (!additive) {
		float outside = texture(outdoor_mask, ((p - mask_origin) / tile_px) / mask_cells).g;
		col = mix(ambient, moon, outside);
	}
	for (int i = 0; i < MAX_LIGHTS; i++) {
		if (i >= light_count) { break; }
		vec4 L = lights[i];
		float d = distance(p, L.xy);
		float reach = additive ? L.z * 0.7 : L.z * 1.7;
		if (d > reach) { continue; }
		float a;
		if (additive) {
			a = clamp(1.0 - d / reach, 0.0, 1.0);
			a = a * a * a * 0.35;
		} else {
			float core = clamp(1.0 - d / L.z, 0.0, 1.0);
			core = core * core * (3.0 - 2.0 * core);
			float outer = clamp(1.0 - d / reach, 0.0, 1.0) * spill;
			a = max(core, outer);
			a = floor(a * bands + dither) / bands;   // banded + dithered steps
		}
		if (a <= 0.0) { continue; }
		if (light_colors[i].w > 0.5) {
			a *= visibility(p, L.xy);
		}
		col += light_colors[i].rgb * a * L.w;
	}

	if (additive) {
		COLOR = vec4(col * (1.0 - daylight), 1.0);
	} else {
		vec2 uv = SCREEN_UV - 0.5;
		col *= clamp(1.0 - dot(uv, uv) * vignette * 2.0 * (1.0 - 0.8 * daylight), 0.0, 1.0);
		if (daylight > 0.0) {
			float outside = texture(outdoor_mask, ((p - mask_origin) / tile_px) / mask_cells).g;
			vec3 day = mix(vec3(0.62, 0.6, 0.68), vec3(1.0), outside) * day_tint;
			col = mix(col, max(col, day), daylight);
		}
		COLOR = vec4(min(col, vec3(1.0)), 1.0);
	}
}
