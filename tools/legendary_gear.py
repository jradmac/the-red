"""The two legendary pieces of gear, drawn to sit with the rest:

    WARDEN'S AXE     the felling axe of the labyrinth's first warden: a broad
                     bearded head with a moon-bright edge on a long ash haft,
                     a strip of red cloth tied below the head.
    KING'S MANTLE    the mantle of whoever wore the Hollow Crown: deep purple,
                     trimmed in gold, a collar of white fur, and a thin gold
                     circlet over the hood.

Also six everyday weapons for variety (EXTRA: pitchfork, cleaver, boar spear,
flail, silver dagger, war scythe), drawn the same way, in the usual loot.

The other generators call in here, so re-running any of them keeps these:
    make_gear_big.py   register_gear()  -> the axe in gear_big / gear_side(_big).png
    make_hero_big.py   mantle_hero()    -> the mantle as look 6 of the big hero
and tools/make_legendary_gear.py adds the small pieces to the sheets other
tools build whole (hero*.png look 6, gear.png column 6, items.png icons 32, 33).
"""
import math

from PIL import Image

AXE = "wardens_axe"
CLOAK = "kings_mantle"
VELVET = {1: "4e2a6e", 2: "2e3478"}       # the mantle (bluer on player 2)
GOLD = "d8a838"
ERMINE = "f0ece4"


# --- the weapon (make_gear_big.py) ------------------------------------------------------

def _axe(s, g):
    at, grip = g["at"], g["grip"]
    # the long ash haft, a pale grain line along it, a leather grip and a brass butt cap
    s.limb([at(0), at(60)], 2.0, "ash")
    s.line([at(3, -0.7), at(58, -0.7)], "ash", 4)
    grip(s, 3, 17, 2.4, "leather")
    s.blob(*at(1.2), 2.5, 2.5, "brass")
    # the head: a broad bearded blade sweeping down past the haft, a hammer poll behind
    s.poly([at(43, 1.5), at(58, 1.5), at(63, 9), at(62, 17), at(55, 19), at(48, 15), at(44, 8)], "metal",
           grad=(2, 1))
    s.poly([at(48, -1.5), at(57, -1.5), at(56, -6), at(49, -6)], "metal", tone=2)
    s.blob(*at(52.5, 0), 1.0, 1.0, "dark", outline=False)        # the wedge through the eye
    # the edge: a crescent of moon-bright steel, and a hunter's mark etched on the cheek
    for k in range(9):
        a = -0.2 + k * 0.17
        x, y = at(57 + math.cos(a) * 6.0, 9 + math.sin(a) * 9.5)
        s.pdot(round(x), round(y), "dfe8f4" if k % 3 else "fbfdff")
    s.line([at(60, 4), at(62, 12)], "silver", 5)
    s.line([at(50, 6), at(53, 11), at(56, 7)], "metal", 1)        # the warden's mark
    s.dot(*at(53, 8), "metal", 0)
    # a strip of red cloth tied round the haft under the head, its ends fluttering
    s.limb([at(40, -2.6), at(40, 2.6)], 1.3, "ribbon")
    s.limb([at(40, 2.0), at(36, 5.5), at(33, 8)], 1.0, "ribbon", r_end=0.6)
    s.limb([at(40, 2.4), at(38, 7), at(37, 10)], 0.9, "ribbon", r_end=0.5)
    s.texture("ash", 0.12, -1, tones=(2, 3, 4), seed=8)
    s.glints("metal", 0.07)


# --- more everyday weapons, for variety (columns 7-12) -----------------------------------

def _pitchfork(s, g):
    at, grip = g["at"], g["grip"]
    s.limb([at(0), at(50)], 1.8, "ash")
    s.line([at(3, -0.6), at(48, -0.6)], "ash", 4)
    grip(s, 4, 14, 2.1, "leather", wraps=False)
    s.limb([at(48, -5.5), at(48, 5.5)], 1.4, "metal")           # the crossbar
    for o in (-5, 0, 5):                                        # three tines, rusted at the roots
        s.limb([at(48, o), at(63, o * 0.8)], 1.1, "metal", r_end=0.4)
        s.blob(*at(49.5, o), 1.0, 1.0, "rust", outline=False, bands=(-0.3, 0.2, 0.7))
    s.texture("ash", 0.12, -1, tones=(2, 3, 4), seed=11)


