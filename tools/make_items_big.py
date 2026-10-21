"""Builds assets/items_big.png: every item that isn't a weapon, up close at
64 x 64 (one column each, in the order of ORDER), drawn with pixkit like the
big battle sprites and gear_big.png -- lit from the upper left by the
lantern, outlined, shaded in clean bands. The bag shows these in its ITEM
panel, and the journal on the backs of its cards. (Weapons already have
theirs in gear_big.png.)
Run:  python3 tools/make_items_big.py
"""
import math
from pathlib import Path

from PIL import Image

from pixkit import Sprite, OUTLINE

ROOT = Path(__file__).resolve().parent.parent
S = 64
PAL = {
    "glass": "8ea6c0", "cork": "9a6a3e", "red": "d8303a", "amber": "e8962a", "sky": "86d4f0",
    "violet": "9a5ae0", "berry": "c8283a", "blueb": "4058d0", "leaf": "4a9a3a", "stem": "6a4a2a",
    "sun": "ffc838", "bomb": "3c3650", "fuse": "8a6a40", "stone": "5a5a6a", "green": "38b060",
    "wood": "8a5a32", "brass": "c8913a", "iron": "5c6070", "flame": "ffb040", "hot": "fff0b0",
    "witch": "48c888", "ruby": "d02040", "box": "b83a30", "paper": "d8c8a0", "match": "d8b070",
    "head": "c82830", "bronze": "b8743a", "silver": "b8c0d0", "gold": "f0c040", "purple": "9a4ae8",
    "wool": "b02a30", "bwool": "3456b8", "dark": "1e1428", "leather": "8a5530", "chain": "8a92a4",
    "bone": "ddd2b6", "plate": "98a2b4", "mantle": "6a2ab0", "ermine": "f0ece4", "lace": "3a2418",
    "flare": "b03030", "spark": "9affb0", "lglass": "d88a30", "wflame": "b0ffd0",
}


def ring(s, cx, cy, rx, ry, r, mat, a0=0.0, a1=360.0, n=40):
    pts = [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
            cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]
    return s.limb(pts, r, mat)


def sparkle(s, x, y, col="fff6d0", big=False):
    s.pdot(x, y, col)
    for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        s.pdot(x + d[0], y + d[1], col)
    if big:
        for d in ((2, 0), (-2, 0), (0, 2), (0, -2)):
            s.pdot(x + d[0], y + d[1], col)


# --- potions -------------------------------------------------------------------------
def flask(s, liquid, level=36, tall=False, extra=None):
    cy, r = (40, 17) if not tall else (42, 14)
    s.poly([(27, 11), (37, 11), (37, cy - r + 3), (27, cy - r + 3)], "glass", grad=(3, 1))   # the neck
    body = s.blob(32, cy, r if not tall else 13, r, "glass")
    inner = [c for c in body if math.hypot(c[0] + 0.5 - 32, (c[1] + 0.5 - cy) * (r / r)) < r - 2.2 and c[1] >= level]
    for (x, y) in inner:   # the liquid inside, lit from within at the bottom
        p = s.px[y][x]
        t = 2 if p[1] >= 2 else 1
        if y == level:
            t = 4
        s.px[y][x] = (liquid, t + (1 if y > cy + r - 8 and abs(x - 32) < 6 else 0))
    if extra:
        extra(s, cy, r)
    for k in range(5):   # the glass's gleam, a curved streak upper left
        a = math.radians(200 + k * 12)
        s.pdot(int(32 + (r - 4) * math.cos(a)), int(cy + (r - 4) * math.sin(a)), "f4f8ff")
    s.pdot(29, 14, "f4f8ff")
    s.pdot(29, 15, "f4f8ff")
    s.poly([(25, 4), (39, 4), (38, 12), (26, 12)], "cork", grad=(4, 1))   # the cork
    s.texture("cork", 0.25, seed=4)
    s.poly([(24, 11), (40, 11), (40, 13), (24, 13)], "glass", tone=4)     # the lip


def healing_tonic(s):
    def heart(s, cy, r):
        for (x, y) in [(29, 0), (30, 0), (34, 0), (35, 0), (28, 1), (29, 1), (30, 1), (31, 1), (33, 1), (34, 1),
                       (35, 1), (36, 1), (28, 2), (29, 2), (30, 2), (31, 2), (32, 2), (33, 2), (34, 2), (35, 2),
                       (36, 2), (29, 3), (30, 3), (31, 3), (32, 3), (33, 3), (34, 3), (35, 3), (30, 4), (31, 4),
                       (32, 4), (33, 4), (34, 4), (31, 5), (32, 5), (33, 5), (32, 6)]:
            s.pdot(x, y + cy + 1, "ffd0d4")
    flask(s, "red", 34, extra=heart)


