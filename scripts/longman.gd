class_name Longman
extends Node2D
## The Longman: what comes for you in the dark. One per player.
##
##   Your flame is low (its last quarter, at night): it shows itself at the
##   edge of your sight, standing, watching. It doesn't come yet.
##   Your light goes out: it gets down on all fours and comes for you, over
##   walls, rocks, graves and closed doors -- it climbs whatever is in the way.
##   Light again (a match, oil, a flare, a candle, a village, the sun): it
##   turns and crawls back off the edge of the screen, slower than it came.
##   Dark again: it comes back, from wherever it got to.
##   If it reaches you in the dark, it eats you. That's the end of the run.
##
## It isn't a creature on the grid like the others: it moves freely in tiles
## (x, z) with a height (y) -- the top of whatever it's on -- and wherever the
## next tile is higher or lower it goes to the edge and climbs the face. The
## 3D view shows it as an upright sprite in the world (a Sprite3D); the 2D
## view draws the same frames above the darkness, lifted by its height.
##
## Tuning is the block of constants below. Art: tools/make_longman.py.

signal ate(h: Hero)

static var all: Array = []

const SHEET: Texture2D = preload("res://assets/longman.png")
const FRAME := Vector2i(80, 80)
const FRAMES := {
	"idle": [0, 1], "tilt": [2, 3], "walk": [4, 5, 6, 7], "drop": [8], "crawl": [9, 10, 11, 12], "lunge": [13],
	"climb_back": [14, 15], "over": [16, 17], "down": [18, 19], "toward": [20, 36, 21, 37],
	"perch": [22, 23], "scale": [24, 25, 26, 27], "descend": [28, 29, 30, 31],
	"away": [32, 33, 34, 35], "lunge_toward": [38], "lunge_away": [39],
}
## Crawling, the frames step with the ground it actually covers (no sliding):
## one frame per this many tiles. Which way it faces follows its heading,
## smoothed, so a diagonal path doesn't flick between views.
const GAIT_STEP := 0.21
const HEAD_FOLLOW := 0.45      ## tiles crawled to swing its heading all the way round

# --- Tuning -------------------------------------------------------------------------------
const APPROACH_SPEED := 2.4      ## tiles per second, coming for you -- at first
const HUNT_TOP_SPEED := 9.2      ## ...and, the longer you stay dark, up to this: faster than your sprint
                                 ## (you walk 4.5 tiles a second, sprint 8.3 -- for ~4.5 s)
const HUNT_RAMP := 10.0          ## seconds of dark to reach top speed (slow to start: you get a head start)
const HUNT_COOL := 1.5           ## light drains the built-up speed this many times faster than dark builds it
const RETREAT_SPEED := 1.3       ## tiles per second, going back into the dark
const CLIMB_SPEED := 1.6         ## up or down a face, coming
const RETREAT_CLIMB := 1.0       ## ...going
const BOLT_SPEED := 10.0         ## caught in your light: it scuttles off faster than you can run
const BOLT_CLIMB := 6.0
const BOLT_AFTER := 0.7          ## ...and keeps bolting this long after it's out of the light
const LIGHT_MARGIN := 1.0        ## tiles past the edge of your light that still count as in it
const WATCH_TIME := 2.0          ## seconds it stands at the edge of the dark before it comes
const DROP_TIME := 0.55          ## folding down onto all fours
const LUNGE_TIME := 0.4
const REACH := 1.2               ## tiles: close enough to take you
const APPEAR_X := [8.5, 10.0]    ## where it first shows itself: this far to your left or right...
const APPEAR_Z := 4.0            ## ...and up to this far above or below you (tiles)
const OUT_OF_SIGHT := Vector2(13.0, 9.5)   ## this far away (x, z), it has left the screen
const FORGET := 30.0             ## further than this, next time it appears at the edge again
const RETREAT_TO := 16.0         ## it heads this far away from you when the light comes back
const SCARE_TIME := 6.0          ## a bomb going off near it sends it back for this long
const DREAD_RANGE := 7.0         ## your heart starts pounding when it's this close
const FACE_GAP := 0.16
const STEP := 0.12
const STRETCH := 1.0 / cos(View3D.PITCH) * 0.82   ## the same upright stretch as the other characters

