class_name LockPuzzle
extends CanvasLayer
## Lockpicking: pins bounce up and down in their channels. Press A (Z) when
## the highlighted pin crosses the gold shear line to set it, one pin at a time.
##   bronze: 3 pins, slow    silver: 4 pins    gold: 5 pins, fast    master seal: 6
##
## It's meant to be stressful. Your lantern burns much faster while you're
## bent over a lock (PICK_DRAIN), and every miss takes a big bite out of it
## (MISS_FUEL) -- miss too often and the flame dies, you're thrown out of the
## lock, and the Longman comes. The lantern meter runs along the bottom of the
## screen. On gold and the seal a miss knocks every pin back down; on silver it
## drops the last pin you set.
##
## The deeper the door (Doors.progress: 0 near the start, 1 at the bottom), the
## faster the pins move (DEPTH_SPEED), the tighter the window (DEPTH_TOLERANCE),
## and past halfway they stop moving evenly (ERRATIC). Roughly how long a pin
## sits in the window: bronze ~200 ms at the start, gold ~70 ms at the bottom.
## B (X) gives up and keeps your key.
##
## Bent over a lock you aren't safe. If the flame dies (and no flare or other
## light is near), the lock goes dark -- you're picking blind -- and the Wolf Man
## comes as it would anywhere (main.gd keeps it moving while the lock is up).
## Strike a match (E) right here to relight and carry on, or run (X). If it
## reaches you, main.gd calls interrupt(): the lock drops away and you see it take you.

var pfx := ""   ## input action prefix: "" for player 1, "p2_" for player 2

const PINS := {"bronze": 3, "silver": 4, "gold": 5, "purple": 6}
const SPEED := {"bronze": 2.4, "silver": 3.0, "gold": 3.6, "purple": 3.8}       # radians/sec at the start
## How close to the line counts (pin travel, 0..1 from the middle).
const TOLERANCE := {"bronze": 0.145, "silver": 0.125, "gold": 0.12, "purple": 0.115}

# --- Tuning: the stress ------------------------------------------------------------------
const PICK_DRAIN := 2.4          ## extra fuel per second while picking (on top of the normal burn)
const PICK_DRAIN_DEEP := 1.4     ## ...plus up to this much more at the deepest doors
const MISS_FUEL := 14.0          ## fuel a miss costs (a full lantern is 100)
const MISS_FUEL_DEEP := 6.0      ## ...plus up to this much more at the deepest doors
const DEPTH_SPEED := 0.6         ## pins at the deepest doors move this much faster (+60%)
const DEPTH_TOLERANCE := 0.15    ## ...and the window is this much narrower (-15%)
const ERRATIC := 0.5             ## past this depth the pins surge and stall instead of moving evenly
const LOW := 0.3                 ## below this much fuel the meter goes red and your heart pounds

const METAL := {"bronze": Color("c07a3a"), "silver": Color("c9cbd8"), "gold": Color("e8b84a"), "purple": Color("a060ff")}
const C_TEXT := Color("e8dfc8")
const C_DIM := Color("8a8299")
const C_CHANNEL := Color("0d0910")
const C_PIN := Color("b9bfd0")
const C_KEY_PIN := Color("d8a45a")
const C_SET := Color("7dff9a")
const C_LINE := Color("ffd35a")
const C_MISS := Color("ff4a5a")
const C_STEEL := Color("9aa3b5")
const CH_H := 60.0
const CH_W := 10.0
const LAYOUT := Vector2(240, 160)
const PANEL := Rect2(22, 6, 196, 118)