def lamp_oil(s):
    def label(s, cy, r):
        for y in range(cy - 4, cy + 3):
            for x in range(18, 47):
                p = s.px[y][x]
                if p and p[0] in ("glass", "amber"):
                    s.px[y][x] = ("paper", 3 if x < 30 else 2)
        s.pline([(24, cy - 1), (40, cy - 1)], "6a4a2a")
        s.pline([(26, cy + 1), (37, cy + 1)], "6a4a2a")
    flask(s, "amber", 32, extra=label)


def windbreak(s):
    def swirl(s, cy, r):
        for k in range(26):
            a = k * 0.42
            rr = 2 + k * 0.42
            s.pdot(int(32 + rr * math.cos(a)), int(cy + 3 + rr * 0.7 * math.sin(a)), "e8faff")
    flask(s, "sky", 30, tall=True, extra=swirl)


def seers_draught(s):
    def stars(s, cy, r):
        sparkle(s, 27, cy + 4, "f0d8ff")
        sparkle(s, 37, cy + 8, "f0d8ff")
        s.pdot(33, cy, "ffffff")
        s.pdot(25, cy + 10, "e0c0ff")
    flask(s, "violet", 33, extra=stars)


# --- found things --------------------------------------------------------------------
def berries(s, mat, crowns):
    s.limb([(33, 8), (31, 16), (24, 26)], 1.4, "stem")
    s.limb([(31, 16), (40, 24)], 1.2, "stem")
    s.limb([(32, 12), (33, 20), (34, 30)], 1.2, "stem")
    s.poly([(33, 9), (44, 4), (52, 8), (46, 14), (36, 13)], "leaf", grad=(4, 2))
    s.line([(35, 11), (50, 7)], "leaf", 1)
    for (x, y, r) in ([(22, 34, 9), (41, 33, 9), (31, 45, 10)] if not crowns else
                      [(21, 32, 8), (40, 31, 8), (28, 46, 8), (45, 46, 7), (31, 34, 7)]):
        s.blob(x, y, r, r, mat)
        s.pdot(int(x - r * 0.45), int(y - r * 0.45), "ffffff")
        s.pdot(int(x - r * 0.45) + 1, int(y - r * 0.45), "ffe8f0")
        if crowns:   # a blueberry's little star where the flower was
            s.pdot(x + 1, y + 1, "1a1840")
            s.pdot(x + 2, y + 1, "1a1840")
            s.pdot(x + 1, y + 2, "1a1840")
            s.pdot(x, y + 1, "2a2a60")
    s.glints(mat, 0.04)


def red_berry(s):
    berries(s, "berry", False)


def blue_berry(s):
    berries(s, "blueb", True)


def sunstone(s):
    for k in range(12):   # rays
        a = math.radians(k * 30 + 15)
        r0, r1 = 20, 28 if k % 2 else 25
        for t in range(r0, r1):
            s.pdot(int(32 + t * math.cos(a)), int(32 + t * math.sin(a)), "ffe890" if t < r1 - 2 else "c89030")
    pts = [(32, 12), (45, 20), (49, 32), (45, 44), (32, 52), (19, 44), (15, 32), (19, 20)]
    s.poly(pts, "sun", tone=2)
    # facets: the upper left ones catch the light
    s.poly([(32, 12), (45, 20), (39, 26), (32, 22)], "sun", tone=4, outline=False)
    s.poly([(32, 12), (32, 22), (25, 26), (19, 20)], "sun", tone=5, outline=False)
    s.poly([(19, 20), (25, 26), (24, 38), (15, 32)], "sun", tone=4, outline=False)
    s.poly([(25, 26), (39, 26), (40, 38), (24, 38)], "sun", tone=3, outline=False)
    s.poly([(39, 26), (45, 20), (49, 32), (40, 38)], "sun", tone=2, outline=False)
    s.poly([(24, 38), (40, 38), (32, 52), (19, 44)], "sun", tone=1, outline=False)
    s.poly([(40, 38), (49, 32), (45, 44), (32, 52)], "sun", tone=0, outline=False)
    sparkle(s, 27, 21, "ffffff", True)
    sparkle(s, 44, 45, "fff4c0")


