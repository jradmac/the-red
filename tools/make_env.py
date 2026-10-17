"""Builds assets/env.png: the detailed environment tileset.

Everything is generated procedurally (stone layouts, bevels, noise, moss
fringes...) so it's easy to tweak a palette or a size and re-run:

    python3 tools/make_env.py

Atlas layout (16x16 cells; row, col). world.gd mirrors these constants.
  row 0: floor flagstones, 8 variants
  row 1: moss x4, tall grass x2, dirt x2
  row 2: moss fringe over stone: N, E, S, W, then corners NE, SE, SW, NW
  row 3: wall faces, 8 variants
  row 4: wall tops, by open neighbours (bit 1 = N, 2 = E, 4 = W): 0..7
  row 5: water frames x4, shore overlays N, E, S, W
  row 6: floor decals x8 (pebbles, crack, bones, leaves, puddle, scratches, roots, cobweb)
  row 7: ambient-occlusion overlays: N, E, W, NE, NW, S(lip)
"""
from pathlib import Path
import math
import random

from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets"
T = 16


def hx(h, a=255):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mix(c1, c2, t):
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(4))


def shade(c, f):
    return (max(0, min(255, int(c[0] * f))), max(0, min(255, int(c[1] * f))),
            max(0, min(255, int(c[2] * f))), c[3])


BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def dith(x, y):
    return (BAYER4[y % 4][x % 4] + 0.5) / 16.0


class Tile:
    def __init__(self, fill=(0, 0, 0, 0)):
        self.img = Image.new("RGBA", (T, T), fill)
        self.px = self.img.load()

    def set(self, x, y, c):
        if 0 <= x < T and 0 <= y < T:
            if c[3] == 255:
                self.px[x, y] = c
            else:
                base = self.px[x, y]
                a = c[3] / 255.0
                if base[3] == 0:
                    self.px[x, y] = c
                else:
                    self.px[x, y] = (int(base[0] + (c[0] - base[0]) * a), int(base[1] + (c[1] - base[1]) * a),
                                     int(base[2] + (c[2] - base[2]) * a), max(base[3], c[3]))

    def get(self, x, y):
        return self.px[x % T, y % T]


# ---------------------------------------------------------------------------
# Palettes. Albedo is fairly bright: the lighting shader supplies the gloom.
# ---------------------------------------------------------------------------
STONE = dict(mortar=hx("26222f"), mortar_lt=hx("332e3d"),
             bases=[hx("7d7689"), hx("736d80"), hx("837a86"), hx("6e6a7e"), hx("7a7280")],
             hi=hx("a39cae"), sh=hx("4e485c"), speck=hx("5f586c"), speck_lt=hx("968fa3"),
             crack=hx("2b2633"))
MOSS = dict(base=hx("3f6a4a"), dark=hx("2f523b"), deep=hx("24402f"), mid=hx("4f8058"),
            hi=hx("74a96f"), tip=hx("9fcf86"), flower=hx("c9d8ff"), flower2=hx("f2d2ff"))
DIRT = dict(base=hx("6a5848"), dark=hx("53443a"), hi=hx("85705c"), peb=hx("8f8a96"))
WALLC = dict(mortar=hx("1a1722"), block=hx("5d566c"), block2=hx("564f66"), block3=hx("625a6b"),
             hi=hx("8b839c"), sh=hx("3a3449"), cap=hx("2a2535"), cap_hi=hx("8f88a3"),
             cap_mid=hx("514a62"), base=hx("100e15"), top=hx("1c1924"), top2=hx("221e2b"),
             top3=hx("17141e"), rim=hx("6c6482"), rim2=hx("413a52"))
WATER = dict(deep=hx("142338"), mid=hx("1c3350"), lt=hx("2c4f73"), hi=hx("5f8fb8"),
             spark=hx("bfe3ff"), foam=hx("9cc4dc"), bank=hx("0b1320"))


# ---------------------------------------------------------------------------
# Floor: irregular flagstones with bevels, speckle, chips and cracks.
# ---------------------------------------------------------------------------
LAYOUTS = [
    [(0, 0, 7, 6), (7, 0, 9, 4), (7, 4, 4, 5), (11, 4, 5, 5), (0, 6, 7, 5), (7, 9, 9, 7), (0, 11, 7, 5)],
    [(0, 0, 5, 5), (5, 0, 6, 7), (11, 0, 5, 7), (0, 5, 5, 6), (5, 7, 11, 4), (0, 11, 9, 5), (9, 11, 7, 5)],
    [(0, 0, 9, 5), (9, 0, 7, 8), (0, 5, 5, 6), (5, 5, 4, 6), (9, 8, 7, 8), (0, 11, 9, 5)],
    [(0, 0, 6, 8), (6, 0, 10, 5), (6, 5, 5, 6), (11, 5, 5, 6), (0, 8, 6, 8), (6, 11, 10, 5)],
    [(0, 0, 8, 8), (8, 0, 8, 8), (0, 8, 8, 8), (8, 8, 8, 8)],
    [(0, 0, 4, 4), (4, 0, 8, 6), (12, 0, 4, 6), (0, 4, 4, 8), (4, 6, 6, 6), (10, 6, 6, 10), (0, 12, 10, 4)],
    [(0, 0, 11, 6), (11, 0, 5, 10), (0, 6, 6, 10), (6, 6, 5, 5), (6, 11, 5, 5), (11, 10, 5, 6)],
    [(0, 0, 7, 7), (7, 0, 9, 5), (7, 5, 9, 6), (0, 7, 7, 9), (7, 11, 9, 5)],
]


