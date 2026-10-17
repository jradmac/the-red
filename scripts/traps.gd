class_name Traps
extends Node2D
## Traps scattered through the labyrinth, a different set for each landscape.
## They hurt you directly (armor doesn't help) -- a little damage variety
## between fights. Most are faintly visible if you watch the floor.
##
##   crypt      SPIKE PLATE   a loose flagstone: spears shoot up when stepped on
##              SPIKE ROW     spikes that rise and sink on a timer -- time your crossing
##              TRAPDOOR      a wooden hatch: you drop through and climb back out
##              DART PLATE    a click... a dart flies out of the wall
##   courtyard  SPIKE PLATE, DART PLATE, FALLING MASONRY (a shadow, then stones)
##   forest     BEAR TRAP     steel jaws: snaps shut and holds you a moment
##              THORNS        a bramble patch that scratches
##   mountain   ROCKFALL      a shadow grows -- keep moving or get crushed
##   river      BEAR TRAP, QUICKSAND (slows you down)
##   swamp      GAS VENT      belches poison clouds every few seconds
##              QUICKSAND
## Deeper traps hit a little harder.

const TILES_PER_TRAP := 400
const MIN_START_DIST := 10
const KINDS_BY_BIOME := {
	0: ["spike_plate", "spike_plate", "spike_row", "trapdoor", "dart_plate"],
	1: ["bear_trap", "bear_trap", "thorns"],
	2: ["spike_plate", "dart_plate", "masonry"],
	3: ["rockfall", "rockfall", "spike_plate"],
	4: ["bear_trap", "quicksand"],
	5: ["gas_vent", "gas_vent", "quicksand"],
}
const BASE_DAMAGE := {"spike_plate": 2, "spike_row": 2, "trapdoor": 3, "dart_plate": 1, "masonry": 2,
	"bear_trap": 2, "thorns": 1, "rockfall": 3, "quicksand": 1, "gas_vent": 1}
const NAMES := {"spike_plate": "SPIKES", "spike_row": "SPIKES", "trapdoor": "A TRAPDOOR", "dart_plate": "A DART",
	"masonry": "FALLING STONES", "bear_trap": "A BEAR TRAP", "thorns": "THORNS", "rockfall": "A ROCKFALL",
	"quicksand": "QUICKSAND", "gas_vent": "POISON GAS"}
const REARM := 4.0           # seconds before a sprung trap can go off again
const ROW_UP := 1.0          # spike row: seconds up / down
const ROW_DOWN := 2.4
const VENT_EVERY := Vector2(4.0, 7.0)
const VENT_CLOUD := 1.8

signal hurt(text: String, damage: int)

var world: World
var player: Player
var doors: Doors
var traps := {}   # cell -> {kind, t (anim time), armed_in, damage, phase, ...}
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _gas_tick := 0.0
var _ci: CanvasItem = self   # what the draw helpers draw on
var _fx: Node2D              # springing spears, falling rocks, gas: drawn above the hero
var _fx_pass := false


func setup(w: World, p: Player, d: Doors, pickups: Pickups, chests: Chests) -> void:
	world = w
	player = p
	doors = d
	_rng.seed = world.seed_value + 1313
	var spots: Array[Vector2i] = []
	for y in range(1, world.height - 1):
		for x in range(1, world.width - 1):
			var c := Vector2i(x, y)
			var t := world.tile_at(c)
			if not (t == "." or t == ",") or not world.is_walkable(c):
				continue
			if (Vector2(c) - Vector2(world.start_cell)).length() < MIN_START_DIST:
				continue
			if world.doors.has(c) or world.arches.has(c) or world.reserved.has(c) or pickups.has_item_at(c) or world.ramps.has(c) \
					or world.near_village(c, 3):
				continue
			spots.append(c)
	var want := maxi(8, spots.size() / TILES_PER_TRAP)   # ~1 per 400 open tiles
	for n in want * 6:
		if traps.size() >= want or spots.is_empty():
			break
		var c: Vector2i = spots[_rng.randi() % spots.size()]
		if _near_trap(c):
			continue
		var kinds: Array = KINDS_BY_BIOME.get(world.biome_at(c), KINDS_BY_BIOME[0])
		var kind: String = kinds[_rng.randi() % kinds.size()]
		if kind == "spike_row" and world.room_at(c).size != Vector2i.ZERO:
			kind = "spike_plate"
		if kind == "dart_plate" and not _next_to_wall(c):
			kind = "spike_plate"
		var prog := doors.progress(c)
		traps[c] = {"kind": kind, "t": -1.0, "armed_in": 0.0, "damage": BASE_DAMAGE[kind] + int(round(prog * 2.0)),
			"phase": _rng.randf() * 3.0, "vent": _rng.randf_range(VENT_EVERY.x, VENT_EVERY.y), "cloud": 0.0}
	# (main connects each hero's footsteps to _on_stepped)
	_fx = Node2D.new()
	_fx.z_index = 1
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


