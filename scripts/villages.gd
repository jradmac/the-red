class_name Villages
extends Node2D
## The villages: safe havens behind a wall, lit by lamps, where nothing from
## the labyrinth can follow you. Each has a shop, a sage, an inn, a farm and a
## few homes, guards at both gates and villagers wandering the streets.
##
## The layout comes from LabyrinthGenerator (see _stamp_village); this draws
## it (in the style of the land around it), opens the gates as you come near,
## walks the villagers about, and answers "who's there?" and "whose door is
## this?" for main.gd.
##
## Drawing is in three layers, like the world's: the ground and everything
## standing on it (below the heroes), the people in front of a hero (above
## them), and the tops of tall things (walls, lamps, the well, the gate's
## beam) over everything.

signal entered(h: Hero, vi: int)     ## a hero walked into a village (first time each visit)

const TEX: Texture2D = preload("res://assets/village.png")
const NPC_TEX: Texture2D = preload("res://assets/npcs.png")
const BLOCK := 152
const TILE := 16
const LAMP_COLOR := Color(1.0, 0.78, 0.45)
const WINDOW_COLOR := Color(1.0, 0.72, 0.38)
const WALK_SPEED := 2.4          # tiles per second
const GATE_REACH := 2.6          # tiles: the gate opens when a hero is this close
const GATE_SPEED := 2.5          # how fast it swings
const VILLAGER_LOOKS := 10
const GUARD_LOOK := 10           # + style
const CHILD_LOOKS := [18, 19]

# Where things are in village.png (inside one style's block).
const R_WALL_EW := [Rect2(0, 0, 16, 24), Rect2(16, 0, 16, 24)]
const R_WALL_NS := Rect2(32, 0, 16, 24)
const R_WALL_POST := Rect2(48, 0, 16, 24)
const R_GATE := Rect2(64, 0, 48, 40)
const R_LEAVES := Rect2(112, 0, 16, 24)
const R_BUILDING := {
	"shop": Rect2(0, 43, 80, 64), "sage": Rect2(80, 43, 64, 64), "inn": Rect2(144, 43, 96, 64),
	"home4": Rect2(240, 59, 64, 48), "home5": Rect2(304, 59, 80, 48),
	"home4b": Rect2(384, 59, 64, 48), "home5b": Rect2(448, 59, 80, 48),
}
const PY := 108
const R_PROP := {
	"lamp": Rect2(0, PY + 8, 16, 32), "barrel": Rect2(16, PY + 24, 16, 16), "crate": Rect2(32, PY + 24, 16, 16),
	"pots": Rect2(48, PY + 24, 16, 16), "hay": Rect2(64, PY + 24, 16, 16), "well": Rect2(80, PY, 32, 40),
	"tree": Rect2(112, PY, 32, 40), "bench": Rect2(144, PY + 24, 16, 16), "sign": Rect2(160, PY + 16, 16, 24),
}
const R_ROAD := Rect2(176, PY + 24, 16, 16)       # x += 16 * variant (4)
const R_PLAZA := Rect2(240, PY + 24, 16, 16)      # x += 16 * variant (2)
const R_SOIL := Rect2(272, PY + 24, 16, 16)
const R_FENCE_EW := Rect2(288, PY + 16, 16, 24)
const R_FENCE_NS := Rect2(304, PY + 16, 16, 24)
const R_FENCE_POST := Rect2(320, PY + 16, 16, 24)
const R_FLOWERS := Rect2(336, PY + 24, 16, 16)    # x += 16 * variant (4)

const FIRST_NAMES := ["MARTA", "EDRIC", "HILDE", "OSWIN", "BRAM", "LISBET", "TOMAS", "GRETA", "WILLEM",
	"ANYA", "CORIN", "MAB", "FENN", "IDA", "RUFUS", "ELSA", "PIP", "NELL", "AMOS", "ROSA", "JOREN", "TILDA"]

