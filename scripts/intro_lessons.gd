class_name IntroLessons
extends RefCounted
## The picture lessons in the intro. After the hero wakes, Lume takes him to
## a dark screen and shows him -- with the game's own sprites, animated --
## what he needs to survive: the lantern and matches, flares and the map,
## gates and keys, creatures and fighting, chests, and the purple gate.
##
## intro.gd calls, every frame while a lesson is up:
##   IntroLessons.draw(canvas, id, seconds_showing, stage_rect)
##   IntroLessons.cues(id, from, to)   -> sounds to play (first time through)
## Each lesson loops. The words for each one live in lore.gd (Lore.INTRO).

const ITEMS_TEX: Texture2D = preload("res://assets/items.png")
const PROPS_TEX: Texture2D = preload("res://assets/props.png")
const INSECTS_TEX: Texture2D = preload("res://assets/insects.png")
const DEMONS_TEX: Texture2D = preload("res://assets/demons.png")
const LONGMAN_TEX: Texture2D = preload("res://assets/longman.png")   # the Wolf Man
const INSECTS_BIG: Texture2D = preload("res://assets/insects_battle.png")   # 64 x 64 frames, as in battle
const DEMONS_BIG: Texture2D = preload("res://assets/demons_battle.png")     # 64 x 96 frames
const BAG_TEX: Texture2D = preload("res://assets/bag_icon.png")
## The lantern pictures share a layout: the lantern hangs at SHELF_Y, captions sit on LABEL_Y.
const SHELF_Y := 62.0
const LABEL_Y := 124.0
const BIG_CARD := Vector2(92, 50)          # the battle's move cards
const C_ATTACK := Color("ff7a4a")
const C_DEFEND := Color("6aa8ff")
const C_DODGE := Color("b8f0c8")

const C_TEXT := Color("e8dfc8")
const C_DIM := Color("8a8299")
const C_GOLD := Color("ffd35a")
const C_RED := Color("ff8a9a")
const LANTERN := Color(1.0, 0.72, 0.42)
const GREEN := Color(0.45, 1.0, 0.6)
const PURPLE := Color("a060ff")
const STONE_DK := Color("221d2e")
const KEY_COLORS := {"bronze": Color("c07a3a"), "silver": Color("c9cbd8"), "gold": Color("e8b84a")}
const FLARE := 5
const MOVE_COLORS := {"attack": Color("e0503c"), "defend": Color("4a8ad8"), "dodge": Color("4ac87a"), "item": Color("e8b84a")}

## Seconds before each lesson's animation starts over.
const LOOP := {
	"lantern": 6.0, "match": 3.6, "ghosts": 6.0,
	"flare": 4.0, "map": 6.5, "flare_ghosts": 6.0,
	"gate": 4.0, "keys": 6.0,
	"creatures": 4.0, "moves": 4.0, "clash": 9.0,
	"chest": 5.0, "items": 6.0,
	"master": 4.0, "escape": 6.0,
}
## Sounds, the first time through each lesson: [seconds, sound, volume dB].
const SOUNDS := {
	"match": [[0.72, "match_strike", -4.0]],
	"ghosts": [[3.4, "lantern_out", -6.0], [3.8, "ghost_appear", -8.0], [4.6, "match_strike", -6.0], [4.75, "ghost_scatter", -8.0]],
	"flare": [[0.45, "flare", -4.0]],
	"map": [[0.3, "page", -10.0]],
	"gate": [[0.3, "door_locked", -6.0]],
	"keys": [[1.7, "key", -6.0], [3.1, "key", -6.0], [4.5, "key", -6.0]],
	"clash": [[1.1, "hit", -8.0], [4.1, "block", -8.0], [7.1, "dodge", -8.0]],
	"chest": [[0.8, "chest_open", -4.0]],
	"master": [[0.2, "riddle", -6.0]],
	"escape": [[0.6, "chest_open", -6.0], [2.6, "correct", -4.0]],
}


## Sounds whose moment falls between `from` and `to` (seconds since the
## lesson appeared). Only the first run-through has sound.
static func cues(id: String, from: float, to: float) -> Array:
	var out := []
	for s in SOUNDS.get(id, []):
		if from < s[0] and s[0] <= to:
			out.append(s)
	return out


static func draw(c: CanvasItem, id: String, t: float, a: Rect2) -> void:
	var lt := fmod(t, float(LOOP.get(id, 6.0)))
	match id:
		"lantern": _lantern_lesson(c, t, lt, a)
		"match": _match_lesson(c, t, lt, a)
		"ghosts": _ghosts_lesson(c, t, lt, a)
		"flare": _flare_lesson(c, t, lt, a)
		"map": _map_lesson(c, t, lt, a)
		"flare_ghosts": _flare_ghosts_lesson(c, t, lt, a)
		"gate": _gate_lesson(c, t, lt, a)
		"keys": _keys_lesson(c, t, lt, a)
		"creatures": _creatures_lesson(c, t, lt, a)
		"moves": _moves_lesson(c, t, lt, a)
		"clash": _clash_lesson(c, t, lt, a)
		"chest": _chest_lesson(c, t, lt, a)
		"items": _items_lesson(c, t, lt, a)
		"master": _master_lesson(c, t, lt, a)
		"escape": _escape_lesson(c, t, lt, a)


# --- 1. The lantern -----------------------------------------------------------

## The lantern hanging in the dark, its fuel slowly burning down.
static func _lantern_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var fuel := lerpf(1.0, 0.3, _k(lt, 0.3, 5.4))
	if lt > 5.4:
		fuel = lerpf(0.3, 1.0, _ease(_k(lt, 5.4, 5.9)))
	var lp := Vector2(cx + roundf(sin(t * 1.4) * 2.0), a.position.y + SHELF_Y)
	_lantern(c, lp, Vector2(cx, a.position.y), fuel, t, 1.0)
	_fuel_bar(c, Vector2(cx, a.position.y + LABEL_Y), fuel)


