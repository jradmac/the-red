class_name SpriteHost
extends Node
## The characters of the 3D view: the same 2D pixel sprites, standing upright
## in the 3D world (like Pokemon's). Each frame every character near the
## camera paints itself (with its own 2D drawing code) into a slot of an atlas
## texture; a billboard in the 3D world shows that slot, tinted by the world's
## lights, with a soft round shadow on the ground under it.

const SLOT := Vector2i(48, 48)
const PIVOT := Vector2(24, 44)        ## in a slot: the point that stands on the ground
const ATLAS := Vector2i(1024, 512)
const RANGE := 17.0                   ## tiles from the camera's spot
const LIFT := 1.6                     ## (no longer used: see sprite3d_depth.gdshader)
const DEPTH_SHADER: Shader = preload("res://shaders/sprite3d_depth.gdshader")
var TOWARD_CAMERA := Vector3(0.0, sin(View3D.PITCH), cos(View3D.PITCH))

var view: View3D
var _vp: SubViewport
var _canvas: _AtlasCanvas
var _pool: Array[Sprite3D] = []
var _shadows: Array[MeshInstance3D] = []
var _jobs: Array = []                 ## this frame: [slot index, painter callable, foot Vector3, shaded, height]
var _active := false
var _slot_of := {}                    ## thing -> its atlas slot
var _free: Array[int] = []


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = ATLAS
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_canvas = _AtlasCanvas.new()
	_canvas.host = self
	_vp.add_child(_canvas)


func set_active(on: bool) -> void:
	_active = on
	if _vp != null:
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if not on:
		_slot_of.clear()
		_free.clear()
		for s in _pool:
			s.visible = false
		for s in _shadows:
			s.visible = false


func _slot_origin(i: int) -> Vector2:
	var cols := ATLAS.x / SLOT.x
	return Vector2((i % cols) * SLOT.x, (i / cols) * SLOT.y)


