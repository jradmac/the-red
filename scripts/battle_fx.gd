class_name BattleFX
extends RefCounted
## The battle screen's world and weather: the place you're fighting in (drawn
## behind the fighters to match where the fight broke out), and everything
## that floats in it -- embers off your lantern, dust in its light, the
## creature's aura (malice off a demon, spores off an insect), the landscape's
## own drift (fireflies, falling grit, snow, swamp bubbles), rolling fog, and
## the bursts when blows land.
##
## battle.gd owns one: setup() when a fight starts, update() every frame,
## draw_back() first, draw_front() over the fighters, burst() on impacts,
## card_emit() for the move card you're hovering.

const HORIZON := 104.0          ## where the back wall / tree line meets the floor
const MAX_PARTS := 420

var biome := World.B_CRYPT
var outdoors := false
var kind := "insect"            ## the creature: "insect" or "demon"
var time := 0.0
var parts: Array = []           ## {p, v, age, life, col, col2, size, grav, front, shape, sway, seed}
var _acc := {}                  ## emitter -> accumulated count
var _fog: Array = []            ## {x, y, r, speed, a}
var _stars: Array = []          ## {p, s}
var _deco: Array = []           ## scattered ground details: {p, k}
var _rng := RandomNumberGenerator.new()


func setup(b: int, out: bool, creature: String, seed_value: int) -> void:
	biome = b
	outdoors = out
	kind = creature
	time = 0.0
	parts.clear()
	_acc.clear()
	_rng.seed = seed_value
	_fog.clear()
	for i in 7:
		_fog.append({"x": _rng.randf_range(-60, 400), "y": _rng.randf_range(118, 168), "r": _rng.randf_range(28, 54),
			"speed": _rng.randf_range(3.0, 8.0) * (1 if i % 2 else -1), "a": _rng.randf_range(0.05, 0.11)})
	_stars.clear()
	for i in 46:
		_stars.append({"p": Vector2(_rng.randf_range(0, 360), _rng.randf_range(2, HORIZON - 30)), "s": _rng.randf()})
	_deco.clear()
	for i in 34:
		var y := _rng.randf_range(HORIZON + 6, 236)
		_deco.append({"p": Vector2(_rng.randf_range(0, 360), y), "k": _rng.randi() % 4})
	_deco.sort_custom(func(a, b2): return a.p.y < b2.p.y)


# --- Particles ---------------------------------------------------------------------------

func _add(p: Vector2, v: Vector2, life: float, col: Color, size := 1.0, grav := 0.0, front := true,
		shape := "dot", col2 := Color(0, 0, 0, 0), sway := 0.0) -> void:
	if parts.size() >= MAX_PARTS:
		return
	parts.append({"p": p, "v": v, "age": 0.0, "life": life, "col": col, "col2": col2 if col2.a > 0.0 else col,
		"size": size, "grav": grav, "front": front, "shape": shape, "sway": sway, "seed": _rng.randf() * TAU})


## Emits `rate` particles a second from emitter `key`, calling make() for each.
func _rate(key: String, rate: float, delta: float, make: Callable) -> void:
	var a: float = _acc.get(key, _rng.randf()) + rate * delta
	while a >= 1.0:
		a -= 1.0
		make.call()
	_acc[key] = a


