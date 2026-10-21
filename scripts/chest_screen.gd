class_name ChestScreen
extends CanvasLayer
## The open-chest screen: the chest's contents on the left, your bag on the
## right. Arrows move (left/right switches side), A moves the selected item to
## the other side (TAKE from the chest, STORE into it), B closes.
## Matches, flares and lanterns are used the moment you take them.

var pfx := ""   ## input action prefix: "" for player 1, "p2_" for player 2

const CAPACITY := 6
const C_BG := Color(0.02, 0.01, 0.04, 0.96)
const C_TEXT := Color("e8dfc8")
const C_DIM := Color("8a8299")
const C_PICK := Color("ffd35a")
const C_ROW := Color("1e1830")
const C_ROW_PICK := Color("3a2f52")
const C_ROW_OTHER := Color("2a2240")
const C_BAD := Color("ff4a5a")
const ROW_H := 22

var player: Player
var inventory: Inventory
var chests: Chests
var hero: Hero   ## whose screen this is (shared systems get pointed at them)
var dialog: Dialog
var _canvas: Node2D
var _chest: Dictionary = {}
var _side := 0            # 0 = chest, 1 = bag
var _sel: Array[int] = [0, 0]
var _note := ""
var _note_col := C_TEXT
var _note_t := 0.0
var _opened_frame := -1
var _time := 0.0
var _dialog_frame := -10
var _open_t := 0.0     # time since this chest screen opened (lid/glow intro)


func setup(p: Player, inv: Inventory, ch: Chests, d: Dialog) -> void:
	player = p
	inventory = inv
	chests = ch
	dialog = d
	layer = 5
	visible = false
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_screen)
	add_child(_canvas)


func open_chest(chest: Dictionary) -> void:
	_chest = chest
	visible = true
	player.ui_lock = "chest"
	_side = 0 if not chest.items.is_empty() else 1
	_sel = [0, 0]
	_note = ""
	_open_t = 0.0
	_opened_frame = Engine.get_process_frames()


func _close() -> void:
	visible = false
	_chest = {}
	player.ui_lock = ""


func _process(delta: float) -> void:
	if not visible:
		return
	_note_t = maxf(_note_t - delta, 0.0)
	_time += delta
	_open_t += delta
	_canvas.queue_redraw()
	if dialog.is_open():
		_dialog_frame = Engine.get_process_frames()
		return
	if player.ui_lock == "":
		player.ui_lock = "chest"  # a message box just closed on top of us
	if Engine.get_process_frames() - _dialog_frame <= 1:
		return  # the press that closed it isn't meant for us
	if Engine.get_process_frames() == _opened_frame:
		return
	var count := _list_size(_side)
	if Input.is_action_just_pressed(pfx + "run") or Input.is_action_just_pressed(pfx + "inventory"):
		_close()
		return
	if Input.is_action_just_pressed(pfx + "move_left") or Input.is_action_just_pressed(pfx + "move_right"):
		_side = 1 - _side
		Sfx.play("ui_move")
	elif Input.is_action_just_pressed(pfx + "move_up"):
		_sel[_side] = posmod(_sel[_side] - 1, maxi(count, 1))
		Sfx.play("ui_move")
	elif Input.is_action_just_pressed(pfx + "move_down"):
		_sel[_side] = posmod(_sel[_side] + 1, maxi(count, 1))
		Sfx.play("ui_move")
	elif Input.is_action_just_pressed(pfx + "confirm"):
		if _side == 0:
			_take(_sel[0])
		else:
			_store(_sel[1])
	_sel[0] = clampi(_sel[0], 0, maxi(_chest.items.size() - 1, 0))


func _list_size(side: int) -> int:
	return _chest.items.size() if side == 0 else Inventory.SLOTS


func _say(text: String, col: Color = C_TEXT) -> void:
	_note = text
	_note_col = col
	_note_t = 2.5


