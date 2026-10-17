class_name VillageScreen
extends CanvasLayer
## Inside a village building: the shop, the sage's hut, the inn, or
## somebody's home. The room and whoever keeps it on the left, what you can do
## on the right, what they say along the bottom. Up/down choose, A does it,
## B leaves.
##
##   shop   always sells healing tonics, flares, matches and every kind of
##          lantern, plus a few odds and ends that change from village to village
##   sage   mends all your wounds (priced by how hurt you are), and gives advice
##   inn    a bed until morning (for everybody: the night is skipped), or a hot meal
##   home   whoever lives there; some give you something for the road

var pfx := ""   ## input action prefix: "" for player 1, "p2_" for player 2

const C_TEXT := Color("e8dfc8")
const C_DIM := Color("8a8299")
const C_PICK := Color("ffd35a")
const C_BAD := Color("ff6a7a")
const C_GOOD := Color("7dff9a")
const C_ROW := Color("1e1830")
const C_ROW_PICK := Color("3a2f52")
const C_RUBY := Color("ff5a6a")
const ROW_H := 14
const LIST_ROWS := 9
const CHARS_PER_SEC := 55.0

## Prices for services (rubies).
const SAGE_PER_HEART := 2      ## a full mend: this much per missing heart
const SAGE_MIN := 3
const INN_PRICE := 12          ## a night's sleep (skips to morning)
const MEAL_PRICE := 4          ## a hot meal: +3 hearts
const MEAL_HEAL := 3

const SHOP_ALWAYS := ["healing_tonic", "flare", "matches", "lamp_oil", "red_berry",
	"brass_lantern", "storm_lantern", "witchglass_lantern"]

const SHOP_NAMES := ["THE GILDED LANTERN", "THE COPPER KETTLE", "WAYFARER'S GOODS", "THE RUSTY NAIL",
	"THE LAST CANDLE", "THE CROOKED SHELF"]
const INN_NAMES := ["THE SLEEPING FOX", "THE WARM HEARTH", "THE DOZING OWL", "THE QUIET MOON", "THE LANTERN REST"]
const SAGE_NAMES := ["ORLA", "THESSALY", "OLD WREN", "MOTHER ISOLDE", "BROTHER AMMON", "SILAS"]

const SHOP_HELLO := ["COME IN, COME IN! EVERYTHING HAS A PRICE, AND EVERY PRICE IS FAIR.",
	"LOOKING TO SPEND SOME RUBIES? YOU'VE COME TO THE RIGHT COUNTER.",
	"MIND THE SHELVES. AND THE CAT. MOSTLY THE CAT.",
	"LIGHT, HEALING, STEEL. WHATEVER KEEPS YOU BREATHING OUT THERE."]
const SHOP_THANKS := ["A FINE CHOICE.", "PLEASURE DOING BUSINESS.", "MAY IT SERVE YOU WELL.",
	"COME BACK ALIVE, NOW. I LIKE REPEAT CUSTOMERS.", "THAT ONE'S A GOOD 'UN."]
const SAGE_HELLO := ["SIT. LET ME SEE THOSE WOUNDS.", "THE LABYRINTH HAS LEFT ITS MARKS ON YOU, I SEE.",
	"COME CLOSER TO THE FIRE, CHILD. TELL ME WHERE IT HURTS."]
