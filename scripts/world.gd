class_name World
extends Node2D
## The tile map: holds the layout, answers "can I walk here?", and draws itself
## from the tile and prop sprite sheets in assets/.
##
## The layout comes from LabyrinthGenerator (a new one every run). Everything
## else only talks to the functions below (is_walkable, cell_to_position...).

const TILE := 16

## Legend (produced by LabyrinthGenerator)
##   #  wall          .  stone floor     ,  moss         w  tall grass
##   ~  dark water
##   Props (sit on the ground around them):
##   g  gravestone (blocks)   c  candles (blocks, glows)   x  skull
##   m  glowing mushrooms     b  dead bush (blocks)

signal mapped_changed

## Labyrinth size in tiles (odd numbers work best). 181 x 135 is a 3-4 hour run.
@export var map_size := Vector2i(301, 169)   # 8 zones across (~37 x 33 each): 6 landscapes' worth plus room for villages
## How far a flare maps a corridor (in walking steps).
const FLARE_CORRIDOR_REACH := 10

# Indices into assets/tiles.png (one row of 16x16 tiles).
enum { T_FLOOR_A, T_FLOOR_B, T_FLOOR_C, T_MOSS_A, T_MOSS_B, T_TALL_GRASS,
	T_WATER_A, T_WATER_B, T_WALL_TOP, T_WALL_FACE_A, T_WALL_FACE_B, T_WALL_FACE_MOSS }
# Indices into assets/props.png.
const PROP_INDEX := {"g": 0, "c": 1, "x": 2, "m": 3, "b": 4}
const WALKABLE := ".,wxm"
const C_WALL_RIM := Color("5a5170")
const C_WALL_SHADOW := Color(0, 0, 0, 0.35)

const _UNUSED := 0
const PROPS_TEX: Texture2D = preload("res://assets/props.png")

var grid: Array[String] = []
var start_cell := Vector2i(1, 1)
var goal_cell := Vector2i(1, 1)
var rooms: Array[Rect2i] = []
var seed_value := 0
var _room_grid := PackedInt32Array()   # room index per tile, -1 in corridors
## Landscape per tile (index into LabyrinthGenerator.BIOMES): 0 crypt,
## 1 forest, 2 courtyard, 3 mountain, 4 river.
var biome := PackedByteArray()
var zones: Array[Rect2i] = []
var zone_biome: Array[int] = []
var zone_names: Array[String] = []
## Gateways between the crypts and the outdoors: cell -> "front" (north-south
## passage) or "side" (east-west passage). Drawn as stone archways.
var arches := {}
## How far through the labyrinth a cell is, 0 (start) .. 1 (the master
## chamber's section). Set by main from Doors.progress.
var progress: Callable
var width := 0
var height := 0
var mapped := PackedByteArray()  ## tiles that show on the map screen
var blockers := {}  ## extra blocked cells: chests, and doors while locked
var doors := {}     ## door cell -> true (locked or not); filled by Doors
var reserved := {}  ## tiles kept clear of chests (around the master gate)
var _water_frame := 0
var _water_timer := 0.0


var _last_view := Rect2i()
var _ci: CanvasItem = self    # what the tile helpers draw on (self, or the overhead layer)
var _over: Node2D             # tall things in front of the hero, drawn over them
var focus := Vector2i(-99, -99)
## Villages (see LabyrinthGenerator._stamp_village): their walls, buildings and
## props are "#" tiles drawn by Villages, not as rock.
var villages: Array = []
var terrain3d: Terrain3D   ## the 3D walls and high ground (null / hidden: all 2D)
var nooks := {}   ## the back wall of each wide dead end in the crypt (cell -> true)
var links: Array = []   ## full-width links between maze blocks: [side, middle, side]
var link_of := {}       ## cell -> index into links
var village_solid := {}            ## cell -> what stands there ("wall", "shop", "lamp"...)
var _village_id := PackedByteArray()   ## per tile: village index + 1 inside a village's wall, else 0
## High ground (see LabyrinthGenerator._raise_land): each tile's level (0..2),
## the cliff / ledge tiles ringing raised ground ("#" walls drawn as rock
## faces), and the slopes / stairs up ("s", "w" or "e").
var heights := PackedByteArray()
var cliffs := {}
var ramps := {}
const HEIGHTS_TEX: Texture2D = preload("res://assets/heights.png")
var shaking := {}   ## cell -> seconds left: a bush or tall grass you brushed against   ## the hero's tile (set by main) for walking-behind


## Builds a brand-new labyrinth. Same seed = same labyrinth.
##
## Villages go in last: the labyrinth is built, its doors are worked out (on
## a scratch copy) to see how deep each zone lies, and then a village is
## stamped into the zone that best matches each of VILLAGE_DEPTHS -- spread
## from early on to the last stretch before eternal night (80%).
const VILLAGE_DEPTHS := [0.12, 0.33, 0.53, 0.72]


func generate(new_seed: int) -> void:
	instance = self
	seed_value = new_seed
	var banned: Array = []
	for attempt in 4:
		var gen := LabyrinthGenerator.new()
		_apply(gen.generate(map_size.x, map_size.y, new_seed))
		var depth := _zone_depths()
		var picks := _pick_village_zones(gen, depth, banned)
		if attempt == 3:
			picks = picks.filter(func(z): return not banned.has(z))   # last try: just leave those out
		var final := gen.add_villages(picks)
		_apply(final)
		# Check with the real doors: every village must come before eternal night.
		var too_deep: Array = []
		var d := Doors.new()
		d.generate(self)
		var depths := {}
		for v in villages:
			var p := d.progress(v.gates[0])
			if p >= DayCycle.NO_MORE_DAYS_AT - 0.02:
				too_deep.append(v.zone)
			depths[v.zone] = p
		# and spread out: two villages at the same depth -> move the second
		if attempt < 3:
			for i in villages.size():
				for j in range(i + 1, villages.size()):
					if absf(depths[villages[i].zone] - depths[villages[j].zone]) < 0.07 and not too_deep.has(villages[j].zone):
						too_deep.append(villages[j].zone)
		d.free()
		_apply(final)   # (the doors knocked a few walls through; start clean)
		if too_deep.is_empty():
			break
		banned.append_array(too_deep)
	print("Labyrinth seed: ", new_seed)


## How deep (0..1, like Doors.progress) the middle of each zone lies.
func _zone_depths() -> Array[float]:
	var d := Doors.new()
	d.generate(self)
	var out: Array[float] = []
	for zi in zones.size():
		var r: Rect2i = zones[zi]
		var total := 0.0
		var n := 0
		for y in range(r.position.y + 1, r.end.y - 1, 2):
			for x in range(r.position.x + 1, r.end.x - 1, 2):
				var c := Vector2i(x, y)
				if is_walkable(c):
					total += d.progress(c)
					n += 1
		out.append(total / n if n > 0 else -1.0)
	d.free()
	blockers.clear()
	doors.clear()
	return out


func _pick_village_zones(gen: LabyrinthGenerator, depth: Array[float], banned: Array) -> Array:
	var picks: Array = []
	var cols := LabyrinthGenerator.ZONE_COLS
	for target in VILLAGE_DEPTHS:
		var best := -1
		var best_score := INF
		for zi in zones.size():
			if zi == gen.start_zone() or picks.has(zi) or banned.has(zi) or depth[zi] < 0.0 or depth[zi] > 0.75 \
					or (zones[zi] as Rect2i).has_point(goal_cell):
				continue
			var next_to := false
			for p in picks:
				if absi(p % cols - zi % cols) + absi(p / cols - zi / cols) <= 1:
					next_to = true
			if next_to:
				continue
			# open land suits a village better than the crypts
			var score := absf(depth[zi] - target) + (0.06 if zone_biome[zi] == 0 else 0.0)
			if score < best_score:
				best_score = score
				best = zi
		if best >= 0:
			picks.append(best)
	return picks


