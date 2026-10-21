class_name Village3D
extends Node3D
## The villages as 3D models for View3D: timber-and-plaster houses with
## pitched roofs, chimneys, lit windows and doors; the inn, the shop with its
## awning, the sage's round tower; the palisade (or stone wall) round it all
## with its gate that swings open; lamp posts, the well, the farm's fence,
## barrels, crates and hay. Same layout and colours as the 2D art (each
## village has its own style: roof colour, wood or stone wall).
##
## The static parts of a village are merged into a few meshes (one per
## material); only the gate leaves move.

const W3D := "res://assets/w3d/"
const LAMP_GLOW := Color(1.0, 0.8, 0.5)

var view: View3D
var villages: Villages
var _mats := {}
var _st := {}            ## material key -> SurfaceTool (the village being built)
var _gates: Array = []   ## [gate cell, left pivot, right pivot, inward sign]


func build(v: View3D) -> void:
	view = v
	villages = v.main.get("villages")
	if villages == null:
		return
	for vi in villages.list.size():
		_build_village(vi)


func _process(_delta: float) -> void:
	if view == null or not view.active or villages == null:
		return
	for g in _gates:
		var t: float = villages.gate_open.get(g[0], 0.0)
		var a := (1.0 - pow(1.0 - t, 2.0)) * deg_to_rad(100.0)
		(g[1] as Node3D).rotation.y = -a * g[3]
		(g[2] as Node3D).rotation.y = a * g[3]


# --- Materials ---------------------------------------------------------------------

func mat(key: String, tint := Color.WHITE, glow := 0.0, cut := false) -> StandardMaterial3D:
	var k := "%s|%s|%s|%s" % [key, tint, glow, cut]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.texture_repeat = true
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if key != "":
		m.albedo_texture = load(W3D + key + ".png")
	m.albedo_color = tint
	if cut:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = tint
		m.emission_energy_multiplier = glow
		if key != "":
			m.emission_texture = m.albedo_texture
	_mats[k] = m
	return m


# --- Building meshes ------------------------------------------------------------------

func _surf(key: String) -> SurfaceTool:
	if not _st.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[key] = st
	return _st[key]


## A quad: corners top-left, top-right, bottom-right, bottom-left (seen from
## its front); the texture repeats `u` times across and `v` times down.
func _quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, u: float, v: float) -> void:
	var st := _surf(key)
	var n := (b - a).cross(d - a).normalized()
	var pts := [a, b, c, d]
	var uvs := [Vector2(0, 0), Vector2(u, 0), Vector2(u, v), Vector2(0, v)]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n)
		st.set_uv(uvs[k])
		st.add_vertex(pts[k])


## A box (texture `density` repeats per tile). `sides_only`: no top or bottom.
func _box(key: String, lo: Vector3, hi: Vector3, density := Vector2.ONE, sides_only := false) -> void:
	var sx := (hi.x - lo.x) * density.x
	var sz := (hi.z - lo.z) * density.x
	var sy := (hi.y - lo.y) * density.y
	# south, north, east, west
	_quad(key, Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z), sx, sy)
	_quad(key, Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), sx, sy)
	_quad(key, Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), sz, sy)
	_quad(key, Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, lo.y, lo.z), sz, sy)
	if not sides_only:
		_quad(key, Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z), sx, sz)


func _tri(key: String, a: Vector3, b: Vector3, c: Vector3, scale := 1.0) -> void:
	var st := _surf(key)
	var n := (b - a).cross(c - a).normalized()
	for p in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2(p.x + p.z, -p.y) * scale)
		st.add_vertex(p)


func _flush(parent: Node3D) -> void:
	for key in _st:
		var mi := MeshInstance3D.new()
		mi.mesh = (_st[key] as SurfaceTool).commit()
		mi.material_override = _mat_for(key)
		parent.add_child(mi)
	_st.clear()


