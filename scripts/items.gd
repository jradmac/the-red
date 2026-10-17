class_name Items
extends RefCounted
## The item catalog: every item's name, type, stats and icon, plus the loot
## table chests roll on. Add or rebalance items here.
##
## kinds:  weapon / armor / potion  -> take an inventory slot (potions stack to 3)
##         key                       -> takes a slot (same-color keys stack to 3)
##         matches / flare / lantern -> no slot (counters, or replaces your lantern)

const ICONS_TEX: Texture2D = preload("res://assets/items.png")

const DATA := {
	# Weapons (atk)
	"rusty_dagger": {"name": "RUSTY DAGGER", "kind": "weapon", "atk": 2, "icon": 0,
		"desc": "NICKED AND DULL. BETTER THAN NOTHING."},
	"bone_club": {"name": "BONE CLUB", "kind": "weapon", "atk": 3, "icon": 1,
		"desc": "A THIGHBONE. WHOSE, YOU'D RATHER NOT KNOW."},
	"hatchet": {"name": "HATCHET", "kind": "weapon", "atk": 4, "icon": 2,
		"desc": "A WOODSMAN'S HATCHET, STILL SHARP."},
	"hooked_sickle": {"name": "HOOKED SICKLE", "kind": "weapon", "atk": 4, "icon": 3,
		"desc": "FOR REAPING THINGS THAT AREN'T WHEAT."},
	"iron_mace": {"name": "IRON MACE", "kind": "weapon", "atk": 5, "icon": 4,
		"desc": "HEAVY, SPIKED, AND VERY PERSUASIVE."},
	"grave_blade": {"name": "GRAVE BLADE", "kind": "weapon", "atk": 6, "icon": 5,
		"desc": "A SWORD PULLED FROM A TOMB. IT HUMS."},
	# Armor (def)
	"worn_cloak": {"name": "WORN CLOAK", "kind": "armor", "def": 1, "icon": 6,
		"desc": "THIN WOOL. IT SMELLS LIKE HOME."},
	"leather_vest": {"name": "LEATHER VEST", "kind": "armor", "def": 2, "icon": 7,
		"desc": "STIFF LEATHER, STITCHED BY HAND."},
	"chain_shirt": {"name": "CHAIN SHIRT", "kind": "armor", "def": 3, "icon": 8,
		"desc": "RUSTY RINGS THAT STILL STOP A CLAW."},
	"bone_mail": {"name": "BONE MAIL", "kind": "armor", "def": 4, "icon": 9,
		"desc": "RIBS LASHED TOGETHER. GRIM BUT STURDY."},
	"iron_plate": {"name": "IRON PLATE", "kind": "armor", "def": 5, "icon": 10,
		"desc": "A KNIGHT'S BREASTPLATE. THE KNIGHT IS GONE."},
	# Potions
	"healing_tonic": {"name": "HEALING TONIC", "kind": "potion", "icon": 11,
		"desc": "RESTORES ALL YOUR HEALTH."},
	"lamp_oil": {"name": "LAMP OIL", "kind": "potion", "icon": 12,
		"desc": "REFILLS HALF YOUR LANTERN. WORKS EVEN IF IT'S OUT."},
	"red_berry": {"name": "RED BERRIES", "kind": "potion", "icon": 23,
		"desc": "SWEET AND SHARP. RESTORES 3 HEALTH."},
	"blue_berry": {"name": "BLUE BERRIES", "kind": "potion", "icon": 24,
		"desc": "CRUSH THEM INTO THE LANTERN: FOR 60 SECONDS IT BURNS BLUE AND CREATURES FLEE ITS LIGHT."},
	"sunstone": {"name": "SUNSTONE", "kind": "potion", "icon": 26,
		"desc": "A SHARD OF TRAPPED DAYLIGHT. FOR 2 MINUTES YOUR LANTERN BLAZES LIKE THE SUN: YOU SEE THE WHOLE SCREEN, IT BURNS NO FUEL, AND NO WIND CAN TOUCH IT."},
	"bomb": {"name": "BOMB", "kind": "bomb", "icon": 25,
		"desc": "PLANT IT AND RUN. A SHORT FUSE, THEN EVERYTHING CLOSE BY IS BLOWN TO SMOKE. (B)"},
	"windbreak": {"name": "WINDBREAK", "kind": "potion", "icon": 13,
		"desc": "FOR 60 SECONDS NO WIND CAN TOUCH YOUR FLAME."},
	"seers_draught": {"name": "SEER'S DRAUGHT", "kind": "potion", "icon": 14,
		"desc": "SHOWS THE NEAREST UNOPENED CHEST ON YOUR MAP."},
	# Lanterns (replace yours if better)
	"brass_lantern": {"name": "BRASS LANTERN", "kind": "lantern", "icon": 15,
		"max_fuel": 130.0, "radius": 94.0, "desc": "BURNS LONGER AND BRIGHTER."},
	"storm_lantern": {"name": "STORM LANTERN", "kind": "lantern", "icon": 28,
		"max_fuel": 150.0, "radius": 98.0, "desc": "IRON AND THICK GLASS. NO GUST CAN BLOW IT OUT."},
	"witchglass_lantern": {"name": "WITCHGLASS LANTERN", "kind": "lantern", "icon": 16,
		"max_fuel": 170.0, "radius": 104.0, "desc": "GREEN GLASS. THE DARK FLINCHES."},
	# Money
	"ruby": {"name": "RUBY", "kind": "ruby", "icon": 27,
		"desc": "THE VILLAGES TRADE IN THESE. SPEND THEM AT A SHOP, A SAGE OR AN INN."},
	# Counters
	"matches": {"name": "MATCHES", "kind": "matches", "icon": 17, "amount": 2,
		"desc": "A BOX OF 2. STRIKE ONE TO REFUEL YOUR LANTERN."},
	"loose_match": {"name": "MATCH", "kind": "matches", "icon": 17, "amount": 1,
		"desc": "A SINGLE MATCH."},
	"flare": {"name": "FLARE", "kind": "flare", "icon": 18, "amount": 1,
		"desc": "PLANT IT TO PUT A ROOM ON YOUR MAP."},
	# Keys (open any door of their color; used up when the door opens)
	"bronze_key": {"name": "BRONZE KEY", "kind": "key", "color": "bronze", "icon": 19,
		"desc": "OPENS ANY BRONZE DOOR. BREAKS IN THE LOCK."},
	"silver_key": {"name": "SILVER KEY", "kind": "key", "color": "silver", "icon": 20,
		"desc": "OPENS ANY SILVER DOOR. BREAKS IN THE LOCK."},
	"gold_key": {"name": "GOLD KEY", "kind": "key", "color": "gold", "icon": 21,
		"desc": "OPENS ANY GOLD DOOR. BREAKS IN THE LOCK."},
	"purple_key": {"name": "MASTER KEY", "kind": "key", "color": "purple", "icon": 22,
		"desc": "PURPLE AND COLD. IT OPENS THE MASTER CHAMBER."},
}