## Strike a match on the box, feed it to the lantern: the light swells. The
## lantern and the matchbox stand either side of the middle, each with its
## caption on the same line beneath it.
static func _match_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var lp := Vector2(cx - 64, a.position.y + SHELF_Y)
	var bc := Vector2(cx + 64, a.position.y + SHELF_Y + 8)       # the matchbox, resting at the lantern's foot line
	var fuel := 0.15
	if lt >= 1.55:
		fuel = lerpf(0.15, 0.45, _ease(_k(lt, 1.55, 2.0)))
	if lt >= 3.3:
		fuel = lerpf(0.45, 0.15, _k(lt, 3.3, 3.6))
	var boost := 0.0
	if lt >= 1.55:
		boost = 22.0 * (1.0 - _k(lt, 1.55, 2.4))
	_lantern(c, lp, Vector2(lp.x, a.position.y), fuel, t, 1.0, boost)
	_fuel_bar(c, Vector2(lp.x, a.position.y + LABEL_Y), fuel)
	# the matchbox, lit a little from the lantern's side, its shadow on the shelf
	var lit := 0.55 + 0.45 * clampf(fuel * 1.6 + boost / 30.0, 0.0, 1.0)
	c.draw_rect(Rect2(bc.x - 22, bc.y + 14, 44, 1), Color(0, 0, 0, 0.5))
	_art(c, "matchbox", bc, Color(lit, lit * 0.95, lit * 0.9))
	_key_line(c, Vector2(bc.x, a.position.y + LABEL_Y + 2), "E", "STRIKE A MATCH")
	# the match: out of the drawer, down the striker on the box's end, alight, over to the lantern
	var striker := bc + Vector2(14, -2)
	var head := bc + Vector2(-21, -30)
	var alpha := _k(lt, 0.0, 0.3)
	if lt >= 0.25:
		head = head.lerp(striker + Vector2(0, -16), _ease(_k(lt, 0.25, 0.5)))
	if lt >= 0.5:
		head = (striker + Vector2(0, -16)).lerp(striker + Vector2(0, 6), _ease_in(_k(lt, 0.5, 0.72)))
	if lt >= 0.72:
		head = (striker + Vector2(0, 6)).lerp(striker + Vector2(-6, -22), _ease(_k(lt, 0.72, 0.95)))
	if lt >= 0.95:
		var k := _ease(_k(lt, 0.95, 1.55))
		head = (striker + Vector2(-6, -22)).lerp(lp + Vector2(10, -6), k)
		head.y -= sin(k * PI) * 26.0
	if lt >= 2.0:
		var k2 := _ease(_k(lt, 2.0, 2.6))
		head = (lp + Vector2(10, -6)).lerp(lp + Vector2(44, -26), k2)
		alpha = 1.0 - k2
	var burning := lt >= 0.72
	var flame := 1.0 - _k(lt, 2.0, 2.45)
	if lt < 2.6:
		_match(c, head.round(), burning, flame, alpha, t, lt >= 2.0)
	# sparks off the striker
	if lt >= 0.72 and lt < 1.05:
		var sk := _k(lt, 0.72, 1.05)
		for i in 8:
			var ang := -PI * 0.1 - i * 0.38
			var p := striker + Vector2(0, 4) + Vector2(cos(ang), sin(ang)) * (3.0 + sk * 15.0)
			c.draw_rect(Rect2(p.round(), Vector2(1, 1)), Color(1.0, 0.85, 0.4, 1.0 - sk))


## The Wolf Man at the edge of your light. While the lantern burns he only
## stands there, half of him caught by it and the rest lost in the dark. The
## flame dies: nothing -- only the pale point in the hole where his face
## should be, coming closer. A match flares and there he is, right in front
## of you, lit full; he shrinks back to the edge.
static func _ghosts_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var lp := Vector2(cx - 104, a.position.y + SHELF_Y - 6)
	var fuel := 0.6
	var dark := false
	if lt >= 3.3 and lt < 3.7:
		fuel = 0.6 * (1.0 - _k(lt, 3.3, 3.7)) * (0.55 + 0.45 * sin(t * 45.0))
	elif lt >= 3.7 and lt < 4.6:
		fuel = 0.0
		dark = true
	var boost := 0.0
	if lt >= 4.6:
		boost = 30.0 * (1.0 - _k(lt, 4.6, 5.3))
	var far := cx + 64.0
	var near := cx - 22.0
	var x := far
	var pose := 1 if fmod(t, 3.1) > 2.4 else 0     # now and then the head tilts and the hand lifts
	var light := 0.62 + 0.3 * fuel                 # how brightly the lantern catches him
	var body := 1.0                                # how much of him there is to see
	if lt >= 3.3 and lt < 3.7:
		light *= fuel / 0.6
	if dark:
		x = lerpf(far, near, _ease_in(_k(lt, 3.75, 4.5)))
		body = 0.07
		pose = 1
	elif lt >= 4.6:
		var back := _ease(_k(lt, 4.75, 5.6))
		x = lerpf(near, far, back)
		pose = 4 if lt < 4.95 else 1
		light = lerpf(1.1, 0.8, back)
	var breathe := roundf(sin(t * 1.7) * 1.0)
	var top := Vector2(roundf(x - IntroArt.WOLF_SIZE.x / 2.0), a.position.y + breathe)
	if body > 0.0:
		_wolf(c, top, pose, Color(light, light * 0.97, light * 1.04, body), a)
	# the pinprick deep in the hole: faint while you can see him, burning in the dark
	var ga := 1.0 if dark else (0.3 + 0.2 * sin(t * 2.3) if lt < 3.7 else 0.0)
	if ga > 0.0:
		var gp := 3 if pose != 0 else 2
		_wolf(c, top, gp, Color(1.0, 0.97, 0.85, ga), a)
		if dark:
			_glow(c, top + _wolf_eye(pose), 6.0, Color(1.0, 0.95, 0.8), 0.6)
	_lantern(c, lp, Vector2(lp.x, a.position.y), fuel, t, 1.0, boost)
	if lt >= 4.6 and lt < 5.0:
		var fk := _k(lt, 4.6, 5.0)
		c.draw_circle(lp, 40.0 * (1.0 - fk) + 8.0, Color(1.0, 0.9, 0.7, 0.4 * (1.0 - fk)))
	if dark:
		_text_c(c, cx, a.end.y - 12, "THE LIGHT IS OUT", C_RED)
	else:
		_text_c(c, cx, a.end.y - 12, "SAFE INSIDE THE LIGHT", C_DIM)


# --- 2. Flares and the map ----------------------------------------------------

## A flare drops, plants itself and burns green.
static func _flare_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var ground := Vector2(cx - 20, a.position.y + 100)
	var planted := lt >= 0.45
	var r := 0.0
	if planted:
		r = lerpf(0.0, 74.0, _ease(_k(lt, 0.45, 0.7)))
		if lt > 0.7:
			r = lerpf(74.0, 58.0, _k(lt, 0.7, 1.6))
		r += sin(t * 9.0) * 1.0
	_floor(c, ground, 150.0, 56.0, GREEN, r / 74.0)
	_glow(c, ground + Vector2(0, -16), r, GREEN, 0.9)
	var drop := 0.0 if planted else -80.0 * (1.0 - _ease_in(_k(lt, 0.0, 0.45)))
	_flare(c, ground + Vector2(0, drop), _k(lt, 0.0, 0.2))
	if planted and lt < 1.4:
		var bk := _k(lt, 0.45, 1.4)
		c.draw_arc(ground + Vector2(0, -12), 8.0 + bk * 70.0, 0.0, TAU, 40, Color(GREEN, 0.7 * (1.0 - bk)), 1.0)
	_key(c, Vector2(cx + 96, a.position.y + 90), "F", "PLANT A FLARE")