## Surface keys are "texture" or "texture@glow" or "texture#cut" or "tint:r,g,b".
func _mat_for(key: String) -> Material:
	if key.begins_with("tint:"):
		var p := key.substr(5).split(",")
		var glow := float(p[3]) if p.size() > 3 else 0.0
		return mat("", Color(float(p[0]), float(p[1]), float(p[2])), glow)
	if key.ends_with("@glow"):
		return mat(key.trim_suffix("@glow"), Color.WHITE, 0.55)
	if key.ends_with("#cut"):
		return mat(key.trim_suffix("#cut"), Color.WHITE, 0.0, true)
	if key.contains("*"):
		var p := key.split("*")
		return mat(p[0], Color(p[1]))
	return mat(key)


# --- A village ------------------------------------------------------------------------

func _build_village(vi: int) -> void:
	var v: Dictionary = villages.list[vi]
	var st := villages.style_of(vi)
	var stone := st == 1 or st == 2
	var P: Rect2i = v.rect
	var node := Node3D.new()
	node.position.y = view.ground_at(P.get_center().x, P.get_center().y)
	add_child(node)
	var solid: Dictionary = v.solid
	var wood := "vwood_%d" % st
	# the wall round the village
	for y in range(P.position.y, P.end.y):
		for x in range(P.position.x, P.end.x):
			var c := Vector2i(x, y)
			match solid.get(c, ""):
				"wall":
					_wall(v, c, st, stone)
				"fence":
					_fence(solid, c, wood)
	for g in v.gates:
		_gate(node, v, g, st, stone)
	for b in v.buildings:
		_building(b, st)
	for p in v.props:
		_prop(node, p, wood)
	_well(v.well, st)
	_flush(node)


func _is_wallish(v: Dictionary, c: Vector2i) -> bool:
	return v.solid.get(c, "") == "wall" or v.gates.has(c)


## A stretch of the village wall: arms from the middle of the cell toward
## each neighbouring piece of wall. Palisades are sharpened logs (cut out
## against the sky); stone walls have a coping on top.
func _wall(v: Dictionary, c: Vector2i, st: int, stone: bool) -> void:
	if v.gates.has(c + Vector2i.LEFT) or v.gates.has(c + Vector2i.RIGHT):
		return   # a gate post stands here
	var h := 1.15 if stone else 1.3
	var t := 0.2 if stone else 0.17
	var m := Vector3(c.x + 0.5, 0, c.y + 0.5)
	var key := "vwall_%d" % st
	var dens := Vector2(0.5, 1.0 / 1.5) if stone else Vector2(1.0, 1.0 / 1.5)
	var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	var any := false
	for d in dirs:
		if not _is_wallish(v, c + d):
			continue
		any = true
		var lo := m + Vector3(minf(d.x * 0.5, 0.0) - t * absf(d.y), 0, minf(d.y * 0.5, 0.0) - t * absf(d.x))
		var hi := m + Vector3(maxf(d.x * 0.5, 0.0) + t * absf(d.y), h, maxf(d.y * 0.5, 0.0) + t * absf(d.x))
		if stone:
			_box(key, lo, hi, dens, true)
			_box("tint:0.82,0.8,0.76", Vector3(lo.x - 0.05 * absf(d.y), h, lo.z - 0.05 * absf(d.x)), Vector3(hi.x + 0.05 * absf(d.y), h + 0.12, hi.z + 0.05 * absf(d.x)))
		else:
			_box(key + "#cut", lo, hi, dens, true)
	# a post where it turns or ends
	var straight := (_is_wallish(v, c + Vector2i.LEFT) and _is_wallish(v, c + Vector2i.RIGHT) and not _is_wallish(v, c + Vector2i.UP) and not _is_wallish(v, c + Vector2i.DOWN)) \
		or (_is_wallish(v, c + Vector2i.UP) and _is_wallish(v, c + Vector2i.DOWN) and not _is_wallish(v, c + Vector2i.LEFT) and not _is_wallish(v, c + Vector2i.RIGHT))
	if not straight or not any:
		var r := t + 0.08
		if stone:
			_box(key, m + Vector3(-r, 0, -r), m + Vector3(r, h + 0.15, r), dens)
			_box("tint:0.82,0.8,0.76", m + Vector3(-r - 0.05, h + 0.15, -r - 0.05), m + Vector3(r + 0.05, h + 0.27, r + 0.05))
		else:
			_box("vwood_%d" % st, m + Vector3(-r, 0, -r), m + Vector3(r, h + 0.12, r), Vector2(1, 1))


