class_name Sfx
extends Node
## Every sound in the game. Sounds are made by tools/make_sfx.py.
##
##   Sfx.play("hit")                    -- anywhere, any time
##   Sfx.play_at("ghost_strike", pos)   -- quieter the farther it is from you
##   Sfx.ambient("amb_night")           -- crossfades the background loop
##
##   Sfx.music("forest_day")           -- crossfades the music (assets/music)
##
## Volumes (sound effects, music) are set in the bag's SETTINGS and kept in
## user://settings.cfg. - and = also nudge the sound effects; N mutes music.

const DIR := "res://assets/sfx/"
## Per-sound loudness (dB). Anything not listed plays at 0.
const LEVEL := {
	"step_stone0": -16.0, "step_stone1": -16.0, "step_stone2": -16.0,
	"step_grass0": -17.0, "step_grass1": -17.0, "step_grass2": -17.0, "step_mud0": -15.0, "step_mud1": -15.0,
	"type": -20.0, "voice0": -9.0, "voice1": -9.0, "voice2": -9.0, "voice3": -9.0,
	"ui_move": -12.0, "ui_select": -9.0, "ui_back": -10.0, "ui_deny": -9.0, "page": -8.0,
	"encounter": -8.0, "pickup": -8.0, "pickup_match": -8.0, "fuse": -12.0, "heartbeat": -6.0,
	"insect": -6.0, "demon": -3.0, "whisper": -2.0, "bump": -12.0, "explosion": 1.0,
	"amb_night": -10.0, "amb_outdoor": -12.0, "amb_day": -13.0,
}
const POOL := 16
const MUSIC_DIR := "res://assets/music/"
const MUSIC_DB := -7.0
const MUSIC_FADE := 3.0

static var _inst: Sfx
var volume := 0.8          ## sound effects and backgrounds, 0..1
var music_volume := 0.7    ## music, 0..1
const SETTINGS := "user://settings.cfg"
var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _amb: Array[AudioStreamPlayer] = []
var _amb_name := ""
var _amb_cur := 0
var _fuse: AudioStreamPlayer
var _listener: Node2D       ## the hero (for play_at)
var _last_played := {}      ## name -> time, to stop the same sound stacking up
var music_on := true
var _mus: Array[AudioStreamPlayer] = []
var _mus_cur := 0
var _mus_name := ""
var _mus_pos := {}          ## track -> where it was, so coming back picks up there
var _mus_streams := {}


func _ready() -> void:
	_inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dir := DirAccess.open(DIR)
	if dir != null:
		for f in dir.get_files():
			var n := f.get_basename() if not f.ends_with(".import") else ""
			if f.ends_with(".import"):
				n = f.trim_suffix(".import").get_basename()
			if n != "" and not _streams.has(n):
				var s: Resource = load(DIR + n + ".wav")
				if s != null:
					_streams[n] = s
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for i in 2:
		var a := AudioStreamPlayer.new()
		add_child(a)
		a.volume_db = -80.0
		a.finished.connect(a.play)   # keep looping
		_amb.append(a)
	for i in 2:
		var m := AudioStreamPlayer.new()
		add_child(m)
		m.volume_db = -80.0
		m.finished.connect(m.play)
		_mus.append(m)
	_fuse = AudioStreamPlayer.new()
	add_child(_fuse)
	_fuse.stream = _streams.get("fuse")
	_fuse.finished.connect(func() -> void:
		if _fuse.get_meta("on", false):
			_fuse.play())
	_load_settings()
	_apply_volume()


func set_listener(n: Node2D) -> void:
	_listener = n


static func set_listener_static(n: Node2D) -> void:
	if _inst != null:
		_inst._listener = n


static func play(sound: String, db: float = 0.0, pitch_var: float = 0.04, pitch: float = 1.0) -> void:
	if _inst == null:
		return
	_inst._play(sound, db, pitch_var, pitch)


## A sound out in the world: fades with distance (silent past ~18 tiles).
static func play_at(sound: String, world_pos: Vector2, db: float = 0.0) -> void:
	if _inst == null:
		return
	var d := 0.0
	if _inst._listener != null:
		d = (world_pos - _inst._listener.global_position).length() / 16.0
	if d > 18.0:
		return
	_inst._play(sound, db - maxf(d - 3.0, 0.0) * 1.3, 0.06, 1.0)


static func ambient(sound: String) -> void:
	if _inst != null:
		_inst._ambient(sound)


static func music(track: String) -> void:
	if _inst != null:
		_inst._music(track)


