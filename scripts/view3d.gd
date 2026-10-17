class_name View3D
extends Node
## The 3D view of the labyrinth: the walls, ground, trees and everything in it
## as models, under a camera that looks down at an angle (and always keeps
## you in the middle of the screen), lit by your lantern. The characters are
## still the 2D pixel sprites, standing upright in it (SpriteHost).
##
## The game itself is unchanged underneath: everything still lives on the
## tile grid and the 2D world keeps running (it's what you see with the 3D
## view switched off). This node just shows it differently:
##   - a SubViewport renders the 3D scene at the game's own low resolution
##     (360 x 240), so it's chunky pixels like the rest; in two-player mode
##     there are two, one per player's camera, looking at the same world;
##   - the flat things on the floor (trap plates, trapdoors, scorch marks,
##     wind, mist) are drawn into a texture that is laid over the 3D ground,
##     so they're lit, and hidden behind walls, like the floor itself;
##   - sparks and flashes (Fx) are drawn over the picture.
## World units are tiles: x east, y up, z south.

const PITCH := deg_to_rad(52.0)     ## how steeply the camera looks down
const DIST := 22.0                  ## camera distance (tiles) from the spot it looks at
const LIGHT_POOL := 16              ## lamps, candles, wisps... at once (nearest first)
const DECAL_TILES := Vector2i(48, 40)   ## the stretch of floor drawn on, around each camera

static var enabled := _load_enabled()   ## the "3D WORLD" setting
const SETTINGS_PATH := "user://display.cfg"

var main: Node
var world: World
var vp: SubViewport           ## player 1's (or the only) 3D picture
var root: Node3D              ## everything 3D
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var layer: CanvasLayer        ## shows the 3D picture (one player)
var screen: TextureRect
var sprites: SpriteHost
var objects: Objects3D
var village: Village3D
var traps3d: Traps3D
var active := false

var _views: Array = []        ## per camera: {vp, cam, target: Vector3, display: Viewport, show: CanvasLayer}
var _coop_svs: Array = []     ## two-player: each player's view of the world (CoopView)
var _coop_hide: Array = []    ## two-player: their darkness layers etc., hidden in 3D
var coop_centers: Array = []  ## two-player: where each camera looks (2D pixels), set by CoopView
var _lights: Array[OmniLight3D] = []
var _lanterns := {}           ## Hero -> OmniLight3D (with shadows)
var _built := false
var _time := 0.0
var _ground_meshes: Array[ArrayMesh] = []

# drawing 2D things in the 3D view
var _overlay_canvas: RID      ## Fx, over the picture
var _overlay_item: RID
var _decal_canvas: RID        ## floor things, drawn into textures laid on the ground
var _decal_item: RID
var _decal_vps: Array[SubViewport] = []
var _decal_mat: ShaderMaterial
var _attached: Array = []     ## [viewport RID, canvas RID]
var _moved: Array = []        ## [canvas item node, onto the floor?] moved onto those canvases


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


func setup(m: Node) -> void:
	main = m
	world = m.world
	_add_view()
	vp = _views[0].vp
	cam = _views[0].cam
	root = Node3D.new()
	vp.add_child(root)
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.015, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	vp.add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(-35.0), 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	sun.shadow_bias = 0.06
	root.add_child(sun)
	for i in LIGHT_POOL:
		var l := OmniLight3D.new()
		l.visible = false
		l.shadow_enabled = false
		l.omni_attenuation = 1.4
		root.add_child(l)
		_lights.append(l)
	# on screen: the 3D picture, above the 2D world (layer 0) and its old
	# darkness (layer 1), below the HUD (4) and menus
	layer = CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	screen = TextureRect.new()
	screen.texture = vp.get_texture()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.size = Vector2(360, 240)
	layer.add_child(screen)
	sprites = SpriteHost.new()
	sprites.view = self
	add_child(sprites)
	_setup_canvases()
	set_active(false)


