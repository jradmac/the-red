"""Builds assets/tall.png: sprites with height, drawn bigger than one tile so
the outdoors reads as a 3D world (see the rects in scripts/world.gd):

  fortress faces   16x24 x4  crypt walls seen from outside (castle stone)
  courtyard faces  16x24 x4  ruined walls, taller, broken top edge
  cliff faces      16x24 x4  layered rock with a ragged top
  fortress tops    16x16 x2  battlements along the crypt's outer walls
  arch front       48x40     stone archway (north-south passage)
  arch side        16x40     the same arch seen from the side (east-west)
  tree crowns      32x32 x4  round, overlapping canopies
  boulder piles    32x32 x3  mountain tops
Run: python3 tools/make_tall.py
"""
from pathlib import Path
import math
import random
import sys

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_env import hx, mix, shade, MOSS, FOREST, COURT, MTN  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "assets"

FORT = dict(block=hx("6a6478"), block2=hx("625c70"), block3=hx("736b7e"), hi=hx("a49cb4"), sh=hx("3e384c"),
            mortar=hx("221e2b"), cap=hx("8a829c"), cap_hi=hx("c4bcd2"), dark=hx("0d0b12"))


class Spr:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.px = self.img.load()

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c

    def get(self, x, y):
        return self.px[x, y]


def blocks_face(s, top, rnd, bases, hi, sh, mortar, rows=(0, 7, 14)):
    """Masonry from `top` down, light at the top, darker at the foot."""
    for y in range(top, s.h):
        for x in range(s.w):
            s.set(x, y, mortar)
    heights = [7, 7, 7, 7]
    y0 = top
    r = 0
    while y0 < s.h:
        hgt = heights[r % 4]
        x = -(r % 2) * rnd.randrange(3, 7)
        while x < s.w:
            bw = rnd.randrange(6, 10)
            base = rnd.choice(bases)
            for yy in range(hgt - 1):
                for xx in range(bw - 1):
                    px, py = x + xx, y0 + yy
                    if 0 <= px < s.w and py < s.h:
                        c = shade(base, 1.12 - 0.4 * (py / s.h) + (rnd.random() - 0.5) * 0.06)
                        if yy == 0:
                            c = mix(c, hi, 0.5)
                        elif yy == hgt - 2:
                            c = mix(c, sh, 0.55)
                        if xx == bw - 2:
                            c = mix(c, sh, 0.45)
                        s.set(px, py, c)
            x += bw
        y0 += hgt
        r += 1


def ragged_top(s, depth, rnd):
    """Knock notches out of the top edge so the silhouette isn't a square."""
    x = 0
    while x < s.w:
        w = rnd.randrange(2, 6)
        d = rnd.randrange(0, depth + 1)
        for xx in range(x, min(s.w, x + w)):
            for y in range(d):
                s.set(xx, y, (0, 0, 0, 0))
        x += w


def fortress_face(v):
    rnd = random.Random(3000 + v)
    s = Spr(16, 24)
    blocks_face(s, 4, rnd, [FORT["block"], FORT["block2"], FORT["block3"]], FORT["hi"], FORT["sh"], FORT["mortar"])
    for x in range(16):   # coping stone along the top
        for y in range(0, 4):
            s.set(x, y, FORT["cap_hi"] if y == 0 else (FORT["cap"] if y < 3 else FORT["sh"]))
    for x in range(16):   # dark foot + moss creeping up
        s.set(x, 23, FORT["dark"])
        for y in range(22 - rnd.randrange(0, 4), 23):
            if rnd.random() < 0.6:
                s.set(x, y, MOSS["mid"] if rnd.random() < 0.6 else MOSS["dark"])
    if v == 1:   # ivy
        for x in range(16):
            ln = int(4 + 9 * abs(math.sin(x * 0.8 + 2)) + rnd.random() * 3)
            for y in range(3, min(22, 3 + ln)):
                if rnd.random() < 0.8:
                    s.set(x, y, COURT["ivy"] if (x + y) % 3 else COURT["ivy_hi"])
    if v == 2:   # barred window
        for y in range(8, 17):
            for x in range(5, 11):
                s.set(x, y, hx("08070c"))
        for x in (6, 8, 10):
            for y in range(8, 17):
                s.set(x, y, hx("5a5468"))
        for x in range(4, 12):
            s.set(x, 7, FORT["cap_hi"])
            s.set(x, 17, FORT["sh"])
    if v == 3:   # iron torch bracket
        for (x, y) in [(7, 9), (8, 9), (7, 10), (8, 10), (7, 11), (8, 11), (6, 12), (9, 12), (7, 13), (8, 13)]:
            s.set(x, y, hx("3a3036"))
        s.set(7, 8, hx("6a5a48"))
        s.set(8, 8, hx("6a5a48"))
    return s.img


