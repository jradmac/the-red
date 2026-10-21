class_name JournalScreen
extends CanvasLayer
## Red's journal, from the title screen: everything she has ever found, kept
## across every run (Profile). Her portrait and her tally on the left; on the
## right, bookmarked pages -- CREATURES (insects and demons, each from common
## to legendary), GEAR (weapons and armor) and LANDS -- with a slot for every one in the game,
## found or not, framed in its rarity's colour. What she hasn't found is only a
## shadow. Pick one and its trading card comes up, big, everything on it: the
## picture, its rarity, its stats, its story. The rarer the card, the more its
## foil shines; one not yet collected shows only its back.

signal closed

const C_BG_TOP := Color("0d0818")
const C_BG_BOT := Color("040208")
const C_PANEL := Color("120d1f")
const C_PANEL_HI := Color("1b1430")
const C_EDGE := Color("2e2545")
const C_SLOT := Color("0a0712")
const C_TEXT := Color("e8dfc8")
const C_DIM := Color("8a8299")
const C_FAINT := Color("4a4260")
const C_PICK := Color("ffd35a")
const C_BRASS := Color("b8904a")
const C_SHADOW := Color(0.13, 0.11, 0.19)
## The creatures as they look walking about the labyrinth (Enemy: insects 24 x
## 24, demons 24 x 32; rows 0-3 walking toward you).
const INSECTS: Texture2D = preload("res://assets/insects_walk.png")
const DEMONS: Texture2D = preload("res://assets/demons_walk.png")
const INSECTS_BIG: Texture2D = preload("res://assets/insects_battle.png")   # 64 x 64
const DEMONS_BIG: Texture2D = preload("res://assets/demons_battle.png")     # 64 x 96
const PAGES := ["CREATURES", "GEAR", "LANDS"]
const LANDS_TEX: Texture2D = preload("res://assets/journal_lands.png")   ## 92 x 98 floating islands (tools/make_land_islands.py)
const LANDS_SMALL: Texture2D = preload("res://assets/journal_lands_small.png")   ## 30 x 33, for the grid
const LAND_SMALL := Vector2(30, 33)
const LAND := Vector2(92, 98)
const PANEL := Rect2(6, 20, 72, 196)    # Red's panel
const BOOK := Rect2(82, 33, 273, 146)   # the page the slots sit on (under the bookmarks)
const GRID := Vector2(86, 44)           # the slots start here
## The creatures page: insects on the left, demons on the right, each in
## order from common to legendary.
const SIDE_COLS := {"insect": 6, "demon": 5}
const CREATURE_CELL := Vector2(24, 31)
const CREATURE_TOP := 50.0
const DEMON_X := GRID.x + 6 * 24 + 3
const CELL := {"CREATURES": Vector2(25, 31), "GEAR": Vector2(37, 32), "LANDS": Vector2(37, 44)}
## The gear page: weapons on the left, armor on the right.
const GEAR_COLS := {"weapon": 4, "armor": 2}
const ARMOR_X := GRID.x + 4 * 37 + 22
const COLS := {"CREATURES": 10, "GEAR": 4, "LANDS": 7}
## The trading card, as it comes up.
const CARD := Vector2(150, 222)

var _page := 0
var _sel := 0
var _on_tabs := false
var _detail := false
var _time := 0.0
var _t_detail := 0.0
var _canvas: Node2D
var _ready_frame := -1
var _creatures: Array = []
var _weapons: Array = []
var _card_fx: Node2D
var _glow: Texture2D   # one soft round glow (white; tinted where it's drawn)
var _motes: Array[Dictionary] = []
var _card_at := Vector2.ZERO      # the card's centre this frame
var _card_sx := 1.0               # its width as it flips (1 = face on)
var _card_zoom := 1.0             # it grows a little as it comes up
var _card_face := true            # showing the front (false: the back)
var _card_tier := "COMMON"
## Opened in the middle of a run (from the bag) rather than the title: cards
## found since you last looked shimmer, NEW on them, until you open them.
var in_game := false
var _new_banner := ""          # on the card now open: "NEW CREATURE DEFEATED!" etc.
var _new_t := 0.0


func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.35))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	_glow = gt
	_creatures = JournalData.creatures()
	# insects first, then demons; each from common to legendary (and among one
	# rarity, the more common ones first)
	_creatures.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] == "insect"
		var ta := JournalData.TIERS.find(a[3])
		var tb := JournalData.TIERS.find(b[3])
		if ta != tb:
			return ta < tb
		var ra: float = CreatureData.TYPES[a[0]][a[1]].get("rarity", 0.0)
		var rb: float = CreatureData.TYPES[b[0]][b[1]].get("rarity", 0.0)
		return ra > rb)
	_weapons = JournalData.weapons() + JournalData.armor()   # (the gear page: weapons, then armor)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 46:   # dust and embers drifting up through the dark
		_motes.append({"p": Vector2(rng.randf_range(0, 360), rng.randf_range(0, 240)),
			"v": rng.randf_range(2.0, 7.0), "ph": rng.randf() * TAU, "warm": rng.randf() < 0.55,
			"big": rng.randf() < 0.15})
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_page)
	add_child(_canvas)
	_card_fx = Node2D.new()   # the cards' foil, added on top
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_card_fx.material = add
	_card_fx.draw.connect(_draw_card_fx)
	add_child(_card_fx)
	_ready_frame = Engine.get_process_frames()
	Sfx.play("page")


func _count() -> int:
	return _total(PAGES[_page])


func _total(page: String) -> int:
	match page:
		"CREATURES": return _creatures.size()
		"GEAR": return _weapons.size()
	return JournalData.LANDS.size()


func _pressed(action: String) -> bool:
	if Input.is_action_just_pressed(action):
		return true
	return InputMap.has_action("p2_" + action) and Input.is_action_just_pressed("p2_" + action)


func _process(delta: float) -> void:
	_time += delta
	_t_detail += delta
	_new_t += delta
	_canvas.queue_redraw()
	_card_fx.queue_redraw()
	if Engine.get_process_frames() <= _ready_frame + 1:
		return
	var back := _pressed("run") or _pressed("inventory") or Input.is_action_just_pressed("ui_cancel")
	if _detail:
		if back or _pressed("confirm"):
			_detail = false
			Sfx.play("ui_back")
		elif _pressed("move_left") or _pressed("move_right"):   # flip through them
			_sel = posmod(_sel + (1 if _pressed("move_right") else -1), _count())
			_t_detail = 0.0
			Sfx.play("page", -6.0)
			_card_shown()
		return
	if back:
		Sfx.play("ui_back")
		set_process(false)
		closed.emit()
		return
	if _on_tabs:
		if _pressed("move_left") or _pressed("move_right"):
			_page = posmod(_page + (1 if _pressed("move_right") else -1), PAGES.size())
			_sel = 0
			Sfx.play("page", -4.0)
		elif _pressed("move_down") or _pressed("confirm"):
			_on_tabs = false
			Sfx.play("ui_move")
		return
	var moved := true
	if _pressed("move_left"):
		_sel = _nearest(Vector2.LEFT)
	elif _pressed("move_right"):
		_sel = _nearest(Vector2.RIGHT)
	elif _pressed("move_up"):
		var up := _nearest(Vector2.UP)
		if up == _sel:
			_on_tabs = true
		else:
			_sel = up
	elif _pressed("move_down"):
		_sel = _nearest(Vector2.DOWN)
	else:
		moved = false
	if moved:
		Sfx.play("ui_move", -6.0)
	if _pressed("confirm"):
		_detail = true
		_t_detail = 0.0
		Sfx.play("ui_select")
		_card_shown()


# --- what each slot is -----------------------------------------------------------------

## Slot i's key among the new cards (Profile.is_new).
func _key(i: int) -> String:
	match PAGES[_page]:
		"CREATURES": return "c:" + String(_creatures[i][2])
		"LANDS": return "l:" + String(JournalData.LANDS[i][0])
	return ("a:" if _armor(_weapons[i]) else "w:") + String(_weapons[i])


