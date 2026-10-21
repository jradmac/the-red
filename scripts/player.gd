class_name Player
extends Node2D
## Grid-based movement in the style of classic handheld RPGs:
## one tile per step, smooth slide between tiles, turn in place when blocked.
##
## Controls: arrow keys / WASD / gamepad D-pad. Hold Z (or Shift / gamepad B)
## to sprint: it burns ENERGY, which refills when you stop. Run it dry and
## you're winded for a few seconds until it's full again.

var pfx := ""   ## input action prefix: "" for player 1, "p2_" for player 2

signal stepped(cell: Vector2i)

const WALK_TIME := 0.22  # seconds per tile
const RUN_TIME := 0.12
const MAX_ENERGY := 100.0
const ENERGY_DRAIN := 22.0      # per second while sprinting (~4.5 s of sprint)
const ENERGY_REFILL := 30.0     # per second when not sprinting
const REFILL_DELAY := 0.6       # pause before it starts refilling
const TILE := World.TILE

enum Facing { DOWN, UP, LEFT, RIGHT }

## Where the lantern hangs (relative to the tile's top-left), per facing.
const LANTERN_OFFSET := {
	Facing.DOWN: Vector2(14, 12),
	Facing.UP: Vector2(1, 12),
	Facing.LEFT: Vector2(3, 11),
	Facing.RIGHT: Vector2(13, 11),
}

var world: World
var cell := Vector2i.ZERO
var facing := Facing.DOWN
var moving := false
## Name of the menu / text box that currently owns the controls ("" = none).
## While set, the hero can't move or act.
var ui_lock := "":
	set(value):
		if value == "" and ui_lock != "":
			_unlock_frame = Engine.get_process_frames()
		ui_lock = value
var _unlock_frame := -1
## Extra check for tiles you can't step into (set by main: enemies).
var blocked: Callable
## Called with (tile, fresh_press) when you walk into something `blocked`
## (an enemy or a sprite).
var bumped: Callable
## Called with (tile, fresh_press) when you walk into a wall, bush, rock...
var bumped_wall: Callable
var dead := false
var knocked_out := false   ## co-op: down for a moment, not dead (main.gd)
var energy := MAX_ENERGY
var stuck_t := 0.0     ## held in place (a bear trap) for this long
var slow_steps := 0    ## next steps are slowed (quicksand)
var winded := false   ## ran out: no sprinting until energy is full again
var sprinting := false
var _rest_t := 0.0
var lantern_offset := LANTERN_OFFSET[Facing.DOWN]
var _step_frame := 0
var _move_from := Vector2.ZERO
var _move_to := Vector2.ZERO
var _move_t := 0.0
var _move_duration := WALK_TIME
var _held_dirs: Array[Vector2i] = []
## What the hero visibly wears and carries (set by main from the inventory).
var armor_id := "worn_cloak"
var weapon_id := "rusty_dagger"
var _col := 0
var sleeping := false   ## lying on the bier during the intro
## Getting up off the bier (intro): see HeroLook.draw_pose. pose_up < 0 = normal.
var pose_up := -1.0
var pose_legs := 0.0
var pose_hip := Vector2(15, 2)
var p2 := false            ## player 2: blue clothes
var lantern_blue := false  ## set by main: the lantern burns blue
var lantern_glow := Color(0, 0, 0, 0)   ## set by main: a shimmer around the lantern (blue flame, sunstone)
var _body_bob := 0.0
var _gear_off := Vector2.ZERO
## Climbing over a wall on a ladder (Ladders): up, over the top, a hop down.
const CLIMB_TIME := 1.35
const CLIMB_TOP := 1.08     # tiles: just over a crypt wall's top
var climbing := false
var climb_lift := 0.0       ## tiles off the ground right now (3D: raised; 2D: drawn higher)
var _climb := {}
var _gear_vel := Vector2.ZERO


func _ready() -> void:
	_setup_input()


func setup(w: World, start: Vector2i) -> void:
	world = w
	cell = start
	position = world.cell_to_position(cell)
	_update_sprite(0.0)


