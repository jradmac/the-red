class_name Arches
extends Node2D
## Stone archways where the crypts open onto the outdoors. Drawn above the
## hero so you walk *under* them: a clear "stepping outside" moment.
##
## In the 3D view each one is a real stone arch (built here, into the view's
## scene, once it's ready): a ring of crypt stone over the gap, its crown above
## the wall tops, reaching a little past the front of its tile -- so a
## character passing through is hidden by it from the shoulders up (sprites
## stand on an upright plane just past their tile's front edge:
## sprite3d_depth.gdshader), and one standing in front of it is drawn over it.

var world: World
var _built3d := false

const SPRING := 0.95      ## where the arch's curve starts (tiles up): the wall tops
const CROWN := 1.62       ## the underside of the arch at its top, over the hero's head
const TOP := 2.75          ## the top of the stonework (tall, as in the 2D art)
const REACH := 0.66       ## half its width (the gap is 0.5 each side of centre)
const FRONT := 0.66       ## how far it reaches toward the camera from the tile's centre
const BACK := -0.42
const SEGMENTS := 10


## The stone arch over each gateway in the 3D view. Off: a gateway is just
## the gap in the wall, open to the sky -- a lintel over it only got in the
## way of the hero walking through (he showed above it).
const BUILD_3D := false


func _ready() -> void:
	z_index = 3


func _process(_delta: float) -> void:
	queue_redraw()
	if not _built3d and BUILD_3D:
		var v = get_parent().get("view3d")
		if v != null and v.root != null and v.get("_built") == true:
			_build3d(v)
			_built3d = true


# --- 3D ------------------------------------------------------------------------------

func _build3d(v: View3D) -> void:
	var holder := Node3D.new()
	holder.name = "Arches3D"
	v.root.add_child(holder)
	var face := _stone("res://assets/w3d/crypt_side.png")
	var top := _stone("res://assets/w3d/crypt_cap_top.png")
	for c in world.arches:
		var front: bool = world.arches[c] == "front"
		# a north-south passage: the arch faces the camera and reaches past the
		# tile's front; an east-west one spans it north to south (turned), its
		# south half reaching over the wall in front
		var zf := FRONT if front else 0.42
		var zb := BACK
		var n := MeshInstance3D.new()
		n.mesh = _arch_mesh(zf, zb, front)
		n.material_override = face
		n.position = Vector3(c.x + 0.5, v.ground_at(c.x + 0.5, c.y + 0.5), c.y + 0.5)
		if not front:
			n.rotation.y = PI / 2.0
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(n)
		# a capstone along the top, and the keystone at the crown
		var cap := MeshInstance3D.new()
		cap.mesh = Objects3D.box_mesh(Vector3(-REACH - 0.03, TOP, zb - 0.03), Vector3(REACH + 0.03, TOP + 0.08, zf + 0.03))
		cap.material_override = top
		n.add_child(cap)
		var key := MeshInstance3D.new()
		key.mesh = Objects3D.box_mesh(Vector3(-0.1, CROWN - 0.05, zf - 0.02), Vector3(0.1, TOP - 0.04, zf + 0.05))
		key.material_override = top
		n.add_child(key)
	LightStyle.convert(holder)


func _stone(path: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.texture_repeat = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.74, 0.68, 0.88)   # the crypt walls' cold violet cast
	return m