func _is_new(i: int) -> bool:
	return in_game and Profile.is_new(_key(i))


## A card comes up: if it's a new one, say so (once) -- it isn't new after.
func _card_shown() -> void:
	_new_banner = ""
	if not _is_new(_sel):
		return
	match PAGES[_page]:
		"CREATURES": _new_banner = "NEW CREATURE DEFEATED!"
		"LANDS": _new_banner = "NEW LAND FOUND!"
		_: _new_banner = "NEW ARMOR FOUND!" if _armor(_weapons[_sel]) else "NEW WEAPON FOUND!"
	_new_t = 0.0
	Profile.clear_new(_key(_sel))
	Sfx.play("correct", -4.0)


## [name, tier, found] for slot i of the current page.
func _entry(i: int) -> Array:
	if PAGES[_page] == "CREATURES":
		var c: Array = _creatures[i]
		return [c[2], c[3], Profile.kills(c[2]) > 0]
	if PAGES[_page] == "LANDS":
		var l: Array = JournalData.LANDS[i]
		return [l[1], l[2], Profile.has_land(l[0])]
	var id: String = _weapons[i]
	if _armor(id):
		return [String(Items.DATA[id].name), String(JournalData.ARMOR_INFO[id][0]), Profile.has_armor(id)]
	return [String(Items.DATA[id].name), String(JournalData.WEAPON_INFO[id][0]), Profile.has_weapon(id)]


func _armor(id: String) -> bool:
	return Items.kind(id) == "armor"


func _has_gear(id: String) -> bool:
	return Profile.has_armor(id) if _armor(id) else Profile.has_weapon(id)


func _found_count(page: String) -> int:
	var n := 0
	if page == "CREATURES":
		for c in _creatures:
			if Profile.kills(c[2]) > 0:
				n += 1
	elif page == "LANDS":
		for l in JournalData.LANDS:
			if Profile.has_land(l[0]):
				n += 1
	else:
		for id in _weapons:
			if _has_gear(id):
				n += 1
	return n


# --- drawing ---------------------------------------------------------------------------

func _draw_page() -> void:
	var size := _canvas.get_viewport_rect().size
	_draw_backdrop(size)
	_draw_header(size)
	_draw_portrait()
	_draw_book()
	_draw_tabs()
	_draw_grid()
	_draw_info(size)
	if _detail:
		_draw_detail(size)
	else:
		_controls(size, [["ARROWS", "MOVE"], ["Z", "VIEW CARD"], ["UP", "PAGES"], ["X", "BACK"]])


## The dark, a lantern's warmth low on the left, and motes drifting up.
func _draw_backdrop(size: Vector2) -> void:
	var bands := 12
	for i in bands:
		var y0 := size.y * i / bands
		_canvas.draw_rect(Rect2(0, y0, size.x, size.y / bands + 1), C_BG_TOP.lerp(C_BG_BOT, float(i) / (bands - 1)))
	_canvas.draw_texture_rect(_glow, Rect2(Vector2(42, 92) - Vector2(90, 90), Vector2(180, 180)), false, Color(1.0, 0.5, 0.18, 0.10))
	_canvas.draw_texture_rect(_glow, Rect2(Vector2(230, 110) - Vector2(150, 110), Vector2(300, 220)), false, Color(0.45, 0.3, 0.8, 0.06))
	for m in _motes:
		var p: Vector2 = m.p
		p.y = fposmod(p.y - _time * float(m.v), size.y + 10.0) - 5.0
		p.x += sin(_time * 0.6 + float(m.ph)) * 4.0
		var tw := 0.35 + 0.35 * sin(_time * 2.0 + float(m.ph))
		var col := Color(1.0, 0.7, 0.35, tw * 0.55) if m.warm else Color(0.6, 0.48, 0.95, tw * 0.4)
		_canvas.draw_rect(Rect2(p.round(), Vector2(2, 2) if m.big else Vector2.ONE), col)


## RED'S JOURNAL, between two gilded rules, and how much of it is filled.
func _draw_header(size: Vector2) -> void:
	var title := "RED'S JOURNAL"
	var cx := size.x / 2.0
	var tw := PixelFont.width_of(title)
	PixelFont.draw(_canvas, Vector2(floorf(cx - tw / 2.0), 5), title, C_PICK, Color(0.3, 0.12, 0.0, 0.9))
	for side: float in [-1.0, 1.0]:   # rules running out from the title, fading, a diamond at the inner end
		var x0 := cx + side * (tw / 2.0 + 6)
		for k in 60:
			var a := 0.75 * (1.0 - k / 60.0)
			_canvas.draw_rect(Rect2(x0 + side * k - (1 if side < 0 else 0), 8, 1, 1), Color(C_BRASS, a))
		_diamond(Vector2(x0, 8.5), 2.0, C_PICK)
	# the whole collection, top right
	var found := 0
	var total := 0
	for page in PAGES:
		found += _found_count(page)
		total += _total(page)
	var pct := "%d%%" % int(round(100.0 * found / maxf(total, 1)))
	PixelFont.draw(_canvas, Vector2(size.x - 8 - PixelFont.width_of(pct), 5), pct, C_TEXT)
	var lab := "COLLECTED"
	PixelFont.draw(_canvas, Vector2(size.x - 12 - PixelFont.width_of(pct) - PixelFont.width_of(lab), 5), lab, C_FAINT)
	var lab2 := "%d / %d" % [found, total]
	PixelFont.draw(_canvas, Vector2(8, 5), lab2, C_FAINT)


func _diamond(c: Vector2, r: float, col: Color) -> void:
	_canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)


## A panel: dark, a lit top edge, brass corners.
func _panel(r: Rect2, corners := true) -> void:
	_canvas.draw_rect(r, C_PANEL)
	_canvas.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), C_PANEL_HI.lightened(0.15))
	_frame(r, C_EDGE)
	_canvas.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1)), C_PANEL_HI)
	if corners:
		for c in [r.position, Vector2(r.end.x - 1, r.position.y), Vector2(r.position.x, r.end.y - 1), r.end - Vector2.ONE]:
			var sx := 1.0 if c.x == r.position.x else -1.0
			var sy := 1.0 if c.y == r.position.y else -1.0
			_canvas.draw_rect(Rect2(c, Vector2(1, 1)), C_PICK)
			for k in range(1, 4):
				_canvas.draw_rect(Rect2(c + Vector2(sx * k, 0), Vector2.ONE), Color(C_BRASS, 1.0 - k * 0.22))
				_canvas.draw_rect(Rect2(c + Vector2(0, sy * k), Vector2.ONE), Color(C_BRASS, 1.0 - k * 0.22))


