class_name SoundLife
extends RefCounted
## The sounds between the music and the action (main.gd calls update()):
##
##   your flame starving   a sputter now and then when the oil is nearly gone
##   it's coming           as your light runs low in the dark, the Wolf Man's
##                         screech, far off -- before it ever shows itself
##   the lands             each has its own life: drips, chains and moans in
##                         the crypts; owls and far howls in the woods at night,
##                         crows by day; bells tolling over the courtyards; the
##                         wind whistling round the peaks; water lapping by the
##                         river; frogs in the swamp -- more often, and darker,
##                         the deeper you are
##   creatures near you    insects chitter and demons growl before they reach you
## (The heart pounding at low health, and the Wolf Man's own screech, snarl and
## breathing as it comes, are in main.gd and longman.gd.)

var main: Node
var _rng := RandomNumberGenerator.new()
var _sputter := 3.0
var _dread := 8.0
var _accent := 6.0
var _creature := 3.0

## per rare land (these replace the land they're built on)
const RARE_ACCENTS := {
	World.R_BEACH: [["waves", true, true, 5], ["gull", false, true, 2], ["owl", true, false, 1]],
	World.R_JUNGLE: [["bird_call", false, true, 3], ["frog", true, true, 3], ["owl", true, false, 1], ["howl_far", true, false, 1]],
	World.R_SNOW: [["wind_whistle", true, true, 4], ["howl_far", true, false, 1]],
	World.R_VOLCANO: [["rumble", true, true, 3], ["lava_bubble", true, true, 4]],
	World.R_GOLD: [["chime", true, true, 4], ["coin", true, true, 1]],
}
## per land: [sound, by night?, by day?, chance weight]
const ACCENTS := {
	0: [["drip", true, true, 4], ["chains", true, false, 1], ["moan_far", true, false, 1]],
	1: [["owl", true, false, 3], ["howl_far", true, false, 1], ["crow", false, true, 2]],
	2: [["toll_far", true, false, 2], ["owl", true, false, 1], ["crow", false, true, 2]],
	3: [["wind_whistle", true, true, 3], ["howl_far", true, false, 1], ["crow", false, true, 1]],
	4: [["water_lap", true, true, 3], ["frog", true, false, 2], ["owl", true, false, 1]],
	5: [["frog", true, true, 4], ["moan_far", true, false, 1], ["drip", true, true, 1]],
}


func _init(m: Node) -> void:
	main = m
	_rng.randomize()


func update(delta: float) -> void:
	var p: Player = main.player
	if p == null or p.dead:
		return
	var world: World = main.world
	var day = main.day
	var night: bool = day.light < 0.5
	var in_village: bool = world.in_village(p.cell)
	var depth: float = world.progress.call(p.cell)
	for h in Hero.all:
		if h.battle.is_active() or h.transition.is_playing():
			return
	# the flame starving, and what it brings
	for h in Hero.all:
		if not h.alive():
			continue
		var l: Lantern = h.lantern
		var burning := l.state == Lantern.State.LIT and not l.daylight and not l.sheltered
		var f := l.fraction()
		if burning and f < 0.14:
			_sputter -= delta
			if _sputter <= 0.0:
				_sputter = _rng.randf_range(2.0, 4.5)
				Sfx.play("lantern_sputter", -5.0, 0.12)
		if night and not in_village and (not burning or f < 0.3):
			var lm = main.longmen.get(h)
			var waiting: bool = lm == null or lm.state in ["away", "watch", "retreat"]
			if waiting:
				_dread -= delta
				if _dread <= 0.0:
					_dread = _rng.randf_range(9.0, 18.0) * (0.6 if not burning else 1.0)
					Sfx.play("screech_far", _rng.randf_range(-9.0, -4.0), 0.1)
	# each land's own life
	if not in_village:
		_accent -= delta * lerpf(1.0, 1.6, depth)
		if _accent <= 0.0:
			_accent = _rng.randf_range(8.0, 20.0)
			var land := world.rare_at(p.cell)
			var list: Array = RARE_ACCENTS[land] if RARE_ACCENTS.has(land) else ACCENTS.get(world.biome_at(p.cell), [])
			if RARE_ACCENTS.has(land):
				_accent *= 0.6   # (the rare lands are busier: the sea, the lava, the jungle)
			var pool: Array = []
			var total := 0
			for a in list:
				if (night and a[1]) or (not night and a[2]):
					pool.append(a)
					total += int(a[3])
			if total > 0:
				var r := _rng.randi() % total
				for a in pool:
					r -= int(a[3])
					if r < 0:
						Sfx.play(String(a[0]), _rng.randf_range(-11.0, -6.0), 0.1)
						break
	# creatures close by, before they're on you
	_creature -= delta
	if _creature <= 0.0:
		_creature = _rng.randf_range(2.5, 6.0)
		var en = main.get("enemies")
		if en != null:
			var best: Enemy = null
			var bd := 7.0
			for e in en.list:
				if not is_instance_valid(e) or e.kind == "ghost":
					continue
				var d: float = (e.position - p.position).length() / World.TILE
				if d < bd:
					bd = d
					best = e
			if best != null:
				Sfx.play_at("chitter" if best.kind == "insect" else "growl", best.position, -3.0)
