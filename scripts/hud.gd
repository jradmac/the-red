class_name Hud
extends CanvasLayer
## Everything drawn on top of the game: lantern fuel bar, match and flare
## counts, health hearts, attack/defense, wind warning, pickup messages, the
## light-out warning and the death screen.

const C_TEXT := Color("e8dfc8")
const C_DIM := Color("8a8299")
const C_SHADOW := Color("0d0a12")
const C_FRAME := Color("3a3449")
const C_FUEL_HI := Color("ffd35a")
const C_FUEL_MID := Color("f5a33a")
const C_FUEL_LOW := Color("ff4a5a")
const C_BLUE_FLAME := Color("6f9cff")
const C_FLARE := Color("7dff9a")
const C_FLARE_CORE := Color("e4ffe9")
const C_MATCH_HEAD := Color("e0453f")
const C_MATCH_STICK := Color("d8c39a")
const C_WIND := Color(0.85, 0.85, 1.0)
const C_DREAD := Color(0.35, 0.0, 0.05)
const HINT := "HOLD Z SPRINT  E MATCH  F FLARE  M MAP  I BAG"
const HINT_P2 := "ENTER SPRINT  . MATCH  , FLARE  L MAP  ; BAG  K FIGHT  J TRADE"
const HINT_TIME := 8.0
const BAR_W := 44
const C_ENERGY := Color("7de0ff")

var enemies: Enemies   ## set by main, for the "attack a demon" prompt
var _zone := -1
var _zone_t := -1.0       # banner timer when you enter a new area
var _zone_name := ""
var _zone_sub := ""
var _deepest := 0
var _zone_col := Color("f2e6c8")
var _zone_tier := ""      # the rarity gem beside the banner's title ("" for none: RarityIcon)
var day: DayCycle   ## set by main
var lantern: Lantern
var flares: Flares
var wind: Wind
var player: Player
var hero: Hero   ## whose HUD this is
var shelter := ""   ## set by main while your lantern is out: "partner" (in their lantern light), "light" (a flare or candle), "" (nothing: it's coming)
var inventory: Inventory
var pickups: Pickups
var chests: Chests
var doors: Doors
var stats: RunStats
var master: MasterChamber
var _canvas: Node2D
var _time := 0.0
var _messages: Array[Dictionary] = []   # {text, color, age}
var _flash_flares := 0.0
var _flash_matches := 0.0
var _death_t := -1.0
var _death_title := "THE DARK TOOK YOU"
var _hurt_t := 0.0


func setup(l: Lantern, f: Flares, w: Wind, p: Player, pk: Pickups, inv: Inventory, ch: Chests, dr: Doors) -> void:
	doors = dr
	lantern = l
	flares = f
	wind = w
	player = p
	inventory = inv
	pickups = pk
	chests = ch
	layer = 4
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)
	flares.denied.connect(func(): _flash_flares = 0.6)
	lantern.denied.connect(_on_match_denied)
	lantern.struck.connect(func(): _say("YOU STRIKE A MATCH", C_FUEL_HI))
	lantern.went_out.connect(func(): _say("YOUR LIGHT IS OUT", C_FUEL_LOW))
	lantern.relit.connect(func(): _say("THE FLAME CATCHES AGAIN", C_FUEL_HI))
	# (main routes pickups' messages to whoever picked the item up)


## A big title across the top: DAYBREAK, NIGHTFALL...
func announce(title: String, sub_text: String, col: Color, tier: String = "") -> void:
	if tier == "" and player != null and player.world != null and _zone >= 0 \
			and _zone < player.world.zone_names.size() and title == player.world.zone_names[_zone]:
		tier = RarityIcon.land_tier(player.world, _zone)   # (the land you're in, named again)
	_zone_name = title
	_zone_sub = sub_text
	_zone_col = col
	_zone_tier = tier
	_zone_t = 0.0