## Red herself, in her lantern's light, and her tally.
func _draw_portrait() -> void:
	var r := PANEL
	_panel(r)
	PixelFont.draw(_canvas, Vector2(r.position.x + 6, r.position.y + 5), "RED", C_PICK)
	var jt := "JOURNEY %d" % maxi(Profile.number("runs"), 1 if Profile.intro_seen() else 0)
	PixelFont.draw(_canvas, Vector2(r.end.x - 5 - PixelFont.width_of(jt), r.position.y + 5), jt, C_FAINT)
	var mid := Vector2(r.get_center().x, r.position.y + 64)
	var flick := 0.9 + 0.1 * sin(_time * 7.0) * sin(_time * 3.1)
	_canvas.draw_texture_rect(_glow, Rect2(mid - Vector2(40, 40), Vector2(80, 80)), false, Color(1.0, 0.55, 0.2, 0.26 * flick))
	_canvas.draw_texture_rect(_glow, Rect2(mid + Vector2(-22, 40), Vector2(44, 9)), false, Color(0, 0, 0, 0.6))   # her shadow
	HeroLook.use(null)
	var bob := roundf(sin(_time * 1.6) * 1.0)
	HeroLook.draw_big(_canvas, Vector2(r.position.x + 4, r.position.y + 14), 0, "worn_cloak", _best_weapon(), bob)
	# the tally
	var y := r.position.y + 116
	_canvas.draw_rect(Rect2(r.position.x + 6, y - 4, r.size.x - 12, 1), C_EDGE)
	var rows := [["DEATHS", str(Profile.number("deaths")), Color("ff8a9a")], ["KILLS", str(Profile.total_kills()), Color("ffb070")]]
	for row in rows:
		_canvas.draw_rect(Rect2(r.position.x + 6, y + 1, 3, 3), row[2])
		PixelFont.draw(_canvas, Vector2(r.position.x + 12, y), row[0], C_DIM)
		PixelFont.draw(_canvas, Vector2(r.end.x - 6 - PixelFont.width_of(row[1]), y), row[1], C_TEXT)
		y += 10
	y += 3
	_canvas.draw_rect(Rect2(r.position.x + 6, y - 3, r.size.x - 12, 1), C_EDGE)
	for i in PAGES.size():
		var page: String = PAGES[i]
		var total := _total(page)
		var found := _found_count(page)
		var on := i == _page
		PixelFont.draw(_canvas, Vector2(r.position.x + 6, y + 1), page, C_TEXT if on else C_DIM)
		var s := "%d/%d" % [found, total]
		PixelFont.draw(_canvas, Vector2(r.end.x - 6 - PixelFont.width_of(s), y + 1), s, C_PICK if found == total else (C_TEXT if on else C_DIM))
		var bw := r.size.x - 12
		var fill := roundf(bw * found / maxf(total, 1))
		_canvas.draw_rect(Rect2(r.position.x + 6, y + 8, bw, 3), C_SLOT)
		_canvas.draw_rect(Rect2(r.position.x + 6, y + 8, fill, 3), Color(C_PICK, 0.85 if on else 0.5))
		_canvas.draw_rect(Rect2(r.position.x + 6, y + 8, fill, 1), Color(1, 0.95, 0.75, 0.6 if on else 0.3))
		y += 16


## The page the slots sit on.
func _draw_book() -> void:
	_panel(BOOK)
	_canvas.draw_texture_rect(_glow, Rect2(BOOK.get_center() - Vector2(110, 60), Vector2(220, 120)), false, Color(0.5, 0.35, 0.9, 0.05))


## Bookmarks along the top of the page: the open one joins it.
func _draw_tabs() -> void:
	var x := BOOK.position.x + 4
	for i in PAGES.size():
		var page: String = PAGES[i]
		var label := "%s %d/%d" % [page, _found_count(page), _total(page)]
		var w := PixelFont.width_of(label) + 12
		var on := i == _page
		var r := Rect2(x, 21 if on else 23, w, 13 if on else 10)
		_canvas.draw_rect(r, C_PANEL if on else Color("0c0916"))
		_canvas.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), (C_PICK if _on_tabs else C_BRASS) if on else C_EDGE)
		_canvas.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), C_EDGE)
		_canvas.draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), C_EDGE)
		if on:
			_canvas.draw_rect(Rect2(r.position.x + 1, BOOK.position.y, r.size.x - 2, 1), C_PANEL)   # (opens onto the page)
		var col := ((C_PICK if _on_tabs else C_TEXT) if on else C_FAINT)
		PixelFont.draw(_canvas, Vector2(x + 6, r.position.y + 4), label, col)
		var fresh := Profile.any_new("w:") or Profile.any_new("a:") if page == "GEAR" else Profile.any_new({"CREATURES": "c:", "LANDS": "l:"}[page])
		if in_game and fresh:
			var a := 0.6 + 0.4 * sin(_time * 5.0)
			_diamond(Vector2(r.end.x - 2, r.position.y + 1), 2.5, Color(C_PICK, a))   # new cards in here
		x += w + 3
	if _on_tabs:
		var a := 0.6 + 0.4 * sin(_time * 5.0)
		PixelFont.draw(_canvas, Vector2(x + 3, 25), "< >", Color(C_PICK, a))


func _draw_grid() -> void:
	if PAGES[_page] == "CREATURES":   # the two sides' headings
		for side in ["insect", "demon"]:
			var total := 0
			var found := 0
			for c in _creatures:
				if c[0] == side:
					total += 1
					if Profile.kills(c[2]) > 0:
						found += 1
			var x0: float = GRID.x if side == "insect" else DEMON_X
			var w: float = SIDE_COLS[side] * CREATURE_CELL.x - 1
			PixelFont.draw(_canvas, Vector2(x0, 40), ("INSECTS" if side == "insect" else "DEMONS"), C_BRASS)
			var cnt := "%d/%d" % [found, total]
			PixelFont.draw(_canvas, Vector2(x0 + w - PixelFont.width_of(cnt), 40), cnt, C_DIM)
			_canvas.draw_rect(Rect2(x0, 47, w, 1), C_EDGE)
		for k in range(0, int(4 * CREATURE_CELL.y), 3):   # a dotted rule between the two
			_canvas.draw_rect(Rect2(DEMON_X - 4, 41 + k, 1, 1), C_EDGE)
	elif PAGES[_page] == "GEAR":   # weapons and armor, each with its heading
		for side in ["weapon", "armor"]:
			var ids: Array = JournalData.weapons() if side == "weapon" else JournalData.armor()
			var found := 0
			for id in ids:
				if _has_gear(id):
					found += 1
			var x0: float = GRID.x if side == "weapon" else ARMOR_X
			var w: float = GEAR_COLS[side] * CELL["GEAR"].x - 3
			PixelFont.draw(_canvas, Vector2(x0, 40), "WEAPONS" if side == "weapon" else "ARMOR", C_BRASS)
			var cnt := "%d/%d" % [found, ids.size()]
			PixelFont.draw(_canvas, Vector2(x0 + w - PixelFont.width_of(cnt), 40), cnt, C_DIM)
			_canvas.draw_rect(Rect2(x0, 47, w, 1), C_EDGE)
		for k in range(0, int(4 * CELL["GEAR"].y), 3):
			_canvas.draw_rect(Rect2(ARMOR_X - 11, 41 + k, 1, 1), C_EDGE)
	for i in _count():
		var e := _entry(i)
		var r := _slot_rect(i)
		var picked: bool = not _on_tabs and i == _sel and not _detail
		if picked:
			r.position.y -= 1   # it lifts a little
		_slot_frame(i, r, e, picked)
		_slot_art(i, r, e[2])
		if _is_new(i):
			_new_shimmer(i, r)
		if picked:
			_brackets(r.grow(2), Color(C_TEXT, 0.75 + 0.25 * sin(_time * 6.0)))


## A slot: dark, or for one found a little of its rarity's light inside, and
## its rarity on the frame either way (something to hunt for).
func _slot_frame(i: int, r: Rect2, e: Array, picked: bool) -> void:
	var tc: Color = JournalData.TIER_COL[e[1]]
	if picked:
		_canvas.draw_texture_rect(_glow, Rect2(r.get_center() - r.size, r.size * 2.0), false, Color(tc, 0.35))
	_canvas.draw_rect(r, C_SLOT)
	if e[2]:
		var bands := 6
		for k in bands:   # light from below, in its colour
			var h := r.size.y / bands
			_canvas.draw_rect(Rect2(r.position.x, r.position.y + k * h, r.size.x, h + 1), Color(tc, 0.03 + 0.035 * k))
	_frame(r, tc if e[2] else Color(tc, 0.4))
	if e[2]:
		_canvas.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1)), Color(tc.lightened(0.4), 0.45))
	if e[1] == "LEGENDARY":   # a glint running round the gold
		var k := fmod(_time * 0.7 + i * 0.13, 1.0)
		var per := 2.0 * (r.size.x + r.size.y)
		var d := k * per
		var p := r.position
		if d < r.size.x: p += Vector2(d, 0)
		elif d < r.size.x + r.size.y: p += Vector2(r.size.x - 1, d - r.size.x)
		elif d < 2.0 * r.size.x + r.size.y: p += Vector2(r.size.x - (d - r.size.x - r.size.y) - 1, r.size.y - 1)
		else: p += Vector2(0, r.size.y - (d - 2.0 * r.size.x - r.size.y) - 1)
		_canvas.draw_rect(Rect2(p.round(), Vector2.ONE), Color(1, 1, 0.85))