var main: Node
var hero: Hero
var world: World
var view: View3D
var pos := Vector3.ZERO          ## tiles: x east, y height, z south (the 3D view's units)
var state := "away"              ## away, watch, drop, approach, lunge, retreat, feeding, gone
var placed := false              ## has it got a spot in the world yet?
var fade := 0.0                  ## 0 = not there, 1 = fully there
var path: Array[Vector2i] = []
var dir := Vector2i(0, 1)
var face_x := 1
var climbing := ""               ## "", "up", "down"
var scared := 0.0
var _climb_to := 0.0
var _hunt := 0.0                 ## seconds it has been hunting you in the dark (it speeds up)
var _t := 0.0
var _anim := 0.0
var _repath := 0.0
var _goal := Vector2i.ZERO
var _beat := 0.0
var _scrape := 0.0
var _breath := 0.0
var _sprite: Sprite3D
var _glow: OmniLight3D
var _shown_frame := 0
var _last_hero := Vector2.ZERO
var _flip := false
var _head := Vector2(0, 1)       ## which way it's heading (x, z), smoothed
var _gait := 0.0                 ## tiles crawled (steps the frames)
var _last_pos := Vector3.ZERO
var _view := "crawl"             ## crawl (side), toward or away
var _bolt := 0.0                 ## > 0: it's bolting from your light

static var _astar: AStarGrid2D
static var _astar_world: World
static var _wm: WorldMesh


func setup(m: Node, h: Hero) -> void:
	main = m
	hero = h
	world = m.world
	view = m.get("view3d")
	z_index = 5
	all.append(self)
	_build_paths(world)
	if view != null:
		_sprite = Sprite3D.new()
		_sprite.texture = SHEET
		_sprite.region_enabled = true
		_sprite.pixel_size = 1.0 / World.TILE
		_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_sprite.shaded = false          # pale even in the pitch dark
		_sprite.double_sided = true
		_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_sprite.offset = Vector2(0, FRAME.y / 2.0)   # bottom middle stands on its position
		_sprite.scale = Vector3(1.0, STRETCH, 1.0)
		_sprite.visible = false
		view.root.add_child(_sprite)
		_glow = OmniLight3D.new()       # a faint cold light: you see the stone it's on
		_glow.light_color = Color(0.7, 0.78, 1.0)
		_glow.light_energy = 0.0
		_glow.omni_range = 2.6
		_glow.omni_attenuation = 1.6
		view.root.add_child(_glow)


## (Only when it's really deleted: split screen moves the layer it lives on,
## which takes it out of the tree and puts it back.)
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		all.erase(self)
		if is_instance_valid(_sprite):
			_sprite.queue_free()
		if is_instance_valid(_glow):
			_glow.queue_free()


# --- The ground it moves over -------------------------------------------------------------

## Pathfinding over the whole labyrinth: everything is passable (it climbs),
## the ground is cheapest, walls and cliffs cost a little more, water more
## still. Villages are closed to it.
static func _build_paths(w: World) -> void:
	if _astar != null and _astar_world == w:
		return
	_astar_world = w
	_wm = WorldMesh.new()
	_wm.world = w
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, w.width, w.height)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.update()
	for y in w.height:
		for x in w.width:
			var c := Vector2i(x, y)
			if w.in_village(c) or w.near_village(c, 1):
				_astar.set_point_solid(c, true)
			elif w.tile_at(c) == "~":
				_astar.set_point_weight_scale(c, 3.0)
			elif w.tile_at(c) == "#":
				_astar.set_point_weight_scale(c, 1.6)


## The top of whatever is on a tile: the floor, a wall's top, a cliff, a
## closed door, a chest, a gravestone.
func surface(c: Vector2i) -> float:
	if not world._in_bounds(c):
		return 1.05
	var h := 0.0 if _wm.is_tree(c) else _wm.surface(c)
	if world.blockers.has(c):
		h = maxf(h, 1.0 if world.doors.has(c) else 0.55)
	match world.tile_at(c):
		"g": h = maxf(h, 0.55)
		"b": h = maxf(h, 0.5)
	return h