## Each flare reveals its room on the map, one after another.
static func _map_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	const CELL := 4
	const W := 34
	const H := 17
	const ROOMS := [Rect2i(1, 1, 7, 5), Rect2i(12, 1, 9, 6), Rect2i(26, 1, 7, 5),
		Rect2i(2, 10, 8, 6), Rect2i(14, 10, 8, 6), Rect2i(26, 10, 7, 6)]
	const HALLS := [[Rect2i(8, 3, 4, 1), 0], [Rect2i(21, 3, 5, 1), 1], [Rect2i(4, 6, 1, 4), 3],
		[Rect2i(16, 7, 1, 3), 4], [Rect2i(29, 6, 1, 4), 5], [Rect2i(10, 12, 4, 1), 3], [Rect2i(22, 12, 4, 1), 4]]
	const ORDER := [0, 1, 4, 3]     # rooms that get a flare, in order (2 and 5 stay unexplored)
	const WHEN := [0.3, 1.4, 2.5, 3.6]
	var cx := a.get_center().x
	var o := Vector2(roundf(cx - W * CELL / 2.0) - 14, a.position.y + 34)
	var frame := Rect2(o - Vector2(8, 8), Vector2(W * CELL + 16, H * CELL + 16))
	UiKit.panel(c, frame, "MAP")
	c.draw_rect(frame.grow(-2), Color(0.02, 0.01, 0.04))
	var shown := {}
	for i in ORDER.size():
		if lt >= WHEN[i]:
			shown[ORDER[i]] = _k(lt, WHEN[i], WHEN[i] + 0.3)
	# walls first, then floors, so a room never paints over its neighbour
	for pass_i in 2:
		for room in shown:
			var al: float = shown[room]
			var rects: Array = [ROOMS[room]]
			for h in HALLS:
				if h[1] == room:
					rects.append(h[0])
			for rr in rects:
				var px := Rect2(o + Vector2((rr as Rect2i).position) * CELL, Vector2((rr as Rect2i).size) * CELL)
				if pass_i == 0:
					c.draw_rect(px.grow(CELL / 2.0), Color(Color("2a2438"), al))
				else:
					c.draw_rect(px, Color(Color("6b6480"), al))
	# the gate on the way east, once that hall is mapped
	if shown.has(1):
		c.draw_rect(Rect2(o + Vector2(23, 3) * CELL - Vector2.ONE, Vector2(CELL + 2, CELL + 2)), Color(Color("c07a3a"), shown[1]))
	# the flares, and you beside the newest one
	var newest := -1
	for i in ORDER.size():
		if not shown.has(ORDER[i]):
			continue
		newest = ORDER[i]
		var rc := (ROOMS[ORDER[i]] as Rect2i).get_center()
		var fp := o + Vector2(rc) * CELL
		c.draw_rect(Rect2(fp, Vector2(CELL, CELL)), Color("7dff9a"))
		var since: float = lt - WHEN[i]
		if since < 0.8:
			c.draw_arc(fp + Vector2(2, 2), 3.0 + since * 18.0, 0.0, TAU, 24, Color(GREEN, 0.8 * (1.0 - since / 0.8)), 1.0)
	if newest >= 0 and fmod(t, 0.8) < 0.55:
		var hc := (ROOMS[newest] as Rect2i).get_center() + Vector2i(2, 1)
		c.draw_rect(Rect2(o + Vector2(hc) * CELL - Vector2.ONE, Vector2(CELL + 2, CELL + 2)), Color("ec6a5c"))
	_key(c, Vector2(frame.end.x + 26, frame.get_center().y - 6), "M", "MAP")
	_text_c(c, frame.get_center().x, frame.end.y + 5, "ONLY FLARED ROOMS SHOW UP", C_DIM)


## A flare's green light holds the Longman back too: it creeps up to the
## edge every few seconds, and recoils.
static func _flare_ghosts_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var ground := Vector2(cx, a.position.y + 94)
	var r := 58.0 + sin(t * 9.0) * 1.0
	_floor(c, ground, 150.0, 56.0, GREEN, 0.8)
	_glow(c, ground + Vector2(0, -16), r, GREEN, 0.9)
	_flare(c, ground, 1.0)
	var floor_y := a.position.y + 138.0
	var edge := cx - 112.0
	var x := edge
	var frame := 0 if fmod(t, 2.4) < 1.6 else 2
	var dk := fmod(lt, 3.0)
	if dk > 1.4 and dk < 2.6:
		# it gets brave, creeps toward the light, and recoils
		var k := _k(dk, 1.4, 2.6)
		x = edge + sin(k * PI) * 34.0
		frame = 4 + int(t * 7.0) % 4
	var seen := clampf(1.0 - (absf(x - cx) - r) / 50.0, 0.0, 1.0)
	var col := Color(0.3, 0.34, 0.36).lerp(Color(0.75, 1.0, 0.82), seen * 0.7)
	_longman(c, Vector2(x, floor_y), frame, false, col)
	_text_c(c, cx, a.end.y - 6, "FLARES HOLD THE WOLF MAN BACK", C_DIM)


# --- 3. Gates and keys --------------------------------------------------------

## A locked gate set in a stone wall, rattling when you try it.
static func _gate_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var base := a.position.y + 130
	_glow(c, Vector2(cx, base - 40), 96.0, LANTERN, 0.5)
	_art_feet(c, "wall", Vector2(cx, base + 1))
	var shake := roundf(sin(lt * 90.0)) if lt > 0.3 and lt < 0.6 else 0.0
	_art_feet(c, "gate_bronze", Vector2(cx + shake, base))
	if fmod(t, 1.6) < 0.8:
		_twinkle(c, Vector2(cx + 6 + shake, base - 44), C_GOLD, 1.0 - fmod(t, 1.6) / 0.8)
	_text_c(c, cx, base + 8, "LOCKED", Color("c07a3a"))


## Bronze, silver and gold gates: each key rises into its own gate's lock and
## the gate swings open.
static func _keys_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var base := a.position.y + 98
	var colors := ["bronze", "silver", "gold"]
	for i in 3:
		var col: String = colors[i]
		var x := cx + (i - 1) * 112
		var tint: Color = KEY_COLORS[col]
		var open_t := 1.2 + i * 1.4
		var is_open := lt >= open_t + 0.5
		_glow(c, Vector2(x, base - 40), 52.0, LANTERN, 0.32)
		if is_open:
			_glow(c, Vector2(x, base - 34), 34.0, tint, 0.5)
		_art_feet(c, "gate_" + col + ("_open" if is_open else ""), Vector2(x, base))
		# the key: floating below, then up into the lock (the plate right of centre)
		var lock := Vector2(x + 6, base - 36)
		var kk := _ease(_k(lt, open_t, open_t + 0.5))
		var rest := Vector2(x, base + 18 + sin(t * 3.0 + i) * 2.0)
		var kp := rest.lerp(lock + Vector2(-14, 0), kk)
		var ka := 1.0 - _k(lt, open_t + 0.4, open_t + 0.55)
		if ka > 0.0:
			_glow(c, kp, 14.0, tint, 0.5 * ka)
			_art(c, "key_" + col, kp, Color(1, 1, 1, ka))
		if lt >= open_t + 0.5 and lt < open_t + 1.1:
			var bk := _k(lt, open_t + 0.5, open_t + 1.1)
			c.draw_arc(lock, 6.0 + bk * 26.0, 0.0, TAU, 28, Color(tint, 0.8 * (1.0 - bk)), 1.0)
		_text_c(c, x, base + 30, col.to_upper(), tint)
	_key_line(c, Vector2(cx, a.end.y - 10), "Z", "FACE THE GATE WITH ITS KEY")