def _cleaver(s, g):
    at, grip = g["at"], g["grip"]
    s.blob(*at(1.5), 2.3, 2.3, "metal")
    grip(s, 3, 18, 2.4, "wood")
    for t in (7, 13):
        s.dot(*at(t), "brass", 4)                               # rivets in the handle
    # a broad rectangular blade, the edge on the far side, a hole to hang it by
    s.poly([at(19, -2.5), at(44, -2.5), at(46, 0), at(46, 11), at(19, 10)], "metal", grad=(3, 2))
    s.line([at(20, 9.6), at(45.5, 10.6)], "metal", 5)
    s.blob(*at(41, 1.5), 1.6, 1.6, "dark", outline=False)
    s.line([at(22, 1), at(34, 1)], "metal", 1)
    for (t, o) in ((28, 6), (36, 8)):
        s.blob(*at(t, o), 1.2, 0.9, "rust", outline=False, bands=(-0.3, 0.2, 0.7))
    s.glints("metal", 0.05)


def _boar_spear(s, g):
    at, grip = g["at"], g["grip"]
    s.limb([at(0), at(50)], 1.8, "ash")
    s.line([at(3, -0.6), at(48, -0.6)], "ash", 4)
    grip(s, 5, 17, 2.2, "leather")
    s.blob(*at(1), 2.0, 2.0, "metal")
    s.limb([at(47, -6), at(47, 6)], 1.5, "metal")              # the crossbar (lugs)
    s.blob(*at(47, -6), 1.4, 1.4, "metal")
    s.blob(*at(47, 6), 1.4, 1.4, "metal")
    s.poly([at(49, -3.4), at(57, -3.2), at(65, 0), at(57, 3.2), at(49, 3.4)], "metal", grad=(3, 2))
    s.line([at(50, 0), at(63, 0)], "metal", 5)
    s.limb([at(44, -2.6), at(44, 2.6)], 1.0, "leather")          # a leather binding under the lugs
    s.texture("ash", 0.12, -1, tones=(2, 3, 4), seed=12)


def _flail(s, g):
    at, grip = g["at"], g["grip"]
    s.limb([at(0), at(24)], 2.2, "wood")
    grip(s, 2, 15, 2.5, "leather")
    s.blob(*at(25), 2.4, 2.4, "metal")
    # the chain, sagging, then the spiked ball
    links = [at(27 + k * 3.3, 2.2 * math.sin(k * 0.6) + k * 0.5) for k in range(7)]
    for k, (x, y) in enumerate(links):
        s.blob(x, y, 1.3, 1.0 if k % 2 else 1.3, "metal", bands=(-0.3, 0.2, 0.7))
    bx, by = at(55, 4.5)
    for k in range(8):
        a = k * math.pi / 4 + 0.2
        s.limb([(bx, by), (bx + math.cos(a) * 8.5, by + math.sin(a) * 8.5)], 1.2, "metal", r_end=0.3)
    s.blob(bx, by, 5.5, 5.5, "dark", bands=(-0.3, 0.05, 0.5, 0.85, 0.96))
    s.glints("metal", 0.06)


def _silver_dagger(s, g):
    at, grip, guard, blade = g["at"], g["grip"], g["guard"], g["blade"]
    s.blob(*at(2), 2.6, 2.6, "silver")
    grip(s, 4, 15, 2.0, "wrap")
    guard(s, 16, 6.5, 1.5, "silver")
    s.blob(*at(16), 1.8, 1.8, "ribbon")                         # a red stone in the guard
    blade(s, 17, 47, 3.0, "silver")
    for t in (23, 30, 37):                                      # a little cross etched down it
        x, y = at(t, 0)
        s.pdot(round(x), round(y), "8a9ab0")
    s.glints("silver", 0.12)


