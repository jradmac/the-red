"""The two legendary pieces of gear, drawn to sit with the rest:

    HUNTSMAN'S AXE   the woodsman's felling axe -- the one that cut Grandmother
                     free. A broad bearded head with a moon-bright edge on a
                     long ash haft, a strip of red cloth tied below the head.
    WOLFSKIN CLOAK   the Big Bad Wolf's own pelt, worn with its head for a hood:
                     ears up, muzzle over your brow, amber glass for eyes.

The other generators call in here, so re-running any of them keeps these:
    make_gear_big.py   register_gear()  -> the axe in gear_big / gear_side(_big).png
    make_hero_big.py   wolf_hero()      -> the cloak as look 6 of the big hero
and tools/make_legendary_gear.py adds the small pieces to the sheets other
tools build whole (hero*.png look 6, gear.png column 6, items.png icons 32, 33).
"""
import math

from PIL import Image

AXE = "huntsmans_axe"
CLOAK = "wolfskin_cloak"
FUR = {1: "7c7680", 2: "6e7488"}          # the pelt (a little bluer on player 2)
EYE = "ffb040"                            # the wolf's amber glass eyes


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
    s.line([at(50, 6), at(53, 11), at(56, 7)], "metal", 1)        # the mark: a wolf's head, roughly
    s.dot(*at(53, 8), "metal", 0)
    # a strip of red cloth tied round the haft under the head, its ends fluttering
    s.limb([at(40, -2.6), at(40, 2.6)], 1.3, "ribbon")
    s.limb([at(40, 2.0), at(36, 5.5), at(33, 8)], 1.0, "ribbon", r_end=0.6)
    s.limb([at(40, 2.4), at(38, 7), at(37, 10)], 0.9, "ribbon", r_end=0.5)
    s.texture("ash", 0.12, -1, tones=(2, 3, 4), seed=8)
    s.glints("metal", 0.07)


def register_gear(order, designs, pal, g):
    """Called by make_gear_big.py: the axe after the grave blade (column 6)."""
    if AXE in order:
        return
    order.append(AXE)
    designs.append(lambda s: _axe(s, g))
    pal.update({"ash": "b08a5a", "silver": "dfe8f4", "ribbon": "c4323e"})


# --- the armour, big (make_hero_big.py) ---------------------------------------------------

def wolf_hero(Hero):
    """Called by make_hero_big.py: a Hero that also knows the wolfskin cloak --
    drawn as the worn cloak's long cloak and hood, in fur, with the wolf's head."""

    class WolfHero(Hero):
        def __init__(self, look, facing, blue, arm=True):
            self.wolf = look == CLOAK
            super().__init__("worn_cloak" if self.wolf else look, facing, blue, arm)

        def arm(self, sh, el, hd, sleeve, near=True):
            if self.wolf and sleeve == "tunic":
                sleeve = "cloth"   # (the arm piece asks for a bare sleeve: it's fur too)
            super().arm(sh, el, hd, sleeve, near)

        def _ears(self, xs, top):
            for x0, x1, tip in xs:
                self.poly([(x0, top + 7), (x1, top + 5), (tip, top - 7)], "cloth", grad=(4, 2))
                mx = (x0 + x1) / 2
                self.poly([(mx - 1.6, top + 4.5), (mx + 1.6, top + 4), (tip + (mx - tip) * 0.35, top - 2)], "skin",
                          tone=1, outline=False)

        def head_front(self):
            super().head_front()
            if not self.wolf:
                return
            self._ears(((19, 27, 20.5), (37, 45, 43.5)), 14)
            # the wolf's head over the brow: muzzle toward you, nose, fangs over the rim, glass eyes
            self.limb([(32, 21), (32, 15)], 4.2, "cloth", r_end=3.4)          # the bridge of the muzzle
            self.line([(30, 20), (30, 15)], "cloth", 4)
            self.blob(32, 13.5, 3.0, 2.0, "dark", bands=(-0.3, 0.3, 0.8))     # the nose
            self.dot(31, 13, "dark", 4)
            for x in (28.5, 35.5):
                self.limb([(x, 19.5), (x + (0.6 if x < 32 else -0.6), 23)], 0.9, "bone", r_end=0.3)
            for x in (24, 40):
                self.s.pdot(self.X(x), 18, EYE)
                self.s.pdot(self.X(x) + 1, 18, EYE)
                self.s.pdot(self.X(x), 19, "a8601a")

        def head_back(self):
            super().head_back()
            if not self.wolf:
                return
            self._ears(((19, 27, 20.5), (37, 45, 43.5)), 14)
            for k in range(7):   # the ruff of the pelt at the nape
                x = 21 + k * 3.7
                self.line([(x, 42), (x + 1, 46)], "cloth", 1 if k % 2 else 4, only_on=False)

        def head_side(self):
            super().head_side()
            if not self.wolf:
                return
            self._ears(((32, 38, 35), (38, 44, 43)), 14)
            # the muzzle runs forward over the brow, to a black nose
            self.limb([(31, 20), (24, 17.5), (16, 19)], 4.0, "cloth", r_end=2.2)
            self.blob(14.8, 18.6, 1.8, 1.5, "dark", bands=(-0.3, 0.3, 0.8))
            self.limb([(20, 21.5), (20.5, 24.5)], 0.8, "bone", r_end=0.3)
            x = self.X(27)
            self.s.pdot(x, 17, EYE)
            self.s.pdot(x + (-1 if self.flip else 1), 17, EYE)

        def finish(self, pal):
            if self.wolf:
                pal = dict(pal)
                pal["cloth"] = FUR[2 if pal.get("cloth") == "3a5cc4" else 1]
                self.s.fuzz("cloth", 0.5, seed=13, tone=1)
                self.s.texture("cloth", 0.18, -1, tones=(1, 2, 3, 4), seed=21)
            return super().finish(pal)

    return WolfHero