func _process(delta: float) -> void:
	if world == null:
		return   # labyrinth still being built
	if Input.is_action_just_pressed(pfx + "restart") or (dead and not knocked_out and Input.is_action_just_pressed(pfx + "inventory")):
		get_tree().reload_current_scene()  # brand-new labyrinth
		return
	_update_held_dirs()
	if ui_lock != "" or dead:
		_held_dirs.clear()
	if climbing:
		_tick_climb(delta)
		_update_energy(delta)
		_update_sprite(delta)
		return
	if moving:
		_move_t += delta / _move_duration
		if _move_t >= 1.0:
			position = _move_to
			moving = false
			stepped.emit(cell)
		else:
			position = _move_from.lerp(_move_to, _move_t).round()
	if not moving:
		_try_start_move()
	_update_energy(delta)
	stuck_t = maxf(stuck_t - delta, 0.0)
	_update_sprite(delta)
	lantern_offset = lantern_offset.lerp(LANTERN_OFFSET[facing], 0.3)


func _wants_sprint() -> bool:
	return Controls.sprint_held(pfx) and not winded and energy > 0.0 and ui_lock == ""


func _update_energy(delta: float) -> void:
	sprinting = moving and _move_duration < WALK_TIME
	if sprinting:
		energy = maxf(energy - ENERGY_DRAIN * delta, 0.0)
		_rest_t = 0.0
		if energy <= 0.0:
			winded = true
	else:
		_rest_t += delta
		if _rest_t > REFILL_DELAY:
			energy = minf(energy + ENERGY_REFILL * delta * (0.7 if winded else 1.0), MAX_ENERGY)
	if winded and energy >= MAX_ENERGY:
		winded = false


## True when nothing is open and the hero can do things (open, strike, plant).
## Also false on the frame a menu closes, so one key press can't do two things.
func can_act() -> bool:
	return ui_lock == "" and not dead and not climbing and Engine.get_process_frames() != _unlock_frame


func facing_cell() -> Vector2i:
	return cell + [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT][int(facing)]


## Over the wall at `wall` (a ladder's on it) and down onto `land`.
func climb_over(wall: Vector2i, land: Vector2i) -> void:
	facing = _dir_to_facing(wall - cell)
	_climb = {"from": position, "wall": world.cell_to_position(wall), "to": world.cell_to_position(land),
		"land": land, "t": 0.0}
	climbing = true
	moving = true
	Sfx.play("rustle", -6.0, 0.1, 0.8)


## Off the edge of high ground: across the rim (`rim`, the plateau's edge
## tile) and down onto `land` below (World.drop_land says where).
const JUMP_TIME := 0.5


func jump_down(rim: Vector2i, land: Vector2i) -> void:
	var d := Vector2(rim - cell)
	facing = _dir_to_facing(rim - cell)
	_climb = {"jump": true, "from": position, "rim": world.cell_to_position(rim) + d * TILE * 0.55,
		"to": world.cell_to_position(land), "land": land, "t": 0.0,
		"top": float(world.height_at(cell)) * WorldMesh.LEVEL, "low": float(world.height_at(land)) * WorldMesh.LEVEL}
	climbing = true
	moving = true


func _tick_jump(delta: float) -> void:
	_climb.t += delta / JUMP_TIME
	var u: float = _climb.t
	var h: float = _climb.top
	if u < 0.4:            # a quick step out to the edge, still up top
		position = (_climb.from as Vector2).lerp(_climb.rim, u / 0.4).round()
	elif u < 1.0:          # and over: a little hop up, then down
		var k := (u - 0.4) / 0.6
		if not _climb.has("hop"):
			_climb["hop"] = true
			Sfx.play("dodge", -8.0)
		position = (_climb.rim as Vector2).lerp(_climb.to, k).round()
		h = lerpf(_climb.top, _climb.low, k * k) + 0.32 * sin(k * PI) * (1.0 - k * 0.5)
	else:
		position = _climb.to
		cell = _climb.land
		climb_lift = 0.0
		climbing = false
		moving = false
		_climb = {}
		Sfx.play("bump", -4.0, 0.05, 0.7)   # a thump as you land
		stepped.emit(cell)
		return
	# how high that is above the ground right under you (the 3D view stands you on it)
	var under := Vector2i(int(floor(position.x / TILE + 0.5)), int(floor(position.y / TILE + 0.5)))
	climb_lift = maxf(h - float(world.height_at(under)) * WorldMesh.LEVEL, 0.0)


