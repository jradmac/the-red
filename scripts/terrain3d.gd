class_name Terrain3D
extends Node2D
## The world's walls, cliffs and high ground as real 3D blocks.
##
## A 3D camera renders them so they line up pixel for pixel with the 2D
## world: a tile of ground is 16 px deep and a tile of height is 16 px tall,
## exactly like the hand-drawn view. The difference is the depth: block tops
## lean out from the middle of the screen as the camera moves (the further
## from the middle, the more you see of a wall's side), faces are shaded by
## which way they look, and high ground really rises -- whatever stands on it
## is lifted with it (World.cell_to_position).
##
## The picture is drawn into the 2D world twice:
##   this node     -- everything, just above the ground (under the creatures)
##   `over`        -- only block TOPS, and only the part north of the tile's
##                    own row: drawn over the creatures, so whoever walks
##                    behind a wall is hidden by it (as the 2D view did).
## The 2D lighting / darkness still goes over all of it, so the mood is the same.

const CHUNK := 24
const LIFT := 0.75            ## one level of high ground, in tiles
const TOP_H := 1.0            ## a wall's top, in tiles (it shows over its own tile)
const PARALLAX := 0.05        ## how far tops lean out: per tile of height, per tile from the middle
const DEPTH := 0.035          ## walls further up the screen show taller fronts (per tile from the middle)
const THETA := PI / 4.0
const BORDER := 16            ## blocks drawn past the map's edge, so it never ends in a void

const HEIGHTS_TEX: Texture2D = preload("res://assets/heights.png")
const ENV_TEX: Texture2D = preload("res://assets/env.png")
## The walls' stone: tops, fronts and sides from one material (tools/make_wall_blocks.py).
const BLOCK_TEX: Texture2D = preload("res://assets/wall_blocks.png")
## Moss, ivy, snow, crystals... laid over the walls and cliffs (tools/make_wall_details.py).
const WALL_DETAIL_TEX: Texture2D = preload("res://assets/wall_details.png")
const CLIFF_DETAIL_TEX: Texture2D = preload("res://assets/cliff_details.png")
const SHADER := preload("res://shaders/terrain3d.gdshader")

## Which landscapes have 3D walls (the woods are still drawn as trees in 2D).
const SOLID_BIOMES := [World.B_CRYPT, World.B_COURT, World.B_MOUNTAIN]

## Face brightness by the way it looks (the art has its own shading too).
const SHADE_TOP := 1.0
const SHADE_SOUTH := 0.92
const SHADE_WEST := 0.78
const SHADE_EAST := 0.6

## How often a face gets a detail, by landscape (more of them in clusters).
const DETAIL_CHANCE := {
	World.B_CRYPT: 0.65, World.B_FOREST: 0.4, World.B_COURT: 0.45,
	World.B_MOUNTAIN: 0.4, World.B_RIVER: 0.35, World.B_SWAMP: 0.5,
}
const DETAIL_LIFT := 0.01     ## how far a detail sits in front of its face (no flicker)

static var enabled := _load_enabled()   ## the "3D WORLD" setting (bag > settings)

const SETTINGS_PATH := "user://display.cfg"


static func _load_enabled() -> bool:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return true
	return bool(cf.get_value("display", "world_3d", true))


static func set_enabled(on: bool) -> void:
	enabled = on
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)
	cf.set_value("display", "world_3d", on)
	cf.save(SETTINGS_PATH)

var world: World
var over: Node2D              ## the tops layer (added to the world by main)
var _vp: SubViewport
var _vp_over: SubViewport
var _cam: Camera3D
var _cam_over: Camera3D
var _root: Node3D
var _mats := {}               ## texture -> [base material, over material]
var _center := Vector2.ZERO   ## the world pixel at the middle of the screen (snapped)
var _size := Vector2i(360, 240)


