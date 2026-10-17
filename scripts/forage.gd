class_name Forage
extends Node2D
## Healing, budgeted. Every section of the labyrinth (the stretch between two
## locked doors) gets enough healing to cover MOST of the damage you can
## expect to take there -- not all of it. You make up the rest by fighting
## well, using the tells, and dodging fights you don't need.
##
##   expected damage = creatures there x share you'll fight x damage per fight
##                     (+ a little for traps and ghosts)
##   healing placed  = COVERAGE x expected damage
##
## That healing comes from healing tonics already in the section's chests,
## then red-berry bushes (forest and riverbank), then extra tonics left on
## the floor and in chests. Blue-berry bushes grow in the marshes and on the
## mountains. Bushes are picked by walking into them, and grow back at dawn.

signal picked(text: String)

const TEX: Texture2D = preload("res://assets/bushes.png")
const COVERAGE := 0.8          # share of the expected damage the map heals
const FIGHT_SHARE := 0.35      # share of a section's creatures you'll end up fighting (most insects keep away)
const OVERHEAD := 1.15         # traps and ghosts on top of fights
const BERRY_SHARE := 0.6       # of a section's healing, how much is berries (where they grow)
const BERRIES_PER_BUSH := 2
const RED_HEAL := 3
const TONIC_HEAL := 7         # a tonic heals fully; drunk when low, it is worth about 7
const TILES_PER_BLUE_BUSH := 350   # of marsh / mountain ground
const TILES_PER_RED_BUSH := 150    # at least this many red bushes in forest / riverbank

var world: World
var player: Player
var inventory: Inventory
var bushes := {}      # cell -> {"blue": bool, "berries": int}
var _shake := {}      # cell -> seconds left shaking
var report: Array[Dictionary] = []   # per depth: what the budget asked for and what was placed
var _rng := RandomNumberGenerator.new()


## Average damage a fight costs at `p` (0 = start .. 1 = deepest), from
## simulating the battle rules against a player who reads the tells and has
## the gear you'd expect to find by then.
static func damage_per_fight(p: float) -> float:
	return 3.2 + 5.4 * p   # fitted to tools/battle_sim.py


func setup(w: World, p: Player, inv: Inventory, chests: Chests, pickups: Pickups, doors: Doors) -> void:
	world = w
	player = p
	inventory = inv
	_rng.seed = world.seed_value + 909
	_place(chests, pickups, doors)


func bind(h: Hero) -> void:
	player = h.player
	inventory = h.inventory


## A berry bush on a village farm (always fruiting by morning).
func add_farm_bush(c: Vector2i, blue: bool) -> void:
	bushes[c] = {"blue": blue, "berries": BERRIES_PER_BUSH, "farm": true}
	world.blockers[c] = true
	queue_redraw()


func bush_at(c: Vector2i) -> bool:
	return bushes.has(c)


## The sun brings the berries back.
func regrow() -> void:
	for c in bushes:
		bushes[c].berries = BERRIES_PER_BUSH
	queue_redraw()


func _place(chests: Chests, pickups: Pickups, doors: Doors) -> void:
	# Sort the open ground by depth.
	var by_depth := {}
	for y in world.height:
		for x in world.width:
			var c := Vector2i(x, y)
			if not world.is_walkable(c):
				continue
			var d := doors.depth_at(c)
			if not by_depth.has(d):
				by_depth[d] = []
			by_depth[d].append(c)
	var max_d := doors.max_depth()
	var start_room := world.room_at(world.start_cell)
	for d in by_depth:
		var cells: Array = by_depth[d]
		var p := clampf(float(d) / float(max_d), 0.0, 1.0)
		var fights := float(cells.size()) / float(Enemies.TILES_PER_CREATURE) * Enemies.density(p) \
			* Enemies.DENSITY_TOTAL * FIGHT_SHARE
		var need := fights * damage_per_fight(p) * OVERHEAD * COVERAGE
		# Tonics the chests here already hold.
		var have := 0.0
		for cc in chests.chests:
			if doors.depth_at(cc) == d:
				for st in chests.chests[cc].items:
					if st.id == "healing_tonic":
						have += TONIC_HEAL * st.qty
		var left := maxf(need - have, 0.0)
		# Red berries where they grow.
		var red_spots: Array[Vector2i] = []
		var blue_spots: Array[Vector2i] = []
		var marsh_tiles := 0
		for c in cells:
			var b := world.biome_at(c)
			if b == World.B_SWAMP or b == World.B_MOUNTAIN:
				marsh_tiles += 1
			if start_room.has_point(c) or not _good_spot(c, chests, pickups):
				continue
			if b == World.B_FOREST or b == World.B_RIVER:
				red_spots.append(c)
			elif b == World.B_SWAMP or b == World.B_MOUNTAIN:
				blue_spots.append(c)
		var want_red := maxi(int(round(left * BERRY_SHARE / float(BERRIES_PER_BUSH * RED_HEAL))),
			red_spots.size() / TILES_PER_RED_BUSH)
		var red := _plant(red_spots, want_red, false, chests, pickups)
		left = maxf(left - red * BERRIES_PER_BUSH * RED_HEAL, 0.0)
		_plant(blue_spots, int(round(float(marsh_tiles) / TILES_PER_BLUE_BUSH)), true, chests, pickups)
		# Whatever's left: healing tonics, in this section's chests and on its floor.
		var tonics := int(ceil(left / TONIC_HEAL))
		var placed := _hide_tonics(cells, tonics, chests, pickups, doors, d)
		report.append({"depth": d, "tiles": cells.size(), "need": need, "chest_hp": have,
			"red_bushes": red, "tonics": placed, "healing": have + red * BERRIES_PER_BUSH * RED_HEAL + placed * TONIC_HEAL})
	queue_redraw()