func show_death(title: String) -> void:
	if stats != null:
		stats.running = false
	if _death_t < 0.0:
		_death_title = title
		_death_t = 0.0


func say(text: String) -> void:
	_say(text, C_FUEL_HI)


func hurt(text: String) -> void:
	_hurt_t = 0.4
	_say(text, C_FUEL_LOW)


func _on_picked(text: String) -> void:
	var col := C_TEXT
	if "MATCH" in text:
		col = C_FUEL_HI
	elif "FLARE" in text:
		col = C_FLARE
	_say(text, col)


## A small 5x4 pixel heart.
static func draw_heart(canvas: CanvasItem, o: Vector2, col: Color) -> void:
	canvas.draw_rect(Rect2(o + Vector2(0, 0), Vector2(2, 1)), col)
	canvas.draw_rect(Rect2(o + Vector2(3, 0), Vector2(2, 1)), col)
	canvas.draw_rect(Rect2(o + Vector2(0, 1), Vector2(5, 1)), col)
	canvas.draw_rect(Rect2(o + Vector2(1, 2), Vector2(3, 1)), col)
	canvas.draw_rect(Rect2(o + Vector2(2, 3), Vector2(1, 1)), col)


func _on_match_denied(reason: String) -> void:
	_flash_matches = 0.6
	_say(reason, C_FUEL_LOW)


func _say(text: String, color: Color) -> void:
	_messages.append({"text": text, "color": color, "age": 0.0})
	if _messages.size() > 3:
		_messages.pop_front()


func _process(delta: float) -> void:
	if player != null and player.world != null:
		var z := player.world.zone_at(player.cell)
		if z >= 0 and z != _zone:
			var prev := _zone
			_zone = z
			if prev < 0 or player.world.zone_names[z] != player.world.zone_names[prev]:
				_zone_name = player.world.zone_names[z]
				_zone_sub = "DEPTH " + str(doors.depth_at(player.cell))
				_zone_col = Color("f2e6c8")
				_zone_tier = RarityIcon.land_tier(player.world, z)
				_zone_t = 0.0
		# Through a door into deeper ground: the labyrinth gets meaner.
		var d := doors.depth_at(player.cell)
		if d > _deepest:
			_deepest = d
			_zone_name = "DEPTH " + str(d)   # (never how many there are: the dark has no bottom you can see)
			_zone_sub = "THE CREATURES HERE GROW STRONGER - AND SO DOES THE LOOT"
			_zone_col = Color("f2e6c8")
			_zone_tier = ""
			_zone_t = 0.0
	if _zone_t >= 0.0:
		_zone_t += delta
		if _zone_t > 4.0:
			_zone_t = -1.0
	_time += delta
	_flash_flares = maxf(_flash_flares - delta, 0.0)
	_flash_matches = maxf(_flash_matches - delta, 0.0)
	_hurt_t = maxf(_hurt_t - delta, 0.0)
	if _death_t >= 0.0:
		_death_t += delta
	for m in _messages:
		m.age += delta
	_messages = _messages.filter(func(m): return m.age < 2.0)
	_canvas.queue_redraw()


const KEY_COLORS := {"bronze": Color("c07a3a"), "silver": Color("c9cbd8"), "gold": Color("e8b84a"), "purple": Color("a060ff")}


func _text(pos: Vector2, text: String, color: Color) -> void:
	PixelFont.draw(_canvas, pos.floor(), text, color, Color(C_SHADOW, color.a))


func _centered(y: float, text: String, color: Color) -> void:
	var w := _canvas.get_viewport_rect().size.x
	_text(Vector2((w - PixelFont.width_of(text)) / 2, y), text, color)


