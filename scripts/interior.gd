class_name Interior
extends CanvasLayer
## Inside a village building, Pokemon style. Walk into a door: the screen
## fades out and back in on a little room you can walk around -- a tiled
## floor, the back wall, furniture you bump into, whoever lives or works
## there. Talk to the keeper across their counter (A) to shop, heal or take a
## bed; talk to the folk at home; poke at the furniture. Walk back onto the
## door mat and keep going (down) to step outside again.
##
## One per player (it sits in that player's half of the screen in two-player
## mode). If your partner is in the same building, you see them too.

var pfx := ""   ## input action prefix: "" for player 1, "p2_" for player 2

const TEX: Texture2D = preload("res://assets/interiors.png")
const TILE := 16
const FADE := 0.28
const C_TEXT := Color("e8dfc8")

## Room layouts. `size`: the floor in tiles (the back wall is two rows above
## row 0). Objects: [art name, cell of the top-left of its footprint]; wall
## hangings use row -2. `keeper`: where the keeper stands (behind a counter).
const ROOMS := {
	"shop": {"size": Vector2i(11, 7), "floor": ["check_a", "check_b"], "wall": "plaster", "keeper": Vector2i(2, 2),
		"door": Vector2i(5, 6), "objects": [
			["window", Vector2i(4, -2)], ["painting", Vector2i(6, -2)],
			["shelf_potions", Vector2i(0, 0)], ["shelf_goods", Vector2i(2, 0)], ["shelf_potions", Vector2i(7, 0)],
			["shelf_goods", Vector2i(9, 0)], ["rug_red", Vector2i(1, 4)],
			["counter_l", Vector2i(1, 3)], ["counter_m", Vector2i(2, 3)], ["counter_till", Vector2i(3, 3)], ["counter_r", Vector2i(4, 3)],
			["display", Vector2i(7, 3)], ["display", Vector2i(7, 5)], ["barrel", Vector2i(10, 3)], ["crate", Vector2i(10, 4)],
			["sack", Vector2i(10, 5)], ["plant", Vector2i(0, 6)], ["plant", Vector2i(10, 6)]]},
	"sage": {"size": Vector2i(10, 7), "floor": ["purple_a", "purple_b"], "wall": "stone", "keeper": Vector2i(4, 1),
		"door": Vector2i(5, 6), "objects": [
			["star_chart", Vector2i(3, -2)], ["herbs", Vector2i(6, -2)],
			["shelf_jars", Vector2i(0, 0)], ["bookshelf", Vector2i(8, 0)], ["rug_rune", Vector2i(3, 3)],
			["low_table", Vector2i(4, 2)], ["crystal", Vector2i(6, 1)], ["cauldron", Vector2i(1, 2)],
			["candle_stand", Vector2i(1, 4)], ["candle_stand", Vector2i(8, 4)], ["plant", Vector2i(0, 6)],
			["sack", Vector2i(9, 6)], ["shelf_jars", Vector2i(2, 0)]]},
	"inn": {"size": Vector2i(13, 8), "floor": ["wood_a", "wood_b"], "wall": "paper_red", "keeper": Vector2i(2, 1),
		"door": Vector2i(6, 7), "objects": [
			["crest", Vector2i(5, -2)], ["window_red", Vector2i(8, -2)],
			["shelf_bottles", Vector2i(0, 0)], ["shelf_bottles", Vector2i(2, 0)],
			["counter_l", Vector2i(0, 2)], ["counter_mugs", Vector2i(1, 2)], ["counter_m", Vector2i(2, 2)],
			["counter_mugs", Vector2i(3, 2)], ["counter_r", Vector2i(4, 2)],
			["fireplace", Vector2i(6, 0)], ["stairs", Vector2i(9, 0)], ["bed_red", Vector2i(11, 0)], ["bed_red", Vector2i(12, 0)],
			["rug_green", Vector2i(5, 3)], ["table", Vector2i(6, 3)], ["stool", Vector2i(5, 3)], ["stool", Vector2i(8, 3)],
			["table_cloth", Vector2i(6, 5)], ["stool", Vector2i(5, 5)], ["stool", Vector2i(8, 5)],
			["barrel", Vector2i(12, 5)], ["barrel", Vector2i(12, 6)], ["bed_blue", Vector2i(11, 3)],
			["plant", Vector2i(0, 7)], ["plant", Vector2i(12, 7)], ["clock", Vector2i(10, 3)]]},
	"home0": {"size": Vector2i(10, 6), "floor": ["wood_a", "wood_b"], "wall": "paper_green",
		"door": Vector2i(5, 5), "objects": [
			["window_blue", Vector2i(4, -2)], ["painting", Vector2i(7, -2)],
			["stove", Vector2i(0, 0)], ["cupboard", Vector2i(2, 0)], ["clock", Vector2i(7, 0)], ["bed_blue", Vector2i(9, 0)],
			["rug_blue", Vector2i(3, 3)], ["table", Vector2i(4, 2)], ["stool", Vector2i(3, 2)], ["stool", Vector2i(6, 2)],
			["plant", Vector2i(0, 5)], ["bookshelf", Vector2i(8, 3)], ["barrel", Vector2i(0, 3)]]},
	"home1": {"size": Vector2i(10, 6), "floor": ["green_a", "green_b"], "wall": "paper_blue",
		"door": Vector2i(4, 5), "objects": [
			["window_red", Vector2i(3, -2)], ["painting", Vector2i(1, -2)],
			["bookshelf", Vector2i(0, 0)], ["bed_green", Vector2i(2, 0)], ["cupboard", Vector2i(6, 0)], ["stove", Vector2i(8, 0)],
			["rug_red", Vector2i(4, 3)], ["table_cloth", Vector2i(4, 2)], ["stool", Vector2i(3, 2)], ["stool", Vector2i(6, 2)],
			["plant", Vector2i(9, 5)], ["clock", Vector2i(9, 3)], ["crate", Vector2i(0, 4)], ["sack", Vector2i(0, 5)]]},
	"home2": {"size": Vector2i(11, 6), "floor": ["wood_b", "wood_a"], "wall": "panel",
		"door": Vector2i(5, 5), "objects": [
			["window", Vector2i(5, -2)], ["herbs", Vector2i(1, -2)],
			["fireplace", Vector2i(0, 0)], ["cupboard", Vector2i(3, 0)], ["bed_red", Vector2i(9, 0)], ["bed_blue", Vector2i(10, 0)],
			["rug_green", Vector2i(3, 3)], ["table", Vector2i(4, 3)], ["stool", Vector2i(3, 3)], ["stool", Vector2i(6, 3)],
			["plant", Vector2i(10, 5)], ["barrel", Vector2i(0, 4)], ["bookshelf", Vector2i(7, 0)]]},
}
## Things you can poke at (A while facing them).
const FLAVOR := {
	"bookshelf": ["DUSTY BOOKS. ONE IS CALLED 'A HUNDRED WAYS TO LIGHT A CANDLE'.", "A BOOK OF MAPS. EVERY ONE OF THEM IS DIFFERENT, AND ALL OF THEM ARE WRONG.",
		"A DIARY. YOU PUT IT BACK. SOME THINGS AREN'T YOURS TO READ."],
	"shelf_potions": ["ROWS OF LITTLE BOTTLES. THE SHOPKEEPER WATCHES YOUR HANDS."],
	"shelf_goods": ["BREAD, JARS, ODDS AND ENDS. IT SMELLS LIKE A KITCHEN."],
	"shelf_bottles": ["BOTTLES OF SOMETHING STRONG. THE LABELS ARE HAND-WRITTEN AND UNREADABLE."],
	"shelf_jars": ["JARS OF ROOTS, EYES OF NEWTS, AND SOMETHING THAT BLINKED. PROBABLY NOT."],
	"cupboard": ["PLATES AND BOWLS, STACKED NEATLY."],
	"fireplace": ["THE FIRE CRACKLES. YOUR BONES WARM UP A LITTLE."],
	"stove": ["SOMETHING IS SIMMERING. IT SMELLS GOOD."],
	"cauldron": ["IT BUBBLES. IT SMELLS OF MINT AND SOMETHING MUCH WORSE."],
	"crystal": ["THE CRYSTAL BALL SHOWS... YOUR OWN FACE, UPSIDE DOWN."],
	"clock": ["TICK... TOCK... IT'S ALWAYS LATER THAN YOU THINK."],
	"bed_red": ["A SOFT BED. TALK TO THE INNKEEPER IF YOU WANT TO SLEEP."],
	"bed_blue": ["A SOFT BED. IT LOOKS VERY INVITING."], "bed_green": ["A NEATLY MADE BED."],
	"stairs": ["THE ROOMS UPSTAIRS ARE TAKEN."],
	"barrel": ["A BARREL. IT SLOSHES."], "crate": ["A CRATE. NAILED SHUT."], "sack": ["A SACK OF FLOUR."],
	"plant": ["A HAPPY LITTLE PLANT. SOMEONE WATERS IT."],
	"display": ["NICE THINGS ON A RED CLOTH. TALK TO THE SHOPKEEPER TO BUY."],
	"table": ["A TABLE, WORN SMOOTH BY YEARS OF ELBOWS."], "table_cloth": ["A TABLE WITH A CLEAN WHITE CLOTH."],
	"stool": ["A STOOL."], "candle_stand": ["A TALL CANDLE. THE WAX DRIPS SLOWLY."],
}

