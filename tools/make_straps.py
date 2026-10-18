"""Builds the straps that hold the hero's weapon on their back:

    assets/straps.png        the small (overworld) hero: 32 x 32 cells
    assets/straps_big.png    the big hero (bag, battle): 128 x 128 cells

A cell holds the hero's 16 x 24 frame (64 x 96 for the big one) with a margin
of 8 (32) all round, since the weapon pokes out of the frame. Columns are the
facings (down, up, left, right). Row 0 is the baldric -- the leather strap
from one shoulder to the other hip: over the chest from the front and side,
under the weapon on the back. Row 1 is the two loops that bind the weapon to
it, seen from behind (drawn over the weapon).

The geometry matches HeroLook.CARRY_OFF / CARRY_OFF_BIG: where the weapon
sits for each facing, its grip over the right shoulder and the blade down
across the back (the loops line up with it seen from behind).
Run:  python3 tools/make_straps.py
"""
import math
from pathlib import Path

from PIL import Image

from pixkit import Sprite

ROOT = Path(__file__).resolve().parent.parent

# all in small-frame units (the 16 x 24 frame); the big hero is 4x
BALDRIC = {
    0: [(4.2, 12.0), (8.2, 15.6), (11.8, 18.8)],     # over the right shoulder (left as you see it) to the left hip
    1: [(14.2, 11.6), (9.4, 16.0), (4.4, 20.6)],     # on the back: right shoulder to left hip
    2: [(9.8, 12.0), (8.0, 15.2), (6.4, 18.6)],      # from the side: over the near shoulder, down the chest
    3: [(6.2, 12.0), (8.0, 15.2), (9.6, 18.6)],
}
BUCKLE = {0: (8.2, 15.6), 2: (8.0, 15.4), 3: (8.0, 15.4)}
# the small hero's head is bigger for its body: its strap starts lower
BALDRIC_SMALL = {
    0: [(3.6, 14.0), (8.0, 17.0), (12.4, 19.6)],
    1: [(14.0, 13.0), (9.0, 17.0), (4.0, 21.0)],
    2: [(9.6, 13.6), (8.0, 16.2), (6.6, 19.0)],
    3: [(6.4, 13.6), (8.0, 16.2), (9.4, 19.0)],
}
BUCKLE_SMALL = {0: (8.0, 17.0)}
GRIP_BACK = (14.5, 8.5)                              # the weapon's grip, seen from behind
AXIS = (-1 / math.sqrt(2), 1 / math.sqrt(2))         # grip -> point, seen from behind
ACROSS = (1 / math.sqrt(2), 1 / math.sqrt(2))
LOOPS_AT = (5.2, 8.6)                                # how far down the weapon each loop is

LEATHER = (74, 46, 32, 255)
LEATHER_HI = (122, 80, 48, 255)
BRASS = (232, 184, 80, 255)
OUT = (26, 16, 34, 255)


def small_sheet():
    img = Image.new("RGBA", (32 * 4, 32 * 2), (0, 0, 0, 0))

    def put(x, y, c, cell, row):
        x, y = int(math.floor(x)) + 8, int(math.floor(y)) + 8
        if 0 <= x < 32 and 0 <= y < 32:
            img.putpixel((cell * 32 + x, row * 32 + y), c)

    def line(a, b, c, cell, row):
        n = int(max(abs(b[0] - a[0]), abs(b[1] - a[1])) * 2) + 1
        for k in range(n + 1):
            put(a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n, c, cell, row)

    for f, pts in BALDRIC_SMALL.items():
        for i in range(len(pts) - 1):
            line(pts[i], pts[i + 1], LEATHER, f, 0)
        if f in BUCKLE_SMALL:
            put(*BUCKLE_SMALL[f], BRASS, f, 0)
    for t in LOOPS_AT:
        c = (GRIP_BACK[0] + AXIS[0] * t, GRIP_BACK[1] + AXIS[1] * t)
        a = (c[0] - ACROSS[0] * 1.4, c[1] - ACROSS[1] * 1.4)
        b = (c[0] + ACROSS[0] * 1.6, c[1] + ACROSS[1] * 1.6)
        line(a, b, LEATHER_HI, 1, 1)
    return img


def big_sheet():
    img = Image.new("RGBA", (128 * 4, 128 * 2), (0, 0, 0, 0))
    pal = {"strap": "5c3a24", "brass": "d8a040"}

    def P(p):
        return (p[0] * 4 + 32, p[1] * 4 + 32)

    for f, pts in BALDRIC.items():
        s = Sprite(128, 128, grain=0.10, cast=False)
        s.limb([P(p) for p in pts], 1.9, "strap", bands=(-0.4, 0.1, 0.6, 0.95))
        # stitching down both edges
        for i in range(len(pts) - 1):
            a, b = P(pts[i]), P(pts[i + 1])
            ln = math.dist(a, b)
            ux, uy = (b[0] - a[0]) / ln, (b[1] - a[1]) / ln
            for k in range(1, int(ln), 3):
                for side in (-1, 1):
                    s.pdot(round(a[0] + ux * k - uy * side * 1.2), round(a[1] + uy * k + ux * side * 1.2), "strap", 4)
        if f in BUCKLE:
            bx, by = P(BUCKLE[f])
            s.poly([(bx - 3, by - 3), (bx + 3, by - 3), (bx + 3, by + 3), (bx - 3, by + 3)], "brass", tone=3)
            s.poly([(bx - 1.5, by - 1.5), (bx + 1.5, by - 1.5), (bx + 1.5, by + 1.5), (bx - 1.5, by + 1.5)], "strap",
                   tone=1, outline=False)
            s.pdot(bx - 2, by - 2, "brass", 5)
            s.pline([(bx, by - 1), (bx, by + 1)], "brass", 4)
        img.paste(s.image(pal), (f * 128, 0))
    s = Sprite(128, 128, grain=0.10, cast=False)
    for t in LOOPS_AT:
        c = P((GRIP_BACK[0] + AXIS[0] * t, GRIP_BACK[1] + AXIS[1] * t))
        a = (c[0] - ACROSS[0] * 6.5, c[1] - ACROSS[1] * 6.5)
        b = (c[0] + ACROSS[0] * 7.5, c[1] + ACROSS[1] * 7.5)
        s.limb([a, b], 1.7, "strap", bands=(-0.4, 0.1, 0.6, 0.95))
        s.pdot(round(b[0] - ACROSS[0] * 2.5), round(b[1] - ACROSS[1] * 2.5), "brass", 4)   # a little buckle
        s.pdot(round(b[0] - ACROSS[0] * 3.5), round(b[1] - ACROSS[1] * 3.5), "brass", 2)
    img.paste(s.image(pal), (128, 128))
    return img


def main():
    small_sheet().save(ROOT / "assets" / "straps.png")
    big_sheet().save(ROOT / "assets" / "straps_big.png")
    print("wrote the weapon straps")


if __name__ == "__main__":
    main()
