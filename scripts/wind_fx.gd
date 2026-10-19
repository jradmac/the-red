class_name WindFx
extends Node3D
## The wind in the 3D view (Wind decides where and when it blows).
##
## Wind comes in puffs, not as a steady stream. Every few seconds a puff runs
## down each drafty stretch, and when it passes:
##   - a ribbon or two of air, pale and see-through, lifts off the floor, runs
##     down the corridor waving as it goes, and rises over the wall where the
##     corridor ends; they only really show where there's light to catch them;
##   - bits of the land blow along with it, tumbling and skipping over the
##     ground: dead leaves in the forest, dust in the crypts, petals in the
##     court, grit on the crags, spray off the river, seed fluff in the mire
##     (and sand, snow, ash and embers, gold dust in the rare lands);
##   - the tall grass bends in a wave ahead of it (tall_grass.gdshader: puffs);
##   - there's a soft rush of air as it goes by.
## A GUST (the one that beats your flame down) is the same thing, but huge: in
## its warning a few leaves start to skitter and the grass stirs, then a front
## sweeps right across the screen and everything streams downwind behind it
## until it dies away.

const RANGE := 13.0            ## how far from the camera's spot puffs are shown (tiles)
const MAX_BITS := 180
const RIBBON_LEN := 2.3        ## tiles of trail behind a ribbon's head
const GUST_SWEEP := 26.0       ## tiles a second a gust's front crosses the screen
const GUST_FROM := 13.0        ## it starts this far upwind of the camera's spot
const AIR := Color(0.86, 0.92, 1.0)
## what blows about, by land (World.B_*; then the rare lands by World.R_*):
## [colours, size (px wide, high), how it moves]
const BITS := {
	"crypt": [["8a8070", "a69c88", "6e675c", "bdb4a0"], Vector2(1, 1), "dust"],
	"forest": [["8a5a2a", "a8702e", "6e4a22", "c08a3a", "5e6a2a"], Vector2(2, 2), "leaf"],
	"court": [["e8c8d0", "f2e6e0", "d8a8b8", "c8b070", "7a8a3a"], Vector2(2, 2), "leaf"],
	"mountain": [["9a8a70", "7a6e5a", "b8a888"], Vector2(1, 1), "grit"],
	"river": [["cfe6f0", "a8d0e0", "e8f4f8"], Vector2(1, 1), "spray"],
	"swamp": [["e8e4d0", "c8c4a8", "7a7a40", "a4a060"], Vector2(1, 1), "fluff"],
	"beach": [["e8d8a0", "d8c488", "f2e8c0"], Vector2(1, 1), "grit"],
	"jungle": [["3a7a2a", "5a9a30", "2a5a22", "8ab040"], Vector2(2, 2), "leaf"],
	"snow": [["f4f8ff", "dce8f8", "ffffff"], Vector2(1, 1), "fluff"],
	"volcano": [["5a5050", "7a6e68", "ff9a40", "ffc060"], Vector2(1, 1), "ash"],
	"gold": [["ffe27a", "fff0b0", "e8b840"], Vector2(1, 1), "glint"],
}
const BIOME_BITS := ["crypt", "forest", "court", "mountain", "river", "swamp"]
const RARE_BITS := {1: "beach", 2: "jungle", 3: "snow", 4: "volcano", 5: "gold"}
const PX := 1.0 / 16.0         ## one sprite pixel, in tiles (at the camera's distance)

var view: Node                 ## View3D
var wind: Wind
var world: World
var _ribbons: Array = []       ## {start, dir, age, life, delay, seed, speed, power, run, h, len, curl, y0}
var _bits: Array = []          ## {p, v, age, life, col, size, kind, spin, glow}
var _ribbon_mesh: ImmediateMesh
var _bit_mm: MultiMesh
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _gust_was := false
var _gust_age := 0.0
var _gust_origin := Vector2.ZERO   ## the camera's spot when the gust began (its front sweeps from there)
var _mid: Array = []           ## per drafty stretch: its middle (tiles)
var _reach: Array = []         ## ...and how far it spreads from there


