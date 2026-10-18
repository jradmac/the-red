class_name Pickups
extends Node2D
## Items on the floor: loose matches and flares (scattered when the labyrinth
## is made, often in dead ends) and anything you drop from your bag.
## They hover where they lie. Stand on one and press A to pick it up; if your
## bag is full you'll be asked what to swap. You only see them in your light.

var pfx := ""   ## input action prefix: "" for player 1, "p2_" for player 2

signal picked(text: String)

const CELLS_PER_MATCH := 160   # roughly one loose match per this many floor tiles (light is scarce)
const TILES_PER_FLARE := 1200  # loose flares: one per this many map tiles
const EARLY_MATCHES := 3      # a few extra matches tucked away in the first stretch ...
const EARLY_UNTIL := 0.12     # ... (enough to see the first night through -- just, if you look)
const DEEP_KEEP := 1.0        # loose matches thin out the deeper you go: this share is left at the bottom
const CELLS_PER_RUBY := 220    # loose rubies: one per this many floor tiles (1-3 each, more deeper)

var world: World
var player: Player
var lantern: Lantern
var flares: Flares
var inventory: Inventory
var chests: Chests
var dialog: Dialog
var ground := {}   # cell -> {"id": String, "qty": int}
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func setup(w: World, p: Player, l: Lantern, f: Flares, inv: Inventory, ch: Chests, d: Dialog) -> void:
	world = w
	player = p
	lantern = l
	flares = f
	inventory = inv
	chests = ch
	dialog = d
	_rng.seed = world.seed_value + 202
	_scatter()
	# Matches, flares and lanterns are grabbed the instant you step on them,
	# even mid-stride (no need to stop).
	# (main connects each hero's footsteps to _on_stepped)


