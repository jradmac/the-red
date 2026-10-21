class_name HeroLook
## Draws the hero in layers: the weapon you carry (strapped to your back) and
## a body that changes with your armor. draw() is the small overworld hero;
## draw_big() is the detailed 64 x 96 one (tools/make_hero_big.py) for the
## battle screen and the bag.

const BODY_TEX: Texture2D = preload("res://assets/hero.png")
const BODY_BLUE_TEX: Texture2D = preload("res://assets/hero_blue.png")   # the lantern burning blue
const BODY_P2_TEX: Texture2D = preload("res://assets/hero_p2.png")        # player 2: blue clothes
const BODY_P2_BLUE_TEX: Texture2D = preload("res://assets/hero_p2_blue.png")
## Which hero the next draw() is for (see use()).
static var blue_flame := false
static var p2 := false


## Draw the next hero as this player looks (player 2's clothes, a blue lantern).
static func use(pl: Node) -> void:
	p2 = pl != null and pl.get("p2") == true
	blue_flame = pl != null and pl.get("lantern_blue") == true
const GEAR_TEX: Texture2D = preload("res://assets/gear.png")
const WAKE_TEX: Texture2D = preload("res://assets/hero_wake.png")        ## getting out of bed (draw_pose)
const WAKE_BLUE_TEX: Texture2D = preload("res://assets/hero_wake_blue.png")
const WAKE_P2_TEX: Texture2D = preload("res://assets/hero_wake_p2.png")
const WAKE_P2_BLUE_TEX: Texture2D = preload("res://assets/hero_wake_p2_blue.png")
const WAKE_CELL := Vector2(40, 32)
const WAKE_HIP := Vector2(20, 21)   ## where the standing frame's (8, 19) falls in a wake cell
const BIG_TEX: Texture2D = preload("res://assets/hero_big.png")
const BIG_BLUE_TEX: Texture2D = preload("res://assets/hero_big_blue.png")
const BIG_P2_TEX: Texture2D = preload("res://assets/hero_big_p2.png")
const BIG_P2_BLUE_TEX: Texture2D = preload("res://assets/hero_big_p2_blue.png")
const BIG_ARM_TEX: Texture2D = preload("res://assets/hero_big_arm.png")
const GEAR_BIG_TEX: Texture2D = preload("res://assets/gear_big.png")
const STRAPS_TEX: Texture2D = preload("res://assets/straps.png")          ## tools/make_straps.py
const STRAPS_BIG_TEX: Texture2D = preload("res://assets/straps_big.png")
const GEAR_SIDE_TEX: Texture2D = preload("res://assets/gear_side.png")       ## carried, seen from the side
const GEAR_SIDE_BIG_TEX: Texture2D = preload("res://assets/gear_side_big.png")
const BIG := Vector2(64, 96)              ## a big frame: the small one at 4x
const BIG_SHOULDER := Vector2(45, 50)     ## the right shoulder, seen from behind, in a big frame
const BIG_ARM := Vector2(16, 28)          ## an arm piece in hero_big_arm.png
const BIG_ARM_SHOULDER := Vector2(8, 4)   ## its shoulder; the hand is 15 px below
const BIG_GRIP := Vector2(10, 50)         ## where a hand holds a gear_big.png weapon
## Armor id -> look block in hero.png (4 rows of 3 frames each). "" = no armor.
const LOOKS := {"": 0, "worn_cloak": 1, "blue_hood": 1, "leather_vest": 2, "chain_shirt": 3, "bone_mail": 4, "iron_plate": 5,
	"kings_mantle": 6}   ## (6: the legendary one, tools/legendary_gear.py)
## Weapon id -> column in gear.png.
const WEAPONS := {"rusty_dagger": 0, "bone_club": 1, "hatchet": 2, "hooked_sickle": 3, "iron_mace": 4, "grave_blade": 5,
	"wardens_axe": 6,   ## (6: the legendary one, tools/legendary_gear.py)
	"pitchfork": 7, "cleaver": 8, "boar_spear": 9, "flail": 10, "silver_dagger": 11, "war_scythe": 12}   ## (7-12: everyday extras, legendary_gear.py EXTRA)
