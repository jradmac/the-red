class_name RareLook
extends RefCounted
## How the rare lands look: each one repaints the land it's built on (the
## mountains' rock, the swamp's trees, the river's ground...) in its own colours.
## A texture keeps its pattern -- its light and dark -- and takes the land's
## palette: each pixel's brightness picks a colour along a ramp.
##   beach     pale sand; the trees' leaves sun-bleached and yellow-green
##   jungle    lush, deep, saturated greens; dark wet earth
##   snow      snow on every top; cold blue-grey rock on the faces
##   volcano   black basalt and ash; embers glowing in the cracks
##   gold      gold -- all of it

const BEACH := World.R_BEACH
const JUNGLE := World.R_JUNGLE
const SNOW := World.R_SNOW
const VOLCANO := World.R_VOLCANO
const GOLD := World.R_GOLD

## per land and part: the ramp's [dark, light] (and an ember colour for the brightest bits)
const RAMPS := {
	BEACH: {"top": ["b49464", "f6e8bc"], "side": ["8a6a42", "dcc08a"], "ground": ["c4a472", "f7e9c0"], "leaves": ["4f7a1e", "d6e86a"]},
	JUNGLE: {"top": ["163a16", "6fbf3c"], "side": ["1c2614", "5f7a34"], "ground": ["17301a", "62a63a"], "leaves": ["0f4a1a", "7fe04a"]},
	SNOW: {"top": ["8a9cb8", "eef3fa"], "side": ["2c3346", "8f9bb3"], "ground": ["98aac4", "e6edf6"], "leaves": ["2c4a46", "e8f4ff"]},
	VOLCANO: {"top": ["161112", "4e403c"], "side": ["0e0a0b", "3e302e"], "ground": ["141011", "4a3c38"], "leaves": ["2a1a14", "6a4a30"]},
	GOLD: {"top": ["5a3606", "e8c060"], "side": ["3e2404", "d0a03a"], "ground": ["4a2e06", "c99a3c"], "leaves": ["6a4a08", "ffe27a"]},
}
const EMBER := Color("ff7a2a")


## Which ramp a world texture takes ("side" for faces, "leaves" for foliage).
static func part_of(key: String) -> String:
	if "leaves" in key or "needles" in key or key.begins_with("tuft") or key == "fern" or key == "moss":
		return "leaves"
	if "side" in key or "bark" in key:
		return "side"
	return "top"


## A copy of `img` in land `land`'s colours, for part `part`.
static func recolor(img: Image, land: int, part: String) -> Image:
	var out := img.duplicate() as Image
	if out.is_compressed():
		out.decompress()
	out.convert(Image.FORMAT_RGBA8)
	var ramp: Array = RAMPS[land][part]
	var dark := Color(ramp[0])
	var light := Color(ramp[1])
	# the texture's own range of brightness, stretched over the ramp
	var lo := 1.0
	var hi := 0.0
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			if c.a > 0.1:
				lo = minf(lo, c.get_luminance())
				hi = maxf(hi, c.get_luminance())
	var span := maxf(hi - lo, 0.05)
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			if c.a <= 0.1:
				continue
			var l := clampf((c.get_luminance() - lo) / span, 0.0, 1.0)
			var n := dark.lerp(light, l)
			if land == VOLCANO and part == "side" and l > 0.96:
				n = EMBER.lerp(Color("ffd060"), (l - 0.96) / 0.04)   # embers in the cracks
			out.set_pixel(x, y, Color(n.r, n.g, n.b, c.a))
	return out


## The baked ground of one tile repainted (in place, in `img`, at `o`, `size` px).
static func recolor_area(img: Image, o: Vector2i, size: int, land: int, part: String) -> void:
	var ramp: Array = RAMPS[land][part]
	var dark := Color(ramp[0])
	var light := Color(ramp[1])
	for y in range(o.y, mini(o.y + size, img.get_height())):
		for x in range(o.x, mini(o.x + size, img.get_width())):
			if x < 0 or y < 0:
				continue
			var c := img.get_pixel(x, y)
			var l := clampf((c.get_luminance() - 0.08) / 0.62, 0.0, 1.0)
			var n := dark.lerp(light, l)
			img.set_pixel(x, y, Color(n.r, n.g, n.b, 1.0))
