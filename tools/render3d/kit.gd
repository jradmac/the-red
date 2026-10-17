extends RefCounted
## A tiny kit for modelling simple buildings and props in 3D and rendering
## them to pixel-art sprites that drop straight into the game's 2D sheets.
##
## The game draws the world in an "oblique" top-down view: a tile of ground
## is a 16x16 square on screen, and walls rise straight up the screen. Here a
## camera tilted back THETA renders the model, and the model is stretched
## (y / cos THETA, depth / sin THETA) so that, on screen, one tile of ground
## depth and one tile of wall height are both exactly 16 px. So everything is
## modelled in "screen tiles":  x right, y up, d (depth) away from the viewer,
## and a building whose footprint is W x D tiles fills a W*16 x D*16 sprite.

const THETA := deg_to_rad(52.0)
const SS := 4                        # supersampling
const LIGHT_DIR := Vector3(-0.55, -0.72, -0.42)   # from the upper left, a little in front

var root: Node3D        # the stretched model space
var _vp: SubViewport
var _tex_cache := {}


func _init(tree: SceneTree, w_tiles: float, d_tiles: float) -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(int(w_tiles * 16 * SS), int(d_tiles * 16 * SS))
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.6, 0.68)
	e.ambient_light_energy = 0.55
	env.environment = e
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.05
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.02
	sun.directional_shadow_max_distance = 60.0
	_vp.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, LIGHT_DIR.normalized(), Vector3.UP)
	var fill := DirectionalLight3D.new()   # a soft bounce from the front right
	fill.light_energy = 0.25
	fill.light_color = Color(0.75, 0.8, 1.0)
	_vp.add_child(fill)
	fill.look_at_from_position(Vector3.ZERO, Vector3(0.6, -0.3, -0.8).normalized(), Vector3.UP)
	root = Node3D.new()
	root.scale = Vector3(1.0, 1.0 / cos(THETA), 1.0 / sin(THETA))
	_vp.add_child(root)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = d_tiles
	cam.near = 0.1
	cam.far = 200.0
	_vp.add_child(cam)
	var target := Vector3(w_tiles / 2.0, 0.0, -(d_tiles / 2.0) / sin(THETA))
	var back := Vector3(0.0, sin(THETA), cos(THETA))
	cam.look_at_from_position(target + back * 60.0, target, Vector3.UP)


## Renders and returns the finished sprite (pixel-art: downsampled, hard
## alpha, a dark outline).
func render(tree: SceneTree, outline := Color("1c1020")) -> Image:
	for i in 4:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width() / SS
	var h := img.get_height() / SS
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var acc := Color(0, 0, 0, 0)
			var n := 0.0
			var cov := 0.0
			for sy in SS:
				for sx in SS:
					var c := img.get_pixel(x * SS + sx, y * SS + sy)
					cov += c.a
					if c.a > 0.01:
						acc += Color(c.r, c.g, c.b, 1.0)
						n += 1.0
			if cov / float(SS * SS) >= 0.45 and n > 0.0:
				var c2 := Color(acc.r / n, acc.g / n, acc.b / n, 1.0)
				# a little posterising, so it sits with the hand-made pixel art
				c2.r = roundf(c2.r * 31.0) / 31.0
				c2.g = roundf(c2.g * 31.0) / 31.0
				c2.b = roundf(c2.b * 31.0) / 31.0
				out.set_pixel(x, y, c2)
	# outline
	var edge := []
	for y in h:
		for x in w:
			if out.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and out.get_pixel(q.x, q.y).a > 0.0:
					edge.append(Vector2i(x, y))
					break
	# a selective outline: a deep shade of whatever it borders (not black), so
	# the sprite sits in the world instead of looking cut out and pasted on
	var shades := []
	for p in edge:
		var acc := Color(0, 0, 0, 0)
		var n := 0.0
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h:
				var c := out.get_pixel(q.x, q.y)
				if c.a > 0.0:
					acc += c
					n += 1.0
		var avg := Color(acc.r / n, acc.g / n, acc.b / n, 1.0)
		shades.append(avg.darkened(0.62).lerp(outline, 0.35))
	for i in edge.size():
		out.set_pixelv(edge[i], shades[i])
	_vp.queue_free()
	return out


# --- Shapes (all in screen tiles: x right, y up, d away) -----------------------------

func _to3(x: float, y: float, d: float) -> Vector3:
	return Vector3(x, y, -d)


