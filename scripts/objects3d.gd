class_name Objects3D
extends Node3D
## The things in the labyrinth, as 3D models for View3D: doors that swing
## open, chests whose lids lift, gravestones, pillars, candles, bushes,
## boulders, the stone bier you wake on, the master seal. Their state comes
## from the game's own systems (Doors, Chests, MasterChamber...) every frame.

const W3D := "res://assets/w3d/"
const DOOR_H := 1.0

var view: View3D
var world: World
var _mats := {}
var _doors := {}      ## cell -> {node, leaf pivot, open amount}
var _chests := {}     ## cell -> {node, lid pivot, open amount}
var _gate: Dictionary = {}


func build(v: View3D) -> void:
	view = v
	world = v.world
	var main := v.main
	for c in main.doors.doors:
		_add_door(c, main.doors.doors[c].color)
	if main.master != null and main.master.gate.x >= 0:
		_gate = _add_door(main.master.gate, "purple", true)
	for c in main.chests.chests:
		_add_chest(c, main.chests.chests[c].get("purple", false))
	_props()
	_bier(world.start_cell)


func _process(delta: float) -> void:
	if view == null or not view.active:
		return
	var main := view.main
	for c in _doors:
		var d: Dictionary = _doors[c]
		var want := 1.0 if (main.doors.doors.has(c) and main.doors.doors[c].open) else 0.0
		if d.has("gate"):
			want = 1.0 if main.master.opened else 0.0
		d.t = move_toward(d.t, want, delta * 2.2)
		var ease := 1.0 - pow(1.0 - d.t, 3.0)
		(d.pivot as Node3D).rotation.y = d.sign * ease * deg_to_rad(105.0)
	for c in _chests:
		var ch: Dictionary = _chests[c]
		var want := 1.0 if (main.chests.chests.has(c) and main.chests.chests[c].open) else 0.0
		ch.t = move_toward(ch.t, want, delta * 3.0)
		var ease := 1.0 - pow(1.0 - ch.t, 3.0)
		(ch.pivot as Node3D).rotation.x = -ease * deg_to_rad(110.0)
	for c in _chests.keys():
		if not main.chests.chests.has(c):   # (a chest can vanish: a mimic, say)
			(_chests[c].node as Node3D).queue_free()
			_chests.erase(c)


# --- Materials and boxes ------------------------------------------------------

func mat(key: String, tint := Color.WHITE, glow := 0.0) -> StandardMaterial3D:
	var k := key + str(tint) + str(glow)
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.texture_repeat = true
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	if key != "":
		m.albedo_texture = load(W3D + key + ".png")
	m.albedo_color = tint
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = tint
		m.emission_energy_multiplier = glow
	_mats[k] = m
	return m


## A box from `lo` to `hi` (local), each face showing the whole texture
## (`tile`: how many times across a face).
static func box_mesh(lo: Vector3, hi: Vector3, tile := Vector2.ONE) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z),
		Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	# faces: corners (top-left, top-right, bottom-right, bottom-left as seen from outside), normal
	var faces := [
		[[7, 6, 5, 4], Vector3.BACK], [[2, 3, 0, 1], Vector3.FORWARD],
		[[6, 2, 1, 5], Vector3.RIGHT], [[3, 7, 4, 0], Vector3.LEFT],
		[[3, 2, 6, 7], Vector3.UP], [[4, 5, 1, 0], Vector3.DOWN],
	]
	var uvs := [Vector2(0, 0), Vector2(tile.x, 0), Vector2(tile.x, tile.y), Vector2(0, tile.y)]
	for f in faces:
		var idx: Array = f[0]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(f[1])
			st.set_uv(uvs[k])
			st.add_vertex(c[idx[k]])
	return st.commit()