## What chests can hold, with weights (higher = more common).
const LOOT := [
	["matches", 8], ["flare", 8],
	["healing_tonic", 12], ["lamp_oil", 5], ["windbreak", 6], ["seers_draught", 6], ["bomb", 7],
	["red_berry", 9], ["blue_berry", 4], ["sunstone", 3],
	["bone_club", 6], ["hatchet", 5], ["hooked_sickle", 4], ["iron_mace", 3], ["grave_blade", 1],
	["leather_vest", 6], ["chain_shirt", 4], ["bone_mail", 3], ["iron_plate", 2],
	["brass_lantern", 3], ["storm_lantern", 2], ["witchglass_lantern", 1],
]

## What things cost in a village shop (rubies). Set against what an item
## does for you and how much ruby the labyrinth hands out (see Pickups and
## Chests: about 300 over a whole run, most of it deeper in), so a careful
## player can afford a better lantern or a fine weapon by the last village
## but never everything.
const PRICES := {
	"matches": 4, "flare": 6, "red_berry": 5, "blue_berry": 9, "lamp_oil": 8,
	"healing_tonic": 14, "windbreak": 10, "seers_draught": 12, "bomb": 18, "sunstone": 28,
	"brass_lantern": 35, "storm_lantern": 55, "witchglass_lantern": 85,
	"bone_club": 10, "hatchet": 24, "hooked_sickle": 24, "iron_mace": 42, "grave_blade": 70,
	"leather_vest": 10, "chain_shirt": 24, "bone_mail": 42, "iron_plate": 62,
}


static func price(stack: Dictionary) -> int:
	return int(PRICES.get(stack.id, 10)) + Items.bonus(stack) * 8


static func get_info(id: String) -> Dictionary:
	return DATA.get(id, {})


static func display_name(id: String) -> String:
	return DATA[id].name


static func kind(id: String) -> String:
	return DATA[id].kind