var hero: Hero
var villages: Villages
var screen_menu: VillageScreen
var active := false
var vi := -1
var building: Dictionary = {}
var kind := ""
var room: Dictionary = {}
var cell := Vector2i.ZERO
var facing := 1                   # 0 down 1 up 2 left 3 right (HeroLook)
var _from := Vector2.ZERO
var _pos := Vector2.ZERO
var _move_t := 1.0
var _move_len := 0.22
var _step := 0
var _phase := ""                  # enter_out, enter_in, inside, exit_out, exit_in
var _fade_t := 0.0
var _solid := {}                  # cell -> object name
var _objects: Array = []          # [name, cell]
var _people: Array[Dictionary] = []
var _canvas: Node2D
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _home_talks := 0
var _busy_frame := -10


func setup(h: Hero, v: Villages, menu: VillageScreen) -> void:
	hero = h
	villages = v
	screen_menu = menu
	layer = 4
	visible = false
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_room)
	add_child(_canvas)


## Walk in through the door of building `b` in village `village`.
func enter(village: int, b: Dictionary) -> void:
	if active:
		return
	active = true
	vi = village
	building = b
	kind = b.kind
	var key: String = kind
	if kind == "home":
		key = "home" + str(int(b.variant) % 3)
	room = ROOMS[key]
	_objects = room.objects
	_solid.clear()
	for o in _objects:
		var art: Array = InteriorArt.ART[o[0]]
		if art[3] != "block":
			continue
		for y in art[2]:
			for x in art[1]:
				_solid[o[1] + Vector2i(x, y)] = o[0]
	cell = room.door
	facing = 1
	_pos = Vector2(cell * TILE)
	_move_t = 1.0
	_rng.seed = int(villages.list[vi].seed) + (b.door as Vector2i).x * 131 + (b.door as Vector2i).y * 7
	_home_talks = 0
	_people.clear()
	if room.has("keeper"):
		var look: int = {"shop": 15, "sage": 16, "inn": 17}[kind]
		_people.append({"cell": room.keeper, "look": look, "dir": 0, "keeper": true, "pos": Vector2(room.keeper * TILE),
			"from": Vector2(room.keeper * TILE), "t": 1.0, "wait": 0.0})
	else:
		var n := 1 + _rng.randi() % 2
		for k in n:
			var c := _free_cell()
			_people.append({"cell": c, "look": (_rng.randi() % Villages.VILLAGER_LOOKS) if k == 0 else Villages.CHILD_LOOKS[_rng.randi() % 2],
				"dir": 0, "keeper": false, "child": k > 0, "pos": Vector2(c * TILE), "from": Vector2(c * TILE), "t": 1.0,
				"wait": _rng.randf_range(0.5, 2.0)})
	hero.player.ui_lock = "interior"
	visible = true
	_phase = "enter_out"
	_fade_t = 0.0
	Sfx.play("door_open", -6.0)