# --- the small pieces (make_legendary_gear.py) -------------------------------------------

# the small hero: the worn cloak's look in fur (make_art.py ARMOR_LOOKS form)
_FUR_SMALL = {"R": "7c7680", "H": "a49eac", "h": "ccc6d0", "r": "57525f", "d": "3b3745"}
SMALL_LOOK = ("wolfskin_cloak", {"head": dict(_FUR_SMALL), "body": dict(_FUR_SMALL), "legs": {}})


def ears_small(frame, view):
    """Two pricked ears on the small hero's hood (view: down / up / left / right)."""
    px = frame.load()
    ys = [y for y in range(frame.height) if any(px[x, y][3] for x in range(16))]
    if not ys:
        return frame
    top = ys[0]
    xs = [x for x in range(16) if px[x, top][3]]
    lo, hi = min(xs), max(xs)
    if view in ("down", "up"):
        ear_x = (lo, hi)
    else:   # side: both ears toward the back of the head
        back = hi if view == "left" else lo
        step = -1 if view == "left" else 1
        ear_x = (back - step * 3, back - step * 1)
    fur = (0xa4, 0x9e, 0xac, 255)
    dark = (0x1c, 0x10, 0x20, 255)
    for x in ear_x:
        if top >= 1:
            frame.putpixel((x, top - 1), dark)
        if top >= 0:
            frame.putpixel((x, top), fur)
    return frame


def small_axe(big_diag):
    """The 16 x 16 carried axe (gear.png) from the big diagonal drawing."""
    from make_gear_big import shrink
    return shrink(big_diag)


CLOAK_ICON = [
    "................",
    "...K........K...",
    "..KhK......KhK..",
    "..KhhKKKKKKhhK..",
    "..KhHHHHHHHHrK..",
    "..KHHaHHHHaHrK..",
    "...KHHHKKHHrK...",
    "...KHHHHHHrrK...",
    "..KHHKbKKbKHrK..",
    ".KHHHHHHHHHHrrK.",
    ".KhHHHHHHHHHHrK.",
    "KhHHHHHHHHHHHrrK",
    "KHHHHHHHHHHHHHrK",
    "KHrHHrHHrHHrHrrK",
    ".KKrKKrKKrKKrKK.",
    "................",
]
CLOAK_PAL = {"K": "1c1020", "H": "8c8690", "h": "ccc6d0", "r": "57525f", "a": EYE, "b": "f2ead8"}


def cloak_icon():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(CLOAK_ICON):
        for x, ch in enumerate(row):
            if ch != ".":
                c = CLOAK_PAL[ch]
                img.putpixel((x, y), tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (255,))
    return img
