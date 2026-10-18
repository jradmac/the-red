class_name Bag
extends CanvasLayer
## The bag screen (I / gamepad Start). Left: your hero on a pedestal, wearing
## and carrying what's in the bag (left/right turns him). Middle: the 4 slots.
## Right: the highlighted item up close, plus your lantern and supplies.
## Highlight a slot, then A (Z) uses it if it's a potion and B (X) drops it
## at your feet. I / Start closes. The lantern keeps burning while it's open.

var pfx := ""   ## input action prefix: "" for player 1, "p2_" for player 2

const C_BG := Color("0b0812")
const C_TEXT := Color("e8dfc8")
const C_DIM := Color("8a8299")
const C_PICK := Color("ffd35a")
const C_SLOT := Color("1e1830")
const C_SLOT_PICK := Color("3a2f52")
const C_HEART := Color("e0453f")
const C_HEART_EMPTY := Color("3a2433")

var player: Player
var inventory: Inventory
var lantern: Lantern
var pickups: Pickups
var dialog: Dialog
var _canvas: Node2D
var _sel := 0
var _opened_frame := -1
var _note := ""
var _note_col := C_TEXT
var _note_t := 0.0
var flares: Flares   ## set by main (for the supplies count)
var _time := 0.0
var _turn := 0            # index into TURN_ORDER
var _guide := -1          # >= 0: showing page _guide of Lume's guide
var _menu := -1           # >= 0: a button on the bottom row is selected (see BUTTONS)
var _settings := false    # the settings panel is open
var _set_sel := 0         # 0 sound effects, 1 music, 2 3D world, 3 back
var save_game: Callable   ## set by main: saves the run, returns true if it worked
var leave_game: Callable  ## set by main: this player leaves (two players only)
var hero: Hero
const SOLO_BUTTONS := ["SAVE GAME", "SAVE + QUIT", "SETTINGS"]
const COOP_BUTTONS := ["SAVE GAME", "LEAVE GAME", "SETTINGS"]
var BUTTONS: Array:
	get:
		return COOP_BUTTONS if Hero.all.size() > 1 else SOLO_BUTTONS
var _turn_t := 0.0        # auto-turn timer (paused for a while after you turn him)
const TURN_ORDER := [0, 3, 1, 2]   # facing down, right, up, left


func setup(p: Player, inv: Inventory, l: Lantern, pk: Pickups, d: Dialog) -> void:
	player = p
	inventory = inv
	lantern = l
	pickups = pk
	dialog = d
	layer = 5
	visible = false
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_bag)
	add_child(_canvas)


var _dialog_frame := -10
var block_until := -1        ## set by main: the bag can't open before this frame (a join press)
var on_pad := false          ## set by main: this player holds a controller (button names)
var _leave_armed := false    # LEAVE GAME asks once more before it really leaves


func _process(delta: float) -> void:
	if not visible:
		if Input.is_action_just_pressed(pfx + "inventory") and player.can_act() \
				and Engine.get_process_frames() > block_until:
			visible = true
			Sfx.play("bag_open")
			player.ui_lock = "bag"
			_note_t = 0.0
			_opened_frame = Engine.get_process_frames()
		return
	_note_t = maxf(_note_t - delta, 0.0)
	_time += delta
	_turn_t += delta
	if _turn_t > 2.2:
		_turn_t = 0.0
		_turn = (_turn + 1) % 4
	if dialog.is_open():
		_dialog_frame = Engine.get_process_frames()
		return  # a message from using an item is showing on top
	if Engine.get_process_frames() - _dialog_frame <= 1:
		return  # the press that closed that message isn't meant for the bag
	if player.ui_lock == "":
		player.ui_lock = "bag"
	_canvas.queue_redraw()
	if Engine.get_process_frames() == _opened_frame:
		return
	_browse()