func _take(i: int) -> void:
	if hero != null:
		Hero.bind_all(hero)
	Sfx.play("pickup")
	var items: Array = _chest.items
	if i >= items.size():
		return
	var st: Dictionary = items[i]
	var id: String = st.id
	if Items.is_ruby(id):
		inventory.rubies += int(st.qty)
		inventory.changed.emit()
		_say("+" + str(st.qty) + (" RUBIES" if st.qty > 1 else " RUBY"), C_PICK)
		Sfx.play("coin")
		items.remove_at(i)
		return
	if Items.uses_slot(id):
		if inventory.slot_for(id) == -1:
			_say("YOUR BAG IS FULL. STORE SOMETHING FIRST.", C_BAD)
			return
		var one := st.duplicate()
		one.qty = 1
		inventory.add_stack(one)
		_say("TOOK " + Items.with_article(id) + (" +" + str(Items.bonus(st)) if Items.bonus(st) > 0 else "") + ".")
	elif Items.kind(id) == "matches" and chests.lantern.room_for_matches() < int(Items.get_info(id).amount):
		# only part of the box fits: take what fits, the rest stays here
		var room := chests.lantern.room_for_matches()
		if room == 0:
			_say("YOUR MATCHBOX IS FULL (" + str(Lantern.MAX_MATCHES) + ").", C_BAD)
			return
		chests.lantern.add_matches(room)
		_say("+" + str(room) + " MATCH. THE BOX IS FULL.", C_PICK)
		st.qty -= 1
		if st.qty <= 0:
			items.remove_at(i)
		Chests.add_to_chest(items, "loose_match", {"id": "loose_match", "qty": int(Items.get_info(id).amount) - room})
		return
	else:
		var msg := chests.apply_free_item(id)
		if Items.kind(id) == "lantern":
			dialog.say(msg, id)
		else:
			_say(msg, C_PICK)
	st.qty -= 1
	if st.qty <= 0:
		items.remove_at(i)


func _store(i: int) -> void:
	Sfx.play("ui_select")
	var s := inventory.slots[i]
	if s.is_empty():
		return
	if not Chests.add_to_chest(_chest.items, s.id, s):
		_say("THE CHEST IS FULL.", C_BAD)
		return
	var id := inventory.remove_one(i)
	_say("STORED " + Items.with_article(id) + ".")


func _draw_row(r: Rect2, stack: Dictionary, picked: bool, other_picked: bool) -> void:
	_canvas.draw_rect(r, C_ROW_PICK if picked else (C_ROW_OTHER if other_picked else C_ROW))
	if picked:
		_canvas.draw_rect(Rect2(r.position, Vector2(2, r.size.y)), C_PICK)
	var icon_r := Rect2(r.position + Vector2(4, 2), Vector2(18, 18))
	UiKit.icon_frame(_canvas, icon_r, picked)
	if stack.is_empty():
		PixelFont.draw(_canvas, r.position + Vector2(28, 8), "EMPTY", C_DIM)
		return
	var lift := -1.0 if picked and fmod(_time, 0.8) < 0.4 else 0.0
	Items.draw_icon(_canvas, stack.id, Rect2(icon_r.position + Vector2(1, 1 + lift), Vector2(16, 16)))
	PixelFont.draw(_canvas, r.position + Vector2(28, 4), Items.label(stack),
		C_PICK if picked else C_TEXT)
	var sub := Items.short_stat_of(stack)
	if sub == "":
		var info := Items.get_info(stack.id)
		match info.kind:
			"matches": sub = str(info.amount) + (" MATCHES" if info.amount > 1 else " MATCH")
			"flare": sub = "MAPS A ROOM"
			_: sub = info.kind.to_upper()
	if stack.qty > 1:
		sub += "  X" + str(stack.qty)
	PixelFont.draw(_canvas, r.position + Vector2(28, 12), sub, C_DIM)


