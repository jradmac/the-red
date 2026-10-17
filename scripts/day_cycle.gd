class_name DayCycle
extends Node
## The clock. Most of the time it's night (your lantern matters, demons and
## the Longman are out). For a few minutes each cycle the sun comes up: the whole
## screen is lit, the lantern is put away (no fuel burns), and demons and
## the Longman are gone -- only insects remain. Use the daylight to explore!
## Once you've pushed 80% of the way through the labyrinth, the sun never
## rises again.

signal dawn         ## the sun is coming up
signal dusk         ## night is falling
signal eternal      ## no more days

const NIGHT := 900.0        # seconds of night per cycle (15 min)
const DAY := 300.0          # seconds of day per cycle (5 min)
const FADE := 25.0          # sunrise / sunset length
const START_AT := 640.0     # the first run begins ~4.5 minutes before dawn
const NO_MORE_DAYS_AT := 0.8   # progress through the labyrinth

var t := START_AT
var light := 0.0            ## 0 = night .. 1 = full day (smooth)
var forever_night := false
var _was_day := false


func cycle_pos() -> float:
	return fmod(t, NIGHT + DAY)


func is_day() -> bool:
	return light > 0.5


## 0..1 how warm (orange) the light is right now: strongest mid sunrise / sunset.
func warmth() -> float:
	return clampf(1.0 - absf(light - 0.5) * 2.0, 0.0, 1.0)


## Seconds until the next change (dawn or dusk). -1 when night is forever.
func time_left() -> float:
	if forever_night and not is_day():
		return -1.0
	var p := cycle_pos()
	return (NIGHT - p) if p < NIGHT else (NIGHT + DAY - p)


## Called by main as you go deeper: past 80%, no more days.
func note_progress(p: float) -> void:
	if forever_night or p < NO_MORE_DAYS_AT:
		return
	forever_night = true
	eternal.emit()
	if cycle_pos() >= NIGHT:   # it's day: start the sunset now
		t = floorf(t / (NIGHT + DAY)) * (NIGHT + DAY) + NIGHT + DAY - FADE
		if t < 0.0:
			t = 0.0


func _process(delta: float) -> void:
	t += delta
	var p := cycle_pos()
	var target := 0.0
	if p >= NIGHT:
		target = clampf((p - NIGHT) / FADE, 0.0, 1.0) * clampf((NIGHT + DAY - p) / FADE, 0.0, 1.0)
	if forever_night and p < NIGHT:
		target = 0.0
	if forever_night and p >= NIGHT + DAY - FADE:
		pass
	elif forever_night and p >= NIGHT and light <= 0.0:
		# skip the day entirely: jump to the next night
		t += (NIGHT + DAY) - p
		target = 0.0
	light = target
	var day := is_day()
	if day != _was_day:
		_was_day = day
		if day:
			dawn.emit()
		else:
			dusk.emit()