# --- 4. Creatures -------------------------------------------------------------

## The things that live down here: insects and demons, as you'll see them up
## close in a fight (the battle's own art).
static func _creatures_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var feet_y := a.position.y + 104
	# insects (64 x 64 battle frames)
	var gx := cx - 88
	_glow(c, Vector2(gx, feet_y - 30), 62.0, LANTERN, 0.3)
	var insects := [0, 12]
	for i in insects.size():
		var al := _k(t, 0.1 + i * 0.2, 0.45 + i * 0.2)
		var fx := gx + (i * 2 - 1) * 36
		UiKit.pedestal(c, Vector2(fx, feet_y - 2), 26, 5)
		var fr: int = [0, 2][int(t * 2.0 + i) % 2]
		c.draw_texture_rect_region(INSECTS_BIG, Rect2(Vector2(fx - 32, feet_y - 62 + roundf(sin(t * 3.0 + i) * 1.0)), Vector2(64, 64)),
			Rect2(insects[i] * 64, fr * 64, 64, 64), Color(1, 1, 1, al))
	_text_c(c, gx, feet_y + 6, "INSECTS", C_GOLD)
	_text_c(c, gx, feet_y + 16, "IN LIGHT AND DARK", C_DIM)
	# demons (64 x 96 battle frames)
	var dx := cx + 88
	_glow(c, Vector2(dx, feet_y - 44), 62.0, Color("ff5a6a"), 0.22)
	var demons := [0, 8]
	for i in demons.size():
		var al2 := _k(t, 0.6 + i * 0.2, 0.95 + i * 0.2)
		var fx2 := dx + (i * 2 - 1) * 36
		UiKit.pedestal(c, Vector2(fx2, feet_y - 2), 26, 5)
		var fr2: int = [0, 2][int(t * 1.6 + i) % 2]
		c.draw_texture_rect_region(DEMONS_BIG, Rect2(Vector2(fx2 - 32, feet_y - 94 + roundf(sin(t * 2.0 + i) * 1.0)), Vector2(64, 96)),
			Rect2(demons[i] * 64, fr2 * 96, 64, 96), Color(1, 1, 1, al2))
	_text_c(c, dx, feet_y + 6, "DEMONS", C_RED)
	_text_c(c, dx, feet_y + 16, "THEY HUNT BY NIGHT", C_DIM)
	_text_c(c, cx, a.end.y - 12, "TOUCH ONE - OR LET IT TOUCH YOU - AND THE FIGHT BEGINS", C_DIM)


## The battle's move deck: three big cards, each with the number that matters
## and what it costs you; your bag beneath them.
static func _moves_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var moves := ["attack", "defend", "dodge"]
	const GAP := 6.0
	var total := 3 * BIG_CARD.x + 2 * GAP
	var sel := int(lt) % 4    # attack, defend, dodge, then the bag
	var y0 := a.position.y + 42
	_text_c(c, cx, a.position.y + 6, "YOU BOTH CHOOSE IN SECRET...", C_DIM)
	_text_c(c, cx, a.position.y + 16, "...THEN BOTH ARE REVEALED", C_DIM)
	# the creature's tell, on its banner, like in a fight
	var band := Rect2(24, y0 - 15, 312, 11)
	c.draw_rect(band, Color(0.02, 0.01, 0.04, 0.78))
	c.draw_rect(Rect2(band.position, Vector2(band.size.x, 1)), Color(C_GOLD, 0.45))
	_text_c(c, cx, band.position.y + 2, "THE PALE SPIDER REARS BACK...", C_GOLD)
	for i in 3:
		var k := _ease(_k(t, 0.15 * i, 0.15 * i + 0.4))
		var x := floorf(cx - total / 2.0 + i * (BIG_CARD.x + GAP))
		var picked := sel == i and t > 1.0
		var r := Rect2(Vector2(x, y0 + (1.0 - k) * 16.0 - (5.0 if picked else 0.0)), BIG_CARD)
		_big_card(c, r, moves[i], picked, k, t)
	# the bag, beneath
	var br := Rect2(cx - 32, y0 + BIG_CARD.y + 10, 64, 14)
	var on_bag := sel == 3 and t > 1.0
	c.draw_rect(br.grow(1), Color("0a070f"))
	c.draw_rect(br, C_GOLD if on_bag else Color("5a5170"))
	c.draw_rect(br.grow(-1), Color("2a2038") if on_bag else Color("17121f"))
	c.draw_texture_rect_region(BAG_TEX, Rect2(br.position + Vector2(3, -4), Vector2(16, 16)), Rect2(0, 0, 16, 16))
	PixelFont.draw(c, br.position + Vector2(23, 4), "BAG", C_GOLD if on_bag else C_TEXT)
	PixelFont.draw(c, Vector2(br.end.x - 4 - PixelFont.width_of("DOWN"), br.position.y + 4), "DOWN", C_DIM)
	if on_bag:
		_text_c(c, cx, br.end.y + 5, "DRINK A TONIC OR FLARE YOUR LANTERN: IT TAKES YOUR TURN", C_DIM)