var player: Player
var lantern: Lantern
var _color := ""
var _depth := 0.0
var _pins: Array[Dictionary] = []   # {phase, speed, set, wob, wob_phase, wob_rate, drift}
var _current := 0
var _callback: Callable
var _t := 0.0
var _miss_flash := 0.0
var _set_flash := 0.0
var _shake := 0.0
var _done_t := -1.0
var _opened_frame := -1
var _canvas: Node2D
var _pick_x := 0.0               # where the pick's tip is (eases toward the current pin)
var _lost := 0.0                 # the bite a miss just took, shown on the meter
var _lost_at := 0.0              # ...starting from this fraction
var _lost_t := 0.0
var _beat := 0.0
var _sparks: Array = []          # {p, v, t, col}
## Set by doors.gd: is there light at the door besides your own lantern (a
## flare, your partner's lantern, a candle)? Enough to see the pins by.
var other_light: Callable
var _popups: Array = []          # {text, p, t, col}
## Set every frame by main.gd: how close the Wolf Man is (0 far or not coming .. 1 on you).
var danger := 0.0
var _blind_t := 0.0              # how long you've been picking in the dark


func setup(p: Player, l: Lantern) -> void:
	# Laid out for 240x160, centered on the (larger) screen; the lantern meter
	# and the darkness use the whole screen.
	offset = ((get_viewport().get_visible_rect().size - LAYOUT) / 2).floor()
	player = p
	lantern = l
	layer = 5
	visible = false
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_lock)
	add_child(_canvas)


## depth: how deep the door is, 0 (near the start) .. 1 (the bottom).
func start(color: String, on_done: Callable, depth: float = 0.0) -> void:
	_color = color
	_depth = clampf(depth, 0.0, 1.0)
	_callback = on_done
	_pins.clear()
	var base: float = SPEED[color] * (1.0 + DEPTH_SPEED * _depth)
	var wob := clampf((_depth - ERRATIC) / (1.0 - ERRATIC), 0.0, 1.0) * 0.3
	for i in PINS[color]:
		_pins.append({"phase": randf() * TAU, "speed": base * randf_range(0.85, 1.2), "set": false,
			"wob": wob * randf_range(0.6, 1.0), "wob_phase": randf() * TAU, "wob_rate": randf_range(1.3, 2.3), "drift": 0.0})
	_current = 0
	_t = 0.0
	_done_t = -1.0
	_miss_flash = 0.0
	_set_flash = 0.0
	_shake = 0.0
	_lost = 0.0
	_lost_t = 0.0
	_sparks.clear()
	_popups.clear()
	_blind_t = 0.0
	danger = 0.0
	visible = true
	player.ui_lock = "lock"
	_opened_frame = Engine.get_process_frames()
	_pick_x = _channel(0).get_center().x


func _end(success: bool) -> void:
	visible = false
	player.ui_lock = ""
	if _callback.is_valid():
		_callback.call(success)


## The Wolf Man has you: drop the lock (the key stays in your bag) so the
## screen shows what happens next.
func interrupt() -> void:
	if visible:
		_end(false)


## Picking in the dark: no light of your own and none nearby.
func _blind() -> bool:
	return not _can_see()


func _tolerance() -> float:
	return TOLERANCE[_color] * (1.0 - DEPTH_TOLERANCE * _depth)


## Does the lantern burn here? (Not by day, in a village, or under a sunstone.)
func _burning() -> bool:
	return lantern.state == Lantern.State.LIT and not lantern.daylight and not lantern.sheltered and lantern.sun_left <= 0.0


## Enough light to see the pins: your lantern, daylight, or some other light by the door.
func _can_see() -> bool:
	return lantern.state == Lantern.State.LIT or lantern.daylight or _borrowed()


## Picking by someone else's light (a flare, a partner's lantern): your own is out.
func _borrowed() -> bool:
	return lantern.state != Lantern.State.LIT and not lantern.daylight and other_light.is_valid() and other_light.call()


