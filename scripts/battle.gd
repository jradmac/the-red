class_name Battle
extends CanvasLayer
## Combat: a duel of hidden choices.
##
## Every round you and the enemy each secretly pick a move, then both are
## revealed at once and play out together:
##
##   ATTACK  hit for your full ATK (the weapon you hold: your best)
##   DEFEND  block: incoming damage = their ATK - your DEF (the armor you wear)
##   DODGE   50/50: evade the attack completely, or get hit for full
##   ITEM    drink a potion or flare your lantern -- takes your turn, and
##           an attack that round doesn't hurt you
##
##   Attack vs Attack   both take full damage
##   Attack vs Defend   defender takes ATK - DEF
##   Attack vs Dodge    coin flip: miss completely, or full damage
##   anything else      nobody gets hurt
##
## Enemies have a NATURE (shown under their name) that shapes what they pick,
## and sometimes give away their next move with a tell. Every round burns a
## little lantern fuel, so stalling isn't free. There is no running away.
## Demons lose 1 DEF while your lantern is lit.

var pfx := ""   ## input action prefix: "" for player 1, "p2_" for player 2

signal ended(result: String, enemy: Enemy)   # "won" or "lost"

const FUEL_PER_ROUND := 2.0
const FLARE_FUEL := 15.0
const FLARE_BURN := 2          # damage the flash deals to demons
const DODGE_CHANCE := 0.5
const TELL_CHANCE := 0.65      # how often the enemy gives a tell
const TELL_TRUTH := 0.8        # how often a tell is right
const MSG_TIME := 2.2          # seconds a message stays before moving on (Z skips)
const LOCK_TIME := 0.45
const REVEAL_TIME := 0.5
const CLASH_TIME := 1.25
const IMPACT_AT := 0.42        # seconds into the clash when blows land

## How each nature picks (see _enemy_choice).
const NATURES := {
	"bold": "BOLD: LOVES TO ATTACK",
	"timid": "TIMID: HIDES BEHIND ITS GUARD",
	"skittish": "SKITTISH: QUICK TO DODGE",
	"mirror": "MIMIC: COPIES YOUR LAST MOVE",
	"contrary": "CONTRARY: COUNTERS YOUR LAST MOVE",
	"alternate": "RHYTHMIC: ATTACKS EVERY OTHER ROUND",
	"desperate": "DESPERATE: RECKLESS WHEN HURT",
	"punisher": "CRUEL: STRIKES WHEN YOU HOLD BACK",
}
const TELLS := {
	"attack": ["%s REARS BACK...", "%s TENSES TO LUNGE...", "%s'S EYES FIX ON YOUR THROAT...", "%s CREEPS CLOSER..."],
	"defend": ["%s HUNKERS DOWN...", "%s DRAWS INTO ITSELF...", "%s BRACES...", "%s HOLDS ITS GROUND..."],
	"dodge": ["%s SHIFTS ITS WEIGHT...", "%s'S FEET SKITTER...", "%s SWAYS SIDE TO SIDE...", "%s WATCHES YOUR HANDS..."],
}
const MOVE_NAMES := {"attack": "ATTACK", "defend": "DEFEND", "dodge": "DODGE", "item": "ITEM", "dazed": "DAZED"}
const DRINKABLE := ["healing_tonic", "red_berry", "lamp_oil"]

const C_TEXT := Color("e8dfc8")
const C_DIM := Color("8a8299")
const C_PICK := Color("ffd35a")
const C_RED := Color("ff4a5a")
const C_BLUE := Color("8fc7ff")
const C_GREEN := Color("7dff9a")
const C_WHITE := Color("ffffff")
const C_ATTACK := Color("ff7a4a")
const C_DEFEND := Color("6aa8ff")
const C_DODGE := Color("b8f0c8")
const C_ITEM := Color("d8a0ff")

const HERO_HOME := Vector2(74, 92)       # hero 3x frame top-left (48 x 72)
const ENEMY_FEET := Vector2(262, 100)    # enemy stands here (bottom-centre)
const CARD_SIZE := Vector2(36, 50)
const DIE_TIME := 1.6          # the slain creature dissolving into smoke
const BAG_TEX: Texture2D = preload("res://assets/bag_icon.png")

var player: Player
var inventory: Inventory
var lantern: Lantern
var enemy: Enemy
var _canvas: Node2D
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _state := "idle"     # choose, items, lock, reveal, clash, messages
var _t := 0.0            # time in the current state
var _round := 0
var _sel := 0            # selected card
var _item_sel := 0
var _options: Array[String] = []        # "attack", "defend", "dodge", ("item")
var _item_options: Array[Dictionary] = []
var _you := ""           # your move this round
var _you_item: Dictionary = {}
var _them := ""          # enemy's move this round
var _last_you := ""
var _them_last := ""
var _dazed_next := false
var _tell := ""
var _messages: Array[String] = []
var _msg_t := 0.0
var _result := ""
var _opened_frame := -1
# what this round's clash does
var _dmg_to_enemy := 0
var _dmg_to_you := 0
var _heal := 0
var _you_dodge_ok := false
var _them_dodge_ok := false
var _impact_done := false
var _popups: Array[Dictionary] = []     # {text, pos, col, t}
var _enemy_flash := 0.0
var _player_flash := 0.0
var _shake := 0.0
var _white_flash := 0.0
var _die_t := -1.0       # >= 0 while the enemy dissolves


func setup(p: Player, inv: Inventory, l: Lantern) -> void:
	player = p
	inventory = inv
	lantern = l
	layer = 7
	visible = false
	_rng.randomize()
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_battle)
	add_child(_canvas)


func is_active() -> bool:
	return visible


