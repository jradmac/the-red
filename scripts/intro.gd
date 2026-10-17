class_name Intro
extends CanvasLayer
## The opening: a voice in the dark, a little flame, a hero waking on a
## stone bier, and the Commandments of the Labyrinth. Plays at the start of
## every run; ESC (or Start on a pad) skips it. The whole game is paused
## underneath until it ends.

signal finished

const C_TEXT := Color("e8dfc8")
const C_DIM := Color("8a8299")
const C_NAME := Color("ffd35a")
const C_VOICE := Color("d8d0f0")
const CHARS_PER_SEC := 38.0

var player: Player
var world: World
var companion: Companion
var hud: CanvasLayer
var _canvas: Node2D
var _step := -1
var _kind := ""
var _speaker := ""
var _text := ""
var _shown := 0.0
var _t := 0.0           # time in the current step
var _time := 0.0
var _black := 1.0       # full-screen black (1 = all black)
var _sleeping := true
var _wake_from := Vector2.ZERO
var _wake_to := Vector2.ZERO
var _shown_rules := 0.0
var _done := false


func setup(p: Player, w: World, c: Companion, h: CanvasLayer) -> void:
	player = p
	world = w
	companion = c
	hud = h
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_intro)
	add_child(_canvas)


func start() -> void:
	get_tree().paused = true
	player.ui_lock = "intro"
	player.sleeping = true
	player.facing = Player.Facing.DOWN
	player.queue_redraw()
	hud.visible = false
	Sfx.ambient("amb_night")
	Sfx.music("crypt_night")
	companion.follow = false
	companion.alpha = 0.0
	companion.pos = player.position + Vector2(2, -14)
	_next()


func _next() -> void:
	_step += 1
	_t = 0.0
	_shown = 0.0
	companion.talking = false
	if _step >= Lore.INTRO.size():
		_finish()
		return
	var s: Array = Lore.INTRO[_step]
	_kind = s[0]
	_speaker = s[1]
	_text = s[2]
	if _kind == "voice":
		Sfx.play("whisper")
	elif _kind == "appear":
		Sfx.play("riddle", -4.0)
	elif _kind == "commandments":
		Sfx.play("dusk", -2.0)
	if _kind == "wake":
		Sfx.play("wake")
		_wake_from = player.position
		_wake_to = world.cell_to_position(world.start_cell + Vector2i.DOWN)


func _process(delta: float) -> void:
	if _done:
		return
	_time += delta
	_t += delta
	_canvas.queue_redraw()
	var confirm := Input.is_action_just_pressed("confirm")
	match _kind:
		"black":
			if _t > 1.2:
				_next()
		"voice", "say":
			var total := float(_text.length())
			var before := int(_shown)
			_shown = minf(_shown + delta * CHARS_PER_SEC, total)
			if _kind == "say" and int(_shown) != before and int(_shown) % 3 == 0 and int(_shown) < total \
					and _text[int(_shown) - 1] != " ":
				if _speaker == "LUME":
					Sfx.play("voice" + str(randi() % 4), 0.0, 0.03)
				else:
					Sfx.play("voice" + str(randi() % 4), -5.0, 0.02, 0.6)
			companion.talking = _kind == "say" and _shown < total
			if confirm:
				if _shown < total:
					_shown = total
				else:
					_next()
		"fade":
			_black = maxf(1.0 - _t / 2.5, 0.0)
			if _t > 2.8:
				_next()
		"appear":
			# a spark rises off the bier, swells into Lume and drifts to the hero
			var k := clampf(_t / 1.4, 0.0, 1.0)
			companion.alpha = k
			companion.pos = player.position + Vector2(2, -2).lerp(Vector2(14, -18), ease(k, -2.0))
			if _t > 1.6:
				_next()
		"wake":
			# a stir, then he sits up, swings his legs over the edge and hops down
			_sleeping = _t < 0.35
			player.sleeping = false
			var stir := sin(_t * 30.0) * 1.0 if _t > 0.1 and _t < 0.35 else 0.0
			var up := ease(clampf((_t - 0.4) / 0.6, 0.0, 1.0), -2.0)
			var legs := ease(clampf((_t - 1.15) / 0.45, 0.0, 1.0), -2.0)
			var hop := clampf((_t - 1.75) / 0.45, 0.0, 1.0)
			player.pose_up = up
			player.pose_legs = legs
			# the hip: on the bier, then shuffling to its front edge, then down onto the floor
			var hip := Vector2(15, 2).lerp(Vector2(10, 5), legs).lerp(Vector2(8, 11), ease(hop, -1.6))
			hip.y -= sin(hop * PI) * 5.0 - stir * 0.0
			hip.x += stir
			player.pose_hip = hip.round()
			player.queue_redraw()   # (the game is paused during the intro)
			player.position = _wake_from.lerp(_wake_to, ease(hop, -2.0)).round()
			if _t > 1.15 and _t - get_process_delta_time() <= 1.15:
				Sfx.play("step_stone0", -2.0)
			if _t > 2.2 and _t - get_process_delta_time() <= 2.2:
				Sfx.play("step_stone1", 2.0)
			if _t > 2.45:
				_settle_hero()
				companion.follow = true
				_next()
		"commandments":
			var was := int(_shown_rules)
			_shown_rules = minf(_shown_rules + delta * 2.2, Lore.COMMANDMENTS.size())
			if int(_shown_rules) != was and int(_shown_rules) <= Lore.COMMANDMENTS.size():
				Sfx.play("trap_thud", -12.0, 0.05, 0.7)
			if confirm:
				if _shown_rules < Lore.COMMANDMENTS.size():
					_shown_rules = Lore.COMMANDMENTS.size()
				else:
					_next()


