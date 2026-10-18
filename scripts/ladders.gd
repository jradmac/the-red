class_name Ladders
extends Node2D
## Ladders (an item): set one against a crypt wall that's only one brick thick
## and it hooks over the top, a ladder down each face. Face it and press Z to
## climb: up the ladder, over the top, and a hop down on the far side (you
## never walk along the wall). It stays where you put it, and works from
## either side. Only the crypt's brick walls will hold one, and only a wall
## inside one part of the labyrinth: it won't take you past a locked door.

const WALL_H := 1.0                  ## a crypt wall's top (Terrain3D.TOP_H)
const WOOD := Color("8a5a32")

var world: World
var view: View3D
var master_gate := Vector2i(-1, -1)
## Set by main: which part of the labyrinth a cell is in (Doors.section_of,
## the parts the locked doors divide it into). Both sides must be the same.
var area_of: Callable
var ladders := {}                    ## wall cell -> the way it was first climbed (Vector2i)
var _root3d: Node3D
var _built3d := {}                   ## wall cell -> Node3D


func setup(w: World) -> void:
	world = w


## Why a ladder can't go on `wall` from `from` ("" = it can).
func why_not(wall: Vector2i, from: Vector2i) -> String:
	var dir := wall - from
	if absi(dir.x) + absi(dir.y) != 1:
		return "FACE A WALL TO SET THE LADDER AGAINST IT."
	if world.tile_at(wall) != "#" or world.biome_at(wall) != World.B_CRYPT or world.village_solid.has(wall) \
			or world.cliffs.has(wall) or wall == master_gate:
		return "A LADDER ONLY HOLDS ON THE CRYPT'S BRICK WALLS."
	if wall.x <= 0 or wall.y <= 0 or wall.x >= world.width - 1 or wall.y >= world.height - 1:
		return "THAT'S THE OUTER WALL. THERE'S NOTHING BEYOND IT."
	if ladders.has(wall):
		return "THERE'S ALREADY A LADDER HERE."
	if not _floor(wall + dir):
		return "THIS WALL IS TOO THICK -- THERE'S NO FLOOR ON THE OTHER SIDE."
	if not _same_area(from, wall + dir):
		return "THE OTHER SIDE LIES BEYOND A LOCKED DOOR. THE LADDER WON'T TAKE YOU THERE."
	return ""


func _same_area(a: Vector2i, b: Vector2i) -> bool:
	return not area_of.is_valid() or area_of.call(a) == area_of.call(b)


func _floor(c: Vector2i) -> bool:
	return world.is_walkable(c) and not world.blockers.has(c)


## Sets a ladder on the wall in front of you. Returns the message ("!" first: it didn't).
func place(wall: Vector2i, from: Vector2i) -> String:
	var why := why_not(wall, from)
	if why != "":
		return "!" + why
	ladders[wall] = wall - from
	Sfx.play("trap_thud", -6.0, 0.05, 1.3)
	queue_redraw()
	return "YOU SET THE LADDER AGAINST THE WALL AND HOOK IT OVER THE TOP. FACE IT AND PRESS Z TO CLIMB OVER."


## Facing a laddered wall from `from`: where you'd land on the other side,
## or (-1, -1) if you can't go over here.
func landing(wall: Vector2i, from: Vector2i) -> Vector2i:
	if not ladders.has(wall):
		return Vector2i(-1, -1)
	var land := wall + (wall - from)
	return land if _floor(land) and _same_area(from, land) else Vector2i(-1, -1)


## Loading a saved game.
func restore(list: Array) -> void:
	for e in list:
		ladders[Vector2i(int(e[0]), int(e[1]))] = Vector2i(int(e[2]), int(e[3]))
	queue_redraw()


func save_list() -> Array:
	var out := []
	for c in ladders:
		out.append([c.x, c.y, ladders[c].x, ladders[c].y])
	return out


# --- drawing -------------------------------------------------------------------------

## 2D: the ladder up the wall's face, its top hooked over.
func _draw() -> void:
	for c in ladders:
		var o: Vector2 = world.cell_to_position(c)
		var vertical: bool = (ladders[c] as Vector2i).x == 0
		if vertical:
			for x in [3.0, 11.0]:
				draw_rect(Rect2(o + Vector2(x, -4), Vector2(2, 22)), Color("2a1a10"))
				draw_rect(Rect2(o + Vector2(x, -4), Vector2(1, 22)), WOOD)
			for y in range(-2, 18, 4):
				draw_rect(Rect2(o + Vector2(4, y), Vector2(8, 1)), WOOD.lightened(0.2))
				draw_rect(Rect2(o + Vector2(4, y + 1), Vector2(8, 1)), Color("2a1a10"))
		else:
			for y in [2.0, 11.0]:
				draw_rect(Rect2(o + Vector2(-3, y), Vector2(22, 2)), Color("2a1a10"))
				draw_rect(Rect2(o + Vector2(-3, y), Vector2(22, 1)), WOOD)
			for x in range(-1, 19, 4):
				draw_rect(Rect2(o + Vector2(x, 3), Vector2(1, 8)), WOOD.lightened(0.2))


func _process(_delta: float) -> void:
	if view == null or view.root == null:
		return
	if _root3d == null:
		_root3d = Node3D.new()
		view.root.add_child(_root3d)
	for c in ladders:
		if not _built3d.has(c):
			var n := _ladder3d(c, ladders[c])
			_root3d.add_child(n)
			LightStyle.convert(n)
			_built3d[c] = n


## 3D: a ladder leaning on each face of the wall, its rails poking up over the top.
func _ladder3d(wall: Vector2i, dir: Vector2i) -> Node3D:
	var n := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = WOOD
	mat.roughness = 1.0
	var center := Vector3(wall.x + 0.5, 0.0, wall.y + 0.5)
	var d := Vector3(dir.x, 0, dir.y)
	var across := Vector3(-d.z, 0, d.x)
	for side: float in [-1.0, 1.0]:
		var out: Vector3 = d * side            # away from the wall, on this face (-1: the side it was set from)
		var face: Vector3 = center + out * 0.5
		var base: Vector3 = face + out * 0.34
		var top: Vector3 = face + out * 0.02 + Vector3(0, WALL_H + 0.18, 0)
		for s: float in [-1.0, 1.0]:
			_bar(n, base + across * 0.17 * s, top + across * 0.17 * s, 0.055, mat)
		for k in 6:
			var t := (k + 0.6) / 6.6
			var p: Vector3 = base.lerp(top, t)
			_bar(n, p - across * 0.17, p + across * 0.17, 0.04, mat)
	return n


func _bar(parent: Node3D, a: Vector3, b: Vector3, thick: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(thick, a.distance_to(b), thick)
	box.material = mat
	mi.mesh = box
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up).normalized()
	mi.transform = Transform3D(Basis(side, up, fwd), (a + b) * 0.5)
	parent.add_child(mi)
