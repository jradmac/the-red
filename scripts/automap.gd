class_name Automap
extends CanvasLayer
## The map screen. Toggle with M / Tab (gamepad: Select).
## It only shows areas you've lit with a flare, plus the flares themselves and
## where you're standing, so you build your map by choosing where to spend
## flares. It opens centered on you; arrows pan around. Movement is paused
## while it's open (your lantern still burns).

var pfx := ""   ## input action prefix: "" for player 1, "p2_" for player 2

const CELL := 2
const PAN_STEP := 3
const C_BG := Color(0.02, 0.01, 0.04, 1.0)
const C_FRAME := Color("5a5170")
const C_FLOOR := Color("6b6480")
const C_GRASS := Color("4f7a58")
const C_WATER := Color("2c3a66")
const C_WALL := Color("2a2438")
const C_CANDLE := Color("f5a33a")
const C_MUSH := Color("6fe0e8")
const C_FLARE := Color("7dff9a")
const C_HERO := Color("ec6a5c")
const C_TEXT := Color("e8dfc8")
const C_DIM := Color("6b6480")

var world: World
var player: Player
var flares: Flares
var chests: Chests
var doors: Doors
var master_cell := Vector2i(-1, -1)
var hints: Array[Vector2i] = []   ## spots a sprite revealed (blinking rings)
var _canvas: Node2D
var _blink := 0.0
var _view := Vector2i.ZERO    # map tile at the center of the screen
var _pan_t := 0.0


func setup(w: World, p: Player, f: Flares, ch: Chests, dr: Doors) -> void:
	doors = dr
	world = w
	player = p
	flares = f
	chests = ch
	layer = 5
	visible = false
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_map)
	add_child(_canvas)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed(pfx + "map"):
		if not visible and player.can_act():
			visible = true
			Sfx.play("page")
			player.ui_lock = "map"
			_view = player.cell
		elif visible:
			visible = false
			player.ui_lock = ""
	if visible:
		_blink += delta
		_pan(delta)
		_canvas.queue_redraw()


func _pan(delta: float) -> void:
	var dir := Vector2i.ZERO
	if Input.is_action_pressed(pfx + "move_left"): dir.x -= 1
	if Input.is_action_pressed(pfx + "move_right"): dir.x += 1
	if Input.is_action_pressed(pfx + "move_up"): dir.y -= 1
	if Input.is_action_pressed(pfx + "move_down"): dir.y += 1
	if dir == Vector2i.ZERO:
		_pan_t = 0.0
		return
	_pan_t -= delta
	if _pan_t <= 0.0:
		_pan_t = 0.08
		_view += dir * PAN_STEP
		_view.x = clampi(_view.x, 0, world.width - 1)
		_view.y = clampi(_view.y, 0, world.height - 1)