## A new card, not looked at yet: light sweeping across it, a glow pulsing
## round it, and NEW in its corner.
func _new_shimmer(i: int, r: Rect2) -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 4.0 + i)
	_frame(r.grow(1), Color(C_PICK, 0.35 + 0.5 * pulse))
	_frame(r.grow(2), Color(C_PICK, 0.15 * pulse))
	var k := fmod(_time * 0.8 + i * 0.37, 1.6)
	if k < 1.0:
		var x := lerpf(-r.size.x * 0.6, r.size.x * 1.4, k)
		_band(_canvas, r.grow(-1), x, 5.0, 0.5, Color(1, 1, 0.9, 0.35))
		_band(_canvas, r.grow(-1), x + 7.0, 2.0, 0.5, Color(1, 1, 0.9, 0.22))
	var tag := "NEW"
	var tw := PixelFont.width_of(tag) + 4
	var at := Vector2(r.end.x - tw + 1, r.position.y - 3)
	_canvas.draw_rect(Rect2(at, Vector2(tw, 8)), Color("c89020"))
	_canvas.draw_rect(Rect2(at, Vector2(tw, 1)), Color("ffe8a0"))
	PixelFont.draw(_canvas, at + Vector2(2, 2), tag, Color("2a1404"))


## Corner brackets round the picked slot.
func _brackets(r: Rect2, col: Color) -> void:
	var L := 4.0
	for c in [r.position, Vector2(r.end.x - 1, r.position.y), Vector2(r.position.x, r.end.y - 1), r.end - Vector2.ONE]:
		var sx := 1.0 if c.x == r.position.x else -1.0
		var sy := 1.0 if c.y == r.position.y else -1.0
		_canvas.draw_rect(Rect2(Vector2(minf(c.x, c.x + sx * (L - 1)), c.y), Vector2(L, 1)), col)
		_canvas.draw_rect(Rect2(Vector2(c.x, minf(c.y, c.y + sy * (L - 1))), Vector2(1, L)), col)


func _frame(r: Rect2, col: Color) -> void:
	_canvas.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), col)
	_canvas.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), col)
	_canvas.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), col)
	_canvas.draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 0), Vector2(1, r.size.y)), col)


## The little picture in slot i (a shadow until it's found).
func _slot_art(i: int, r: Rect2, found: bool) -> void:
	if PAGES[_page] == "CREATURES":
		var c: Array = _creatures[i]
		var frame := int(_time * 5.0) % 4 if found and i == _sel and not _on_tabs else 0   # (the picked one walks in place)
		var inside := r.grow(-1)
		if c[0] == "insect":
			var at := (r.get_center() - Vector2(12, 12)).round()
			_pic(INSECTS, Rect2(at, Vector2(24, 24)), Rect2(c[1] * 24, frame * 24, 24, 24), found, inside)
		else:
			var at := (r.get_center() - Vector2(12, 17)).round()
			_pic(DEMONS, Rect2(at, Vector2(24, 32)), Rect2(c[1] * 24, frame * 32, 24, 32), found, inside)
	elif PAGES[_page] == "LANDS":   # its little floating island (a shadow until you've been)
		var bob := roundf(sin(_time * 1.5 + i * 0.9) * 1.0) if found else 0.0
		var at := (r.get_center() - LAND_SMALL / 2.0 + Vector2(0, bob)).round()
		_pic(LANDS_SMALL, Rect2(at, LAND_SMALL), Rect2(i * LAND_SMALL.x, 0, LAND_SMALL.x, LAND_SMALL.y), found)
	else:
		var id: String = _weapons[i]
		var at := (r.get_center() - Vector2(16, 16)).round()   # (its detailed render, at 32 x 32)
		var src: Array = Items.mid_src(id)
		_pic(src[0], Rect2(at, Vector2(32, 32)), src[1], found, r.grow(-1))


## Under the page: what the picked slot is.
func _draw_info(size: Vector2) -> void:
	var r := Rect2(BOOK.position.x, BOOK.end.y + 4, BOOK.size.x, 30)
	_panel(r, false)
	if _on_tabs:
		PixelFont.draw(_canvas, Vector2(r.position.x + 8, r.position.y + 7), "TURN TO A PAGE", C_DIM)
		PixelFont.draw(_canvas, Vector2(r.position.x + 8, r.position.y + 17), "LEFT AND RIGHT, THEN DOWN", C_FAINT)
		_legend(r)
		return
	var e := _entry(_sel)
	var tier: String = e[1]
	var tc: Color = JournalData.TIER_COL[tier]
	var name: String = e[0] if e[2] else "???"
	PixelFont.draw(_canvas, Vector2(r.position.x + 8, r.position.y + 6), name, C_TEXT if e[2] else C_DIM)
	_pill(Vector2(r.position.x + 12 + PixelFont.width_of(name), r.position.y + 4), tier, tc)
	var line := ""
	if PAGES[_page] == "CREATURES":
		var k := Profile.kills(e[0])
		line = ("DEFEATED %d TIME%s" % [k, "" if k == 1 else "S"]) if k > 0 else "NOT YET DEFEATED"
	elif PAGES[_page] == "LANDS":
		line = "VISITED" if e[2] else ("NOT YET SEEN -- IT'S RARE" if tier in ["RARE", "LEGENDARY"] else "NOT YET VISITED")
	else:
		var gid: String = _weapons[_sel]
		line = (("FOUND -- DEF %d" % int(Items.DATA[gid].def)) if _armor(gid) else ("FOUND -- ATK %d" % int(Items.DATA[gid].atk))) if e[2] else "NOT YET FOUND"
	PixelFont.draw(_canvas, Vector2(r.position.x + 8, r.position.y + 17), line, C_DIM)
	_legend(r)


## The four rarities, as little gems, at the right of the bar.
func _legend(r: Rect2) -> void:
	var x := r.end.x - 8.0
	for k in range(JournalData.TIERS.size() - 1, -1, -1):
		var tier: String = JournalData.TIERS[k]
		var tc: Color = JournalData.TIER_COL[tier]
		var label := tier.substr(0, 1) + tier.substr(1).to_lower() if false else tier.substr(0, 3)
		var w := PixelFont.width_of(label)
		x -= w
		PixelFont.draw(_canvas, Vector2(x, r.position.y + 12), label, Color(tc, 0.85))
		_diamond(Vector2(x - 4, r.position.y + 14.5), 2.0, tc)
		x -= 12


## A rarity in a little coloured pill.
func _pill(at: Vector2, tier: String, tc: Color) -> void:
	var w := PixelFont.width_of(tier) + 6
	_canvas.draw_rect(Rect2(at, Vector2(w, 9)), tc.darkened(0.55))
	_frame(Rect2(at, Vector2(w, 9)), tc)
	PixelFont.draw(_canvas, at + Vector2(3, 2), tier, tc.lightened(0.35))


## The buttons along the bottom, as little key caps.
func _controls(size: Vector2, items: Array) -> void:
	var total := 0.0
	for it in items:
		total += PixelFont.width_of(it[0]) + 6 + 4 + PixelFont.width_of(it[1]) + 12
	var x := floorf((size.x - total) / 2.0)
	var y := size.y - 12
	for it in items:
		var kw := PixelFont.width_of(it[0]) + 6
		_canvas.draw_rect(Rect2(x, y - 2, kw, 9), C_PANEL_HI)
		_frame(Rect2(x, y - 2, kw, 9), C_EDGE)
		_canvas.draw_rect(Rect2(x + 1, y + 6, kw - 2, 1), Color(0, 0, 0, 0.5))
		PixelFont.draw(_canvas, Vector2(x + 3, y), it[0], C_TEXT)
		x += kw + 4
		PixelFont.draw(_canvas, Vector2(x, y), it[1], C_DIM)
		x += PixelFont.width_of(it[1]) + 12