def _war_scythe(s, g):
    at, grip = g["at"], g["grip"]
    s.limb([at(0), at(58)], 1.9, "wood")
    s.line([at(3, -0.6), at(56, -0.6)], "wood", 4)
    grip(s, 3, 13, 2.3, "leather")
    s.limb([at(30, 0), at(30, 5)], 1.3, "wood", r_end=1.0)      # the second grip (the nib)
    s.blob(*at(57), 2.4, 2.4, "metal")
    # the long curved blade, sweeping back down from the top of the snath
    pts = []
    for k in range(14):
        a = k * 0.2
        pts.append(at(58 - k * 2.4 + math.sin(a) * 2, -2 - k * 1.6 - math.sin(a) * 4))
    s.limb([at(58)] + pts, 3.0, "metal", r_end=0.4)
    s.limb([at(58)] + pts[:-1], 0.9, "metal", r_end=0.3, outline=False, bands=(9,))   # the honed edge
    s.texture("wood", 0.12, -1, tones=(2, 3, 4), seed=13)
    s.glints("metal", 0.08)


# id, name, atk, tier (Items.GEAR_TIER), loot weight, price, description
EXTRA = [
    ("pitchfork", "PITCHFORK", 3, 0, 3, 12, "THREE RUSTED TINES. IT STILL SMELLS OF HAY.", _pitchfork),
    ("cleaver", "CLEAVER", 3, 0, 3, 12, "A BUTCHER'S CLEAVER. THE INN WILL WANT IT BACK.", _cleaver),
    ("boar_spear", "BOAR SPEAR", 4, 1, 2, 26,
     "A CROSSBAR BELOW THE BLADE, SO WHATEVER YOU STAB CAN'T CLIMB THE SHAFT TO YOU.", _boar_spear),
    ("flail", "FLAIL", 5, 2, 2, 44, "A SPIKED BALL ON A CHAIN. HARD TO AIM. HARDER TO STOP.", _flail),
    ("silver_dagger", "SILVER DAGGER", 5, 2, 1, 50, "BLESSED SILVER. THE DEMONS DON'T LIKE TO LOOK AT IT.",
     _silver_dagger),
    ("war_scythe", "WAR SCYTHE", 6, 2, 1, 72,
     "A REAPER'S BLADE TURNED TO STAND UP STRAIGHT. FOR A HARVEST OF A DIFFERENT KIND.", _war_scythe),
]
EXTRA_FIRST = 7       # their column in the gear sheets (the axe is 6)
EXTRA_ICON = 34       # their first icon in items.png (the legendary pair are 32, 33)


def register_gear(order, designs, pal, g):
    """Called by make_gear_big.py: the axe after the grave blade (column 6),
    then the everyday extras (columns 7-12)."""
    if AXE in order:
        return
    order.append(AXE)
    designs.append(lambda s: _axe(s, g))
    for row in EXTRA:
        order.append(row[0])
        designs.append(lambda s, fn=row[7]: fn(s, g))
    pal.update({"ash": "b08a5a", "silver": "dfe8f4", "ribbon": "c4323e", "fur": "8c8690"})


# --- the armour, big (make_hero_big.py) ---------------------------------------------------

