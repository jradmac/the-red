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
const DOORS_TEX: Texture2D = preload("res://assets/doors.png")
const MASTER_TEX: Texture2D = preload("res://assets/master.png")
const INSECTS_TEX: Texture2D = preload("res://assets/insects.png")
const DEMONS_TEX: Texture2D = preload("res://assets/demons.png")
const LONGMAN_TEX: Texture2D = preload("res://assets/longman.png")

const C_TEXT := Color("e8dfc8")
const C_DIM := Color("8a8299")
const C_GOLD := Color("ffd35a")
const C_RED := Color("ff8a9a")
const LANTERN := Color(1.0, 0.72, 0.42)
const GREEN := Color(0.45, 1.0, 0.6)
const PURPLE := Color("a060ff")
const STONE := Color("3a3448")
const STONE_DK := Color("221d2e")
const STONE_HI := Color("4a4458")
const KEY_COLORS := {"bronze": Color("c07a3a"), "silver": Color("c9cbd8"), "gold": Color("e8b84a")}
const DOOR_COLUMN := {"bronze": 0, "silver": 2, "gold": 4}   # columns in doors.png
const DOOR_OPEN := 6
const CHEST_CLOSED := 8   # columns in props.png
const CHEST_OPEN := 9
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
	var lp := Vector2(cx + roundf(sin(t * 1.4) * 2.0), a.position.y + 70)
	_lantern(c, lp, Vector2(cx, a.position.y), fuel, t, 1.0)
	_fuel_bar(c, Vector2(cx, a.end.y - 16), fuel)


## Strike a match on the box, feed it to the lantern: the light swells.
static func _match_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var lp := Vector2(cx - 56, a.position.y + 70)
	var box := Vector2(cx + 70, a.position.y + 96)
	var fuel := 0.15
	if lt >= 1.55:
		fuel = lerpf(0.15, 0.45, _ease(_k(lt, 1.55, 2.0)))
	if lt >= 3.3:
		fuel = lerpf(0.45, 0.15, _k(lt, 3.3, 3.6))
	var boost := 0.0
	if lt >= 1.55:
		boost = 22.0 * (1.0 - _k(lt, 1.55, 2.4))
	_lantern(c, lp, Vector2(lp.x, a.position.y), fuel, t, 1.0, boost)
	_fuel_bar(c, Vector2(lp.x, a.end.y - 16), fuel)
	# the matchbox and its key
	_icon(c, "matches", box, 3)
	_key(c, box + Vector2(0, 32), "E", "STRIKE A MATCH")
	# the match: rises over the box, swipes down its side, catches, flies to the lantern
	var head := box + Vector2(-26, -50)
	var alpha := _k(lt, 0.0, 0.3)
	if lt >= 0.5:
		head = head.lerp(box + Vector2(-26, -16), _ease_in(_k(lt, 0.5, 0.75)))
	if lt >= 0.75:
		head = (box + Vector2(-26, -16)).lerp(box + Vector2(-34, -40), _ease(_k(lt, 0.75, 0.95)))
	if lt >= 0.95:
		var k := _ease(_k(lt, 0.95, 1.55))
		head = (box + Vector2(-34, -40)).lerp(lp + Vector2(22, -2), k)
		head.y -= sin(k * PI) * 26.0
	if lt >= 2.0:
		var k2 := _ease(_k(lt, 2.0, 2.6))
		head = (lp + Vector2(22, -2)).lerp(lp + Vector2(52, -18), k2)
		alpha = 1.0 - k2
	var lit := lt >= 0.72
	var flame := 1.0 - _k(lt, 2.0, 2.45)
	if lt < 2.6:
		_match(c, head.round(), lit, flame, alpha, t)
	# sparks off the striker
	if lt >= 0.72 and lt < 1.05:
		var sk := _k(lt, 0.72, 1.05)
		var at := box + Vector2(-26, -16)
		for i in 7:
			var ang := -PI * 0.15 - i * 0.42
			var p := at + Vector2(cos(ang), sin(ang)) * (4.0 + sk * 16.0)
			c.draw_rect(Rect2(p.round(), Vector2(1, 1)), Color(1.0, 0.85, 0.4, 1.0 - sk))