## One of the battle's move cards (as battle.gd draws them), with sample numbers:
## your ATK 2, DEF 1 against a creature with ATK 3, DEF 1.
static func _big_card(c: CanvasItem, r: Rect2, move: String, picked: bool, alpha: float, t: float) -> void:
	var col: Color = {"attack": C_ATTACK, "defend": C_DEFEND, "dodge": C_DODGE}[move]
	var pulse := 0.5 + 0.5 * sin(t * 6.0)
	if picked:
		_glow(c, r.get_center(), r.size.x * 0.62, col, 0.8 * alpha)
	c.draw_rect(r.grow(1), Color(0.02, 0.01, 0.04, alpha))
	c.draw_rect(r, Color(C_GOLD.lerp(col, 0.35 * pulse) if picked else col.darkened(0.5), alpha))
	c.draw_rect(r.grow(-1), Color(Color("100b18"), alpha))
	for i in 6:
		c.draw_rect(Rect2(r.position + Vector2(1, 13 + i * 6), Vector2(r.size.x - 2, 6)),
			Color(col, (0.09 - i * 0.012) * (1.6 if picked else 1.0) * alpha))
	var head := Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 12))
	c.draw_rect(head, Color(col, (0.38 if picked else 0.16) * alpha))
	var label := move.to_upper()
	var name_col := col.lightened(0.35) if picked else col.darkened(0.1)
	_big_text(c, head.position + Vector2(floorf((head.size.x - PixelFont.width_of(label) * 2) / 2.0), 1), label, Color(name_col, alpha))
	var ib := Rect2(r.position + Vector2(4, 15), Vector2(32, 32))
	c.draw_rect(ib.grow(1), Color(col.darkened(0.55), alpha))
	c.draw_rect(ib, Color(Color("07050b"), alpha))
	match move:
		"attack": _icon(c, "hatchet", ib.get_center(), 2, alpha)
		"defend": _icon(c, "leather_vest", ib.get_center(), 2, alpha)
		"dodge": _dodge_icon(c, ib.get_center(), col, alpha)
	var tx := r.position.x + 41
	var lines: Array = {"attack": ["2", "ATK", "HITS FOR 2", "GUARDED: 1"],
		"defend": ["1", "DEF", "IF HIT: -2", "NOT -3"],
		"dodge": ["50%", "", "DODGED: -0", "ELSE: -3"]}[move]
	_big_text(c, Vector2(tx, r.position.y + 16), lines[0], Color(C_TEXT if picked else C_TEXT.darkened(0.25), alpha))
	if lines[1] != "":
		PixelFont.draw(c, Vector2(tx + PixelFont.width_of(lines[0]) * 2 + 3, r.position.y + 21), lines[1], Color(col, alpha))
	PixelFont.draw(c, Vector2(tx, r.position.y + 31), lines[2], Color(C_TEXT if picked else C_DIM, alpha))
	PixelFont.draw(c, Vector2(tx, r.position.y + 39), lines[3], Color(C_DIM, alpha))
	if not picked:
		c.draw_rect(r, Color(0.02, 0.01, 0.04, 0.3 * alpha))


static func _big_text(c: CanvasItem, pos: Vector2, text: String, col: Color) -> void:
	c.draw_set_transform(pos.round(), 0.0, Vector2(2, 2))
	PixelFont.draw(c, Vector2.ZERO, text, col, Color(0, 0, 0, col.a * 0.8))
	c.draw_set_transform(Vector2.ZERO)


## Three rounds as a fight shows them -- you (from behind) on the left, the
## creature on its stone on the right, both cards flipping together, then the
## blows: attack/attack, defend/attack, dodge/attack.
static func _clash_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var rnd := int(lt / 3.0)
	var rt := fmod(lt, 3.0)
	var yours: String = ["attack", "defend", "dodge"][rnd]
	var top := a.position.y
	var hero_feet := Vector2(cx - 112, top + 122)
	var foe_feet := Vector2(cx + 100, top + 96)
	# the blows: both lunge in at 1.1s and spring back
	var lunge := 0.0
	if rt >= 0.95 and rt < 1.6:
		lunge = sin(_k(rt, 0.95, 1.6) * PI)
	var hit := rt >= 1.1 and rt < 1.4
	var dodged := yours == "dodge" and int(t / 9.0) % 2 == 0
	# the creature (it always attacks here)
	UiKit.pedestal(c, foe_feet + Vector2(0, -2), 30, 6)
	var fr: int = (int(t * 8.0) % 4) if lunge > 0.0 else [0, 2][int(t * 2.0) % 2]
	var fp := foe_feet - Vector2(32, 96) + Vector2(-36, 22) * lunge
	var shake_foe := roundf(sin(rt * 80.0) * 2.0) if hit and yours == "attack" else 0.0
	c.draw_texture_rect_region(DEMONS_BIG, Rect2((fp + Vector2(shake_foe, 0)).round(), Vector2(64, 96)), Rect2(0, fr * 96, 64, 96))
	# you, from behind
	UiKit.pedestal(c, hero_feet + Vector2(0, -2), 30, 6)
	var hp := hero_feet - Vector2(32, 96)
	if yours == "attack":
		hp += Vector2(30, -18) * lunge
	elif yours == "dodge" and lunge > 0.0:
		hp += Vector2(-18 if dodged else -4, 0) * lunge
	var hurt := hit and _hurts(yours, 0) and not dodged
	if hurt:
		hp.x += roundf(sin(rt * 80.0) * 2.0)
	HeroLook.draw_big(c, hp.round(), 1, "leather_vest", "hatchet")
	if yours == "defend" and rt >= 1.0 and rt < 1.6:
		c.draw_arc(hero_feet + Vector2(0, -48), 34.0, 0.0, TAU, 36, Color(C_DEFEND, 0.7 * (1.0 - _k(rt, 1.3, 1.6))), 2.0)
	# the two cards between you, face down, then flipped together
	var flip := _k(rt, 0.5, 0.8)
	var sx := absf(cos(flip * PI))
	var face := flip >= 0.5
	for side in 2:
		var x := cx - 22 if side == 0 else cx + 22
		var mv: String = yours if side == 0 else "attack"
		var w := maxf(36.0 * sx, 2.0)
		_card(c, Rect2(roundf(x - w / 2.0), top + 6, roundf(w), 50), mv, face, 1.0 - _k(rt, 1.0, 1.2) * 0.4, false)
	_text_c(c, cx, top + 26, "VS", C_DIM)
	# what happened
	if rt >= 1.1:
		var lift := -_k(rt, 1.1, 1.9) * 10.0
		var al := 1.0 - _k(rt, 2.2, 2.8)
		var hy := hero_feet.y - 100 + lift
		match yours:
			"attack":
				_text_c(c, hero_feet.x, hy, "-3", Color(C_RED, al))
				_text_c(c, foe_feet.x, foe_feet.y - 90 + lift, "-2", Color(C_RED, al))
			"defend":
				_text_c(c, hero_feet.x, hy, "-2", Color(Color("8ab8ff"), al))
			"dodge":
				_text_c(c, hero_feet.x, hy, "MISS!" if dodged else "-3", Color(Color("8affb0") if dodged else C_RED, al))
	if rt >= 1.0:
		var lines: Dictionary = {
			"attack": "ATTACK VS ATTACK: YOU BOTH TAKE A FULL HIT",
			"defend": "DEFEND: ONLY ITS ATK MINUS YOUR DEF GETS THROUGH",
			"dodge": "DODGE: A COIN FLIP - DODGE IT ALL, OR TAKE IT ALL",
		}
		_text_c(c, cx, a.end.y - 12, lines[yours], Color(C_TEXT, _k(rt, 1.0, 1.3)))


static func _hurts(yours: String, side: int) -> bool:
	match yours:
		"attack": return true
		"defend": return side == 0
		"dodge": return side == 0
	return false


# --- 5. Chests ----------------------------------------------------------------

