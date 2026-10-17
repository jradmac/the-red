extends Node2D
## Wires the world, the players, the camera, light and atmosphere together.
##
## Everything that belongs to one player lives in a Hero (hero.gd). Alone,
## there's one; a second player can join at any time (Start on another
## controller, or J on the keyboard) and leave again from their bag. The
## shared world systems are pointed at whichever hero is acting.

const LANTERN_COLOR := Color(1.0, 0.72, 0.42)
const BLUE_FLAME := Color(0.45, 0.62, 1.0)
const SUN_COLOR := Color(1.0, 0.93, 0.78)
const CANDLE_COLOR := Color(1.0, 0.55, 0.25)
const MUSHROOM_COLOR := Color(0.25, 0.75, 0.85)
const COOP_HEALTH := 8          ## each player's hearts with two players
const KNOCKOUT_TIME := 12.0     ## co-op: seconds a fallen player is out before getting up beside their partner
const KNOCKOUT_HEARTS := 3      ## ... with this many hearts
const TRADE_REACH := 2          ## tiles: close enough to swap items

@onready var world: World = $World
@onready var camera: Camera2D = $Player/Camera2D

# Player 1 (or whoever is playing alone). Kept pointing at heroes[0].
var player: Player
var lantern: Lantern
var inventory: Inventory
var hud: Hud
var battle: Battle
var transition: Transition
var automap: Automap
var riddle: RiddleScreen
var companion: Companion
var eyes: WatchingEyes
# Shared by everyone.
var lighting: Lighting
var wind: Wind
var enemies: Enemies
var day: DayCycle
var wisps: Wisps
var pickups: Pickups
var forage: Forage
var bombs: Bombs
var chests: Chests
var doors: Doors
var flares: Flares
var traps: Traps
var _fx: Fx
var stats: RunStats
var ending: Ending
var master: MasterChamber
var villages: Villages
var coop: CoopView
var longmen := {}   ## Hero -> their Longman (longman.gd): what comes for them in the dark
var view3d: View3D
var _eyes_layer: CanvasLayer


func _ready() -> void:
	y_sort_enabled = true   # hero and enemies overlap correctly by height
	Hero.all.clear()
	Hero.systems.clear()
	Hero.bound = null
	Controls.setup_solo()
	# Building a big labyrinth takes a few seconds: show a loading screen first.
	var loading := _loading_screen()
	await get_tree().process_frame
	await get_tree().process_frame
	# A saved run? Offer to pick it back up.
	var save := SaveGame.load_data()
	var autoload := OS.has_environment("SCYTHE_AUTOLOAD")   # tests: load without asking
	if OS.has_environment("SCYTHE_NO_INTRO") and not autoload:
		save = {}
	if not save.is_empty() and not autoload:
		var title := TitleScreen.new()
		add_child(title)
		title.setup(SaveGame.summary(save))
		var choice: String = await title.chosen
		title.queue_free()
		if choice == "new":
			SaveGame.delete()
			save = {}
		await get_tree().process_frame
	var fixed_seed := OS.get_environment("SCYTHE_SEED")   # (for tests)
	world.generate(int(save.seed) if not save.is_empty() else (int(fixed_seed) if fixed_seed != "" else randi()))
	_build(save)
	loading.queue_free()


func _loading_screen() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 20
	var canvas := Node2D.new()
	canvas.draw.connect(func():
		var size := canvas.get_viewport_rect().size
		canvas.draw_rect(Rect2(Vector2.ZERO, size), Color("040208"))
		var text := "DESCENDING INTO THE LABYRINTH..."
		PixelFont.draw(canvas, Vector2(floorf((size.x - PixelFont.width_of(text)) / 2), floorf(size.y / 2)), text, Color("8a8299")))
	layer.add_child(canvas)
	add_child(layer)
	return layer


