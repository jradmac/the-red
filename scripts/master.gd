class_name MasterChamber
extends Node2D
## The goal of every run.
##
## The master chamber is a sealed purple archway in the room farthest from the
## start (behind the bronze -> silver -> gold doors). It glows faintly, so you
## can spot it from a distance in the dark.
##
## Its key, the Master Key, lies in a purple chest hidden somewhere random,
## preferably behind at least one locked door. Bring the key to the arch and
## pick the 6-pin master seal to win.

var pfx := ""   ## input action prefix: "" for player 1, "p2_" for player 2

signal won

const MASTER_TEX: Texture2D = preload("res://assets/master.png")
const GLOW := Color(0.62, 0.35, 1.0)

var world: World
var player: Player
var inventory: Inventory
var dialog: Dialog
var puzzle: LockPuzzle
var pickups: Pickups
var gate := Vector2i(-1, -1)
var purple_chest := Vector2i(-1, -1)
var opened := false
var _rng := RandomNumberGenerator.new()
var _time := 0.0


## Step 1 (right after doors): put the arch in the far room.
func place_gate(w: World, doors: Doors) -> void:
	world = w
	_rng.seed = world.seed_value + 606
	var room := world.room_at(world.goal_cell)
	var options: Array[Vector2i] = []
	if room.size != Vector2i.ZERO:
		# Prefer the back (top) wall of the room's interior, centered.
		var inner := room.grow(-1)
		for x in range(inner.position.x, inner.end.x):
			options.append(Vector2i(x, inner.position.y))
		options.sort_custom(func(a, b): return absi(a.x - room.get_center().x) < absi(b.x - room.get_center().x))
		for y in range(inner.position.y + 1, inner.end.y):
			for x in range(inner.position.x, inner.end.x):
				options.append(Vector2i(x, y))
	options.append(world.goal_cell)
	for c in options:
		if _try_block(c, doors):
			gate = c
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				world.reserved[c + d] = true
			return


func _try_block(c: Vector2i, doors: Doors) -> bool:
	var t := world.tile_at(c)
	if not world.is_walkable(c) or t == "~":
		return false
	if world.safe_to_block(c, world.doors):
		world.blockers[c] = true
		return true
	return false


## Step 2 (after chests): hide the purple chest with the Master Key.
func place_purple_chest(chests: Chests, doors: Doors) -> void:
	# Prefer sections behind at least one door, and never the start area or
	# the chamber's own room.
	var goal_room := world.room_at(gate)
	var deep: Array[Vector2i] = []
	var any: Array[Vector2i] = []
	for c in doors.section_of:
		if goal_room.has_point(c) or c == world.start_cell:
			continue
		var depth: int = doors.section_depth.get(doors.section_of[c], 0)
		if depth == 0 and (Vector2(c) - Vector2(world.start_cell)).length() < 12:
			continue
		if depth >= 1:
			deep.append(c)
		any.append(c)
	# Try, in order: dead ends behind a door, anywhere behind a door,
	# dead ends anywhere, anywhere. Shuffled within each group.
	var groups: Array = [_tips(deep), deep, _tips(any), any]
	for group in groups:
		var cells: Array[Vector2i] = []
		cells.assign(group)
		for i in range(cells.size() - 1, 0, -1):
			var j := _rng.randi() % (i + 1)
			var tmp := cells[i]
			cells[i] = cells[j]
			cells[j] = tmp
		for c in cells:
			if pickups.has_item_at(c) or not chests._can_block(c):
				continue
			world.blockers[c] = true
			chests.chests[c] = {"open": false, "purple": true, "items": [{"id": "purple_key", "qty": 1}]}
			purple_chest = c
			chests.queue_redraw()
			return
	push_warning("Could not place the purple chest")


func _tips(cells: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells:
		var exits := 0
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if world.is_walkable(c + d) or world.doors.has(c + d):
				exits += 1
		if exits == 1:
			out.append(c)
	return out


func setup(p: Player, inv: Inventory, d: Dialog, lp: LockPuzzle, pk: Pickups, lighting: Lighting) -> void:
	player = p
	inventory = inv
	dialog = d
	puzzle = lp
	pickups = pk
	if gate.x >= 0:
		lighting.add_light(world, world.cell_to_position(gate) + Vector2(8, 4), 34.0, GLOW, 0.9, 0.06)


func bind(h: Hero) -> void:
	player = h.player
	inventory = h.inventory
	dialog = h.dialog
	puzzle = h.lock_puzzle
	pfx = h.pfx


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Run once per player per frame, bound to that player (main.gd).
func hero_tick() -> void:
	if opened or player == null or not player.can_act() or player.moving:
		return
	if pickups.needs_button(player.cell):
		return
	if Input.is_action_just_pressed(pfx + "confirm") and player.facing_cell() == gate:
		if inventory.count_of("purple_key") <= 0:
			dialog.say("A PURPLE SEAL BARS THE MASTER CHAMBER. SOMEWHERE IN THE DARK, A PURPLE CHEST HOLDS ITS KEY.", "purple_key")
			return
		var inv := inventory
		var on_done := func(success: bool) -> void:
			if success:
				opened = true
				inv.consume("purple_key")
				won.emit()
		puzzle.start("purple", on_done)


func _draw() -> void:
	if gate.x < 0:
		return
	var o := world.cell_to_position(gate)
	var pulse := 0.85 + 0.15 * sin(_time * 2.0)
	draw_texture_rect_region(MASTER_TEX, Rect2(o + Vector2(0, -8), Vector2(16, 24)), Rect2(0, 0, 16, 24),
		Color(pulse, pulse, pulse) if not opened else Color(1, 1, 1, 0.3))
