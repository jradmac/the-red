class_name Companion
extends Node2D
## Lume: the little flame that woke you. It hovers at your shoulder for the
## whole game, trailing a step behind, bobbing and flickering, with a small
## warm light of its own (not enough to keep the Longman away).

const TEX: Texture2D = preload("res://assets/lume.png")
const TEAL_TEX: Texture2D = preload("res://assets/lume_teal.png")   # player 2's spirit
const FRAME := Vector2(12, 14)
const LIGHT_COLOR := Color(1.0, 0.85, 0.55)

var player: Player
var teal := false
var follow := true        # false while the intro moves it by hand
var pos := Vector2.ZERO   # where it is (world pixels, top-left of the sprite)
var talking := false
var alpha := 1.0
var _light: Dictionary
var _time := 0.0
var _blink := 3.0


func setup(p: Player, lighting: Lighting) -> void:
	player = p
	z_index = 2
	process_mode = Node.PROCESS_MODE_ALWAYS   # it keeps moving during the intro
	pos = _home()
	_light = lighting.add_light(self, pos + FRAME / 2, 26.0, Color(0.45, 1.0, 0.9) if teal else LIGHT_COLOR, 0.55, 0.12, false)
	_lighting = lighting


var _lighting: Lighting


## Goes away (its player left the game).
func dismiss() -> void:
	if _lighting != null:
		_lighting.remove_light(_light)
	queue_free()


## Where it likes to be: just behind your shoulder, on the side away from
## where you're facing, drifting in a slow loop.
func _home() -> Vector2:
	var side := -1.0
	match player.facing:
		Player.Facing.LEFT: side = 1.0
		Player.Facing.RIGHT: side = -1.0
		_: side = -1.0 if sin(_time * 0.25) < 0.0 else 1.0
	var loop := Vector2(cos(_time * 1.1) * 3.0, sin(_time * 2.2) * 1.5)
	return player.position + Vector2(2 + side * 11, -16) + loop


func _process(delta: float) -> void:
	_time += delta
	_blink -= delta
	if _blink < -0.15:
		_blink = randf_range(2.0, 5.0)
	if follow and player != null:
		pos = pos.lerp(_home(), 1.0 - exp(-4.5 * delta))
	var bob := sin(_time * 3.0) * 1.5
	_light.offset = pos + FRAME / 2 + Vector2(0, bob)
	_light.energy = 0.55 * alpha
	queue_redraw()


func _draw() -> void:
	paint(self, pos)


## Draws the spirit with its frame's top-left at `top_left` (+ its bob).
func paint(ci: CanvasItem, top_left: Vector2) -> void:
	if alpha <= 0.01:
		return
	var bob := roundf(sin(_time * 3.0) * 1.5)
	var frame := int(_time * 6.0) % 2
	if talking and fmod(_time, 0.24) < 0.12:
		frame = 2
	elif _blink < 0.0:
		frame = 3
	var at := (top_left + Vector2(0, bob)).round()
	# soft glow, then the flame
	var glow := Color(0.4, 1.0, 0.9) if teal else Color(1.0, 0.8, 0.45)
	ci.draw_circle(at + FRAME / 2, 8.0, Color(glow, 0.10 * alpha))
	ci.draw_circle(at + FRAME / 2, 5.0, Color(glow.lightened(0.3), 0.12 * alpha))
	ci.draw_texture_rect_region(TEAL_TEX if teal else TEX, Rect2(at, FRAME), Rect2(frame * FRAME.x, 0, FRAME.x, FRAME.y),
		Color(1, 1, 1, alpha))
	# a faint shadow on the ground below it
	if not Shadows.off:
		ci.draw_rect(Rect2((top_left + Vector2(3, 20)).round(), Vector2(6, 1)), Color(0, 0, 0, 0.18 * alpha))


## The portrait for dialogue boxes: big, crisp, flickering.
static func draw_portrait(canvas: CanvasItem, at: Vector2, scale: float, t: float, talking: bool) -> void:
	var frame := int(t * 6.0) % 2
	if talking and fmod(t, 0.24) < 0.12:
		frame = 2
	canvas.draw_circle(at + FRAME * scale / 2, 9.0 * scale, Color(1.0, 0.75, 0.4, 0.08))
	canvas.draw_texture_rect_region(TEX, Rect2(at, FRAME * scale), Rect2(frame * FRAME.x, 0, FRAME.x, FRAME.y))
