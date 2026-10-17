class_name HeroLook
## Draws the hero in layers: the weapon you carry (strapped to your back) and
## a body that changes with your armor. Used by the overworld hero and the
## battle screen.

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
## Armor id -> look block in hero.png (4 rows of 3 frames each). "" = no armor.
const LOOKS := {"": 0, "worn_cloak": 1, "leather_vest": 2, "chain_shirt": 3, "bone_mail": 4, "iron_plate": 5}
## Weapon id -> column in gear.png.
const WEAPONS := {"rusty_dagger": 0, "bone_club": 1, "hatchet": 2, "hooked_sickle": 3, "iron_mace": 4, "grave_blade": 5}
## Where the weapon sits (frame pixels) for each facing: down, up, left, right.
## Facing you, it's behind you (only the end pokes over your shoulder); from
## behind it's strapped across your back; from the side it sticks out behind.
const WEAPON_POS := [Vector2(-3, -1), Vector2(1, 2), Vector2(6, 2), Vector2(-6, 2)]
const WEAPON_FLIP := [true, false, false, true]


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
	if has_weapon and in_front:
		_weapon(ci, origin, scale, facing, WEAPONS[weapon], gear_off)


## The body sheet for the next hero (player 2's clothes, a blue lantern).
static func body_tex() -> Texture2D:
	return (BODY_P2_BLUE_TEX if blue_flame else BODY_P2_TEX) if p2 else (BODY_BLUE_TEX if blue_flame else BODY_TEX)


## Seen from behind: the right arm (shoulder to hand) as a 3 x 6 piece of the
## body sheet, its outline included. Its shoulder is at (1.5, 0.5) in the piece,
## the frame's (14.5, 14.5); the hand is 4 pixels below that.
static func back_arm_src(armor: String) -> Rect2:
	return Rect2(13, (LOOKS.get(armor, 0) * 4 + 1) * 24 + 14, 3, 6)


## The hero getting into or out of bed, seen from the front. The body bends at
## the hip: `up` 0 = lying on the back (head to the left) .. 1 = sitting up;
## `legs` 0 = legs stretched out along the bed (to the right) .. 1 = hanging
## down / standing. With up = legs = 1 it's exactly the standing frame, with
## the hip at `hip` (the frame's (8, 19)).
static func draw_pose(ci: CanvasItem, hip: Vector2, up: float, legs: float, armor: String, scale: float = 1.0) -> void:
	var look: int = LOOKS.get(armor, 0)
	var tex: Texture2D = (BODY_P2_BLUE_TEX if blue_flame else BODY_P2_TEX) if p2 else (BODY_BLUE_TEX if blue_flame else BODY_TEX)
	var row := look * 4 * 24
	ci.draw_set_transform(hip, -PI / 2.0 * (1.0 - clampf(legs, 0.0, 1.0)), Vector2(scale, scale))
	ci.draw_texture_rect_region(tex, Rect2(-8, 0, 16, 5), Rect2(0, row + 19, 16, 5))
	ci.draw_set_transform(hip, -PI / 2.0 * (1.0 - clampf(up, 0.0, 1.0)), Vector2(scale, scale))
	ci.draw_texture_rect_region(tex, Rect2(-8, -19, 16, 19), Rect2(0, row, 16, 19))
	ci.draw_set_transform(Vector2.ZERO)


static func _weapon(ci: CanvasItem, origin: Vector2, scale: float, facing: int, index: int, off: Vector2) -> void:
	var p: Vector2 = origin + (WEAPON_POS[facing] + off) * scale
	var src := Rect2(index * 16, 0, 16, 16)
	if WEAPON_FLIP[facing]:
		# Mirror by drawing through a flipped transform.
		ci.draw_set_transform(p + Vector2(16 * scale, 0), 0.0, Vector2(-1, 1))
		ci.draw_texture_rect_region(GEAR_TEX, Rect2(Vector2.ZERO, Vector2(16, 16) * scale), src)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		ci.draw_texture_rect_region(GEAR_TEX, Rect2(p, Vector2(16, 16) * scale), src)