## Starts a fight. (Who started it doesn't change anything.)
func start(e: Enemy, _you_started: bool) -> void:
	enemy = e
	visible = true
	player.ui_lock = "battle"
	lantern.paused = true
	_round = 0
	_result = ""
	_you = ""
	_them = ""
	_last_you = ""
	_them_last = ""
	_dazed_next = false
	_die_t = -1.0
	_popups.clear()
	_opened_frame = Engine.get_process_frames()
	var a := "AN " if e.display_name()[0] in "AEIOU" else "A "
	_messages = [a + e.display_name() + " BARS YOUR WAY!",
		"PICK ATTACK, DEFEND OR DODGE. IT PICKS IN SECRET TOO."]
	if e.kind == "demon" and lantern.state == Lantern.State.LIT:
		_messages.append("YOUR LANTERN LIGHT WEAKENS IT: -1 DEF.")
	_state = "messages"
	_msg_t = 0.0


# --- Numbers -----------------------------------------------------------------

func _your_atk() -> int:
	return inventory.attack()


func _your_def() -> int:
	return inventory.defense()


func _enemy_atk() -> int:
	return enemy.atk


func _enemy_def() -> int:
	var d := enemy.def
	if enemy.kind == "demon" and lantern.state == Lantern.State.LIT:
		d -= 1
	return maxi(d, 0)


func _name() -> String:
	return "THE " + enemy.display_name()


# --- Rounds --------------------------------------------------------------------

func _new_round() -> void:
	_round += 1
	_you = ""
	_them = "dazed" if _dazed_next else _enemy_choice()
	_dazed_next = false
	if _them == "dazed":
		_tell = _name() + " IS STILL REELING FROM THE FLARE!"
	elif _rng.randf() < TELL_CHANCE:
		var shown := _them
		if _rng.randf() > TELL_TRUTH:
			var others := ["attack", "defend", "dodge"].filter(func(m): return m != _them)
			shown = others[_rng.randi() % others.size()]
		var lines: Array = TELLS[shown]
		_tell = lines[_rng.randi() % lines.size()] % _name()
	else:
		_tell = _name() + " GIVES NOTHING AWAY."
	_options = ["attack", "defend", "dodge"]
	_build_items()
	if not _item_options.is_empty():
		_options.append("item")
	_sel = clampi(_sel, 0, _options.size() - 1)
	_state = "choose"
	_t = 0.0


func _build_items() -> void:
	_item_options.clear()
	for id in DRINKABLE:
		if inventory.count_of(id) > 0:
			var ok := true
			if (id == "healing_tonic" or id == "red_berry") and inventory.health >= inventory.max_health:
				ok = false
			if id == "lamp_oil" and lantern.fuel >= lantern.max_fuel - 2.0:
				ok = false
			var verb := "EAT " if id == "red_berry" else "DRINK "
			var desc: String = {"healing_tonic": "HEAL FULLY", "red_berry": "HEAL 3"}.get(id, "REFILL HALF YOUR LANTERN")
			_item_options.append({"id": id, "name": verb + Items.display_name(id), "ok": ok, "desc": desc})
	var flare_ok := lantern.fuel >= FLARE_FUEL
	var flare_desc := "BURN " + str(int(FLARE_FUEL)) + " FUEL: DAZES IT"
	if enemy.kind == "demon":
		flare_desc += ", SEARS FOR " + str(FLARE_BURN)
	_item_options.append({"id": "flare_up", "name": "FLARE UP LANTERN", "ok": flare_ok, "desc": flare_desc})


func _enemy_choice() -> String:
	var nature: String = enemy.info.get("nature", "bold")
	var w := [50, 30, 20]   # attack, defend, dodge
	match nature:
		"bold":
			w = [65, 15, 20]
		"timid":
			w = [25, 55, 20]
		"skittish":
			w = [30, 15, 55]
		"mirror":
			if _last_you in ["attack", "defend", "dodge"] and _rng.randf() < 0.8:
				return _last_you
		"contrary":
			if _last_you != "" and _rng.randf() < 0.8:
				if _last_you == "attack":
					return "defend" if _rng.randf() < 0.6 else "dodge"
				return "attack"
		"alternate":
			if _them_last != "" and _rng.randf() < 0.85:
				if _them_last == "attack":
					return "defend" if _rng.randf() < 0.5 else "dodge"
				return "attack"
		"desperate":
			w = [70, 5, 25] if enemy.hp * 2 <= enemy.max_hp else [30, 50, 20]
		"punisher":
			if _last_you in ["defend", "dodge", "item"] and _rng.randf() < 0.85:
				return "attack"
			w = [20, 50, 30]
	var r: int = _rng.randi() % (int(w[0]) + int(w[1]) + int(w[2]))
	if r < w[0]:
		return "attack"
	if r < w[0] + w[1]:
		return "defend"
	return "dodge"


## Locks in your move; the clash is worked out now and played back.
func _lock_in(move: String, item: Dictionary = {}) -> void:
	_you = move
	_you_item = item
	_state = "lock"
	_t = 0.0
	_resolve()