func _build(save: Dictionary = {}) -> void:
	var h := Hero.new()
	h.player = $Player
	h.player.setup(world, world.start_cell)

	# No limits: the camera stays on you everywhere, even at the map's edge
	# (World draws more wall out past it).
	camera.offset = Vector2(8, 8)  # center on the player's tile, not its corner
	camera.make_current()

	day = DayCycle.new()
	add_child(day)
	lighting = Lighting.new()
	lighting.world = world
	lighting.day = day
	add_child(lighting)
	for c in world.cells_with("c"):
		lighting.add_light(world, world.cell_to_position(c) + Vector2(8, 5), 30.0, CANDLE_COLOR, 0.9, 0.12)
	for c in world.cells_with("m"):
		lighting.add_light(world, world.cell_to_position(c) + Vector2(8, 9), 22.0, MUSHROOM_COLOR, 0.8, 0.03)
	# Eyes (and the Longman) live above the darkness layer so they glow in the black.
	_eyes_layer = CanvasLayer.new()
	_eyes_layer.layer = 2
	_eyes_layer.follow_viewport_enabled = true
	add_child(_eyes_layer)

	_make_hero_core(h)

	# Ground layers, drawn above the world but below the hero (in this order).
	flares = Flares.new()
	doors = Doors.new()
	chests = Chests.new()
	pickups = Pickups.new()
	wind = Wind.new()
	master = MasterChamber.new()
	forage = Forage.new()
	for node in [wind, pickups, forage, chests, doors, master, flares]:
		add_child(node)
		move_child(node, world.get_index() + 1)
	# Order matters: doors split the map first, the master gate goes in the
	# far room, chests avoid doorways, loose items avoid chests, each door's
	# key goes on its near side, and finally the purple chest is hidden.
	doors.generate(world)
	world.progress = doors.progress
	world.find_arches()
	for d in doors.doors:
		world.arches.erase(d)   # a door has its own frame
	master.place_gate(world, doors)
	flares.setup(world, h.player, lighting)
	chests.setup(world, h.player, h.inventory, h.lantern, flares, h.dialog)
	pickups.setup(world, h.player, h.lantern, flares, h.inventory, chests, h.dialog)
	chests.pickups = pickups
	doors.place_keys(chests, pickups)
	master.pickups = pickups
	master.place_purple_chest(chests, doors)
	forage.setup(world, h.player, h.inventory, chests, pickups, doors)
	# The villages: walls, lamps, people. Ground and buildings sit below the
	# heroes; people in front of a hero are drawn over them.
	villages = Villages.new()
	add_child(villages)
	move_child(villages, world.get_index() + 1)
	villages.setup(world, lighting, day, forage, self)
	villages.entered.connect(_on_village_entered)
	wind.setup(world)
	wind.enabled = func() -> bool: return not day.is_day()
	wind.gust_hit.connect(_on_gust)
	traps = Traps.new()
	add_child(traps)
	move_child(traps, world.get_index() + 1)
	traps.setup(world, h.player, doors, pickups, chests)
	traps.hurt.connect(func(text: String, dmg: int) -> void: _on_trap(Hero.bound, text, dmg))
	var arches := Arches.new()
	arches.world = world
	add_child(arches)
	var mist := Mist.new()
	mist.world = world
	add_child(mist)
	_fx = Fx.new()
	_fx.lighting = lighting
	add_child(_fx)
	chests.opened_first.connect(func(c: Vector2i) -> void:
		_fx.chest_burst(world.cell_to_position(c) + Vector2(8, 6), chests.chests[c].get("purple", false))
		Sfx.play("chest_open"))
	doors.opened.connect(func(_c): lighting.refresh_mask())
	pickups.picked.connect(func(t: String) -> void:
		if Hero.bound != null and Hero.bound.hud != null:
			Hero.bound.hud._on_picked(t)
		_on_pickup_sound(t))
	forage.picked.connect(func(t: String) -> void:
		if Hero.bound != null and Hero.bound.hud != null:
			Hero.bound.hud._on_picked(t))

	stats = RunStats.new()
	add_child(stats)
	ending = Ending.new()
	add_child(ending)
	ending.setup(stats)

	enemies = Enemies.new()
	add_child(enemies)
	enemies.setup(world, h.player, h.lantern, h.inventory, flares, doors, self, _eyes_layer)
	enemies.day = day
	enemies.hit_player.connect(_on_hit)
	enemies.encounter.connect(_on_encounter)
	var enemy_eyes := EnemyEyes.new()
	enemy_eyes.enemies = enemies
	_eyes_layer.add_child(enemy_eyes)
	wisps = Wisps.new()
	add_child(wisps)
	wisps.setup(world, h.player, lighting, enemies)
	master.setup(h.player, h.inventory, h.dialog, null, pickups, lighting)
	master.won.connect(_on_won)

	# Sound: every effect, and the background of wherever you are.
	var sfx := Sfx.new()
	add_child(sfx)
	sfx.set_listener(h.player)
	wind.gust_hit.connect(func() -> void:
		for hh in Hero.all:
			if hh.alive() and not world.in_village(hh.player.cell):
				Sfx.play("gust")   # (behind the village walls you don't hear it)
				return)
	day.dawn.connect(func() -> void: Sfx.play("dawn"))
	day.dusk.connect(func() -> void: Sfx.play("dusk"))
	day.eternal.connect(func() -> void: Sfx.play("eternal"))
	day.dawn.connect(forage.regrow)
	day.dawn.connect(func(): _announce_all("DAYBREAK", "THE DEMONS FLEE THE SUN, AND THE LONGMAN IS GONE. EXPLORE WHILE YOU CAN!", Color("ffe08a")))
	day.dusk.connect(func(): _announce_all("NIGHTFALL", "LIGHT YOUR LANTERN. THE DARK IS AWAKE.", Color("b8a8ff")))
	day.eternal.connect(func(): _announce_all("ETERNAL NIGHT", "THIS DEEP IN, THE SUN WILL NEVER RISE AGAIN.", Color("ff8a9a")))

	# Bombs: plant with B (or from the bag).
	bombs = Bombs.new()
	add_child(bombs)
	move_child(bombs, world.get_index() + 1)
	bombs.setup(world, h.player, enemies, _fx)
	bombs.slay = _slay
	bombs.hurt_player.connect(func(d: int) -> void: _on_trap(Hero.bound, "THE BLAST CATCHES YOU!", d))
	bombs.exploded.connect(func(at: Vector2) -> void:
		for lm in longmen.values():
			lm.scare(at, Bombs.BLAST_RADIUS))

	Hero.systems = [chests, pickups, doors, master, flares, forage, traps, bombs, wisps, enemies]
	_make_hero_ui(h)
	Hero.all.append(h)
	Hero.bind_all(h)
	stats.watch(h.lantern, flares, chests, doors, h.inventory)
	_refresh_aliases()
	lighting.process_mode = Node.PROCESS_MODE_ALWAYS

	coop = CoopView.new()
	add_child(coop)
	coop.setup(self)

	# The 3D view (view3d.gd): built in the background (the ground is baked a
	# piece per frame), then switched on if the setting says so.
	view3d = View3D.new()
	add_child(view3d)
	view3d.setup(self)
	view3d.build()

	# The opening scene (every new run; ESC skips), or straight back in.
	if OS.has_environment("SCYTHE_NO_INTRO") or not save.is_empty():
		world.blockers[world.start_cell] = true
		player.cell = world.start_cell + Vector2i.DOWN
		player.position = world.cell_to_position(player.cell)
		if not save.is_empty():
			SaveGame.apply(self, save)
			stats._last_flares = flares.count
			companion.pos = player.position + Vector2(10, -16)
			hud.announce("YOU RETURN", "THE LABYRINTH REMEMBERS YOU.", Color("ffe08a"))
	else:
		var intro := Intro.new()
		add_child(intro)
		intro.setup(player, world, companion, hud)
		intro.start()


## A hero's body, light, health and text box (made before the world systems,
## which are first set up pointing at player 1).
func _make_hero_core(h: Hero) -> void:
	h.player.pfx = h.pfx
	h.player.p2 = h.p2
	h.lantern = Lantern.new()
	h.lantern.pfx = h.pfx
	add_child(h.lantern)
	h.lantern.can_act = h.player.can_act
	h.inventory = Inventory.new()
	add_child(h.inventory)
	var pl := h.player
	var inv := h.inventory
	var dress := func() -> void:
		pl.armor_id = inv.best_id("armor", "def")
		pl.weapon_id = inv.best_id("weapon", "atk")
	inv.changed.connect(dress)
	dress.call()
	# The lantern: warm, flickering, the main light in the game.
	h.lantern_light = lighting.add_light(pl, pl.lantern_offset, 84.0, LANTERN_COLOR, 1.15, 0.05)
	# A faint cool halo so the hero is never fully swallowed by the dark.
	h.halo_light = lighting.add_light(pl, Vector2(8, 8), 20.0, Color(0.35, 0.3, 0.5), 0.4, 0.0, false)
	h.halo_light.glow = 0.0
	_add_dust(pl)
	h.eyes = WatchingEyes.new()
	_eyes_layer.add_child(h.eyes)
	h.eyes.setup(world, pl)
	h.dialog = Dialog.new()
	h.dialog.pfx = h.pfx
	add_child(h.dialog)
	h.dialog.setup(pl)


