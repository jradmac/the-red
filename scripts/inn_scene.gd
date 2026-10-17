class_name InnScene
extends Node2D
## A night at the inn, as a little scene over the whole screen: a room with a
## bed for each player. You sit on the edge, swing your legs up and lie back,
## the blanket comes up, the candle goes out... Z z z ... then the sun comes
## through the window, you push the blanket off, sit up and climb out.
## main.gd turns the clock to morning at `night` and gives control back at `done`.

signal night     ## the screen is dark: now's the time to skip the clock
signal done      ## the scene is over

const LENGTH := 9.6
const T_NIGHT := 4.4     # all dark: the clock jumps
const BLANKET := Color("4d6fb0")
const BLANKET_DK := Color("34507e")

var heroes: Array = []
var _t := 0.0
var _night_sent := false
var _sounds := {}


func _process(delta: float) -> void:
	_t += delta
	if _t >= T_NIGHT and not _night_sent:
		_night_sent = true
		night.emit()
	_cue(1.0, "step_grass0")
	_cue(2.3, "rustle")
	_cue(3.1, "lantern_out")
	_cue(5.2, "morning")
	_cue(6.6, "rustle")
	_cue(7.6, "step_stone1")
	queue_redraw()
	if _t >= LENGTH:
		set_process(false)
		done.emit()


func _cue(at: float, sound: String) -> void:
	if _t >= at and not _sounds.has(at):
		_sounds[at] = true
		Sfx.play(sound, -4.0)


func _k(a: float, b: float) -> float:
	return clampf((_t - a) / (b - a), 0.0, 1.0)


func _draw() -> void:
	# drawn at a whole-number zoom, so the little room fills the screen
	var full := get_viewport_rect().size
	var z := maxf(1.0, floorf(minf(full.x / 170.0, full.y / 100.0)))
	scale = Vector2(z, z)
	var screen := full / z
	# how much of the scene shows (fades from the world in, and back out)
	var show := _k(0.0, 0.7) * (1.0 - _k(LENGTH - 0.7, LENGTH))
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, minf(1.0, show * 1.4)))
	if show <= 0.0:
		return
	# light in the room: candle at first, dark at night, sunlight in the morning
	var candle := 1.0 - _k(3.0, 3.4)
	var sun := _k(5.0, 6.2)
	var dark := clampf(1.0 - candle - sun, 0.0, 1.0)
	var room := Rect2((screen / 2.0 - Vector2(80, 46)).round(), Vector2(160, 92))
	var tint := Color(1, 1, 1).lerp(Color(0.35, 0.38, 0.6), dark * 0.85)
	tint = tint.lerp(Color(1.08, 1.0, 0.85), sun * 0.4)
	var a := show
	_room(room, tint, a, candle, sun)
	var n := maxi(heroes.size(), 1)
	for i in heroes.size():
		var bx := room.position.x + room.size.x * (float(i) + 0.5) / n
		_bed_and_hero(heroes[i], Vector2(roundf(bx), room.position.y + room.size.y - 18), tint, a, i)
	# deep night: everything but the Z z z goes black
	var black := _k(3.6, 4.2) * (1.0 - _k(4.8, 5.4))
	if black > 0.0:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, black * show))
	if _t > 2.8 and _t < 5.4:
		var za := minf(_k(2.8, 3.3), 1.0 - _k(5.0, 5.4)) * show
		for k in 3:
			var ph := fmod(_t * 0.5 + k / 3.0, 1.0)
			var p := screen / 2.0 + Vector2(-4 + ph * 10.0 + sin(ph * 6.0) * 2.0, -8 - ph * 18.0)
			PixelFont.draw(self, p.round(), "Z" if k % 2 == 0 else "z", Color(0.85, 0.85, 1.0, (1.0 - ph) * za))
	if _t > 6.0:
		var msg := "MORNING!"
		PixelFont.draw(self, Vector2(floorf((screen.x - PixelFont.width_of(msg)) / 2.0), room.position.y - 9), msg,
			Color(1.0, 0.88, 0.5, _k(6.0, 6.4) * show))


func _room(r: Rect2, tint: Color, a: float, candle: float, sun: float) -> void:
	var wall := Color("5a3a26") * tint
	var floor_c := Color("6e4a2c") * tint
	var fy := r.position.y + r.size.y * 0.55
	draw_rect(r.grow(3), Color(0.08, 0.05, 0.04, a))
	draw_rect(Rect2(r.position, Vector2(r.size.x, fy - r.position.y)), Color(wall, a))
	for x in range(int(r.position.x), int(r.end.x), 8):
		draw_rect(Rect2(x, r.position.y, 1, fy - r.position.y), Color(wall.darkened(0.25), a))
	draw_rect(Rect2(r.position.x, fy, r.size.x, r.end.y - fy), Color(floor_c, a))
	for y in range(int(fy) + 4, int(r.end.y), 5):
		draw_rect(Rect2(r.position.x, y, r.size.x, 1), Color(floor_c.darkened(0.2), a))
	# the window: night sky, then morning
	var win := Rect2(r.position.x + r.size.x / 2.0 - 13, r.position.y + 8, 26, 18)
	var sky := Color("1a2040").lerp(Color("ffd890"), sun)
	draw_rect(win.grow(2), Color(Color("3a2618") * tint, a))
	draw_rect(win, Color(sky, a))
	if sun < 0.5:
		for s in 6:
			var sp := win.position + Vector2(3 + (s * 13) % 21, 2 + (s * 7) % 14)
			draw_rect(Rect2(sp, Vector2(1, 1)), Color(1, 1, 0.9, a * (1.0 - sun * 2.0)))
	draw_rect(Rect2(win.position.x + 12, win.position.y, 2, win.size.y), Color(Color("3a2618") * tint, a))
	draw_rect(Rect2(win.position.x, win.position.y + 8, win.size.x, 2), Color(Color("3a2618") * tint, a))
	if sun > 0.0:   # a beam of morning light across the floor
		var pts := PackedVector2Array([win.position + Vector2(0, win.size.y), win.end,
			Vector2(win.end.x + 34, r.end.y), Vector2(win.position.x + 12, r.end.y)])
		draw_colored_polygon(pts, Color(1.0, 0.9, 0.6, 0.18 * sun * a))
	# a candle on a little table
	var tx := r.position.x + 8
	draw_rect(Rect2(tx, fy + 4, 10, 2), Color(Color("7a5232") * tint, a))
	draw_rect(Rect2(tx + 1, fy + 6, 1, 8), Color(Color("5a3a22") * tint, a))
	draw_rect(Rect2(tx + 8, fy + 6, 1, 8), Color(Color("5a3a22") * tint, a))
	draw_rect(Rect2(tx + 4, fy, 2, 4), Color(Color("e8dfc8") * tint, a))
	if candle > 0.0:
		var fl := roundf(sin(_t * 11.0) * 0.6)
		draw_rect(Rect2(tx + 4, fy - 2 - fl, 2, 2 + fl), Color(1.0, 0.8, 0.35, a * candle))
		draw_circle(Vector2(tx + 5, fy - 1), 9.0, Color(1.0, 0.75, 0.4, 0.08 * candle * a))