const SAGE_TIPS := [
	"A DEMON SHOWS ITS INTENT BEFORE IT STRIKES. WATCH ITS TELLS, AND DEFEND WHEN IT WINDS UP.",
	"WHEN THE FLAME DIES, THE LONGMAN COMES. KEEP A MATCH READY, ALWAYS.",
	"EVERY LOCKED DOOR HAS ITS KEY ON YOUR SIDE OF IT. SEARCH BEFORE YOU DESPAIR.",
	"BLUE BERRIES CRUSHED INTO THE FLAME MAKE IT BURN COLD. THE CREATURES CANNOT BEAR IT.",
	"THE SUN DOES NOT REACH THE DEEPEST HALLS. SPEND YOUR DAYLIGHT WISELY.",
	"A STORM LANTERN LAUGHS AT THE WIND. A WITCHGLASS ONE SEES FURTHER.",
	"THE SPRITES OF LIGHT ASK RIDDLES. ANSWER WELL AND THEY'LL SHOW YOU WHAT'S HIDDEN.",
	"A FLARE IN A LARGE ROOM SHOWS YOU THE WHOLE OF IT. DON'T WASTE THEM IN CORRIDORS.",
	"RUN WHEN YOU MUST, BUT YOUR BREATH RUNS OUT. RUN TOO LONG AND YOU'LL STAND WINDED IN THE DARK.",
]
const INN_HELLO := ["A BED FOR THE NIGHT? YOU'LL WAKE TO SUNSHINE, I PROMISE.",
	"WELCOME, WELCOME. THE BEDS ARE SOFT AND THE DOORS ARE THICK.",
	"YOU LOOK DEAD ON YOUR FEET. NOT LITERALLY, I HOPE."]
const HOME_HELLO := ["OH! A VISITOR. SIT, SIT. WE DON'T GET MANY.", "WIPE YOUR BOOTS. THE LABYRINTH TRACKS IN.",
	"YOU'RE NOT FROM HERE. NOBODY'S FROM OUT THERE ANYMORE.", "COME IN QUICK, YOU'RE LETTING THE DARK IN.",
	"HELLO, STRANGER. CAN I HELP YOU?"]
const HOME_TALK := [
	"MY HUSBAND MAPPED THE CRYPTS ONCE. THE MAP WALKED OFF ONE NIGHT. WE DON'T TALK ABOUT IT.",
	"I KEEP A CANDLE IN EVERY WINDOW. OLD HABIT. THE DARK DOESN'T LIKE BEING WATCHED.",
	"MY SON WENT LOOKING FOR THE MASTER CHAMBER. IF YOU SEE HIM, TELL HIM DINNER'S COLD.",
	"THE STEW'S NOT READY. COME BACK... SOMETIME.",
	"BEFORE THE WALLS WE LIVED OUT THERE, IN THE OPEN. MY GRANDMOTHER REMEMBERED THE STARS.",
	"THEY SAY IF YOU LISTEN AT THE WELL AT MIDNIGHT, YOU HEAR THE CRYPTS BREATHING.",
	"THE GUARDS ARE GOOD LADS. ONE OF THEM IS SWEET ON THE BAKER'S DAUGHTER.",
	"DON'T TOUCH THAT. IT WAS MY MOTHER'S. NO, I DON'T KNOW WHAT IT IS EITHER.",
	"YOU CARRY A LITTLE FLAME SPIRIT? HOLD ON TO IT. THEY CHOOSE SO FEW.",
	"I USED TO TRADE RUBIES FROM THE DEEP HALLS. THE DEEPER YOU GO, THE BIGGER THEY GET.",
	"SOMETIMES I DREAM THE LABYRINTH IS DREAMING US. THEN I HAVE TEA AND FEEL BETTER.",
	"THE FARM FEEDS US ALL. TAKE A FEW BERRIES ON YOUR WAY OUT, NOBODY WILL MIND.",
]
const HOME_GIFT := "WAIT - TAKE THESE, FOR THE ROAD. YOU NEED THEM MORE THAN I DO."

var hero: Hero
var villages: Villages
var flares: Flares
var day: DayCycle
var world: World
var sleep: Callable           ## main: everyone sleeps till morning
var compact := false          ## over a walk-in room: just the list and the speech box
var return_lock := ""         ## what the hero's controls go back to when this closes
var _canvas: Node2D
var _vi := -1
var _b: Dictionary = {}
var _kind := ""
var _rng := RandomNumberGenerator.new()
var _options: Array[Dictionary] = []   ## {label, price, id, stack, act}
var _sel := 0
var _scroll := 0
var _say := ""
var _shown := 0.0
var _say_col := C_TEXT
var _keeper_look := 0
var _keeper_name := ""
var _place_name := ""
var _time := 0.0
var _opened_frame := -1
var _talk_i := 0


func setup(h: Hero, v: Villages, f: Flares, d: DayCycle, w: World) -> void:
	hero = h
	villages = v
	flares = f
	day = d
	world = w
	layer = 5
	visible = false
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_screen)
	add_child(_canvas)


