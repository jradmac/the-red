class_name RiddleScreen
extends CanvasLayer
## A sprite's riddle. The sprite floats on the left; its riddle and three
## answers on the right. Get it right and choose a reward:
##   UPGRADE  one of your weapons or armor gets +2, +3 or +4
##   CLUE     the next door to unlock, or the spot where its key lies, is
##            put on your map (just that room -- not the way there)
## Get it wrong and the sprite giggles and vanishes. X walks away (the
## sprite stays).

var pfx := ""   ## input action prefix: "" for player 1, "p2_" for player 2

const C_TEXT := Color("e8dfc8")
const C_DIM := Color("8a8299")
const C_PICK := Color("ffd35a")
const C_GOOD := Color("7dff9a")
const C_BAD := Color("ff5a6a")

var player: Player
var inventory: Inventory
var doors: Doors
var world: World
var automap: Automap
var wisps: Wisps
var _canvas: Node2D
var _rng := RandomNumberGenerator.new()
var _used := {}
var _wisp: Dictionary = {}
var _riddle: Dictionary = {}
var _state := ""      # ask, result, reward, upgrade, clue, done
var _sel := 0
var _picked := -1
var _options: Array[String] = []
var _slots: Array[int] = []      # bag slots offered for an upgrade
var _message := ""
var _message_col := C_TEXT
var _time := 0.0
var _opened_frame := -1
var _fade_t := -1.0     # >= 0 while a wrong-answered sprite dissipates
const FADE_TIME := 1.6


func setup(p: Player, inv: Inventory, dr: Doors, w: World, am: Automap, ws: Wisps) -> void:
	player = p
	inventory = inv
	doors = dr
	world = w
	automap = am
	wisps = ws
	layer = 5
	visible = false
	_rng.randomize()
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_screen)
	add_child(_canvas)


func open(w: Dictionary) -> void:
	_wisp = w
	_riddle = Riddles.make(_rng, _used)
	_options.assign(_riddle.options)
	_state = "ask"
	_sel = 0
	_picked = -1
	_message = ""
	_fade_t = -1.0
	visible = true
	Sfx.play("riddle")
	player.ui_lock = "riddle"
	_opened_frame = Engine.get_process_frames()


func _close(vanish: bool) -> void:
	visible = false
	player.ui_lock = ""
	if vanish:
		wisps.vanish(_wisp)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if _fade_t >= 0.0:
		_fade_t += delta
		if _fade_t >= FADE_TIME + 0.8:
			_close(true)   # it's gone; back to the labyrinth
			return
	_canvas.queue_redraw()
	if Engine.get_process_frames() == _opened_frame:
		return
	if _state in ["ask", "reward", "upgrade", "clue"]:
		if Input.is_action_just_pressed(pfx + "move_up"):
			_sel = posmod(_sel - 1, _options.size())
			Sfx.play("ui_move")
		elif Input.is_action_just_pressed(pfx + "move_down"):
			_sel = posmod(_sel + 1, _options.size())
			Sfx.play("ui_move")
	if _state == "ask" and Input.is_action_just_pressed(pfx + "run"):
		_close(false)
		return
	if not Input.is_action_just_pressed(pfx + "confirm"):
		return
	match _state:
		"ask":
			_picked = _sel
			_state = "result"
			if _picked == int(_riddle.answer):
				_message = ["YES! CLEVER LITTLE LANTERN-BEARER.", "CORRECT! THE SPRITE SPINS WITH DELIGHT.",
					"RIGHT! NOW, WHAT IS YOUR WISH?"][_rng.randi() % 3]
				_message_col = C_GOOD
				Sfx.play("correct")
			else:
				Sfx.play("wrong")
				_message = "WRONG! THE ANSWER WAS " + _options[int(_riddle.answer)] + "."
				_message_col = C_BAD
		"result":
			if _picked == int(_riddle.answer):
				_state = "reward"
				_options = ["AN UPGRADE  (+2 TO +4 ON A WEAPON OR ARMOR)", "A CLUE  (A DOOR OR KEY ON YOUR MAP)"]
				_sel = 0
			else:
				_message = "THE SPRITE GIGGLES... AND FADES AWAY INTO THE DARK."
				_message_col = C_DIM
				_state = "done"
				_fade_t = 0.0
				Sfx.play("fade_away")
		"reward":
			if _sel == 0:
				_offer_upgrade()
			else:
				_state = "clue"
				_options = ["THE NEXT DOOR TO UNLOCK", "WHERE ITS KEY IS HIDDEN"]
				_sel = 0
		"upgrade":
			var slot := _slots[_sel]
			var amount := _rng.randi_range(2, 4)
			Sfx.play("upgrade")
			var s: Dictionary = inventory.slots[slot]
			s["bonus"] = Items.bonus(s) + amount
			inventory.changed.emit()
			_message = "YOUR " + Items.display_name(s.id) + " GLOWS!  +" + str(amount) + " " + \
				("ATK" if Items.kind(s.id) == "weapon" else "DEF") + "  (NOW " + Items.short_stat_of(s) + ")"
			_message_col = C_GOOD
			_state = "done"
		"clue":
			_give_clue(_sel == 1)
			_state = "done"
		"done":
			if _fade_t >= 0.0 and _fade_t < FADE_TIME:
				return   # let it finish fading
			_close(true)