func _fence(solid: Dictionary, c: Vector2i, wood: String) -> void:
	var m := Vector3(c.x + 0.5, 0, c.y + 0.5)
	_box(wood, m + Vector3(-0.06, 0, -0.06), m + Vector3(0.06, 0.62, 0.06))
	for d in [Vector2i.RIGHT, Vector2i.DOWN]:
		if solid.get(c + d, "") != "fence":
			continue
		for y in [0.28, 0.5]:
			var lo := m + Vector3(0, y, 0) - Vector3(0.03, 0, 0.03)
			var hi := m + Vector3(d.x, y + 0.07, d.y) + Vector3(0.03, 0, 0.03)
			_box(wood, lo, hi, Vector2(1, 1))


## The village gate: two tall posts, a beam with a lantern, and two leaves
## that swing inward when someone comes near.
func _gate(node: Node3D, v: Dictionary, g: Vector2i, st: int, stone: bool) -> void:
	var post := ("vwall_%d" % st) if stone else ("vwood_%d" % st)
	var h := 2.0
	var z := g.y + 0.5
	for dx in [-1, 1]:
		var x: float = g.x + 0.5 + dx * 0.78
		_box(post, Vector3(x - 0.24, 0, z - 0.24), Vector3(x + 0.24, h, z + 0.24), Vector2(0.5, 0.5) if stone else Vector2.ONE)
		_box("tint:0.35,0.24,0.15", Vector3(x - 0.28, h, z - 0.28), Vector3(x + 0.28, h + 0.1, z + 0.28))
	_box("vwood_%d" % st, Vector3(g.x - 0.5, h - 0.32, z - 0.14), Vector3(g.x + 1.5, h - 0.1, z + 0.14), Vector2(1, 1))
	# the lantern under the beam
	_box("tint:0.15,0.13,0.16", Vector3(g.x + 0.42, h - 0.36, z - 0.02), Vector3(g.x + 0.58, h - 0.32, z + 0.02))
	_box("tint:1.0,0.8,0.5,2.5", Vector3(g.x + 0.4, h - 0.6, z - 0.08), Vector3(g.x + 0.6, h - 0.38, z + 0.08))
	var inward := 1.0 if g.y == (v.rect as Rect2i).position.y else -1.0
	var leaf := mat("vwood_%d" % st)
	var pivots: Array[Node3D] = []
	for side in [-1, 1]:
		var pv := Node3D.new()
		pv.position = Vector3(g.x + 0.5 + side * 0.54, 0, z)
		node.add_child(pv)
		var mi := MeshInstance3D.new()
		var w := 0.54
		var lo := Vector3(0.0 if side < 0 else -w, 0.04, -0.05)
		var hi := Vector3(w if side < 0 else 0.0, 1.45, 0.05)
		mi.mesh = Objects3D.box_mesh(lo, hi, Vector2(w * 2.0, 1.4))
		mi.material_override = leaf
		pv.add_child(mi)
		# a cross brace
		var br := MeshInstance3D.new()
		br.mesh = Objects3D.box_mesh(Vector3(lo.x, 0.6, -0.08), Vector3(hi.x, 0.75, 0.08), Vector2(1, 0.2))
		br.material_override = mat("", Color(0.3, 0.2, 0.12))
		pv.add_child(br)
		pivots.append(pv)
	_gates.append([g, pivots[0], pivots[1], inward])