## Walk in through building `b` of village `vi`.
func open(vi: int, b: Dictionary) -> void:
	_vi = vi
	_b = b
	_kind = b.kind
	visible = true
	hero.player.ui_lock = "village"
	_opened_frame = Engine.get_process_frames()
	_sel = 0
	_scroll = 0
	var v: Dictionary = villages.list[vi]
	var door: Vector2i = b.door
	_rng.seed = int(v.seed) + door.x * 131 + door.y * 7
	_talk_i = _rng.randi() % HOME_TALK.size()
	match _kind:
		"shop":
			_keeper_look = 15
			_place_name = SHOP_NAMES[_rng.randi() % SHOP_NAMES.size()]
			_keeper_name = "SHOPKEEPER"
			_speak(SHOP_HELLO[randi() % SHOP_HELLO.size()])
			if not compact:
				Sfx.play("shop_bell")
		"sage":
			_keeper_look = 16
			_keeper_name = SAGE_NAMES[_rng.randi() % SAGE_NAMES.size()]
			_place_name = "THE HUT OF " + _keeper_name
			_speak(SAGE_HELLO[randi() % SAGE_HELLO.size()])
			Sfx.play("door_open", -6.0)
		"inn":
			_keeper_look = 17
			_place_name = INN_NAMES[_rng.randi() % INN_NAMES.size()]
			_keeper_name = "INNKEEPER"
			_speak(INN_HELLO[randi() % INN_HELLO.size()])
			Sfx.play("door_open", -6.0)
		_:
			_keeper_look = _rng.randi() % Villages.VILLAGER_LOOKS
			_keeper_name = Villages.FIRST_NAMES[_rng.randi() % Villages.FIRST_NAMES.size()]
			_place_name = _keeper_name + "'S HOME"
			_speak(HOME_HELLO[randi() % HOME_HELLO.size()])
			Sfx.play("door_open", -6.0)
			# some folk give you something, once
			if not villages.gifts_given.has(door) and _rng.randf() < 0.45:
				villages.gifts_given[door] = true
				_give_gift()
			else:
				villages.gifts_given[door] = true
	_build_options()


func _close() -> void:
	visible = false
	hero.player.ui_lock = return_lock
	Sfx.play("ui_back")


func _speak(text: String, col: Color = C_TEXT) -> void:
	_say = text
	_shown = 0.0
	_say_col = col


func _give_gift() -> void:
	var inv := hero.inventory
	if _rng.randf() < 0.6:
		var n := _rng.randi_range(2, 5)
		inv.rubies += n
		inv.changed.emit()
		_speak(HOME_GIFT + " (+" + str(n) + " RUBIES)", C_GOOD)
		Sfx.play("coin")
	elif inv.slot_for("red_berry") != -1:
		inv.add_stack({"id": "red_berry", "qty": 1})
		_speak(HOME_GIFT + " (+ RED BERRIES)", C_GOOD)
		Sfx.play("pickup")


# --- What you can do -------------------------------------------------------------------

func _build_options() -> void:
	_options.clear()
	match _kind:
		"shop":
			var stock := _stock()
			for i in stock.size():
				var st: Dictionary = stock[i]
				if st.get("once", false) and villages.sold.has(_sold_key(i)):
					continue
				_options.append({"label": Items.label(st), "price": Items.price(st), "stack": st, "index": i, "act": "buy"})
		"sage":
			var missing := hero.inventory.max_health - hero.inventory.health
			_options.append({"label": "MEND MY WOUNDS", "price": _sage_price() if missing > 0 else 0, "act": "heal"})
			_options.append({"label": "ASK FOR ADVICE", "price": 0, "act": "advice"})
		"inn":
			_options.append({"label": "SLEEP UNTIL MORNING", "price": INN_PRICE, "act": "sleep"})
			_options.append({"label": "A HOT MEAL", "price": MEAL_PRICE, "act": "meal"})
		_:
			_options.append({"label": "TALK", "price": 0, "act": "talk"})
	_options.append({"label": "LEAVE", "price": 0, "act": "leave"})
	_sel = clampi(_sel, 0, _options.size() - 1)


