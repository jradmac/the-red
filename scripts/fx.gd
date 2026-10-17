class_name Fx
extends Node2D
## Little world effects:
##   chest_burst  -- a chest opens: a warm flash of light and motes rising out
##   match_strike -- you strike a match: sparks, a flame that leaps up at the
##                   lantern, then a curl of smoke

var lighting: Lighting
var _flames: Array[Dictionary] = []   # {pos, t, node, offset}
var _blasts: Array[Dictionary] = []   # {pos, t, r, seed}
var shake := 0.0                      # screen shake strength (main moves the camera)
const BLAST_TIME := 0.9


func _ready() -> void:
	z_index = 5


func chest_burst(at: Vector2, purple: bool = false) -> void:
	var col := Color(0.75, 0.5, 1.0) if purple else Color(1.0, 0.82, 0.45)
	var light := lighting.add_light(self, at, 10.0, col, 2.0, 0.05)
	var swell := func(v: float) -> void:
		light.radius = 10.0 + 70.0 * sin(v * PI * 0.5)
		light.energy = 2.0 * (1.0 - v)
	var done := func() -> void:
		lighting.remove_light(light)
	var tw := create_tween()
	tw.tween_method(swell, 0.0, 1.0, 1.4)
	tw.tween_callback(done)
	_particles(at, 30, col.lightened(0.5), Color(col, 0.0), Vector2(0, -1), 50.0, Vector2(0, -10),
		14.0, 34.0, 1.5, Vector2(5, 2), 0.7, 2.0)
	_particles(at, 20, Color(1, 1, 0.9), Color(col, 0.0), Vector2(0, -1), 70.0, Vector2(0, -6),
		8.0, 22.0, 1.1, Vector2(6, 2), 0.5)


## A bomb goes off: a white flash, a fireball that boils out and rolls up
## into smoke, a shockwave ring, sparks, embers and flying debris, a burst of
## light that lights up the whole area, and the screen shakes.
func explosion(at: Vector2, radius: float) -> void:
	_blasts.append({"pos": at, "t": 0.0, "r": radius, "seed": randi() % 10000})
	shake = maxf(shake, 1.0)
	var light := lighting.add_light(self, at, 20.0, Color(1.0, 0.7, 0.35), 3.2, 0.25, false)
	var swell := func(v: float) -> void:
		light.radius = 20.0 + 150.0 * sin(minf(v * 3.0, 1.0) * PI * 0.5)
		light.energy = 3.2 * pow(1.0 - v, 2.0)
	var done := func() -> void:
		lighting.remove_light(light)
	var tw := create_tween()
	tw.tween_method(swell, 0.0, 1.0, 1.3)
	tw.tween_callback(done)
	# sparks: fast, bright, falling
	_particles(at, 46, Color(1, 1, 0.85), Color(1.0, 0.35, 0.05, 0.0), Vector2(0, -1), 180.0,
		Vector2(0, 160), 70.0, 170.0, 0.6, Vector2(3, 3), 1.0, 1.0)
	# embers: slow, drifting up
	_particles(at, 28, Color(1.0, 0.65, 0.2), Color(0.9, 0.2, 0.05, 0.0), Vector2(0, -1), 120.0,
		Vector2(0, -18), 15.0, 55.0, 1.6, Vector2(8, 6), 0.9, 1.0)
	# debris: dark chunks thrown out and falling
	_particles(at, 20, Color(0.25, 0.2, 0.2), Color(0.15, 0.1, 0.1, 0.0), Vector2(0, -1), 160.0,
		Vector2(0, 260), 60.0, 140.0, 0.75, Vector2(4, 3), 1.0, 2.0)
	# smoke: big grey puffs that climb and spread
	_particles(at + Vector2(0, -4), 26, Color(0.35, 0.3, 0.32, 0.85), Color(0.12, 0.1, 0.12, 0.0), Vector2(0, -1), 80.0,
		Vector2(0, -22), 10.0, 40.0, 2.2, Vector2(12, 8), 0.75, 4.0)


func match_strike(target: Node2D, offset: Vector2) -> void:
	var at := target.global_position + offset
	# sparks
	_particles(at, 18, Color(1.0, 0.95, 0.6), Color(1.0, 0.4, 0.1, 0.0), Vector2(0, -1), 160.0,
		Vector2(0, 70), 25.0, 65.0, 0.5, Vector2(1, 1), 0.95, 2.0)
	# the flame catching, drawn by hand (follows the lantern for a moment)
	_flames.append({"t": 0.0, "node": target, "offset": offset})
	# smoke after the flare-up
	var smoke := func() -> void:
		if is_instance_valid(target):
			_particles(target.global_position + offset + Vector2(0, -5), 14, Color(0.85, 0.82, 0.9, 0.75),
				Color(0.5, 0.48, 0.55, 0.0), Vector2(0, -1), 25.0, Vector2(4, -12), 6.0, 14.0, 1.6,
				Vector2(1, 1), 0.25, 2.0)
	get_tree().create_timer(0.25).timeout.connect(smoke)