## The Longman waits at the edge of the light. Let it die and it comes.
static func _ghosts_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var lp := Vector2(cx, a.position.y + 74)
	var fuel := 0.6
	var dark := false
	if lt >= 3.3 and lt < 3.7:
		fuel = 0.6 * (1.0 - _k(lt, 3.3, 3.7)) * (0.55 + 0.45 * sin(t * 45.0))
	elif lt >= 3.7 and lt < 4.6:
		fuel = 0.0
		dark = true
	var boost := 0.0
	if lt >= 4.6:
		boost = 26.0 * (1.0 - _k(lt, 4.6, 5.2))
	_lantern(c, lp, Vector2(cx, a.position.y), fuel, t, 1.0, boost)
	# where it stands: just outside the light, on the right, feet on the floor
	var floor_y := a.position.y + 138.0
	var edge := cx + 104.0
	var near := cx + 34.0
	var x := edge
	var frame := 0 if fmod(t, 2.4) < 1.6 else 2   # standing, now and then tilting its head
	var walk := int(t * 7.0) % 4
	if lt >= 3.75 and lt < 3.9:
		frame = 8                                   # it drops onto all fours
	elif lt >= 3.9 and lt < 4.6:
		x = lerpf(edge, near, _ease(_k(lt, 3.9, 4.55)))
		frame = 9 + walk                            # and comes
	elif lt >= 4.6 and lt < 5.5:
		x = lerpf(near, edge, _ease(_k(lt, 4.62, 5.4)))
		frame = 9 + walk                            # the light comes back: it backs away
	# lit only as far as the light reaches it: at the edge, a pale shape in the dark
	var r := (16.0 + 50.0 * fuel) + boost if fuel > 0.0 else 0.0
	var seen := clampf(1.0 - (absf(x - cx) - r) / 60.0, 0.0, 1.0)
	var col := Color(0.46, 0.43, 0.54).lerp(Color(1.0, 0.92, 0.82), seen * 0.8)
	if dark:
		col = Color(0.55, 0.52, 0.6)
	_longman(c, Vector2(x, floor_y), frame, x > cx, col)
	if lt >= 4.6 and lt < 5.0:
		var fk := _k(lt, 4.6, 5.0)
		c.draw_circle(lp, 34.0 * (1.0 - fk) + 8.0, Color(1.0, 0.9, 0.7, 0.45 * (1.0 - fk)))
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
	_text_c(c, cx, a.end.y - 6, "FLARES HOLD THE LONGMAN BACK", C_DIM)


# --- 3. Gates and keys --------------------------------------------------------

## A locked gate in a stone wall, rattling.
static func _gate_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var base := a.position.y + 126
	_wall(c, Rect2(cx - 110, base - 104, 220, 104), STONE)
	_glow(c, Vector2(cx, base - 30), 80.0, LANTERN, 0.45)
	var shake := roundf(sin(lt * 90.0)) if lt > 0.3 and lt < 0.6 else 0.0
	var dst := Rect2(cx - 32 + shake, base - 96, 64, 96)
	c.draw_texture_rect_region(DOORS_TEX, dst, Rect2(DOOR_COLUMN.bronze * 16, 0, 16, 24))
	if fmod(t, 1.6) < 0.8:
		_twinkle(c, Vector2(cx + 2 + shake, base - 50), C_GOLD, 1.0 - fmod(t, 1.6) / 0.8)
	c.draw_rect(Rect2(cx - 110, base, 220, 1), Color("0a070f"))
	_text_c(c, cx, base + 8, "LOCKED", Color("c07a3a"))