func _resolve() -> void:
	_dmg_to_enemy = 0
	_dmg_to_you = 0
	_heal = 0
	_you_dodge_ok = false
	_them_dodge_ok = false
	_impact_done = false
	var lines: Array[String] = []
	var n := _name()
	var you_attack := _you == "attack"
	var them_attack := _them == "attack"
	# --- your blow
	if you_attack:
		match _them:
			"attack", "dazed":
				_dmg_to_enemy = _your_atk()
			"defend":
				_dmg_to_enemy = maxi(_your_atk() - _enemy_def(), 0)
			"dodge":
				_them_dodge_ok = _rng.randf() < DODGE_CHANCE
				_dmg_to_enemy = 0 if _them_dodge_ok else _your_atk()
	# --- its blow
	if them_attack:
		match _you:
			"attack":
				_dmg_to_you = _enemy_atk()
			"defend":
				_dmg_to_you = maxi(_enemy_atk() - _your_def(), 0)
			"dodge":
				_you_dodge_ok = _rng.randf() < DODGE_CHANCE
				_dmg_to_you = 0 if _you_dodge_ok else _enemy_atk()
			"item":
				_dmg_to_you = 0
	# --- the story of the round
	if you_attack and them_attack:
		lines.append("YOU BOTH ATTACK!")
		lines.append("YOU HIT " + n + " FOR " + str(_dmg_to_enemy) + ". IT HITS YOU FOR " + str(_dmg_to_you) + ".")
	elif you_attack:
		match _them:
			"defend":
				lines.append(n + " DEFENDS!")
				if _dmg_to_enemy > 0:
					lines.append("YOUR " + str(_your_atk()) + " ATTACK BEATS ITS " + str(_enemy_def()) + " DEFENSE: " + str(_dmg_to_enemy) + " DAMAGE.")
				else:
					lines.append("ITS " + str(_enemy_def()) + " DEFENSE STOPS YOUR " + str(_your_atk()) + " ATTACK COLD.")
			"dodge":
				lines.append(n + " TRIES TO DODGE...")
				if _them_dodge_ok:
					lines.append("AND IT WORKS! YOUR ATTACK MISSES.")
				else:
					lines.append("TOO SLOW! YOU HIT IT FOR " + str(_dmg_to_enemy) + ".")
			"dazed":
				lines.append(n + " IS DAZED - A CLEAN HIT FOR " + str(_dmg_to_enemy) + "!")
	elif them_attack:
		match _you:
			"defend":
				lines.append(n + " ATTACKS - YOU DEFEND!")
				if _dmg_to_you > 0:
					lines.append("ITS " + str(_enemy_atk()) + " ATTACK BEATS YOUR " + str(_your_def()) + " DEFENSE: YOU TAKE " + str(_dmg_to_you) + ".")
				else:
					lines.append("YOUR " + str(_your_def()) + " DEFENSE HOLDS. NO DAMAGE!")
			"dodge":
				lines.append(n + " ATTACKS - YOU TRY TO DODGE...")
				if _you_dodge_ok:
					lines.append("AND YOU DO! IT MISSES COMPLETELY.")
				else:
					lines.append("TOO SLOW! IT HITS YOU FOR " + str(_dmg_to_you) + ".")
			"item":
				lines.append(n + " ATTACKS, BUT YOU SLIP AWAY.")
	else:
		if _you in ["defend", "dodge"] and _them in ["defend", "dodge"]:
			lines.append("YOU BOTH HOLD BACK, CIRCLING EACH OTHER...")
		elif _them == "dazed" and _you != "attack":
			lines.append(n + " STAGGERS, DAZED.")
		elif _you == "item":
			lines.append(n + (" DEFENDS" if _them == "defend" else " DODGES") + " AGAINST NOTHING.")
	# --- items
	if _you == "item":
		var id: String = _you_item.get("id", "")
		if id == "flare_up":
			lantern.fuel = maxf(lantern.fuel - FLARE_FUEL, 0.0)
			_dazed_next = true
			if enemy.kind == "demon":
				_dmg_to_enemy += FLARE_BURN
				lines.append("YOUR LANTERN FLARES! THE LIGHT SEARS IT FOR " + str(FLARE_BURN) + ".")
			else:
				lines.append("YOUR LANTERN FLARES! IT'S BLINDED.")
		else:
			var slot := _slot_of(id)
			var before := inventory.health
			if slot >= 0:
				var msg := inventory.use_slot(slot)
				_heal = inventory.health - before
				lines.append(msg if msg != "" else "YOU DRINK IT.")
	_last_you = _you
	_them_last = _them
	lantern.fuel = maxf(lantern.fuel - FUEL_PER_ROUND, 0.0)
	_messages = lines


func _apply_impact() -> void:
	if _impact_done:
		return
	_impact_done = true
	if _dmg_to_enemy > 0:
		Sfx.play("hit")
	if _dmg_to_you > 0:
		Sfx.play("hurt")
	if (_you == "defend" and _them == "attack") or (_them == "defend" and _you == "attack"):
		Sfx.play("block", -2.0 if _dmg_to_you + _dmg_to_enemy > 0 else 0.0)
	if (_you == "attack" and _them == "dodge" and _them_dodge_ok) or (_them == "attack" and _you == "dodge" and _you_dodge_ok):
		Sfx.play("miss")
	if _heal > 0:
		Sfx.play("heal")
	if _you == "item" and _you_item.get("id", "") == "flare_up":
		Sfx.play("flare_up")
	var enemy_pos := ENEMY_FEET - Vector2(0, 40)
	var hero_pos := HERO_HOME + Vector2(24, 20)
	if _dmg_to_enemy > 0:
		enemy.hp -= _dmg_to_enemy
		_enemy_flash = 0.45
		_popup("-" + str(_dmg_to_enemy), enemy_pos, C_RED)
	if _dmg_to_you > 0:
		inventory.health = maxi(inventory.health - _dmg_to_you, 0)
		inventory.changed.emit()
		_player_flash = 0.4
		_shake = 0.35
		_popup("-" + str(_dmg_to_you), hero_pos, C_RED)
	if _you == "attack" and _them == "defend" and _dmg_to_enemy == 0:
		_popup("BLOCKED", enemy_pos, C_BLUE)
	if _them == "attack" and _you == "defend" and _dmg_to_you == 0:
		_popup("BLOCKED", hero_pos, C_BLUE)
	if _you == "attack" and _them == "dodge":
		_popup("DODGED!" if _them_dodge_ok else "TOO SLOW!", enemy_pos - Vector2(0, 14),
			C_WHITE if _them_dodge_ok else C_RED)
	if _them == "attack" and _you == "dodge":
		_popup("DODGED!" if _you_dodge_ok else "TOO SLOW!", hero_pos - Vector2(0, 16),
			C_GREEN if _you_dodge_ok else C_RED)
	if _heal > 0:
		_popup("+" + str(_heal), hero_pos, C_GREEN)
	if _you == "item" and _you_item.get("id", "") == "flare_up":
		_white_flash = 0.5


func _popup(text: String, pos: Vector2, col: Color) -> void:
	_popups.append({"text": text, "pos": pos, "col": col, "t": 0.0})


