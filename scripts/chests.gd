class_name Chests
extends Node2D
## Wooden chests tucked into rooms and dead ends, holding 1-3 items each.
## Face one and press A to open the chest screen, where you can take items
## out or store items in it (chests double as storage, up to 6 items).
##
## Milestone 5 adds bronze / silver / gold / purple chests that hold keys.

var pfx := ""   ## input action prefix: "" for player 1, "p2_" for player 2

signal opened_first(c: Vector2i)

const PROPS_TEX: Texture2D = preload("res://assets/props.png")
const CLOSED_SPRITE := 8   # columns in props.png
const OPEN_SPRITE := 9
const OPEN_PAUSE := 0.55   # seconds of glow in the world before the chest screen
const ROOM_CHANCE := 0.55  # chance each room (except the start) gets a chest
const TILES_PER_DEAD_END_CHEST := 350   # extra chests tucked in dead ends
## Every labyrinth has at least these, so a run is always survivable.
const RUBY_CHANCE := 0.3          # chance a chest holds rubies (rising to 0.5 at the bottom)
const RUBY_DEPTH_BONUS := 4.0     # extra rubies per chest at the very bottom
const GUARANTEED := ["lamp_oil", "healing_tonic", "matches"]

var world: World
var player: Player
var inventory: Inventory
var lantern: Lantern
var flares: Flares
var dialog: Dialog
var screen: ChestScreen
var pickups: Pickups
var chests := {}     # cell -> {"open": bool, "items": Array[Dictionary] of {id, qty}}
var revealed := {}   # cells shown on the map by a Seer's Draught
var _rng := RandomNumberGenerator.new()


func setup(w: World, p: Player, inv: Inventory, l: Lantern, f: Flares, d: Dialog) -> void:
	world = w
	player = p
	inventory = inv
	lantern = l
	flares = f
	dialog = d
	_rng.seed = world.seed_value + 303
	_place()


func _place() -> void:
	var spots: Array[Vector2i] = []
	var start_room := world.room_at(world.start_cell)
	for r in world.rooms:
		if r == start_room or _rng.randf() > ROOM_CHANCE:
			continue
		var inner := r.grow(-1)
		for attempt in 8:
			var c := Vector2i(_rng.randi_range(inner.position.x, inner.end.x - 1),
				_rng.randi_range(inner.position.y, inner.end.y - 1))
			if _can_block(c):
				spots.append(c)
				world.blockers[c] = true
				break
	var dead_ends: Array[Vector2i] = []
	for y in world.height:
		for x in world.width:
			var c := Vector2i(x, y)
			if world.room_at(c).size == Vector2i.ZERO and (_is_dead_end(c) or (world.nooks.has(c) and world.is_walkable(c))) and _can_block(c):
				dead_ends.append(c)
	for n in (world.width * world.height) / TILES_PER_DEAD_END_CHEST:
		if dead_ends.is_empty():
			break
		var c: Vector2i = dead_ends.pop_at(_rng.randi() % dead_ends.size())
		if _can_block(c):
			spots.append(c)
			world.blockers[c] = true
	# Fill them: 1-3 items each, plus the guaranteed items in random chests.
	for c in spots:
		var items: Array[Dictionary] = []
		var n := 1 if _rng.randf() < 0.4 else (2 if _rng.randf() < 0.67 else 3)
		var progress: float = world.progress.call(c) if world.progress.is_valid() else 0.0
		for k in n:
			var st := Items.roll_stack(_rng, progress)
			add_to_chest(items, st.id, st)
		# Rubies: more of them, and bigger handfuls, deeper in.
		if _rng.randf() < RUBY_CHANCE + progress * 0.2 and items.size() < ChestScreen.CAPACITY:
			items.append({"id": "ruby", "qty": _rng.randi_range(1, 3) + int(round(progress * RUBY_DEPTH_BONUS))})
		chests[c] = {"open": false, "items": items}
	if not spots.is_empty():
		for id in GUARANTEED:
			_add_to(chests[spots[_rng.randi() % spots.size()]].items, id)
	queue_redraw()


## Adds one of `id` to a chest's item list (stacking potions up to 3).
## Returns false if the chest is full.
static func add_to_chest(items: Array, id: String, from_stack: Dictionary = {}) -> bool:
	if Items.stacks(id):
		for st in items:
			if st.id == id and st.qty < Inventory.MAX_STACK:
				st.qty += 1
				return true
	if items.size() >= ChestScreen.CAPACITY:
		return false
	var st := {"id": id, "qty": 1}
	if Items.bonus(from_stack) > 0:
		st["bonus"] = Items.bonus(from_stack)
	items.append(st)
	return true


func _add_to(items: Array, id: String) -> void:
	add_to_chest(items, id)


func _is_dead_end(c: Vector2i) -> bool:
	if not world.is_walkable(c):
		return false
	var exits := 0
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if world.is_walkable(c + d):
			exits += 1
	return exits == 1