func _particles(at: Vector2, amount: int, c0: Color, c1: Color, dir: Vector2, spread: float,
		gravity: Vector2, v_min: float, v_max: float, life: float, extents: Vector2, explosive: float,
		size: float = 1.0) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = explosive
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = extents
	p.direction = dir
	p.spread = spread
	p.gravity = gravity
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.scale_amount_min = size
	p.scale_amount_max = size
	var ramp := Gradient.new()
	ramp.set_color(0, c0)
	ramp.set_color(1, c1)
	p.color_ramp = ramp
	p.emitting = true
	add_child(p)
	p.finished.connect(p.queue_free)


func _process(delta: float) -> void:
	shake = maxf(shake - delta * 2.2, 0.0)
	for b in _blasts:
		b.t += delta
	_blasts = _blasts.filter(func(b): return b.t < BLAST_TIME)
	if _flames.is_empty() and _blasts.is_empty():
		return
	for f in _flames:
		f.t += delta
	_flames = _flames.filter(func(f): return f.t < 0.5 and is_instance_valid(f.node))
	queue_redraw()


## A pixel flame that leaps up tall, flickers, and settles back into the lantern.
func _draw() -> void:
	for b in _blasts:
		_draw_blast(b)
	for f in _flames:
		var t: float = f.t
		var base: Vector2 = (f.node.global_position + f.offset).round()
		var h := roundf(lerpf(13.0, 2.0, clampf(t / 0.5, 0.0, 1.0)) + sin(t * 40.0))
		if t < 0.06:
			h = roundf(t / 0.06 * 13.0)
		var w := 3.0 if h > 5 else 2.0
		# outer orange, inner yellow, white core
		draw_rect(Rect2(base.x - w + 1, base.y - h, w * 2 - 1, h), Color(1.0, 0.45, 0.12, 0.85))
		draw_rect(Rect2(base.x - w + 2, base.y - h + 2, maxf(w * 2 - 3, 1), maxf(h - 2, 1)), Color(1.0, 0.85, 0.35))
		draw_rect(Rect2(base.x, base.y - maxf(h - 4, 1), 1, maxf(h - 4, 1)), Color(1, 1, 0.9))
		draw_rect(Rect2(base.x, base.y - h - 1, 1, 1), Color(1.0, 0.6, 0.2, 0.6))



## The fireball, hand-drawn in chunky pixel circles.
func _draw_blast(b: Dictionary) -> void:
	var t: float = b.t
	var at: Vector2 = b.pos
	var r: float = b.r
	var rng := RandomNumberGenerator.new()
	rng.seed = b.seed
	# 1. the first instant: a hard white flash
	if t < 0.09:
		draw_circle(at, lerpf(8.0, r * 0.75, t / 0.09), Color(1, 1, 1, 0.95))
	# 2. shockwave: a thin ring racing outwards
	var ring := clampf(t / 0.35, 0.0, 1.0)
	if ring < 1.0:
		draw_arc(at, r * 1.25 * ease(ring, 0.4), 0.0, TAU, 40, Color(1.0, 0.95, 0.8, 0.8 * (1.0 - ring)),
			lerpf(4.0, 1.0, ring))
		draw_arc(at, r * 1.05 * ease(ring, 0.4), 0.0, TAU, 40, Color(1.0, 0.6, 0.2, 0.35 * (1.0 - ring)), 2.0)
	# 3. the fireball: lumps of flame that swell, then cool from white to
	#    yellow to orange to red to smoke as it rolls upward
	var grow := ease(clampf(t / 0.22, 0.0, 1.0), 0.35)
	var cool := clampf((t - 0.1) / 0.75, 0.0, 1.0)
	var rise := -14.0 * cool
	for k in 14:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(0.15, 0.62) * r * grow
		var size := rng.randf_range(0.28, 0.45) * r * grow * (1.0 - cool * 0.55)
		var p := at + Vector2.from_angle(ang) * dist + Vector2(0, rise * rng.randf_range(0.5, 1.2))
		var outer := _fire(cool + 0.25)
		var inner := _fire(cool)
		draw_circle(p, size, outer)
		draw_circle(p + Vector2(-1, -1), size * 0.62, inner)
	# the hot core
	if cool < 0.5:
		draw_circle(at + Vector2(0, rise * 0.6), r * 0.32 * grow * (1.0 - cool * 1.6), _fire(cool * 0.6))


## Fire colors by how far the flame has cooled (0 = white-hot .. 1 = smoke).
func _fire(k: float) -> Color:
	k = clampf(k, 0.0, 1.0)
	var stops := [Color(1, 1, 0.92), Color(1.0, 0.88, 0.35), Color(1.0, 0.55, 0.12), Color(0.85, 0.2, 0.08),
		Color(0.3, 0.22, 0.22, 0.75), Color(0.15, 0.12, 0.14, 0.0)]
	var f := k * (stops.size() - 1)
	var i := mini(int(f), stops.size() - 2)
	return (stops[i] as Color).lerp(stops[i + 1], f - i)
