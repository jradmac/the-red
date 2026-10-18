class_name Doors
extends Node2D
## Bronze, silver and gold doors that seal the labyrinth into sections.
##
## Placement: doors go on straight corridor tiles that are chokepoints (the
## only way through). About 20 sit on the route from the start to the master
## chamber, each sealing a section a bit bigger than the last, so the time
## between doors grows as the run goes on. The first 3 are always bronze;
## after that it's a random mix. More doors seal off side wings.
##
## The always-solvable rule: every door's key is placed on the NEAR side of
## that door (the side you reach first). So whatever order you open doors in,
## you always hold exactly as many keys of a color as there are locked doors
## of that color you can reach -- you can never waste a key and get stuck.
## To make keys hard to find, each one goes as far as possible from both the
## door it opens and the way you came into that section.
##
## Opening: face a door and press A with a matching key -> lockpicking puzzle.
## The key breaks in the lock when the door opens.

var pfx := ""   ## input action prefix: "" for player 1, "p2_" for player 2

signal opened(c: Vector2i)

const PROPS_TEX: Texture2D = preload("res://assets/props.png")
const SPRITE := {"bronze": 10, "silver": 11, "gold": 12}   # columns in props.png
const OPEN_SPRITE := 13
const DOORS_TEX: Texture2D = preload("res://assets/doors.png")
const DOOR_COLUMN := {"bronze": 0, "silver": 2, "gold": 4}   # columns in doors.png
const ROUTE_SECTIONS := 20     # aim for about this many doors on the route
const SECTION_GROWTH := 1.1    # each section ~10% bigger than the one before
const ROUTE_FILL := 0.9        # share of the labyrinth the route sections take up (the rest lies past the last door)
const WING_MIN := 600          # side wings bigger than this (and than WING_SHARE of the stage) get their own door
const WING_SHARE := 1.2
const FIRST_BRONZE := 3        # the first doors on the route are always bronze
const COLOR_WEIGHTS := {"bronze": 40, "silver": 35, "gold": 25}
const TILES_PER_SIDE_DOOR := 2400
const SIDE_MIN := 50           # side wings: smallest / largest area to seal (tiles)
const SIDE_MAX := 700
const MIN_START_DIST := 8      # no doors right next to the start
const MIN_DOOR_GAP := 5        # tiles between doors
const LOOP_CHANCE := 0.012    # share of eligible walls knocked out for loops (the corridors are wide: few needed)
const KEY_FAR_SHARE := 0.25    # key goes in the farthest quarter of its section (deep down)
const KEY_EASY_BAND := Vector2(0.35, 0.65)   # the first route keys: this slice, counted from the farthest spot
const KEY_HARD_BY := 10.0      # by this route door, keys are as hidden as they get

var world: World
var player: Player
var inventory: Inventory
var dialog: Dialog
var puzzle: LockPuzzle
var pickups: Pickups
var doors := {}        # cell -> {"color": String, "open": bool, "front": int, "route": bool}
var section_of := {}   # cell -> section id (with every door closed)
var section_depth := {}  # section id -> how many doors stand between it and the start
var key_spots := {}    # door cell -> where its key was put (for debugging/tests)
var route_doors: Array[Vector2i] = []
var wing_doors: Array[Vector2i] = []   ## doors that shut big side wings off the route
var chests_ref: Chests
## Set by main.gd: is this tile lit by anything -- anyone's lantern, a planted
## flare, a candle? (Enemies.is_lit.) Light by the door is enough to pick its
## lock, even with your own lantern out.
var light_at: Callable
var _clue_door := {}   ## player ("" or "p2_") -> the door a sprite pointed them to, until it opens
var _rng := RandomNumberGenerator.new()
# Depth-first search data (by tile index) used to find chokepoints.
var _disc := PackedInt32Array()
var _low := PackedInt32Array()
var _size := PackedInt32Array()
var _parent := PackedInt32Array()


# --- Generation ---------------------------------------------------------------

