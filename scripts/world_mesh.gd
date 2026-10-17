class_name WorldMesh
extends RefCounted
## Builds the labyrinth's 3D models from the tile map (for View3D).
##
##   ground   the 2D view's own ground art (floors, grass, moss, water, bridges,
##            decals...) baked into textures, laid on the ground -- raised
##            where the land is raised, sunk a little where there's water
##   walls    real walls: a body of coursed stone, a coping of cap stones along
##            the top; between walls, packed earth and rubble (crypt, courtyard)
##            or a jagged rock mass (mountains)
##   cliffs   the rings round high ground: rock or earth faces, the hill's own
##            ground on top; slopes are tilted ramps
##   trees    in the woods every wall tile is a tree: a round leafy crown, and a
##            trunk where you can see one (instanced, so a forest is cheap)

var ground_meshes: Array[ArrayMesh] = []   ## the ground (for things drawn on it: View3D)

const CHUNK := 32               ## tiles per ground texture (512 px)
const BORDER := 14              ## built past the map's edge, so it never ends in a void
const LEVEL := 0.85             ## one level of high ground
const WATER_Y := -0.22          ## water lies a little below the ground
const CAP := 0.2                ## the coping: how tall
const OV := 0.07                ## ...and how far it sticks out
const WALL_H := {World.B_CRYPT: 1.05, World.B_COURT: 1.0, World.B_MOUNTAIN: 1.3}
const TREE_BIOMES := [World.B_FOREST, World.B_RIVER, World.B_SWAMP]
const WALL_BIOMES := [World.B_CRYPT, World.B_COURT, World.B_MOUNTAIN]

const W3D := "res://assets/w3d/"
const HEIGHTS_TEX: Texture2D = preload("res://assets/heights.png")
const CROWN_SHADER := preload("res://shaders/crown.gdshader")

var view: View3D
var world: World
var _root: Node3D
var _mats := {}
var _geo := {}        ## material key -> [verts, normals, uvs, colors]
var _ground_tex := {} ## chunk origin -> texture


func build(root: Node3D) -> void:
	world = view.world
	_root = root
	await _bake_ground()
	var t0 := Time.get_ticks_msec()
	_measure_rock()
	for cy in range(-BORDER, world.height + BORDER, CHUNK):
		for cx in range(-BORDER, world.width + BORDER, CHUNK):
			_build_chunk(Vector2i(cx, cy))
	print("WorldMesh built in ", Time.get_ticks_msec() - t0, " ms")


# --- Baking the ground -----------------------------------------------------------------

func _bake_ground() -> void:
	var t0 := Time.get_ticks_msec()
	var vp := SubViewport.new()
	vp.size = Vector2i(CHUNK * World.TILE, CHUNK * World.TILE)
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.add_child(vp)
	var painter := _Painter.new()
	painter.world = world
	painter.villages = view.main.get("villages")
	painter.wm = self
	vp.add_child(painter)
	for cy in range(-BORDER, world.height + BORDER, CHUNK):
		for cx in range(-BORDER, world.width + BORDER, CHUNK):
			painter.rect = Rect2i(cx, cy, CHUNK, CHUNK)
			painter.position = -Vector2(cx, cy) * World.TILE
			painter.queue_redraw()
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			_ground_tex[Vector2i(cx, cy)] = ImageTexture.create_from_image(img)
	vp.queue_free()
	print("WorldMesh ground baked in ", Time.get_ticks_msec() - t0, " ms")


class _Painter extends Node2D:
	var world: World
	var wm: WorldMesh
	var villages: Node
	var rect := Rect2i()

	func _draw() -> void:
		world.bake_ground(self, rect)
		if villages != null and villages.has_method("bake_ground"):
			villages.bake_ground(self, rect)
		_contact_shadows()

	## Where the floor meets a wall it darkens (light can't get into the
	## corner): a soft band along the foot of every wall, so walls stand up
	## out of the floor instead of blending into it.
	func _contact_shadows() -> void:
		var T := float(World.TILE)
		var steps := [[0.0, 2.0, 0.42], [2.0, 2.0, 0.26], [4.0, 3.0, 0.12]]
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var c := Vector2i(x, y)
				if wm.is_wall(c) or wm.is_tree(c) or world.tile_at(c) == "~":
					continue
				var o := Vector2(x, y) * T
				for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					if not wm.is_wall(c + d):
						continue
					for st in steps:
						var a: float = st[0]
						var w: float = st[1]
						var col := Color(0.03, 0.02, 0.06, st[2])
						match d:
							Vector2i.UP: draw_rect(Rect2(o + Vector2(0, a), Vector2(T, w)), col)
							Vector2i.DOWN: draw_rect(Rect2(o + Vector2(0, T - a - w), Vector2(T, w)), col)
							Vector2i.LEFT: draw_rect(Rect2(o + Vector2(a, 0), Vector2(w, T)), col)
							_: draw_rect(Rect2(o + Vector2(T - a - w, 0), Vector2(w, T)), col)


# --- Materials -------------------------------------------------------------------------

