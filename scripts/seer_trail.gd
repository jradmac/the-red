class_name SeerTrail
extends Node2D
## The Seer Stone's trail: glowing green dust laid along the ground from where
## you stood to the nearest gate (Doors.seer_path -- the same gate a sprite's
## clue names). It runs out from your feet fast, pulses toward the gate now
## and then, motes of it hang and drift up in the air, and after a while it
## fades away. One trail per player (a new stone replaces your old trail).
##
## In 2D it's drawn here; in the 3D view it's tiny glowing billboards (one
## MultiMesh), unshaded so it shines in the dark, hidden behind walls like
## anything else; a few faint green lights along it tint the floor.

const SPEED := 16.0          ## tiles per second the trail runs out
const LIFE := 90.0           ## seconds it lasts
const FADE := 6.0            ## ...the last of them fading
const PER_TILE := 12         ## grains of dust per tile of path
const LIGHT_EVERY := 4       ## a faint light every this many tiles
const MAX_GRAINS := 4000
const COLS := [Color("7dff9a"), Color("d8ffe4"), Color("3fbf6a"), Color("a8ffc0")]

var world: World
var lighting: Lighting
var view: View3D
var _trails: Array[Dictionary] = []   # {who, grains, goal, t, length, lights}
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _mm: MultiMesh
var _mmi: MultiMeshInstance3D
var _glow: MultiMesh               # a soft green glow lying on the ground under the dust
var _glowi: MultiMeshInstance3D
const MAX_GLOW := 600


func setup(w: World, l: Lighting) -> void:
	world = w
	lighting = l
	_rng.seed = 7


## Lays a new trail for player `who` ("" or "p2_") along `path` (cells).
func start(who: String, path: Array[Vector2i]) -> void:
	clear(who)
	if path.size() < 2:
		return
	var grains: Array[Dictionary] = []
	var d := 0.0
	for i in path.size() - 1:
		var a := Vector2(path[i] * World.TILE)
		var b := Vector2(path[i + 1] * World.TILE)
		var last := i == path.size() - 2
		var n := PER_TILE if not last else PER_TILE / 2   # stops short of the gate itself
		var along := (b - a).normalized()
		var across := Vector2(-along.y, along.x)
		for k in n:
			var f := (k + _rng.randf()) / PER_TILE
			var p := a.lerp(b, f) + across * _rng.randf_range(-4.5, 4.5) + along * _rng.randf_range(-1.5, 1.5)
			grains.append({"p": p, "d": d + f, "col": COLS[_rng.randi() % COLS.size()],
				"big": _rng.randf() < 0.18, "phase": _rng.randf() * TAU, "rate": _rng.randf_range(2.0, 6.0),
				"mote": _rng.randf() < 0.12})
		d += 1.0
	# a swirl of it hanging at the gate
	var goal: Vector2i = path[path.size() - 1]
	for k in 18:
		grains.append({"p": Vector2(goal * World.TILE), "d": d, "col": COLS[k % COLS.size()], "big": k % 3 == 0,
			"phase": k * TAU / 18.0, "rate": _rng.randf_range(2.0, 5.0), "mote": false, "orbit": true})
	var lights: Array = []
	if lighting != null:
		for i in range(0, path.size(), LIGHT_EVERY):
			lights.append({"at": i, "src": null})
	_trails.append({"who": who, "grains": grains, "goal": goal, "t": 0.0, "length": d, "lights": lights})


func clear(who: String) -> void:
	for tr in _trails.duplicate():
		if tr.who == who:
			_drop_lights(tr)
			_trails.erase(tr)


func _drop_lights(tr: Dictionary) -> void:
	for l in tr.lights:
		if l.src != null and lighting != null:
			lighting.remove_light(l.src)
			l.src = null


func _alpha(tr: Dictionary) -> float:
	return clampf((LIFE - tr.t) / FADE, 0.0, 1.0)


func _process(delta: float) -> void:
	_time += delta
	for tr in _trails.duplicate():
		tr.t += delta
		if tr.t >= LIFE:
			_drop_lights(tr)
			_trails.erase(tr)
			continue
		# the faint lights come on as the dust reaches them
		var reach: float = tr.t * SPEED
		for l in tr.lights:
			if l.src == null and l.at <= reach and lighting != null:
				var g: Dictionary = tr.grains[mini(l.at * PER_TILE, tr.grains.size() - 1)]
				l.src = lighting.add_light(self, g.p + Vector2(8, 8), 36.0, Color(0.45, 1.0, 0.6), 0.7, 0.15, false)
			if l.src != null:
				l.src.energy = 0.7 * _alpha(tr)
	queue_redraw()
	_update_3d()