func pin_y(i: int) -> float:
	## 0 = top of the channel, 1 = bottom, 0.5 = on the line.
	var p := _pins[i]
	if p.set:
		return 0.5
	return 0.5 + 0.5 * sin(p.drift + p.phase)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_miss_flash = maxf(_miss_flash - delta, 0.0)
	_set_flash = maxf(_set_flash - delta, 0.0)
	_shake = maxf(_shake - delta, 0.0)
	_lost_t = maxf(_lost_t - delta, 0.0)
	for p in _pins:
		# deeper pins surge and stall: their speed swells and sags
		var surge: float = 1.0 + p.wob * sin(_t * p.wob_rate + p.wob_phase)
		p.drift += p.speed * surge * delta
	for s in _sparks:
		s.t += delta
		s.v.y += 120.0 * delta
		s.p += s.v * delta
	_sparks = _sparks.filter(func(s): return s.t < 0.5)
	for q in _popups:
		q.t += delta
	_popups = _popups.filter(func(q): return q.t < 1.0)
	if _done_t < 0.0 and _current < _pins.size():
		_pick_x = lerpf(_pick_x, _channel(_current).get_center().x, minf(delta * 14.0, 1.0))
	_canvas.queue_redraw()
	if _blind():
		# the light died and there's no other: you can't see the pins, and it's coming
		_blind_t += delta
		if Engine.get_process_frames() != _opened_frame and Input.is_action_just_pressed(pfx + "match"):
			lantern.strike()   # relight right here, and carry on
	else:
		_blind_t = 0.0
	# bent over the lock, the flame burns fast
	if _burning() and _done_t < 0.0:
		lantern.fuel = maxf(lantern.fuel - (PICK_DRAIN + PICK_DRAIN_DEEP * _depth) * delta, 0.0)
	# your heart, when the light's nearly gone
	if (_burning() and lantern.fraction() < LOW) or _blind():
		_beat -= delta
		if _beat <= 0.0:
			_beat = lerpf(0.45, 0.9, lantern.fraction() / LOW) if not _blind() else lerpf(0.5, 0.22, danger)
			Sfx.play("heartbeat", 0.0, 0.0)
	if _done_t >= 0.0:
		_done_t += delta
		if _done_t > 0.6:
			_end(true)
		return
	if Engine.get_process_frames() == _opened_frame:
		return
	if Input.is_action_just_pressed(pfx + "run"):
		_end(false)
	elif Input.is_action_just_pressed(pfx + "confirm"):
		if absf(pin_y(_current) - 0.5) <= _tolerance():
			_set_pin()
		else:
			_miss()


func _set_pin() -> void:
	Sfx.play("trap_click", 4.0, 0.1, 1.3 + _current * 0.05)
	_pins[_current].set = true
	var ch := _channel(_current)
	for i in 10:
		_sparks.append({"p": Vector2(ch.get_center().x, _line_y()), "v": Vector2(randf_range(-50, 50), randf_range(-70, -20)),
			"t": 0.0, "col": C_SET})
	_set_flash = 0.25
	_current += 1
	if _current >= _pins.size():
		_done_t = 0.0
		Sfx.play("door_open", -2.0)


func _miss() -> void:
	_miss_flash = 0.45
	_shake = 0.3
	Sfx.play("ui_deny")
	Sfx.play("lantern_out", -8.0, 0.1, 1.4)
	var ch := _channel(_current)
	for i in 14:
		_sparks.append({"p": Vector2(_pick_x, ch.end.y), "v": Vector2(randf_range(-80, 80), randf_range(-90, -10)),
			"t": 0.0, "col": Color("ffb040")})
	if _burning():
		var bite := MISS_FUEL + MISS_FUEL_DEEP * _depth
		_lost_at = lantern.fraction()
		lantern.fuel = maxf(lantern.fuel - bite, 0.0)
		_lost = _lost_at - lantern.fraction()
		_lost_t = 0.8
		var m := _meter_rect()
		_popups.append({"text": "-" + str(int(round(bite))) + " LIGHT", "p": m.position + Vector2(m.size.x * _lost_at, -16), "t": 0.0, "col": C_MISS})
	if _color == "gold" or _color == "purple":
		for p in _pins:
			p.set = false
		_current = 0
	elif _color == "silver" and _current > 0:
		_current -= 1
		_pins[_current].set = false


# --- Layout ------------------------------------------------------------------------------

func _body() -> Rect2:
	var n := _pins.size()
	var spacing := 22.0
	var w := n * spacing + 22
	return Rect2(floorf(PANEL.get_center().x - w / 2), PANEL.position.y + 18, w, CH_H + 22)


func _channel(i: int) -> Rect2:
	var b := _body()
	return Rect2(b.position.x + 13 + i * 22.0, b.position.y + 8, CH_W, CH_H)