func setup(v: Node, w: Wind) -> void:
	view = v
	wind = w
	world = w.world
	_rng.seed = world.seed_value + 303
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# the ribbons of air: one mesh, rebuilt every frame
	_ribbon_mesh = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _ribbon_mesh
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.vertex_color_use_as_albedo = true
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	rm.render_priority = 110   # after the ink pass (view3d.gd _add_ink, 100), which would paint over it
	mi.material_override = rm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0
	add_child(mi)
	# the bits blowing along: little squares of pixels facing the camera
	_bit_mm = MultiMesh.new()
	_bit_mm.transform_format = MultiMesh.TRANSFORM_3D
	_bit_mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	_bit_mm.mesh = q
	_bit_mm.instance_count = MAX_BITS
	_bit_mm.visible_instance_count = 0
	var bi := MultiMeshInstance3D.new()
	bi.multimesh = _bit_mm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.vertex_color_use_as_albedo = true
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bm.billboard_keep_scale = true
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.render_priority = 110
	bi.material_override = bm
	bi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bi.extra_cull_margin = 16384.0
	add_child(bi)
	wind.puffed.connect(_on_puff)
	for st in wind.stretches:
		var mid := Vector2.ZERO
		for c in st.cells:
			mid += Vector2(c) + Vector2(0.5, 0.5)
		mid /= maxf(st.cells.size(), 1)
		var reach := 0.0
		for c in st.cells:
			reach = maxf(reach, (Vector2(c) + Vector2(0.5, 0.5)).distance_to(mid))
		_mid.append(mid)
		_reach.append(reach)


# --- Where things are ---------------------------------------------------------------------

func _targets() -> Array:
	return view.targets()


func _near(p: Vector2, reach: float = RANGE) -> bool:
	for t in _targets():
		if Vector2(t.x, t.z).distance_to(p) < reach:
			return true
	return false


func _open(p: Vector2) -> bool:
	var c := Vector2i(floori(p.x), floori(p.y))
	return world.is_walkable(c) and not world.near_village(c, 1)


## What blows about where this point is.
func _bits_at(p: Vector2) -> Array:
	var zi := world.zone_at(Vector2i(floori(p.x), floori(p.y)))
	var rare = world.get("zone_rare")
	if rare is Array and zi >= 0 and zi < rare.size() and RARE_BITS.has(int(rare[zi])):
		return BITS[RARE_BITS[int(rare[zi])]]
	var b := 0
	if zi >= 0 and zi < world.zone_biome.size():
		b = world.zone_biome[zi]
	return BITS[BIOME_BITS[clampi(b, 0, BIOME_BITS.size() - 1)]]


func _ground(p: Vector2) -> float:
	return view.ground_at(p.x, p.y)


# --- Puffs --------------------------------------------------------------------------------

## A puff starts down a stretch: if it's near, a ribbon or two of air will
## ride its front, and you hear it go by.
func _on_puff(i: int) -> void:
	if not view.active:
		return
	var st: Dictionary = wind.stretches[i]
	if not _near(_mid[i], RANGE + _reach[i]):
		return
	var dir: Vector2 = st.dir
	var near: Array = []
	var closest := INF
	var closest_c := Vector2i.ZERO
	for c in st.cells:
		var p := Vector2(c) + Vector2(0.5, 0.5)
		if not _near(p):
			continue
		for t in _targets():
			var dd := Vector2(t.x, t.z).distance_to(p)
			if dd < closest:
				closest = dd
				closest_c = c
		# a ribbon needs a little run of open corridor ahead of it
		if _open(p + dir) and _open(p + dir * 2.0):
			near.append(c)
	if closest < 9.0:   # (play_at quietens it with distance)
		Sfx.play_at("wind_puff%d" % (_rng.randi() % 3), Vector2(closest_c) * World.TILE, -7.0)
	if near.is_empty():
		return
	# the ones nearest you (it's there you'd see them)
	var ts := _targets()
	var t0 := Vector2(ts[0].x, ts[0].z) if not ts.is_empty() else Vector2.ZERO
	near.sort_custom(func(x, y): return (Vector2(x) - t0).length_squared() < (Vector2(y) - t0).length_squared() \
		or ((Vector2(x) - t0).length_squared() == (Vector2(y) - t0).length_squared() and x < y))
	near.resize(mini(near.size(), 8))
	for k in mini(3 if _rng.randf() < 0.4 else 2, near.size()):
		var c: Vector2i = near[_rng.randi() % near.size()]
		var p := Vector2(c) + Vector2(0.5, 0.5) + Vector2(-dir.y, dir.x) * _rng.randf_range(-0.25, 0.25)
		var along := p.dot(dir) - float(st.front)
		_add_ribbon(p, dir, maxf(0.0, along / Wind.PUFF_SPEED), Wind.PUFF_SPEED * 0.95, 0.55, 1.0)