## Where a grain is right now (2D pixels of its cell's top-left space) and how
## high it floats (tiles), and how bright.
func _grain_now(tr: Dictionary, g: Dictionary) -> Array:
	var p: Vector2 = g.p
	var rise := 0.0
	var tw := 0.55 + 0.45 * sin(_time * g.rate + g.phase)
	if g.get("orbit", false):
		var a: float = g.phase + _time * 1.4
		p += Vector2(cos(a), sin(a) * 0.6) * (5.0 + 2.0 * sin(_time * 2.0 + g.phase))
		rise = 0.35 + 0.25 * sin(_time * 1.7 + g.phase)
	elif g.mote:
		var u := fmod(_time * 0.22 + g.phase, 1.0)
		rise = u * 0.9
		tw *= 1.0 - u
		p += Vector2(sin(_time + g.phase) * 2.0, 0)
	# a pulse of light running out toward the gate every few seconds
	var k := fmod(tr.t * 12.0 - float(g.d), 40.0)
	var pulse := 1.0 if k > 0.0 and k < 3.0 else 0.0
	var a := clampf((tr.t * SPEED - float(g.d)) * 2.0, 0.0, 1.0) * _alpha(tr)
	return [p, rise, clampf(tw * 0.8 + pulse * 0.6, 0.0, 1.4) * a]


func _draw() -> void:
	if world == null or (view != null and view.active):
		return
	for tr in _trails:
		var reach: float = tr.t * SPEED
		for g in tr.grains:   # a faint glow on the ground first
			if float(g.d) > reach or g.get("orbit", false) or int(g.d * PER_TILE) % 4 != 0:
				continue
			var gc := Vector2i(int(floor(g.p.x / World.TILE + 0.5)), int(floor(g.p.y / World.TILE + 0.5)))
			draw_circle(g.p + Vector2(8, 8) + world.lift(gc), 7.0, Color(0.3, 1.0, 0.5, 0.05 * _alpha(tr)))
	for tr in _trails:
		for g in tr.grains:
			var n := _grain_now(tr, g)
			var b: float = n[2]
			if b <= 0.01:
				continue
			var c := Vector2i(int(floor(n[0].x / World.TILE + 0.5)), int(floor(n[0].y / World.TILE + 0.5)))
			var at: Vector2 = n[0] + Vector2(8, 8) + world.lift(c) - Vector2(0, float(n[1]) * World.TILE)
			var col: Color = g.col
			if g.big:
				draw_rect(Rect2(at.round() - Vector2(1, 1), Vector2(3, 3)), Color(col, 0.18 * b))
			draw_rect(Rect2(at.round(), Vector2(2, 2) if g.big else Vector2.ONE), Color(col.lightened(0.2 * b), minf(b, 1.0)))


# --- 3D ----------------------------------------------------------------------------

func _update_3d() -> void:
	if view == null or view.root == null or not view.active:
		if _mmi != null:
			_mmi.visible = false
			_glowi.visible = false
		return
	if _mmi == null:
		_make_3d()
	# the glow on the ground: one soft patch per tile the dust has reached
	var j := 0
	for tr in _trails:
		var reach: float = tr.t * SPEED
		var a := _alpha(tr)
		var step := 0
		for g in tr.grains:
			if j >= MAX_GLOW or float(g.d) > reach or g.get("orbit", false):
				continue
			step += 1
			if step % (PER_TILE / 2) != 0:
				continue
			var pos: Vector3 = view.to3d(g.p)
			pos.y += 0.03
			var k := fmod(tr.t * 12.0 - float(g.d), 40.0)
			var b := (0.22 + 0.06 * sin(_time * 1.5 + float(g.d)) + (0.25 if k > 0.0 and k < 3.0 else 0.0)) * a
			_glow.set_instance_transform(j, Transform3D(Basis(), pos))
			_glow.set_instance_color(j, Color(0.3 * b, 1.0 * b, 0.5 * b, 1.0))
			j += 1
	_glow.visible_instance_count = j
	_glowi.visible = j > 0
	var i := 0
	for tr in _trails:
		for g in tr.grains:
			if i >= MAX_GRAINS:
				break
			var n := _grain_now(tr, g)
			var b: float = n[2]
			if b <= 0.01:
				continue
			var pos: Vector3 = view.to3d(n[0])
			pos.y += 0.04 + float(n[1])
			var s := 1.8 if g.big else 1.0
			_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), pos))
			var col: Color = g.col
			_mm.set_instance_color(i, Color(col.r * b, col.g * b, col.b * b, 1.0))
			i += 1
	_mm.visible_instance_count = i
	_mmi.visible = i > 0


func _make_3d() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(0.1, 0.1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	q.material = m
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = q
	_mm.instance_count = MAX_GRAINS
	_mm.visible_instance_count = 0
	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = _mm
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.root.add_child(_mmi)
	# the ground glow: flat soft round patches, added on
	var gq := QuadMesh.new()
	gq.size = Vector2(1.1, 1.1)
	gq.orientation = PlaneMesh.FACE_Y
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.vertex_color_use_as_albedo = true
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	gm.albedo_texture = tex
	gq.material = gm
	_glow = MultiMesh.new()
	_glow.transform_format = MultiMesh.TRANSFORM_3D
	_glow.use_colors = true
	_glow.mesh = gq
	_glow.instance_count = MAX_GLOW
	_glow.visible_instance_count = 0
	_glowi = MultiMeshInstance3D.new()
	_glowi.multimesh = _glow
	_glowi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.root.add_child(_glowi)