## A house (or the inn, the shop): plaster walls on a stone footing, timber
## corners, a pitched roof with a chimney, a door and lit windows facing the
## street (south, as in the 2D art).
func _building(b: Dictionary, st: int) -> void:
	var r: Rect2i = b.rect
	var kind: String = b.kind
	if kind == "sage":
		_tower(r)
		return
	var x0 := r.position.x + 0.06
	var x1 := r.end.x - 0.06
	var z0 := r.position.y + 0.25
	var z1 := r.end.y - 0.04
	var H := 1.3
	match kind:
		"inn": H = 2.1
		"shop": H = 1.45
	var wood := "vwood_%d" % st
	var timber := "tint:0.3,0.19,0.11"
	if st == 4:
		timber = "tint:0.2,0.17,0.12"
	# footing and walls
	_box("slab", Vector3(x0 - 0.05, 0, z0 - 0.05), Vector3(x1 + 0.05, 0.18, z1 + 0.05), Vector2(1, 1))
	var wall_key := wood if (st == 3 or st == 4) else "plaster"
	_box(wall_key, Vector3(x0, 0.18, z0), Vector3(x1, H, z1), Vector2(1, 1), true)
	# timber frame: corner posts, a beam under the eaves (and between floors)
	for x in [x0, x1]:
		for z in [z0, z1]:
			_box(timber, Vector3(x - 0.07, 0.18, z - 0.07), Vector3(x + 0.07, H, z + 0.07))
	_box(timber, Vector3(x0 - 0.04, H - 0.12, z1 - 0.02), Vector3(x1 + 0.04, H, z1 + 0.05))
	if kind == "inn":
		_box(timber, Vector3(x0 - 0.04, 1.05, z1 - 0.02), Vector3(x1 + 0.04, 1.15, z1 + 0.05))
	# the roof: ridge running east-west, eaves overhanging all round
	var o := 0.24
	var depth := z1 - z0
	var rise := depth * (0.42 if kind != "inn" else 0.36)
	var zm := (z0 + z1) / 2.0
	var roof := "roof_%d" % st
	var ra := Vector3(x0 - o, H - 0.08, z1 + o)
	var rb := Vector3(x1 + o, H - 0.08, z1 + o)
	var rc := Vector3(x1 + o, H + rise, zm)
	var rd := Vector3(x0 - o, H + rise, zm)
	var slope := (rc - rb).length()
	_quad(roof, rd, rc, rb, ra, x1 - x0 + 2 * o, slope)
	_quad(roof, Vector3(x1 + o, H + rise, zm), Vector3(x0 - o, H + rise, zm), Vector3(x0 - o, H - 0.08, z0 - o), Vector3(x1 + o, H - 0.08, z0 - o), x1 - x0 + 2 * o, slope)
	# a ridge cap
	_box("tint:0.3,0.2,0.14", Vector3(x0 - o - 0.02, H + rise - 0.06, zm - 0.07), Vector3(x1 + o + 0.02, H + rise + 0.07, zm + 0.07))
	# gable ends
	for x in [x0, x1]:
		_tri(wall_key, Vector3(x, H, z1), Vector3(x, H + rise - 0.05, zm), Vector3(x, H, z0))
	# chimney (towards the back, so the roof hides its foot)
	if kind != "shop":
		var cx := x0 + 0.8 + float(int(b.variant) % 2) * (x1 - x0 - 1.6)
		_box("slab", Vector3(cx - 0.17, H + rise * 0.3, zm - depth * 0.3 - 0.17), Vector3(cx + 0.17, H + rise + 0.45, zm - depth * 0.3 + 0.17), Vector2(1, 1))
		_box("tint:0.12,0.1,0.1", Vector3(cx - 0.2, H + rise + 0.45, zm - depth * 0.3 - 0.2), Vector3(cx + 0.2, H + rise + 0.52, zm - depth * 0.3 + 0.2))
	# the door (the shop's stands open, lit: see below)
	var d: Vector2i = b.door
	var fz := z1 + 0.012
	if kind != "shop":
		_quad("house_door", Vector3(d.x + 0.22, 0.98, fz), Vector3(d.x + 0.78, 0.98, fz), Vector3(d.x + 0.78, 0.18, fz), Vector3(d.x + 0.22, 0.18, fz), 0.56, 0.8)
	_box(timber, Vector3(d.x + 0.14, 0.98, z1 - 0.02), Vector3(d.x + 0.86, 1.08, z1 + 0.06))
	_box("slab", Vector3(d.x + 0.12, 0, z1), Vector3(d.x + 0.88, 0.1, z1 + 0.3), Vector2(1, 1))
	# windows either side of the door, on each floor
	var rows: Array = [0.52]
	if kind == "inn":
		rows = [0.48, 1.42]
	for wy in rows:
		for x in range(r.position.x, r.end.x):
			if x == d.x and wy < 1.0:
				continue
			if absi(x - d.x) == 0 and wy > 1.0 and kind == "inn":
				pass
			var wx := x + 0.5
			if x == r.position.x:
				wx += 0.08
			elif x == r.end.x - 1:
				wx -= 0.08
			_quad("window@glow", Vector3(wx - 0.19, wy + 0.4, fz), Vector3(wx + 0.19, wy + 0.4, fz), Vector3(wx + 0.19, wy, fz), Vector3(wx - 0.19, wy, fz), 1, 1)
			# a sill
			_box(timber, Vector3(wx - 0.23, wy - 0.05, z1), Vector3(wx + 0.23, wy, z1 + 0.06))
	# the shop's striped awning; the inn's hanging sign
	if kind == "shop":
		_shop_front(x0, x1, z1, fz, d, timber)
	elif kind == "inn":
		var sx := float(d.x) + 1.5
		_box(timber, Vector3(sx - 0.03, 1.25, z1), Vector3(sx + 0.03, 1.31, z1 + 0.45))
		_box("tint:0.62,0.42,0.22", Vector3(sx - 0.02, 0.88, z1 + 0.15), Vector3(sx + 0.02, 1.22, z1 + 0.45))