func _line_y() -> float:
	return _body().position.y + 8 + CH_H * 0.5


## The lantern meter, along the bottom of the whole screen (in layout coordinates).
func _meter_rect() -> Rect2:
	var full := _canvas.get_viewport_rect().size if _canvas != null else LAYOUT
	return Rect2(-offset.x + 44, -offset.y + full.y - 16, full.x - 64, 7)


# --- Drawing -----------------------------------------------------------------------------

func _draw_lock() -> void:
	var full := _canvas.get_viewport_rect().size
	var shake := Vector2(randf_range(-2, 2), randf_range(-1, 1)) * (_shake / 0.3) if _shake > 0.0 else Vector2.ZERO
	var frac := lantern.fraction()
	# how well you can see: your fuel -- or, picking by a flare's light, fairly well
	var seen := maxf(frac, 0.8) if _borrowed() else frac
	# the room goes dark around you; the darker, the less fuel is left
	_canvas.draw_rect(Rect2(-offset, full), Color(0.01, 0.0, 0.03, 0.72 + 0.2 * (1.0 - seen)))
	# your lantern's glow on the lock, flickering, shrinking as it burns down
	var glow_c := PANEL.get_center() + Vector2(0, 8)
	var flick := 1.0 + sin(_t * 23.0) * 0.04 + sin(_t * 7.0) * 0.05 * (1.0 - seen)
	for k in 5:
		_canvas.draw_circle(glow_c, (60.0 + 90.0 * seen) * flick * (1.0 - k * 0.16), Color(1.0, 0.65, 0.3, 0.035))
	_canvas.draw_set_transform(shake)
	Dialog.draw_panel(_canvas, PANEL)
	var title := "THE MASTER SEAL" if _color == "purple" else _color.to_upper() + " LOCK"
	PixelFont.draw(_canvas, Vector2(PANEL.position.x + (PANEL.size.x - PixelFont.width_of(title)) / 2, PANEL.position.y + 6),
		title, METAL[_color])
	var set_count := 0
	for p in _pins:
		if p.set:
			set_count += 1
	var count := str(set_count) + "/" + str(_pins.size())
	PixelFont.draw(_canvas, Vector2(PANEL.end.x - 8 - PixelFont.width_of(count), PANEL.position.y + 6), count, C_SET if set_count > 0 else C_DIM)
	if _depth >= 0.15:
		var tag := "DEPTH " + str(int(round(_depth * 100))) + "%"
		PixelFont.draw(_canvas, PANEL.position + Vector2(8, 6), tag, C_MISS.lerp(C_DIM, 1.0 - _depth))
	_draw_body()
	_draw_tools()
	for s in _sparks:
		var a: float = 1.0 - s.t / 0.5
		_canvas.draw_rect(Rect2((s.p as Vector2).round(), Vector2(1, 1)), Color(s.col, a))
	var blind := _blind() and _done_t < 0.0
	if blind:
		# the dark swallows the lock: only the faintest shape of it, and the pick in your hand
		_canvas.draw_rect(PANEL.grow(2), Color(0.01, 0.0, 0.02, 0.94))
		var t2 := "THE LIGHT IS OUT"
		PixelFont.draw(_canvas, Vector2(PANEL.position.x + (PANEL.size.x - PixelFont.width_of(t2)) / 2, PANEL.position.y + 30), t2,
			Color(C_MISS, 0.7 + 0.3 * sin(_t * 6.0)))
		var t3 := "YOU CAN'T SEE THE PINS"
		PixelFont.draw(_canvas, Vector2(PANEL.position.x + (PANEL.size.x - PixelFont.width_of(t3)) / 2, PANEL.position.y + 44), t3, C_DIM)
	var msg := "CLICK!" if _done_t >= 0.0 else ("MISSED!" if _miss_flash > 0.0 else ("E STRIKE A MATCH   X RUN" if blind else "Z SET PIN   X GIVE UP"))
	var col := C_SET if _done_t >= 0.0 else (C_MISS if _miss_flash > 0.0 else (C_TEXT if blind else C_DIM))
	PixelFont.draw(_canvas, Vector2(PANEL.position.x + (PANEL.size.x - PixelFont.width_of(msg)) / 2, PANEL.end.y - 11), msg, col)
	_canvas.draw_set_transform(Vector2.ZERO)
	if blind and danger > 0.0:
		# it's close: the dark pulses red with your heartbeat
		var beat := 0.5 + 0.5 * sin(_t * lerpf(8.0, 22.0, danger))
		_canvas.draw_rect(Rect2(-offset, full), Color(0.5, 0.0, 0.06, danger * 0.28 * beat))
	if _miss_flash > 0.0:
		_canvas.draw_rect(Rect2(-offset, full), Color(0.6, 0.0, 0.08, _miss_flash * 0.5))
	_draw_vignette(full, seen)
	_draw_meter(frac)