func _tick_climb(delta: float) -> void:
	if _climb.get("jump", false):
		_tick_jump(delta)
		return
	_climb.t += delta / CLIMB_TIME
	var u: float = _climb.t
	var near: Vector2 = (_climb.from as Vector2).lerp(_climb.wall, 0.5)    # at the wall's face
	var far: Vector2 = (_climb.wall as Vector2).lerp(_climb.to, 0.5)       # its other face
	if u < 0.5:            # up the ladder, hand over hand
		var k := u / 0.5
		var rung := int(k * 4.0)   # the rungs creak under each step up
		if rung > int(_climb.get("rung", -1)):
			_climb["rung"] = rung
			Sfx.play("ladder", -4.0, 0.12)
		position = (_climb.from as Vector2).lerp(near, minf(k * 1.6, 1.0)).round()
		climb_lift = CLIMB_TOP * smoothstep(0.0, 1.0, k)
	elif u < 0.72:         # over the top
		var k := (u - 0.5) / 0.22
		position = near.lerp(far, k).round()
		climb_lift = CLIMB_TOP + 0.1 * sin(k * PI)
	elif u < 1.0:          # and a hop down the other side
		var k := (u - 0.72) / 0.28
		position = far.lerp(_climb.to, k).round()
		climb_lift = CLIMB_TOP * (1.0 - k) + 0.35 * sin(k * PI) * (1.0 - k)
		if not _climb.has("hop"):
			_climb["hop"] = true
			Sfx.play("dodge", -8.0)
	else:
		position = _climb.to
		cell = _climb.land
		climb_lift = 0.0
		climbing = false
		moving = false
		Sfx.play("bump", -6.0, 0.05, 0.8)
		stepped.emit(cell)


func _try_start_move() -> void:
	if _held_dirs.is_empty() or stuck_t > 0.0:
		return
	var dir: Vector2i = _held_dirs.back()
	facing = _dir_to_facing(dir)
	var target := cell + dir
	if blocked.is_valid() and blocked.call(target):
		if bumped.is_valid():
			bumped.call(target, Input.is_action_just_pressed(pfx + _dir_action(dir)))
		return
	if not world.is_walkable(target):
		# at the edge of high ground: jump down (World.drop_land)
		var land: Vector2i = world.drop_land(cell, dir)
		if land.x >= 0 and not (blocked.is_valid() and blocked.call(land)):
			jump_down(target, land)
			return
		if bumped_wall.is_valid():
			bumped_wall.call(target, Input.is_action_just_pressed(pfx + _dir_action(dir)))
		return
	if world.is_walkable(target):
		cell = target
		_move_from = position
		_move_to = world.cell_to_position(target)
		_move_t = 0.0
		_move_duration = RUN_TIME if _wants_sprint() else WALK_TIME
		if slow_steps > 0:
			slow_steps -= 1
			_move_duration = WALK_TIME * 2.2
		moving = true
		_step_frame = 1 - _step_frame