## The button or key this player presses for an action, for the help lines.
func _k(action: String) -> String:
	if on_pad:
		return {"confirm": "A", "run": "B", "inventory": "START", "guide": "B"}.get(action, "?")
	if pfx == "p2_":
		return {"confirm": "ENTER", "run": "/", "inventory": ";", "guide": "P"}.get(action, "?")
	return {"confirm": "Z", "run": "X", "inventory": "I", "guide": "G"}.get(action, "?")


func _close() -> void:
	Sfx.play("bag_close")
	_menu = -1
	_settings = false
	_leave_armed = false
	visible = false
	player.ui_lock = ""


func _say(text: String, col: Color = C_TEXT) -> void:
	_note = text
	_note_col = col
	_note_t = 2.0


func _browse() -> void:
	if _guide >= 0:
		_browse_guide()
		return
	if _settings:
		_browse_settings()
		return
	if _menu >= 0:
		_browse_menu()
		return
	var slot := inventory.slots[_sel]
	if Input.is_action_just_pressed(pfx + "guide"):
		_guide = 0
		Sfx.play("page")
		return
	if Input.is_action_just_pressed(pfx + "inventory"):
		_close()
	elif Input.is_action_just_pressed(pfx + "move_up"):
		_sel = posmod(_sel - 1, Inventory.SLOTS)
		Sfx.play("ui_move")
	elif Input.is_action_just_pressed(pfx + "move_down"):
		if _sel == Inventory.SLOTS - 1:
			_menu = 0   # down past the last slot: the buttons along the bottom
		else:
			_sel += 1
		Sfx.play("ui_move")
	elif Input.is_action_just_pressed(pfx + "move_left") or Input.is_action_just_pressed(pfx + "move_right"):
		_turn = posmod(_turn + (1 if Input.is_action_just_pressed(pfx + "move_right") else -1), 4)
		_turn_t = -3.0   # hold this pose a while
	elif Input.is_action_just_pressed(pfx + "confirm") and not slot.is_empty():
		var id: String = slot.id
		if Items.kind(id) == "key":
			_say("KEYS ARE USED ON DOORS. FACE ONE AND PRESS Z.", Color("ff4a5a"))
			return
		if Items.kind(id) == "bomb":
			# plant it and get out of the menu: the fuse is already burning
			_close()
			pickups.picked.emit(inventory.use_slot(_sel))
			return
		if not (Items.kind(id) in ["potion", "tool"]):
			_say("ONLY POTIONS AND TOOLS CAN BE USED.", Color("ff4a5a"))
			Sfx.play("ui_deny")
			return
		var before := int(slot.get("qty", 1))
		var msg := inventory.use_slot(_sel)
		var used := inventory.slots[_sel].is_empty() or int(inventory.slots[_sel].get("qty", 1)) < before
		if Items.kind(id) == "tool" and used:
			_close()   # a tool worked: out of the bag, to see what it did
		if msg != "":
			player.ui_lock = ""
			dialog.say(msg, id)
	elif Input.is_action_just_pressed(pfx + "run") and slot.is_empty():
		_close()   # B (back) on an empty slot: out of the bag
	elif Input.is_action_just_pressed(pfx + "run") and not slot.is_empty():
		if pickups.has_item_at(player.cell):
			_say("SOMETHING IS ALREADY LYING HERE.", Color("ff4a5a"))
			return
		var stack := inventory.take_slot(_sel)
		pickups.drop(player.cell, stack)
		_say("DROPPED " + Items.with_article(stack.id, stack.qty) + ".")