## Everything else a hero has: their screens, their spirit, and the wiring
## from their actions into the shared world.
func _make_hero_ui(h: Hero) -> void:
	var pl := h.player
	var inv := h.inventory
	inv.lantern = h.lantern
	inv.world = world
	inv.player = pl
	inv.chests = chests
	inv.bomb_planter = func() -> String:
		Hero.bind_all(h)
		return bombs.plant()

	h.hud = Hud.new()
	add_child(h.hud)
	h.hud.setup(h.lantern, flares, wind, pl, pickups, inv, chests, doors)
	h.hud.stats = stats
	h.hud.master = master
	h.hud.day = day
	h.hud.enemies = enemies
	h.hud.hero = h
	h.automap = Automap.new()
	h.automap.pfx = h.pfx
	add_child(h.automap)
	h.automap.setup(world, pl, flares, chests, doors)
	h.automap.master_cell = master.gate
	h.bag = Bag.new()
	h.bag.pfx = h.pfx
	add_child(h.bag)
	h.bag.setup(pl, inv, h.lantern, pickups, h.dialog)
	h.bag.flares = flares
	h.bag.save_game = save_game
	h.bag.hero = h
	h.bag.leave_game = func() -> void: drop_out(h, false)
	h.chest_screen = ChestScreen.new()
	h.chest_screen.pfx = h.pfx
	h.chest_screen.hero = h
	add_child(h.chest_screen)
	h.chest_screen.setup(pl, inv, chests, h.dialog)
	h.lock_puzzle = LockPuzzle.new()
	h.lock_puzzle.pfx = h.pfx
	add_child(h.lock_puzzle)
	h.lock_puzzle.setup(pl, h.lantern)
	h.riddle = RiddleScreen.new()
	h.riddle.pfx = h.pfx
	add_child(h.riddle)
	h.riddle.setup(pl, inv, doors, world, h.automap, wisps)
	h.battle = Battle.new()
	h.battle.pfx = h.pfx
	add_child(h.battle)
	h.battle.setup(pl, inv, h.lantern)
	h.battle.ended.connect(func(result: String, e: Enemy) -> void: _on_battle_ended(h, result, e))
	h.transition = Transition.new()
	add_child(h.transition)
	h.trade = TradeScreen.new()
	h.trade.pfx = h.pfx
	add_child(h.trade)
	h.trade.setup(h)
	h.village_screen = VillageScreen.new()
	h.village_screen.pfx = h.pfx
	add_child(h.village_screen)
	h.village_screen.setup(h, villages, flares, day, world)
	h.village_screen.sleep = _sleep_until_morning
	h.interior = Interior.new()
	h.interior.pfx = h.pfx
	add_child(h.interior)
	h.interior.setup(h, villages, h.village_screen)
	h.ui_layers = [h.hud, h.automap, h.bag, h.chest_screen, h.lock_puzzle, h.riddle, h.battle,
		h.transition, h.dialog, h.trade, h.interior, h.village_screen]
	# The shared systems that the doors/chests/master use for this hero's lock puzzles.
	if master.puzzle == null:
		master.puzzle = h.lock_puzzle
	if doors.puzzle == null:
		doors.setup(pl, inv, h.dialog, h.lock_puzzle)

	h.companion = Companion.new()
	h.companion.teal = h.p2
	add_child(h.companion)
	h.companion.setup(pl, lighting)

	# Walking about.
	pl.blocked = func(c: Vector2i) -> bool:
		if enemies.enemy_at(c) != null or not wisps.wisp_at(c).is_empty() or forage.bush_at(c) or villages.blocks(c):
			return true
		var other := h.partner()
		return other != null and other.alive() and other.player.cell == c
	pl.bumped = func(c: Vector2i, fresh: bool) -> void: _on_bump(h, c, fresh)
	pl.bumped_wall = func(c: Vector2i, fresh: bool) -> void: _on_bump_wall(h, c, fresh)
	pl.stepped.connect(func(c: Vector2i) -> void:
		Hero.bind_all(h)
		pickups._on_stepped(c)
		traps._on_stepped(c)
		if world.tile_at(c) == "w":   # wading through tall grass
			world.shake(c, 0.4)
			Sfx.play("rustle", -6.0, 0.1)
		_on_step_sound(h, c))
	h.lantern.struck.connect(func() -> void:
		_fx.match_strike(pl, h.lantern_light.offset)
		Sfx.play("match_strike"))
	h.lantern.went_out.connect(func() -> void: Sfx.play("lantern_out"))
	h.lantern.denied.connect(func(_r: String) -> void: Sfx.play("ui_deny"))


func _add_dust(pl: Node2D) -> void:
	# Drifting dust motes; they only show up inside the lantern light.
	var dust := CPUParticles2D.new()
	dust.amount = 18
	dust.lifetime = 5.0
	dust.preprocess = 5.0
	dust.position = Vector2(8, 4)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(70, 50)
	dust.direction = Vector2(0.3, -1)
	dust.spread = 60.0
	dust.gravity = Vector2(0, -1.5)
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 4.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 1.0
	dust.local_coords = false
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.9, 0.7, 0.0))
	ramp.set_color(1, Color(1, 0.9, 0.7, 0.0))
	ramp.add_point(0.3, Color(1, 0.9, 0.7, 0.55))
	ramp.add_point(0.7, Color(1, 0.9, 0.7, 0.55))
	dust.color_ramp = ramp
	pl.add_child(dust)