## One bed, and one hero getting in, sleeping, and getting out again.
func _bed_and_hero(h: Hero, foot: Vector2, tint: Color, a: float, i: int) -> void:
	var bed := Rect2(foot + Vector2(-20, -9), Vector2(44, 8))   # the mattress top, headboard on the left
	draw_rect(Rect2(bed.position + Vector2(-3, -8), Vector2(3, 22)), Color(Color("6a4024") * tint, a))   # headboard
	draw_rect(Rect2(bed.position + Vector2(-3, -8), Vector2(3, 1)), Color(Color("8a5a34") * tint, a))
	draw_rect(Rect2(bed.position + Vector2(bed.size.x, -2), Vector2(3, 16)), Color(Color("6a4024") * tint, a))   # foot
	draw_rect(Rect2(bed.position + Vector2(0, 8), Vector2(bed.size.x, 6)), Color(Color("7a5232") * tint, a))
	draw_rect(Rect2(bed.position + Vector2(0, 13), Vector2(bed.size.x, 1)), Color(Color("4a3020") * tint, a))
	draw_rect(Rect2(bed.position, Vector2(bed.size.x, 8)), Color(Color("e8dfc8") * tint, a))   # sheet
	draw_rect(Rect2(bed.position + Vector2(1, -3), Vector2(10, 5)), Color(Color("ffffff") * tint, a))   # pillow
	draw_rect(Rect2(bed.position + Vector2(1, 1), Vector2(10, 1)), Color(Color("c8c0b0") * tint, a))
	# the timeline (every player a beat apart)
	var o := float(i) * 0.25
	var sit_down := _k(0.8 + o, 1.4 + o)        # walk up and sit on the edge
	var legs_up := _k(1.5 + o, 2.1 + o)         # swing the legs onto the bed
	var lie := _k(1.9 + o, 2.6 + o)             # lie back
	var cover := _k(2.3 + o, 2.9 + o)           # blanket up
	var uncover := _k(6.3 + o, 6.8 + o)
	var sit_up := _k(6.6 + o, 7.2 + o)
	var legs_down := _k(7.1 + o, 7.6 + o)
	var stand := _k(7.6 + o, 8.1 + o)
	var up := 1.0 - lie + sit_up
	var legs := 1.0 - legs_up + legs_down
	# where the hip is: standing beside the bed, sitting on its edge, lying along it
	var stand_hip := foot + Vector2(-34, 7)
	var edge_hip := foot + Vector2(-4, -5)
	var lie_hip := foot + Vector2(1, -6)
	var hip := stand_hip.lerp(edge_hip, sit_down).lerp(lie_hip, legs_up)
	hip = hip.lerp(edge_hip, legs_down).lerp(stand_hip, stand)
	hip.y -= sin(sit_down * PI) * 4.0 + sin(stand * PI) * 4.0
	HeroLook.use(h.player)
	var mod_a := a
	HeroLook.draw_pose(self, hip.round(), clampf(up, 0.0, 1.0), clampf(legs, 0.0, 1.0), h.player.armor_id)
	# the blanket over whoever's lying there
	var c := clampf(cover - uncover, 0.0, 1.0)
	if c > 0.0:
		var bw := roundf((bed.size.x - 11) * c)
		var br := Rect2(bed.position + Vector2(bed.size.x - bw, -4), Vector2(bw, 12))
		draw_rect(br, Color(BLANKET * tint, mod_a))
		draw_rect(Rect2(br.position, Vector2(br.size.x, 2)), Color(BLANKET.lightened(0.25) * tint, mod_a))
		draw_rect(Rect2(br.position + Vector2(0, 9), Vector2(br.size.x, 3)), Color(BLANKET_DK * tint, mod_a))
		for k in range(int(br.position.x) + 4, int(br.end.x), 7):
			draw_rect(Rect2(k, br.position.y + 3, 1, 6), Color(BLANKET_DK * tint, mod_a))
	# the blanket folded at the foot when it's off
	else:
		draw_rect(Rect2(bed.position + Vector2(bed.size.x - 9, -1), Vector2(8, 10)), Color(BLANKET * tint, mod_a))
		draw_rect(Rect2(bed.position + Vector2(bed.size.x - 9, -1), Vector2(8, 2)), Color(BLANKET.lightened(0.25) * tint, mod_a))