def mantle_hero(Hero):
    """Called by make_hero_big.py: a Hero that also knows the King's Mantle --
    drawn as the worn cloak's long cloak and hood, in velvet, trimmed in gold,
    with a white fur collar and a circlet over the hood."""

    class MantleHero(Hero):
        def __init__(self, look, facing, blue, arm=True):
            self.mantle = look == CLOAK
            super().__init__("worn_cloak" if self.mantle else look, facing, blue, arm)

        def arm(self, sh, el, hd, sleeve, near=True):
            if self.mantle and sleeve == "tunic":
                sleeve = "cloth"
            super().arm(sh, el, hd, sleeve, near)

        def capelet(self, back):
            super().capelet(back)
            if self.mantle:
                # the white fur collar round the shoulders, spotted, and gold trim down the edges
                self.blob(32, 47, 15, 3.6, "ermine", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
                for x in (22, 28, 35, 41):
                    self.dot(x, 47 + (x % 2), "eye", 1)
                if not back:
                    for side in (-1, 1):
                        self.line([(32 + side * 9, 50), (32 + side * 13.5, 83)], "gold", 3, only_on=True)

        def _circlet(self, y, x0, x1):
            self.limb([(x0, y), (x1, y)], 0.9, "gold")
            for x in (x0 + 2, (x0 + x1) / 2, x1 - 2):
                self.poly([(x - 1.2, y - 0.5), (x + 1.2, y - 0.5), (x, y - 3.2)], "gold", tone=3)
            self.dot((x0 + x1) / 2, y, "ff3b4d")

        def head_front(self):
            super().head_front()
            if self.mantle:
                self.line([(20, 40), (19, 30), (24, 19), (32, 16.5), (40, 19), (45, 30), (44, 40)], "gold", 3)
                self._circlet(18.5, 23, 41)

        def head_back(self):
            super().head_back()
            if self.mantle:
                self._circlet(19, 21, 43)

        def head_side(self):
            super().head_side()
            if self.mantle:
                self._circlet(19.5, 22, 44)

        def finish(self, pal):
            if self.mantle:
                pal = dict(pal)
                pal["cloth"] = VELVET[2 if pal.get("cloth") == "3a5cc4" else 1]
                pal["gold"] = GOLD
                pal["ermine"] = ERMINE
                self.s.texture("cloth", 0.06, +1, tones=(2, 3), seed=21)
                self.s.glints("gold", 0.25)
            return super().finish(pal)

    return MantleHero


# --- the small pieces (make_legendary_gear.py) -------------------------------------------

# the small hero: the worn cloak's look in velvet (make_art.py ARMOR_LOOKS form)
_VELVET_SMALL = {"R": "5a3480", "H": "7e52a8", "h": "a27cc8", "r": "3e2258", "d": "2a163e"}
SMALL_LOOK = ("kings_mantle", {"head": dict(_VELVET_SMALL), "body": dict(_VELVET_SMALL), "legs": {}})


def crown_small(frame, view):
    """A thin gold circlet across the top of the small hero's hood."""
    px = frame.load()
    ys = [y for y in range(frame.height) if any(px[x, y][3] for x in range(16))]
    if not ys:
        return frame
    row = ys[0] + 1
    xs = [x for x in range(16) if px[x, row][3] and px[x, row][:3] != (0x1c, 0x10, 0x20)]
    if len(xs) >= 3:
        gold = (0xe8, 0xb8, 0x48, 255)
        for x in xs[1:-1]:
            frame.putpixel((x, row), gold)
        frame.putpixel((xs[len(xs) // 2], row), (0xff, 0x3b, 0x4d, 255))
    return frame


def small_axe(big_diag):
    """The 16 x 16 carried axe (gear.png) from the big diagonal drawing."""
    from make_gear_big import shrink
    return shrink(big_diag)


CLOAK_ICON = [
    "................",
    "....G.G..G.G....",
    "....GGGRRGGG....",
    "...KVVVVVVVVK...",
    "..KVvVVVVVVvVK..",
    "..KVVKKKKKKVVK..",
    "..KWWWWWWWWWWK..",
    ".KWdWWdWWdWWdWK.",
    ".KVGVVVVVVVVGVK.",
    "KVVGVVVVVVVVGVvK",
    "KVVGVVVVVVVVGvvK",
    "KVVGVVVVVVVVGVvK",
    "KVVGVVVVVVVVGvvK",
    "KGGGGGGGGGGGGGGK",
    ".KKKKKKKKKKKKKK.",
    "................",
]
CLOAK_PAL = {"K": "1c1020", "V": "5e3488", "v": "3e2258", "G": "e8b848", "R": "ff3b4d", "W": "f0ece4",
             "d": "2a2430"}


def cloak_icon():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(CLOAK_ICON):
        for x, ch in enumerate(row):
            if ch != ".":
                c = CLOAK_PAL[ch]
                img.putpixel((x, y), tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (255,))
    return img
