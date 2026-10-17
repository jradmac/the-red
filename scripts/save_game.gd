class_name SaveGame
## Saving and loading a run. The labyrinth itself is never stored: it's
## rebuilt from its seed (every part of it is generated from that one
## number), then everything that has changed since is put back -- where you
## stand, your bag, your light, which doors are open, what's left in each
## chest and on the floor, which creatures are dead and where the living
## ones are, the berries, the sprites, the map you've uncovered, the clock.
##
## One save slot (user://scythe_save.dat). Dying deletes it: death is final.

const PATH := "user://scythe_save.dat"
const VERSION := 4   # 2: villages and rubies; 3: wide crypt corridors, bigger map; 4: no ghosts (the creatures moved) -- older saves don't fit


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func delete() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


static func load_data() -> Dictionary:
	if not exists():
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = f.get_var()
	if not (d is Dictionary) or int(d.get("version", 0)) != VERSION:
		return {}
	return d


## A one-line description for the title screen.
static func summary(d: Dictionary) -> String:
	var secs := int(d.get("time", 0.0))
	return "DEPTH %d   %d:%02d:%02d" % [int(d.get("depth", 0)), secs / 3600, (secs / 60) % 60, secs % 60]


static func save(main: Node) -> bool:
	var world: World = main.world
	var player: Player = main.player
	var inv: Inventory = main.inventory
	var lantern: Lantern = main.lantern
	var d := {"version": VERSION, "seed": world.seed_value}
	var doors: Doors = _child(main, Doors)
	var chests: Chests = _child(main, Chests)
	var flares: Flares = _child(main, Flares)
	d["depth"] = doors.depth_at(player.cell)
	d["time"] = main.stats.time
	d["player"] = {"cell": player.cell, "facing": int(player.facing), "energy": player.energy}
	d["inventory"] = {"slots": inv.slots.duplicate(true), "health": inv.health, "windbreak": inv.windbreak_left,
		"rubies": inv.rubies}
	var seen: Array = []
	for i in world.villages.size():
		if world.villages[i].get("seen", false):
			seen.append(i)
	d["villages"] = {"sold": main.villages.sold.duplicate(), "gifts": main.villages.gifts_given.duplicate(), "seen": seen}
	d["lantern"] = {"fuel": lantern.fuel, "matches": lantern.matches, "max_fuel": lantern.max_fuel,
		"max_radius": lantern.max_radius, "id": lantern.lantern_id, "lit": lantern.state == Lantern.State.LIT,
		"blue": lantern.blue_left, "sun": lantern.sun_left}
	d["flares"] = {"count": flares.count, "planted": flares.planted.duplicate()}
	var open_doors: Array = []
	for c in doors.doors:
		if doors.doors[c].open:
			open_doors.append(c)
	d["doors"] = open_doors
	d["chests"] = chests.chests.duplicate(true)
	d["revealed"] = chests.revealed.duplicate()
	d["ground"] = main.pickups.ground.duplicate(true)
	var berries := {}
	for c in main.forage.bushes:
		berries[c] = main.forage.bushes[c].berries
	d["berries"] = berries
	var creatures := {}
	for e in main.enemies.list:
		if e.has_meta("uid"):
			creatures[int(e.get_meta("uid"))] = {"cell": e.cell, "hp": e.hp}
	d["creatures"] = creatures
	var sprites: Array = []
	for w in main.wisps.list:
		sprites.append({"cell": w.cell, "home": w.get("home", w.cell), "kind": w.kind})
	d["sprites"] = sprites
	d["sprite_respawns"] = main.wisps._respawns.duplicate()
	d["day"] = {"t": main.day.t, "forever": main.day.forever_night}
	d["mapped"] = world.mapped
	d["hints"] = main.automap.hints.duplicate()
	d["master_open"] = main.master.opened
	d["riddles_used"] = main.riddle._used.duplicate()
	var st: RunStats = main.stats
	d["stats"] = {"chests": st.chests_opened, "doors": st.doors_opened, "slain": st.enemies_slain,
		"matches": st.matches_struck, "flares": st.flares_planted, "damage": st.damage_taken}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(d)
	f.close()
	return true


## Puts a saved run back on top of a freshly rebuilt labyrinth (same seed).
static func apply(main: Node, d: Dictionary) -> void:
	var world: World = main.world
	var player: Player = main.player
	var inv: Inventory = main.inventory
	var lantern: Lantern = main.lantern
	var doors: Doors = _child(main, Doors)
	var chests: Chests = _child(main, Chests)
	var flares: Flares = _child(main, Flares)
	# you
	var p: Dictionary = d.player
	player.cell = p.cell
	player.position = world.cell_to_position(p.cell)
	player.facing = p.facing
	player.energy = p.energy
	# your bag
	var iv: Dictionary = d.inventory
	for i in Inventory.SLOTS:
		inv.slots[i] = iv.slots[i] if i < iv.slots.size() else {}
	inv.health = iv.health
	inv.windbreak_left = iv.windbreak
	inv.rubies = int(iv.get("rubies", 0))
	if d.has("villages"):
		main.villages.sold = d.villages.sold
		main.villages.gifts_given = d.villages.gifts
		for i in d.villages.seen:
			if i < world.villages.size():
				world.villages[i]["seen"] = true
	inv.changed.emit()
	# your light
	var l: Dictionary = d.lantern
	lantern.max_fuel = l.max_fuel
	lantern.max_radius = l.max_radius
	lantern.lantern_id = l.id
	lantern.fuel = l.fuel
	lantern.matches = l.matches
	lantern.state = Lantern.State.LIT if l.lit else Lantern.State.OUT
	lantern.blue_left = l.blue
	lantern.sun_left = l.sun
	# flares
	flares.restore(d.flares.planted, d.flares.count)
	# doors
	for c in d.doors:
		if doors.doors.has(c):
			doors.doors[c].open = true
			world.blockers.erase(c)
	doors.queue_redraw()
	main.lighting.refresh_mask()
	# chests and the floor
	chests.chests = d.chests
	chests.revealed = d.revealed
	chests.queue_redraw()
	main.pickups.ground = d.ground
	for c in d.berries:
		if main.forage.bushes.has(c):
			main.forage.bushes[c].berries = d.berries[c]
	# creatures: the dead stay dead, the living are where you left them
	var creatures: Dictionary = d.creatures
	for e in main.enemies.list.duplicate():
		var uid := int(e.get_meta("uid", -1))
		if not creatures.has(uid):
			main.enemies.remove(e)
			continue
		e.cell = creatures[uid].cell
		e.position = world.cell_to_position(e.cell)
		e.hp = creatures[uid].hp
	# the wandering flames
	main.wisps.restore(d.sprites, d.sprite_respawns)
	# the clock, the map, the rest
	main.day.t = d.day.t
	main.day.forever_night = d.day.forever
	world.mapped = d.mapped
	world.mapped_changed.emit()
	main.automap.hints.assign(d.hints)
	main.master.opened = d.master_open
	main.riddle._used = d.riddles_used
	var st: RunStats = main.stats
	st.time = d.time
	st.chests_opened = d.stats.chests
	st.doors_opened = d.stats.doors
	st.enemies_slain = d.stats.slain
	st.matches_struck = d.stats.matches
	st.flares_planted = d.stats.flares
	st.damage_taken = d.stats.damage
	st._last_health = inv.health


static func _child(main: Node, cls: Variant) -> Node:
	for n in main.get_children():
		if is_instance_of(n, cls):
			return n
	return null
