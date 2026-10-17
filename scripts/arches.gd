class_name Arches
extends Node2D
## Stone archways where the crypts open onto the outdoors. Drawn above the
## hero so you walk *under* them: a clear "stepping outside" moment.

var world: World


func _ready() -> void:
	z_index = 3


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var v := world._visible_cells()
	for c in world.arches:
		if not v.has_point(c):
			continue
		var o := world.cell_to_position(c)
		if world.arches[c] == "front":
			draw_texture_rect_region(World.TALL_TEX, Rect2(o + Vector2(-16, -24), World.R_ARCH_FRONT.size), World.R_ARCH_FRONT)
		else:
			draw_texture_rect_region(World.TALL_TEX, Rect2(o + Vector2(0, -24), World.R_ARCH_SIDE.size), World.R_ARCH_SIDE)