## The bottom row: SAVE GAME, SAVE & QUIT, SETTINGS.
func _browse_menu() -> void:
	var was_armed := _leave_armed
	for a in ["inventory", "move_up", "move_down", "move_left", "move_right", "run"]:
		if Input.is_action_just_pressed(pfx + a):
			_leave_armed = false   # anything else: never mind
	if Input.is_action_just_pressed(pfx + "inventory"):
		_close()
	elif Input.is_action_just_pressed(pfx + "move_up") or Input.is_action_just_pressed(pfx + "run"):
		_menu = -1
		_sel = Inventory.SLOTS - 1
		Sfx.play("ui_move")
	elif Input.is_action_just_pressed(pfx + "move_left"):
		_menu = posmod(_menu - 1, BUTTONS.size())
		Sfx.play("ui_move")
	elif Input.is_action_just_pressed(pfx + "move_right"):
		_menu = posmod(_menu + 1, BUTTONS.size())
		Sfx.play("ui_move")
	elif Input.is_action_just_pressed(pfx + "confirm"):
		match _menu:
			0, 1:
				if _menu == 1 and Hero.all.size() > 1:
					if not was_armed:
						_leave_armed = true   # are you sure?
						_say(_k("confirm") + " AGAIN TO LEAVE THE GAME - " + _k("inventory") + " TO KEEP PLAYING", Color("ff8a5a"))
						Sfx.play("ui_deny")
						return
					_close()
					if leave_game.is_valid():
						leave_game.call()
					return
				var ok: bool = save_game.is_valid() and save_game.call()
				if not ok:
					_say("YOU CAN'T SAVE RIGHT NOW.", Color("ff4a5a"))
					Sfx.play("ui_deny")
					return
				Sfx.play("correct", -6.0)
				if _menu == 1:
					get_tree().quit()
					return
				_say("GAME SAVED. YOU CAN QUIT AND COME BACK ANY TIME.", Color("7dff9a"))
			2:
				_settings = true
				_set_sel = 0
				Sfx.play("page")


## SETTINGS: two volume bars. Up/down choose, left/right adjust.
func _browse_settings() -> void:
	var v := Sfx.get_volumes()
	if Input.is_action_just_pressed(pfx + "run") or Input.is_action_just_pressed(pfx + "guide") \
			or (Input.is_action_just_pressed(pfx + "confirm") and _set_sel == 3):
		_settings = false
		Sfx.play("ui_back")
	elif Input.is_action_just_pressed(pfx + "inventory"):
		_close()
	elif Input.is_action_just_pressed(pfx + "move_up"):
		_set_sel = posmod(_set_sel - 1, 4)
		Sfx.play("ui_move")
	elif Input.is_action_just_pressed(pfx + "move_down"):
		_set_sel = posmod(_set_sel + 1, 4)
		Sfx.play("ui_move")
	elif Input.is_action_just_pressed(pfx + "move_left") or Input.is_action_just_pressed(pfx + "move_right"):
		var step := 0.1 if Input.is_action_just_pressed(pfx + "move_right") else -0.1
		if _set_sel == 0:
			Sfx.set_volumes(snappedf(v.x + step, 0.1), v.y)
			Sfx.play("pickup")   # so you hear the new level
		elif _set_sel == 1:
			Sfx.set_volumes(v.x, snappedf(v.y + step, 0.1))
			Sfx.play("ui_move")
		elif _set_sel == 2:
			_toggle_3d()
	elif Input.is_action_just_pressed(pfx + "confirm") and _set_sel == 2:
		_toggle_3d()


func _toggle_3d() -> void:
	View3D.set_enabled(not View3D.enabled)
	var m := get_tree().current_scene
	var v: View3D = m.get("view3d")
	var coop: CoopView = m.get("coop")
	if v != null:
		v.set_active(View3D.enabled and not (coop != null and coop.active))
	Sfx.play("ui_move")