## lantern_at: the flame (screen px); light: 0..1 fuel; enemy_box: the creature's
## sprite rect; calm: no fight animation playing (ambient only).
func update(delta: float, lantern_at: Vector2, light: float, enemy_box: Rect2) -> void:
	time += delta
	# your lantern: embers rising, and dust turning in its light
	_rate("ember", 5.0 + 7.0 * light, delta, func() -> void:
		_add(lantern_at + Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-2, 1)),
			Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-30, -14)), _rng.randf_range(1.0, 2.2),
			Color("ffe0a0"), 2.0 if _rng.randf() < 0.25 else 1.0, -4.0, true, "ember", Color("c8402a"), 9.0))
	_rate("dust", 11.0, delta, func() -> void:
		var c := Vector2(170, 112)
		_add(c + Vector2(_rng.randf_range(-140, 140), _rng.randf_range(-70, 40)),
			Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-3, 2)), _rng.randf_range(2.5, 5.0),
			Color(1.0, 0.88, 0.62, 0.85), 1.0, 0.0, _rng.randf() < 0.5, "mote", Color(1.0, 0.86, 0.6, 0.0), 4.0))
	# big soft motes drifting close to the "lens", out of focus
	_rate("bokeh", 0.9, delta, func() -> void:
		_add(Vector2(_rng.randf_range(0, 360), _rng.randf_range(10, 230)), Vector2(_rng.randf_range(-5, 5), _rng.randf_range(-4, -1)),
			_rng.randf_range(4.0, 7.0), Color(1.0, 0.8, 0.55, 0.07), _rng.randf_range(3.0, 6.0), 0.0, true, "bokeh"))
	# the creature's aura
	if enemy_box.size.x > 0.0:
		if kind == "demon":
			_rate("malice", 16.0, delta, func() -> void:
				var x := _rng.randf_range(enemy_box.position.x + 4, enemy_box.end.x - 4)
				var y := _rng.randf_range(enemy_box.position.y + enemy_box.size.y * 0.3, enemy_box.end.y - 4)
				_add(Vector2(x, y), Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-22, -10)), _rng.randf_range(0.8, 1.6),
					Color("e0304a"), 2.0, -2.0, true, "wisp", Color(0.35, 0.05, 0.4, 0.0), 6.0))
		else:
			_rate("spore", 10.0, delta, func() -> void:
				var c := enemy_box.get_center()
				var a := _rng.randf() * TAU
				_add(c + Vector2.from_angle(a) * _rng.randf_range(16, 30), Vector2(_rng.randf_range(-5, 5), _rng.randf_range(-8, -2)),
					_rng.randf_range(1.4, 2.6), Color("b8e870"), 1.0, 0.0, true, "mote", Color(0.4, 0.7, 0.3, 0.0), 8.0))
	# the landscape's own drift
	match biome:
		World.B_FOREST, World.B_RIVER:
			_rate("firefly", 2.2, delta, func() -> void:
				_add(Vector2(_rng.randf_range(10, 350), _rng.randf_range(HORIZON - 30, 200)),
					Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-4, 4)), _rng.randf_range(3.0, 5.0),
					Color("e8ff8a"), 1.0, 0.0, _rng.randf() < 0.5, "firefly", Color("8ad04a"), 10.0))
		World.B_SWAMP:
			_rate("bubble", 3.0, delta, func() -> void:
				_add(Vector2(_rng.randf_range(10, 350), _rng.randf_range(150, 236)), Vector2(0, _rng.randf_range(-6, -3)),
					_rng.randf_range(0.8, 1.5), Color("7fae6a"), 1.0, 0.0, false, "bubble", Color("3e5a3a"), 2.0))
			_rate("swampspore", 4.0, delta, func() -> void:
				_add(Vector2(_rng.randf_range(0, 360), _rng.randf_range(20, 200)), Vector2(_rng.randf_range(2, 7), _rng.randf_range(-2, 2)),
					_rng.randf_range(3.0, 5.0), Color(0.6, 0.85, 0.45, 0.6), 1.0, 0.0, true, "mote", Color(0.4, 0.6, 0.3, 0.0), 6.0))
		World.B_MOUNTAIN:
			_rate("snow", 14.0, delta, func() -> void:
				_add(Vector2(_rng.randf_range(-20, 380), -4), Vector2(_rng.randf_range(4, 12), _rng.randf_range(16, 30)),
					_rng.randf_range(6.0, 10.0), Color(0.92, 0.95, 1.0, 0.8), 1.0 if _rng.randf() < 0.7 else 2.0, 0.0,
					_rng.randf() < 0.6, "snow", Color(0.92, 0.95, 1.0, 0.8), 10.0))
		World.B_COURT:
			_rate("ash", 4.0, delta, func() -> void:
				_add(Vector2(_rng.randf_range(-10, 370), -4), Vector2(_rng.randf_range(-4, 8), _rng.randf_range(8, 16)),
					_rng.randf_range(8.0, 14.0), Color("8a8090"), 1.0, 0.0, _rng.randf() < 0.5, "leaf", Color("5a5266"), 14.0))
		_:
			_rate("grit", 3.0, delta, func() -> void:   # crypt: grit sifting down from the ceiling
				var x := _rng.randf_range(20, 340)
				_add(Vector2(x, 0), Vector2(_rng.randf_range(-1, 1), _rng.randf_range(30, 50)), _rng.randf_range(1.5, 3.0),
					Color("6a6078"), 1.0, 30.0, false, "dot"))
	for f in _fog:
		f.x += f.speed * delta
		if f.x > 420: f.x = -60
		if f.x < -60: f.x = 420
	for p in parts:
		p.age += delta
		p.v.y += p.grav * delta
		p.p += p.v * delta
		if p.sway > 0.0:
			p.p.x += sin(time * 2.3 + p.seed) * p.sway * delta
	parts = parts.filter(func(p): return p.age < p.life)