func _apply(result: Dictionary) -> void:
	_load_map(result.rows)
	blockers.clear()
	doors.clear()
	reserved.clear()
	arches.clear()
	start_cell = result.start
	goal_cell = result.goal
	rooms = result.rooms
	biome = result.biome
	zones.assign(result.zones)
	zone_biome.assign(result.zone_biome)
	_name_zones()
	villages = result.villages
	heights = result.get("heights", PackedByteArray())
	if heights.size() != width * height:
		heights.resize(width * height)
		heights.fill(0)
	cliffs = result.get("cliffs", {})
	ramps = result.get("ramps", {})
	nooks = result.get("nooks", {})
	links.clear()
	link_of.clear()
	for l in result.get("links", []):
		links.append(l)
		for c in l:
			link_of[c] = links.size() - 1
	village_solid.clear()
	_village_id.resize(width * height)
	_village_id.fill(0)
	for i in villages.size():
		var v: Dictionary = villages[i]
		for c in v.solid:
			village_solid[c] = v.solid[c]
		var r: Rect2i = v.rect
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				_village_id[y * width + x] = i + 1
	if _over == null:
		_over = Node2D.new()
		_over.z_index = 3
		_over.draw.connect(_draw_over)
		add_child(_over)
	_room_grid.resize(width * height)
	_room_grid.fill(-1)
	for i in rooms.size():
		var r: Rect2i = rooms[i]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				_room_grid[y * width + x] = i
	mapped.resize(width * height)
	mapped.fill(0)


func _process(delta: float) -> void:
	if width == 0:
		return
	# Only the tiles on screen are drawn, so redraw when the view moves...
	var view := _visible_cells()
	if view != _last_view:
		_last_view = view
		queue_redraw()
	if _over != null:
		_over.queue_redraw()
	if not shaking.is_empty():
		for c in shaking.keys():
			shaking[c] -= delta
			if shaking[c] <= 0.0:
				shaking.erase(c)
		queue_redraw()
	# ...and for the slow water ripple.
	_water_timer += delta
	if _water_timer > 0.45:
		_water_timer = 0.0
		_water_frame = (_water_frame + 1) % 4
		queue_redraw()


## Is there a leafy bush on this tile (one you can rustle)?
func is_bush(cell: Vector2i) -> bool:
	if tile_at(cell) != "b":
		return false
	var b := biome_at(cell)
	return (b == B_FOREST or b == B_RIVER) and _prop_rock(cell, b).x < 0


func shake(cell: Vector2i, time: float = 0.5) -> void:
	shaking[cell] = time
	queue_redraw()


## How far a shaking thing is pushed sideways right now.
func shake_offset(cell: Vector2i) -> Vector2:
	if not shaking.has(cell):
		return Vector2.ZERO
	var t: float = shaking[cell]
	return Vector2(roundf(sin(t * 48.0) * 1.6 * clampf(t / 0.5, 0.0, 1.0)), 0)


## --- Baking the ground for the 3D view ----------------------------------------------
## The flat ground (floors, grass, moss, decals, water, bridges -- everything
## you walk on) drawn exactly as the 2D view draws it, into `ci`, for the
## cells in `r`. Things that stand up (walls, trees, props, rocks) are left out:
## the 3D view builds those as models.
var _baking := false


func bake_ground(ci: CanvasItem, r: Rect2i) -> void:
	_ci = ci
	_baking = true
	var keep_frame := _water_frame
	_water_frame = 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var cell := Vector2i(x, y)
			var o := Vector2(x * TILE, y * TILE)
			var inside := Vector2i(clampi(x, 0, width - 1), clampi(y, 0, height - 1))
			var b := biome_at(inside)
			var t := tile_at(cell)
			if t == "~":
				_draw_ground_plain(o, cell, b)
				_draw_quarters(o, cell, 4 + _water_frame, "~", Color.WHITE, 1)
				if b == B_SWAMP:
					_ci.draw_rect(Rect2(o, Vector2(TILE, TILE)), Color(0.18, 0.3, 0.08, 0.35))
				if (b == B_SWAMP or b == B_RIVER) and _hash(x, y, 21) % 6 == 0:
					_env(o, ROW_WATER_FX, 7)
			elif b == B_CRYPT:
				_draw_ground(o, cell, "." if t == "#" else t)
			elif t == "#":
				_outdoor_base(o, cell, b, _hash(x, y, 4), false)
			else:
				_draw_outdoor_ground(o, cell, t, b, 0)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var cell := Vector2i(x, y)
			var t := tile_at(cell)
			var b := biome_at(cell)
			if t != "#" and t != "~" and b != B_CRYPT and not in_village(cell) and _in_bounds(cell):
				_draw_patch(cell, b)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var cell := Vector2i(x, y)
			var t := tile_at(cell)
			var b := biome_at(cell)
			if t != "#" and t != "~" and b != B_CRYPT and _in_bounds(cell):
				_draw_outdoor_ground(Vector2(x * TILE, y * TILE), cell, t, b, 1)
	_water_frame = keep_frame
	_baking = false
	_ci = self


## The block of tiles currently on screen (plus a margin).
## While the 3D view is on: the flat 2D map isn't seen, so it isn't drawn
## (`flat_hidden`), and the effects laid on the 3D ground (traps, mist, wind)
## are drawn over `fx_rect`, the stretch the 3D cameras see.
static var flat_hidden := false
static var fx_rect := Rect2i()


func fx_cells() -> Rect2i:
	if fx_rect.size != Vector2i.ZERO:
		return fx_rect.intersection(Rect2i(0, 0, width, height))
	return _visible_cells()


func _visible_cells() -> Rect2i:
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	var view := get_viewport().get_visible_rect()
	var tl := inv * view.position
	var br := inv * view.end
	var x0 := maxi(int(floor(tl.x / TILE)) - 2, 0)
	var y0 := maxi(int(floor(tl.y / TILE)) - 2, 0)
	var x1 := mini(int(ceil(br.x / TILE)) + 2, width)
	var y1 := mini(int(ceil(br.y / TILE)) + 2, height)
	return Rect2i(x0, y0, x1 - x0, y1 - y0)


## Cheap check that blocking `c` (with a chest, gate...) cuts nothing off:
## the open tiles around it must still reach each other nearby.
## Cells in `passable` (locked doors) count as open.
func safe_to_block(c: Vector2i, passable: Dictionary = {}) -> bool:
	var around: Array[Vector2i] = []
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if is_walkable(c + d) or passable.has(c + d):
			around.append(c + d)
	if around.size() <= 1:
		return true
	var seen := {around[0]: true}
	var queue: Array[Vector2i] = [around[0]]
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = p + d
			if n == c or seen.has(n) or absi(n.x - c.x) > 10 or absi(n.y - c.y) > 10:
				continue
			if is_walkable(n) or passable.has(n):
				seen[n] = true
				queue.append(n)
	for a in around:
		if not seen.has(a):
			return false
	return true


func _load_map(rows: Array) -> void:
	grid.clear()
	for row in rows:
		grid.append(row)
	height = grid.size()
	width = grid[0].length()
	queue_redraw()


## Knocks out a wall tile (used to add loops inside a section).
func close_wall(cell: Vector2i) -> void:
	var row := grid[cell.y]
	grid[cell.y] = row.substr(0, cell.x) + "#" + row.substr(cell.x + 1)


func open_wall(cell: Vector2i) -> void:
	var row := grid[cell.y]
	grid[cell.y] = row.substr(0, cell.x) + "." + row.substr(cell.x + 1)