func _input(event: InputEvent) -> void:
	if _done:
		return
	var skip := false
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		skip = true
	if event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START:
		skip = true
	if skip:
		get_viewport().set_input_as_handled()
		_finish()


## The hero steps down off the bier; the bier becomes solid.
func _settle_hero() -> void:
	player.sleeping = false
	player.pose_up = -1.0
	_sleeping = false
	var c := world.start_cell + Vector2i.DOWN
	player.cell = c
	player.position = world.cell_to_position(c)
	world.blockers[world.start_cell] = true


func _finish() -> void:
	_done = true
	_settle_hero()
	companion.follow = true
	companion.alpha = 1.0
	companion.talking = false
	player.ui_lock = ""
	hud.visible = true
	get_tree().paused = false
	finished.emit()
	# fade the black away, then go
	var tw := create_tween()
	tw.tween_property(self, "_black", 0.0, 0.5 if _black > 0.0 else 0.01)
	tw.tween_callback(queue_free)
	_kind = ""
	set_process(true)


func _draw_intro() -> void:
	var screen := _canvas.get_viewport_rect().size
	if _black > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, _black))
	if _done:
		return
	# Z z z over the sleeping hero
	if _sleeping and _black < 0.9:
		var hp: Vector2 = get_viewport().get_canvas_transform() * (player.global_position + Vector2(10, -6))
		for i in 3:
			var ph := fmod(_time * 0.6 + i / 3.0, 1.0)
			var p := hp + Vector2(ph * 8.0 + sin(ph * 6.0) * 2.0, -ph * 18.0)
			PixelFont.draw(_canvas, p.round(), "Z" if i % 2 == 0 else "z", Color(C_VOICE, (1.0 - ph) * (1.0 - _black)))
	if _kind == "wake" and _t > 0.3 and _t < 0.95:
		var hp2: Vector2 = get_viewport().get_canvas_transform() * (player.global_position + Vector2(6, -16))
		PixelFont.draw(_canvas, hp2.round(), "!", Color("ffffff"))
	match _kind:
		"voice":
			var visible_text := _text.substr(0, int(_shown))
			var lines := Dialog.wrap_text(_text, 260)
			var y := floorf(screen.y / 2 - lines.size() * 5)
			var used := 0
			for line in lines:
				var part := visible_text.substr(used, line.length())
				PixelFont.draw(_canvas, Vector2(floorf((screen.x - PixelFont.width_of(line)) / 2), y), part,
					Color(C_VOICE, 0.85 + 0.15 * sin(_time * 3.0)))
				used += line.length() + 1
				y += 10
			if _shown >= _text.length():
				_more_arrow(Vector2(floorf(screen.x / 2) - 2, y + 4))
		"say":
			_draw_box(screen)
		"commandments":
			_draw_commandments(screen)
	var hint := "ESC  SKIP INTRO"
	PixelFont.draw(_canvas, Vector2(screen.x - 8 - PixelFont.width_of(hint), 6), hint, Color(C_DIM, 0.75))