## Where slot i of the current page sits.
func _slot_rect(i: int) -> Rect2:
	var page: String = PAGES[_page]
	if page == "CREATURES":
		var c: Array = _creatures[i]
		var first := 0   # (index of the first of its side)
		while _creatures[first][0] != c[0]:
			first += 1
		var k := i - first
		var cols: int = SIDE_COLS[c[0]]
		var x0: float = GRID.x if c[0] == "insect" else DEMON_X
		return Rect2(Vector2(x0, CREATURE_TOP) + Vector2(k % cols, k / cols) * CREATURE_CELL, CREATURE_CELL - Vector2(1, 3))
	if page == "GEAR":
		var nw := JournalData.weapons().size()
		var arm := i >= nw
		var k2 := i - nw if arm else i
		var gc: int = GEAR_COLS["armor" if arm else "weapon"]
		var gx: float = ARMOR_X if arm else GRID.x
		return Rect2(Vector2(gx, CREATURE_TOP) + Vector2(k2 % gc, k2 / gc) * CELL["GEAR"], CELL["GEAR"] - Vector2(3, 3))
	var cell: Vector2 = CELL[page]
	var cols2: int = COLS[page]
	return Rect2(GRID + Vector2(i % cols2, i / cols2) * cell, cell - Vector2(3, 3))


## The slot next to the picked one in direction `dir` (the picked one if none).
func _nearest(dir: Vector2) -> int:
	var here := _slot_rect(_sel).get_center()
	var best := _sel
	var best_d := INF
	for i in _count():
		if i == _sel:
			continue
		var d := _slot_rect(i).get_center() - here
		var along := d.dot(dir)
		if along < 4.0:
			continue
		var across := absf(d.dot(Vector2(dir.y, dir.x)))
		var score := along + across * 2.5
		if score < best_d:
			best_d = score
			best = i
	return best


## The best weapon ever found, on her back.
func _best_weapon() -> String:
	var best := "rusty_dagger"
	for id in JournalData.weapons():
		if Profile.has_weapon(id) and int(Items.DATA[id].atk) > int(Items.DATA[best].atk):
			best = id
	return best


## The card, big, in the middle: it flips over as it comes up and as you turn
## to the next, floats a little, and carries everything -- picture, rarity,
## stats, its story. The rarer it is, the more its foil shines.
func _draw_detail(size: Vector2) -> void:
	var e := _entry(_sel)
	var tier: String = e[1]
	var tc: Color = JournalData.TIER_COL[tier]
	var found: bool = e[2]
	var come := clampf(_t_detail / 0.3, 0.0, 1.0)
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.005, 0.02, 0.86 * minf(1.0, _t_detail / 0.12 + 0.6)))
	var center := (size / 2.0).round()
	_canvas.draw_texture_rect(_glow, Rect2(center - Vector2(130, 130), Vector2(260, 260)), false, Color(tc, 0.16 if found else 0.07))
	# the card: flips in (back, edge on, then the face), grows into place, floats
	var t := clampf(_t_detail / 0.36, 0.0, 1.0)
	var flip := cos(PI * t)                   # 1 -> -1
	_card_face = found and flip < 0.0
	_card_sx = maxf(absf(flip), 0.04) if found else 1.0
	_card_zoom = lerpf(0.86, 1.0, ease(come, -2.0))
	_card_tier = tier
	var bob := roundf(sin(_time * 1.6) * 1.5)
	_card_at = center + Vector2(0, bob)
	var sc := Vector2(_card_sx * _card_zoom, _card_zoom)
	_canvas.draw_set_transform(_card_at + Vector2(4, 6 - bob), 0.0, sc)   # its shadow
	_canvas.draw_rect(Rect2(-CARD / 2.0, CARD), Color(0, 0, 0, 0.5))
	_canvas.draw_set_transform(_card_at, 0.0, sc)
	if _card_face:
		_card_front(e)
	else:
		_card_back(e)
	_canvas.draw_set_transform(Vector2.ZERO)
	if _new_banner != "" and _card_face:
		_draw_new_banner(center + Vector2(0, -CARD.y / 2.0 + 22 + bob))
	# around it: which card this is, and the way to the next
	var pg := "%d / %d" % [_sel + 1, _count()]
	PixelFont.draw(_canvas, Vector2(10, 10), PAGES[_page], C_BRASS)
	PixelFont.draw(_canvas, Vector2(10, 20), pg, C_DIM)
	var a := 0.55 + 0.45 * sin(_time * 4.0)
	var nudge := roundf(sin(_time * 4.0) * 1.5)
	PixelFont.draw(_canvas, Vector2(center.x - CARD.x / 2.0 - 16 - nudge, center.y - 2), "<", Color(C_TEXT, a))
	PixelFont.draw(_canvas, Vector2(center.x + CARD.x / 2.0 + 13 + nudge, center.y - 2), ">", Color(C_TEXT, a))
	_controls_side(size)


## NEW ...! on a gold ribbon across the top of the card, light bursting off it.
func _draw_new_banner(at: Vector2) -> void:
	var t := clampf((_new_t - 0.3) / 0.25, 0.0, 1.0)   # (after the card has turned over)
	if t <= 0.0:
		return
	var w := (PixelFont.width_of(_new_banner) + 20) * ease(t, -2.0)
	var r := Rect2(at.x - w / 2.0, at.y - 7, w, 14).abs()
	_canvas.draw_texture_rect(_glow, Rect2(at - Vector2(90, 26), Vector2(180, 52)), false, Color(1.0, 0.8, 0.3, 0.3 * t))
	for side: float in [-1.0, 1.0]:   # the ribbon's notched tails
		var ex := at.x + side * (w / 2.0)
		_canvas.draw_colored_polygon(PackedVector2Array([Vector2(ex, at.y - 5), Vector2(ex + side * 9, at.y - 5),
			Vector2(ex + side * 5, at.y + 1), Vector2(ex + side * 9, at.y + 7), Vector2(ex, at.y + 7)]), Color("8a5a10"))
	_canvas.draw_rect(r, Color("d8a030"))
	_canvas.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color("fff0b0"))
	_canvas.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), Color("7a4a08"))
	if t >= 1.0:
		var pulse := 0.85 + 0.15 * sin(_time * 6.0)
		PixelFont.draw(_canvas, Vector2(floorf(at.x - PixelFont.width_of(_new_banner) / 2.0), at.y - 2), _new_banner,
			Color(0.16, 0.07, 0.0, pulse), Color(1, 0.95, 0.7, 0.5))
		for k in 10:   # sparks thrown off as it lands
			var life := clampf((_new_t - 0.55) / 0.9, 0.0, 1.0)
			if life >= 1.0:
				break
			var ang := k * TAU / 10.0 + 0.3
			var p := at + Vector2(cos(ang) * (w / 2.0 + 4), sin(ang) * 10.0) * (0.6 + life)
			_canvas.draw_rect(Rect2(p.round(), Vector2.ONE), Color(1, 0.9, 0.5, 1.0 - life))


func _controls_side(size: Vector2) -> void:
	var items := [["< >", "NEXT CARD"], ["X", "BACK"]]
	var y := size.y - 24.0
	for it in items:
		var kw := PixelFont.width_of(it[0]) + 6
		var x := size.x - 10 - kw - 4 - PixelFont.width_of(it[1])
		_canvas.draw_rect(Rect2(x, y - 2, kw, 9), C_PANEL_HI)
		_frame(Rect2(x, y - 2, kw, 9), C_EDGE)
		PixelFont.draw(_canvas, Vector2(x + 3, y), it[0], C_TEXT)
		PixelFont.draw(_canvas, Vector2(x + kw + 4, y), it[1], C_DIM)
		y += 12


## The metal of a card's edge, by rarity: [light, mid, dark].
func _metal(tier: String) -> Array:
	match tier:
		"LEGENDARY": return [Color("fff0a8"), Color("e0a828"), Color("7a5210")]
		"RARE": return [Color("bfe0ff"), Color("4a8ae0"), Color("1c3a78")]
		"UNCOMMON": return [Color("c8f8d4"), Color("3ea860"), Color("1a5030")]
	return [Color("e8e2f0"), Color("9890a8"), Color("4a4458")]


