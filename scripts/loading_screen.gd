class_name LoadingScreen
extends CanvasLayer
## The screen while a labyrinth is built (a new game or a saved one): a little
## lantern in the dark with motes of light circling it -- so you can see it's
## working -- what's being done, and a bar filling up. It runs on real time
## and keeps going while the game is paused for the build; between the long
## steps main.gd and WorldMesh hand it a frame so it can move.

const C_BG := Color("040208")
const C_TEXT := Color("8a8299")
const C_DIM := Color("4a4260")
const C_FLAME := Color("ffb040")
const C_HOT := Color("fff0b0")
const C_BRASS := Color("b8904a")

var stage := "DESCENDING INTO THE LABYRINTH"
var frac := 0.0              ## 0..1, how far along
var _shown := 0.0            ## the bar, easing toward frac
var _canvas: Node2D
var _glow: Texture2D


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	_glow = gt
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_it)
	add_child(_canvas)


func _process(delta: float) -> void:
	_shown = move_toward(_shown, frac, delta * 1.5)
	_canvas.queue_redraw()


func _draw_it() -> void:
	var size := _canvas.get_viewport_rect().size
	var t := Time.get_ticks_msec() / 1000.0
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), C_BG)
	var c := (size / 2.0 + Vector2(0, -18)).round()
	# the lantern's glow
	var breathe := 0.9 + 0.1 * sin(t * 2.3)
	_canvas.draw_texture_rect(_glow, Rect2(c - Vector2(34, 34) * breathe, Vector2(68, 68) * breathe), false, Color(1.0, 0.6, 0.2, 0.22))
	# motes of light circling it: a bright one leading, the rest trailing off
	for k in 10:
		var ang := t * 3.2 - k * 0.32
		var p := (c + Vector2(cos(ang), sin(ang) * 0.85) * 17.0).round()
		var a := 1.0 - k / 10.0
		var s := 2.0 if k == 0 else 1.0
		_canvas.draw_rect(Rect2(p - Vector2(s / 2.0, s / 2.0).floor(), Vector2(s, s)), Color(C_FLAME.lerp(C_HOT, a), a))
	# the lantern: a ring on top, a little cage, the flame inside
	var body := Rect2(c + Vector2(-4, -5), Vector2(9, 11))
	_canvas.draw_rect(Rect2(c + Vector2(-1, -9), Vector2(3, 1)), C_BRASS)
	_canvas.draw_rect(Rect2(c + Vector2(-2, -8), Vector2(1, 2)), C_BRASS)
	_canvas.draw_rect(Rect2(c + Vector2(2, -8), Vector2(1, 2)), C_BRASS)
	_canvas.draw_rect(Rect2(body.position + Vector2(0, -1), Vector2(body.size.x, 1)), C_BRASS)
	_canvas.draw_rect(Rect2(body.position + Vector2(0, body.size.y), Vector2(body.size.x, 2)), C_BRASS.darkened(0.3))
	_canvas.draw_rect(body, Color(0.35, 0.18, 0.05, 0.9))
	var flick := sin(t * 11.0) * 0.5 + sin(t * 17.0) * 0.5
	var fh := 6.0 + roundf(flick)
	_canvas.draw_rect(Rect2(c + Vector2(-2, 4 - fh), Vector2(5, fh)), C_FLAME)
	_canvas.draw_rect(Rect2(c + Vector2(-1, 5 - fh), Vector2(3, fh - 2)), C_HOT)
	for x in [body.position.x, body.position.x + 4, body.end.x - 1]:   # the cage bars
		_canvas.draw_rect(Rect2(x, body.position.y, 1, body.size.y), Color(C_BRASS, 0.9))
	# what's being done, the dots counting along
	var dots := ".".repeat(1 + int(t * 2.0) % 3)
	var text := stage
	var tw := PixelFont.width_of(text + "...")
	var tx := floorf((size.x - tw) / 2.0)
	PixelFont.draw(_canvas, Vector2(tx, c.y + 34), text + dots, C_TEXT)
	# the bar
	var bw := 120.0
	var bar := Rect2(floorf((size.x - bw) / 2.0), c.y + 46, bw, 3)
	_canvas.draw_rect(bar, Color("120c1e"))
	var fill := roundf(bw * clampf(_shown, 0.0, 1.0))
	_canvas.draw_rect(Rect2(bar.position, Vector2(fill, 3)), Color(C_FLAME, 0.85))
	_canvas.draw_rect(Rect2(bar.position, Vector2(fill, 1)), Color(C_HOT, 0.7))