def flagstone(t, rnd, x0, y0, w, h, base):
    # Stones are inset by one pixel of mortar on the right/bottom.
    w -= 1
    h -= 1
    for y in range(h):
        for x in range(w):
            # gentle top-left -> bottom-right gradient for a rounded, 3D read
            g = 1.06 - 0.12 * ((x / max(1, w - 1)) * 0.5 + (y / max(1, h - 1)) * 0.5)
            c = shade(base, g + (rnd.random() - 0.5) * 0.06)
            t.set(x0 + x, y0 + y, c)
    # bevel
    for x in range(w):
        t.set(x0 + x, y0, STONE["hi"])
        t.set(x0 + x, y0 + h - 1, STONE["sh"])
    for y in range(h):
        t.set(x0, y0 + y, mix(STONE["hi"], base, 0.35))
        t.set(x0 + w - 1, y0 + y, STONE["sh"])
    # rounded corners
    for (cx, cy) in [(x0, y0), (x0 + w - 1, y0), (x0, y0 + h - 1), (x0 + w - 1, y0 + h - 1)]:
        t.set(cx, cy, STONE["mortar_lt"])
    # speckle
    for _ in range(max(1, (w * h) // 9)):
        sx, sy = x0 + 1 + rnd.randrange(max(1, w - 2)), y0 + 1 + rnd.randrange(max(1, h - 2))
        t.set(sx, sy, STONE["speck"] if rnd.random() < 0.65 else STONE["speck_lt"])
    # chipped edge
    if w > 3 and rnd.random() < 0.35:
        cx = x0 + 1 + rnd.randrange(w - 2)
        t.set(cx, y0 + h - 1, STONE["mortar_lt"])
        t.set(cx, y0 + h - 2, STONE["sh"])


def floor_tile(v):
    rnd = random.Random(100 + v)
    t = Tile(STONE["mortar"])
    for (x, y, w, h) in LAYOUTS[v]:
        flagstone(t, rnd, x, y, w, h, rnd.choice(STONE["bases"]))
    if v in (2, 5):  # a crack running across a stone
        x, y = 3 + rnd.randrange(6), 2 + rnd.randrange(4)
        for i in range(7):
            t.set(x, y, STONE["crack"])
            t.set(x, y + 1, STONE["hi"])
            x += 1
            y += rnd.choice([0, 1, 1])
    if v == 6:  # weeds in the mortar
        for (x, y, c) in [(6, 10, MOSS["mid"]), (5, 9, MOSS["hi"]), (7, 9, MOSS["mid"]), (6, 8, MOSS["tip"])]:
            t.set(x, y, c)
    return t.img


# ---------------------------------------------------------------------------
# Moss / grass
# ---------------------------------------------------------------------------
def blade(t, x, y, ln, rnd):
    """A single grass blade from (x, y) upward."""
    lean = rnd.choice([-1, 0, 0, 1])
    for i in range(ln):
        px = x + (lean if i >= ln - 1 else 0)
        c = MOSS["tip"] if i == ln - 1 else (MOSS["hi"] if i == ln - 2 else MOSS["mid"])
        t.set(px % T, (y - i) % T, c)
    t.set(x % T, (y + 1) % T, MOSS["deep"])


def tuft(t, x, y):
    """A little HGSS-style grass tuft: three blades in a 'w' shape."""
    for (dx, dy, c) in [(0, 0, "mid"), (0, -1, "hi"), (2, 0, "mid"), (2, -1, "hi"), (2, -2, "tip"),
                        (4, 0, "mid"), (4, -1, "hi"), (1, 1, "deep"), (3, 1, "deep"), (1, 0, "dark"), (3, 0, "dark")]:
        t.set((x + dx) % T, (y + dy) % T, MOSS[c])


def moss_tile(v):
    rnd = random.Random(200 + v)
    t = Tile(MOSS["base"])
    # soft, tileable two-tone patches instead of pixel noise
    ph = rnd.random() * 6
    for y in range(T):
        for x in range(T):
            n = math.sin((x / 16.0) * math.tau + ph) + math.sin((y / 16.0) * math.tau * 2 + ph * 2) \
                + 0.6 * math.sin(((x + y) / 16.0) * math.tau * 3)
            if n > 1.0 + dith(x, y) * 0.6:
                t.set(x, y, MOSS["mid"])
            elif n < -1.2 - dith(x, y) * 0.6:
                t.set(x, y, MOSS["dark"])
    spots = [(2, 5), (9, 3), (6, 12), (12, 10)]
    for (x, y) in spots[: 2 + v % 3]:
        tuft(t, x + rnd.randrange(-1, 2), y + rnd.randrange(-1, 2))
    if v == 1:  # pale spore flowers
        for _ in range(2):
            x, y = rnd.randrange(1, 15), rnd.randrange(1, 15)
            for (dx, dy) in [(0, -1), (-1, 0), (1, 0), (0, 1)]:
                t.set(x + dx, y + dy, MOSS["flower"])
            t.set(x, y, hx("ffe9a8"))
    if v == 3:
        for _ in range(3):
            t.set(rnd.randrange(T), rnd.randrange(T), MOSS["flower2"])
    return t.img


def tall_grass_tile(v):
    rnd = random.Random(300 + v)
    t = Tile()
    t.img.paste(moss_tile(2), (0, 0))
    t.px = t.img.load()
    # dense clumps of tall blades, darker at the root (gives it volume)
    for i in range(22):
        bx = (i * 7 + rnd.randrange(3)) % T
        base_y = 15 - (i % 3) * 5 + rnd.randrange(2)
        ln = rnd.randrange(5, 9)
        lean = rnd.choice([-1, 1])
        for k in range(ln):
            f = k / ln
            px = bx + int(lean * f * f * 2.5)
            c = MOSS["dark"] if f < 0.25 else (MOSS["mid"] if f < 0.6 else (MOSS["hi"] if f < 0.85 else MOSS["tip"]))
            if 0 <= base_y - k < T:
                t.set(px % T, base_y - k, c)
                t.set((px + 1) % T, base_y - k, hx("17301f"))
    return t.img


def dirt_tile(v):
    rnd = random.Random(400 + v)
    t = Tile(DIRT["base"])
    for y in range(T):
        for x in range(T):
            n = rnd.random()
            if n < 0.2:
                t.set(x, y, DIRT["dark"])
            elif n < 0.28:
                t.set(x, y, DIRT["hi"])
    for _ in range(3):
        x, y = rnd.randrange(1, 15), rnd.randrange(1, 15)
        t.set(x, y, DIRT["peb"])
        t.set(x, y + 1, DIRT["dark"])
    return t.img


def moss_fringe(side):
    """Moss creeping onto stone from one side (or a corner). Transparent elsewhere."""
    rnd = random.Random(500 + hash(side) % 97)
    t = Tile()
    for y in range(T):
        for x in range(T):
            if side == "N":
                d = y
            elif side == "S":
                d = 15 - y
            elif side == "E":
                d = 15 - x
            elif side == "W":
                d = x
            else:   # corners: distance from that corner
                cx = 15 if "E" in side else 0
                cy = 0 if "N" in side else 15
                d = math.hypot(x - cx, y - cy) - 1.5
            along = x if side in "NS" else y
            edge = (4.0 + 1.8 * math.sin(along * 1.1 + len(side)) + 1.2 * math.sin(along * 2.7)) if len(side) == 1 else 4.5
            if d < edge - 1:
                t.set(x, y, MOSS["base"] if rnd.random() > 0.2 else MOSS["dark"])
            elif d < edge:
                # the grass's edge: a lit lip where it faces up, dark where it drops away
                t.set(x, y, MOSS["hi"] if side in ("S", "SE", "SW") else MOSS["deep"])
            elif d < edge + 2 and side in ("N", "W", "NW", "NE"):
                # a little step down onto the bare ground: shadow just below the grass
                t.set(x, y, (10, 8, 6, 110 if d < edge + 1 else 55))
    for _ in range(5):
        if side == "N":
            x, y = rnd.randrange(T), rnd.randrange(2, 5)
        elif side == "S":
            x, y = rnd.randrange(T), 15 - rnd.randrange(0, 2)
        elif side == "E":
            x, y = 15 - rnd.randrange(0, 3), rnd.randrange(3, T)
        elif side == "W":
            x, y = rnd.randrange(0, 3), rnd.randrange(3, T)
        else:
            continue
        blade(t, x, y, 2, rnd)
    return t.img


# ---------------------------------------------------------------------------
# Walls
# ---------------------------------------------------------------------------
def wall_face(v):
    rnd = random.Random(600 + v)
    t = Tile(WALLC["mortar"])
    # cap: the lip of the wall top, catching light
    for x in range(T):
        t.set(x, 0, WALLC["cap"])
        t.set(x, 1, WALLC["cap_hi"])
        t.set(x, 2, WALLC["cap_mid"])
        t.set(x, 3, WALLC["sh"])
    # two courses of big blocks, offset like masonry
    courses = [(4, 6), (10, 5)]
    for r, (y0, hgt) in enumerate(courses):
        x = -rnd.randrange(2, 6) if r else 0
        while x < T:
            w = rnd.randrange(6, 10)
            base = rnd.choice([WALLC["block"], WALLC["block2"], WALLC["block3"]])
            for yy in range(hgt - 1):
                for xx in range(w - 1):
                    px = x + xx
                    if not 0 <= px < T:
                        continue
                    # light from above: blocks darken toward the floor
                    g = 1.12 - 0.35 * ((y0 + yy) / 15.0) + (rnd.random() - 0.5) * 0.07
                    c = shade(base, g)
                    if yy == 0:
                        c = mix(c, WALLC["hi"], 0.55)
                    elif yy == hgt - 2:
                        c = mix(c, WALLC["sh"], 0.6)
                    if xx == 0:
                        c = mix(c, WALLC["hi"], 0.25)
                    elif xx == w - 2:
                        c = mix(c, WALLC["sh"], 0.5)
                    t.set(px, y0 + yy, c)
            x += w
    # contact shadow at the foot
    for x in range(T):
        t.set(x, 15, WALLC["base"])
        t.set(x, 14, mix(t.get(x, 14), WALLC["base"], 0.5))
    if v == 1:  # crack
        x, y = 5 + rnd.randrange(5), 4
        while y < 15:
            t.set(x, y, WALLC["base"])
            t.set(x + 1, y, mix(t.get(x + 1, y), WALLC["hi"], 0.3))
            y += 1
            x += rnd.choice([-1, 0, 1])
    if v == 2:  # moss dripping from the lip
        for x in range(T):
            ln = int(2 + 3 * abs(math.sin(x * 1.7)) + rnd.random() * 2)
            for y in range(2, 2 + ln):
                t.set(x, y, MOSS["mid"] if y < 1 + ln else MOSS["dark"])
            t.set(x, 2, MOSS["hi"])
    if v == 3:  # roots
        for sx in (3, 11):
            x = sx
            for y in range(3, 14):
                t.set(x, y, hx("3d2b22"))
                t.set(x + 1, y, hx("5b4031"))
                if rnd.random() < 0.3:
                    x += rnd.choice([-1, 1])
    if v == 4:  # missing block: dark hole
        for y in range(5, 9):
            for x in range(6, 11):
                t.set(x, y, hx("08070b"))
        for x in range(6, 11):
            t.set(x, 9, WALLC["hi"])
    if v == 5:  # rusty chain
        for y in range(3, 13):
            c = hx("7a5a40") if y % 2 else hx("a5774c")
            t.set(8, y, c)
            t.set(7 + (y % 2) * 2, y, hx("4d3626"))
    if v == 6:  # carved rune, faintly glowing
        for (x, y) in [(7, 6), (8, 6), (9, 6), (8, 7), (8, 8), (7, 9), (9, 9), (6, 10), (10, 10)]:
            t.set(x, y, hx("7a6aa8"))
    return t.img


def wall_top(mask):
    """Top of a wall seen from above. mask bits: 1 = open to N, 2 = open to E, 4 = open to W."""
    rnd = random.Random(700 + mask)
    t = Tile(WALLC["top"])
    for y in range(T):
        for x in range(T):
            n = rnd.random()
            if n < 0.25:
                t.set(x, y, WALLC["top2"])
            elif n < 0.4:
                t.set(x, y, WALLC["top3"])
    # rough rubble bumps
    for _ in range(4):
        x, y = rnd.randrange(1, 14), rnd.randrange(1, 14)
        t.set(x, y, hx("2b2737"))
        t.set(x + 1, y, hx("2b2737"))
        t.set(x, y + 1, hx("121017"))
    if mask & 1:
        for x in range(T):
            t.set(x, 0, WALLC["rim"])
            t.set(x, 1, WALLC["rim2"])
    if mask & 2:
        for y in range(T):
            t.set(15, y, WALLC["rim"])
            t.set(14, y, WALLC["rim2"])
    if mask & 4:
        for y in range(T):
            t.set(0, y, WALLC["rim"])
            t.set(1, y, WALLC["rim2"])
    return t.img


# ---------------------------------------------------------------------------
# Water
# ---------------------------------------------------------------------------
def water_tile(frame):
    t = Tile()
    for y in range(T):
        for x in range(T):
            w = math.sin((x + frame * 4) * 0.8 + y * 0.45) + math.sin((y - frame * 4) * 0.7 - x * 0.3)
            if w > 1.3:
                c = WATER["lt"]
            elif w > 0.4:
                c = WATER["mid"]
            else:
                c = WATER["deep"]
            t.set(x, y, c)
    rnd = random.Random(800 + frame)
    for _ in range(3):
        x, y = rnd.randrange(T), rnd.randrange(T)
        t.set(x, y, WATER["spark"])
        t.set(x + 1, y, WATER["hi"])
    return t.img


def shore(side):
    t = Tile()
    for i in range(T):
        for d in range(4):
            a = [210, 140, 80, 30][d]
            c = (WATER["bank"][0], WATER["bank"][1], WATER["bank"][2], a)
            if side == "N":
                t.set(i, d, c)
            elif side == "S":
                t.set(i, 15 - d, c)
            elif side == "E":
                t.set(15 - d, i, c)
            else:
                t.set(d, i, c)
        foam = WATER["foam"] if i % 5 else WATER["spark"]
        if (i * 7) % 3:
            if side == "N":
                t.set(i, 2 + (i % 2), foam)
            elif side == "S":
                t.set(i, 13 - (i % 2), foam)
            elif side == "E":
                t.set(13 - (i % 2), i, foam)
            else:
                t.set(2 + (i % 2), i, foam)
    return t.img


# ---------------------------------------------------------------------------
# Decals (transparent overlays on floor tiles)
# ---------------------------------------------------------------------------
def decal(kind):
    rnd = random.Random(900 + kind)
    t = Tile()
    if kind == 0:  # pebbles
        for _ in range(4):
            x, y = rnd.randrange(2, 13), rnd.randrange(2, 13)
            t.set(x, y, hx("9a94a6"))
            t.set(x + 1, y, hx("736d80"))
            t.set(x, y + 1, hx("26222f", 160))
    elif kind == 1:  # long crack
        x, y = 1, 4 + rnd.randrange(6)
        while x < 15:
            t.set(x, y, STONE["crack"])
            t.set(x, y + 1, hx("a39cae", 120))
            x += 1
            y += rnd.choice([-1, 0, 0, 1])
    elif kind == 2:  # scattered bones
        for (x, y) in [(3, 9), (4, 9), (5, 9), (6, 9), (7, 10)]:
            t.set(x, y, hx("e8dfc8"))
            t.set(x, y + 1, hx("8a826f"))
        t.set(2, 8, hx("e8dfc8"))
        t.set(2, 10, hx("e8dfc8"))
        for (x, y) in [(10, 5), (11, 5), (11, 6), (12, 6)]:
            t.set(x, y, hx("d8cfb8"))
            t.set(x, y + 1, hx("6f685a"))
    elif kind == 3:  # dead leaves
        for _ in range(5):
            x, y = rnd.randrange(1, 14), rnd.randrange(1, 14)
            c = rnd.choice([hx("8a5a32"), hx("a8743a"), hx("6e4a2c")])
            t.set(x, y, c)
            t.set(x + 1, y, c)
            t.set(x, y + 1, shade(c, 0.6))
    elif kind == 4:  # puddle
        for y in range(5, 11):
            for x in range(3, 13):
                if ((x - 8) / 5.0) ** 2 + ((y - 8) / 3.0) ** 2 < 1:
                    t.set(x, y, hx("1d2c44", 210))
        for x in range(5, 9):
            t.set(x, 6, hx("6f9cc4", 200))
    elif kind == 5:  # claw scratches
        for k in range(3):
            for i in range(6):
                t.set(4 + k * 3 + i // 2, 4 + i, hx("2b2633"))
                t.set(5 + k * 3 + i // 2, 4 + i, hx("a39cae", 120))
    elif kind == 6:  # roots
        x, y = 0, 6
        for i in range(16):
            t.set(x, y, hx("4a3428"))
            t.set(x, y + 1, hx("2a1d17", 180))
            x += 1
            if rnd.random() < 0.3:
                y += rnd.choice([-1, 1])
    elif kind == 7:  # cobweb in the top-left corner (used under N+W walls)
        for i in range(9):
            t.set(i, 0, hx("d8d4e8", 150))
            t.set(0, i, hx("d8d4e8", 150))
            t.set(i, i, hx("d8d4e8", 130))
        for r in (3, 6):
            for i in range(r + 1):
                t.set(i, r - i, hx("d8d4e8", 110))
    return t.img


# ---------------------------------------------------------------------------
# Ambient occlusion overlays (dithered so they stay pixel-art)
# ---------------------------------------------------------------------------
def ao(side):
    """Cast shadows. The light comes from the upper left, so a wall to the
    north throws a long shadow down onto the floor, a wall to the west a
    shadow to the right; walls to the east barely shade at all."""
    t = Tile()
    for y in range(T):
        for x in range(T):
            if side == "N":      # long shadow, its far edge slanting (sun from the left)
                reach = 9.0 + (x / 15.0) * 3.0
                d = y / reach
                hard = 0.55
            elif side == "E":
                d = (15 - x) / 1.5
                hard = 0.25
            elif side == "W":
                d = x / 6.0
                hard = 0.5
            elif side == "NE":
                d = math.hypot((15 - x) * 1.6, y) / 5.0
                hard = 0.3
            elif side == "NW":   # the shadow wraps round the corner
                d = math.hypot(x * 0.9, y * 0.8) / 8.0
                hard = 0.55
            else:  # S: a thin dark line where the floor meets a wall top below
                d = (15 - y) / 2.5
                hard = 0.35
            a = max(0.0, 1.0 - d)
            if a > dith(x, y) * 0.5:
                t.set(x, y, (8, 6, 18, int(255 * hard * (0.55 + 0.45 * a))))
    return t.img


# ---------------------------------------------------------------------------
# Doors (16 x 24 each, feet on the tile's bottom edge) -> assets/doors.png
#   per colour (bronze, silver, gold): front (N-S corridor), side (E-W corridor)
#   then: open front, open side
# ---------------------------------------------------------------------------
METAL = {
    "bronze": (hx("c8803c"), hx("8a5222"), hx("f2b878")),
    "silver": (hx("a9b3c6"), hx("677086"), hx("eef4ff")),
    "gold": (hx("e6b640"), hx("9c7414"), hx("fff0a0")),
}
WOOD = dict(base=hx("6a4630"), dark=hx("4a2f20"), hi=hx("8a5e40"), line=hx("33201a"))


def _img(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, img.load()


def _stone_px(x, y, rnd):
    c = rnd.choice([WALLC["block"], WALLC["block2"], WALLC["block3"]])
    return shade(c, 1.1 - y / 40.0)


def door_front(metal, opened=False):
    img, px = _img(16, 24)
    rnd = random.Random(1)
    # stone arch frame
    for y in range(24):
        for x in range(16):
            inside = 2 <= x <= 13 and y >= 4 and not (y < 6 and (x < 4 or x > 11)) and not (y == 4 and (x < 5 or x > 10))
            if not inside:
                c = _stone_px(x, y, rnd)
                if y in (0, 8, 16) or x in (0, 15):
                    c = WALLC["sh"]
                if y in (1, 9, 17):
                    c = mix(c, WALLC["hi"], 0.4)
                px[x, y] = c
            elif opened:
                px[x, y] = hx("0b090f")   # dark passage beyond
            else:
                # vertical planks
                c = WOOD["base"]
                if (x - 2) % 3 == 0:
                    c = WOOD["line"]
                elif (x - 2) % 3 == 1:
                    c = WOOD["hi"]
                c = shade(c, 1.05 - (y - 4) / 50.0)
                px[x, y] = c
    for x in range(16):  # arch outline + floor contact
        px[x, 23] = WALLC["base"]
    if opened:
        for y in range(6, 23):   # the door leaf swung open, seen edge-on
            px[3, y] = WOOD["hi"]
            px[4, y] = WOOD["dark"]
        return img
    m, md, mh = metal
    for by in (8, 18):    # iron/metal bands with rivets
        for x in range(2, 14):
            px[x, by] = mh if x % 4 == 0 else m
            px[x, by + 1] = md
    for (x, y) in [(7, 12), (8, 12), (7, 13), (8, 13), (7, 14), (8, 14), (6, 13), (9, 13)]:
        px[x, y] = m
    px[7, 11] = mh
    px[8, 11] = mh
    px[7, 13] = hx("0b090f")
    px[7, 14] = hx("0b090f")
    px[8, 13] = md
    # ring handle
    for (x, y) in [(10, 14), (11, 15), (10, 16), (9, 15)]:
        px[x, y] = md
    return img


def door_side(metal, opened=False):
    """Seen edge-on from the side, in an east-west corridor."""
    img, px = _img(16, 24)
    rnd = random.Random(2)
    # posts set into the walls above and below: top cap + a sill at the floor
    for y in range(0, 9):
        for x in range(4, 12):
            px[x, y] = _stone_px(x, y, rnd)
        px[4, y] = WALLC["sh"]
        px[11, y] = WALLC["sh"]
    for x in range(4, 12):
        px[x, 0] = WALLC["cap_hi"]
        px[x, 8] = WALLC["sh"]
    for x in range(4, 12):
        px[x, 22] = WALLC["block"]
        px[x, 23] = WALLC["base"]
    if opened:
        for y in range(9, 22):
            px[4, y] = WOOD["dark"]
            px[11, y] = WOOD["dark"]
        return img
    m, md, mh = metal
    for y in range(9, 22):
        for x in range(5, 11):
            c = WOOD["base"] if x < 9 else WOOD["dark"]
            if x == 5:
                c = WOOD["hi"]
            px[x, y] = shade(c, 1.05 - (y - 9) / 40.0)
    for by in (11, 18):
        for x in range(5, 11):
            px[x, by] = mh if x == 5 else (m if x < 9 else md)
    px[5, 14] = m
    px[5, 15] = hx("0b090f")
    return img


def doors_sheet():
    frames = []
    for col in ["bronze", "silver", "gold"]:
        frames += [door_front(METAL[col]), door_side(METAL[col])]
    frames += [door_front(METAL["bronze"], True), door_side(METAL["bronze"], True)]
    sheet = Image.new("RGBA", (16 * len(frames), 24), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * 16, 0))
    return sheet


# ---------------------------------------------------------------------------
# LANDSCAPES (rows 8-15): forest, courtyard, mountain, water features, props
# ---------------------------------------------------------------------------
FOREST = dict(dirt=hx("5a4636"), dirt_dk=hx("46362a"), dirt_lt=hx("735a44"), leaf1=hx("8a5a2a"), leaf2=hx("6a7a30"),
              can=hx("234a2c"), can_dk=hx("17331f"), can_mid=hx("2f5f38"), can_hi=hx("4c8a4a"), can_tip=hx("74b064"),
              trunk=hx("4a3326"), trunk_hi=hx("6a4a34"), trunk_dk=hx("2c1e17"))
COURT = dict(stone=hx("a89c88"), stone2=hx("9c907e"), stone3=hx("b4a892"), hi=hx("cfc3ac"), sh=hx("7a6f60"),
             joint=hx("4e463e"), brick=hx("8c7f6e"), brick2=hx("98897a"), brick_hi=hx("bcae98"), brick_sh=hx("625848"),
             mortar=hx("3a332c"), top=hx("554c42"), top2=hx("4a423a"), rim=hx("c8bca6"), ivy=hx("3e7a44"), ivy_hi=hx("62a65e"))
MTN = dict(grav=hx("6e6258"), grav2=hx("62574e"), grav_lt=hx("857868"), peb=hx("9a8e80"), peb_dk=hx("4a4038"),
           rock=hx("7a6c60"), rock2=hx("6a5e54"), rock_hi=hx("a6988a"), rock_sh=hx("443a34"), rock_dk=hx("2e2824"),
           lichen=hx("8a9a5a"), top=hx("564a42"), top2=hx("4a4038"), top_hi=hx("8a7c6e"))


def _noise_fill(t, rnd, cols, weights):
    for y in range(T):
        for x in range(T):
            r = rnd.random()
            acc = 0
            for c, wgt in zip(cols, weights):
                acc += wgt
                if r < acc:
                    t.set(x, y, c)
                    break


def forest_ground(v):
    rnd = random.Random(1000 + v)
    if v < 2:   # dirt + leaf litter (forest '.')
        t = Tile(FOREST["dirt"])
        _noise_fill(t, rnd, [FOREST["dirt_dk"], FOREST["dirt_lt"]], [0.18, 0.1])
        for _ in range(6 + v * 3):
            x, y = rnd.randrange(T), rnd.randrange(T)
            c = rnd.choice([FOREST["leaf1"], FOREST["leaf2"], hx("a0702c")])
            t.set(x, y, c)
            t.set(x + 1, y, shade(c, 0.8))
        for _ in range(2):
            x, y = rnd.randrange(1, 15), rnd.randrange(1, 15)
            t.set(x, y, hx("8a8494"))
            t.set(x, y + 1, FOREST["dirt_dk"])
        return t.img
    t = Tile()   # lush grass (forest ',')
    t.img.paste(moss_tile(v - 2 + (1 if v == 3 else 0)), (0, 0))
    t.px = t.img.load()
    for _ in range(3):
        x, y = rnd.randrange(2, 14), rnd.randrange(2, 14)
        t.set(x, y, rnd.choice([hx("f2e27a"), hx("e8a0c8"), hx("c8d8ff")]))
    return t.img


def _leaf_blob(t, cx, cy, r, rnd, light=True):
    for y in range(-r, r + 1):
        for x in range(-r, r + 1):
            d = math.hypot(x, y)
            if d <= r + 0.3:
                # light from the top-left
                k = (-x - y) / (r * 1.6)
                c = FOREST["can_mid"]
                if k > 0.35:
                    c = FOREST["can_hi"] if light else FOREST["can_mid"]
                elif k < -0.4:
                    c = FOREST["can"]
                if d > r - 0.7:
                    c = FOREST["can_dk"]
                t.set(cx + x, cy + y, c)
    if light and rnd.random() < 0.7:
        t.set(cx - r // 2, cy - r // 2, FOREST["can_tip"])


def canopy_top(mask):
    rnd = random.Random(1100 + mask)
    t = Tile(FOREST["can_dk"])
    blobs = [(3, 3, 3), (11, 3, 3), (7, 8, 4), (2, 12, 3), (12, 12, 3), (7, 14, 2), (14, 7, 2), (0, 7, 2)]
    rnd.shuffle(blobs)
    for (cx, cy, r) in blobs:
        _leaf_blob(t, cx + rnd.randrange(-1, 2), cy + rnd.randrange(-1, 2), r, rnd)
    # open edges: scalloped rims catching light
    if mask & 1:
        for x in range(T):
            t.set(x, 0, FOREST["can_tip"] if x % 4 in (1, 2) else FOREST["can_hi"])
    if mask & 2:
        for y in range(T):
            t.set(15, y, FOREST["can_mid"] if y % 4 in (1, 2) else FOREST["can_dk"])
    if mask & 4:
        for y in range(T):
            t.set(0, y, FOREST["can_hi"] if y % 4 in (1, 2) else FOREST["can_mid"])
    return t.img


def tree_face(v):
    rnd = random.Random(1200 + v)
    t = Tile(FOREST["can_dk"])
    # canopy hanging down over the top half
    for (cx, cy, r) in [(3, 2, 4), (11, 2, 4), (7, 5, 4)]:
        _leaf_blob(t, cx + rnd.randrange(-1, 2), cy, r, rnd)
    # shadowy gap under the leaves
    for y in range(9, 16):
        for x in range(T):
            t.set(x, y, hx("120e14") if y < 11 else hx("1a1518"))
    # trunks
    trunks = [(3, 3), (11, 2)] if v % 2 == 0 else [(6, 4)]
    if v == 3:
        trunks = [(2, 2), (8, 3), (13, 2)]
    for (tx, tw) in trunks:
        for y in range(8, 16):
            for x in range(tx, tx + tw):
                c = FOREST["trunk"]
                if x == tx:
                    c = FOREST["trunk_hi"]
                elif x == tx + tw - 1:
                    c = FOREST["trunk_dk"]
                if (y + x) % 5 == 0:
                    c = shade(c, 0.85)
                t.set(x, y, c)
        # roots
        t.set(tx - 1, 15, FOREST["trunk"])
        t.set(tx + tw, 15, FOREST["trunk_dk"])
    # leaves that dangle lowest
    for x in range(T):
        if rnd.random() < 0.4:
            t.set(x, 9, FOREST["can"])
    return t.img


def court_ground(v):
    rnd = random.Random(1300 + v)
    t = Tile(COURT["joint"])
    blocks = [(0, 0, 8, 8), (8, 0, 8, 8), (0, 8, 8, 8), (8, 8, 8, 8)] if v % 2 == 0 else \
        [(0, 0, 10, 7), (10, 0, 6, 7), (0, 7, 6, 9), (6, 7, 10, 9)]
    for (x0, y0, w0, h0) in blocks:
        base = rnd.choice([COURT["stone"], COURT["stone2"], COURT["stone3"]])
        for y in range(h0 - 1):
            for x in range(w0 - 1):
                c = shade(base, 1.03 + (rnd.random() - 0.5) * 0.06 - 0.06 * (x + y) / (w0 + h0))
                if y == 0 or x == 0:
                    c = mix(c, COURT["hi"], 0.5)
                elif y == h0 - 2 or x == w0 - 2:
                    c = mix(c, COURT["sh"], 0.5)
                t.set(x0 + x, y0 + y, c)
        if rnd.random() < 0.35:   # crack
            cx, cy = x0 + 2, y0 + 2 + rnd.randrange(3)
            for i in range(5):
                t.set(cx + i, cy + (i % 2), COURT["joint"])
    if v >= 2:   # grass pushing up through the joints
        for x in range(T):
            for y in (7, 8, 15) if v == 2 else (6, 7, 15):
                if rnd.random() < 0.55:
                    t.set(x, y, MOSS["mid"] if rnd.random() < 0.6 else MOSS["hi"])
        for y in range(T):
            if rnd.random() < 0.5:
                t.set(7 if v == 2 else 9, y, MOSS["mid"])
    return t.img


def court_face(v):
    rnd = random.Random(1400 + v)
    t = Tile(COURT["mortar"])
    for x in range(T):
        t.set(x, 0, COURT["top2"])
        t.set(x, 1, COURT["rim"])
        t.set(x, 2, COURT["brick_sh"])
    for row, y0 in enumerate([3, 7, 11]):
        x = -(row % 2) * 4
        while x < T:
            bw = 7
            base = rnd.choice([COURT["brick"], COURT["brick2"]])
            for yy in range(3):
                for xx in range(bw - 1):
                    px = x + xx
                    if 0 <= px < T:
                        c = shade(base, 1.1 - (y0 + yy) / 40.0)
                        if yy == 0:
                            c = mix(c, COURT["brick_hi"], 0.5)
                        elif yy == 2:
                            c = mix(c, COURT["brick_sh"], 0.4)
                        t.set(px, y0 + yy, c)
            x += bw
    for x in range(T):
        t.set(x, 15, hx("1a1612"))
    if v == 1:  # ivy curtain
        for x in range(T):
            ln = int(3 + 6 * abs(math.sin(x * 0.9 + 1)) + rnd.random() * 3)
            for y in range(2, min(15, 2 + ln)):
                if rnd.random() < 0.8:
                    t.set(x, y, COURT["ivy"] if (x + y) % 3 else COURT["ivy_hi"])
    if v == 2:  # arched window into darkness
        for y in range(4, 13):
            for x in range(5, 11):
                if not (y == 4 and x in (5, 10)):
                    t.set(x, y, hx("0e0b10"))
        for x in range(5, 11):
            t.set(x, 13, COURT["brick_hi"])
    if v == 3:  # crumbled section
        for (x, y) in [(10, 3), (11, 3), (12, 3), (11, 4), (12, 4), (12, 5), (13, 3), (13, 4)]:
            t.set(x, y, COURT["mortar"])
        for x in (3, 4, 9):
            t.set(x, 14, COURT["brick"])
    return t.img


def court_top(mask):
    rnd = random.Random(1500 + mask)
    t = Tile(COURT["top"])
    _noise_fill(t, rnd, [COURT["top2"], hx("62584c")], [0.3, 0.15])
    for _ in range(3):   # weeds on top of the ruin
        x, y = rnd.randrange(2, 14), rnd.randrange(2, 14)
        t.set(x, y, MOSS["mid"])
        t.set(x + 1, y, MOSS["hi"])
    for edge, cond in (("N", mask & 1), ("E", mask & 2), ("W", mask & 4)):
        if not cond:
            continue
        for i in range(T):
            a, b = (i, 0), (i, 1)
            if edge == "E":
                a, b = (15, i), (14, i)
            elif edge == "W":
                a, b = (0, i), (1, i)
            t.set(*a, COURT["rim"])
            t.set(*b, COURT["brick"])
    return t.img


def mtn_ground(v):
    rnd = random.Random(1600 + v)
    t = Tile(MTN["grav"])
    _noise_fill(t, rnd, [MTN["grav2"], MTN["grav_lt"]], [0.18, 0.08])
    # soft, tileable tonal waves (dusty earth, not pixel noise)
    ph = rnd.random() * 6
    for y in range(T):
        for x in range(T):
            n = math.sin((x / 16.0) * math.tau + ph) + math.sin(((x + 2 * y) / 16.0) * math.tau + ph * 2)
            if n > 1.1 + dith(x, y) * 0.6:
                t.set(x, y, hx("7c6e60"))
            elif n < -1.2 - dith(x, y) * 0.6:
                t.set(x, y, hx("645850"))
    if v < 2:   # a few short wind ripples in the dust
        for k in range(2):
            y0 = 4 + k * 7 + v * 3
            x0 = rnd.randrange(16)
            for i in range(rnd.randrange(5, 9)):
                x = (x0 + i) % T
                y = y0 + int(round(math.sin((x / 16.0) * math.tau * 2 + ph) * 1.0))
                if True:
                    t.set(x, y % T, hx("5a4e46"))
                    t.set(x, (y - 1) % T, hx("8a7c6c"))
    for _ in range(5):
        x, y = rnd.randrange(1, 14), rnd.randrange(1, 14)
        t.set(x, y, MTN["peb"])
        t.set(x + 1, y, MTN["grav_lt"])
        t.set(x, y + 1, MTN["peb_dk"])
    if v >= 2:   # mossy, lichen-covered rock
        for _ in range(14):
            x, y = rnd.randrange(T), rnd.randrange(T)
            t.set(x, y, MTN["lichen"] if rnd.random() < 0.5 else MOSS["mid"])
    return t.img


def cliff_face(v):
    rnd = random.Random(1700 + v)
    t = Tile(MTN["rock2"])
    # horizontal strata, lit from above
    bands = [0, 3, 7, 10, 13, 16]
    for i in range(len(bands) - 1):
        base = [MTN["rock"], MTN["rock2"], hx("847466"), MTN["rock"], hx("5e524a")][(i + v) % 5]
        for y in range(bands[i], bands[i + 1]):
            for x in range(T):
                c = shade(base, 1.15 - y / 22.0 + (rnd.random() - 0.5) * 0.08)
                if y == bands[i]:
                    c = mix(c, MTN["rock_hi"], 0.55)
                elif y == bands[i + 1] - 1:
                    c = mix(c, MTN["rock_sh"], 0.5)
                t.set(x, y, c)
    for x in range(T):   # top lip
        t.set(x, 0, MTN["rock_hi"])
        t.set(x, 15, MTN["rock_dk"])
    for _ in range(2):   # vertical cracks
        x = rnd.randrange(2, 14)
        for y in range(rnd.randrange(2, 6), rnd.randrange(9, 15)):
            t.set(x, y, MTN["rock_dk"])
            t.set(x + 1, y, MTN["rock_hi"])
            if rnd.random() < 0.3:
                x += rnd.choice([-1, 1])
    if v == 3:
        for _ in range(8):
            t.set(rnd.randrange(T), rnd.randrange(1, 6), MTN["lichen"])
    return t.img


def rock_top(mask):
    rnd = random.Random(1800 + mask)
    t = Tile(MTN["top2"])
    for (cx, cy, r) in [(4, 4, 4), (12, 5, 4), (7, 11, 5), (14, 13, 3), (1, 12, 3)]:
        for y in range(-r, r + 1):
            for x in range(-r, r + 1):
                d = math.hypot(x, y)
                if d <= r:
                    k = (-x - y) / (r * 1.5)
                    c = MTN["top"] if k < 0.3 else MTN["top_hi"]
                    if k < -0.45:
                        c = MTN["top2"]
                    if d > r - 0.8:
                        c = MTN["rock_dk"]
                    t.set(cx + x, cy + y, c)
    for edge, cond in (("N", mask & 1), ("E", mask & 2), ("W", mask & 4)):
        if not cond:
            continue
        for i in range(T):
            if edge == "N":
                t.set(i, 0, MTN["rock_hi"])
            elif edge == "E":
                t.set(15, i, MTN["rock2"])
            else:
                t.set(0, i, MTN["rock_hi"])
    return t.img


def waterfall(frame):
    t = Tile()
    for y in range(T):
        for x in range(T):
            phase = (y - frame * 4 + (x * 7) % 5) % 8
            c = hx("6fa6d8") if phase < 3 else (hx("4a7fb8") if phase < 6 else hx("cfe8ff"))
            if x in (0, 15):
                c = hx("2c4f73")
            t.set(x, y, c)
    for x in range(T):   # lip of the falls
        t.set(x, 0, hx("e8f6ff"))
    return t.img


def bridge(vertical):
    t = Tile()
    for i in range(T):
        for j in range(2, 14):
            x, y = (j, i) if vertical else (i, j)
            plank = (i // 3) % 2
            c = hx("8a6240") if plank else hx("7a5436")
            if i % 3 == 2:
                c = hx("4a3222")
            if j in (2, 13):
                c = hx("5a3e2a")
            t.set(x, y, c)
        # rope rails
        for j in (1, 14):
            x, y = (j, i) if vertical else (i, j)
            t.set(x, y, hx("c8a878") if i % 4 else hx("8a7050"))
    return t.img


def reeds():
    rnd = random.Random(1900)
    t = Tile()
    for _ in range(9):
        x = rnd.randrange(T)
        h0 = rnd.randrange(4, 9)
        for k in range(h0):
            t.set(x, 15 - k, hx("6a8a4a") if k < h0 - 2 else hx("a8b86a"))
        if rnd.random() < 0.5:
            t.set(x, 15 - h0, hx("6a4a2a"))
            t.set(x, 14 - h0, hx("6a4a2a"))
    return t.img


def lily():
    t = Tile()
    for (cx, cy) in [(4, 5), (11, 10)]:
        for y in range(-2, 3):
            for x in range(-3, 4):
                if x * x / 9 + y * y / 4 <= 1 and not (x > 0 and y == 0):
                    t.set(cx + x, cy + y, hx("4a8a4a") if (x + y) % 3 else hx("6aaa5a"))
    t.set(5, 4, hx("f0c0d8"))
    return t.img


def prop_bush():
    rnd = random.Random(2000)
    t = Tile()
    for (cx, cy, r) in [(5, 9, 4), (10, 9, 4), (8, 6, 4)]:
        _leaf_blob(t, cx, cy, r, rnd)
    for (x, y) in [(5, 7), (10, 8), (8, 5)]:
        t.set(x, y, hx("c84a5a"))   # berries
    return t.img


def prop_boulder():
    t = Tile()
    cx, cy, rx, ry = 8, 10, 6, 5
    for y in range(-ry, ry + 1):
        for x in range(-rx, rx + 1):
            d = (x / rx) ** 2 + (y / ry) ** 2
            if d <= 1:
                k = (-x / rx - y / ry)
                c = MTN["rock"] if k < 0.4 else MTN["rock_hi"]
                if k < -0.6:
                    c = MTN["rock_sh"]
                if d > 0.8:
                    c = MTN["rock_dk"] if y > -2 else MTN["rock_sh"]
                t.set(cx + x, cy + y, c)
    t.set(6, 7, MTN["lichen"])
    t.set(7, 7, MTN["lichen"])
    return t.img


def prop_statue():
    t = Tile()
    pal = {"K": hx("2a2622"), "S": COURT["stone3"], "s": COURT["sh"], "H": COURT["hi"], "M": MOSS["mid"]}
    g = ["......KKK.......",
         ".....KHSsK......",
         ".....KSSsK......",
         "......KsK.......",
         "....KKHSSKK.....",
         "...KHSSSSsSK....",
         "...KSKSSSsKSK...",
         "...KSKHSSsKsK...",
         "....KKSSSsK.K...",
         ".....KSSMsK.....",
         ".....KSKKsK.....",
         ".....KSK.KsK....",
         "...KKKKKKKKKKK..",
         "...KHHSSSSSssK..",
         "...KSSSSSSsssK..",
         "...KKKKKKKKKKK.."]
    for y, row in enumerate(g):
        for x, ch in enumerate(row):
            if ch != ".":
                t.set(x, y, pal[ch])
    return t.img


def prop_pillar():
    t = Tile()
    for y in range(1, 16):
        for x in range(4, 12):
            c = COURT["stone3"] if x < 7 else (COURT["stone"] if x < 10 else COURT["sh"])
            if x in (4, 11):
                c = hx("2a2622")
            if y in (1, 2) or y in (13, 14):
                c = COURT["hi"] if x < 8 else COURT["stone2"]
            t.set(x, y, c)
    for x in range(3, 13):
        t.set(x, 15, hx("2a2622"))
        t.set(x, 0, hx("2a2622"))
    for (x, y) in [(5, 6), (6, 7), (5, 9), (9, 4)]:   # cracks and ivy
        t.set(x, y, hx("5a5044"))
    for y in range(6, 12):
        t.set(10, y, MOSS["mid"])
    return t.img


def decal_fern():
    t = Tile()
    for k, (bx, by) in enumerate([(4, 12), (11, 13)]):
        for i in range(6):
            t.set(bx - i // 2, by - i, MOSS["hi"])
            t.set(bx + i // 2 + 1, by - i, MOSS["mid"])
            t.set(bx, by - i, MOSS["deep"])
    return t.img


def decal_flowers():
    rnd = random.Random(2100)
    t = Tile()
    for _ in range(5):
        x, y = rnd.randrange(2, 14), rnd.randrange(2, 14)
        c = rnd.choice([hx("f2e27a"), hx("f0a0c0"), hx("ffffff"), hx("b8a0ff")])
        for (dx, dy) in [(0, -1), (-1, 0), (1, 0), (0, 1)]:
            t.set(x + dx, y + dy, c)
        t.set(x, y, hx("f5c542"))
        t.set(x, y + 2, MOSS["mid"])
    return t.img


def decal_scree():
    rnd = random.Random(2200)
    t = Tile()
    for _ in range(9):
        x, y = rnd.randrange(1, 15), rnd.randrange(1, 15)
        t.set(x, y, MTN["peb"])
        t.set(x, y + 1, MTN["peb_dk"])
    return t.img


def decal_marsh():
    rnd = random.Random(2300)
    t = Tile()
    for _ in range(6):
        x, y = rnd.randrange(1, 15), rnd.randrange(6, 15)
        for k in range(rnd.randrange(2, 5)):
            t.set(x, y - k, hx("7a9a5a") if k < 2 else hx("a8c07a"))
    return t.img


def build():
    rows = []
    rows.append([floor_tile(v) for v in range(8)])
    rows.append([moss_tile(v) for v in range(4)] + [tall_grass_tile(0), tall_grass_tile(1), dirt_tile(0), dirt_tile(1)])
    rows.append([moss_fringe(s) for s in ["N", "E", "S", "W", "NE", "SE", "SW", "NW"]])
    rows.append([wall_face(v) for v in range(8)])
    rows.append([wall_top(m) for m in range(8)])
    rows.append([water_tile(f) for f in range(4)] + [shore(s) for s in ["N", "E", "S", "W"]])
    rows.append([decal(k) for k in range(8)])
    rows.append([ao(s) for s in ["N", "E", "W", "NE", "NW", "S"]])
    rows.append([forest_ground(v) for v in range(4)] + [tree_face(v) for v in range(4)])          # 8
    rows.append([canopy_top(m) for m in range(8)])                                               # 9
    rows.append([court_ground(v) for v in range(4)] + [court_face(v) for v in range(4)])         # 10
    rows.append([court_top(m) for m in range(8)])                                                # 11
    rows.append([mtn_ground(v) for v in range(4)] + [cliff_face(v) for v in range(4)])           # 12
    rows.append([rock_top(m) for m in range(8)])                                                 # 13
    rows.append([waterfall(f) for f in range(4)] + [bridge(False), bridge(True), reeds(), lily()])  # 14
    rows.append([prop_bush(), prop_boulder(), prop_statue(), prop_pillar(),
                 decal_fern(), decal_flowers(), decal_scree(), decal_marsh()])                    # 15
    sheet = Image.new("RGBA", (T * 8, T * len(rows)), (0, 0, 0, 0))
    for r, row in enumerate(rows):
        for c, img in enumerate(row):
            sheet.paste(img, (c * T, r * T))
    return sheet


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    build().save(OUT / "env.png")
    doors_sheet().save(OUT / "doors.png")
    print("wrote env.png, doors.png")