func _free_cell() -> Vector2i:
	var size: Vector2i = room.size
	for k in 60:
		var c := Vector2i(_rng.randi_range(0, size.x - 1), _rng.randi_range(1, size.y - 2))
		if not _solid.has(c) and c != room.door and _person_at(c).is_empty():
			return c
	return Vector2i(1, 1)


func _person_at(c: Vector2i) -> Dictionary:
	for p in _people:
		if p.cell == c:
			return p
	return {}


func _partner_here() -> Hero:
	var other := hero.partner()
	if other != null and other.interior != null and other.interior.active and other.interior.vi == vi \
			and other.interior.building.get("door") == building.get("door"):
		return other
	return null


func _blocked(c: Vector2i) -> bool:
	var size: Vector2i = room.size
	if c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y or _solid.has(c) or not _person_at(c).is_empty():
		return true
	var other := _partner_here()
	return other != null and other.interior.cell == c


# --- Every frame -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not active:
		return
	_time += delta
	_canvas.queue_redraw()
	match _phase:
		"enter_out":
			_fade_t += delta
			if _fade_t >= FADE:
				_phase = "enter_in"
				_fade_t = 0.0
				if kind == "shop":
					Sfx.play("shop_bell")
		"enter_in":
			_fade_t += delta
			if _fade_t >= FADE:
				_phase = "inside"
		"exit_out":
			_fade_t += delta
			if _fade_t >= FADE:
				_phase = "exit_in"
				_fade_t = 0.0
				hero.player.facing = Player.Facing.DOWN
		"exit_in":
			_fade_t += delta
			if _fade_t >= FADE:
				active = false
				visible = false
				hero.player.ui_lock = ""
			return
	for p in _people:
		_move_person(p, delta)
	if _move_t < 1.0:
		_move_t = minf(_move_t + delta / _move_len, 1.0)
		_pos = _from.lerp(Vector2(cell * TILE), _move_t)
		if _move_t >= 1.0:
			_step += 1
		return
	if _phase != "inside" or hero.player.ui_lock != "interior" or hero.dialog.is_open() or screen_menu.visible:
		_busy_frame = Engine.get_process_frames()
		return
	if Engine.get_process_frames() - _busy_frame <= 1:
		return   # (the press that closed a text box isn't a new one)
	if Input.is_action_just_pressed(pfx + "confirm"):
		_interact()
		return
	var dir := Vector2i.ZERO
	if Input.is_action_pressed(pfx + "move_down"):
		dir = Vector2i.DOWN
	elif Input.is_action_pressed(pfx + "move_up"):
		dir = Vector2i.UP
	elif Input.is_action_pressed(pfx + "move_left"):
		dir = Vector2i.LEFT
	elif Input.is_action_pressed(pfx + "move_right"):
		dir = Vector2i.RIGHT
	if dir == Vector2i.ZERO:
		return
	facing = {Vector2i.DOWN: 0, Vector2i.UP: 1, Vector2i.LEFT: 2, Vector2i.RIGHT: 3}[dir]
	# off the door mat and out
	if cell == room.door and dir == Vector2i.DOWN:
		_phase = "exit_out"
		_fade_t = 0.0
		Sfx.play("door_open", -8.0)
		return
	if _blocked(cell + dir):
		return
	_from = _pos
	cell += dir
	_move_t = 0.0
	_move_len = Player.RUN_TIME if Input.is_action_pressed(pfx + "sprint") else Player.WALK_TIME
	Sfx.play("step_stone" + str(_step % 3), -4.0)