var world: World
var lighting: Lighting
var day: DayCycle
var forage: Forage
var list: Array = []
var people: Array[Dictionary] = []   ## villagers and guards (see _spawn_people)
var gate_open := {}                  ## gate cell -> 0 (shut) .. 1 (open)
var gifts_given := {}                ## home door -> true (a gift only once per home)
var sold := {}                       ## "village:index" -> how many bought of a one-off shop item
var _inside := {}                    ## hero -> village index they're in (-1 outside)
var _front: Node2D                   ## people standing in front of a hero
var _over: Node2D                    ## the tall parts, over everything
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _road := {}                      ## cell -> style (for the ground pass)
var _plaza := {}
var _soil := {}
var _flowers := {}
var _style := PackedByteArray()      ## per village


func setup(w: World, l: Lighting, d: DayCycle, f: Forage, front_parent: Node) -> void:
	world = w
	lighting = l
	day = d
	forage = f
	list = w.villages
	_rng.seed = w.seed_value + 717
	_front = Node2D.new()
	_front.draw.connect(_draw_front)
	front_parent.add_child(_front)
	_over = Node2D.new()
	_over.z_index = 3
	_over.draw.connect(_draw_over)
	add_child(_over)
	for vi in list.size():
		var v: Dictionary = list[vi]
		var st := clampi(int(v.host) - 1, 0, 4)
		_style.append(st)
		for c in v.road:
			_road[c] = vi
		for g in v.gates:
			_road[g] = vi
			_road[g + (Vector2i.UP if g.y == v.rect.position.y else Vector2i.DOWN)] = vi
			gate_open[g] = 0.0
		var pr: Rect2i = v.plaza
		for y in range(pr.position.y, pr.end.y):
			for x in range(pr.position.x, pr.end.x):
				if not v.solid.has(Vector2i(x, y)):
					_plaza[Vector2i(x, y)] = vi
		for c in v.flowers:
			_flowers[c] = vi
		if not v.farm.is_empty():
			var fi: Rect2i = (v.farm.rect as Rect2i).grow(-1)
			for y in range(fi.position.y, fi.end.y):
				for x in range(fi.position.x, fi.end.x):
					_soil[Vector2i(x, y)] = vi
			_soil[v.farm.opening] = vi
			for bc in v.farm.bushes:
				forage.add_farm_bush(bc, _rng.randf() < 0.3)
		# Light: the lamps, the gate lanterns, a glow at every door.
		for p in v.props:
			if p.kind == "lamp":
				lighting.add_light(self, world.cell_to_position(p.cell) + Vector2(8, -8), 100.0, LAMP_COLOR, 1.15, 0.05)
		for g in v.gates:
			var inward := Vector2i.DOWN if g.y == v.rect.position.y else Vector2i.UP
			lighting.add_light(self, world.cell_to_position(g + inward) + Vector2(8, 0), 80.0, LAMP_COLOR, 1.0, 0.06)
		for b in v.buildings:
			var br: Rect2i = b.rect
			for wx in range(br.position.x, br.end.x, 2):
				lighting.add_light(self, world.cell_to_position(Vector2i(wx, br.end.y)) + Vector2(8, 2), 46.0, WINDOW_COLOR, 0.75, 0.04, false)
		var vr: Rect2i = v.rect
		for k in [Vector2(0.3, 0.3), Vector2(0.7, 0.3), Vector2(0.3, 0.7), Vector2(0.7, 0.7)]:
			var at: Vector2 = Vector2(vr.position) + Vector2(vr.size) * k
			lighting.add_light(self, at * TILE, 150.0, LAMP_COLOR, 0.45, 0.0, false)
		_spawn_people(vi)


func _spawn_people(vi: int) -> void:
	var v: Dictionary = list[vi]
	for g in v.guards:
		people.append({"v": vi, "kind": "guard", "cell": g.cell, "pos": world.cell_to_position(g.cell),
			"from": world.cell_to_position(g.cell), "t": 1.0, "dir": g.facing, "home_dir": g.facing,
			"look": GUARD_LOOK + _style[vi], "wait": 0.0, "name": "GUARD", "line": _rng.randi()})
	var free: Array[Vector2i] = []
	var I: Rect2i = (v.rect as Rect2i).grow(-1)
	for y in range(I.position.y, I.end.y):
		for x in range(I.position.x, I.end.x):
			var c := Vector2i(x, y)
			if _walkable_for_people(c):
				free.append(c)
	var n: int = 3 + v.buildings.size() / 2 + _rng.randi_range(0, 2)
	for k in n:
		if free.is_empty():
			break
		var c: Vector2i = free.pop_at(_rng.randi() % free.size())
		var child := _rng.randf() < 0.2
		people.append({"v": vi, "kind": "child" if child else "villager", "cell": c,
			"pos": world.cell_to_position(c), "from": world.cell_to_position(c), "t": 1.0,
			"dir": Vector2i.DOWN, "look": CHILD_LOOKS[_rng.randi() % 2] if child else _rng.randi() % VILLAGER_LOOKS,
			"wait": _rng.randf_range(0.0, 2.0), "name": FIRST_NAMES[_rng.randi() % FIRST_NAMES.size()],
			"line": _rng.randi()})