def bomb(s):
    s.blob(30, 38, 19, 19, "bomb", bands=(-0.3, 0.05, 0.4, 0.75, 0.93))
    s.poly([(36, 15), (46, 11), (49, 18), (40, 22)], "iron", grad=(4, 1))   # the cap
    s.limb([(46, 13), (50, 8), (55, 7), (57, 3)], 1.3, "fuse")
    sparkle(s, 57, 3, "ffe060", True)
    s.pdot(58, 1, "ff8030")
    s.pdot(55, 1, "ffd040")
    s.pdot(60, 4, "ff8030")
    s.pdot(21, 26, "ffffff")
    s.pdot(22, 26, "c8c0e0")
    s.pdot(21, 27, "c8c0e0")
    s.glints("bomb", 0.03)


def seer_stone(s):
    s.blob(32, 33, 22, 22, "stone", bands=(-0.3, 0.05, 0.45, 0.8, 0.95))
    s.texture("stone", 0.18, seed=9)
    s.blob(32, 33, 15, 15, "green", outline=True)
    s.blob(32, 33, 11, 8, "ermine", bands=(-0.5, -0.2, 0.2, 0.7, 0.95))   # the white of the eye
    s.eye(32, 33, 6, "38d070")
    s.pdot(32, 33, "0a0a10")
    s.pdot(31, 33, "0a0a10")
    s.pdot(32, 32, "0a0a10")
    s.pdot(32, 34, "0a0a10")
    for k in range(8):   # runes round the rim
        a = math.radians(k * 45 + 22)
        x, y = int(32 + 19 * math.cos(a)), int(33 + 19 * math.sin(a))
        s.pdot(x, y, "8affb0")
        s.pdot(x + (1 if k % 2 else 0), y + (0 if k % 2 else 1), "4ad080")


def portal_flare(s):
    s.limb([(32, 30), (32, 60)], 2.2, "wood", r_end=1.4)
    s.texture("wood", 0.2, seed=2)
    ring(s, 32, 18, 14, 12, 2.6, "purple")
    s.blob(32, 18, 9, 7, "violet", outline=False, bands=(-0.9, -0.5, 0.0, 0.5, 0.9))
    for k in range(18):   # the violet swirl inside
        a = k * 0.6
        rr = 1 + k * 0.42
        s.pdot(int(32 + rr * math.cos(a)), int(18 + rr * 0.8 * math.sin(a)), "f0d8ff" if k < 6 else "c890ff")
    s.pdot(32, 18, "ffffff")
    s.poly([(28, 31), (36, 31), (35, 34), (29, 34)], "brass", grad=(4, 1))
    sparkle(s, 14, 9, "e0b0ff")
    sparkle(s, 51, 27, "c890ff")


def ladder(s):
    a, b = (14, 60), (34, 4)
    c, d = (30, 60), (50, 4)
    for i in range(7):
        t = 0.1 + i * 0.13
        p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
        q = (c[0] + (d[0] - c[0]) * t, c[1] + (d[1] - c[1]) * t)
        s.limb([p, q], 1.6, "wood")
    s.limb([a, b], 2.4, "wood")
    s.limb([c, d], 2.4, "wood")
    s.texture("wood", 0.22, seed=6)
    for i in range(7):   # pegs through the rails
        t = 0.1 + i * 0.13
        s.pdot(int(a[0] + (b[0] - a[0]) * t), int(a[1] + (b[1] - a[1]) * t), "3a2414")
        s.pdot(int(c[0] + (d[0] - c[0]) * t), int(c[1] + (d[1] - c[1]) * t), "3a2414")


# --- lanterns ------------------------------------------------------------------------
def lantern(s, frame, glass, light, bars=3, thick=False):
    ring(s, 32, 8, 6, 5, 1.4, frame, 180, 360, 16)   # the handle
    s.poly([(22, 13), (42, 13), (46, 19), (18, 19)], frame, grad=(4, 1))   # the cap
    s.poly([(28, 9), (36, 9), (37, 13), (27, 13)], frame, grad=(4, 2))
    s.poly([(19, 19), (45, 19), (45, 48), (19, 48)], glass, tone=2)
    glass = glass
    for y in range(20, 48):   # the light inside: brightest round the flame
        for x in range(20, 45):
            d = math.hypot(x - 32, (y - 36) * 0.8)
            s.pdot(x, y, glass, 5 if d < 5 else 4 if d < 8 else 3 if d < 12 else 2)
    s.poly([(32, 24), (37, 32), (36, 38), (28, 38), (27, 32)], "flame", tone=4, outline=False)
    s.poly([(32, 28), (34, 33), (34, 37), (30, 37), (30, 33)], "hot", tone=5, outline=False)
    s.poly([(29, 38), (35, 38), (35, 42), (29, 42)], "dark", tone=2, outline=False)   # the wick holder
    w = 2.2 if thick else 1.3
    for x in (19.5, 44.5):
        s.limb([(x, 19), (x, 48)], w, frame)
    if thick:   # a storm lantern's crossed guards
        s.limb([(19, 25), (45, 25)], 1.3, frame)
        s.limb([(19, 44), (45, 44)], 1.3, frame)
    s.poly([(17, 48), (47, 48), (45, 55), (19, 55)], frame, grad=(3, 0))   # the base
    s.poly([(20, 55), (44, 55), (44, 57), (20, 57)], frame, tone=0)
    for y in range(21, 46, 3):
        s.pdot(22, y, "ffffff" if y < 30 else light)