func generate(w: World) -> void:
	world = w
	_rng.seed = world.seed_value + 404
	var W := world.width
	var start_i := world.start_cell.y * W + world.start_cell.x
	_plan_route()
	# The real layout from here on (the doors themselves count as open).
	_dfs(start_i, {}, doors)
	var path := _route_path()

	# Side doors: chokepoints off the route that seal a wing of decent size.
	var on_path := {}
	for v in path:
		on_path[v] = true
	var candidates: Array[int] = []
	for y in range(1, world.height - 1):
		for x in range(1, W - 1):
			var v := y * W + x
			if _disc[v] < 0 or on_path.has(v):
				continue
			var c := Vector2i(x, y)
			var child := _straight_child(v, c)
			if child >= 0 and _low[child] >= _disc[v] and _size[child] >= SIDE_MIN and _size[child] <= SIDE_MAX:
				candidates.append(v)
	for i in range(candidates.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var wings: Array[Vector2i] = []   # [first disc, last disc] of sealed wings (no nesting)
	var want := (W * world.height) / TILES_PER_SIDE_DOOR
	for v in candidates:
		if want <= 0:
			break
		var c := Vector2i(v % W, v / W)
		var child := _straight_child(v, c)
		var span := Vector2i(_disc[child], _disc[child] + _size[child] - 1)
		var clash := false
		for wspan in wings:
			if (_disc[v] >= wspan.x and _disc[v] <= wspan.y) or (wspan.x >= span.x and wspan.x <= span.y):
				clash = true
				break
		if clash or not _door_ok(c):
			continue
		_add(c, _random_color(), false)
		wings.append(span)
		want -= 1

	_compute_sections()
	_add_loops()
	queue_redraw()


## The labyrinth is generated as a tree (one way between any two places) so
## the route has chokepoints for doors. Now that the doors are in, knock out a
## few walls between tiles of the SAME section so each section has loops and
## alternate paths, without ever creating a way around a door.
func _add_loops() -> void:
	for y in range(2, world.height - 2):
		for x in range(2, world.width - 2):
			var c := Vector2i(x, y)
			if world.tile_at(c) != "#" or _rng.randf() > LOOP_CHANCE or world.near_village(c, 1):
				continue
			var a: Vector2i
			var b: Vector2i
			if world.tile_at(c + Vector2i.LEFT) != "#" and world.tile_at(c + Vector2i.RIGHT) != "#" \
					and world.tile_at(c + Vector2i.UP) == "#" and world.tile_at(c + Vector2i.DOWN) == "#":
				a = c + Vector2i.LEFT
				b = c + Vector2i.RIGHT
			elif world.tile_at(c + Vector2i.UP) != "#" and world.tile_at(c + Vector2i.DOWN) != "#" \
					and world.tile_at(c + Vector2i.LEFT) == "#" and world.tile_at(c + Vector2i.RIGHT) == "#":
				a = c + Vector2i.UP
				b = c + Vector2i.DOWN
			else:
				continue
			if not section_of.has(a) or section_of.get(a) != section_of.get(b):
				continue
			var near_door := false
			for d in doors:
				if absi(d.x - c.x) + absi(d.y - c.y) <= 2:
					near_door = true
					break
			if near_door:
				continue
			world.open_wall(c)
			section_of[c] = section_of[a]


## A link can become a doorway only if its outer tiles lead nowhere else.
func _narrowable(l: Array) -> bool:
	for c in [l[0], l[2]]:
		if _neighbors(c).size() != 3:
			return false
	return world.is_walkable(l[1])


# --- Route planning ---------------------------------------------------------------
# The map is seen as CHAMBERS (open areas) joined by NARROW places (one-tile
# doorways, and full-width maze links, which can be narrowed into doorways).
# Walking that graph from the start to the far room, a door goes on a narrow
# place once the stretch since the last door is as big as this stage should
# be. Big side wings hanging off the way get a door of their own (optional
# areas), so they don't swell the stage you have to search.

var _nd_node := PackedInt32Array()   # tile -> graph node
var _nd_tiles: Array = []            # node -> its tiles (narrow places) or [] (chambers)
var _nd_size := PackedInt32Array()   # node -> tiles in it
var _nd_adj: Array = []              # node -> neighbouring nodes


func _build_graph() -> void:
	var W := world.width
	var H := world.height
	_nd_node.resize(W * H)
	_nd_node.fill(-1)
	_nd_tiles.clear()
	var sizes: Array[int] = []
	for l in world.links:
		if _narrowable(l) and _nd_node[l[1].y * W + l[1].x] < 0:
			for c in l:
				_nd_node[c.y * W + c.x] = _nd_tiles.size()
			_nd_tiles.append(l)
			sizes.append(3)
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			var c := Vector2i(x, y)
			if _nd_node[y * W + x] >= 0 or not world.is_walkable(c) or world.ramps.has(c):
				continue
			var ew := world.is_walkable(c + Vector2i.LEFT) and world.is_walkable(c + Vector2i.RIGHT) \
				and not world.is_walkable(c + Vector2i.UP) and not world.is_walkable(c + Vector2i.DOWN)
			var ns := world.is_walkable(c + Vector2i.UP) and world.is_walkable(c + Vector2i.DOWN) \
				and not world.is_walkable(c + Vector2i.LEFT) and not world.is_walkable(c + Vector2i.RIGHT)
			if ew or ns:
				_nd_node[y * W + x] = _nd_tiles.size()
				_nd_tiles.append([c])
				sizes.append(1)
	for y in H:
		for x in W:
			if _nd_node[y * W + x] >= 0 or not world.is_walkable(Vector2i(x, y)):
				continue
			var id := _nd_tiles.size()
			_nd_tiles.append([])
			var q: Array[Vector2i] = [Vector2i(x, y)]
			_nd_node[y * W + x] = id
			var head := 0
			while head < q.size():
				var p: Vector2i = q[head]
				head += 1
				for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					var n: Vector2i = p + d
					if n.x >= 0 and n.y >= 0 and n.x < W and n.y < H and _nd_node[n.y * W + n.x] < 0 and world.is_walkable(n):
						_nd_node[n.y * W + n.x] = id
						q.append(n)
			sizes.append(q.size())
	_nd_size = PackedInt32Array(sizes)
	_nd_adj.clear()
	for i in _nd_tiles.size():
		_nd_adj.append({})
	for id in _nd_tiles.size():
		for c in _nd_tiles[id]:
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var n: Vector2i = c + d
				if n.x < 0 or n.y < 0 or n.x >= W or n.y >= H or not world.is_walkable(n):
					continue
				var o := _nd_node[n.y * W + n.x]
				if o >= 0 and o != id:
					_nd_adj[id][o] = true
					_nd_adj[o][id] = true


func _plan_route() -> void:
	_build_graph()
	# a dry run first, to see how much ground the way to the end covers once
	# the big wings are shut off; then the stages are sized to fit it
	var mass := _walk_route(-1.0, true)
	_walk_route(float(mass) * ROUTE_FILL, false)


## Returns the tiles counted along the route (stage areas).
func _walk_route(route_mass: float, dry: bool) -> int:
	var W := world.width
	var n := _nd_tiles.size()
	var root := _nd_node[world.start_cell.y * W + world.start_cell.x]
	var goal := _nd_node[world.goal_cell.y * W + world.goal_cell.x]
	# depth-first tree over the graph: discovery, low-link (bridges), sizes
	var disc := PackedInt32Array()
	disc.resize(n)
	disc.fill(-1)
	var low := PackedInt32Array()
	low.resize(n)
	var par := PackedInt32Array()
	par.resize(n)
	par.fill(-1)
	var sub := PackedInt32Array()
	sub.resize(n)
	var t := 0
	disc[root] = t
	low[root] = t
	t += 1
	var stack: Array = [[root, (_nd_adj[root] as Dictionary).keys(), 0]]
	while not stack.is_empty():
		var top: Array = stack.back()
		var v: int = top[0]
		var nbs: Array = top[1]
		if top[2] < nbs.size():
			var u: int = nbs[top[2]]
			top[2] += 1
			if disc[u] < 0:
				par[u] = v
				disc[u] = t
				low[u] = t
				t += 1
				stack.append([u, (_nd_adj[u] as Dictionary).keys(), 0])
			elif u != par[v]:
				low[v] = mini(low[v], disc[u])
		else:
			stack.pop_back()
			sub[v] += _nd_size[v]
			if par[v] >= 0:
				low[par[v]] = mini(low[par[v]], low[v])
				sub[par[v]] += sub[v]
	if disc[goal] < 0:
		return 0
	var route: Array[int] = []
	var g := goal
	while g >= 0:
		route.push_front(g)
		g = par[g]
	var on_route := {}
	for x in route:
		on_route[x] = true
	# a door on narrow node x (entered from parent p) cuts x's subtree off
	# only if no loop gets round it
	var cuts := func(x: int) -> bool:
		if _nd_tiles[x].is_empty() or par[x] < 0:
			return false
		for y in _nd_adj[x]:
			if par[y] == x and low[y] < disc[x]:
				return false
		return true
	var growth_sum := (pow(SECTION_GROWTH, ROUTE_SECTIONS) - 1.0) / (SECTION_GROWTH - 1.0)
	var base := (route_mass if route_mass > 0.0 else float(sub[root]) * 0.5) / growth_sum
	var acc := 0
	var counted := 0
	var k := 0
	for i in route.size():
		var x: int = route[i]
		var nxt: int = route[i + 1] if i + 1 < route.size() else -1
		var want := base * pow(SECTION_GROWTH, k)
		acc += _nd_size[x]
		counted += _nd_size[x]
		for y in _nd_adj[x]:
			if par[y] != x or y == nxt:
				continue
			var big := maxf(WING_MIN, want * WING_SHARE)
			if sub[y] < big:
				acc += sub[y]
				counted += sub[y]
				continue
			# a big wing: shut most of it off behind its own door
			var spot := -1
			var q: Array[int] = [y]
			var head := 0
			while head < q.size() and head < 400:
				var z: int = q[head]
				head += 1
				if not _nd_tiles[z].is_empty() and cuts.call(z) and _node_door_ok(z):
					spot = z
					break
				for c in _nd_adj[z]:
					if par[c] == z and sub[c] >= big * 0.6:
						q.append(c)
			if spot < 0:
				acc += sub[y]
				counted += sub[y]
				continue
			if not dry:
				_door_on_node(spot, _random_color(), false)
			acc += sub[y] - sub[spot]
			counted += sub[y] - sub[spot]
		if nxt < 0 or k >= ROUTE_SECTIONS:
			continue
		if float(acc) >= want and not _nd_tiles[x].is_empty() and cuts.call(x) and _node_door_ok(x):
			if not dry:
				_door_on_node(x, "bronze" if k < FIRST_BRONZE else _random_color(), true)
			acc = 0
			k += 1
	return counted


func _node_door_ok(x: int) -> bool:
	var tl: Array = _nd_tiles[x]
	if tl.size() == 3:
		return _door_ok(tl[1], true)
	return _door_ok(tl[0])


func _door_on_node(x: int, color: String, route: bool) -> void:
	var tl: Array = _nd_tiles[x]
	var c: Vector2i = tl[0]
	if tl.size() == 3:
		world.close_wall(tl[0])
		world.close_wall(tl[2])
		c = tl[1]
	_add(c, color, route)
	if route:
		route_doors.append(c)
	else:
		wing_doors.append(c)


func _random_color() -> String:
	var total := 0
	for c in COLOR_WEIGHTS:
		total += COLOR_WEIGHTS[c]
	var r := _rng.randi() % total
	for c in COLOR_WEIGHTS:
		r -= COLOR_WEIGHTS[c]
		if r < 0:
			return c
	return "bronze"


## For a straight corridor tile, the neighbor that's its child in the search
## tree (or -1).
func _straight_child(v: int, c: Vector2i) -> int:
	var n := _neighbors(c)
	if n.size() != 2 or n[0] - c != -(n[1] - c):
		return -1
	for nb in n:
		var ni := nb.y * world.width + nb.x
		if _parent[ni] == v:
			return ni
	return -1


func _door_ok(c: Vector2i, doorway := false) -> bool:
	var t := world.tile_at(c)
	if not (t == "." or t == ",") or not world.is_walkable(c):
		return false
	if world.room_at(c).size != Vector2i.ZERO or world.near_village(c, 3) or world.ramps.has(c):
		return false
	if absi(c.x - world.start_cell.x) + absi(c.y - world.start_cell.y) < MIN_START_DIST:
		return false
	if not doorway:
		var n := _neighbors(c)
		if n.size() != 2 or n[0] - c != -(n[1] - c):
			return false   # only straight corridor tiles
	for other in doors:
		if (Vector2(other) - Vector2(c)).length() < MIN_DOOR_GAP:
			return false
	return true


func _add(c: Vector2i, color: String, route: bool) -> void:
	doors[c] = {"color": color, "open": false, "front": -1, "route": route}
	world.doors[c] = true
	world.blockers[c] = true


## The depth-first tree's path from the start to the far room (tile indices).
func _route_path() -> Array[int]:
	var path: Array[int] = []
	var gi := world.goal_cell.y * world.width + world.goal_cell.x
	while gi != -1:
		path.push_front(gi)
		gi = _parent[gi]
	return path


## Iterative depth-first search from the start over open tiles: discovery
## order, low-link (for chokepoints) and subtree sizes.
func _dfs(root: int, closed: Dictionary = {}, also_open: Dictionary = {}) -> void:
	var W := world.width
	var n := W * world.height
	var open := PackedByteArray()
	open.resize(n)
	for y in world.height:
		for x in W:
			var c := Vector2i(x, y)
			open[y * W + x] = 1 if (world.is_walkable(c) or also_open.has(c)) and not closed.has(c) else 0
	_disc.resize(n)
	_disc.fill(-1)
	_low.resize(n)
	_size.resize(n)
	_size.fill(0)
	_parent.resize(n)
	_parent.fill(-1)
	var offs := [-W, W, -1, 1]
	var t := 0
	_disc[root] = t
	_low[root] = t
	_size[root] = 1
	t += 1
	var stack: Array = [[root, 0]]
	while not stack.is_empty():
		var top: Array = stack.back()
		var v: int = top[0]
		var it: int = top[1]
		if it < 4:
			top[1] = it + 1
			var u: int = v + offs[it]
			if u < 0 or u >= n or open[u] == 0:
				continue
			if _disc[u] == -1:
				_parent[u] = v
				_disc[u] = t
				_low[u] = t
				_size[u] = 1
				t += 1
				stack.append([u, 0])
			elif u != _parent[v]:
				_low[v] = mini(_low[v], _disc[u])
		else:
			stack.pop_back()
			var p := _parent[v]
			if p != -1:
				_low[p] = mini(_low[p], _low[v])
				_size[p] += _size[v]


func _neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if world.is_walkable(c + d):
			out.append(c + d)
	return out


## Splits the labyrinth into sections (with all doors shut), then works out
## which side of each door is the near ("front") side.
func _compute_sections() -> void:
	section_of.clear()
	var count := 0
	for y in world.height:
		for x in world.width:
			var c := Vector2i(x, y)
			if world.is_walkable(c) and not section_of.has(c):
				for cell in _flood(c):
					section_of[cell] = count
				count += 1
	var start_sec: int = section_of[world.start_cell]
	var links := {}   # section -> [[other section, door], ...]
	for d in doors:
		var sides := _door_sections(d)
		if sides.size() != 2:
			continue
		for k in 2:
			if not links.has(sides[k]):
				links[sides[k]] = []
			links[sides[k]].append(sides[1 - k])
	var depth := {start_sec: 0}
	var queue: Array[int] = [start_sec]
	while not queue.is_empty():
		var sec: int = queue.pop_front()
		for other in links.get(sec, []):
			if not depth.has(other):
				depth[other] = depth[sec] + 1
				queue.append(other)
	for d in doors:
		var sides := _door_sections(d)
		doors[d].front = sides[0] if depth.get(sides[0], 99) < depth.get(sides[1], 99) else sides[1]
	section_depth = depth


func _door_sections(d: Vector2i) -> Array[int]:
	var out: Array[int] = []
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if section_of.has(d + dir):
			out.append(section_of[d + dir])
	return out


## Puts one key per door on the door's near side, as far as possible from
## both the door and the way into that section: in a chest there if one is
## far enough out, otherwise hovering in a far dead end.
func place_keys(chests: Chests, pk: Pickups) -> void:
	pickups = pk
	chests_ref = chests
	var cells_of := {}   # section -> cells
	for c in section_of:
		var sec: int = section_of[c]
		if not cells_of.has(sec):
			cells_of[sec] = []
		cells_of[sec].append(c)
	# Where you walk into each section: the start, or the door leading in.
	var entry := {section_of[world.start_cell]: world.start_cell}
	for d in doors:
		var sides := _door_sections(d)
		var back: int = sides[0] if sides[0] != doors[d].front else sides[1]
		for nb in _neighbors_any(d):
			if section_of.get(nb, -1) == back:
				entry[back] = nb
	for d in doors:
		var key: String = doors[d].color + "_key"
		var sec: int = doors[d].front
		var door_side := Vector2i(-1, -1)
		for nb in _neighbors_any(d):
			if section_of.get(nb, -1) == sec:
				door_side = nb
		var from_entry := _flood_in(entry.get(sec, door_side), sec)
		var from_door := _flood_in(door_side, sec)
		var scored: Array = []
		for c in cells_of[sec]:
			scored.append([mini(from_entry.get(c, 0), from_door.get(c, 0)), c])
		scored.sort_custom(func(a, b): return a[0] > b[0])
		# How hidden: the first doors' keys lie partway in (you'll come across
		# them while looking around); deeper down they're in the far corners.
		var band := Vector2(0.0, KEY_FAR_SHARE)
		var ri := route_doors.find(d)
		if ri >= 0:
			var hard := clampf(float(ri) / KEY_HARD_BY, 0.0, 1.0)
			band = Vector2(lerpf(KEY_EASY_BAND.x, 0.0, hard), lerpf(KEY_EASY_BAND.y, KEY_FAR_SHARE, hard))
		var far := {}
		var i0 := int(scored.size() * band.x)
		var i1 := maxi(i0 + 1, int(scored.size() * band.y))
		for i in range(i0, mini(i1, scored.size())):
			far[scored[i][1]] = true
		# A chest out in the far part of the section?
		var options: Array[Vector2i] = []
		for c in chests.chests:
			if far.has(c) and chests.chests[c].items.size() < ChestScreen.CAPACITY \
					and not chests.chests[c].get("purple", false):
				options.append(c)
		if not options.is_empty():
			var pick: Vector2i = options[_rng.randi() % options.size()]
			Chests.add_to_chest(chests.chests[pick].items, key)
			key_spots[d] = pick
			continue
		var tips: Array[Vector2i] = []
		var rest: Array[Vector2i] = []
		for c in far:
			if c == world.start_cell or pk.has_item_at(c) or not world.is_walkable(c) or world.reserved.has(c):
				continue
			if not (world.tile_at(c) == "." or world.tile_at(c) == ","):
				continue
			if _neighbors(c).size() == 1:
				tips.append(c)
			else:
				rest.append(c)
		var pool := tips if not tips.is_empty() else rest
		if pool.is_empty():
			for c in cells_of[sec]:
				if world.is_walkable(c) and not pk.has_item_at(c) and c != world.start_cell:
					pool.append(c)
		var spot: Vector2i = pool[_rng.randi() % pool.size()]
		pk.drop(spot, {"id": key, "qty": 1})
		key_spots[d] = spot


func _neighbors_any(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		out.append(c + d)
	return out


## Walking distance from `from` to every tile of section `sec`.
func _flood_in(from: Vector2i, sec: int) -> Dictionary:
	var dist := {from: 0}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if not dist.has(n) and section_of.get(n, -1) == sec:
				dist[n] = dist[c] + 1
				queue.append(n)
	return dist


# --- Play -------------------------------------------------------------------

func setup(p: Player, inv: Inventory, d: Dialog, lp: LockPuzzle) -> void:
	player = p
	inventory = inv
	dialog = d
	puzzle = lp


func is_locked(c: Vector2i) -> bool:
	return doors.has(c) and not doors[c].open


func bind(h: Hero) -> void:
	player = h.player
	inventory = h.inventory
	dialog = h.dialog
	puzzle = h.lock_puzzle
	pfx = h.pfx


## Run once per player per frame, bound to that player (main.gd).
func hero_tick() -> void:
	if player == null or not player.can_act() or player.moving:
		return
	if pickups.needs_button(player.cell):
		return   # A picks up the item you're standing on first
	if Input.is_action_just_pressed(pfx + "confirm"):
		var c := player.facing_cell()
		if is_locked(c):
			try_open(c)


func try_open(c: Vector2i) -> void:
	var color: String = doors[c].color
	var key := color + "_key"
	if inventory.count_of(key) <= 0:
		Sfx.play("door_locked")
		dialog.say("A " + color.to_upper() + " LOCK. YOU NEED " + Items.with_article(key) + ".", key)
		return
	var here := player.cell
	var lit_by_door := func() -> bool:
		return light_at.is_valid() and (light_at.call(c) or light_at.call(here))
	var own := puzzle.lantern == null or puzzle.lantern.state == Lantern.State.LIT or puzzle.lantern.daylight
	if not own and not lit_by_door.call():
		Sfx.play("ui_deny")
		dialog.say("TOO DARK TO SEE THE PINS. STRIKE A MATCH, OR LIGHT A FLARE BY THE DOOR.", key)
		return
	puzzle.other_light = lit_by_door
	var h := Hero.bound
	var on_done := func(success: bool) -> void:
		if success:
			if h != null:
				Hero.bind_all(h)
			_open(c, key)
	# deeper doors: faster pins (measured on the door's deeper side)
	var deep := progress(c)
	for n in [c + Vector2i.UP, c + Vector2i.DOWN, c + Vector2i.LEFT, c + Vector2i.RIGHT]:
		deep = maxf(deep, progress(n))
	puzzle.start(color, on_done, deep)


func _open(c: Vector2i, key: String) -> void:
	inventory.consume(key)
	Sfx.play("door_open")
	opened.emit(c)
	doors[c].open = true
	world.blockers.erase(c)
	queue_redraw()
	dialog.say("CLICK. THE " + Items.display_name(key) + " SNAPS IN THE LOCK, BUT THE DOOR SWINGS OPEN.", key)


func _draw() -> void:
	for c in doors:
		# Front view in a north-south corridor, edge-on in an east-west one.
		var side := 1 if world.tile_at(c + Vector2i.UP) == "#" else 0
		var col: int = 6 + side if doors[c].open else DOOR_COLUMN[doors[c].color] + side
		var o := world.cell_to_position(c)
		Shadows.oval(self, o + Vector2(8, 15), 14 if side == 0 else 8)
		draw_texture_rect_region(DOORS_TEX, Rect2(o + Vector2(0, -8), Vector2(16, 24)),
			Rect2(col * 16, 0, 16, 24))


## The locked door you can walk up to right now that comes next on the way
## out (route doors first, in order; else the nearest side door).
## Returns (-1, -1) if every reachable door is open.
func next_door(from: Vector2i) -> Vector2i:
	var seen := {from: true}
	var q: Array[Vector2i] = [from]
	var head := 0
	var frontier: Array[Vector2i] = []
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if seen.has(n):
				continue
			seen[n] = true
			if is_locked(n):
				frontier.append(n)
			elif world.is_walkable(n):
				q.append(n)
	for d in route_doors:
		if frontier.has(d):
			return d
	if frontier.is_empty():
		return Vector2i(-1, -1)
	return frontier[0]


# --- Clues (the sprites' riddles) ------------------------------------------------------
## A sprite's clue always points at ONE door: the nearest locked door you can
## walk up to that you can actually open (you hold its key, or one lies
## within reach) -- or simply the nearest, if none. Once chosen it stays the
## door for that player: ask again (for the door or for its key) and you're
## shown the same one, until it's open.

## Walking distance from `from` to every cell you can reach without opening a
## door, and to every locked door at the edge of that.
func _reach(from: Vector2i) -> Dictionary:
	var dist := {from: 0}
	var front := {}
	var q: Array[Vector2i] = [from]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if dist.has(n) or front.has(n):
				continue
			if is_locked(n):
				front[n] = dist[c] + 1
			elif world.is_walkable(n):
				dist[n] = dist[c] + 1
				q.append(n)
	return {"dist": dist, "front": front}


func clue_door(from: Vector2i, who: String, inv: Inventory) -> Vector2i:
	var r := _reach(from)
	var front: Dictionary = r.front
	var kept: Vector2i = _clue_door.get(who, Vector2i(-1, -1))
	if kept.x >= 0 and is_locked(kept) and front.has(kept):
		return kept
	var best := Vector2i(-1, -1)
	var best_any := Vector2i(-1, -1)
	for d in front:
		if best_any.x < 0 or front[d] < front[best_any]:
			best_any = d
		var color: String = doors[d].color
		if inv.count_of(color + "_key") > 0 or _nearest_key(color, r).x >= 0:
			if best.x < 0 or front[d] < front[best]:
				best = d
	if best.x < 0:
		best = best_any
	if best.x >= 0:
		_clue_door[who] = best
	return best


## The way there on foot: the cells from `from` up to (and including) `goal`,
## walking only through open ground. [] if there's no way.
func path_to(from: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var parent := {from: from}
	var q: Array[Vector2i] = [from]
	var head := 0
	var found := false
	while head < q.size() and not found:
		var c: Vector2i = q[head]
		head += 1
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if parent.has(n):
				continue
			if n == goal:
				parent[n] = c
				found = true
				break
			if world.is_walkable(n) and not is_locked(n):
				parent[n] = c
				q.append(n)
	var path: Array[Vector2i] = []
	if not found:
		return path
	var at := goal
	while at != from:
		path.push_front(at)
		at = parent[at]
	path.push_front(from)
	return path


## The Seer Stone's trail: the way to the same gate a sprite's clue would
## name (clue_door), or to the master seal once no locked door is left in reach.
func seer_path(from: Vector2i, who: String, inv: Inventory, master_gate: Vector2i) -> Array[Vector2i]:
	var door := clue_door(from, who, inv)
	if door.x >= 0:
		return path_to(from, door)
	if master_gate.x >= 0:
		return path_to(from, master_gate)
	return [] as Array[Vector2i]


## Where to find a key for `door`: its own key if it's still where it was
## hidden, else the nearest key of that colour within reach. (-1, -1) if none.
func clue_key(door: Vector2i, from: Vector2i) -> Vector2i:
	var color: String = doors[door].color
	var r := _reach(from)
	var own: Vector2i = key_spots.get(door, Vector2i(-1, -1))
	if own.x >= 0 and _key_lies_at(own, color) and _reachable(own, r):
		return own
	return _nearest_key(color, r)


func _key_lies_at(c: Vector2i, color: String) -> bool:
	var id := color + "_key"
	if pickups != null and pickups.ground.has(c) and pickups.ground[c].id == id:
		return true
	if chests_ref != null and chests_ref.chests.has(c):
		for it in chests_ref.chests[c].items:
			if it.id == id:
				return true
	return false


## A chest counts as within reach if you can stand next to it.
func _reachable(c: Vector2i, r: Dictionary) -> bool:
	if r.dist.has(c):
		return true
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if r.dist.has(c + d):
			return true
	return false


func _nearest_key(color: String, r: Dictionary) -> Vector2i:
	var id := color + "_key"
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	var dist: Dictionary = r.dist
	if pickups != null:
		for c in pickups.ground:
			if pickups.ground[c].id == id and dist.has(c) and dist[c] < best_d:
				best = c
				best_d = dist[c]
	if chests_ref != null:
		for c in chests_ref.chests:
			if not _key_lies_at(c, color):
				continue
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if dist.has(c + d) and dist[c + d] + 1 < best_d:
					best = c
					best_d = dist[c + d] + 1
	return best


## How deep a cell is: the number of locked doors between it and the start.
func depth_at(c: Vector2i) -> int:
	return section_depth.get(section_of.get(c, -1), 0)


## The deepest section's depth (the master chamber's side of the map).
func max_depth() -> int:
	var m := 1
	for s in section_depth:
		m = maxi(m, section_depth[s])
	return m


## 0 at the start .. 1 at the deepest section. Enemies get stronger and
## chests richer as this rises.
func progress(c: Vector2i) -> float:
	return clampf(float(depth_at(c)) / float(max_depth()), 0.0, 1.0)


## Where a key that opens `door` was hidden (a chest or a spot on the floor).
func key_spot(door: Vector2i) -> Vector2i:
	return key_spots.get(door, Vector2i(-1, -1))


# --- Helpers -----------------------------------------------------------------

func _flood(from: Vector2i) -> Dictionary:
	var dist := {from: 0}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for n in _neighbors(c):
			if not dist.has(n):
				dist[n] = dist[c] + 1
				queue.append(n)
	return dist


func _path(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var prev := {a: a}
	var queue: Array[Vector2i] = [a]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if c == b:
			break
		for n in _neighbors(c):
			if not prev.has(n):
				prev[n] = c
				queue.append(n)
	var path: Array[Vector2i] = []
	if not prev.has(b):
		return path
	var c := b
	while c != a:
		path.push_front(c)
		c = prev[c]
	return path