func _music_stream(track: String) -> AudioStream:
	if not _mus_streams.has(track):
		var s: Resource = load(MUSIC_DIR + track + ".ogg") if ResourceLoader.exists(MUSIC_DIR + track + ".ogg") else null
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		_mus_streams[track] = s
	return _mus_streams[track]


func _music(track: String) -> void:
	if track == _mus_name:
		return
	var old := _mus[_mus_cur]
	if _mus_name != "" and old.playing:
		_mus_pos[_mus_name] = old.get_playback_position()
	_mus_name = track
	_mus_cur = 1 - _mus_cur
	var cur := _mus[_mus_cur]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(old, "volume_db", -80.0, MUSIC_FADE)
	tw.chain().tween_callback(old.stop)
	var s := _music_stream(track) if track != "" else null
	if s != null:
		cur.stream = s
		cur.volume_db = -50.0
		cur.play(float(_mus_pos.get(track, 0.0)))
		var tw2 := create_tween()
		tw2.tween_property(cur, "volume_db", _music_db(), MUSIC_FADE)


func _music_db() -> float:
	if not music_on or music_volume <= 0.001:
		return -80.0
	return MUSIC_DB + linear_to_db(music_volume)


static func get_volumes() -> Vector2:
	return Vector2(_inst.volume, _inst.music_volume) if _inst != null else Vector2(0.8, 0.7)


## Sets the two volumes (0..1), applies them and remembers them.
static func set_volumes(sfx_vol: float, music_vol: float) -> void:
	if _inst == null:
		return
	_inst.volume = clampf(sfx_vol, 0.0, 1.0)
	_inst.music_volume = clampf(music_vol, 0.0, 1.0)
	_inst.music_on = true
	_inst._apply_volume()
	_inst._save_settings()


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) == OK:
		volume = float(cf.get_value("audio", "sfx", volume))
		music_volume = float(cf.get_value("audio", "music", music_volume))


func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "sfx", volume)
	cf.set_value("audio", "music", music_volume)
	cf.save(SETTINGS)


static func fuse(on: bool) -> void:
	if _inst == null or _inst._fuse.stream == null:
		return
	if on == _inst._fuse.get_meta("on", false):
		return
	_inst._fuse.set_meta("on", on)
	if on:
		_inst._fuse.volume_db = LEVEL.get("fuse", 0.0) + _inst._master_db()
		_inst._fuse.play()
	else:
		_inst._fuse.stop()


func _master_db() -> float:
	return linear_to_db(maxf(volume, 0.0001))


func _play(sound: String, db: float, pitch_var: float, pitch: float) -> void:
	var s: AudioStream = _streams.get(sound)
	if s == null or volume <= 0.0:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < 35:
		return   # the same sound twice in one instant: once is enough
	_last_played[sound] = now
	var p := _pool[_next]
	_next = (_next + 1) % POOL
	p.stream = s
	p.volume_db = LEVEL.get(sound, 0.0) + db + _master_db()
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_var, pitch_var))
	p.play()


func _ambient(sound: String) -> void:
	if sound == _amb_name:
		return
	_amb_name = sound
	var old := _amb[_amb_cur]
	_amb_cur = 1 - _amb_cur
	var cur := _amb[_amb_cur]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(old, "volume_db", -80.0, 2.5)
	if sound != "" and _streams.has(sound):
		cur.stream = _streams[sound]
		cur.volume_db = -60.0
		cur.play(randf() * 6.0)
		tw.tween_property(cur, "volume_db", LEVEL.get(sound, 0.0) + _master_db(), 2.5)


func _apply_volume() -> void:
	if _mus_name != "":
		_mus[_mus_cur].volume_db = _music_db()
	if _amb_name != "" and _amb[_amb_cur].playing:
		_amb[_amb_cur].volume_db = LEVEL.get(_amb_name, 0.0) + _master_db()
	if _fuse.playing:
		_fuse.volume_db = LEVEL.get("fuse", 0.0) + _master_db()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_N:
			music_on = not music_on
			_apply_volume()
			var h: Variant = get_tree().current_scene.get("hud")
			if h != null and h.has_method("say"):
				h.say("MUSIC ON" if music_on else "MUSIC OFF")
			return
		if k == KEY_MINUS or k == KEY_EQUAL or k == KEY_KP_SUBTRACT or k == KEY_KP_ADD:
			volume = clampf(volume + (0.1 if k == KEY_EQUAL or k == KEY_KP_ADD else -0.1), 0.0, 1.0)
			_apply_volume()
			_save_settings()
			_play("ui_move", 0.0, 0.0, 1.0)
			var hud: Variant = get_tree().current_scene.get("hud")
			if hud != null and hud.has_method("say"):
				hud.say("SOUND EFFECTS " + str(int(round(volume * 100))) + "%")