func _draw_map() -> void:
	var screen := _canvas.get_viewport_rect().size
	_canvas.draw_rect(Rect2(Vector2.ZERO, screen), C_BG)
	var area := Rect2(8, 16, screen.x - 16, screen.y - 28)
	_canvas.draw_rect(area.grow(2), C_FRAME, false)
	PixelFont.draw(_canvas, Vector2(area.position.x - 2, 6), "MAP", C_TEXT)
	var flare_text := "FLARES LEFT " + str(flares.count)
	PixelFont.draw(_canvas, Vector2(area.end.x + 2 - PixelFont.width_of(flare_text), 6), flare_text, C_DIM)
	PixelFont.draw(_canvas, Vector2(area.position.x - 2, screen.y - 9), "ARROWS PAN   M CLOSE", C_DIM)

	# Which map tiles fit, centered on _view and kept inside the labyrinth.
	var cols := int(area.size.x / CELL)
	var rows := int(area.size.y / CELL)
	var x0 := clampi(_view.x - cols / 2, 0, maxi(world.width - cols, 0))
	var y0 := clampi(_view.y - rows / 2, 0, maxi(world.height - rows, 0))
	var o := area.position - Vector2(x0, y0) * CELL
	var x1 := mini(x0 + cols, world.width)
	var y1 := mini(y0 + rows, world.height)

	for y in range(y0, y1):
		for x in range(x0, x1):
			var c := Vector2i(x, y)
			if not world.is_mapped(c):
				continue
			var col := C_FLOOR
			match world.tile_at(c):
				"#": col = C_WALL
				",", "w": col = C_GRASS
				"~": col = C_WATER
				"c": col = C_CANDLE
				"m": col = C_MUSH
			_canvas.draw_rect(Rect2(o + Vector2(x, y) * CELL, Vector2(CELL, CELL)), col)

	var shown := Rect2i(x0, y0, x1 - x0, y1 - y0)
	# Chests: shown if their spot is mapped, or a Seer's Draught revealed them.
	for c in chests.chests:
		var seer: bool = chests.revealed.has(c)
		if not shown.has_point(c) or not (world.is_mapped(c) or seer):
			continue
		var ccol := Color("5e3b26") if chests.chests[c].open else Color("e8b84a")
		if chests.chests[c].get("purple", false):
			ccol = Color("3a2060") if chests.chests[c].open else Color("a060ff")
		if seer and not chests.chests[c].open and fmod(_blink, 0.5) < 0.25:
			ccol = Color("fff1c2")
		_canvas.draw_rect(Rect2(o + Vector2(c) * CELL, Vector2(CELL, CELL)), ccol)

	const DOOR_COLORS := {"bronze": Color("c07a3a"), "silver": Color("c9cbd8"), "gold": Color("e8b84a")}
	for c in doors.doors:
		if shown.has_point(c) and world.is_mapped(c):
			var dcol: Color = C_FLOOR if doors.doors[c].open else DOOR_COLORS[doors.doors[c].color]
			_canvas.draw_rect(Rect2(o + Vector2(c) * CELL - Vector2.ONE, Vector2(CELL + 2, CELL + 2)), dcol)

	if master_cell.x >= 0 and world.is_mapped(master_cell) and shown.has_point(master_cell):
		_canvas.draw_rect(Rect2(o + Vector2(master_cell) * CELL - Vector2.ONE, Vector2(CELL + 2, CELL + 2)), Color("a060ff"))

	for c in hints:
		if shown.has_point(c):
			var pulse := 2.0 + (1.0 if fmod(_blink, 0.6) < 0.3 else 0.0)
			var rr := Rect2(o + Vector2(c) * CELL - Vector2.ONE * (pulse + 1), Vector2.ONE * (CELL + pulse * 2 + 2))
			_canvas.draw_rect(rr, Color("7dffe0"), false, 1.0)

	for c in flares.planted:
		if shown.has_point(c):
			_canvas.draw_rect(Rect2(o + Vector2(c) * CELL, Vector2(CELL, CELL)), C_FLARE)

	# Villages you've been to: a warm glow and their name.
	for v in world.villages:
		if not v.get("seen", false):
			continue
		var vr: Rect2i = v.rect
		if not shown.intersects(vr):
			continue
		var top := o + Vector2(vr.position) * CELL
		_canvas.draw_rect(Rect2(top, Vector2(vr.size) * CELL), Color(1.0, 0.8, 0.4, 0.12))
		var nm: String = v.name
		var nx := top.x + vr.size.x * CELL / 2.0 - PixelFont.width_of(nm) / 2.0
		_canvas.draw_rect(Rect2(nx - 2, top.y - 9, PixelFont.width_of(nm) + 4, 8), Color(0.05, 0.03, 0.08, 0.85))
		PixelFont.draw(_canvas, Vector2(roundf(nx), top.y - 8), nm, Color("ffd38a"))

	if not world.mapped.has(1):
		var msg := "NOTHING MAPPED YET"
		var msg2 := "PRESS F TO PLANT A FLARE"
		PixelFont.draw(_canvas, Vector2(floorf((screen.x - PixelFont.width_of(msg)) / 2), screen.y / 2 - 8), msg, C_TEXT)
		PixelFont.draw(_canvas, Vector2(floorf((screen.x - PixelFont.width_of(msg2)) / 2), screen.y / 2 + 2), msg2, C_DIM)

	if fmod(_blink, 0.6) < 0.4 and shown.has_point(player.cell):
		_canvas.draw_rect(Rect2(o + Vector2(player.cell) * CELL - Vector2.ONE * 2, Vector2(CELL + 4, CELL + 4)), C_HERO)
