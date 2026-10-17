class_name Wisps
extends Node2D
## Sprites: little floating flames with faces that drift slowly around the
## labyrinth. They're harmless. Walk into one and it asks you a riddle
## (riddle_screen.gd); answer right and it grants an upgrade or a clue.
## Either way it vanishes afterwards, and another appears somewhere else.

signal touched(w: Dictionary)

const TEX: Texture2D = preload("res://assets/wisps.png")
const KINDS := 6
const COLORS := [Color(0.4, 0.7, 1.0), Color(0.5, 1.0, 0.55), Color(0.75, 0.55, 1.0),
	Color(1.0, 0.78, 0.35), Color(1.0, 0.55, 0.75), Color(0.4, 1.0, 0.9)]
const TILES_PER_WISP := 1600     # about 15 on the big map
const STEP_TIME := 0.75          # seconds to drift one tile
const WANDER := 3                # sprites roam this many tiles from where they appeared
const RESPAWN_TIME := 40.0       # a new sprite appears this long after one vanishes
const MIN_PLAYER_DIST := 8

var world: World
var player: Player
var lighting: Lighting
var enemies: Enemies
var list: Array[Dictionary] = []   # {cell, pos, from, to, t, moving, kind, wait, light}
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _respawns: Array[float] = []


func setup(w: World, p: Player, l: Lighting, e: Enemies) -> void:
	world = w
	player = p
	lighting = l
	enemies = e
	_rng.seed = world.seed_value + 909
	z_index = 2
	for n in maxi(4, (world.width * world.height) / TILES_PER_WISP):
		_spawn()


func wisp_at(c: Vector2i) -> Dictionary:
	for w in list:
		if w.cell == c:
			return w
	return {}


func bind(h: Hero) -> void:
	player = h.player


func _on_hero(c: Vector2i) -> bool:
	for h in Hero.all:
		if h.player.cell == c:
			return true
	return c == player.cell


func _free(c: Vector2i) -> bool:
	return world.is_walkable(c) and not _on_hero(c) and wisp_at(c).is_empty() and not world.near_village(c, 1) \
		and (enemies == null or enemies.enemy_at(c) == null)


func _spawn() -> void:
	for attempt in 200:
		var c := Vector2i(_rng.randi_range(1, world.width - 2), _rng.randi_range(1, world.height - 2))
		if not _free(c) or (Vector2(c) - Vector2(player.cell)).length() < MIN_PLAYER_DIST:
			continue
		var kind := _rng.randi() % KINDS
		var w := {"cell": c, "home": c, "pos": world.cell_to_position(c), "from": Vector2.ZERO, "to": Vector2.ZERO,
			"t": 0.0, "moving": false, "kind": kind, "wait": _rng.randf_range(0.5, 3.0), "seed": _rng.randf() * 10.0}
		w.light = lighting.add_light(self, w.pos + Vector2(8, 8), 30.0, COLORS[kind], 0.7, 0.08)
		list.append(w)
		return


## Loading a saved game: the sprites back where they were.
func restore(saved: Array, respawns: Array) -> void:
	for w in list:
		lighting.remove_light(w.light)
	list.clear()
	for s in saved:
		var c: Vector2i = s.cell
		var w := {"cell": c, "home": s.home, "pos": world.cell_to_position(c), "from": Vector2.ZERO, "to": Vector2.ZERO,
			"t": 0.0, "moving": false, "kind": s.kind, "wait": _rng.randf_range(0.5, 3.0), "seed": _rng.randf() * 10.0}
		w.light = lighting.add_light(self, w.pos + Vector2(8, 8), 30.0, COLORS[s.kind], 0.7, 0.08)
		list.append(w)
	_respawns.assign(respawns)


## The sprite has done its job: it bursts into sparks and fades.
func vanish(w: Dictionary) -> void:
	list.erase(w)
	lighting.remove_light(w.light)
	_respawns.append(RESPAWN_TIME)
	var p := CPUParticles2D.new()
	p.position = w.pos + Vector2(8, 8)
	p.one_shot = true
	p.amount = 30
	p.lifetime = 1.0
	p.explosiveness = 0.9
	p.spread = 180.0
	p.gravity = Vector2(0, -20)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 35.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1))
	ramp.set_color(1, Color(COLORS[w.kind], 0.0))
	p.color_ramp = ramp
	p.emitting = true
	add_child(p)
	p.finished.connect(p.queue_free)


func _process(delta: float) -> void:
	_time += delta
	for i in range(_respawns.size() - 1, -1, -1):
		_respawns[i] -= delta
		if _respawns[i] <= 0.0:
			_respawns.remove_at(i)
			_spawn()
	var paused := player.ui_lock == "intro"
	for w in list:
		if w.moving:
			w.t += delta / STEP_TIME
			if w.t >= 1.0:
				w.pos = w.to
				w.moving = false
			else:
				w.pos = w.from.lerp(w.to, ease(w.t, -1.6))
		elif not paused:
			w.wait -= delta
			if w.wait <= 0.0:
				w.wait = _rng.randf_range(0.3, 1.6)
				# hold still once you're right next to it, so you can reach it
				var close := false
				for h in Hero.all:
					var near: Vector2i = (w.cell - h.player.cell).abs()
					if near.x + near.y <= 1:
						close = true
				if close:
					w.wait = 0.6
					continue
				var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
				var d: Vector2i = dirs[_rng.randi() % 4]
				var off: Vector2i = (w.cell + d - w.home).abs()
				if maxi(off.x, off.y) <= WANDER and _free(w.cell + d):
					w.cell += d
					w.from = w.pos
					w.to = world.cell_to_position(w.cell)
					w.t = 0.0
					w.moving = true
		w.light.offset = w.pos + Vector2(8 + _sway(w), 6 + sin(_time * 2.0 + w.seed) * 2.0)
	queue_redraw()


## A gentle side-to-side drift, so a sprite is never quite still.
func _sway(w: Dictionary) -> float:
	return sin(_time * 1.3 + w.seed * 2.0) * 1.5 + sin(_time * 2.9 + w.seed) * 0.8


func _draw() -> void:
	var view := world._visible_cells()
	for w in list:
		if not view.has_point(w.cell):
			continue
		paint_one(self, w, w.pos)


## One sprite, its tile's top-left at `at`.
func paint_one(ci: CanvasItem, w: Dictionary, at: Vector2) -> void:
	var bob := roundf(sin(_time * 2.0 + w.seed) * 2.0) - 3.0
	var frame := int(_time * 5.0 + w.seed) % 2
	Shadows.oval(ci, at + Vector2(8, 15), 8, 0.5)
	ci.draw_texture_rect_region(TEX, Rect2((at + Vector2(_sway(w), bob)).round(), Vector2(16, 16)),
		Rect2(frame * 16, w.kind * 16, 16, 16))