func _walkable_for_people(c: Vector2i) -> bool:
	var vi := world.village_at(c)
	if vi < 0 or not world.is_walkable(c) or forage.bush_at(c):
		return false
	var v: Dictionary = list[vi]
	if v.gates.has(c):
		return false
	for b in v.buildings:
		if c == b.door + Vector2i.DOWN:
			return false   # don't stand in doorways
	return true


# --- Questions from main --------------------------------------------------------------

## The person standing on this tile (a Dictionary from `people`), or {}.
func person_at(c: Vector2i) -> Dictionary:
	for p in people:
		if p.cell == c:
			return p
	return {}


func blocks(c: Vector2i) -> bool:
	return not person_at(c).is_empty()


## The building whose door is on this tile, or {}.
func building_at_door(c: Vector2i) -> Dictionary:
	var vi := world.village_at(c)
	if vi < 0:
		return {}
	for b in list[vi].buildings:
		if b.door == c:
			return b
	return {}


func style_of(vi: int) -> int:
	return _style[vi]


# --- Every frame -------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if list.is_empty():
		return
	var heroes: Array = Hero.all.filter(func(h): return h.alive())
	# Gates: open while someone's near, shut behind them.
	for g in gate_open:
		var near := false
		for h in heroes:
			if (Vector2(h.player.cell) - Vector2(g)).length() <= GATE_REACH:
				near = true
		var was: float = gate_open[g]
		gate_open[g] = move_toward(was, 1.0 if near else 0.0, delta * GATE_SPEED)
		if was == 0.0 and gate_open[g] > 0.0 or was == 1.0 and gate_open[g] < 1.0:
			Sfx.play_at("gate", world.cell_to_position(g))
	# Who's inside?
	for h in heroes:
		var vi := world.village_at(h.player.cell)
		if vi >= 0 and list[vi].gates.has(h.player.cell):
			vi = -1   # still in the gateway
		if vi != _inside.get(h, -1):
			_inside[h] = vi
			if vi >= 0:
				entered.emit(h, vi)
	# People.
	for p in people:
		_move_person(p, delta, heroes)
	queue_redraw()
	_front.queue_redraw()
	_over.queue_redraw()


func _move_person(p: Dictionary, delta: float, heroes: Array) -> void:
	if p.t < 1.0:
		p.t = minf(p.t + delta * WALK_SPEED, 1.0)
		p.pos = (p.from as Vector2).lerp(world.cell_to_position(p.cell), p.t)
		return
	p.wait -= delta
	if p.wait > 0.0:
		return
	if p.kind == "guard":
		p.dir = p.home_dir   # back to watching
		p.wait = 1.0
		return
	# Take a step somewhere free (not onto a hero or another person).
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	if _rng.randf() < 0.55 and dirs.has(p.dir):
		dirs = [p.dir]   # keep strolling the same way for a bit
	dirs.shuffle()
	for d in dirs:
		var n: Vector2i = p.cell + d
		if not _walkable_for_people(n) or blocks(n) or world.village_at(n) != p.v:
			continue
		var on_hero := false
		for h in heroes:
			if h.player.cell == n:
				on_hero = true
		if on_hero:
			continue
		p.from = p.pos
		p.cell = n
		p.dir = d
		p.t = 0.0
		p.wait = _rng.randf_range(0.0, 0.4) if _rng.randf() < 0.7 else _rng.randf_range(1.5, 4.0)
		return
	p.wait = _rng.randf_range(0.5, 1.5)