func _draw_screen() -> void:
	if _chest.is_empty():
		return
	var screen := _canvas.get_viewport_rect().size
	UiKit.backdrop(_canvas, screen)
	var purple: bool = _chest.get("purple", false)
	var glow_col := Color("c08aff") if purple else Color("ffcf6a")

	# --- The chest itself, centre: lid open, light spilling out ------------------------
	var mid := Vector2(screen.x / 2, 66)
	var burst := clampf(1.0 - _open_t / 0.6, 0.0, 1.0)   # bright flash as it opens
	UiKit.glow(_canvas, mid - Vector2(0, 8), 40 + burst * 30, glow_col, 1.0 + burst * 2.0 + 0.15 * sin(_time * 4.0))
	# light rays fanning up from the open lid
	for i in 5:
		var ang := -PI / 2 + (i - 2) * 0.32 + sin(_time * 0.8 + i) * 0.05
		var ln := 34.0 + 8.0 * sin(_time * 2.0 + i * 1.7)
		var from := mid + Vector2(0, -12)
		for k in int(ln / 3):
			var p := from + Vector2.from_angle(ang) * (k * 3.0)
			_canvas.draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(glow_col, 0.22 * (1.0 - k * 3.0 / ln)))
	UiKit.pedestal(_canvas, mid + Vector2(0, 26), 30, 5)
	Shadows.oval(_canvas, mid + Vector2(0, 24), 50)
	var dst := Rect2(mid - Vector2(32, 36), Vector2(64, 64))
	if purple:
		_canvas.draw_texture_rect_region(MasterChamber.MASTER_TEX, dst, Rect2(32, 8, 16, 16))
	else:
		_canvas.draw_texture_rect_region(Chests.PROPS_TEX, dst, Rect2(Chests.OPEN_SPRITE * 16, 0, 16, 16))
	# motes of light drifting up out of it
	for i in 14:
		var ph := fmod(_time * 0.5 + i * 0.137, 1.0)
		var x := mid.x - 18 + fmod(i * 23.7, 36.0) + sin(_time * 2.0 + i) * 3.0
		var y := mid.y - 14 - ph * 46.0
		_canvas.draw_rect(Rect2(Vector2(x, y).round(), Vector2(1, 1)), Color(glow_col.lightened(0.5), 1.0 - ph))

	# --- Chest contents, left ----------------------------------------------------------
	var left := Rect2(8, 12, 124, 154)
	UiKit.panel(_canvas, left, "CHEST", _side == 0)
	PixelFont.draw(_canvas, left.position + Vector2(left.size.x - 22, 6),
		str(_chest.items.size()) + "/" + str(CAPACITY), C_DIM)
	if _chest.items.is_empty():
		PixelFont.draw(_canvas, left.position + Vector2(44, 70), "EMPTY", C_DIM)
	for i in _chest.items.size():
		_draw_row(Rect2(left.position + Vector2(5, 13 + i * (ROW_H + 1)), Vector2(left.size.x - 10, ROW_H)),
			_chest.items[i], _side == 0 and i == _sel[0], false)

	# --- Your bag, right ----------------------------------------------------------------
	var right := Rect2(228, 12, 124, 154)
	UiKit.panel(_canvas, right, "BAG", _side == 1)
	for i in Inventory.SLOTS:
		_draw_row(Rect2(right.position + Vector2(5, 13 + i * (ROW_H + 1)), Vector2(right.size.x - 10, ROW_H)),
			inventory.slots[i], _side == 1 and i == _sel[1], false)
	var stats := "ATK " + str(inventory.attack()) + "   DEF " + str(inventory.defense())
	PixelFont.draw(_canvas, Vector2(right.position.x + 8, right.end.y - 12), stats, C_TEXT)
	# little hero, showing off what you're wearing
	HeroLook.use(player)
	HeroLook.draw(_canvas, Vector2(right.end.x - 26, right.end.y - 34), 1.0, 0, 0,
		inventory.best_id("armor", "def"), inventory.best_id("weapon", "atk"))

	# arrows between the two lists show which way Z moves things
	var arrow_y := 112.0
	var ax := screen.x / 2
	var dir := 1.0 if _side == 0 else -1.0
	var pulse := roundf(sin(_time * 6.0) * 1.5)
	for k in 3:
		var px := ax + dir * (k * 6 - 6 + pulse)
		for j in 3:
			_canvas.draw_rect(Rect2(px - dir * j, arrow_y - j, 1, 1 + j * 2), Color(C_PICK, 0.5 + 0.25 * k))
	var verb := "TAKE" if _side == 0 else "STORE"
	PixelFont.draw(_canvas, Vector2(floorf(ax - PixelFont.width_of(verb) / 2.0), arrow_y + 8), verb, C_PICK)

	# --- Detail strip, bottom ---------------------------------------------------------
	var det := Rect2(8, 172, 344, 42)
	UiKit.panel(_canvas, det)
	var target: Dictionary = {}
	if _side == 0 and _sel[0] < _chest.items.size():
		target = _chest.items[_sel[0]]
	elif _side == 1:
		target = inventory.slots[_sel[1]]
	if _note_t > 0.0:
		PixelFont.draw(_canvas, det.position + Vector2(8, 17), _note, Color(_note_col, clampf(_note_t / 0.4, 0.0, 1.0)))
	elif not target.is_empty():
		Items.draw_mid(_canvas, target.id, Rect2(det.position + Vector2(6, 5), Vector2(32, 32)))
		PixelFont.draw(_canvas, det.position + Vector2(44, 7), Items.display_name(target.id), C_PICK)
		var y := det.position.y + 16
		for line in Dialog.wrap_text(Items.get_info(target.id).desc, 290):
			PixelFont.draw(_canvas, Vector2(det.position.x + 44, y), line, C_TEXT)
			y += 7
	var help := ("Z TAKE" if _side == 0 else "Z STORE") + "   ARROWS MOVE   X CLOSE"
	PixelFont.draw(_canvas, Vector2(floorf((screen.x - PixelFont.width_of(help)) / 2), screen.y - 12), help, C_DIM)
