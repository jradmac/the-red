extends SceneTree
## Models the village buildings in 3D and renders them into assets/village.png
## (over the hand-drawn ones, same places, same sizes), one set per village
## style. Run after tools/make_village.py:
##
##   godot --path . -s tools/render3d/render_buildings.gd
##
## (Needs a display: on a headless machine run it under xvfb-run.)

const Kit := preload("res://tools/render3d/kit.gd")
const SHEET := "res://assets/village.png"
const BLOCK := 152

## Where each building goes in a style's block (matches Villages.R_BUILDING).
const SLOTS := [
	["shop", 0, Rect2i(0, 43, 80, 64)], ["sage", 0, Rect2i(80, 43, 64, 64)], ["inn", 0, Rect2i(144, 43, 96, 64)],
	["home", 0, Rect2i(240, 59, 64, 48)], ["home", 0, Rect2i(304, 59, 80, 48)],
	["home", 1, Rect2i(384, 59, 64, 48)], ["home", 1, Rect2i(448, 59, 80, 48)],
]

const STYLES := [
	{"wall": "timber", "wall_c": Color("d9c9a2"), "beam": Color("5a3a22"), "roof": "shingle", "roof_c": Color("4f6b3c"),
		"trim": Color("6a4426"), "base": Color("6e6458")},
	{"wall": "stone", "wall_c": Color("cfc6b4"), "mortar": Color("958c7a"), "roof": "shingle", "roof_c": Color("4d5f80"),
		"trim": Color("6a5a48"), "base": Color("8a8272")},
	{"wall": "stone", "wall_c": Color("8e887c"), "mortar": Color("5a564e"), "roof": "tile", "roof_c": Color("a3483a"),
		"trim": Color("4e3a2a"), "base": Color("5e5a52")},
	{"wall": "planks", "wall_c": Color("a07a50"), "beam": Color("5a3e26"), "roof": "thatch", "roof_c": Color("b48e4a"),
		"trim": Color("5a3e26"), "base": Color("6e6458")},
	{"wall": "planks", "wall_c": Color("5c5040"), "beam": Color("2e281e"), "roof": "thatch", "roof_c": Color("5c6a3c"),
		"trim": Color("2e281e"), "base": Color("3e3a30")},
]

const GLASS := Color("ffcf6a")
const FRAME := Color("3a2618")
const DOOR := Color("6a4024")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	sheet.convert(Image.FORMAT_RGBA8)
	for si in STYLES.size():
		for slot in SLOTS:
			var r: Rect2i = slot[2]
			var w := r.size.x / 16
			var d := r.size.y / 16
			var kit = Kit.new(self, w, d)
			_build(kit, slot[0], STYLES[si], slot[1], w, d)
			var img: Image = await kit.render(self)
			var at := Vector2i(r.position.x, r.position.y + si * BLOCK)
			sheet.fill_rect(Rect2i(at, r.size), Color(0, 0, 0, 0))
			sheet.blend_rect(img, Rect2i(Vector2i.ZERO, r.size), at)
			print("rendered ", slot[0], " ", w, "x", d, " style ", si)
	sheet.save_png(ProjectSettings.globalize_path(SHEET))
	print("wrote ", SHEET)
	quit()


# --- Building it ----------------------------------------------------------------------

func _wall_mat(kit, st: Dictionary) -> Material:
	match st.wall:
		"timber":
			return kit.mat(Color.WHITE, Kit.tex_plaster(st.wall_c, st.beam), Vector2(1, 1))
		"stone":
			return kit.mat(Color.WHITE, Kit.tex_bricks(st.wall_c, st.mortar), Vector2(1, 1))
	return kit.mat(Color.WHITE, Kit.tex_planks(st.wall_c), Vector2(1, 1))


func _roof_mat(kit, st: Dictionary) -> Material:
	match st.roof:
		"thatch":
			return kit.mat(Color.WHITE, Kit.tex_thatch(st.roof_c), Vector2(1, 1))
		"tile":
			return kit.mat(Color.WHITE, Kit.tex_shingles(st.roof_c, 3), Vector2(1, 1))
	return kit.mat(Color.WHITE, Kit.tex_shingles(st.roof_c, 4), Vector2(1, 1))