## A hero talks to someone: they turn to face the hero and stop a moment.
func face(p: Dictionary, toward: Vector2i) -> void:
	var d: Vector2i = toward - p.cell
	if d != Vector2i.ZERO:
		p.dir = Vector2i(signi(d.x), 0) if absi(d.x) > absi(d.y) else Vector2i(0, signi(d.y))
	p.wait = 4.0


# --- Drawing ------------------------------------------------------------------------------

func _visible() -> Rect2i:
	var xf := get_viewport().get_canvas_transform()
	var size := get_viewport_rect().size
	var tl := -xf.origin / xf.get_scale()
	var r := Rect2i(Vector2i(tl / TILE) - Vector2i(2, 2), Vector2i(size / xf.get_scale() / TILE) + Vector2i(5, 6))
	# in two-player mode each half has its own camera: draw around both heroes
	for h in Hero.all:
		r = r.merge(Rect2i(h.player.cell - Vector2i(14, 10), Vector2i(29, 21)))
	return r


func _src(vi: int, r: Rect2) -> Rect2:
	return Rect2(r.position + Vector2(0, _style[vi] * BLOCK), r.size)


## Draws a sprite standing on a footprint: its bottom on the footprint's bottom.
## `over` draws only the part that rises above the footprint's top row.
func _stand(ci: CanvasItem, vi: int, r: Rect2, foot: Rect2i, over: bool, xoff: float = 0.0) -> void:
	var src := _src(vi, r)
	var bottom := float(foot.end.y * TILE)
	var top := bottom - src.size.y
	var x := foot.position.x * TILE + (foot.size.x * TILE - src.size.x) / 2.0 + xoff
	if over:
		var rise := float(foot.position.y * TILE) - top
		if rise <= 0.0:
			return
		ci.draw_texture_rect_region(TEX, Rect2(x, top, src.size.x, rise), Rect2(src.position, Vector2(src.size.x, rise)))
	else:
		ci.draw_texture_rect_region(TEX, Rect2(x, top, src.size.x, src.size.y), src)


## The village ground (streets, the square, the field, flowers) for the 3D
## view's baked ground, over cells `r`.
func bake_ground(ci: CanvasItem, r: Rect2i) -> void:
	for layer in [_road, _plaza, _soil, _flowers]:
		for c in layer:
			if not r.has_point(c):
				continue
			var at := Rect2(world.cell_to_position(c), Vector2(TILE, TILE))
			var vi: int = layer[c]
			if layer == _road:
				var h: int = (c.x * 73 + c.y * 151) % 4
				ci.draw_texture_rect_region(TEX, at, _src(vi, Rect2(R_ROAD.position + Vector2(16 * h, 0), R_ROAD.size)))
			elif layer == _plaza:
				ci.draw_texture_rect_region(TEX, at, _src(vi, Rect2(R_PLAZA.position + Vector2(16 * ((c.x + c.y) % 2), 0), R_PLAZA.size)))
			elif layer == _soil:
				ci.draw_texture_rect_region(TEX, at, _src(vi, R_SOIL))
			else:
				var h: int = (c.x * 31 + c.y * 17) % 4
				ci.draw_texture_rect_region(TEX, at, _src(vi, Rect2(R_FLOWERS.position + Vector2(16 * h, 0), R_FLOWERS.size)))