func _move_person(p: Dictionary, delta: float) -> void:
	if p.t < 1.0:
		p.t = minf(p.t + delta * 2.6, 1.0)
		p.pos = (p.from as Vector2).lerp(Vector2(p.cell * TILE), p.t)
		return
	if p.keeper:
		return
	p.wait -= delta
	if p.wait > 0.0:
		return
	p.wait = _rng.randf_range(0.8, 3.0)
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var d: Vector2i = dirs[_rng.randi() % 4]
	var n: Vector2i = p.cell + d
	p.dir = {Vector2i.DOWN: 0, Vector2i.UP: 1, Vector2i.LEFT: 2, Vector2i.RIGHT: 3}[d]
	if _blocked(n) or n == cell or n == room.door or n.y == 0:
		return
	p.from = p.pos
	p.cell = n
	p.t = 0.0


## A while facing something.
func _interact() -> void:
	var dir: Vector2i = [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT][facing]
	var f := cell + dir
	var p := _person_at(f)
	var thing: String = _solid.get(f, "")
	# the keeper, or their counter / table
	if (not p.is_empty() and p.keeper) or thing.begins_with("counter") or (thing == "low_table" and kind == "sage"):
		for q in _people:
			if q.keeper:
				q.dir = 0
		screen_menu.compact = true
		screen_menu.return_lock = "interior"
		screen_menu.open(vi, building)
		return
	if not p.is_empty():
		_talk_home(p)
		return
	if FLAVOR.has(thing):
		var lines: Array = FLAVOR[thing]
		hero.dialog.say(lines[randi() % lines.size()])
		Sfx.play("ui_select", -6.0)