static func is_ruby(id: String) -> bool:
	return id == "ruby"


static func uses_slot(id: String) -> bool:
	return kind(id) in ["weapon", "armor", "potion", "key", "bomb"]


## Potions and keys of the same type stack (up to 3) in one slot.
static func stacks(id: String) -> bool:
	return kind(id) in ["potion", "key", "bomb"]


static func stat_line(id: String) -> String:
	var d: Dictionary = DATA[id]
	match d.kind:
		"weapon": return "WEAPON   ATK " + str(d.atk)
		"armor": return "ARMOR   DEF " + str(d.def)
		"potion": return "POTION"
		"key": return "KEY"
		"bomb": return "BOMB"
		"lantern": return "LANTERN"
		"ruby": return "MONEY"
	return ""


## An item stack's upgrade bonus (from a sprite), 0 if none.
static func bonus(stack: Dictionary) -> int:
	return int(stack.get("bonus", 0))


## Display name including any upgrade: "HATCHET +3".
static func label(stack: Dictionary) -> String:
	var b := bonus(stack)
	return display_name(stack.id) + (" +" + str(b) if b > 0 else "")


## ATK / DEF of this particular item, upgrades included.
static func power(stack: Dictionary) -> int:
	var d: Dictionary = DATA[stack.id]
	return int(d.get("atk", d.get("def", 0))) + bonus(stack)


## "ATK 7" / "DEF 5" for a stack (with upgrades), "" for anything else.
static func short_stat_of(stack: Dictionary) -> String:
	match kind(stack.id):
		"weapon": return "ATK " + str(power(stack))
		"armor": return "DEF " + str(power(stack))
	return ""


## Just the number that matters: "ATK 5", "DEF 4", or "" for potions.
static func short_stat(id: String) -> String:
	var d: Dictionary = DATA[id]
	match d.kind:
		"weapon": return "ATK " + str(d.atk)
		"armor": return "DEF " + str(d.def)
	return ""


## "A HATCHET", "AN IRON MACE", "2 HEALING TONICS"
static func with_article(id: String, qty: int = 1) -> String:
	var n := display_name(id)
	if qty > 1:
		return str(qty) + " " + n + "S"
	return ("AN " if n[0] in "AEIOU" else "A ") + n


## How good each piece of gear is: 0 early, 1 mid, 2 late. Deeper in the
## labyrinth, chests lean toward the better tiers.
const GEAR_TIER := {
	"rusty_dagger": 0, "bone_club": 0, "hatchet": 1, "hooked_sickle": 1, "iron_mace": 2, "grave_blade": 2,
	"worn_cloak": 0, "leather_vest": 0, "chain_shirt": 1, "bone_mail": 2, "iron_plate": 2,
	"brass_lantern": 1, "storm_lantern": 1, "witchglass_lantern": 2,
}


## A random find for a spot `progress` of the way through the labyrinth
## (0 = start, 1 = the master chamber). Returns a stack; deep gear may come
## already blessed (+1 to +4).
static func roll_stack(rng: RandomNumberGenerator, progress: float) -> Dictionary:
	var want := progress * 2.0
	var weights: Array[float] = []
	var total := 0.0
	for entry in LOOT:
		var wgt := float(entry[1])
		if GEAR_TIER.has(entry[0]):
			var t: int = GEAR_TIER[entry[0]]
			wgt *= exp(-pow(t - want, 2) / 0.9) * (1.0 + progress) * 2.0
		weights.append(wgt)
		total += wgt
	var r := rng.randf() * total
	var id: String = LOOT[LOOT.size() - 1][0]
	for i in LOOT.size():
		r -= weights[i]
		if r < 0.0:
			id = LOOT[i][0]
			break
	var stack := {"id": id, "qty": 1}
	if kind(id) in ["weapon", "armor"] and rng.randf() < progress * 0.7:
		stack["bonus"] = 1 + rng.randi_range(0, int(progress * 3.0))
	return stack


static func roll(rng: RandomNumberGenerator) -> String:
	var total := 0
	for entry in LOOT:
		total += entry[1]
	var r := rng.randi() % total
	for entry in LOOT:
		r -= entry[1]
		if r < 0:
			return entry[0]
	return "matches"


static func draw_icon(canvas: CanvasItem, id: String, rect: Rect2) -> void:
	canvas.draw_texture_rect_region(ICONS_TEX, rect, Rect2(DATA[id].icon * 16, 0, 16, 16))