func box(parent: Node3D, lo: Vector3, hi: Vector3, m: Material, tile := Vector2.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh(lo, hi, tile)
	mi.material_override = m
	parent.add_child(mi)
	return mi


func _cell_node(c: Vector2i) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(c.x + 0.5, view.ground_at(c.x + 0.5, c.y + 0.5), c.y + 0.5)
	add_child(n)
	return n


# --- Doors ------------------------------------------------------------------------

## A heavy plank door with iron (bronze, silver, gold) straps, hung across the
## doorway; it swings open on its hinge when unlocked.
func _add_door(c: Vector2i, color: String, gate := false) -> Dictionary:
	var n := _cell_node(c)
	# across an east-west passage the door faces east; else it faces south
	var ew := world.tile_at(c + Vector2i.UP) == "#"
	if ew:
		n.rotation.y = PI / 2.0
	var w := 0.5
	var hgt := DOOR_H * (1.15 if gate else 1.0)
	# the frame: two stone posts, no higher than the gate -- nothing over the
	# doorway, so once it's open it's just the open hall (a lintel over it read
	# as a tunnel you walked under)
	var stone := mat("slab")
	box(n, Vector3(-w - 0.08, 0, -0.14), Vector3(-w + 0.04, hgt, 0.14), stone)
	box(n, Vector3(w - 0.04, 0, -0.14), Vector3(w + 0.08, hgt, 0.14), stone)
	# the leaf, on a hinge at its left edge
	var pivot := Node3D.new()
	pivot.position = Vector3(-w + 0.04, 0, 0)
	n.add_child(pivot)
	box(pivot, Vector3(0, 0.02, -0.06), Vector3(2 * w - 0.08, hgt, 0.06), mat("door_" + color), Vector2(1, 1))
	# the lock plate and a ring
	var metal := mat("metal_" + color)
	box(pivot, Vector3(2 * w - 0.32, hgt * 0.42, 0.06), Vector3(2 * w - 0.16, hgt * 0.58, 0.1), metal)
	box(pivot, Vector3(2 * w - 0.32, hgt * 0.42, -0.1), Vector3(2 * w - 0.16, hgt * 0.58, -0.06), metal)
	if gate:
		# the master seal: a glowing rune on the door
		box(pivot, Vector3(w - 0.2, hgt * 0.62, 0.06), Vector3(w + 0.12, hgt * 0.86, 0.09), mat("", Color(0.75, 0.5, 1.0), 1.4))
	var d := {"node": n, "pivot": pivot, "t": 0.0, "sign": -1.0}
	if gate:
		d["gate"] = true
	_doors[c] = d
	return d


# --- Chests -------------------------------------------------------------------------

func _add_chest(c: Vector2i, purple: bool) -> void:
	var n := _cell_node(c)
	var h := world._hash(c.x, c.y, 19)
	n.rotation.y = deg_to_rad(float(h % 9 - 4) * 2.0)
	var wood := mat("chest_purple" if purple else "chest_iron")
	var metal := mat("metal_purple" if purple else "metal_gold")
	var s := 1.15 if purple else 1.0
	box(n, Vector3(-0.34, 0, -0.22) * s, Vector3(0.34, 0.34, 0.22) * s, wood)
	# the lid, hinged at the back
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 0.34, -0.22) * s
	n.add_child(pivot)
	box(pivot, Vector3(-0.35, 0, 0) * s, Vector3(0.35, 0.16, 0.45) * s, wood)
	box(pivot, Vector3(-0.06, -0.08, 0.44) * s, Vector3(0.06, 0.06, 0.48) * s, metal)
	# corner straps
	for x in [-0.35, 0.29]:
		box(n, Vector3(x, 0, -0.23) * s, Vector3(x + 0.06, 0.35, 0.23) * s, metal)
	_chests[c] = {"node": n, "pivot": pivot, "t": 0.0}


# --- Props: graves, pillars, candles, bushes, boulders -------------------------------

static var _rock_mesh: ArrayMesh


## A lumpy stone: an icosphere pushed in and out at random.
static func rock_mesh() -> ArrayMesh:
	if _rock_mesh != null:
		return _rock_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sphere := SphereMesh.new()
	sphere.radial_segments = 8
	sphere.rings = 5
	var arr := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var moved := PackedVector3Array()
	for v in verts:
		var k := 1.0 + (fmod(abs(sin(v.x * 12.9 + v.y * 78.2 + v.z * 37.7) * 43758.5), 1.0) - 0.5) * 0.35
		var p := v * k
		if p.y < -0.25:
			p.y = -0.25
		moved.append(p)
	for i in range(0, idx.size(), 3):
		var a := moved[idx[i]]
		var b := moved[idx[i + 1]]
		var c := moved[idx[i + 2]]
		var n := (b - a).cross(c - a).normalized()
		if n.dot(a + b + c) < 0.0:
			n = -n
		for p in [a, b, c]:
			st.set_normal(n)
			st.set_uv(Vector2(p.x + p.z, p.y) * 0.8)
			st.add_vertex(p)
	_rock_mesh = st.commit()
	return _rock_mesh


func _rock(parent: Node3D, at: Vector3, size: Vector3, rot: float, key := "rock_side") -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = rock_mesh()
	var m := mat(key).duplicate() as StandardMaterial3D
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = at + Vector3(0, size.y * 0.25, 0)
	mi.scale = size
	mi.rotation.y = rot
	parent.add_child(mi)


func _props() -> void:
	for y in world.height:
		for x in world.width:
			var c := Vector2i(x, y)
			var t := world.tile_at(c)
			var b := world.biome_at(c)
			if t == "g":
				if b == World.B_COURT:
					_pillar(c)
				else:
					_grave(c)
			elif t == "c":
				_candles(c)
			elif t == "b":
				var pr := world._prop_rock(c, b)
				if pr.x >= 0:
					_boulder(c, pr.x)
				elif b == World.B_MOUNTAIN:
					_boulder(c, World.ROCK_BOULDER)
				else:
					_bush(c)