## A chest may go here only if it's plain ground and doesn't cut anything off.
func _can_block(c: Vector2i) -> bool:
	var t := world.tile_at(c)
	if c == world.start_cell or not (t == "." or t == ","):
		return false
	if world.doors.has(c) or world.reserved.has(c) or world.near_village(c, 1) or world.ramps.has(c):
		return false
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if world.doors.has(c + d):
			return false  # never right in front of a door
		if chests.has(c + d):
			return false  # never wall off another chest
	if world.blockers.has(c):
		return false
	# Fast path: blocking a dead-end tip can't cut anything else off.
	var open_sides := 0
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if world.is_walkable(c + d) or world.doors.has(c + d):
			open_sides += 1
	if open_sides == 1:
		return true
	return world.safe_to_block(c, world.doors)


func nearest_closed(from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for c in chests:
		if not chests[c].open and not revealed.has(c):
			var d := (Vector2(c) - Vector2(from)).length()
			if d < best_d:
				best_d = d
				best = c
	return best


func reveal(c: Vector2i) -> void:
	revealed[c] = true
	world.map_area(c)


## Points this system at one player (see Hero.bind_all).
func bind(h: Hero) -> void:
	player = h.player
	inventory = h.inventory
	lantern = h.lantern
	dialog = h.dialog
	screen = h.chest_screen
	pfx = h.pfx


## Run once per player per frame, bound to that player (main.gd).
func hero_tick() -> void:
	if not player.can_act() or player.moving:
		return
	# Standing on a floor item? Then A picks that up instead (see pickups.gd).
	if pickups != null and pickups.needs_button(player.cell):
		return
	if Input.is_action_just_pressed(pfx + "confirm"):
		var c := player.facing_cell()
		if chests.has(c):
			var chest: Dictionary = chests[c]
			if chest.open:
				screen.open_chest(chest)
				return
			# First time: the lid swings up, light spills out, then the screen.
			opened_first.emit(c)
			chest.open = true
			queue_redraw()
			player.ui_lock = "chest_opening"
			var pl := player
			var scr := screen
			var show := func() -> void:
				pl.ui_lock = ""
				scr.open_chest(chest)
			get_tree().create_timer(OPEN_PAUSE).timeout.connect(show)


## Applies an item that doesn't use a slot. Returns the text box message.
func apply_free_item(id: String) -> String:
	var info := Items.get_info(id)
	match info.kind:
		"ruby":
			inventory.rubies += 1
			inventory.changed.emit()
			return "+1 RUBY"
		"matches":
			var got := lantern.add_matches(info.amount)
			if got == 0:
				return "YOUR MATCHBOX IS FULL."
			return "+" + str(got) + (" MATCHES" if got > 1 else " MATCH")
		"flare":
			flares.add(info.amount)
			return "+1 FLARE"
		"lantern":
			if info.max_fuel > lantern.max_fuel:
				lantern.upgrade(info.max_fuel, info.radius)
				lantern.lantern_id = id
				return "YOU TAKE " + Items.with_article(id) + ". YOUR LIGHT BURNS LONGER AND BRIGHTER."
			lantern.add_matches(2)
			return "AN OLD LANTERN, NO BETTER THAN YOURS. YOU SALVAGE 2 MATCHES."
	return ""


## Bag is full: ask which slot to give up for `stack`. If the player picks a
## slot, on_swap is called with the stack they gave up. "Leave it" does nothing.
func offer_swap(id: String, stack: Dictionary, on_swap: Callable) -> void:
	var options: Array[String] = []
	for s in inventory.slots:
		options.append(Items.label(s) + (" X" + str(s.qty) if s.qty > 1 else ""))
	options.append("LEAVE IT")
	var h := Hero.bound
	var on_choice := func(choice: int) -> void:
		if choice >= Inventory.SLOTS:
			return
		if h != null:
			Hero.bind_all(h)
		var given_up := inventory.take_slot(choice)
		var taken := stack.duplicate()
		inventory.put_slot(choice, taken)
		on_swap.call(given_up)
		dialog.say("YOU TAKE THE " + Items.display_name(id) + " AND LEAVE THE "
			+ Items.display_name(given_up.id) + ".", id)
	var stat := Items.short_stat(id)
	var question := "YOUR BAG IS FULL. SWAP SOMETHING FOR " + Items.with_article(id) \
		+ (", " + stat if stat != "" else "") + "?"
	dialog.ask(question, options, on_choice, id)


const MASTER_TEX: Texture2D = preload("res://assets/master.png")


func _draw() -> void:
	for c in chests:
		var dst := Rect2(world.cell_to_position(c), Vector2(16, 16))
		if chests[c].get("purple", false):
			draw_texture_rect_region(MASTER_TEX, dst, Rect2(32 if chests[c].open else 16, 8, 16, 16))
			continue
		Shadows.oval(self, dst.position + Vector2(8, 14), 14)
		var sprite := OPEN_SPRITE if chests[c].open else CLOSED_SPRITE
		draw_texture_rect_region(PROPS_TEX, dst, Rect2(sprite * 16, 0, 16, 16))
