class_name CoopView
extends Node
## The two-player screen.
##
## Each player gets their own camera (a SubViewport looking at the same
## world) with its own darkness, glowing eyes and ghosts. While the two of
## you are close, both cameras sit at the point between you and the screen
## looks exactly like one view. Walk apart and the cameras separate: the
## screen splits along a line at right angles to the line between you, so
## each of you stays in the middle of your own side, and it closes up again
## as you come back together.
##
## The whole screen doubles in co-op (720 x 480), so each player's world view
## is drawn at 2x exactly as before, and each player's HUD and menus (bag,
## battle, chests...) are shown crisp on their own half: player 1 on the
## left, player 2 on the right. When one of you is in a battle or a menu the
## screen splits straight down the middle so the other can keep playing.

const VIEW := Vector2i(360, 240)     # one player's view (game pixels)
const SCREEN := Vector2i(720, 480)   # the screen in co-op
const HALF := Vector2i(360, 480)
const SPLIT_SHADER := preload("res://shaders/split.gdshader")

var main: Node
var active := false
var shake := Vector2.ZERO
var _world_svs: Array[SubViewport] = []
var _cams: Array[Camera2D] = []
var _hud_svs: Array[SubViewport] = []
var _menu_svs: Array[SubViewport] = []
var _view2: Lighting
var _eyes2: CanvasLayer
var _layer: CanvasLayer
var _mat: ShaderMaterial
var _split := 0.0
var _heroes: Array = []


func setup(m: Node) -> void:
	main = m


func start() -> void:
	if active:
		return
	active = true
	_heroes = Hero.all.duplicate()
	get_window().content_scale_size = SCREEN
	var world_2d: World2D = main.get_viewport().world_2d
	for i in 2:
		var h: Hero = _heroes[i]
		# the world, through this player's camera
		var sv := SubViewport.new()
		sv.size = VIEW
		sv.world_2d = world_2d
		sv.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(sv)
		var cam := Camera2D.new()
		sv.add_child(cam)
		cam.make_current()
		_world_svs.append(sv)
		_cams.append(cam)
		if i == 0:
			main.lighting.reparent(sv, false)
			main._eyes_layer.reparent(sv, false)
		else:
			_view2 = Lighting.new()
			_view2.source = main.lighting
			sv.add_child(_view2)
			_view2.process_mode = Node.PROCESS_MODE_ALWAYS
			main.lighting.views.append(_view2)
			_eyes2 = CanvasLayer.new()
			_eyes2.layer = 2
			_eyes2.follow_viewport_enabled = true
			sv.add_child(_eyes2)
			var ee := EnemyEyes.new()
			ee.enemies = main.enemies
			_eyes2.add_child(ee)
			var gm := GhostMirror.new()
			gm.enemies = main.enemies
			_eyes2.add_child(gm)
			h.eyes.reparent(_eyes2, false)
		# their HUD (a tall half-screen) and their menus (the usual 360 x 240)
		var hud_sv := _ui_viewport(HALF)
		h.hud.reparent(hud_sv, false)
		_hud_svs.append(hud_sv)
		var menu_sv := _ui_viewport(VIEW)
		for l in h.ui_layers:
			if l != h.hud:
				l.reparent(menu_sv, false)
		_menu_svs.append(menu_sv)
	# put it all on screen
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	var rect := ColorRect.new()
	rect.size = Vector2(SCREEN)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SPLIT_SHADER
	_mat.set_shader_parameter("view1", _world_svs[0].get_texture())
	_mat.set_shader_parameter("view2", _world_svs[1].get_texture())
	rect.material = _mat
	_layer.add_child(rect)
	for i in 2:
		var x := float(i * HALF.x)
		_layer.add_child(_tex_rect(_hud_svs[i], Vector2(x, 0), Vector2(HALF)))
		_layer.add_child(_tex_rect(_menu_svs[i], Vector2(x, (HALF.y - VIEW.y) / 2.0), Vector2(VIEW)))
	# the 3D world: one camera for each of you
	if main.view3d != null:
		main.view3d.attach_coop(_world_svs, [_view2, _eyes2])
	_process(0.0)


func _ui_viewport(size: Vector2i) -> SubViewport:
	var sv := SubViewport.new()
	sv.size = size
	sv.transparent_bg = true
	sv.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	return sv


func _tex_rect(sv: SubViewport, pos: Vector2, size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = sv.get_texture()
	r.position = pos
	r.size = size
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Back to one screen (a player left). Everything moves back where it was.
func stop() -> void:
	if not active:
		return
	active = false
	if main.view3d != null:
		main.view3d.detach_coop()
	main.lighting.reparent(main, false)
	main._eyes_layer.reparent(main, false)
	for h in _heroes:
		if is_instance_valid(h.eyes) and h.eyes.get_parent() != main._eyes_layer:
			h.eyes.reparent(main._eyes_layer, false)
		for l in h.ui_layers:
			if is_instance_valid(l):
				l.reparent(main, false)
	if is_instance_valid(_view2):
		main.lighting.views.erase(_view2)
	for sv in _world_svs + _hud_svs + _menu_svs:
		sv.queue_free()
	_world_svs.clear()
	_cams.clear()
	_hud_svs.clear()
	_menu_svs.clear()
	if _layer != null:
		_layer.queue_free()
		_layer = null
	_heroes.clear()
	get_window().content_scale_size = VIEW
	main.camera.make_current()


func _process(_delta: float) -> void:
	if not active or _heroes.size() < 2:
		return
	var h1: Hero = _heroes[0]
	var h2: Hero = _heroes[1]
	if not is_instance_valid(h1.player) or not is_instance_valid(h2.player):
		return
	var p1: Vector2 = h1.player.position + Vector2(8, 8)
	var p2: Vector2 = h2.player.position + Vector2(8, 8)
	var half := Vector2(VIEW) / 2.0
	var m1 := h1.in_menu()
	var m2 := h2.in_menu()
	var c1: Vector2
	var c2: Vector2
	if m1 or m2:
		# someone's in a menu: straight down the middle, each of you centered on your half
		c1 = p1 + Vector2(half.x / 2.0, 0)
		c2 = p2 - Vector2(half.x / 2.0, 0)
		_split = 1.0
		_mat.set_shader_parameter("forced", true)
		_mat.set_shader_parameter("dir", Vector2.RIGHT)
	else:
		var d := p2 - p1
		var dist := d.length()
		var dir := d / dist if dist > 0.01 else Vector2.RIGHT
		# how far it is from the middle of the screen to its edge, this way
		var edge := 1.0 / sqrt(pow(dir.x / half.x, 2) + pow(dir.y / half.y, 2))
		if dist <= edge:
			c1 = (p1 + p2) / 2.0
			c2 = c1
		else:
			c1 = p1 + dir * edge / 2.0
			c2 = p2 - dir * edge / 2.0
		_split = clampf((dist - edge) / 10.0, 0.0, 1.0)
		_mat.set_shader_parameter("forced", false)
		_mat.set_shader_parameter("dir", dir)
	_cams[0].position = (c1 + shake).round()
	_cams[1].position = (c2 + shake).round()
	_mat.set_shader_parameter("split", _split)
	if main.view3d != null:
		main.view3d.coop_centers = [c1, c2]
	_mat.set_shader_parameter("black1", m1)
	_mat.set_shader_parameter("black2", m2)
	# each half gets its own sunstone daylight
	if is_instance_valid(_view2):
		_view2.sun_glow = main._sun_of(h2)