func _mat(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not key.begins_with("ground:") and key != "ramps":
		# walls, rock and leaves: crisp bands of light, like the DS games
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	if key.begins_with("ground:"):
		m.albedo_texture = _ground_tex[_chunk_of_key(key)]
		m.texture_repeat = false
	elif key == "ramps":
		m.albedo_texture = HEIGHTS_TEX
		m.texture_repeat = false
	else:
		m.albedo_texture = load(W3D + key + ".png")
		m.texture_repeat = true
	if key.ends_with("_hang"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.texture_repeat = false
	_mats[key] = m
	return m


func _chunk_of_key(key: String) -> Vector2i:
	var parts := key.substr(7).split(",")
	return Vector2i(int(parts[0]), int(parts[1]))


func _arrays(key: String) -> Array:
	if not _geo.has(key):
		_geo[key] = [PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedColorArray()]
	return _geo[key]


## A quad a-b-c-d (texture reads a top-left, b top-right, c bottom-right, d bottom-left).
func _quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, n: Vector3,
		ca := Color.WHITE, cb := Color.WHITE, cc := Color.WHITE, cd := Color.WHITE) -> void:
	var arr := _arrays(key)
	var vs := [a, b, c, a, c, d]
	var us := [ua, ub, uc, ua, uc, ud]
	var cs := [ca, cb, cc, ca, cc, cd]
	for i in 6:
		arr[0].append(vs[i])
		arr[1].append(n)
		arr[2].append(us[i])
		arr[3].append(cs[i])


func _flush(chunk: Vector2i) -> void:
	var node := Node3D.new()
	node.name = "chunk_%d_%d" % [chunk.x, chunk.y]
	for key in _geo:
		var arr: Array = _geo[key]
		if arr[0].is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = arr[0]
		arrays[Mesh.ARRAY_NORMAL] = arr[1]
		arrays[Mesh.ARRAY_TEX_UV] = arr[2]
		arrays[Mesh.ARRAY_COLOR] = arr[3]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _mat(key)
		node.add_child(mi)
		if key.begins_with("ground:") or key == "ramps":
			ground_meshes.append(mesh)
	_geo.clear()
	_root.add_child(node)


# --- The map, tile by tile -----------------------------------------------------------

func _biome(c: Vector2i) -> int:
	return world.biome_at(Vector2i(clampi(c.x, 0, world.width - 1), clampi(c.y, 0, world.height - 1)))


func _solid(c: Vector2i) -> bool:
	return world.tile_at(c) == "#"


func is_tree(c: Vector2i) -> bool:
	return _solid(c) and not world.cliffs.has(c) and not world.village_solid.has(c) and TREE_BIOMES.has(_biome(c))


func is_wall(c: Vector2i) -> bool:
	return _solid(c) and not world.cliffs.has(c) and not world.village_solid.has(c) and WALL_BIOMES.has(_biome(c))


## The top of whatever is on a tile (ground, water, a hill, a cliff ring...).
func surface(c: Vector2i) -> float:
	if is_wall(c):
		return WALL_H[_biome(c)]
	if is_tree(c):
		return 0.0   # (trees don't hide what's beside them)
	if world.cliffs.has(c):
		return float(world.cliffs[c]) * LEVEL
	if world.tile_at(c) == "~":
		return WATER_Y
	if world.ramps.has(c):
		return float(world.height_at(c)) * LEVEL
	return float(world.height_at(c)) * LEVEL


func _build_chunk(chunk: Vector2i) -> void:
	var gkey := "ground:%d,%d" % [chunk.x, chunk.y]
	var trees: Array = []
	for y in range(chunk.y, chunk.y + CHUNK):
		for x in range(chunk.x, chunk.x + CHUNK):
			var c := Vector2i(x, y)
			var uv0 := Vector2(x - chunk.x, y - chunk.y) / CHUNK
			var uv1 := uv0 + Vector2.ONE / CHUNK
			if is_wall(c):
				_wall(c)
			elif is_tree(c):
				_ground_quad(gkey, c, 0.0, uv0, uv1)
				trees.append(c)
			elif world.cliffs.has(c):
				_cliff(c, gkey, uv0, uv1)
			elif world.ramps.has(c):
				_ramp(c)
			elif world.tile_at(c) == "~":
				_ground_quad(gkey, c, WATER_Y, uv0, uv1)
				_banks(c)
			else:
				_ground_quad(gkey, c, surface(c), uv0, uv1)
	_flush(chunk)
	if not trees.is_empty():
		_trees(chunk, trees)
	if not _ledges.is_empty():
		_ledge_props()
		_ledges.clear()
	if not _small.is_empty():
		_small_props()
		_small.clear()


func _ground_quad(key: String, c: Vector2i, h: float, uv0: Vector2, uv1: Vector2) -> void:
	var x0 := float(c.x)
	var z0 := float(c.y)
	_quad(key, Vector3(x0, h, z0), Vector3(x0 + 1, h, z0), Vector3(x0 + 1, h, z0 + 1), Vector3(x0, h, z0 + 1),
		uv0, Vector2(uv1.x, uv0.y), uv1, Vector2(uv0.x, uv1.y), Vector3.UP)


const DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]


## The edge of tile c facing d, as two points (left to right as you face it from outside).
func _edge(c: Vector2i, d: Vector2i) -> Array:
	var x0 := float(c.x)
	var z0 := float(c.y)
	match d:
		Vector2i.DOWN: return [Vector2(x0, z0 + 1), Vector2(x0 + 1, z0 + 1)]
		Vector2i.UP: return [Vector2(x0 + 1, z0), Vector2(x0, z0)]
		Vector2i.RIGHT: return [Vector2(x0 + 1, z0 + 1), Vector2(x0 + 1, z0)]
	return [Vector2(x0, z0), Vector2(x0, z0 + 1)]


## A vertical face along edge e (two points), from height lo to hi, textured
## with `key` (tex_w x tex_h px, 16 px per tile), shaded darker at the foot.
func _face(key: String, e: Array, lo: float, hi: float, n: Vector3, tex: Vector2, v_top := 0.0, foot := 0.6) -> void:
	var a: Vector2 = e[0]
	var b: Vector2 = e[1]
	var ua: float = (a.x + a.y) * 16.0 / tex.x
	var ub: float = ua + 16.0 / tex.x
	var v0 := v_top
	var v1 := v_top + (hi - lo) * 16.0 / tex.y
	var top_c := Color.WHITE
	var foot_c := Color(foot, foot, foot)
	_quad(key, Vector3(a.x, hi, a.y), Vector3(b.x, hi, b.y), Vector3(b.x, lo, b.y), Vector3(a.x, lo, a.y),
		Vector2(ua, v0), Vector2(ub, v0), Vector2(ub, v1), Vector2(ua, v1), n, top_c, top_c, foot_c, foot_c)


func _n(d: Vector2i) -> Vector3:
	return Vector3(d.x, 0, d.y)


# --- Walls -----------------------------------------------------------------------------