def brass_lantern(s):
    lantern(s, "brass", "lglass", "fff6d0")


def storm_lantern(s):
    lantern(s, "iron", "lglass", "ffe0a0", bars=3, thick=True)


def witchglass_lantern(s):
    PAL_SWAP = {"flame": "wflame"}
    lantern(s, "iron", "witch", "e0ffe8")
    for y in range(64):
        for x in range(64):
            p = s.px[y][x]
            if p and p[0] in PAL_SWAP:
                s.px[y][x] = (PAL_SWAP[p[0]], p[1])
            elif p and p[0] == "hot":
                s.px[y][x] = ("#", (230, 255, 236, 255))


# --- treasure and tinder -------------------------------------------------------------
def ruby(s):
    s.poly([(20, 14), (44, 14), (54, 26), (32, 56), (10, 26)], "ruby", tone=2)
    s.poly([(20, 14), (32, 14), (26, 26), (10, 26)], "ruby", tone=4, outline=False)
    s.poly([(32, 14), (44, 14), (38, 26), (26, 26)], "ruby", tone=3, outline=False)
    s.poly([(44, 14), (54, 26), (38, 26)], "ruby", tone=2, outline=False)
    s.poly([(10, 26), (26, 26), (32, 56)], "ruby", tone=3, outline=False)
    s.poly([(26, 26), (38, 26), (32, 56)], "ruby", tone=2, outline=False)
    s.poly([(38, 26), (54, 26), (32, 56)], "ruby", tone=0, outline=False)
    s.pline([(10, 26), (54, 26)], "ruby", 5)
    sparkle(s, 22, 18, "ffffff", True)
    sparkle(s, 30, 40, "ffd0d8")


def match_stick(s, a, b):
    s.limb([a, b], 1.6, "match")
    ux, uy = b[0] - a[0], b[1] - a[1]
    l = math.hypot(ux, uy)
    h = (b[0] + ux / l * 1.5, b[1] + uy / l * 1.5)
    s.blob(h[0], h[1], 3.4, 3.4, "head")


def matches(s):
    match_stick(s, (24, 34), (30, 10))
    match_stick(s, (34, 34), (40, 8))
    s.poly([(14, 22), (50, 22), (54, 26), (10, 26)], "dark", tone=3)            # the open drawer, inside
    s.poly([(10, 26), (54, 26), (54, 54), (10, 54)], "box", grad=(3, 1))       # the box
    s.poly([(16, 31), (48, 31), (48, 46), (16, 46)], "paper", grad=(3, 2))     # its label
    s.poly([(32, 34), (36, 40), (34, 43), (30, 43), (28, 40)], "flame", tone=3, outline=False)
    s.poly([(32, 38), (33, 41), (31, 41)], "hot", tone=4, outline=False)
    for x in range(12, 53, 2):   # the striker along the bottom
        s.pdot(x, 50, "3a2418")
        s.pdot(x + 1, 51, "3a2418")


def loose_match(s):
    match_stick(s, (12, 54), (48, 14))
    s.texture("match", 0.15, seed=3)
    s.pdot(48, 9, "ffffff")


def flare(s):
    s.limb([(32, 60), (32, 22)], 2.6, "wood", r_end=2.2)
    s.poly([(27, 12), (37, 12), (37, 30), (27, 30)], "flare", grad=(4, 1))   # the tube
    s.poly([(27, 18), (37, 18), (37, 21), (27, 21)], "paper", tone=3, outline=False)
    s.poly([(28, 8), (36, 8), (37, 12), (27, 12)], "iron", tone=3)
    s.blob(32, 6, 4, 3, "spark", outline=False)
    for (x, y) in [(28, 2), (36, 1), (25, 6), (40, 5), (32, 0)]:
        sparkle(s, x, y, "c8ffd0")
    s.pdot(32, 5, "ffffff")