func _draw_body() -> void:
	var metal: Color = METAL[_color]
	var b := _body()
	# the plate: dark rim, metal face, a lit top edge, an engraved border, rivets
	_canvas.draw_rect(b.grow(1), Color("07050b"))
	_canvas.draw_rect(b, metal.darkened(0.55))
	_canvas.draw_rect(b.grow(-1), metal.darkened(0.25))
	for i in 4:   # brushed face: faint horizontal streaks
		_canvas.draw_rect(Rect2(b.position.x + 2, b.position.y + 6 + i * 19, b.size.x - 4, 1), Color(metal.lightened(0.2), 0.25))
	_canvas.draw_rect(Rect2(b.position + Vector2(1, 1), Vector2(b.size.x - 2, 1)), metal.lightened(0.35))
	_canvas.draw_rect(Rect2(b.position + Vector2(3, 3), b.size - Vector2(6, 6)), metal.darkened(0.45), false)
	for p in [b.position + Vector2(4, 4), Vector2(b.end.x - 6, b.position.y + 4), Vector2(b.position.x + 4, b.end.y - 6), b.end - Vector2(6, 6)]:
		_canvas.draw_rect(Rect2(p, Vector2(2, 2)), metal.darkened(0.6))
		_canvas.draw_rect(Rect2(p, Vector2(1, 1)), metal.lightened(0.5))
	# the shear line, with the window you have to hit as a faint band
	var line_y := _line_y()
	var band := _tolerance() * (CH_H - 24)
	var pulse := 0.55 + 0.45 * sin(_t * 6.0)
	_canvas.draw_rect(Rect2(b.position.x + 6, line_y - band, b.size.x - 12, band * 2), Color(C_LINE, 0.08))
	for i in _pins.size():
		_draw_channel(i)
	_canvas.draw_rect(Rect2(b.position.x + 4, line_y, b.size.x - 8, 1), Color(C_LINE, 0.6 + 0.4 * pulse))
	# the keyhole
	var kh := Vector2(b.get_center().x, b.end.y - 8)
	_canvas.draw_circle(kh, 2.5, Color("07050b"))
	_canvas.draw_rect(Rect2(kh.x - 1, kh.y, 3, 4), Color("07050b"))


## Where the pin's middle (the join between its two halves) sits, so that
## "on the line" means the join is on the shear line.
func _pin_join(i: int) -> float:
	var ch := _channel(i)
	return ch.position.y + 12 + pin_y(i) * (CH_H - 24)