func bind(h: Hero) -> void:
	player = h.player


func _near_trap(c: Vector2i) -> bool:
	for t in traps:
		if absi(t.x - c.x) <= 3 and absi(t.y - c.y) <= 3:
			return true
	return false


func _next_to_wall(c: Vector2i) -> bool:
	for d in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		if world.tile_at(c + d) == "#":
			return true
	return false


func trap_at(c: Vector2i) -> Dictionary:
	return traps.get(c, {})


## You stepped onto a tile: is there a trap?
func _on_stepped(c: Vector2i) -> void:
	if not traps.has(c) or player.dead:
		return
	var tr: Dictionary = traps[c]
	if tr.armed_in > 0.0:
		return
	match tr.kind:
		"spike_plate", "trapdoor", "dart_plate", "bear_trap", "thorns", "quicksand":
			tr.t = 0.0
			tr.armed_in = REARM
			_hit(tr)
			if tr.kind == "bear_trap":
				player.stuck_t = 1.4
			elif tr.kind == "trapdoor":
				player.stuck_t = 1.0
			elif tr.kind == "quicksand":
				player.slow_steps = 4
		"rockfall", "masonry":
			if tr.t < 0.0:
				Sfx.play("trap_click")
				tr.t = 0.0      # the shadow starts to grow...
				tr.armed_in = REARM + 1.0
				tr["hit"] = false
		"spike_row":
			if _row_up(tr):
				_hit(tr)
				tr.armed_in = 1.0


const SOUND := {"spike_plate": "trap_spike", "spike_row": "trap_spike", "trapdoor": "trap_thud",
	"dart_plate": "trap_dart", "masonry": "", "bear_trap": "trap_snap", "thorns": "trap_snap",
	"rockfall": "", "quicksand": "trap_sink", "gas_vent": "trap_gas"}


func _hit(tr: Dictionary) -> void:
	if SOUND.get(tr.kind, "") != "":
		Sfx.play(SOUND[tr.kind])
	Sfx.play("hurt", -4.0)
	var lines := {"spike_plate": "CLICK! SPEARS STAB UP FROM THE FLOOR!", "spike_row": "THE SPIKES CATCH YOU!",
		"trapdoor": "THE FLOOR GIVES WAY! YOU FALL AND CLIMB BACK OUT.", "dart_plate": "CLICK... A DART FLIES FROM THE WALL!",
		"masonry": "STONES CRASH DOWN ON YOU!", "bear_trap": "SNAP! A BEAR TRAP BITES YOUR LEG!",
		"thorns": "THORNS TEAR AT YOU!", "rockfall": "ROCKS CRASH DOWN ON YOU!",
		"quicksand": "QUICKSAND! IT SUCKS AT YOUR BOOTS.", "gas_vent": "POISON GAS BURNS YOUR LUNGS!"}
	hurt.emit(lines[tr.kind] + " -" + str(tr.damage), tr.damage)


func _row_up(tr: Dictionary) -> bool:
	return fmod(_time + tr.phase, ROW_UP + ROW_DOWN) < ROW_UP


