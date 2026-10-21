class_name TallGrass
extends Node3D
## Tall grass you wade through (the 3D view).
##
## Where it grows: every tall-grass tile ("w") the labyrinth already has, plus
## patches over the open ground of the outdoor lands -- thick in the forest and
## by the river, meadow clumps in the courtyards, reeds and sedge in the swamp,
## thin dry grass up the mountain. The patches are only looks: the tiles keep
## what they are, so nothing else (doors, keys, chests, traps) changes.
##
## How it's drawn: little camera-facing clumps of pixel blades, a few rows to a
## tile, which
##   - sway in the wind, with gusts rolling across the field in waves (the
##     tips catch the light as a wave passes);
##   - part around whoever walks through, shiver when they run, and stay bent
##     for a moment along the path behind them;
## and, as you wade in, the blades in front of you hide your legs for real:
## each clump is hidden and hides as an upright cut-out standing at its roots,
## the same rule the characters follow (sprite3d_depth.gdshader).

const SHADER: Shader = preload("res://shaders/tall_grass.gdshader")
const TW := 16                 ## one clump in the texture (pixels)
const TH := 12
const CLUMP := 1.0             ## its width in the world (tiles): 1 px = 1/16 tile
const CHUNK := 16
const PUSHERS := 8
## per land: how much of its open ground is grown over (noise threshold;
## higher = less) -- the crypt only has its garden rooms' own tall grass
const GROW := {World.B_FOREST: 0.22, World.B_RIVER: 0.26, World.B_COURT: 0.3, World.B_SWAMP: 0.26, World.B_MOUNTAIN: 0.38}
## per land (the texture's rows: tools/make_tall_grass.py has the colours)
const PAL := [
	["1f3a2a", "2f5a3a", "4a7d4c", "79a868"],   # crypt gardens: damp, mossy
	["1d3d1f", "2e6030", "4c8a3c", "8cc65a"],   # forest
	["34501f", "557a2c", "7fa23a", "bcd26a"],   # courtyard meadow
	["4a4428", "6f6838", "948a4c", "b8ab6c"],   # mountain: dry and straw-pale
	["1b4a33", "2c6e44", "4c9a56", "92d07a"],   # river: lush
	["2a3a1e", "465a28", "6a7a34", "a4a85a"],   # swamp: olive sedge
]

static var tex: Texture2D
var view: View3D
var world: World
var cells := {}                ## cell -> land id, every tile with tall grass on it
var _mat: ShaderMaterial
var _noise: FastNoiseLite      ## where the patches lie (their edges follow it, not the tiles)
var _last_cell := {}           ## hero -> the cell it was in
var _trail: Array = []         ## [x, z, seconds left]: grass still bent where someone just went


func build(v: View3D) -> void:
	view = v
	world = v.world
	_make_texture()
	_find_cells()
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("tex", tex)
	_mat.set_shader_parameter("atlas", Vector2(2.0, PAL.size()))
	var mesh := _clump_mesh()
	var by := {}
	for c in cells:
		var k := Vector2i(c.x / CHUNK, c.y / CHUNK)
		if not by.has(k):
			by[k] = []
		by[k].append(c)
	var n := 0
	for k in by:
		var xs: Array = []
		for c in by[k]:
			_clumps(c, xs)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i][0])
			mm.set_instance_custom_data(i, xs[i][1])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		n += xs.size()
	print("TallGrass: ", cells.size(), " tiles, ", n, " clumps")


## Which land's grass is at `cell` (-1: none).
func land_at(cell: Vector2i) -> int:
	return cells.get(cell, -1)


func _find_cells() -> void:
	var noise := FastNoiseLite.new()
	_noise = noise
	noise.seed = world.seed_value * 7 + 13
	noise.frequency = 0.14
	noise.fractal_octaves = 2
	var near_start := Rect2i(world.start_cell - Vector2i(3, 3), Vector2i(7, 7))
	for y in world.height:
		for x in world.width:
			var c := Vector2i(x, y)
			var t := world.tile_at(c)
			var b := world.biome_at(c)
			var land := world.rare_at(c)
			if land in [World.R_SNOW, World.R_VOLCANO, World.R_GOLD, World.R_BEACH]:
				continue   # (nothing tall grows on snow, ash, gold or sand)
			if t == "w":
				cells[c] = b
				continue
			if not GROW.has(b) or not (t == "." or t == ","):
				continue
			if world.ramps.has(c) or world.doors.has(c) or world.blockers.has(c) \
					or near_start.has_point(c) or world.near_village(c, 1):
				continue
			if noise.get_noise_2d(x, y) > (-0.05 if land == World.R_JUNGLE else float(GROW[b])):
				cells[c] = b