func _draw_channel(i: int) -> void:
	var ch := _channel(i)
	var p := _pins[i]
	var current := i == _current and _done_t < 0.0
	_canvas.draw_rect(ch.grow(1), Color("05030a"))
	_canvas.draw_rect(ch, C_CHANNEL)
	_canvas.draw_rect(Rect2(ch.position, Vector2(1, ch.size.y)), Color(1, 1, 1, 0.05))
	if current:
		_canvas.draw_rect(ch.grow(2), Color(C_TEXT, 0.6 + 0.4 * sin(_t * 8.0)), false)
		if _miss_flash > 0.0:
			_canvas.draw_rect(ch, Color(C_MISS, _miss_flash * 1.6))
	if p.set and _set_flash > 0.0 and i == _current - 1:
		_canvas.draw_rect(ch.grow(1), Color(C_SET, _set_flash * 2.0))
	var join := _pin_join(i)
	var pin_top := join - 8
	# the spring, squeezed when the pin rides up
	var spring_h := pin_top - ch.position.y - 1
	var coils := 5
	for k in coils * 2:
		var y0 := ch.position.y + 1 + spring_h * k / (coils * 2)
		var y1 := ch.position.y + 1 + spring_h * (k + 1) / (coils * 2)
		var x0: float = ch.position.x + (2.0 if k % 2 == 0 else CH_W - 3.0)
		var x1: float = ch.position.x + (CH_W - 3.0 if k % 2 == 0 else 2.0)
		_canvas.draw_line(Vector2(x0, y0).round(), Vector2(x1, y1).round(), Color(C_STEEL.darkened(0.35), 0.9), 1.0)
	# driver pin (steel) on top of the key pin (brass); the join between them
	# is what has to meet the shear line
	var lit := 1.0 if (current or p.set) else 0.55
	var driver := Rect2(ch.position.x + 2, pin_top, CH_W - 4, 8)
	var key := Rect2(ch.position.x + 2, join, CH_W - 4, 10)
	var dcol := C_SET if p.set else C_PIN
	_canvas.draw_rect(driver, dcol.darkened(1.0 - lit))
	_canvas.draw_rect(Rect2(driver.position, Vector2(driver.size.x, 1)), dcol.lightened(0.4).darkened(1.0 - lit))
	_canvas.draw_rect(key, C_KEY_PIN.darkened(1.0 - lit))
	_canvas.draw_rect(Rect2(key.position.x, key.end.y - 2, key.size.x, 2), C_KEY_PIN.darkened(0.4 + 0.4 * (1.0 - lit)))
	_canvas.draw_rect(Rect2(key.position.x + 1, key.end.y, key.size.x - 2, 1), C_KEY_PIN.darkened(0.5))   # its pointed tip


func _draw_tools() -> void:
	var b := _body()
	var kh := Vector2(b.get_center().x, b.end.y - 8)
	# the tension wrench, an L of steel in the bottom of the keyhole, its arm off to the left
	_canvas.draw_rect(Rect2(kh.x - 14, kh.y + 3, 14, 2), C_STEEL.darkened(0.2))
	_canvas.draw_rect(Rect2(kh.x - 14, kh.y - 1, 2, 4), C_STEEL.darkened(0.2))
	if _done_t >= 0.0 or _current >= _pins.size():
		return
	# the pick: in through the keyhole, its hooked tip under the current pin
	var ch := _channel(_current)
	var tip := Vector2(_pick_x, ch.end.y + 3)
	var handle := Vector2(b.end.x + 10, b.end.y - 6)
	var jitter := Vector2(0, roundf(sin(_t * 31.0) * 0.6)) if lantern.fraction() < LOW else Vector2.ZERO   # your hand shakes
	_canvas.draw_line((kh + Vector2(0, 2)).round(), (handle + jitter).round(), C_STEEL, 2.0)
	_canvas.draw_line((kh + Vector2(0, 2)).round(), (tip + jitter).round(), C_STEEL.lightened(0.2), 1.0)
	_canvas.draw_rect(Rect2((tip + jitter).round() + Vector2(0, -3), Vector2(1, 3)), C_STEEL.lightened(0.4))
	_canvas.draw_rect(Rect2((handle + jitter).round() - Vector2(2, 2), Vector2(14, 5)), Color("3a2a20"))
	_canvas.draw_rect(Rect2((handle + jitter).round() - Vector2(2, 2), Vector2(14, 1)), Color("5a4232"))