func _sage_price() -> int:
	var missing := hero.inventory.max_health - hero.inventory.health
	return maxi(SAGE_MIN, missing * SAGE_PER_HEART)


func _sold_key(i: int) -> String:
	return str(_vi) + ":" + str(i)


## This village's shop shelves: the staples, then a few one-off finds that
## suit how deep the village lies (better gear deeper in).
func _stock() -> Array:
	var v: Dictionary = villages.list[_vi]
	var out: Array = []
	for id in SHOP_ALWAYS:
		out.append({"id": id, "qty": 1})
	var rng := RandomNumberGenerator.new()
	rng.seed = int(v.seed) + 55
	var p: float = world.progress.call(v.gates[0]) if world.progress.is_valid() else 0.3
	var seen := {}
	var tries := 0
	while out.size() < SHOP_ALWAYS.size() + 4 and tries < 60:
		tries += 1
		var st := Items.roll_stack(rng, clampf(p + 0.15, 0.0, 1.0))
		if SHOP_ALWAYS.has(st.id) or seen.has(st.id) or Items.kind(st.id) in ["matches", "flare", "lantern", "key", "ruby"]:
			continue
		seen[st.id] = true
		st["once"] = true
		out.append(st)
	return out


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_shown = minf(_shown + delta * CHARS_PER_SEC, float(_say.length()))
	_canvas.queue_redraw()
	if Engine.get_process_frames() == _opened_frame:
		return
	if Input.is_action_just_pressed(pfx + "run") or Input.is_action_just_pressed(pfx + "inventory"):
		_close()
	elif Input.is_action_just_pressed(pfx + "move_up"):
		_sel = posmod(_sel - 1, _options.size())
		Sfx.play("ui_move")
	elif Input.is_action_just_pressed(pfx + "move_down"):
		_sel = posmod(_sel + 1, _options.size())
		Sfx.play("ui_move")
	elif Input.is_action_just_pressed(pfx + "confirm"):
		if _shown < _say.length():
			_shown = _say.length()   # finish the sentence first
		else:
			_do(_options[_sel])
	_scroll = clampi(_scroll, _sel - LIST_ROWS + 1, _sel)


func _pay(price: int) -> bool:
	if hero.inventory.rubies < price:
		_speak("YOU'RE " + str(price - hero.inventory.rubies) + " RUBIES SHORT, FRIEND.", C_BAD)
		Sfx.play("ui_deny")
		return false
	hero.inventory.rubies -= price
	hero.inventory.changed.emit()
	return true