func setup(w: World) -> void:
	world = w
	_vp = _make_viewport()
	_vp.own_world_3d = true
	_vp_over = _make_viewport()
	add_child(_vp)
	add_child(_vp_over)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.background_color = Color(0, 0, 0, 0)
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	_vp.add_child(env)
	_root = Node3D.new()
	_root.scale = Vector3(1.0, 1.0 / cos(THETA), 1.0 / sin(THETA))
	_vp.add_child(_root)
	_cam = _make_camera(1)
	_vp.add_child(_cam)
	_cam_over = _make_camera(2)
	_vp_over.add_child(_cam_over)
	_vp_over.world_3d = _vp.find_world_3d()
	_cam_over.make_current()
	_cam.make_current()
	over = Node2D.new()
	over.z_index = 3
	over.draw.connect(_draw_over)
	_build()


func _make_viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = _size
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	return vp


func _make_camera(mask: int) -> Camera3D:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = float(_size.y) / World.TILE
	cam.near = 1.0
	cam.far = 400.0
	cam.cull_mask = mask
	cam.current = true
	return cam


# --- Every frame -----------------------------------------------------------------

func _process(_delta: float) -> void:
	if world == null:
		return
	var mode := SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	if _vp.render_target_update_mode != mode:
		_vp.render_target_update_mode = mode
		_vp_over.render_target_update_mode = mode
	if not visible:
		return
	var view := get_viewport().get_visible_rect().size
	var want := Vector2i(int(view.x) + 2, int(view.y) + 2)
	if want != _size:
		_size = want
		_vp.size = _size
		_vp_over.size = _size
		_cam.size = float(_size.y) / World.TILE
		_cam_over.size = _cam.size
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	_center = (inv * (view / 2.0)).round()
	# the camera looks north and down at THETA; the ground point under the
	# middle of the screen is (center / TILE) in tile units
	var cx := _center.x / World.TILE
	var cz := _center.y / World.TILE
	var target := Vector3(cx, 0.0, cz / sin(THETA))
	var fwd := Vector3(0.0, -sin(THETA), -cos(THETA))
	for cam in [_cam, _cam_over]:
		cam.look_at_from_position(target - fwd * 150.0, target, Vector3(0.0, cos(THETA), -sin(THETA)))
	for k in _mats:
		for m in _mats[k]:
			(m as ShaderMaterial).set_shader_parameter("cam_x", cx)
			(m as ShaderMaterial).set_shader_parameter("cam_z", cz)
	queue_redraw()
	over.queue_redraw()


func _draw() -> void:
	draw_texture(_vp.get_texture(), _center - Vector2(_size) / 2.0)


func _draw_over() -> void:
	over.draw_texture(_vp_over.get_texture(), _center - Vector2(_size) / 2.0)


# --- Building the blocks ------------------------------------------------------------

## Arrays for one texture in one chunk.
class Part:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var cols := PackedColorArray()
	var normals := PackedVector3Array()
	var tex_size := Vector2.ONE
	var biome := 0.0

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv_rect: Rect2, shade: float, line: float, n: Vector3) -> void:
		# a b c d: top-left, top-right, bottom-right, bottom-left (as the texture reads)
		var u0 := uv_rect.position / tex_size
		var u1 := uv_rect.end / tex_size
		var corner_uv := [Vector2(u0.x, u0.y), Vector2(u1.x, u0.y), Vector2(u1.x, u1.y), Vector2(u0.x, u1.y)]
		var pts := [a, b, c, d]
		for i in [0, 1, 2, 0, 2, 3]:
			verts.append(pts[i])
			uvs.append(corner_uv[i])
			uv2s.append(Vector2(line, 0.0))
			cols.append(Color(shade, biome / 8.0, 0.0, line))
			normals.append(n)


var _parts := {}   # "tex:over" -> Part, for the chunk being built
var _line := 0.0
var _cur_biome := 0


func _part(tex: Texture2D, top: bool) -> Part:
	var key := "%d:%d" % [tex.get_rid().get_id(), 1 if top else 0]
	if not _parts.has(key):
		var p := Part.new()
		p.tex_size = tex.get_size()
		_parts[key] = [p, tex, top]
	var part: Part = _parts[key][0]
	part.biome = _cur_biome
	return part


func _build() -> void:
	var t0 := Time.get_ticks_msec()
	for cy in range(-BORDER, world.height + BORDER, CHUNK):
		for cx in range(-BORDER, world.width + BORDER, CHUNK):
			_parts.clear()
			for y in range(cy, mini(cy + CHUNK, world.height + BORDER)):
				for x in range(cx, mini(cx + CHUNK, world.width + BORDER)):
					_cell(Vector2i(x, y))
			_commit()
	print("Terrain3D built in ", Time.get_ticks_msec() - t0, " ms, ", _root.get_child_count(), " meshes")