func _draw_settings(screen: Vector2) -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, screen), Color(0.02, 0.01, 0.05, 0.88))
	var r := Rect2(70, 40, screen.x - 140, 160)
	UiKit.panel(_canvas, r, "SETTINGS")
	var v := Sfx.get_volumes()
	var rows := [["SOUND EFFECTS", v.x], ["MUSIC", v.y]]
	for i in 2:
		var y := r.position.y + 22 + i * 34
		var picked := _set_sel == i
		PixelFont.draw(_canvas, Vector2(r.position.x + 14, y), rows[i][0], C_PICK if picked else C_TEXT)
		var pct := str(int(round(float(rows[i][1]) * 100))) + "%"
		PixelFont.draw(_canvas, Vector2(r.end.x - 14 - PixelFont.width_of(pct), y), pct, C_PICK if picked else C_DIM)
		var bar := Rect2(r.position.x + 14, y + 11, r.size.x - 28, 6)
		_canvas.draw_rect(bar, Color("1e1830"))
		_canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(rows[i][1]), bar.size.y)),
			Color("ffd35a") if picked else Color("8a7aff"))
		for k in 11:   # ticks every 10%
			_canvas.draw_rect(Rect2(bar.position + Vector2(floorf(bar.size.x * k / 10.0), 7), Vector2(1, 2)), C_DIM)
		if picked:
			PixelFont.draw(_canvas, Vector2(bar.position.x - 9, bar.position.y - 1), "<", C_PICK)
			PixelFont.draw(_canvas, Vector2(bar.end.x + 4, bar.position.y - 1), ">", C_PICK)
	var y3 := r.position.y + 22 + 2 * 34
	var on3 := "3D WORLD"
	var val := "ON" if View3D.enabled else "OFF"
	PixelFont.draw(_canvas, Vector2(r.position.x + 14, y3), on3, C_PICK if _set_sel == 2 else C_TEXT)
	var vs := ("< " + val + " >") if _set_sel == 2 else val
	PixelFont.draw(_canvas, Vector2(r.end.x - 14 - PixelFont.width_of(vs), y3), vs, C_PICK if _set_sel == 2 else C_DIM)
	var back := "BACK"
	PixelFont.draw(_canvas, Vector2(floorf(r.get_center().x - PixelFont.width_of(back) / 2.0), r.end.y - 18),
		("> " + back + " <") if _set_sel == 3 else back, C_PICK if _set_sel == 3 else C_TEXT)
	var help := "UP/DOWN CHOOSE   LEFT/RIGHT ADJUST   X BACK"
	PixelFont.draw(_canvas, Vector2(screen.x - 10 - PixelFont.width_of(help), screen.y - 12), help, C_DIM)


func _browse_guide() -> void:
	if Input.is_action_just_pressed(pfx + "move_right") or Input.is_action_just_pressed(pfx + "move_down") \
			or Input.is_action_just_pressed(pfx + "confirm"):
		_guide = (_guide + 1) % Lore.GUIDE.size()
		Sfx.play("page")
	elif Input.is_action_just_pressed(pfx + "move_left") or Input.is_action_just_pressed(pfx + "move_up"):
		_guide = posmod(_guide - 1, Lore.GUIDE.size())
		Sfx.play("page")
	elif Input.is_action_just_pressed(pfx + "guide") or Input.is_action_just_pressed(pfx + "run"):
		_guide = -1
	elif Input.is_action_just_pressed(pfx + "inventory"):
		_guide = -1
		_close()


## Lume's guide: one page per topic, Lume in the corner.
func _draw_guide(screen: Vector2) -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, screen), Color(0.02, 0.01, 0.05, 0.9))
	var r := Rect2(16, 14, screen.x - 32, screen.y - 40)
	var page: Array = Lore.GUIDE[_guide]
	UiKit.panel(_canvas, r, "ASK " + Lore.COMPANION)
	# Lume, big, in the top-left
	var pr := Rect2(r.position + Vector2(10, 14), Vector2(44, 48))
	UiKit.glow(_canvas, pr.get_center(), 26, Color("ffb060"), 0.6 + 0.1 * sin(_time * 3.0))
	Companion.draw_portrait(_canvas, pr.position + Vector2(4, 4 + roundf(sin(_time * 2.5))), 3.0, _time, false)
	# page title and dots
	PixelFont.draw(_canvas, r.position + Vector2(64, 16), page[0], C_PICK)
	for i in Lore.GUIDE.size():
		var dot := Rect2(r.position + Vector2(64 + i * 6, 27), Vector2(3, 3))
		_canvas.draw_rect(dot, C_PICK if i == _guide else Color("3a2f52"))
	var y := r.position.y + 38
	if page[1] == "":
		# the Commandments page
		for c in Lore.COMMANDMENTS:
			PixelFont.draw(_canvas, Vector2(r.position.x + 88 - PixelFont.width_of(c[0]), y), c[0], C_PICK)
			for line in Dialog.wrap_text(c[1], int(r.size.x) - 104):
				PixelFont.draw(_canvas, Vector2(r.position.x + 94, y), line, C_TEXT)
				y += 8
			y += 6
	else:
		for line in Dialog.wrap_text(page[1], int(r.size.x) - 78):
			PixelFont.draw(_canvas, Vector2(r.position.x + 64, y), line, C_TEXT)
			y += 10
	var help := "< > TURN THE PAGE   %s BACK TO THE BAG   %s CLOSE" % [_k("guide") if not on_pad else _k("run"), _k("inventory")]
	PixelFont.draw(_canvas, Vector2(screen.x - 10 - PixelFont.width_of(help), screen.y - 12), help, C_DIM)