func _wall(c: Vector2i) -> void:
	var b := _biome(c)
	var h: float = WALL_H[b]
	if b == World.B_MOUNTAIN:
		_rock(c, h)
		return
	var prefix := "crypt" if b == World.B_CRYPT else "court"
	# a wall tile with open ground next to it (8 ways) wears the coping; the
	# ones further in are the packed ground between walls
	var border := false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and not is_wall(c + Vector2i(dx, dy)):
				border = true
	var x0 := float(c.x)
	var z0 := float(c.y)
	var open := {}
	for d in DIRS:
		open[d] = not is_wall(c + d)
	for d in DIRS:
		if not open[d]:
			continue
		var low := minf(surface(c + d), 0.0)
		_face(prefix + "_side", _edge(c, d), low, h - CAP, _n(d), Vector2(32, 30), 0.0, 0.42)
	if not border:
		_ruin_step(c, prefix, h)
		return
	# the coping: a slab a little wider than the wall where it faces open ground
	var l := x0 - (OV if open[Vector2i.LEFT] else 0.0)
	var r := x0 + 1 + (OV if open[Vector2i.RIGHT] else 0.0)
	var t := z0 - (OV if open[Vector2i.UP] else 0.0)
	var bt := z0 + 1 + (OV if open[Vector2i.DOWN] else 0.0)
	_quad(prefix + "_cap_top", Vector3(l, h, t), Vector3(r, h, t), Vector3(r, h, bt), Vector3(l, h, bt),
		Vector2(l * 0.5, t), Vector2(r * 0.5, t), Vector2(r * 0.5, bt), Vector2(l * 0.5, bt), Vector3.UP)
	for d in DIRS:
		if not open[d]:
			continue
		var e: Array
		match d:
			Vector2i.DOWN: e = [Vector2(l, bt), Vector2(r, bt)]
			Vector2i.UP: e = [Vector2(r, t), Vector2(l, t)]
			Vector2i.RIGHT: e = [Vector2(r, bt), Vector2(r, t)]
			_: e = [Vector2(l, t), Vector2(l, bt)]
		_face(prefix + "_cap_side", e, h - CAP, h, _n(d), Vector2(16, 4), 0.0, 0.8)
		# its underside, the shadowed lip over the wall face
		var e2 := _edge(c, d)
		_quad(prefix + "_cap_side", Vector3(e[0].x, h - CAP, e[0].y), Vector3(e[1].x, h - CAP, e[1].y),
			Vector3(e2[1].x, h - CAP, e2[1].y), Vector3(e2[0].x, h - CAP, e2[0].y),
			Vector2(0, 0.9), Vector2(1, 0.9), Vector2(1, 1), Vector2(0, 1), Vector3.DOWN,
			Color(0.4, 0.4, 0.45), Color(0.4, 0.4, 0.45), Color(0.4, 0.4, 0.45), Color(0.4, 0.4, 0.45))


## The inside of a thick crypt or courtyard wall: not a flat roof but a ruin
## built up in steps -- each step a course of the same masonry, its top
## overgrown -- rising toward the middle of the mass.
func _ruin_step(c: Vector2i, prefix: String, h: float) -> void:
	var st: Array = TERRACE[_biome(c)]
	var x0 := float(c.x)
	var z0 := float(c.y)
	var t := _tier(c)
	var top := _step_h(c, h)
	var k := 0.78 + 0.08 * float(t)   # higher steps catch more light
	var cs := []
	for q in [Vector2i(c.x, c.y), Vector2i(c.x + 1, c.y), Vector2i(c.x + 1, c.y + 1), Vector2i(c.x, c.y + 1)]:
		cs.append(_corner_tone(q.x, q.y, t) * Color(k, k, k))
	var tkey := _top_key(c, t)
	_quad(tkey, Vector3(x0, top, z0), Vector3(x0 + 1, top, z0), Vector3(x0 + 1, top, z0 + 1), Vector3(x0, top, z0 + 1),
		Vector2(x0, z0) / 2.0, Vector2(x0 + 1, z0) / 2.0, Vector2(x0 + 1, z0 + 1) / 2.0, Vector2(x0, z0 + 1) / 2.0, Vector3.UP,
		cs[0], cs[1], cs[2], cs[3])
	_maybe_ledge_prop(c, top, t)
	_details(c, tkey, [top, top, top, top])
	for d in DIRS:
		var nb: Vector2i = c + d
		if not is_wall(nb):
			continue   # (an outer cell, with its coping, is always between)
		var below := _step_h(nb, h)
		if below >= top - 0.01:
			continue
		# the riser: a course of masonry, with a lit lip along its top
		_face(prefix + "_side", _edge(c, d), below, top - 0.06, _n(d), Vector2(32, 30), 0.0, 0.5)
		_face(prefix + "_cap_side", _edge(c, d), top - 0.06, top, _n(d), Vector2(16, 4), 0.0, 0.9)


## The light on a terrace's ground at a tile corner: bright along the rim
## where it drops away, dark at the foot of the step above (the rock keeps
## the light off), and patchy over all (drier, greener) so a big ledge never
## looks like one flat sheet.
func _corner_tone(x: int, z: int, t: int) -> Color:
	var higher := false
	var lower := false
	for o in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		var c: Vector2i = Vector2i(x, z) + o
		if not is_wall(c):
			lower = true
		else:
			var tc := _tier(c)
			if tc > t:
				higher = true
			elif tc < t:
				lower = true
	var k := 1.0
	if higher:
		k = 0.6
	elif lower:
		k = 1.14
	var n := _wander(x * 0.55 + 31.0, z * 0.55) * 0.5 + 0.5
	var patch := Color(0.9, 1.02, 0.86).lerp(Color(1.06, 0.96, 0.86), n)
	return Color(patch.r * k, patch.g * k, patch.b * k)