func _add_view() -> Dictionary:
	var v := SubViewport.new()
	v.size = Vector2i(360, 240)
	v.msaa_3d = Viewport.MSAA_DISABLED
	v.render_target_update_mode = SubViewport.UPDATE_DISABLED
	v.positional_shadow_atlas_size = 2048
	if _views.is_empty():
		v.own_world_3d = true
	add_child(v)
	if not _views.is_empty():
		v.world_3d = (_views[0].vp as SubViewport).find_world_3d()
	var c := Camera3D.new()
	c.fov = rad_to_deg(2.0 * atan(7.5 / DIST))
	c.near = 1.0
	c.far = 90.0
	v.add_child(c)
	c.current = true
	var d := {"vp": v, "cam": c, "target": Vector3.ZERO, "display": null, "show": null}
	_views.append(d)
	return d


## Builds the models (call once the labyrinth is complete). Async: it bakes
## the ground a piece per frame, then switches the view on.
func build() -> void:
	var wm := WorldMesh.new()
	wm.view = self
	await wm.build(root)
	_ground_meshes = wm.ground_meshes
	objects = Objects3D.new()
	root.add_child(objects)
	objects.build(self)
	village = Village3D.new()
	root.add_child(village)
	village.build(self)
	traps3d = Traps3D.new()
	root.add_child(traps3d)
	traps3d.build(self)
	_build_decals()
	_built = true
	set_active(enabled)


func set_active(on: bool) -> void:
	on = on and _built
	active = on
	World.flat_hidden = on
	if not on:
		World.fx_rect = Rect2i()
	if world != null:
		world.queue_redraw()
	var b = main.get("bombs")
	if b != null:
		b.hide_planted = on
	var t = main.get("traps")
	if t != null:
		t.set_fx_hidden(on)
	sprites.set_active(on)
	if main.lighting != null:
		main.lighting.visible = not on
	if main._eyes_layer != null:
		main._eyes_layer.visible = not on
	for n in _coop_hide:
		if is_instance_valid(n):
			n.visible = not on
	_move_2d(on)
	_refresh_display()


