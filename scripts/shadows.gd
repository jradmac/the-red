class_name Shadows
## Soft, rounded contact shadows under anything standing on the ground.


## Draws an oval shadow centred at `center` (pixels), `w` pixels wide.
static var off := false   ## (set while painting sprites for the 3D view, which has its own shadows)


static func oval(ci: CanvasItem, center: Vector2, w: float, strength: float = 1.0) -> void:
	if off:
		return
	var x := center.x
	var y := center.y
	ci.draw_rect(Rect2(x - w / 2 + 2, y - 1, w - 4, 1), Color(0, 0, 0, 0.22 * strength))
	ci.draw_rect(Rect2(x - w / 2, y, w, 1), Color(0, 0, 0, 0.42 * strength))
	ci.draw_rect(Rect2(x - w / 2 + 1, y + 1, w - 2, 1), Color(0, 0, 0, 0.32 * strength))
	ci.draw_rect(Rect2(x - w / 2 + 3, y + 2, w - 6, 1), Color(0, 0, 0, 0.15 * strength))