func _material(tex: Texture2D, over_pass: bool) -> ShaderMaterial:
	if not _mats.has(tex):
		var pair := []
		for o in [false, true]:
			var m := ShaderMaterial.new()
			m.shader = SHADER
			m.set_shader_parameter("tex", tex)
			m.set_shader_parameter("parallax", PARALLAX)
			# (high ground keeps its height: whatever stands on it is lifted by a fixed amount)
			var flat := tex == HEIGHTS_TEX or tex == ENV_TEX or tex == CLIFF_DETAIL_TEX
			m.set_shader_parameter("depth", 0.0 if flat else DEPTH)
			m.set_shader_parameter("over_pass", o)
			pair.append(m)
		_mats[tex] = pair
	return _mats[tex][1 if over_pass else 0]


func _commit() -> void:
	for key in _parts:
		var entry: Array = _parts[key]
		var p: Part = entry[0]
		if p.verts.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = p.verts
		arrays[Mesh.ARRAY_TEX_UV] = p.uvs
		arrays[Mesh.ARRAY_TEX_UV2] = p.uv2s
		arrays[Mesh.ARRAY_COLOR] = p.cols
		arrays[Mesh.ARRAY_NORMAL] = p.normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _material(entry[1], false)
		mi.layers = 1
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(mi)
		if entry[2]:
			# the tops again, for the layer over the creatures
			var mo := MeshInstance3D.new()
			mo.mesh = mesh
			mo.material_override = _material(entry[1], true)
			mo.layers = 2
			mo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_root.add_child(mo)


## How high the solid thing on this tile is (0 = nothing 3D here).
func block_height(c: Vector2i) -> float:
	if world.cliffs.has(c):
		return float(world.cliffs[c]) * LIFT
	if world.tile_at(c) != "#" or world.village_solid.has(c):
		return 0.0
	if not SOLID_BIOMES.has(_biome(c)):
		return 0.0
	return TOP_H


## The height of the ground you'd stand on here.
func ground_height(c: Vector2i) -> float:
	if world.ramps.has(c):
		return (float(world.height_at(c)) + 0.5) * LIFT
	return float(world.height_at(c)) * LIFT


func _biome(c: Vector2i) -> int:
	return world.biome_at(Vector2i(clampi(c.x, 0, world.width - 1), clampi(c.y, 0, world.height - 1)))


func _surface(c: Vector2i) -> float:
	var b := block_height(c)
	return b if b > 0.0 else ground_height(c)


func _wall(c: Vector2i) -> bool:
	return block_height(c) > 0.0 and not world.cliffs.has(c)