## Player 1's things, for everything that only cares about "the" player.
func _refresh_aliases() -> void:
	var h: Hero = Hero.all[0]
	player = h.player
	lantern = h.lantern
	inventory = h.inventory
	hud = h.hud
	battle = h.battle
	transition = h.transition
	automap = h.automap
	riddle = h.riddle
	companion = h.companion
	eyes = h.eyes


func _announce_all(title: String, sub_text: String, col: Color) -> void:
	for h in Hero.all:
		h.hud.announce(title, sub_text, col)


# --- Two players ----------------------------------------------------------------------

## Player 2 joins, right beside player 1. `pad` is their controller (-1 = keyboard).
func join(pad: int) -> void:
	if Hero.all.size() >= 2 or player.dead or player.ui_lock == "intro":
		return
	var h1: Hero = Hero.all[0]
	# Player 1 keeps the controller they've been playing with (not a guess).
	if h1.pad < 0 and _p1_pad_used >= 0 and _p1_pad_used != pad:
		h1.pad = _p1_pad_used
	# The Start press that joined player 2 must not open player 1's bag too
	# (in a solo game, Start on any controller is player 1's bag).
	h1.bag.block_until = Engine.get_process_frames() + 2
	if h1.bag.visible:
		h1.bag._close()
	var h := Hero.new()
	h.p2 = not h1.p2
	h.pfx = "p2_" if h1.pfx == "" else ""
	h.pad = pad
	var pl := Player.new()
	pl.name = "Player2"
	add_child(pl)
	move_child(pl, h1.player.get_index() + 1)
	h.player = pl
	pl.setup(world, _free_beside(h1.player.cell))
	_make_hero_core(h)
	_make_hero_ui(h)
	Hero.all.append(h)
	h.companion.pos = pl.position + Vector2(10, -16)
	# Two players share the hearts: 5 each.
	for x in Hero.all:
		x.inventory.max_health = COOP_HEALTH
	h1.inventory.health = clampi(int(ceil(h1.inventory.health / 2.0)), 1, COOP_HEALTH)
	h.inventory.health = COOP_HEALTH
	h1.inventory.changed.emit()
	h.inventory.changed.emit()
	h.lantern.fuel = h.lantern.max_fuel
	_set_controls()
	coop.start()
	Sfx.play("correct")
	for x in Hero.all:
		x.hud.announce("PLAYER 2 JOINS", "A SECOND LANTERN IN THE DARK.", Color("8ab8ff"))


## A player leaves (from their bag), or falls. The other carries on alone:
## their hearts go back up to 10, and they get the leaver's hearts added on.
## A player who falls drops everything they carried where they fell.
func drop_out(h: Hero, died: bool) -> void:
	var other := h.partner()
	if other == null:
		return
	Hero.bind_all(h)
	# Their things stay in the labyrinth.
	var spill: Array = []
	for i in Inventory.SLOTS:
		if not h.inventory.slots[i].is_empty():
			spill.append(h.inventory.slots[i])
	for i in h.lantern.matches:
		spill.append({"id": "loose_match", "qty": 1})
	if h.inventory.rubies > 0:
		spill.append({"id": "ruby", "qty": h.inventory.rubies})
	for st in spill:
		var c := _free_floor_near(h.player.cell)
		if c.x >= 0:
			pickups.drop(c, st)
	# Hearts: the two are added together, out of 10.
	var give := 0 if died else h.inventory.health
	other.inventory.max_health = Inventory.MAX_HEALTH
	other.inventory.health = clampi(other.inventory.health + give, 1, Inventory.MAX_HEALTH)
	other.inventory.changed.emit()
	coop.stop()
	# Take them out of the game.
	for layer in h.ui_layers:
		layer.queue_free()
	h.companion.dismiss()
	h.eyes.queue_free()
	lighting.remove_light(h.lantern_light)
	lighting.remove_light(h.halo_light)
	h.lantern.queue_free()
	h.inventory.queue_free()
	for e in enemies.list:
		if e.has_meta("hero") and e.get_meta("hero") == h:
			e.remove_meta("hero")
	enemies._hunters.erase(h)
	if enemies.cur == h:
		enemies.cur = null
	Hero.all.erase(h)
	var was_main: bool = h.player == $Player
	if was_main:
		# player 1 fell: player 2 carries on as the main player; the camera follows them
		camera.reparent(other.player, false)
		camera.position = Vector2.ZERO
		$Player.visible = false
		$Player.set_process(false)
		$Player.cell = Vector2i(-99, -99)
	else:
		h.player.queue_free()
	_refresh_aliases()
	Hero.bind_all(other)
	Sfx.set_listener_static(other.player)
	Controls.setup_solo(other.pfx)
	other.hud.announce("YOU ARE ALONE" if died else "PLAYER " + ("2" if h.p2 else "1") + " LEAVES",
		"YOUR PARTNER HAS FALLEN. THEIR THINGS LIE WHERE THEY FELL." if died
		else "THEIR HEARTS ARE YOURS NOW.", Color("ff8a9a") if died else Color("8ab8ff"))


func _set_controls() -> void:
	for x in Hero.all:
		x.bag.on_pad = x.pad >= 0 or (Hero.all.size() == 1 and _p1_pad_used >= 0)
	if Hero.all.size() < 2:
		Controls.setup_solo(Hero.all[0].pfx)
		return
	var a: Hero = Hero.all[0]
	var b: Hero = Hero.all[1]
	var p1 := a if a.pfx == "" else b
	var p2 := b if p1 == a else a
	var p1_pad := -1
	if p2.pad >= 0:
		p1_pad = p1.pad if p1.pad >= 0 else (0 if p2.pad != 0 else 1)
	Controls.setup_coop(p1.pfx, p2.pfx, p1_pad, p2.pad)


func _free_beside(c: Vector2i) -> Vector2i:
	for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP, Vector2i(1, 1), Vector2i(-1, 1)]:
		var n: Vector2i = c + d
		if world.is_walkable(n) and enemies.enemy_at(n) == null and wisps.wisp_at(n).is_empty():
			return n
	return c


