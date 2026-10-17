class_name Enemy
extends Node2D
## One enemy in the labyrinth. Moves one tile at a time like the hero.
## The brain (what to do next) lives in enemies.gd; this node holds the
## enemy's stats, steps between tiles, and draws itself.

const INSECTS_TEX: Texture2D = preload("res://assets/insects.png")
const DEMONS_TEX: Texture2D = preload("res://assets/demons.png")
const GHOSTS_TEX: Texture2D = preload("res://assets/ghosts.png")
## The insects as they walk (tools/make_overworld_creatures.py): three-quarter
## view, 24 px, facing where they go -- rows: down 0-3, side 4-7, up 8-11.
const INSECTS_WALK_TEX: Texture2D = preload("res://assets/insects_walk.png")
const WALK_ART := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]   ## insects drawn for it
const FLIERS := [4, 5, 12, 13]     ## these fly: they flap, and hover over their shadow
## The demons as they walk (same tool, overworld_demons.py): 24 x 32 cells,
## same rows. Each moves its own way -- see demon_frame().
const DEMONS_WALK_TEX: Texture2D = preload("res://assets/demons_walk.png")

var kind := ""          # "insect", "demon", "ghost"
var variant := 0        # column in its sprite sheet
var info: Dictionary    # the variant's data from Enemies.TYPES
var atk := 1
var def := 0
var hp := 1
var max_hp := 1
var depth_progress := 0.0   # 0..1, how deep it lives (set by Enemies)
var cell := Vector2i.ZERO
var moving := false
var stunned := 0.0      # seconds left recoiling after a hit
var hunter := true      ## comes after you when it notices you (else it keeps its distance)
var chasing := false
var chase_t := 0.0      ## how long it's been chasing
var calm := 0.0         ## > 0: it gave up on you and won't chase again for a while
var lit := false        # standing in light right now (set by Enemies)
var cornered := 0.0     # how long it's been trapped in light with nowhere to flee
var facing_left := false
var facing := 0         # 0 toward you, 1 away, 2 to the side (facing_left says which)
var lunging := false
var in_battle := false   ## someone is fighting it: it holds still and can't be bumped into
var fade := 1.0         # ghosts: 0 = not there, 1 = fully formed
var hunting := false    # ghosts: coming for you in the dark
var windup := false     # ghosts: rearing up to strike
var _lunge_t := -1.0
var _lunge_to := Vector2.ZERO
var _lunge_done: Callable
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _t := 0.0
var _dur := 0.3
var _time := 0.0
var _steps := 0         # counts steps, so the walk cycle alternates feet


func setup(k: String, v: int, data: Dictionary, at: Vector2i, rng: RandomNumberGenerator) -> void:
	kind = k
	variant = v
	info = data
	atk = rng.randi_range(data.atk[0], data.atk[1])
	def = rng.randi_range(data.def[0], data.def[1])
	hp = data.hp
	max_hp = hp
	cell = at
	position = World.pos_of(at)
	_time = rng.randf() * 10.0


func display_name() -> String:
	return info.name


func step_to(target: Vector2i, duration: float) -> void:
	if target.x != cell.x:
		facing_left = target.x < cell.x
	facing = 2 if target.x != cell.x else (0 if target.y > cell.y else 1)
	cell = target
	_steps += 1
	_from = position
	_to = World.pos_of(target)
	_t = 0.0
	_dur = duration
	moving = true


## Leaps into `target` (the hero's position), then calls `done`.
func lunge(target: Vector2, done: Callable) -> void:
	if target.x != position.x:
		facing_left = target.x < position.x
	lunging = true
	_lunge_t = 0.0
	_lunge_to = target
	_lunge_done = done


func _process(delta: float) -> void:
	_time += delta
	stunned = maxf(stunned - delta, 0.0)
	if _lunge_t >= 0.0:
		# wind up (lean back), then snap forward into the hero
		_lunge_t += delta
		var home := World.pos_of(cell)
		var dir := (_lunge_to - home).normalized()
		if _lunge_t < 0.12:
			position = (home - dir * 2.0 * (_lunge_t / 0.12)).round()
		elif _lunge_t < 0.2:
			position = (home + dir * 11.0 * ((_lunge_t - 0.12) / 0.08)).round()
		else:
			position = home
			_lunge_t = -1.0
			lunging = false
			_lunge_done.call()
		queue_redraw()
		return
	if moving:
		_t += delta / _dur
		if _t >= 1.0:
			position = _to
			moving = false
		else:
			position = _from.lerp(_to, _t).round()
	if visible:
		queue_redraw()


## The frame of the walk sheet (insects_walk.png): legs step through a full
## gait every two steps; fliers beat their wings all the time.
func walk_frame() -> int:
	if FLIERS.has(variant):
		return int(_time * 11.0 + variant) % 4
	if moving or lunging:
		return (int(clampf(_t, 0.0, 0.999) * 2.0) + (_steps % 2) * 2) % 4
	return 0


