class_name Wind
extends Node2D
## Drafty corridors (fixed per labyrinth) make the lantern burn faster.
## Random GUSTS (anywhere, at night) blow it straight out -- unless a
## Windbreak potion is protecting the flame. A gust gives a couple of seconds'
## warning ("THE WIND PICKS UP...") before it hits.
##
## Drafts don't blow evenly: every few seconds a PUFF runs down each drafty
## stretch (a front moving downwind, the air behind it trailing off), and the
## flame leans with it. In the 3D view WindFx shows the puffs and the gusts
## (ribbons of air, things blowing along, the grass bending); the flat streaks
## here are only drawn when the 3D view is off.

const TILES_PER_ZONE := 600   # one drafty stretch per this many map tiles
const ZONE_REACH := 9          # how far each draft spreads along corridors
const ZONE_DRAIN := 3.0        # lantern drain multiplier inside a draft
const GUST_DRAIN := 4.0
const GUST_EVERY := Vector2(60.0, 120.0)  # seconds between gusts (min, max)
const FIRST_GUST := Vector2(200.0, 260.0) # the first one holds off a while (learn the ropes first)
const GUST_WARNING := 2.0                 # seconds of warning before it hits
const GUST_LENGTH := 2.8
const C_STREAK := Color(0.9, 0.92, 1.0, 0.85)
const C_TRAIL := Color(0.9, 0.92, 1.0, 0.35)
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const PUFF_EVERY := Vector2(3.0, 6.0)   ## seconds between puffs down a drafty stretch
const PUFF_SPEED := 7.0                 ## tiles a second the puff's front runs downwind
const PUFF_AHEAD := 0.8                 ## the front's leading edge (tiles)
const PUFF_TAIL := 2.6                  ## the air trailing behind it (tiles)
const DRAFT_BASE := 0.3                 ## how hard a draft pushes the flame between puffs

var world: World
var zones := {}            # cell -> Vector2 direction the wind blows
var gust_dir := Vector2.ZERO
var gust_left := 0.0
var _gust_timer := 0.0
var warning_left := 0.0    ## > 0 while a gust is about to hit
var enabled: Callable      ## gusts only blow when this says so (at night)
signal gust_hit            ## the gust arrives
var _time := 0.0
var _rng := RandomNumberGenerator.new()
## the drafty stretches: {dir, cells (cell -> true), lo, hi (along dir), next, front (-INF: no puff)}
var stretches: Array = []
var _stretch_of := {}      ## cell -> stretch index
var _puff_rng := RandomNumberGenerator.new()   ## (its own dice: the labyrinth comes out the same)
signal puffed(stretch: int)   ## a puff starts down a stretch
var _fx: Node3D            ## the wind in the 3D view (WindFx), once there is one


func setup(w: World) -> void:
	world = w
	_rng.seed = world.seed_value + 101
	_gust_timer = _rng.randf_range(FIRST_GUST.x, FIRST_GUST.y)   # a calm first few minutes
	_build_zones()
	_puff_rng.seed = world.seed_value + 202
	for st in stretches:
		st.next = _puff_rng.randf_range(0.3, PUFF_EVERY.y)   # each stretch out of step with the rest


func _build_zones() -> void:
	var candidates: Array[Vector2i] = []
	for y in world.height:
		for x in world.width:
			var c := Vector2i(x, y)
			if world.is_walkable(c) and world.room_at(c).size == Vector2i.ZERO \
					and (c - world.start_cell).length() > 8 and not world.near_village(c, 1):
				candidates.append(c)
	for i in maxi(4, (world.width * world.height) / TILES_PER_ZONE):
		if candidates.is_empty():
			return
		var origin: Vector2i = candidates[_rng.randi() % candidates.size()]
		var dir := Vector2(DIRS[_rng.randi() % 4])
		var st := {"dir": dir, "cells": {}, "lo": INF, "hi": -INF, "next": 0.0, "front": -INF}
		stretches.append(st)
		var dist := {origin: 0}
		var queue: Array[Vector2i] = [origin]
		var head := 0
		while head < queue.size():
			var c: Vector2i = queue[head]
			head += 1
			zones[c] = dir
			st.cells[c] = true
			_stretch_of[c] = stretches.size() - 1
			var along := (Vector2(c) + Vector2(0.5, 0.5)).dot(dir)
			st.lo = minf(st.lo, along)
			st.hi = maxf(st.hi, along)
			if dist[c] >= ZONE_REACH:
				continue
			for d in DIRS:
				var n: Vector2i = c + d
				if not dist.has(n) and world.is_walkable(n) and world.room_at(n).size == Vector2i.ZERO:
					dist[n] = dist[c] + 1
					queue.append(n)


## Wind at a cell right now: its direction, as long as it's strong (zero if
## calm; a draft is light between puffs, about 1 in one, more in a gust).
## Gusts override drafts.
func wind_at(cell: Vector2i) -> Vector2:
	if world.near_village(cell, 1):
		return Vector2.ZERO   # the village walls break the wind
	if gust_left > 0.0:
		return gust_dir * (1.0 + 0.6 * gust_power())
	var d: Vector2 = zones.get(cell, Vector2.ZERO)
	if d == Vector2.ZERO:
		return d
	return d * (DRAFT_BASE + (1.0 - DRAFT_BASE) * puff_at(Vector2(cell) + Vector2(0.5, 0.5)))