def key(s, mat, teeth=2, gem=None):
    ring(s, 16, 32, 9, 9, 2.6, mat)
    s.limb([(25, 32), (56, 32)], 2.2, mat)
    s.poly([(44, 34), (48, 34), (48, 44), (44, 44)], mat, grad=(3, 1))
    if teeth > 1:
        s.poly([(51, 34), (55, 34), (55, 41), (51, 41)], mat, grad=(3, 1))
    s.blob(26, 32, 3, 4, mat)   # the collar
    if gem:
        s.blob(16, 32, 3.4, 3.4, gem)
        s.pdot(15, 31, "ffffff")
    s.glints(mat, 0.06)


def bronze_key(s):
    key(s, "bronze", 1)


def silver_key(s):
    key(s, "silver", 2)


def gold_key(s):
    key(s, "gold", 2, gem="ruby")


def purple_key(s):
    key(s, "purple", 2, gem="witch")
    sparkle(s, 52, 22, "e0c0ff")
    sparkle(s, 8, 18, "c890ff")


# --- armour --------------------------------------------------------------------------
SHIRT = [(20, 12), (27, 10), (32, 15), (37, 10), (44, 12), (54, 22), (48, 30), (45, 27), (45, 56), (19, 56),
         (19, 27), (16, 30), (10, 22)]


def lit_side(s, mat):
    s.shade(lambda x, y: x > 37, -1)
    s.shade(lambda x, y: x < 25, 1)


def cloak(s, mat):
    s.poly([(24, 20), (40, 20), (54, 58), (10, 58)], mat, grad=(3, 1))   # the cloak
    for x0 in (20, 30, 40):   # folds
        s.line([(x0 + 2, 26), (x0 - 2 + (x0 - 32) * 0.4, 57)], mat, 1)
        s.line([(x0 + 3, 26), (x0 - 1 + (x0 - 32) * 0.4, 57)], mat, 3)
    s.shade(lambda x, y: x > 40, -1)
    s.blob(32, 18, 14, 14, mat)                                          # the hood
    s.blob(32, 21, 8, 9, "dark", bands=(-0.5, 0.2, 0.9, 1.1, 1.2))       # in its shadow
    s.limb([(18, 16), (32, 5), (46, 16)], 1.2, mat)
    s.blob(32, 32, 3, 3, "brass")                                        # the clasp
    s.texture(mat, 0.1, seed=11)


def worn_cloak(s):
    cloak(s, "wool")


def blue_hood(s):
    cloak(s, "bwool")


def leather_vest(s):
    s.poly(SHIRT, "leather", grad=(3, 2))
    lit_side(s, "leather")
    s.poly([(29, 15), (35, 15), (33, 56), (31, 56)], "dark", tone=1, outline=False)   # the open front
    for y in range(20, 54, 6):   # laces
        s.pline([(28, y), (36, y + 4)], "lace", 2)
        s.pline([(36, y), (28, y + 4)], "lace", 2)
    for (a, b) in [((21, 15), (21, 54)), ((43, 15), (43, 54))]:   # stitching
        for y in range(a[1], b[1], 3):
            s.pdot(a[0], y, "e0b880")
    s.poly([(19, 50), (45, 50), (45, 54), (19, 54)], "lace", tone=3, outline=False)   # a belt
    s.poly([(30, 49), (34, 49), (34, 55), (30, 55)], "brass", tone=3)
    s.texture("leather", 0.12, seed=7)


