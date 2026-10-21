class_name LabyrinthGenerator
extends RefCounted
## Builds a fresh labyrinth from a seed.
##
## 0. Split the map into zones (~30 x 27 tiles) and give each a LANDSCAPE:
##      crypt      rooms and winding stone corridors (the classic labyrinth)
##      forest     open woodland clearings walled in by trees
##      courtyard  big ruined plazas with statues and pillars, under the sky
##      mountain   rocky ledges and gullies between cliffs (waterfalls!)
##      river      misty marsh cut by a river with a few bridges
##      swamp      murky pools, mud and gnarled trees in a green fog
##    Open landscapes are carved as one organic area per zone; they join the
##    rest of the labyrinth through narrow gaps, so doors still have chokepoints.
## 1. Scatter rooms in crypt zones (odd-aligned so they line up with the corridor grid).
## 2. Fill the gaps with winding maze corridors.
## 3. Knock openings between rooms and corridors until everything is joined,
##    plus a few extra openings so there are loops, not just one path.
## 4. Fill in most dead ends (some are kept: good hiding spots for chests).
## 5. Theme each room (garden, graveyard, flooded, bare) and dress corridors.
##
## Output uses the same map legend as World (see world.gd).
## Milestone 5 layers doors and keys on top of the openings made in step 3.

const WALL := "#"
const WALKABLE := ".,wxm"
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

## Tuning
const TILES_PER_ROOM := 340   # one room per this many map tiles of crypt
## The crypt's corridors are wide: the maze is laid out in blocks of 3 x 3
## tiles, 4 apart (3 of floor, 1 of wall). Most links between blocks are as
## wide as the corridor; a few are a single-tile doorway (where the doors go).
const PITCH := 4
const CW := 3
const NARROW_LINK := 0.3     # share of maze links that are one tile wide
const WINDING := 0.45         # chance a corridor turns instead of going straight
const EXTRA_OPENING := 0.0    # loops are added later by Doors, inside sections only
const KEEP_DEAD_END := 0.3    # chance a dead end survives pruning
const LOCAL_CHECK := 8        # how far (tiles) the cheap "still connected?" check looks
const ZONE_COLS := 8   # two more columns than the landscapes need: room for the villages
const ZONE_ROWS := 5
const BIOMES: Array[String] = ["crypt", "forest", "courtyard", "mountain", "river", "swamp"]
const BIOME_WEIGHTS := [46, 13, 10, 11, 10, 10]
const SAME_AS_NEIGHBOR := 0.35   # landscapes clump together a bit
## Rare lands (not in every labyrinth). Each is built on one of the usual
## landscapes (so doors, keys, chests and traps work as ever), then dressed as
## its own: see _pick_rare_lands / _decorate_rare, and rare_lands.gd for the rest.
const R_NONE := 0
const R_BEACH := 1      ## rare: only on the map's edge -- a shore, then open sea
const R_JUNGLE := 2     ## rare: murky channels everywhere, bridges over them, jungle trees
const R_SNOW := 3       ## rare: snowy peaks
const R_VOLCANO := 4    ## rare: lava rivers and flows that burn
const R_GOLD := 5       ## extremely rare: one great gold slab, molten gold, rubies, no creatures
const RARE_BASE := {R_BEACH: 4, R_JUNGLE: 5, R_SNOW: 3, R_VOLCANO: 3, R_GOLD: 2}
const RARE_CHANCES := [0.45, 0.4, 0.15]   ## how many rare lands a labyrinth has: none, one, two
const GOLD_CHANCE := 0.04                 ## the gold vault: about one labyrinth in 25

var w := 0
var h := 0
var rng := RandomNumberGenerator.new()
var cells := PackedStringArray()
var region := PackedInt32Array()
var room_of := PackedInt32Array()
var rooms: Array[Rect2i] = []
var room_themes: Array[String] = []
var start := Vector2i.ZERO
var biome := PackedByteArray()        # per tile: index into BIOMES
var zones: Array[Rect2i] = []          # zone rects (walls on their edges)
var zone_biome: Array[int] = []
var zone_rare: Array[int] = []    # per zone: R_NONE or a rare land
var lava := {}                    # walkable cells a lava flow runs over (they burn)
var _start_zone := -1
var villages: Array = []          # see _stamp_village()
var _village_host := {}           # zone index -> the landscape around that village
var _goal := Vector2i.ZERO
var heights := PackedByteArray()  # per tile: 0 ground, 1 raised, 2 raised again
var cliffs := {}                  # cell -> the level above it: the cliff / ledge around raised ground (a wall)
var ramps := {}                   # cell -> "s" / "w" / "e": the slope or stairs up onto raised ground
var _region_count := 0
var _current_region := -1


func generate(width: int, height: int, seed_value: int) -> Dictionary:
	w = width | 1
	h = height | 1
	rng.seed = seed_value
	cells.resize(w * h)
	cells.fill(WALL)
	region.resize(w * h)
	region.fill(-1)
	room_of.resize(w * h)
	room_of.fill(-1)
	biome.resize(w * h)
	biome.fill(0)
	heights.resize(w * h)
	heights.fill(0)

	var left_side := rng.randf() < 0.5
	_make_zones(left_side)
	_pick_rare_lands(seed_value)
	for zi in zones.size():
		if zone_biome[zi] != 0:
			_carve_open_zone(zi)
	var crypt_area := 0
	for b in biome:
		if b == 0:
			crypt_area += 1
	_place_rooms(maxi(6, crypt_area / TILES_PER_ROOM))
	for y in range(1, h - CW, PITCH):
		for x in range(1, w - CW, PITCH):
			if _block_free(Vector2i(x, y)):
				_grow_maze(Vector2i(x, y))
	_connect_regions()
	_remove_islands()
	_prune_blocks()
	_prune_dead_ends()

	# Start in the crypt zone at the left or right edge, so the way out
	# crosses the whole map.
	var edge_rooms: Array[int] = []
	for i in rooms.size():
		if zones[_start_zone].has_point(rooms[i].get_center()):
			edge_rooms.append(i)
	if edge_rooms.is_empty():
		for i in rooms.size():
			var cx := rooms[i].get_center().x
			if (left_side and cx < w * 0.2) or (not left_side and cx > w * 0.8):
				edge_rooms.append(i)
	var start_room := edge_rooms[rng.randi() % edge_rooms.size()] if not edge_rooms.is_empty() \
		else rng.randi() % rooms.size()
	if _start_room >= 0:
		start_room = _start_room
	start = _room_center(rooms[start_room])
	_decorate(start_room)
	_settle_rare_lands()
	_decorate_open_zones()
	var goal := _farthest_cell(start)
	_goal = goal

	var rows: Array[String] = []
	for y in h:
		rows.append("".join(cells.slice(y * w, (y + 1) * w)))
	return {
		"rows": rows, "start": start, "goal": goal,
		"rooms": rooms, "themes": room_themes, "seed": seed_value, "biome": biome,
		"zones": zones, "zone_biome": zone_biome, "villages": villages, "nooks": nooks, "links": _open_links(),
		"zone_rare": zone_rare, "lava": lava,
	}


# --- Grid helpers -------------------------------------------------------------

func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func _at(c: Vector2i) -> String:
	return cells[c.y * w + c.x] if _in_bounds(c) else WALL


func _put(c: Vector2i, ch: String) -> void:
	cells[c.y * w + c.x] = ch


func _carve(c: Vector2i) -> void:
	_put(c, ".")
	region[c.y * w + c.x] = _current_region


func _start_region() -> void:
	_current_region = _region_count
	_region_count += 1


func _walkable(c: Vector2i) -> bool:
	return WALKABLE.contains(_at(c))


func _room_center(r: Rect2i) -> Vector2i:
	return r.position + r.size / 2


# --- 1. Rooms ----------------------------------------------------------------

## The Waking Chamber: every run begins in this same room (9 x 7), carved
## first, in the middle of the start zone. Its furniture never changes.
const START_ROOM_SIZE := Vector2i(9, 7)
var _start_room := -1


func _place_start_room() -> void:
	var z := zones[_start_zone]
	var c := z.get_center()
	var rx := int((c.x - START_ROOM_SIZE.x / 2) / PITCH) * PITCH + 1
	var ry := int((c.y - START_ROOM_SIZE.y / 2) / PITCH) * PITCH + 1
	var r := Rect2i(Vector2i(rx, ry), START_ROOM_SIZE)
	if not _all_crypt(r.grow(1)):
		return
	rooms.append(r)
	_start_room = rooms.size() - 1
	_start_region()
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_carve(Vector2i(x, y))
			room_of[y * w + x] = _start_room