## A box: x0..x0+w, y0..y0+h, d0..d0+dd.
func box(x0: float, y0: float, d0: float, w: float, h: float, dd: float, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, dd)
	m.mesh = bm
	m.material_override = mat
	m.position = _to3(x0 + w / 2.0, y0 + h / 2.0, d0 + dd / 2.0)
	root.add_child(m)
	return m


## A cylinder standing on (cx, y0, cd).
func cylinder(cx: float, y0: float, cd: float, r_bottom: float, r_top: float, h: float, mat: Material, sides := 16) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = r_bottom
	cm.top_radius = r_top
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 1
	m.mesh = cm
	m.material_override = mat
	m.position = _to3(cx, y0 + h / 2.0, cd)
	root.add_child(m)
	return m


func sphere(cx: float, cy: float, cd: float, r: float, mat: Material, squash := 1.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0 * squash
	sm.radial_segments = 12
	sm.rings = 8
	m.mesh = sm
	m.material_override = mat
	m.position = _to3(cx, cy, cd)
	root.add_child(m)
	return m


## A gable roof over x0..x1, front eave at d0 / back eave at d1 (both at
## height y_eave), ridge at height y_ridge halfway between. UVs run up the
## slopes so a shingle texture lines up in rows.
func gable(x0: float, x1: float, d0: float, d1: float, y_eave: float, y_ridge: float, mat: Material, gable_mat: Material = null) -> void:
	var dm := (d0 + d1) / 2.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var slope_len := sqrt(pow(dm - d0, 2) + pow(y_ridge - y_eave, 2))
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3, u_len: float, v_len: float) -> void:
		st.set_uv(Vector2(0, v_len)); st.add_vertex(a)
		st.set_uv(Vector2(u_len, v_len)); st.add_vertex(b)
		st.set_uv(Vector2(u_len, 0)); st.add_vertex(c)
		st.set_uv(Vector2(0, v_len)); st.add_vertex(a)
		st.set_uv(Vector2(u_len, 0)); st.add_vertex(c)
		st.set_uv(Vector2(0, 0)); st.add_vertex(d)
	# front slope, back slope
	quad.call(_to3(x0, y_eave, d0), _to3(x1, y_eave, d0), _to3(x1, y_ridge, dm), _to3(x0, y_ridge, dm), x1 - x0, slope_len)
	quad.call(_to3(x1, y_eave, d1), _to3(x0, y_eave, d1), _to3(x0, y_ridge, dm), _to3(x1, y_ridge, dm), x1 - x0, slope_len)
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat
	root.add_child(m)
	# the triangular gable ends
	if gable_mat != null:
		var g := SurfaceTool.new()
		g.begin(Mesh.PRIMITIVE_TRIANGLES)
		for x in [x0 + 0.06, x1 - 0.06]:
			var tri := [_to3(x, y_eave, d0 + 0.08), _to3(x, y_ridge - 0.08, dm), _to3(x, y_eave, d1 - 0.08)]
			if x > x0 + 0.5:
				tri = [tri[0], tri[2], tri[1]]
			for v in tri:
				g.set_uv(Vector2(v.x, v.y))
				g.add_vertex(v)
		g.generate_normals()
		var gm := MeshInstance3D.new()
		gm.mesh = g.commit()
		gm.material_override = gable_mat
		root.add_child(gm)


## A flat polygon (convex, points in screen tiles as Vector3(x, y, d)), facing
## away from `inside`. UVs are laid out in tiles along its first edge.
func poly(pts: Array, mat: Material, inside: Vector3) -> void:
	var p3: Array[Vector3] = []
	for q in pts:
		p3.append(_to3(q.x, q.y, q.z))
	var ins := _to3(inside.x, inside.y, inside.z)
	var n := (p3[1] - p3[0]).cross(p3[2] - p3[0])
	var ctr := Vector3.ZERO
	for q in p3:
		ctr += q
	ctr /= float(p3.size())
	if n.dot(ctr - ins) < 0.0:
		p3.reverse()
		n = -n
	var e1 := (p3[1] - p3[0]).normalized()
	var e2 := n.normalized().cross(e1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, p3.size() - 1):
		for q in [p3[0], p3[i], p3[i + 1]]:
			st.set_uv(Vector2((q - p3[0]).dot(e1), -(q - p3[0]).dot(e2)))
			st.add_vertex(q)
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat
	root.add_child(m)