## The card's frame: a bevelled metal edge, corners clipped round.
func _card_edge(tier: String) -> Rect2:
	var m := _metal(tier)
	var o := -CARD / 2.0
	var R := Rect2(o, CARD)
	_canvas.draw_rect(R.grow(-1), m[2])
	_canvas.draw_rect(Rect2(o + Vector2(2, 0), Vector2(CARD.x - 4, 1)), m[0])            # top (lit)
	_canvas.draw_rect(Rect2(o + Vector2(0, 2), Vector2(1, CARD.y - 4)), m[0])            # left (lit)
	_canvas.draw_rect(Rect2(o + Vector2(2, CARD.y - 1), Vector2(CARD.x - 4, 1)), m[2].darkened(0.4))
	_canvas.draw_rect(Rect2(o + Vector2(CARD.x - 1, 2), Vector2(1, CARD.y - 4)), m[2].darkened(0.4))
	for c in [Vector2(1, 1), Vector2(CARD.x - 2, 1), Vector2(1, CARD.y - 2), Vector2(CARD.x - 2, CARD.y - 2)]:
		_canvas.draw_rect(Rect2(o + c, Vector2.ONE), m[1])
	_canvas.draw_rect(Rect2(o + Vector2(2, 2), CARD - Vector2(4, 4)), m[1])
	_canvas.draw_rect(Rect2(o + Vector2(3, 3), CARD - Vector2(6, 6)), m[0].darkened(0.15))
	return Rect2(o + Vector2(4, 4), CARD - Vector2(8, 8))   # the inside


## Everything about the entry: [kind, stats, the line under them, its story].
func _card_text(e: Array) -> Array:
	var found: bool = e[2]
	match PAGES[_page]:
		"CREATURES":
			var c: Array = _creatures[_sel]
			var d: Dictionary = CreatureData.TYPES[c[0]][c[1]]
			var k := Profile.kills(c[2])
			return ["INSECT" if c[0] == "insect" else "DEMON", [["ATK", d.atk[0]], ["DEF", d.def[0]], ["HP", d.hp]],
				("SLAIN %d TIME%s" % [k, "" if k == 1 else "S"]) if found else "NOT YET DEFEATED",
				String(JournalData.CREATURE_LORE.get(c[2], "")) if found
					else "YOU HAVEN'T DEFEATED ONE YET. DEFEAT ONE AND ITS CARD WILL BE YOURS, AND ITS STORY WRITTEN HERE."]
		"LANDS":
			var l: Array = JournalData.LANDS[_sel]
			var how := "YOU HAVEN'T SET FOOT HERE YET. KEEP EXPLORING."
			if l[0] == "home":
				how = "NO ONE YOU KNOW HAS SEEN WHAT LIES BEHIND THE PURPLE GATE. OPEN IT AND FIND OUT."
			elif l[2] in ["RARE", "LEGENDARY"]:
				how = "ONLY SOME LABYRINTHS HOLD THIS LAND, AND FEW WANDERERS EVER FIND IT. KEEP LOOKING."
			return ["LAND", [], "VISITED" if found else "NOT YET VISITED", String(l[3]) if found else how]
	var id: String = _weapons[_sel]
	if _armor(id):
		return ["ARMOR", [["DEF", int(Items.DATA[id].def)]], "FOUND" if found else "NOT YET FOUND",
			String(JournalData.ARMOR_INFO[id][1]) if found
				else "YOU HAVEN'T FOUND THIS ONE YET. CHESTS, SHOPS AND THE THINGS YOU KILL ALL HOLD ARMOR."]
	return ["WEAPON", [["ATK", int(Items.DATA[id].atk)]], "FOUND" if found else "NOT YET FOUND",
		String(JournalData.WEAPON_INFO[id][1]) if found
			else "YOU HAVEN'T FOUND THIS ONE YET. CHESTS, SHOPS AND THE THINGS YOU KILL ALL HOLD WEAPONS."]


func _card_front(e: Array) -> void:
	var tier: String = e[1]
	var tc: Color = JournalData.TIER_COL[tier]
	var m := _metal(tier)
	var inner := _card_edge(tier)
	_canvas.draw_rect(inner, Color("151020"))
	var info := _card_text(e)
	# the name plate, a gem at its end
	var plate := Rect2(inner.position, Vector2(inner.size.x, 13))
	_canvas.draw_rect(plate, m[2].darkened(0.3))
	_canvas.draw_rect(Rect2(plate.position, Vector2(plate.size.x, 1)), Color(m[0], 0.35))
	_canvas.draw_rect(Rect2(plate.position + Vector2(0, plate.size.y - 1), Vector2(plate.size.x, 1)), m[1])
	var name: String = e[0]
	PixelFont.draw(_canvas, Vector2(plate.position.x + 5, plate.position.y + 4), name, Color("f4ecd8"), Color(0, 0, 0, 0.6))
	_gem(Vector2(plate.end.x - 7, plate.position.y + 6.5), tier)
	# the picture, on a backdrop the rarity's colour, lit from the middle
	var art := Rect2(inner.position + Vector2(3, 15), Vector2(inner.size.x - 6, 104))
	_canvas.draw_rect(art, tc.darkened(0.8))
	_canvas.draw_texture_rect(_glow, Rect2(art.get_center() - Vector2(70, 60), Vector2(140, 120)), false, Color(tc, 0.32))
	if PAGES[_page] != "LANDS":   # (the ground -- the lands float)
		_canvas.draw_rect(Rect2(art.position.x, art.end.y - 20, art.size.x, 20), Color(0, 0, 0, 0.25))
		_canvas.draw_texture_rect(_glow, Rect2(art.get_center() + Vector2(-26, 30), Vector2(52, 10)), false, Color(0, 0, 0, 0.5))
	var frame := int(_t_detail * 5.0) % 4
	if PAGES[_page] == "CREATURES":
		var c: Array = _creatures[_sel]
		if c[0] == "insect":
			_canvas.draw_texture_rect_region(INSECTS_BIG, Rect2((art.get_center() - Vector2(32, 28)).round(), Vector2(64, 64)),
				Rect2(c[1] * 64, frame * 64, 64, 64))
		else:
			_canvas.draw_texture_rect_region(DEMONS_BIG, Rect2((art.get_center() - Vector2(32, 50)).round(), Vector2(64, 96)),
				Rect2(c[1] * 64, frame * 96, 64, 96))
	elif PAGES[_page] == "LANDS":
		_draw_floating_land(art, tc)
	elif _armor(_weapons[_sel]):   # Red, wearing it, turning to show it off
		var id: String = _weapons[_sel]
		HeroLook.use(null)
		HeroLook.p2 = id == "blue_hood"
		var facing: int = [0, 3, 1, 2][int(_t_detail / 1.6) % 4]
		HeroLook.draw_big(_canvas, (art.get_center() - Vector2(32, 50)).round(), facing, id, "", roundf(sin(_t_detail * 1.6)))
		HeroLook.p2 = false
	else:
		var id: String = _weapons[_sel]
		var b := roundf(sin(_t_detail * 2.0) * 2.0)
		_canvas.draw_texture_rect_region(HeroLook.GEAR_BIG_TEX, Rect2((art.get_center() - Vector2(32, 34 - b)).round(), Vector2(64, 64)),
			Rect2(int(HeroLook.WEAPONS[id]) * 64, 0, 64, 64))
	_frame(art, m[1])
	_frame(art.grow(1), Color(m[2], 0.8))
	# the type line: what it is, and its rarity
	var y := art.end.y + 4
	PixelFont.draw(_canvas, Vector2(inner.position.x + 4, y), info[0], Color("c8bfd8"))
	PixelFont.draw(_canvas, Vector2(inner.end.x - 4 - PixelFont.width_of(tier), y), tier, tc.lightened(0.2))
	# the stats, in little boxes, and how many slain / whether found
	y += 10
	var bx := inner.position.x + 4
	for st in info[1]:
		var label := "%s %d" % [st[0], int(st[1])]
		var bw := PixelFont.width_of(label) + 6
		_canvas.draw_rect(Rect2(bx, y, bw, 9), m[2].darkened(0.35))
		_frame(Rect2(bx, y, bw, 9), Color(m[1], 0.8))
		PixelFont.draw(_canvas, Vector2(bx + 3, y + 2), label, Color("f4ecd8"))
		bx += bw + 2
	var tally: String = info[2]
	PixelFont.draw(_canvas, Vector2(inner.end.x - 4 - PixelFont.width_of(tally), y + 2), tally, Color(m[0], 0.75))
	# a rule, and the story
	y += 13
	for k in int(inner.size.x - 8):
		_canvas.draw_rect(Rect2(inner.position.x + 4 + k, y, 1, 1), Color(m[1], 0.7 * (1.0 - absf(k / (inner.size.x - 8) - 0.5) * 1.6)))
	y += 5
	var lines := Dialog.wrap_text(String(info[3]), int(inner.size.x - 8))
	var room := int((inner.end.y - 10 - y) / 7.0)
	for i in mini(lines.size(), room):
		PixelFont.draw(_canvas, Vector2(inner.position.x + 4, y + i * 7), lines[i], Color("e2d8c0"))
	# the foot of the card
	var no := "NO.%02d" % (_sel + 1)
	PixelFont.draw(_canvas, Vector2(inner.end.x - 3 - PixelFont.width_of(no), inner.end.y - 7), no, Color(m[0], 0.45))
	PixelFont.draw(_canvas, Vector2(inner.position.x + 3, inner.end.y - 7), "RED'S JOURNAL", Color(m[0], 0.3))


