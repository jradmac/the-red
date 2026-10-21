class_name MusicPick
extends RefCounted
## Which take of the music plays (tools/make_music_more.py made the extra ones).
##
## Each land has its day and night music in a few takes: the first one, a
## second take ("_b"), and a darker one for deep in the labyrinth ("_deep").
## How far in you are decides which takes are in play:
##   near the start     the first take and the second
##   halfway in         the second take and the deep one
##   deep               the deep one
## Staying put, it moves on to another of the takes every few minutes (each
## crossfades in where it last left off), so a long night isn't one song on
## repeat. Each fight picks its own battle music; deep fights get the darker ones.

const DIR := "res://assets/music/"
const ROTATE := 180.0          ## seconds before another take of the same music
const HALFWAY := 0.42          ## how far through the labyrinth (0..1) the second / deep takes start
const DEEP := 0.72             ## ...and only the deep ones
const BATTLES := ["battle", "battle_b", "battle_c"]
const DEEP_BATTLES := ["battle_deep", "battle_c"]

var _set := ""
var _cur := ""
var _t := 0.0
var _battle := ""
var _rng := RandomNumberGenerator.new()
static var _exists := {}


func _init() -> void:
	_rng.randomize()


static func has(track: String) -> bool:
	if not _exists.has(track):
		_exists[track] = ResourceLoader.exists(DIR + track + ".ogg")
	return _exists[track]


## The takes of `base` (e.g. "forest_night") that suit a spot `depth` of the way in.
static func takes(base: String, depth: float) -> Array[String]:
	var want: Array = [base, base + "_b"]
	if not has(base + "_deep"):
		pass   # (no deep take -- the villages: they stay as they are)
	elif depth >= DEEP:
		want = [base + "_deep"]
	elif depth >= HALFWAY:
		want = [base + "_b", base + "_deep"]
	var out: Array[String] = []
	for n in want:
		if has(n):
			out.append(n)
	if out.is_empty():
		out.append(base)
	return out


## The track to play now for a land's music `base` at `depth`.
func track(base: String, depth: float, delta: float) -> String:
	var list := takes(base, depth)
	var key := "|".join(list)
	if key != _set or not list.has(_cur):
		_set = key
		_cur = _pick(list, "")
		_t = 0.0
	else:
		_t += delta
		if _t > ROTATE and list.size() > 1:
			_cur = _pick(list, _cur)
			_t = 0.0
	return _cur


## The battle music: chosen when a fight starts, kept until it ends.
func battle(depth: float, starting: bool) -> String:
	if starting or _battle == "":
		var list: Array[String] = []
		for n in (DEEP_BATTLES if depth >= 0.6 else BATTLES):
			if has(n):
				list.append(n)
		_battle = _pick(list, _battle) if not list.is_empty() else "battle"
	return _battle


func _pick(list: Array[String], avoid: String) -> String:
	var options := list.filter(func(n): return n != avoid)
	if options.is_empty():
		options = list
	return options[_rng.randi() % options.size()]