func cell() -> Vector2i:
	return Vector2i(int(floor(pos.x)), int(floor(pos.z)))


func _hero_pos() -> Vector2:
	if hero != null and is_instance_valid(hero.player):
		_last_hero = Vector2(hero.player.cell) + Vector2(0.5, 0.5)
	return _last_hero


func _rel() -> Vector2:
	return Vector2(pos.x, pos.z) - _hero_pos()


func distance() -> float:
	return _rel().length()


func on_screen() -> bool:
	var r := _rel()
	return absf(r.x) < OUT_OF_SIGHT.x and absf(r.y) < OUT_OF_SIGHT.y


# --- Each frame ---------------------------------------------------------------------------

## dark: the player's light is out (and nothing else lights them).
## watching: their flame is in its last quarter -- it shows itself, but waits.
## frozen: their game is paused behind a menu or a fight.
func tick(delta: float, dark: bool, watching: bool, daytime: bool, frozen: bool) -> void:
	if state == "feeding":
		_feed(delta)
		return
	if state == "gone" or hero == null or not is_instance_valid(hero.player) or not hero.alive():
		_show(false)
		return
	_anim += delta
	scared = maxf(scared - delta, 0.0)
	if daytime:
		# the sun: it's simply not there
		state = "away"
		placed = false
		fade = 0.0
		_show(false)
		return
	if frozen:
		_show(fade > 0.0)
		return
	var coming := dark and scared <= 0.0
	_t += delta
	if state == "approach" and coming:
		_hunt = minf(_hunt + delta, HUNT_RAMP)
	elif not coming:
		_hunt = maxf(_hunt - delta * HUNT_COOL, 0.0)
	match state:
		"away":
			fade = move_toward(fade, 0.0, delta * 2.0)
			if coming or (watching and scared <= 0.0):
				if not placed or distance() > FORGET:
					_appear()
				elif coming:
					_start_approach()   # it was waiting just out of sight: it comes back
				else:
					_appear()
		"watch":
			fade = move_toward(fade, 1.0, delta / 0.8)
			if _in_light():
				_start_retreat()   # you walked your light into it: it bolts
			elif coming and _t >= WATCH_TIME:
				state = "drop"
				_t = 0.0
				Sfx.play("screech", 0.0, 0.06)   # it has seen you, and it comes
			elif not coming and not watching:
				_start_retreat()
		"drop":
			fade = 1.0
			if not coming:
				_start_retreat()
			elif _t >= DROP_TIME:
				_start_approach()
		"approach":
			fade = move_toward(fade, 1.0, delta * 3.0)
			if not coming:
				_start_retreat()
			else:
				_approach(delta)
		"lunge":
			if _t >= LUNGE_TIME:
				if dark:
					_eat()
				else:
					_start_retreat()   # the light came back in time
		"retreat":
			if coming:
				_start_approach()
			else:
				_retreat(delta)
	_dread(delta)
	_show(fade > 0.01)


## Where this player's camera is looking (tiles). In split screen it isn't
## centred on them; alone it is.
var view_center: Vector2 = Vector2(-1, -1)


func _appear() -> void:
	# at the edge of your sight, to one side, standing on the ground
	var hc := hero.player.cell
	var best := Vector2i(-1, -1)
	var lean := 0
	if view_center.x >= 0.0 and absf(view_center.x - (hc.x + 0.5)) > 2.0:
		lean = 1 if view_center.x > hc.x + 0.5 else -1   # the side with more screen
	for attempt in 24:
		var side := lean if lean != 0 else (1 if randf() < 0.5 else -1)
		var c := hc + Vector2i(side * int(round(randf_range(APPEAR_X[0], APPEAR_X[1]))), int(round(randf_range(-APPEAR_Z, APPEAR_Z))))
		if not world._in_bounds(c) or _astar.is_point_solid(c):
			continue
		best = c
		if world.is_walkable(c):
			break
	if best.x < 0:
		best = hc + Vector2i(10, 0)
	pos = Vector3(best.x + 0.5, surface(best), best.y + 0.5)
	placed = true
	state = "watch"
	_t = 0.0
	fade = 0.0
	face_x = 1 if hc.x > best.x else -1
	climbing = ""
	Sfx.play_at("ghost_appear", Vector2(best * World.TILE), -2.0)