func _draw_bag() -> void:
	var screen := _canvas.get_viewport_rect().size
	UiKit.backdrop(_canvas, screen)
	var armor := inventory.best_id("armor", "def")
	var weapon := inventory.best_id("weapon", "atk")

	# --- Hero ----------------------------------------------------------------
	var hero_r := Rect2(8, 12, 112, 196)
	UiKit.panel(_canvas, hero_r, "HERO")
	var center := Vector2(hero_r.get_center().x, hero_r.position.y + 112)
	UiKit.glow(_canvas, center - Vector2(0, 44), 52, Color("ffb060"), 0.9 + 0.1 * sin(_time * 3.0))
	UiKit.pedestal(_canvas, center + Vector2(0, 4), 30, 6)
	Shadows.oval(_canvas, center + Vector2(0, 1), 40)
	var facing: int = TURN_ORDER[_turn]
	var bob := -1.0 if fmod(_time, 1.6) < 0.8 else 0.0   # breathing
	HeroLook.use(player)
	HeroLook.draw_big(_canvas, center - Vector2(32, 92), facing, armor, weapon, bob * 2.0, Vector2(0, bob))
	# hearts + stats under the pedestal
	var hy := hero_r.position.y + 128
	for i in inventory.max_health:
		Hud.draw_heart(_canvas, Vector2(hero_r.position.x + 14 + i * 8.5, hy),
			C_HEART if i < inventory.health else C_HEART_EMPTY)
	var stats := "ATK " + str(inventory.attack()) + "    DEF " + str(inventory.defense())
	PixelFont.draw(_canvas, Vector2(floorf(center.x - PixelFont.width_of(stats) / 2.0), hy + 10), stats, C_TEXT)
	_equip_line(Vector2(hero_r.position.x + 8, hy + 24), "HELD", weapon, "BARE HANDS")
	_equip_line(Vector2(hero_r.position.x + 8, hy + 40), "WORN", armor, "NO ARMOR")
	PixelFont.draw(_canvas, Vector2(hero_r.position.x + 8, hero_r.end.y - 10), "< > TURN", Color(C_DIM, 0.7))

	# --- Slots -----------------------------------------------------------------
	var slots_r := Rect2(128, 12, 108, 196)
	UiKit.panel(_canvas, slots_r, "BAG")
	for i in Inventory.SLOTS:
		var r := Rect2(slots_r.position + Vector2(6, 12 + i * 44), Vector2(slots_r.size.x - 12, 40))
		var picked := i == _sel and _menu < 0
		_canvas.draw_rect(r, C_SLOT_PICK if picked else C_SLOT)
		if picked:
			_canvas.draw_rect(Rect2(r.position, Vector2(2, r.size.y)), C_PICK)
		var icon_r := Rect2(r.position + Vector2(6, 6), Vector2(28, 28))
		UiKit.icon_frame(_canvas, icon_r, picked)
		var s := inventory.slots[i]
		if s.is_empty():
			PixelFont.draw(_canvas, r.position + Vector2(40, 17), "EMPTY", C_DIM)
			continue
		var lift := -1.0 if picked and fmod(_time, 0.8) < 0.4 else 0.0
		Items.draw_icon(_canvas, s.id, Rect2(icon_r.position + Vector2(6, 6 + lift), Vector2(16, 16)))
		if Items.stacks(s.id):
			# how many are in this slot (up to 3), on the icon's corner
			var badge := str(s.qty)
			var bp := icon_r.end - Vector2(PixelFont.width_of(badge) + 3, 8)
			_canvas.draw_rect(Rect2(bp - Vector2(1, 1), Vector2(PixelFont.width_of(badge) + 2, 7)), Color(0, 0, 0, 0.75))
			PixelFont.draw(_canvas, bp, badge, C_PICK if s.qty >= Inventory.MAX_STACK else C_TEXT)
		var name_lines := Dialog.wrap_text(Items.label(s), r.size.x - 44)
		var ty := r.position.y + 6
		for line in name_lines:
			PixelFont.draw(_canvas, Vector2(r.position.x + 40, ty), line, C_PICK if picked else C_TEXT)
			ty += 7
		var sub := Items.short_stat_of(s)
		if Items.stacks(s.id):
			sub += ("  " if sub != "" else "") + str(s.qty) + " OF " + str(Inventory.MAX_STACK)
		if sub == "":
			sub = Items.kind(s.id).to_upper()
		PixelFont.draw(_canvas, Vector2(r.position.x + 40, ty + 1), sub, C_DIM)
		if s.id == weapon:
			UiKit.chip(_canvas, Vector2(r.position.x + 40, r.end.y - 10), "HELD", Color("ffb060"))
		elif s.id == armor:
			UiKit.chip(_canvas, Vector2(r.position.x + 40, r.end.y - 10), "WORN", Color("8ab4ff"))

	# --- Selected item ------------------------------------------------------------
	var d := Rect2(244, 12, 108, 128)
	UiKit.panel(_canvas, d, "ITEM")
	var sel := inventory.slots[_sel]
	if not sel.is_empty():
		var ic := Vector2(d.get_center().x, d.position.y + 30)
		UiKit.glow(_canvas, ic, 22, Color("8a7aff"), 0.8)
		var float_y := roundf(sin(_time * 2.5) * 1.5)
		Shadows.oval(_canvas, ic + Vector2(0, 19), 18, 0.8)
		Items.draw_icon(_canvas, sel.id, Rect2(ic - Vector2(16, 16 - float_y), Vector2(32, 32)))
		var y := d.position.y + 56
		for line in Dialog.wrap_text(Items.label(sel), 96):
			PixelFont.draw(_canvas, Vector2(d.position.x + 6, y), line, C_PICK)
			y += 7
		var sl := Items.stat_line(sel.id)
		if Items.bonus(sel) > 0:
			sl = Items.kind(sel.id).to_upper() + "   " + Items.short_stat_of(sel) + "  (+" + str(Items.bonus(sel)) + ")"
		PixelFont.draw(_canvas, Vector2(d.position.x + 6, y), sl, C_DIM)
		y += 11
		for line in Dialog.wrap_text(Items.get_info(sel.id).desc, 96):
			PixelFont.draw(_canvas, Vector2(d.position.x + 6, y), line, C_TEXT)
			y += 7
	else:
		PixelFont.draw(_canvas, d.position + Vector2(36, 60), "NOTHING", C_DIM)

	# --- Supplies --------------------------------------------------------------------
	var sup := Rect2(244, 148, 108, 60)
	UiKit.panel(_canvas, sup, "SUPPLIES")
	var lantern_name := "OLD LANTERN" if lantern.lantern_id == "" else Items.display_name(lantern.lantern_id)
	PixelFont.draw(_canvas, sup.position + Vector2(6, 10), lantern_name, C_TEXT)
	var frac := lantern.fraction()
	var blue := lantern.blue_left > 0.0 and lantern.state == Lantern.State.LIT
	UiKit.bar(_canvas, Rect2(sup.position + Vector2(6, 19), Vector2(sup.size.x - 12, 4)), frac,
		Color("6f9cff") if blue else (Color("f5c542") if frac > 0.25 else Color("e0453f")))
	if blue:
		var tag := "BLUE " + str(int(ceil(lantern.blue_left)))
		PixelFont.draw(_canvas, Vector2(sup.end.x - 6 - PixelFont.width_of(tag), sup.position.y + 10), tag, Color("8fb4ff"))
	Items.draw_icon(_canvas, "matches", Rect2(sup.position + Vector2(4, 28), Vector2(16, 16)))
	PixelFont.draw(_canvas, sup.position + Vector2(21, 34), "X" + str(lantern.matches) + "/" + str(Lantern.MAX_MATCHES), C_TEXT)
	if flares != null:
		Items.draw_icon(_canvas, "flare", Rect2(sup.position + Vector2(52, 28), Vector2(16, 16)))
		PixelFont.draw(_canvas, sup.position + Vector2(69, 34), "X" + str(flares.count), C_TEXT)
	Items.draw_icon(_canvas, "ruby", Rect2(sup.position + Vector2(4, 42), Vector2(16, 16)))
	PixelFont.draw(_canvas, sup.position + Vector2(21, 48), "X" + str(inventory.rubies) + " RUBIES", C_TEXT)

	# --- Footer -------------------------------------------------------------------------
	# the bottom row: save, save & quit, settings
	var bw := 100.0
	for i in BUTTONS.size():
		var br := Rect2(8 + i * (bw + 22), 212, bw, 13)
		var on := _menu == i
		_canvas.draw_rect(br, C_SLOT_PICK if on else C_SLOT)
		if on:
			_canvas.draw_rect(Rect2(br.position, Vector2(2, br.size.y)), C_PICK)
		var bt: String = BUTTONS[i]
		PixelFont.draw(_canvas, Vector2(floorf(br.get_center().x - PixelFont.width_of(bt) / 2.0), br.position.y + 3), bt,
			C_PICK if on else C_DIM)
	if _note_t > 0.0:
		var nw := PixelFont.width_of(_note) + 12
		_canvas.draw_rect(Rect2(floorf((screen.x - nw) / 2), 196, nw, 12), Color(0.03, 0.02, 0.05, 0.92))
		PixelFont.draw(_canvas, Vector2(floorf((screen.x - nw) / 2) + 6, 199), _note, Color(_note_col, clampf(_note_t / 0.4, 0.0, 1.0)))
	var help := ("ARROWS CHOOSE   %s SELECT   %s CLOSE" % [_k("confirm"), _k("inventory")] if _menu >= 0
		else "%s USE   %s DROP   %s%s CLOSE" % [_k("confirm"), _k("run"),
			"" if on_pad else _k("guide") + " ASK " + Lore.COMPANION + "   ", _k("inventory")])
	PixelFont.draw(_canvas, Vector2(screen.x - 10 - PixelFont.width_of(help), screen.y - 12), help, C_DIM)
	if _guide >= 0:
		_draw_guide(screen)
	if _settings:
		_draw_settings(screen)


func _equip_line(pos: Vector2, label: String, id: String, none: String) -> void:
	UiKit.chip(_canvas, pos, label, Color("ffb060") if label == "HELD" else Color("8ab4ff"))
	if id == "":
		PixelFont.draw(_canvas, pos + Vector2(26, 1), none, C_DIM)
		return
	var slot := inventory.best_slot("weapon" if label == "HELD" else "armor")
	var stack: Dictionary = inventory.slots[slot] if slot >= 0 else {"id": id, "qty": 1}
	Items.draw_icon(_canvas, id, Rect2(pos + Vector2(24, -5), Vector2(16, 16)))
	PixelFont.draw(_canvas, pos + Vector2(42, -2), Items.label(stack), C_TEXT)
	PixelFont.draw(_canvas, pos + Vector2(42, 5), Items.short_stat_of(stack), C_DIM)