def fortress_top(v):
    rnd = random.Random(3100 + v)
    s = Spr(16, 16)
    for y in range(16):
        for x in range(16):
            s.set(x, y, FORT["block2"] if rnd.random() < 0.7 else FORT["block"])
    # walkway down the middle, merlons on the edges
    for y in range(16):
        for x in range(4, 12):
            s.set(x, y, shade(FORT["block"], 0.7))
    for y in range(0, 16, 6):
        for x in list(range(0, 4)) + list(range(12, 16)):
            for yy in range(y, min(16, y + 4)):
                s.set(x, yy, FORT["cap_hi"] if yy == y else FORT["cap"])
    if v == 1:
        for _ in range(5):
            s.set(rnd.randrange(4, 12), rnd.randrange(16), MOSS["mid"])
    return s.img


def court_tall(v):
    rnd = random.Random(3200 + v)
    s = Spr(16, 24)
    blocks_face(s, 3, rnd, [COURT["brick"], COURT["brick2"]], COURT["brick_hi"], COURT["brick_sh"], COURT["mortar"])
    for x in range(16):
        s.set(x, 3, COURT["rim"])
        s.set(x, 23, hx("1a1612"))
    ragged_top(s, 5 if v != 0 else 3, rnd)
    if v == 1:
        for x in range(16):
            ln = int(4 + 10 * abs(math.sin(x * 0.9 + 1)) + rnd.random() * 3)
            for y in range(3, min(22, 3 + ln)):
                if rnd.random() < 0.8 and s.get(x, y)[3]:
                    s.set(x, y, COURT["ivy"] if (x + y) % 3 else COURT["ivy_hi"])
    if v == 2:   # arched window
        for y in range(8, 19):
            for x in range(5, 11):
                if not (y == 8 and x in (5, 10)):
                    s.set(x, y, hx("0e0b10"))
    return s.img


def cliff_tall(v):
    rnd = random.Random(3300 + v)
    s = Spr(16, 24)
    bands = [0, 4, 9, 13, 18, 24]
    for i in range(len(bands) - 1):
        base = [MTN["rock"], MTN["rock2"], hx("847466"), MTN["rock"], hx("5e524a")][(i + v) % 5]
        for y in range(bands[i], bands[i + 1]):
            for x in range(16):
                c = shade(base, 1.18 - y / 30.0 + (rnd.random() - 0.5) * 0.08)
                if y == bands[i]:
                    c = mix(c, MTN["rock_hi"], 0.55)
                elif y == bands[i + 1] - 1:
                    c = mix(c, MTN["rock_sh"], 0.5)
                s.set(x, y, c)
    for _ in range(3):
        x = rnd.randrange(2, 14)
        for y in range(rnd.randrange(3, 8), rnd.randrange(12, 23)):
            s.set(x, y, MTN["rock_dk"])
            s.set(x + 1, y, MTN["rock_hi"])
            if rnd.random() < 0.3:
                x += rnd.choice([-1, 1])
    for x in range(16):
        s.set(x, 23, MTN["rock_dk"])
    ragged_top(s, 6, rnd)
    # light catches the new top edge
    for x in range(16):
        for y in range(24):
            if s.get(x, y)[3]:
                s.set(x, y, MTN["rock_hi"])
                break
    if v == 3:
        for _ in range(8):
            x, y = rnd.randrange(16), rnd.randrange(4, 12)
            if s.get(x, y)[3]:
                s.set(x, y, MTN["lichen"])
    return s.img