func _start_approach() -> void:
	state = "approach"
	Sfx.play_at("snarl", Vector2(pos.x, pos.z) * World.TILE, 1.0)
	_t = 0.0
	_repath = 0.0
	climbing = ""


func _start_retreat() -> void:
	if state == "away":
		return
	state = "retreat"
	_t = 0.0
	climbing = ""
	# somewhere well away from you, back the way it came
	var away := _rel()
	if away.length() < 0.5:
		away = Vector2(face_x * -1.0, 0.0)
	var g := _hero_pos() + away.normalized() * RETREAT_TO
	_goal = Vector2i(clampi(int(g.x), 1, world.width - 2), clampi(int(g.y), 1, world.height - 2))
	if _astar.is_point_solid(_goal):
		_goal = cell()
	path = _find_path(cell(), _goal)


## A bomb went off near it: it flinches back into the dark for a while.
func scare(at: Vector2, radius_tiles: float) -> void:
	if state in ["away", "gone"]:
		return
	var p := at / World.TILE
	if Vector2(pos.x, pos.z).distance_to(p) <= radius_tiles + 1.5:
		scared = SCARE_TIME
		_start_retreat()


func _find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not world._in_bounds(from) or not world._in_bounds(to):
		return out
	var was_solid := _astar.is_point_solid(from)
	_astar.set_point_solid(from, false)   # (it can always leave where it is)
	var p := _astar.get_id_path(from, to, true)
	_astar.set_point_solid(from, was_solid)
	for c in p:
		out.append(c)
	if not out.is_empty() and out[0] == from:
		out.remove_at(0)
	return out


## How fast it comes right now: a crawl at first, building -- slowly, then
## faster -- the longer you're in the dark, until it outruns your sprint.
func hunt_factor() -> float:
	var k := clampf(_hunt / HUNT_RAMP, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k) * 0.35 + k * k * 0.65   # an ease-in: gentle at first


func hunt_speed() -> float:
	return lerpf(APPROACH_SPEED, HUNT_TOP_SPEED, hunt_factor())


func _approach(delta: float) -> void:
	var hp := _hero_pos()
	var spd := hunt_speed()
	var mult := spd / APPROACH_SPEED
	if Vector2(pos.x, pos.z).distance_to(hp) <= REACH and climbing == "":
		state = "lunge"
		_t = 0.0
		face_x = 1 if hp.x >= pos.x else -1
		Sfx.play("ghost_strike", 2.0)
		return
	_repath -= delta
	if _repath <= 0.0 or path.is_empty():
		_repath = 0.4 / mult    # faster, it keeps closer track of you
		path = _find_path(cell(), hero.player.cell)
		if path.is_empty():
			# right beside you: go straight for you
			var p2 := Vector2(pos.x, pos.z).move_toward(hp, spd * delta)
			pos.x = p2.x
			pos.z = p2.y
			return
	_move(delta, spd, CLIMB_SPEED * mult)
	_scrape -= delta
	if _scrape <= 0.0:
		_scrape = 0.32 / mult   # its scrabbling quickens as it speeds up
		Sfx.play_at("step_stone%d" % (randi() % 3), Vector2(pos.x, pos.z) * World.TILE, -6.0)
	_breath -= delta
	if _breath <= 0.0:   # its ragged breathing, louder as it nears
		_breath = 1.25 / sqrt(mult)
		Sfx.play_at("breath", Vector2(pos.x, pos.z) * World.TILE, -3.0)


## Is it inside this player's lantern light (or near its edge)?
func _in_light() -> bool:
	if hero == null or hero.lantern == null:
		return false
	var r := hero.lantern.radius() / World.TILE
	return r > 0.0 and distance() <= r + LIGHT_MARGIN


