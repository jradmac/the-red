class_name UiKit
## Shared drawing for the full-screen menus (bag, chest): backdrop, framed
## panels with rivets and a title tab, glows, pedestals, bars.

const C_BG_TOP := Color("120d1c")
const C_BG_BOT := Color("06040a")
const C_PANEL := Color("17121f")
const C_PANEL_2 := Color("1d1727")
const C_EDGE := Color("5a5170")
const C_EDGE_HI := Color("a89ec0")
const C_EDGE_DK := Color("0a070f")
const C_RIVET := Color("c8a060")
const C_RIVET_DK := Color("6a5030")
const C_TAB := Color("2a2038")
const C_TEXT := Color("e8dfc8")
const C_DIM := Color("8a8299")
const C_PICK := Color("ffd35a")

const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


## Dark backdrop with a soft vertical gradient (dithered bands) and corner shade.
static func backdrop(c: CanvasItem, size: Vector2) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, size), C_BG_BOT)
	var bands := 12
	for i in bands:
		var t := float(i) / bands
		var col := C_BG_TOP.lerp(C_BG_BOT, t)
		c.draw_rect(Rect2(0, size.y * t * 0.8, size.x, size.y * 0.8 / bands + 1), col)


## A framed panel: dark outer line, light inner bevel, rivets in the corners and
## an optional title tab sitting on the top edge.
static func panel(c: CanvasItem, r: Rect2, title: String = "", active: bool = true) -> void:
	c.draw_rect(r.grow(1), C_EDGE_DK)
	c.draw_rect(r, C_EDGE if active else Color("3a3448"))
	c.draw_rect(r.grow(-1), C_PANEL)
	# subtle inner gradient: lighter top
	c.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, minf(10, r.size.y - 2))), C_PANEL_2)
	# bevel highlight on top / left
	c.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1)), Color(C_EDGE_HI, 0.35 if active else 0.12))
	c.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(1, r.size.y - 2)), Color(C_EDGE_HI, 0.2 if active else 0.08))
	for p in [r.position + Vector2(2, 2), Vector2(r.end.x - 4, r.position.y + 2),
			Vector2(r.position.x + 2, r.end.y - 4), r.end - Vector2(4, 4)]:
		c.draw_rect(Rect2(p, Vector2(2, 2)), C_RIVET_DK)
		c.draw_rect(Rect2(p, Vector2(1, 1)), C_RIVET)
	if title != "":
		var w := PixelFont.width_of(title) + 10
		var tab := Rect2(r.position + Vector2(8, -4), Vector2(w, 9))
		c.draw_rect(tab.grow(1), C_EDGE_DK)
		c.draw_rect(tab, C_EDGE if active else Color("3a3448"))
		c.draw_rect(tab.grow(-1), C_TAB)
		PixelFont.draw(c, tab.position + Vector2(5, 2), title, C_PICK if active else C_DIM)


## A soft round glow made of dithered rings (stays pixel-art).
static func glow(c: CanvasItem, center: Vector2, radius: float, col: Color, strength: float = 1.0) -> void:
	var rings := 6
	for i in rings:
		var f := 1.0 - float(i) / rings
		c.draw_circle(center, radius * f, Color(col, 0.06 * strength + 0.05 * strength * float(i) / rings))


## A stone pedestal ellipse for a figure to stand on.
static func pedestal(c: CanvasItem, center: Vector2, w: float, h: float) -> void:
	_ellipse(c, center + Vector2(0, 2), w + 2, h + 1, Color("0a070f"))
	_ellipse(c, center + Vector2(0, 1), w, h, Color("3a3448"))
	_ellipse(c, center, w, h, Color("5a5170"))
	_ellipse(c, center - Vector2(0, 1), w - 4, h - 2, Color("6e6584"))


static func _ellipse(c: CanvasItem, center: Vector2, rx: float, ry: float, col: Color) -> void:
	for y in range(-int(ry), int(ry) + 1):
		var half := rx * sqrt(maxf(0.0, 1.0 - float(y * y) / (ry * ry)))
		c.draw_rect(Rect2(roundf(center.x - half), center.y + y, roundf(half * 2), 1), col)


## A horizontal meter (fuel, health...).
static func bar(c: CanvasItem, r: Rect2, frac: float, col: Color) -> void:
	c.draw_rect(r.grow(1), C_EDGE_DK)
	c.draw_rect(r, Color("2a2236"))
	c.draw_rect(Rect2(r.position, Vector2(roundf(r.size.x * clampf(frac, 0.0, 1.0)), r.size.y)), col)
	c.draw_rect(Rect2(r.position, Vector2(roundf(r.size.x * clampf(frac, 0.0, 1.0)), 1)), col.lightened(0.35))


## A framed square for an item icon (slot).
static func icon_frame(c: CanvasItem, r: Rect2, picked: bool) -> void:
	c.draw_rect(r.grow(1), C_EDGE_DK)
	c.draw_rect(r, C_PICK if picked else C_EDGE)
	c.draw_rect(r.grow(-1), Color("0e0a14"))
	c.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1)), Color(1, 1, 1, 0.06))


## A small coloured label chip, e.g. "WORN".
static func chip(c: CanvasItem, pos: Vector2, text: String, col: Color) -> void:
	var r := Rect2(pos, Vector2(PixelFont.width_of(text) + 4, 7))
	c.draw_rect(r, Color(col, 0.25))
	c.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), col)
	PixelFont.draw(c, pos + Vector2(2, 1), text, col)