def arch_front():
    """A stone gate over a north-south passage: two pillars and an arch."""
    rnd = random.Random(3400)
    s = Spr(48, 40)
    # pillars (left 0-15, right 32-47), rising the full height
    for (x0, x1) in ((2, 16), (32, 46)):
        for y in range(4, 40):
            for x in range(x0, x1):
                c = shade(FORT["block3"], 1.15 - y / 60.0)
                if (y - 4) % 7 == 0:
                    c = FORT["mortar"]
                elif x == x0:
                    c = FORT["hi"]
                elif x == x1 - 1:
                    c = FORT["sh"]
                elif (x + (y // 7) * 3) % 8 == 0:
                    c = FORT["mortar"]
                s.set(x, y, c)
        for x in range(x0 - 1, x1 + 1):   # capitals
            s.set(x, 4, FORT["cap_hi"])
            s.set(x, 5, FORT["cap"])
            s.set(x, 39, FORT["dark"])
    # the arch: voussoirs around a half circle over the opening (x 16-31)
    cx, cy = 24.0, 22.0
    for y in range(0, 24):
        for x in range(10, 38):
            d = math.hypot(x + 0.5 - cx, (y + 0.5 - cy) * 1.1)
            if 9.0 <= d <= 15.5:
                ang = math.atan2(y + 0.5 - cy, x + 0.5 - cx)
                seg = int((ang + math.pi) / (math.pi / 7))
                c = FORT["block"] if seg % 2 else FORT["block3"]
                if d > 14.5:
                    c = FORT["cap_hi"]
                elif d < 10.0:
                    c = FORT["sh"]
                s.set(x, y, c)
    # keystone with a carved mark
    for y in range(6, 12):
        for x in range(22, 26):
            s.set(x, y, FORT["cap_hi"] if y == 6 else FORT["cap"])
    s.set(23, 9, hx("7a6aa8"))
    s.set(24, 9, hx("7a6aa8"))
    # shadow under the arch's inner curve
    for y in range(18, 24):
        for x in range(16, 32):
            d = math.hypot(x + 0.5 - cx, (y + 0.5 - cy) * 1.1)
            if 8.0 <= d < 9.0:
                s.set(x, y, (10, 8, 14, 160))
    # ivy over one side
    for x in range(30, 44):
        ln = int(3 + 8 * abs(math.sin(x * 0.7)) + rnd.random() * 3)
        for y in range(5, min(30, 5 + ln)):
            if rnd.random() < 0.7 and s.get(x, y)[3]:
                s.set(x, y, COURT["ivy"] if (x + y) % 3 else COURT["ivy_hi"])
    return s.img


def arch_side():
    """The arch seen edge-on over an east-west passage: a stone band rising
    from the wall above and spanning the top of the passage."""
    s = Spr(16, 40)
    for y in range(0, 30):
        for x in range(3, 13):
            c = shade(FORT["block3"], 1.15 - y / 50.0)
            if y % 7 == 0:
                c = FORT["mortar"]
            elif x == 3:
                c = FORT["hi"]
            elif x == 12:
                c = FORT["sh"]
            s.set(x, y, c)
    for x in range(2, 14):
        s.set(x, 0, FORT["cap_hi"])
        s.set(x, 29, FORT["dark"])
    for y in range(30, 33):   # shadow it casts on the passage floor
        for x in range(3, 13):
            s.set(x, y, (10, 8, 14, 120))
    return s.img


def crown(v):
    rnd = random.Random(3500 + v)
    s = Spr(32, 32)
    blobs = []
    n = 6 + v
    for i in range(n):
        ang = rnd.random() * math.tau
        rr = rnd.uniform(3, 8)
        blobs.append((16 + math.cos(ang) * rr, 15 + math.sin(ang) * rr * 0.8, rnd.uniform(6, 9)))
    blobs.append((16, 15, 10))
    tint = [FOREST["can_dk"], FOREST["can"], FOREST["can_mid"], FOREST["can_hi"], FOREST["can_tip"]]
    # outline pass then fill, blobs sorted top-down so upper ones sit behind
    blobs.sort(key=lambda b: b[1])
    for (cx, cy, r) in blobs:
        for y in range(32):
            for x in range(32):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                if d <= r + 1:
                    s.set(x, y, hx("0e1f12"))
    for (cx, cy, r) in blobs:
        for y in range(32):
            for x in range(32):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                if d <= r:
                    k = (-(x - cx) - (y - cy)) / (r * 1.5)
                    i = 2
                    if k > 0.45:
                        i = 4 if d < r * 0.55 and rnd.random() < 0.5 else 3
                    elif k > 0.1:
                        i = 3 if rnd.random() < 0.3 else 2
                    elif k < -0.45:
                        i = 0
                    elif k < -0.1:
                        i = 1
                    if d > r - 1.0:
                        i = max(0, i - 1)
                    s.set(x, y, tint[i])
    # leaf speckle
    for _ in range(40):
        x, y = rnd.randrange(32), rnd.randrange(32)
        if s.get(x, y)[3] and s.get(x, y) != hx("0e1f12"):
            s.set(x, y, shade(s.get(x, y), rnd.choice([0.8, 1.15])))
    return s.img


def boulders(v):
    rnd = random.Random(3600 + v)
    s = Spr(32, 32)
    rocks = [(12 + rnd.uniform(-2, 2), 18, 10, 8), (22, 14 + rnd.uniform(-2, 2), 7, 6), (9, 10, 6, 5)][: 2 + v % 2]
    rocks.sort(key=lambda r: r[1])
    for (cx, cy, rx, ry) in rocks:
        for y in range(32):
            for x in range(32):
                d = ((x + 0.5 - cx) / (rx + 1)) ** 2 + ((y + 0.5 - cy) / (ry + 1)) ** 2
                if d <= 1:
                    s.set(x, y, MTN["rock_dk"])
        for y in range(32):
            for x in range(32):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                d = dx * dx + dy * dy
                if d <= 1:
                    k = -dx - dy
                    c = MTN["rock"]
                    if k > 0.6:
                        c = MTN["rock_hi"]
                    elif k < -0.5:
                        c = MTN["rock_sh"]
                    elif k < 0:
                        c = MTN["rock2"]
                    s.set(x, y, shade(c, 1 + (rnd.random() - 0.5) * 0.06))
        for _ in range(3):
            x, y = int(cx + rnd.uniform(-rx / 2, 0)), int(cy + rnd.uniform(-ry / 2, 0))
            s.set(x, y, MTN["lichen"])
    return s.img


def tall_tree(v):
    """A whole tree, 32 x 48: a big crown on a trunk, roots in the ground.
    Stands on the forest's edge so the woods have real height."""
    rnd = random.Random(3700 + v)
    s = Spr(32, 48)
    # trunk
    tx0, tx1 = 13, 19
    for y in range(24, 46):
        for x in range(tx0, tx1):
            c = FOREST["trunk"]
            if x == tx0:
                c = FOREST["trunk_hi"]
            elif x >= tx1 - 2:
                c = FOREST["trunk_dk"]
            if (y * 3 + x) % 7 == 0:
                c = shade(c, 0.8)
            s.set(x, y, c)
    for (x, y) in [(11, 45), (12, 45), (12, 44), (19, 45), (20, 45), (19, 44), (10, 46), (21, 46)]:
        s.set(x, y, FOREST["trunk_dk"])
    for x in range(10, 22):
        s.set(x, 47, (10, 8, 6, 160))
    # crown (re-using the round canopy), with a shadow on the trunk under it
    c = crown(v).load()
    for y in range(32):
        for x in range(32):
            if c[x, y][3]:
                s.set(x, y + (0 if v != 2 else 2), c[x, y])
    for y in range(28, 32):
        for x in range(tx0, tx1):
            if not s.get(x, y)[3] or s.get(x, y) == FOREST["trunk"] or s.get(x, y) == FOREST["trunk_hi"]:
                s.set(x, y, FOREST["trunk_dk"])
    return s.img


def build():
    sheet = Image.new("RGBA", (128, 200), (0, 0, 0, 0))
    for i in range(4):
        sheet.paste(fortress_face(i), (i * 16, 0))
        sheet.paste(court_tall(i), (64 + i * 16, 0))
        sheet.paste(cliff_tall(i), (i * 16, 24))
        sheet.paste(crown(i), (i * 32, 88))
    for i in range(2):
        sheet.paste(fortress_top(i), (64 + i * 16, 24))
    sheet.paste(arch_front(), (0, 48))
    sheet.paste(arch_side(), (48, 48))
    for i in range(3):
        sheet.paste(boulders(i), (i * 32, 120))
        sheet.paste(tall_tree(i), (i * 32, 152))
    return sheet


if __name__ == "__main__":
    build().save(OUT / "tall.png")
    print("wrote tall.png")