func _cell(c: Vector2i) -> void:
	_cur_biome = _biome(c)
	if world.ramps.has(c):
		_ramp(c)
		return
	if world.cliffs.has(c):
		_cliff_cell(c)
		return
	# Walls are laid out the way the map reads (and the way HGSS maps are):
	# each wall tile's TOP shows over its own tile and the FRONT fills the
	# bottom row. So the 3D box that carries the top of tile (x, y-1) stands
	# on tile (x, y), and the front stands at the wall's south edge: one block,
	# TOP_H tall, its top, front and sides cut from the same stone
	# (wall_blocks.png) so they meet in a rounded edge.
	var b := _biome(c)
	var x0 := float(c.x)
	var x1 := x0 + 1.0
	var z0 := float(c.y)
	var z1 := z0 + 1.0
	_line = 0.0
	if not _wall(c):
		return
	var up := c + Vector2i.UP
	var down := c + Vector2i.DOWN
	var front := not _wall(down) and _surface(down) < TOP_H
	if _has_top(up):
		# a full top (tile `up`'s), and the block's sides
		_top_quarters(up, b, TOP_H, Rect2(x0, z0, 1.0, 1.0))
		var tv := _detail_variant(up, b, 61, 0.5)
		if tv >= 0:
			var trow := 64 if b == World.B_MOUNTAIN else 48
			var tcol := (4 if b == World.B_COURT else 0) + tv % 4
			var y := TOP_H + DETAIL_LIFT
			_part(WALL_DETAIL_TEX, true).quad(Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1),
				Rect2(tcol * 16, trow, 16, 16), SHADE_TOP, _line, Vector3.UP)
		_block_sides(c, up, b, z0, z1, front)
	elif front:
		# a wall only one tile deep: a strip of top along the front's upper edge
		# (where the old 2D art showed the wall's cap)
		_top_quarters(c, b, TOP_H, Rect2(x0, z1 - 0.5, 1.0, 0.5))
		_block_sides(c, c, b, z1 - 0.5, z1, true)
	if front:
		var fp := _part(BLOCK_TEX, true)
		var hsh := world._hash(c.x, c.y, 9)
		var ends := (1 if not _wall(c + Vector2i.LEFT) else 0) + (2 if not _wall(c + Vector2i.RIGHT) else 0)
		var src := Rect2(((hsh % 2) * 4 + ends) * 16, 24 + _block_row(b) * 16, 16, 16)
		_face(fp, Vector3(x0, TOP_H, z1), Vector3(x1, TOP_H, z1), _surface(down), src, SHADE_SOUTH, Vector3.BACK, TOP_H)
		var fv := _detail_variant(c, b, 62, 1.0)
		if fv >= 0:
			var zd := z1 + DETAIL_LIFT
			_face(_part(WALL_DETAIL_TEX, true), Vector3(x0, TOP_H, zd), Vector3(x1, TOP_H, zd), _surface(down),
				Rect2(fv * 16, _wall_detail_row(b) * 16, 16, 16), SHADE_SOUTH, Vector3.BACK, TOP_H)


## Does wall tile `t` show a top? (It needs a wall south of it to stand on --
## or, one tile deep, it gets a strip along its front instead.)
func _has_top(t: Vector2i) -> bool:
	return _wall(t) and _wall(t + Vector2i.DOWN)


## The east / west faces of the block on tile c (carrying the top of `t`),
## from z_a to z_b, where no block continues beside it.
func _block_sides(c: Vector2i, t: Vector2i, b: int, z_a: float, z_b: float, south_end: bool) -> void:
	var x0 := float(c.x)
	var x1 := x0 + 1.0
	var sp := _part(BLOCK_TEX, true)
	var v := world._hash(c.x, c.y, 19) % 2
	var src := Rect2((v * 2 + (1 if south_end else 0)) * 16, 72 + _block_row(b) * 16, 16, 16)
	var flipped := Rect2(src.position.x + 16, src.position.y, -16, 16)   # seen from the east, south is on the left
	var strip := t == c
	if not (_beside_top(t + Vector2i.RIGHT, strip)):
		_face(sp, Vector3(x1, TOP_H, z_b), Vector3(x1, TOP_H, z_a), 0.0, flipped, SHADE_EAST, Vector3.RIGHT, TOP_H)
	if not (_beside_top(t + Vector2i.LEFT, strip)):
		_face(sp, Vector3(x0, TOP_H, z_a), Vector3(x0, TOP_H, z_b), 0.0, src, SHADE_WEST, Vector3.LEFT, TOP_H)


## Is there a block of the same kind next door (so no side face between)?
func _beside_top(n: Vector2i, strip: bool) -> bool:
	if strip:
		return _wall(n) and not _wall(n + Vector2i.DOWN)
	return _has_top(n)


func _block_row(b: int) -> int:
	match b:
		World.B_COURT: return 1
		World.B_MOUNTAIN: return 2
	return 0