func _after_clash() -> void:
	if enemy.hp <= 0 and _die_t < 0.0:
		_die_t = 0.0
		Sfx.play("dissolve")
		_state = "dying"
		_t = 0.0
		return
	if inventory.health <= 0:
		# your death wins out, even if you took it down with you
		if enemy.hp <= 0:
			_messages.append(_name() + " DISSOLVES INTO SMOKE... BUT ITS LAST BLOW HAS FOUND YOU.")
		_messages.append("YOU FALL...")
		_result = "lost"
	elif enemy.hp <= 0:
		_messages.append(_name() + " DISSOLVES INTO SMOKE!")
		_result = "won"
		Sfx.play("win")
	else:
		_messages.append(_name() + " HAS " + str(enemy.hp) + " HP LEFT. YOU HAVE " + str(inventory.health) + ".")
	_state = "messages"
	_msg_t = 0.0


func _slot_of(id: String) -> int:
	for i in Inventory.SLOTS:
		if inventory.slots[i].get("id", "") == id:
			return i
	return -1


func _close() -> void:
	visible = false
	_state = "idle"
	player.ui_lock = ""
	lantern.paused = false
	ended.emit(_result, enemy)


# --- Input & timing --------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_t += delta
	_enemy_flash = maxf(_enemy_flash - delta, 0.0)
	_player_flash = maxf(_player_flash - delta, 0.0)
	_shake = maxf(_shake - delta, 0.0)
	_white_flash = maxf(_white_flash - delta, 0.0)
	for p in _popups:
		p.t += delta
	_popups = _popups.filter(func(p): return p.t < 1.2)
	_canvas.queue_redraw()
	if Engine.get_process_frames() == _opened_frame:
		return
	match _state:
		"messages":
			_msg_t += delta
			if Input.is_action_just_pressed(pfx + "confirm") or _msg_t > MSG_TIME:
				_messages.pop_front()
				_msg_t = 0.0
				if _messages.is_empty():
					if _result != "":
						_close()
					else:
						_new_round()
		"choose":
			if Input.is_action_just_pressed(pfx + "move_right"):
				_sel = mini(_sel + 1, _options.size() - 1)
				Sfx.play("ui_move")
			elif Input.is_action_just_pressed(pfx + "move_left"):
				_sel = maxi(_sel - 1, 0)
				Sfx.play("ui_move")
			elif Input.is_action_just_pressed(pfx + "confirm"):
				Sfx.play("ui_select")
				if _options[_sel] == "item":
					_state = "items"
					_item_sel = 0
				else:
					_lock_in(_options[_sel])
		"items":
			if Input.is_action_just_pressed(pfx + "move_down"):
				_item_sel = mini(_item_sel + 1, _item_options.size() - 1)
				Sfx.play("ui_move")
			elif Input.is_action_just_pressed(pfx + "move_up"):
				_item_sel = maxi(_item_sel - 1, 0)
				Sfx.play("ui_move")
			elif Input.is_action_just_pressed(pfx + "run"):
				Sfx.play("ui_back")
				_state = "choose"
			elif Input.is_action_just_pressed(pfx + "confirm") and _item_options[_item_sel].ok:
				_lock_in("item", _item_options[_item_sel])
		"lock":
			if _t >= LOCK_TIME:
				_state = "reveal"
				_t = 0.0
		"reveal":
			if _t >= REVEAL_TIME:
				_state = "clash"
				_t = 0.0
				if _you == "attack" or _them == "attack":
					Sfx.play("swing")
				if _you == "dodge" or _them == "dodge":
					Sfx.play("dodge", -3.0)
		"clash":
			if _t >= IMPACT_AT:
				_apply_impact()
			if _t >= CLASH_TIME:
				_after_clash()
		"dying":
			_die_t = _t
			if _t >= DIE_TIME:
				_after_clash()


# --- Drawing -------------------------------------------------------------------------

func _draw_battle() -> void:
	if enemy == null:
		return
	var screen := _canvas.get_viewport_rect().size
	var shake := Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-1, 1)) if _shake > 0.0 else Vector2.ZERO
	UiKit.backdrop(_canvas, screen)
	if _player_flash > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, screen), Color(0.6, 0.0, 0.08, _player_flash * 0.6))
	# lantern light pooling on the ground between you
	UiKit.glow(_canvas, Vector2(170, 120) + shake, 120, Color(1.0, 0.7, 0.4), 0.6 + 0.6 * lantern.fraction())
	UiKit.pedestal(_canvas, ENEMY_FEET + Vector2(0, 2) + shake, 40, 8)
	UiKit.pedestal(_canvas, HERO_HOME + Vector2(24, 70) + shake, 44, 9)
	_draw_enemy(shake)
	_draw_hero(shake)
	_draw_cards_in_play()
	_draw_popups()
	_draw_enemy_panel()
	_draw_player_panel()
	_draw_bottom()
	if _white_flash > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, screen), Color(1, 0.97, 0.85, minf(_white_flash * 1.6, 1.0)))


## 0..1 over the lunge: forward fast, hang at the impact, then back.
func _lunge_curve() -> float:
	if _state != "clash":
		return 0.0
	var t := _t
	if t < IMPACT_AT:
		return ease(t / IMPACT_AT, 2.4)
	if t < IMPACT_AT + 0.15:
		return 1.0
	return clampf(1.0 - (t - IMPACT_AT - 0.15) / 0.4, 0.0, 1.0)


## Sideways hop for a dodge: big if it works, a stumble if it doesn't.
func _dodge_offset(works: bool) -> float:
	if _state != "clash":
		return 0.0
	var t := clampf((_t - (IMPACT_AT - 0.2)) / 0.6, 0.0, 1.0)
	return sin(t * PI) * (24.0 if works else 6.0)


