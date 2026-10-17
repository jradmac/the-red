class_name Transition
extends CanvasLayer
## The lead-in to a fight: the screen flashes a few times, cuts to black with
## "THE SPIDER ATTACKED YOU!" (or "YOU ATTACKED THE SPIDER!"), then the battle
## fades in underneath.

const FLASHES := 3
const FLASH_TIME := 0.5     # all the flashes
const TEXT_TIME := 1.0      # black screen with the line of text
const FADE_TIME := 0.3      # black fades away over the battle screen
const C_TEXT := Color("e8dfc8")
const C_RED := Color("ff5a6a")

var _t := -1.0
var _text := ""
var _color := C_TEXT
var _then: Callable
var _fired := false
var _canvas: Node2D


func _ready() -> void:
	layer = 8
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_it)
	add_child(_canvas)


func is_playing() -> bool:
	return _t >= 0.0


## Plays the transition; `then` runs when the screen is black (start the battle there).
func play(text: String, enemy_started: bool, then: Callable) -> void:
	_t = 0.0
	_text = text
	_color = C_RED if enemy_started else C_TEXT
	_then = then
	_fired = false


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	if not _fired and _t >= FLASH_TIME + TEXT_TIME:
		_fired = true
		_then.call()
	if _t >= FLASH_TIME + TEXT_TIME + FADE_TIME:
		_t = -1.0
	_canvas.queue_redraw()


func _draw_it() -> void:
	if _t < 0.0:
		return
	var screen := _canvas.get_viewport_rect().size
	var full := Rect2(Vector2.ZERO, screen)
	if _t < FLASH_TIME:
		# quick white flashes, each a little longer than the last
		var phase := _t / FLASH_TIME * FLASHES
		var a := 1.0 - fmod(phase, 1.0)
		_canvas.draw_rect(full, Color(1, 0.97, 0.9, a * a * 0.9))
		return
	var black := 1.0
	if _t > FLASH_TIME + TEXT_TIME:
		black = 1.0 - (_t - FLASH_TIME - TEXT_TIME) / FADE_TIME
	_canvas.draw_rect(full, Color(0.02, 0.01, 0.04, clampf(black, 0.0, 1.0)))
	if _t < FLASH_TIME + TEXT_TIME:
		var ta := clampf((_t - FLASH_TIME) / 0.15, 0.0, 1.0)
		# the text slams in from the side
		var slide := (1.0 - ta) * 40.0
		var w := PixelFont.width_of(_text)
		var pos := Vector2(floorf((screen.x - w) / 2 + slide), floorf(screen.y / 2 - 3))
		_canvas.draw_rect(Rect2(0, pos.y - 6, screen.x, 17), Color(0.12, 0.04, 0.08, ta * 0.9))
		PixelFont.draw(_canvas, pos, _text, Color(_color, ta))