## A slope (or stairs) up onto high ground: one tilted quad, low at the foot.
func _ramp(c: Vector2i) -> void:
	var lo := float(world.height_at(c)) * LIFT
	var hi := lo + LIFT
	var x0 := float(c.x)
	var x1 := x0 + 1.0
	var z0 := float(c.y)
	var z1 := z0 + 1.0
	var dir: String = world.ramps[c]
	var col: int = {"s": 9, "w": 10, "e": 11}.get(dir, 9)
	var src := Rect2(col * 16, _style(_biome(c)) * 16, 16, 16)
	_line = 0.0
	var p := _part(HEIGHTS_TEX, false)
	match dir:
		"w":   # high to the east
			p.quad(Vector3(x0, lo, z0), Vector3(x1, hi, z0), Vector3(x1, hi, z1), Vector3(x0, lo, z1), src, SHADE_TOP, 0.0, Vector3.UP)
		"e":   # high to the west
			p.quad(Vector3(x0, hi, z0), Vector3(x1, lo, z0), Vector3(x1, lo, z1), Vector3(x0, hi, z1), src, SHADE_TOP, 0.0, Vector3.UP)
		_:     # high to the north
			p.quad(Vector3(x0, hi, z0), Vector3(x1, hi, z0), Vector3(x1, lo, z1), Vector3(x0, lo, z1), src, SHADE_TOP, 0.0, Vector3.UP)
			# the slope's sides, down to the ground beside it
			var side := Rect2(0, _style(_biome(c)) * 16, 16, 16)
			for dx in [0, 1]:
				var n := c + Vector2i(-1 if dx == 0 else 1, 0)
				if _surface(n) < hi - 0.01:
					var xs := x0 if dx == 0 else x1
					p.quad(Vector3(xs, hi, z0), Vector3(xs, lo, z1), Vector3(xs, lo, z1), Vector3(xs, lo, z0), side,
						SHADE_WEST if dx == 0 else SHADE_EAST, 0.0, Vector3.LEFT)


func _style(b: int) -> int:
	match b:
		World.B_SWAMP: return 1
		World.B_MOUNTAIN: return 2
		World.B_COURT: return 3
		World.B_CRYPT: return 4
	return 0


## High ground: the ring of cliff tiles round a hill is a block as high as the
## hill (it really rises), and whatever stands on the hill is lifted to match.
func _cliff_cell(c: Vector2i) -> void:
	var h := block_height(c)
	var b := _biome(c)
	var x0 := float(c.x)
	var x1 := x0 + 1.0
	var z0 := float(c.y)
	var z1 := z0 + 1.0
	# don't let the over-layer clip the head of whoever stands just south of it, up there
	_line = float(world.cliffs[c]) / 4.0
	var p := _part(ENV_TEX, true)
	p.quad(Vector3(x0, h, z0), Vector3(x1, h, z0), Vector3(x1, h, z1), Vector3(x0, h, z1), _cliff_top_src(b, c), SHADE_TOP, _line, Vector3.UP)
	var face := _face_src(c, b, world._hash(c.x, c.y, 9))
	var fp := _part(HEIGHTS_TEX, true)
	var e := DETAIL_LIFT
	var s := _surface(c + Vector2i.DOWN)
	if s < h:
		_face(fp, Vector3(x0, h, z1), Vector3(x1, h, z1), s, face, SHADE_SOUTH, Vector3.BACK, h)
		_cliff_detail(c, b, 71, Vector3(x0, h, z1 + e), Vector3(x1, h, z1 + e), s, SHADE_SOUTH, Vector3.BACK, h)
	s = _surface(c + Vector2i.RIGHT)
	if s < h:
		_face(fp, Vector3(x1, h, z1), Vector3(x1, h, z0), s, face, SHADE_EAST, Vector3.RIGHT, h)
		_cliff_detail(c, b, 72, Vector3(x1 + e, h, z1), Vector3(x1 + e, h, z0), s, SHADE_EAST, Vector3.RIGHT, h)
	s = _surface(c + Vector2i.LEFT)
	if s < h:
		_face(fp, Vector3(x0, h, z0), Vector3(x0, h, z1), s, face, SHADE_WEST, Vector3.LEFT, h)
		_cliff_detail(c, b, 73, Vector3(x0 - e, h, z0), Vector3(x0 - e, h, z1), s, SHADE_WEST, Vector3.LEFT, h)


## Now and then a detail on a cliff face (moss, roots, snow...), per landscape.
func _cliff_detail(c: Vector2i, b: int, salt: int, a: Vector3, d: Vector3, bottom: float, shade: float, n: Vector3, h: float) -> void:
	var v := _detail_variant(c, b, salt, 0.9)
	if v >= 0:
		_face(_part(CLIFF_DETAIL_TEX, true), a, d, bottom, Rect2(v * 16, _style(b) * 16, 16, 16), shade, n, h)


