class_name PixelFont
extends RefCounted
## A tiny 3x5 pixel font for HUD text, drawn with rectangles so it stays
## perfectly crisp at the game's low resolution. Upper-case letters, digits,
## and a few symbols. Use: PixelFont.draw(canvas, pos, "TEXT", color)

const GLYPH_W := 3
const GLYPH_H := 5
const SPACING := 1

const GLYPHS := {
	"A": "010101111101101", "B": "110101110101110", "C": "011100100100011",
	"D": "110101101101110", "E": "111100110100111", "F": "111100110100100",
	"G": "011100101101011", "H": "101101111101101", "I": "111010010010111",
	"J": "001001001101010", "K": "101101110101101", "L": "100100100100111",
	"M": "101111111101101", "N": "110101101101101", "O": "010101101101010",
	"P": "110101110100100", "Q": "010101101110011", "R": "110101110101101",
	"S": "011100010001110", "T": "111010010010010", "U": "101101101101111",
	"V": "101101101101010", "W": "101101111111101", "X": "101101010101101",
	"Y": "101101010010010", "Z": "111001010100111",
	"0": "111101101101111", "1": "010110010010111", "2": "110001010100111",
	"3": "110001010001110", "4": "101101111001001", "5": "111100110001110",
	"6": "011100110101010", "7": "111001010010010", "8": "010101010101010",
	"9": "010101011001110",
	"*": "000101010101000", "-": "000000111000000", ".": "000000000000010",
	":": "000010000010000", "/": "001001010100100", "!": "010010010000010",
	"'": "010010000000000", ",": "000000000010100", "+": "000010111010000",
	"(": "010100100100010", ")": "010001001001010", "?": "110001010000010",
	">": "100010001010100", "%": "101001010100101", "_": "000000000000111",
	";": "000010000010100", "<": "001010100010001", "=": "000111000111000",
	" ": "000000000000000",
}


static func width_of(text: String) -> int:
	return maxi(text.length() * (GLYPH_W + SPACING) - SPACING, 0)


static func draw(canvas: CanvasItem, pos: Vector2, text: String, color: Color,
		shadow: Color = Color(0, 0, 0, 0)) -> void:
	if shadow.a > 0.0:
		_draw_raw(canvas, pos + Vector2.ONE, text, shadow)
	_draw_raw(canvas, pos, text, color)


static func _draw_raw(canvas: CanvasItem, pos: Vector2, text: String, color: Color) -> void:
	var x := pos.x
	for ch in text.to_upper():
		var g: String = GLYPHS.get(ch, GLYPHS[" "])
		for i in g.length():
			if g[i] == "1":
				canvas.draw_rect(Rect2(x + i % GLYPH_W, pos.y + i / GLYPH_W, 1, 1), color)
		x += GLYPH_W + SPACING
