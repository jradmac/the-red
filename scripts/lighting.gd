class_name Lighting
extends CanvasLayer
## Darkness over the whole screen, cut open by light sources.
## Anything can register a light: add_light(node, offset, radius, color, ...).
##
## Walls cast shadows: every frame a tiny mask of the wall tiles on screen is
## handed to the shader (see shaders/lighting_core.gdshaderinc). A second,
## additive overlay adds a warm bloom right around each flame.

const MAX_LIGHTS := 24
const SHADER := preload("res://shaders/lighting.gdshader")
const GLOW_SHADER := preload("res://shaders/glow.gdshader")

var world: World   ## set by main; without it nothing casts shadows
var day: DayCycle  ## set by main: daylight washes the darkness away
var sun_glow := 0.0  ## 0..1, set by main while a sunstone blazes: daylight of your own
## A second view of the same lights (the other half of a split screen): it
## draws `source`'s lights from its own viewport's camera.
var source: Lighting
var views: Array = []
var _rect: ColorRect
var _glow: ColorRect
var _mat: ShaderMaterial
var _glow_mat: ShaderMaterial
var _sources: Array[Dictionary] = []
var _time := 0.0
var _mask_img: Image
var _mask_tex: ImageTexture
var _mask_rect := Rect2i()


func _ready() -> void:
	layer = 1
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect = _make_rect(_mat)
	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = GLOW_SHADER
	_glow_mat.set_shader_parameter("additive", true)
	_glow = _make_rect(_glow_mat)


func _make_rect(mat: ShaderMaterial) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = mat
	add_child(r)
	return r


## Registers a light that follows `node` (plus `offset`). Returns the light's
## dictionary so callers can change radius/energy later (e.g. lantern fuel).
## `shadows` = false for lights that should shine through walls (glows that
## sit inside a wall, say).
func add_light(node: Node2D, offset: Vector2, radius: float, color: Color,
		energy: float = 1.0, flicker: float = 0.0, shadows: bool = true) -> Dictionary:
	var src := {
		"node": node, "offset": offset, "radius": radius, "color": color,
		"energy": energy, "flicker": flicker, "seed": randf() * 100.0, "shadows": shadows,
		"glow": 1.0,
	}
	_sources.append(src)
	return src


func _process(delta: float) -> void:
	_time += delta
	var xf := get_viewport().get_canvas_transform()
	var size := get_viewport().get_visible_rect().size
	var lights: Array[Vector4] = []
	var colors: Array[Vector4] = []
	var glows: Array[Vector4] = []
	var srcs: Array[Dictionary] = source._sources if source != null else _sources
	if source != null:
		world = source.world
		day = source.day
	for s in srcs:
		if not is_instance_valid(s.node):
			continue
		var p: Vector2 = xf * (s.node.global_position + s.offset)
		var r: float = s.radius
		if s.flicker > 0.0:
			var t: float = _time + s.seed
			var n := sin(t * 7.3) * 0.5 + sin(t * 17.1) * 0.3 + sin(t * 31.7) * 0.2
			r *= 1.0 + n * s.flicker
		var reach := r * 1.7
		# Skip lights that are fully off screen.
		if p.x < -reach or p.y < -reach or p.x > size.x + reach or p.y > size.y + reach:
			continue
		lights.append(Vector4(p.x, p.y, r, s.energy))
		var c: Color = s.color
		colors.append(Vector4(c.r, c.g, c.b, 1.0 if s.shadows else 0.0))
		glows.append(Vector4(p.x, p.y, r, s.energy * s.glow))
		if lights.size() >= MAX_LIGHTS:
			break
	var count := lights.size()
	while lights.size() < MAX_LIGHTS:
		lights.append(Vector4.ZERO)
		colors.append(Vector4.ZERO)
		glows.append(Vector4.ZERO)
	_update_mask(xf, size)
	for m in [_mat, _glow_mat]:
		m.set_shader_parameter("light_count", count)
		m.set_shader_parameter("light_colors", colors)
		m.set_shader_parameter("screen_size", size)
	_mat.set_shader_parameter("lights", lights)
	var dl := day.light if day != null else 0.0
	var tint := Color(1, 1, 1).lerp(Color(1.0, 0.72, 0.5), day.warmth() if day != null else 0.0)
	if sun_glow > dl:
		tint = tint.lerp(Color(1.0, 0.9, 0.72), (sun_glow - dl) / maxf(sun_glow, 0.01))
		dl = sun_glow
	for m in [_mat, _glow_mat]:
		m.set_shader_parameter("daylight", dl)
		m.set_shader_parameter("day_tint", Vector3(tint.r, tint.g, tint.b))
	_glow_mat.set_shader_parameter("lights", glows)


## Removes a light added with add_light.
func remove_light(src: Dictionary) -> void:
	_sources.erase(src)


## Call when walls or doors change (a door opened).
func refresh_mask() -> void:
	_mask_rect = Rect2i()
	for v in views:
		if is_instance_valid(v):
			v._mask_rect = Rect2i()


## Rebuilds the wall mask for the tiles on screen (plus a margin so lights just
## off screen still cast shadows correctly).
func _update_mask(xf: Transform2D, size: Vector2) -> void:
	if world == null or world.width == 0:
		return
	var inv := xf.affine_inverse()
	var tl := inv * Vector2.ZERO
	var br := inv * size
	var margin := 6
	var x0 := int(floor(tl.x / World.TILE)) - margin
	var y0 := int(floor(tl.y / World.TILE)) - margin
	var x1 := int(ceil(br.x / World.TILE)) + margin
	var y1 := int(ceil(br.y / World.TILE)) + margin
	var r := Rect2i(x0, y0, x1 - x0, y1 - y0)
	if r != _mask_rect:
		var resized := _mask_img == null or r.size != _mask_rect.size
		_mask_rect = r
		if resized:
			_mask_img = Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGB8)
		for y in r.size.y:
			for x in r.size.x:
				var c := Vector2i(x0 + x, y0 + y)
				var v := 0.0
				if world.village_solid.has(c):
					v = 0.0    # houses, lamps, fences: drawn as sprites, no square shadow
				elif world.cliffs.has(c):
					v = 0.15   # a cliff: low enough for light to spill over
				elif world.tile_at(c) == "#":
					var b := world.biome_at(c)
					if b == 1 or b == 4 or b == 5:
						v = 0.25   # trees: light filters through
					else:
						v = 0.5 if world.tile_at(c + Vector2i.DOWN) != "#" else 1.0
				elif world.doors.has(c) and world.blockers.has(c):
					v = 1.0   # closed doors block light too
				var sky := 1.0 if world.is_outdoors(c) else 0.0
				_mask_img.set_pixel(x, y, Color(v, sky, 0.0))
		if resized or _mask_tex == null:
			_mask_tex = ImageTexture.create_from_image(_mask_img)
		else:
			_mask_tex.update(_mask_img)
	var origin := xf * Vector2(x0 * World.TILE, y0 * World.TILE)
	var tile_px := xf.x.x * World.TILE
	for m in [_mat, _glow_mat]:
		m.set_shader_parameter("wall_mask", _mask_tex)
		m.set_shader_parameter("outdoor_mask", _mask_tex)
		m.set_shader_parameter("mask_origin", origin)
		m.set_shader_parameter("mask_cells", Vector2(r.size))
		m.set_shader_parameter("tile_px", tile_px)