## Which detail (0-7) this face gets, or -1 for none. Details gather in
## patches: a 4x4-tile neighbourhood is damp / overgrown / frosty or not.
func _detail_variant(c: Vector2i, b: int, salt: int, scale: float) -> int:
	var patch := float(world._hash(c.x >> 2, c.y >> 2, salt + 100) % 100) / 100.0
	var chance: float = DETAIL_CHANCE.get(b, 0.4) * scale * (0.35 + 1.3 * patch)
	if float(world._hash(c.x, c.y, salt) % 1000) / 1000.0 >= chance:
		return -1
	return world._hash(c.x, c.y, salt + 1) % 8


func _wall_detail_row(b: int) -> int:
	match b:
		World.B_COURT: return 1
		World.B_MOUNTAIN: return 2
	return 0


## A vertical face from the top edge a-b (at height h) down to height `bottom`.
## The texture's bottom stays at the foot; a short face shows its lower part.
func _face(p: Part, a: Vector3, b: Vector3, bottom: float, src: Rect2, shade: float, n: Vector3, h: float) -> void:
	var frac := clampf((h - bottom) / h, 0.0, 1.0)
	var s := src
	s.position.y += src.size.y * (1.0 - frac)
	s.size.y *= frac
	var c := Vector3(b.x, bottom, b.z)
	var d := Vector3(a.x, bottom, a.z)
	p.quad(a, b, c, d, s, shade, _line, n)


## A cliff face's art (heights.png): one row per landscape style.
func _face_src(_c: Vector2i, b: int, h: int) -> Rect2:
	return Rect2((h % 2) * 16, _style(b) * 16, 16, 16)


func _cliff_top_src(b: int, c: Vector2i) -> Rect2:
	# the same ground as the hill it rims
	var h := world._hash(c.x, c.y, 4)
	var row := World.ROW_FOREST
	var col := 2 + h % 2
	match b:
		World.B_COURT:
			row = World.ROW_COURT
			col = h % 2
		World.B_MOUNTAIN:
			row = World.ROW_MTN
			col = h % 2
		World.B_SWAMP:
			row = World.ROW_GROUND
			col = 6 + h % 2
		World.B_CRYPT:
			row = World.ROW_FLOOR
			col = h % 8
	return Rect2(col * 16, row * 16, 16, 16)


## A wall top from four 8x8 quarters (rounded far corners, a lit edge where
## it rolls over onto the front or a side): the top of tile `c`, laid at
## height `h` on the footprint `at` (x, z, width, depth).
func _top_quarters(c: Vector2i, b: int, h: float, at: Rect2) -> void:
	var row := _block_row(b)
	var p := _part(BLOCK_TEX, true)
	var variant := world._hash(c.x, c.y, 51) % 2
	var strip := not _has_top(c)
	for q in 4:
		var vs := -1 if q < 2 else 1
		var hs := -1 if q % 2 == 0 else 1
		var kind := 0
		if strip:
			# one tile deep: open to the north and south, sides by the neighbours
			var h_open := not _beside_top(c + Vector2i(hs, 0), true)
			kind = 3 if h_open else 1
		else:
			var v_same := _has_top(c + Vector2i(0, vs))
			var h_same := _has_top(c + Vector2i(hs, 0))
			var d_same := _has_top(c + Vector2i(hs, vs))
			if not v_same and not h_same:
				kind = 3
			elif not v_same:
				kind = 1
			elif not h_same:
				kind = 2
			elif not d_same:
				kind = 4
		var src := Rect2((variant * 20 + q * 5 + kind) * 8, row * 8, 8, 8)
		var qw := at.size.x * 0.5
		var qd := at.size.y * 0.5
		var qx := at.position.x + (q % 2) * qw
		var qz := at.position.y + (q / 2) * qd
		p.quad(Vector3(qx, h, qz), Vector3(qx + qw, h, qz), Vector3(qx + qw, h, qz + qd), Vector3(qx, h, qz + qd),
			src, SHADE_TOP, _line, Vector3.UP)


## Rebuild everything (after walls change).
func rebuild() -> void:
	for ch in _root.get_children():
		ch.queue_free()
	_build()
