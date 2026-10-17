class_name TradeScreen
extends CanvasLayer
## Swapping things between the two players. Stand next to your partner and
## press T (player 2: J; a controller: X or Y) -- both bags side by side:
## yours on the left, theirs on the right. Pick something and press A to hand
## it across (or take it). Matches go one at a time. B closes.
## Your partner holds still while you trade.

var pfx := ""   ## input action prefix: "" for player 1, "p2_" for player 2

const C_TEXT := Color("e8dfc8")
const C_DIM := Color("8a8299")
const C_PICK := Color("ffd35a")
const C_ROW := Color("1e1830")
const C_ROW_PICK := Color("3a2f52")
const C_BAD := Color("ff4a5a")
const C_GOOD := Color("7dff9a")
const ROWS := 6   # 4 slots, matches, rubies

var hero: Hero
var other: Hero
var _canvas: Node2D
var _side := 0
var _sel: Array[int] = [0, 0]
var _note := ""
var _note_col := C_TEXT
var _note_t := 0.0
var _time := 0.0
var _opened_frame := -1


func setup(h: Hero) -> void:
	hero = h
	layer = 5
	visible = false
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_screen)
	add_child(_canvas)


func open(partner: Hero) -> void:
	other = partner
	visible = true
	hero.player.ui_lock = "trade"
	other.player.ui_lock = "traded"
	_side = 0
	_sel = [0, 0]
	_note = ""
	_opened_frame = Engine.get_process_frames()
	Sfx.play("ui_select")


func _close() -> void:
	visible = false
	if hero != null and is_instance_valid(hero.player):
		hero.player.ui_lock = ""
	if other != null and is_instance_valid(other.player) and other.player.ui_lock == "traded":
		other.player.ui_lock = ""
	Sfx.play("ui_back")


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_note_t = maxf(_note_t - delta, 0.0)
	_canvas.queue_redraw()
	if other == null or not Hero.all.has(other) or not other.alive():
		_close()
		return
	if Engine.get_process_frames() == _opened_frame:
		return
	if Input.is_action_just_pressed(pfx + "run") or Input.is_action_just_pressed(pfx + "trade") \
			or Input.is_action_just_pressed(pfx + "inventory"):
		_close()
	elif Input.is_action_just_pressed(pfx + "move_left") or Input.is_action_just_pressed(pfx + "move_right"):
		_side = 1 - _side
		Sfx.play("ui_move")
	elif Input.is_action_just_pressed(pfx + "move_up"):
		_sel[_side] = posmod(_sel[_side] - 1, ROWS)
		Sfx.play("ui_move")
	elif Input.is_action_just_pressed(pfx + "move_down"):
		_sel[_side] = posmod(_sel[_side] + 1, ROWS)
		Sfx.play("ui_move")
	elif Input.is_action_just_pressed(pfx + "confirm"):
		_move()


## Hands the selected thing to the other side.
func _move() -> void:
	var from: Hero = hero if _side == 0 else other
	var to: Hero = other if _side == 0 else hero
	var i := _sel[_side]
	if i == Inventory.SLOTS + 1:   # rubies: a handful (5) at a time
		var n := mini(5, from.inventory.rubies)
		if n <= 0:
			_say("NO RUBIES TO GIVE.", C_BAD)
			return
		from.inventory.rubies -= n
		to.inventory.rubies += n
		from.inventory.changed.emit()
		to.inventory.changed.emit()
		_say(("GAVE " if _side == 0 else "TOOK ") + str(n) + (" RUBIES." if n > 1 else " RUBY."), C_GOOD)
		Sfx.play("coin")
		return
	if i == Inventory.SLOTS:   # matches, one at a time
		if from.lantern.matches <= 0:
			_say("NO MATCHES TO GIVE.", C_BAD)
			return
		if to.lantern.add_matches(1) == 0:
			_say("THEIR MATCHBOX IS FULL.", C_BAD)
			return
		from.lantern.matches -= 1
		_say("HANDED OVER A MATCH." if _side == 0 else "TOOK A MATCH.", C_GOOD)
		Sfx.play("pickup_match")
		return
	var st: Dictionary = from.inventory.slots[i]
	if st.is_empty():
		_say("NOTHING THERE.", C_DIM)
		return
	var id: String = st.id
	if to.inventory.slot_for(id) == -1:
		_say(("THEIR" if _side == 0 else "YOUR") + " BAG IS FULL.", C_BAD)
		Sfx.play("ui_deny")
		return
	if Items.stacks(id):
		from.inventory.remove_one(i)
		to.inventory.add(id, 1)
	else:
		to.inventory.add_stack(from.inventory.take_slot(i))
	_say(("GAVE " if _side == 0 else "TOOK ") + Items.with_article(id) + ".", C_GOOD)
	Sfx.play("pickup")


