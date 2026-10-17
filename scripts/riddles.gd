class_name Riddles
## Riddles the sprites ask. Several kinds, most of them generated fresh each
## time, so a run rarely sees the same puzzle twice:
##
##   RIDDLE      classic "what am I?" riddles (hand-written, below)
##   NUMBERS     what comes next in a number pattern
##   COUNTING    a little story problem about candles, keys, coins...
##   SCRAMBLE    unscramble a word
##   BACKWARDS   a word written backwards
##   ODD ONE     which one doesn't belong
##   SEQUENCE    what comes next in a sequence of words
##   MISSING     fill in the missing letter
##
## make() returns {"kind", "q", "options" (3 strings), "answer" (index)}.

const CLASSIC := [
	["THE MORE YOU TAKE, THE MORE YOU LEAVE BEHIND. WHAT AM I?", "FOOTSTEPS", "BREATHS", "SECRETS"],
	["WHAT HAS KEYS BUT CANNOT OPEN A SINGLE LOCK?", "A PIANO", "A JAILER", "A MAP"],
	["I SPEAK WITHOUT A MOUTH AND HEAR WITHOUT EARS. I COME ALIVE WITH THE WIND. WHAT AM I?", "AN ECHO", "A GHOST", "A BELL"],
	["WHAT CAN YOU CATCH BUT NEVER THROW?", "A COLD", "A FISH", "A SHADOW"],
	["THE MORE OF ME THERE IS, THE LESS YOU SEE. WHAT AM I?", "DARKNESS", "LIGHT", "WATER"],
	["I HAVE A HEAD AND A TAIL, BUT NO BODY. WHAT AM I?", "A COIN", "A SNAKE", "A COMET"],
	["WHAT HAS ONE EYE BUT CANNOT SEE?", "A NEEDLE", "A FISH", "A STONE"],
	["WHAT GETS WETTER THE MORE IT DRIES?", "A TOWEL", "A RIVER", "A CANDLE"],
	["I AM TALL WHEN I AM YOUNG AND SHORT WHEN I AM OLD. WHAT AM I?", "A CANDLE", "A TREE", "A SHADOW"],
	["WHAT HAS HANDS BUT CANNOT CLAP?", "A CLOCK", "A GLOVE", "A SCARECROW"],
	["SAY MY NAME AND I AM GONE. WHAT AM I?", "SILENCE", "A SECRET", "A WISH"],
	["WHAT RUNS BUT NEVER WALKS, HAS A MOUTH BUT NEVER TALKS?", "A RIVER", "A CLOCK", "A WOLF"],
	["FEED ME AND I LIVE. GIVE ME A DRINK AND I DIE. WHAT AM I?", "FIRE", "A PLANT", "A GHOST"],
	["WHAT CAN FILL A ROOM BUT TAKES UP NO SPACE?", "LIGHT", "WATER", "DUST"],
	["WHAT HAS A NECK BUT NO HEAD?", "A BOTTLE", "A SNAKE", "A SCARF"],
	["MY ROOTS ARE HIDDEN, I STAND TALLER THAN TREES, UP I GO BUT NEVER GROW. WHAT AM I?", "A MOUNTAIN", "A TOWER", "A CLOUD"],
	["I HAVE CITIES BUT NO HOUSES, FORESTS BUT NO TREES, AND RIVERS BUT NO FISH. WHAT AM I?", "A MAP", "A DREAM", "A DESERT"],
	["WHAT COMES ONCE IN A MINUTE, TWICE IN A MOMENT, AND NEVER IN A THOUSAND YEARS?", "THE LETTER M", "A HEARTBEAT", "A BLINK"],
	["WHAT WALKS ON FOUR LEGS AT DAWN, TWO AT NOON, AND THREE AT DUSK?", "A PERSON", "A SPIDER", "A DOG"],
	["WHAT HAS TEETH BUT CANNOT BITE?", "A COMB", "A WOLF", "A DEMON"],
	["WHAT IS ALWAYS COMING BUT NEVER ARRIVES?", "TOMORROW", "THE TIDE", "WINTER"],
	["WHAT CAN TRAVEL ALL AROUND THE WORLD WHILE STAYING IN ONE CORNER?", "A STAMP", "A SPIDER", "A SHADOW"],
	["I FOLLOW YOU ALL DAY BUT VANISH IN THE DARK. WHAT AM I?", "YOUR SHADOW", "A GHOST", "AN ECHO"],
	["WHAT HAS ONE HEAD, ONE FOOT AND FOUR LEGS?", "A BED", "A TABLE", "A HORSE"],
	["WHAT GOES UP BUT NEVER COMES DOWN?", "YOUR AGE", "SMOKE", "A BIRD"],
	["WHAT HAS WORDS BUT NEVER SPEAKS?", "A BOOK", "A GHOST", "A BELL"],
	["WHAT IS FULL OF HOLES BUT STILL HOLDS WATER?", "A SPONGE", "A NET", "A BASKET"],
	["WHAT CAN YOU KEEP AFTER GIVING IT TO SOMEONE?", "YOUR WORD", "A COIN", "A KEY"],
	["WHAT HAS A BED BUT NEVER SLEEPS?", "A RIVER", "A GHOST", "A CAT"],
	["WHAT BELONGS TO YOU, BUT OTHERS USE IT MORE THAN YOU DO?", "YOUR NAME", "YOUR LANTERN", "YOUR SHADOW"],
	["THE MORE YOU HAVE OF IT, THE LESS YOU CAN SEE. IT ISN'T NIGHT. WHAT IS IT?", "FOG", "GOLD", "SLEEP"],
	["WHAT HAS A THUMB AND FOUR FINGERS BUT IS NOT ALIVE?", "A GLOVE", "A STATUE", "A CLAW"],
	["WHAT BREAKS YET NEVER FALLS, AND FALLS YET NEVER BREAKS?", "DAY AND NIGHT", "GLASS AND RAIN", "BONES AND LEAVES"],
	["WHAT HAS LEGS BUT DOESN'T WALK?", "A TABLE", "A SPIDER", "A STATUE"],
	["WHAT CAN RUN, BUT NEVER GETS TIRED?", "WATER", "A WOLF", "A WIND-UP TOY"],
	["I SHAVE EVERY DAY, BUT MY BEARD STAYS THE SAME. WHAT AM I?", "A BARBER", "A GOAT", "A KING"],
	["WHAT HAS A RING BUT NO FINGER?", "A BELL", "A TREE STUMP", "A KEY"],
	["WHAT KIND OF ROOM HAS NO DOORS OR WINDOWS?", "A MUSHROOM", "A TOMB", "A CELLAR"],
	["WHAT HAS MANY TEETH BUT CAN'T EAT?", "A SAW", "A SKULL", "A SHARK"],
	["WHAT DISAPPEARS AS SOON AS YOU SAY ITS NAME?", "SILENCE", "A GHOST", "DARKNESS"],
	["WHAT IS LIGHT AS A FEATHER, YET THE STRONGEST MAN CAN'T HOLD IT FOR LONG?", "HIS BREATH", "A FLAME", "A LIE"],
	["WHAT HAS ONE HEAD, NO ARMS, AND STANDS ON A FOOT?", "A MUSHROOM", "A CANDLE", "A NAIL"],
	["THE MAKER SELLS IT, THE BUYER NEVER USES IT, THE USER NEVER KNOWS. WHAT IS IT?", "A COFFIN", "A CANDLE", "A KEY"],
	["WHAT HAS FOUR FINGERS AND A THUMB BUT NO FLESH OR BONE?", "A GLOVE", "A GHOST", "A SKELETON"],
	["I AM ALWAYS HUNGRY AND MUST BE FED. THE FINGER I TOUCH WILL SOON TURN RED. WHAT AM I?", "FIRE", "A DEMON", "A WOLF"],
	["WHAT GOES THROUGH A DOOR BUT NEVER GOES IN OR COMES OUT?", "A KEYHOLE", "A GHOST", "THE WIND"],
	["WHAT IS BLACK WHEN YOU BUY IT, RED WHEN YOU USE IT, AND GREY WHEN YOU THROW IT AWAY?", "CHARCOAL", "A CANDLE", "IRON"],
	["THE ONE WHO HAS ME DOESN'T SHARE ME. IF I'M SHARED, I'M GONE. WHAT AM I?", "A SECRET", "A KEY", "A MEAL"],
	["WHAT CAN YOU HEAR BUT NOT TOUCH OR SEE?", "YOUR VOICE", "A GHOST", "THE DARK"],
	["WHAT HAS A HEART THAT DOESN'T BEAT?", "AN ARTICHOKE", "A STATUE", "A GHOST"],
	["WHAT WORD IS SPELLED WRONG IN EVERY DICTIONARY?", "WRONG", "WEIRD", "ERROR"],
	["WHAT FLIES WITHOUT WINGS?", "TIME", "A GHOST", "DUST"],
	["WHAT HAS 88 KEYS BUT CAN'T OPEN A DOOR?", "A PIANO", "A JAILER", "A CHEST"],
	["WHAT GETS BIGGER THE MORE YOU TAKE AWAY FROM IT?", "A HOLE", "A SHADOW", "A DEBT"],
	["WHAT IS SEEN IN THE MIDDLE OF MARCH AND APRIL THAT CAN'T BE SEEN AT THE START OR END?", "THE LETTER R", "THE MOON", "RAIN"],
	["IF YOU DROP ME I'M SURE TO CRACK, BUT SMILE AT ME AND I'LL SMILE BACK. WHAT AM I?", "A MIRROR", "AN EGG", "A SKULL"],
	["WHAT HAS ONE EYE AND A TAIL BUT NO HEAD, AND HELPS YOU MEND YOUR CLOAK?", "A NEEDLE", "A COMET", "A FISH"],
	["I GO ALL AROUND THE HOUSE BUT NEVER COME INSIDE. WHAT AM I?", "A WALL", "THE WIND", "A CAT"],
	["WHAT HAS A FACE AND TWO HANDS BUT NO ARMS OR LEGS?", "A CLOCK", "A SKULL", "A MASK"],
	["I HAVE NO LIFE, BUT I CAN DIE. WHAT AM I?", "A FLAME", "A STONE", "A SKULL"],
	["THE MORE YOU CUT ME, THE TALLER I GROW. WHAT AM I?", "A HOLE", "A TREE", "GRASS"],
]

