class_name WatchingEyes
extends Node2D
## Pairs of glowing eyes that open in the darkness, blink, and shrink away
## when the lantern gets close. When the lantern dies (dread = 1) they crowd
## in close and stop fleeing. Pure atmosphere for now; in milestone 6 the
## real demons (and the Longman) take over this job.

const MAX_EYES := 3
const MIN_DIST := 5   # tiles from the player
const MAX_DIST := 9
const FLEE_DIST := 3.5
const COLORS := [Color("ffe9a0"), Color("ff4a5a"), Color("c8ff8a")]

var world: World
var player: Player
var _eyes: Array[Dictionary] = []
var _spawn_timer := 1.5
var dread := 0.0  ## 0 = normal, 1 = your light is out


func setup(w: World, p: Player) -> void:
	world = w
	player = p


func _process(delta: float) -> void:
	if world == null:
		return
	_spawn_timer -= delta * (1.0 + dread * 6.0)
	if _spawn_timer <= 0.0 and _eyes.size() < MAX_EYES + int(dread * 7):
		_spawn_timer = randf_range(1.5, 4.0)
		_try_spawn()

	for e in _eyes:
		e.age += delta
		var dist: float = (Vector2(e.cell) - Vector2(player.cell)).length()
		if (dist < FLEE_DIST and dread < 0.5) or e.age > e.life + dread * 10.0:
			e.fading = true
		e.alpha = move_toward(e.alpha, 0.0 if e.fading else 1.0, delta * (3.0 if e.fading else 0.8))
		e.blink -= delta
		if e.blink < -0.12:
			e.blink = randf_range(1.0, 3.5)
	_eyes = _eyes.filter(func(e): return not (e.fading and e.alpha <= 0.0))
	queue_redraw()


func _try_spawn() -> void:
	for attempt in 20:
		var far := MAX_DIST - int(dread * 5)
		var near := MIN_DIST - dread * 3.5
		var c := player.cell + Vector2i(randi_range(-far, far), randi_range(-far, far))
		var d := (Vector2(c) - Vector2(player.cell)).length()
		if d < near or d > far or not world.is_walkable(c) or world.near_village(c, 1):
			continue
		if world.tile_at(c) == "m":
			continue  # mushrooms glow; nothing hides there
		_eyes.append({
			"cell": c, "age": 0.0, "life": randf_range(3.0, 7.0), "alpha": 0.0,
			"fading": false, "blink": randf_range(0.5, 2.0),
			"color": COLORS[randi() % COLORS.size()],
			"gap": 3 + randi() % 2,
		})
		return


func _draw() -> void:
	for e in _eyes:
		if e.blink < 0.0:
			continue  # mid-blink
		var o: Vector2 = world.cell_to_position(e.cell) + Vector2(5, 6)
		var c: Color = e.color
		c.a = e.alpha
		draw_rect(Rect2(o, Vector2(2, 1)), c)
		draw_rect(Rect2(o + Vector2(e.gap + 2, 0), Vector2(2, 1)), c)
		var glow := Color(c.r, c.g, c.b, e.alpha * 0.25)
		draw_rect(Rect2(o + Vector2(0, -1), Vector2(2, 1)), glow)
		draw_rect(Rect2(o + Vector2(e.gap + 2, -1), Vector2(2, 1)), glow)
