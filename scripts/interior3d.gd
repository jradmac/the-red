class_name Interior3D
extends Node
## The inside of a village building in 3D, for Interior (interior.gd) when
## the 3D world is on: the same room, laid out the same way, but built as a
## real room under the same camera and the same light as the labyrinth.
##
##   floor     the room's floor tiles (interiors.png), a doormat at the door
##   walls     the back wall and the two side walls, as tall as the 2D wall
##             art, with a dark cap along their tops
##   things    every piece of furniture is a block standing on its footprint:
##             its top and its front are cut from its own pixel art, so from
##             the game's camera it looks just like the drawing -- but it has
##             depth, hides whoever walks behind it and is lit by the room
##   on walls  windows, paintings, herbs... hang on the back wall; rugs lie on
##             the floor
##   light     a warm room light, plus the fire, the stove, candles, the
##             crystal ball and the cauldron, each a real light that flickers;
##             windows glow (moonlight at night, daylight by day)
##   people    you, your partner and whoever is home, as the same upright
##             sprites as outside, tinted by the light where they stand
##
## The room's logic (walking, talking, the keeper's counter) stays in
## Interior; this only shows it.

const TEX: Texture2D = preload("res://assets/interiors.png")
const GRADE_SHADER := preload("res://shaders/grade3d.gdshader")
const PX_UP := 16.0 * cos(View3D.PITCH)   ## screen pixels per tile of height
const PX_DEEP := 16.0 * sin(View3D.PITCH) ## screen pixels per tile of floor depth
const WALL_H := 32.0 / (16.0 * cos(View3D.PITCH))   ## the wall art (32 px) at 1:1
const SLOT := Vector2i(48, 48)
const PIVOT := Vector2(24, 44)
const SLOTS := 6
const LIFT := 1.6

## How deep each piece of furniture really is (tiles): the rest of its
## footprint is floor in front of it. Pieces against the wall are shallow.
const DEPTH := {
	"shelf_potions": 0.55, "shelf_goods": 0.55, "bookshelf": 0.55, "shelf_bottles": 0.55, "shelf_jars": 0.55,
	"cupboard": 0.6, "fireplace": 0.7, "stairs": 1.0, "stove": 0.7, "clock": 0.45, "candle_stand": 0.3,
	"crystal": 0.5, "plant": 0.55, "stool": 0.55, "sack": 0.7, "barrel": 0.8, "crate": 0.85, "cauldron": 0.9,
	"bed_blue": 2.0, "bed_red": 2.0, "bed_green": 2.0, "table": 1.0, "table_cloth": 1.0, "display": 1.0,
	"low_table": 1.0, "counter_l": 1.0, "counter_m": 1.0, "counter_r": 1.0, "counter_till": 1.0, "counter_mugs": 1.0,
}
## Lights that live in the furniture: [colour, energy, range (tiles), height, flicker, z offset]
const GLOWS := {
	"fireplace": [Color(1.0, 0.55, 0.22), 2.6, 7.0, 0.7, 0.18, 0.15],
	"stove": [Color(1.0, 0.5, 0.25), 1.2, 3.5, 0.9, 0.1, 0.1],
	"candle_stand": [Color(1.0, 0.72, 0.4), 1.4, 4.5, 2.4, 0.12, 0.0],
	"low_table": [Color(1.0, 0.72, 0.4), 1.2, 4.0, 1.3, 0.12, 0.0],
	"crystal": [Color(0.72, 0.5, 1.0), 1.2, 3.5, 1.8, 0.05, 0.0],
	"cauldron": [Color(0.45, 1.0, 0.45), 1.0, 3.0, 1.3, 0.08, 0.0],
}
## Each room's own feel: the warm light that fills it.
const ROOM_LIGHT := {
	"shop": Color(1.0, 0.86, 0.66), "sage": Color(0.82, 0.72, 1.0), "inn": Color(1.0, 0.78, 0.55),
}