func _talk_home(p: Dictionary) -> void:
	p.dir = {Vector2i.DOWN: 0, Vector2i.UP: 1, Vector2i.LEFT: 2, Vector2i.RIGHT: 3}.get(cell - (p.cell as Vector2i), 0)
	p.wait = 4.0
	var icon := "npc:" + str(p.look)
	if p.get("child", false):
		hero.dialog.say(VillageTalk.CHILD[randi() % VillageTalk.CHILD.size()], icon)
		return
	var door: Vector2i = building.door
	if _home_talks == 0:
		hero.dialog.say(VillageScreen.HOME_HELLO[_rng.randi() % VillageScreen.HOME_HELLO.size()], icon)
		if not villages.gifts_given.has(door):
			villages.gifts_given[door] = true
			if _rng.randf() < 0.45:
				var inv := hero.inventory
				if _rng.randf() < 0.6:
					var n := _rng.randi_range(2, 5)
					inv.rubies += n
					inv.changed.emit()
					hero.dialog.say(VillageScreen.HOME_GIFT + " (+" + str(n) + " RUBIES)", icon)
					Sfx.play("coin")
				elif inv.slot_for("red_berry") != -1:
					inv.add_stack({"id": "red_berry", "qty": 1})
					hero.dialog.say(VillageScreen.HOME_GIFT + " (+ RED BERRIES)", icon)
	else:
		hero.dialog.say(VillageScreen.HOME_TALK[(_rng.randi() + _home_talks) % VillageScreen.HOME_TALK.size()], icon)
	_home_talks += 1
	Sfx.play("voice" + str(randi() % 4), -4.0)


# --- Drawing ----------------------------------------------------------------------------

func _origin() -> Vector2:
	var screen := _canvas.get_viewport_rect().size
	var size: Vector2i = room.size
	return ((screen - Vector2(size.x * TILE, (size.y + 2) * TILE)) / 2.0 + Vector2(0, 2 * TILE + 6)).round()


func _art(name: String, at: Vector2) -> void:
	var a: Array = InteriorArt.ART[name]
	var r: Rect2 = a[0]
	_canvas.draw_texture_rect_region(TEX, Rect2(at, r.size), r)


