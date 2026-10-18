class_name TitleScreen
extends CanvasLayer
## The title screen, before anything else: RED RIDING carved out of the dark
## (assets/title_logo.png, tools/make_title.py), motes of lantern light and
## shadow drifting up past it. It's all there from the start, unlit: a warm
## lantern light drifts in from below and the letters show as it reaches them. PRESS START, then CONTINUE (when there's a saved
## run) or NEW GAME. Starting over asks first, since it erases the save.

signal chosen(choice: String)   ## "continue" or "new"

const LOGO: Texture2D = preload("res://assets/title_logo.png")
const C_BG := Color("040208")
const C_TEXT := Color("e8dfc8")
const C_DIM := Color("8a8299")
const C_PICK := Color("ffd35a")
const C_BAD := Color("ff6a6a")
const C_EMBER := Color("ffb060")
const LOGO_Y := 22.0
const REVEAL := 3.2        ## the lantern light coming in
const TILE := 4            ## the title is lit in tiles this size
const MOTES := 70
## The background: near-black, a soft violet in the far corners, and the
## lantern's light -- one smooth pool, a hot heart running out through orange
## to a deep red edge, like the lantern in the game. Dithered a little so the
## falloff never steps into rings.
const LIGHT_SHADER := """
shader_type canvas_item;
uniform vec2 screen = vec2(360.0, 240.0);
uniform vec2 light_pos = vec2(180.0, 150.0);
uniform float radius = 220.0;
uniform float strength = 1.0;
uniform vec3 bg = vec3(0.016, 0.008, 0.031);

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 px = floor(UV * screen) + 0.5;
	// the pool is a little wider than tall, like light lying across a floor
	vec2 d = (px - light_pos) / vec2(radius, radius * 0.82);
	float r = length(d);
	float i = pow(clamp(1.0 - r, 0.0, 1.0), 1.5) * strength;
	vec3 deep = vec3(0.42, 0.06, 0.04);
	vec3 warm = vec3(0.95, 0.38, 0.10);
	vec3 hot = vec3(1.0, 0.66, 0.30);
	vec3 col = mix(deep, warm, smoothstep(0.05, 0.55, i));
	col = mix(col, hot, smoothstep(0.6, 1.0, i));
	vec3 c = bg + col * i * 0.6;
	// cold violet creeping in at the far corners
	float corner = smoothstep(0.55, 1.15, length((px - screen * 0.5) / screen * vec2(1.6, 1.9)));
	c += vec3(0.10, 0.05, 0.20) * corner * 0.35 * (1.0 - i);
	c += (hash(px) - 0.5) / 255.0 * 2.5;
	COLOR = vec4(c, 1.0);
}
"""

var _summary := ""
var _has_save := false
var _state := "reveal"     # reveal, press, menu, confirm, leaving
var _sel := 0
var _time := 0.0
var _t := 0.0              # time in the state
var _choice := ""
var _canvas: Node2D
var _light_rect: ColorRect   # the dark and the lantern's light, drawn by LIGHT_SHADER
var _ready_frame := -1
var _motes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


## `summary` describes the saved run (empty when there isn't one).
func setup(summary: String, has_save: bool) -> void:
	_summary = summary
	_has_save = has_save
	layer = 30
	_light_rect = ColorRect.new()
	_light_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_light_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = LIGHT_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_light_rect.material = mat
	add_child(_light_rect)
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_title)
	add_child(_canvas)
	_ready_frame = Engine.get_process_frames()
	_rng.randomize()
	for i in MOTES:
		_motes.append(_new_mote(true))
	Sfx.play("match_strike", -4.0)


func _options() -> Array:
	return ["CONTINUE", "NEW GAME"] if _has_save else ["NEW GAME"]


## A mote of light (warm, from the lantern) or of shadow (deep violet) drifting upward.
func _new_mote(anywhere: bool) -> Dictionary:
	var warm := _rng.randf() < 0.55
	return {
		"p": Vector2(_rng.randf_range(0, 360), _rng.randf_range(0, 240) if anywhere else _rng.randf_range(244, 260)),
		"v": Vector2(_rng.randf_range(-3, 3), -_rng.randf_range(3, 11)),
		"warm": warm, "size": 2.0 if _rng.randf() < 0.18 else 1.0,
		"phase": _rng.randf() * TAU, "rate": _rng.randf_range(1.0, 3.5),
		"col": (C_EMBER if _rng.randf() < 0.7 else Color("ffe08a")) if warm
			else (Color("8a6ad0") if _rng.randf() < 0.5 else Color("4a3a7a")),
	}


## Either player's button (and any controller, which plays as player 1 here).
func _pressed(action: String) -> bool:
	if Input.is_action_just_pressed(action):
		return true
	return InputMap.has_action("p2_" + action) and Input.is_action_just_pressed("p2_" + action)