var interior: Interior
var vp: SubViewport
var screen: TextureRect
var _root: Node3D
var _room: Node3D
var _cam: Camera3D
var _env: Environment
var _sun: DirectionalLight3D
var _grade: ShaderMaterial
var _lights: Array = []        ## [OmniLight3D, base energy, flicker, seed]
var _glows: Array = []         ## [MeshInstance3D emissive, base colour, flicker, seed]
var _sprites: Array[Sprite3D] = []
var _shadows: Array[MeshInstance3D] = []
var _atlas: SubViewport
var _atlas_canvas: Node2D
var _jobs: Array = []          ## [slot, painter Callable]
var _look := Vector3.ZERO
var _mats := {}
var _time := 0.0


func setup(owner_interior: Interior) -> void:
	interior = owner_interior
	vp = SubViewport.new()
	vp.size = Vector2i(360, 240)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.positional_shadow_atlas_size = 1024
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	_root = Node3D.new()
	vp.add_child(_root)
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.02, 0.015, 0.03)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_REINHARDT
	_env.tonemap_white = 2.2
	_env.tonemap_exposure = 1.0
	we.environment = _env
	vp.add_child(we)
	# a soft light from the front and above, like a lamp hanging in the room
	_sun = DirectionalLight3D.new()
	_sun.rotation = Vector3(deg_to_rad(-62.0), deg_to_rad(-18.0), 0.0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = View3D.DIST + 20.0
	_sun.shadow_bias = 0.05
	_root.add_child(_sun)
	_cam = Camera3D.new()
	_cam.near = 1.0
	_cam.far = View3D.DIST + 60.0
	vp.add_child(_cam)
	_cam.current = true
	_grade = ShaderMaterial.new()
	_grade.shader = GRADE_SHADER
	_grade.set_shader_parameter("night", 0.55)
	_grade.set_shader_parameter("vignette", 0.5)
	screen = TextureRect.new()
	screen.texture = vp.get_texture()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.material = _grade
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.visible = false
	# the characters: painted into a small atlas, shown on billboards
	_atlas = SubViewport.new()
	_atlas.size = Vector2i(SLOT.x * SLOTS, SLOT.y)
	_atlas.transparent_bg = true
	_atlas.disable_3d = true
	_atlas.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_atlas.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_atlas)
	_atlas_canvas = Node2D.new()
	_atlas_canvas.draw.connect(_paint_atlas)
	_atlas.add_child(_atlas_canvas)


## The 3D view is used when the 3D world setting is on.
static func wanted() -> bool:
	return View3D.enabled


func set_shown(on: bool) -> void:
	screen.visible = on
	var mode := SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	vp.render_target_update_mode = mode
	_atlas.render_target_update_mode = mode


# --- Building the room ----------------------------------------------------------------------

