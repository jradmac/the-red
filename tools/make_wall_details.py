"""Builds the landscape details laid over the 3D walls and cliffs
(scripts/terrain3d.gd puts them on the faces, a hair in front):

  assets/wall_details.png   128 x 80
      rows y 0 / 16 / 32 : wall FRONTS (16x16, 8 each) -- crypt, courtyard, mountain
      row  y 48          : wall TOPS (16x16) -- crypt 0-3, courtyard 4-7
      row  y 64          : wall TOPS (16x16) -- mountain 0-3
  assets/cliff_details.png  128 x 80
      one row of 8 (16x16) per cliff style, same order as heights.png:
      0 woods / river, 1 swamp, 2 mountain, 3 courtyard, 4 crypt

Everything is transparent except the detail itself: moss, ivy, roots, snow,
crystals, cobwebs... The game picks one now and then, more of them in
clusters (damp corners of the crypt, overgrown stretches of the courtyard).
Run:  python3 tools/make_wall_details.py
"""
from pathlib import Path
import math
import random

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent


def hx(s):
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


class Spr:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.px = self.img.load()

    def set(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c

    def has(self, x, y):
        x, y = int(x), int(y)
        return 0 <= x < self.w and 0 <= y < self.h and self.px[x, y][3] > 0

    def get(self, x, y):
        return self.px[int(x), int(y)]


# --- palettes ---------------------------------------------------------------------

MOSS = [hx("1c3324"), hx("2f523b"), hx("3e7a44"), hx("4f8058"), hx("62a65e"), hx("8cc878")]
IVY = [hx("1a3020"), hx("2c5a32"), hx("3e7a44"), hx("5a9a4e"), hx("7cbc62")]
LICHEN_Y = [hx("6a5a2a"), hx("a88a38"), hx("d8b850"), hx("f0dc88")]
LICHEN_O = [hx("6a3a22"), hx("a85a30"), hx("d88a48"), hx("f0b878")]
LICHEN_G = [hx("4a5a3a"), hx("7a8a5a"), hx("a8b880"), hx("d0dca8")]
SNOW = [hx("6878a0"), hx("a8b8d8"), hx("d8e4f4"), hx("ffffff")]
ICE = [hx("3a5a88"), hx("78a8d8"), hx("b8dcf4"), hx("eef8ff")]
CRYSTAL = [hx("2a1e4a"), hx("5a3a9a"), hx("8a6ad8"), hx("c8b0ff"), hx("f4ecff")]
CRYSTAL_B = [hx("1a2e4a"), hx("2e6a9a"), hx("4ab0d8"), hx("a8e8ff"), hx("f0fcff")]
WEB = [hx("8a8698"), hx("c8c4d4"), hx("eceaf4")]
ROOT_C = [hx("2a1c12"), hx("4a3424"), hx("6e5038"), hx("9a7650")]
SLIME = [hx("2a3a12"), hx("5a7a1e"), hx("8aaa30"), hx("c8e05a")]
MUSH = [hx("3a1e1a"), hx("8a3a2e"), hx("c8644a"), hx("f0c8a0")]
PALE_MUSH = [hx("4a4250"), hx("9a92a8"), hx("d0c8dc"), hx("fff8ff")]
FUNGUS = [hx("3a2a1a"), hx("7a5a32"), hx("b08a50"), hx("e0c890")]
BONE = [hx("4a4438"), hx("a89c84"), hx("e0d6bc"), hx("fff8e8")]
STAIN = [hx("3e384c"), hx("4a4458")]
GLINT = hx("9ab0c8")
CRACK = hx("0d0b12")
FLOWER_W = hx("f4f0f8")
FLOWER_P = hx("d070a8")
FLOWER_Y = hx("f0d058")
WATER = [hx("1e3a3a"), hx("2e5a4e"), hx("4a7a5a")]
CANDLE = [hx("8a7a5a"), hx("e8dcb8"), hx("ffe890"), hx("ff9a30")]


# --- brushes ----------------------------------------------------------------------

def blob(s, rnd, cx, cy, r, ramp, light=(-1, -1), density=1.0, squash=1.0):
    """A soft clump (moss, lichen): a ramp shaded from the light, a dark rim."""
    pts = []
    for y in range(int(cy - r - 2), int(cy + r + 3)):
        for x in range(int(cx - r - 2), int(cx + r + 3)):
            dx, dy = (x - cx), (y - cy) / squash
            d = math.hypot(dx, dy) + rnd.uniform(-0.7, 0.7)
            if d <= r and rnd.random() < density:
                pts.append((x, y, d, dx, dy))
    for x, y, d, dx, dy in pts:
        lit = -(dx * light[0] + dy * light[1]) / max(r, 0.5)
        t = 0.55 + 0.45 * lit - 0.35 * (d / max(r, 0.5)) + rnd.uniform(-0.18, 0.18)
        i = 1 + int(max(0, min(len(ramp) - 2, t * (len(ramp) - 1))))
        if d > r - 1.0:
            i = max(1, i - 1)
        s.set(x, y, ramp[min(i, len(ramp) - 1)])
    # a dark rim underneath, so it sits on the stone
    for x, y, d, dx, dy in pts:
        if not s.has(x, y + 1) and rnd.random() < 0.8:
            s.set(x, y + 1, ramp[0])


def strand(s, rnd, x, y0, length, ramp, sway=0.0, leaf=0.0):
    """Something hanging (moss, roots, vines) from y0 down."""
    fx = float(x)
    for i in range(length):
        y = y0 + i
        fx += sway * rnd.uniform(-1, 1)
        t = 1.0 - i / max(length, 1)
        c = ramp[max(1, min(len(ramp) - 1, int(1 + t * (len(ramp) - 2) + rnd.uniform(-0.4, 0.4))))]
        s.set(round(fx), y, c)
        if i < length * 0.4 and rnd.random() < 0.35:
            s.set(round(fx) + rnd.choice((-1, 1)), y, ramp[1])
        if leaf and rnd.random() < leaf:
            side = rnd.choice((-1, 1))
            s.set(round(fx) + side, y, ramp[-1] if rnd.random() < 0.4 else ramp[2])
    s.set(round(fx), y0 + length, ramp[0])


def line(s, x0, y0, x1, y1, c):
    n = int(max(abs(x1 - x0), abs(y1 - y0), 1))
    for i in range(n + 1):
        s.set(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)


def crack(s, rnd, x, y, length, hi=None):
    """A wandering crack, lit on its lower edge."""
    fx, fy = float(x), float(y)
    for _ in range(length):
        s.set(round(fx), round(fy), CRACK)
        if hi is not None and rnd.random() < 0.6:
            if not s.has(round(fx) + 1, round(fy) + 1):
                s.set(round(fx) + 1, round(fy) + 1, hi)
        fy += 1
        fx += rnd.choice((-1, 0, 0, 1))
        if rnd.random() < 0.15:   # a branch
            bx, by = fx, fy
            for _ in range(rnd.randrange(2, 4)):
                bx += rnd.choice((-1, 1))
                by += 1
                s.set(round(bx), round(by), CRACK)


def leafy(s, rnd, x, y, ramp, size=1):
    """A small ivy leaf (3x3 heart-ish)."""
    pat = [(0, 0), (1, 0), (-1, 0), (0, -1), (0, 1)] if size else [(0, 0), (1, 0), (0, -1)]
    for i, (dx, dy) in enumerate(pat):
        s.set(x + dx, y + dy, ramp[2] if i else ramp[3])
    s.set(x - 1, y - 1, ramp[min(4, len(ramp) - 1)])
    s.set(x + 1, y + 1, ramp[1])


def vine(s, rnd, x, y0, y1, ramp, up=True, leaves=0.45, flowers=None):
    """A climbing stem with leaves (ivy)."""
    fx = float(x)
    step = -1 if up else 1
    y = y0
    while (y >= y1) if up else (y <= y1):
        s.set(round(fx), y, ramp[1])
        if rnd.random() < leaves:
            lx = round(fx) + rnd.choice((-2, 2))
            leafy(s, rnd, lx, y, ramp)
            if flowers and rnd.random() < 0.3:
                s.set(lx, y - 1, flowers)
        fx += rnd.uniform(-0.6, 0.6)
        y += step


def web(s, rnd, cx, cy, sx, sy, r):
    """A cobweb in a corner (sx, sy = which way it opens): a few threads."""
    spokes = 3
    ends = []
    for k in range(spokes + 1):
        a = (math.pi / 2) * k / spokes
        ends.append((cx + sx * math.cos(a) * r, cy + sy * math.sin(a) * r))
        if 0 < k < spokes:   # (the outer two would only trace the corner)
            line(s, cx, cy, ends[-1][0], ends[-1][1], WEB[0])
    for ring in (r * 0.45, r * 0.85):
        for k in range(spokes):
            a0 = (math.pi / 2) * k / spokes
            a1 = (math.pi / 2) * (k + 1) / spokes
            for i in range(1, 6):
                a = a0 + (a1 - a0) * i / 6
                sag = math.sin(math.pi * i / 6) * 0.9
                x = cx + sx * math.cos(a) * (ring - sag)
                y = cy + sy * math.sin(a) * (ring - sag)
                if i % 2 or ring > r * 0.5:
                    s.set(round(x), round(y), WEB[1])
    s.set(cx + sx, cy + sy, WEB[2])
    # a strand drifting loose
    x, y = ends[1]
    for i in range(3):
        s.set(round(x), round(y) + i, WEB[0])


def mushroom(s, rnd, x, y, ramp, cap=2):
    """A little cap on a stalk, standing at (x, y) = its foot."""
    s.set(x, y, ramp[3])
    s.set(x, y - 1, ramp[3])
    for dx in range(-cap, cap + 1):
        s.set(x + dx, y - 2, ramp[1])
    for dx in range(-cap + 1, cap):
        s.set(x + dx, y - 3, ramp[2])
    s.set(x - cap + 1, y - 3, ramp[3])
    s.set(x, y - 2, ramp[1])
    s.set(x + cap, y - 2, ramp[0])


def icicles(s, rnd, x0, x1, y, ramp, maxlen=6):
    for x in range(x0, x1):
        if rnd.random() < 0.45:
            n = rnd.randrange(2, maxlen + 1)
            for i in range(n):
                c = ramp[3] if i == 0 else (ramp[2] if i < n * 0.5 else ramp[1])
                s.set(x, y + i, c)
            s.set(x + 1, y, ramp[1])


def snow_cap(s, rnd, y, depth, ramp, x0=0, x1=16):
    """Snow along a ledge, ragged underneath, lit on top."""
    for x in range(x0, x1):
        d = depth + rnd.choice((-1, 0, 0, 1))
        for i in range(max(1, d)):
            c = ramp[3] if i == 0 else (ramp[2] if i < d - 1 else ramp[1])
            s.set(x, y + i, c)
        if rnd.random() < 0.2:
            s.set(x, y + d, ramp[0])


def crystal(s, rnd, x, y, h, ramp, lean=0):
    """A shard standing on (x, y), h tall: lit face left, dark face right."""
    for i in range(h):
        w = max(0, int(round((h - i) / h * 1.5)))
        cx = x + round(lean * i / h)
        for dx in range(-w, w + 1):
            c = ramp[3] if dx < 0 else (ramp[2] if dx == 0 else ramp[1])
            s.set(cx + dx, y - i, c)
    s.set(x + round(lean), y - h, ramp[4])
    for dx in (-2, -1, 0, 1, 2):
        if not s.has(x + dx, y + 1):
            s.set(x + dx, y + 1, ramp[0])


def speckle(s, rnd, cx, cy, r, ramp, n):
    for _ in range(n):
        a = rnd.uniform(0, math.tau)
        d = rnd.uniform(0, r)
        x, y = cx + math.cos(a) * d, cy + math.sin(a) * d * 0.8
        s.set(x, y, rnd.choice(ramp[1:]))
        if rnd.random() < 0.4:
            s.set(x + 1, y, ramp[2])


def root_tangle(s, rnd, x, y0, length, ramp):
    fx = float(x)
    for i in range(length):
        fx += rnd.choice((-1, 0, 0, 1)) * 0.8
        s.set(round(fx), y0 + i, ramp[2] if i % 3 else ramp[3])
        s.set(round(fx) + 1, y0 + i, ramp[1])
        if rnd.random() < 0.18:
            bx = round(fx)
            for k in range(rnd.randrange(2, 4)):
                bx += rnd.choice((-1, 1))
                s.set(bx, y0 + i + k, ramp[1])
    s.set(round(fx), y0 + length, ramp[0])


def drip_stain(s, rnd, x, y0, length):
    """Damp seeping down the stone: a darker streak with a wet glint."""
    for i in range(length):
        if rnd.random() < 0.8:
            s.set(x, y0 + i, STAIN[1] if i < length * 0.6 else STAIN[0])
        if i > 1 and rnd.random() < 0.25:
            x += rnd.choice((-1, 1))
    s.set(x, y0 + length, GLINT)
    s.set(x, y0 + 2, GLINT)


def shelf(s, rnd, x, y, w, ramp):
    """A bracket fungus sticking out of the face."""
    for dx in range(w):
        s.set(x + dx, y, ramp[3] if dx < w - 1 else ramp[2])
        s.set(x + dx, y + 1, ramp[1])
    for dx in range(1, w - 1):
        s.set(x + dx, y - 1, ramp[2])
    s.set(x, y + 2, ramp[0])


def tuft(s, rnd, x, y, ramp, n=4, h=4):
    for i in range(n):
        bx = x + i - n // 2
        hh = rnd.randrange(h // 2, h + 1)
        lean = rnd.choice((-1, 0, 1))
        for k in range(hh):
            s.set(bx + (lean if k > hh // 2 else 0), y - k, ramp[2] if k < hh - 1 else ramp[3])
    for i in range(n):
        s.set(x + i - n // 2, y, ramp[1])


def bones(s, rnd, x, y):
    """A bit of bone poking out of the earth / mortar."""
    line(s, x, y, x + 4, y - 1, BONE[2])
    s.set(x - 1, y, BONE[3])
    s.set(x - 1, y - 1, BONE[2])
    s.set(x + 5, y - 1, BONE[3])
    s.set(x + 5, y - 2, BONE[2])
    line(s, x, y + 1, x + 4, y, BONE[0])


def candle(s, rnd, x, y):
    for i in range(3):
        s.set(x, y - i, CANDLE[1])
    s.set(x + 1, y - 1, CANDLE[0])
    s.set(x, y - 3, CANDLE[3])
    s.set(x, y - 4, CANDLE[2])
    for dx in (-1, 0, 1, 2):
        s.set(x + dx, y + 1, CANDLE[0] if dx else CANDLE[1])


# --- the details ----------------------------------------------------------------

LIP = 4   # just under the cap / the turf along a wall front's top (wall_blocks.png fronts)


def crypt_face(v, rnd):
    s = Spr(16, 16)
    if v == 0:      # moss creeping up from the foot
        for x in range(0, 16, 3):
            blob(s, rnd, x + rnd.uniform(0, 2), 14.5 + rnd.uniform(-1, 0.5), rnd.uniform(1.8, 3.0), MOSS, squash=0.8)
        for _ in range(2):
            blob(s, rnd, rnd.uniform(2, 14), rnd.uniform(9, 11), rnd.uniform(1.0, 1.6), MOSS)
    elif v == 1:    # moss hanging from under the coping
        for x in range(1, 15):
            if rnd.random() < 0.7:
                strand(s, rnd, x, LIP, rnd.randrange(2, 9), MOSS, sway=0.25)
        for x in range(0, 16):
            s.set(x, LIP, MOSS[2] if x % 3 else MOSS[3])
    elif v == 2:    # a cobweb under the coping, left, a little moss below
        web(s, rnd, 0, LIP, 1, 1, 7)
        blob(s, rnd, 13, 14, 2.2, MOSS)
    elif v == 3:    # cobweb right
        web(s, rnd, 15, LIP, -1, 1, 7)
        blob(s, rnd, 3, 14.5, 2.0, MOSS)
    elif v == 4:    # a crack, moss growing in it
        crack(s, rnd, 7, LIP, 10, hi=hx("8a829c"))
        blob(s, rnd, 6, 8, 1.5, MOSS)
        blob(s, rnd, 8, 13, 1.8, MOSS)
    elif v == 5:    # water seeping down, a green pool at the foot
        for x in (4, 9, 12):
            drip_stain(s, rnd, x, LIP, rnd.randrange(5, 9))
        blob(s, rnd, 8, 15, 3.2, MOSS, squash=0.6)
    elif v == 6:    # a thick blanket of moss over half the stones
        for _ in range(7):
            blob(s, rnd, rnd.uniform(1, 15), rnd.uniform(LIP + 1, 15), rnd.uniform(1.6, 2.8), MOSS)
        for x in range(2, 14, 2):
            strand(s, rnd, x, LIP, rnd.randrange(2, 5), MOSS)
    else:           # pale toadstools and a candle stub at the foot
        blob(s, rnd, 8, 15.5, 3.0, MOSS, squash=0.6)
        mushroom(s, rnd, 4, 14, PALE_MUSH, cap=2)
        mushroom(s, rnd, 7, 15, PALE_MUSH, cap=1)
        candle(s, rnd, 12, 13)
    return s


def court_face(v, rnd):
    s = Spr(16, 16)
    if v == 0:      # ivy climbing from the foot
        vine(s, rnd, 5, 15, 3, IVY)
        vine(s, rnd, 11, 15, 8, IVY)
        blob(s, rnd, 8, 15.5, 2.3, IVY, squash=0.6)
    elif v == 1:    # ivy pouring over the edge
        for x in range(0, 16, 2):
            vine(s, rnd, x + rnd.choice((0, 1)), 0, rnd.randrange(3, 10), IVY, up=False, leaves=0.5)
    elif v == 2:    # lichen rosettes
        for _ in range(4):
            speckle(s, rnd, rnd.uniform(2, 14), rnd.uniform(4, 13), rnd.uniform(1.2, 2.2),
                    rnd.choice((LICHEN_Y, LICHEN_G)), 8)
    elif v == 3:    # a crack and a chipped-out stone
        crack(s, rnd, 10, 2, 9, hi=hx("c8bca6"))
        for y in range(9, 12):
            for x in range(2, 6):
                s.set(x, y, hx("3a332c") if y > 9 else hx("1a1612"))
        s.set(2, 12, hx("c8bca6"))
        s.set(5, 12, hx("98897a"))
    elif v == 4:    # a flowering creeper
        vine(s, rnd, 8, 15, 2, IVY, leaves=0.55, flowers=FLOWER_W)
        vine(s, rnd, 3, 15, 9, IVY, leaves=0.55, flowers=FLOWER_P)
    elif v == 5:    # moss in the corners and along the foot
        blob(s, rnd, 1, 3, 2.0, MOSS)
        blob(s, rnd, 14, 4, 1.8, MOSS)
        for x in range(0, 16, 3):
            blob(s, rnd, x + 1, 15.5, 1.7, MOSS, squash=0.6)
    elif v == 6:    # tufts of grass at the foot
        tuft(s, rnd, 4, 15, IVY, n=5, h=5)
        tuft(s, rnd, 12, 15, IVY, n=4, h=4)
        speckle(s, rnd, 9, 7, 2, LICHEN_Y, 6)
    else:           # ivy curtain, both ends
        vine(s, rnd, 2, 15, 1, IVY, leaves=0.6)
        vine(s, rnd, 14, 0, 9, IVY, up=False, leaves=0.6)
    return s


def mountain_face(v, rnd):
    s = Spr(16, 16)
    if v == 0:      # orange and yellow lichen
        for _ in range(3):
            speckle(s, rnd, rnd.uniform(2, 14), rnd.uniform(7, 13), rnd.uniform(1.4, 2.4),
                    rnd.choice((LICHEN_O, LICHEN_Y)), 9)
    elif v == 1:    # snow on the turf, icicles under it
        snow_cap(s, rnd, 0, 3, SNOW)
        icicles(s, rnd, 1, 15, 3, ICE, maxlen=5)
    elif v == 2:    # a cluster of violet crystals in a cleft
        crack(s, rnd, 6, 5, 6)
        crystal(s, rnd, 6, 14, 5, CRYSTAL, lean=-1)
        crystal(s, rnd, 9, 15, 7, CRYSTAL, lean=1)
        crystal(s, rnd, 12, 15, 3, CRYSTAL)
    elif v == 3:    # frost in the cracks
        crack(s, rnd, 5, 5, 9, hi=ICE[2])
        crack(s, rnd, 11, 7, 7, hi=ICE[2])
        snow_cap(s, rnd, 0, 2, SNOW, 3, 13)
    elif v == 4:    # grass and pale lichen at the foot
        tuft(s, rnd, 4, 15, [hx("3a4a22"), hx("5a6a2a"), hx("8a9a5a"), hx("b8c080")], n=5, h=4)
        speckle(s, rnd, 11, 11, 2.0, LICHEN_G, 9)
    elif v == 5:    # long icicles
        snow_cap(s, rnd, 0, 2, SNOW)
        icicles(s, rnd, 0, 16, 2, ICE, maxlen=9)
    elif v == 6:    # a vein of ore (rust-gold)
        fx = 0.0
        for x in range(16):
            fx += rnd.choice((-1, 0, 1))
            y = round(9 + fx * 0.6)
            s.set(x, y, hx("8a5a28"))
            s.set(x, y - 1, hx("d8a848") if rnd.random() < 0.5 else hx("8a5a28"))
            if rnd.random() < 0.3:
                s.set(x, y - 2, hx("fff0a0"))
        speckle(s, rnd, 4, 13, 1.8, LICHEN_O, 6)
    else:           # blue crystals and snow
        snow_cap(s, rnd, 0, 2, SNOW, 0, 9)
        crystal(s, rnd, 5, 14, 6, CRYSTAL_B)
        crystal(s, rnd, 9, 15, 4, CRYSTAL_B, lean=1)
    return s


def wall_top(biome, v, rnd):
    s = Spr(16, 16)
    if biome == "crypt":
        if v < 3:
            for _ in range(2 + v):
                blob(s, rnd, rnd.uniform(4, 12), rnd.uniform(4, 12), rnd.uniform(1.5, 3.0), MOSS)
        else:       # moss with pale toadstools in it
            blob(s, rnd, 8, 9, 3.2, MOSS)
            mushroom(s, rnd, 6, 9, PALE_MUSH, cap=1)
            mushroom(s, rnd, 10, 10, PALE_MUSH, cap=1)
    elif biome == "court":
        if v < 2:
            for _ in range(6 + v * 3):
                leafy(s, rnd, round(rnd.uniform(3, 13)), round(rnd.uniform(3, 13)), IVY)
        elif v == 2:
            for _ in range(3):
                speckle(s, rnd, rnd.uniform(4, 12), rnd.uniform(4, 12), 2.0, LICHEN_Y, 7)
        else:
            tuft(s, rnd, 6, 11, IVY, n=4, h=4)
            tuft(s, rnd, 11, 8, IVY, n=3, h=3)
            s.set(9, 11, FLOWER_Y)
            s.set(5, 7, FLOWER_W)
    else:
        if v < 3:   # drifts of snow
            for _ in range(2 + v):
                blob(s, rnd, rnd.uniform(4, 12), rnd.uniform(4, 12), rnd.uniform(2.0, 3.4), SNOW, squash=0.7)
        else:       # a frost-rimed stone, lichen on it
            blob(s, rnd, 8, 9, 2.6, [hx("3a3530"), hx("5e5a52"), hx("8a8478"), hx("aaa496")], squash=0.8)
            speckle(s, rnd, 8, 8, 1.5, LICHEN_O, 4)
            s.set(7, 6, SNOW[3])
            s.set(8, 6, SNOW[2])
    return s


def cliff(style, v, rnd):
    """16x16 details for a cliff face; the face's top 3 px are its grassy lip."""
    s = Spr(16, 16)
    if style == 0:      # woods / river: roots, ferns, moss, mushrooms
        [lambda: [root_tangle(s, rnd, x, 3, rnd.randrange(5, 12), ROOT_C) for x in (3, 9, 13)],
         lambda: (tuft(s, rnd, 5, 15, IVY, n=5, h=5), tuft(s, rnd, 12, 15, IVY, n=3, h=3)),
         lambda: [blob(s, rnd, x, rnd.uniform(6, 13), rnd.uniform(1.5, 2.5), MOSS) for x in (3, 8, 13)],
         lambda: (mushroom(s, rnd, 5, 14, MUSH), mushroom(s, rnd, 9, 15, MUSH, cap=1), blob(s, rnd, 12, 15, 2, MOSS, squash=0.6)),
         lambda: [strand(s, rnd, x, 3, rnd.randrange(3, 9), IVY, leaf=0.4) for x in range(1, 16, 3)],
         lambda: (root_tangle(s, rnd, 7, 3, 11, ROOT_C), blob(s, rnd, 11, 13, 2, MOSS)),
         lambda: (shelf(s, rnd, 3, 8, 5, FUNGUS), shelf(s, rnd, 6, 12, 4, FUNGUS)),
         lambda: (tuft(s, rnd, 8, 15, IVY, n=6, h=6), s.set(6, 10, FLOWER_Y), s.set(10, 11, FLOWER_W)),
         ][v]()
    elif style == 1:    # swamp: slime, vines, bracket fungus, a waterline
        [lambda: [strand(s, rnd, x, 3, rnd.randrange(4, 13), SLIME, sway=0.15) for x in range(1, 16, 2) if rnd.random() < 0.7],
         lambda: [strand(s, rnd, x, 3, rnd.randrange(5, 13), IVY, leaf=0.45, sway=0.3) for x in (2, 7, 12)],
         lambda: (shelf(s, rnd, 2, 7, 5, FUNGUS), shelf(s, rnd, 8, 10, 6, FUNGUS), shelf(s, rnd, 4, 13, 4, FUNGUS)),
         lambda: [s.set(x, 12 + (x * 7 % 3 == 0), WATER[rnd.randrange(3)]) for x in range(16)] + [blob(s, rnd, 6, 14, 2.5, SLIME, squash=0.6)],
         lambda: (mushroom(s, rnd, 4, 15, PALE_MUSH), mushroom(s, rnd, 7, 15, PALE_MUSH, cap=1), mushroom(s, rnd, 12, 14, PALE_MUSH)),
         lambda: [blob(s, rnd, rnd.uniform(2, 14), rnd.uniform(5, 14), rnd.uniform(1.4, 2.4), SLIME) for _ in range(4)],
         lambda: (root_tangle(s, rnd, 4, 3, 12, ROOT_C), strand(s, rnd, 11, 3, 10, SLIME)),
         lambda: (tuft(s, rnd, 5, 15, [hx("2a2a1c"), hx("4a5a28"), hx("6a7a32"), hx("9aa84a")], n=6, h=7), s.set(4, 8, hx("c8a050"))),
         ][v]()
    elif style == 2:    # mountain: snow lip, icicles, lichen, crystals
        [lambda: (snow_cap(s, rnd, 0, 3, SNOW), icicles(s, rnd, 1, 15, 3, ICE, maxlen=5)),
         lambda: [speckle(s, rnd, rnd.uniform(3, 13), rnd.uniform(5, 13), 2.2, rnd.choice((LICHEN_O, LICHEN_Y)), 9) for _ in range(3)],
         lambda: (crystal(s, rnd, 6, 14, 6, CRYSTAL, lean=-1), crystal(s, rnd, 9, 15, 8, CRYSTAL), crystal(s, rnd, 12, 15, 4, CRYSTAL, lean=1)),
         lambda: snow_cap(s, rnd, 0, 4, SNOW),
         lambda: (crack(s, rnd, 8, 3, 11, hi=ICE[2]), speckle(s, rnd, 4, 11, 2, LICHEN_G, 7)),
         lambda: (crystal(s, rnd, 5, 15, 6, CRYSTAL_B), crystal(s, rnd, 8, 14, 4, CRYSTAL_B, lean=1)),
         lambda: (tuft(s, rnd, 8, 15, [hx("3a4a22"), hx("5a6a2a"), hx("8a9a5a"), hx("b8c080")], n=5, h=4), speckle(s, rnd, 11, 7, 2, LICHEN_O, 6)),
         lambda: (snow_cap(s, rnd, 0, 2, SNOW), icicles(s, rnd, 0, 16, 2, ICE, maxlen=9)),
         ][v]()
    elif style == 3:    # courtyard: ivy, flowers, lichen, cracks
        [lambda: (vine(s, rnd, 4, 15, 4, IVY), vine(s, rnd, 11, 15, 8, IVY)),
         lambda: [vine(s, rnd, x, 2, 3 + rnd.randrange(3, 11), IVY, up=False) for x in (2, 6, 10, 14)],
         lambda: [speckle(s, rnd, rnd.uniform(3, 13), rnd.uniform(5, 13), 2.0, LICHEN_Y, 8) for _ in range(3)],
         lambda: crack(s, rnd, 7, 3, 12, hi=hx("e0d8c8")),
         lambda: (vine(s, rnd, 8, 15, 4, IVY, leaves=0.6, flowers=FLOWER_P)),
         lambda: (tuft(s, rnd, 5, 15, IVY, n=5, h=5), s.set(5, 9, FLOWER_Y), tuft(s, rnd, 12, 15, IVY, n=3, h=3)),
         lambda: [blob(s, rnd, x, rnd.uniform(9, 14), rnd.uniform(1.4, 2.2), MOSS) for x in (3, 9, 13)],
         lambda: (vine(s, rnd, 13, 2, 14, IVY, up=False, flowers=FLOWER_W), speckle(s, rnd, 5, 10, 2, LICHEN_G, 6)),
         ][v]()
    else:               # crypt: moss, cobwebs, bones, seeping water
        [lambda: [blob(s, rnd, x, rnd.uniform(10, 14), rnd.uniform(1.6, 2.6), MOSS) for x in (2, 7, 12)],
         lambda: [strand(s, rnd, x, 2, rnd.randrange(3, 10), MOSS, sway=0.2) for x in range(1, 16) if rnd.random() < 0.6],
         lambda: web(s, rnd, 0, 2, 1, 1, 8),
         lambda: web(s, rnd, 15, 2, -1, 1, 8),
         lambda: (bones(s, rnd, 4, 10), blob(s, rnd, 12, 14, 2, MOSS)),
         lambda: ([drip_stain(s, rnd, x, 3, rnd.randrange(6, 11)) for x in (3, 8, 12)], blob(s, rnd, 8, 15, 3, MOSS, squash=0.5)),
         lambda: (mushroom(s, rnd, 5, 15, PALE_MUSH), mushroom(s, rnd, 8, 15, PALE_MUSH, cap=1), candle(s, rnd, 12, 14)),
         lambda: (crack(s, rnd, 8, 3, 10, hi=hx("6a6480")), blob(s, rnd, 7, 9, 1.6, MOSS), blob(s, rnd, 9, 14, 2, MOSS)),
         ][v]()
    return s


def main():
    wd = Image.new("RGBA", (128, 80), (0, 0, 0, 0))
    for row, fn in enumerate((crypt_face, court_face, mountain_face)):
        for v in range(8):
            wd.alpha_composite(fn(v, random.Random(row * 100 + v)).img, (v * 16, row * 16))
    for v in range(4):
        wd.alpha_composite(wall_top("crypt", v, random.Random(500 + v)).img, (v * 16, 48))
        wd.alpha_composite(wall_top("court", v, random.Random(600 + v)).img, (64 + v * 16, 48))
        wd.alpha_composite(wall_top("mountain", v, random.Random(700 + v)).img, (v * 16, 64))
    cd = Image.new("RGBA", (128, 80), (0, 0, 0, 0))
    for style in range(5):
        for v in range(8):
            cd.alpha_composite(cliff(style, v, random.Random(1000 + style * 10 + v)).img, (v * 16, style * 16))
    wd.save(ROOT / "assets" / "wall_details.png")
    cd.save(ROOT / "assets" / "cliff_details.png")
    print("wrote assets/wall_details.png, assets/cliff_details.png")


if __name__ == "__main__":
    main()