## Bronze, silver and gold gates: each key flies into its own gate.
static func _keys_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var top := a.position.y + 18
	var colors := ["bronze", "silver", "gold"]
	for i in 3:
		var col: String = colors[i]
		var x := cx + (i - 1) * 100
		var tint: Color = KEY_COLORS[col]
		c.draw_rect(Rect2(x - 26, top - 4, 52, 58), Color("0a070f"))
		_wall(c, Rect2(x - 25, top - 3, 50, 56), STONE)
		var open_t := 1.2 + i * 1.4
		var is_open := lt >= open_t + 0.5
		if is_open:
			_glow(c, Vector2(x, top + 26), 30.0, tint, 0.5)
		var colm: int = DOOR_OPEN if is_open else DOOR_COLUMN[col]
		c.draw_texture_rect_region(DOORS_TEX, Rect2(x - 16, top + 4, 32, 48), Rect2(colm * 16, 0, 16, 24))
		var kk := _ease(_k(lt, open_t, open_t + 0.5))
		var kp := Vector2(x, top + 80 + sin(t * 3.0 + i) * 2.0 * (1.0 - kk)).lerp(Vector2(x, top + 30), kk)
		var ka := 1.0 - _k(lt, open_t + 0.4, open_t + 0.55)
		if ka > 0.0:
			_glow(c, kp, 14.0, tint, 0.5 * ka)
			_icon(c, col + "_key", kp, 2, ka)
		if lt >= open_t + 0.5 and lt < open_t + 1.1:
			var bk := _k(lt, open_t + 0.5, open_t + 1.1)
			c.draw_arc(Vector2(x, top + 30), 6.0 + bk * 26.0, 0.0, TAU, 28, Color(tint, 0.8 * (1.0 - bk)), 1.0)
		_text_c(c, x, top + 100, col.to_upper(), tint)
	_key_line(c, Vector2(cx, a.end.y - 14), "Z", "FACE THE GATE WITH ITS KEY")


# --- 4. Creatures -------------------------------------------------------------

## The things that live down here: insects and demons.
static func _creatures_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var y := a.position.y + 62
	# insects (16x16 frames, 4 rows of animation)
	var gx := cx - 86
	_glow(c, Vector2(gx, y), 54.0, LANTERN, 0.35)
	var insects := [0, 2, 12]
	for i in insects.size():
		var al := _k(t, 0.1 + i * 0.15, 0.4 + i * 0.15)
		var p := Vector2(gx + (i - 1) * 34, y - absf(sin(t * 6.0 + i * 1.7)) * 2.0)
		var fr := int(t * 5.0 + i) % 4
		_tex(c, INSECTS_TEX, Rect2(insects[i] * 16, fr * 16, 16, 16), p, 2.0, Color(1, 1, 1, al))
	_text_c(c, gx, y + 30, "INSECTS", C_GOLD)
	_text_c(c, gx, y + 40, "IN LIGHT AND DARK", C_DIM)
	# demons (16x24 frames)
	var dx := cx + 86
	_glow(c, Vector2(dx, y), 54.0, Color("ff5a6a"), 0.25)
	var demons := [0, 4, 8]
	for i in demons.size():
		var al2 := _k(t, 0.6 + i * 0.15, 0.9 + i * 0.15)
		var p2 := Vector2(dx + (i - 1) * 34 + roundf(sin(t * 1.5 + i) * 1.0), y - 6)
		var fr2 := int(t * 3.0 + i) % 4
		_tex(c, DEMONS_TEX, Rect2(demons[i] * 16, fr2 * 24, 16, 24), p2, 2.0, Color(1, 1, 1, al2))
	_text_c(c, dx, y + 30, "DEMONS", C_RED)
	_text_c(c, dx, y + 40, "THEY HUNT BY NIGHT", C_DIM)
	_key_line(c, Vector2(cx, a.end.y - 14), "SPACE", "CHARGE A DEMON IN YOUR LIGHT")


## The four moves you can pick each round of a fight.
static func _moves_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var moves := ["attack", "defend", "dodge", "item"]
	const CW := 46
	const CH := 62
	var total := 4 * CW + 3 * 10
	for i in 4:
		var k := _ease(_k(t, 0.15 * i, 0.15 * i + 0.4))
		var x := cx - total / 2.0 + i * (CW + 10)
		var y := a.position.y + 34 + (1.0 - k) * 18.0
		var hi := int(lt) % 4 == i and t > 1.0
		if hi:
			y -= 4.0
		_card(c, Rect2(roundf(x), roundf(y), CW, CH), moves[i], true, k, hi)
	_text_c(c, cx, a.position.y + 120, "YOU BOTH CHOOSE IN SECRET...", C_DIM)
	_text_c(c, cx, a.position.y + 130, "...THEN BOTH ARE REVEALED", C_DIM)