## How hard a puff is blowing at a point (tiles) right now, 0..1.
func puff_at(p: Vector2) -> float:
	var i: int = _stretch_of.get(Vector2i(floori(p.x), floori(p.y)), -1)
	if i < 0:
		return 0.0
	return puff_strength(stretches[i], p)


## A stretch's puff at a point (tiles): strongest just behind the front.
static func puff_strength(st: Dictionary, p: Vector2) -> float:
	if st.front == -INF:
		return 0.0
	var d := p.dot(st.dir) - float(st.front)
	if d > 0.0:
		return pow(clampf(1.0 - d / PUFF_AHEAD, 0.0, 1.0), 1.5)
	return pow(clampf(1.0 + d / PUFF_TAIL, 0.0, 1.0), 1.5)


## A gust's strength, 0..1: building through the warning, full once it hits,
## dying away at the end.
func gust_power() -> float:
	if gust_left > 0.0:
		return clampf((GUST_LENGTH - gust_left) / 0.35, 0.0, 1.0) * clampf(gust_left / 0.8, 0.0, 1.0)
	if warning_left > 0.0:
		return 0.25 * (1.0 - warning_left / GUST_WARNING)
	return 0.0


## Lantern drain multiplier at a cell right now.
func drain_at(cell: Vector2i) -> float:
	if world.near_village(cell, 1):
		return 1.0
	if gust_left > 0.0:
		return GUST_DRAIN
	return ZONE_DRAIN if zones.has(cell) else 1.0


func _process(delta: float) -> void:
	_time += delta
	_puffs(delta)
	if _fx == null:
		var v3 = get_parent().get("view3d") if get_parent() != null else null
		if v3 != null and v3.get("_built") and v3.root != null:
			_fx = WindFx.new()
			v3.root.add_child(_fx)
			_fx.setup(v3, self)
	if gust_left > 0.0:
		gust_left -= delta
	elif warning_left > 0.0:
		warning_left -= delta
		if warning_left <= 0.0:
			gust_left = GUST_LENGTH
			gust_hit.emit()
	else:
		_gust_timer -= delta
		if _gust_timer <= 0.0:
			_gust_timer = _rng.randf_range(GUST_EVERY.x, GUST_EVERY.y)
			if not enabled.is_valid() or enabled.call():
				gust_dir = Vector2(DIRS[_rng.randi() % 4])
				warning_left = GUST_WARNING
	queue_redraw()


## Every few seconds a puff runs down each drafty stretch.
func _puffs(delta: float) -> void:
	for i in stretches.size():
		var st: Dictionary = stretches[i]
		if st.front != -INF:
			st.front += PUFF_SPEED * delta
			if st.front > st.hi + PUFF_TAIL + 0.5:
				st.front = -INF
		else:
			st.next -= delta
			if st.next <= 0.0:
				st.next = _puff_rng.randf_range(PUFF_EVERY.x, PUFF_EVERY.y)
				st.front = st.lo - PUFF_AHEAD - 0.5
				puffed.emit(i)


## The 3D view shows the wind itself (WindFx); the flat streaks are for the 2D view.
func _shown_in_3d() -> bool:
	var v3 = get_parent().get("view3d") if get_parent() != null else null
	return v3 != null and v3.active


func _draw() -> void:
	if _shown_in_3d():
		return
	# Streaks on on-screen tiles that have wind right now.
	var v := world.fx_cells()
	for y in range(v.position.y, v.end.y):
		for x in range(v.position.x, v.end.x):
			var c := Vector2i(x, y)
			if not world.is_walkable(c):
				continue
			var dir := wind_at(c)
			if dir == Vector2.ZERO:
				continue
			dir = dir.normalized()
			_draw_streaks(c, dir, 4 if gust_left > 0.0 else 3)


func _draw_streaks(c: Vector2i, dir: Vector2, count: int) -> void:
	var t := float(World.TILE)
	var tile := Rect2(Vector2(c) * t, Vector2(t, t))
	var across := Vector2(-dir.y, dir.x)
	var h := absi(c.x * 73856093 ^ c.y * 19349663)
	for i in count:
		var lane := float((h >> (i * 4)) % 13 + 1)
		var speed := 70.0 + float((h >> (i * 5)) % 40)
		var streak_len := 5.0 + float((h >> (i * 2)) % 4)
		var along := fmod(_time * speed + float(h % 97) + i * 23.0, t + streak_len) - streak_len
		# Start at the upwind edge of the tile and travel downwind.
		var start := tile.get_center() - (dir + across) * t * 0.5 + across * lane + dir * along
		if dir.x < 0 or dir.y < 0:
			start -= dir.abs() * streak_len
		var head := Rect2(start, dir.abs() * streak_len + across.abs()).abs().intersection(tile)
		var tail := Rect2(start - dir * 3.0, dir.abs() * 3.0 + across.abs()).abs().intersection(tile)
		if tail.has_area():
			draw_rect(tail, C_TRAIL)
		if head.has_area():
			draw_rect(head, C_STREAK)
