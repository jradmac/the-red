class_name Bombs
extends Node2D
## Planted bombs. Plant one (B, or from the bag) and it sits at your feet,
## fuse fizzing, blinking faster and faster -- then it goes off. Every
## insect and demon within BLAST_RADIUS is blown to smoke (and drops what it
## carried), a ghost caught in it is scattered, and if you're still standing
## right beside it you get hurt too. It leaves a scorch mark for a while.

signal exploded(at: Vector2)
signal hurt_player(damage: int)

const FUSE := 2.2              # seconds
const BLAST_RADIUS := 2.6      # tiles
const SELF_RADIUS := 1.2       # tiles: this close and it catches you too
const SELF_DAMAGE := 2
const SCORCH_TIME := 90.0

var world: World
var player: Player
var enemies: Enemies
var fx: Fx
var slay: Callable            ## main: kills an enemy the way a won fight does (drops, stats)
var planted: Array[Dictionary] = []   # {cell, t}
var scorches: Array[Dictionary] = []  # {pos, t, seed}
var _time := 0.0


func setup(w: World, p: Player, e: Enemies, f: Fx) -> void:
	world = w
	player = p
	enemies = e
	fx = f


func bind(h: Hero) -> void:
	player = h.player


func bomb_at(c: Vector2i) -> bool:
	for b in planted:
		if b.cell == c:
			return true
	return false


## Plants a bomb on the hero's tile. Returns the message to show.
func plant() -> String:
	var c := player.cell
	if bomb_at(c):
		return ""
	planted.append({"cell": c, "t": 0.0})
	Sfx.play("bomb_plant")
	return "YOU PLANT THE BOMB. RUN!"


func _process(delta: float) -> void:
	_time += delta
	var paused := player.ui_lock == "intro"
	for i in range(planted.size() - 1, -1, -1):
		if not paused:
			planted[i].t += delta
		if planted[i].t >= FUSE:
			var c: Vector2i = planted[i].cell
			planted.remove_at(i)
			_explode(c)
	for s in scorches:
		s.t += delta
	scorches = scorches.filter(func(s): return s.t < SCORCH_TIME)
	Sfx.fuse(not planted.is_empty() and not paused)
	queue_redraw()


func _explode(c: Vector2i) -> void:
	var at := world.cell_to_position(c) + Vector2(8, 10)
	fx.explosion(at, BLAST_RADIUS * World.TILE)
	Sfx.play_at("explosion", at, 2.0)
	scorches.append({"pos": at, "t": 0.0, "seed": randi() % 1000})
	exploded.emit(at)
	var center := Vector2(c)
	for e in enemies.list.duplicate():
		if not e.visible:
			continue
		var d := (Vector2(e.cell) - center).length()
		if d > BLAST_RADIUS:
			continue
		if e.kind == "ghost":
			enemies.scatter_ghost(e)
		elif slay.is_valid():
			slay.call(e)
	# chain reaction: other bombs in the blast go off too
	for b in planted:
		if (Vector2(b.cell) - center).length() <= BLAST_RADIUS:
			b.t = maxf(b.t, FUSE - 0.12)
	for h in Hero.all:
		if h.alive() and (Vector2(h.player.cell) - center).length() <= SELF_RADIUS:
			Hero.bind_all(h)
			hurt_player.emit(SELF_DAMAGE)


var hide_planted := false   ## (the 3D view draws the bombs itself)


func _draw() -> void:
	# scorch marks: an irregular sooty blot that slowly fades
	for s in scorches:
		var a := 0.55 * clampf(1.0 - (s.t - SCORCH_TIME * 0.7) / (SCORCH_TIME * 0.3), 0.0, 1.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = s.seed
		draw_circle(s.pos, 13.0, Color(0.05, 0.03, 0.03, a * 0.6))
		for k in 10:
			var off := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(6.0, 16.0)
			draw_circle(s.pos + off, rng.randf_range(2.0, 5.0), Color(0.06, 0.04, 0.04, a * 0.7))
		draw_circle(s.pos, 6.0, Color(0.02, 0.01, 0.01, a))
		if s.t < 6.0:   # embers still glowing in the crater
			for k in 5:
				var off2 := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1.0, 9.0)
				if fmod(_time * 3.0 + k * 0.7, 1.0) < 0.6:
					draw_rect(Rect2((s.pos + off2).round(), Vector2.ONE), Color(1.0, 0.45, 0.1, 1.0 - s.t / 6.0))
	# the bombs themselves (the 3D view shows them standing in the world instead)
	if not hide_planted:
		for b in planted:
			paint_bomb(self, b, world.cell_to_position(b.cell))


## Draws a planted bomb (fuse, sparks, blinking) on `ci` with its tile's
## top-left at `o`.
func paint_bomb(ci: CanvasItem, b: Dictionary, o: Vector2) -> void:
	var left := FUSE - float(b.t)
	var shake := Vector2(roundf(sin(_time * 50.0)) if left < 0.6 else 0.0, 0)
	var p := o + Vector2(8, 10) + shake
	ci.draw_rect(Rect2(p + Vector2(-5, 3), Vector2(11, 2)), Color(0, 0, 0, 0.35))   # shadow
	ci.draw_circle(p, 5.0, Color("0c0a12"))
	ci.draw_circle(p, 4.0, Color("3a3650"))
	ci.draw_circle(p + Vector2(1, 1), 3.0, Color("24202f"))
	ci.draw_rect(Rect2(p + Vector2(-3, -3), Vector2(2, 1)), Color("8a86a8"))
	ci.draw_rect(Rect2(p + Vector2(-3, -2), Vector2(1, 1)), Color("8a86a8"))
	ci.draw_rect(Rect2(p + Vector2(-1, -6), Vector2(2, 2)), Color("7a7488"))   # cap
	# the fuse burns down
	var fuse_len := int(ceil(4.0 * left / FUSE))
	for k in fuse_len:
		ci.draw_rect(Rect2(p + Vector2(k * 0.6, -7 - k), Vector2.ONE), Color("c8b48a"))
	var tip := p + Vector2(fuse_len * 0.6, -7 - fuse_len)
	var sparkle := fmod(_time * 20.0, 1.0)
	ci.draw_rect(Rect2(tip.round() - Vector2.ONE, Vector2(3, 3)), Color(1.0, 0.6, 0.15, 0.8))
	ci.draw_rect(Rect2(tip.round(), Vector2.ONE), Color(1, 1, 0.8))
	for k in 3:
		var sp := tip + Vector2.from_angle(sparkle * TAU + k * 2.1) * (2.0 + sparkle * 2.0)
		ci.draw_rect(Rect2(sp.round(), Vector2.ONE), Color(1.0, 0.85, 0.3, 1.0 - sparkle))
	# it blinks red, faster as the fuse runs out
	var rate := lerpf(2.0, 14.0, clampf(float(b.t) / FUSE, 0.0, 1.0))
	if fmod(_time * rate, 1.0) < 0.5:
		ci.draw_circle(p, 4.0, Color(1.0, 0.15, 0.1, 0.55))