func _draw_enemy(shake: Vector2) -> void:
	if _die_t >= 0.0 and _state != "dying":
		return   # it's gone
	if _state == "dying":
		_draw_dissolve(shake)
		return
	var h := 24 if enemy.kind == "demon" else 16
	var tex: Texture2D = Enemy.INSECTS_TEX if enemy.kind == "insect" else Enemy.DEMONS_TEX
	var size := Vector2(48, h * 3)
	var pos := ENEMY_FEET - Vector2(24, size.y) + Vector2(0, roundf(sin(_time * 3.0) * 1.5)) + shake
	if _them == "attack":
		pos += Vector2(-110, 50) * _lunge_curve()
	elif _them == "dodge":
		var o := _dodge_offset(_them_dodge_ok)
		pos += Vector2(o, -o * 0.3)
	elif _them == "dazed" and _state == "clash":
		pos.x += sin(_time * 30.0) * 2.0
	if _enemy_flash > 0.0:
		pos.x += _rng.randf_range(-3, 3)
	Shadows.oval(_canvas, ENEMY_FEET + Vector2(0, -1) + shake, 36)
	var mod := Color(4, 4, 4) if fmod(_enemy_flash, 0.1) > 0.05 else Color.WHITE
	var fr: int = (int(_time * 8.0) % 4) if (_them == "attack" and _state == "clash") else [0, 2][int(_time * 2.0) % 2]
	_canvas.draw_texture_rect_region(tex, Rect2(pos.round(), size), Rect2(enemy.variant * 16, fr * h, 16, h), mod)
	if _them == "defend" and _state == "clash":
		_shield_bubble(ENEMY_FEET - Vector2(0, size.y * 0.5), 34, C_DEFEND)
	if _you == "attack" and _state == "clash" and _dmg_to_enemy > 0 and _t >= IMPACT_AT and _t < IMPACT_AT + 0.25:
		for i in 10:
			var aa := i * TAU / 10.0
			var p := ENEMY_FEET - Vector2(0, size.y * 0.5) + Vector2.from_angle(aa) * (6.0 + (_t - IMPACT_AT) * 90.0)
			_canvas.draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(1, 0.95, 0.7))
	# a "?" while it's deciding
	if _state in ["choose", "items"]:
		var q := Vector2(ENEMY_FEET.x + 20, ENEMY_FEET.y - size.y - 4 + roundf(sin(_time * 4.0) * 2.0))
		_canvas.draw_rect(Rect2(q - Vector2(4, 4), Vector2(11, 13)), Color("0e0a14"))
		_canvas.draw_rect(Rect2(q - Vector2(3, 3), Vector2(9, 11)), Color("3a2f52"))
		PixelFont.draw(_canvas, q, "?", C_PICK)


func _draw_hero(shake: Vector2) -> void:
	var pos := HERO_HOME + shake
	if _you == "attack":
		pos += Vector2(110, -50) * _lunge_curve()
	elif _you == "dodge":
		var o := _dodge_offset(_you_dodge_ok)
		pos += Vector2(-o, -o * 0.3)
	Shadows.oval(_canvas, HERO_HOME + Vector2(24, 68) + shake, 40)
	var weapon := inventory.best_id("weapon", "atk")
	var armor := inventory.best_id("armor", "def")
	var swinging := _you == "attack" and _state == "clash" and weapon != ""
	var bob := -1.0 if fmod(_time, 1.4) < 0.7 else 0.0
	HeroLook.use(player)
	HeroLook.draw(_canvas, pos.round(), 3.0, 1, 0, armor, "" if swinging else weapon, bob, Vector2.ZERO, swinging)
	if swinging:
		_draw_swing(pos.round(), weapon, armor, bob)
	if _you == "defend" and _state == "clash":
		_shield_bubble(HERO_HOME + Vector2(24, 34), 40, C_DEFEND)
	if _them == "attack" and _state == "clash" and _dmg_to_you > 0:
		_draw_claws(HERO_HOME + Vector2(24, 34))
	if _you == "item" and _state == "clash" and _heal > 0:
		for i in 10:
			var ph := fmod(_t * 0.9 + i * 0.1, 1.0)
			var x := HERO_HOME.x + 8 + fmod(i * 17.0, 32.0)
			_canvas.draw_rect(Rect2(x, HERO_HOME.y + 60 - ph * 60, 2, 2), Color(C_GREEN, 1.0 - ph))


## The swing: the hero's right arm comes off the body and swings from the
## shoulder, with the weapon gripped in its hand -- shoulder, arm, hand and
## weapon move together as one piece, up over the head and down through the
## enemy in a single smooth arc.
const ARM_PIVOT := Vector2(14.5, 14.5)   # right shoulder, in the 16 x 24 back-view frame
const ARM_HAND := 4.0                     # shoulder -> hand, frame pixels
const GRIP := Vector2(2.5, 12.5)          # where the hand holds a gear.png weapon (its handle)
const GRIP_TURN := 1.658                  # the weapon's angle in the hand (95 degrees)
const BLADE_TIP := Vector2(13, 2)         # roughly the far end of a gear.png weapon


## Which way the arm points, shoulder to hand (radians; PI/2 = hanging down).
func _swing_angle() -> float:
	var a: float
	if _t < IMPACT_AT * 0.45:
		a = lerpf(80.0, -115.0, ease(_t / (IMPACT_AT * 0.45), 0.4))                 # raise it overhead
	elif _t < IMPACT_AT:
		a = lerpf(-115.0, 15.0, ease((_t - IMPACT_AT * 0.45) / (IMPACT_AT * 0.55), 2.2))   # bring it down, fast
	elif _t < IMPACT_AT + 0.4:
		a = lerpf(15.0, 60.0, ease((_t - IMPACT_AT) / 0.4, 0.5))                   # follow through
	else:
		a = lerpf(60.0, 85.0, clampf((_t - IMPACT_AT - 0.4) / 0.4, 0.0, 1.0))      # lower it
	return deg_to_rad(a)


func _arm_xf(pivot: Vector2, phi: float) -> Transform2D:
	return Transform2D(phi - PI / 2.0, Vector2(3, 3), 0.0, pivot)


func _weapon_xf(pivot: Vector2, phi: float) -> Transform2D:
	return _arm_xf(pivot, phi) * Transform2D(GRIP_TURN, Vector2(0, ARM_HAND))