## The clumps on one tile: three rows of two or three, facing the camera
## (turned a little each), smaller where the patch ends.
func _clumps(c: Vector2i, out: Array) -> void:
	var b: int = cells[c]
	var h := _hash(c.x, c.y)
	var rows := [0.1, 0.43, 0.76]
	for r in rows.size():
		var per := 2
		for i in per:
			var hh := _hash(c.x * 31 + r * 7 + i, c.y * 17 - r)
			var fx := (float(i) + 0.5) / float(per) + (float(hh % 100) / 100.0 - 0.5) * 0.3
			var fz: float = rows[r] + (float((hh >> 8) % 100) / 100.0 - 0.5) * 0.1
			var x := float(c.x) + clampf(fx, 0.05, 0.95)
			var z := float(c.y) + fz
			var s := 0.85 + float((hh >> 4) % 30) / 100.0
			# the patch's edge wanders with the noise, not along the tiles: past
			# it, nothing; near it, shorter
			if world.tile_at(c) != "w":
				var over := _noise.get_noise_2d(x - 0.5, z - 0.5) - float(GROW.get(b, 0.0))
				if over < 0.0:
					continue
				s *= lerpf(0.55, 1.0, clampf(over / 0.08, 0.0, 1.0))
			var yaw := (float((hh >> 12) % 100) / 100.0 - 0.5) * 0.3
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3(1.0, s, 1.0))
			var pos := Vector3(x, view.ground_at(x, z), z)
			out.append([Transform3D(basis, pos), Color(float(b), float((hh >> 16) % 2), float(hh % 628) / 100.0, 0.0)])


static func _clump_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := CLUMP / 2.0
	var ht := CLUMP * float(TH) / float(TW)
	# leaning back to face the camera square, as the characters' sprites do: one
	# depth all the way up (so only what's truly in front hides them) and drawn
	# pixel for pixel, like them
	var up := Vector3(0.0, cos(View3D.PITCH), -sin(View3D.PITCH)) * ht
	var q := [Vector3(-w, 0, 0) + up, Vector3(w, 0, 0) + up, Vector3(w, 0, 0), Vector3(-w, 0, 0)]
	var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(uv[i])
		st.add_vertex(q[i])
	return st.commit()


static func _hash(x: int, y: int) -> int:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return h ^ (h >> 16)


## The clumps: two for each land, side by side, one row per land -- smooth
## tapered leaves, drawn by tools/make_tall_grass.py (palettes there).
static func _make_texture() -> void:
	if tex == null:
		tex = load("res://assets/w3d/tall_grass.png") as Texture2D


## Each frame: who's pushing the grass aside, and the rustle as a hero wades in.
func update() -> void:
	if _mat == null:
		return
	var dt := get_process_delta_time()
	var push: Array[Vector4] = []
	for h in Hero.all:
		var pl: Player = h.player
		if not is_instance_valid(pl) or not pl.visible:
			continue
		var p := view.to3d(pl.position)
		push.append(Vector4(p.x, p.z, 1.0 if pl.moving else 0.0, 1.0))
		var was: Vector2i = _last_cell.get(h, Vector2i(-999, -999))
		if pl.cell != was:
			_last_cell[h] = pl.cell
			if cells.has(was):
				_trail.append([float(was.x) + 0.5, float(was.y) + 0.5, 0.9])
			# (main.gd rustles the old tall-grass tiles itself)
			if cells.has(pl.cell) and world.tile_at(pl.cell) != "w":
				Sfx.play("rustle", -7.0, 0.12)
	var en = view.main.get("enemies")
	if en != null:
		var ts := view.targets()
		var best: Array = []
		for e in en.list:
			if not is_instance_valid(e) or not e.visible or e.kind == "ghost":
				continue
			var c := Vector2i(int(e.position.x + 8.0) / World.TILE, int(e.position.y + 8.0) / World.TILE)
			if not cells.has(c):
				continue
			var p := view.to3d(e.position)
			var d := INF
			for t in ts:
				d = minf(d, Vector2(p.x - t.x, p.z - t.z).length())
			best.append([d, p])
		best.sort_custom(func(a, b): return a[0] < b[0])
		for i in mini(best.size(), 3):
			push.append(Vector4(best[i][1].x, best[i][1].z, 1.0, 1.0))
	for i in range(_trail.size() - 1, -1, -1):
		_trail[i][2] -= dt
		if _trail[i][2] <= 0.0:
			_trail.remove_at(i)
	for tr in _trail:
		if push.size() < PUSHERS:
			push.append(Vector4(tr[0], tr[1], 0.0, clampf(tr[2] / 0.9, 0.0, 1.0) * 0.7))
	while push.size() < PUSHERS:
		push.append(Vector4(-999.0, -999.0, 0.0, 0.0))
	push.resize(PUSHERS)
	_mat.set_shader_parameter("pushers", push)