func _place_rooms(max_rooms: int) -> void:
	_place_start_room()
	for attempt in max_rooms * 30:
		var rw := (2 if rng.randf() < 0.6 else 3) * PITCH - 1   # 7 or 11
		var rh := (2 if rng.randf() < 0.75 else 3) * PITCH - 1   # 7 or 11
		var rx := rng.randi_range(0, (w - rw - 2) / PITCH) * PITCH + 1
		var ry := rng.randi_range(0, (h - rh - 2) / PITCH) * PITCH + 1
		var r := Rect2i(rx, ry, rw, rh)
		if not _all_crypt(r.grow(1)):
			continue
		var overlaps := false
		for other in rooms:
			if r.grow(1).intersects(other):
				overlaps = true
				break
		if overlaps:
			continue
		rooms.append(r)
		_start_region()
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				_carve(Vector2i(x, y))
				room_of[y * w + x] = rooms.size() - 1
		if rooms.size() >= max_rooms:
			return


# --- 0. Landscapes ---------------------------------------------------------------

func _crypt(c: Vector2i) -> bool:
	return _in_bounds(c) and biome[c.y * w + c.x] == 0


func _all_crypt(r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not _crypt(Vector2i(x, y)):
				return false
	return true


## Splits the map into a grid of zones and picks each one's landscape.
## Zone edges sit on even coordinates, so they line up with the maze walls.
func _make_zones(left_side: bool) -> void:
	var xs: Array[int] = []
	var ys: Array[int] = []
	for i in ZONE_COLS + 1:
		xs.append(int(round(float(i) * (w - 1) / ZONE_COLS / 4.0)) * 4)
	for i in ZONE_ROWS + 1:
		ys.append(int(round(float(i) * (h - 1) / ZONE_ROWS / 4.0)) * 4)
	xs[-1] = w - 1
	ys[-1] = h - 1
	var start_row := rng.randi() % ZONE_ROWS
	for zy in ZONE_ROWS:
		for zx in ZONE_COLS:
			var r := Rect2i(xs[zx], ys[zy], xs[zx + 1] - xs[zx] + 1, ys[zy + 1] - ys[zy] + 1)
			zones.append(r)
			var b := _pick_biome()
			# clump: sometimes copy the zone to the left or above
			if rng.randf() < SAME_AS_NEIGHBOR:
				if zx > 0 and rng.randf() < 0.5:
					b = zone_biome[zones.size() - 2]
				elif zy > 0:
					b = zone_biome[zones.size() - 1 - ZONE_COLS]
			var is_start := zy == start_row and zx == (0 if left_side else ZONE_COLS - 1)
			if is_start:
				b = 0
				_start_zone = zones.size() - 1
			zone_biome.append(b)
	for zi in zones.size():
		var r := zones[zi]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				biome[y * w + x] = zone_biome[zi]


## Which rare lands this labyrinth has, and where (its own dice: the usual
## landscapes come out as they always would). Never the starting zone; the
## beach only on the map's edge, facing out to sea.
func _pick_rare_lands(seed_value: int) -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value * 7919 + 4243
	zone_rare.resize(zones.size())
	zone_rare.fill(R_NONE)
	var wanted: Array[int] = []
	var roll := dice.randf()
	var count := 0 if roll < RARE_CHANCES[0] else (1 if roll < RARE_CHANCES[0] + RARE_CHANCES[1] else 2)
	var kinds: Array[int] = [R_BEACH, R_JUNGLE, R_SNOW, R_VOLCANO]
	for n in count:
		var k: int = kinds[dice.randi() % kinds.size()]
		kinds.erase(k)
		wanted.append(k)
	if dice.randf() < GOLD_CHANCE:
		wanted.append(R_GOLD)
	for k in wanted:
		var options: Array[int] = []
		for zi in zones.size():
			if zi == _start_zone or zone_rare[zi] != R_NONE or zone_biome[zi] == 0:
				continue   # (only open land becomes a rare land: the crypts stay as they are)
			var zx := zi % ZONE_COLS
			var zy := zi / ZONE_COLS
			var edge := zy == 0 or zy == ZONE_ROWS - 1
			if k == R_BEACH and not edge:
				continue   # (the sea is only above and below: the start and the end are left and right)
			if k == R_GOLD and (edge or zx == 0 or zx == ZONE_COLS - 1):
				continue   # the vault lies deep inside
			# not right beside the start
			var s := _start_zone
			if absi(zx - s % ZONE_COLS) + absi(zy - s / ZONE_COLS) <= 1:
				continue
			options.append(zi)
		if options.is_empty():
			continue
		var zi: int = options[dice.randi() % options.size()]
		zone_rare[zi] = k


## The rare lands take on the landscape they're built on (after the zones are
## carved and joined, so everything up to here is just as it would be).
func _settle_rare_lands() -> void:
	for zi in zones.size():
		if zone_rare[zi] == R_NONE:
			continue
		zone_biome[zi] = RARE_BASE[zone_rare[zi]]
		var r := zones[zi]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				biome[y * w + x] = zone_biome[zi]


## The map edge a beach zone faces (UP or DOWN), or ZERO.
func sea_side(zi: int) -> Vector2i:
	var zy := zi / ZONE_COLS
	if zy == 0:
		return Vector2i.UP
	if zy == ZONE_ROWS - 1:
		return Vector2i.DOWN
	return Vector2i.ZERO


## Dresses a rare land.
func _decorate_rare(zi: int, r: Rect2i, cells_in: Array[Vector2i]) -> void:
	match zone_rare[zi]:
		R_BEACH:
			# sand, then the shore: the sea comes in over the side facing out
			var side := sea_side(zi)
			var phase := rng.randf() * TAU
			var cells_sorted := cells_in.duplicate()
			cells_sorted.sort_custom(func(a, b): return (a.y if side == Vector2i.UP else -a.y) < (b.y if side == Vector2i.UP else -b.y))
			for c: Vector2i in cells_sorted:
				var from_edge: int = (c.y - r.position.y) if side == Vector2i.UP else (r.end.y - 1 - c.y)
				var coast := 4.0 + sin(phase + c.x * 0.31) * 1.6 + sin(phase * 2.0 + c.x * 0.13) * 1.2
				if float(from_edge) < coast:
					_try_block(c, "~")
			for c in cells_in:
				if _at(c) == "." and rng.randf() < 0.02:
					_try_block(c, "b")      # driftwood and rocks
				elif _at(c) == "." and rng.randf() < 0.01:
					_try_place(c, "x")      # bleached bones
			_pools(r, cells_in, 2)          # tide pools
		R_JUNGLE:
			for c in cells_in:
				var roll := rng.randf()
				if roll < 0.5:
					_put(c, ",")
				elif roll < 0.62:
					_put(c, "w")
			for n in 3:
				_river(r)                   # murky channels, each with its bridges
			_pools(r, cells_in, 10)
			for c in cells_in:
				var roll := rng.randf()
				if roll < 0.035:
					_try_block(c, "b")      # thick undergrowth
				elif roll < 0.05:
					_try_place(c, "m")
		R_SNOW:
			for c in cells_in:
				var roll := rng.randf()
				if roll < 0.06:
					_try_block(c, "b")      # snow-buried boulders
				elif roll < 0.07:
					_try_place(c, "x")
			_pools(r, cells_in, 3)          # frozen tarns
		R_VOLCANO:
			for c in cells_in:
				if rng.randf() < 0.05:
					_try_block(c, "b")      # black rock
			for n in 2:
				_river(r)                   # rivers of lava, crusted over in places
			_pools(r, cells_in, 9)          # lava pools
			# lava flows over the ground: they burn, but never close a way
			# through (each one could be a wall without cutting anything off)
			var flows: Array[Vector2i] = []
			for c in cells_in:
				if _at(c) != "." or c == start:
					continue
				var by_lava := false
				for d in DIRS:
					if _at(c + d) == "~":
						by_lava = true
				if by_lava and rng.randf() < 0.6:
					_try_block(c, "~")
					if _at(c) == "~":
						flows.append(c)
						lava[c] = true
			for c in flows:
				_put(c, ".")
		R_GOLD:
			# one great slab of gold, edge to edge (only ever opening things
			# up), with rivers of molten gold across it
			var inner := r.grow(-2)
			for y in range(inner.position.y, inner.end.y):
				for x in range(inner.position.x, inner.end.x):
					if _at(Vector2i(x, y)) != ".":
						_put(Vector2i(x, y), ".")
			cells_in.clear()
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if _at(Vector2i(x, y)) == ".":
						cells_in.append(Vector2i(x, y))
			for n in 2:
				_river(r)
			_pools(r, cells_in, 3)


func _pick_biome() -> int:
	var total := 0
	for wt in BIOME_WEIGHTS:
		total += wt
	var r := rng.randi() % total
	for i in BIOME_WEIGHTS.size():
		r -= BIOME_WEIGHTS[i]
		if r < 0:
			return i
	return 0


## Carves one open landscape zone: an organic open area (cellular automaton),
## kept in one piece, with paths out to the middle of each zone edge so it can
## join its neighbours.
func _carve_open_zone(zi: int) -> void:
	var r := zones[zi]
	var inner := r.grow(-1)
	var kind: String = BIOMES[zone_biome[zi]]
	var open_chance: float = {"forest": 0.47, "courtyard": 0.0, "mountain": 0.43, "river": 0.52, "swamp": 0.55}[kind]
	var grid := {}
	if kind == "courtyard":
		# one or two big plazas
		for n in rng.randi_range(1, 2):
			var pw := rng.randi_range(int(inner.size.x * 0.45), int(inner.size.x * 0.8))
			var ph := rng.randi_range(int(inner.size.y * 0.45), int(inner.size.y * 0.8))
			var px := inner.position.x + rng.randi_range(0, inner.size.x - pw)
			var py := inner.position.y + rng.randi_range(0, inner.size.y - ph)
			for y in range(py, py + ph):
				for x in range(px, px + pw):
					grid[Vector2i(x, y)] = true
	else:
		for y in range(inner.position.y, inner.end.y):
			for x in range(inner.position.x, inner.end.x):
				# thinner toward the zone edges, so areas are rounded, not square
				var edge := mini(mini(x - inner.position.x, inner.end.x - 1 - x), mini(y - inner.position.y, inner.end.y - 1 - y))
				var fall := clampf(float(edge) / 4.0, 0.0, 1.0)
				if rng.randf() < open_chance * (0.55 + 0.45 * fall):
					grid[Vector2i(x, y)] = true
		for it in 5:
			var next := {}
			for y in range(inner.position.y, inner.end.y):
				for x in range(inner.position.x, inner.end.x):
					var walls := 0
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							if (dx != 0 or dy != 0) and not grid.has(Vector2i(x + dx, y + dy)):
								walls += 1
					if walls < 5:
						next[Vector2i(x, y)] = true
			grid = next
	# paths from the middle out to each edge (so neighbours can connect)
	var mid := inner.get_center()
	# path ends on odd coordinates, where the crypt maze's corridors run
	var ends: Array[Vector2i] = [
		Vector2i((mid.x + rng.randi_range(-3, 3)) | 1, inner.position.y), Vector2i((mid.x + rng.randi_range(-3, 3)) | 1, inner.end.y - 1),
		Vector2i(inner.position.x, (mid.y + rng.randi_range(-3, 3)) | 1), Vector2i(inner.end.x - 1, (mid.y + rng.randi_range(-3, 3)) | 1)]
	for e in ends:
		var c := mid
		while c != e:
			grid[c] = true
			if kind != "courtyard":
				grid[c + Vector2i(1, 0)] = inner.has_point(c + Vector2i(1, 0))
			var d := e - c
			if absi(d.x) > absi(d.y) or (absi(d.x) > 0 and rng.randf() < 0.3):
				c.x += signi(d.x)
			else:
				c.y += signi(d.y)
		grid[e] = true
	for k in grid.keys():
		if not grid[k] or not inner.has_point(k):
			grid.erase(k)
	# keep the biggest connected piece
	var best := {}
	var seen := {}
	for c in grid:
		if seen.has(c):
			continue
		var comp := {c: true}
		var q: Array[Vector2i] = [c]
		var head := 0
		while head < q.size():
			var p: Vector2i = q[head]
			head += 1
			for d in DIRS:
				var n := p + d
				if grid.has(n) and not comp.has(n):
					comp[n] = true
					q.append(n)
		for k in comp:
			seen[k] = true
		if comp.size() > best.size():
			best = comp
	_start_region()
	for c in best:
		_carve(c)


## Dresses each open landscape.
func _decorate_open_zones() -> void:
	for zi in zones.size():
		var kind: String = BIOMES[zone_biome[zi]]
		if kind == "crypt":
			continue
		var r := zones[zi]
		var cells_in: Array[Vector2i] = []
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if _at(Vector2i(x, y)) == ".":
					cells_in.append(Vector2i(x, y))
		if cells_in.is_empty():
			continue   # this zone got filled in (it couldn't be joined up)
		if zone_rare[zi] != R_NONE:
			_decorate_rare(zi, r, cells_in)
			continue
		match kind:
			"forest":
				for c in cells_in:
					var roll := rng.randf()
					if roll < 0.55:
						_put(c, ",")
					elif roll < 0.62:
						_put(c, "w")
				for c in cells_in:
					var roll := rng.randf()
					if roll < 0.03:
						_try_block(c, "b")      # bushes
					elif roll < 0.045:
						_try_place(c, "m")
					elif roll < 0.05:
						_try_place(c, "x")
			"courtyard":
				# statues / pillars on a loose grid, grass in the cracks
				for c in cells_in:
					if c.x % 4 == 0 and c.y % 4 == 0 and rng.randf() < 0.55:
						_try_block(c, "g")
					elif rng.randf() < 0.18:
						_put(c, ",")
				for n in 2:
					_no_candle(cells_in[rng.randi() % cells_in.size()])
			"mountain":
				for c in cells_in:
					var roll := rng.randf()
					if roll < 0.05:
						_try_block(c, "b")      # boulders
					elif roll < 0.12:
						_put(c, ",")
					elif roll < 0.13:
						_try_place(c, "x")
				_pools(r, cells_in, 2)
			"river":
				_river(r)
				for c in cells_in:
					if _at(c) == "." and rng.randf() < 0.5:
						_put(c, ",")
				for c in cells_in:
					if _at(c) == "," and rng.randf() < 0.03:
						_try_place(c, "m")
				_pools(r, cells_in, 3)
			"swamp":
				for c in cells_in:
					var roll := rng.randf()
					if roll < 0.3:
						_put(c, ",")
					elif roll < 0.36:
						_put(c, "w")
				_pools(r, cells_in, 14)
				for c in cells_in:
					var roll := rng.randf()
					if roll < 0.025:
						_try_place(c, "m")
					elif roll < 0.04:
						_try_block(c, "b")      # dead snags
					elif roll < 0.047:
						_try_place(c, "x")


## Little ponds (only where they don't cut anything off).
func _pools(r: Rect2i, cells_in: Array[Vector2i], count: int) -> void:
	for n in count:
		if cells_in.is_empty():
			return
		var c: Vector2i = cells_in[rng.randi() % cells_in.size()]
		for k in rng.randi_range(4, 12):
			_try_block(c, "~")
			c += DIRS[rng.randi() % 4]
			if not r.grow(-1).has_point(c):
				break


## A river winding across the zone, with a couple of bridges.
## Undone if it would cut the zone in two.
func _river(r: Rect2i) -> void:
	var inner := r.grow(-2)
	var horizontal := rng.randf() < 0.5
	var length := inner.size.x if horizontal else inner.size.y
	var across := inner.size.y if horizontal else inner.size.x
	var base := across / 2 + rng.randi_range(-across / 5, across / 5)
	var phase := rng.randf() * TAU
	var bridges := [rng.randi_range(2, length / 2 - 2), rng.randi_range(length / 2 + 2, length - 3)]
	var changed := {}
	for i in length:
		if absi(i - bridges[0]) <= 0 or absi(i - bridges[1]) <= 0:
			continue
		var mid := base + int(round(sin(phase + i * 0.25) * across * 0.18))
		for k in range(-1, 1):
			var c := Vector2i(inner.position.x + i, inner.position.y + mid + k) if horizontal \
				else Vector2i(inner.position.x + mid + k, inner.position.y + i)
			if _at(c) == "." or _at(c) == ",":
				changed[c] = _at(c)
				_put(c, "~")
	# still in one piece?
	var start_c := Vector2i(-1, -1)
	var total := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _walkable(Vector2i(x, y)):
				total += 1
				start_c = Vector2i(x, y)
	if start_c.x < 0:
		return
	var seen := {start_c: true}
	var q: Array[Vector2i] = [start_c]
	var head := 0
	while head < q.size():
		var p: Vector2i = q[head]
		head += 1
		for d in DIRS:
			var n := p + d
			if r.has_point(n) and not seen.has(n) and _walkable(n):
				seen[n] = true
				q.append(n)
	if seen.size() != total:
		for c in changed:
			_put(c, changed[c])


# --- 2. Maze corridors ---------------------------------------------------------

## The 3 x 3 block at `tl` (its top-left tile) is all crypt and all wall.
func _block_free(tl: Vector2i) -> bool:
	if tl.x < 1 or tl.y < 1 or tl.x + CW >= w or tl.y + CW >= h:
		return false
	for y in range(tl.y - 1, tl.y + CW + 1):
		for x in range(tl.x - 1, tl.x + CW + 1):
			var c := Vector2i(x, y)
			var inside := x >= tl.x and x < tl.x + CW and y >= tl.y and y < tl.y + CW
			if inside and (not _crypt(c) or _at(c) != WALL):
				return false
			if not inside and not _crypt(c) and _at(c) != WALL:
				return false   # (the wall around a landscape may border the maze)
	return true


func _carve_block(tl: Vector2i) -> void:
	for y in range(tl.y, tl.y + CW):
		for x in range(tl.x, tl.x + CW):
			_carve(Vector2i(x, y))
	_blocks[tl] = true


## The wall tiles between block `tl` and its neighbour in direction `d`.
func _link_cells(tl: Vector2i, d: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for k in CW:
		if d.x > 0:
			out.append(Vector2i(tl.x + CW, tl.y + k))
		elif d.x < 0:
			out.append(Vector2i(tl.x - 1, tl.y + k))
		elif d.y > 0:
			out.append(Vector2i(tl.x + k, tl.y + CW))
		else:
			out.append(Vector2i(tl.x + k, tl.y - 1))
	return out


var _blocks := {}   # top-left tile of every carved maze block
var nooks := {}     # the far end of each wide dead end (chests and loot like these)
var _wide_links: Array = []   # the 3 tiles of each full-width link between maze blocks


## Wide links still fully open (Doors may narrow one to a doorway for a door).
func _open_links() -> Array:
	var out: Array = []
	for l in _wide_links:
		if _walkable(l[0]) and _walkable(l[1]) and _walkable(l[2]):
			out.append(l)
	return out


func _grow_maze(from: Vector2i) -> void:
	_start_region()
	_carve_block(from)
	var stack: Array[Vector2i] = [from]
	var last_dir := Vector2i.ZERO
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for d in DIRS:
			if _block_free(c + d * PITCH):
				options.append(d)
		if options.is_empty():
			stack.pop_back()
			last_dir = Vector2i.ZERO
			continue
		var dir: Vector2i
		if options.has(last_dir) and rng.randf() > WINDING:
			dir = last_dir
		else:
			dir = options[rng.randi() % options.size()]
		var link := _link_cells(c, dir)
		if rng.randf() < NARROW_LINK:
			_carve(link[1])   # a doorway, one tile wide
		else:
			for l in link:
				_carve(l)
			_wide_links.append(link)
		_carve_block(c + dir * PITCH)
		stack.append(c + dir * PITCH)
		last_dir = dir


## Fills in most dead-end blocks of the wide maze (a block with one way out),
## and the link that led into it, then looks again at the block it led to.
func _prune_blocks() -> void:
	var keep := {}
	var queue: Array[Vector2i] = []
	queue.assign(_blocks.keys())
	var head := 0
	while head < queue.size():
		var tl: Vector2i = queue[head]
		head += 1
		if not _blocks.has(tl) or keep.has(tl) or _at(tl) == WALL:
			continue
		var exits: Array[Vector2i] = []
		for d in DIRS:
			for l in _link_cells(tl, d):
				if _at(l) != WALL:
					exits.append(d)
					break
		if exits.size() != 1:
			continue
		var d: Vector2i = exits[0]
		if rng.randf() < KEEP_DEAD_END:
			keep[tl] = true
			nooks[tl + Vector2i.ONE - d] = true   # the back of the dead end
			continue
		var blocked_room := false
		for l in _link_cells(tl, d):
			if room_of[l.y * w + l.x] >= 0:
				blocked_room = true
		if blocked_room:
			continue
		for y in range(tl.y, tl.y + CW):
			for x in range(tl.x, tl.x + CW):
				_put(Vector2i(x, y), WALL)
		for l in _link_cells(tl, d):
			_put(l, WALL)
		_blocks.erase(tl)
		queue.append(tl + d * PITCH)


# --- 3. Connect everything ------------------------------------------------------

func _connect_regions() -> void:
	# Kruskal-style: walk every possible opening in random order; open it if it
	# joins two things that aren't joined yet (union-find), and now and then
	# open one anyway to make a loop. Never two openings side by side.
	var connectors: Array[Vector2i] = []
	var touching := {}
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var c := Vector2i(x, y)
			if _at(c) != WALL:
				continue
			var regs := {}
			for d in DIRS:
				var r := region[(c + d).y * w + (c + d).x]
				if r != -1:
					regs[r] = true
			if regs.size() >= 2:
				connectors.append(c)
				touching[c] = regs.keys()
	for i in range(connectors.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp := connectors[i]
		connectors[i] = connectors[j]
		connectors[j] = tmp
	var parent := PackedInt32Array()
	parent.resize(_region_count)
	for i in _region_count:
		parent[i] = i
	var opened := {}
	for pass_n in 2:
		for c in connectors:
			if opened.has(c):
				continue
			if pass_n == 0:
				var crowded := false
				for d in DIRS:
					if opened.has(c + d):
						crowded = true
				if crowded:
					continue
			var roots := {}
			for r in touching[c]:
				roots[_find(parent, r)] = true
			if roots.size() > 1:
				var keys := roots.keys()
				for k in range(1, keys.size()):
					parent[keys[k]] = keys[0]
				_put(c, ".")
				opened[c] = true
			elif pass_n == 0 and rng.randf() < EXTRA_OPENING:
				_put(c, ".")
				opened[c] = true


## Anything that didn't get joined to the main labyrinth is filled back in,
## so every open tile can be reached.
func _remove_islands() -> void:
	var comp := PackedInt32Array()
	comp.resize(w * h)
	comp.fill(-1)
	var sizes: Array[int] = []
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var c := Vector2i(x, y)
			if _at(c) == WALL or comp[y * w + x] >= 0:
				continue
			var id := sizes.size()
			var count := 0
			var q: Array[Vector2i] = [c]
			comp[y * w + x] = id
			var head := 0
			while head < q.size():
				var p: Vector2i = q[head]
				head += 1
				count += 1
				for d in DIRS:
					var n := p + d
					if _in_bounds(n) and _at(n) != WALL and comp[n.y * w + n.x] < 0:
						comp[n.y * w + n.x] = id
						q.append(n)
			sizes.append(count)
	var biggest := 0
	for i in sizes.size():
		if sizes[i] > sizes[biggest]:
			biggest = i
	for i in w * h:
		if comp[i] >= 0 and comp[i] != biggest:
			cells[i] = WALL
			room_of[i] = -1
	# forget rooms that were filled in
	var kept: Array[Rect2i] = []
	var remap := {}
	for ri in rooms.size():
		var ctr := _room_center(rooms[ri])
		if _at(ctr) != WALL:
			remap[ri] = kept.size()
			kept.append(rooms[ri])
	for i in w * h:
		if room_of[i] >= 0:
			room_of[i] = remap.get(room_of[i], -1)
	rooms = kept


func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


# --- 4. Dead ends -----------------------------------------------------------------

func _prune_dead_ends() -> void:
	var keep := {}
	var queue: Array[Vector2i] = []
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			queue.append(Vector2i(x, y))
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if _at(c) == WALL or room_of[c.y * w + c.x] >= 0 or keep.has(c):
			continue
		var exits: Array[Vector2i] = []
		for d in DIRS:
			if _at(c + d) != WALL:
				exits.append(c + d)
		if exits.size() != 1:
			continue
		if rng.randf() < KEEP_DEAD_END:
			keep[c] = true
			continue
		_put(c, WALL)
		queue.append(exits[0])   # its neighbor may now be a dead end too


# --- 5. Decoration -----------------------------------------------------------------

func _decorate(start_room: int) -> void:
	for i in rooms.size():
		var r := rooms[i]
		var theme := "bare"
		if i == start_room:
			theme = "start"
		else:
			var roll := rng.randf()
			if roll < 0.32:
				theme = "garden"
			elif roll < 0.58:
				theme = "graveyard"
			elif roll < 0.74 and r.size.x >= 7:
				theme = "flooded"
		room_themes.append(theme)
		match theme:
			"start":
				# The Waking Chamber: a stone bier in the middle (drawn by the
				# world), two old graves, moss in the cracks.
				if r.size == START_ROOM_SIZE:
					for p in [Vector2i(1, 1), Vector2i(7, 1)]:
						_put(r.position + p, "g")
					for p in [Vector2i(1, 5), Vector2i(2, 5), Vector2i(1, 4), Vector2i(7, 5), Vector2i(6, 5), Vector2i(4, 6)]:
						_put(r.position + p, ",")
				else:
					_no_candle(r.position + Vector2i(1, 1))
					_no_candle(r.end - Vector2i(2, 2))
			"garden":
				_fill_room(r, ",")
				for n in rng.randi_range(1, 3):
					_grass_blob(_rand_in(r), rng.randi_range(4, 9), r)
				for n in rng.randi_range(1, 2):
					_try_place(_rand_in(r.grow(-1)), "m")
				if rng.randf() < 0.5:
					_try_block(_rand_in(r.grow(-1)), "b")
			"graveyard":
				for y in range(r.position.y + 1, r.end.y - 1, 2):
					for x in range(r.position.x + 1, r.end.x - 1, 2):
						if rng.randf() < 0.75:
							_try_block(Vector2i(x, y), "g")
				for n in rng.randi_range(1, 2):
					_no_candle(_rand_in(r.grow(-1)))
				for n in rng.randi_range(0, 2):
					_try_place(_rand_in(r), "x")
			"flooded":
				var inner := r.grow(-1)
				for y in range(inner.position.y, inner.end.y):
					for x in range(inner.position.x, inner.end.x):
						_put(Vector2i(x, y), "~")
				for y in range(r.position.y, r.end.y):
					for x in range(r.position.x, r.end.x):
						if _at(Vector2i(x, y)) == "." and rng.randf() < 0.5:
							_put(Vector2i(x, y), ",")
				_try_place(r.position, "m")
				_try_place(r.end - Vector2i.ONE, "m")
			_:
				for n in rng.randi_range(0, 2):
					_try_place(_rand_in(r), "x")
				for y in range(r.position.y, r.end.y):
					for x in range(r.position.x, r.end.x):
						if rng.randf() < 0.12:
							_put(Vector2i(x, y), ",")

	# Corridors: creeping moss, the odd skull or mushroom.
	var corridor: Array[Vector2i] = []
	for y in h:
		for x in w:
			if _at(Vector2i(x, y)) == "." and room_of[y * w + x] < 0 and biome[y * w + x] == 0:
				corridor.append(Vector2i(x, y))
	for n in corridor.size() / 25:
		var c: Vector2i = corridor[rng.randi() % corridor.size()]
		for step in rng.randi_range(3, 10):
			if _at(c) == ".":
				_put(c, ",")
			var nexts: Array[Vector2i] = []
			for d in DIRS:
				if _walkable(c + d):
					nexts.append(c + d)
			if nexts.is_empty():
				break
			c = nexts[rng.randi() % nexts.size()]
	for c in corridor:
		var roll := rng.randf()
		if roll < 0.02:
			_try_place(c, "x")
		elif roll < 0.03:
			_try_place(c, "m")


func _rand_in(r: Rect2i) -> Vector2i:
	return Vector2i(rng.randi_range(r.position.x, r.end.x - 1), rng.randi_range(r.position.y, r.end.y - 1))


func _fill_room(r: Rect2i, ch: String) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_put(Vector2i(x, y), ch)


func _grass_blob(c: Vector2i, steps: int, inside: Rect2i) -> void:
	for i in steps:
		if inside.has_point(c) and (_at(c) == "," or _at(c) == "."):
			_put(c, "w")
		c += DIRS[rng.randi() % 4]


## Walkable decoration: only on plain ground, never on the start tile.
func _try_place(c: Vector2i, ch: String) -> void:
	if c != start and (_at(c) == "." or _at(c) == ","):
		_put(c, ch)


## Blocking decoration: only if it doesn't cut anything off.
## Where a floor candle used to go. They're gone (too small to see on the
## floor, and they blocked the way); the spot is still picked, so the dice
## roll the same and every labyrinth -- and every saved run -- stays as it was.
func _no_candle(_c: Vector2i) -> void:
	pass


func _try_block(c: Vector2i, ch: String) -> void:
	if c == start or not (_at(c) == "." or _at(c) == ","):
		return
	var before := _at(c)
	_put(c, ch)
	if not _neighbors_still_connected(c):
		_put(c, before)


## Cheap, local version of "is everything still reachable?": the open tiles
## around `c` must still reach each other without going through `c`, within
## a small box around it. (If they do, no path anywhere was cut.)
func _neighbors_still_connected(c: Vector2i) -> bool:
	var around: Array[Vector2i] = []
	for d in DIRS:
		if _walkable(c + d):
			around.append(c + d)
	if around.size() <= 1:
		return true
	var seen := {around[0]: true}
	var queue: Array[Vector2i] = [around[0]]
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		for d in DIRS:
			var n := p + d
			if n == c or seen.has(n) or not _walkable(n):
				continue
			if absi(n.x - c.x) > LOCAL_CHECK or absi(n.y - c.y) > LOCAL_CHECK:
				continue
			seen[n] = true
			queue.append(n)
	for a in around:
		if not seen.has(a):
			return false
	return true


func _flood(from: Vector2i) -> Dictionary:
	var dist := {from: 0}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in DIRS:
			var n := c + d
			if not dist.has(n) and _walkable(n):
				dist[n] = dist[c] + 1
				queue.append(n)
	return dist


## The walkable room cell farthest (by walking) from `from`. The master
## chamber will go in this room in milestone 8.
func _farthest_cell(from: Vector2i) -> Vector2i:
	var dist := _flood(from)
	var best := from
	var best_d := -1
	for c in dist:
		if room_of[c.y * w + c.x] >= 0 and dist[c] > best_d:
			best_d = dist[c]
			best = c
	return best


# --- 6. Villages -------------------------------------------------------------------
# A few zones hold a walled village: a safe haven with a shop, a sage, an inn,
# a farm and homes. The zone is first carved like the landscape around it (so
# the open land isn't any smaller), then the village is stamped in the middle:
# a ring of open ground, the wall, two gates (north and south) and the streets.
# Every blocking thing inside (wall, buildings, fences, the well, lamp posts)
# is a wall tile "#" for the rest of the game; World and Villages draw them.

const VILLAGE_SIZES := [Vector2i(21, 17), Vector2i(23, 19), Vector2i(25, 21)]
const BUILDING_SIZE := {"shop": Vector2i(5, 4), "sage": Vector2i(4, 4), "inn": Vector2i(6, 4),
	"home": Vector2i(4, 3), "home_wide": Vector2i(5, 3)}
const VILLAGE_NAME_A := ["ASH", "BRIAR", "HOLLOW", "MILL", "WREN", "THORN", "ELDER", "STONE", "FERN",
	"MOSS", "LARK", "HAZEL", "RAVEN", "WILLOW", "CANDLE", "AMBER"]
const VILLAGE_NAME_B := ["FORD", "BROOK", "WICK", "STEAD", "VALE", "HOLM", "BURY", "CROFT", "HAVEN",
	"MERE", "DALE", "WATCH"]


func _zone_neighbors(zi: int) -> Array[int]:
	var out: Array[int] = []
	var zx := zi % ZONE_COLS
	var zy := zi / ZONE_COLS
	for d in DIRS:
		var nx := zx + d.x
		var ny := zy + d.y
		if nx >= 0 and ny >= 0 and nx < ZONE_COLS and ny < ZONE_ROWS:
			out.append(ny * ZONE_COLS + nx)
	return out


## Stamps villages into the finished labyrinth, one per zone in `picks`
## (World chooses the zones by how deep they lie). Returns the map again, as
## generate() does.
func add_villages(picks: Array) -> Dictionary:
	for zi in picks:
		var hosts: Array[int] = []
		if zone_biome[zi] != 0:
			hosts.append(zone_biome[zi])
		else:
			for n in _zone_neighbors(zi):
				if zone_biome[n] != 0:
					hosts.append(zone_biome[n])
		_village_host[zi] = hosts[rng.randi() % hosts.size()] if not hosts.is_empty() else 2
		_stamp_village(zi)
	_forget_rooms_under_villages()
	_raise_land()
	_remove_islands()
	_break_loops()
	var rows: Array[String] = []
	for y in h:
		rows.append("".join(cells.slice(y * w, (y + 1) * w)))
	return {
		"rows": rows, "start": start, "goal": _goal,
		"rooms": rooms, "themes": room_themes, "seed": 0, "biome": biome,
		"zones": zones, "zone_biome": zone_biome, "villages": villages, "nooks": nooks, "links": _open_links(),
		"zone_rare": zone_rare, "lava": lava,
		"heights": heights, "cliffs": cliffs, "ramps": ramps,
	}


# --- Loops ------------------------------------------------------------------------------
## The labyrinth should branch like a tree between its narrow places (that's
## where the doors go). Villages (two gates, a path all round the walls) and
## landscapes with several ways out make long loops. Treat every one-tile
## doorway and every full-width maze link as a "narrow place", the open areas
## between them as chambers, and keep only enough narrow places to join
## everything up (in a random order); wall up the rest.
func _break_loops() -> void:
	var node := PackedInt32Array()
	node.resize(w * h)
	node.fill(-1)
	var narrow := {}   # node id -> Array of tiles (a doorway or a whole link)
	var nid := 0
	for l in _wide_links:
		if _walkable(l[0]) and _walkable(l[1]) and _walkable(l[2]):
			for c in l:
				node[c.y * w + c.x] = nid
			narrow[nid] = l
			nid += 1
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var c := Vector2i(x, y)
			if node[y * w + x] >= 0 or not _walkable(c) or ramps.has(c):
				continue
			var ew := _walkable(c + Vector2i.LEFT) and _walkable(c + Vector2i.RIGHT) \
				and not _walkable(c + Vector2i.UP) and not _walkable(c + Vector2i.DOWN)
			var ns := _walkable(c + Vector2i.UP) and _walkable(c + Vector2i.DOWN) \
				and not _walkable(c + Vector2i.LEFT) and not _walkable(c + Vector2i.RIGHT)
			if ew or ns:
				node[y * w + x] = nid
				narrow[nid] = [c]
				nid += 1
	# chambers: everything else that's open, in connected pieces
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if node[y * w + x] >= 0 or not _walkable(Vector2i(x, y)):
				continue
			var q: Array[Vector2i] = [Vector2i(x, y)]
			node[y * w + x] = nid
			var head := 0
			while head < q.size():
				var p: Vector2i = q[head]
				head += 1
				for d in DIRS:
					var n := p + d
					if _in_bounds(n) and node[n.y * w + n.x] < 0 and _walkable(n):
						node[n.y * w + n.x] = nid
						q.append(n)
			nid += 1
	# edges: each narrow place to whatever it touches
	var edges: Array = []
	var seen_edge := {}
	for id in narrow:
		for c in narrow[id]:
			for d in DIRS:
				var n: Vector2i = c + d
				if not _in_bounds(n) or not _walkable(n):
					continue
				var other := node[n.y * w + n.x]
				if other == id or other < 0:
					continue
				var key := Vector2i(mini(id, other), maxi(id, other))
				if seen_edge.has(key):
					continue
				seen_edge[key] = true
				edges.append([id, other])
	# keep the ones by the villages first (their gates must stay open)
	var keep_first := func(e: Array) -> bool:
		for id in [e[0], e[1]]:
			if narrow.has(id):
				for c in narrow[id]:
					if _near_any_village(c, 3):
						return true
		return false
	for i in range(edges.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t: Array = edges[i]
		edges[i] = edges[j]
		edges[j] = t
	var first: Array = edges.filter(keep_first)
	var rest: Array = edges.filter(func(e): return not keep_first.call(e))
	var deg := {}
	for e in edges:
		deg[e[0]] = deg.get(e[0], 0) + 1
		deg[e[1]] = deg.get(e[1], 0) + 1
	var parent := PackedInt32Array()
	parent.resize(nid)
	for i in nid:
		parent[i] = i
	var closed := {}
	for e in first + rest:
		if closed.has(e[0]) or closed.has(e[1]):
			continue
		var a := _find(parent, e[0])
		var b := _find(parent, e[1])
		if a != b:
			parent[a] = b
			continue
		# a loop: wall up the narrow place on this edge (not by a village)
		var id: int = e[0] if narrow.has(e[0]) else e[1]
		if not narrow.has(id) or keep_first.call(e):
			continue
		if deg.get(id, 0) != 2 or (narrow[id].size() == 1 and _degree(narrow[id][0]) != 2):
			continue   # it joins more than two things: closing it could cut one off
		closed[id] = true
		for c in narrow[id]:
			_put(c, WALL)


func _degree(c: Vector2i) -> int:
	var n := 0
	for d in DIRS:
		if _walkable(c + d):
			n += 1
	return n


# --- 7. High ground ---------------------------------------------------------------------
# Out in the open land, some ground is raised a level (now and then two):
# hills and plateaus ringed by cliffs, reached only up a slope. In the crypts,
# some rooms have a raised dais at the back with a short flight of stairs.
# A cliff is just a wall tile (the ring around the raised ground) that World
# draws as a rock face or ledge; a slope / stair is a plain floor tile in that
# ring. So everything that walks the map (creatures, doors, the flood fills)
# needs nothing new.

const PLATEAU_TRIES := 3          # per open zone
const PLATEAU_CHANCE := 0.6
const PLATEAU_SIZE := [70, 160]   # tiles of ground, before the cliff ring is taken off
const DAIS_CHANCE := 0.3          # crypt rooms with a raised back


func _raise_land() -> void:
	for zi in zones.size():
		if zi == _start_zone or _village_host.has(zi) or zone_biome[zi] == 0:
			continue
		for t in PLATEAU_TRIES:
			if rng.randf() < PLATEAU_CHANCE:
				_try_plateau(zones[zi].grow(-2), 1, rng.randi_range(PLATEAU_SIZE[0], PLATEAU_SIZE[1]), {})
	for r in rooms:
		if r.has_point(start) or r.size.x < 7 or r.size.y < 5 or rng.randf() > DAIS_CHANCE:
			continue
		if _at(r.position + Vector2i(1, r.size.y - 2)) == "~" or _at(r.get_center()) == "~":
			continue   # flooded
		_try_dais(r)


func _near_any_village(c: Vector2i, reach: int) -> bool:
	for v in villages:
		if (v.rect as Rect2i).grow(reach).has_point(c):
			return true
	return false


func _flat_ground(c: Vector2i, level: int) -> bool:
	var t := _at(c)
	if not ((t == "." or t == "," or t == "w" or t == "x" or t == "m") and heights[c.y * w + c.x] == level and c != start \
			and not ramps.has(c) and not _near_any_village(c, 3)):
		return false
	# only open field: never a narrow path (walling that in would cut the way through)
	var open := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if _walkable(n) and not cliffs.has(n):
				open += 1
	return open >= 9


func _try_plateau(area: Rect2i, level: int, size: int, inside: Dictionary) -> void:
	# a compact blob of plain open ground
	var seed_c := Vector2i(-1, -1)
	for attempt in 40:
		var c := Vector2i(rng.randi_range(area.position.x, area.end.x - 1), rng.randi_range(area.position.y, area.end.y - 1))
		if _flat_ground(c, level - 1) and (inside.is_empty() or inside.has(c)):
			seed_c = c
			break
	if seed_c.x < 0:
		return
	var blob := {seed_c: true}
	var frontier: Array[Vector2i] = [seed_c]
	while blob.size() < size and not frontier.is_empty():
		# grow where the blob is fullest, so it comes out round, not stringy
		var best_n := Vector2i(-1, -1)
		var best_k := -1
		for t in 6:
			if frontier.is_empty():
				break
			var fi := rng.randi() % frontier.size()
			var c: Vector2i = frontier[fi]
			var any := false
			for d in DIRS:
				var n: Vector2i = c + d
				if blob.has(n) or not area.has_point(n) or not _flat_ground(n, level - 1):
					continue
				if not inside.is_empty() and not inside.has(n):
					continue
				any = true
				var k := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if blob.has(n + Vector2i(dx, dy)):
							k += 1
				if k > best_k:
					best_k = k
					best_n = n
			if not any:
				frontier.remove_at(fi)   # boxed in: stop growing from here
		if best_n.x < 0:
			continue
		blob[best_n] = true
		frontier.append(best_n)
	if blob.size() < 36:
		return
	# the top: every tile whose eight neighbours are all in the blob
	var top := {}
	for c in blob:
		var all_in := true
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if not blob.has(c + Vector2i(dx, dy)):
					all_in = false
		if all_in:
			top[c] = true
	if top.size() < 8:
		return
	# keep only the biggest piece of the top (the rest goes back to the ring)
	var piece := _biggest_piece(top)
	var ring: Array[Vector2i] = []
	for c in blob:
		if not piece.has(c):
			var touches := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if piece.has(c + Vector2i(dx, dy)):
						touches = true
			if touches:
				ring.append(c)
	# raise it
	var old := {}
	for c in ring:
		old[c] = _at(c)
		_put(c, WALL)
	for c in piece:
		heights[c.y * w + c.x] = level
	# one or two ways up: a slope from the south, or from a side
	var options := {"s": [], "w": [], "e": []}
	for c in ring:
		var below := level - 1
		if piece.has(c + Vector2i.UP) and _open_at(c + Vector2i.DOWN, below) and not piece.has(c + Vector2i.DOWN):
			options.s.append(c)
		elif piece.has(c + Vector2i.RIGHT) and _open_at(c + Vector2i.LEFT, below):
			options.w.append(c)
		elif piece.has(c + Vector2i.LEFT) and _open_at(c + Vector2i.RIGHT, below):
			options.e.append(c)
	var made: Array[Vector2i] = []
	var want := 1 if piece.size() < 30 or rng.randf() < 0.5 else 2
	for k in want:
		var dir := "s" if not options.s.is_empty() and (rng.randf() < 0.7 or (options.w.is_empty() and options.e.is_empty())) else ("w" if rng.randf() < 0.5 and not options.w.is_empty() else "e")
		var list: Array = options[dir]
		if list.is_empty():
			continue
		var c: Vector2i = list[rng.randi() % list.size()]
		var far_enough := true
		for m in made:
			if absi(m.x - c.x) + absi(m.y - c.y) < 6:
				far_enough = false
		if not far_enough:
			continue
		_put(c, ".")
		ramps[c] = dir
		made.append(c)
	if made.is_empty() or not _still_one_piece(ring, piece):
		for c in ring:
			_put(c, old[c])
		for c in piece:
			heights[c.y * w + c.x] = level - 1
		for c in made:
			ramps.erase(c)
		return
	for c in ring:
		if not ramps.has(c):
			cliffs[c] = level
	# now and then a second, smaller rise on top of the first
	if level == 1 and piece.size() >= 36 and rng.randf() < 0.6:
		_try_plateau(area, 2, piece.size() / 2, piece)


func _open_at(c: Vector2i, level: int) -> bool:
	return _walkable(c) and heights[c.y * w + c.x] == level and not cliffs.has(c)


func _biggest_piece(cells_in: Dictionary) -> Dictionary:
	var best := {}
	var seen := {}
	for c in cells_in:
		if seen.has(c):
			continue
		var comp := {c: true}
		var q: Array[Vector2i] = [c]
		var head := 0
		while head < q.size():
			var p: Vector2i = q[head]
			head += 1
			for d in DIRS:
				var n := p + d
				if cells_in.has(n) and not comp.has(n):
					comp[n] = true
					q.append(n)
		for k in comp:
			seen[k] = true
		if comp.size() > best.size():
			best = comp
	return best


## After walling in raised ground: can every open tile around it (and the top)
## still reach every other, nearby? (A cheap local check.)
func _still_one_piece(ring: Array[Vector2i], top: Dictionary) -> bool:
	var box := Rect2i(ring[0], Vector2i.ONE)
	for c in ring:
		box = box.expand(c)
	box = box.grow(16)
	var targets: Array[Vector2i] = []
	for c in ring:
		for d in DIRS:
			var n := c + d
			if _walkable(n) and box.has_point(n):
				targets.append(n)
	for c in top:
		targets.append(c)
		break
	if targets.is_empty():
		return false
	var seen := {targets[0]: true}
	var q: Array[Vector2i] = [targets[0]]
	var head := 0
	while head < q.size():
		var p: Vector2i = q[head]
		head += 1
		for d in DIRS:
			var n := p + d
			if not seen.has(n) and box.has_point(n) and _walkable(n):
				seen[n] = true
				q.append(n)
	for t in targets:
		if not seen.has(t):
			return false
	return true


## A crypt room with a raised dais at the back: its top two rows go up a
## level, the row below becomes a ledge, with steps in the middle.
func _try_dais(r: Rect2i) -> void:
	var ledge_y := r.position.y + 2
	# no doorway may open onto the ledge row
	if _walkable(Vector2i(r.position.x - 1, ledge_y)) or _walkable(Vector2i(r.end.x, ledge_y)):
		return
	var ring: Array[Vector2i] = []
	var old := {}
	for x in range(r.position.x, r.end.x):
		var c := Vector2i(x, ledge_y)
		ring.append(c)
		old[c] = _at(c)
	var top := {}
	for y in range(r.position.y, ledge_y):
		for x in range(r.position.x, r.end.x):
			top[Vector2i(x, y)] = true
	for c in ring:
		_put(c, WALL)
	var mid := Vector2i(r.position.x + r.size.x / 2, ledge_y)
	_put(mid, ".")
	ramps[mid] = "s"
	for c in top:
		heights[c.y * w + c.x] = 1
		if _at(c) == "~":
			_put(c, ".")
	if not _still_one_piece(ring, top):
		for c in ring:
			_put(c, old[c])
		for c in top:
			heights[c.y * w + c.x] = 0
		ramps.erase(mid)
		return
	for c in ring:
		if c != mid:
			cliffs[c] = 1


## A village stamped over crypt rooms: those rooms are gone.
func _forget_rooms_under_villages() -> void:
	var kept: Array[Rect2i] = []
	var kept_themes: Array[String] = []
	var remap := {}
	for ri in rooms.size():
		var hit := false
		for v in villages:
			if (v.rect as Rect2i).grow(1).intersects(rooms[ri]):
				hit = true
		if hit:
			continue
		remap[ri] = kept.size()
		kept.append(rooms[ri])
		if ri < room_themes.size():
			kept_themes.append(room_themes[ri])
	for i in w * h:
		if room_of[i] >= 0:
			room_of[i] = remap.get(room_of[i], -1)
	rooms = kept
	room_themes = kept_themes


## The start zone (no village there).
func start_zone() -> int:
	return _start_zone


func _stamp_village(zi: int) -> void:
	var inner := zones[zi].grow(-1)
	var v := {}
	for attempt in 30:
		var size: Vector2i = VILLAGE_SIZES[rng.randi() % VILLAGE_SIZES.size()] if attempt < 20 else VILLAGE_SIZES[0]
		size.x = mini(size.x, inner.size.x - 2)
		size.y = mini(size.y, inner.size.y - 2)
		var room := inner.size - size - Vector2i(2, 2)
		var pos := inner.position + Vector2i.ONE + Vector2i(rng.randi_range(room.x / 4, room.x - room.x / 4),
			rng.randi_range(room.y / 4, room.y - room.y / 4))
		v = _layout_village(Rect2i(pos, size))
		if not v.is_empty():
			break
	if v.is_empty():
		return
	v["zone"] = zi
	v["host"] = _village_host[zi]
	v["name"] = VILLAGE_NAME_A[rng.randi() % VILLAGE_NAME_A.size()] + VILLAGE_NAME_B[rng.randi() % VILLAGE_NAME_B.size()]
	v["seed"] = rng.randi()
	# Put it on the map.
	var P: Rect2i = v.rect
	var ring := P.grow(1)
	for y in range(ring.position.y, ring.end.y):
		for x in range(ring.position.x, ring.end.x):
			var c := Vector2i(x, y)
			var ch := ","
			if v.solid.has(c):
				ch = WALL
			elif v.road_set.has(c):
				ch = "."
			_put(c, ch)
			region[y * w + x] = -1
			biome[y * w + x] = v.host
	# Paths from the gates out to the open ground (usually only a step or two).
	for g in v.gates:
		var out: Vector2i = g + (Vector2i.UP if g.y == P.position.y else Vector2i.DOWN)
		_put(out, ".")
		_tunnel_from(out, ring)
	v.erase("road_set")
	villages.append(v)


## Digs a path from `from` to the nearest open ground outside `avoid`
## (the village and its ring), so the village joins the labyrinth.
func _tunnel_from(from: Vector2i, avoid: Rect2i) -> void:
	var reach := _flood(start)
	if reach.has(from):
		return
	var prev := {from: from}
	var q: Array[Vector2i] = [from]
	var head := 0
	var found := Vector2i(-1, -1)
	while head < q.size() and found.x < 0:
		var c: Vector2i = q[head]
		head += 1
		for d in DIRS:
			var n := c + d
			if prev.has(n) or n.x < 1 or n.y < 1 or n.x >= w - 1 or n.y >= h - 1:
				continue
			if avoid.has_point(n) and not (_walkable(n) and not avoid.grow(-1).has_point(n)):
				continue
			prev[n] = c
			if reach.has(n) and not avoid.has_point(n):
				found = n
				break
			q.append(n)
	if found.x < 0:
		return
	var cur := prev[found] as Vector2i
	while cur != from:
		if not _walkable(cur):
			_put(cur, ".")
		cur = prev[cur]
	if not _walkable(from):
		_put(from, ".")


## Lays out a village with its wall on `P`. Returns {} if it doesn't fit.
func _layout_village(P: Rect2i) -> Dictionary:
	var I := P.grow(-1)
	var solid := {}
	var taken: Array[Rect2i] = []    # things nothing else may touch (with their 1-tile gap)
	# The wall and its two gates.
	var gn := Vector2i(P.position.x + P.size.x / 2 + rng.randi_range(-2, 2), P.position.y)
	var gs := Vector2i(P.position.x + P.size.x / 2 + rng.randi_range(-2, 2), P.end.y - 1)
	for x in range(P.position.x, P.end.x):
		for y in [P.position.y, P.end.y - 1]:
			solid[Vector2i(x, y)] = "wall"
	for y in range(P.position.y, P.end.y):
		for x in [P.position.x, P.end.x - 1]:
			solid[Vector2i(x, y)] = "wall"
	solid.erase(gn)
	solid.erase(gs)
	# The street: down from the north gate, across, down to the south gate,
	# through a little square with the well.
	var mid_y := I.position.y + I.size.y / 2 + rng.randi_range(-1, 1)
	var road := {}
	var c := gn + Vector2i.DOWN
	while c.y < mid_y:
		road[c] = true
		c.y += 1
	while c.x != gs.x:
		road[c] = true
		c.x += signi(gs.x - c.x)
	while c.y < gs.y:
		road[c] = true
		c.y += 1
	var plaza_c := Vector2i(clampi((gn.x + gs.x) / 2 + rng.randi_range(-3, 3), I.position.x + 4, I.end.x - 5), mid_y)
	var plaza := Rect2i(plaza_c - Vector2i(2, 2), Vector2i(6, 5))
	for y in range(plaza.position.y, plaza.end.y):
		for x in range(plaza.position.x, plaza.end.x):
			road[Vector2i(x, y)] = true
	var well := Rect2i(plaza_c + Vector2i(0, -1), Vector2i(2, 2))
	for y in range(well.position.y, well.end.y):
		for x in range(well.position.x, well.end.x):
			solid[Vector2i(x, y)] = "well"
			road.erase(Vector2i(x, y))
	# keep the gates' insides clear for the guards and the way in
	taken.append(Rect2i(gn + Vector2i(-2, 1), Vector2i(5, 2)))
	taken.append(Rect2i(gs + Vector2i(-2, -2), Vector2i(5, 2)))
	taken.append(well)
	# Buildings, nearest the street first.
	var want: Array[String] = ["inn", "shop", "sage", "farm"]
	var homes := 1 + (P.size.x - 21) / 2
	for n in homes:
		want.append("home" if rng.randf() < 0.5 else "home_wide")
	var buildings: Array = []
	var farm := {}
	for kind in want:
		var size: Vector2i = Vector2i(rng.randi_range(7, 9) | 1, 5) if kind == "farm" else BUILDING_SIZE[kind]
		var best := Rect2i()
		var best_score := INF
		for attempt in 120:
			var r := Rect2i(Vector2i(rng.randi_range(I.position.x + 1, I.end.x - 1 - size.x),
				rng.randi_range(I.position.y + 1, I.end.y - 1 - size.y)), size)
			if r.position.x < I.position.x + 1 or r.position.y < I.position.y + 1:
				continue
			var ok := true
			for t in taken:
				if r.grow(1).intersects(t):
					ok = false
					break
			if ok:
				for y in range(r.position.y, r.end.y):
					for x in range(r.position.x, r.end.x):
						if road.has(Vector2i(x, y)):
							ok = false
			if not ok:
				continue
			var door := Vector2i(r.position.x + r.size.x / 2, r.end.y)   # the tile in front of the door
			var score := 999.0
			for rc in road:
				score = minf(score, absi(rc.x - door.x) + absi(rc.y - door.y))
			score += rng.randf() * 2.0
			if kind == "farm":
				score = -score * 0.3   # fields sit a little out of the way
			if score < best_score:
				best_score = score
				best = r
		if best.size == Vector2i.ZERO:
			if kind.begins_with("home"):
				continue
			return {}
		taken.append(best)
		if kind == "farm":
			# bushes on every other tile, lanes between; the gate opens onto a lane
			farm = {"rect": best, "bushes": [], "opening": Vector2i(best.position.x + 2 + 2 * rng.randi_range(0, (best.size.x - 4) / 2 - 1), best.end.y - 1)}
			for x in range(best.position.x, best.end.x):
				for y in [best.position.y, best.end.y - 1]:
					solid[Vector2i(x, y)] = "fence"
			for y in range(best.position.y, best.end.y):
				for x in [best.position.x, best.end.x - 1]:
					solid[Vector2i(x, y)] = "fence"
			solid.erase(farm.opening)
			var fi := best.grow(-1)
			for y in range(fi.position.y, fi.end.y):
				for x in range(fi.position.x, fi.end.x):
					if (x - fi.position.x) % 2 == 0 and (y - fi.position.y) % 2 == 0:
						farm.bushes.append(Vector2i(x, y))
		else:
			var b := {"kind": "home" if kind.begins_with("home") else kind, "rect": best,
				"door": Vector2i(best.position.x + best.size.x / 2, best.end.y - 1), "variant": rng.randi() % 4}
			buildings.append(b)
			for y in range(best.position.y, best.end.y):
				for x in range(best.position.x, best.end.x):
					solid[Vector2i(x, y)] = b.kind
	# Lamp posts along the street, and odds and ends by the houses.
	var props: Array = []
	var guards: Array = []
	for g in [gn, gs]:
		var inward := Vector2i.DOWN if g == gn else Vector2i.UP
		for dx in [-1, 1]:
			guards.append({"cell": g + inward + Vector2i(dx, 0), "facing": inward})
	var blocked_extra := {}
	for gd in guards:
		blocked_extra[gd.cell] = true
	for b in buildings:
		blocked_extra[b.door + Vector2i.DOWN] = true
	if not farm.is_empty():
		blocked_extra[farm.opening + Vector2i.DOWN] = true
	var road_cells := road.keys()
	road_cells.sort()
	var lamp_n := 0
	for rc in road_cells:
		lamp_n += 1
		if lamp_n % 3 != 0:
			continue
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var lc: Vector2i = rc + d
			var crowded := false
			for q in props:
				if q.kind == "lamp" and absi(q.cell.x - lc.x) + absi(q.cell.y - lc.y) < 4:
					crowded = true
			if not crowded and _free_village_cell(lc, I, solid, road, taken, blocked_extra) \
					and _still_joined(lc, I, solid, blocked_extra, farm):
				solid[lc] = "lamp"
				props.append({"kind": "lamp", "cell": lc})
				break
	for b in buildings:
		var r: Rect2i = b.rect
		for n in rng.randi_range(0, 2):
			var side := rng.randi() % 2
			var pc := Vector2i(r.position.x - 1 if side == 0 else r.end.x, r.end.y - 1 - rng.randi_range(0, 1))
			if _free_village_cell(pc, I, solid, road, [], blocked_extra) and _still_joined(pc, I, solid, blocked_extra, farm):
				var kind: String = ["barrel", "crate", "barrel", "pots"][rng.randi() % 4]
				solid[pc] = kind
				props.append({"kind": kind, "cell": pc})
	if not farm.is_empty():
		var hc := Vector2i(farm.rect.end.x, farm.rect.position.y + 1)
		if _free_village_cell(hc, I, solid, road, [], blocked_extra) and _still_joined(hc, I, solid, blocked_extra, farm):
			solid[hc] = "hay"
			props.append({"kind": "hay", "cell": hc})
	# Flowers and garden patches: walk-on decoration.
	var flowers: Array = []
	for y in range(I.position.y, I.end.y):
		for x in range(I.position.x, I.end.x):
			var fc := Vector2i(x, y)
			if not solid.has(fc) and not road.has(fc) and rng.randf() < 0.06:
				flowers.append(fc)
	# Everything inside must be reachable from the gate.
	var seen := {gn: true}
	var q: Array[Vector2i] = [gn]
	var head := 0
	var bush_set := {}
	if not farm.is_empty():
		for bc in farm.bushes:
			bush_set[bc] = true
	while head < q.size():
		var p: Vector2i = q[head]
		head += 1
		for d in DIRS:
			var n := p + d
			if P.has_point(n) and not seen.has(n) and not solid.has(n) and not bush_set.has(n):
				seen[n] = true
				q.append(n)
	if not seen.has(gs):
		return {}
	for b in buildings:
		if not seen.has(b.door + Vector2i.DOWN):
			return {}
	if not farm.is_empty() and not seen.has(farm.opening):
		return {}
	return {"rect": P, "gates": [gn, gs], "buildings": buildings, "farm": farm, "well": well,
		"props": props, "guards": guards, "road": road.keys(), "road_set": road, "plaza": plaza,
		"flowers": flowers, "solid": solid}


func _free_village_cell(c: Vector2i, I: Rect2i, solid: Dictionary, road: Dictionary, taken: Array, extra: Dictionary) -> bool:
	if not I.grow(-1).has_point(c) or solid.has(c) or road.has(c) or extra.has(c):
		return false
	for t in taken:
		if t.has_point(c):
			return false
	return true


## True if blocking `c` keeps the open tiles around it connected (nearby).
func _still_joined(c: Vector2i, I: Rect2i, solid: Dictionary, extra: Dictionary, farm: Dictionary) -> bool:
	var open := func(n: Vector2i) -> bool:
		if not I.has_point(n) or solid.has(n) or n == c:
			return false
		if not farm.is_empty() and farm.bushes.has(n):
			return false
		return true
	var around: Array[Vector2i] = []
	for d in DIRS:
		if open.call(c + d):
			around.append(c + d)
	if around.size() <= 1:
		return true
	var seen := {around[0]: true}
	var q: Array[Vector2i] = [around[0]]
	var head := 0
	while head < q.size():
		var p: Vector2i = q[head]
		head += 1
		for d in DIRS:
			var n := p + d
			if not seen.has(n) and open.call(n) and absi(n.x - c.x) <= 8 and absi(n.y - c.y) <= 8:
				seen[n] = true
				q.append(n)
	for a in around:
		if not seen.has(a):
			return false
	return true