func _process(delta: float) -> void:
	_time += delta
	_t += delta
	for m in _motes:
		m.p += m.v * delta + Vector2(sin(_time * 0.7 + m.phase) * 4.0 * delta, 0)
		if m.p.y < -6:
			m.merge(_new_mote(false), true)
	_canvas.queue_redraw()
	if Engine.get_process_frames() <= _ready_frame + 1:
		return
	var go := _pressed("confirm") or _pressed("inventory") or Input.is_action_just_pressed("ui_accept")
	match _state:
		"reveal":
			if go:
				_t = maxf(_t, REVEAL)   # skip to the end of it
			if _t >= REVEAL + 0.4:
				_set_state("press")
		"press":
			if go:
				Sfx.play("ui_select")
				_sel = 0
				_set_state("menu")
		"menu":
			var n := _options().size()
			if _pressed("move_up") or _pressed("move_down"):
				if n > 1:
					_sel = (_sel + 1) % n
					Sfx.play("ui_move")
			elif _pressed("run"):
				Sfx.play("ui_back")
				_set_state("press")
			elif go:
				var opt: String = _options()[_sel]
				if opt == "CONTINUE":
					_leave("continue")
				elif _has_save:
					Sfx.play("ui_select")
					_set_state("confirm")   # it would erase the save: ask once more
				else:
					_leave("new")
		"confirm":
			if _pressed("confirm"):
				_leave("new")
			elif _pressed("run"):
				Sfx.play("ui_back")
				_set_state("menu")
		"leaving":
			if _t >= 0.9:
				set_process(false)
				chosen.emit(_choice)


func _set_state(s: String) -> void:
	_state = s
	_t = 0.0


func _leave(choice: String) -> void:
	_choice = choice
	Sfx.play("ui_select")
	Sfx.play("whisper", -6.0)
	_set_state("leaving")


func _draw_title() -> void:
	var size := _canvas.get_viewport_rect().size
	var cx := floorf(size.x / 2.0)
	var reveal := 1.0 if _state != "reveal" else clampf(_t / REVEAL, 0.0, 1.0)
	# the lantern's light: it drifts in from below on the left and comes to rest
	# low in the middle, widening as it comes; it breathes like a flame
	var k := ease(reveal, -2.0)
	var breath := 0.9 + 0.07 * sin(_time * 1.7) + 0.03 * sin(_time * 7.3)
	var light := Vector2(lerpf(-40.0, cx, k), lerpf(size.y + 60.0, 150.0, k))
	var radius := lerpf(70.0, 230.0, k) * breath
	var mat := _light_rect.material as ShaderMaterial
	mat.set_shader_parameter("screen", size)
	mat.set_shader_parameter("light_pos", light + Vector2(0, 20))
	mat.set_shader_parameter("radius", radius * 1.45)
	mat.set_shader_parameter("strength", lerpf(0.6, 1.0, k) * breath)
	for i in _motes.size():   # motes behind the title
		if i % 2 == 0:
			_draw_mote(_motes[i])
	# the title: always there, but only what the light reaches shows
	var lp := Vector2(floorf(cx - LOGO.get_width() / 2.0), LOGO_Y)
	var lw := int(LOGO.get_width())
	var lh := int(LOGO.get_height())
	for ty in range(0, lh, TILE):
		for tx in range(0, lw, TILE):
			var src := Rect2(tx, ty, mini(TILE, lw - tx), mini(TILE, lh - ty))
			var d := (lp + src.get_center()).distance_to(light)
			var b := 0.07 + 0.93 * (1.0 - smoothstep(radius * 0.45, radius * 1.05, d))
			_canvas.draw_texture_rect_region(LOGO, Rect2(lp + src.position, src.size), src,
				Color(b, b * 0.96, b * 0.92))
	# a slow band of heat passing across the letters now and then
	var sweep := fmod(_time, 6.0) / 1.6
	if reveal >= 1.0 and sweep < 1.0:
		var bx := lerpf(-24.0, LOGO.get_width() + 8.0, sweep)
		var band := Rect2(bx, 0, 16, LOGO.get_height()).intersection(Rect2(Vector2.ZERO, LOGO.get_size()))
		if band.size.x > 0:
			_canvas.draw_texture_rect_region(LOGO, Rect2(lp + band.position, band.size), band, Color(1.6, 1.25, 1.0, 0.35))
	for i in _motes.size():   # motes in front
		if i % 2 == 1:
			_draw_mote(_motes[i])
	match _state:
		"press":
			if fmod(_t, 1.1) < 0.75:
				_text_c(cx, 190, "PRESS START", C_EMBER)
		"menu":
			var opts := _options()
			var y := 178.0 if opts.size() > 1 else 188.0
			for i in opts.size():
				var picked := i == _sel
				var text: String = opts[i]
				if picked:
					text = "> " + text + " <"
				_text_c(cx, y, text, C_PICK if picked else C_TEXT)
				if opts[i] == "CONTINUE" and _summary != "":
					_text_c(cx, y + 10, _summary, C_DIM)
					y += 10
				y += 16
			_text_c(cx, size.y - 12, "ARROWS CHOOSE   Z CONFIRM   X BACK", Color(C_DIM, 0.6))
		"confirm":
			_text_c(cx, 180, "START OVER? YOUR SAVED GAME WILL BE LOST.", C_BAD)
			_text_c(cx, 198, "Z  YES, START OVER        X  NO", C_DIM)
		"leaving":
			_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, clampf(_t / 0.8, 0.0, 1.0)))


func _draw_mote(m: Dictionary) -> void:
	var tw: float = 0.45 + 0.55 * (0.5 + 0.5 * sin(_time * m.rate + m.phase))
	var col: Color = m.col
	var s: float = m.size
	if m.warm and s > 1.0:
		_canvas.draw_rect(Rect2((m.p - Vector2(1, 1)).round(), Vector2(4, 4)), Color(col, 0.12 * tw))
	_canvas.draw_rect(Rect2(m.p.round(), Vector2(s, s)), Color(col, (0.85 if m.warm else 0.6) * tw))


func _text_c(cx: float, y: float, text: String, col: Color) -> void:
	PixelFont.draw(_canvas, Vector2(floorf(cx - PixelFont.width_of(text) / 2.0), y), text, col)