func _retreat(delta: float) -> void:
	# going back into the dark, slowly, lingering -- unless your light touches
	# it: then it scuttles off, fast (you can't run it down)
	if _in_light():
		if _bolt <= 0.0:
			Sfx.play_at("screech", Vector2(pos.x, pos.z) * World.TILE, -6.0)
		_bolt = BOLT_AFTER
	else:
		_bolt = maxf(_bolt - delta, 0.0)
	if not on_screen():
		state = "away"   # gone from sight: it waits out there, in the dark
		fade = 0.0
		return
	if path.is_empty():
		_start_retreat()
		if path.is_empty():
			state = "away"
			return
	if _bolt > 0.0:
		_move(delta, BOLT_SPEED, BOLT_CLIMB)
	else:
		_move(delta, RETREAT_SPEED, RETREAT_CLIMB)


## Along the path, climbing whatever is higher or lower than where it is.
func _move(delta: float, speed: float, climb: float) -> void:
	if climbing != "":
		pos.y = move_toward(pos.y, _climb_to, climb * delta)
		if is_equal_approx(pos.y, _climb_to):
			var d := Vector3(dir.x, 0, dir.y)
			pos += d * (FACE_GAP * 2.0 + (0.25 if climbing == "up" else 0.1))
			climbing = ""
		return
	if path.is_empty():
		return
	var here := cell()
	var next: Vector2i = path[0]
	if next == here:
		path.remove_at(0)
		return
	if absi(next.x - here.x) + absi(next.y - here.y) > 1:
		# knocked off its path (it lunged, or the path is stale): find a new one
		path.clear()
		_repath = 0.0
		return
	dir = next - here
	if dir.x != 0:
		face_x = dir.x
	var h1 := surface(next)
	var edge := Vector2(here.x + 0.5 + dir.x * 0.5, here.y + 0.5 + dir.y * 0.5)
	if absf(h1 - pos.y) > STEP:
		var stop := edge - Vector2(dir) * FACE_GAP if h1 > pos.y else edge + Vector2(dir) * FACE_GAP
		var p := Vector2(pos.x, pos.z).move_toward(stop, speed * delta)
		pos.x = p.x
		pos.z = p.y
		if p.distance_to(stop) < 0.01:
			climbing = "up" if h1 > pos.y else "down"
			_climb_to = h1
		return
	var goal := Vector2(next.x + 0.5, next.y + 0.5)
	var p2 := Vector2(pos.x, pos.z).move_toward(goal, speed * delta)
	pos.x = p2.x
	pos.z = p2.y
	pos.y = move_toward(pos.y, h1, 2.0 * delta)


func _eat() -> void:
	# it lands where you stood and hunches over the spot
	var hp := _hero_pos()
	pos = Vector3(hp.x, surface(hero.player.cell), hp.y)
	state = "feeding"
	_t = 0.0
	climbing = ""
	Sfx.play("ghost_strike", 4.0)
	Sfx.play("hit", 2.0)
	ate.emit(hero)


const FEED_TIME := 1.6
const FEED_FADE := 1.2


func _feed(delta: float) -> void:
	_t += delta
	_anim += delta
	fade = 1.0 if _t < FEED_TIME else clampf(1.0 - (_t - FEED_TIME) / FEED_FADE, 0.0, 1.0)
	if _t >= FEED_TIME + FEED_FADE:
		state = "gone"
		fade = 0.0
	_show(fade > 0.01)


## Your heart pounds as it gets close.
func _dread(delta: float) -> void:
	if state not in ["approach", "drop", "lunge"]:
		return
	var d := distance()
	if d > DREAD_RANGE:
		return
	_beat -= delta
	if _beat <= 0.0:
		_beat = lerpf(0.32, 0.8, clampf(d / DREAD_RANGE, 0.0, 1.0))
		Sfx.play("heartbeat", lerpf(0.0, -8.0, d / DREAD_RANGE), 0.0)


# --- Drawing ------------------------------------------------------------------------------

## Which view of the crawl suits its heading: away from you up the screen,
## toward you down it, else from the side -- with a margin so it doesn't
## flicker between two when heading diagonally.
func _crawl_view() -> String:
	var y := _head.y
	match _view:
		"away":
			if y > -0.45: _view = "crawl"
		"toward":
			if y < 0.45: _view = "crawl"
		_:
			if y < -0.66: _view = "away"
			elif y > 0.66: _view = "toward"
	return _view