## A hipped roof: slopes on all four sides, the ridge `inset` in from each end.
func hip(x0: float, x1: float, d0: float, d1: float, y_eave: float, y_ridge: float, inset: float, mat: Material) -> void:
	var dm := (d0 + d1) / 2.0
	var a := Vector3(x0, y_eave, d0)
	var b := Vector3(x1, y_eave, d0)
	var c := Vector3(x1, y_eave, d1)
	var d := Vector3(x0, y_eave, d1)
	var r0 := Vector3(x0 + inset, y_ridge, dm)
	var r1 := Vector3(x1 - inset, y_ridge, dm)
	var inside := Vector3((x0 + x1) / 2.0, y_eave, dm)
	poly([a, b, r1, r0], mat, inside)
	poly([c, d, r0, r1], mat, inside)
	poly([d, a, r0], mat, inside)
	poly([b, c, r1], mat, inside)


## A gable roof whose ridge runs front to back (the pointed end faces you).
func gable_d(x0: float, x1: float, d0: float, d1: float, y_eave: float, y_ridge: float, mat: Material, gable_mat: Material = null) -> void:
	var xm := (x0 + x1) / 2.0
	var inside := Vector3(xm, y_eave, (d0 + d1) / 2.0)
	poly([Vector3(x0, y_eave, d0), Vector3(xm, y_ridge, d0), Vector3(xm, y_ridge, d1), Vector3(x0, y_eave, d1)], mat, inside)
	poly([Vector3(x1, y_eave, d0), Vector3(x1, y_eave, d1), Vector3(xm, y_ridge, d1), Vector3(xm, y_ridge, d0)], mat, inside)
	if gable_mat != null:
		var dd := d0 + 0.1
		poly([Vector3(x0 + 0.12, y_eave, dd), Vector3(x1 - 0.12, y_eave, dd), Vector3(xm, y_ridge - 0.1, dd)], gable_mat, Vector3(xm, y_eave, dd + 1.0))


# --- Materials ------------------------------------------------------------------------

func mat(color: Color, tex: Image = null, uv_scale := Vector2.ONE, emissive := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.metallic_specular = 0.1
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if tex != null:
		m.albedo_texture = ImageTexture.create_from_image(tex)
		m.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	return m


static func _hash(x: int, y: int, s: int) -> float:
	var h := (x * 374761393 + y * 668265263 + s * 2246822519) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0


## Pattern textures (one tile = 16 px), tinted by the material colour.
static func tex_shingles(base: Color, rows := 4) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var rh := 16 / rows
	for y in 16:
		var row := y / rh
		for x in 16:
			var off := (row % 2) * 4
			var c := base
			if y % rh == rh - 1:
				c = base.darkened(0.35)
			elif (x + off) % 8 == 7:
				c = base.darkened(0.2)
			elif y % rh == 0:
				c = base.lightened(0.12)
			if _hash(x, y, 3) < 0.07:
				c = c.darkened(0.12)
			img.set_pixel(x, y, c)
	return img


static func tex_thatch(base: Color) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var c := base
			var k := _hash(x, y / 3, 5)
			if k < 0.25:
				c = base.darkened(0.25)
			elif k > 0.8:
				c = base.lightened(0.18)
			if y % 5 == 4:
				c = c.darkened(0.15)
			img.set_pixel(x, y, c)
	return img


static func tex_bricks(base: Color, mortar: Color, bh := 4, bw := 8) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		var row := y / bh
		for x in 16:
			var off := (row % 2) * (bw / 2)
			var c := base
			if y % bh == bh - 1 or (x + off) % bw == bw - 1:
				c = mortar
			elif y % bh == 0:
				c = base.lightened(0.1)
			elif _hash((x + off) / bw + row * 7, row, 9) < 0.3:
				c = base.darkened(0.08)
			img.set_pixel(x, y, c)
	return img


static func tex_planks(base: Color, vertical := false) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var a := x if vertical else y
			var b := y if vertical else x
			var plank := a / 4
			var c := base.darkened(0.06 * float(plank % 3))
			if a % 4 == 3:
				c = base.darkened(0.35)
			elif _hash(plank, b / 5, 11) < 0.12 and b % 5 == 0:
				c = base.darkened(0.3)
			img.set_pixel(x, y, c)
	return img


static func tex_plaster(base: Color, beam: Color) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var c := base
			if _hash(x, y, 13) < 0.08:
				c = base.darkened(0.08)
			if x <= 1 or y >= 14:
				c = beam
			img.set_pixel(x, y, c)
	return img


static func tex_noise(base: Color, amt := 0.12, salt := 1) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var k := _hash(x, y, salt)
			img.set_pixel(x, y, base.darkened(amt * k) if k < 0.6 else base.lightened(amt * 0.6 * (k - 0.6)))
	return img
