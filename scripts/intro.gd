class_name Intro
extends CanvasLayer
## The opening: a voice in the dark, a little flame, a hero waking on a
## stone bier -- and then Lume's lessons: on a dark screen it shows him,
## picture by picture, how to survive the labyrinth (intro_lessons.gd), and
## brings him back to the chamber to set off. Plays at the start of every
## run; ESC (or Start on a pad) skips it. The whole game is paused
## underneath until it ends.

signal finished

const C_TEXT := Color("e8dfc8")
const C_DIM := Color("8a8299")
const C_NAME := Color("ffd35a")
const C_VOICE := Color("d8d0f0")
const C_LESSON_BG := Color(0.016, 0.01, 0.03)
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
var _done := false
# The lesson screen
var _lesson_bg := 0.0   # the dark lesson screen over the world (0..1)
var _lesson := ""       # which picture is up (IntroLessons)
var _topic := ""        # its heading; a new heading opens out of the dark
var _topic_n := 0       # how many headings so far (the progress pips)
var _topics_total := 0
var _delay := 0.0       # dark pause before the picture appears
var _fade := 0.3        # ...and how long it takes to come up
var _vt_was := -1.0     # last frame's time into the picture (for its sounds)
var _steps: Array = Lore.INTRO
var _short := false     # just the waking (every run after the very first)


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
	var seen := {}
	for s in Lore.INTRO:
		if s[0] == "lesson" and not seen.has(s[3]):
			seen[s[3]] = true
	_topics_total = seen.size()


## The short opening, for every new run after the first: out of the dark,
## Lume's spark, and the hero getting up off the bier -- no voice, no lessons.
func start_short() -> void:
	_short = true
	_steps = []
	for s in Lore.INTRO:
		if s[0] in ["black", "fade", "appear", "wake"]:
			_steps.append(s)
			if s[0] == "appear":
				_steps.append(["say", Lore.COMPANION, SHORT_WAKE])   # (with the REPLAY INTRO button)
	start()


## Lume's one line in the short opening -- while it's up, a small button offers
## the whole opening again (X, or click it): back into the dark, from the voice.
const SHORT_WAKE := "WAKE UP, RED. HOME IS STILL WAITING."
var _replay_rect := Rect2()


func _replay_offered() -> bool:
	return _short and not _done and _kind == "say"


func _replay_full() -> void:
	_short = false
	_steps = Lore.INTRO
	_step = -1
	_black = 1.0
	_sleeping = true
	companion.alpha = 0.0
	companion.talking = false
	companion.pos = player.position + Vector2(2, -14)
	Sfx.play("ui_select")
	_next()


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
	_vt_was = -1000.0
	companion.talking = false
	if _step >= _steps.size():
		_finish()
		return
	var s: Array = _steps[_step]
	_kind = s[0]
	_speaker = s[1]
	_text = s[2]
	if _kind == "voice":
		Sfx.play("whisper")
	elif _kind == "appear":
		Sfx.play("riddle", -4.0)
	elif _kind == "lessons_in":
		Sfx.play("dusk", -4.0)
	elif _kind == "lesson":
		_lesson = s[1]
		_speaker = Lore.COMPANION
		var topic: String = s[3]
		if topic != _topic:
			_delay = 0.7 if _topic != "" else 0.3
			_fade = 0.5
			_topic = topic
			_topic_n += 1
		else:
			_delay = 0.0
			_fade = 0.25
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
		"voice", "say", "lesson":
			var typing := true
			if _kind == "lesson":
				var vt := _t - _delay
				var was := _vt_was
				_vt_was = vt
				if was < 0.0 and vt >= 0.0 and _fade >= 0.5:
					Sfx.play("page", -6.0)   # a new picture opens out of the dark
				if vt >= 0.0:
					for cue in IntroLessons.cues(_lesson, was, vt):
						Sfx.play(cue[1], cue[2])
				else:
					typing = false
					if confirm:
						_t = _delay   # don't wait in the dark
						confirm = false
			if typing:
				var total := float(_text.length())
				var before := int(_shown)
				_shown = minf(_shown + delta * CHARS_PER_SEC, total)
				if _kind != "voice" and int(_shown) != before and int(_shown) % 3 == 0 and int(_shown) < total \
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
			# a stir, then she sits up -- drawing her legs in under her cloak --
			# scoots to the edge of the bier, and hops down, legs coming back out
			_sleeping = _t < 0.35
			player.sleeping = false
			var stir := sin(_t * 30.0) * 1.0 if _t > 0.1 and _t < 0.35 else 0.0
			var up := ease(clampf((_t - 0.4) / 0.6, 0.0, 1.0), -2.0)
			var scoot := ease(clampf((_t - 1.15) / 0.45, 0.0, 1.0), -2.0)
			var hop := clampf((_t - 1.75) / 0.45, 0.0, 1.0)
			player.pose_up = up
			# legs: tucked (0) while she sits and scoots, perched (0.6) on the edge, out (1) as she drops
			player.pose_legs = 1.0 if hop > 0.12 else (0.6 if scoot > 0.85 else 0.0)
			# the hip: on the bier, then shuffling to its front edge, then down onto the floor
			var hip := Vector2(15, 2).lerp(Vector2(10, 5), scoot).lerp(Vector2(8, 11), ease(hop, -1.6))
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
		"lessons_in":
			# the chamber sinks into the dark
			_lesson_bg = minf(_t / 0.8, 1.0)
			if _t > 1.0:
				_next()
		"lessons_out":
			# ...and comes back
			_lesson_bg = maxf(1.0 - _t / 0.8, 0.0)
			if _t > 0.9:
				_lesson_bg = 0.0
				_next()