const WORDS := ["LANTERN", "SHADOW", "CANDLE", "SPIDER", "GHOST", "DEMON", "FLAME", "CHEST", "SWORD", "TORCH",
	"RIVER", "FOREST", "TOMB", "SKULL", "MOTH", "WRAITH", "SICKLE", "HATCHET", "SWAMP", "BRIDGE",
	"STONE", "CLOAK", "SPIRIT", "MATCH", "MIST", "TOWER", "STATUE", "PILLAR", "BEETLE", "FLARE",
	"DUNGEON", "PORTAL", "EMBER", "RIDDLE", "SECRET", "WILLOW", "RAVEN", "CRYPT", "COFFIN", "THRONE",
	"MARSH", "MAZE", "DOOR", "KNIGHT", "POTION", "SCROLL", "LEGEND", "WOLF", "OWL", "MOON"]

const GROUPS := {
	"CREEPY CRAWLIES": ["SPIDER", "BEETLE", "MOTH", "TICK", "WASP", "MANTIS", "CENTIPEDE"],
	"WEAPONS": ["DAGGER", "HATCHET", "SICKLE", "MACE", "SWORD", "SPEAR", "CLUB"],
	"LIGHTS": ["CANDLE", "LANTERN", "TORCH", "FLARE", "EMBER", "MATCH", "FIREFLY"],
	"WATERS": ["RIVER", "SWAMP", "LAKE", "POND", "STREAM", "MARSH", "BROOK"],
	"TREES": ["OAK", "WILLOW", "PINE", "BIRCH", "ASH", "MAPLE", "ELM"],
	"METALS": ["IRON", "GOLD", "SILVER", "BRONZE", "COPPER", "TIN", "STEEL"],
	"COLORS": ["RED", "BLUE", "GREEN", "PURPLE", "YELLOW", "ORANGE", "WHITE"],
	"NIGHT THINGS": ["MOON", "STARS", "OWL", "BAT", "DREAM", "SHADOW", "DARK"],
	"ANIMALS": ["WOLF", "RAVEN", "BEAR", "FOX", "DEER", "HARE", "BOAR"],
}