## A chest bursts open and its loot flies out.
static func _chest_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var feet := Vector2(cx - 20, a.position.y + 128)
	var opened := lt >= 0.8
	_glow(c, feet + Vector2(0, -24), 50.0, LANTERN, 0.3)
	if opened:
		_glow(c, feet + Vector2(0, -30), 30.0 + 50.0 * (1.0 - _k(lt, 0.8, 1.8)), C_GOLD, 0.7)
	var shake := roundf(sin(lt * 70.0)) if lt > 0.4 and lt < 0.8 else 0.0
	c.draw_rect(Rect2(feet.x - 24, feet.y, 48, 1), Color(0, 0, 0, 0.5))
	_art_feet(c, "chest_open" if opened else "chest", feet + Vector2(shake, 0))
	var loot := ["hatchet", "chain_shirt", "healing_tonic", "lamp_oil", "matches", "bronze_key"]
	for i in loot.size():
		var ft := _k(lt, 0.9 + i * 0.1, 1.5 + i * 0.1)
		if ft <= 0.0:
			continue
		var target := Vector2(cx - 20 + (i - 2.5) * 40, a.position.y + 26)
		var p := (feet + Vector2(0, -26)).lerp(target, _ease(ft))
		p.y -= sin(ft * PI) * 26.0
		_glow(c, p, 12.0, C_GOLD, 0.25 * ft)
		_icon(c, loot[i], p, 2)
	_key(c, Vector2(cx + 80, a.position.y + 112), "Z", "OPEN")


## What chests hold, sorted on four shelves.
static func _items_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var shelves := [
		["GEAR", ["hatchet", "iron_mace", "chain_shirt", "iron_plate"], "STRONGER"],
		["HEALING", ["healing_tonic", "red_berry"], "MEND WOUNDS"],
		["LIGHT", ["lamp_oil", "matches", "flare", "storm_lantern"], "FEED THE FLAME"],
		["AND MORE", ["bomb", "windbreak", "blue_berry", "sunstone"], "STRANGE THINGS"],
	]
	for si in shelves.size():
		var sh: Array = shelves[si]
		var r := Rect2(roundf(cx - 172 + (si % 2) * 176), a.position.y + 6 + (si / 2) * 74, 168, 64)
		UiKit.panel(c, r, sh[0])
		var ids: Array = sh[1]
		for j in ids.size():
			var k := _k(t, 0.2 + si * 0.35 + j * 0.08, 0.45 + si * 0.35 + j * 0.08)
			var p := Vector2(r.get_center().x + (j - (ids.size() - 1) / 2.0) * 38, r.position.y + 28 + (1.0 - k) * 4.0)
			UiKit.pedestal(c, p + Vector2(0, 14), 12, 3)
			_icon(c, ids[j], p, 2, k)
		_text_c(c, r.get_center().x, r.end.y - 10, sh[2], Color(C_DIM, _k(t, 0.5 + si * 0.35, 0.8 + si * 0.35)))


# --- 6. The way out -----------------------------------------------------------

## The purple gate of the master chamber, glowing in its wall.
static func _master_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var base := a.position.y + 130
	var pulse := 0.5 + 0.5 * sin(t * 2.5)
	_glow(c, Vector2(cx, base - 56), 84.0 + pulse * 8.0, PURPLE, 0.75)
	_art_feet(c, "wall", Vector2(cx, base + 1), Color(0.72, 0.62, 0.95))
	_art_feet(c, "master", Vector2(cx, base))
	# the eye in the door breathes
	_glow(c, Vector2(cx, base - 54), 10.0 + pulse * 4.0, Color("c8a0ff"), 0.5)
	for i in 16:
		var ox := float((i * 37) % 130) - 65.0
		var y := base - fmod(t * (10.0 + i % 5 * 3.0) + i * 23.0, 112.0)
		var al := clampf((y - (base - 112)) / 40.0, 0.0, 1.0) * 0.8
		c.draw_rect(Rect2(Vector2(cx + ox + sin(t + i) * 3.0, y).round(), Vector2(1, 1)), Color(Color("d8b8ff"), al))
	_text_c(c, cx, base + 8, "THE MASTER CHAMBER", Color("c8a0ff"))


## Purple chest -> purple key -> purple gate -> home.
static func _escape_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var ground := a.position.y + 112
	var chest_p := Vector2(cx - 112, ground)
	var key_p := Vector2(cx, ground - 30)
	var gate_p := Vector2(cx + 112, ground)
	var opened := lt >= 0.6
	# the chest
	_glow(c, chest_p + Vector2(0, -20), 30.0, PURPLE, 0.3)
	if opened:
		_glow(c, chest_p + Vector2(0, -26), 20.0 + 30.0 * (1.0 - _k(lt, 0.6, 1.4)), PURPLE, 0.6)
	_art_feet(c, "chest_purple_open" if opened else "chest_purple", chest_p)
	# the gate: it opens on warm light when the key reaches it
	var freed := lt >= 2.6
	var warm := Color(1.0, 0.86, 0.6)
	_glow(c, gate_p + Vector2(0, -40), 44.0 + (24.0 * (1.0 - _k(lt, 2.6, 3.4)) if freed else 0.0), warm if freed else PURPLE, 0.8 if freed else 0.45)
	_art_feet(c, "master_small_open" if freed else "master_small", gate_p)
	if freed and lt < 3.0:
		var fk := _k(lt, 2.6, 3.0)
		c.draw_rect(Rect2(gate_p + Vector2(-20, -70), Vector2(40, 66)), Color(1, 0.97, 0.9, 0.7 * (1.0 - fk)))
	# arrows between
	for i in 2:
		var ax := cx + (i * 2 - 1) * 58
		var hot := (i == 0 and lt >= 0.8 and lt < 1.5) or (i == 1 and lt >= 2.0 and lt < 2.6)
		_chevrons(c, Vector2(ax, key_p.y), Color(Color("c8a0ff"), 1.0 if hot else 0.3))
	# the key: out of the chest, a pause in the middle, into the gate
	_art(c, "key_purple", key_p, Color(1, 1, 1, 0.16))
	var kp := Vector2.ZERO
	var ka := 0.0
	if lt >= 0.7 and lt < 2.6:
		ka = 1.0
		if lt < 1.5:
			var k := _ease(_k(lt, 0.8, 1.5))
			kp = (chest_p + Vector2(0, -26)).lerp(key_p, k)
			kp.y -= sin(k * PI) * 20.0
		elif lt < 2.0:
			kp = key_p + Vector2(0, sin(t * 4.0) * 2.0)
		else:
			var k2 := _ease(_k(lt, 2.0, 2.6))
			kp = key_p.lerp(gate_p + Vector2(0, -44), k2)
			kp.y -= sin(k2 * PI) * 20.0
			ka = 1.0 - _k(lt, 2.45, 2.6)
	if ka > 0.0:
		_glow(c, kp, 16.0, PURPLE, 0.6 * ka)
		_art(c, "key_purple", kp.round(), Color(1, 1, 1, ka))
	_text_c(c, chest_p.x, ground + 8, "PURPLE CHEST", C_DIM)
	_text_c(c, key_p.x, ground + 8, "MASTER KEY", C_DIM)
	_text_c(c, gate_p.x, ground + 8, "PURPLE GATE", C_DIM)
	if freed:
		_text_c(c, gate_p.x, ground - 92, "HOME", Color(Color("ffe6b0"), _k(lt, 2.8, 3.3)))


