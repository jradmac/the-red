class_name Rare3D
extends Node3D
## The rare lands in the 3D view: their liquids and their air.
##
## Liquids (shaders/liquid.gdshader) laid over the water tiles -- the open sea
## off a beach (out past the map's edge), the jungle's murky channels, frozen
## tarns in the snow, lava in the volcano (its rivers, and the flows across the
## ground that burn), molten gold in the vault.
## The air, round wherever you are: snow drifting down; ash falling and embers
## rising off the lava; gold dust twinkling; fireflies in the jungle at night.

const LIQUID_SHADER: Shader = preload("res://shaders/liquid.gdshader")
const KIND := {World.R_BEACH: 0, World.R_JUNGLE: 1, World.R_SNOW: 2, World.R_VOLCANO: 3, World.R_GOLD: 4}

var view: View3D
var world: World
var _air := {}      ## land -> CPUParticles3D (one or two)
var _any := false


func build(v: View3D) -> void:
	view = v
	world = v.world
	if not world.any_rare:
		return   # (no rare land in this labyrinth: nothing to build)
	var wm_border := WorldMesh.BORDER
	var cells := {}   # kind -> [cell, height]
	for y in range(-wm_border, world.height + wm_border):
		for x in range(-wm_border, world.width + wm_border):
			var c := Vector2i(x, y)
			var land := world.rare_at(c)
			if world.is_sea(c):
				land = World.R_BEACH
			if land == World.R_NONE:
				continue
			_any = true
			var inside := x >= 0 and y >= 0 and x < world.width and y < world.height
			var sea := world.is_sea(c)
			var h := -1.0
			if sea or (inside and world.tile_at(c) == "~"):
				h = WorldMesh.WATER_Y + 0.03
			elif inside and world.lava.has(c):
				h = view.ground_at(x + 0.5, y + 0.5) + 0.02   # a flow over the ground
			if h > -0.9:
				var k: int = KIND[land]
				if not cells.has(k):
					cells[k] = []
				cells[k].append([c, h])
	if not _any:
		return
	var shore := _shore_map()
	for k in cells:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for e in cells[k]:
			var c: Vector2i = e[0]
			var h: float = e[1]
			var a := Vector3(c.x, h, c.y)
			var q := [a, a + Vector3(1, 0, 0), a + Vector3(1, 0, 1), a + Vector3(0, 0, 1)]
			for i in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP)
				st.add_vertex(q[i])
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var m := ShaderMaterial.new()
		m.shader = LIQUID_SHADER
		m.set_shader_parameter("kind", k)
		m.set_shader_parameter("shore_map", shore)
		m.set_shader_parameter("map_rect", Vector4(-wm_border, -wm_border, world.width + wm_border * 2, world.height + wm_border * 2))
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_make_air()


## How near the land each tile is (foam on the sea's edge, crust on the lava's).
func _shore_map() -> ImageTexture:
	var b := WorldMesh.BORDER
	var w := world.width + b * 2
	var h := world.height + b * 2
	var img := Image.create(w, h, false, Image.FORMAT_R8)
	for y in h:
		for x in w:
			var c := Vector2i(x - b, y - b)
			var near := 0.0
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var n: Vector2i = c + d
				if n.x >= 0 and n.y >= 0 and n.x < world.width and n.y < world.height and world.is_walkable(n) and not world.lava.has(n):
					near = 1.0
			img.set_pixel(x, y, Color(near, 0, 0))
	return ImageTexture.create_from_image(img)


func _make_air() -> void:
	_air[World.R_SNOW] = [_particles(Color(1, 1, 1, 0.95), 0.07, 260, Vector3(0, -0.9, 0), 0.4, 9.0, false)]
	_air[World.R_VOLCANO] = [_particles(Color(0.42, 0.38, 0.38, 0.8), 0.06, 160, Vector3(0, -0.5, 0), 0.3, 10.0, false),
		_particles(Color(1.0, 0.55, 0.15, 1.0), 0.05, 60, Vector3(0, 1.1, 0), 0.5, 3.5, true)]
	_air[World.R_GOLD] = [_particles(Color(1.0, 0.9, 0.45, 1.0), 0.045, 120, Vector3(0, 0.15, 0), 0.25, 4.0, true)]
	_air[World.R_JUNGLE] = [_particles(Color(0.75, 1.0, 0.45, 1.0), 0.05, 40, Vector3(0, 0.05, 0), 0.35, 6.0, true)]
	_air[World.R_BEACH] = [_particles(Color(1, 1, 1, 0.6), 0.04, 30, Vector3(0.4, 0.05, 0), 0.4, 6.0, false)]


func _particles(col: Color, size: float, amount: int, vel: Vector3, spread: float, life: float, glow: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(15, 3.5, 11)
	p.direction = vel.normalized() if vel.length() > 0.0 else Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = vel.length() * 0.7
	p.initial_velocity_max = vel.length() * 1.3
	p.gravity = Vector3.ZERO
	p.angular_velocity_min = 0.0
	p.angular_velocity_max = 0.0
	p.tangential_accel_min = -spread
	p.tangential_accel_max = spread
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	if glow:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 1.5
	q.material = m
	p.mesh = q
	p.color = col
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	p.visible = false
	add_child(p)
	return p


## Each frame: the air of the land you're in, round the camera's spot.
func update() -> void:
	if not _any:
		return
	var main = view.main
	var pl: Player = main.player
	var land := world.rare_at(pl.cell)
	var night: bool = main.day.light < 0.5
	var t: Vector3 = view.targets()[0]
	for k in _air:
		var on: bool = k == land and (k != World.R_JUNGLE or night)
		for p in _air[k]:
			var ps: CPUParticles3D = p
			if on != ps.emitting:
				ps.emitting = on
			if on:
				ps.visible = true
			ps.global_position = t + Vector3(0, 3.2, 0)
