class_name Dialog
extends CanvasLayer
## Pokemon-style text box at the bottom of the screen, with optional item
## icon, typewriter text, and multiple-choice prompts.
##
##   dialog.say("FOUND A HATCHET!", "hatchet")
##   dialog.ask("SWAP?", ["YES", "NO"], func(choice): ...)
##
## A (Z / Enter) advances or picks, B (X / Shift) cancels a prompt.
## While anything is showing, the hero can't move.

var pfx := ""   ## input action prefix: "" for player 1, "p2_" for player 2

const C_BOX := Color("14101e")
const C_BORDER := Color("e8dfc8")
const C_BORDER_DK := Color("5a5170")
const C_TEXT := Color("e8dfc8")
const C_PICK := Color("ffd35a")
const BOX := Rect2(4, 116, 232, 40)
const CHARS_PER_SEC := 45.0
const LINE_H := 8
const TEXT_W := 200

var player: Player
var _queue: Array[Dictionary] = []   # {text, icon, options, callback}
var _current: Dictionary = {}
var _shown := 0.0
var _choice := 0
var _opened_frame := -1
var _canvas: Node2D
var _time := 0.0
var _back_to := ""


func setup(p: Player) -> void:
	player = p
	# The box is laid out for 240x160; keep it bottom-center on bigger screens.
	var size := get_viewport().get_visible_rect().size
	offset = Vector2(floorf((size.x - 240) / 2), size.y - 160)
	layer = 6
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_box)
	add_child(_canvas)


func is_open() -> bool:
	return not _current.is_empty()


func say(text: String, icon: String = "") -> void:
	_push({"text": text, "icon": icon, "options": [], "callback": Callable()})


func ask(text: String, options: Array, callback: Callable, icon: String = "") -> void:
	_push({"text": text, "icon": icon, "options": options, "callback": callback})


func _push(entry: Dictionary) -> void:
	_queue.append(entry)
	if _current.is_empty():
		_next()


func _next() -> void:
	if _queue.is_empty():
		_current = {}
		if player.ui_lock == "dialog":
			player.ui_lock = _back_to
		_back_to = ""
		return
	_current = _queue.pop_front()
	_shown = 0.0
	_choice = 0
	_opened_frame = Engine.get_process_frames()
	if player.ui_lock == "interior":
		_back_to = "interior"   # talking inside a building: back to walking about in there
	player.ui_lock = "dialog"


func _process(delta: float) -> void:
	_time += delta
	if _current.is_empty():
		_canvas.visible = false
		return
	_canvas.visible = true
	var full: int = _current.text.length()
	var before := int(_shown)
	_shown = minf(_shown + delta * CHARS_PER_SEC, full)
	if int(_shown) != before and int(_shown) % 2 == 0 and int(_shown) < full:
		Sfx.play("type", 0.0, 0.08)
	_canvas.queue_redraw()
	if Engine.get_process_frames() == _opened_frame:
		return  # ignore the key press that opened this box
	var options: Array = _current.options
	var typing := _shown < full
	if Input.is_action_just_pressed(pfx + "confirm"):
		if typing:
			_shown = full
		elif options.is_empty():
			_next()
		else:
			_pick(_choice)
	elif not typing and not options.is_empty():
		if Input.is_action_just_pressed(pfx + "move_up"):
			_choice = posmod(_choice - 1, options.size())
		elif Input.is_action_just_pressed(pfx + "move_down"):
			_choice = posmod(_choice + 1, options.size())
		elif Input.is_action_just_pressed(pfx + "run"):
			_pick(options.size() - 1)  # B = last option (cancel / leave it)


func _pick(index: int) -> void:
	var cb: Callable = _current.callback
	_next()
	if cb.is_valid():
		cb.call(index)


static func wrap_text(text: String, max_w: int) -> Array[String]:
	var lines: Array[String] = []
	var line := ""
	for word in text.split(" "):
		var test := word if line == "" else line + " " + word
		if PixelFont.width_of(test) > max_w and line != "":
			lines.append(line)
			line = word
		else:
			line = test
	if line != "":
		lines.append(line)
	return lines


static func draw_panel(canvas: CanvasItem, r: Rect2) -> void:
	canvas.draw_rect(r, C_BORDER_DK)
	canvas.draw_rect(r.grow(-1), C_BORDER)
	canvas.draw_rect(r.grow(-2), C_BOX)


func _draw_box() -> void:
	if _current.is_empty():
		return
	draw_panel(_canvas, BOX)
	var x := BOX.position.x + 8
	if String(_current.icon).begins_with("npc:"):
		# someone in a village: their little portrait
		Villages.draw_portrait(_canvas, int(String(_current.icon).substr(4)), BOX.position + Vector2(6, 8), 1.0, _time)
		x += 20
	elif _current.icon != "":
		Items.draw_icon(_canvas, _current.icon, Rect2(BOX.position + Vector2(7, 12), Vector2(16, 16)))
		x += 20
	var visible_text: String = _current.text.substr(0, int(_shown))
	var lines := wrap_text(_current.text, TEXT_W - (20 if _current.icon != "" else 0))
	var y := BOX.position.y + 8
	var used := 0
	for line in lines:
		var part := visible_text.substr(used, line.length())
		PixelFont.draw(_canvas, Vector2(x, y), part, C_TEXT)
		used += line.length() + 1
		y += LINE_H
	var options: Array = _current.options
	var done: bool = int(_shown) >= _current.text.length()
	if done and options.is_empty() and fmod(_time, 0.8) < 0.5:
		# little "more" arrow
		var a := BOX.end - Vector2(12, 9)
		_canvas.draw_rect(Rect2(a, Vector2(5, 1)), C_TEXT)
		_canvas.draw_rect(Rect2(a + Vector2(1, 1), Vector2(3, 1)), C_TEXT)
		_canvas.draw_rect(Rect2(a + Vector2(2, 2), Vector2(1, 1)), C_TEXT)
	if done and not options.is_empty():
		var w := 0
		for o in options:
			w = maxi(w, PixelFont.width_of(o))
		var h := options.size() * LINE_H + 10
		var r := Rect2(BOX.end.x - w - 22, BOX.position.y - h - 2, w + 22, h)
		draw_panel(_canvas, r)
		for i in options.size():
			var oy := r.position.y + 6 + i * LINE_H
			var col := C_PICK if i == _choice else C_TEXT
			if i == _choice:
				PixelFont.draw(_canvas, Vector2(r.position.x + 6, oy), ">", C_PICK)
			PixelFont.draw(_canvas, Vector2(r.position.x + 12, oy), options[i], col)