## How the weapon is carried, for each facing (down, up, left, right): slung
## across the back on a baldric, its grip up over the right shoulder and the
## blade down towards the left hip, bound to the strap by two loops.
## CARRY_OFF = the top-left of its gear box in the small frame (16 x 16 box),
## CARRY_OFF_BIG in the big one (64 x 64 box). Facing you it's upside down
## (grip up-left) behind you: the grip shows over your shoulder and the strap
## crosses your chest. From behind it's turned round (grip up-right) and lies
## across your back over the pack, bound by two loops. From the side it's the
## steeper side-view sprite (gear_side*.png), grip up behind your head and the
## blade down along your pack (mirrored facing right). tools/make_straps.py
## draws the baldric and loops to match.
const CARRY_OFF := [Vector2(-4, 3), Vector2(1, 5), Vector2(8, 3), Vector2(-8, 3)]
const CARRY_OFF_BIG := [Vector2(-4, 20), Vector2(4, 20), Vector2(28, 12), Vector2(-28, 12)]


## `origin` = top-left of the 16x24 frame. `facing`: 0 down, 1 up, 2 left, 3 right.
## `col`: 0 stand, 1/2 stepping. `body_bob`/`gear_off` animate the walk.
static func draw(ci: CanvasItem, origin: Vector2, scale: float, facing: int, col: int,
		armor: String, weapon: String, body_bob: float = 0.0, gear_off := Vector2.ZERO, hide_arm := false) -> void:
	var look: int = LOOKS.get(armor, 0)
	var has_weapon := WEAPONS.has(weapon)
	var in_front := facing == 1
	if has_weapon and not in_front:
		_weapon(ci, origin, scale, facing, WEAPONS[weapon], gear_off)
	var tex := body_tex()
	var src := Rect2(col * 16, (look * 4 + facing) * 24, 16, 24)
	var at := origin + Vector2(0, body_bob) * scale
	if hide_arm:
		# (battle, seen from behind) the right arm is drawn on its own, swinging
		# the weapon -- leave it off the body
		for part: Rect2 in [Rect2(0, 0, 14, 24), Rect2(14, 0, 2, 14), Rect2(14, 20, 2, 4)]:
			ci.draw_texture_rect_region(tex, Rect2(at + part.position * scale, part.size * scale),
				Rect2(src.position + part.position, part.size))
	else:
		ci.draw_texture_rect_region(tex, Rect2(at, Vector2(16, 24) * scale), src)
	if has_weapon:
		_straps(ci, STRAPS_TEX, at - Vector2(8, 8) * scale, 32.0, scale, facing, 0)
		if in_front and not hide_arm:   # (swinging it: it's in your hand, not on your back)
			_weapon(ci, origin, scale, facing, WEAPONS[weapon], gear_off)
			_straps(ci, STRAPS_TEX, origin + (gear_off - Vector2(8, 8)) * scale, 32.0, scale, facing, 1)


## The detailed hero, 64 x 96 with `origin` its top-left (feet at the bottom
## middle, like the small frame at 4x). `facing`: 0 down, 1 up, 2 left, 3 right.
## `body_bob`/`gear_off` are in pixels. `hide_arm`: from behind, leave the right
## arm off (the battle draws it swinging; see big_arm_src()).
static func draw_big(ci: CanvasItem, origin: Vector2, facing: int, armor: String, weapon: String,
		body_bob: float = 0.0, gear_off := Vector2.ZERO, hide_arm := false) -> void:
	var look: int = LOOKS.get(armor, 0)
	var has_weapon := WEAPONS.has(weapon)
	var in_front := facing == 1
	if has_weapon and not in_front:
		_weapon_big(ci, origin, facing, WEAPONS[weapon], gear_off)
	var tex: Texture2D = (BIG_P2_BLUE_TEX if blue_flame else BIG_P2_TEX) if p2 else (BIG_BLUE_TEX if blue_flame else BIG_TEX)
	var col := 4 if (hide_arm and facing == 1) else facing
	var at := origin + Vector2(0, body_bob)
	ci.draw_texture_rect_region(tex, Rect2(at, BIG), Rect2(Vector2(col, look) * BIG, BIG))
	if has_weapon:
		_straps(ci, STRAPS_BIG_TEX, at - Vector2(32, 32), 128.0, 1.0, facing, 0)
		if in_front and not hide_arm:   # (swinging it: it's in your hand, not on your back)
			_weapon_big(ci, origin, facing, WEAPONS[weapon], gear_off)
			_straps(ci, STRAPS_BIG_TEX, origin + gear_off - Vector2(32, 32), 128.0, 1.0, facing, 1)


## The right arm on its own (seen from behind), for the next hero: its shoulder
## is at BIG_ARM_SHOULDER in the piece.
static func big_arm_src(armor: String) -> Rect2:
	return Rect2(Vector2(LOOKS.get(armor, 0) * BIG_ARM.x, BIG_ARM.y if p2 else 0.0), BIG_ARM)