## The shop's front: the striped awning over the windows only, in two halves,
## so the doorway between them is never hidden; the door stands open with warm
## light inside and spilling onto the step; a lantern either side, and a sign
## over it (a gold coin and a ruby) -- you can't miss the way in.
func _shop_front(x0: float, x1: float, z1: float, fz: float, d: Vector2i, timber: String) -> void:
	for seg in [[x0 + 0.15, float(d.x) + 0.04], [float(d.x) + 0.96, x1 - 0.15]]:
		var a: float = seg[0]
		var e: float = seg[1]
		if e - a < 0.3:
			continue
		_quad("awning", Vector3(a, 1.2, z1 + 0.02), Vector3(e, 1.2, z1 + 0.02), Vector3(e, 0.98, z1 + 0.5), Vector3(a, 0.98, z1 + 0.5), e - a, 1)
		_quad("awning", Vector3(a, 0.98, z1 + 0.5), Vector3(e, 0.98, z1 + 0.5), Vector3(e, 0.86, z1 + 0.5), Vector3(a, 0.86, z1 + 0.5), e - a, 0.5)
	var l := float(d.x) + 0.2
	var r := float(d.x) + 0.8
	# the open doorway: a warm, lit room beyond, darker at its edges
	_quad("tint:1.0,0.72,0.42,1.3", Vector3(l, 1.0, fz), Vector3(r, 1.0, fz), Vector3(r, 0.18, fz), Vector3(l, 0.18, fz), 1, 1)
	_quad("tint:0.55,0.32,0.18,0.6", Vector3(l, 1.0, fz + 0.002), Vector3(r, 1.0, fz + 0.002), Vector3(r, 0.9, fz + 0.002), Vector3(l, 0.9, fz + 0.002), 1, 1)
	# the door itself, swung open against the inside of the frame
	_quad("house_door", Vector3(l, 1.0, fz + 0.004), Vector3(l + 0.13, 1.0, fz + 0.004), Vector3(l + 0.13, 0.18, fz + 0.004), Vector3(l, 0.18, fz + 0.004), 0.15, 0.8)
	# the frame
	_box(timber, Vector3(l - 0.07, 0.18, z1 - 0.02), Vector3(l, 1.02, z1 + 0.06))
	_box(timber, Vector3(r, 0.18, z1 - 0.02), Vector3(r + 0.07, 1.02, z1 + 0.06))
	_box(timber, Vector3(l - 0.08, 1.0, z1 - 0.02), Vector3(r + 0.08, 1.09, z1 + 0.07))
	# light spilling out onto the step
	_quad("tint:1.0,0.72,0.42,0.7", Vector3(l, 0.111, z1 + 0.02), Vector3(r, 0.111, z1 + 0.02), Vector3(r + 0.06, 0.111, z1 + 0.32), Vector3(l - 0.06, 0.111, z1 + 0.32), 1, 1)
	# a lantern either side of the door
	for lx in [l - 0.17, r + 0.17]:
		_box("tint:0.16,0.14,0.18", Vector3(lx - 0.02, 0.92, z1), Vector3(lx + 0.02, 0.96, z1 + 0.16))
		_box("tint:1.0,0.8,0.45,2.5", Vector3(lx - 0.06, 0.72, z1 + 0.08), Vector3(lx + 0.06, 0.9, z1 + 0.2))
		_box("tint:0.16,0.14,0.18", Vector3(lx - 0.08, 0.9, z1 + 0.06), Vector3(lx + 0.08, 0.94, z1 + 0.22))
	# the sign over the door: a board with a gold coin and a ruby on it
	var sc := float(d.x) + 0.5
	_box("tint:0.42,0.26,0.13", Vector3(sc - 0.34, 1.1, z1 + 0.02), Vector3(sc + 0.34, 1.38, z1 + 0.08))
	_box("tint:0.28,0.17,0.09", Vector3(sc - 0.37, 1.08, z1 + 0.01), Vector3(sc + 0.37, 1.11, z1 + 0.09))
	_box("tint:1.0,0.8,0.3,1.4", Vector3(sc - 0.2, 1.16, z1 + 0.08), Vector3(sc - 0.04, 1.32, z1 + 0.1))
	_box("tint:1.0,0.25,0.3,1.4", Vector3(sc + 0.05, 1.17, z1 + 0.08), Vector3(sc + 0.19, 1.31, z1 + 0.1))