## Plain ground that can be blocked without cutting any path off.
func _good_spot(c: Vector2i, chests: Chests, pickups: Pickups) -> bool:
	if pickups.ground.has(c) or bushes.has(c):
		return false
	return chests._can_block(c)


func _plant(spots: Array[Vector2i], count: int, blue: bool, chests: Chests, pickups: Pickups) -> int:
	var planted := 0
	while planted < count and not spots.is_empty():
		var c: Vector2i = spots.pop_at(_rng.randi() % spots.size())
		if not _good_spot(c, chests, pickups):
			continue
		var crowded := false
		for b in bushes:
			if (b - c).length() < 3.0:
				crowded = true
				break
		if crowded:
			continue
		bushes[c] = {"blue": blue, "berries": BERRIES_PER_BUSH}
		world.blockers[c] = true
		planted += 1
	return planted


func _hide_tonics(cells: Array, count: int, chests: Chests, pickups: Pickups, doors: Doors, d: int) -> int:
	var placed := 0
	# Half go in this section's chests (where there's room)...
	var section_chests: Array = []
	for cc in chests.chests:
		if doors.depth_at(cc) == d:
			section_chests.append(cc)
	var in_chests := count / 2
	for i in in_chests:
		if section_chests.is_empty():
			break
		var cc: Vector2i = section_chests[_rng.randi() % section_chests.size()]
		if Chests.add_to_chest(chests.chests[cc].items, "healing_tonic"):
			placed += 1
	# ...the rest lie on the floor, mostly at dead ends.
	var floor_spots: Array = []
	for c in cells:
		var t := world.tile_at(c)
		if (t == "." or t == ",") and not pickups.ground.has(c) and not world.blockers.has(c) and not world.doors.has(c):
			floor_spots.append(c)
	var tries := 0
	while placed < count and not floor_spots.is_empty() and tries < 400:
		tries += 1
		var c: Vector2i = floor_spots[_rng.randi() % floor_spots.size()]
		var exits := 0
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if world.is_walkable(c + dir):
				exits += 1
		if exits > 1 and _rng.randf() < 0.6:
			continue   # prefer dead ends
		floor_spots.erase(c)
		pickups.drop(c, {"id": "healing_tonic", "qty": 1})
		placed += 1
	return placed


## Walk into a bush to pick it. Berries go in your bag; if there's no room
## and you're hurt, you eat the red ones on the spot.
func pick(c: Vector2i) -> void:
	var bush: Dictionary = bushes[c]
	_shake[c] = 0.5
	Sfx.play("rustle")
	if bush.berries <= 0:
		picked.emit("NO BERRIES LEFT. THEY'LL GROW BACK AT DAWN.")
		return
	var id := "blue_berry" if bush.blue else "red_berry"
	var got := 0
	var ate := 0
	while bush.berries > 0:
		if inventory.slot_for(id) != -1:
			inventory.add_stack({"id": id, "qty": 1})
			got += 1
		elif not bush.blue and inventory.health < inventory.max_health:
			inventory.heal(RED_HEAL)
			ate += 1
		else:
			break
		bush.berries -= 1
	queue_redraw()
	if got > 0 or ate > 0:
		Sfx.play("berry_pick")
	if ate > 0:
		Sfx.play("eat")
	if got == 0 and ate == 0:
		picked.emit("YOUR BAG IS FULL.")
	elif ate > 0:
		picked.emit("YOU EAT THEM RIGHT OFF THE BUSH. +" + str(ate * RED_HEAL) + " HEALTH")
	else:
		picked.emit("+" + str(got) + " " + Items.display_name(id) + " (" + str(inventory.count_of(id)) + " IN YOUR BAG)")


func _draw() -> void:
	var view := world._visible_cells()
	for c in bushes:
		if not view.has_point(c):
			continue
		var b: Dictionary = bushes[c]
		var col := (2 if b.blue else 0) + (1 if b.berries > 0 else 0)
		var jig := Vector2.ZERO
		if _shake.has(c):
			var t: float = _shake[c]
			jig.x = roundf(sin(t * 48.0) * 1.6 * clampf(t / 0.5, 0.0, 1.0))
		draw_texture_rect_region(TEX, Rect2(world.cell_to_position(c) + Vector2(-8, -12) + jig, Vector2(32, 32)),
			Rect2(col * 32, 0, 32, 32))


func _process(delta: float) -> void:
	for c in _shake.keys():
		_shake[c] -= delta
		if _shake[c] <= 0.0:
			_shake.erase(c)
	queue_redraw()