## A burst of particles: "spark" (a blow landing), "gore" (ichor; pass a colour),
## "block" (a guard holding), "dodge" (dust kicked up), "heal", "flare".
func burst(what: String, at: Vector2, col := Color.WHITE) -> void:
	match what:
		"spark":
			for i in 16:
				var a := _rng.randf() * TAU
				var s := _rng.randf_range(60, 150)
				_add(at, Vector2.from_angle(a) * s, _rng.randf_range(0.18, 0.4), Color("fff6c8"), 1.0, 160.0, true, "streak", Color("ffb040"))
			for i in 3:
				_add(at, Vector2.ZERO, 0.16, Color(1, 1, 0.9, 0.9), 6.0 + i * 4.0, 0.0, true, "ring", Color(1, 0.8, 0.5, 0.0))
		"gore":
			for i in 12:
				var a := _rng.randf_range(-PI * 0.95, -PI * 0.05)
				_add(at + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4)), Vector2.from_angle(a) * _rng.randf_range(30, 90),
					_rng.randf_range(0.4, 0.8), col, 2.0 if i % 3 == 0 else 1.0, 220.0, true, "dot", col.darkened(0.5))
		"block":
			for i in 14:
				var a := TAU * i / 14.0
				_add(at + Vector2.from_angle(a) * 12.0, Vector2.from_angle(a) * 70.0, 0.3, Color("dceaff"), 1.0, 0.0, true, "streak", Color("4a7ad8"))
			_add(at, Vector2.ZERO, 0.25, Color(0.6, 0.8, 1.0, 0.9), 14.0, 0.0, true, "ring", Color(0.4, 0.6, 1.0, 0.0))
		"dodge":
			for i in 10:
				_add(at + Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-2, 2)), Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-14, -4)),
					_rng.randf_range(0.4, 0.7), Color(0.75, 0.7, 0.8, 0.6), 2.0, 0.0, true, "puff", Color(0.5, 0.45, 0.6, 0.0))
		"heal":
			for i in 14:
				_add(at + Vector2(_rng.randf_range(-18, 18), _rng.randf_range(-10, 20)), Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-30, -16)),
					_rng.randf_range(0.8, 1.3), Color("9dffb0"), 1.0, 0.0, true, "plus", Color("3aa060"))
		"flare":
			for i in 30:
				var a := _rng.randf() * TAU
				_add(at, Vector2.from_angle(a) * _rng.randf_range(80, 200), _rng.randf_range(0.3, 0.7), Color("fff2b0"), 1.0, 40.0, true, "streak", Color("ff9030"))
			_add(at, Vector2.ZERO, 0.4, Color(1, 0.95, 0.7, 1.0), 30.0, 0.0, true, "ring", Color(1, 0.6, 0.2, 0.0))


## The move card you're hovering gives off its move: sparks off ATTACK, cold
## motes off DEFEND, wind off DODGE.
func card_emit(move: String, r: Rect2, delta: float) -> void:
	match move:
		"attack":
			_rate("card_attack", 14.0, delta, func() -> void:
				_add(Vector2(_rng.randf_range(r.position.x, r.end.x), r.position.y + _rng.randf_range(0, 4)),
					Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-30, -14)), _rng.randf_range(0.4, 0.8),
					Color("ffd38a"), 1.0, 0.0, true, "ember", Color("e0402a")))
		"defend":
			_rate("card_defend", 10.0, delta, func() -> void:
				var x := _rng.randf_range(r.position.x, r.end.x)
				_add(Vector2(x, r.end.y - _rng.randf_range(0, r.size.y)), Vector2(0, _rng.randf_range(-14, -6)), _rng.randf_range(0.6, 1.0),
					Color("cfe3ff"), 1.0, 0.0, true, "mote", Color(0.3, 0.5, 1.0, 0.0), 3.0))
		"dodge":
			_rate("card_dodge", 12.0, delta, func() -> void:
				var y := _rng.randf_range(r.position.y + 4, r.end.y - 4)
				_add(Vector2(r.position.x - 2, y), Vector2(_rng.randf_range(70, 110), 0), _rng.randf_range(0.25, 0.45),
					Color(0.8, 1.0, 0.85, 0.7), 1.0, 0.0, true, "streak", Color(0.5, 0.9, 0.6, 0.0)))