func _offer_upgrade() -> void:
	_slots.clear()
	_options.clear()
	for i in Inventory.SLOTS:
		var s := inventory.slots[i]
		if not s.is_empty() and Items.kind(s.id) in ["weapon", "armor"]:
			_slots.append(i)
			_options.append(Items.label(s) + "   " + Items.short_stat_of(s))
	if _slots.is_empty():
		_message = "YOU CARRY NO WEAPON OR ARMOR TO BLESS. HAVE A CLUE INSTEAD."
		_message_col = C_DIM
		_state = "clue"
		_options = ["THE NEXT DOOR TO UNLOCK", "WHERE ITS KEY IS HIDDEN"]
	else:
		_state = "upgrade"
	_sel = 0


func _give_clue(key: bool) -> void:
	# always the same door for you until it's open: the one nearest you
	# (that you can open) when you first asked -- the key clue is that door's key
	var door := doors.clue_door(player.cell, pfx, inventory)
	if door.x < 0:
		_message = "NO LOCKED DOOR STANDS BEFORE YOU. SEEK THE MASTER CHAMBER!"
		_message_col = C_DIM
		return
	var color: String = doors.doors[door].color
	var spot := door
	_message = ""
	if key:
		if inventory.count_of(color + "_key") > 0:
			_message = "YOU ALREADY CARRY A " + color.to_upper() + " KEY! HERE IS ITS DOOR."
		else:
			var k := doors.clue_key(door, player.cell)
			if k.x >= 0:
				spot = k
	world.map_area(spot)
	if not automap.hints.has(spot):
		automap.hints.append(spot)
	if spot == door and not automap.hints.has(door):
		automap.hints.append(door)
	if _message == "":
		if spot != door:
			_message = "THE KEY TO THE " + color.to_upper() + " DOOR LIES HERE..."
		else:
			_message = "THE " + color.to_upper() + " DOOR TO OPEN NEXT IS HERE..."
	_message += "  CHECK YOUR MAP (M)."
	_message_col = Color("7dffe0")


# --- Drawing ---------------------------------------------------------------------

func _draw_screen() -> void:
	if _wisp.is_empty():
		return
	var screen := _canvas.get_viewport_rect().size
	UiKit.backdrop(_canvas, screen)
	var col: Color = Wisps.COLORS[_wisp.kind]

	# the sprite, big, bobbing in its own glow
	var c := Vector2(70, 100)
	if _fade_t < 0.0:
		UiKit.glow(_canvas, c, 60, col, 1.4 + 0.2 * sin(_time * 3.0))
	var mood := 0.0
	if _state != "ask" and _picked >= 0:
		mood = 1.0 if _picked == int(_riddle.answer) else -1.0
	var bob := roundf(sin(_time * 2.2) * 4.0) - (6.0 * absf(sin(_time * 8.0)) if mood > 0 else 0.0)
	var shake := sin(_time * 30.0) * 2.0 if mood < 0 and _state == "result" else 0.0
	var frame := int(_time * 5.0) % 2
	if _fade_t >= 0.0:
		_draw_fading(c, col, frame)
	else:
		_draw_sprite(c, col, frame, bob, shake)
	_draw_panels(screen)


func _draw_sprite(c: Vector2, col: Color, frame: int, bob: float, shake: float) -> void:
	Shadows.oval(_canvas, c + Vector2(0, 46), 34, 0.6)
	_canvas.draw_texture_rect_region(Wisps.TEX, Rect2(c + Vector2(-32 + shake, -36 + bob), Vector2(64, 64)),
		Rect2(frame * 16, _wisp.kind * 16, 16, 16))
	for i in 8:
		var a := _time * 1.5 + i * TAU / 8.0
		var p := c + Vector2(cos(a) * 44.0, sin(a) * 16.0 - 4.0)
		_canvas.draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(col.lightened(0.5), 0.5 + 0.5 * sin(_time * 4.0 + i)))