func _add_ribbon(p: Vector2, dir: Vector2, delay: float, speed: float, power: float, life_k: float) -> void:
	# how far it can run before a wall (the air goes up and over it there)
	var run := 0.0
	while run < 14.0 and _open(p + dir * (run + 0.35)):
		run += 0.25
	_ribbons.append({
		"start": p, "dir": dir, "age": 0.0, "delay": delay,
		"life": _rng.randf_range(0.9, 1.3) * life_k, "seed": _rng.randf() * TAU,
		"speed": speed * _rng.randf_range(0.9, 1.1), "power": power, "run": run,
		"h": _rng.randf_range(0.2, 0.45) + (0.15 if power >= 1.0 else 0.0),
		"len": RIBBON_LEN * (1.7 if power >= 1.0 else 1.0) * _rng.randf_range(0.85, 1.15),
		"curl": 1.0 if _rng.randf() < 0.5 else -1.0, "y0": _ground(p),
	})


# --- Every frame --------------------------------------------------------------------------

func _process(delta: float) -> void:
	visible = view.active
	if not view.active:
		return
	_time += delta
	_gust(delta)
	_spawn_puff_bits(delta)
	_tick_ribbons(delta)
	_tick_bits(delta)
	_draw_ribbons()
	_draw_bits()
	_push_grass()


## The gust: a front sweeping across the screen, everything streaming behind it.
func _gust(delta: float) -> void:
	var on := wind.gust_left > 0.0 or wind.warning_left > 0.0
	if not on:
		_gust_was = false
		return
	var ts := _targets()
	if ts.is_empty():
		return
	var t: Vector3 = ts[0]
	if not _gust_was:
		_gust_was = true
		_gust_age = 0.0
	var dir := wind.gust_dir
	var across := Vector2(-dir.y, dir.x)
	var power := wind.gust_power()
	if wind.gust_left > 0.0:
		var first := _gust_age == 0.0
		if first:
			_gust_origin = Vector2(t.x, t.z)
		var was := _gust_front()
		_gust_age += delta
		# ribbons: thrown up all along the front as it sweeps across the screen,
		# then a steady stream behind it
		var front := _gust_front()
		var tries := 0
		var want := int((front - was) * 1.1) + (1 if _rng.randf() < fmod((front - was) * 1.1, 1.0) else 0)
		if front > GUST_FROM:
			want = 1 if _rng.randf() < delta * 9.0 * power else 0
		while want > 0 and tries < 30:
			tries += 1
			var along := _rng.randf_range(was, front) if front <= GUST_FROM else _rng.randf_range(-9.0, 7.0)
			var p := _gust_origin + dir * along + across * _rng.randf_range(-10.0, 10.0)
			if _open(p) and _open(p + dir) and _open(p + dir * 2.0):
				_add_ribbon(p, dir, 0.0, GUST_SWEEP * 0.5, 1.0, 1.2)
				want -= 1
	# bits: a few in the warning (the first leaves skittering), a storm once it hits
	var rate := 26.0 * power / 0.25 if wind.gust_left <= 0.0 else 120.0 * power
	var count := int(rate * delta) + (1 if _rng.randf() < fmod(rate * delta, 1.0) else 0)
	for k in count:
		var p := Vector2(t.x, t.z) + across * _rng.randf_range(-12.0, 12.0) + dir * _rng.randf_range(-10.0, 6.0)
		if wind.gust_left > 0.0 and (p - _gust_origin).dot(dir) > _gust_front():
			continue   # (ahead of the front, still calm)
		_spawn_bit(p, Vector3(dir.x, 0.0, dir.y) * _rng.randf_range(5.0, 9.0) * maxf(power, 0.35), power)


## How far past the camera's spot the gust's front has come (tiles, along it).
func _gust_front() -> float:
	return -GUST_FROM + _gust_age * GUST_SWEEP