def chain_shirt(s):
    s.poly(SHIRT, "chain", grad=(3, 2))
    lit_side(s, "chain")
    for y in range(64):   # the rings
        for x in range(64):
            p = s.px[y][x]
            if p and p[0] == "chain":
                u, v = (x + (2 if (y // 3) % 2 else 0)) % 4, y % 3
                if v == 2 or u == 3:
                    s.px[y][x] = ("chain", max(0, p[1] - 2))
                elif u == 0 and v == 0:
                    s.px[y][x] = ("chain", min(5, p[1] + 2))
    s.poly([(26, 9), (38, 9), (36, 14), (28, 14)], "leather", grad=(3, 1))   # the collar
    s.poly([(19, 52), (45, 52), (45, 57), (19, 57)], "leather", grad=(3, 1))


def bone_mail(s):
    s.poly(SHIRT, "lace", grad=(3, 1))
    s.limb([(32, 14), (32, 54)], 2.2, "bone")   # the spine
    for i in range(6):
        y = 18 + i * 6
        w = 13 - abs(i - 2) * 1.2
        for side in (-1, 1):
            s.limb([(32 + side * 2, y), (32 + side * w * 0.7, y + 1), (32 + side * w, y + 4)], 1.6, "bone",
                   r_end=1.1)
    for side in (-1, 1):   # leather straps over the shoulders
        s.limb([(32 + side * 6, 12), (32 + side * 13, 16), (32 + side * 18, 22)], 1.5, "leather")
    s.texture("bone", 0.1, seed=13)


def iron_plate(s):
    s.poly([(4, 24), (10, 14), (20, 14), (24, 26), (12, 30)], "plate", grad=(4, 1))     # pauldrons
    s.poly([(60, 24), (54, 14), (44, 14), (40, 26), (52, 30)], "plate", grad=(3, 0))
    s.pline([(6, 23), (12, 27), (22, 24)], "plate", 1)
    s.pline([(58, 23), (52, 27), (42, 24)], "plate", 0)
    s.poly([(18, 16), (46, 16), (48, 34), (42, 50), (32, 56), (22, 50), (16, 34)], "plate", grad=(4, 1))
    s.shade(lambda x, y: x > 33, -1)
    s.pline([(32, 17), (32, 54)], "plate", 5)          # the ridge
    s.pline([(33, 17), (33, 54)], "plate", 1)
    s.poly([(26, 14), (38, 14), (35, 20), (29, 20)], "dark", tone=2)   # the neck
    for (x, y) in [(20, 20), (44, 20), (19, 34), (45, 34), (24, 47), (40, 47)]:
        s.pdot(x, y, "e8eef8")
        s.pdot(x + 1, y + 1, "3a3a4a")
    s.pline([(18, 42), (32, 47), (46, 42)], "plate", 1)
    s.glints("plate", 0.04)


def kings_mantle(s):
    s.poly([(22, 22), (42, 22), (56, 60), (8, 60)], "mantle", grad=(3, 1))
    for x0 in (22, 32, 42):
        s.line([(x0, 30), (x0 + (x0 - 32) * 0.5, 59)], "mantle", 1)
    s.shade(lambda x, y: x > 40, -1)
    s.poly([(8, 56), (56, 56), (56, 60), (8, 60)], "ermine", tone=3)   # ermine hem
    s.blob(32, 28, 20, 8, "ermine", flat=0.8)                         # ermine collar
    for (x, y) in [(18, 27), (26, 31), (36, 30), (45, 27), (14, 58), (26, 58), (38, 58), (50, 58)]:
        s.pdot(x, y, "1a1420")
        s.pdot(x, y + 1, "1a1420")
    # the hollow crown, resting on it
    s.poly([(20, 6), (25, 12), (29, 3), (32, 10), (35, 3), (39, 12), (44, 6), (43, 21), (21, 21)], "gold",
           grad=(4, 1))
    s.poly([(21, 17), (43, 17), (43, 21), (21, 21)], "gold", tone=3)
    for (x, c) in [(26, "ruby"), (32, "witch"), (38, "ruby")]:
        s.blob(x, 18.5, 1.8, 1.8, c, outline=False)
        s.pdot(x - 1, 18, "ffffff")
    s.glints("gold", 0.08)


ORDER = ["worn_cloak", "blue_hood", "leather_vest", "chain_shirt", "bone_mail", "iron_plate", "kings_mantle",
         "healing_tonic", "lamp_oil", "red_berry", "blue_berry", "sunstone", "bomb", "windbreak",
         "seers_draught", "seer_stone", "portal_flare", "ladder", "brass_lantern", "storm_lantern",
         "witchglass_lantern", "ruby", "matches", "loose_match", "flare", "bronze_key", "silver_key",
         "gold_key", "purple_key"]


def main():
    sheet = Image.new("RGBA", (S * len(ORDER), S), (0, 0, 0, 0))
    for i, name in enumerate(ORDER):
        s = Sprite(S, S, grain=0.08, cast=True)
        globals()[name](s)
        sheet.paste(s.image(PAL), (i * S, 0))
    sheet.save(ROOT / "assets" / "items_big.png")
    print("wrote %d items at 64 x 64" % len(ORDER))
    print("ORDER:", ", ".join('"%s": %d' % (n, i) for i, n in enumerate(ORDER)))


if __name__ == "__main__":
    main()
