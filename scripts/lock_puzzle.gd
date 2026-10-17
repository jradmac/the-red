class_name LockPuzzle
extends CanvasLayer
## Lockpicking: pins bounce up and down in their channels. Press A (Z) when
## the highlighted pin crosses the gold line to set it, one pin at a time.
##   bronze: 3 pins, slow    silver: 4 pins    gold: 5 pins, fast
## A miss costs lantern fuel; on gold it also knocks every pin back down.
## B (X) gives up and keeps your key. Your lantern burns the whole time, and
## if it goes out you're kicked out of the lock.

var pfx := ""   ## input action prefix: "" for player 1, "p2_" for player 2

const PINS := {"bronze": 3, "silver": 4, "gold": 5, "purple": 6}
const SPEED := {"bronze": 2.4, "silver": 3.0, "gold": 3.6, "purple": 3.8}       # radians/sec
## How close to the line counts. Roughly a 200 / 140 / 110 / 100 ms window.
const TOLERANCE := {"bronze": 0.145, "silver": 0.125, "gold": 0.12, "purple": 0.115}
const MISS_FUEL := 4.0
const METAL := {"bronze": Color("c07a3a"), "silver": Color("c9cbd8"), "gold": Color("e8b84a"), "purple": Color("a060ff")}
const C_TEXT := Color("e8dfc8")
const C_DIM := Color("8a8299")
const C_CHANNEL := Color("0d0910")
const C_PIN := Color("b9bfd0")
const C_SET := Color("7dff9a")
const C_LINE := Color("ffd35a")
const C_MISS := Color("ff4a5a")
const CH_H := 52.0

var player: Player
var lantern: Lantern
var _color := ""
var _pins: Array[Dictionary] = []   # {phase, speed, set}
var _current := 0
var _callback: Callable
var _t := 0.0
var _miss_flash := 0.0
var _done_t := -1.0
var _opened_frame := -1
var _canvas: Node2D


func setup(p: Player, l: Lantern) -> void:
	# Laid out for 240x160, centered on the (larger) screen.
	offset = ((get_viewport().get_visible_rect().size - Vector2(240, 160)) / 2).floor()
	player = p
	lantern = l
	layer = 5
	visible = false
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_lock)
	add_child(_canvas)


func start(color: String, on_done: Callable) -> void:
	_color = color
	_callback = on_done
	_pins.clear()
	for i in PINS[color]:
		_pins.append({"phase": randf() * TAU, "speed": SPEED[color] * randf_range(0.85, 1.2), "set": false})
	_current = 0
	_t = 0.0
	_done_t = -1.0
	_miss_flash = 0.0
	visible = true
	player.ui_lock = "lock"
	_opened_frame = Engine.get_process_frames()


func _end(success: bool) -> void:
	visible = false
	player.ui_lock = ""
	if _callback.is_valid():
		_callback.call(success)


func pin_y(i: int) -> float:
	## 0 = top of the channel, 1 = bottom, 0.5 = on the line.
	var p := _pins[i]
	if p.set:
		return 0.5
	return 0.5 + 0.5 * sin(_t * p.speed + p.phase)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_miss_flash = maxf(_miss_flash - delta, 0.0)
	_canvas.queue_redraw()
	if lantern.state != Lantern.State.LIT and not lantern.daylight:
		_end(false)   # the light died -- go strike a match!
		return
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
		if absf(pin_y(_current) - 0.5) <= TOLERANCE[_color]:
			Sfx.play("trap_click", 4.0, 0.1, 1.3)
			_pins[_current].set = true
			_current += 1
			if _current >= _pins.size():
				_done_t = 0.0
		else:
			_miss_flash = 0.35
			Sfx.play("ui_deny")
			lantern.fuel = maxf(lantern.fuel - MISS_FUEL, 0.0)
			if _color == "gold" or _color == "purple":
				for p in _pins:
					p.set = false
				_current = 0


func _draw_lock() -> void:
	var full := _canvas.get_viewport_rect().size
	var screen := Vector2(240, 160)
	_canvas.draw_rect(Rect2(-offset, full), Color(0.01, 0.0, 0.03, 0.75))
	var panel := Rect2(36, 18, 168, 120)
	Dialog.draw_panel(_canvas, panel)
	var title := "THE MASTER SEAL" if _color == "purple" else _color.to_upper() + " LOCK"
	PixelFont.draw(_canvas, Vector2(panel.position.x + (panel.size.x - PixelFont.width_of(title)) / 2, panel.position.y + 6),
		title, METAL[_color])

	# Lock body
	var n := _pins.size()
	var spacing := 18.0
	var body_w := n * spacing + 10
	var body := Rect2(panel.get_center().x - body_w / 2, panel.position.y + 18, body_w, CH_H + 12)
	_canvas.draw_rect(body, METAL[_color].darkened(0.45))
	_canvas.draw_rect(body.grow(-1), METAL[_color].darkened(0.2))
	var line_y := body.position.y + 6 + CH_H * 0.5
	for i in n:
		var ch := Rect2(body.position.x + 8 + i * spacing, body.position.y + 6, 8, CH_H)
		_canvas.draw_rect(ch, C_CHANNEL)
		if i == _current and _done_t < 0.0:
			_canvas.draw_rect(ch.grow(1), C_TEXT, false)
			if _miss_flash > 0.0:
				_canvas.draw_rect(ch, Color(C_MISS, _miss_flash * 2.0))
		var y := ch.position.y + pin_y(i) * (CH_H - 10)
		var col := C_SET if _pins[i].set else (C_PIN if i == _current else C_PIN.darkened(0.4))
		_canvas.draw_rect(Rect2(ch.position.x + 1, y, 6, 10), col)
		_canvas.draw_rect(Rect2(ch.position.x + 1, y, 6, 1), col.lightened(0.4))
	# The shear line
	_canvas.draw_rect(Rect2(body.position.x + 3, line_y, body.size.x - 6, 1), C_LINE)

	# Fuel left (the lantern keeps burning in here)
	var bar := Rect2(panel.position.x + 16, panel.end.y - 26, panel.size.x - 32, 3)
	_canvas.draw_rect(bar, C_CHANNEL)
	_canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * lantern.fraction(), 3)),
		C_LINE if lantern.fraction() > 0.2 else C_MISS)

	var msg := "CLICK!" if _done_t >= 0.0 else ("MISSED!" if _miss_flash > 0.0 else "Z SET PIN   X GIVE UP")
	var col := C_SET if _done_t >= 0.0 else (C_MISS if _miss_flash > 0.0 else C_DIM)
	PixelFont.draw(_canvas, Vector2(panel.position.x + (panel.size.x - PixelFont.width_of(msg)) / 2, panel.end.y - 16), msg, col)