# --- The life of the terraces ----------------------------------------------------------
## What a terrace's ground is made of, in patches that wander across it:
## [texture, share] per landscape -- the first is the commonest.
const TOPS := {
	World.B_MOUNTAIN: ["rock_top", "rock_slab", "scree", "alpine_meadow"],
	World.B_CRYPT: ["crypt_mass", "crypt_paving", "crypt_rubble"],
	World.B_COURT: ["court_mass", "court_paving", "court_meadow"],
}
## The small things on a terrace, per landscape and per kind of ground:
## [kind, how many per tile on average]. Kinds: a texture name (an upright
## tuft, fern or flowers) or "pebbles".
const SMALL := {
	"rock_top": [["tuft_dry", 1.2], ["pebbles", 0.5], ["tuft_flowers", 0.2]],
	"rock_slab": [["pebbles", 0.6], ["tuft_dry", 0.5]],
	"scree": [["pebbles", 1.4], ["tuft_dry", 0.2]],
	"alpine_meadow": [["tuft_flowers", 1.0], ["tuft_green", 1.0], ["pebbles", 0.2]],
	"crypt_mass": [["fern", 0.9], ["tuft_green", 0.5], ["pebbles", 0.3]],
	"crypt_paving": [["tuft_green", 0.5], ["fern", 0.3], ["pebbles", 0.4]],
	"crypt_rubble": [["pebbles", 1.3], ["fern", 0.3]],
	"court_mass": [["tuft_court", 0.9], ["tuft_green", 0.6], ["pebbles", 0.2]],
	"court_paving": [["tuft_court", 0.5], ["pebbles", 0.4]],
	"court_meadow": [["tuft_flowers", 1.2], ["tuft_court", 1.0]],
}
## What hangs over a terrace's edge, per landscape
const HANG := {World.B_MOUNTAIN: "grass_hang", World.B_CRYPT: "ivy_hang", World.B_COURT: "vine_hang"}
var _small: Array = []         ## this chunk: [position, kind, hash]


func _top_key(c: Vector2i, t: int) -> String:
	var b := _biome(c)
	var opts: Array = TOPS.get(b, ["rock_top"])
	var n := _wander(c.x * 0.45 + 17.0, c.y * 0.45 - 5.0)
	var n2 := _wander(c.x * 0.3 - 40.0, c.y * 0.3 + 9.0)
	if b == World.B_MOUNTAIN:
		if t >= 3 and n2 > 0.1:
			return "alpine_meadow" if n > 0.0 else "rock_slab"
		if n > 0.38:
			return "rock_slab"
		if n < -0.42:
			return "scree"
		if n2 > 0.55:
			return "alpine_meadow"
		return "rock_top"
	if n > 0.3:
		return opts[1]
	if n < -0.38:
		return opts[2]
	return opts[0]


## Scatter the small things on a terrace tile, and hang growth over its edges.
## `hs`: the heights of its corners (NW, NE, SE, SW).
func _details(c: Vector2i, tkey: String, hs: Array) -> void:
	var h := world._hash(c.x, c.y, 151)
	var list: Array = SMALL.get(tkey, [])
	var k := 0
	for kc in list:
		# how many: the average, rounded up or down by chance
		var avg: float = kc[1]
		var n := int(avg) + (1 if float((h >> k) % 100) / 100.0 < avg - floorf(avg) else 0)
		for i in n:
			var hh := world._hash(c.x * 7 + i, c.y * 13 + k, 157)
			var fx := 0.12 + float(hh % 76) / 100.0
			var fz := 0.12 + float((hh / 76) % 76) / 100.0
			var y := lerpf(lerpf(hs[0], hs[1], fx), lerpf(hs[3], hs[2], fx), fz)
			_small.append([Vector3(c.x + fx, y, c.y + fz), kc[0], hh])
		k += 3
	# growth hanging down over every edge that drops away
	var b := _biome(c)
	var key: String = HANG.get(b, "")
	if key == "":
		return
	var t := _tier(c)
	var corner := {Vector2i.DOWN: [3, 2], Vector2i.UP: [1, 0], Vector2i.RIGHT: [2, 1], Vector2i.LEFT: [0, 3]}
	for d in DIRS:
		var nb: Vector2i = c + d
		var drop := not is_wall(nb) or (_tier(nb) < t and TERRACE.has(_biome(nb)))
		if not drop or world._hash(c.x + d.x * 3, c.y + d.y * 5, 163) % 100 > 55:
			continue
		var e := _edge(c, d)
		var ha: float = hs[corner[d][0]]
		var hb: float = hs[corner[d][1]]
		var ln := 0.35 + float(world._hash(c.x, c.y + d.x, 167) % 40) / 100.0
		var o := Vector3(d.x, 0, d.y) * 0.025
		var a := Vector3(e[0].x, ha, e[0].y) + o
		var bb := Vector3(e[1].x, hb, e[1].y) + o
		_quad(key, a + Vector3(0, 0.04, 0), bb + Vector3(0, 0.04, 0), bb + Vector3(0, -ln, 0), a + Vector3(0, -ln, 0),
			Vector2(0, 0), Vector2(1, 0), Vector2(1, ln / 1.5 * 1.0), Vector2(0, ln / 1.5 * 1.0), _n(d))


static var _tuft_mesh: ArrayMesh
static var _pebble_mesh: ArrayMesh


## An upright tuft: two quads crossed (seen right from any side).
static func _make_tuft() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for a in [0.4, 0.4 + PI / 2.0]:
		var dx := Vector3(cos(a), 0, sin(a)) * 0.5
		var q := [-dx + Vector3(0, 1, 0), dx + Vector3(0, 1, 0), dx, -dx]
		var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[i])
			st.add_vertex(q[i])
	return st.commit()