# --- Drawing helpers ----------------------------------------------------------

## A picture from intro_art.png at its own size, centred on `center`.
static func _art(c: CanvasItem, name: String, center: Vector2, mod := Color.WHITE) -> void:
	var src := IntroArt.rect(name)
	c.draw_texture_rect_region(IntroArt.TEX, Rect2((center - src.size / 2.0).round(), src.size), src, mod)


## ...or standing with its bottom edge on `feet`.
static func _art_feet(c: CanvasItem, name: String, feet: Vector2, mod := Color.WHITE) -> void:
	var src := IntroArt.rect(name)
	c.draw_texture_rect_region(IntroArt.TEX, Rect2((feet - Vector2(src.size.x / 2.0, src.size.y)).round(), src.size), src, mod)


## One frame of the Wolf Man (intro_wolfman.png: 0/1 by lantern, 2/3 their
## glints, 4 caught in a match's flare) with its top-left at `top`, cut off at
## the stage's edges.
static func _wolf(c: CanvasItem, top: Vector2, frame: int, col: Color, a: Rect2) -> void:
	var size := IntroArt.WOLF_SIZE
	var dst := Rect2(top, size)
	var clip := dst.intersection(a)
	if clip.size.x <= 0.0 or clip.size.y <= 0.0:
		return
	var src := Rect2(Vector2(frame * size.x, 0) + (clip.position - dst.position), clip.size)
	c.draw_texture_rect_region(IntroArt.WOLF, clip, src, col)


## Where the pinprick sits in the frame (to hang a glow on it in the dark).
static func _wolf_eye(pose: int) -> Vector2:
	return Vector2(63, 49) if pose == 0 else Vector2(70, 51)


## A texture region scaled up and centred on `center`.
static func _tex(c: CanvasItem, tex: Texture2D, src: Rect2, center: Vector2, s: float, mod := Color.WHITE) -> void:
	var size := src.size * s
	c.draw_texture_rect_region(tex, Rect2((center - size / 2.0).round(), size), src, mod)


static func _icon(c: CanvasItem, id: String, center: Vector2, s: float, alpha := 1.0) -> void:
	_tex(c, ITEMS_TEX, Rect2(int(Items.DATA[id].icon) * 16, 0, 16, 16), center, s, Color(1, 1, 1, alpha))


## The Longman (longman.png, 80 x 80 frames), standing on `feet`; `flip`
## turns it to face left.
static func _longman(c: CanvasItem, feet: Vector2, frame: int, flip: bool, col: Color) -> void:
	var src := Rect2(frame * 80, 0, 80, 80)
	var dst := Rect2((feet - Vector2(40, 80)).round(), Vector2(80, 80))
	if flip:
		dst.size.x = -80.0   # (drawn mirrored in the same place)
	c.draw_texture_rect_region(LONGMAN_TEX, dst, src, col)


static func _flare(c: CanvasItem, ground: Vector2, alpha: float) -> void:
	_tex(c, PROPS_TEX, Rect2(FLARE * 16, 0, 16, 16), ground + Vector2(0, -20), 3.0, Color(1, 1, 1, alpha))


## A soft pool of light in layered rings.
static func _glow(c: CanvasItem, center: Vector2, r: float, col: Color, strength := 1.0) -> void:
	if r < 1.0:
		return
	for i in 7:
		c.draw_circle(center, r * (1.0 - i / 7.0), Color(col, 0.055 * strength))


## The lantern on its chain, its light sized by its fuel: the brass body, the
## flame inside the glass, then the cage bars and glints over it.
static func _lantern(c: CanvasItem, lp: Vector2, anchor: Vector2, fuel: float, t: float, s := 1.0, boost := 0.0) -> void:
	var lit := fuel > 0.0
	var flick := sin(t * 13.0) * 1.2 + sin(t * 7.3) * 0.8
	if fuel < 0.25:
		flick *= 2.5
	var r := (16.0 + 50.0 * fuel + flick) * s + boost if lit else 0.0
	_glow(c, lp, r, LANTERN, 1.0)
	_glow(c, lp, r * 0.45, Color(1.0, 0.9, 0.7), 0.7)
	# chain, down to the ring
	var top := anchor.y
	var bottom := lp.y - 22.0
	var y := top
	var n := 0
	while y < bottom:
		var k := (y - top) / maxf(bottom - top, 1.0)
		var x := roundf(lerpf(anchor.x, lp.x, k))
		if n % 2 == 0:
			c.draw_rect(Rect2(x - 1, y, 3, 3), Color("2a2230"))
			c.draw_rect(Rect2(x, y, 1, 3), Color("8a7a60"))
		else:
			c.draw_rect(Rect2(x - 1, y + 1, 3, 1), Color("5e5242"))
		y += 3.0
		n += 1
	var body_col := Color(0.55, 0.5, 0.55) if not lit else Color.WHITE.lerp(Color(1.0, 0.95, 0.85), 0.5)
	_art(c, "lantern", lp, body_col)
	if lit:
		# warm glass, then the flame on its wick (the glass spans y -8..+11 about the centre)
		var gc := lp + Vector2(0, 1)
		var warm := clampf(0.25 + fuel * 0.6 + boost / 40.0, 0.0, 1.0)
		c.draw_rect(Rect2(gc.x - 9, gc.y - 9, 19, 19), Color(1.0, 0.62, 0.25, 0.22 * warm))
		var f := clampf(0.35 + fuel * 0.75 + boost / 30.0, 0.3, 1.3) * (0.92 + 0.08 * sin(t * 23.0))
		var base := lp + Vector2(0, 9)
		var sway := roundf(sin(t * 9.0) * 0.7)
		var h := 4.0 + 9.0 * f
		for i in int(h):
			var k := float(i) / h
			var w := (1.0 - k) * (2.6 + 1.6 * f) * (0.6 + 0.4 * sin(k * PI))
			var x := base.x + sway * k
			var col := Color(1.0, 0.45, 0.12).lerp(Color(1.0, 0.86, 0.4), clampf(1.0 - k * 1.4, 0.0, 1.0))
			c.draw_rect(Rect2(roundf(x - w), base.y - i, maxf(roundf(w * 2.0), 1.0), 1), col)
		var core := clampf(h * 0.45, 2.0, 6.0)
		c.draw_rect(Rect2(base.x - 1, base.y - core, 2, core), Color(1.0, 0.97, 0.85))
	_art(c, "lantern_front", lp, body_col)