## Walk cycle: the stepping frame shows mid-stride and the body lifts a pixel.
## The weapon on your back is on a little spring: it lags behind the body's
## bounce and swings a touch side to side, more when running.
func _update_sprite(delta: float) -> void:
	_col = 0
	if climbing:
		# hand over hand up the rungs, then still for the hop
		var u: float = _climb.get("t", 0.0)
		_col = [1, 2, 3, 4][int(u * 14.0) % 4] if u < 0.5 else 0
		_body_bob = 0.0
		queue_redraw()
		return
	var lift := 0.0
	var sway := 0.0
	if moving:
		var running := _move_duration < WALK_TIME
		# a full stride is two steps: contact, pass, contact (other foot), pass
		var phase := _step_frame * 2 + (0 if _move_t < 0.5 else 1)
		_col = (5 if running else 1) + phase
		lift = -sin(clampf(_move_t, 0.0, 1.0) * PI)   # 0 -> -1 -> 0 over a step
		if running:
			lift *= 1.6
		var side := 1.0 if _step_frame == 0 else -1.0
		sway = side * (1.0 if running else 0.6) * sin(clampf(_move_t, 0.0, 1.0) * PI)
	_body_bob = roundf(lift * 0.9) if moving else 0.0
	# Spring toward (sway, lift), so the weapon trails the body.
	var target := Vector2(sway, lift * 1.2)
	if facing == Facing.LEFT or facing == Facing.RIGHT:
		target.x = sway * 0.5
	if delta > 0.0:
		var accel := (target - _gear_off) * 260.0 - _gear_vel * 18.0
		_gear_vel += accel * delta
		_gear_off += _gear_vel * delta
	queue_redraw()


func _draw() -> void:
	paint(self, Vector2(0, -roundf(climb_lift * TILE)))


## Draws the hero onto any canvas with its tile's top-left at `at` (its own
## _draw, or a sprite for the 3D view).
func paint(ci: CanvasItem, at: Vector2) -> void:
	if sleeping or pose_up >= 0.0:   # on the bier (on his back, head to the left), or getting up
		HeroLook.use(self)
		HeroLook.draw_pose(ci, at + (pose_hip if pose_up >= 0.0 else Vector2(15, 2)), maxf(pose_up, 0.0),
			pose_legs if pose_up >= 0.0 else 0.0, armor_id)
		return
	# Soft ground shadow under the feet.
	Shadows.oval(ci, at + Vector2(8, 14), 12)
	HeroLook.use(self)
	HeroLook.draw(ci, at + Vector2(0, -8), 1.0, int(facing), _col, armor_id, weapon_id,
		_body_bob, _gear_off.round())
	if lantern_glow.a > 0.0:   # a cold shimmer around the lantern
		var lp := at + lantern_offset + Vector2(0, _body_bob - 8 + 2)
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
		ci.draw_circle(lp, 6.0, Color(lantern_glow, lantern_glow.a * 0.18 * pulse))
		ci.draw_circle(lp, 3.5, Color(lantern_glow, lantern_glow.a * 0.35 * pulse))
		var k := int(Time.get_ticks_msec() / 90) % 6
		ci.draw_rect(Rect2((lp + Vector2.from_angle(k * 1.05) * 5.0).round(), Vector2.ONE), Color(lantern_glow.lightened(0.5), lantern_glow.a))


func _update_held_dirs() -> void:
	var dirs := {
		"move_up": Vector2i.UP,
		"move_down": Vector2i.DOWN,
		"move_left": Vector2i.LEFT,
		"move_right": Vector2i.RIGHT,
	}
	for action in dirs:
		var d: Vector2i = dirs[action]
		if Input.is_action_just_pressed(pfx + action):
			_held_dirs.erase(d)
			_held_dirs.append(d)
		elif not Input.is_action_pressed(pfx + action):
			_held_dirs.erase(d)


func _dir_action(d: Vector2i) -> String:
	if d == Vector2i.UP:
		return "move_up"
	if d == Vector2i.DOWN:
		return "move_down"
	if d == Vector2i.LEFT:
		return "move_left"
	return "move_right"


func _dir_to_facing(d: Vector2i) -> Facing:
	if d == Vector2i.UP:
		return Facing.UP
	if d == Vector2i.LEFT:
		return Facing.LEFT
	if d == Vector2i.RIGHT:
		return Facing.RIGHT
	return Facing.DOWN


# --- Input map (set in code so the project needs no manual setup) ---------

func _setup_input() -> void:
	if not InputMap.has_action("confirm"):
		Controls.setup_solo()


func _add_action(action: String, keys: Array, joy_button: JoyButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	if joy_button != JOY_BUTTON_INVALID:
		var jb := InputEventJoypadButton.new()
		jb.button_index = joy_button
		InputMap.action_add_event(action, jb)