## The cameras currently in use and where each picture goes on screen.
func _refresh_display() -> void:
	for a in _attached:
		RenderingServer.viewport_remove_canvas(a[0], a[1])
	_attached.clear()
	var two := not _coop_svs.is_empty()
	if two and _views.size() < 2:
		_add_view()
	for i in _views.size():
		var v: Dictionary = _views[i]
		var used := active and (i == 0 or two)
		(v.vp as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS if used else SubViewport.UPDATE_DISABLED
		if v.show != null and (not two or not used):
			(v.show as CanvasLayer).queue_free()
			v.show = null
		v.display = null
		if not used:
			continue
		var display: Viewport
		if two:
			display = _coop_svs[i]
			(v.vp as SubViewport).size = (_coop_svs[i] as SubViewport).size
			if v.show == null:
				var cl := CanvasLayer.new()
				cl.layer = 1
				var tr := TextureRect.new()
				tr.texture = (v.vp as SubViewport).get_texture()
				tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				tr.size = Vector2((_coop_svs[i] as SubViewport).size)
				cl.add_child(tr)
				display.add_child(cl)
				v.show = cl
		else:
			display = main.get_viewport()
		v.display = display
		_attach(display.get_viewport_rid(), _overlay_canvas, 2)
	layer.visible = active and not two
	for i in _decal_vps.size():
		var used := active and (i == 0 or two)
		_decal_vps[i].render_target_update_mode = SubViewport.UPDATE_ALWAYS if used else SubViewport.UPDATE_DISABLED
		if used:
			_attach(_decal_vps[i].get_viewport_rid(), _decal_canvas, 0)


func _attach(vp_rid: RID, canvas: RID, stack: int) -> void:
	RenderingServer.viewport_attach_canvas(vp_rid, canvas)
	RenderingServer.viewport_set_canvas_stacking(vp_rid, canvas, stack, 0)
	_attached.append([vp_rid, canvas])


## Two-player: show the world in 3D in each player's view (CoopView's
## SubViewports); `hide`: their old darkness layers.
func attach_coop(svs: Array, hide: Array) -> void:
	_coop_svs = svs.duplicate()
	_coop_hide = hide.duplicate()
	for n in _coop_hide:
		if is_instance_valid(n):
			n.visible = not active
	_refresh_display()


func detach_coop() -> void:
	_coop_svs.clear()
	_coop_hide.clear()
	coop_centers.clear()
	_refresh_display()


## Where a 2D world position (pixels; a tile's top-left) stands in 3D: the
## middle of that tile, on the ground there.
func to3d(p: Vector2) -> Vector3:
	var x := p.x / World.TILE + 0.5
	var z := p.y / World.TILE + 0.5
	return Vector3(x, ground_at(x, z), z)


## The height of the ground under a point (tiles), slopes included.
func ground_at(x: float, z: float) -> float:
	var c := Vector2i(int(floor(x)), int(floor(z)))
	if world.ramps.has(c):
		var lo := float(world.height_at(c)) * WorldMesh.LEVEL
		var f := 0.0
		match world.ramps[c]:
			"w": f = x - floor(x)
			"e": f = 1.0 - (x - floor(x))
			_: f = 1.0 - (z - floor(z))
		return lo + f * WorldMesh.LEVEL
	if world.tile_at(c) == "~":
		return WorldMesh.WATER_Y
	return float(world.height_at(c)) * WorldMesh.LEVEL


## The spots the cameras look at (one, or two in two-player mode).
func targets() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in _views.size():
		if i == 0 or not _coop_svs.is_empty():
			out.append(_views[i].target)
	return out


func _process(delta: float) -> void:
	if not active:
		return
	_time += delta
	var two := not _coop_svs.is_empty()
	if not two:
		var view := main.get_viewport().get_visible_rect().size
		if Vector2(vp.size) != view:
			vp.size = Vector2i(view)
			screen.size = view
	var p: Player = main.player
	for i in _views.size():
		if i > 0 and not two:
			break
		var v: Dictionary = _views[i]
		var c: Camera3D = v.cam
		var at: Vector2 = p.position + Vector2(8, 8)
		if two and coop_centers.size() == 2:
			at = coop_centers[i]
		var g := Vector3(at.x / World.TILE, 0.0, at.y / World.TILE)
		g.y = ground_at(g.x, g.z)
		v.target = g
		var size := Vector2((v.vp as SubViewport).size)
		c.fov = rad_to_deg(2.0 * atan(size.y / 32.0 / DIST))
		var look := _snap(g + Vector3(0.0, 0.6, 0.0))
		c.position = look + Vector3(0.0, sin(PITCH), cos(PITCH)) * DIST
		c.look_at(look, Vector3.UP)
		_place_overlay(v, at, g)
	var ts := targets()
	_update_lights(ts)
	sprites.update(ts)
	_update_decals(ts)


## The camera only ever moves by whole screen pixels (as a 2D game's does):
## the point it looks at is rounded, across and up the screen, to 1/16 of a
## tile -- one pixel at that distance. A camera gliding by fractions of a
## pixel makes every pixel of the low-resolution picture crawl and shimmer.
func _snap(p: Vector3) -> Vector3:
	var right := Vector3.RIGHT
	var up := Vector3(0.0, cos(PITCH), -sin(PITCH))
	var fwd := -Vector3(0.0, sin(PITCH), cos(PITCH))
	var r := roundf(p.dot(right) * 16.0) / 16.0
	var u := roundf(p.dot(up) * 16.0) / 16.0
	return right * r + up * u + fwd * p.dot(fwd)


# --- Light ------------------------------------------------------------------------

## The camera that shows `p` (the nearest one's, in two-player mode).
func camera_for(p: Vector3) -> Camera3D:
	if _coop_svs.is_empty() or _views.size() < 2:
		return cam
	var a: Vector3 = _views[0].target
	var b: Vector3 = _views[1].target
	return cam if Vector2(p.x - a.x, p.z - a.z).length() <= Vector2(p.x - b.x, p.z - b.z).length() else _views[1].cam


## How lit a spot is (for tinting the sprites): the daylight, plus every
## lantern, lamp and candle near it.
func light_at(p: Vector3) -> Color:
	var c := env.ambient_light_color * env.ambient_light_energy * 1.3
	c += sun.light_color * sun.light_energy * 0.7
	var ls: Array = _lanterns.values() + _lights
	for l in ls:
		var o := l as OmniLight3D
		if o == null or not o.visible:
			continue
		var d := o.position.distance_to(p + Vector3(0, 0.6, 0))
		if d >= o.omni_range:
			continue
		var att := pow(1.0 - d / o.omni_range, o.omni_attenuation)
		c += o.light_color * o.light_energy * att * 0.9
	return Color(clampf(c.r, 0.06, 1.0), clampf(c.g, 0.06, 1.0), clampf(c.b, 0.07, 1.0))


func _update_lights(ts: Array[Vector3]) -> void:
	var day: DayCycle = main.day
	var dl := day.light if day != null else 0.0
	var warm := day.warmth() if day != null else 0.0
	# the sun (and moon): daylight, warm at dawn and dusk; a faint cold moon at night
	sun.light_energy = lerpf(0.08, 0.95, dl)
	sun.light_color = Color(0.55, 0.6, 0.95).lerp(Color(1.0, 0.95, 0.85), dl).lerp(Color(1.0, 0.7, 0.45), warm * 0.8)
	sun.shadow_enabled = dl > 0.05
	env.ambient_light_color = Color(0.2, 0.18, 0.3).lerp(Color(0.62, 0.62, 0.72), dl)
	env.ambient_light_energy = lerpf(0.2, 0.55, dl)
	env.background_color = Color(0.02, 0.015, 0.03).lerp(Color(0.25, 0.25, 0.3), dl)
	# lanterns: one real light each, casting shadows
	for h in Hero.all:
		if not _lanterns.has(h):
			var l := OmniLight3D.new()
			l.shadow_enabled = true
			l.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
			l.shadow_bias = 0.08
			l.omni_attenuation = 1.2
			root.add_child(l)
			_lanterns[h] = l
	for h in _lanterns.keys():
		if not Hero.all.has(h):
			(_lanterns[h] as OmniLight3D).queue_free()
			_lanterns.erase(h)
	var lanterns := {}
	for h in Hero.all:
		var src: Dictionary = h.lantern_light
		lanterns[src] = true
		var l: OmniLight3D = _lanterns[h]
		_place_light(l, src, 1.0)
	# everything else that glows: the nearest ones get a light
	var srcs: Array = []
	for s in main.lighting._sources:
		if lanterns.has(s) or not is_instance_valid(s.node) or s.energy <= 0.01 or s.get("glow", 1.0) <= 0.0 and s.radius < 21.0:
			continue
		var p := _source_pos(s)
		var d := INF
		for t in ts:
			d = minf(d, Vector2(p.x - t.x, p.z - t.z).length())
		if d < 20.0:
			srcs.append([d, s, p])
	srcs.sort_custom(func(a, b): return a[0] < b[0])
	for i in _lights.size():
		var l: OmniLight3D = _lights[i]
		if i < srcs.size():
			_place_light(l, srcs[i][1], 0.8)
		else:
			l.visible = false


func _source_pos(s: Dictionary) -> Vector3:
	var node: Node2D = s.node
	var p: Vector2 = node.global_position + s.offset
	if node is Player:
		# a lantern: held at your side (its 2D offset upward is its height)
		var base := to3d(node.global_position)
		return Vector3(p.x / World.TILE, base.y + 0.9, base.z)
	var x := p.x / World.TILE
	var z := p.y / World.TILE
	return Vector3(x, ground_at(x, z) + 0.6, z)


func _place_light(l: OmniLight3D, s: Dictionary, k: float) -> void:
	var r: float = s.radius
	if s.flicker > 0.0:
		var t: float = _time + s.seed
		r *= 1.0 + (sin(t * 7.3) * 0.5 + sin(t * 17.1) * 0.3 + sin(t * 31.7) * 0.2) * s.flicker
	l.position = _source_pos(s)
	l.omni_range = maxf(r / World.TILE * 1.45, 0.1)
	l.light_energy = s.energy * 1.6 * k
	l.light_color = s.color
	l.visible = s.energy > 0.01 and r > 1.0


# --- 2D things in the 3D view ------------------------------------------------------

const DECAL_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_toon, specular_disabled;
uniform sampler2D dec0 : source_color, filter_nearest;
uniform sampler2D dec1 : source_color, filter_nearest;
uniform vec4 r0;   // x, z of its corner, then its size (tiles)
uniform vec4 r1;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX += NORMAL * 0.012;
}
void fragment() {
	vec2 u0 = (wp.xz - r0.xy) / r0.zw;
	vec2 u1 = (wp.xz - r1.xy) / r1.zw;
	vec4 c = vec4(0.0);
	if (u0.x >= 0.0 && u0.y >= 0.0 && u0.x < 1.0 && u0.y < 1.0) {
		c = texture(dec0, u0);
	} else if (u1.x >= 0.0 && u1.y >= 0.0 && u1.x < 1.0 && u1.y < 1.0) {
		c = texture(dec1, u1);
	}
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ROUGHNESS = 1.0;
}
"""


func _setup_canvases() -> void:
	_overlay_canvas = RenderingServer.canvas_create()
	_overlay_item = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_overlay_item, _overlay_canvas)
	_decal_canvas = RenderingServer.canvas_create()
	_decal_item = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_decal_item, _decal_canvas)
	for i in 2:
		var d := SubViewport.new()
		d.size = DECAL_TILES * World.TILE
		d.transparent_bg = true
		d.disable_3d = true
		d.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		d.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(d)
		_decal_vps.append(d)


func _build_decals() -> void:
	_decal_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = DECAL_SHADER
	_decal_mat.shader = sh
	_decal_mat.set_shader_parameter("dec0", _decal_vps[0].get_texture())
	_decal_mat.set_shader_parameter("dec1", _decal_vps[1].get_texture())
	for m in _ground_meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = _decal_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)


## Moves the 2D effects (for drawing only) onto the canvases the 3D view
## uses, or back into the 2D world.
func _move_2d(on: bool) -> void:
	if _moved.is_empty():
		for ch in main.get_children():
			if ch is Traps or ch is Mist or ch is Bombs or ch is Wind:
				_moved.append([ch, true])
			elif ch is Fx:
				_moved.append([ch, false])
	for m in _moved:
		var ci: CanvasItem = m[0]
		if not is_instance_valid(ci):
			continue
		var to: RID = (_decal_item if m[1] else _overlay_item) if on else main.get_canvas_item()
		RenderingServer.canvas_item_set_parent(ci.get_canvas_item(), to)


## The floor-drawing canvas follows each camera; the cells it covers become
## the stretch the traps, mist and wind draw.
func _update_decals(ts: Array[Vector3]) -> void:
	if _decal_mat == null:
		return
	var cover := Rect2i()
	for i in 2:
		var r := Vector4(-9999.0, -9999.0, 1.0, 1.0)
		if i < ts.size():
			var o := Vector2i(int(floor(ts[i].x)) - DECAL_TILES.x / 2, int(floor(ts[i].z)) - DECAL_TILES.y * 2 / 3)
			r = Vector4(o.x, o.y, DECAL_TILES.x, DECAL_TILES.y)
			RenderingServer.viewport_set_canvas_transform(_decal_vps[i].get_viewport_rid(), _decal_canvas,
				Transform2D(0.0, -Vector2(o * World.TILE)))
			var rect := Rect2i(o, DECAL_TILES)
			cover = rect if cover.size == Vector2i.ZERO else cover.merge(rect)
		_decal_mat.set_shader_parameter("r%d" % i, r)
	World.fx_rect = cover


## Maps 2D world pixels to the screen as the ground plane around the
## camera's spot looks: exact there, close enough a little way off.
func _place_overlay(v: Dictionary, at: Vector2, g: Vector3) -> void:
	if v.display == null:
		return
	var c: Camera3D = v.cam
	var o := c.unproject_position(g)
	var ex := c.unproject_position(g + Vector3(1, 0, 0)) - o
	var ez := c.unproject_position(g + Vector3(0, 0, 1)) - o
	var xf := Transform2D(ex / World.TILE, ez / World.TILE, Vector2.ZERO)
	xf.origin = o - xf.basis_xform(at)
	RenderingServer.viewport_set_canvas_transform((v.display as Viewport).get_viewport_rid(), _overlay_canvas, xf)