## Bits picked up where a puff's front is passing.
func _spawn_puff_bits(delta: float) -> void:
	for i in wind.stretches.size():
		var st: Dictionary = wind.stretches[i]
		if st.front == -INF or not _near(_mid[i], RANGE + _reach[i]):
			continue
		var dir: Vector2 = st.dir
		for c in st.cells:
			var p := Vector2(c) + Vector2(0.5, 0.5)
			var d := p.dot(dir) - float(st.front)
			if d > 0.2 or d < -1.4:
				continue
			if not _near(p):
				continue
			if _rng.randf() < 5.0 * delta:
				var q := p + Vector2(_rng.randf_range(-0.45, 0.45), _rng.randf_range(-0.45, 0.45))
				_spawn_bit(q, Vector3(dir.x, 0, dir.y) * Wind.PUFF_SPEED * _rng.randf_range(0.55, 0.85), 0.6)


func _spawn_bit(p: Vector2, vel: Vector3, power: float) -> void:
	if _bits.size() >= MAX_BITS or not _open(p):
		return
	var kind_of: Array = _bits_at(p)
	var cols: Array = kind_of[0]
	var kind: String = kind_of[2]
	var col := Color(String(cols[_rng.randi() % cols.size()]))
	var glow := kind == "glint" or (kind == "ash" and col.r > 0.9)   # embers and gold dust shine on their own
	var y := _ground(p) + (0.05 if kind in ["leaf", "grit", "dust"] else _rng.randf_range(0.1, 0.5))
	var v := vel
	v.y = _rng.randf_range(0.4, 1.6) * (1.0 + power)
	if kind == "spray":
		v.y = _rng.randf_range(1.0, 2.0)
	_bits.append({
		"p": Vector3(p.x, y, p.y), "v": v, "age": 0.0,
		"life": _rng.randf_range(0.9, 1.8) * (0.7 if kind in ["dust", "spray"] else 1.0),
		"col": col, "size": kind_of[1], "kind": kind, "spin": _rng.randf() * TAU, "glow": glow,
	})


func _tick_ribbons(delta: float) -> void:
	var keep: Array = []
	for r in _ribbons:
		if r.delay > 0.0:
			r.delay -= delta
		else:
			r.age += delta
		var past_wall := float(r.speed) * float(r.age) - float(r.run)
		if r.age < r.life + 0.35 and past_wall < 1.2:
			keep.append(r)
	_ribbons = keep


func _tick_bits(delta: float) -> void:
	var keep: Array = []
	for b in _bits:
		b.age += delta
		if b.age > b.life:
			continue
		var p: Vector3 = b.p
		var v: Vector3 = b.v
		var here := Vector2(p.x, p.z)
		# carried by the air where it is: a puff, a gust, or nothing (it settles)
		var push := Vector2.ZERO
		var pw := wind.puff_at(here)
		var d: Vector2 = wind.zones.get(Vector2i(floori(p.x), floori(p.z)), Vector2.ZERO)
		push = d * Wind.PUFF_SPEED * 0.8 * pw
		if wind.gust_left > 0.0 or wind.warning_left > 0.0:
			push += wind.gust_dir * 8.0 * wind.gust_power()
		var drag := 2.2 if b.kind in ["leaf", "fluff"] else 1.4
		v.x += (push.x - v.x) * minf(1.0, drag * delta) if push != Vector2.ZERO else -v.x * minf(1.0, 1.2 * delta)
		v.z += (push.y - v.z) * minf(1.0, drag * delta) if push != Vector2.ZERO else -v.z * minf(1.0, 1.2 * delta)
		var grav := 3.0
		match b.kind:
			"leaf": grav = 2.2; v.y += sin(b.age * 7.0 + b.spin) * 3.0 * delta
			"fluff": grav = 0.5
			"dust": grav = 0.8
			"spray": grav = 6.0
			"ash": grav = -0.4 if b.glow else 0.9   # embers rise
			"glint": grav = 0.3
		v.y -= grav * delta
		var np := p + v * delta
		# into a wall: it's stopped (and gone)
		if not _open(Vector2(np.x, np.z)):
			continue
		var g := _ground(Vector2(np.x, np.z))
		if np.y < g + 0.02:
			np.y = g + 0.02
			if b.kind == "spray":
				continue   # (it splashes and is gone)
			v.y = absf(v.y) * 0.35 + (pw + wind.gust_power()) * _rng.randf_range(0.2, 1.4)   # skipping along
			v.x *= 0.85
			v.z *= 0.85
		b.p = np
		b.v = v
		b.spin += delta * (9.0 + v.length() * 2.0)
		keep.append(b)
	_bits = keep