## The frame of the demon walk sheet, by how each kind moves (variant / 2):
## 0 grinner, 3 hollow: step left, step right; 1 many-eyes: oozes, squash and
## stretch every step; 4 maw: hops, crouch-spring-air-land every step;
## 2 wraith, 5 weeper & bride: drift and glide all the time, slower when still.
func demon_frame() -> int:
	var g := variant / 2
	match g:
		2, 5:
			return int(_time * (6.0 if moving else 2.5) + variant) % 4
		1, 4:
			if moving or lunging:
				return int(clampf(_t, 0.0, 0.999) * 4.0) % 4
			return [0, 3][int(_time * 1.2 + float(variant) * 0.37) % 2] if g == 1 else 0
	if moving or lunging:
		return (int(clampf(_t, 0.0, 0.999) * 2.0) + (_steps % 2) * 2) % 4
	return 0


## Which animation frame (row of its sheet) to show right now.
func anim_frame() -> int:
	if kind == "ghost":
		return 0
	if moving or lunging:
		if kind == "insect":   # legs scuttle: a full cycle every step
			return int(clampf(_t, 0.0, 0.999) * 4.0 + (_steps % 2) * 2) % 4
		return (1 if _steps % 2 == 0 else 3) if _t < 0.65 else 0   # a foot lifts, then lands
	# standing: insects twitch, demons breathe
	if kind == "insect":
		return [0, 2][int(_time * 2.5 + float(variant)) % 2]
	return [0, 2][int(_time * 1.2 + float(variant) * 0.37) % 2]


func _draw() -> void:
	paint(self, Vector2.ZERO)


## Draws the creature onto any canvas at `at` (its own _draw, or a mirror in
## the other player's half of a split screen).
func paint(ci: CanvasItem, at: Vector2) -> void:
	if stunned > 0.0 and fmod(stunned, 0.2) < 0.1:
		return   # blink while recoiling
	var bob := 0.0
	var tex: Texture2D
	var src: Rect2
	var dst: Rect2
	match kind:
		"insect":
			if WALK_ART.has(variant):
				tex = INSECTS_WALK_TEX
				var fr := walk_frame()
				if FLIERS.has(variant):
					bob = -5.0 + roundf(sin(_time * 3.1 + variant) * 1.5)   # hovering
				src = Rect2(variant * 24, ([0, 8, 4][facing] + fr) * 24, 24, 24)   # (rows: down, side, up)
				dst = Rect2(Vector2(-4, -7 + bob), Vector2(24, 24))
			else:
				tex = INSECTS_TEX
				bob = -1.0 if moving and _t < 0.5 else 0.0
				src = Rect2(variant * 16, anim_frame() * 16, 16, 16)
				dst = Rect2(Vector2(0, bob), Vector2(16, 16))
		"demon":
			tex = DEMONS_WALK_TEX
			if variant / 2 == 2:
				bob = -2.0 + roundf(sin(_time * 2.2 + variant))   # wraiths float
			src = Rect2(variant * 24, ([0, 8, 4][facing] + demon_frame()) * 32, 24, 32)   # (rows: down, side, up)
			dst = Rect2(Vector2(-4, -15 + bob), Vector2(24, 32))
		"ghost":
			tex = GHOSTS_TEX
			bob = roundf(sin(_time * 2.0) * 2.0) - 3.0
			src = Rect2(variant * 16, 0, 16, 16)
			dst = Rect2(Vector2(0, bob), Vector2(16, 16))
	# ground shadow (ghosts have none)
	if kind != "ghost":
		Shadows.oval(ci, at + Vector2(8, 14), 12)
	else:
		Shadows.oval(ci, at + Vector2(8, 15), 8, 0.35)
	var mod := Color(1, 1, 1, 0.55 + 0.25 * sin(_time * 3.0)) if kind == "ghost" else Color.WHITE
	if kind == "ghost":
		if fade <= 0.01:
			return
		if hunting:
			# bright and cold, with a halo and a smear behind it as it rushes
			mod = Color(0.92, 0.96, 1.0, 0.9)
			if windup:
				mod = Color(1.0, 0.72, 0.72, 1.0)
				dst.position += Vector2(roundf(sin(_time * 60.0)), -2.0)
				dst = dst.grow(1.0)
			ci.draw_circle(at + Vector2(8, 7 + bob), 10.0, Color(0.6, 0.7, 1.0, 0.12 * fade))
			ci.draw_circle(at + Vector2(8, 7 + bob), 6.0, Color(0.75, 0.85, 1.0, 0.16 * fade))
			if moving:
				var back := (_from - _to).normalized()
				for k in [2, 1]:
					var ghost_dst := Rect2(at + dst.position + back * 4.0 * k, dst.size)
					ci.draw_texture_rect_region(tex, ghost_dst, src, Color(0.7, 0.8, 1.0, 0.18 * fade / k))
		mod.a *= fade
	var mirror := facing_left
	if kind == "demon" or (kind == "insect" and WALK_ART.has(variant)):
		mirror = facing_left and facing == 2   # (only the side view turns round)
	if mirror:   # mirror through a flipped transform
		ci.draw_set_transform(at + Vector2(16, 0), 0.0, Vector2(-1, 1))
		ci.draw_texture_rect_region(tex, dst, src, mod)
	else:
		ci.draw_texture_rect_region(tex, Rect2(at + dst.position, dst.size), src, mod)
	ci.draw_set_transform(Vector2.ZERO)