func _draw_hud() -> void:
	var screen := _canvas.get_viewport_rect().size

	# --- Dread: dark red pulse while the light is out --------------------------
	if lantern.state == Lantern.State.OUT and not (day != null and day.is_day()):
		var pulse := 0.12 + 0.08 * sin(_time * 3.0)
		_canvas.draw_rect(Rect2(Vector2.ZERO, screen), Color(C_DREAD, pulse))

	if _hurt_t > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, screen), Color(0.8, 0.05, 0.1, _hurt_t * 0.6))

	# --- Lantern fuel bar -----------------------------------------------------
	var o := Vector2(5, 5)
	# lantern icon
	_canvas.draw_rect(Rect2(o + Vector2(1, 0), Vector2(3, 1)), C_DIM)
	_canvas.draw_rect(Rect2(o + Vector2(0, 1), Vector2(5, 5)), C_SHADOW)
	var blue := lantern.blue_left > 0.0 and lantern.state == Lantern.State.LIT
	_canvas.draw_rect(Rect2(o + Vector2(1, 2), Vector2(3, 3)),
		(C_BLUE_FLAME if blue else C_FUEL_HI) if lantern.state == Lantern.State.LIT else C_FRAME)
	# bar
	var f := lantern.fraction()
	var col := C_FUEL_HI if f > 0.5 else (C_FUEL_MID if f > 0.2 else C_FUEL_LOW)
	if blue and f > 0.2:
		col = C_BLUE_FLAME
	var bar := Rect2(o + Vector2(8, 1), Vector2(BAR_W + 2, 5))
	_canvas.draw_rect(bar, C_SHADOW)
	_canvas.draw_rect(bar.grow(-1), C_FRAME)
	if not (f < 0.2 and fmod(_time, 0.5) < 0.2):
		_canvas.draw_rect(Rect2(bar.position + Vector2.ONE, Vector2(roundf(BAR_W * f), 3)), col)
	# wind icon: three streaks sliding, when the wind is draining your lantern
	if wind.drain_at(player.cell) > 1.0 and inventory.windbreak_left <= 0.0:
		var wx := bar.end.x + 4
		for i in 3:
			var slide := fmod(_time * 12.0 + i * 3.0, 6.0)
			_canvas.draw_rect(Rect2(wx + slide, o.y + 1 + i * 2, 3, 1), Color(C_WIND, 0.9))

	# --- Sprint energy ---------------------------------------------------------
	var eo := o + Vector2(0, 8)
	_canvas.draw_rect(Rect2(eo + Vector2(2, 0), Vector2(2, 2)), C_ENERGY)   # little bolt
	_canvas.draw_rect(Rect2(eo + Vector2(1, 2), Vector2(2, 1)), C_ENERGY)
	_canvas.draw_rect(Rect2(eo + Vector2(1, 3), Vector2(1, 1)), C_ENERGY)
	var ebar := Rect2(eo + Vector2(8, 0), Vector2(BAR_W + 2, 4))
	_canvas.draw_rect(ebar, C_SHADOW)
	_canvas.draw_rect(ebar.grow(-1), C_FRAME)
	var ef := player.energy / Player.MAX_ENERGY
	var ecol := C_ENERGY
	if player.winded:
		ecol = C_FUEL_LOW if fmod(_time, 0.4) < 0.2 else Color("a04040")
	_canvas.draw_rect(Rect2(ebar.position + Vector2.ONE, Vector2(roundf(BAR_W * ef), 2)), ecol)
	if player.winded:
		_text(ebar.end + Vector2(4, -5), "WINDED", C_FUEL_LOW)

	# --- Matches and flares -----------------------------------------------------
	var r2 := o + Vector2(0, 15)
	_canvas.draw_rect(Rect2(r2 + Vector2(1, 0), Vector2(2, 2)), C_MATCH_HEAD)
	_canvas.draw_rect(Rect2(r2 + Vector2(1, 2), Vector2(1, 4)), C_MATCH_STICK)
	var mcol := C_FUEL_LOW if fmod(_flash_matches, 0.2) > 0.1 else C_TEXT
	_text(r2 + Vector2(5, 1), "*" + str(lantern.matches), mcol)

	var r3 := r2 + Vector2(22, 0)
	_canvas.draw_rect(Rect2(r3 + Vector2(1, 0), Vector2(1, 1)), C_FLARE_CORE)
	_canvas.draw_rect(Rect2(r3 + Vector2(0, 1), Vector2(3, 2)), C_FLARE)
	_canvas.draw_rect(Rect2(r3 + Vector2(1, 3), Vector2(1, 3)), Color("c0393f"))
	var fcol := C_FUEL_LOW if fmod(_flash_flares, 0.2) > 0.1 else C_TEXT
	_text(r3 + Vector2(5, 1), "*" + str(flares.count), fcol)
	# rubies: a little red gem
	var r4 := r3 + Vector2(22, 0)
	_canvas.draw_rect(Rect2(r4 + Vector2(1, 0), Vector2(3, 1)), Color("ff8a94"))
	_canvas.draw_rect(Rect2(r4 + Vector2(0, 1), Vector2(5, 2)), Color("e0283c"))
	_canvas.draw_rect(Rect2(r4 + Vector2(1, 3), Vector2(3, 1)), Color("9a1424"))
	_canvas.draw_rect(Rect2(r4 + Vector2(2, 4), Vector2(1, 1)), Color("9a1424"))
	_text(r4 + Vector2(7, 1), "*" + str(inventory.rubies), C_TEXT)
	# keys: one little key per colour you carry, with how many
	var kx := r4.x + 9 + PixelFont.width_of("*" + str(inventory.rubies)) + 5
	for kc in KEY_COLORS:
		var n := inventory.count_of(kc + "_key")
		if n <= 0:
			continue
		var kcol: Color = KEY_COLORS[kc]
		var kp := Vector2(kx, r4.y)
		_canvas.draw_rect(Rect2(kp + Vector2(0, 0), Vector2(3, 3)), kcol)
		_canvas.draw_rect(Rect2(kp + Vector2(1, 1), Vector2(1, 1)), C_SHADOW)
		_canvas.draw_rect(Rect2(kp + Vector2(3, 1), Vector2(3, 1)), kcol)
		_canvas.draw_rect(Rect2(kp + Vector2(5, 2), Vector2(1, 2)), kcol)
		_text(kp + Vector2(8, 1), "*" + str(n), C_TEXT)
		kx += 8 + PixelFont.width_of("*" + str(n)) + 5
	if lantern.sun_left > 0.0:
		var sc := Color("ffe08a") if lantern.sun_left > 10.0 or fmod(_time, 0.4) < 0.25 else Color("8a6a2a")
		var ss := int(ceil(lantern.sun_left))
		_text(r2 + Vector2(0, 17), "SUNSTONE %d:%02d" % [ss / 60, ss % 60], sc)
	if lantern.blue_left > 0.0:
		var bc := Color("8fb4ff") if lantern.blue_left > 10.0 or fmod(_time, 0.4) < 0.25 else Color("3a4a8a")
		_text(r2 + Vector2(0, 9), "BLUE FLAME " + str(int(ceil(lantern.blue_left))), bc)

	# --- Health and stats, top-right ----------------------------------------------
	for i in inventory.max_health:
		draw_heart(_canvas, Vector2(screen.x - 5 - (inventory.max_health - i) * 6, 6),
			Color("e0453f") if i < inventory.health else Color("3a2433"))
	var stat_text := "ATK " + str(inventory.attack()) + " DEF " + str(inventory.defense())
	_text(Vector2(screen.x - 6 - PixelFont.width_of(stat_text), 14), stat_text, C_TEXT)
	if inventory.windbreak_left > 0.0:
		var wb := "STILL AIR " + str(ceili(inventory.windbreak_left))
		_text(Vector2(screen.x - 6 - PixelFont.width_of(wb), 22), wb, Color("9fe3ff"))

	# --- Messages (pickups, warnings) ---------------------------------------------
	var my := 30.0
	for m in _messages:
		var a := clampf((2.0 - m.age) / 0.5, 0.0, 1.0)
		_centered(my - m.age * 4.0, m.text, Color(m.color, a))
		my += 8.0

	# --- Light out: strike a match! -------------------------------------------------
	if lantern.state == Lantern.State.OUT and not (day != null and day.is_day()):
		var msg := "PRESS E TO STRIKE A MATCH" if lantern.matches > 0 \
			else ("NO MATCHES - DRINK LAMP OIL" if inventory.count_of("lamp_oil") > 0 else "NO MATCHES - FIND LIGHT")
		if fmod(_time, 1.0) < 0.7:
			_centered(screen.y / 2 + 24, msg, C_TEXT)
		if shelter == "partner":
			_centered(screen.y / 2 + 34, "SAFE IN YOUR PARTNER'S LIGHT. STAY CLOSE.", Color(C_FUEL_HI, 0.8))
		elif shelter == "light":
			_centered(screen.y / 2 + 34, "SAFE IN THE LIGHT. FOR NOW.", Color(C_FUEL_HI, 0.8))
		else:
			_centered(screen.y / 2 + 34, "IT'S COMING", Color(C_FUEL_LOW, 0.8))
	elif lantern.ghosts_gather() and not (day != null and day.is_day()) and fmod(_time, 1.6) < 1.1:
		_centered(screen.y / 2 + 34, "SOMETHING IS WATCHING YOU...", Color(C_FUEL_LOW, 0.65))

	# --- What A does right here ----------------------------------------------------------
	if player.can_act() and not player.moving:
		var prompt := ""
		if pickups.needs_button(player.cell):
			prompt = "Z  PICK UP " + Items.display_name(pickups.item_at(player.cell).id)
		elif chests.chests.has(player.facing_cell()):
			prompt = "Z  OPEN CHEST"
		elif master != null and player.facing_cell() == master.gate and not master.opened:
			if inventory.count_of("purple_key") > 0:
				prompt = "Z  OPEN THE MASTER SEAL"
			else:
				prompt = "SEALED - FIND THE MASTER KEY"
		elif doors.is_locked(player.facing_cell()):
			var color: String = doors.doors[player.facing_cell()].color
			if inventory.count_of(color + "_key") > 0:
				prompt = "Z  PICK THE " + color.to_upper() + " LOCK"
			else:
				prompt = "LOCKED - NEEDS A " + color.to_upper() + " KEY"
		if prompt != "":
			var w := PixelFont.width_of(prompt) + 8
			var r := Rect2(floorf((screen.x - w) / 2), screen.y - 34, w, 11)
			_canvas.draw_rect(r, Color(0.05, 0.03, 0.08, 0.85))
			_text(r.position + Vector2(4, 3), prompt, C_TEXT)

	# --- The clock: sun or moon, and time until it changes ----------------------
	if day != null:
		var cx := floorf(screen.x / 2)
		var icon_c := Vector2(cx - 30, 9)
		if day.is_day():
			_canvas.draw_circle(icon_c, 3.0, Color("ffd35a"))
			for i in 8:
				var a := i * TAU / 8.0 + _time * 0.5
				_canvas.draw_rect(Rect2(icon_c + Vector2.from_angle(a) * 5.0, Vector2.ONE), Color("ffd35a"))
		else:
			_canvas.draw_circle(icon_c, 3.0, Color("d8d4f0"))
			_canvas.draw_circle(icon_c + Vector2(1.5, -1), 2.6, Color(0.05, 0.04, 0.08))
		# Only the last minute before dawn or dusk is counted down.
		var left := day.time_left()
		var label := "ETERNAL NIGHT" if left < 0.0 else ("DAY" if day.is_day() else "NIGHT")
		var clock_col := Color("ffe08a") if day.is_day() else C_DIM
		if left >= 0.0 and left <= 60.0:
			var secs := int(ceil(left))
			label = ("DUSK IN " if day.cycle_pos() >= DayCycle.NIGHT else "DAWN IN ") + "0:%02d" % secs
			if secs <= 10 and fmod(_time, 0.5) < 0.25:
				clock_col = Color("ffffff")
		_text(Vector2(cx - 22, 7), label, clock_col)
	if wind.warning_left > 0.0 and inventory.windbreak_left <= 0.0 and lantern.state == Lantern.State.LIT \
			and not lantern.sheltered \
			and fmod(_time, 0.3) < 0.2:
		_centered(screen.y / 2 - 40, "THE WIND PICKS UP...", Color("cfe0ff"))

	# --- Area name, when you enter a new part of the labyrinth -------------------
	if _zone_t >= 0.0 and _zone_name != "":
		var za := clampf(_zone_t / 0.6, 0.0, 1.0) * clampf((4.0 - _zone_t) / 0.8, 0.0, 1.0)
		var zw := PixelFont.width_of(_zone_name)
		var zy := 46.0
		var gem := RarityIcon.size_of(_zone_tier) if _zone_tier != "" else Vector2i.ZERO
		var gap := gem.x + 4 if gem.x > 0 else 0   # the land's rarity gem, just before its name
		var line_w := maxf(zw + gap, PixelFont.width_of(_zone_sub)) + 24.0
		_canvas.draw_rect(Rect2(floorf((screen.x - line_w) / 2), zy - 4, line_w, 22), Color(0.03, 0.02, 0.05, 0.6 * za))
		_canvas.draw_rect(Rect2(floorf((screen.x - line_w) / 2), zy + 8, line_w, 1), Color(0.9, 0.8, 0.6, 0.5 * za))
		var sw := PixelFont.width_of(_zone_sub)
		PixelFont.draw(_canvas, Vector2(floorf((screen.x - sw) / 2), zy + 11), _zone_sub, Color(Color("b8a8d0"), za))
		var zx := floorf((screen.x - zw - gap) / 2)
		if gap > 0:
			RarityIcon.draw(_canvas, Vector2(zx, zy + 2 - floorf((gem.y - 1) / 2.0)), _zone_tier, _time, za)
		_canvas.draw_set_transform(Vector2(zx + gap, zy), 0.0, Vector2.ONE)
		PixelFont.draw(_canvas, Vector2.ZERO, _zone_name, Color(_zone_col, za), Color(0, 0, 0, za))
		_canvas.draw_set_transform(Vector2.ZERO)

	# --- Controls hint, fades out ------------------------------------------------------
	if _time < HINT_TIME and _death_t < 0.0 and player.ui_lock == "":
		var a := clampf((HINT_TIME - _time) / 1.5, 0.0, 1.0) * clampf(_time / 0.5, 0.0, 1.0)
		_centered(screen.y - 12, HINT_P2 if (hero != null and hero.pfx == "p2_") else HINT, Color(C_TEXT, a))

	# --- Death screen ------------------------------------------------------------------
	if _death_t >= 0.0:
		var a := clampf(_death_t / 1.5, 0.0, 1.0)
		_canvas.draw_rect(Rect2(Vector2.ZERO, screen), Color(0.01, 0.0, 0.02, a))
		if _death_t > 1.2:
			var ta := clampf((_death_t - 1.2) / 1.0, 0.0, 1.0)
			_centered(screen.y / 2 - 10, _death_title, Color(C_FUEL_LOW, ta))
			if stats != null and _death_t > 2.2:
				var sa := clampf((_death_t - 2.2) / 1.0, 0.0, 1.0)
				var sy := screen.y / 2 + 14
				for line in stats.lines():
					_centered(sy, line, Color(C_DIM, sa * 0.8))
					sy += 9
			_centered(screen.y - 16, "PRESS R FOR A NEW LABYRINTH", Color(C_TEXT, ta))