func _draw_swing(hero_pos: Vector2, weapon: String, armor: String, bob: float) -> void:
	var pivot := hero_pos + (ARM_PIVOT + Vector2(0, bob)) * 3.0
	var phi := _swing_angle()
	# slash trail, traced by the blade's tip, right around the impact
	if _t > IMPACT_AT * 0.55 and _t < IMPACT_AT + 0.22:
		var a := clampf(1.0 - absf(_t - IMPACT_AT) / 0.3, 0.0, 1.0)
		for i in 16:
			var ph := lerpf(deg_to_rad(-100.0), phi, i / 15.0)
			var tip: Vector2 = _weapon_xf(pivot, ph) * (BLADE_TIP - GRIP)
			_canvas.draw_rect(Rect2(tip.round() - Vector2(1, 1), Vector2(3, 3)), Color(1, 1, 0.9, a * (0.25 + i / 20.0)))
	# the weapon, then the arm over it (the hand closes over the handle)
	_canvas.draw_set_transform_matrix(_weapon_xf(pivot, phi))
	_canvas.draw_texture_rect_region(HeroLook.GEAR_TEX, Rect2(-GRIP, Vector2(16, 16)),
		Rect2(HeroLook.WEAPONS[weapon] * 16, 0, 16, 16))
	_canvas.draw_set_transform_matrix(_arm_xf(pivot, phi))
	_canvas.draw_texture_rect_region(HeroLook.body_tex(), Rect2(-1.5, -0.5, 3, 6), HeroLook.back_arm_src(armor))
	_canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


## Claw marks raked across whoever got hit.
func _draw_claws(center: Vector2) -> void:
	var a := clampf(1.0 - (_t - IMPACT_AT) / 0.5, 0.0, 1.0)
	if _t < IMPACT_AT or a <= 0.0:
		return
	for k in 3:
		for i in 12:
			var p := center + Vector2(-14 + k * 9 + i * 1.6, -16 + i * 2.6)
			_canvas.draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(1.0, 0.3, 0.35, a))


## The slain creature comes apart into thick purple smoke: it flashes, its
## body sinks and breaks into drifting motes while smoke billows up and out.
func _draw_dissolve(shake: Vector2) -> void:
	var t := _die_t / DIE_TIME
	var h := 24 if enemy.kind == "demon" else 16
	var tex: Texture2D = Enemy.INSECTS_TEX if enemy.kind == "insect" else Enemy.DEMONS_TEX
	var size := Vector2(48, h * 3)
	var base := ENEMY_FEET + shake
	# billowing smoke behind and around
	for i in 16:
		var ph := clampf(t * 1.3 - i * 0.03, 0.0, 1.0)
		if ph <= 0.0:
			continue
		var ang := i * 2.39
		var spread := Vector2(cos(ang) * 26.0, -absf(sin(ang)) * 10.0)
		var p := base + Vector2(0, -size.y * 0.45) + spread * ph + Vector2(0, -34.0 * ph)
		var rad := 6.0 + 16.0 * ph
		var a := (1.0 - ph) * 0.75
		_canvas.draw_circle(p, rad, Color(0.22, 0.08, 0.32, a))
		_canvas.draw_circle(p - Vector2(rad * 0.25, rad * 0.25), rad * 0.6, Color(0.5, 0.25, 0.7, a * 0.7))
	# the body: flashes white, then sinks and fades, sliced into wavering rows
	var body_a := clampf(1.0 - t * 1.6, 0.0, 1.0)
	if body_a > 0.0:
		var flash := Color(5, 5, 5, body_a) if t < 0.08 else Color(1.0, 0.75, 1.2, body_a)
		var rows := h
		for row in rows:
			var wob := sin(row * 1.7 + _time * 20.0) * 6.0 * t
			var lift := -row * 0.0 + t * 10.0 * (1.0 - float(row) / rows)
			var dst := Rect2(base + Vector2(-24 + wob, -size.y + row * 3 - lift + t * 18.0), Vector2(48, 3))
			_canvas.draw_texture_rect_region(tex, Rect2(dst.position.round(), dst.size), Rect2(enemy.variant * 16, row, 16, 1), flash)
	# motes of its essence drifting up
	for i in 24:
		var ph := fmod(t * 1.2 + i * 0.041, 1.0)
		var x := base.x - 20 + fmod(i * 13.7, 40.0) + sin(_time * 3.0 + i) * 4.0
		var y := base.y - size.y * 0.6 - ph * 50.0
		_canvas.draw_rect(Rect2(Vector2(x, y).round(), Vector2(2, 2)), Color(0.8, 0.55, 1.0, (1.0 - ph) * (1.0 - t)))


## A shimmering ring of light: someone braced behind their guard.
func _shield_bubble(center: Vector2, r: float, col: Color) -> void:
	var a := clampf(_t / 0.2, 0.0, 1.0) * clampf((CLASH_TIME - _t) / 0.3, 0.0, 1.0)
	for i in 40:
		var ang := TAU * i / 40.0
		var p := center + Vector2(cos(ang) * r, sin(ang) * r * 0.9)
		_canvas.draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(col, a * (0.5 + 0.5 * sin(ang * 3.0 + _time * 6.0))))
	_canvas.draw_circle(center, r, Color(col, 0.08 * a))


## The two chosen cards in the middle: yours slides up, theirs slides in
## face-down, both flip together, then they fade as the moves play out.
func _draw_cards_in_play() -> void:
	if not _state in ["lock", "reveal", "clash"]:
		return
	var you_home := Vector2(132, 62)
	var them_home := Vector2(176, 62)
	var slide := 1.0
	var flip := 0.0
	var alpha := 1.0
	match _state:
		"lock":
			slide = ease(clampf(_t / LOCK_TIME, 0.0, 1.0), 0.4)
		"reveal":
			flip = clampf(_t / REVEAL_TIME, 0.0, 1.0)
		"clash":
			flip = 1.0
			alpha = clampf(1.0 - _t / 0.3, 0.0, 1.0)
	if alpha <= 0.0:
		return
	var yp := you_home.lerp(Vector2(250, 180), 1.0 - slide)
	var tp := them_home.lerp(Vector2(380, 62), 1.0 - slide)
	_card(yp, _you, true, false, alpha, 1.0)
	_card(tp, _them, flip >= 0.5, true, alpha, maxf(absf(cos(flip * PI)), 0.08))
	if _state == "reveal" and _t > REVEAL_TIME * 0.5:
		PixelFont.draw(_canvas, Vector2(170, 84), "VS", Color(C_PICK, alpha))


