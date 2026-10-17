class_name Mist
extends Node2D
## Drifting fog over the wilder landscapes: thick green murk in swamps, pale
## mist along rivers, wisps in forests and mountains. It sits under the
## darkness overlay, so it glows where your lantern light falls on it.

const DENSITY := {1: 0.45, 3: 0.35, 4: 0.9, 5: 1.3}   # biome -> how thick
const COLORS := {1: Color(0.8, 0.85, 0.9), 3: Color(0.85, 0.85, 0.9), 4: Color(0.75, 0.85, 0.95), 5: Color(0.6, 0.8, 0.5)}
const STEP := 3   # tiles between fog puffs

var world: World
var _time := 0.0


func _ready() -> void:
	z_index = 4


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if world == null or world.width == 0:
		return
	var v := world.fx_cells().grow(STEP)
	var x0 := (v.position.x / STEP) * STEP
	var y0 := (v.position.y / STEP) * STEP
	for gy in range(y0, v.end.y, STEP):
		for gx in range(x0, v.end.x, STEP):
			var b := world.biome_at(Vector2i(gx, gy))
			if not DENSITY.has(b):
				continue
			var h := world._hash(gx, gy, 31)
			var dens: float = DENSITY[b]
			if (h % 100) / 100.0 > 0.55 * dens + 0.2:
				continue
			# each puff drifts slowly sideways and breathes
			var drift := Vector2(fmod(_time * (3.0 + h % 4) + h % 97, 48.0) - 24.0, sin(_time * 0.4 + h) * 4.0)
			var p := Vector2(gx * World.TILE + 8, gy * World.TILE + 8) + drift
			var r := 18.0 + (h % 13) + sin(_time * 0.6 + h * 0.1) * 3.0
			var col: Color = COLORS[b]
			var a := 0.085 * dens
			draw_circle(p, r, Color(col, a))
			draw_circle(p + Vector2(r * 0.4, -r * 0.2), r * 0.7, Color(col, a))
			draw_circle(p - Vector2(r * 0.5, -r * 0.1), r * 0.55, Color(col, a * 1.2))