## The sage's round tower with its purple cone roof.
func _tower(r: Rect2i) -> void:
	var c := Vector3(r.get_center().x, 0, r.get_center().y + 0.1)
	var rad := minf(r.size.x, r.size.y) / 2.0 - 0.15
	var H := 2.0
	var n := 10
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := c + Vector3(cos(a0), 0, sin(a0)) * rad
		var p1 := c + Vector3(cos(a1), 0, sin(a1)) * rad
		var w := (p1 - p0).length()
		_quad("plaster", p1 + Vector3(0, H, 0), p0 + Vector3(0, H, 0), p0, p1, w, H)
		# the cone
		var q0 := c + Vector3(cos(a0), 0, sin(a0)) * (rad + 0.3) + Vector3(0, H - 0.05, 0)
		var q1 := c + Vector3(cos(a1), 0, sin(a1)) * (rad + 0.3) + Vector3(0, H - 0.05, 0)
		_tri("roof_1*b07ae0", q0, c + Vector3(0, H + 1.8, 0), q1, 1.0)
	# door and windows on its south side
	var fz := c.z + rad + 0.01
	_quad("house_door", Vector3(c.x - 0.28, 0.95, fz), Vector3(c.x + 0.28, 0.95, fz), Vector3(c.x + 0.28, 0.0, fz), Vector3(c.x - 0.28, 0.0, fz), 0.56, 0.95)
	_quad("window@glow", Vector3(c.x - 0.17, 1.65, fz - 0.02), Vector3(c.x + 0.17, 1.65, fz - 0.02), Vector3(c.x + 0.17, 1.31, fz - 0.02), Vector3(c.x - 0.17, 1.31, fz - 0.02), 1, 1)
	_box("tint:1.0,0.85,0.4,2.0", c + Vector3(-0.05, H + 1.8, -0.05), c + Vector3(0.05, H + 1.95, 0.05))