const SEQUENCES := [
	["DAWN", "NOON", "DUSK", "MIDNIGHT"],
	["SPRING", "SUMMER", "AUTUMN", "WINTER"],
	["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"],
	["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST"],
	["ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE"],
	["FIRST", "SECOND", "THIRD", "FOURTH", "FIFTH", "SIXTH"],
	["BRONZE", "SILVER", "GOLD", "PURPLE"],
	["SEED", "SPROUT", "SAPLING", "TREE"],
	["EGG", "CATERPILLAR", "COCOON", "MOTH"],
	["NORTH", "EAST", "SOUTH", "WEST"],
	["CRAWL", "WALK", "RUN", "SPRINT"],
	["SPARK", "FLAME", "FIRE", "INFERNO"],
	["WHISPER", "SPEAK", "SHOUT", "SCREAM"],
]

const KINDS := ["RIDDLE", "RIDDLE", "NUMBERS", "COUNTING", "SCRAMBLE", "BACKWARDS", "ODD ONE", "SEQUENCE", "MISSING"]


## A fresh puzzle. `used` remembers classic riddles already asked this run.
static func make(rng: RandomNumberGenerator, used: Dictionary) -> Dictionary:
	var kind: String = KINDS[rng.randi() % KINDS.size()]
	match kind:
		"RIDDLE":
			var free: Array[int] = []
			for i in CLASSIC.size():
				if not used.has(i):
					free.append(i)
			if free.is_empty():
				used.clear()
				return make(rng, used)
			var i: int = free[rng.randi() % free.size()]
			used[i] = true
			var r: Array = CLASSIC[i]
			return _pack(kind, r[0], r[1], [r[2], r[3]], rng)
		"NUMBERS":
			return _numbers(rng)
		"COUNTING":
			return _counting(rng)
		"SCRAMBLE":
			var word: String = WORDS[rng.randi() % WORDS.size()]
			var s := _shuffle_word(word, rng)
			return _pack(kind, "UNSCRAMBLE THESE LETTERS:  " + " ".join(s.split("")), word, _other_words(word, rng), rng)
		"BACKWARDS":
			var word2: String = WORDS[rng.randi() % WORDS.size()]
			return _pack(kind, "THIS WORD IS WRITTEN BACKWARDS:  " + word2.reverse() + "  -  WHAT IS IT?",
				word2, _other_words(word2, rng), rng)
		"ODD ONE":
			return _odd_one(rng)
		"SEQUENCE":
			var seq: Array = SEQUENCES[rng.randi() % SEQUENCES.size()]
			var start := rng.randi_range(0, seq.size() - 4)
			var shown: Array = seq.slice(start, start + 3)
			var right: String = seq[start + 3]
			var wrongs: Array[String] = []
			for wd in seq:
				if wd != right and not shown.has(wd):
					wrongs.append(wd)
			wrongs.shuffle()
			var extra: Array = shown.duplicate()
			extra.shuffle()
			for wd in extra:
				if wrongs.size() >= 2:
					break
				if not wrongs.has(wd):
					wrongs.append(wd)
			return _pack(kind, "WHAT COMES NEXT?   " + ", ".join(shown) + ", ...", right, [wrongs[0], wrongs[1]], rng)
		"MISSING":
			var word3: String = WORDS[rng.randi() % WORDS.size()]
			var at := rng.randi_range(1, word3.length() - 2)
			var hole := word3.substr(0, at) + "_" + word3.substr(at + 1)
			var right3 := word3[at]
			var letters := "AEIOURSTLNMDHCK"
			var wrong_letters: Array[String] = []
			while wrong_letters.size() < 2:
				var l := letters[rng.randi() % letters.length()]
				var test := word3.substr(0, at) + l + word3.substr(at + 1)
				if l != right3 and not wrong_letters.has(l) and not WORDS.has(test):
					wrong_letters.append(l)
			return _pack(kind, "WHICH LETTER FILLS THE GAP?   " + hole, right3, wrong_letters, rng)
	return _numbers(rng)