func _scatter() -> void:
	var start_room := world.room_at(world.start_cell)
	var dead_ends: Array[Vector2i] = []
	var others: Array[Vector2i] = []
	for y in world.height:
		for x in world.width:
			var c := Vector2i(x, y)
			if not (world.tile_at(c) == "." or world.tile_at(c) == ",") or not world.is_walkable(c):
				continue
			if start_room.has_point(c) or world.in_village(c):
				continue
			var exits := 0
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if world.is_walkable(c + d):
					exits += 1
			if exits == 1 or world.nooks.has(c):
				dead_ends.append(c)
			else:
				others.append(c)
	var total := (dead_ends.size() + others.size()) / CELLS_PER_MATCH
	var flare_count := maxi(2, (world.width * world.height) / TILES_PER_FLARE)
	var spots: Array[Vector2i] = []
	for c in dead_ends:
		if _rng.randf() < 0.6:
			spots.append(c)
	while spots.size() < total + flare_count and not others.is_empty():
		spots.append(others.pop_at(_rng.randi() % others.size()))
	for i in range(spots.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var tmp := spots[i]
		spots[i] = spots[j]
		spots[j] = tmp
	for i in mini(spots.size(), total + flare_count):
		if i >= flare_count and world.progress.is_valid():
			# fewer and fewer loose matches the deeper you go
			var keep := lerpf(1.0, DEEP_KEEP, clampf(float(world.progress.call(spots[i])), 0.0, 1.0))
			if _rng.randf() > keep:
				continue
		ground[spots[i]] = {"id": "flare" if i < flare_count else "loose_match", "qty": 1}
	# A few more matches in the first stretch of the labyrinth, while you're
	# still learning your way around (light gets scarcer the deeper you go).
	if world.progress.is_valid():
		var early: Array[Vector2i] = []
		for c in dead_ends + others:
			if not ground.has(c) and float(world.progress.call(c)) < EARLY_UNTIL:
				early.append(c)
		var placed := 0
		var tries := 0
		while placed < EARLY_MATCHES and not early.is_empty() and tries < 20000:
			tries += 1
			var i := _rng.randi() % early.size()
			ground[early.pop_at(i)] = {"id": "loose_match", "qty": 1}
			placed += 1
	# Rubies glint in odd corners, like matches.
	var rubies := (dead_ends.size() + others.size()) / CELLS_PER_RUBY
	var pool: Array[Vector2i] = []
	for c in dead_ends + others:
		if not ground.has(c):
			pool.append(c)
	for n in rubies:
		if pool.is_empty():
			break
		var c: Vector2i = pool.pop_at(_rng.randi() % pool.size())
		var p: float = world.progress.call(c) if world.progress.is_valid() else 0.0
		ground[c] = {"id": "ruby", "qty": 1 + (1 if _rng.randf() < p else 0) + (1 if _rng.randf() < p * 0.5 else 0)}


func has_item_at(c: Vector2i) -> bool:
	return ground.has(c)


## Something here you pick up with A (a bag item). Matches, flares, rubies
## and lanterns are picked up by walking over them -- no button.
func needs_button(c: Vector2i) -> bool:
	return ground.has(c) and Items.uses_slot(ground[c].id)


func item_at(c: Vector2i) -> Dictionary:
	return ground.get(c, {})


func drop(c: Vector2i, stack: Dictionary) -> void:
	if stack.is_empty():
		return
	var same: bool = ground.has(c) and ground[c].id == stack.id and Items.kind(stack.id) in ["matches", "ruby", "flare", "potion", "bomb", "key", "tool"]
	if ground.has(c) and not same:
		# never drop something on top of something else (a key would be lost):
		# put it on the nearest free floor instead
		var seen := {c: true}
		var q: Array[Vector2i] = [c]
		var head := 0
		while head < q.size() and head < 400:
			var p: Vector2i = q[head]
			head += 1
			if not ground.has(p) and world.is_walkable(p):
				c = p
				break
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var n: Vector2i = p + d
				if not seen.has(n) and (world.is_walkable(n) or n == c):
					seen[n] = true
					q.append(n)
	elif ground.has(c):
		stack = stack.duplicate()
		stack.qty = int(stack.get("qty", 1)) + int(ground[c].get("qty", 1))
	ground[c] = stack


func bind(h: Hero) -> void:
	player = h.player
	inventory = h.inventory
	lantern = h.lantern
	dialog = h.dialog
	pfx = h.pfx


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()  # hovering animation


## Run once per player per frame, bound to that player (main.gd).
func hero_tick() -> void:
	var c := player.cell
	if not ground.has(c) or not player.can_act() or player.moving:
		return
	# Matches, flares and rubies don't take a slot: walking over them picks them
	# up (a full matchbox just leaves them). Only bag items need A.
	if not Items.uses_slot(ground[c].id):
		_pick_up(c)
	elif Input.is_action_just_pressed(pfx + "confirm"):
		_pick_up(c)


func _on_stepped(c: Vector2i) -> void:
	if ground.has(c) and not Items.uses_slot(ground[c].id) and player.ui_lock == "":
		_pick_up(c)


## A full matchbox leaves matches where they lie, quietly (come back for them later).
func _box_full(c: Vector2i) -> bool:
	if Items.kind(ground[c].id) != "matches" or lantern.room_for_matches() > 0:
		return false
	return true


func _pick_up(c: Vector2i) -> void:
	var stack: Dictionary = ground[c]
	var id: String = stack.id
	if _box_full(c):
		return
	if Items.is_ruby(id):
		ground.erase(c)
		inventory.rubies += int(stack.qty)
		inventory.changed.emit()
		picked.emit("+" + str(stack.qty) + (" RUBIES" if stack.qty > 1 else " RUBY"))
		return
	if not Items.uses_slot(id):
		ground.erase(c)
		for n in stack.qty:
			if Items.kind(id) == "matches" and lantern.room_for_matches() == 0:
				ground[c] = {"id": id, "qty": stack.qty - n}   # the rest waits here
				break
			picked.emit(chests.apply_free_item(id))
		return
	if inventory.slot_for(id) != -1:
		var one := stack.duplicate()
		one.qty = 1
		inventory.add_stack(one)
		stack.qty -= 1
		if stack.qty <= 0:
			ground.erase(c)
		picked.emit("+ " + Items.label(stack))
		return
	var on_swap := func(given_up: Dictionary) -> void:
		ground.erase(c)
		if not given_up.is_empty():
			ground[c] = given_up
	chests.offer_swap(id, stack, on_swap)


func _draw() -> void:
	var nears: Array[Rect2i] = []
	for h in Hero.all:
		nears.append(Rect2i(h.player.cell - Vector2i(16, 12), Vector2i(33, 25)))
	if nears.is_empty():
		nears.append(Rect2i(player.cell - Vector2i(16, 12), Vector2i(33, 25)))
	for c in ground:
		var seen := false
		for near in nears:
			if near.has_point(c):
				seen = true
		if not seen:
			continue
		var o := world.cell_to_position(c)
		var phase := float((c.x * 7 + c.y * 13) % 10)
		var lift := roundf(2.5 + sin(_time * 2.6 + phase) * 1.5)   # 1..4 px off the ground
		var shadow_w := 10.0 - lift
		draw_rect(Rect2(o + Vector2((16.0 - shadow_w) / 2.0, 13), Vector2(shadow_w, 2)), Color(0, 0, 0, 0.4))
		Items.draw_icon(self, ground[c].id, Rect2(o + Vector2(0, -lift), Vector2(16, 16)))
