class_name GhostMirror
extends Node2D
## Ghosts glow above the darkness, so they live on a layer that belongs to
## player 1's screen. On player 2's half of a split screen this draws them
## again, from the same creatures (and the Longmen).

var enemies: Enemies


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if enemies == null:
		return
	for e in enemies.list:
		if e.kind == "ghost" and e.visible and is_instance_valid(e):
			e.paint(self, e.position)
	for lm in Longman.all:
		if is_instance_valid(lm) and lm.visible:
			lm.paint(self, lm.position)