func _draw_room() -> void:
	var screen := _canvas.get_viewport_rect().size
	var fade := 0.0
	match _phase:
		"enter_out": fade = _fade_t / FADE
		"enter_in": fade = 1.0 - _fade_t / FADE
		"exit_out": fade = _fade_t / FADE
		"exit_in": fade = 1.0 - _fade_t / FADE
	var show_room := _phase in ["enter_in", "inside", "exit_out"]
	if show_room:
		_canvas.draw_rect(Rect2(Vector2.ZERO, screen), Color("06040a"))
		_draw_inside()
	if fade > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, clampf(fade, 0.0, 1.0)))


func _draw_inside() -> void:
	var o := _origin()
	var size: Vector2i = room.size
	var floors: Array = room.floor
	# floor
	for y in size.y:
		for x in size.x:
			var c := Vector2i(x, y)
			var name: String = "doormat" if c == room.door else (floors[1] if (x * 7 + y * 13) % 5 == 0 else floors[0])
			_art(name, o + Vector2(c * TILE))
	# back wall
	for x in size.x:
		_art(room.wall + ("_b" if (x * 5) % 3 == 0 else ""), o + Vector2(x * TILE, -2 * TILE))
	# side shadows and the wall's foot
	_canvas.draw_rect(Rect2(o + Vector2(0, 0), Vector2(size.x * TILE, 3)), Color(0, 0, 0, 0.25))
	_canvas.draw_rect(Rect2(o + Vector2(-3, -2 * TILE), Vector2(3, (size.y + 2) * TILE)), Color("1a1220"))
	_canvas.draw_rect(Rect2(o + Vector2(size.x * TILE, -2 * TILE), Vector2(3, (size.y + 2) * TILE)), Color("1a1220"))
	# wall hangings and rugs
	for ob in _objects:
		var a: Array = InteriorArt.ART[ob[0]]
		var r: Rect2 = a[0]
		if a[3] == "wall":
			_art(ob[0], o + Vector2(ob[1].x * TILE + 4, -2 * TILE + 7))
		elif a[3] == "floor":
			_art(ob[0], o + Vector2(ob[1] * TILE) + Vector2(0, a[2] * TILE - r.size.y))
	# everything standing, back to front
	var items: Array = []
	for ob in _objects:
		var a: Array = InteriorArt.ART[ob[0]]
		if a[3] == "block":
			items.append([ob[1].y + a[2] - 1, 0, ob])
	for p in _people:
		items.append([int(roundf(p.pos.y / TILE)), 1, p])
	items.append([int(roundf(_pos.y / TILE)), 2, null])
	var other := _partner_here()
	if other != null:
		items.append([other.interior.cell.y, 3, other])
	items.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for it in items:
		match it[1]:
			0:
				var ob: Array = it[2]
				var a: Array = InteriorArt.ART[ob[0]]
				var r: Rect2 = a[0]
				var foot := Vector2(a[1] * TILE, a[2] * TILE)
				var at := o + Vector2(ob[1] * TILE) + Vector2((foot.x - r.size.x) / 2.0, foot.y - r.size.y)
				Shadows.oval(_canvas, at + Vector2(r.size.x / 2.0, r.size.y - 1), r.size.x * 0.8)
				_art(ob[0], at.round())
				_animate(ob[0], at.round())
			1:
				var p: Dictionary = it[2]
				var row: int = [0, 1, 2, 3][int(p.dir)]
				var col := 0 if p.t >= 1.0 else 1 + int(p.t * 4.0) % 4
				var base: Vector2 = o + (p.pos as Vector2).round()
				Shadows.oval(_canvas, base + Vector2(8, 15), 12)
				var src := Rect2(col * 16, (int(p.look) * 4 + row) * 24, 16, 24)
				if p.get("child", false):
					_canvas.draw_texture_rect_region(Villages.NPC_TEX, Rect2(base + Vector2(2, -2), Vector2(12, 18)), src)
				else:
					_canvas.draw_texture_rect_region(Villages.NPC_TEX, Rect2(base + Vector2(0, -8), Vector2(16, 24)), src)
			2:
				_draw_hero(hero, o + _pos.round(), facing, _move_t, _step)
			3:
				var oh: Hero = it[2]
				_draw_hero(oh, o + oh.interior._pos.round(), oh.interior.facing, oh.interior._move_t, oh.interior._step)
	# a little bar at the top: where you are, your hearts and rubies
	var title: String = {"shop": "THE SHOP", "sage": "THE SAGE'S HUT", "inn": "THE INN"}.get(kind, "A HOME")
	var screen := _canvas.get_viewport_rect().size
	PixelFont.draw(_canvas, Vector2(floorf((screen.x - PixelFont.width_of(title)) / 2.0), 4), title, Color("ffd38a"))
	PixelFont.draw(_canvas, Vector2(6, 4), "HEARTS " + str(hero.inventory.health) + "/" + str(hero.inventory.max_health), C_TEXT)
	Items.draw_icon(_canvas, "ruby", Rect2(screen.x - 44, -1, 16, 16))
	PixelFont.draw(_canvas, Vector2(screen.x - 28, 4), "X" + str(hero.inventory.rubies), C_TEXT)
	if _phase == "inside" and cell == room.door and _time > 0.0:
		var hint := "DOWN: GO OUTSIDE"
		PixelFont.draw(_canvas, Vector2(floorf((screen.x - PixelFont.width_of(hint)) / 2.0), screen.y - 9), hint, Color("8a8299"))