## A window on the front wall: frame, glowing glass, a sill (and shutters).
func _window(kit, x: float, y: float, wdt: float, hgt: float, st: Dictionary, shutters := false, box_flowers := false) -> void:
	kit.box(x - 0.05, y - 0.05, -0.03, wdt + 0.1, hgt + 0.1, 0.06, kit.mat(FRAME))
	kit.box(x, y, -0.05, wdt, hgt, 0.04, kit.mat(GLASS, null, Vector2.ONE, 0.6))
	kit.box(x + wdt / 2.0 - 0.025, y, -0.07, 0.05, hgt, 0.03, kit.mat(FRAME))
	kit.box(x, y + hgt / 2.0 - 0.025, -0.07, wdt, 0.05, 0.03, kit.mat(FRAME))
	kit.box(x - 0.08, y - 0.1, -0.12, wdt + 0.16, 0.06, 0.12, kit.mat(st.trim.lightened(0.15)))
	if shutters:
		for sx in [x - 0.22, x + wdt + 0.04]:
			kit.box(sx, y, -0.04, 0.18, hgt, 0.04, kit.mat(st.trim))
	if box_flowers:
		kit.box(x - 0.05, y - 0.22, -0.2, wdt + 0.1, 0.12, 0.16, kit.mat(Color("6a4024")))
		for k in 4:
			var col: Color = [Color("e05a6a"), Color("f5d05a"), Color("c87af0"), Color("e05a6a")][k]
			kit.sphere(x + 0.05 + k * (wdt / 3.5), y - 0.08, -0.13, 0.07, kit.mat(col))


func _door(kit, x: float, st: Dictionary, h := 0.95, color: Color = DOOR) -> void:
	kit.box(x - 0.08, 0.0, -0.04, 0.76, h + 0.1, 0.06, kit.mat(st.trim.darkened(0.2)))
	kit.box(x, 0.0, -0.06, 0.6, h, 0.04, kit.mat(color, Kit.tex_planks(color, true), Vector2(1, 1)))
	kit.box(x + 0.44, h * 0.45, -0.09, 0.07, 0.07, 0.03, kit.mat(Color("e8c060")))
	kit.box(x - 0.12, 0.0, -0.22, 0.84, 0.06, 0.2, kit.mat(st.base.lightened(0.1)))   # the step


## A ridge cap along the top of a gable roof, a shade darker than the roof.
func _ridge(kit, st: Dictionary, x0: float, x1: float, d0: float, d1: float, y_ridge: float) -> void:
	var dm := (d0 + d1) / 2.0
	kit.box(x0 - 0.02, y_ridge - 0.07, dm - 0.1, x1 - x0 + 0.04, 0.14, 0.2, kit.mat(st.roof_c.darkened(0.35)))


## Bushes and flowers hugging the front corners, so the house sits in the
## ground instead of on it.
func _shrubs(kit, w: int, variant: int) -> void:
	var leaf = kit.mat(Color("3f6b34"))
	var leaf2 = kit.mat(Color("557f3c"))
	for side in [0, 1]:
		var x := 0.32 if side == 0 else w - 0.32
		if (variant + side) % 3 == 2:
			continue
		kit.sphere(x, 0.2, -0.12, 0.3, leaf, 0.8)
		kit.sphere(x + (0.18 if side == 0 else -0.18), 0.32, -0.02, 0.22, leaf2, 0.85)
		if (variant + side) % 2 == 0:
			for k in 3:
				kit.sphere(x - 0.15 + k * 0.15, 0.4 + (k % 2) * 0.06, -0.3, 0.06, kit.mat([Color("e05a6a"), Color("f5d05a"), Color("f0f0f0")][(k + variant) % 3]))


func _chimney(kit, x: float, d: float, y0: float, h: float) -> void:
	kit.box(x, y0, d, 0.36, h, 0.36, kit.mat(Color.WHITE, Kit.tex_bricks(Color("7a6e62"), Color("4e463c"), 3, 6)))
	kit.box(x - 0.04, y0 + h, d - 0.04, 0.44, 0.08, 0.44, kit.mat(Color("5a5048")))


