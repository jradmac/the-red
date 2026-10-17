class_name TitleScreen
extends CanvasLayer
## Shown at start-up when there's a saved run: CONTINUE or NEW GAME.
## Starting a new game asks first, since it erases the save.

signal chosen(choice: String)   ## "continue" or "new"

const C_TEXT := Color("e8dfc8")
const C_DIM := Color("8a8299")
const C_PICK := Color("ffd35a")
const C_BAD := Color("ff6a6a")

var _summary := ""
var _sel := 0
var _confirm := false
var _time := 0.0
var _canvas: Node2D
var _ready_frame := -1


func setup(summary: String) -> void:
	_summary = summary
	layer = 30
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_title)
	add_child(_canvas)
	_ready_frame = Engine.get_process_frames()


func _process(delta: float) -> void:
	_time += delta
	_canvas.queue_redraw()
	if Engine.get_process_frames() <= _ready_frame + 1:
		return
	if _confirm:
		if Input.is_action_just_pressed("confirm"):
			chosen.emit("new")
		elif Input.is_action_just_pressed("run"):
			_confirm = false
		return
	if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("move_down"):
		_sel = 1 - _sel
	elif Input.is_action_just_pressed("confirm"):
		if _sel == 0:
			chosen.emit("continue")
		else:
			_confirm = true


func _draw_title() -> void:
	var size := _canvas.get_viewport_rect().size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color("040208"))
	var cx := floorf(size.x / 2)
	# a little flame, breathing
	var fy := 62.0 + roundf(sin(_time * 2.0) * 2.0)
	_canvas.draw_circle(Vector2(cx, fy), 26.0 + sin(_time * 3.0), Color(1.0, 0.7, 0.35, 0.06))
	_canvas.draw_circle(Vector2(cx, fy), 14.0, Color(1.0, 0.75, 0.4, 0.1))
	Companion.draw_portrait(_canvas, Vector2(cx - 18, fy - 21), 3.0, _time, false)
	var title := "THE LABYRINTH"
	PixelFont.draw(_canvas, Vector2(floorf(cx - PixelFont.width_of(title) / 2.0), 100), title, C_PICK)
	if _confirm:
		var l1 := "START OVER? YOUR SAVED GAME WILL BE LOST."
		var l2 := "Z  YES, START OVER        X  NO"
		PixelFont.draw(_canvas, Vector2(floorf(cx - PixelFont.width_of(l1) / 2.0), 140), l1, C_BAD)
		PixelFont.draw(_canvas, Vector2(floorf(cx - PixelFont.width_of(l2) / 2.0), 160), l2, C_DIM)
		return
	var opts := ["CONTINUE", "NEW GAME"]
	for i in 2:
		var y := 136.0 + i * 26.0
		var col := C_PICK if i == _sel else C_TEXT
		var text: String = opts[i]
		if i == _sel:
			text = "> " + text + " <"
		PixelFont.draw(_canvas, Vector2(floorf(cx - PixelFont.width_of(text) / 2.0), y), text, col)
		if i == 0:
			PixelFont.draw(_canvas, Vector2(floorf(cx - PixelFont.width_of(_summary) / 2.0), y + 10), _summary, C_DIM)
	var help := "ARROWS CHOOSE   Z CONFIRM"
	PixelFont.draw(_canvas, Vector2(floorf(cx - PixelFont.width_of(help) / 2.0), size.y - 14), help, Color(C_DIM, 0.7))