## Three clashes, one after another: attack/attack, defend/attack, dodge/attack.
static func _clash_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var rnd := int(lt / 3.0)
	var rt := fmod(lt, 3.0)
	var yours: String = ["attack", "defend", "dodge"][rnd]
	var top := a.position.y + 8
	var lx := cx - 72
	var rx := cx + 72
	# who's who
	_text_c(c, lx, top + 40, "YOU", C_GOLD)
	var fr := int(t * 3.0) % 4
	_tex(c, DEMONS_TEX, Rect2(2 * 16, fr * 24, 16, 24), Vector2(rx, top + 24), 2.0)
	if rt < 0.9:
		_text_c(c, rx, top + 2, "IT REARS BACK...", C_RED)
	# the cards: face down, flip together, then the blows land
	var flip := _k(rt, 0.6, 0.9)
	var sx := absf(cos(flip * PI))
	var face := flip >= 0.5
	for side in 2:
		var x := lx if side == 0 else rx
		var mv: String = yours if side == 0 else "attack"
		var w := maxf(46.0 * sx, 2.0)
		var shake := 0.0
		var hit := rt >= 1.1 and rt < 1.4
		if hit and _hurts(yours, side):
			shake = roundf(sin(rt * 80.0) * 2.0)
		_card(c, Rect2(roundf(x - w / 2.0 + shake), top + 50, roundf(w), 62), mv, face, 1.0, false)
	_text_c(c, cx, top + 78, "VS", C_DIM)
	# what happened
	if rt >= 1.1:
		var pk := _k(rt, 1.1, 1.9)
		var lift := Vector2(0, -pk * 10.0)
		var al := 1.0 - _k(rt, 2.2, 2.8)
		match yours:
			"attack":
				_text_c(c, lx - 36, top + 78 + lift.y, "-5", Color(C_RED, al))
				_text_c(c, rx + 36, top + 78 + lift.y, "-4", Color(C_RED, al))
			"defend":
				_text_c(c, lx - 36, top + 78 + lift.y, "-2", Color(Color("8ab8ff"), al))
			"dodge":
				var missed := int(t / 9.0) % 2 == 0
				_text_c(c, lx - 36, top + 78 + lift.y, "MISS!" if missed else "-5", Color(Color("8affb0") if missed else C_RED, al))
	if rt >= 1.0:
		var lines := {
			"attack": "ATTACK VS ATTACK: YOU BOTH TAKE A FULL HIT",
			"defend": "DEFEND: ONLY ITS ATK MINUS YOUR DEF GETS THROUGH",
			"dodge": "DODGE: A COIN FLIP - DODGE IT ALL, OR TAKE IT ALL",
		}
		_text_c(c, cx, top + 126, lines[yours], Color(C_TEXT, _k(rt, 1.0, 1.3)))


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
	var cp := Vector2(cx - 20, a.position.y + 104)
	var opened := lt >= 0.8
	if opened:
		_glow(c, cp + Vector2(0, -10), 30.0 + 50.0 * (1.0 - _k(lt, 0.8, 1.8)), C_GOLD, 0.7)
	var shake := roundf(sin(lt * 70.0)) if lt > 0.4 and lt < 0.8 else 0.0
	_tex(c, PROPS_TEX, Rect2((CHEST_OPEN if opened else CHEST_CLOSED) * 16, 0, 16, 16), cp + Vector2(shake, 0), 4.0)
	var loot := ["hatchet", "chain_shirt", "healing_tonic", "lamp_oil", "matches", "bronze_key"]
	for i in loot.size():
		var ft := _k(lt, 0.9 + i * 0.1, 1.5 + i * 0.1)
		if ft <= 0.0:
			continue
		var target := Vector2(cx - 20 + (i - 2.5) * 40, a.position.y + 26)
		var p := (cp + Vector2(0, -20)).lerp(target, _ease(ft))
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