func _walls(kit, st: Dictionary, x0: float, x1: float, d0: float, d1: float, h: float) -> void:
	kit.box(x0, 0.0, d0, x1 - x0, h, d1 - d0, _wall_mat(kit, st))
	kit.box(x0 - 0.05, 0.0, d0 - 0.05, x1 - x0 + 0.1, 0.16, d1 - d0 + 0.1, kit.mat(Color.WHITE, Kit.tex_bricks(st.base, st.base.darkened(0.3), 4, 8)))
	if st.wall == "timber":
		var bm = kit.mat(st.beam)
		for bx in [x0 - 0.02, x1 - 0.1, (x0 + x1) / 2.0 - 0.05]:
			kit.box(bx, 0.0, d0 - 0.03, 0.12, h, 0.05, bm)
		kit.box(x0, h - 0.1, d0 - 0.03, x1 - x0, 0.1, 0.05, bm)
		kit.box(x0, h * 0.5, d0 - 0.03, x1 - x0, 0.08, 0.05, bm)
	elif st.wall == "planks":
		var bm2 = kit.mat(st.beam)
		for bx in [x0 - 0.04, x1 - 0.08]:
			kit.box(bx, 0.0, d0 - 0.04, 0.12, h, 0.12, bm2)


func _build(kit, kind: String, st: Dictionary, variant: int, w: int, d: int) -> void:
	var door_x := float(w / 2) + 0.2
	match kind:
		"home":
			if variant == 0:
				# a hipped roof: it slopes away on every side
				var hv := 1.45
				var db := minf(d - hv - 0.05, 1.15)
				_walls(kit, st, 0.22, w - 0.22, 0.06, db, hv)
				kit.hip(0.0, w, -0.1, db + 0.12, hv - 0.04, hv + 0.95, 1.0, _roof_mat(kit, st))
				_ridge(kit, st, 1.0, w - 1.0, -0.1, db + 0.12, hv + 0.95)
				_chimney(kit, w - 1.3, db * 0.35, hv + 0.2, 0.7)
			else:
				# the gable end faces the street
				var hv := 1.3
				var db := 0.85
				_walls(kit, st, 0.22, w - 0.22, 0.06, db, hv)
				kit.gable_d(0.0, w, -0.12, db + 0.1, hv - 0.04, hv + 0.78, _roof_mat(kit, st), _wall_mat(kit, st))
				kit.box(w / 2.0 - 0.06, hv + 0.62, -0.14, 0.12, 0.14, db + 0.24, kit.mat(st.roof_c.darkened(0.35)))
				# a round attic window up in the gable
				kit.box(w / 2.0 - 0.2, hv + 0.08, -0.02, 0.4, 0.34, 0.06, kit.mat(FRAME))
				kit.box(w / 2.0 - 0.14, hv + 0.13, -0.05, 0.28, 0.24, 0.04, kit.mat(GLASS, null, Vector2.ONE, 0.6))
				_chimney(kit, 0.55, db * 0.45, hv + 0.3, 0.6)
			_door(kit, door_x, st)
			_shrubs(kit, w, variant)
			for wx in range(0, w):
				if wx == w / 2:
					continue
				_window(kit, wx + 0.26, 0.55, 0.48, 0.5, st, variant == 0 and wx % 2 == 0, variant == 1)
		"shop":
			var hv := 1.8
			var db := minf(d - hv - 0.05, 1.4)
			_walls(kit, st, 0.12, w - 0.12, 0.06, db, hv)
			kit.hip(-0.06, w + 0.06, -0.1, db + 0.12, hv - 0.04, hv + 1.0, 1.3, _roof_mat(kit, st))
			_ridge(kit, st, 1.24, w - 1.24, -0.1, db + 0.12, hv + 1.0)
			_chimney(kit, 0.9, db * 0.4, hv + 0.25, 0.7)
			_door(kit, door_x, st, 1.05)
			for wx in range(0, w):
				if wx == w / 2:
					continue
				_window(kit, wx + 0.18, 0.45, 0.64, 0.7, st)
			# the striped awning, sloping out over the front
			var stripes := Image.create(16, 16, false, Image.FORMAT_RGBA8)
			for y in 16:
				for x in 16:
					stripes.set_pixel(x, y, Color("c0393f") if (x / 4) % 2 == 0 else Color("ece0c4"))
			var aw = kit.box(0.2, hv - 0.22, -0.42, w - 0.4, 0.06, 0.52, kit.mat(Color.WHITE, stripes, Vector2(w - 0.4, 1)))
			aw.rotation.x = deg_to_rad(-16)
			# a hanging sign with a red potion on it
			kit.box(w - 1.1, hv + 0.05, -0.3, 0.06, 0.06, 0.3, kit.mat(FRAME))
			kit.box(w - 1.35, hv - 0.55, -0.32, 0.6, 0.45, 0.05, kit.mat(Color("a87448")))
			kit.box(w - 1.12, hv - 0.45, -0.36, 0.16, 0.24, 0.04, kit.mat(Color("e04a5a")))
			# crates of goods by the door
			kit.box(door_x - 1.0, 0.0, -0.45, 0.42, 0.34, 0.34, kit.mat(Color.WHITE, Kit.tex_planks(Color("9a6a3e")), Vector2.ONE))
			kit.sphere(door_x - 0.9, 0.4, -0.3, 0.09, kit.mat(Color("e04a5a")))
			kit.sphere(door_x - 0.7, 0.4, -0.25, 0.09, kit.mat(Color("f5d05a")))
		"inn":
			var hv := 2.3
			var db := minf(d - hv - 0.05, 1.3)
			_walls(kit, st, 0.12, w - 0.12, 0.06, db, hv)
			kit.box(0.1, 1.12, -0.02, w - 0.2, 0.08, 0.08, kit.mat(st.trim))   # the floor line
			kit.hip(-0.08, w + 0.08, -0.12, db + 0.1, hv - 0.04, hv + 0.88, 1.0, _roof_mat(kit, st))
			_ridge(kit, st, 0.92, w - 0.92, -0.12, db + 0.1, hv + 0.88)
			# a cross gable over the door
			var gx0 := door_x - 0.85
			var gx1 := door_x + 1.45
			kit.gable_d(gx0, gx1, -0.2, db * 0.7, hv - 0.04, hv + 0.88, _roof_mat(kit, st), _wall_mat(kit, st))
			_chimney(kit, w - 1.2, db * 0.45, hv + 0.25, 0.6)
			_door(kit, door_x, st, 0.95)
			for wx in range(0, w):
				if wx == w / 2:
					_window(kit, wx + 0.28, 1.45, 0.44, 0.5, st)
					_window(kit, wx + 0.36, hv + 0.12, 0.3, 0.3, st)   # up in the gable
				else:
					_window(kit, wx + 0.28, 1.45, 0.44, 0.5, st, wx % 2 == 1)
					_window(kit, wx + 0.25, 0.4, 0.5, 0.48, st)
			_shrubs(kit, w, 2)
			# sign: a bed on a board
			kit.box(0.5, 1.05, -0.28, 0.06, 0.06, 0.3, kit.mat(FRAME))
			kit.box(0.25, 0.55, -0.32, 0.62, 0.42, 0.05, kit.mat(Color("a87448")))
			kit.box(0.32, 0.64, -0.36, 0.48, 0.1, 0.03, kit.mat(Color("e8dfc8")))
			kit.box(0.48, 0.7, -0.37, 0.3, 0.06, 0.03, kit.mat(Color("4d6fb0")))
		"sage":
			var r := 1.4
			var cx := w / 2.0
			var cd := r + 0.08
			var hv := 1.6
			var wm := _wall_mat(kit, st)
			kit.cylinder(cx, 0.0, cd, r, r, hv, wm, 20)
			kit.cylinder(cx, 0.0, cd, r + 0.06, r + 0.06, 0.16, kit.mat(st.base), 20)
			var roof: Material = kit.mat(Color.WHITE, Kit.tex_shingles(Color("5a3e8a"), 4), Vector2(3, 2))
			kit.cylinder(cx, hv - 0.06, cd, r + 0.18, 0.02, 0.85, roof, 20)
			kit.sphere(cx, hv + 0.84, cd, 0.1, kit.mat(Color("f5e08a"), null, Vector2.ONE, 0.8))
			# door and two round windows, glowing violet
			_door(kit, door_x - 0.2, st, 0.95, Color("4a3a6a"))
			for k in [-1, 1]:
				var wx: float = cx + k * 0.95 - 0.18
				kit.box(wx - 0.04, 0.5, 0.18, 0.44, 0.44, 0.06, kit.mat(FRAME))
				kit.box(wx, 0.54, 0.15, 0.36, 0.36, 0.05, kit.mat(Color("c8a8ff"), null, Vector2.ONE, 0.7))
			# a star on a banner, herbs in a pot
			kit.box(cx + 0.55, 0.85, -0.05, 0.36, 0.36, 0.05, kit.mat(Color("a87448")))
			kit.box(cx + 0.66, 0.96, -0.08, 0.14, 0.14, 0.03, kit.mat(Color("f5e08a"), null, Vector2.ONE, 0.4))
			kit.cylinder(0.55, 0.0, 0.2, 0.16, 0.14, 0.3, kit.mat(Color("8a4a32")))
			kit.sphere(0.55, 0.42, 0.2, 0.2, kit.mat(Color("5aa04a")))