## Collect this frame's characters (nearest first) and place their billboards.
func update(targets: Array[Vector3]) -> void:
	if not _active or targets.is_empty():
		return
	_jobs.clear()
	var main := view.main
	var target: Vector3 = targets[0]
	var dist := func(x: float, z: float) -> float:
		var best := INF
		for t in targets:
			best = minf(best, Vector2(x - t.x, z - t.z).length())
		return best
	var cands: Array = []   # [dist, painter, 2D position, shaded, shadow width]
	var cloaks := {}        # the heroes' sprites (by id): the wind tugs at their hoods
	for h in Hero.all:
		var pl: Player = h.player
		if is_instance_valid(pl):
			cloaks[pl.get_instance_id()] = pl
		if is_instance_valid(pl) and pl.visible:
			# (you carry your own light: never a dark shape in your own lantern's glow)
			cands.append([0.0, _paint_node.bind(pl), pl.position, false, 0.42, pl.get_instance_id(), pl.climb_lift])
		var comp: Companion = h.companion
		if is_instance_valid(comp) and comp.alpha > 0.01:
			cands.append([0.5, _paint_companion.bind(comp), comp.pos + Vector2(0, 16), false, 0.0, comp.get_instance_id()])
	var en: Enemies = main.enemies
	if en != null:
		for e in en.list:
			if not is_instance_valid(e) or not e.visible:
				continue
			var d: float = dist.call(e.position.x / 16.0, e.position.y / 16.0)
			if d < RANGE:
				cands.append([d, _paint_enemy.bind(e), e.position, e.kind != "ghost", 0.0 if e.kind == "ghost" else 0.42, e.get_instance_id()])
	var ws: Wisps = main.wisps
	if ws != null:
		for w in ws.list:
			var d: float = dist.call(w.pos.x / 16.0, w.pos.y / 16.0)
			if d < RANGE:
				cands.append([d, _paint_wisp.bind(w, ws), w.pos, false, 0.0, "w%d" % ws.list.find(w)])
	var vl = main.get("villages")
	if vl != null:
		for p in vl.people:
			var d: float = dist.call(p.pos.x / 16.0, p.pos.y / 16.0)
			if d < RANGE:
				cands.append([d, _paint_person.bind(p, vl), p.pos, true, 0.4, "p%d" % vl.people.find(p)])
	# things on the ground: items, planted flares, bushes with berries
	var near := Rect2i(Vector2i(int(target.x - RANGE), int(target.z - RANGE)), Vector2i(int(RANGE * 2), int(RANGE * 2)))
	for t in targets:
		near = near.merge(Rect2i(Vector2i(int(t.x - RANGE), int(t.z - RANGE)), Vector2i(int(RANGE * 2), int(RANGE * 2))))
	var pk: Pickups = main.pickups
	if pk != null:
		for c in pk.ground:
			if near.has_point(c):
				var d: float = dist.call(c.x + 0.5, c.y + 0.5)
				cands.append([d + 0.2, _paint_item.bind(pk.ground[c].id, c), Vector2(c * 16), true, 0.25, "i%s" % c])
	var fl: Flares = main.flares
	if fl != null:
		for c in fl.planted:
			if near.has_point(c):
				cands.append([1.0, _paint_flare, Vector2(c * 16), false, 0.0, "f%s" % c])
		for c in fl.portals:
			if near.has_point(c):
				cands.append([1.0, _paint_portal, Vector2(c * 16), false, 0.0, "P%s" % c])
	var fo: Forage = main.forage
	if fo != null:
		for c in fo.bushes:
			if near.has_point(c):
				var d: float = dist.call(c.x + 0.5, c.y + 0.5)
				cands.append([d + 0.3, _paint_bush.bind(fo.bushes[c], c, fo), Vector2(c * 16), true, 0.45, "b%s" % c])
	var bm = main.get("bombs")
	if bm != null:
		for b in bm.planted:
			cands.append([0.8, _paint_bomb.bind(b, bm), Vector2(b.cell * 16), false, 0.2, "B%s" % b.cell])
	# little things on the floor: skulls and bones, glowing mushrooms
	var wd := view.world
	for y in range(near.position.y, near.end.y):
		for x in range(near.position.x, near.end.x):
			var c := Vector2i(x, y)
			var t := wd.tile_at(c)
			if t == "x" or t == "m":
				var d: float = dist.call(x + 0.5, y + 0.5)
				if d < RANGE - 2.0:
					cands.append([d + 0.5, _paint_floor.bind(t), Vector2(c * 16), t == "x", 0.0, "x%s" % c])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var max_slots := (ATLAS.x / SLOT.x) * (ATLAS.y / SLOT.y)
	var n := mini(cands.size(), max_slots)
	# Each thing keeps its own slot for as long as it's shown: a slot never
	# switches to someone else between the atlas being painted and shown
	# (that made things flicker and swap for a frame as you moved).
	var want := {}
	for i in n:
		want[cands[i][5]] = cands[i]
	for key in _slot_of.keys():
		if not want.has(key):
			_free.append(_slot_of[key])
			_slot_of.erase(key)
	var fresh := {}
	for key in want:
		if not _slot_of.has(key):
			var slot: int = _free.pop_back() if not _free.is_empty() else _slot_of.size() + _free.size()
			while _pool.size() <= slot:
				_add_sprite()
			_slot_of[key] = slot
			fresh[slot] = true
	var by_slot := {}
	for key in want:
		by_slot[_slot_of[key]] = want[key]
	for i in _pool.size():
		var s := _pool[i]
		var sh := _shadows[i]
		if not by_slot.has(i):
			s.visible = false
			sh.visible = false
			continue
		var c: Array = by_slot[i]
		var foot := view.to3d(c[2])
		var ground := foot
		if c.size() > 6:
			foot.y += float(c[6])   # climbing over a wall on a ladder
		_jobs.append([i, c[1]])
		var o := _slot_origin(i)
		s.region_rect = Rect2(o, SLOT)
		var dm := s.material_override as ShaderMaterial
		dm.set_shader_parameter("flutter", _flutter(cloaks.get(c[5])))
		dm.set_shader_parameter("flutter_rows", Vector2(o.y + PIVOT.y - 26.0, o.y + PIVOT.y - 7.0))
		# the billboard stands on its feet; its depth is worked out per pixel as
		# an upright figure's (sprite3d_depth.gdshader), so walls in front cover it
		var at := foot
		# Like Pokemon: one sprite pixel is exactly one screen pixel, near or
		# far, square to the screen, its feet on a whole pixel.
		var cm := view.camera_for(at)
		var depth := (at - cm.global_position).dot(-cm.global_transform.basis.z)
		var sp := cm.unproject_position(at).round()
		s.position = cm.project_position(sp, depth)
		var k := depth / View3D.DIST
		s.scale = Vector3(k, k, k)
		# its own drawn shading kept; just tinted by the light where it stands
		s.modulate = Color.WHITE if not c[3] else view.light_at(ground)
		s.visible = not fresh.has(i)   # (its slot is painted from the next frame on)
		var w: float = c[4]
		var raised := c.size() > 6 and float(c[6]) > 0.15
		sh.visible = w > 0.0 and not raised
		if w > 0.0:
			sh.position = ground + Vector3(0, 0.02, 0)
			sh.scale = Vector3(w * 2.0, 1.0, w * 1.3)
	_canvas.queue_redraw()


