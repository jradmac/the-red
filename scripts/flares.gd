class_name Flares
extends Node2D
## Flare markers. Press F (gamepad: L) to plant one where you stand: it burns
## green forever and puts that room (or stretch of corridor) on the map.
## Flares stack like matches and don't use an inventory slot.

var pfx := ""   ## input action prefix: "" for player 1, "p2_" for player 2

signal count_changed(count: int)
signal denied  ## tried to plant with none left, or on a tile that has one

const START_COUNT := 5
const LIGHT_COLOR := Color(0.45, 1.0, 0.6)
const PROPS_TEX: Texture2D = preload("res://assets/props.png")
const FLARE_INDEX := 5  # column in props.png

var world: World
var player: Player
var lighting: Lighting
var count := START_COUNT
var planted: Array[Vector2i] = []
var _lights: Array[Dictionary] = []
## Portal flares (an item, from the bag): they burn violet forever, show on
## the map like flares, and from the map either player can step back to one.
var portals: Array[Vector2i] = []
var _portal_lights: Array[Dictionary] = []
var _time := 0.0
const PORTAL_COLOR := Color(0.62, 0.42, 1.0)


func setup(w: World, p: Player, l: Lighting) -> void:
	world = w
	player = p
	lighting = l


func add(amount: int) -> void:
	count += amount
	count_changed.emit(count)


func bind(h: Hero) -> void:
	player = h.player
	pfx = h.pfx


## Run once per player per frame, bound to that player (main.gd).
func hero_tick() -> void:
	if Input.is_action_just_pressed(pfx + "mark") and player.can_act():
		_plant(player.cell)


func _process(delta: float) -> void:
	_time += delta
	# A freshly lit flare flares up bright, then settles.
	for l in _lights:
		l.energy = move_toward(l.energy, 0.9, delta * 0.8)
		l.radius = move_toward(l.radius, 44.0, delta * 30.0)
	# portal flares settle too, and breathe
	for l in _portal_lights:
		l.radius = move_toward(l.radius, 46.0, delta * 30.0)
		l["base"] = move_toward(float(l.get("base", l.energy)), 0.85, delta * 0.8)
		l.energy = float(l.base) * (0.9 + 0.1 * sin(_time * 2.5))
	if not portals.is_empty():
		queue_redraw()


## Plants a portal flare at `cell`. Returns the message ("!" first: it couldn't).
func plant_portal(cell: Vector2i) -> String:
	if portals.has(cell) or planted.has(cell):
		return "!SOMETHING IS ALREADY BURNING HERE."
	portals.append(cell)
	_portal_light(cell, true)
	world.map_area(cell)
	Sfx.play("flare", 0.0, 0.0, 0.7)
	Sfx.play("whisper", -8.0)
	queue_redraw()
	return "THE PORTAL FLARE CATCHES, VIOLET AND STILL. OPEN YOUR MAP AND PICK IT TO STEP BACK HERE FROM ANYWHERE."


func _portal_light(cell: Vector2i, fresh: bool) -> void:
	var l := lighting.add_light(world, world.cell_to_position(cell) + Vector2(7, 3), 96.0 if fresh else 46.0,
		PORTAL_COLOR, 1.8 if fresh else 0.85, 0.05)
	_portal_lights.append(l)


## Loading a saved game: the portal flares already burning.
func restore_portals(cells: Array) -> void:
	for cell in cells:
		if not portals.has(cell):
			portals.append(cell)
			_portal_light(cell, false)
	queue_redraw()


## A portal flare as it looks on the ground: the flare, ringed by a slow
## violet swirl (used here in 2D, and by SpriteHost in 3D).
static func paint_portal(ci: CanvasItem, at: Vector2, t: float) -> void:
	for k in 10:
		var a := t * 1.6 + k * TAU / 10.0
		var p := at + Vector2(8, 10) + Vector2(cos(a) * 6.5, sin(a) * 3.0 - 4.0 - 2.0 * sin(t * 2.0 + k))
		ci.draw_rect(Rect2(p.round(), Vector2.ONE), Color(0.85, 0.65, 1.0, 0.45 + 0.4 * sin(a * 2.0)))
	Items.draw_icon(ci, "portal_flare", Rect2(at + Vector2(0, -2 + roundf(sin(t * 2.0))), Vector2(16, 16)))


## Loading a saved game: flares already burning where they were planted.
func restore(cells: Array, new_count: int) -> void:
	for cell in cells:
		if planted.has(cell):
			continue
		planted.append(cell)
		var light := lighting.add_light(world, world.cell_to_position(cell) + Vector2(7, 3), 44.0, LIGHT_COLOR, 0.9, 0.1)
		_lights.append(light)
	count = new_count
	count_changed.emit(count)
	queue_redraw()


func _plant(cell: Vector2i) -> void:
	if count <= 0 or planted.has(cell):
		Sfx.play("ui_deny")
		denied.emit()
		return
	count -= 1
	Sfx.play("flare")
	planted.append(cell)
	var light := lighting.add_light(world, world.cell_to_position(cell) + Vector2(7, 3),
		90.0, LIGHT_COLOR, 2.0, 0.1)
	_lights.append(light)
	world.map_area(cell)
	count_changed.emit(count)
	queue_redraw()


func _draw() -> void:
	for c in planted:
		draw_texture_rect_region(PROPS_TEX, Rect2(world.cell_to_position(c), Vector2(16, 16)),
			Rect2(FLARE_INDEX * 16, 0, 16, 16))
	for c in portals:
		paint_portal(self, world.cell_to_position(c), _time)