func _do(o: Dictionary) -> void:
	var inv := hero.inventory
	var lan := hero.lantern
	match o.act:
		"leave":
			_close()
		"buy":
			var st: Dictionary = o.stack
			var id: String = st.id
			var info := Items.get_info(id)
			# can you carry it?
			match info.kind:
				"lantern":
					if float(info.max_fuel) <= lan.max_fuel:
						_speak("YOUR LANTERN IS AS GOOD AS THAT ONE ALREADY.", C_DIM)
						Sfx.play("ui_deny")
						return
				"matches":
					if lan.room_for_matches() <= 0:
						_speak("YOUR MATCHBOX IS FULL.", C_DIM)
						Sfx.play("ui_deny")
						return
				"flare":
					pass
				_:
					if inv.slot_for(id) == -1:
						_speak("YOUR BAG IS FULL. MAKE SOME ROOM FIRST.", C_DIM)
						Sfx.play("ui_deny")
						return
			if not _pay(int(o.price)):
				return
			match info.kind:
				"lantern":
					lan.upgrade(info.max_fuel, info.radius)
					lan.lantern_id = id
				"matches":
					lan.add_matches(int(info.amount))
				"flare":
					flares.add(1)
				_:
					var one := st.duplicate()
					one.erase("once")
					one.qty = 1
					inv.add_stack(one)
			if st.get("once", false):
				villages.sold[_sold_key(int(o.index))] = true
				_build_options()
			Sfx.play("buy")
			_speak(SHOP_THANKS[randi() % SHOP_THANKS.size()] + " (" + Items.with_article(id) + ")", C_GOOD)
		"heal":
			if inv.health >= inv.max_health:
				_speak("YOU ARE WHOLE ALREADY. SAVE YOUR RUBIES.", C_DIM)
				return
			if not _pay(_sage_price()):
				return
			inv.health = inv.max_health
			inv.changed.emit()
			Sfx.play("sage")
			_speak("THERE. THE WOUNDS ARE CLOSED. TRY TO KEEP THEM THAT WAY.", C_GOOD)
			_build_options()
		"advice":
			_speak(SAGE_TIPS[randi() % SAGE_TIPS.size()])
			Sfx.play("page")
		"meal":
			if inv.health >= inv.max_health:
				_speak("YOU'RE NOT HUNGRY. NOBODY'S THAT HUNGRY AT FULL STRENGTH.", C_DIM)
				return
			if not _pay(MEAL_PRICE):
				return
			inv.heal(MEAL_HEAL)
			Sfx.play("eat")
			_speak("HOT STEW AND BLACK BREAD. +" + str(MEAL_HEAL) + " HEARTS.", C_GOOD)
		"sleep":
			if day.forever_night:
				_speak("NO MORNING COMES THIS DEEP, FRIEND. NOT ANY MORE.", C_DIM)
				Sfx.play("ui_deny")
				return
			if day.is_day():
				_speak("THE SUN'S STILL UP! COME BACK WHEN IT'S DARK.", C_DIM)
				Sfx.play("ui_deny")
				return
			var other := hero.partner()
			if other != null and other.alive() and other.battle.is_active():
				_speak("YOUR FRIEND IS FIGHTING FOR THEIR LIFE OUT THERE! NOT NOW.", C_BAD)
				Sfx.play("ui_deny")
				return
			if not _pay(INN_PRICE):
				return
			_close()
			sleep.call()
		"talk":
			_talk_i = (_talk_i + 1 + randi() % 3) % HOME_TALK.size()
			_speak(HOME_TALK[_talk_i])
			Sfx.play("voice" + str(randi() % 4), -4.0)


# --- Drawing --------------------------------------------------------------------------