## The purple gate of the master chamber, glowing.
static func _master_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var base := a.position.y + 126
	_wall(c, Rect2(cx - 110, base - 104, 220, 104), STONE.lerp(PURPLE, 0.12))
	var pulse := 0.5 + 0.5 * sin(t * 2.5)
	_glow(c, Vector2(cx, base - 48), 76.0 + pulse * 8.0, PURPLE, 0.75)
	c.draw_texture_rect_region(MASTER_TEX, Rect2(cx - 32, base - 96, 64, 96), Rect2(0, 0, 16, 24))
	for i in 16:
		var ox := float((i * 37) % 130) - 65.0
		var y := base - fmod(t * (10.0 + i % 5 * 3.0) + i * 23.0, 112.0)
		var al := clampf((y - (base - 112)) / 40.0, 0.0, 1.0) * 0.8
		c.draw_rect(Rect2(Vector2(cx + ox + sin(t + i) * 3.0, y).round(), Vector2(1, 1)), Color(Color("d8b8ff"), al))
	c.draw_rect(Rect2(cx - 110, base, 220, 1), Color("0a070f"))
	_text_c(c, cx, base + 8, "THE MASTER CHAMBER", Color("c8a0ff"))


## Purple chest -> purple key -> purple gate -> out.
static func _escape_lesson(c: CanvasItem, t: float, lt: float, a: Rect2) -> void:
	var cx := a.get_center().x
	var y := a.position.y + 70
	var chest_p := Vector2(cx - 112, y + 12)
	var key_p := Vector2(cx, y)
	var gate_p := Vector2(cx + 112, y)
	var opened := lt >= 0.6
	# the chest
	if opened:
		_glow(c, chest_p, 20.0 + 30.0 * (1.0 - _k(lt, 0.6, 1.4)), PURPLE, 0.6)
	_tex(c, MASTER_TEX, Rect2(32 if opened else 16, 8, 16, 16), chest_p, 3.0)
	# the gate (it flares when the key reaches it)
	var freed := lt >= 2.6
	_glow(c, gate_p, 40.0 + (24.0 * (1.0 - _k(lt, 2.6, 3.4)) if freed else 0.0), PURPLE, 0.8 if freed else 0.45)
	_tex(c, MASTER_TEX, Rect2(0, 0, 16, 24), gate_p, 3.0)
	if freed and lt < 3.0:
		var fk := _k(lt, 2.6, 3.0)
		c.draw_rect(Rect2(gate_p - Vector2(24, 36), Vector2(48, 72)), Color(1, 1, 1, 0.6 * (1.0 - fk)))
	# arrows between
	for i in 2:
		var ax := cx + (i * 2 - 1) * 56
		var lit := (i == 0 and lt >= 0.8 and lt < 1.5) or (i == 1 and lt >= 2.0 and lt < 2.6)
		_chevrons(c, Vector2(ax, y), Color(Color("c8a0ff"), 1.0 if lit else 0.3))
	# the key: out of the chest, a pause in the middle, into the gate
	_icon(c, "purple_key", key_p, 3, 0.18)
	var kp := Vector2.ZERO
	var ka := 0.0
	if lt >= 0.7 and lt < 2.6:
		ka = 1.0
		if lt < 1.5:
			var k := _ease(_k(lt, 0.8, 1.5))
			kp = (chest_p + Vector2(0, -14)).lerp(key_p, k)
			kp.y -= sin(k * PI) * 20.0
		elif lt < 2.0:
			kp = key_p + Vector2(0, sin(t * 4.0) * 2.0)
		else:
			var k2 := _ease(_k(lt, 2.0, 2.6))
			kp = key_p.lerp(gate_p, k2)
			kp.y -= sin(k2 * PI) * 20.0
			ka = 1.0 - _k(lt, 2.45, 2.6)
	if ka > 0.0:
		_glow(c, kp, 16.0, PURPLE, 0.6 * ka)
		_icon(c, "purple_key", kp, 3, ka)
	_text_c(c, chest_p.x, y + 44, "PURPLE CHEST", C_DIM)
	_text_c(c, key_p.x, y + 44, "MASTER KEY", C_DIM)
	_text_c(c, gate_p.x, y + 44, "PURPLE GATE", C_DIM)
	if freed:
		_text_c(c, gate_p.x, y - 52, "FREEDOM", Color(Color("e8d0ff"), _k(lt, 2.8, 3.3)))