## The back of a card not yet collected: the same edge, a dark patterned back,
## a seal with a question on it, its rarity, and how you might find it.
func _card_back(e: Array) -> void:
	var tier: String = e[1]
	var tc: Color = JournalData.TIER_COL[tier]
	var inner := _card_edge(tier)
	_canvas.draw_rect(inner, Color("120c1e"))
	for yy in range(int(inner.position.y) + 3, int(inner.end.y) - 2, 6):   # a lattice of little diamonds
		for xx in range(int(inner.position.x) + 3 + (3 if (yy / 6) % 2 else 0), int(inner.end.x) - 2, 6):
			_canvas.draw_rect(Rect2(xx, yy, 1, 1), Color(tc, 0.2))
	_frame(inner.grow(-3), Color(tc, 0.35))
	_frame(inner.grow(-5), Color(tc, 0.15))
	var seal := Vector2(0, -38)
	_canvas.draw_texture_rect(_glow, Rect2(seal - Vector2(44, 44), Vector2(88, 88)), false, Color(tc, 0.2))
	_canvas.draw_circle(seal, 19.0, Color(tc, 0.55))
	_canvas.draw_circle(seal, 17.0, Color("120c1e"))
	_canvas.draw_circle(seal, 14.0, Color(tc, 0.15))
	PixelFont.draw(_canvas, seal + Vector2(-1, -2), "?", tc)
	var y := 0.0
	var t1 := "NOT YET COLLECTED"
	PixelFont.draw(_canvas, Vector2(roundf(-PixelFont.width_of(t1) / 2.0), y), t1, Color(C_TEXT, 0.85))
	y += 11
	_gem(Vector2(-PixelFont.width_of(tier) / 2.0 - 6, y + 2.5), tier)
	PixelFont.draw(_canvas, Vector2(roundf(-PixelFont.width_of(tier) / 2.0) + 2, y), tier, tc)
	y += 14
	var info := _card_text(e)
	var lines := Dialog.wrap_text(String(info[3]), int(inner.size.x - 20))
	for l in lines:
		PixelFont.draw(_canvas, Vector2(roundf(-PixelFont.width_of(l) / 2.0), y), l, Color(C_DIM, 0.95))
		y += 8
	var no := "NO.%02d" % (_sel + 1)
	PixelFont.draw(_canvas, Vector2(inner.end.x - 6 - PixelFont.width_of(no), inner.end.y - 10), no, Color(tc, 0.35))


## The land's island on its card, alive: it floats, rising and sinking
## slowly; chips of its rock drift beside it out of step; dust trickles from
## its underside; cloud drifts past; its light pools softer below it as it
## rises; and each land has its own motes in the air (embers, snow, gold...).
func _draw_floating_land(art: Rect2, tc: Color) -> void:
	var t := _time
	var id: String = JournalData.LANDS[_sel][0]
	var rise := sin(t * 1.1) * 3.0 + sin(t * 0.47) * 1.0          # a slow, uneven float
	var fl := roundf(-rise)
	var mid := art.get_center()
	# cloud drifting behind it
	for k in 3:
		var cx := fposmod(t * (4.0 + k * 1.5) + k * 37.0, art.size.x + 40.0) - 20.0
		var cy := art.position.y + 22.0 + k * 27.0
		_cloud(art, Vector2(art.position.x + cx, cy), 7.0 + k * 2.0, Color(1, 1, 1, 0.05 + 0.02 * k))
	# its light pooled below, softer the higher it floats
	var under := mid + Vector2(0, 40)
	_canvas.draw_texture_rect(_glow, Rect2(under - Vector2(26, 7), Vector2(52, 14)), false,
		Color(tc.lightened(0.3), 0.16 - rise * 0.012))
	# the island
	var dst := Rect2((art.get_center() - LAND / 2.0).round() + Vector2(0, fl), LAND)
	var vis := dst.intersection(art)   # (kept inside its window as it rises and sinks)
	_canvas.draw_texture_rect_region(LANDS_TEX, vis, Rect2(Vector2(_sel * LAND.x, 0) + vis.position - dst.position, vis.size))
	# chips of rock floating beside it, each on its own slow float
	var rock := Color("4a4258")
	var rock_hi := Color("7a7090")
	for k in 3:
		var side := -1.0 if k % 2 == 0 else 1.0
		var ph := t * (0.9 + k * 0.23) + k * 2.1
		var p := (mid + Vector2(side * (30.0 + k * 4.0), 10.0 + k * 9.0 + sin(ph) * 3.0)).round()
		var w := 3.0 if k != 1 else 2.0
		if art.grow(-2).has_point(p):
			_canvas.draw_rect(Rect2(p, Vector2(w, 2)), rock)
			_canvas.draw_rect(Rect2(p, Vector2(w, 1)), rock_hi)
	# dust trickling off the bottom
	for k in 5:
		var life := fposmod(t * 0.55 + k * 0.29, 1.0)
		var p := mid + Vector2((k - 2) * 5.0 + sin(k * 7.0) * 3.0, 22.0 + fl + life * 26.0)
		if art.grow(-2).has_point(p):
			_canvas.draw_rect(Rect2(p.round(), Vector2.ONE), Color(0.6, 0.55, 0.7, 0.55 * (1.0 - life)))
	# the land's own motes in the air: [colour, -1 rising / 1 falling / 0 hanging]
	var motes := {"volcano": [Color("ffa040"), -1.0], "snow": [Color("f4f8ff"), 1.0], "gold": [Color("fff0a0"), 0.0],
		"forest": [Color("d8ff8a"), 0.0], "swamp": [Color("a8ffb0"), 0.0], "jungle": [Color("d8ff8a"), 0.0],
		"home": [Color("fff6d8"), -1.0], "crypt": [Color("c8a8ff"), -1.0], "village": [Color("ffd890"), -1.0],
		"beach": [Color("e8f8ff"), 0.0], "river": [Color("a8e0ff"), 0.0], "court": [Color("fff0c8"), -1.0],
		"mountain": [Color("e0d8e8"), 1.0]}
	var mo: Array = motes.get(id, [Color.WHITE, 0.0])
	var n := 9 if id in ["snow", "volcano", "gold", "home"] else 5
	for k in n:
		var h1 := fposmod(sin(k * 12.9898) * 43758.5453, 1.0)
		var h2 := fposmod(sin(k * 78.233) * 24634.6345, 1.0)
		var life := fposmod(t * (0.18 + h2 * 0.12) + h1, 1.0)
		var x := art.position.x + 6.0 + h1 * (art.size.x - 12.0) + sin(t * 1.3 + k) * 3.0
		var y := 0.0
		var a := sin(life * PI)
		if mo[1] < 0.0:     # rising (embers, motes of light)
			y = art.end.y - 6.0 - life * (art.size.y - 12.0)
		elif mo[1] > 0.0:   # falling (snow)
			y = art.position.y + 6.0 + life * (art.size.y - 12.0)
		else:               # hanging, blinking (fireflies, glints)
			y = art.position.y + 10.0 + h2 * (art.size.y - 20.0) + sin(t * 0.9 + k * 2.0) * 4.0
			a = maxf(0.0, sin(t * (2.0 + h2 * 2.0) + k * 3.0))
		var p := Vector2(x, y).round()
		if art.grow(-2).has_point(p):
			_canvas.draw_rect(Rect2(p, Vector2.ONE), Color(mo[0], 0.9 * a))
			if a > 0.6 and k % 3 == 0:
				for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
					_canvas.draw_rect(Rect2(p + d, Vector2.ONE), Color(mo[0], 0.3 * a))