func _input(event: InputEvent) -> void:
	if _done:
		return
	var skip := false
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		skip = true
	if event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START:
		skip = true
	if _replay_offered():
		var replay := false
		if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_X:
			replay = true
		if event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_X:
			replay = true
		if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
				and _replay_rect.has_point(_canvas.get_local_mouse_position()):
			replay = true
		if replay:
			get_viewport().set_input_as_handled()
			_replay_full()
			return
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
	if not _short and not OS.has_environment("SCYTHE_NO_INTRO"):
		Profile.mark_intro_seen()   # the whole opening only ever plays once
	_settle_hero()
	companion.follow = true
	companion.alpha = 1.0
	companion.talking = false
	player.ui_lock = ""
	hud.visible = true
	get_tree().paused = false
	finished.emit()
	# (skipped from the lesson screen: fade out of its dark instead of popping)
	_black = maxf(_black, _lesson_bg)
	_lesson_bg = 0.0
	# fade the black away, then go
	var tw := create_tween()
	tw.tween_property(self, "_black", 0.0, 0.5 if _black > 0.0 else 0.01)
	tw.tween_callback(queue_free)
	_kind = ""
	set_process(true)


func _draw_intro() -> void:
	var screen := _canvas.get_viewport_rect().size
	if _lesson_bg > 0.0 and not _done:
		_draw_lesson_screen(screen)
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
			if _replay_offered():
				_draw_replay_button(screen)
		"lesson":
			if _t >= _delay:
				_draw_box(screen)
	var hint := "ESC  SKIP INTRO"
	PixelFont.draw(_canvas, Vector2(screen.x - 8 - PixelFont.width_of(hint), 6), hint, Color(C_DIM, 0.75))


## The dark lesson screen: Lume's picture in the middle, its heading and
## progress at the top (the dialogue box goes underneath, in _draw_box).
func _draw_lesson_screen(screen: Vector2) -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, screen), Color(C_LESSON_BG, _lesson_bg))
	if _kind != "lesson":
		return
	var stage := Rect2(0, 20, screen.x, screen.y - 84)
	var vt := _t - _delay
	if vt >= 0.0:
		IntroLessons.draw(_canvas, _lesson, vt, stage)
	var shown := clampf(vt / _fade, 0.0, 1.0) if vt >= 0.0 else 0.0
	if shown < 1.0:
		_canvas.draw_rect(Rect2(0, 0, screen.x, stage.end.y), Color(C_LESSON_BG, 1.0 - shown))
	# heading, with a pip for each topic
	var cx := floorf(screen.x / 2)
	PixelFont.draw(_canvas, Vector2(cx - floorf(PixelFont.width_of(_topic) / 2.0), 5), _topic, Color(C_NAME, shown))
	var w := _topics_total * 6 - 2
	for i in _topics_total:
		var col := C_NAME if i < _topic_n else Color("3a3448")
		_canvas.draw_rect(Rect2(cx - floorf(w / 2.0) + i * 6, 13, 4, 1), Color(col, maxf(shown, 0.4)))


## The small REPLAY INTRO button, just above the dialogue box on the right.
func _draw_replay_button(screen: Vector2) -> void:
	var label := "REPLAY INTRO"
	var key := "X"
	var w := PixelFont.width_of(key) + 6 + 5 + PixelFont.width_of(label) + 8
	var r := Rect2(screen.x - 8 - w, screen.y - 77, w, 12)
	_replay_rect = r
	var hover := r.has_point(_canvas.get_local_mouse_position())
	var a := clampf(_t / 0.4, 0.0, 1.0)   # it fades in with the line
	var edge := C_NAME if hover else Color("8a7a5a")
	_canvas.draw_rect(r.grow(1), Color(0.02, 0.01, 0.04, 0.9 * a))
	_canvas.draw_rect(r, Color(edge, a))
	_canvas.draw_rect(r.grow(-1), Color(Color("2a2038") if hover else Color("17121f"), a))
	var kr := Rect2(r.position + Vector2(3, 2), Vector2(PixelFont.width_of(key) + 4, 8))
	_canvas.draw_rect(kr, Color(Color("a89ec0"), a))
	_canvas.draw_rect(kr.grow(-1), Color(Color("2a2038"), a))
	PixelFont.draw(_canvas, kr.position + Vector2(2, 1), key, Color(C_TEXT, a))
	PixelFont.draw(_canvas, Vector2(kr.end.x + 5, r.position.y + 3), label, Color(C_NAME if hover else C_TEXT, a))


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


func _more_arrow(a: Vector2) -> void:
	if fmod(_time, 0.8) >= 0.5:
		return
	_canvas.draw_rect(Rect2(a, Vector2(5, 1)), C_TEXT)
	_canvas.draw_rect(Rect2(a + Vector2(1, 1), Vector2(3, 1)), C_TEXT)
	_canvas.draw_rect(Rect2(a + Vector2(2, 2), Vector2(1, 1)), C_TEXT)
