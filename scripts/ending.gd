class_name Ending
extends CanvasLayer
## The victory sequence: a flash of purple light as the seal breaks, then the
## run's stats. R (gamepad Start) starts a new labyrinth.

const C_TEXT := Color("e8dfc8")
const C_DIM := Color("8a8299")
const C_PURPLE := Color("c08aff")

var stats: RunStats
var _t := -1.0
var _canvas: Node2D


func setup(s: RunStats) -> void:
	stats = s
	layer = 9
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_end)
	add_child(_canvas)


func play() -> void:
	_t = 0.0
	stats.running = false


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	_canvas.queue_redraw()


func _centered(y: float, text: String, col: Color) -> void:
	var w := _canvas.get_viewport_rect().size.x
	PixelFont.draw(_canvas, Vector2(floorf((w - PixelFont.width_of(text)) / 2), y), text, col)


func _draw_end() -> void:
	if _t < 0.0:
		return
	var screen := _canvas.get_viewport_rect().size
	# 0-0.6s: blinding purple-white flash. Then fade to deep purple-black.
	var flash := clampf(1.0 - absf(_t - 0.35) / 0.35, 0.0, 1.0)
	var dark := clampf((_t - 0.4) / 1.2, 0.0, 1.0)
	_canvas.draw_rect(Rect2(Vector2.ZERO, screen), Color(0.04, 0.01, 0.08, dark))
	if flash > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, screen), Color(0.9, 0.8, 1.0, flash))
	if _t < 1.6:
		return
	var a := clampf((_t - 1.6) / 1.0, 0.0, 1.0)
	_centered(30, "THE MASTER SEAL SHATTERS", Color(C_PURPLE, a))
	_centered(44, "YOU ESCAPED THE LABYRINTH", Color(C_TEXT, a))
	if _t < 2.8:
		return
	var b := clampf((_t - 2.8) / 1.0, 0.0, 1.0)
	var y := 70.0
	for line in stats.lines():
		_centered(y, line, Color(C_DIM, b))
		y += 10
	if _t > 4.0 and fmod(_t, 1.0) < 0.7:
		_centered(screen.y - 18, "PRESS R FOR A NEW LABYRINTH", C_TEXT)
