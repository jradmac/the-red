class_name Controls
## The input map, built in code. Player 1's actions have plain names
## ("confirm"); player 2's are the same names with "p2_" in front.
##
##   Solo:          arrows or WASD, Z/X/E/F/I/M/B/G, or any controller.
##   Two players:   P1 = WASD + Z X E F I M B G T (+ a controller)
##                  P2 = arrows + Enter (act, hold to sprint), / or Backspace
##                       (back), . (match), , (flare), ; (bag), L (map),
##                       ' (bomb), P (guide), J (trade)
##                       -- or their own controller.

const ACTIONS := ["move_up", "move_down", "move_left", "move_right", "run", "sprint", "confirm", "map", "mark",
	"match", "inventory", "restart", "guide", "bomb", "trade"]

const P1_KEYS := {
	"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT], "run": [KEY_X], "sprint": [KEY_Z, KEY_SHIFT], "confirm": [KEY_Z, KEY_ENTER],
	"map": [KEY_M, KEY_TAB], "mark": [KEY_F, KEY_C], "match": [KEY_E, KEY_Q], "inventory": [KEY_I],
	"restart": [KEY_R], "guide": [KEY_G, KEY_H], "bomb": [KEY_B], "trade": [KEY_T],
}
## Keys player 1 gives up when player 2 shares the keyboard.
const P2_TAKES := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER]
const P2_KEYS := {
	"move_up": [KEY_UP], "move_down": [KEY_DOWN], "move_left": [KEY_LEFT], "move_right": [KEY_RIGHT],
	"run": [KEY_SLASH, KEY_BACKSPACE], "sprint": [KEY_ENTER, KEY_KP_ENTER], "confirm": [KEY_ENTER, KEY_KP_ENTER],
	"map": [KEY_L], "mark": [KEY_COMMA], "match": [KEY_PERIOD], "inventory": [KEY_SEMICOLON],
	"restart": [], "guide": [KEY_P], "bomb": [KEY_APOSTROPHE], "trade": [KEY_J],
}
const PAD := {
	"move_up": JOY_BUTTON_DPAD_UP, "move_down": JOY_BUTTON_DPAD_DOWN, "move_left": JOY_BUTTON_DPAD_LEFT,
	"move_right": JOY_BUTTON_DPAD_RIGHT, "run": JOY_BUTTON_B, "sprint": JOY_BUTTON_B, "confirm": JOY_BUTTON_A,
	"map": JOY_BUTTON_BACK, "mark": JOY_BUTTON_LEFT_SHOULDER, "match": JOY_BUTTON_RIGHT_SHOULDER,
	"inventory": JOY_BUTTON_START, "trade": JOY_BUTTON_X,
}
const STICK := {"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0]}


## Solo: player 1 gets every key and every controller.
static func setup_solo(pfx: String = "") -> void:
	_build(pfx, P1_KEYS if pfx == "" else P2_KEYS, [], -1)


## Two players. `p2_pad` is player 2's controller (-1 = they use the keyboard).
static func setup_coop(p1_pfx: String, p2_pfx: String, p1_pad: int, p2_pad: int) -> void:
	var keyboard_shared := p2_pad < 0
	var k1: Dictionary = P1_KEYS if p1_pfx == "" else P2_KEYS
	_build(p1_pfx, k1, P2_TAKES if keyboard_shared and p1_pfx == "" else [], p1_pad)
	var k2: Dictionary = P2_KEYS if p2_pfx == "p2_" else P1_KEYS
	_build(p2_pfx, k2 if keyboard_shared else {}, [], p2_pad if p2_pad >= 0 else -2)


## (Re)builds one player's actions. pad: -1 any controller, -2 none, else that device.
static func _build(pfx: String, keys: Dictionary, without: Array, pad: int) -> void:
	for a in ACTIONS:
		var name: String = pfx + a
		if InputMap.has_action(name):
			InputMap.action_erase_events(name)
			# Forget any button still held under the old mapping: otherwise the
			# Start that made player 2 join stays "held" for player 1 forever
			# (its release no longer matches), and player 1's Start stops working.
			Input.action_release(name)
		else:
			InputMap.add_action(name, 0.45)
		for k in keys.get(a, []):
			if k in without:
				continue
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(name, ev)
		if pad == -2:
			continue
		if PAD.has(a):
			var jb := InputEventJoypadButton.new()
			jb.button_index = PAD[a]
			jb.device = pad
			InputMap.action_add_event(name, jb)
		if STICK.has(a):
			var jm := InputEventJoypadMotion.new()
			jm.axis = STICK[a][0]
			jm.axis_value = STICK[a][1]
			jm.device = pad
			InputMap.action_add_event(name, jm)
