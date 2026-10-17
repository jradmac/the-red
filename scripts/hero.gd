class_name Hero
extends RefCounted
## Everything that belongs to one player: the hero on the map and their bag,
## light, health, screens and spirit. Alone there is one Hero; with a second
## player there are two, and the shared world systems (chests, doors, the
## floor, traps, creatures...) are "bound" to whichever hero is acting.
##
##   Hero.all        the players in the game (all[0] is the main one)
##   Hero.bind_all(h) points every shared system at hero h

static var all: Array = []
static var systems: Array = []   ## shared systems with a bind(h: Hero) method
static var bound: Hero           ## the hero the shared systems are pointing at

var p2 := false        ## the second player's look: blue clothes, a teal spirit
var pfx := ""          ## input prefix: "" or "p2_"
var pad := -1          ## their controller (-1 none / any)
var player: Player
var inventory: Inventory
var lantern: Lantern
var companion: Companion
var hud: Hud
var bag: Bag
var battle: Battle
var chest_screen: ChestScreen
var riddle: RiddleScreen
var dialog: Dialog
var lock_puzzle: LockPuzzle
var automap: Automap
var transition: Transition
var trade: TradeScreen
var village_screen: VillageScreen
var interior: Interior
var eyes: WatchingEyes
var lantern_light: Dictionary
var halo_light: Dictionary
var lean := Vector2.ZERO
var ui_layers: Array = []      ## this hero's screens (CanvasLayers), moved into their half in co-op
var beat_t := 0.0
var knocked_t := 0.0           ## co-op: seconds until a knocked-out player is back on their feet


static func bind_all(h: Hero) -> void:
	bound = h
	for s in systems:
		s.bind(h)


static func index_of(h: Hero) -> int:
	return all.find(h)


## The other player (or null when alone).
func partner() -> Hero:
	for h in all:
		if h != self:
			return h
	return null


func alive() -> bool:
	return player != null and not player.dead


## In a fight or a full-screen menu: their half of the screen shows that
## instead of the world.
func in_menu() -> bool:
	if player == null:
		return false
	return player.ui_lock in ["battle", "bag", "chest", "riddle", "lock", "map", "trade", "transition", "village", "interior"] \
		or (interior != null and interior.active) \
		or (village_screen != null and village_screen.visible) \
		or (battle != null and battle.is_active()) or (bag != null and bag.visible) \
		or (chest_screen != null and chest_screen.visible) or (riddle != null and riddle.visible) \
		or (automap != null and automap.visible) or (trade != null and trade.visible) \
		or (lock_puzzle != null and lock_puzzle.visible) or (transition != null and transition.is_playing())
