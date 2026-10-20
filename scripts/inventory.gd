class_name Inventory
extends Node
## 4 item slots, health, and your attack/defense totals.
##
## Stat rule: your ATTACK is every weapon you carry added together (bare fists
## = 1); the one in your hand -- the one you see, on your back and on the attack
## card -- is the strongest of them, and of equally strong ones the one you
## picked up last. Your DEFENSE is your best armor, the one you wear. Potions of
## the same type stack to 3.

signal changed

const SLOTS := 4
const MAX_STACK := 3
const MAX_HEALTH := 10
const START_ITEMS := ["rusty_dagger", "worn_cloak"]
const WINDBREAK_TIME := 60.0

var slots: Array[Dictionary] = []   # each {} (empty) or {"id": String, "qty": int}
var max_health := MAX_HEALTH   ## 10 alone, 5 each with two players
var rubies := 0   ## money, for the villages
var health := MAX_HEALTH
var bomb_planter: Callable   ## set by main: plants a bomb at your feet, returns a message
## Set by main: the tools. Each returns a message for the text box; one that
## starts with "!" means it didn't work (the tool isn't used up).
var seer_user: Callable      ## seer stone: lays the trail to the nearest gate
var portal_planter: Callable ## portal flare: planted at your feet
var ladder_placer: Callable  ## ladder: set against the wall you face
var spirit_user: Callable    ## two players: your fallen partner's spirit brings them back (main.gd)
var windbreak_left := 0.0

# Set by main so potions can affect the world.
var lantern: Lantern
var world: World
var player: Player
var chests: Chests


func _init() -> void:
	for i in SLOTS:
		slots.append({})
	for id in START_ITEMS:
		add(id)
	changed.connect(_stamp_new)


## Every stack that arrives in the bag gets a number, counting up, so "the one
## picked up last" can be told apart (stack["got"]; kept in saves).
func _stamp_new() -> void:
	var top := 0
	for s in slots:
		top = maxi(top, int(s.get("got", 0)))
	for s in slots:
		if not s.is_empty() and not s.has("got"):
			top += 1
			s["got"] = top


## Is stack `a` the better one to hold or wear than `b` (stronger, or as
## strong and picked up later)?
func _better(a: Dictionary, b: Dictionary) -> bool:
	if b.is_empty():
		return true
	var pa := Items.power(a)
	var pb := Items.power(b)
	return pa > pb or (pa == pb and int(a.get("got", 0)) > int(b.get("got", 0)))


func _process(delta: float) -> void:
	windbreak_left = maxf(windbreak_left - delta, 0.0)


## Slot an item would go into (stack first, then an empty slot), or -1.
func slot_for(id: String) -> int:
	if Items.stacks(id):
		for i in SLOTS:
			if slots[i].get("id", "") == id and slots[i].qty < MAX_STACK:
				return i
	for i in SLOTS:
		if slots[i].is_empty():
			return i
	return -1


func add(id: String, qty: int = 1) -> bool:
	for n in qty:
		var i := slot_for(id)
		if i == -1:
			return false
		if slots[i].is_empty():
			slots[i] = {"id": id, "qty": 1}
		else:
			slots[i].qty += 1
	changed.emit()
	return true


## Adds a whole stack (keeps upgrades). Non-stacking items only need a free
## slot; stacking ones go through add(). False if there's no room.
func add_stack(stack: Dictionary) -> bool:
	if Items.stacks(stack.id):
		return add(stack.id, stack.qty)
	var i := slot_for(stack.id)
	if i == -1:
		return false
	slots[i] = stack.duplicate()
	slots[i].qty = 1
	changed.emit()
	return true


## The slot holding your best item of a kind (-1 if none).
func best_slot(kind_name: String) -> int:
	_stamp_new()
	var best := -1
	for i in SLOTS:
		var s := slots[i]
		if not s.is_empty() and Items.kind(s.id) == kind_name and (best < 0 or _better(s, slots[best])):
			best = i
	return best


## Empties slot i and returns what was in it ({} if nothing).
func take_slot(i: int) -> Dictionary:
	var stack := slots[i]
	slots[i] = {}
	changed.emit()
	return stack


## Takes one item out of slot i (one potion from a stack). Returns its id.
func remove_one(i: int) -> String:
	var s := slots[i]
	if s.is_empty():
		return ""
	var id: String = s.id
	s.qty -= 1
	if s.qty <= 0:
		slots[i] = {}
	changed.emit()
	return id


func put_slot(i: int, stack: Dictionary) -> void:
	slots[i] = stack
	changed.emit()


func _total(stat: String, kind_name: String, base: int) -> int:
	var best := 0
	for s in slots:
		if not s.is_empty() and Items.kind(s.id) == kind_name:
			best = maxi(best, int(Items.DATA[s.id][stat]) + Items.bonus(s))
	return best if best > 0 else base


