class_name EnemyEyes
extends Node2D
## Draws the glowing eyes of insects and demons standing in the dark, above
## the darkness layer. You can't see the creature, only that it's watching.

var enemies: Enemies


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if enemies == null or enemies.is_daytime():
		return
	for e in enemies.list:
		if not e.visible or e.kind == "ghost" or e.lit or not CreatureData.EYES.has(e.kind):
			continue
		if fmod(e._time, 4.0) > 3.85:
			continue   # blink
		for eye in CreatureData.EYES[e.kind][e.variant]:
			var p: Vector2 = eye[0]
			if e.facing_left:
				p.x = 15 - p.x
			draw_rect(Rect2(e.position + p, Vector2(1, 1)), eye[1])