func _draw_part(c: CanvasItem, p: Dictionary) -> void:
	var t: float = p.age / p.life
	var col: Color = (p.col as Color).lerp(p.col2, t)
	var pos: Vector2 = (p.p as Vector2).round()
	match p.shape:
		"dot":
			c.draw_rect(Rect2(pos, Vector2(p.size, p.size)), Color(col, col.a * (1.0 - t * 0.6)))
		"ember":
			var a := (1.0 - t) * (0.7 + 0.3 * sin(time * 30.0 + p.seed))
			var sz: float = p.size
			c.draw_rect(Rect2(pos - Vector2(1, 1), Vector2(sz + 2, sz + 2)), Color(col, a * 0.15))
			c.draw_rect(Rect2(pos, Vector2(sz, sz)), Color(col, a))
			if t < 0.5:
				c.draw_rect(Rect2(pos + Vector2(0, sz), Vector2(1, 1)), Color(col, a * 0.4))
		"mote":
			var a := sin(t * PI) * col.a
			c.draw_rect(Rect2(pos, Vector2(1, 1)), Color(col, a))
			c.draw_rect(Rect2(pos - Vector2(1, 0), Vector2(3, 1)), Color(col, a * 0.18))
		"bokeh":
			var a3 := sin(t * PI) * col.a
			c.draw_circle(pos, p.size, Color(col, a3))
			c.draw_circle(pos, p.size * 0.6, Color(col, a3))
		"wisp":
			var a := sin(t * PI) * 0.85
			var s: float = p.size * (1.0 + t)
			c.draw_rect(Rect2(pos - Vector2(s, s) * 0.5, Vector2(s, s)), Color(col, a * 0.5))
			c.draw_rect(Rect2(pos, Vector2(1, 1)), Color(col.lightened(0.3), a))
		"firefly":
			var blink := clampf(sin(time * 3.0 + p.seed * 3.0) * 2.0, 0.0, 1.0) * sin(t * PI)
			c.draw_rect(Rect2(pos, Vector2(1, 1)), Color(col, blink))
			c.draw_rect(Rect2(pos - Vector2(1, 1), Vector2(3, 3)), Color(col, blink * 0.18))
		"bubble":
			c.draw_rect(Rect2(pos, Vector2(2, 2)), Color(col, 0.8 * (1.0 - t)))
			c.draw_rect(Rect2(pos, Vector2(1, 1)), Color(1, 1, 1, 0.5 * (1.0 - t)))
		"snow":
			c.draw_rect(Rect2(pos, Vector2(p.size, p.size)), Color(col, col.a * (1.0 - t * 0.5)))
		"leaf":
			var w := 2 if fmod(time * 4.0 + p.seed, 2.0) < 1.0 else 1
			c.draw_rect(Rect2(pos, Vector2(w, 1)), Color(col, 1.0 - t))
		"streak":
			var v: Vector2 = p.v
			var tail := pos - v.normalized() * minf(v.length() * 0.04, 5.0)
			c.draw_line(tail.round(), pos, Color(col, 1.0 - t), 1.0)
		"ring":
			var r: float = p.size + t * p.size * 1.5
			for i in 24:
				var a := TAU * i / 24.0
				c.draw_rect(Rect2((pos + Vector2(cos(a) * r, sin(a) * r * 0.8)).round(), Vector2(1, 1)), Color(col, (1.0 - t) * col.a))
		"puff":
			var r2: float = p.size + t * 4.0
			c.draw_circle(pos, r2, Color(col, col.a * (1.0 - t)))
		"plus":
			var a2 := 1.0 - t
			c.draw_rect(Rect2(pos + Vector2(-1, 0), Vector2(3, 1)), Color(col, a2))
			c.draw_rect(Rect2(pos + Vector2(0, -1), Vector2(1, 3)), Color(col, a2))