func _draw_screen() -> void:
	if _vi < 0:
		return
	var c := _canvas
	var screen := c.get_viewport_rect().size
	if compact:
		c.draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.35))
		c.draw_rect(Rect2(Vector2(0, 0), Vector2(screen.x, 15)), Color(0.03, 0.02, 0.05, 0.9))
	else:
		UiKit.backdrop(c, screen)
	PixelFont.draw(c, Vector2(floorf((screen.x - PixelFont.width_of(_place_name)) / 2.0), 5), _place_name, C_PICK)
	# rubies, top right
	Items.draw_icon(c, "ruby", Rect2(screen.x - 46, 1, 16, 16))
	PixelFont.draw(c, Vector2(screen.x - 30, 6), "X" + str(hero.inventory.rubies), C_TEXT)
	# hearts, top left
	PixelFont.draw(c, Vector2(8, 6), "HEARTS " + str(hero.inventory.health) + "/" + str(hero.inventory.max_health),
		C_TEXT if hero.inventory.health > 3 else C_BAD)
	# the room
	if not compact:
		var room := Rect2(8, 18, 160, 150)
		UiKit.panel(c, room, "", true)
		_draw_room(c, room.grow(-2))
	# the list
	var lr := Rect2(176, 18, 176, 150)
	UiKit.panel(c, lr, {"shop": "FOR SALE", "sage": "THE SAGE", "inn": "THE INN"}.get(_kind, "VISIT"), true)
	for k in mini(LIST_ROWS, _options.size()):
		var i := _scroll + k
		if i >= _options.size():
			break
		var o: Dictionary = _options[i]
		var row := Rect2(lr.position + Vector2(4, 8 + k * (ROW_H + 1)), Vector2(lr.size.x - 8, ROW_H))
		var picked := i == _sel
		c.draw_rect(row, C_ROW_PICK if picked else C_ROW)
		if picked:
			c.draw_rect(Rect2(row.position, Vector2(2, row.size.y)), C_PICK)
		var tx := row.position.x + 5
		if o.has("stack"):
			Items.draw_icon(c, o.stack.id, Rect2(row.position + Vector2(3, -1), Vector2(16, 16)))
			tx += 17
		var price := int(o.price)
		var label: String = o.label
		var can := price <= hero.inventory.rubies
		PixelFont.draw(c, Vector2(tx, row.position.y + 5), label, (C_PICK if picked else C_TEXT) if can or price == 0 else C_DIM)
		if price > 0:
			var ps := str(price)
			var px := row.end.x - 6 - PixelFont.width_of(ps)
			PixelFont.draw(c, Vector2(px, row.position.y + 5), ps, C_RUBY if can else Color(C_RUBY, 0.45))
			c.draw_rect(Rect2(px - 5, row.position.y + 6, 3, 3), C_RUBY if can else Color(C_RUBY, 0.45))
	if _scroll > 0:
		PixelFont.draw(c, lr.position + Vector2(lr.size.x - 12, 2), "^", C_DIM)
	if _scroll + LIST_ROWS < _options.size():
		PixelFont.draw(c, lr.end - Vector2(12, 8), "V", C_DIM)
	# what the selected thing is (shop)
	var o2: Dictionary = _options[_sel] if _sel < _options.size() else {}
	# the speech box
	var box := Rect2(8, 174, 344, 46)
	Dialog.draw_panel(c, box)
	Villages.draw_portrait(c, _keeper_look, box.position + Vector2(6, 9), 1.0, _time)
	var text := _say
	PixelFont.draw(c, box.position + Vector2(26, 6), _keeper_name, C_PICK)
	var lines := Dialog.wrap_text(text, int(box.size.x) - 34)
	var used := 0
	var y := box.position.y + 16
	for line in lines:
		var part := text.substr(used, line.length()).substr(0, maxi(0, int(_shown) - used))
		PixelFont.draw(c, Vector2(box.position.x + 26, y), part, _say_col)
		used += line.length() + 1
		y += 8
	if o2.has("stack"):
		var desc: String = Items.get_info(o2.stack.id).desc
		var sl := Items.short_stat_of(o2.stack)
		var info := (sl + "  " if sl != "" else "") + desc
		var dl := Dialog.wrap_text(info, int(screen.x) - 20)
		if not dl.is_empty():
			PixelFont.draw(c, Vector2(10, screen.y - 17), dl[0], C_DIM)
	var help := "ENTER CHOOSE  / LEAVE" if pfx == "p2_" else "Z CHOOSE   X LEAVE"
	PixelFont.draw(c, Vector2(screen.x - 8 - PixelFont.width_of(help), screen.y - 9), help, C_DIM)


