class_name Profile
extends RefCounted
## The player's profile (user://red_riding_profile.cfg): what lasts across
## every run, even death: whether the opening has been seen, and the journal
## (journal_screen.gd) -- every creature killed, weapon held and land walked. The
## whole opening -- the voice in the dark, Lume, the lessons -- plays only the
## very first time; every new run after that just wakes the hero on the bier.
## (A run's own save is SaveGame's, and dying still deletes that.)

const PATH := "user://red_riding_profile.cfg"


static func _cfg() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(PATH)   # (missing the first time: empty)
	return c


static func intro_seen() -> bool:
	return bool(_journal().get_value("profile", "intro_seen", false))


static func mark_intro_seen() -> void:
	_journal().set_value("profile", "intro_seen", true)
	_keep()


## A run begun (new game) or ended by death -- kept for the record.
static func count(key: String) -> void:
	var c := _journal()
	c.set_value("profile", key, int(c.get_value("profile", key, 0)) + 1)
	_keep()


# --- The journal: everything ever found, across every run --------------------------

static var _c: ConfigFile = null


static func _journal() -> ConfigFile:
	if _c == null:
		_c = _cfg()
	return _c


static func _keep() -> void:
	_journal().save(PATH)


## True once there's anything to look back on (the opening seen, or a find).
static func exists() -> bool:
	return FileAccess.file_exists(PATH)


## A creature (by name) killed.
static func record_kill(creature: String) -> void:
	var c := _journal()
	var was := int(c.get_value("kills", creature, 0))
	c.set_value("kills", creature, was + 1)
	if was == 0:
		c.set_value("new", "c:" + creature, true)   # a new card, not looked at yet
	_keep()


static func kills(creature: String) -> int:
	return int(_journal().get_value("kills", creature, 0))


static func total_kills() -> int:
	var c := _journal()
	var n := 0
	if c.has_section("kills"):
		for k in c.get_section_keys("kills"):
			n += int(c.get_value("kills", k, 0))
	return n


## A weapon (item id) held for the first time.
static func found_weapon(id: String) -> void:
	_found("weapons", id)


static func has_weapon(id: String) -> bool:
	return bool(_journal().get_value("weapons", id, false))


## A piece of armor (item id) held for the first time.
static func found_armor(id: String) -> void:
	_found("armor", id)


static func has_armor(id: String) -> bool:
	return bool(_journal().get_value("armor", id, false))


## A land (JournalData.LANDS id) set foot in for the first time.
static func found_land(id: String) -> void:
	_found("lands", id)


static func has_land(id: String) -> bool:
	return bool(_journal().get_value("lands", id, false))


static func _found(section: String, id: String) -> void:
	var c := _journal()
	if not bool(c.get_value(section, id, false)):
		c.set_value(section, id, true)
		c.set_value("new", {"weapons": "w:", "armor": "a:", "lands": "l:"}[section] + id, true)   # a new card, not looked at yet
		_keep()


static func number(key: String) -> int:
	return int(_journal().get_value("profile", key, 0))


# --- New cards: found since the in-game journal last showed them -------------------
## Keys: "c:" + creature name, "w:" + weapon id, "a:" + armor id, "l:" + land id.

static func is_new(key: String) -> bool:
	return bool(_journal().get_value("new", key, false))


static func any_new(prefix: String) -> bool:
	var c := _journal()
	if not c.has_section("new"):
		return false
	for k in c.get_section_keys("new"):
		if String(k).begins_with(prefix) and bool(c.get_value("new", k, false)):
			return true
	return false


## Seen in the in-game journal: no longer new.
static func clear_new(key: String) -> void:
	var c := _journal()
	if c.has_section_key("new", key):
		c.erase_section_key("new", key)
		_keep()
