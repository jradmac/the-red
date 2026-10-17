class_name RunStats
extends Node
## Keeps score of the current run for the victory and death screens.

var time := 0.0
var chests_opened := 0
var doors_opened := 0
var enemies_slain := 0
var matches_struck := 0
var flares_planted := 0
var damage_taken := 0
var running := true
var _last_health := 10
var _last_flares := -1
var _inventory: Inventory


func watch(lantern: Lantern, flares: Flares, chests: Chests, doors: Doors, inventory: Inventory) -> void:
	lantern.struck.connect(func(): matches_struck += 1)
	_last_flares = flares.count
	flares.count_changed.connect(_on_flares)
	chests.opened_first.connect(func(_c): chests_opened += 1)
	doors.opened.connect(func(_c): doors_opened += 1)
	_inventory = inventory
	_last_health = inventory.health
	inventory.changed.connect(_on_inventory_changed)


func _on_inventory_changed() -> void:
	if _inventory.health < _last_health:
		damage_taken += _last_health - _inventory.health
	_last_health = _inventory.health


func _on_flares(count: int) -> void:
	if _last_flares >= 0 and count < _last_flares:
		flares_planted += _last_flares - count
	_last_flares = count


func _process(delta: float) -> void:
	if running:
		time += delta


func time_text() -> String:
	var t := int(time)
	return "%d:%02d" % [t / 60, t % 60]


func lines() -> Array[String]:
	return [
		"TIME " + time_text(),
		"CHESTS OPENED " + str(chests_opened) + "    DOORS UNLOCKED " + str(doors_opened),
		"ENEMIES SLAIN " + str(enemies_slain) + "    DAMAGE TAKEN " + str(damage_taken),
		"MATCHES STRUCK " + str(matches_struck) + "    FLARES PLANTED " + str(flares_planted),
	]