func _process(delta: float) -> void:
	_time += delta
	_gas_tick = maxf(_gas_tick - delta, 0.0)
	for c in traps:
		var tr: Dictionary = traps[c]
		tr.armed_in = maxf(tr.armed_in - delta, 0.0)
		if tr.t >= 0.0:
			tr.t += delta
		match tr.kind:
			"spike_row":
				# standing still on the row when it rises hurts too
				for h in Hero.all:
					if h.alive() and h.player.ui_lock == "" and h.player.cell == c and not h.player.moving \
							and _row_up(tr) and tr.armed_in <= 0.0:
						Hero.bind_all(h)
						_hit(tr)
						tr.armed_in = ROW_UP + ROW_DOWN
			"rockfall", "masonry":
				if tr.t >= 0.75 and not tr.get("hit", true):
					tr["hit"] = true
					Sfx.play_at("trap_rocks", world.cell_to_position(c))
					for h in Hero.all:
						if h.alive() and h.player.cell == c:   # still standing under it? (sprint through!)
							Hero.bind_all(h)
							_hit(tr)
				if tr.t > 1.6:
					tr.t = -1.0
			"gas_vent":
				tr.vent -= delta
				if tr.vent <= 0.0:
					tr.vent = _rng.randf_range(VENT_EVERY.x, VENT_EVERY.y)
					tr.cloud = VENT_CLOUD
				tr.cloud = maxf(tr.cloud - delta, 0.0)
				if tr.cloud > 0.0 and _gas_tick <= 0.0:
					for h in Hero.all:
						if h.alive() and h.player.ui_lock == "" \
								and absi(h.player.cell.x - c.x) <= 1 and absi(h.player.cell.y - c.y) <= 1:
							_gas_tick = 1.0
							Hero.bind_all(h)
							_hit(tr)
		if tr.t > 1.2 and tr.kind in ["spike_plate", "trapdoor", "dart_plate", "thorns", "quicksand"]:
			tr.t = -1.0
		if tr.kind == "bear_trap" and tr.t > REARM:
			tr.t = -1.0
	queue_redraw()
	_fx.queue_redraw()


# --- Drawing ---------------------------------------------------------------------

func _draw() -> void:
	_ci = self
	_fx_pass = false
	_draw_all()


func _draw_fx() -> void:
	_ci = _fx
	_fx_pass = true
	_draw_all()
	_ci = self


func _draw_all() -> void:
	var v := world.fx_cells()
	for c in traps:
		if not v.has_point(c):
			continue
		var tr: Dictionary = traps[c]
		var o := world.cell_to_position(c)
		match tr.kind:
			"spike_plate": _draw_spike_plate(o, tr)
			"spike_row": _draw_spike_row(o, tr)
			"trapdoor": _draw_trapdoor(o, tr)
			"dart_plate": _draw_dart_plate(o, c, tr)
			"bear_trap": _draw_bear_trap(o, tr)
			"thorns": _draw_thorns(o, tr)
			"rockfall", "masonry": _draw_fall(o, tr)
			"quicksand": _draw_quicksand(o, tr)
			"gas_vent": _draw_vent(o, tr)


func _px(o: Vector2, x: float, y: float, w: float, h: float, col: Color) -> void:
	_ci.draw_rect(Rect2(o + Vector2(x, y), Vector2(w, h)), col)


## Spears: a ring of steel tips that shoot up and slowly sink back.
func _spears(o: Vector2, height: float) -> void:
	if height <= 0.0 or not _fx_pass:
		return
	for i in 4:
		var x := 2.0 + i * 3.6
		var h := height * (0.8 + 0.2 * ((i * 7) % 3))
		_px(o, x, 13 - h, 1, h, Color("c8cedc"))
		_px(o, x + 1, 13 - h, 1, h, Color("6a7286"))
		_px(o, x, 12 - h, 2, 1, Color("ffffff"))


func _draw_spike_plate(o: Vector2, tr: Dictionary) -> void:
	# a slightly sunken flagstone with tiny holes
	if _fx_pass:
		if tr.t >= 0.0:
			var k0: float = tr.t
			_spears(o, 10.0 if k0 < 0.5 else 10.0 * (1.0 - (k0 - 0.5) / 0.7))
		return
	_px(o, 2, 2, 12, 12, Color(0, 0, 0, 0.18))
	_px(o, 2, 2, 12, 1, Color(1, 1, 1, 0.08))
	for hx in [4, 8, 12]:
		for hy in [5, 10]:
			_px(o, hx - 1, hy, 1, 1, Color(0, 0, 0, 0.45))
	if tr.t >= 0.0:
		var k: float = tr.t
		_spears(o, 10.0 if k < 0.5 else 10.0 * (1.0 - (k - 0.5) / 0.7))


func _draw_spike_row(o: Vector2, tr: Dictionary) -> void:
	if not _fx_pass:
		_px(o, 0, 3, 16, 10, Color(0, 0, 0, 0.22))
		for i in 5:
			_px(o, 1 + i * 3, 8, 1, 1, Color(0, 0, 0, 0.5))
	var cyc := fmod(_time + tr.phase, ROW_UP + ROW_DOWN)
	var h := 0.0
	if cyc < ROW_UP:
		h = 9.0 * clampf(cyc / 0.1, 0.0, 1.0)
	elif cyc > ROW_UP + ROW_DOWN - 0.5:
		h = 2.0 * sin((cyc - ROW_UP - ROW_DOWN + 0.5) * 30.0) + 1.0   # rumbling warning
	_spears(o, h)