func _small_props() -> void:
	if _tuft_mesh == null:
		_tuft_mesh = _make_tuft()
	var by := {}
	for it in _small:
		if not by.has(it[1]):
			by[it[1]] = []
		by[it[1]].append(it)
	for kind in by:
		var list: Array = by[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var mat: StandardMaterial3D
		if kind == "pebbles":
			mm.mesh = Objects3D.rock_mesh()
			mat = _mat("rock_side").duplicate() as StandardMaterial3D
			mat.vertex_color_use_as_albedo = false
		else:
			mm.mesh = _tuft_mesh
			mat = StandardMaterial3D.new()
			mat.albedo_texture = load(W3D + kind + ".png")
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = 0.5
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			mat.roughness = 1.0
		mm.instance_count = list.size()
		for i in list.size():
			var p: Vector3 = list[i][0]
			var h: int = list[i][2]
			var rot := Basis(Vector3.UP, float(h % 360) * 0.0174)
			var xf: Transform3D
			if kind == "pebbles":
				var r := 0.06 + float(h % 5) * 0.025
				xf = Transform3D(rot.scaled(Vector3(r, r * 0.6, r)), p)
			else:
				var r := 0.36 + float(h % 4) * 0.06
				xf = Transform3D(rot.scaled(Vector3(r, r, r)), p - Vector3(0, 0.02, 0))
			mm.set_instance_transform(i, xf)
			var tone := 0.85 + float((h / 9) % 4) * 0.07
			mm.set_instance_color(i, Color(tone, tone, tone))
		mat.vertex_color_use_as_albedo = false
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(mi)


## Maybe something on this ledge (only well inside it, away from its edges).
func _maybe_ledge_prop(c: Vector2i, top: float, t: int) -> void:
	if t < 1:
		return
	for d in DIRS:
		if _tier(c + d) != t or not is_wall(c + d):
			return
	var b := _biome(c)
	var h := world._hash(c.x, c.y, 131)
	var roll := float(h % 1000) / 1000.0
	for kc in LEDGE_PROPS.get(b, []):
		if roll < kc[1]:
			var j := Vector3(float(h % 7 - 3) * 0.06, 0.0, float((h / 7) % 7 - 3) * 0.06)
			_ledges.append([Vector3(c.x + 0.5, top, c.y + 0.5) + j, kc[0], h, b])
			return
		roll -= kc[1]


## How high the top of a thick wall's cell is: the coping on its outer
## cells, then a step up for each terrace inward.
func _step_h(c: Vector2i, h: float) -> float:
	var border := false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and not is_wall(c + Vector2i(dx, dy)):
				border = true
	if border or not TERRACE.has(_biome(c)) or _biome(c) == World.B_MOUNTAIN:
		return h
	var st: Array = TERRACE[_biome(c)]
	return h - 0.06 + float(_tier(c)) * float(st[0])


## Mountains: not a flat-topped block but a hill of rock that steps up in
## terraces -- ledge after ledge, each with its own cliff face -- the further
## a spot is from open ground, rising to a peak in the middle of a big mass.
## The terrace edges wander (a smooth noise added to the distance), so the
## ledges curve like real strata rather than following the corridors.
## Each landscape builds its high ground its own way: [step height, tiles
## per terrace, most terraces]. Mountains: tall rough rock ledges up to a
## peak. Crypts: a ruin -- low stepped courses of old masonry, ivy on every
## step. Courtyards: broad sandstone steps, grass in the joints.
const TERRACE := {
	World.B_MOUNTAIN: [0.95, 2.1, 5],
	World.B_CRYPT: [0.85, 2.2, 3],
	World.B_COURT: [0.75, 2.4, 3],
}
const TIER_STEP := 0.95
## What grows or lies about on the ledges, per landscape: [kind, chance]
const LEDGE_PROPS := {
	World.B_MOUNTAIN: [["pine", 0.13], ["boulder", 0.1]],
	World.B_CRYPT: [["bush", 0.16], ["stump", 0.07], ["boulder", 0.04]],
	World.B_COURT: [["round", 0.08], ["stump", 0.08], ["bush", 0.07]],
}
var _ledges: Array = []        ## this chunk: [position, kind, hash, biome]
const MAX_TIER := 5
var _rock_dist := {}           ## wall cell -> distance (tiles) to open ground


func _measure_rock() -> void:
	# distance from open ground, spreading inward over the rock (8 ways)
	var q: Array[Vector2i] = []
	var lo := Vector2i(-BORDER, -BORDER)
	var hi := Vector2i(world.width + BORDER, world.height + BORDER)
	for y in range(lo.y, hi.y):
		for x in range(lo.x, hi.x):
			var c := Vector2i(x, y)
			if is_wall(c) and TERRACE.has(_biome(c)):
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if not is_wall(c + Vector2i(dx, dy)):
							if not _rock_dist.has(c):
								_rock_dist[c] = 1.0
								q.append(c)
	var h := 0
	while h < q.size():
		var c: Vector2i = q[h]
		h += 1
		var d: float = _rock_dist[c]
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := c + Vector2i(dx, dy)
				if n.x < lo.x or n.y < lo.y or n.x >= hi.x or n.y >= hi.y:
					continue
				if _rock_dist.has(n) or not is_wall(n) or not TERRACE.has(_biome(n)):
					continue
				_rock_dist[n] = d + (1.4 if dx != 0 and dy != 0 else 1.0)
				q.append(n)


## A smooth wander (-1..1) over the map, so terrace edges curve.
func _wander(x: float, z: float) -> float:
	var gx := floorf(x / 5.0)
	var gz := floorf(z / 5.0)
	var fx := x / 5.0 - gx
	var fz := z / 5.0 - gz
	var v := func(a: float, b: float) -> float: return float(world._hash(int(a), int(b), 97) % 1000) / 500.0 - 1.0
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var top := lerpf(v.call(gx, gz), v.call(gx + 1, gz), fx)
	var bot := lerpf(v.call(gx, gz + 1), v.call(gx + 1, gz + 1), fx)
	return lerpf(top, bot, fz)


func _tier(c: Vector2i) -> int:
	if not _rock_dist.has(c):
		return 0
	var st: Array = TERRACE.get(_biome(c), TERRACE[World.B_MOUNTAIN])
	var d: float = _rock_dist[c] + _wander(c.x + 0.5, c.y + 0.5) * 1.3
	if d < 1.6:
		return 0
	return clampi(int(floor((d - 1.0) / st[1])), 0, st[2])


## The height of a terrace's corner: its tier, a little rough at every corner.
func _rock_h(x: int, z: int, h: float, tier := 0) -> float:
	var n := float(world._hash(x, z, 83 + tier * 7) % 1000) / 1000.0
	# rough at every corner, and rolling gently across the ledge
	return h + tier * TIER_STEP + (n - 0.5) * (0.5 if tier == 0 else 0.22) + _wander(x * 1.7, z * 1.7) * 0.16


func _rock(c: Vector2i, h: float) -> void:
	var x0 := float(c.x)
	var z0 := float(c.y)
	var t := _tier(c)
	var hs := [_rock_h(c.x, c.y, h, t), _rock_h(c.x + 1, c.y, h, t), _rock_h(c.x + 1, c.y + 1, h, t), _rock_h(c.x, c.y + 1, h, t)]
	var pts := [Vector3(x0, hs[0], z0), Vector3(x0 + 1, hs[1], z0), Vector3(x0 + 1, hs[2], z0 + 1), Vector3(x0, hs[3], z0 + 1)]
	var n: Vector3 = (pts[1] - pts[0]).cross(pts[3] - pts[0]).normalized()
	if n.y < 0:
		n = -n
	# the ledge's own ground: brighter on high ledges (more sky), scrubby lower
	var lt := 0.8 + 0.06 * float(t)   # higher ledges catch more light
	var tones := []
	for q in [Vector2i(c.x, c.y), Vector2i(c.x + 1, c.y), Vector2i(c.x + 1, c.y + 1), Vector2i(c.x, c.y + 1)]:
		tones.append(_corner_tone(q.x, q.y, t) * Color(lt, lt, lt))
	var tkey := _top_key(c, t)
	_quad(tkey, pts[0], pts[1], pts[2], pts[3], Vector2(x0, z0) / 2.0, Vector2(x0 + 1, z0) / 2.0,
		Vector2(x0 + 1, z0 + 1) / 2.0, Vector2(x0, z0 + 1) / 2.0, n, tones[0], tones[1], tones[2], tones[3])
	_maybe_ledge_prop(c, (hs[0] + hs[1] + hs[2] + hs[3]) / 4.0, t)
	_details(c, tkey, hs)
	var corner := {Vector2i.DOWN: [3, 2], Vector2i.UP: [1, 0], Vector2i.RIGHT: [2, 1], Vector2i.LEFT: [0, 3]}
	var cpos := [Vector2i(c.x, c.y), Vector2i(c.x + 1, c.y), Vector2i(c.x + 1, c.y + 1), Vector2i(c.x, c.y + 1)]
	for d in DIRS:
		var nb: Vector2i = c + d
		var e := _edge(c, d)
		var ia: int = corner[d][0]
		var ib: int = corner[d][1]
		var ha: float = hs[ia]
		var hb: float = hs[ib]
		var la: float
		var lb: float
		if is_wall(nb):
			if _biome(nb) != World.B_MOUNTAIN:
				continue   # (the ruin next door builds its own side)
			# a terrace edge: the cliff down to the ledge below
			var tn := _tier(nb)
			if tn >= t:
				continue
			la = _rock_h(cpos[ia].x, cpos[ia].y, h, tn)
			lb = _rock_h(cpos[ib].x, cpos[ib].y, h, tn)
		else:
			la = minf(surface(nb), 0.0)
			lb = la
		var ua: float = (e[0].x + e[0].y) * 0.5
		var ub: float = ua + 0.5
		# strata run level across the face; darker toward its foot
		_quad("rock_side", Vector3(e[0].x, ha, e[0].y), Vector3(e[1].x, hb, e[1].y), Vector3(e[1].x, lb, e[1].y), Vector3(e[0].x, la, e[0].y),
			Vector2(ua, -ha * 0.5), Vector2(ub, -hb * 0.5), Vector2(ub, -lb * 0.5), Vector2(ua, -la * 0.5), _n(d),
			Color.WHITE, Color.WHITE, Color(0.55, 0.55, 0.55), Color(0.55, 0.55, 0.55))


# --- High ground --------------------------------------------------------------------

func _side_key(b: int) -> String:
	match b:
		World.B_SWAMP: return "swamp_side"
		World.B_MOUNTAIN: return "mtn_side"
		World.B_COURT: return "courtstep_side"
		World.B_CRYPT: return "cryptstep_side"
	return "earth_side"


func _cliff(c: Vector2i, gkey: String, uv0: Vector2, uv1: Vector2) -> void:
	var h := surface(c)
	_ground_quad(gkey, c, h, uv0, uv1)
	var key := _side_key(_biome(c))
	for d in DIRS:
		var s := surface(c + d)
		if is_wall(c + d) or s >= h - 0.01:
			continue
		_face(key, _edge(c, d), s, h, _n(d), Vector2(32, 16), 0.0, 0.6)


func _ramp(c: Vector2i) -> void:
	var lo := float(world.height_at(c)) * LEVEL
	var hi := lo + LEVEL
	var x0 := float(c.x)
	var z0 := float(c.y)
	var dir: String = world.ramps[c]
	var col: int = {"s": 9, "w": 10, "e": 11}.get(dir, 9)
	var style := 0
	match _biome(c):
		World.B_SWAMP: style = 1
		World.B_MOUNTAIN: style = 2
		World.B_COURT: style = 3
		World.B_CRYPT: style = 4
	var u0 := Vector2(col * 16, style * 16) / HEIGHTS_TEX.get_size()
	var u1 := u0 + Vector2(16, 16) / HEIGHTS_TEX.get_size()
	var hs := [hi, hi, lo, lo]   # NW NE SE SW
	match dir:
		"w": hs = [lo, hi, hi, lo]
		"e": hs = [hi, lo, lo, hi]
	var p := [Vector3(x0, hs[0], z0), Vector3(x0 + 1, hs[1], z0), Vector3(x0 + 1, hs[2], z0 + 1), Vector3(x0, hs[3], z0 + 1)]
	_quad("ramps", p[0], p[1], p[2], p[3], u0, Vector2(u1.x, u0.y), u1, Vector2(u0.x, u1.y), Vector3.UP)
	# its sides, down to lower ground beside it
	var key := _side_key(_biome(c))
	var corner := {Vector2i.DOWN: [3, 2], Vector2i.UP: [1, 0], Vector2i.RIGHT: [2, 1], Vector2i.LEFT: [0, 3]}
	for d in DIRS:
		var s := surface(c + d)
		var ia: int = corner[d][0]
		var ib: int = corner[d][1]
		if is_wall(c + d) or maxf(hs[ia], hs[ib]) <= s + 0.01:
			continue
		var e := _edge(c, d)
		var ua: float = (e[0].x + e[0].y) * 0.5
		_quad(key, Vector3(e[0].x, hs[ia], e[0].y), Vector3(e[1].x, hs[ib], e[1].y), Vector3(e[1].x, s, e[1].y), Vector3(e[0].x, s, e[0].y),
			Vector2(ua, 0), Vector2(ua + 0.5, 0), Vector2(ua + 0.5, 0.5), Vector2(ua, 0.5), _n(d))


## Water lies low: earth banks down to it from the ground around.
func _banks(c: Vector2i) -> void:
	var key := _side_key(_biome(c))
	for d in DIRS:
		var s := surface(c + d)
		if world.tile_at(c + d) == "~" or is_wall(c + d) or s <= WATER_Y + 0.01:
			continue
		_face(key, _edge(c + d, -d), WATER_Y, minf(s, 0.0), _n(-d), Vector2(32, 16), 0.5, 0.5)


# --- Trees ------------------------------------------------------------------------------

static var _crown_mesh: ArrayMesh
static var _pine_mesh: ArrayMesh
static var _trunk_mesh: ArrayMesh


func _trees(chunk: Vector2i, cells: Array) -> void:
	if _crown_mesh == null:
		_crown_mesh = _make_crown()
		_trunk_mesh = _make_trunk()
		_pine_mesh = _make_pine()
	# what grows here: round leafy trees, with pines among them in the
	# forest; the swamp's are dark and drooping
	var groups := {}   # [mesh kind, leaves texture, bark] -> list of [cell, hash]
	for c in cells:
		var h := world._hash(c.x, c.y, 41)
		var b := _biome(c)
		var key: String
		if b == World.B_SWAMP:
			key = "round|swamp_leaves|swamp_bark"
		elif b == World.B_FOREST and h % 10 < 3:
			key = "pine|needles|bark"
		else:
			key = "round|leaves|bark"
		if not groups.has(key):
			groups[key] = []
		groups[key].append([c, h])
	var trunks: Dictionary = {}   # bark -> list of transforms
	for key in groups:
		var parts: PackedStringArray = key.split("|")
		var list: Array = groups[key]
		var pine := parts[0] == "pine"
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _pine_mesh if pine else _crown_mesh
		mm.instance_count = list.size()
		for i in list.size():
			var c: Vector2i = list[i][0]
			var h: int = list[i][1]
			var r := (0.62 if pine else 0.66) + float(h % 5) * 0.04
			var jx := float(h % 7 - 3) * 0.04
			var jz := float((h / 7) % 5 - 2) * 0.04
			var base := Vector3(c.x + 0.5 + jx, 0.0, c.y + 0.5 + jz)
			# crowns at different heights, so the rows behind show over the front
			var trunk_h := (0.55 if pine else 0.75) + float((h / 35) % 4) * 0.12
			var basis := Basis(Vector3.UP, float(h % 360) * 0.0174).scaled(Vector3(r, r * (1.15 if pine else 0.95), r))
			mm.set_instance_transform(i, Transform3D(basis, base + Vector3(0, trunk_h, 0)))
			var tone := 0.88 + float((h / 3) % 7) * 0.04
			var hue := Color(tone, tone * (1.0 + float((h / 11) % 3) * 0.03), tone * 0.96)
			mm.set_instance_color(i, hue)
			# a trunk you can see wherever the tree isn't hidden behind another
			if not is_tree(c + Vector2i.DOWN) or h % 3 == 0:
				if not trunks.has(parts[2]):
					trunks[parts[2]] = []
				trunks[parts[2]].append(Transform3D(Basis().scaled(Vector3(1.0, trunk_h - 0.05, 1.0)), base))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var m := ShaderMaterial.new()
		m.shader = CROWN_SHADER
		m.set_shader_parameter("leaves", load(W3D + parts[1] + ".png"))
		m.set_shader_parameter("uv_scale", 0.9 if pine else 0.5)
		mi.material_override = m
		_root.add_child(mi)
	for bark in trunks:
		var ts: Array = trunks[bark]
		var tm := MultiMesh.new()
		tm.transform_format = MultiMesh.TRANSFORM_3D
		tm.mesh = _trunk_mesh
		tm.instance_count = ts.size()
		for i in ts.size():
			tm.set_instance_transform(i, ts[i])
		var ti := MultiMeshInstance3D.new()
		ti.multimesh = tm
		ti.material_override = _mat(bark)
		_root.add_child(ti)


## The trees, bushes, boulders and broken columns on the terraces.
func _ledge_props() -> void:
	if _crown_mesh == null:
		_crown_mesh = _make_crown()
		_trunk_mesh = _make_trunk()
		_pine_mesh = _make_pine()
	var by := {}
	for l in _ledges:
		if not by.has(l[1]):
			by[l[1]] = []
		by[l[1]].append(l)
	var trunks: Array = []
	for kind in by:
		var list: Array = by[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var mat: Material
		match kind:
			"pine", "round", "bush":
				mm.mesh = _pine_mesh if kind == "pine" else _crown_mesh
				var m := ShaderMaterial.new()
				m.shader = CROWN_SHADER
				var tex := "needles" if kind == "pine" else ("swamp_leaves" if kind == "bush" and _biome(Vector2i(int(list[0][0].x), int(list[0][0].z))) == World.B_CRYPT else "leaves")
				m.set_shader_parameter("leaves", load(W3D + tex + ".png"))
				m.set_shader_parameter("uv_scale", 0.9 if kind == "pine" else 0.6)
				mat = m
			"boulder":
				mm.mesh = Objects3D.rock_mesh()
				var m2 := _mat("rock_side").duplicate() as StandardMaterial3D
				m2.vertex_color_use_as_albedo = false
				mat = m2
			_:
				mm.mesh = Objects3D.box_mesh(Vector3(-0.2, 0, -0.2), Vector3(0.2, 1, 0.2), Vector2(1, 2))
				var m3 := _mat("pillar").duplicate() as StandardMaterial3D
				m3.vertex_color_use_as_albedo = false
				mat = m3
		mm.instance_count = list.size()
		for i in list.size():
			var p: Vector3 = list[i][0]
			var h: int = list[i][2]
			var rot := Basis(Vector3.UP, float(h % 360) * 0.0174)
			var xf: Transform3D
			match kind:
				"pine":
					var r := 0.42 + float(h % 4) * 0.05
					xf = Transform3D(rot.scaled(Vector3(r, r * 1.2, r)), p + Vector3(0, 0.35, 0))
					trunks.append(Transform3D(Basis().scaled(Vector3(0.7, 0.4, 0.7)), p))
				"round":
					var r := 0.48 + float(h % 4) * 0.04
					xf = Transform3D(rot.scaled(Vector3(r, r * 0.95, r)), p + Vector3(0, 0.55, 0))
					trunks.append(Transform3D(Basis().scaled(Vector3(0.7, 0.5, 0.7)), p))
				"bush":
					var r := 0.3 + float(h % 3) * 0.04
					xf = Transform3D(rot.scaled(Vector3(r, r * 0.8, r)), p + Vector3(0, r * 0.45, 0))
				"boulder":
					var r := 0.28 + float(h % 4) * 0.06
					xf = Transform3D(rot.scaled(Vector3(r, r * 0.8, r)), p + Vector3(0, r * 0.12, 0))
				_:
					# a broken column: some still tall, most snapped off low
					var hh := 0.35 + float(h % 5) * 0.18
					xf = Transform3D(rot.scaled(Vector3(1, hh, 1)), p)
			mm.set_instance_transform(i, xf)
			var tone := 0.9 + float((h / 5) % 5) * 0.05
			mm.set_instance_color(i, Color(tone, tone, tone))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat
		_root.add_child(mi)
	if not trunks.is_empty():
		var tm := MultiMesh.new()
		tm.transform_format = MultiMesh.TRANSFORM_3D
		tm.mesh = _trunk_mesh
		tm.instance_count = trunks.size()
		for i in trunks.size():
			tm.set_instance_transform(i, trunks[i])
		var ti := MultiMeshInstance3D.new()
		ti.multimesh = tm
		ti.material_override = _mat("bark")
		_root.add_child(ti)


static func _sphere_into(st: SurfaceTool, at: Vector3, r: Vector3, seg: int, rings: int, flat_below := -0.55) -> void:
	var pts := []
	for i in rings + 1:
		var row := []
		var th := PI * float(i) / rings
		for j in seg + 1:
			var ph := TAU * float(j) / seg
			var n := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			var p := n
			if p.y < flat_below:
				p.y = flat_below - (p.y - flat_below) * -0.3
			row.append([at + p * r, n])
		pts.append(row)
	for i in rings:
		for j in seg:
			var q := [pts[i][j], pts[i][j + 1], pts[i + 1][j + 1], pts[i + 1][j]]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(q[k][1])
				st.set_color(Color.WHITE)
				st.add_vertex(q[k][0])


## A round leafy crown: not one ball but a cluster of clumps -- a big one on
## top and smaller ones round it, lower down -- like a hand-drawn tree.
static func _make_crown() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_sphere_into(st, Vector3(0, 0.38, 0), Vector3(0.62, 0.56, 0.62), 9, 6)
	for k in 5:
		var a := TAU * float(k) / 5.0 + 0.4
		var rr := 0.44 + 0.06 * float(k % 2)
		_sphere_into(st, Vector3(cos(a) * 0.52, 0.0 + 0.08 * float(k % 3), sin(a) * 0.52), Vector3(rr, rr * 0.85, rr), 8, 5)
	return st.commit()


## A pine: three tiers of drooping boughs, narrowing to a point.
static func _make_pine() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SIDES := 9
	var tiers := [[-0.1, 0.95, 0.75], [0.45, 0.75, 0.62], [0.95, 0.5, 0.55]]   # base y, radius, height
	for t in tiers:
		var y0: float = t[0]
		var r: float = t[1]
		var hgt: float = t[2]
		var tip := Vector3(0, y0 + hgt, 0)
		for j in SIDES:
			var a0 := TAU * float(j) / SIDES
			var a1 := TAU * float(j + 1) / SIDES
			# the rim of each tier droops a little between its boughs
			var p0 := Vector3(cos(a0) * r, y0 - 0.06 * float(j % 2), sin(a0) * r)
			var p1 := Vector3(cos(a1) * r, y0 - 0.06 * float((j + 1) % 2), sin(a1) * r)
			var n := (p1 - p0).cross(tip - p0).normalized()
			if n.dot(p0) < 0.0:
				n = -n
			for p in [p0, p1, tip]:
				st.set_normal((n + Vector3(0, 0.3, 0)).normalized())
				st.set_color(Color.WHITE)
				st.add_vertex(p)
			# the underside, in shade
			for p in [p1, p0, Vector3(0, y0 + 0.1, 0)]:
				st.set_normal(Vector3.DOWN)
				st.set_color(Color(0.6, 0.6, 0.6))
				st.add_vertex(p)
	return st.commit()


static func _make_trunk() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SIDES := 6
	var r0 := 0.15
	var r1 := 0.09
	for j in SIDES:
		var a0 := TAU * float(j) / SIDES
		var a1 := TAU * float(j + 1) / SIDES
		var p := [Vector3(cos(a0) * r0, 0, sin(a0) * r0), Vector3(cos(a1) * r0, 0, sin(a1) * r0),
			Vector3(cos(a1) * r1, 1, sin(a1) * r1), Vector3(cos(a0) * r1, 1, sin(a0) * r1)]
		var uvs := [Vector2(j / 3.0, 1), Vector2((j + 1) / 3.0, 1), Vector2((j + 1) / 3.0, 0), Vector2(j / 3.0, 0)]
		var n := Vector3(cos((a0 + a1) / 2), 0, sin((a0 + a1) / 2))
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(uvs[k])
			st.set_color(Color(0.8, 0.8, 0.8) if k < 2 else Color.WHITE)
			st.add_vertex(p[k])
	return st.commit()