func _say(text: String, col: Color) -> void:
	_note = text
	_note_col = col
	_note_t = 2.0


func _draw_screen() -> void:
	if other == null:
		return
	var screen := _canvas.get_viewport_rect().size
	UiKit.backdrop(_canvas, screen)
	var title := "TRADE"
	PixelFont.draw(_canvas, Vector2(floorf((screen.x - PixelFont.width_of(title)) / 2.0), 6), title, C_PICK)
	for s in 2:
		var h: Hero = hero if s == 0 else other
		var r := Rect2(8 + s * 176, 16, 168, 196)
		UiKit.panel(_canvas, r, "YOU" if s == 0 else "PARTNER", _side == s)
		# the hero, small, at the top
		HeroLook.use(h.player)
		HeroLook.draw(_canvas, r.position + Vector2(8, 10), 1.0, 0, 0, h.player.armor_id, h.player.weapon_id)
		var hp := str(h.inventory.health) + "/" + str(h.inventory.max_health)
		PixelFont.draw(_canvas, r.position + Vector2(30, 16), "HEARTS " + hp, C_TEXT)
		PixelFont.draw(_canvas, r.position + Vector2(30, 26), "ATK " + str(h.inventory.attack()) + "  DEF " + str(h.inventory.defense()), C_DIM)
		for i in ROWS:
			var row := Rect2(r.position + Vector2(6, 40 + i * 25), Vector2(r.size.x - 12, 23))
			var picked := _side == s and _sel[s] == i
			_canvas.draw_rect(row, C_ROW_PICK if picked else C_ROW)
			if picked:
				_canvas.draw_rect(Rect2(row.position, Vector2(2, row.size.y)), C_PICK)
			if i == Inventory.SLOTS + 1:
				Items.draw_icon(_canvas, "ruby", Rect2(row.position + Vector2(5, 3), Vector2(16, 16)))
				PixelFont.draw(_canvas, row.position + Vector2(26, 8), "RUBIES X" + str(h.inventory.rubies), C_PICK if picked else C_TEXT)
				continue
			if i == Inventory.SLOTS:
				Items.draw_icon(_canvas, "matches", Rect2(row.position + Vector2(5, 3), Vector2(16, 16)))
				PixelFont.draw(_canvas, row.position + Vector2(26, 8), "MATCHES X" + str(h.lantern.matches), C_PICK if picked else C_TEXT)
				continue
			var st: Dictionary = h.inventory.slots[i]
			if st.is_empty():
				PixelFont.draw(_canvas, row.position + Vector2(26, 8), "EMPTY", C_DIM)
				continue
			Items.draw_icon(_canvas, st.id, Rect2(row.position + Vector2(5, 3), Vector2(16, 16)))
			PixelFont.draw(_canvas, row.position + Vector2(26, 4), Items.label(st), C_PICK if picked else C_TEXT)
			var sub := Items.short_stat_of(st)
			if st.qty > 1:
				sub += ("  " if sub != "" else "") + "X" + str(st.qty)
			PixelFont.draw(_canvas, row.position + Vector2(26, 13), sub, C_DIM)
	# the arrow showing which way things go
	var ay := 112.0
	var arrow := ">>" if _side == 0 else "<<"
	PixelFont.draw(_canvas, Vector2(floorf(screen.x / 2.0) - 4, ay), arrow, C_PICK)
	if _note_t > 0.0:
		var nw := PixelFont.width_of(_note) + 12
		_canvas.draw_rect(Rect2(floorf((screen.x - nw) / 2), 214, nw, 12), Color(0.03, 0.02, 0.05, 0.92))
		PixelFont.draw(_canvas, Vector2(floorf((screen.x - nw) / 2) + 6, 217), _note, Color(_note_col, clampf(_note_t / 0.4, 0.0, 1.0)))
	var help := "ENTER HAND IT OVER   ARROWS CHOOSE   / CLOSE" if pfx == "p2_" else "Z HAND IT OVER   ARROWS CHOOSE   X CLOSE"
	PixelFont.draw(_canvas, Vector2(screen.x - 10 - PixelFont.width_of(help), screen.y - 10), help, C_DIM)