func _draw() -> void:
	if World.flat_hidden:
		return
	var view := _visible()
	# 1. Ground: streets, the square, the field, flowers.
	for c in _road:
		if view.has_point(c):
			var h: int = (c.x * 73 + c.y * 151) % 4
			draw_texture_rect_region(TEX, Rect2(world.cell_to_position(c), Vector2(TILE, TILE)),
				_src(_road[c], Rect2(R_ROAD.position + Vector2(16 * h, 0), R_ROAD.size)))
	for c in _plaza:
		if view.has_point(c):
			draw_texture_rect_region(TEX, Rect2(world.cell_to_position(c), Vector2(TILE, TILE)),
				_src(_plaza[c], Rect2(R_PLAZA.position + Vector2(16 * ((c.x + c.y) % 2), 0), R_PLAZA.size)))
	for c in _soil:
		if view.has_point(c):
			draw_texture_rect_region(TEX, Rect2(world.cell_to_position(c), Vector2(TILE, TILE)), _src(_soil[c], R_SOIL))
	for c in _flowers:
		if view.has_point(c):
			var h: int = (c.x * 31 + c.y * 17) % 4
			draw_texture_rect_region(TEX, Rect2(world.cell_to_position(c), Vector2(TILE, TILE)),
				_src(_flowers[c], Rect2(R_FLOWERS.position + Vector2(16 * h, 0), R_FLOWERS.size)))
	# 2. Everything standing, back to front (row by row).
	for vi in list.size():
		var v: Dictionary = list[vi]
		var P: Rect2i = v.rect
		if not view.intersects(P.grow(2)):
			continue
		_draw_village(self, vi, view, false)
	# 3. People behind the heroes.
	for p in people:
		if view.has_point(p.cell) and not _in_front(p):
			_draw_person(self, p)


func _draw_front() -> void:
	if World.flat_hidden:
		return
	var view := _visible()
	for p in people:
		if view.has_point(p.cell) and _in_front(p):
			_draw_person(_front, p)


func _draw_over() -> void:
	if World.flat_hidden:
		return
	var view := _visible()
	for vi in list.size():
		if view.intersects((list[vi].rect as Rect2i).grow(2)):
			_draw_village(_over, vi, view, true)


## Someone south of the nearest hero is drawn over them.
func _in_front(p: Dictionary) -> bool:
	var best := INF
	var front := false
	for h in Hero.all:
		var d: float = (h.player.position - p.pos).length()
		if d < best:
			best = d
			front = p.pos.y > h.player.position.y
	return front


func _draw_village(ci: CanvasItem, vi: int, view: Rect2i, over: bool) -> void:
	var v: Dictionary = list[vi]
	var P: Rect2i = v.rect
	# things in draw order: each with the row of its footprint's bottom
	var items: Array = []
	for y in range(P.position.y, P.end.y):
		for x in range(P.position.x, P.end.x):
			var c := Vector2i(x, y)
			var k: String = v.solid.get(c, "")
			if k == "wall" or k == "fence":
				if view.has_point(c):
					items.append([y, 0, c, k])
	for g in v.gates:
		items.append([g.y, 1, g, "gate"])
	for b in v.buildings:
		items.append([(b.rect as Rect2i).end.y - 1, 2, b, "building"])
	for p in v.props:
		items.append([p.cell.y, 3, p, "prop"])
	items.append([(v.well as Rect2i).end.y - 1, 4, v.well, "well"])
	items.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for it in items:
		match it[3]:
			"wall":
				_draw_wall(ci, vi, it[2], over)
			"fence":
				_draw_fence(ci, vi, it[2], over)
			"gate":
				_draw_gate(ci, vi, it[2], over)
			"building":
				if not over:
					var b: Dictionary = it[2]
					var r: Rect2i = b.rect
					if view.intersects(r):
						var key: String = b.kind
						if key == "home":
							key = ("home4" if r.size.x == 4 else "home5") + ("b" if int(b.variant) % 2 == 1 else "")
						_cast_shadow(ci, r, (R_BUILDING[key] as Rect2).size.y)
						_stand(ci, vi, R_BUILDING[key], r, false)
			"prop":
				var p: Dictionary = it[2]
				if view.has_point(p.cell):
					var foot := Rect2i(p.cell, Vector2i.ONE)
					if not over:
						Shadows.oval(ci, world.cell_to_position(p.cell) + Vector2(8, 14), 12)
					_stand(ci, vi, R_PROP[p.kind], foot, over)
			"well":
				if view.intersects(it[2]):
					_stand(ci, vi, R_PROP["well"], it[2], over)


## The shadow a building throws on the ground: the light comes from the upper
## left (as in its 3D render), so it falls to the right and a little up the
## street, softening into the ground; plus a dark seam where the walls meet it.
func _cast_shadow(ci: CanvasItem, r: Rect2i, height: float) -> void:
	var R := float(r.end.x * TILE)
	var B := float(r.end.y * TILE)
	var L := float(r.position.x * TILE)
	var reach := 9.0
	for k in 3:
		var g := float(k) * 2.0
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(R - 3, B), Vector2(R + reach - g, B - 3), Vector2(R + reach - g, B - height * 0.62 + g),
			Vector2(R - 3, B - height * 0.8)]), Color(0.02, 0.0, 0.06, 0.09))
	ci.draw_rect(Rect2(L + 2, B - 2, R - L - 2, 3), Color(0.02, 0.0, 0.06, 0.18))