## One move card. `face` = showing its move. `theirs` = the enemy's card.
## `sx` squashes it horizontally (for the flip).
func _card(pos: Vector2, move: String, face: bool, theirs: bool, alpha: float, sx: float,
		picked: bool = false, value_text: String = "") -> void:
	var size := CARD_SIZE
	_canvas.draw_set_transform((pos + size / 2).round(), 0.0, Vector2(sx, 1.0))
	var r := Rect2(-size / 2, size)
	var col := _move_color(move)
	_canvas.draw_rect(r.grow(1), Color(0.02, 0.01, 0.04, alpha))
	if not face:
		_canvas.draw_rect(r, Color(Color("5a3a8a"), alpha))
		_canvas.draw_rect(r.grow(-2), Color(Color("2a1840"), alpha))
		for k in 5:
			_canvas.draw_rect(Rect2(r.position + Vector2(5 + k * 6, 7 + (k % 2) * 4), Vector2(2, 2)), Color(Color("8a6ad0"), alpha * 0.6))
			_canvas.draw_rect(Rect2(r.position + Vector2(5 + k * 6, size.y - 11 - (k % 2) * 4), Vector2(2, 2)), Color(Color("8a6ad0"), alpha * 0.6))
		PixelFont.draw(_canvas, Vector2(-1, -2), "?", Color(C_PICK, alpha))
		_canvas.draw_set_transform(Vector2.ZERO)
		return
	_canvas.draw_rect(r, Color(C_PICK if picked else col, alpha))
	_canvas.draw_rect(r.grow(-1), Color(Color("120d1c"), alpha))
	_canvas.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(size.x - 2, 9)), Color(col, 0.25 * alpha))
	var label: String = MOVE_NAMES.get(move, move.to_upper())
	PixelFont.draw(_canvas, Vector2(-PixelFont.width_of(label) / 2.0, r.position.y + 3).round(), label, Color(col, alpha))
	_move_icon(Vector2(0, -1), move, theirs, alpha)
	if value_text == "":
		value_text = _value_text(move, theirs)
	if value_text != "":
		PixelFont.draw(_canvas, Vector2(-PixelFont.width_of(value_text) / 2.0, r.end.y - 9).round(), value_text, Color(C_TEXT, alpha))
	_canvas.draw_set_transform(Vector2.ZERO)


func _move_color(move: String) -> Color:
	match move:
		"attack": return C_ATTACK
		"defend": return C_DEFEND
		"dodge": return C_DODGE
		"item": return C_ITEM
	return C_DIM


func _value_text(move: String, theirs: bool) -> String:
	match move:
		"attack": return str(_enemy_atk() if theirs else _your_atk())
		"defend": return str(_enemy_def() if theirs else _your_def())
		"dodge": return "50%"
		"item":
			return "BAG"
		"dazed": return "STUNNED"
	return ""


## Icon in the middle of a card (card-local coordinates around `c`).
func _move_icon(c: Vector2, move: String, theirs: bool, alpha: float) -> void:
	match move:
		"attack":
			var w := inventory.best_id("weapon", "atk")
			if not theirs and w != "":
				Items.draw_icon(_canvas, w, Rect2(c - Vector2(8, 8), Vector2(16, 16)))
			else:
				for k in 3:   # claw marks
					for i in 9:
						_canvas.draw_rect(Rect2((c + Vector2(-6 + k * 4 + i * 0.6, -6 + i * 1.4)).round(), Vector2(1, 2)),
							Color(C_RED if theirs else C_ATTACK, alpha))
		"defend":
			var a := inventory.best_id("armor", "def")
			if not theirs and a != "":
				Items.draw_icon(_canvas, a, Rect2(c - Vector2(8, 8), Vector2(16, 16)))
			else:
				for y in 12:   # a shield
					var half := 6.0 if y < 6 else 6.0 - (y - 6)
					_canvas.draw_rect(Rect2(c.x - half, c.y - 6 + y, half * 2, 1), Color(C_DEFEND, alpha))
				_canvas.draw_rect(Rect2(c.x - 1, c.y - 5, 2, 9), Color(Color("dceaff"), alpha))
		"dodge":
			for k in 3:   # swoosh lines
				var y := c.y - 5 + k * 5
				for i in 9:
					_canvas.draw_rect(Rect2(c.x - 6 + i + (k - 1) * 2, roundf(y + sin(i * 0.7) * 1.5), 1, 1),
						Color(C_DODGE, alpha * (0.4 + i / 14.0)))
				_canvas.draw_rect(Rect2(c.x + 3 + (k - 1) * 2, y - 1, 1, 3), Color(C_DODGE, alpha))
		"item":
			_canvas.draw_texture_rect_region(BAG_TEX, Rect2(c - Vector2(8, 8), Vector2(16, 16)), Rect2(0, 0, 16, 16),
				Color(1, 1, 1, alpha))
		"dazed":
			for i in 3:
				var a := _time * 3.0 + i * TAU / 3.0
				_canvas.draw_rect(Rect2(c + Vector2(cos(a) * 7, sin(a) * 3 - 2), Vector2(2, 2)), Color(C_PICK, alpha))


func _draw_popups() -> void:
	for p in _popups:
		var t: float = p.t
		var pos: Vector2 = p.pos + Vector2(0, -t * 22.0)
		var a := clampf(1.0 - (t - 0.8) / 0.4, 0.0, 1.0)
		var text: String = p.text
		var s := 2.0 if t > 0.08 else 3.0   # pops in big, then settles
		var w := PixelFont.width_of(text) * s
		_canvas.draw_set_transform((pos - Vector2(w / 2.0, 0)).round(), 0.0, Vector2(s, s))
		PixelFont.draw(_canvas, Vector2.ZERO, text, Color(p.col, a), Color(0, 0, 0, a))
		_canvas.draw_set_transform(Vector2.ZERO)