func _draw_trapdoor(o: Vector2, tr: Dictionary) -> void:
	if _fx_pass:
		return
	var open: bool = tr.t >= 0.0 and tr.t < 1.0
	if open:
		_px(o, 2, 2, 12, 12, Color("06050a"))
		_px(o, 2, 2, 12, 2, Color("3a2a1e"))
		return
	for i in 4:   # planks
		_px(o, 2 + i * 3, 2, 3, 12, Color("5a4030") if i % 2 else Color("6a4a36"))
		_px(o, 2 + i * 3, 2, 1, 12, Color("3a2a1e"))
	_px(o, 2, 7, 12, 1, Color("2a1e16"))
	_px(o, 12, 6, 1, 3, Color("8a8494"))   # iron ring


func _draw_dart_plate(o: Vector2, c: Vector2i, tr: Dictionary) -> void:
	if not _fx_pass:
		_px(o, 4, 4, 8, 8, Color(0, 0, 0, 0.16))
		_px(o, 4, 4, 8, 1, Color(1, 1, 1, 0.07))
		return
	if tr.t >= 0.0 and tr.t < 0.35:
		# the dart streaks in from the nearest wall
		var from := Vector2(8, -16)
		if world.tile_at(c + Vector2i.LEFT) == "#":
			from = Vector2(-16, 8)
		elif world.tile_at(c + Vector2i.RIGHT) == "#":
			from = Vector2(32, 8)
		var p: Vector2 = from.lerp(Vector2(8, 6), tr.t / 0.35)
		var dirv := (Vector2(8, 6) - from).normalized()
		for k in 6:
			_ci.draw_rect(Rect2(o + p - dirv * k, Vector2(1, 1)), Color(0.9, 0.9, 1.0, 1.0 - k / 6.0))


func _draw_bear_trap(o: Vector2, tr: Dictionary) -> void:
	if _fx_pass:
		return
	var shut: bool = tr.t >= 0.0
	var steel := Color("8a8f9e")
	var dark := Color("3a3c46")
	_px(o, 3, 10, 10, 2, dark)   # base plate
	_px(o, 7, 7, 2, 2, Color("6a5a48"))
	if shut:
		_px(o, 3, 6, 10, 2, steel)
		for i in 5:
			_px(o, 3 + i * 2, 5, 1, 1, Color("c8ccd8"))
			_px(o, 4 + i * 2, 8, 1, 1, Color("c8ccd8"))
	else:
		for side in [0, 1]:
			var y := 4 if side == 0 else 12
			_px(o, 2, y, 12, 1, steel)
			for i in 6:
				_px(o, 2 + i * 2, y + (1 if side == 0 else -1), 1, 1, Color("c8ccd8"))
		_px(o, 2, 4, 1, 9, dark)
		_px(o, 13, 4, 1, 9, dark)


func _draw_thorns(o: Vector2, tr: Dictionary) -> void:
	if _fx_pass:
		return
	var shake := 1.0 if tr.t >= 0.0 and tr.t < 0.4 else 0.0
	for i in 7:
		var x := 2.0 + fmod(i * 5.3, 12.0) + shake * sin(_time * 40.0 + i)
		var y := 4.0 + fmod(i * 3.7, 9.0)
		_px(o, x, y, 3, 1, Color("4a3a24"))
		_px(o, x + 1, y - 1, 1, 3, Color("4a3a24"))
		_px(o, x, y - 1, 1, 1, Color("c8b890"))
		_px(o, x + 2, y + 1, 1, 1, Color("c8b890"))