func build(room: Dictionary, kind: String) -> void:
	if _room != null:
		_room.queue_free()
	_room = Node3D.new()
	_root.add_child(_room)
	_lights.clear()
	_glows.clear()
	var size: Vector2i = room.size
	var floors: Array = room.floor
	# floor
	var st := _st()
	for y in size.y:
		for x in size.x:
			var c := Vector2i(x, y)
			var name: String = "doormat" if c == room.door else (floors[1] if (x * 7 + y * 13) % 5 == 0 else floors[0])
			_quad(st, Vector3(x, 0, y), Vector3(x + 1, 0, y), Vector3(x + 1, 0, y + 1), Vector3(x, 0, y + 1),
				InteriorArt.ART[name][0], Vector3.UP)
	_commit(st, _mat("floor"))
	# walls: back, left and right, the wall art standing at 1:1, a dark cap on top
	var ws := _st()
	for x in size.x:
		var strip: String = room.wall + ("_b" if (x * 5) % 3 == 0 else "")
		_quad(ws, Vector3(x, WALL_H, 0), Vector3(x + 1, WALL_H, 0), Vector3(x + 1, 0, 0), Vector3(x, 0, 0),
			InteriorArt.ART[strip][0], Vector3.BACK)
	for z in size.y:
		var strip: String = room.wall + ("_b" if (z * 5) % 3 == 0 else "")
		var r: Rect2 = InteriorArt.ART[strip][0]
		_quad(ws, Vector3(0, WALL_H, z), Vector3(0, WALL_H, z + 1), Vector3(0, 0, z + 1), Vector3(0, 0, z), r, Vector3.RIGHT)
		_quad(ws, Vector3(size.x, WALL_H, z + 1), Vector3(size.x, WALL_H, z), Vector3(size.x, 0, z), Vector3(size.x, 0, z + 1), r, Vector3.LEFT)
	_commit(ws, _mat("walls"))
	var cap := _mat("cap", Color("2a1d2c"), false)
	var t := 0.22
	_box(Vector3(-t, 0, -t), Vector3(size.x + t, WALL_H + 0.06, 0), cap)
	_box(Vector3(-t, 0, 0), Vector3(0, WALL_H + 0.06, size.y), cap)
	_box(Vector3(size.x, 0, 0), Vector3(size.x + t, WALL_H + 0.06, size.y), cap)
	# rugs on the floor, hangings on the wall, furniture standing
	var fs := _st()
	var hs := _st()
	for ob in room.objects:
		var name: String = ob[0]
		var at: Vector2i = ob[1]
		var a: Array = InteriorArt.ART[name]
		var r: Rect2 = a[0]
		match a[3]:
			"floor":
				var x0 := float(at.x)
				var z0 := float(at.y) + float(a[2]) - r.size.y / 16.0
				var y := 0.012
				_quad(fs, Vector3(x0, y, z0), Vector3(x0 + r.size.x / 16.0, y, z0), Vector3(x0 + r.size.x / 16.0, y, z0 + r.size.y / 16.0),
					Vector3(x0, y, z0 + r.size.y / 16.0), r, Vector3.UP)
			"wall":
				var x0 := float(at.x) + 4.0 / 16.0
				var top := WALL_H - 7.0 / PX_UP
				var bot := top - r.size.y / PX_UP
				var x1 := x0 + r.size.x / 16.0
				_quad(hs, Vector3(x0, top, 0.02), Vector3(x1, top, 0.02), Vector3(x1, bot, 0.02), Vector3(x0, bot, 0.02), r, Vector3.BACK)
				if name.begins_with("window"):
					_window_light(Vector3((x0 + x1) / 2.0, (top + bot) / 2.0, 0.0), r)
			"block":
				_furniture(name, at, a)
	_commit(fs, _mat("rugs", Color.WHITE, true))
	_commit(hs, _mat("hangings", Color.WHITE, true))
	# the room's own light, filling it warmly
	var lamp := OmniLight3D.new()
	lamp.light_color = ROOM_LIGHT.get(kind, Color(1.0, 0.82, 0.62))
	lamp.light_energy = 0.4 if kind == "shop" else 0.55   # (the shop's pale floor needs less)
	lamp.omni_range = maxf(size.x, size.y) * 1.1
	lamp.omni_attenuation = 0.6
	lamp.position = Vector3(size.x / 2.0, WALL_H + 0.4, size.y * 0.55)
	_room.add_child(lamp)
	_lights.append([lamp, lamp.light_energy, 0.0, 0.0])
	LightStyle.convert(_room)
	# the camera looks at the middle of the room (fixed: the room fits the screen)
	_look = Vector3(size.x / 2.0, 0.9, size.y / 2.0 - 0.35)
	_place_camera()