## A soft puff of cloud (three soft glows), kept inside `art`.
func _cloud(art: Rect2, c: Vector2, r: float, col: Color) -> void:
	for k in 3:
		var p := c + Vector2((k - 1) * r * 0.9, (1 - absi(k - 1)) * -r * 0.3)
		var full := Rect2(p - Vector2(r, r * 0.55), Vector2(r * 2.0, r * 1.1))
		var rr := full.intersection(art)
		if rr.size.x > 1.0 and rr.size.y > 1.0:
			var src := Rect2((rr.position - full.position) / full.size * 128.0, rr.size / full.size * 128.0)
			_canvas.draw_texture_rect_region(_glow, rr, src, col)


## A cut gem in the rarity's colour (a bigger, brighter one the rarer it is).
func _gem(c: Vector2, tier: String) -> void:
	var tc: Color = JournalData.TIER_COL[tier]
	var rr := 2.0 + JournalData.TIERS.find(tier) * 0.6
	var pts := PackedVector2Array([c + Vector2(0, -rr - 1), c + Vector2(rr + 1, 0), c + Vector2(0, rr + 1), c + Vector2(-rr - 1, 0)])
	_canvas.draw_colored_polygon(pts, tc.darkened(0.45))
	var pts2 := PackedVector2Array([c + Vector2(0, -rr), c + Vector2(rr, 0), c + Vector2(0, rr), c + Vector2(-rr, 0)])
	_canvas.draw_colored_polygon(pts2, tc)
	_canvas.draw_rect(Rect2((c + Vector2(-1, -rr + 1)).round(), Vector2.ONE), Color(1, 1, 1, 0.9))


## The foil, added over the card's face: a sheen of light sweeping across it
## now and then, and for the rare ones the holographic rainbow bands that
## slide as the card catches the light, and sparkles.
func _draw_card_fx() -> void:
	if not _detail or not _card_face:
		return
	var level := JournalData.TIERS.find(_card_tier)   # 0 common .. 3 legendary
	if level <= 0:
		return
	var fx := _card_fx
	fx.draw_set_transform(_card_at, 0.0, Vector2(_card_sx * _card_zoom, _card_zoom))
	var R := Rect2(-CARD / 2.0 + Vector2(2, 2), CARD - Vector2(4, 4))
	var slope := 0.55
	# the holo bands (rare and legendary)
	if level >= 2:
		var drift := sin(_time * 0.9) * 22.0 + _time * 9.0
		var n := 14
		for i in n:
			var span := 18.0
			var x0 := fmod(i * span + drift, n * span) - 40.0
			var hue := fmod(float(i) / n + _time * 0.05, 1.0)
			var col := Color.from_hsv(hue, 0.7 if level == 3 else 0.45, 1.0, 0.13 if level == 3 else 0.08)
			if level == 2:   # rares: the cooler half of the rainbow
				col = Color.from_hsv(0.48 + 0.25 * hue, 0.55, 1.0, 0.09)
			var bw := span * 0.8
			for f: float in [0.0, 0.2, 0.36]:   # soft-edged: brighter toward the middle
				_band(fx, R, x0 + bw * f, bw * (1.0 - 2.0 * f), slope, Color(col, col.a * 0.45))
	# the sheen: a bright band crossing the card
	var every: float = [0.0, 4.0, 3.0, 2.4][level]
	var k := fmod(_time + 0.6, every) / 0.9
	if k < 1.0:
		var x := lerpf(-CARD.x, CARD.x * 1.2, k)
		_band(fx, R, x, 10.0, slope, Color(1, 1, 1, 0.16 + 0.06 * level))
		_band(fx, R, x + 12.0, 3.0, slope, Color(1, 1, 1, 0.10 + 0.05 * level))
	# sparkles
	if level >= 2:
		var count := 4 if level == 2 else 8
		for i in count:
			var ph := fmod(_time * 0.9 + i * 0.37, 1.6)
			if ph > 0.5:
				continue
			var a := 1.0 - absf(ph / 0.25 - 1.0)
			var h1 := fmod(sin(i * 12.9898 + floorf((_time * 0.9 + i * 0.37) / 1.6) * 78.233) * 43758.5453, 1.0)
			var h2 := fmod(sin(i * 39.346 + floorf((_time * 0.9 + i * 0.37) / 1.6) * 11.135) * 24634.6345, 1.0)
			var p := (R.position + Vector2(absf(h1), absf(h2)) * R.size).round()
			var c := Color(1, 1, 0.9, a * 0.9)
			fx.draw_rect(Rect2(p, Vector2.ONE), c)
			if level == 3 or i % 2 == 0:
				for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
					fx.draw_rect(Rect2(p + d, Vector2.ONE), Color(c, a * 0.5))
	fx.draw_set_transform(Vector2.ZERO)


## A slanted band across rect R (clipped to it).
func _band(ci: CanvasItem, R: Rect2, x0: float, w: float, slope: float, col: Color) -> void:
	var top := R.position.y
	var bot := R.end.y
	var h := bot - top
	var band := PackedVector2Array([Vector2(R.position.x + x0, top), Vector2(R.position.x + x0 + w, top),
		Vector2(R.position.x + x0 + w - h * slope, bot), Vector2(R.position.x + x0 - h * slope, bot)])
	var box := PackedVector2Array([R.position, Vector2(R.end.x, R.position.y), R.end, Vector2(R.position.x, R.end.y)])
	for poly in Geometry2D.intersect_polygons(band, box):
		if poly.size() >= 3:
			ci.draw_colored_polygon(poly, col)


## A picture, or -- not found yet -- just its shadow: flat dark, with a faint
## edge so its shape still shows.
func _pic(tex: Texture2D, dst: Rect2, src: Rect2, found: bool, clip := Rect2()) -> void:
	if found:
		_blit(tex, dst, src, Color.WHITE, clip)
		return
	var step := maxf(1.0, roundf(dst.size.x / src.size.x))
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		_blit(tex, Rect2(dst.position + d * step, dst.size), src, C_SHADOW, clip)
	_blit(tex, dst, src, Color(0.02, 0.015, 0.035), clip)


## Draws part of a texture, cut to `clip` if one is given (pixel for pixel).
func _blit(tex: Texture2D, dst: Rect2, src: Rect2, mod: Color, clip: Rect2) -> void:
	if clip.size == Vector2.ZERO:
		_canvas.draw_texture_rect_region(tex, dst, src, mod)
		return
	var vis := dst.intersection(clip)
	if vis.size.x <= 0.0 or vis.size.y <= 0.0:
		return
	var k := src.size / dst.size
	_canvas.draw_texture_rect_region(tex, vis, Rect2(src.position + (vis.position - dst.position) * k, vis.size * k), mod)


func _text_c(cx: float, y: float, text: String, col: Color) -> void:
	PixelFont.draw(_canvas, Vector2(floorf(cx - PixelFont.width_of(text) / 2.0), y), text, col)
