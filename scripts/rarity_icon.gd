class_name RarityIcon
## A little gem that says how rare something is: shown beside a creature's
## name in battle, and beside a land's name when you walk into it.
##
## Each rarity has its own colour (the journal's) and its own shape, so they
## tell apart without the colour too:
##   COMMON     a small grey stone
##   UNCOMMON   a green diamond
##   RARE       a cut blue gem that catches the light now and then
##   LEGENDARY  a cut gold gem, a shine sweeping over it and a star twinkling

const TIER_COL := {
	"COMMON": Color("b8b0c8"),
	"UNCOMMON": Color("6ad88a"),
	"RARE": Color("5aa8ff"),
	"LEGENDARY": Color("ffd35a"),
}

## o outline, L light, M mid, D dark, W glint
const SHAPES := {
	"COMMON": [
		"..o..",
		".oLo.",
		"oLMDo",
		".oDo.",
		"..o..",
	],
	"UNCOMMON": [
		"...o...",
		"..oWo..",
		".oLLMo.",
		"oLLMMDo",
		".oMMDo.",
		"..oDo..",
		"...o...",
	],
	"RARE": [
		"..ooooo..",
		".oWLLMMo.",
		"oLLLMMMDo",
		".oLMMMDo.",
		"..oMMDo..",
		"...oDo...",
		"....o....",
	],
	"LEGENDARY": [
		"..ooooo..",
		".oWLLMMo.",
		"oLLLMMMDo",
		".oLMMMDo.",
		"..oMMDo..",
		"...oDo...",
		"....o....",
	],
}

## The lands' rarities (as in the journal): World.B_* biomes, villages, and the
## rare lands (World.R_*: beach, jungle, snow, volcano; 5 the golden vault).
const BIOME_TIER := ["COMMON", "COMMON", "UNCOMMON", "UNCOMMON", "UNCOMMON", "UNCOMMON"]
const VILLAGE_TIER := "UNCOMMON"
const RARE_LAND_TIER := {1: "RARE", 2: "RARE", 3: "RARE", 4: "RARE", 5: "LEGENDARY"}


static func size_of(tier: String) -> Vector2i:
	var rows: Array = SHAPES.get(tier, SHAPES["COMMON"])
	return Vector2i(String(rows[0]).length(), rows.size())


## The rarity of the land zone `zi` of `world` ("" if there's none).
static func land_tier(world: Object, zi: int) -> String:
	if world == null or zi < 0:
		return ""
	var rare = world.get("zone_rare")   # (the rare lands, where the world has them)
	if rare is Array and zi < rare.size() and RARE_LAND_TIER.has(int(rare[zi])):
		return RARE_LAND_TIER[int(rare[zi])]
	var biomes = world.get("zone_biome")
	if biomes is Array and zi < biomes.size():
		var b := int(biomes[zi])
		if b >= 0 and b < BIOME_TIER.size():
			return BIOME_TIER[b]
	return ""


## Draws the gem with its top-left at `at` (whole pixels). `t` is a clock in
## seconds, for the glints; `alpha` fades it with whatever it sits on.
static func draw(ci: CanvasItem, at: Vector2, tier: String, t: float, alpha: float = 1.0) -> void:
	if not SHAPES.has(tier) or alpha <= 0.0:
		return
	var base: Color = TIER_COL[tier]
	var pal := {
		"o": base.darkened(0.78),
		"L": base.lightened(0.45),
		"M": base,
		"D": base.darkened(0.38),
		"W": Color(1, 1, 0.96),
	}
	var rows: Array = SHAPES[tier]
	var w := String(rows[0]).length()
	var p0 := at.round()
	# legendary: a soft halo hugging its outline, breathing
	if tier == "LEGENDARY":
		var g := (0.3 + 0.15 * sin(t * 3.0)) * alpha
		for y in range(-1, rows.size() + 1):
			for x in range(-1, w + 1):
				if _filled(rows, x, y):
					continue
				if _filled(rows, x + 1, y) or _filled(rows, x - 1, y) or _filled(rows, x, y + 1) or _filled(rows, x, y - 1):
					ci.draw_rect(Rect2(p0 + Vector2(x, y), Vector2(1, 1)), Color(base.lightened(0.2), g))
	# a band of light that sweeps over a legendary gem every so often
	var sweep := -100.0
	if tier == "LEGENDARY":
		var ph := fmod(t, 1.8)
		if ph < 0.6:
			sweep = -3.0 + ph / 0.6 * (w + rows.size() + 3.0)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var k := row[x]
			if k == ".":
				continue
			var c: Color = pal[k]
			if k != "o" and absf(float(x + y) - sweep) < 1.5:
				c = c.lerp(Color(1, 1, 0.92), 0.7)
			ci.draw_rect(Rect2(p0 + Vector2(x, y), Vector2(1, 1)), Color(c, c.a * alpha))
	# glints: a rare gem catches the light now and then; a legendary one twinkles
	var star := Vector2(-100, -100)
	var sa := 0.0
	if tier == "RARE":
		var ph := fmod(t, 2.4)
		if ph < 0.4:
			star = p0 + Vector2(2, 1)
			sa = 1.0 - absf(ph / 0.2 - 1.0)
	elif tier == "LEGENDARY":
		var ph := fmod(t + 0.9, 1.8)
		if ph < 0.5:
			star = p0 + Vector2(w - 1, 0)
			sa = 1.0 - absf(ph / 0.25 - 1.0)
	if sa > 0.0:
		var sc := Color(1, 1, 0.92, sa * alpha)
		ci.draw_rect(Rect2(star, Vector2(1, 1)), sc)
		var reach := 2 if tier == "LEGENDARY" and sa > 0.5 else 1
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			for r in range(1, reach + 1):
				ci.draw_rect(Rect2(star + d * r, Vector2(1, 1)), Color(sc, sc.a * (0.65 if r == 1 else 0.3)))


static func _filled(rows: Array, x: int, y: int) -> bool:
	if y < 0 or y >= rows.size() or x < 0 or x >= String(rows[y]).length():
		return false
	return String(rows[y])[x] != "."
