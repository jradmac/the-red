class_name Traps3D
extends Node3D
## The springing parts of the traps, as models in the 3D view: steel spears
## that shoot up out of the floor, darts that streak in from the wall, rocks
## that crash down from above, the green cloud from a gas vent. (What lies on
## the floor -- plates, trapdoors, bear traps, thorns -- is drawn on the
## ground itself.) Walls hide them like anything else.

var view: View3D
var traps: Traps
var _parts := {}     ## cell -> {kind, node, ...}
var _spear_mesh: ArrayMesh
var _row_mesh: ArrayMesh


func build(v: View3D) -> void:
	view = v
	traps = v.main.get("traps")
	if traps == null:
		return
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("dfe4f0")
	steel.roughness = 0.4
	steel.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	_spear_mesh = _spears(PackedVector2Array([Vector2(-0.25, -0.15), Vector2(0.0, -0.22), Vector2(0.25, -0.15),
		Vector2(-0.22, 0.12), Vector2(0.05, 0.16), Vector2(0.24, 0.1)]))
	_row_mesh = _spears(PackedVector2Array([Vector2(-0.4, 0.0), Vector2(-0.2, 0.02), Vector2(0.0, 0.0), Vector2(0.2, 0.02), Vector2(0.4, 0.0)]))
	var rock := StandardMaterial3D.new()
	rock.albedo_texture = load("res://assets/w3d/rock_side.png")
	rock.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	rock.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	rock.cull_mode = BaseMaterial3D.CULL_DISABLED
	rock.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var gas := StandardMaterial3D.new()
	gas.albedo_color = Color(0.45, 0.72, 0.22, 0.35)
	gas.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gas.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gas.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dart := StandardMaterial3D.new()
	dart.albedo_color = Color(0.9, 0.9, 1.0)
	dart.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for c in traps.traps:
		var tr: Dictionary = traps.traps[c]
		var n := Node3D.new()
		n.position = Vector3(c.x + 0.5, view.ground_at(c.x + 0.5, c.y + 0.5), c.y + 0.5)
		n.visible = false
		add_child(n)
		var part := {"node": n}
		match tr.kind:
			"spike_plate", "spike_row":
				var mi := MeshInstance3D.new()
				mi.mesh = _spear_mesh if tr.kind == "spike_plate" else _row_mesh
				mi.material_override = steel
				# a row runs across the corridor
				if tr.kind == "spike_row" and view.world.tile_at(c + Vector2i.LEFT) == "#":
					mi.rotation.y = PI / 2.0
				n.add_child(mi)
				part.mesh = mi
			"rockfall", "masonry":
				var col := Color("7a6c60") if tr.kind == "rockfall" else Color("c8bca6")
				var m := rock.duplicate() as StandardMaterial3D
				m.albedo_color = col
				part.mat = m
				part.rocks = []
				for k in 3:
					var r := MeshInstance3D.new()
					r.mesh = Objects3D.rock_mesh()
					r.material_override = m
					r.scale = Vector3.ONE * (0.2 + 0.05 * k)
					n.add_child(r)
					part.rocks.append(r)
			"dart_plate":
				var mi := MeshInstance3D.new()
				mi.mesh = Objects3D.box_mesh(Vector3(-0.02, -0.02, -0.16), Vector3(0.02, 0.02, 0.16))
				mi.material_override = dart
				n.add_child(mi)
				part.mesh = mi
				var from := Vector3(0, 0.55, -1.0)
				if view.world.tile_at(c + Vector2i.LEFT) == "#":
					from = Vector3(-1.0, 0.55, 0)
				elif view.world.tile_at(c + Vector2i.RIGHT) == "#":
					from = Vector3(1.0, 0.55, 0)
				part.from = from
				mi.look_at_from_position(from, Vector3(0, 0.3, 0))
			"gas_vent":
				var mi := MeshInstance3D.new()
				var sp := SphereMesh.new()
				sp.radial_segments = 10
				sp.rings = 6
				mi.mesh = sp
				mi.material_override = gas
				n.add_child(mi)
				part.mesh = mi
			_:
				n.queue_free()
				continue
		_parts[c] = part


func _process(_delta: float) -> void:
	if view == null or not view.active or traps == null:
		return
	var near: Array[Vector3] = view.targets()
	for c in _parts:
		var part: Dictionary = _parts[c]
		var n: Node3D = part.node
		var close := false
		for t in near:
			if absf(t.x - c.x) < 22.0 and absf(t.z - c.y) < 22.0:
				close = true
		if not close or not traps.traps.has(c):
			n.visible = false
			continue
		var tr: Dictionary = traps.traps[c]
		match tr.kind:
			"spike_plate", "spike_row":
				var h := traps.spear_height(tr) / 10.0
				n.visible = h > 0.01
				(part.mesh as Node3D).scale = Vector3(1, maxf(h, 0.01), 1)
			"rockfall", "masonry":
				var k: float = tr.t
				n.visible = k >= 0.0 and k < 1.5
				if n.visible:
					var y := lerpf(3.8, 0.1, pow(clampf(k / 0.75, 0.0, 1.0), 2.0))
					var rocks: Array = part.rocks
					for i in rocks.size():
						var r: Node3D = rocks[i]
						var a := float(i) * 2.1
						r.position = Vector3(cos(a) * 0.18, y + float(i) * 0.3 * (1.0 if k < 0.75 else 0.0), sin(a) * 0.14)
						r.rotation = Vector3(k * 4.0 + i, k * 3.0, 0)
					(part.mat as StandardMaterial3D).albedo_color.a = 1.0 if k < 0.75 else 1.0 - (k - 0.75) / 0.75
			"dart_plate":
				var k: float = tr.t
				n.visible = k >= 0.0 and k < 0.35
				if n.visible:
					var mi: Node3D = part.mesh
					mi.position = (part.from as Vector3).lerp(Vector3(0, 0.3, 0), k / 0.35)
			"gas_vent":
				n.visible = tr.cloud > 0.0
				if n.visible:
					var k: float = 1.0 - tr.cloud / Traps.VENT_CLOUD
					var r := (10.0 + 14.0 * sin(clampf(k, 0.0, 1.0) * PI * 0.5)) / 16.0
					var mi: Node3D = part.mesh
					mi.scale = Vector3(r * 2.0, r * 1.2, r * 2.0)
					mi.position.y = r * 0.4


## Thin steel spears standing at `spots` (x, z offsets in the tile), each a
## four-sided spike 0.6 tall.
func _spears(spots: PackedVector2Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in spots:
		var b := Vector3(s.x, 0, s.y)
		var top := b + Vector3(0, 0.7, 0)
		var w := 0.06
		var corners := [b + Vector3(-w, 0, -w), b + Vector3(w, 0, -w), b + Vector3(w, 0, w), b + Vector3(-w, 0, w)]
		for i in 4:
			var p0: Vector3 = corners[i]
			var p1: Vector3 = corners[(i + 1) % 4]
			var nrm := (p1 - p0).cross(top - p0).normalized()
			if nrm.dot(p0 - b) < 0.0:
				nrm = -nrm
			for p in [p0, p1, top]:
				st.set_normal(nrm)
				st.add_vertex(p)
	return st.commit()