## A piece of furniture: a block on its footprint, its top and front cut from its art.
func _furniture(name: String, at: Vector2i, a: Array) -> void:
	var r: Rect2 = a[0]
	var fw: float = a[1]
	var fd: float = a[2]
	var d: float = DEPTH.get(name, minf(fd, 0.9))
	# rows of the art that show its top (seen at the camera's angle), the rest is its front
	var top_rows := clampf(roundf(d * PX_DEEP), 2.0, r.size.y - 2.0)
	var front_rows := r.size.y - top_rows
	var h := front_rows / PX_UP
	var w := r.size.x / 16.0
	var x0 := float(at.x) + (fw - w) / 2.0
	var x1 := x0 + w
	var z1 := float(at.y) + fd
	var z0 := z1 - d
	var top_r := Rect2(r.position, Vector2(r.size.x, top_rows))
	var front_r := Rect2(r.position + Vector2(0, top_rows), Vector2(r.size.x, front_rows))
	var st := _st()
	_quad(st, Vector3(x0, h, z0), Vector3(x1, h, z0), Vector3(x1, h, z1), Vector3(x0, h, z1), top_r, Vector3.UP)
	_quad(st, Vector3(x0, h, z1), Vector3(x1, h, z1), Vector3(x1, 0, z1), Vector3(x0, 0, z1), front_r, Vector3.BACK)
	# the sides: the art's edge columns, run back along the depth
	var left := Rect2(front_r.position, Vector2(1, front_rows))
	var right := Rect2(front_r.position + Vector2(r.size.x - 1, 0), Vector2(1, front_rows))
	_quad(st, Vector3(x0, h, z0), Vector3(x0, h, z1), Vector3(x0, 0, z1), Vector3(x0, 0, z0), left, Vector3.LEFT)
	_quad(st, Vector3(x1, h, z1), Vector3(x1, h, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), right, Vector3.RIGHT)
	var mi := _commit(st, _mat("things", Color.WHITE, true))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if GLOWS.has(name):
		var g: Array = GLOWS[name]
		var l := OmniLight3D.new()
		l.light_color = g[0]
		l.light_energy = g[1]
		l.omni_range = g[2]
		l.omni_attenuation = 1.0
		l.position = Vector3((x0 + x1) / 2.0, minf(g[3], h + 0.2), z1 + float(g[5]))
		l.shadow_enabled = name == "fireplace"
		_room.add_child(l)
		_lights.append([l, l.light_energy, g[4], randf() * 10.0])
		# the flame itself: a small glowing patch on the furniture
		var fl := MeshInstance3D.new()
		var q := QuadMesh.new()
		var fsz := Vector2(0.55, 0.35) if name == "fireplace" else Vector2(0.14, 0.2)
		q.size = fsz
		fl.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = (g[0] as Color).lightened(0.35)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		fl.material_override = m
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if name == "fireplace":
			fl.position = Vector3((x0 + x1) / 2.0, 0.45, z1 + 0.02)
		elif name == "low_table":
			fl.visible = false   # (its two candles are in its art)
		else:
			fl.position = Vector3((x0 + x1) / 2.0, h + 0.1, (z0 + z1) / 2.0)
		_room.add_child(fl)
		_glows.append([fl, m.albedo_color, g[4], randf() * 10.0])


## A window glows, and lets in a little light: moonlight by night, day by day.
func _window_light(at: Vector3, _r: Rect2) -> void:
	var l := OmniLight3D.new()
	l.omni_range = 4.0
	l.omni_attenuation = 1.0
	l.position = at + Vector3(0, -0.3, 0.7)
	_room.add_child(l)
	_lights.append([l, -1.0, 0.0, 0.0])   # (energy and colour follow the time of day)


# --- Meshes --------------------------------------------------------------------------------

func _st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, src: Rect2, n: Vector3) -> void:
	var ts := TEX.get_size()
	var u0 := src.position / ts
	var u1 := src.end / ts
	# (a hair inside each texel's edge, so a neighbour's pixels never bleed in)
	var e := Vector2(0.01, 0.01) / ts
	u0 += e
	u1 -= e
	var uv := [Vector2(u0.x, u0.y), Vector2(u1.x, u0.y), Vector2(u1.x, u1.y), Vector2(u0.x, u1.y)]
	var p := [a, b, c, d]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(p[i])