## The arch, in its own frame: the gap runs along z (x from -0.5 to 0.5); the
## stone fills the block from SPRING up to TOP, x within REACH, z from `zb` to
## `zf`, around a half-ellipse opening.
func _arch_mesh(zf: float, zb: float, jambs: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# angles from the west side (PI) over to the east (0), with the two
	# block corners among them so the stone reaches right into the corners
	var corner := atan2(TOP - SPRING, REACH)
	var angles: Array[float] = []
	for i in SEGMENTS + 1:
		angles.append(PI * (1.0 - float(i) / SEGMENTS))
	angles.append(corner)
	angles.append(PI - corner)
	angles.sort()
	angles.reverse()
	var inner: Array[Vector2] = []
	var outer: Array[Vector2] = []
	for a in angles:
		inner.append(Vector2(cos(a) * 0.5, SPRING + sin(a) * (CROWN - SPRING)))
		var dir := Vector2(cos(a), sin(a))
		var tx := REACH / maxf(absf(dir.x), 0.0001)
		var ty := (TOP - SPRING) / maxf(dir.y, 0.0001)
		var t := minf(tx, ty)
		outer.append(Vector2(dir.x * t, SPRING + dir.y * t))
	for i in angles.size() - 1:
		var a0 := inner[i]
		var a1 := inner[i + 1]
		var b0 := outer[i]
		var b1 := outer[i + 1]
		for z: float in [zf, zb]:   # the faces
			_q(st, Vector3(b0.x, b0.y, z), Vector3(b1.x, b1.y, z), Vector3(a1.x, a1.y, z), Vector3(a0.x, a0.y, z),
				Vector3(0, 0, signf(z)))
		# the underside, facing down into the gap
		var mid := (a0 + a1) / 2.0
		var down := Vector3(-mid.x, -(mid.y - SPRING) - 0.2, 0).normalized()
		_q(st, Vector3(a0.x, a0.y, zf), Vector3(a1.x, a1.y, zf), Vector3(a1.x, a1.y, zb), Vector3(a0.x, a0.y, zb), down)
	# the block's ends and top
	_q(st, Vector3(-REACH, TOP, zf), Vector3(-REACH, TOP, zb), Vector3(-REACH, SPRING, zb), Vector3(-REACH, SPRING, zf), Vector3.LEFT)
	_q(st, Vector3(REACH, TOP, zb), Vector3(REACH, TOP, zf), Vector3(REACH, SPRING, zf), Vector3(REACH, SPRING, zb), Vector3.RIGHT)
	_q(st, Vector3(-REACH, TOP, zb), Vector3(REACH, TOP, zb), Vector3(REACH, TOP, zf), Vector3(-REACH, TOP, zf), Vector3.UP)
	if jambs:
		# short stone posts down to the ground at the front, either side of the gap
		for sx: float in [-1.0, 1.0]:
			var x0: float = 0.5 * sx
			var x1: float = REACH * sx
			var lo := minf(x0, x1)
			var hi := maxf(x0, x1)
			_q(st, Vector3(lo, SPRING, zf), Vector3(hi, SPRING, zf), Vector3(hi, 0.0, zf), Vector3(lo, 0.0, zf), Vector3.BACK)
			_q(st, Vector3(x0, SPRING, zf), Vector3(x0, SPRING, 0.5), Vector3(x0, 0.0, 0.5), Vector3(x0, 0.0, zf), Vector3(-sx, 0, 0))
			_q(st, Vector3(x1, SPRING, zf), Vector3(x1, SPRING, 0.5), Vector3(x1, 0.0, 0.5), Vector3(x1, 0.0, zf), Vector3(sx, 0, 0))
	return st.commit()


## A quad (a, b, c, d) facing `normal`, its texture laid on by where it is
## (a texture a tile).
static func _q(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	var n := (b - a).cross(d - a)
	var axis := 2   # which plane to lay the texture in
	if absf(n.x) > absf(n.y) and absf(n.x) > absf(n.z):
		axis = 0
	elif absf(n.y) > absf(n.z):
		axis = 1
	# light from above and in front: tops brightest, the underside of the
	# opening deep in shadow (so the curve of the arch reads)
	var shade := 0.82
	if normal.y > 0.9:
		shade = 1.0
	elif normal.y < -0.1:
		shade = 0.32
	elif absf(normal.x) > 0.9:
		shade = 0.6
	elif normal.z < -0.5:
		shade = 0.55
	for p in [a, b, c, a, c, d]:
		var v: Vector3 = p
		var uv := Vector2(v.x, -v.y) if axis == 2 else (Vector2(v.z, -v.y) if axis == 0 else Vector2(v.x, v.z))
		st.set_uv(uv)
		st.set_color(Color(shade, shade, shade))
		st.set_normal(normal)
		st.add_vertex(v)