func _well(r: Rect2i, st: int) -> void:
	var c := Vector3(r.position.x + 1.0, 0, r.position.y + 1.0)
	var R := 0.68
	var t := 0.2
	var hgt := 0.55
	_box("slab", c + Vector3(-R, 0, -R), c + Vector3(R, hgt, -R + t))
	_box("slab", c + Vector3(-R, 0, R - t), c + Vector3(R, hgt, R))
	_box("slab", c + Vector3(-R, 0, -R + t), c + Vector3(-R + t, hgt, R - t))
	_box("slab", c + Vector3(R - t, 0, -R + t), c + Vector3(R, hgt, R - t))
	_quad("tint:0.08,0.12,0.22", c + Vector3(-R + t, 0.3, -R + t), c + Vector3(R - t, 0.3, -R + t), c + Vector3(R - t, 0.3, R - t), c + Vector3(-R + t, 0.3, R - t), 1, 1)
	var wood := "vwood_%d" % st
	for dx in [-1, 1]:
		_box(wood, c + Vector3(dx * (R - 0.1) - 0.07, 0, -0.07), c + Vector3(dx * (R - 0.1) + 0.07, 1.45, 0.07))
	_box(wood, c + Vector3(-R, 1.2, -0.04), c + Vector3(R, 1.27, 0.04))
	# a little roof
	var roof := "roof_%d" % st
	_quad(roof, c + Vector3(-R - 0.15, 1.75, 0), c + Vector3(R + 0.15, 1.75, 0), c + Vector3(R + 0.15, 1.38, 0.6), c + Vector3(-R - 0.15, 1.38, 0.6), 2, 1)
	_quad(roof, c + Vector3(R + 0.15, 1.75, 0), c + Vector3(-R - 0.15, 1.75, 0), c + Vector3(-R - 0.15, 1.38, -0.6), c + Vector3(R + 0.15, 1.38, -0.6), 2, 1)


func _prop(node: Node3D, p: Dictionary, wood: String) -> void:
	var c: Vector2i = p.cell
	var m := Vector3(c.x + 0.5, 0, c.y + 0.5)
	match p.kind:
		"lamp":
			_box("tint:0.16,0.14,0.18", m + Vector3(-0.05, 0, -0.05), m + Vector3(0.05, 1.45, 0.05))
			_box("tint:0.16,0.14,0.18", m + Vector3(-0.1, 0, -0.1), m + Vector3(0.1, 0.12, 0.1))
			_box("tint:1.0,0.8,0.5,2.5", m + Vector3(-0.1, 1.45, -0.1), m + Vector3(0.1, 1.7, 0.1))
			_box("tint:0.16,0.14,0.18", m + Vector3(-0.14, 1.7, -0.14), m + Vector3(0.14, 1.78, 0.14))
		"barrel":
			_cyl(node, m, 0.24, 0.55, wood)
			_box("tint:0.25,0.22,0.24", m + Vector3(-0.25, 0.12, -0.25), m + Vector3(0.25, 0.16, 0.25))
			_box("tint:0.25,0.22,0.24", m + Vector3(-0.25, 0.4, -0.25), m + Vector3(0.25, 0.44, 0.25))
		"pots":
			_cyl(node, m + Vector3(-0.14, 0, 0.05), 0.15, 0.34, "clay")
			_cyl(node, m + Vector3(0.16, 0, -0.06), 0.12, 0.26, "clay")
		"hay":
			_box("straw", m + Vector3(-0.38, 0, -0.28), m + Vector3(0.38, 0.5, 0.28), Vector2(1, 1))
		_:
			_box(wood, m + Vector3(-0.25, 0, -0.25), m + Vector3(0.25, 0.5, 0.25), Vector2(2, 2))
			_box("tint:0.3,0.2,0.12", m + Vector3(-0.26, 0.22, -0.26), m + Vector3(0.26, 0.28, 0.26))


func _cyl(node: Node3D, at: Vector3, r: float, h: float, key: String) -> void:
	var mi := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = r * 0.9
	cy.bottom_radius = r
	cy.height = h
	cy.radial_segments = 8
	cy.rings = 1
	mi.mesh = cy
	var m := mat(key).duplicate() as StandardMaterial3D
	m.uv1_scale = Vector3(3, 1, 1)
	mi.material_override = m
	mi.position = at + Vector3(0, h / 2.0, 0)
	node.add_child(mi)