func _draw_hero(h: Hero, at: Vector2, face: int, move_t: float, step: int) -> void:
	var col := 0
	if move_t < 1.0:
		col = 1 + (step % 2) * 2 + (1 if move_t > 0.5 else 0)
	Shadows.oval(_canvas, at + Vector2(8, 15), 12)
	HeroLook.use(h.player)
	HeroLook.draw(_canvas, at + Vector2(0, -8), 1.0, face, col, h.player.armor_id, h.player.weapon_id)


## Fire, bubbles and candle flames.
func _animate(name: String, at: Vector2) -> void:
	match name:
		"fireplace":
			for k in 5:
				var hgt := 5.0 + sin(_time * 9.0 + k * 1.9) * 3.0 + 3.0
				var col := Color("ffcf6a") if k % 2 else Color("f5a33a")
				_canvas.draw_rect(Rect2(at + Vector2(9 + k * 3, 33 - hgt), Vector2(3, hgt)), col)
			_canvas.draw_rect(Rect2(at + Vector2(12, 30), Vector2(8, 3)), Color("fff0b0"))
		"cauldron":
			for k in 3:
				var ph := fmod(_time * 0.9 + k * 0.33, 1.0)
				_canvas.draw_rect(Rect2(at + Vector2(7 + k * 4, 6 - ph * 8.0), Vector2(2, 2)), Color(0.7, 1.0, 0.7, 1.0 - ph))
		"candle_stand":
			var fl := roundf(sin(_time * 10.0 + at.x) * 0.6)
			_canvas.draw_rect(Rect2(at + Vector2(7, -2 - fl), Vector2(2, 3 + fl)), Color("ffcf6a"))
		"low_table":
			for x0 in [4.0, 26.0]:
				var fl := roundf(sin(_time * 11.0 + x0) * 0.6)
				_canvas.draw_rect(Rect2(at + Vector2(x0, -1 - fl), Vector2(2, 2 + fl)), Color("ffcf6a"))
		"crystal":
			var g := 0.5 + 0.5 * sin(_time * 2.0)
			_canvas.draw_circle(at + Vector2(8, 8), 7.0 + g, Color(0.75, 0.6, 1.0, 0.15 + 0.1 * g))
		"stove":
			var ph := fmod(_time * 0.5, 1.0)
			_canvas.draw_rect(Rect2(at + Vector2(24, -2 - ph * 8.0), Vector2(2, 2)), Color(0.9, 0.9, 0.95, 0.5 * (1.0 - ph)))