# --- Drawing ------------------------------------------------------------------------------

func _lit(p: Vector3) -> float:
	var c: Color = view.light_at(p)
	return clampf(maxf(c.r, maxf(c.g, c.b)), 0.0, 1.2)


func _draw_ribbons() -> void:
	_ribbon_mesh.clear_surfaces()
	var any := false
	var cam: Camera3D = view.camera_for(Vector3.ZERO)
	var back := cam.global_transform.basis.z if cam != null else Vector3(0, 0.8, 0.6)
	for r in _ribbons:
		if r.delay > 0.0:
			continue
		var head := float(r.speed) * float(r.age)
		var tail := maxf(0.0, head - float(r.len))
		if head - tail < 0.15:
			continue
		var fade := clampf((r.life + 0.35 - r.age) / 0.45, 0.0, 1.0)
		fade *= clampf(1.0 - (head - float(r.run) - 0.2) / 1.0, 0.0, 1.0)   # (gone, over the wall)
		if fade <= 0.0:
			continue
		if not any:
			_ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			any = true
		var pts: Array = []
		var n := 26
		for i in n + 1:
			pts.append(_ribbon_at(r, lerpf(head, tail, float(i) / n), head))
		var strong: bool = r.power >= 1.0
		# a soft, see-through sheath of air, and the bright thread down its middle
		_strip(pts, back, 0.13 if strong else 0.11, fade * (0.34 if strong else 0.28))
		_strip(pts, back, 0.045, fade)
	if any:
		_ribbon_mesh.surface_end()


## A point on a ribbon, `s` tiles along its way (its head is at `head`): it
## lifts off the floor, waves as it goes, rises up over the wall where the
## corridor ends, and its head curls round like a breath of air.
func _ribbon_at(r: Dictionary, s: float, head: float) -> Vector3:
	var dir: Vector2 = r.dir
	var across := Vector2(-dir.y, dir.x)
	var seed: float = r.seed
	var curl_len := 0.95
	var sc := minf(s, head - curl_len) if head > curl_len else s
	var g: Vector2 = Vector2(r.start) + dir * sc
	var settle := clampf(sc / 0.8, 0.0, 1.0)
	g += across * (0.2 * sin(sc * 1.7 + seed) + 0.05 * sin(sc * 4.3 + seed * 2.0)) * settle
	var y: float = float(r.y0) + float(r.h) * (0.4 + 0.6 * settle) + 0.1 * sin(sc * 1.2 + seed)
	y += smoothstep(float(r.run) - 1.0, float(r.run) + 0.1, sc) * 1.25   # up and over the wall
	var p := Vector3(g.x, y, g.y)
	if s > sc and head > curl_len:
		# the curl at its head
		var th := (s - sc) / curl_len * PI * 1.55
		var rad := 0.24 if r.power < 1.0 else 0.32
		var up := (Vector3.UP * 0.75 + Vector3(across.x, 0, across.y) * 0.45 * float(r.curl)).normalized()
		p += Vector3(dir.x, 0, dir.y) * sin(th) * rad + up * (1.0 - cos(th)) * rad
	return p


