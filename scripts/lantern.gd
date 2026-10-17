class_name Lantern
extends Node
## The hero's lantern: the game's central resource.
##
## Fuel always drains (faster in wind). The light radius shrinks as fuel runs
## low, and the flame sputters near empty. Striking a match (E / gamepad R)
## adds fuel. When fuel hits zero the lantern goes OUT: you can keep walking
## in the dark, but the Longman comes for you (see longman.gd) until you strike
## a match or drink lamp oil.
##
## Milestone 4: new lanterns found in chests raise max_fuel and max_radius.

var pfx := ""   ## input action prefix: "" for player 1, "p2_" for player 2

signal went_out
signal relit
signal struck
signal denied(reason: String)

enum State { LIT, OUT }

## Tuning
## Light is a commodity from the first minute: you wake with the lantern part
## burned and two matches, about 2.5 minutes of light, with over 4 minutes of
## night before the first dawn -- you have to find matches to see it through.
## After that, loose matches are about one per 160 floor tiles, chests rarely
## hold matches or oil, and the long nights (with no more days past 80% of
## the way) do the rest. Villages sell matches and oil for rubies.
const BASE_DRAIN := 0.8      # fuel per second: a full lantern lasts ~2 minutes
const MATCH_FUEL := 26.0     # fuel added per match (~30 seconds of light)
const GUST_LEFT := 0.07      # a gust knocks the flame down to this much of the tank
const GHOSTS_GATHER := 0.25  # in the last quarter of the fuel, the Longman shows itself and watches
const BLUE_TIME := 60.0      # seconds a blue-berry flame lasts
const SUN_TIME := 120.0      # seconds a sunstone blazes
const SUN_RADIUS := 230.0    # px: past every corner of the screen
const MAX_MATCHES := 6       # the matchbox holds this many: no hoarding
const MIN_RADIUS := 20.0     # radius (pixels) right before it goes out
const START_MATCHES := 2      # (light is scarce from the very first night)
const START_FUEL := 75.0      # you wake with the lantern part burned: find matches before dawn

var max_fuel := 100.0
var max_radius := 84.0
var fuel := START_FUEL
var matches := START_MATCHES
var state := State.LIT
var drain_mult := 1.0        # set every frame by the wind
var sun_left := 0.0          # > 0: a sunstone blazes -- the whole screen is lit
var blue_left := 0.0         # > 0: burning blue, creatures flee the light
var strike_glow := 0.0       # 1 right after striking, fades to 0
var lantern_id := ""         # "" = the lantern you start with
var can_act: Callable = func() -> bool: return true   # false while menus are open
var paused := false          # battles burn fuel per round instead of per second
var sheltered := false       # inside a village: the lamps are lit, no fuel burns
var daylight := false        # in daylight the lantern is put away: no burning


func fraction() -> float:
	return fuel / max_fuel


## Current light radius in pixels (0 when out).
func radius() -> float:
	if state != State.LIT:
		return 0.0
	var r := lerpf(MIN_RADIUS, max_radius, pow(fraction(), 0.75)) + strike_glow * 18.0
	if sun_left > 0.0:   # swells in fast, shrinks back over the last 4 seconds
		r = lerpf(r, SUN_RADIUS, clampf(sun_left / 4.0, 0.0, 1.0))
	return r


## How much the flame wobbles: steady when full, sputtering when nearly empty.
func flicker() -> float:
	var low := clampf((0.2 - fraction()) / 0.2, 0.0, 1.0)
	return 0.05 + low * 0.22 + (drain_mult - 1.0) * 0.03


func _process(delta: float) -> void:
	strike_glow = move_toward(strike_glow, 0.0, delta * 1.5)
	if paused or daylight or sheltered:
		return
	if sun_left > 0.0:
		sun_left = maxf(sun_left - delta, 0.0)
		return   # no fuel burns while the sunstone blazes
	if state != State.LIT:
		blue_left = 0.0
	blue_left = maxf(blue_left - delta, 0.0)
	if state == State.LIT:
		fuel -= BASE_DRAIN * drain_mult * delta
		if fuel <= 0.0:
			fuel = 0.0
			state = State.OUT
			went_out.emit()
	if Input.is_action_just_pressed(pfx + "match") and can_act.call():
		strike()


## A gust of wind snuffs the flame (fuel stays; strike a match to relight).
func blow_out() -> void:
	if state != State.LIT or sun_left > 0.0 or lantern_id == "storm_lantern" or sheltered:
		return
	state = State.OUT
	went_out.emit()


## A gust of wind beats the flame down to a sputter (almost out). Returns
## true if it did anything.
func gust() -> bool:
	if state != State.LIT or sun_left > 0.0 or lantern_id == "storm_lantern" or sheltered:
		return false
	fuel = minf(fuel, max_fuel * GUST_LEFT)
	return true


## The flame is low enough that the Longman is watching (the name is from the ghosts it replaced).
func ghosts_gather() -> bool:
	return state == State.LIT and fraction() <= GHOSTS_GATHER and sun_left <= 0.0 and not sheltered and not daylight


## Adds fuel (lamp oil). Relights the lantern if it's out.
func refuel(amount: float) -> void:
	fuel = minf(fuel + amount, max_fuel)
	strike_glow = 1.0
	if state == State.OUT:
		state = State.LIT
		relit.emit()


## Swaps in a better lantern (from a chest) and fills it.
func upgrade(new_max_fuel: float, new_radius: float) -> void:
	max_fuel = new_max_fuel
	max_radius = new_radius
	refuel(max_fuel)


func room_for_matches() -> int:
	return maxi(0, MAX_MATCHES - matches)


## Adds up to n matches (the box only holds so many). Returns how many fit.
func add_matches(n: int) -> int:
	var k := mini(n, room_for_matches())
	matches += k
	return k


## A sunstone: the lantern (relit if it was out) blazes for SUN_TIME seconds.
func blaze() -> void:
	sun_left = SUN_TIME
	strike_glow = 1.0
	if state == State.OUT:
		state = State.LIT
		relit.emit()


func strike() -> bool:
	if matches <= 0:
		denied.emit("NO MATCHES")
		return false
	if state == State.LIT and fuel >= max_fuel - 2.0:
		denied.emit("LANTERN IS FULL")
		return false
	matches -= 1
	fuel = minf(fuel + MATCH_FUEL, max_fuel)
	strike_glow = 1.0
	struck.emit()
	if state == State.OUT:
		state = State.LIT
		relit.emit()
	return true