# --- The place -------------------------------------------------------------------------

func draw_back(c: CanvasItem, size: Vector2, shake: Vector2) -> void:
	if outdoors:
		_sky(c, size)
		match biome:
			World.B_MOUNTAIN: _peaks(c)
			World.B_COURT: _ruins(c)
			_: _treeline(c)
		_ground_outdoor(c, size)
	else:
		_crypt_wall(c, size)
		_crypt_floor(c, size)
	for p in parts:
		if not p.front:
			_draw_part(c, p)


func draw_front(c: CanvasItem, size: Vector2) -> void:
	# low fog rolling over the floor
	var fog_col := Color(0.55, 0.75, 0.5) if biome == World.B_SWAMP else Color(0.6, 0.55, 0.75)
	for f in _fog:
		for k in 3:
			c.draw_circle(Vector2(f.x + k * f.r * 0.6, f.y + sin(time * 0.6 + k) * 2.0), f.r * (1.0 - k * 0.2), Color(fog_col, f.a * 0.5))
	for p in parts:
		if p.front:
			_draw_part(c, p)
	_vignette(c, size)


func _vignette(c: CanvasItem, size: Vector2) -> void:
	for i in 8:
		var a := 0.09 * (8 - i) / 8.0
		var w := 3.0
		c.draw_rect(Rect2(i * w, 0, w, size.y), Color(0, 0, 0, a))
		c.draw_rect(Rect2(size.x - (i + 1) * w, 0, w, size.y), Color(0, 0, 0, a))
		c.draw_rect(Rect2(0, i * w, size.x, w), Color(0, 0, 0, a))


func _bands(c: CanvasItem, y0: float, y1: float, top: Color, bot: Color, n := 10) -> void:
	for i in n:
		var t := float(i) / n
		c.draw_rect(Rect2(0, y0 + (y1 - y0) * t, 400, (y1 - y0) / n + 1), top.lerp(bot, t))


func _crypt_wall(c: CanvasItem, size: Vector2) -> void:
	_bands(c, 0, HORIZON, Color("07050b"), Color("1a1426"))
	# bricks: mortar lines, every other row offset, a few lighter faces
	for row in int(HORIZON / 7.0):
		var y := row * 7.0
		c.draw_rect(Rect2(0, y, size.x, 1), Color(0, 0, 0, 0.35))
		var off := 9.0 if row % 2 else 0.0
		var x := -off
		var k := 0
		while x < size.x:
			c.draw_rect(Rect2(x, y + 1, 1, 6), Color(0, 0, 0, 0.3))
			if (row * 7 + k * 3) % 11 == 0:
				c.draw_rect(Rect2(x + 1, y + 1, 16, 1), Color(1, 1, 1, 0.04))
			x += 18.0
			k += 1
	# a colonnade of arches, black beyond
	var centers := [22.0, 112.0, 248.0, 338.0]
	for cx in centers:
		var top := 30.0
		var w := 38.0
		c.draw_rect(Rect2(cx - w / 2, top + w / 2, w, HORIZON - top - w / 2), Color("040307"))
		for y in int(w / 2):
			var half := sqrt(maxf(0.0, (w / 2) * (w / 2) - (w / 2 - y) * (w / 2 - y)))
			c.draw_rect(Rect2(cx - half, top + y, half * 2, 1), Color("040307"))
		# voussoirs: the arch's stone ring
		for i in 13:
			var a := PI + PI * i / 12.0
			var p := Vector2(cx, top + w / 2) + Vector2(cos(a), sin(a)) * (w / 2 + 2)
			c.draw_rect(Rect2(p.round() - Vector2(1, 1), Vector2(3, 3)), Color("2e2540"))
			c.draw_rect(Rect2(p.round() - Vector2(1, 1), Vector2(3, 1)), Color("3e3354"))
	# pillars between them
	for px in [67.0, 180.0, 293.0]:
		c.draw_rect(Rect2(px - 8, 18, 16, HORIZON - 18), Color("221b30"))
		c.draw_rect(Rect2(px - 8, 18, 2, HORIZON - 18), Color("372d4a"))
		c.draw_rect(Rect2(px + 6, 18, 2, HORIZON - 18), Color("120d1a"))
		c.draw_rect(Rect2(px - 10, 18, 20, 4), Color("2e2540"))
		c.draw_rect(Rect2(px - 10, HORIZON - 5, 20, 5), Color("2e2540"))
		# a sconce with a dying flame
		var fl := 0.7 + 0.3 * sin(time * 9.0 + px)
		c.draw_rect(Rect2(px - 2, 46, 4, 3), Color("3a2a20"))
		c.draw_circle(Vector2(px, 43), 10.0, Color(1.0, 0.5, 0.2, 0.07 * fl))
		c.draw_rect(Rect2(px - 1, 42, 2, 3), Color(1.0, 0.7, 0.3, fl))
		c.draw_rect(Rect2(px, 41, 1, 1), Color(1.0, 0.95, 0.7, fl))