## The id of your best item of a kind (by `stat`), or "" if you have none.
## This is what the hero visibly wears / carries.
func best_id(kind_name: String, stat: String) -> String:
	var i := best_slot(kind_name)
	return String(slots[i].id) if i >= 0 else ""


func attack() -> int:
	var sum := 0
	for s in slots:
		if not s.is_empty() and Items.kind(s.id) == "weapon":
			sum += int(Items.DATA[s.id]["atk"]) + Items.bonus(s)
	return sum if sum > 0 else 1


func defense() -> int:
	return _total("def", "armor", 0)


## How many of an item you carry (across all slots).
func count_of(id: String) -> int:
	var n := 0
	for s in slots:
		if s.get("id", "") == id:
			n += s.qty
	return n


## Removes one of `id` from wherever it is. Returns false if you have none.
func consume(id: String) -> bool:
	for i in SLOTS:
		if slots[i].get("id", "") == id:
			remove_one(i)
			return true
	return false


func heal(amount: int) -> void:
	health = mini(health + amount, max_health)
	changed.emit()


## Uses the potion in slot i. Returns a message for the text box.
func use_slot(i: int) -> String:
	var s := slots[i]
	if s.is_empty() or not (Items.kind(s.id) in ["potion", "bomb", "tool"]):
		return ""
	var msg := ""
	var tool := {"seer_stone": seer_user, "portal_flare": portal_planter, "ladder": ladder_placer,
		"spirit_red": spirit_user, "spirit_blue": spirit_user}
	if tool.has(s.id):
		var use: Callable = tool[s.id]
		if not use.is_valid():
			return ""
		msg = use.call()
		if msg.begins_with("!"):
			return msg.substr(1)   # it didn't work: keep it
	match s.id:
		"bomb":
			if not bomb_planter.is_valid():
				return ""
			msg = bomb_planter.call()
			if msg == "":
				return "YOU CAN'T PLANT A BOMB HERE."
		"healing_tonic":
			if health >= max_health:
				return "YOU'RE ALREADY AT FULL HEALTH."
			var gained := max_health - health
			Sfx.play("drink")
			Sfx.play("heal")
			heal(max_health)
			msg = "WARMTH SPREADS THROUGH YOU. FULLY HEALED (+" + str(gained) + ")."
		"red_berry":
			if health >= max_health:
				return "YOU'RE ALREADY AT FULL HEALTH."
			heal(3)
			Sfx.play("eat")
			Sfx.play("heal", -4.0)
			msg = "YOU EAT THE BERRIES. +3 HEALTH."
		"sunstone":
			lantern.blaze()
			Sfx.play("sunstone")
			msg = "THE STONE CRACKS AND LIGHT POURS OUT. FOR TWO MINUTES, THE DARK HAS NOWHERE TO HIDE."
		"blue_berry":
			if lantern.state != Lantern.State.LIT:
				return "LIGHT YOUR LANTERN FIRST."
			lantern.blue_left = Lantern.BLUE_TIME
			Sfx.play("blue_flame")
			msg = "YOU CRUSH THE BERRIES INTO THE FLAME. IT BURNS BLUE - THE CREATURES FEAR IT."
		"lamp_oil":
			if lantern.state == Lantern.State.LIT and lantern.fuel >= lantern.max_fuel - 2.0:
				return "YOUR LANTERN IS ALREADY FULL."
			lantern.refuel(lantern.max_fuel * 0.5)
			Sfx.play("drink")
			msg = "YOU POUR OIL INTO THE LANTERN. IT BURNS BRIGHT."
		"windbreak":
			windbreak_left = WINDBREAK_TIME
			Sfx.play("blue_flame", -4.0, 0.0, 0.7)
			msg = "A STILLNESS SETTLES AROUND YOUR FLAME."
		"seers_draught":
			var c := chests.nearest_closed(player.cell)
			if c == Vector2i(-1, -1):
				return "NOTHING ANSWERS. NO CHESTS REMAIN."
			chests.reveal(c)
			Sfx.play("riddle", -3.0)
			msg = "A CHEST WHISPERS FROM THE " + _direction(player.cell, c) + ". IT'S ON YOUR MAP."
	s.qty -= 1
	if s.qty <= 0:
		slots[i] = {}
	changed.emit()
	return msg


func _direction(from: Vector2i, to: Vector2i) -> String:
	var d := Vector2(to - from)
	var ns := "NORTH" if d.y < 0 else "SOUTH"
	var ew := "WEST" if d.x < 0 else "EAST"
	if absf(d.x) < absf(d.y) * 0.4:
		return ns
	if absf(d.y) < absf(d.x) * 0.4:
		return ew
	return ns + "-" + ew