func _draw_wall(ci: CanvasItem, vi: int, c: Vector2i, over: bool) -> void:
	var v: Dictionary = list[vi]
	var solid: Dictionary = v.solid
	var ew: bool = solid.get(c + Vector2i.LEFT, "") == "wall" or solid.get(c + Vector2i.RIGHT, "") == "wall"
	var ns: bool = solid.get(c + Vector2i.UP, "") == "wall" or solid.get(c + Vector2i.DOWN, "") == "wall"
	var by_gate: bool = v.gates.has(c + Vector2i.LEFT) or v.gates.has(c + Vector2i.RIGHT)
	if by_gate:
		return   # the gate frame's posts stand here
	var r := R_WALL_POST
	if ew and not ns:
		r = R_WALL_EW[(c.x * 7 + c.y) % 2]
	elif ns and not ew:
		r = R_WALL_NS
	_stand(ci, vi, r, Rect2i(c, Vector2i.ONE), over)


func _draw_fence(ci: CanvasItem, vi: int, c: Vector2i, over: bool) -> void:
	var solid: Dictionary = list[vi].solid
	var ew: bool = solid.get(c + Vector2i.LEFT, "") == "fence" or solid.get(c + Vector2i.RIGHT, "") == "fence"
	var ns: bool = solid.get(c + Vector2i.UP, "") == "fence" or solid.get(c + Vector2i.DOWN, "") == "fence"
	var r := R_FENCE_POST
	if ew and not ns:
		r = R_FENCE_EW
	elif ns and not ew:
		r = R_FENCE_NS
	_stand(ci, vi, r, Rect2i(c, Vector2i.ONE), over)


func _draw_gate(ci: CanvasItem, vi: int, g: Vector2i, over: bool) -> void:
	var foot := Rect2i(g - Vector2i(1, 0), Vector2i(3, 1))
	if not over:
		var f := clampi(int(round(float(gate_open.get(g, 0.0)) * 3.0)), 0, 3)
		_stand(ci, vi, Rect2(R_LEAVES.position + Vector2(16 * f, 0), R_LEAVES.size), Rect2i(g, Vector2i.ONE), false)
	_stand(ci, vi, R_GATE, foot, over)


func _draw_person(ci: CanvasItem, p: Dictionary) -> void:
	var row := 0
	match p.dir:
		Vector2i.UP: row = 1
		Vector2i.LEFT: row = 2
		Vector2i.RIGHT: row = 3
	var col := 0
	if p.t < 1.0:
		col = 1 + int(p.t * 4.0) % 4
	elif p.kind != "guard" and fmod(_time + float(p.line % 7), 6.0) < 0.15:
		col = 2   # a little shuffle now and then
	var base: Vector2 = (p.pos as Vector2).round()
	var bob := 1.0 if p.kind == "child" else 0.0
	Shadows.oval(ci, base + Vector2(8, 15), 10 if p.kind == "child" else 12)
	var src := Rect2(col * 16, (int(p.look) * 4 + row) * 24, 16, 24)
	if p.kind == "child":
		ci.draw_texture_rect_region(NPC_TEX, Rect2(base + Vector2(2, -2 + bob), Vector2(12, 18)), src)
	else:
		ci.draw_texture_rect_region(NPC_TEX, Rect2(base + Vector2(0, -8), Vector2(16, 24)), src)


## A person's portrait (for building screens): their front-facing standing frame.
static func draw_portrait(ci: CanvasItem, look: int, at: Vector2, scale: float, t: float = 0.0) -> void:
	var col := 0 if fmod(t, 3.0) > 0.2 else 2
	ci.draw_texture_rect_region(NPC_TEX, Rect2(at, Vector2(16, 24) * scale), Rect2(col * 16, look * 4 * 24, 16, 24))
