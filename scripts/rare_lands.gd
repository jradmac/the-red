class_name RareLands
extends Node
## The rare lands in play (labyrinth.gd makes them; world.gd keeps where they
## are; rare3d.gd draws them):
##   - the first time you set foot in one, it's announced: a rare land, or the
##     gold vault -- a legendary find;
##   - lava flows burn whoever stands in them (a heart, and again every second
##     you stay);
##   - the gold vault is strewn with rubies, and no creature goes in.

const BURN_EVERY := 0.9
const VAULT_RUBIES := 0.11        ## of the vault's floor tiles, this many have rubies on them
const TITLES := {
	World.R_BEACH: ["A RARE LAND", Color("9fe3ff")],
	World.R_JUNGLE: ["A RARE LAND", Color("8ff0a0")],
	World.R_SNOW: ["A RARE LAND", Color("e6f2ff")],
	World.R_VOLCANO: ["A RARE LAND", Color("ffa070")],
	World.R_GOLD: ["A LEGENDARY LAND -- FEW HAVE EVER SEEN IT", Color("ffe27a")],
}

var main: Node
var world: World
var _burn := {}        ## hero -> seconds until the lava burns them again
var _seen := {}        ## zone -> announced already


func setup(m: Node, fresh: bool) -> void:
	main = m
	world = m.world
	if fresh:
		_scatter_rubies()


## The vault's rubies (only in a new game: a saved one keeps what's left).
func _scatter_rubies() -> void:
	var pk: Pickups = main.pickups
	if pk == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed_value * 31 + 5
	for zi in world.zones.size():
		if world.zone_rare[zi] != World.R_GOLD:
			continue
		var r: Rect2i = world.zones[zi]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if world.is_walkable(c) and not pk.ground.has(c) and not world.doors.has(c) and c != world.start_cell \
						and rng.randf() < VAULT_RUBIES:
					pk.ground[c] = {"id": "ruby", "qty": rng.randi_range(1, 4)}


func _process(delta: float) -> void:
	if world == null:
		return
	for h in Hero.all:
		if not h.alive():
			continue
		var pl: Player = h.player
		# the first steps into a rare land
		var zi := world.zone_at(pl.cell)
		if zi >= 0 and zi < world.zone_rare.size() and world.zone_rare[zi] != World.R_NONE and not _seen.has(zi):
			_seen[zi] = true
			var t: Array = TITLES[world.zone_rare[zi]]
			h.hud.announce(world.zone_names[zi], t[0], t[1])
			Sfx.play("sage", -4.0) if world.zone_rare[zi] != World.R_GOLD else Sfx.play("buy", -2.0)
		# lava
		if world.lava.has(pl.cell) and not pl.climbing and not h.battle.is_active():
			var left: float = _burn.get(h, 0.0) - delta
			if left <= 0.0:
				left = BURN_EVERY
				Sfx.play("sizzle", 0.0, 0.08)
				main._on_trap(h, "THE LAVA BURNS YOU!", 1)
			_burn[h] = left
		else:
			_burn[h] = 0.0