func _free_floor_near(c: Vector2i) -> Vector2i:
	for r in range(0, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if world.is_walkable(n) and not pickups.has_item_at(n):
					return n
	return Vector2i(-1, -1)


## Joining: Start on a controller that isn't player 1's, or J on the keyboard.
func _input(event: InputEvent) -> void:
	if Hero.all.size() != 1 or player == null:
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		var d: int = event.device
		if Hero.all[0].pad >= 0 and d == Hero.all[0].pad:
			return
		if _p1_pad_used >= 0 and d == _p1_pad_used:
			return
		join(d)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_J:
		join(-1)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if _p1_pad_used < 0 and (event is InputEventJoypadButton or absf(event.axis_value) > 0.5):
			_p1_pad_used = event.device   # the controller player 1 is holding
			Hero.all[0].bag.on_pad = true


var _p1_pad_used := -1


# --- Every frame -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if lantern == null or wind == null or Hero.all.is_empty():
		return   # still building
	for h in Hero.all:
		if not h.alive():
			if h.knocked_t > 0.0:
				_tick_knocked(h, delta)
			continue
		Hero.bind_all(h)
		chests.hero_tick()
		pickups.hero_tick()
		doors.hero_tick()
		master.hero_tick()
		flares.hero_tick()
		_hero_tick(h, delta)
	_tick_longmen(delta)
	if not Hero.all.is_empty():
		Hero.bind_all(Hero.all[0])
	_update_sound(delta)
	var shake := (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 3.5 * _fx.shake).round()
	camera.offset = Vector2(8, 8) + shake
	coop.shake = shake
	world.focus = player.cell
	var deepest := 0.0
	for h in Hero.all:
		deepest = maxf(deepest, doors_progress(h.player.cell))
	day.note_progress(deepest)
	# Sunstone daylight: player 1's in the main view (each half gets its own in co-op).
	lighting.sun_glow = _sun_of(Hero.all[0])


func _sun_of(h: Hero) -> float:
	return 0.88 * clampf(h.lantern.sun_left / 4.0, 0.0, 1.0) * clampf((Lantern.SUN_TIME - h.lantern.sun_left) / 0.6, 0.0, 1.0)


## One player's frame: their buttons, their light.
func _hero_tick(h: Hero, delta: float) -> void:
	var pl := h.player
	var inv := h.inventory
	var lan := h.lantern
	var p := h.pfx
	# Z while facing a berry bush picks it too; facing a villager, you talk;
	# facing a door in a village, you go in.
	if Input.is_action_just_pressed(p + "confirm") and pl.can_act() and not pl.moving:
		var fc := pl.facing_cell()
		if forage.bush_at(fc):
			Hero.bind_all(h)
			forage.pick(fc)
		elif not villages.person_at(fc).is_empty():
			_talk_to(h, villages.person_at(fc))
		elif not villages.building_at_door(fc).is_empty():
			h.interior.enter(world.village_at(fc), villages.building_at_door(fc))
	# Plant a bomb (B).
	if Input.is_action_just_pressed(p + "bomb") and pl.can_act() and not h.battle.is_active():
		var slot := -1
		for i in Inventory.SLOTS:
			if not inv.slots[i].is_empty() and inv.slots[i].id == "bomb":
				slot = i
		if slot < 0:
			h.hud.say("YOU HAVE NO BOMBS.")
		else:
			h.hud.say(inv.use_slot(slot))
	# Beside your partner: trade.
	if Input.is_action_just_pressed(p + "trade") and pl.can_act() and not pl.moving:
		var other := h.partner()
		if other != null and other.alive() and _near(pl.cell, other.player.cell, TRADE_REACH):
			if other.player.ui_lock == "" and not other.player.moving:
				h.trade.open(other)
			else:
				h.hud.say("YOUR PARTNER IS BUSY.")
		elif other != null:
			h.hud.say("STAND NEXT TO YOUR PARTNER TO TRADE.")
	# Inside a village's walls the lamps are lit: no fuel burns, no wind.
	var sheltered := world.in_village(pl.cell)
	lan.sheltered = sheltered
	# Wind speeds up the burn and pushes the flame (and its light) sideways.
	var calm := inv.windbreak_left > 0.0 or sheltered
	lan.drain_mult = 1.0 if calm else wind.drain_at(pl.cell)
	var push := Vector2.ZERO if calm else wind.wind_at(pl.cell) * 5.0
	h.lean = h.lean.lerp(push, minf(delta * 4.0, 1.0))
	# The clock: daylight puts the lantern away.
	lan.daylight = day.is_day()
	var r := lan.radius()
	var light := h.lantern_light
	light.offset = pl.lantern_offset + h.lean
	light.radius = maxf(r, 1.0)
	light.energy = (0.0 if r <= 0.0 else 1.15 + lan.strike_glow * 0.5) * (1.0 - day.light)
	light.flicker = lan.flicker()
	light.color = BLUE_FLAME if lan.blue_left > 0.0 else LANTERN_COLOR
	var blue := lan.blue_left > 0.0 and lan.state == Lantern.State.LIT
	pl.lantern_blue = blue
	pl.lantern_glow = Color(0.45, 0.65, 1.0, 1.0) if blue else Color(0, 0, 0, 0)
	if lan.sun_left > 0.0:
		light.color = light.color.lerp(SUN_COLOR, clampf(lan.sun_left / 4.0, 0.0, 1.0))
		light.energy = maxf(light.energy, 1.35 * (1.0 - day.light))
		light.flicker = 0.02
	# With the light out you can barely see yourself, and the eyes close in.
	var dark := lan.state != Lantern.State.LIT
	h.halo_light.radius = 24.0 if dark else 20.0
	h.halo_light.energy = 1.1 if dark else 0.4
	h.eyes.dread = move_toward(h.eyes.dread, 1.0 if dark else 0.0, delta * 2.0)
	# The watching eyes belong to the night: they fade out as the sun rises.
	h.eyes.modulate.a = 1.0 - day.light
	h.eyes.visible = day.light < 0.99 and not sheltered
	# A heartbeat when you're nearly dead.
	if inv.health <= 3 and inv.health > 0 and inv.max_health > 3:
		h.beat_t -= delta
		if h.beat_t <= 0.0:
			h.beat_t = 0.75 if inv.health <= 1 else 1.0
			Sfx.play("heartbeat", 0.0, 0.0)


func _near(a: Vector2i, b: Vector2i, reach: int) -> bool:
	return absi(a.x - b.x) <= reach and absi(a.y - b.y) <= reach


# --- Getting hurt -------------------------------------------------------------------------

## A trap (or your own bomb) went off under you. Armor doesn't help.
func _on_trap(h: Hero, text: String, damage: int) -> void:
	if h == null or not h.alive() or h.battle.is_active():
		return
	h.inventory.health = maxi(h.inventory.health - damage, 0)
	h.inventory.changed.emit()
	h.hud.hurt(text)
	if h.inventory.health <= 0:
		_die(h, "YOUR OWN BOMB CLAIMED YOU" if "BLAST" in text else "A TRAP CLAIMED YOU")


## A ghost caught you in the dark.
func _on_hit(e: Enemy, damage: int) -> void:
	var h: Hero = e.get_meta("hero", Hero.all[0])
	if h == null or not Hero.all.has(h) or not h.alive():
		return
	h.inventory.health = maxi(h.inventory.health - damage, 0)
	h.inventory.changed.emit()
	h.hud.hurt(e.display_name() + (" HITS YOU! -" + str(damage) if damage > 0 else " CAN'T GET THROUGH YOUR ARMOR."))
	if h.inventory.health <= 0:
		_die(h, "THE GHOST TOOK YOU" if e.kind == "ghost" else "YOU WERE TORN APART")


## Someone's hearts ran out. Alone, that's the end; with a partner, they
## drop out and the partner carries on.
func _die(h: Hero, why: String) -> void:
	if Hero.all.size() > 1:
		var other := h.partner()
		if other != null and other.alive():
			_knock_out(h, other)
			return
		# both of you down: that's the end of the run
		_death_sound()
		for x in Hero.all:
			x.player.dead = true
			x.player.knocked_out = false
			x.knocked_t = 0.0
			x.hud.show_death(why)
		return
	h.player.dead = true
	_death_sound()
	h.hud.show_death(why)


## Two players: someone who falls is knocked out, not gone. They get back up
## beside their partner after a little while (if the partner's still standing).
func _knock_out(h: Hero, other: Hero) -> void:
	Sfx.play("death", -6.0)
	h.player.dead = true
	h.player.knocked_out = true
	h.player.moving = false
	h.knocked_t = KNOCKOUT_TIME
	h.player.modulate = Color(0.45, 0.45, 0.6, 0.55)
	var who := "PLAYER " + ("2" if h.p2 else "1")
	h.hud.announce("KNOCKED OUT", "YOU'LL BE BACK ON YOUR FEET BESIDE YOUR PARTNER IN A MOMENT.", Color("ff8a9a"))
	other.hud.announce(who + " IS DOWN", "THEY'LL BE BACK AT YOUR SIDE SOON - HOLD ON!", Color("ff8a9a"))


func _tick_knocked(h: Hero, delta: float) -> void:
	h.knocked_t -= delta
	if h.knocked_t > 0.0:
		return
	var other := h.partner()
	if other == null or not other.alive() or other.battle.is_active():
		h.knocked_t = 0.5   # wait for them to be free
		return
	h.knocked_t = 0.0
	var c := _free_beside(other.player.cell)
	h.player.cell = c
	h.player.position = world.cell_to_position(c)
	h.player.dead = false
	h.player.knocked_out = false
	h.player.ui_lock = ""
	h.player.modulate = Color.WHITE
	h.inventory.health = maxi(h.inventory.health, KNOCKOUT_HEARTS)
	h.inventory.changed.emit()
	if h.lantern.state != Lantern.State.LIT or h.lantern.fuel < 20.0:
		h.lantern.refuel(20.0)
	Sfx.play("correct", -6.0)
	h.hud.announce("BACK ON YOUR FEET", "", Color("8ab8ff"))


func doors_progress(c: Vector2i) -> float:
	return world.progress.call(c) if world.progress.is_valid() else 0.0


## A random gust: it beats the lanterns down almost to nothing (a Windbreak protects one).
func _on_gust() -> void:
	if day.is_day():
		return
	for h in Hero.all:
		if not h.alive() or h.lantern.state != Lantern.State.LIT or h.player.ui_lock == "battle":
			continue
		if h.inventory.windbreak_left > 0.0:
			h.hud.say("A GUST HOWLS PAST - YOUR WINDBREAK HOLDS THE FLAME!")
			continue
		if h.lantern.sun_left > 0.0 or h.lantern.sheltered:
			continue
		if h.lantern.lantern_id == "storm_lantern":
			h.hud.say("A GUST HOWLS PAST - THE STORM LANTERN DOESN'T EVEN FLICKER.")
			continue
		if h.lantern.gust():
			h.hud.hurt("A GUST OF WIND BEATS YOUR FLAME DOWN TO A SPUTTER!")


func _on_won() -> void:
	SaveGame.delete()
	Sfx.play("sunstone")
	Sfx.ambient("")
	Sfx.music("")
	if coop.active:
		coop.stop()
	for h in Hero.all:
		h.player.dead = true      # the run is over (no more moving)
		h.lantern.paused = true
	ending.play()


# --- The Longman -------------------------------------------------------------------------

## Each player has their own Longman. It comes while they're in the dark,
## backs off when they have light, and if it reaches them, it eats them.
func _tick_longmen(delta: float) -> void:
	var daytime := day.is_day()
	for h in longmen.keys():
		if not Hero.all.has(h):
			# that player is gone: let their Longman finish (it may be feeding), then remove it
			var old: Longman = longmen[h]
			if old.state == "feeding":
				old.tick(delta, false, false, daytime, false)
			else:
				old.queue_free()
				longmen.erase(h)
	for h in Hero.all:
		if not longmen.has(h):
			var lm := Longman.new()
			_eyes_layer.add_child(lm)   # above the darkness, like the eyes
			lm.setup(self, h)
			lm.ate.connect(_on_eaten)
			longmen[h] = lm
		var lm: Longman = longmen[h]
		if not h.alive():
			lm.tick(delta, false, false, daytime, true)
			continue
		enemies.bind(h)
		var frozen: bool = h.player.ui_lock not in ["", "encounter"] or h.battle.is_active()
		# Light protects whoever stands in it: your lantern, your partner's lantern,
		# anyone's flare, a candle or glowing mushroom.
		var own_dark := enemies.in_the_dark()
		var borrowed := own_dark and _in_partners_light(h)
		var dark := own_dark and not borrowed
		h.hud.shelter = ""
		if h.lantern.state != Lantern.State.LIT:
			h.hud.shelter = "partner" if borrowed else ("" if dark else "light")
		var i := Hero.all.find(h)
		lm.view_center = Vector2(-1, -1)
		if view3d != null and view3d.coop_centers.size() == Hero.all.size() and Hero.all.size() > 1:
			lm.view_center = (view3d.coop_centers[i] as Vector2) / World.TILE
		lm.tick(delta, dark, enemies._gathering(), daytime, frozen)


## Two players: standing in your partner's lantern light keeps you safe too
## (their flares already do: Enemies.in_the_dark counts every planted flare).
func _in_partners_light(h: Hero) -> bool:
	for o in Hero.all:
		if o == h or not o.alive() or o.lantern.state != Lantern.State.LIT:
			continue
		var r: float = o.lantern.radius() / World.TILE - Enemies.LIGHT_EDGE
		if r > 0.0 and (Vector2(h.player.cell) - Vector2(o.player.cell)).length() <= r:
			return true
	return false


## The Longman reached someone in the dark. Alone, the run is over. With a
## partner, that player is gone for good (their things stay where they fell)
## and the other carries on.
func _on_eaten(h: Hero) -> void:
	if not Hero.all.has(h) or not h.alive():
		return
	_fx.shake = maxf(_fx.shake, 1.0)
	h.player.visible = false   # nothing is left of you
	var other := h.partner()
	if other != null and other.alive():
		Sfx.play("death", -4.0)
		other.hud.announce("PLAYER " + ("2" if h.p2 else "1") + " IS GONE", "THE LONGMAN TOOK THEM. KEEP YOUR LIGHT.", Color("ff8a9a"))
		drop_out(h, true)
		return
	for x in Hero.all:
		x.player.dead = true
		x.player.knocked_out = false
		x.knocked_t = 0.0
	_death_sound()
	for x in Hero.all:
		x.hud.show_death("THE LONGMAN TOOK YOU")


# --- Fights ---------------------------------------------------------------------------------

## An insect or demon lunged into someone.
func _on_encounter(e: Enemy) -> void:
	var h: Hero = e.get_meta("hero", Hero.all[0])
	if h == null or not Hero.all.has(h):
		return
	if h.player.ui_lock == "encounter":
		h.player.ui_lock = ""
	if not h.battle.is_active() and h.player.ui_lock == "" and h.alive() and not e.in_battle:
		_start_fight(h, e, false)


## Contact: an insect or demon touched you, or you walked into one. Whoever
## started it, the battle just begins.
func _start_fight(h: Hero, e: Enemy, you_started: bool) -> void:
	if h.transition.is_playing() or e.in_battle or not is_instance_valid(e) or not h.alive():
		return
	e.in_battle = true
	h.player.ui_lock = ""
	Sfx.play("encounter")
	h.battle.start(e, you_started)


## You walked into something: a sprite (riddle), a berry bush, or an enemy (fight).
func _on_bump(h: Hero, c: Vector2i, fresh: bool) -> void:
	if not h.player.can_act() or h.battle.is_active():
		return
	Hero.bind_all(h)
	var w := wisps.wisp_at(c)
	if not w.is_empty():
		h.riddle.open(w)   # a sprite: time for a riddle
		return
	if forage.bush_at(c):
		if fresh:
			forage.pick(c)
		return
	var e := enemies.enemy_at(c)
	if e != null and fresh:
		_start_fight(h, e, true)


func _on_battle_ended(h: Hero, result: String, e: Enemy) -> void:
	if is_instance_valid(e):
		e.in_battle = false
	Hero.bind_all(h)
	match result:
		"won":
			if is_instance_valid(e):
				_reward(h, e)
			_slay(e)
		"fled":
			enemies.shake_off(e)
		"lost":
			if e.hp <= 0:
				enemies.dissolve(e)   # you took it with you
			_die(h, "YOU WERE TORN APART")


## Walking into a leafy bush shakes it; walking into a wall is just a thud.
func _on_bump_wall(h: Hero, c: Vector2i, fresh: bool) -> void:
	if not fresh or not h.player.can_act():
		return
	var b := villages.building_at_door(c)
	if not b.is_empty():
		h.interior.enter(world.village_at(c), b)   # walk in through the door
		return
	if doors.is_locked(c):
		# Walking into a locked door works like pressing A at it.
		var color: String = doors.doors[c].color
		if h.inventory.count_of(color + "_key") > 0:
			Hero.bind_all(h)
			doors.try_open(c)
		else:
			Sfx.play("door_locked")
			h.hud.say("LOCKED - NEEDS " + Items.with_article(color + "_key").to_upper())
		return
	if world.is_bush(c):
		world.shake(c)
		Sfx.play("rustle")
	else:
		Sfx.play("bump")


# --- Sound ------------------------------------------------------------------------------------

var _step_i := 0
var _was_warning := false
var _region_track := ""
var _region_t := 0.0
const REGION_MUSIC := {0: "crypt", 1: "forest", 2: "court", 3: "mountain", 4: "river", 5: "swamp"}


## Footsteps: stone in the crypts and courtyards and on the mountain, soft
## grass in the woods, wet mud in the swamp.
func _on_step_sound(h: Hero, c: Vector2i) -> void:
	_step_i += 1
	var b := world.biome_at(c)
	var snd := "step_stone" + str(_step_i % 3)
	var t := world.tile_at(c)
	if b == World.B_SWAMP and t != ",":
		snd = "step_mud" + str(_step_i % 2)
	elif t == "," or t == "w" or b == World.B_FOREST or b == World.B_RIVER:
		snd = "step_grass" + str(_step_i % 3)
	var running := h.player.energy < Player.MAX_ENERGY and Input.is_action_pressed(h.pfx + "sprint")
	Sfx.play(snd, 2.0 if running else 0.0, 0.08)


func _on_pickup_sound(text: String) -> void:
	if "KEY" in text:
		Sfx.play("key")
	elif "MATCH" in text and not "FULL" in text:
		Sfx.play("pickup_match")
	elif "FULL" in text:
		Sfx.play("ui_deny")
	else:
		Sfx.play("pickup")


## Finds a direct child of a given class.
func _first(cls: Variant) -> Node:
	for n in get_children():
		if is_instance_of(n, cls):
			return n
	return null


## Saves the run (from a bag). Returns true if it worked.
func save_game() -> bool:
	for h in Hero.all:
		if not h.alive() or h.battle.is_active():
			return false
	return SaveGame.save(self)


func _death_sound() -> void:
	SaveGame.delete()   # death is final
	Sfx.play("death")
	Sfx.ambient("")
	Sfx.music("")


## The background: crypt drone and drips, night wind and crickets outdoors,
## birds by day. Music follows player 1 (or whoever's left).
func _update_sound(delta: float) -> void:
	if player.dead:
		return
	var outdoors := world.is_outdoors(player.cell)
	if day.is_day():
		Sfx.ambient("amb_day" if outdoors else "amb_night")
	else:
		Sfx.ambient("amb_outdoor" if outdoors else "amb_night")
	# Music: the landscape you're in, by day or by night (it waits a moment
	# before changing, so walking along a border doesn't flip it back and forth).
	var region: String = "village" if world.in_village(player.cell) else REGION_MUSIC.get(world.biome_at(player.cell), "crypt")
	var want: String = region + ("_day" if day.light > 0.5 else "_night")
	var fighting := false
	for h in Hero.all:
		if h.battle.is_active() or h.transition.is_playing():
			fighting = true
	if fighting:
		Sfx.music("battle")
		_region_t = 99.0
	else:
		if want != _region_track:
			_region_t += delta
			if _region_t > 2.5 or _region_track == "":
				_region_track = want
				_region_t = 0.0
		else:
			_region_t = 0.0
		Sfx.music(_region_track)
	if wind.warning_left > 0.0 and not _was_warning and inventory.windbreak_left <= 0.0 and not world.in_village(player.cell):
		Sfx.play("gust_warn")
	_was_warning = wind.warning_left > 0.0


## A creature is dead (a won fight, or a bomb): it dissolves, maybe drops something.
func _slay(e: Enemy) -> void:
	stats.enemies_slain += 1
	var spot := e.cell
	enemies.dissolve(e)
	var dropped := {}
	if e.kind == "demon":
		dropped = Items.roll_stack(enemies._rng, world.progress.call(spot))
	elif enemies._rng.randf() < 0.35:
		dropped = {"id": "loose_match", "qty": 1}
	if not dropped.is_empty() and not pickups.has_item_at(spot):
		pickups.drop(spot, dropped)
		if Hero.bound != null:
			Hero.bound.hud.say("IT DROPPED SOMETHING.")


## F11 (or Alt+Enter) toggles fullscreen. (Needs the game in its own window,
## not embedded in the editor's Game tab.)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()


# --- Villages ------------------------------------------------------------------------------

## Walking in through a village gate: its name, and it goes on your map.
func _on_village_entered(h: Hero, vi: int) -> void:
	var v: Dictionary = world.villages[vi]
	var first: bool = not v.get("seen", false)
	v["seen"] = true
	if first:
		var r: Rect2i = (v.rect as Rect2i).grow(1)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				world.mapped[y * world.width + x] = 1
		world.mapped_changed.emit()
	h.hud.announce(String(v.name), "A VILLAGE. THE LAMPS KEEP THE DARK AT BAY." if first else "SAFE BEHIND THE WALLS.",
		Color("ffd38a"))
	Sfx.play("dawn", -8.0)


## Someone in a village says something (and turns to face you).
func _talk_to(h: Hero, p: Dictionary) -> void:
	villages.face(p, h.player.cell)
	var lines: Array = VillageTalk.GUARD if p.kind == "guard" else (VillageTalk.CHILD if p.kind == "child" else VillageTalk.VILLAGER)
	p.line = int(p.line) + 1 + randi() % 3
	var who: String = "GUARD" if p.kind == "guard" else String(p.name)
	h.dialog.say(who + ": " + String(lines[int(p.line) % lines.size()]), "npc:" + str(p.look))
	Sfx.play("voice" + str(randi() % 4), -4.0)


## A creature beaten in battle drops a few rubies (more for demons, more deeper in).
func _reward(h: Hero, e: Enemy) -> void:
	var depth := doors_progress(h.player.cell)
	var n := 0
	if e.kind == "demon":
		n = randi_range(2, 4) + int(round(depth * 4.0))
	elif randf() < 0.45 + depth * 0.3:
		n = 1 + (1 if randf() < depth else 0)
	if n <= 0:
		return
	h.inventory.rubies += n
	h.inventory.changed.emit()
	h.hud._on_picked("+" + str(n) + (" RUBIES" if n > 1 else " RUBY"))
	Sfx.play("coin")


## The inn: everyone sleeps until morning. A little scene plays over the
## whole screen (into bed, the candle out, the sun through the window, out of
## bed) while the night passes.
var _sleep_layer: CanvasLayer
func _sleep_until_morning() -> void:
	if _sleep_layer != null:
		return
	_sleep_layer = CanvasLayer.new()
	_sleep_layer.layer = 120
	add_child(_sleep_layer)
	var scene := InnScene.new()
	for h in Hero.all:
		if h.alive() and not h.battle.is_active():
			h.player.ui_lock = "sleep"
			scene.heroes.append(h)
	_sleep_layer.add_child(scene)
	Sfx.play("sleep")
	scene.night.connect(func() -> void:
		# morning: just after sunrise
		var cycle := DayCycle.NIGHT + DayCycle.DAY
		day.t = floorf(day.t / cycle) * cycle + DayCycle.NIGHT + DayCycle.FADE + 1.0
		for h in Hero.all:
			if h.alive():
				h.player.energy = Player.MAX_ENERGY)
	scene.done.connect(func() -> void:
		for h in Hero.all:
			if h.alive() and h.player.ui_lock == "sleep":
				h.player.ui_lock = "interior" if h.interior.active else ""
		_sleep_layer.queue_free()
		_sleep_layer = null
		_announce_all("GOOD MORNING", "YOU WAKE RESTED. THE SUN IS UP - THE DEMONS AND THE LONGMAN ARE GONE.", Color("ffe08a")))