func _draw_box(screen: Vector2) -> void:
	var r := Rect2(8, screen.y - 62, screen.x - 16, 54)
	UiKit.panel(_canvas, r)
	# portrait
	var pr := Rect2(r.position + Vector2(6, 6), Vector2(42, 42))
	_canvas.draw_rect(pr, Color("120d1c"))
	_canvas.draw_rect(Rect2(pr.position, Vector2(pr.size.x, 1)), Color("3a2f52"))
	var unknown := _speaker == "???"
	var t := _time if not unknown else _time * 0.7
	var tex_at := pr.position + Vector2(3, 0)
	if unknown:
		# not yet named: just a flicker in the dark
		_canvas.draw_circle(pr.get_center(), 10.0 + sin(_time * 5.0), Color(1.0, 0.75, 0.4, 0.15))
		_canvas.draw_circle(pr.get_center(), 4.0 + sin(_time * 7.0) * 0.6, Color(1.0, 0.9, 0.7, 0.8))
	else:
		Companion.draw_portrait(_canvas, tex_at, 3.0, t, _shown < _text.length())
	# name and text
	UiKit.chip(_canvas, r.position + Vector2(54, 6), _speaker, C_NAME)
	var visible_text := _text.substr(0, int(_shown))
	var lines := Dialog.wrap_text(_text, int(r.size.x) - 66)
	var y := r.position.y + 18
	var used := 0
	for line in lines:
		PixelFont.draw(_canvas, Vector2(r.position.x + 54, y), visible_text.substr(used, line.length()), C_TEXT)
		used += line.length() + 1
		y += 8
	if _shown >= _text.length():
		_more_arrow(r.end - Vector2(12, 9))


func _draw_commandments(screen: Vector2) -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, screen), Color(0.02, 0.01, 0.04, 0.82))
	var r := Rect2(20, 14, screen.x - 40, screen.y - 28)
	# a stone tablet
	_canvas.draw_rect(r, Color("2a2636"))
	_canvas.draw_rect(r.grow(-2), Color("4a4458"))
	_canvas.draw_rect(r.grow(-4), Color("3a3548"))
	for i in 18:   # weathering
		var h := (i * 7919) % 997
		_canvas.draw_rect(Rect2(r.position + Vector2(8 + h % int(r.size.x - 16), 8 + (h / 7) % int(r.size.y - 16)), Vector2(2, 1)), Color("2e2a3c"))
	var title := "THE COMMANDMENTS OF THE LABYRINTH"
	PixelFont.draw(_canvas, Vector2(floorf((screen.x - PixelFont.width_of(title)) / 2), r.position.y + 10), title, C_NAME)
	_canvas.draw_rect(Rect2(r.position.x + 30, r.position.y + 20, r.size.x - 60, 1), Color("8a7a5a"))
	var n := int(_shown_rules)
	for i in Lore.COMMANDMENTS.size():
		if i > n:
			break
		var a := 1.0 if i < n else fmod(_shown_rules, 1.0)
		var y := r.position.y + 28 + i * 17
		var num: String = Lore.COMMANDMENTS[i][0]
		PixelFont.draw(_canvas, Vector2(r.position.x + 30 - PixelFont.width_of(num), y), num, Color(C_NAME, a))
		PixelFont.draw(_canvas, Vector2(r.position.x + 38, y), Lore.COMMANDMENTS[i][1], Color(C_TEXT, a))
	if n >= Lore.COMMANDMENTS.size():
		_more_arrow(r.end - Vector2(14, 10))


func _more_arrow(a: Vector2) -> void:
	if fmod(_time, 0.8) >= 0.5:
		return
	_canvas.draw_rect(Rect2(a, Vector2(5, 1)), C_TEXT)
	_canvas.draw_rect(Rect2(a + Vector2(1, 1), Vector2(3, 1)), C_TEXT)
	_canvas.draw_rect(Rect2(a + Vector2(2, 2), Vector2(1, 1)), C_TEXT)