func tile_at(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return "#"
	return grid[cell.y][cell.x]


func is_walkable(cell: Vector2i) -> bool:
	return WALKABLE.contains(tile_at(cell)) and not blockers.has(cell)


## True if every walkable tile can be reached from `from`. Cells in
## `passable` (e.g. locked doors) count as open for this check.
func all_reachable(from: Vector2i, passable: Dictionary = {}) -> bool:
	var total := 0
	for y in height:
		for x in width:
			if is_walkable(Vector2i(x, y)) or passable.has(Vector2i(x, y)):
				total += 1
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if not seen.has(n) and (is_walkable(n) or passable.has(n)):
				seen[n] = true
				queue.append(n)
	return seen.size() == total


func is_mapped(cell: Vector2i) -> bool:
	if not _in_bounds(cell):
		return false
	return mapped[cell.y * width + cell.x] == 1


## A flare at `cell` puts its surroundings on the map: the whole room if it's
## in a room, otherwise the stretch of corridor within a few steps.
## Walls bordering the mapped area are included so the shape reads clearly.
func map_area(cell: Vector2i) -> void:
	var area: Array[Vector2i] = []
	var room := room_at(cell)
	if room.size != Vector2i.ZERO:
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				area.append(Vector2i(x, y))
	else:
		var dist := {cell: 0}
		var queue: Array[Vector2i] = [cell]
		var head := 0
		while head < queue.size():
			var c: Vector2i = queue[head]
			head += 1
			area.append(c)
			if dist[c] >= FLARE_CORRIDOR_REACH:
				continue
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var n: Vector2i = c + d
				if not dist.has(n) and tile_at(n) != "#":
					dist[n] = dist[c] + 1
					queue.append(n)
	for c in area:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := c + Vector2i(dx, dy)
				if _in_bounds(n):
					mapped[n.y * width + n.x] = 1
	mapped_changed.emit()


const ZONE_WORDS := {
	0: [["THE"], ["SUNKEN", "FORGOTTEN", "WEEPING", "HOLLOW", "BONE", "SILENT", "ASHEN", "DROWNED"], ["CATACOMBS", "CRYPTS", "VAULTS", "OSSUARY", "UNDERHALLS"]],
	1: [["THE"], ["WHISPERING", "BLACKTHORN", "MOONLIT", "TANGLED", "ELDER", "HUSHED", "WILD"], ["WOODS", "GROVE", "THICKET", "WILDWOOD"]],
	2: [["THE"], ["FALLEN", "MARBLE", "BROKEN", "KING'S", "STARLIT", "EMPTY"], ["COURTYARD", "PLAZA", "GARDENS", "CLOISTER"]],
	3: [["THE"], ["SHATTERED", "IRON", "WINDSWEPT", "GREY", "HOWLING", "JAGGED"], ["CRAGS", "PEAKS", "HIGHLANDS", "CLIFFS"]],
	4: [["THE"], ["SILVER", "MISTY", "SINGING", "COLD", "WINDING", "PALE"], ["RIVER", "FORD", "BROOK", "WATERS"]],
	5: [["THE"], ["ROTTING", "MURKY", "STAGNANT", "GLOOMING", "SUNKEN", "BOG-WITCH'S"], ["MIRE", "FEN", "BOG", "MARSH"]],
}


func _name_zones() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 77
	zone_names.clear()
	for zi in zones.size():
		var words: Array = ZONE_WORDS[zone_biome[zi]]
		var adj: Array = words[1]
		var noun: Array = words[2]
		zone_names.append("THE " + adj[rng.randi() % adj.size()] + " " + noun[rng.randi() % noun.size()])


## The village whose walls hold this cell (gates included), or -1.
func village_at(cell: Vector2i) -> int:
	if not _in_bounds(cell) or _village_id.is_empty():
		return -1
	return _village_id[cell.y * width + cell.x] - 1


func in_village(cell: Vector2i) -> bool:
	return village_at(cell) >= 0


## In or right around a village (no doors, chests or traps here).
func near_village(cell: Vector2i, reach: int = 2) -> bool:
	for v in villages:
		if (v.rect as Rect2i).grow(reach).has_point(cell):
			return true
	return false


## Which zone a cell is in (-1 off the map).
func zone_at(cell: Vector2i) -> int:
	for zi in zones.size():
		var r := zones[zi]
		if cell.x >= r.position.x and cell.y >= r.position.y and cell.x < r.end.x - 1 and cell.y < r.end.y - 1:
			return zi
	return -1


func find_arches() -> void:
	arches.clear()
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var c := Vector2i(x, y)
			if not WALKABLE.contains(tile_at(c)):
				continue
			var l := tile_at(c + Vector2i.LEFT) == "#"
			var r := tile_at(c + Vector2i.RIGHT) == "#"
			var u := tile_at(c + Vector2i.UP) == "#"
			var d := tile_at(c + Vector2i.DOWN) == "#"
			if l and r and not u and not d:
				if (biome_at(c + Vector2i.UP) == 0) != (biome_at(c + Vector2i.DOWN) == 0):
					arches[c] = "front"
			elif u and d and not l and not r:
				if (biome_at(c + Vector2i.LEFT) == 0) != (biome_at(c + Vector2i.RIGHT) == 0):
					arches[c] = "side"


func biome_at(cell: Vector2i) -> int:
	if not _in_bounds(cell):
		return 0
	return biome[cell.y * width + cell.x]


## Out under the sky (everything but the crypts).
func is_outdoors(cell: Vector2i) -> bool:
	return biome_at(cell) != 0


## The room containing `cell`, or an empty Rect2i if it's in a corridor.
func room_at(cell: Vector2i) -> Rect2i:
	if not _in_bounds(cell):
		return Rect2i()
	var i := _room_grid[cell.y * width + cell.x]
	return rooms[i] if i >= 0 else Rect2i()


func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


static var instance: World   ## the world in play (for things that only know a cell)


## Where a creature on `cell` stands, lifted onto high ground (no world yet: flat).
static func pos_of(cell: Vector2i) -> Vector2:
	return instance.cell_to_position(cell) if instance != null else Vector2(cell * TILE)


func cell_to_position(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + lift(cell)


## With the 3D world on, high ground really rises: whatever stands on it is
## drawn this much higher (zero otherwise).
func lift(cell: Vector2i) -> Vector2:
	if not three_d():
		return Vector2.ZERO
	return Vector2(0.0, -terrain3d.ground_height(cell) * TILE)


func three_d() -> bool:
	return terrain3d != null and terrain3d.visible


## Is this tile's wall drawn in 3D (so the 2D view leaves it out)?
func _solid3d(cell: Vector2i) -> bool:
	return three_d() and terrain3d.block_height(cell) > 0.0


func map_size_pixels() -> Vector2i:
	return Vector2i(width * TILE, height * TILE)


## Cells of a given prop type (used to place candle and mushroom lights).
func cells_with(ch: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in height:
		for x in width:
			if grid[y][x] == ch:
				out.append(Vector2i(x, y))
	return out


# --- Drawing ---------------------------------------------------------------
# Tiles come from assets/env.png (built by tools/make_env.py). Each tile is
# composed in layers: base, moss fringes, decals, ambient occlusion, props.

const ENV_TEX: Texture2D = preload("res://assets/env.png")
const ROW_FLOOR := 0
const ROW_GROUND := 1   # moss 0-3, tall grass 4-5, dirt 6-7
const ROW_FRINGE := 2   # N E S W, NE SE SW NW
const ROW_FACE := 3
const ROW_TOP := 4
const ROW_WATER := 5    # frames 0-3, shore N E S W 4-7
const ROW_DECAL := 6
const ROW_AO := 7       # N E W NE NW S


func _hash(x: int, y: int, salt: int = 0) -> int:
	var h := x * 374761393 + y * 668265263 + salt * 1442695041
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))


func _env(o: Vector2, row: int, col: int) -> void:
	_ci.draw_texture_rect_region(ENV_TEX, Rect2(o, Vector2(TILE, TILE)),
		Rect2(col * TILE, row * TILE, TILE, TILE))


func _is_grassy(ch: String) -> bool:
	return ch == "," or ch == "w"


func _ground_grassy(cell: Vector2i) -> bool:
	var t := tile_at(cell)
	if _is_grassy(t):
		return true
	if PROP_INDEX.has(t):
		var n := 0
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if _is_grassy(tile_at(cell + d)):
				n += 1
		return n >= 2
	return false


const B_CRYPT := 0
const B_FOREST := 1
const B_COURT := 2
const B_MOUNTAIN := 3
const B_RIVER := 4
const B_SWAMP := 5
const ROW_FOREST := 8      # ground dirt 0-1, grass 2-3, tree faces 4-7
const ROW_CANOPY := 9      # by open-neighbour mask
const ROW_COURT := 10      # ground 0-3, wall faces 4-7
const ROW_COURT_TOP := 11
const ROW_MTN := 12        # ground 0-3, cliff faces 4-7
const ROW_ROCK_TOP := 13
const ROW_WATER_FX := 14   # waterfall 0-3, bridge H 4, bridge V 5, reeds 6, lily 7
const ROW_PROPS2 := 15     # bush, boulder, statue, pillar, fern, flowers, scree, marsh grass
const SWAMP_TINT := Color(0.72, 0.86, 0.55)
const TALL_TEX: Texture2D = preload("res://assets/tall.png")
# rects in tall.png (see tools/make_tall.py)
const R_FORT_FACE := Rect2(0, 0, 16, 24)       # x += 16 * variant
const R_COURT_FACE := Rect2(64, 0, 16, 24)
const R_CLIFF_FACE := Rect2(0, 24, 16, 24)
const R_FORT_TOP := Rect2(64, 24, 16, 16)
const R_ARCH_FRONT := Rect2(0, 48, 48, 40)
const R_ARCH_SIDE := Rect2(48, 48, 16, 40)
const R_CROWN := Rect2(0, 88, 32, 32)          # x += 32 * variant
const R_BOULDER := Rect2(0, 120, 32, 32)
const R_TREE := Rect2(0, 152, 32, 48)            # x += 32 * variant
const SWAMP_WATER := Color(0.55, 0.8, 0.45)
# map detail (tools/make_detail.py)
const ROCKS_TEX: Texture2D = preload("res://assets/rocks.png")
const DECOR_TEX: Texture2D = preload("res://assets/decor.png")
const PATCH_TEX: Texture2D = preload("res://assets/patches.png")
const ROCK_PEBBLES := 0
const ROCK_SMALL := 1
const ROCK_BOULDER := 2
const ROCK_BIG := 3
const ROCK_SPIRE := 4
const ROCK_CLUSTER := 5
const PAL_MTN := 0
const PAL_GREY := 1
const PAL_MOSS := 2
const PAL_SWAMP := 3
const PAL_SAND := 4
const DECOR_ROW := {0: 5, 1: 1, 2: 4, 3: 0, 4: 2, 5: 3}   # biome -> decor.png row
const PATCH_ROW := {1: 1, 2: 4, 3: 0, 4: 2, 5: 3}


## The stone bier in the Waking Chamber, where every run begins.
func _draw_bier(o: Vector2) -> void:
	var c := o + Vector2(8, 0)
	_ci.draw_rect(Rect2(c + Vector2(-12, 11), Vector2(27, 4)), Color(0.02, 0.01, 0.05, 0.35))   # shadow
	# legs / plinth
	_ci.draw_rect(Rect2(c + Vector2(-12, 6), Vector2(24, 8)), Color("1c1824"))
	_ci.draw_rect(Rect2(c + Vector2(-11, 7), Vector2(22, 6)), Color("4a4458"))
	_ci.draw_rect(Rect2(c + Vector2(-11, 7), Vector2(22, 1)), Color("2a2636"))
	for x in [-9, -3, 3, 8]:   # carved panels
		_ci.draw_rect(Rect2(c + Vector2(x, 9), Vector2(2, 3)), Color("343042"))
	_ci.draw_rect(Rect2(c + Vector2(-11, 7), Vector2(2, 6)), Color("5e5872"))
	# the slab
	_ci.draw_rect(Rect2(c + Vector2(-13, -3), Vector2(26, 11)), Color("1c1824"))
	_ci.draw_rect(Rect2(c + Vector2(-12, -2), Vector2(24, 9)), Color("8a8498"))
	_ci.draw_rect(Rect2(c + Vector2(-12, -2), Vector2(24, 1)), Color("b4aec2"))
	_ci.draw_rect(Rect2(c + Vector2(-12, -2), Vector2(1, 9)), Color("a49eb2"))
	_ci.draw_rect(Rect2(c + Vector2(-12, 5), Vector2(24, 2)), Color("6a6478"))
	_ci.draw_rect(Rect2(c + Vector2(-10, 0), Vector2(20, 4)), Color("7a7488"))   # worn hollow
	# a faded burial cloth draped over the foot, and an old stain of wax
	_ci.draw_rect(Rect2(c + Vector2(4, -2), Vector2(8, 9)), Color("6a2a32"))
	_ci.draw_rect(Rect2(c + Vector2(4, -2), Vector2(8, 1)), Color("8a3a40"))
	_ci.draw_rect(Rect2(c + Vector2(5, 7), Vector2(6, 2)), Color("4a1c24"))
	_ci.draw_rect(Rect2(c + Vector2(-11, -1), Vector2(2, 1)), Color("e8dfc8"))


## A rock sprite stands with its foot on the bottom of the cell.
func _rock(o: Vector2, kind: int, pal: int, variant: int, top_only: bool = false) -> void:
	var src := Rect2(variant * 32, (kind * 5 + pal) * 32, 32, 24 if top_only else 32)
	_blit(ROCKS_TEX, Rect2(o + Vector2(-8, -12), src.size), src)


## Which rock (kind, palette, variant) stands on a blocking prop cell, if any.
func _prop_rock(cell: Vector2i, b: int) -> Vector3i:
	if tile_at(cell) != "b":
		return Vector3i(-1, 0, 0)
	var h := _hash(cell.x, cell.y, 77)
	match b:
		B_MOUNTAIN:
			return Vector3i([ROCK_BOULDER, ROCK_BIG, ROCK_SPIRE, ROCK_CLUSTER, ROCK_BIG][h % 5], PAL_MTN, (h / 5) % 4)
		B_FOREST, B_RIVER:
			if h % 3 == 0:
				return Vector3i([ROCK_BOULDER, ROCK_BIG, ROCK_CLUSTER][(h / 3) % 3], PAL_MOSS, (h / 9) % 4)
		B_SWAMP:
			if h % 3 == 0:
				return Vector3i([ROCK_BOULDER, ROCK_CLUSTER, ROCK_SPIRE][(h / 3) % 3], PAL_SWAMP, (h / 9) % 4)
		B_CRYPT:
			if h % 2 == 0:
				return Vector3i([ROCK_BOULDER, ROCK_CLUSTER, ROCK_BIG][(h / 2) % 3], PAL_GREY, (h / 6) % 4)
	return Vector3i(-1, 0, 0)


## Big rocks sitting up on the mountain plateaus.
func _plateau_rock(cell: Vector2i, b: int) -> Vector3i:
	if b != B_MOUNTAIN or tile_at(cell + Vector2i.DOWN) != "#":
		return Vector3i(-1, 0, 0)
	var h := _hash(cell.x, cell.y, 41)
	if h % 4 != 0:
		return Vector3i(-1, 0, 0)
	return Vector3i([ROCK_BIG, ROCK_SPIRE, ROCK_CLUSTER, ROCK_BOULDER, ROCK_SMALL][(h / 4) % 5], PAL_MTN, (h / 20) % 4)


func _decor(o: Vector2, b: int, col: int) -> void:
	_ci.draw_texture_rect_region(DECOR_TEX, Rect2(o, Vector2(TILE, TILE)),
		Rect2(col * TILE, DECOR_ROW[b] * TILE, TILE, TILE))


## Soft ground patches (sand, gravel, leaf litter, mud...) that break up the
## tile grid. Only on open ground well away from walls and water.
func _draw_patch(cell: Vector2i, b: int) -> void:
	if not PATCH_ROW.has(b):
		return
	var h := _hash(cell.x, cell.y, 61)
	if h % 5 != 0:
		return
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var t := tile_at(cell + Vector2i(dx, dy))
			if t == "#" or t == "~" or biome_at(cell + Vector2i(dx, dy)) != b:
				return
	var variant := _hash(cell.x / 3, cell.y / 3, 62) % 3
	var o := Vector2(cell.x * TILE - 8 + (h / 5) % 7 - 3, cell.y * TILE - 8 + (h / 35) % 5 - 2) + lift(cell)
	_ci.draw_texture_rect_region(PATCH_TEX, Rect2(o, Vector2(32, 32)),
		Rect2(variant * 32, PATCH_ROW[b] * 32, 32, 32))


func _tall(dst_pos: Vector2, src: Rect2, variant: int, mod: Color = Color.WHITE) -> void:
	var r := Rect2(src.position + Vector2(src.size.x * variant, 0), src.size)
	_blit(TALL_TEX, Rect2(dst_pos, src.size), r, mod)


## While redrawing the "in front" layer, only the part of a tall thing that
## rises above its own tile is drawn (y < _clip_y): that's the part that
## stands in front of whatever is on the tiles behind it.
var _clip_y := INF


func _blit(tex: Texture2D, dst: Rect2, src: Rect2, mod: Color = Color.WHITE) -> void:
	if dst.position.y >= _clip_y:
		return
	if dst.end.y > _clip_y:
		var k := src.size.y / dst.size.y
		dst.size.y = _clip_y - dst.position.y
		src.size.y = dst.size.y * k
	_ci.draw_texture_rect_region(tex, dst, src, mod)


func _crect(r: Rect2, col: Color) -> void:
	if r.position.y >= _clip_y:
		return
	if r.end.y > _clip_y:
		r.size.y = _clip_y - r.position.y
	_ci.draw_rect(r, col)


func _is_tree(cell: Vector2i) -> bool:
	if tile_at(cell) != "#" or village_solid.has(cell) or cliffs.has(cell):
		return false
	var b := biome_at(cell)
	return b == B_FOREST or b == B_RIVER or b == B_SWAMP


func _envm(o: Vector2, row: int, col: int, mod: Color) -> void:
	_ci.draw_texture_rect_region(ENV_TEX, Rect2(o, Vector2(TILE, TILE)),
		Rect2(col * TILE, row * TILE, TILE, TILE), mod)


func _draw() -> void:
	if flat_hidden:
		return
	var v := _visible_cells()
	# Past the map's edge: more of the same wall / forest / cliff, so the camera
	# can stay on you right up to the edge (no black void).
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	var vr := get_viewport().get_visible_rect()
	var tl := inv * vr.position
	var br := inv * vr.end
	for y in range(int(floor(tl.y / TILE)) - 1, int(ceil(br.y / TILE)) + 2):
		for x in range(int(floor(tl.x / TILE)) - 1, int(ceil(br.x / TILE)) + 2):
			var cell := Vector2i(x, y)
			if _in_bounds(cell):
				continue
			var inside := Vector2i(clampi(x, 0, width - 1), clampi(y, 0, height - 1))
			if _solid3d(cell):
				continue
			_draw_raised(Vector2(x * TILE, y * TILE), cell, biome_at(inside))
	for y in range(v.position.y, v.end.y):
		for x in range(v.position.x, v.end.x):
			var cell := Vector2i(x, y)
			var o := Vector2(x * TILE, y * TILE) + lift(cell)
			var t := tile_at(cell)
			var b := biome_at(cell)
			if o.y != y * TILE and b != B_CRYPT:
				# lifted high ground: plain ground where it used to be, so no gap shows below it
				_outdoor_base(Vector2(x * TILE, y * TILE), cell, b, _hash(x, y, 4), _ground_grassy(cell))
			if _solid3d(cell):
				# a 3D block stands here: just the ground under it
				if b == B_CRYPT:
					_draw_ground(o, cell, ".")
				else:
					_outdoor_base(o, cell, b, _hash(x, y, 4), false)
			elif t == "#" and cliffs.has(cell):
				_draw_cliff(o, cell, b)
			elif t == "#" and village_solid.has(cell):
				# under a house, lamp or fence: the same ground as around it, so
				# nothing stands on a square patch of its own
				_draw_outdoor_ground(o, cell, ".", b, 0)
			elif t == "#":
				_draw_raised(o, cell, b)
			elif t == "~":
				_draw_ground_plain(o, cell, b)
				_draw_quarters(o, cell, 4 + _water_frame, "~", Color.WHITE, 1)
				if b == B_SWAMP:
					_ci.draw_rect(Rect2(o, Vector2(TILE, TILE)), Color(0.18, 0.3, 0.08, 0.35))
				if (b == B_SWAMP or b == B_RIVER) and _hash(x, y, 21) % 6 == 0:
					_env(o, ROW_WATER_FX, 7)   # lily pads
			elif b == B_CRYPT:
				_draw_ground(o, cell, t)
			else:
				_draw_outdoor_ground(o, cell, t, b, 0)
	# ground patches, then everything that sits on the ground
	for y in range(v.position.y, v.end.y):
		for x in range(v.position.x, v.end.x):
			var cell := Vector2i(x, y)
			var t := tile_at(cell)
			var b := biome_at(cell)
			if t != "#" and t != "~" and b != B_CRYPT and not in_village(cell):
				_draw_patch(cell, b)
	for y in range(v.position.y, v.end.y):
		for x in range(v.position.x, v.end.x):
			var cell := Vector2i(x, y)
			var t := tile_at(cell)
			var b := biome_at(cell)
			if t != "#" and t != "~" and b != B_CRYPT:
				_draw_outdoor_ground(Vector2(x * TILE, y * TILE) + lift(cell), cell, t, b, 1)
	# High ground: slopes, a little extra light on raised tiles, shade below cliffs.
	for y in range(v.position.y, v.end.y):
		for x in range(v.position.x, v.end.x):
			var cell := Vector2i(x, y)
			var o := Vector2(x * TILE, y * TILE) + lift(cell)
			if ramps.has(cell):
				if not three_d():
					_draw_ramp(o, cell)
				continue
			if three_d():
				continue   # (the 3D blocks give high ground its edges and shade)
			var hgt := height_at(cell)
			if hgt > 0 and tile_at(cell) != "#":
				_ci.draw_rect(Rect2(o, Vector2(TILE, TILE)), Color(1.0, 0.97, 0.88, 0.08 * hgt))
				# a bright lip along the edge of the high ground
				if cliffs.has(cell + Vector2i.DOWN):
					_ci.draw_rect(Rect2(o + Vector2(0, TILE - 2), Vector2(TILE, 2)), Color(1, 1, 0.9, 0.12))
				if cliffs.has(cell + Vector2i.LEFT):
					_ci.draw_rect(Rect2(o, Vector2(1, TILE)), Color(1, 1, 0.9, 0.1))
				if cliffs.has(cell + Vector2i.RIGHT):
					_ci.draw_rect(Rect2(o + Vector2(TILE - 1, 0), Vector2(1, TILE)), Color(0, 0, 0, 0.12))
			var up := cell + Vector2i.UP
			if cliffs.has(up) and tile_at(cell) != "#" and height_at(up + Vector2i.UP) > hgt:
				_ci.draw_rect(Rect2(o, Vector2(TILE, 5)), Color(0, 0, 0, 0.22))
				_ci.draw_rect(Rect2(o, Vector2(TILE, 2)), Color(0, 0, 0, 0.15))
	# Second pass: things with height that overlap their neighbours --
	# round tree crowns and boulder piles -- drawn top row first.
	for y in range(v.position.y, v.end.y):
		for x in range(v.position.x, v.end.x):
			var cell := Vector2i(x, y)
			var b := biome_at(cell)
			var o := Vector2(x * TILE, y * TILE) + lift(cell)
			if cell == start_cell:
				_draw_bier(o)
			if tile_at(cell) != "#":
				var pr := _prop_rock(cell, b)
				if pr.x >= 0:
					_rock(o, pr.x, pr.y, pr.z)
				continue
			if village_solid.has(cell) or cliffs.has(cell):
				continue
			var h := _hash(x, y, 41)
			if _is_tree(cell):
				_draw_tree_at(o, cell, b, h)
			elif not _solid3d(cell):
				var rk := _plateau_rock(cell, b)
				if rk.x >= 0:
					_rock(o, rk.x, rk.y, rk.z)


## Off the edge of high ground: walking from `from` (on top) in direction `d`
## over the plateau's rim, where do you land? Vector2i(-1, -1) if you can't
## jump there: not the rim of the rise you're on, nowhere to land, or -- so a
## jump never skips a locked gate -- the landing isn't joined to the foot of a
## way up onto this rise (Player.jump_down does the jump).
func drop_land(from: Vector2i, d: Vector2i) -> Vector2i:
	var none := Vector2i(-1, -1)
	var top := height_at(from)
	if top <= 0 or ramps.has(from) or cliffs.has(from):
		return none
	var rim := from + d
	if not cliffs.has(rim) or int(cliffs[rim]) != top:
		return none
	var land := rim + d
	if not is_walkable(land) or cliffs.has(land) or ramps.has(land) or height_at(land) >= top:
		return none
	if not _drop_joined(land, top):
		return none
	return land


var _drop_ok := {}   ## landings already found joined (doors only ever open, so they stay so)


## Can you walk from `land` (low ground) to a slope up to level `top` without
## climbing and without going through anything shut? (A local search.)
func _drop_joined(land: Vector2i, top: int) -> bool:
	var key := Vector3i(land.x, land.y, top)
	if _drop_ok.has(key):
		return true
	var lvl := height_at(land)
	var box := Rect2i(land - Vector2i(48, 48), Vector2i(97, 97))
	var seen := {land: true}
	var q: Array[Vector2i] = [land]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		if ramps.has(c):
			var up_c: Vector2i = c + {"s": Vector2i.UP, "w": Vector2i.RIGHT, "e": Vector2i.LEFT}.get(ramps[c], Vector2i.UP)
			if height_at(up_c) == top:
				_drop_ok[key] = true
				return true
		for dd in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + dd
			if seen.has(n) or not box.has_point(n) or not is_walkable(n) or cliffs.has(n):
				continue
			if height_at(n) != lvl and not ramps.has(n):
				continue
			seen[n] = true
			q.append(n)
	return false


func height_at(cell: Vector2i) -> int:
	if not _in_bounds(cell) or heights.is_empty():
		return 0
	return heights[cell.y * width + cell.x]


## Which row of heights.png suits this land.
func _height_style(b: int) -> int:
	match b:
		B_FOREST, B_RIVER: return 0
		B_SWAMP: return 1
		B_MOUNTAIN: return 2
		B_COURT: return 3
	return 4


func _height_tile(o: Vector2, b: int, col: int) -> void:
	_ci.draw_texture_rect_region(HEIGHTS_TEX, Rect2(o, Vector2(TILE, TILE)),
		Rect2(col * TILE, _height_style(b) * TILE, TILE, TILE))


## A cliff / ledge tile: the low ground under it, then the rock, oriented by
## where the raised ground is.
func _draw_cliff(o: Vector2, cell: Vector2i, b: int) -> void:
	var level: int = cliffs[cell]
	var hi := func(d: Vector2i) -> bool: return height_at(cell + d) >= level and not cliffs.has(cell + d) and tile_at(cell + d) != "#" or ramps.has(cell + d)
	if b == B_CRYPT:
		_draw_ground(o, cell, ".")
	else:
		_outdoor_base(o, cell, b, _hash(cell.x, cell.y, 4), _ground_grassy(cell))
	var col := -1
	if hi.call(Vector2i.UP):
		col = _hash(cell.x, cell.y, 31) % 2
		var l_end: bool = not hi.call(Vector2i(-1, -1)) and not cliffs.has(cell + Vector2i.LEFT)
		var r_end: bool = not hi.call(Vector2i(1, -1)) and not cliffs.has(cell + Vector2i.RIGHT)
		if l_end:
			col = 2
		elif r_end:
			col = 3
	elif hi.call(Vector2i.RIGHT):
		col = 5
	elif hi.call(Vector2i.LEFT):
		col = 6
	elif hi.call(Vector2i.DOWN):
		col = 4
	elif hi.call(Vector2i(1, -1)):
		col = 2
	elif hi.call(Vector2i(-1, -1)):
		col = 3
	elif hi.call(Vector2i(1, 1)):
		col = 7
	elif hi.call(Vector2i(-1, 1)):
		col = 8
	if col >= 0:
		_height_tile(o, b, col)


func _draw_ramp(o: Vector2, cell: Vector2i) -> void:
	var col: int = {"s": 9, "w": 10, "e": 11}.get(ramps[cell], 9)
	_height_tile(o, biome_at(cell), col)


const W3D_TEX: Texture2D = preload("res://assets/walls3d.png")
const MAT_CRYPT := 0
const MAT_COURT := 1
const MAT_PLATEAU := 2
const MAT_CANOPY := 3


## Raised ground, Pokemon style. The TOP of a wall is built from four 8x8
## quarters that round its outside corners, light its north lip and slope
## its east/west sides; the SOUTH FACE is a tall cliff/wall sprite that
## rises half a tile over the top, so every wall has visible height.
func _draw_raised(o: Vector2, cell: Vector2i, b: int) -> void:
	var below := tile_at(cell + Vector2i.DOWN)
	_draw_ground_plain(o, cell, b)
	if below != "#":
		_draw_face(o, cell, b)
		return
	var mat := MAT_CRYPT
	var mod := Color.WHITE
	match b:
		B_COURT: mat = MAT_COURT
		B_MOUNTAIN: mat = MAT_PLATEAU
		B_FOREST, B_RIVER: mat = MAT_CANOPY
		B_SWAMP:
			mat = MAT_CANOPY
			mod = SWAMP_TINT
	_draw_quarters(o, cell, mat, "#", mod, 2)


## The four quarters of a raised tile (or a water tile): each picks fill,
## lip, side, rounded outside corner or inside corner from its neighbours.
func _draw_quarters(o: Vector2, cell: Vector2i, row: int, same: String, mod: Color, variants: int) -> void:
	var variant := _hash(cell.x, cell.y, 51) % variants
	for q in 4:
		var vs := -1 if q < 2 else 1
		var hs := -1 if q % 2 == 0 else 1
		var v_same := tile_at(cell + Vector2i(0, vs)) == same
		var h_same := tile_at(cell + Vector2i(hs, 0)) == same
		var d_same := tile_at(cell + Vector2i(hs, vs)) == same
		var kind := 0
		if not v_same and not h_same:
			kind = 3
		elif not v_same:
			kind = 1
		elif not h_same:
			kind = 2
		elif not d_same:
			kind = 4
		var src := Rect2((variant * 20 + q * 5 + kind) * 8, row * 8, 8, 8)
		_ci.draw_texture_rect_region(W3D_TEX, Rect2(o + Vector2((q % 2) * 8, (q / 2) * 8), Vector2(8, 8)), src, mod)


## Plain ground for this landscape: what shows around rounded corners.
func _draw_ground_plain(o: Vector2, cell: Vector2i, b: int) -> void:
	var h := _hash(cell.x, cell.y, 4)
	match b:
		B_CRYPT: _env(o, ROW_FLOOR, h % 8)
		B_FOREST, B_RIVER: _env(o, ROW_FOREST, h % 2)
		B_SWAMP: _envm(o, ROW_GROUND, 6 + h % 2, Color(0.62, 0.66, 0.48))
		B_COURT: _env(o, ROW_COURT, h % 2)
		B_MOUNTAIN: _env(o, ROW_MTN, h % 2)


## A wall's south face: tall (it rises 8 px over the tile above) so walls
## read as solid blocks with height. Waterfalls pour over cliffs above water.
func _draw_face(o: Vector2, cell: Vector2i, b: int) -> void:
	var below := tile_at(cell + Vector2i.DOWN)
	var h := _hash(cell.x, cell.y, 9)
	if below == "~" and (b == B_MOUNTAIN or b == B_RIVER or b == B_FOREST):
		_env(o, ROW_WATER_FX, (_water_frame + cell.x) % 4)
		return
	match b:
		B_CRYPT:
			var v := 0
			if h % 9 == 0:
				v = 3   # torch bracket
			elif h % 13 == 0:
				v = 2   # barred window
			elif _faces_outdoors(cell) and h % 3 == 0:
				v = 1   # ivy outside
			_tall(o - Vector2(0, 8), R_FORT_FACE, v)
		B_COURT: _tall(o - Vector2(0, 8), R_COURT_FACE, 0 if h % 5 < 2 else h % 4)
		B_MOUNTAIN: _tall(o - Vector2(0, 8), R_CLIFF_FACE, h % 4)
		_:
			return   # forest edges: a tall tree stands here (second pass)
	# rounded, shaded ends where the face turns a corner
	var left_open := tile_at(cell + Vector2i.LEFT) != "#"
	var right_open := tile_at(cell + Vector2i.RIGHT) != "#"
	if left_open:
		_crect(Rect2(o + Vector2(0, -8), Vector2(1, 24)), Color(0, 0, 0, 0.55))
		_crect(Rect2(o + Vector2(1, -8), Vector2(2, 24)), Color(1, 1, 1, 0.10))
		_crect(Rect2(o + Vector2(0, -8), Vector2(2, 2)), Color(0, 0, 0, 0.8))
	if right_open:
		_crect(Rect2(o + Vector2(TILE - 1, -8), Vector2(1, 24)), Color(0, 0, 0, 0.6))
		_crect(Rect2(o + Vector2(TILE - 4, -8), Vector2(3, 24)), Color(0, 0, 0, 0.25))
		_crect(Rect2(o + Vector2(TILE - 2, -8), Vector2(2, 2)), Color(0, 0, 0, 0.8))


func _draw_outdoor_wall(o: Vector2, cell: Vector2i, b: int) -> void:
	var below := tile_at(cell + Vector2i.DOWN)
	var h := _hash(cell.x, cell.y, 9)
	var mod := SWAMP_TINT if b == B_SWAMP else Color.WHITE
	if below != "#":
		if below == "~" and (b == B_MOUNTAIN or b == B_RIVER or b == B_FOREST):
			_env(o, ROW_WATER_FX, (_water_frame + cell.x) % 4)   # a waterfall pours down
			return
		match b:
			B_COURT: _tall(o - Vector2(0, 8), R_COURT_FACE, 0 if h % 5 < 2 else h % 4)
			B_MOUNTAIN: _tall(o - Vector2(0, 8), R_CLIFF_FACE, h % 4)
			_: _envm(o, ROW_FOREST, 4 + h % 4, mod)
		if tile_at(cell + Vector2i.LEFT) != "#":
			_ci.draw_rect(Rect2(o, Vector2(2, TILE)), Color(0, 0, 0, 0.3))
		if tile_at(cell + Vector2i.RIGHT) != "#":
			_ci.draw_rect(Rect2(o + Vector2(TILE - 2, 0), Vector2(2, TILE)), Color(0, 0, 0, 0.4))
		return
	var mask := 0
	if tile_at(cell + Vector2i.UP) != "#": mask |= 1
	if tile_at(cell + Vector2i.RIGHT) != "#": mask |= 2
	if tile_at(cell + Vector2i.LEFT) != "#": mask |= 4
	match b:
		B_COURT: _env(o, ROW_COURT_TOP, mask)
		B_MOUNTAIN: _env(o, ROW_ROCK_TOP, mask)
		_: _envm(o, ROW_CANOPY, mask, mod)


## A tree tile: whole tall trees (trunk + crown, 3 tiles high) stand along the
## edge of the woods; deeper in, round crowns overlap into a canopy.
func _draw_tree_at(o: Vector2, cell: Vector2i, b: int, h: int) -> void:
	var mod := SWAMP_TINT if b == B_SWAMP else Color.WHITE
	var edge := tile_at(cell + Vector2i.DOWN) != "#"
	if edge:
		var jx := float(h % 5 - 2)
		if _ci == self:   # its shadow falls down and to the right
			_ci.draw_circle(o + Vector2(14 + jx, 17), 8.0, Color(0.03, 0.02, 0.06, 0.22))
			_ci.draw_rect(Rect2(o + Vector2(6 + jx, 15), Vector2(20, 4)), Color(0.03, 0.02, 0.06, 0.25))
		_tall(o + Vector2(-8 + jx, -32), R_TREE, h % 3, mod)
	else:
		var j := Vector2(h % 7 - 3, (h / 7) % 5 - 2)
		_tall(o + Vector2(-8, -12) + j, R_CROWN, h % 4, mod)


## The "in front" layer, drawn over the hero, creatures and items: every
## tall thing on screen (wall faces, trees, cliffs, rocks) is drawn again, but
## only the part that rises above its own tile. So whatever stands on the
## tiles behind it is hidden at the feet and peeks out over the top --
## walk behind a wall or a tree and it hides you, like in Pokemon.
func _draw_over() -> void:
	if flat_hidden:
		return
	_ci = _over
	var v := _visible_cells()
	for y in range(v.position.y, v.end.y + 3):
		for x in range(v.position.x - 1, v.end.x + 1):
			var cell := Vector2i(x, y)
			var o := Vector2(x * TILE, y * TILE) + lift(cell)
			var b := biome_at(cell)
			_clip_y = o.y
			if _solid3d(cell):
				continue   # the 3D view draws its own tops over you
			if tile_at(cell) != "#":
				var pr := _prop_rock(cell, b)
				if pr.x >= 0:
					_rock(o, pr.x, pr.y, pr.z)
				continue
			if village_solid.has(cell) or cliffs.has(cell):
				continue
			if tile_at(cell + Vector2i.UP) == "#" and not _is_tree(cell) and _plateau_rock(cell, b).x < 0:
				continue   # nothing can stand behind it
			var h := _hash(x, y, 41)
			if _is_tree(cell):
				_draw_tree_at(o, cell, b, h)
			elif tile_at(cell + Vector2i.DOWN) != "#":
				_draw_face(o, cell, b)
			else:
				var rk := _plateau_rock(cell, b)
				if rk.x >= 0:
					_rock(o, rk.x, rk.y, rk.z)
	_clip_y = INF
	_ci = self


## A crypt wall that looks out on the open air (outdoor ground next to it).
func _faces_outdoors(cell: Vector2i) -> bool:
	for d in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		var n: Vector2i = cell + d
		if tile_at(n) != "#" and biome_at(n) != B_CRYPT:
			return true
	return false


## The crypts from the outside: castle masonry, tall, topped with battlements.
func _draw_fortress(o: Vector2, cell: Vector2i) -> void:
	var h := _hash(cell.x, cell.y, 9)
	if tile_at(cell + Vector2i.DOWN) != "#":
		_tall(o - Vector2(0, 8), R_FORT_FACE, 0 if h % 6 < 3 else h % 4)
	else:
		_tall(o, R_FORT_TOP, h % 2)


func _draw_outdoor_ground(o: Vector2, cell: Vector2i, t: String, b: int, stage: int) -> void:
	var x := cell.x
	var y := cell.y
	var h := _hash(x, y, 4)
	var grassy := _ground_grassy(cell)
	if stage == 0:
		_outdoor_base(o, cell, b, h, grassy)
		return
	var water_ew := tile_at(cell + Vector2i.LEFT) == "~" and tile_at(cell + Vector2i.RIGHT) == "~"
	var water_ns := tile_at(cell + Vector2i.UP) == "~" and tile_at(cell + Vector2i.DOWN) == "~"
	if t == "w":
		_envm(o + shake_offset(cell), ROW_GROUND, 4 + _hash(x, y, 5) % 2, SWAMP_TINT if b == B_SWAMP else Color.WHITE)
	# bridges over the river
	if water_ew and not PROP_INDEX.has(t):
		_env(o, ROW_WATER_FX, 5)
	elif water_ns and not PROP_INDEX.has(t):
		_env(o, ROW_WATER_FX, 4)
	elif t != "w" and not in_village(cell):
		var hd := _hash(x, y, 11) % 100
		var by_water := false
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if tile_at(cell + d) == "~":
				by_water = true
		if by_water and (b == B_RIVER or b == B_SWAMP) and hd < 45:
			_env(o, ROW_WATER_FX, 6)   # reeds at the water's edge
		elif hd < (22 if b == B_COURT else 26) and not PROP_INDEX.has(t):
			# scattered decor -- a different mix in every landscape
			_decor(o, b, _hash(x, y, 12) % 8)
		elif hd < 29 and not PROP_INDEX.has(t) and b != B_COURT:
			var pal := {B_MOUNTAIN: PAL_MTN, B_SWAMP: PAL_SWAMP}.get(b, PAL_MOSS) as int
			_rock(o, ROCK_PEBBLES, pal, hd % 4)
		elif hd < 27 and b == B_COURT and not PROP_INDEX.has(t):
			_rock(o, ROCK_PEBBLES, PAL_SAND, hd % 4)
	# shade where it meets walls
	var wn := tile_at(cell + Vector2i.UP) == "#"
	var we := tile_at(cell + Vector2i.RIGHT) == "#"
	var ww := tile_at(cell + Vector2i.LEFT) == "#"
	if wn: _env(o, ROW_AO, 0)
	if we: _env(o, ROW_AO, 1)
	if ww: _env(o, ROW_AO, 2)
	if tile_at(cell + Vector2i.DOWN) == "#": _env(o, ROW_AO, 5)
	if PROP_INDEX.has(t) and _prop_rock(cell, b).x < 0 and not _baking:
		_draw_outdoor_prop(o + shake_offset(cell), cell, t, b)


func _outdoor_base(o: Vector2, cell: Vector2i, b: int, h: int, grassy: bool) -> void:
	match b:
		B_FOREST, B_RIVER:
			_env(o, ROW_FOREST, (2 + h % 2) if grassy else h % 2)
		B_SWAMP:
			if grassy:
				_envm(o, ROW_FOREST, 2 + h % 2, SWAMP_TINT)
			else:
				_envm(o, ROW_GROUND, 6 + h % 2, Color(0.62, 0.66, 0.48))   # mud
		B_COURT:
			_env(o, ROW_COURT, (2 + h % 2) if grassy else h % 2)
		B_MOUNTAIN:
			_env(o, ROW_MTN, (2 + h % 2) if grassy else h % 2)
	# grass creeping over bare ground, so patches blend instead of tiling
	if not grassy and b != B_COURT and b != B_MOUNTAIN:
		var tint := SWAMP_TINT if b == B_SWAMP else Color.WHITE
		if _ground_grassy(cell + Vector2i.UP): _envm(o, ROW_FRINGE, 0, tint)
		if _ground_grassy(cell + Vector2i.RIGHT): _envm(o, ROW_FRINGE, 1, tint)
		if _ground_grassy(cell + Vector2i.DOWN): _envm(o, ROW_FRINGE, 2, tint)
		if _ground_grassy(cell + Vector2i.LEFT): _envm(o, ROW_FRINGE, 3, tint)


func _draw_outdoor_prop(o: Vector2, cell: Vector2i, t: String, b: int) -> void:
	Shadows.oval(self, o + Vector2(8, 14), 12 if t != "x" else 9)
	if t == "b" and (b == B_FOREST or b == B_RIVER):
		_env(o, ROW_PROPS2, 0)            # berry bush
	elif t == "b" and b == B_MOUNTAIN:
		_env(o, ROW_PROPS2, 1)            # boulder
	elif t == "g" and b == B_COURT:
		_env(o, ROW_PROPS2, 2 if _hash(cell.x, cell.y, 13) % 3 else 3)   # statue / pillar
	else:
		_ci.draw_texture_rect_region(PROPS_TEX, Rect2(o, Vector2(TILE, TILE)),
			Rect2(PROP_INDEX[t] * TILE, 0, TILE, TILE))


func _draw_ground(o: Vector2, cell: Vector2i, t: String) -> void:
	var x := cell.x
	var y := cell.y
	var grassy := _ground_grassy(cell)
	if grassy:
		_env(o, ROW_GROUND, [0, 0, 2, 2, 1, 3, 0][_hash(x, y) % 7])
	else:
		_env(o, ROW_FLOOR, _hash(x, y, 4) % 8)
		# Moss creeping in from grassy neighbours.
		var n := _ground_grassy(cell + Vector2i.UP)
		var e := _ground_grassy(cell + Vector2i.RIGHT)
		var s := _ground_grassy(cell + Vector2i.DOWN)
		var w := _ground_grassy(cell + Vector2i.LEFT)
		if n: _env(o, ROW_FRINGE, 0)
		if e: _env(o, ROW_FRINGE, 1)
		if s: _env(o, ROW_FRINGE, 2)
		if w: _env(o, ROW_FRINGE, 3)
		if not n and not e and _ground_grassy(cell + Vector2i(1, -1)): _env(o, ROW_FRINGE, 4)
		if not s and not e and _ground_grassy(cell + Vector2i(1, 1)): _env(o, ROW_FRINGE, 5)
		if not s and not w and _ground_grassy(cell + Vector2i(-1, 1)): _env(o, ROW_FRINGE, 6)
		if not n and not w and _ground_grassy(cell + Vector2i(-1, -1)): _env(o, ROW_FRINGE, 7)
		# Scattered detail: pebbles, cracks, bones, leaves, puddles...
		var hd := _hash(x, y, 11) % 100
		if hd < 9:
			_env(o, ROW_DECAL, hd % 7)
		elif hd < 17 and not PROP_INDEX.has(t):
			_decor(o, B_CRYPT, _hash(x, y, 12) % 8)
		elif hd < 20 and not PROP_INDEX.has(t):
			_rock(o, ROCK_PEBBLES, PAL_GREY, hd % 4)
	if t == "w":
		_env(o, ROW_GROUND, 4 + _hash(x, y, 5) % 2)
	# Ambient occlusion where the floor meets walls.
	var wn := tile_at(cell + Vector2i.UP) == "#"
	var we := tile_at(cell + Vector2i.RIGHT) == "#"
	var ww := tile_at(cell + Vector2i.LEFT) == "#"
	if wn: _env(o, ROW_AO, 0)
	if we: _env(o, ROW_AO, 1)
	if ww: _env(o, ROW_AO, 2)
	if not wn and not we and tile_at(cell + Vector2i(1, -1)) == "#": _env(o, ROW_AO, 3)
	if not wn and not ww and tile_at(cell + Vector2i(-1, -1)) == "#": _env(o, ROW_AO, 4)
	if tile_at(cell + Vector2i.DOWN) == "#": _env(o, ROW_AO, 5)
	if wn and ww and not grassy and _hash(x, y, 12) % 3 == 0:
		_env(o, ROW_DECAL, 7)   # cobweb in the corner
	if PROP_INDEX.has(t) and _prop_rock(cell, B_CRYPT).x < 0 and not _baking:
		Shadows.oval(self, o + Vector2(8, 14), 12 if t != "x" else 9)
		_ci.draw_texture_rect_region(PROPS_TEX, Rect2(o, Vector2(TILE, TILE)),
			Rect2(PROP_INDEX[t] * TILE, 0, TILE, TILE))


func _draw_water(o: Vector2, cell: Vector2i) -> void:
	_env(o, ROW_WATER, (_water_frame + (cell.x + cell.y) % 2 * 2) % 4)
	if tile_at(cell + Vector2i.UP) != "~": _env(o, ROW_WATER, 4)
	if tile_at(cell + Vector2i.RIGHT) != "~": _env(o, ROW_WATER, 5)
	if tile_at(cell + Vector2i.DOWN) != "~": _env(o, ROW_WATER, 6)
	if tile_at(cell + Vector2i.LEFT) != "~": _env(o, ROW_WATER, 7)


func _draw_wall(o: Vector2, cell: Vector2i) -> void:
	if tile_at(cell + Vector2i.DOWN) != "#":
		# Front face of the wall, seen from the floor to its south.
		var h := _hash(cell.x, cell.y, 9) % 20
		_env(o, ROW_FACE, 0 if h < 11 else (h - 10 if h < 17 else 0))
		# Shade the face's ends where it turns a corner.
		if tile_at(cell + Vector2i.LEFT) != "#":
			_ci.draw_rect(Rect2(o, Vector2(2, TILE)), Color(0, 0, 0, 0.35))
		if tile_at(cell + Vector2i.RIGHT) != "#":
			_ci.draw_rect(Rect2(o + Vector2(TILE - 2, 0), Vector2(2, TILE)), Color(0, 0, 0, 0.45))
		return
	var mask := 0
	if tile_at(cell + Vector2i.UP) != "#": mask |= 1
	if tile_at(cell + Vector2i.RIGHT) != "#": mask |= 2
	if tile_at(cell + Vector2i.LEFT) != "#": mask |= 4
	_env(o, ROW_TOP, mask)
