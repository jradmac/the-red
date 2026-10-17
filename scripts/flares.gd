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
	# A freshly lit flare flares up bright, then settles.
	for l in _lights:
		l.energy = move_toward(l.energy, 0.9, delta * 0.8)
		l.radius = move_toward(l.radius, 44.0, delta * 30.0)


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