func _draw_panels(screen: Vector2) -> void:
	# speech panel with the riddle
	var r := Rect2(140, 12, 212, 92)
	const TITLES := {"RIDDLE": "A RIDDLE", "NUMBERS": "NUMBER PUZZLE", "COUNTING": "STORY PUZZLE",
		"SCRAMBLE": "WORD SCRAMBLE", "BACKWARDS": "MIRROR WORD", "ODD ONE": "ODD ONE OUT",
		"SEQUENCE": "WHAT COMES NEXT", "MISSING": "MISSING LETTER"}
	UiKit.panel(_canvas, r, TITLES.get(_riddle.kind, "A RIDDLE"))
	var y := r.position.y + 10
	for line in Dialog.wrap_text(_riddle.q, int(r.size.x) - 16):
		PixelFont.draw(_canvas, Vector2(r.position.x + 8, y), line, C_TEXT)
		y += 8

	# answers / choices
	var lr := Rect2(140, 112, 212, 90)
	var title: String = {"ask": "YOUR ANSWER", "result": "YOUR ANSWER", "reward": "YOUR REWARD",
		"upgrade": "BLESS WHICH ITEM?", "clue": "REVEAL WHAT?", "done": ""}.get(_state, "")
	UiKit.panel(_canvas, lr, title)
	if _state in ["ask", "result"]:
		for i in _options.size():
			var oy := lr.position.y + 12 + i * 24
			var row := Rect2(lr.position.x + 6, oy, lr.size.x - 12, 20)
			var bg := Color("1e1830")
			var fg := C_TEXT
			if _state == "ask" and i == _sel:
				bg = Color("3a2f52")
				fg = C_PICK
			elif _state == "result":
				if i == int(_riddle.answer):
					bg = Color(0.15, 0.4, 0.2)
					fg = C_GOOD
				elif i == _picked:
					bg = Color(0.45, 0.1, 0.15)
					fg = C_BAD
			_canvas.draw_rect(row, bg)
			UiKit.icon_frame(_canvas, Rect2(row.position + Vector2(4, 4), Vector2(12, 12)), _state == "ask" and i == _sel)
			PixelFont.draw(_canvas, row.position + Vector2(8, 8), ["A", "B", "C"][i], fg)
			PixelFont.draw(_canvas, row.position + Vector2(22, 8), _options[i], fg)
	elif _state in ["reward", "upgrade", "clue"]:
		for i in _options.size():
			var oy := lr.position.y + 12 + i * 14
			var picked := i == _sel
			if picked:
				_canvas.draw_rect(Rect2(lr.position.x + 6, oy - 3, lr.size.x - 12, 12), Color("3a2f52"))
				PixelFont.draw(_canvas, Vector2(lr.position.x + 10, oy), ">", C_PICK)
			PixelFont.draw(_canvas, Vector2(lr.position.x + 18, oy), _options[i], C_PICK if picked else C_TEXT)
	# result / reward message
	if _state in ["result", "done"] or (_state == "clue" and _message.begins_with("YOU CARRY")):
		var my := lr.position.y + (84 if _state == "result" else 30)
		if _state == "result":
			my = lr.end.y + 8
		for line in Dialog.wrap_text(_message, int(lr.size.x) - 12):
			PixelFont.draw(_canvas, Vector2(lr.position.x + 6, my), line, _message_col)
			my += 8
	var help: String = {"ask": "UP/DOWN CHOOSE   Z ANSWER   X WALK AWAY", "result": "Z CONTINUE",
		"reward": "Z CHOOSE", "upgrade": "Z BLESS IT", "clue": "Z REVEAL", "done": "Z CLOSE"}.get(_state, "")
	PixelFont.draw(_canvas, Vector2(screen.x - 10 - PixelFont.width_of(help), screen.y - 12), help, C_DIM)


## Wrong answer: the sprite flickers, stretches up like a guttering flame and
## comes apart into embers that drift away, while its glow dies.
func _draw_fading(c: Vector2, col: Color, frame: int) -> void:
	var t := clampf(_fade_t / FADE_TIME, 0.0, 1.0)
	UiKit.glow(_canvas, c, 60.0 * (1.0 - t), col, 1.2 * (1.0 - t))
	var body_a := clampf(1.0 - t * 1.4, 0.0, 1.0)
	if body_a > 0.0 and fmod(_fade_t, 0.12) > 0.03:   # flickering
		var stretch := 1.0 + t * 0.9
		var rows := 16
		for row in rows:
			var lift := (rows - row) * 4.0 * stretch - 64.0 * stretch + 28.0
			var wob := sin(row * 1.3 + _time * 18.0) * 7.0 * t
			var w := 64.0 * (1.0 - t * 0.5)
			var dst := Rect2(c + Vector2(-w / 2.0 + wob, lift - 36.0 * t), Vector2(w, 4.0 * stretch))
			_canvas.draw_texture_rect_region(Wisps.TEX, Rect2(dst.position.round(), dst.size),
				Rect2(frame * 16, _wisp.kind * 16 + row, 16, 1), Color(1, 1, 1, body_a))
	for i in 34:
		var ph := clampf(t * 1.3 - fmod(i * 0.037, 0.3), 0.0, 1.0)
		if ph <= 0.0:
			continue
		var ang := i * 2.39
		var p := c + Vector2(cos(ang) * (10.0 + ph * 40.0), -ph * 70.0 + sin(ang) * 10.0 + sin(_time * 4.0 + i) * 3.0)
		var a := 1.0 - ph
		_canvas.draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(col.lightened(0.3 + 0.4 * (i % 2)), a))