func _crypt_floor(c: CanvasItem, size: Vector2) -> void:
	_bands(c, HORIZON, size.y, Color("1d1729"), Color("0b0810"), 8)
	c.draw_rect(Rect2(0, HORIZON, size.x, 1), Color("2e2540"))
	# flagstones in perspective toward a point above the middle
	var vp := Vector2(180, HORIZON - 70)
	var y := HORIZON
	var step := 4.0
	while y < size.y:
		c.draw_rect(Rect2(0, roundf(y), size.x, 1), Color(0, 0, 0, 0.35))
		y += step
		step *= 1.32
	for i in range(-12, 13):
		var bx := 180.0 + i * 46.0
		var t0 := (HORIZON - vp.y) / (size.y - vp.y)
		var top := vp.lerp(Vector2(bx, size.y), t0)
		c.draw_line(top.round(), Vector2(bx, size.y), Color(0, 0, 0, 0.3), 1.0)
	for d in _deco:
		var p: Vector2 = d.p
		match d.k:
			0: c.draw_rect(Rect2(p, Vector2(3, 1)), Color("2a2238"))         # a crack
			1: c.draw_rect(Rect2(p, Vector2(2, 1)), Color("8a8270", 0.35))   # bone chip
			2: c.draw_rect(Rect2(p, Vector2(1, 1)), Color("3e3354"))
			3: c.draw_rect(Rect2(p, Vector2(4, 1)), Color(0.2, 0.35, 0.2, 0.4))   # moss


func _sky(c: CanvasItem, size: Vector2) -> void:
	_bands(c, 0, HORIZON, Color("05040c"), Color("1c1630"))
	for s in _stars:
		var tw := 0.4 + 0.6 * absf(sin(time * (0.8 + s.s) + s.s * 20.0))
		c.draw_rect(Rect2(s.p, Vector2(1, 1)), Color(0.85, 0.85, 1.0, tw * 0.7))
	var m := Vector2(212, 22)
	for i in 5:
		c.draw_circle(m, 22.0 - i * 3.0, Color(0.7, 0.75, 1.0, 0.03 + i * 0.01))
	c.draw_circle(m, 9.0, Color("d8dcf0"))
	c.draw_rect(Rect2(m + Vector2(-3, -2), Vector2(2, 2)), Color("b8bcd8"))
	c.draw_rect(Rect2(m + Vector2(2, 3), Vector2(3, 2)), Color("b8bcd8"))
	c.draw_rect(Rect2(m + Vector2(-1, 4), Vector2(1, 1)), Color("b8bcd8"))


func _treeline(c: CanvasItem) -> void:
	for layer in 2:
		var col := Color("16112a") if layer == 0 else Color("0b0814")
		var base := HORIZON - (16.0 if layer == 0 else 4.0)
		var x := -10.0 + layer * 17.0
		var k := 0
		while x < 380:
			var h := 26.0 + float((k * 37 + layer * 11) % 23) + (14.0 if layer == 1 else 0.0)
			var w := 16.0 + float((k * 13) % 9)
			c.draw_rect(Rect2(x + w / 2 - 2, base - h * 0.4, 4, h * 0.4 + (HORIZON - base) + 2), col)
			for j in 4:
				var cy := base - h * 0.45 - j * h * 0.15
				c.draw_circle(Vector2(x + w / 2 + ((j * 5) % 7 - 3), cy), w / 2 - j * 1.5, col)
			x += w * (0.7 if layer == 1 else 0.85)
			k += 1
	if biome == World.B_SWAMP:
		for i in 6:   # dead snags
			var sx := 20.0 + i * 61.0
			c.draw_rect(Rect2(sx, HORIZON - 34, 2, 34), Color("0b0814"))
			c.draw_rect(Rect2(sx - 5, HORIZON - 26, 6, 1), Color("0b0814"))
			c.draw_rect(Rect2(sx + 2, HORIZON - 20, 5, 1), Color("0b0814"))