static func _pack(kind: String, q: String, right: String, wrong: Array, rng: RandomNumberGenerator) -> Dictionary:
	var options: Array[String] = [right, str(wrong[0]), str(wrong[1])]
	# shuffle, remembering where the right one went
	for i in range(options.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t := options[i]
		options[i] = options[j]
		options[j] = t
	return {"kind": kind, "q": q, "options": options, "answer": options.find(right)}


static func _numbers(rng: RandomNumberGenerator) -> Dictionary:
	var seq: Array[int] = []
	var nxt := 0
	match rng.randi() % 6:
		0:   # add a constant
			var a := rng.randi_range(1, 9)
			var d := rng.randi_range(2, 7)
			for i in 4:
				seq.append(a + d * i)
			nxt = a + d * 4
		1:   # double
			var a := rng.randi_range(1, 5)
			for i in 4:
				seq.append(a * int(pow(2, i)))
			nxt = a * 16
		2:   # squares
			var a := rng.randi_range(1, 5)
			for i in 4:
				seq.append((a + i) * (a + i))
			nxt = (a + 4) * (a + 4)
		3:   # growing gaps
			var a := rng.randi_range(1, 6)
			var v := a
			for i in 4:
				seq.append(v)
				v += i + 1
			nxt = v
		4:   # each is the sum of the two before
			var a := rng.randi_range(1, 3)
			var b := rng.randi_range(a, 4)
			seq = [a, b, a + b, a + 2 * b]
			nxt = seq[2] + seq[3]
		_:   # counting down
			var a := rng.randi_range(30, 60)
			var d := rng.randi_range(3, 8)
			for i in 4:
				seq.append(a - d * i)
			nxt = a - d * 4
	var shown: Array[String] = []
	for n in seq:
		shown.append(str(n))
	var wrong := [str(nxt + rng.randi_range(1, 3)), str(nxt - rng.randi_range(1, 4))]
	return _pack("NUMBERS", "WHAT NUMBER COMES NEXT?   " + ", ".join(shown) + ", ...", str(nxt), wrong, rng)


static func _counting(rng: RandomNumberGenerator) -> Dictionary:
	var q := ""
	var ans := 0
	match rng.randi() % 6:
		0:
			var a := rng.randi_range(5, 12)
			var b := rng.randi_range(1, a - 2)
			q = "YOU CARRY %d MATCHES AND STRIKE %d. HOW MANY ARE LEFT?" % [a, b]
			ans = a - b
		1:
			var a := rng.randi_range(3, 6)
			var b := rng.randi_range(2, 5)
			q = "%d CHESTS EACH HOLD %d COINS. HOW MANY COINS IN ALL?" % [a, b]
			ans = a * b
		2:
			var a := rng.randi_range(3, 9)
			q = "A SPIDER HAS 8 LEGS. HOW MANY LEGS DO %d SPIDERS HAVE?" % a
			ans = 8 * a
		3:
			var a := rng.randi_range(6, 12)
			var b := rng.randi_range(2, a - 3)
			q = "%d CANDLES BURN. THE WIND BLOWS OUT %d. HOW MANY STILL BURN?" % [a, b]
			ans = a - b
		4:
			var a := rng.randi_range(2, 6)
			var b := rng.randi_range(2, 6)
			var c := rng.randi_range(1, 5)
			q = "YOU FIND %d KEYS, THEN %d MORE, THEN LOSE %d. HOW MANY DO YOU HAVE?" % [a, b, c]
			ans = a + b - c
		_:
			var a := rng.randi_range(2, 5) * 2
			q = "A GHOST HAUNTS %d ROOMS. HALF ARE DARK. HOW MANY ARE LIT?" % a
			ans = a / 2
	var wrong := [str(ans + rng.randi_range(1, 3)), str(maxi(ans - rng.randi_range(1, 3), 0) if ans > 1 else ans + 4)]
	return _pack("COUNTING", q, str(ans), wrong, rng)


static func _odd_one(rng: RandomNumberGenerator) -> Dictionary:
	var names := GROUPS.keys()
	var g: String = names[rng.randi() % names.size()]
	var other: String = g
	while other == g:
		other = names[rng.randi() % names.size()]
	var members: Array = GROUPS[g].duplicate()
	members.shuffle()
	var odd_pool: Array = GROUPS[other].filter(func(wd): return not GROUPS[g].has(wd))
	var odd: String = odd_pool[rng.randi() % odd_pool.size()]
	var shown := [members[0], members[1], members[2], odd]
	shown.shuffle()
	return _pack("ODD ONE", "WHICH ONE DOES NOT BELONG?   " + ", ".join(shown), odd, [members[0], members[1]], rng)


static func _shuffle_word(word: String, rng: RandomNumberGenerator) -> String:
	var letters := word.split("")
	for tries in 10:
		for i in range(letters.size() - 1, 0, -1):
			var j := rng.randi() % (i + 1)
			var t := letters[i]
			letters[i] = letters[j]
			letters[j] = t
		if "".join(letters) != word:
			break
	return "".join(letters)


## Two other words, preferably the same length, as wrong answers.
static func _other_words(word: String, rng: RandomNumberGenerator) -> Array:
	var same: Array = WORDS.filter(func(wd): return wd != word and absi(wd.length() - word.length()) <= 1)
	same.shuffle()
	if same.size() < 2:
		same = WORDS.filter(func(wd): return wd != word)
		same.shuffle()
	return [same[0], same[1]]