## The edges close in as the light runs out.
func _draw_vignette(full: Vector2, frac: float) -> void:
	var dark := clampf((0.5 - frac) / 0.5, 0.0, 1.0)
	if dark <= 0.0:
		return
	var rings := 10
	for i in rings:
		var w := (8.0 + 30.0 * dark) * (rings - i) / rings
		var a := 0.12 * dark
		_canvas.draw_rect(Rect2(-offset.x, -offset.y, full.x, w), Color(0, 0, 0, a))
		_canvas.draw_rect(Rect2(-offset.x, -offset.y + full.y - w, full.x, w), Color(0, 0, 0, a))
		_canvas.draw_rect(Rect2(-offset.x, -offset.y, w, full.y), Color(0, 0, 0, a))
		_canvas.draw_rect(Rect2(-offset.x + full.x - w, -offset.y, w, full.y), Color(0, 0, 0, a))


## The lantern meter: big, along the bottom of the screen, impossible to miss.
func _draw_meter(frac: float) -> void:
	var r := _meter_rect()
	var low := frac < LOW
	var pulse := 0.5 + 0.5 * sin(_t * (10.0 if low else 3.0))
	# the flame at its left end, shrinking and guttering with the fuel
	var fc := Vector2(r.position.x - 14, r.get_center().y)
	var fh := 3.0 + 5.0 * frac + sin(_t * 17.0) * (0.5 + 1.5 * (1.0 - frac))
	_canvas.draw_rect(Rect2(fc.x - 4, fc.y + 1, 9, 4), Color("3a2a20"))   # the lantern's base
	_canvas.draw_rect(Rect2(fc.x - 3, fc.y - 7, 7, 8), Color("5a4232"), false)
	if frac > 0.0:
		_canvas.draw_rect(Rect2(fc.x - 1, fc.y - fh + 1, 3, fh), Color("ff9a3a"))
		_canvas.draw_rect(Rect2(fc.x, fc.y - fh * 0.6 + 1, 1, fh * 0.6), Color("fff0b0"))
	PixelFont.draw(_canvas, Vector2(r.position.x, r.position.y - 8), "LANTERN", C_MISS if low else C_TEXT)
	var pct := str(int(round(frac * 100))) + "%"
	PixelFont.draw(_canvas, Vector2(r.end.x - PixelFont.width_of(pct), r.position.y - 8), pct, C_MISS if low else C_LINE)
	if _burning() or _borrowed():
		var rate := "BURNING FAST" if _burning() else "BY ANOTHER LIGHT"
		PixelFont.draw(_canvas, Vector2(roundf(r.get_center().x - PixelFont.width_of(rate) / 2.0), r.position.y - 8), rate,
			Color(C_MISS if low else C_DIM, 0.5 + 0.5 * pulse))
	# the bar itself, with notches every tenth
	_canvas.draw_rect(r.grow(2), Color("05030a"))
	_canvas.draw_rect(r.grow(1), Color("3a3448"))
	_canvas.draw_rect(r, Color("140f1c"))
	var fill := Color("ffd35a").lerp(Color("ff7a2a"), clampf((0.6 - frac) / 0.4, 0.0, 1.0))
	if low:
		fill = C_MISS.lerp(Color("ff9a9a"), pulse * 0.6)
	var w := roundf(r.size.x * frac)
	_canvas.draw_rect(Rect2(r.position, Vector2(w, r.size.y)), fill)
	_canvas.draw_rect(Rect2(r.position, Vector2(w, 2)), fill.lightened(0.35))
	_canvas.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(w, 1)), fill.darkened(0.3))
	# the bite a miss just took: a red stretch that drains away
	if _lost_t > 0.0 and _lost > 0.0:
		var a := _lost_t / 0.8
		_canvas.draw_rect(Rect2(r.position.x + w, r.position.y, roundf(r.size.x * _lost * a), r.size.y), Color(C_MISS, 0.9))
	for k in range(1, 10):
		var x := r.position.x + roundf(r.size.x * k / 10.0)
		_canvas.draw_rect(Rect2(x, r.position.y, 1, r.size.y), Color(0, 0, 0, 0.35))
	for q in _popups:
		var a2: float = 1.0 - q.t
		var p: Vector2 = q.p + Vector2(0, -q.t * 14.0)
		PixelFont.draw(_canvas, (p - Vector2(PixelFont.width_of(q.text) / 2.0, 0)).round(), q.text, Color(q.col, a2), Color(0, 0, 0, a2))