func _draw_enemy_panel() -> void:
	var r := Rect2(8, 10, 172, 46)
	UiKit.panel(_canvas, r)
	PixelFont.draw(_canvas, r.position + Vector2(7, 6), enemy.display_name(), C_TEXT)
	var hp_txt := "HP " + str(maxi(enemy.hp, 0)) + "/" + str(enemy.max_hp)
	PixelFont.draw(_canvas, Vector2(r.end.x - 7 - PixelFont.width_of(hp_txt), r.position.y + 6), hp_txt, C_TEXT)
	UiKit.bar(_canvas, Rect2(r.position + Vector2(7, 14), Vector2(r.size.x - 14, 4)),
		float(maxi(enemy.hp, 0)) / float(enemy.max_hp), Color("7dff9a") if enemy.hp * 2 > enemy.max_hp else Color("ffb040"))
	UiKit.chip(_canvas, r.position + Vector2(7, 23), "ATK " + str(_enemy_atk()), C_ATTACK)
	var def_txt := "DEF " + str(_enemy_def())
	if enemy.kind == "demon" and lantern.state == Lantern.State.LIT:
		def_txt += " (LIGHT -1)"
	UiKit.chip(_canvas, r.position + Vector2(40, 23), def_txt, C_DEFEND)
	PixelFont.draw(_canvas, r.position + Vector2(7, 35), NATURES.get(enemy.info.get("nature", ""), ""), C_DIM)


func _draw_player_panel() -> void:
	var r := Rect2(196, 118, 156, 46)
	UiKit.panel(_canvas, r)
	PixelFont.draw(_canvas, r.position + Vector2(7, 6), "YOU", C_TEXT)
	for i in inventory.max_health:
		Hud.draw_heart(_canvas, r.position + Vector2(28 + i * 8, 5),
			Color("e0453f") if i < inventory.health else Color("3a2433"))
	UiKit.chip(_canvas, r.position + Vector2(7, 18), "ATK " + str(_your_atk()), C_ATTACK)
	UiKit.chip(_canvas, r.position + Vector2(40, 18), "DEF " + str(_your_def()), C_DEFEND)
	PixelFont.draw(_canvas, r.position + Vector2(7, 32), "LIGHT", C_DIM)
	var frac := lantern.fraction()
	UiKit.bar(_canvas, Rect2(r.position + Vector2(32, 32), Vector2(r.size.x - 40, 4)), frac,
		Color("f5c542") if frac > 0.25 else Color("e0453f"))


func _draw_bottom() -> void:
	var r := Rect2(8, 172, 344, 60)
	UiKit.panel(_canvas, r)
	var text_w := 184.0
	var tx := r.position + Vector2(8, 8)
	match _state:
		"messages":
			if not _messages.is_empty():
				_text_block(tx, _messages[0], r.size.x - 24, C_TEXT)
				if fmod(_time, 0.8) < 0.5:
					PixelFont.draw(_canvas, r.end - Vector2(12, 10), "Z", C_DIM)
		"choose":
			_text_block(tx, _tell, text_w, C_PICK)
			_text_block(tx + Vector2(0, 22), _hint(_options[_sel]), text_w, C_DIM)
			for i in _options.size():
				var move: String = _options[i]
				var lift := -4.0 if i == _sel else 0.0
				var pos := Vector2(r.position.x + 196 + i * (CARD_SIZE.x + 1), r.position.y + 6 + lift)
				_card(pos, move, true, false, 1.0, 1.0, i == _sel)
		"items":
			PixelFont.draw(_canvas, tx, "USE WHAT? IT TAKES YOUR TURN, BUT ATTACKS CAN'T HURT YOU.", C_DIM)
			for i in _item_options.size():
				var o: Dictionary = _item_options[i]
				var y := tx.y + 11 + i * 9
				var col := C_PICK if i == _item_sel else (C_TEXT if o.ok else Color(C_DIM, 0.6))
				if i == _item_sel:
					PixelFont.draw(_canvas, Vector2(tx.x, y), ">", C_PICK)
				PixelFont.draw(_canvas, Vector2(tx.x + 8, y), o.name, col)
				PixelFont.draw(_canvas, Vector2(tx.x + 112, y), o.desc if o.ok else "NOT NOW", C_DIM)
			PixelFont.draw(_canvas, r.end - Vector2(64, 10), "Z USE  X BACK", C_DIM)
		"lock", "reveal", "clash":
			var line := "YOU CHOSE " + str(MOVE_NAMES.get(_you, "")) + "."
			if _state == "clash" or (_state == "reveal" and _t > REVEAL_TIME * 0.5):
				line += "  " + _name() + " CHOSE " + str(MOVE_NAMES.get(_them, "?")) + "!"
			_text_block(tx, line, r.size.x - 16, C_TEXT)


func _hint(move: String) -> String:
	match move:
		"attack":
			return "HIT FOR " + str(_your_atk()) + ". IF IT DEFENDS: " + str(maxi(_your_atk() - _enemy_def(), 0)) + \
				". IF IT DODGES: 50% TO MISS."
		"defend":
			return "IF IT ATTACKS YOU TAKE " + str(maxi(_enemy_atk() - _your_def(), 0)) + " INSTEAD OF " + str(_enemy_atk()) + "."
		"dodge":
			return "50/50: AVOID ITS ATTACK COMPLETELY, OR TAKE THE FULL " + str(_enemy_atk()) + "."
		"item":
			return "DRINK A POTION OR FLARE YOUR LANTERN. ATTACKS CAN'T HURT YOU THIS TURN."
	return ""


func _text_block(pos: Vector2, text: String, width: float, col: Color) -> void:
	var y := pos.y
	for line in Dialog.wrap_text(text, width):
		PixelFont.draw(_canvas, Vector2(pos.x, y), line, col)
		y += 8