func _grave(c: Vector2i) -> void:
	var n := _cell_node(c)
	var h := world._hash(c.x, c.y, 23)
	n.rotation = Vector3(deg_to_rad(float(h % 7 - 3) * 2.5), deg_to_rad(float((h / 7) % 9 - 4) * 3.0), 0)
	var m := mat("grave")
	box(n, Vector3(-0.26, 0, -0.06), Vector3(0.26, 0.62, 0.08), m)
	box(n, Vector3(-0.17, 0.62, -0.06), Vector3(0.17, 0.74, 0.08), m)
	box(n, Vector3(-0.32, 0, -0.1), Vector3(0.32, 0.06, 0.12), mat("slab"))


func _pillar(c: Vector2i) -> void:
	var n := _cell_node(c)
	var m := mat("pillar")
	box(n, Vector3(-0.3, 0, -0.3), Vector3(0.3, 0.14, 0.3), m)
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.17
	cyl.bottom_radius = 0.2
	cyl.height = 1.3
	cyl.radial_segments = 8
	cyl.rings = 1
	shaft.mesh = cyl
	shaft.material_override = m
	shaft.position = Vector3(0, 0.14 + 0.65, 0)
	n.add_child(shaft)
	var broken := world._hash(c.x, c.y, 29) % 3 == 0
	if not broken:
		box(n, Vector3(-0.28, 1.44, -0.28), Vector3(0.28, 1.58, 0.28), m)
	else:
		shaft.scale.y = 0.55
		shaft.position.y = 0.14 + 0.36


func _candles(c: Vector2i) -> void:
	var n := _cell_node(c)
	var wax := mat("", Color(0.92, 0.88, 0.76))
	var flame := mat("", Color(1.0, 0.75, 0.35), 2.5)
	var h := world._hash(c.x, c.y, 31)
	for k in 3:
		var a := float(k) * 2.1 + float(h % 10) * 0.3
		var p := Vector3(cos(a) * 0.17, 0, sin(a) * 0.12)
		var tall := 0.22 + float((h / (k + 1)) % 4) * 0.06
		box(n, p + Vector3(-0.035, 0, -0.035), p + Vector3(0.035, tall, 0.035), wax)
		box(n, p + Vector3(-0.022, tall, -0.022), p + Vector3(0.022, tall + 0.08, 0.022), flame)


func _bush(c: Vector2i) -> void:
	var n := _cell_node(c)
	var m := ShaderMaterial.new()
	m.shader = WorldMesh.CROWN_SHADER
	var swamp := world.biome_at(c) == World.B_SWAMP
	m.set_shader_parameter("leaves", load(W3D + ("swamp_leaves" if swamp else "leaves") + ".png"))
	var h := world._hash(c.x, c.y, 37)
	for k in 3:
		var mi := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radial_segments = 8
		sp.rings = 5
		var r := 0.24 + float((h / (k + 1)) % 3) * 0.04
		sp.radius = r
		sp.height = r * 1.7
		mi.mesh = sp
		mi.material_override = m
		var a := float(k) * 2.2 + float(h % 7)
		mi.position = Vector3(cos(a) * 0.16, r * 0.8, sin(a) * 0.12)
		n.add_child(mi)


func _boulder(c: Vector2i, kind: int) -> void:
	var n := _cell_node(c)
	var h := world._hash(c.x, c.y, 41)
	var rot := float(h % 360) * 0.0174
	match kind:
		World.ROCK_CLUSTER:
			for k in 3:
				var a := float(k) * 2.1 + rot
				_rock(n, Vector3(cos(a) * 0.2, 0, sin(a) * 0.15), Vector3(0.26, 0.24, 0.26) * (1.0 + (k % 2) * 0.3), rot + k)
		World.ROCK_SPIRE:
			_rock(n, Vector3.ZERO, Vector3(0.3, 0.95, 0.3), rot)
		World.ROCK_BIG:
			_rock(n, Vector3.ZERO, Vector3(0.48, 0.5, 0.44), rot)
		_:
			_rock(n, Vector3.ZERO, Vector3(0.38, 0.36, 0.34), rot)


## The Waking Chamber's stone bier.
func _bier(c: Vector2i) -> void:
	var n := _cell_node(c)
	var m := mat("slab")
	box(n, Vector3(-0.62, 0, -0.34), Vector3(0.62, 0.36, 0.34), m, Vector2(2, 1))
	box(n, Vector3(-0.7, 0.36, -0.4), Vector3(0.7, 0.46, 0.4), m, Vector2(2, 1))