## A shadow grows, then rocks / stones slam down.
func _draw_fall(o: Vector2, tr: Dictionary) -> void:
	# loose rubble marks the spot
	if not _fx_pass:
		for i in 3:
			_px(o, 3 + i * 4, 11 - i % 2, 2, 2, Color(0.5, 0.45, 0.4, 0.6))
		if tr.t >= 0.0 and tr.t < 0.75:
			_ci.draw_circle(o + Vector2(8, 9), 3.0 + 6.0 * (tr.t / 0.75), Color(0, 0, 0, 0.35 + 0.3 * tr.t))
		return
	if tr.t < 0.0:
		return
	var k: float = tr.t
	if k < 0.75:
		# the rocks, falling from above
		var yfall := lerpf(-60.0, 4.0, pow(k / 0.75, 2.0))
		var col := Color("7a6c60") if tr.kind == "rockfall" else Color("a89c88")
		_px(o, 4, yfall, 5, 4, col)
		_px(o, 9, yfall - 6, 4, 4, col.darkened(0.2))
		_px(o, 6, yfall - 12, 3, 3, col.lightened(0.15))
	elif k < 1.5:
		var a := 1.0 - (k - 0.75) / 0.75
		var col := Color("7a6c60") if tr.kind == "rockfall" else Color("a89c88")
		_px(o, 2, 8, 6, 5, Color(col, a))
		_px(o, 8, 9, 5, 4, Color(col.darkened(0.2), a))
		for i in 6:   # dust
			var ang := i * TAU / 6.0
			_ci.draw_rect(Rect2(o + Vector2(8, 10) + Vector2.from_angle(ang) * (k - 0.75) * 30.0, Vector2(2, 2)), Color(0.8, 0.75, 0.7, a * 0.7))


func _draw_quicksand(o: Vector2, tr: Dictionary) -> void:
	if _fx_pass:
		return
	_ci.draw_circle(o + Vector2(8, 8), 7.0, Color("6a5236"))
	_ci.draw_circle(o + Vector2(8, 8), 5.0, Color("5a4430"))
	var swirl := _time * 1.5
	for i in 3:
		var a := swirl + i * TAU / 3.0
		_ci.draw_rect(Rect2(o + Vector2(8, 8) + Vector2.from_angle(a) * 3.5, Vector2(2, 1)), Color("7a6040"))


func _draw_vent(o: Vector2, tr: Dictionary) -> void:
	if _fx_pass:
		_draw_cloud(o, tr)
		return
	_ci.draw_circle(o + Vector2(8, 9), 4.0, Color("2a3a1a"))
	_ci.draw_circle(o + Vector2(8, 9), 2.5, Color("141c0e"))
	# little bubbles, faster right before a burst
	var fast: bool = tr.vent < 1.2
	for i in 3:
		var ph := fmod(_time * (2.5 if fast else 0.8) + i * 0.33, 1.0)
		_ci.draw_circle(o + Vector2(6 + i * 2, 9 - ph * 6), 1.0, Color(0.6, 0.85, 0.3, 1.0 - ph))


func _draw_cloud(o: Vector2, tr: Dictionary) -> void:
	if tr.cloud > 0.0:
		var k: float = 1.0 - tr.cloud / VENT_CLOUD
		var r := 10.0 + 14.0 * sin(clampf(k, 0.0, 1.0) * PI * 0.5)
		var a := 0.45 * (1.0 - k * 0.6)
		for j in 4:
			var off := Vector2.from_angle(j * 1.7 + _time) * 5.0
			_ci.draw_circle(o + Vector2(8, 6) + off, r * 0.7, Color(0.5, 0.75, 0.2, a * 0.6))
		_ci.draw_circle(o + Vector2(8, 6), r, Color(0.45, 0.7, 0.2, a * 0.4))


# --- For the 3D view (it models the springing parts itself) ---------------------------

## Hides the drawn springing parts (spears, darts, rocks, gas) while the 3D
## view shows its own.
func set_fx_hidden(on: bool) -> void:
	if _fx != null:
		_fx.visible = not on


## How far a trap's spears stand up right now, in pixels (0: down).
func spear_height(tr: Dictionary) -> float:
	match tr.kind:
		"spike_plate":
			if tr.t >= 0.0:
				var k: float = tr.t
				return maxf(10.0 if k < 0.5 else 10.0 * (1.0 - (k - 0.5) / 0.7), 0.0)
		"spike_row":
			var cyc := fmod(_time + tr.phase, ROW_UP + ROW_DOWN)
			if cyc < ROW_UP:
				return 9.0 * clampf(cyc / 0.1, 0.0, 1.0)
			elif cyc > ROW_UP + ROW_DOWN - 0.5:
				return maxf(2.0 * sin((cyc - ROW_UP - ROW_DOWN + 0.5) * 30.0) + 1.0, 0.0)
	return 0.0