static func _fuel_bar(c: CanvasItem, center: Vector2, fuel: float) -> void:
	var br := Rect2(roundf(center.x - 36 + 11), center.y, 72, 4)
	PixelFont.draw(c, Vector2(br.position.x - 22, br.position.y - 1), "FUEL", C_DIM)
	UiKit.bar(c, br, fuel, Color("f5a33a"))


## A match, head up at `h`. `flame` 0..1 is how big the flame is; `burnt`
## once it's done its work.
static func _match(c: CanvasItem, h: Vector2, lit: bool, flame: float, alpha: float, t: float, burnt := false) -> void:
	_art(c, "match_burnt" if burnt else "match", h + Vector2(0, 10), Color(1, 1, 1, alpha))
	if lit and flame > 0.0:
		var f := flame * (0.9 + 0.1 * sin(t * 30.0))
		var top := h + Vector2(roundf(sin(t * 17.0) * 0.6), -4)
		_glow(c, top, 14.0 * f, LANTERN, 0.8 * alpha)
		c.draw_circle(top, 3.5 * f, Color(1.0, 0.5, 0.15, 0.9 * alpha))
		c.draw_circle(top + Vector2(0, -1), 2.2 * f, Color(1.0, 0.82, 0.35, alpha))
		c.draw_circle(top + Vector2(0, -2), 1.0 * f, Color(1.0, 0.97, 0.85, alpha))


## Flagstones on the floor, lit from the middle.
static func _floor(c: CanvasItem, center: Vector2, w: float, h: float, col: Color, light: float) -> void:
	var rx := w / 2.0
	var ry := h / 2.0
	var gy := -ry
	var row := 0
	while gy < ry:
		var gx := -rx + (7.0 if row % 2 == 1 else 0.0)
		while gx < rx:
			var cxp := gx + 7.0
			var cyp := gy + 4.0
			var d := (cxp * cxp) / (rx * rx) + (cyp * cyp) / (ry * ry)
			if d < 1.0:
				var f := (1.0 - d) * light
				var base := STONE_DK.lerp(col.darkened(0.55), clampf(f * 0.75, 0.0, 1.0))
				var tile := Rect2((center + Vector2(gx, gy)).round(), Vector2(13, 8))
				c.draw_rect(tile, Color(base, clampf(1.0 - d, 0.0, 1.0) * 0.9 + 0.1))
				c.draw_rect(Rect2(tile.position, Vector2(13, 1)), Color(1, 1, 1, 0.05 * f))
			gx += 14.0
		gy += 9.0
		row += 1


## A face-up (or face-down) fight card.
static func _card(c: CanvasItem, r: Rect2, move: String, face: bool, alpha: float, hi: bool) -> void:
	var col: Color = MOVE_COLORS[move]
	c.draw_rect(r.grow(1), Color(Color("0a070f"), alpha))
	c.draw_rect(r, Color(col if (face and hi) else Color("5a5170"), alpha))
	if not face:
		c.draw_rect(r.grow(-1), Color(Color("2a2038"), alpha))
		var cc := r.get_center()
		for i in 3:
			var s := 4.0 + i * 5.0
			c.draw_rect(Rect2(cc.x - s / 2.0, cc.y - s / 2.0, s, s), Color(Color("3e3352"), alpha * (0.9 - i * 0.25)), false, 1.0)
		PixelFont.draw(c, (cc - Vector2(1, 2)).round(), "?", Color(C_DIM, alpha))
		return
	c.draw_rect(r.grow(-1), Color(Color("1d1727"), alpha))
	c.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 2)), Color(col, alpha))
	if r.size.x < 30.0:
		return   # mid-flip: too narrow for the art
	var ic := r.position + Vector2(r.size.x / 2.0, 26)
	match move:
		"attack": _icon(c, "hatchet", ic, 2, alpha)
		"defend": _icon(c, "leather_vest", ic, 2, alpha)
		"item": _icon(c, "healing_tonic", ic, 2, alpha)
		"dodge": _dodge_icon(c, ic, col, alpha)
	var label := move.to_upper()
	PixelFont.draw(c, Vector2(roundf(r.get_center().x - PixelFont.width_of(label) / 2.0), r.end.y - 11), label, Color(col.lightened(0.3), alpha))


static func _dodge_icon(c: CanvasItem, center: Vector2, col: Color, alpha: float) -> void:
	for k in 3:
		var x := center.x - 9 + k * 7
		for j in 5:
			var off := 4 - absi(j - 2) * 2
			c.draw_rect(Rect2(x + off, center.y - 5 + j * 2, 2, 2), Color(col, alpha * (0.45 + k * 0.27)))


static func _chevrons(c: CanvasItem, center: Vector2, col: Color) -> void:
	for k in 2:
		var x := center.x - 5 + k * 5
		for j in 5:
			var off := 2 - absi(j - 2)
			c.draw_rect(Rect2(x + off, center.y - 5 + j * 2, 2, 2), col)


static func _twinkle(c: CanvasItem, p: Vector2, col: Color, k: float) -> void:
	var s := roundf(1.0 + k * 3.0)
	c.draw_rect(Rect2(p.x - s, p.y, s * 2 + 1, 1), Color(col, k))
	c.draw_rect(Rect2(p.x, p.y - s, 1, s * 2 + 1), Color(col, k))


## A keyboard key, with an optional caption under it.
static func _key(c: CanvasItem, center: Vector2, label: String, caption := "") -> void:
	var w := PixelFont.width_of(label) + 6
	var r := Rect2((center - Vector2(w, 9) / 2.0).round(), Vector2(w, 9))
	c.draw_rect(Rect2(r.position + Vector2(0, 1), r.size), Color("0a070f"))
	c.draw_rect(r, Color("a89ec0"))
	c.draw_rect(r.grow(-1), Color("2a2038"))
	PixelFont.draw(c, r.position + Vector2(3, 2), label, C_TEXT)
	if caption != "":
		_text_c(c, center.x, r.end.y + 4, caption, C_DIM)


## A key followed by what it does, centred as one line.
static func _key_line(c: CanvasItem, center: Vector2, label: String, text: String) -> void:
	var kw := PixelFont.width_of(label) + 6
	var total := kw + 5 + PixelFont.width_of(text)
	var x := roundf(center.x - total / 2.0)
	_key(c, Vector2(x + kw / 2.0, center.y), label)
	PixelFont.draw(c, Vector2(x + kw + 5, roundf(center.y - 2)), text, C_DIM)


static func _text_c(c: CanvasItem, center_x: float, y: float, text: String, col: Color) -> void:
	PixelFont.draw(c, Vector2(roundf(center_x - PixelFont.width_of(text) / 2.0), roundf(y)), text, col)


static func _k(t: float, from: float, to: float) -> float:
	return clampf((t - from) / (to - from), 0.0, 1.0)


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


static func _ease_in(x: float) -> float:
	return x * x