# --- Drawing helpers ----------------------------------------------------------

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


## The lantern on its chain, its light sized by its fuel.
static func _lantern(c: CanvasItem, lp: Vector2, anchor: Vector2, fuel: float, t: float, s := 1.0, boost := 0.0) -> void:
	var lit := fuel > 0.0
	var flick := sin(t * 13.0) * 1.2 + sin(t * 7.3) * 0.8
	if fuel < 0.25:
		flick *= 2.5
	var r := (16.0 + 50.0 * fuel + flick) * s + boost if lit else 0.0
	_glow(c, lp, r, LANTERN, 1.0)
	_glow(c, lp, r * 0.45, Color(1.0, 0.9, 0.7), 0.7)
	# chain
	var top := anchor.y
	var bottom := lp.y - 26.0
	var y := top
	var n := 0
	while y < bottom:
		var k := (y - top) / maxf(bottom - top, 1.0)
		var x := roundf(lerpf(anchor.x, lp.x, k))
		c.draw_rect(Rect2(x - 1, y, 2, 3), Color("6e6584") if n % 2 == 0 else Color("4a4458"))
		y += 3.0
		n += 1
	_icon(c, "brass_lantern", lp, 4, 1.0)
	if not lit:
		_tex(c, ITEMS_TEX, Rect2(int(Items.DATA.brass_lantern.icon) * 16, 0, 16, 16), lp, 4.0, Color(0.05, 0.04, 0.1, 0.6))


static func _fuel_bar(c: CanvasItem, center: Vector2, fuel: float) -> void:
	var br := Rect2(roundf(center.x - 36), center.y, 72, 4)
	PixelFont.draw(c, Vector2(br.position.x - 22, br.position.y - 1), "FUEL", C_DIM)
	UiKit.bar(c, br, fuel, Color("f5a33a"))


## A match, head up. `flame` 0..1 is how big the flame is.
static func _match(c: CanvasItem, h: Vector2, lit: bool, flame: float, alpha: float, t: float) -> void:
	c.draw_rect(Rect2(h.x - 1, h.y + 2, 2, 22), Color(Color("d8b884"), alpha))
	c.draw_rect(Rect2(h.x, h.y + 2, 1, 22), Color(Color("a88454"), alpha))
	c.draw_rect(Rect2(h.x - 2, h.y - 1, 4, 4), Color(Color("c0302a"), alpha))
	c.draw_rect(Rect2(h.x - 2, h.y - 1, 2, 1), Color(Color("e05a4a"), alpha))
	if lit and flame > 0.0:
		var f := flame * (0.9 + 0.1 * sin(t * 30.0))
		var top := h + Vector2(roundf(sin(t * 17.0) * 0.6), -3)
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


## A stone wall of staggered blocks, fading into the dark at the sides.
static func _wall(c: CanvasItem, r: Rect2, col: Color) -> void:
	var y := r.position.y
	var row := 0
	while y < r.end.y:
		var x := r.position.x - (8.0 if row % 2 == 1 else 0.0)
		var i := 0
		while x < r.end.x:
			var bx := maxf(x, r.position.x)
			var bw := minf(x + 16.0, r.end.x) - bx
			var shade := float(((row * 7 + i * 13) % 5)) * 0.03
			var edge := minf(bx - r.position.x, r.end.x - (bx + bw))
			var fade := clampf(edge / 40.0, 0.0, 1.0)
			var bc := col.darkened(0.1 + shade)
			c.draw_rect(Rect2(bx, y, bw - 1, 7), Color(bc, fade))
			c.draw_rect(Rect2(bx, y, bw - 1, 1), Color(col.lightened(0.15), fade * 0.6))
			x += 16.0
			i += 1
		y += 8.0
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
		"attack": _icon(c, "grave_blade", ic, 2, alpha)
		"defend": _icon(c, "iron_plate", ic, 2, alpha)
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