static func _weapon_big(ci: CanvasItem, origin: Vector2, facing: int, index: int, off: Vector2) -> void:
	_slung(ci, GEAR_SIDE_BIG_TEX if facing >= 2 else GEAR_BIG_TEX, Rect2(index * 64, 0, 64, 64),
		origin + CARRY_OFF_BIG[facing] + off, 64.0, facing)


## A weapon box as carried for a facing, by exact pixel flips (no rotation):
## upside down (facing you), turned round (from behind), the side sprite as it
## is (facing left) or mirrored (facing right).
static func _slung(ci: CanvasItem, tex: Texture2D, src: Rect2, p: Vector2, size: float, facing: int) -> void:
	var flip: Vector2 = [Vector2(1, -1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)][facing]
	var at := p + Vector2(size if flip.x < 0 else 0.0, size if flip.y < 0 else 0.0)
	ci.draw_set_transform(at, 0.0, flip)
	ci.draw_texture_rect_region(tex, Rect2(Vector2.ZERO, Vector2(size, size)), src)
	ci.draw_set_transform(Vector2.ZERO)


## One layer of the straps (0 the baldric, 1 the loops) for a facing; `p` is the
## cell's top-left, `cell` its size in the sheet, drawn at `scale`.
static func _straps(ci: CanvasItem, tex: Texture2D, p: Vector2, cell: float, scale: float, facing: int, row: int) -> void:
	if row == 1 and facing != 1:
		return   # the loops only show from behind
	ci.draw_texture_rect_region(tex, Rect2(p, Vector2(cell, cell) * scale), Rect2(facing * cell, row * cell, cell, cell))


## The body sheet for the next hero (player 2's clothes, a blue lantern).
static func body_tex() -> Texture2D:
	return (BODY_P2_BLUE_TEX if blue_flame else BODY_P2_TEX) if p2 else (BODY_BLUE_TEX if blue_flame else BODY_TEX)


## Seen from behind: the right arm (shoulder to hand) as a 3 x 6 piece of the
## body sheet, its outline included. Its shoulder is at (1.5, 0.5) in the piece,
## the frame's (14.5, 14.5); the hand is 4 pixels below that.
static func back_arm_src(armor: String) -> Rect2:
	return Rect2(13, (LOOKS.get(armor, 0) * 4 + 1) * 24 + 14, 3, 6)


## The hero getting into or out of bed, seen from the front, in drawn frames
## (hero_wake*.png, tools/make_wake_frames.py): `up` 0 = lying on his back
## (head to the left, legs along the bed, toes up) .. 1 = sat up; `legs` 0 =
## sat with the legs drawn up out of sight under the cloak, ~0.6 = perched on
## the edge (the same, settled lower), 1 = legs back out -- the plain standing
## frame, with the hip at `hip` (the frame's (8, 19)).
static func draw_pose(ci: CanvasItem, hip: Vector2, up: float, legs: float, armor: String, scale: float = 1.0) -> void:
	var look: int = LOOKS.get(armor, 0)
	var tex: Texture2D = (BODY_P2_BLUE_TEX if blue_flame else BODY_P2_TEX) if p2 else (BODY_BLUE_TEX if blue_flame else BODY_TEX)
	ci.draw_set_transform(hip, 0.0, Vector2(scale, scale))
	var col := -1
	if up < 0.34:
		col = 0          # lying
	elif up < 0.75:
		col = 1          # propped up
	elif legs < 0.4:
		col = 2          # sat up, legs tucked away under the cloak
	elif legs < 0.85:
		col = 3          # perched on the edge, about to hop down
	if col < 0:
		ci.draw_texture_rect_region(tex, Rect2(-8, -19, 16, 24), Rect2(0, look * 4 * 24, 16, 24))
	else:
		var wake: Texture2D = (WAKE_P2_BLUE_TEX if blue_flame else WAKE_P2_TEX) if p2 else (WAKE_BLUE_TEX if blue_flame else WAKE_TEX)
		ci.draw_texture_rect_region(wake, Rect2(-WAKE_HIP, WAKE_CELL), Rect2(Vector2(col, look) * WAKE_CELL, WAKE_CELL))
	ci.draw_set_transform(Vector2.ZERO)


static func _weapon(ci: CanvasItem, origin: Vector2, scale: float, facing: int, index: int, off: Vector2) -> void:
	_slung(ci, GEAR_SIDE_TEX if facing >= 2 else GEAR_TEX, Rect2(index * 16, 0, 16, 16),
		origin + (CARRY_OFF[facing] + off) * scale, 16.0 * scale, facing)