func _pick_frame() -> void:
	var key := "idle"
	var rate := 0.08
	var flip := false
	var mv := Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z)
	_last_pos = pos
	if mv.length() > 0.0005 and mv.length() < 1.0:
		# turns toward where it's going (by angle: it can turn right round), quicker the further it crawls
		var turn := wrapf(mv.angle() - _head.angle(), -PI, PI)
		_head = Vector2.from_angle(_head.angle() + turn * minf(1.0, mv.length() / HEAD_FOLLOW))
		_gait += mv.length()
	var by_gait := false
	match state:
		"watch":
			var cyc := fmod(_anim, 5.0)
			key = "tilt" if cyc > 2.6 and cyc < 4.2 else "idle"
			rate = 0.6 if key == "tilt" else 0.9
		"drop":
			key = "drop"
		"lunge":
			# at you from whichever side it's on: straight at you, up the screen away, or across
			var rel := _hero_pos() - Vector2(pos.x, pos.z)
			if absf(rel.y) > absf(rel.x) * 1.2:
				key = "lunge_toward" if rel.y > 0.0 else "lunge_away"
			else:
				key = "lunge"
				flip = face_x < 0
		"feeding":
			key = "perch"
			rate = 0.35
			flip = face_x < 0
		"approach", "retreat":
			if climbing == "up":
				rate = 0.14
				if dir.y < 0: key = "climb_back"
				elif dir.y > 0: key = "over"
				else:
					key = "scale"; flip = face_x < 0; rate = 0.08
			elif climbing == "down":
				rate = 0.14
				if dir.y > 0: key = "down"
				elif dir.y < 0: key = "climb_back"
				else:
					key = "descend"; flip = face_x < 0; rate = 0.08
			else:
				key = _crawl_view()
				flip = key == "crawl" and _head.x < 0.0
				by_gait = true
	var frames: Array = FRAMES[key]
	if by_gait:
		_shown_frame = frames[int(_gait / GAIT_STEP) % frames.size()]
	else:
		_shown_frame = frames[int(_anim / rate) % frames.size()]
	_flip = flip


func _shudder() -> Vector3:
	if state != "feeding" or _t > FEED_TIME:
		return Vector3.ZERO
	return Vector3(roundf(sin(_t * 47.0)) / World.TILE, 0, 0)


func _show(on: bool) -> void:
	_pick_frame()
	visible = on
	position = Vector2(pos.x + _shudder().x, pos.z) * World.TILE
	queue_redraw()
	if _sprite != null:
		var three := view.active
		_sprite.visible = on and three
		_sprite.position = pos + _shudder()
		_sprite.region_rect = Rect2(_shown_frame * FRAME.x, 0, FRAME.x, FRAME.y)
		_sprite.flip_h = _flip
		_sprite.modulate = Color(0.9, 0.91, 0.98, fade)
		_glow.visible = on and three
		_glow.position = pos + Vector3(0, 1.4, 0.4)
		_glow.light_energy = 0.55 * fade


func _draw() -> void:
	paint(self, Vector2.ZERO)


## The 2D view (and player 2's half of a split screen): the same frame, above
## the darkness, its feet at its spot and lifted by the height it's climbed to.
func paint(ci: CanvasItem, at: Vector2) -> void:
	if not visible or fade <= 0.01:
		return
	var feet := at + Vector2(0, -pos.y * World.TILE)
	var dst := Rect2(feet - Vector2(FRAME.x / 2.0, FRAME.y), Vector2(FRAME))
	var src := Rect2(_shown_frame * FRAME.x, 0, FRAME.x, FRAME.y)
	var col := Color(0.92, 0.93, 1.0, fade)
	if _flip:
		ci.draw_set_transform(feet, 0.0, Vector2(-1, 1))
		ci.draw_texture_rect_region(SHEET, Rect2(Vector2(-FRAME.x / 2.0, -FRAME.y), Vector2(FRAME)), src, col)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		ci.draw_texture_rect_region(SHEET, dst, src, col)