## How the wind tugs at a hero's hood and cloak (sprite3d_depth.gdshader's
## flutter): only when it's really blowing -- a puff, a gust -- not the
## light draft between puffs.
func _flutter(pl) -> Vector2:
	var wind = view.main.get("wind") if pl != null else null
	if wind == null or not is_instance_valid(pl):
		return Vector2.ZERO
	var w: Vector2 = wind.wind_at(pl.cell)
	var k := w.length()
	if k < 0.5:
		return Vector2.ZERO
	k = minf(k, 1.6)
	if absf(w.x) > 0.3 * w.length():
		return Vector2(signf(w.x) * k, 0.0)
	return Vector2(0.0, k)


func _add_sprite() -> void:
	var s := Sprite3D.new()
	s.texture = _vp.get_texture()
	s.region_enabled = true
	s.pixel_size = 1.0 / 16.0
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.double_sided = true
	s.centered = true
	# hidden by the world like an upright figure, not a card tilted back
	var dm := ShaderMaterial.new()
	dm.shader = DEPTH_SHADER
	dm.set_shader_parameter("atlas", _vp.get_texture())
	s.material_override = dm
	# the slot's pivot on the ground: the slot is 48 px, its middle is 24 up
	s.offset = Vector2(0, SLOT.y / 2.0 - (SLOT.y - PIVOT.y))
	# upright, so seen from above it looks short: stretch it back to its true height
	view.root.add_child(s)
	_pool.append(s)
	var sh := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.orientation = PlaneMesh.FACE_Y
	sh.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _shadow_tex()
	m.albedo_color = Color(0, 0, 0, 0.55)
	sh.material_override = m
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.root.add_child(sh)
	_shadows.append(sh)


static var _stex: ImageTexture


static func _shadow_tex() -> ImageTexture:
	if _stex != null:
		return _stex
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5).length() / 8.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
	_stex = ImageTexture.create_from_image(img)
	return _stex


# --- Painting the slots -------------------------------------------------------------

class _AtlasCanvas extends Node2D:
	var host: SpriteHost

	func _draw() -> void:
		Shadows.off = true   # (the 3D view lays its own shadows on the ground)
		for j in host._jobs:
			var o := host._slot_origin(j[0])
			# the painters draw a tile-sized character at `at` (its tile's top-left)
			var at := o + host.PIVOT - Vector2(8, 15)
			(j[1] as Callable).call(self, at)
		Shadows.off = false


func _paint_node(ci: CanvasItem, at: Vector2, node: Node2D) -> void:
	if node.has_method("paint"):
		node.paint(ci, at)


func _paint_enemy(ci: CanvasItem, at: Vector2, e: Enemy) -> void:
	e.paint(ci, at)


func _paint_companion(ci: CanvasItem, at: Vector2, c: Companion) -> void:
	c.paint(ci, at + Vector2(2, -16))


func _paint_item(ci: CanvasItem, at: Vector2, id: String, c: Vector2i) -> void:
	var phase := float((c.x * 7 + c.y * 13) % 10)
	var lift := roundf(2.5 + sin(Time.get_ticks_msec() / 1000.0 * 2.6 + phase) * 1.5)
	Items.draw_icon(ci, id, Rect2(at + Vector2(0, -lift), Vector2(16, 16)))


const PROPS_TEX: Texture2D = preload("res://assets/props.png")


func _paint_flare(ci: CanvasItem, at: Vector2) -> void:
	ci.draw_texture_rect_region(PROPS_TEX, Rect2(at, Vector2(16, 16)), Rect2(Flares.FLARE_INDEX * 16, 0, 16, 16))


func _paint_portal(ci: CanvasItem, at: Vector2) -> void:
	Flares.paint_portal(ci, at, Time.get_ticks_msec() / 1000.0)


func _paint_floor(ci: CanvasItem, at: Vector2, t: String) -> void:
	ci.draw_texture_rect_region(PROPS_TEX, Rect2(at, Vector2(16, 16)), Rect2(World.PROP_INDEX[t] * 16, 0, 16, 16))


func _paint_bush(ci: CanvasItem, at: Vector2, b: Dictionary, c: Vector2i, fo: Forage) -> void:
	var col := (2 if b.blue else 0) + (1 if b.berries > 0 else 0)
	ci.draw_texture_rect_region(Forage.TEX, Rect2(at + Vector2(-8, -12), Vector2(32, 32)), Rect2(col * 32, 0, 32, 32))


func _paint_wisp(ci: CanvasItem, at: Vector2, w: Dictionary, ws: Wisps) -> void:
	ws.paint_one(ci, w, at)


func _paint_person(ci: CanvasItem, at: Vector2, p: Dictionary, vl: Node) -> void:
	var q := p.duplicate()
	q.pos = at
	vl._draw_person(ci, q)


func _paint_bomb(ci: CanvasItem, at: Vector2, b: Dictionary, bm: Bombs) -> void:
	bm.paint_bomb(ci, b, at)