func _peaks(c: CanvasItem) -> void:
	for layer in 2:
		var col := Color("1a1530") if layer == 0 else Color("0e0b18")
		var pts := PackedVector2Array([Vector2(-10, HORIZON)])
		var x := -10.0
		var k := layer * 3
		while x < 380:
			var h := 30.0 + float((k * 29) % 34) - layer * 10.0
			pts.append(Vector2(x + 18, HORIZON - h))
			pts.append(Vector2(x + 34, HORIZON - h * 0.5))
			x += 34.0
			k += 1
		pts.append(Vector2(380, HORIZON))
		c.draw_colored_polygon(pts, col)
		if layer == 0:
			for i in range(1, pts.size() - 1, 2):   # snow on the far peaks
				var p := pts[i]
				c.draw_rect(Rect2(p + Vector2(-3, 0), Vector2(6, 2)), Color("8a8aa8"))
				c.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(2, 1)), Color("b8b8d0"))


func _ruins(c: CanvasItem) -> void:
	c.draw_rect(Rect2(0, HORIZON - 18, 400, 18), Color("120e1c"))
	for i in 9:
		var x := 12.0 + i * 42.0
		var h := 24.0 + float((i * 31) % 40)
		c.draw_rect(Rect2(x, HORIZON - h, 10, h), Color("1d1729"))
		c.draw_rect(Rect2(x, HORIZON - h, 2, h), Color("2a2238"))
		c.draw_rect(Rect2(x - 2, HORIZON - h, 14, 3), Color("231c30"))
		if i % 3 == 1:   # broken: a jagged top
			c.draw_rect(Rect2(x + 6, HORIZON - h - 4, 4, 4), Color("1d1729"))


func _ground_outdoor(c: CanvasItem, size: Vector2) -> void:
	var top := Color("141a14")
	var bot := Color("070906")
	match biome:
		World.B_SWAMP:
			top = Color("12190f"); bot = Color("060805")
		World.B_MOUNTAIN:
			top = Color("1e1a26"); bot = Color("0b0910")
		World.B_COURT:
			top = Color("1a1624"); bot = Color("09070d")
	_bands(c, HORIZON, size.y, top, bot, 8)
	if biome == World.B_RIVER:   # a slow river across the middle distance
		c.draw_rect(Rect2(0, HORIZON + 6, size.x, 9), Color("0f1a2e"))
		for i in 18:
			var x := fmod(i * 23.0 + time * 9.0, size.x + 20.0) - 10.0
			c.draw_rect(Rect2(x, HORIZON + 8 + (i % 3) * 2, 6, 1), Color(0.5, 0.6, 0.9, 0.25))
	for d in _deco:
		var p: Vector2 = d.p
		if biome == World.B_SWAMP and d.k == 0:
			c.draw_rect(Rect2(p - Vector2(5, 0), Vector2(11, 2)), Color("0c140f"))   # a murky pool
			c.draw_rect(Rect2(p - Vector2(3, 0), Vector2(4, 1)), Color(0.4, 0.6, 0.4, 0.2))
			continue
		if biome == World.B_MOUNTAIN or biome == World.B_COURT:
			c.draw_rect(Rect2(p, Vector2(3, 2)), Color("2a2436"))   # stones
			c.draw_rect(Rect2(p, Vector2(2, 1)), Color("3a3448"))
			continue
		var g := Color("1f3020") if d.k % 2 else Color("26381f")
		c.draw_rect(Rect2(p, Vector2(1, 3)), g)                     # grass tufts
		c.draw_rect(Rect2(p + Vector2(2, 1), Vector2(1, 2)), g)
		c.draw_rect(Rect2(p + Vector2(-2, 1), Vector2(1, 2)), g)