## The inside of the building, with its keeper.
func _draw_room(c: CanvasItem, r: Rect2) -> void:
	var wall: Color = {"shop": Color("4a3424"), "sage": Color("2e2440"), "inn": Color("5a3a26")}.get(_kind, Color("443428"))
	var floor_c: Color = {"shop": Color("6a4a30"), "sage": Color("3a3048"), "inn": Color("6e4a2c")}.get(_kind, Color("5e4630"))
	var floor_y := r.position.y + r.size.y * 0.62
	c.draw_rect(Rect2(r.position, Vector2(r.size.x, floor_y - r.position.y)), wall)
	# wall planks / stones
	for i in range(int(r.position.x), int(r.end.x), 12):
		c.draw_rect(Rect2(i, r.position.y, 1, floor_y - r.position.y), wall.darkened(0.25))
	c.draw_rect(Rect2(r.position.x, floor_y, r.size.x, r.end.y - floor_y), floor_c)
	for i in range(int(floor_y) + 6, int(r.end.y), 7):
		c.draw_rect(Rect2(r.position.x, i, r.size.x, 1), floor_c.darkened(0.2))
	c.draw_rect(Rect2(r.position.x, floor_y, r.size.x, 2), wall.darkened(0.45))
	var mid := r.position.x + r.size.x / 2.0
	match _kind:
		"shop":
			# shelves of goods behind the counter
			for s in 3:
				var sy := r.position.y + 12 + s * 22
				c.draw_rect(Rect2(r.position.x + 8, sy + 14, r.size.x - 16, 3), Color("8a5a34"))
				for k in 7:
					var ids := ["healing_tonic", "lamp_oil", "flare", "matches", "red_berry", "brass_lantern", "bomb", "windbreak"]
					Items.draw_icon(c, ids[(k + s * 3) % ids.size()], Rect2(r.position.x + 10 + k * 20, sy, 16, 16))
		"sage":
			# a star chart, candles, hanging herbs
			c.draw_circle(Vector2(mid, r.position.y + 30), 22, Color("1a1430"))
			for k in 9:
				var a := float(k) * 0.7 + _time * 0.1
				c.draw_rect(Rect2(Vector2(mid, r.position.y + 30) + Vector2(cos(a), sin(a)) * (6 + k * 1.7), Vector2(1, 1)), Color("f5e08a"))
			for k in 4:
				var hx := r.position.x + 14 + k * 38
				c.draw_rect(Rect2(hx, r.position.y, 1, 10), Color("6a5a40"))
				c.draw_rect(Rect2(hx - 2, r.position.y + 10, 5, 6), Color("5a8a4a"))
			for k in [r.position.x + 18, r.end.x - 22]:
				c.draw_rect(Rect2(k, floor_y - 18, 4, 12), Color("e8dfc8"))
				var fl := 1.0 + sin(_time * 9.0 + k) * 0.5
				c.draw_rect(Rect2(k + 1, floor_y - 22 - fl, 2, 3 + fl), Color("ffcf6a"))
		"inn":
			# a hearth with a fire, and a bed
			c.draw_rect(Rect2(r.position.x + 10, floor_y - 40, 40, 40), Color("6e6458"))
			c.draw_rect(Rect2(r.position.x + 16, floor_y - 26, 28, 26), Color("1a1010"))
			for k in 5:
				var fh := 8.0 + sin(_time * 8.0 + k * 1.7) * 4.0
				c.draw_rect(Rect2(r.position.x + 19 + k * 5, floor_y - fh - 2, 4, fh), Color("f5a33a") if k % 2 else Color("ffcf6a"))
			c.draw_rect(Rect2(r.end.x - 58, floor_y - 6, 50, 14), Color("7a5232"))
			c.draw_rect(Rect2(r.end.x - 56, floor_y - 10, 46, 8), Color("4d6fb0"))
			c.draw_rect(Rect2(r.end.x - 56, floor_y - 10, 12, 6), Color("e8dfc8"))
		_:
			# a table, a window, a pot on the stove
			c.draw_rect(Rect2(r.position.x + 14, r.position.y + 14, 24, 20), Color("2a3a5a"))
			c.draw_rect(Rect2(r.position.x + 14, r.position.y + 14, 24, 20).grow(1), Color("3a2618"), false)
			c.draw_rect(Rect2(r.position.x + 25, r.position.y + 14, 1, 20), Color("3a2618"))
			c.draw_rect(Rect2(r.end.x - 40, floor_y - 30, 28, 30), Color("3a3440"))
			c.draw_rect(Rect2(r.end.x - 34, floor_y - 38, 16, 9), Color("2a2430"))
			c.draw_rect(Rect2(r.end.x - 31, floor_y - 44 + sin(_time * 2.0) * 1.0, 2, 4), Color(0.85, 0.85, 0.9, 0.5))
	# the counter / table in front, and the keeper behind it
	Villages.draw_portrait(c, _keeper_look, Vector2(mid - 24, floor_y - 58), 3.0, _time)
	if _kind == "shop" or _kind == "inn":
		c.draw_rect(Rect2(r.position.x + 20, floor_y + 6, r.size.x - 40, 22), Color("7a5232"))
		c.draw_rect(Rect2(r.position.x + 20, floor_y + 6, r.size.x - 40, 3), Color("a87448"))
	elif _kind != "sage":
		c.draw_rect(Rect2(mid - 30, floor_y + 12, 60, 14), Color("6a4628"))
		c.draw_rect(Rect2(mid - 30, floor_y + 12, 60, 2), Color("8a5a34"))