## A band along the points, turned to face the camera, fading in from the
## tail and brightest toward the head; brighter where there's light to catch it.
func _strip(pts: Array, back: Vector3, half: float, alpha: float) -> void:
	var n := pts.size()
	for i in range(n - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var seg := b - a
		if seg.length() < 0.0001:
			continue
		var w := seg.cross(back).normalized()
		var ta := float(i) / float(n - 1)
		var tb := float(i + 1) / float(n - 1)
		var wa := w * half * (1.0 - ta * 0.55)
		var wb := w * half * (1.0 - tb * 0.55)
		var ca := _air_col(a, ta, alpha)
		var cb := _air_col(b, tb, alpha)
		_tri(a - wa, ca, a + wa, ca, b + wb, cb)
		_tri(a - wa, ca, b + wb, cb, b - wb, cb)


func _air_col(p: Vector3, t: float, alpha: float) -> Color:
	# the head (t = 0) bright, the tail trailing off to nothing
	var k := clampf(t / 0.06, 0.3, 1.0) if t < 0.06 else (1.0 if t < 0.45 else pow(1.0 - (t - 0.45) / 0.55, 1.2))
	var l := _lit(p)
	# (a little moonlight on it even in the dark, so you can see the air move)
	var a := alpha * k * clampf(0.5 + l * 0.45, 0.0, 1.0)
	return Color(AIR.r * (0.78 + l * 0.3), AIR.g * (0.8 + l * 0.28), AIR.b * (0.86 + l * 0.2), a)


func _tri(a: Vector3, ca: Color, b: Vector3, cb: Color, c: Vector3, cc: Color) -> void:
	_ribbon_mesh.surface_set_color(ca)
	_ribbon_mesh.surface_add_vertex(a)
	_ribbon_mesh.surface_set_color(cb)
	_ribbon_mesh.surface_add_vertex(b)
	_ribbon_mesh.surface_set_color(cc)
	_ribbon_mesh.surface_add_vertex(c)


func _draw_bits() -> void:
	var n := mini(_bits.size(), MAX_BITS)
	_bit_mm.visible_instance_count = n
	if n == 0:
		return
	var cam: Camera3D = view.camera_for(Vector3.ZERO)
	var k := 1.0
	for i in n:
		var b: Dictionary = _bits[i]
		var p: Vector3 = b.p
		if cam != null:
			k = (p - cam.global_position).dot(-cam.global_transform.basis.z) / View3D.DIST
		var sz: Vector2 = b.size
		var w := sz.x
		var h := sz.y
		if b.kind == "leaf":
			# tumbling: edge-on, then flat, then edge-on
			var f := absf(cos(b.spin))
			w = 1.0 if f < 0.4 else sz.x + 1.0
			h = 1.0 if f > 0.75 else 2.0
		var fade := clampf((b.life - b.age) / 0.35, 0.0, 1.0) * clampf(b.age / 0.12, 0.0, 1.0)
		var col: Color = b.col
		if not b.glow:
			var l := maxf(_lit(p), 0.42)   # (moonlit, at least)
			col = Color(col.r * l, col.g * l, col.b * l)
		elif b.kind == "glint":
			col = col.lightened(0.4 * absf(sin(b.spin * 0.7)))
		col.a = fade
		var basis := Basis().scaled(Vector3(w * PX * k, h * PX * k, 1.0))
		_bit_mm.set_instance_transform(i, Transform3D(basis, p))
		_bit_mm.set_instance_color(i, col)


## The grass bends ahead of each puff and behind a gust's front
## (tall_grass.gdshader's puffs: point on the front, push; and its shape).
func _push_grass() -> void:
	var tg = view.get("tall_grass")
	if tg == null:
		return
	var mat = tg.get("_mat")
	if mat == null:
		return
	var pos: Array = []
	var shape: Array = []
	if wind.gust_left > 0.0 or wind.warning_left > 0.0:
		var dir := wind.gust_dir
		var ts := _targets()
		var o := _gust_origin if wind.gust_left > 0.0 else (Vector2(ts[0].x, ts[0].z) if not ts.is_empty() else Vector2.ZERO)
		var front := _gust_front() if wind.gust_left > 0.0 else -GUST_FROM
		var p := o + dir * front
		var s := maxf(wind.gust_power(), 0.08)
		pos.append(Vector4(p.x, p.y, dir.x * s, dir.y * s))
		shape.append(Vector4(1.2, 60.0, 999.0, 0.0))
	for i in wind.stretches.size():
		var st: Dictionary = wind.stretches[i]
		if pos.size() >= 6:
			break
		if st.front == -INF:
			continue
		var dir: Vector2 = st.dir
		var mid: Vector2 = _mid[i]
		if not _near(mid, RANGE + _reach[i]):
			continue
		var across := Vector2(-dir.y, dir.x)
		var p := across * mid.dot(across) + dir * float(st.front)
		pos.append(Vector4(p.x, p.y, dir.x, dir.y))
		shape.append(Vector4(Wind.PUFF_AHEAD + 0.4, Wind.PUFF_TAIL, _reach[i] + 0.5, 0.0))
	while pos.size() < 6:
		pos.append(Vector4.ZERO)
		shape.append(Vector4.ZERO)
	mat.set_shader_parameter("puffs", pos)
	mat.set_shader_parameter("puff_shape", shape)