func _commit(st: SurfaceTool, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	_room.add_child(mi)
	return mi


func _box(lo: Vector3, hi: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = hi - lo
	mi.mesh = bm
	mi.position = (lo + hi) / 2.0
	mi.material_override = m
	_room.add_child(mi)


func _mat(key: String, tint := Color.WHITE, cut := false) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = tint
	if key != "cap":
		m.albedo_texture = TEX
		m.texture_repeat = false
	if cut:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
	_mats[key] = m
	return m


# --- Every frame ----------------------------------------------------------------------------

func _place_camera() -> void:
	var size := Vector2(vp.size)
	_cam.fov = rad_to_deg(2.0 * atan(size.y / 32.0 / View3D.DIST))
	var right := Vector3.RIGHT
	var up := Vector3(0.0, cos(View3D.PITCH), -sin(View3D.PITCH))
	var fwd := -Vector3(0.0, sin(View3D.PITCH), cos(View3D.PITCH))
	# whole screen pixels only (as outside), so nothing shimmers
	var look := right * (roundf(_look.dot(right) * 16.0) / 16.0) + up * (roundf(_look.dot(up) * 16.0) / 16.0) + fwd * _look.dot(fwd)
	_cam.position = look + Vector3(0.0, sin(View3D.PITCH), cos(View3D.PITCH)) * View3D.DIST
	_cam.look_at(look, Vector3.UP)


func update(delta: float, view_size: Vector2) -> void:
	_time += delta
	if Vector2(vp.size) != view_size and view_size.x > 0:
		vp.size = Vector2i(view_size)
		screen.size = view_size
		_place_camera()
	# light: flames flicker; windows follow the time of day
	var day: DayCycle = interior.hero.player.get_tree().current_scene.get("day") if interior.hero != null else null
	var dl: float = day.light if day != null else 0.0
	_env.ambient_light_color = Color(0.3, 0.24, 0.32).lerp(Color(0.5, 0.47, 0.46), dl)
	_env.ambient_light_energy = lerpf(0.42, 0.55, dl)
	_sun.light_color = Color(1.0, 0.86, 0.66)
	_sun.light_energy = lerpf(0.12, 0.22, dl)
	_grade.set_shader_parameter("night", lerpf(0.55, 0.2, dl))
	for e in _lights:
		var l: OmniLight3D = e[0]
		if e[1] < 0.0:   # a window
			l.light_color = Color(0.55, 0.65, 1.0).lerp(Color(1.0, 0.92, 0.75), dl)
			l.light_energy = lerpf(0.3, 1.3, dl)
			continue
		var f: float = e[2]
		var t: float = _time + e[3]
		var n := sin(t * 7.3) * 0.5 + sin(t * 17.1) * 0.3 + sin(t * 31.7) * 0.2
		l.light_energy = e[1] * (1.0 + n * f)
	for g in _glows:
		var t: float = _time + g[3]
		var n := sin(t * 9.1) * 0.5 + sin(t * 23.3) * 0.5
		((g[0] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = (g[1] as Color).lightened(0.15 * n)
	_place_people()


## How lit a spot is (for tinting the characters), with the same falloff and
## colour as the room's own light model.
func light_at(p: Vector3) -> Color:
	var c := _env.ambient_light_color * _env.ambient_light_energy * 1.6 + _sun.light_color * _sun.light_energy * 0.7
	for e in _lights:
		var o: OmniLight3D = e[0]
		var d := o.position.distance_to(p + Vector3(0, 0.6, 0))
		if d >= o.omni_range:
			continue
		var k := pow(clampf(View3D.omni_falloff(d, o.omni_range, o.omni_attenuation), 0.0, 1.0), 0.75)
		c += View3D.flame(o.light_color, k) * o.light_energy * k * 0.6
	return Color(clampf(c.r, 0.1, 1.1), clampf(c.g, 0.1, 1.1), clampf(c.b, 0.1, 1.1))


## Everyone in the room: [painter, 2D position (px, in the room), shadow width]
func _place_people() -> void:
	var who: Array = []
	var it := interior
	who.append([_paint_hero.bind(it.hero, it.facing, it._move_t, it._step), it._pos, 0.42])
	var other: Hero = it._partner_here()
	if other != null:
		var oi: Interior = other.interior
		who.append([_paint_hero.bind(other, oi.facing, oi._move_t, oi._step), oi._pos, 0.42])
	for p in it._people:
		who.append([_paint_person.bind(p), p.pos, 0.38 if not p.get("child", false) else 0.3])
	while _sprites.size() < who.size():
		_add_sprite()
	_jobs.clear()
	for i in _sprites.size():
		var s := _sprites[i]
		var sh := _shadows[i]
		if i >= who.size() or i >= SLOTS:
			s.visible = false
			sh.visible = false
			continue
		var w: Array = who[i]
		var pos: Vector2 = w[1]
		var foot := Vector3(pos.x / 16.0 + 0.5, 0.0, pos.y / 16.0 + 0.5)
		_jobs.append([i, w[0]])
		s.region_rect = Rect2(i * SLOT.x, 0, SLOT.x, SLOT.y)
		var at := foot   # (hidden by the room like an upright figure: sprite3d_depth.gdshader)
		var depth := (at - _cam.global_position).dot(-_cam.global_transform.basis.z)
		var sp := _cam.unproject_position(at).round()
		s.position = _cam.project_position(sp, depth)
		var k := depth / View3D.DIST
		s.scale = Vector3(k, k, k)
		s.modulate = light_at(foot)
		s.visible = true
		sh.visible = true
		sh.position = foot + Vector3(0, 0.02, 0)
		sh.scale = Vector3(w[2] * 2.0, 1.0, w[2] * 1.3)
	_atlas_canvas.queue_redraw()


func _add_sprite() -> void:
	var s := Sprite3D.new()
	s.texture = _atlas.get_texture()
	s.region_enabled = true
	s.pixel_size = 1.0 / 16.0
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.double_sided = true
	s.offset = Vector2(0, SLOT.y / 2.0 - (SLOT.y - PIVOT.y))
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dm := ShaderMaterial.new()
	dm.shader = SpriteHost.DEPTH_SHADER
	dm.set_shader_parameter("atlas", _atlas.get_texture())
	s.material_override = dm
	_root.add_child(s)
	_sprites.append(s)
	var sh := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.orientation = PlaneMesh.FACE_Y
	sh.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = SpriteHost._shadow_tex()
	m.albedo_color = Color(0, 0, 0, 0.5)
	sh.material_override = m
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(sh)
	_shadows.append(sh)


func _paint_atlas() -> void:
	for j in _jobs:
		var at := Vector2(int(j[0]) * SLOT.x, 0) + PIVOT - Vector2(8, 15)
		(j[1] as Callable).call(_atlas_canvas, at)


func _paint_hero(ci: CanvasItem, at: Vector2, h: Hero, face: int, move_t: float, step: int) -> void:
	var col := 0
	if move_t < 1.0:
		col = 1 + (step % 2) * 2 + (1 if move_t > 0.5 else 0)
	HeroLook.use(h.player)
	HeroLook.draw(ci, at + Vector2(0, -8), 1.0, face, col, h.player.armor_id, h.player.weapon_id)


func _paint_person(ci: CanvasItem, at: Vector2, p: Dictionary) -> void:
	var row: int = [0, 1, 2, 3][int(p.dir)]
	var col := 0 if p.t >= 1.0 else 1 + int(p.t * 4.0) % 4
	var src := Rect2(col * 16, (int(p.look) * 4 + row) * 24, 16, 24)
	if p.get("child", false):
		ci.draw_texture_rect_region(Villages.NPC_TEX, Rect2(at + Vector2(2, -2), Vector2(12, 18)), src)
	else:
		ci.draw_texture_rect_region(Villages.NPC_TEX, Rect2(at + Vector2(0, -8), Vector2(16, 24)), src)
