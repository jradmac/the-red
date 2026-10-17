"""Builds the art for the insides of village buildings.

    python3 tools/make_interiors.py

assets/interiors.png    floor tiles (16x16), wall strips (16x32: the back wall
                        seen face on, ceiling trim at the top, skirting at the
                        bottom) and furniture, packed in rows.
scripts/interior_art.gd where everything is in the sheet (generated, don't edit):
                        ART[name] = [Rect2 in the sheet, footprint w, h (tiles),
                        kind] where kind is "block" (furniture you bump into),
                        "floor" (rugs: walk on them) or "wall" (hangs on the
                        back wall). A sprite stands with its bottom on the
                        bottom of its footprint.
"""
from pathlib import Path
import math
import random
import sys

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_env import hx, mix, shade  # noqa: E402
from make_village import Canvas, noise, OUTLINE, WINDOW  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets"
W = 512

C = dict(
    wood=hx("9a6a3e"), wood_dk=hx("6a4426"), wood_lt=hx("c08a54"), wood_xdk=hx("4a2e1a"),
    oak=hx("b8864e"), oak_lt=hx("d8a868"), oak_dk=hx("8a5e34"),
    cream=hx("ece0c4"), cream_dk=hx("cbbd9c"),
    red=hx("c0393f"), red_dk=hx("862636"), red_lt=hx("e2574f"),
    blue=hx("4d6fb0"), blue_dk=hx("34507e"), blue_lt=hx("7a9ad8"),
    green=hx("4a8a4a"), green_dk=hx("2e5a32"), green_lt=hx("7ab46a"),
    purple=hx("5a3e8a"), purple_dk=hx("3a2660"), purple_lt=hx("8a6ac0"),
    gold=hx("e8b84a"), gold_dk=hx("a87a26"),
    stone=hx("7a7488"), stone_dk=hx("524c60"), stone_lt=hx("9e98ac"),
    iron=hx("3a3440"), iron_lt=hx("6a6478"),
    white=hx("f4f0e8"), glass=hx("bfe6ff"),
)


# ---------------------------------------------------------------------------
# Floors and walls
# ---------------------------------------------------------------------------
def floor_wood(cv, v):
    for y in range(16):
        plank = (y // 4)
        off = (plank * 7 + v * 5) % 16
        for x in range(16):
            base = [C["oak"], shade(C["oak"], 0.94), shade(C["oak"], 1.04), shade(C["oak"], 0.9)][(plank + v) % 4]
            c = base
            if y % 4 == 3:
                c = C["oak_dk"]
            elif (x + off) % 16 == 0:
                c = C["oak_dk"]
            elif noise(x, y, 3 + v) < 0.07:
                c = shade(base, 0.9)
            elif y % 4 == 0:
                c = shade(base, 1.06)
            cv.set(x, y, c)


def floor_check(cv, v, a="e9dcc0", b="d2c19e", line="b8a684"):
    ca, cb = hx(a), hx(b)
    for y in range(16):
        for x in range(16):
            c = ca if ((x // 8) + (y // 8) + v) % 2 == 0 else cb
            if x % 8 == 7 or y % 8 == 7:
                c = hx(line)
            elif x % 8 == 0 or y % 8 == 0:
                c = shade(c, 1.04)
            cv.set(x, y, c)


def floor_stone(cv, v, base="6a6478", dk="4e485c", lt="847e92"):
    b = hx(base)
    for y in range(16):
        for x in range(16):
            cell = ((x + (y // 8 % 2) * 4 + v * 3) // 8, y // 8)
            n = noise(cell[0], cell[1], 7 + v)
            c = mix(hx(dk), hx(lt), 0.35 + n * 0.4)
            if (x + (y // 8 % 2) * 4 + v * 3) % 8 == 7 or y % 8 == 7:
                c = hx(dk)
            cv.set(x, y, c)


def doormat(cv):
    floor_wood(cv, 0)
    cv.rect(1, 3, 14, 11, C["red_dk"])
    cv.rect(2, 4, 12, 9, C["red"])
    for x in range(3, 13, 2):
        cv.vline(x, 5, 7, C["red_lt"])
    cv.hline(1, 13, 14, shade(C["red_dk"], 0.7))


def wall_strip(cv, body, body_dk, pattern, v):
    """16x32: ceiling trim (4), the wall (24), skirting board (4)."""
    for y in range(32):
        for x in range(16):
            c = body
            if pattern == "panel":
                if x % 8 == 0:
                    c = body_dk
                elif x % 8 == 1:
                    c = shade(body, 1.08)
                elif noise(x, y // 3, 5 + v) < 0.08:
                    c = shade(body, 0.94)
                if y in (14, 15):
                    c = shade(body_dk, 0.9)
            elif pattern == "paper":
                if (x + (y // 6) * 4 + v * 2) % 8 == 0 and y % 6 in (1, 2, 3):
                    c = body_dk
                elif (x + (y // 6) * 4 + 4) % 8 == 0 and y % 6 == 4:
                    c = shade(body_dk, 1.1)
                if y in (18, 19):
                    c = C["wood_dk"]
                if y > 19:
                    c = shade(body, 0.9) if x % 4 else shade(body_dk, 0.95)
            elif pattern == "stone":
                row = y // 6
                off = 4 if row % 2 else 0
                c = body
                if y % 6 == 5 or (x + off + v * 2) % 8 == 7:
                    c = body_dk
                elif y % 6 == 0:
                    c = shade(body, 1.1)
                elif noise(x, y, 9 + v) < 0.08:
                    c = shade(body, 0.9)
            elif pattern == "plaster":
                c = body if noise(x, y, 13 + v) > 0.08 else body_dk
                if y in (18, 19):
                    c = C["wood_dk"]
                if 19 < y:
                    c = C["wood"] if x % 8 else C["wood_dk"]
            cv.set(x, y, c)
    cv.rect(0, 0, 16, 3, hx("2a1e1a"))
    cv.hline(0, 3, 16, shade(body, 0.7))
    cv.rect(0, 28, 16, 3, C["wood_dk"])
    cv.hline(0, 28, 16, C["wood_lt"])
    cv.hline(0, 31, 16, C["wood_xdk"])


# ---------------------------------------------------------------------------
# Furniture
# ---------------------------------------------------------------------------
def box3d(cv, x, y, w, h, top_h, front, top, edge=None):
    """A block seen from the front and a little above: a top face and a front face."""
    cv.rect(x, y, w, top_h, top)
    cv.hline(x, y, w, shade(top, 1.12))
    cv.rect(x, y + top_h, w, h - top_h, front)
    cv.hline(x, y + top_h, w, edge or shade(front, 0.75))
    cv.vline(x, y + top_h, h - top_h, shade(front, 1.1))
    cv.vline(x + w - 1, y + top_h, h - top_h, shade(front, 0.8))


def shelf(cv, kind):
    """32x40, stands against the back wall."""
    box3d(cv, 1, 2, 30, 37, 3, C["wood"], C["wood_lt"])
    cv.rect(3, 6, 26, 31, C["wood_xdk"])
    rnd = random.Random(hash(kind) % 1000)
    for s in range(3):
        sy = 6 + s * 10
        cv.rect(3, sy + 9, 26, 2, C["wood_lt"])
        cv.hline(3, sy + 10, 26, C["wood_dk"])
        x = 4
        while x < 28:
            if kind == "potions":
                col = rnd.choice([C["red"], C["blue"], C["green"], C["gold"], C["purple_lt"]])
                cv.rect(x + 1, sy + 1, 2, 2, C["cream"])
                cv.rect(x, sy + 3, 4, 6, col)
                cv.set(x + 1, sy + 4, shade(col, 1.4))
                x += 5
            elif kind == "goods":
                k = rnd.randrange(3)
                if k == 0:   # bread
                    cv.rect(x, sy + 5, 6, 4, hx("c8904a"))
                    cv.hline(x + 1, sy + 5, 4, hx("e0b070"))
                    x += 7
                elif k == 1:   # a jar
                    cv.rect(x, sy + 3, 4, 6, hx("d0c0a0"))
                    cv.rect(x, sy + 2, 4, 1, C["red_dk"])
                    x += 5
                else:   # a little box
                    cv.rect(x, sy + 4, 5, 5, hx("8a6a44"))
                    cv.hline(x, sy + 4, 5, hx("aa8a5c"))
                    x += 6
            elif kind == "books":
                h = rnd.randint(6, 8)
                col = rnd.choice([C["red_dk"], C["blue_dk"], C["green_dk"], hx("6a4a2a"), C["purple_dk"]])
                cv.rect(x, sy + 9 - h, 2, h, col)
                cv.set(x, sy + 9 - h + 1, shade(col, 1.5))
                x += 2 + (1 if rnd.random() < 0.2 else 0)
            elif kind == "bottles":
                col = rnd.choice([hx("4a7a3a"), hx("6a3a2a"), hx("8a7a3a"), hx("3a5a6a")])
                cv.rect(x + 1, sy + 1, 1, 3, col)
                cv.rect(x, sy + 4, 3, 5, col)
                cv.set(x, sy + 5, shade(col, 1.6))
                x += 4
            elif kind == "jars":
                col = rnd.choice([hx("8aa060"), hx("a06aa0"), hx("c0a050"), hx("60a0a0")])
                cv.rect(x, sy + 3, 5, 6, hx("c8d8d8"))
                cv.rect(x + 1, sy + 5, 3, 3, col)
                cv.rect(x, sy + 2, 5, 1, C["wood_dk"])
                x += 6
            else:   # dishes
                cv.rect(x, sy + 4, 6, 5, C["white"])
                cv.hline(x, sy + 6, 6, C["blue_lt"])
                x += 7
    cv.outline(0, 0, 32, 40)


def counter(cv, part):
    """16x24, footprint 1 tile; the top is 8 px, the front 16."""
    box3d(cv, 0, 6, 16, 18, 5, C["wood"], C["oak_lt"])
    cv.hline(0, 6, 16, C["oak_lt"])
    for x in range(2, 16, 5):
        cv.vline(x, 12, 11, C["wood_dk"])
    if part == "l":
        cv.vline(0, 6, 18, C["wood_xdk"])
    if part == "r":
        cv.vline(15, 6, 18, C["wood_xdk"])
    if part == "till":
        cv.rect(4, 1, 8, 6, C["iron"])
        cv.rect(5, 2, 6, 2, C["gold"])
        cv.set(6, 5, C["cream"])
        cv.set(9, 5, C["cream"])
    if part == "mugs":
        for x0 in (2, 9):
            cv.rect(x0, 4, 4, 4, hx("c8b080"))
            cv.rect(x0, 3, 4, 1, C["white"])
            cv.set(x0 + 4, 5, hx("c8b080"))
    cv.outline(0, 0, 16, 24)


def display_table(cv):
    box3d(cv, 1, 8, 30, 16, 7, C["wood"], C["red"])
    cv.hline(1, 8, 30, C["red_lt"])
    cv.rect(4, 3, 6, 6, C["blue"])        # potion
    cv.rect(6, 1, 2, 2, C["cream"])
    cv.rect(13, 5, 7, 4, C["gold"])       # lantern
    cv.rect(15, 2, 3, 3, C["iron"])
    cv.rect(23, 4, 5, 5, C["green"])      # bottle
    cv.set(25, 2, C["cream"])
    cv.outline(0, 0, 32, 24)


def barrel(cv):
    for y in range(6, 23):
        for x in range(2, 14):
            c = C["wood"] if 3 < x < 12 else C["wood_dk"]
            if x == 5:
                c = C["wood_lt"]
            if y in (9, 18):
                c = C["iron"]
            cv.set(x, y, c)
    cv.rect(3, 4, 10, 3, C["wood_lt"])
    cv.rect(4, 5, 8, 1, C["wood_dk"])
    cv.outline(0, 0, 16, 24)


def crate(cv):
    box3d(cv, 1, 7, 14, 16, 4, hx("a87444"), hx("c8945c"))
    for i in range(10):
        cv.set(3 + i, 12 + i * 9 // 10, hx("6a4426"))
    cv.outline(0, 0, 16, 24)


def sack(cv):
    for y in range(6, 20):
        for x in range(2, 14):
            dx = (x - 8) / 6.0
            dy = (y - 13) / 7.0
            if dx * dx + dy * dy <= 1.0:
                cv.set(x, y, hx("c8b080") if dx < 0.3 else hx("a89060"))
    cv.rect(6, 4, 4, 3, hx("a89060"))
    cv.hline(5, 7, 6, hx("6a5a3a"))
    cv.outline(0, 0, 16, 20)


def plant(cv):
    cv.rect(4, 19, 8, 8, hx("b0603e"))
    cv.rect(3, 18, 10, 2, hx("c87a50"))
    cv.vline(5, 20, 6, hx("d08a60"))
    for i, (x, y, r) in enumerate(((8, 11, 6), (5, 8, 4), (11, 8, 4), (8, 4, 4))):
        for yy in range(y - r, y + r + 1):
            for xx in range(x - r, x + r + 1):
                if (xx - x) ** 2 + (yy - y) ** 2 <= r * r:
                    c = C["green"] if (xx + yy) % 5 else C["green_dk"]
                    if (xx - x) + (yy - y) < -r * 0.6:
                        c = C["green_lt"]
                    cv.set(xx, yy, c)
    cv.outline(0, 0, 16, 28)


def table(cv, cloth=None):
    top = cloth or C["oak_lt"]
    box3d(cv, 1, 6, 30, 12, 8, C["wood"], top)
    cv.rect(3, 18, 3, 6, C["wood_dk"])
    cv.rect(26, 18, 3, 6, C["wood_dk"])
    cv.rect(12, 2, 8, 6, C["white"])      # a bowl
    cv.rect(13, 1, 6, 2, hx("c87a50"))
    cv.outline(0, 0, 32, 24)


def stool(cv):
    cv.rect(3, 4, 10, 4, C["oak_lt"])
    cv.hline(3, 4, 10, shade(C["oak_lt"], 1.1))
    cv.rect(3, 8, 10, 2, C["wood_dk"])
    cv.rect(4, 10, 2, 5, C["wood_dk"])
    cv.rect(10, 10, 2, 5, C["wood_dk"])
    cv.outline(0, 0, 16, 16)


def rug(cv, w, h, a, b, edge, rune=False):
    for y in range(h):
        for x in range(w):
            c = a
            if x < 2 or y < 2 or x >= w - 2 or y >= h - 2:
                c = edge
            elif (x // 4 + y // 4) % 2 == 0 and not rune:
                c = b
            cv.set(x, y, c)
    if rune:
        cx, cy = w / 2, h / 2
        for ang in range(0, 360, 3):
            for rr in (h * 0.38, h * 0.26):
                x = int(cx + math.cos(math.radians(ang)) * rr * (w / h))
                y = int(cy + math.sin(math.radians(ang)) * rr)
                cv.set(x, y, b)
        # a ring of little stars and a crescent moon in the middle (a sage's star circle)
        for k in range(8):
            ang = math.radians(k * 45)
            x = int(cx + math.cos(ang) * h * 0.32 * (w / h))
            y = int(cy + math.sin(ang) * h * 0.32)
            for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                cv.set(x + dx, y + dy, hx("f5e08a"))
        for yy in range(-6, 7):
            for xx in range(-6, 7):
                if xx * xx + yy * yy <= 36 and (xx - 3) ** 2 + (yy + 1) ** 2 > 25:
                    cv.set(int(cx) + xx, int(cy) + yy, hx("f5e08a"))
    for x in range(0, w, 2):
        cv.set(x, 0, shade(edge, 0.7))
        cv.set(x, h - 1, shade(edge, 0.7))


def fireplace(cv):
    cv.rect(0, 2, 32, 38, C["stone"])
    for y in range(2, 40, 5):
        cv.hline(0, y, 32, C["stone_dk"])
        for x in range((y // 5 % 2) * 4, 32, 8):
            cv.vline(x, y, 5, C["stone_dk"])
    cv.rect(0, 0, 32, 4, C["wood_dk"])
    cv.hline(0, 0, 32, C["wood_lt"])
    cv.rect(6, 16, 20, 24, hx("1a1010"))
    cv.rect(5, 15, 22, 2, C["stone_lt"])
    cv.rect(8, 34, 16, 3, hx("4a2a1a"))    # logs
    cv.rect(10, 32, 12, 2, hx("6a3a22"))
    cv.outline(0, 0, 32, 40)


def bed(cv, blanket, blanket_dk):
    cv.rect(1, 0, 14, 6, C["wood_dk"])             # headboard
    cv.hline(1, 0, 14, C["wood_lt"])
    cv.rect(1, 5, 14, 25, C["wood"])
    cv.rect(2, 5, 12, 22, C["white"])
    cv.rect(3, 6, 10, 6, hx("fffaf0"))            # pillow
    cv.hline(3, 11, 10, C["cream_dk"])
    cv.rect(2, 13, 12, 14, blanket)
    cv.hline(2, 13, 12, shade(blanket, 1.25))
    for y in range(16, 27, 4):
        cv.hline(2, y, 12, blanket_dk)
    cv.rect(1, 27, 14, 4, C["wood_dk"])
    cv.outline(0, 0, 16, 32)


def stairs(cv):
    for k in range(6):
        y = 2 + k * 6
        cv.rect(2, y, 28, 6, shade(C["oak"], 0.7 + k * 0.06))
        cv.hline(2, y, 28, C["oak_lt"])
        cv.hline(2, y + 5, 28, C["oak_dk"])
    cv.rect(0, 0, 3, 40, C["wood_dk"])
    cv.rect(29, 0, 3, 40, C["wood_dk"])
    cv.outline(0, 0, 32, 40)


def cauldron(cv):
    for y in range(8, 22):
        for x in range(2, 22):
            dx = (x - 12) / 10.0
            dy = (y - 13) / 9.0
            if dx * dx + dy * dy <= 1.0:
                cv.set(x, y, C["iron"] if dx > -0.4 else C["iron_lt"])
    cv.rect(3, 7, 18, 4, hx("2a2430"))
    cv.rect(5, 7, 14, 3, hx("6ad06a"))
    cv.rect(7, 7, 4, 1, hx("b8ffb0"))
    cv.rect(4, 20, 3, 4, C["iron"])
    cv.rect(17, 20, 3, 4, C["iron"])
    cv.outline(0, 0, 24, 24)


def crystal(cv):
    cv.rect(5, 15, 6, 9, C["wood_dk"])
    cv.rect(3, 13, 10, 3, C["wood"])
    for y in range(2, 14):
        for x in range(2, 14):
            dx, dy = (x - 8) / 5.5, (y - 8) / 5.5
            if dx * dx + dy * dy <= 1.0:
                c = hx("8a6ac0") if dx + dy > 0.2 else hx("c8b0ff")
                cv.set(x, y, c)
    cv.set(6, 5, C["white"])
    cv.set(5, 6, C["white"])
    cv.outline(0, 0, 16, 24)


def low_table(cv):
    box3d(cv, 1, 8, 30, 12, 6, C["purple_dk"], C["purple"])
    cv.rect(4, 2, 2, 7, C["cream"])            # candles
    cv.set(4, 1, C["gold"])
    cv.rect(26, 3, 2, 6, C["cream"])
    cv.set(26, 2, C["gold"])
    cv.rect(11, 5, 10, 4, hx("c8b080"))        # an open book
    cv.vline(16, 5, 4, hx("8a7050"))
    cv.outline(0, 0, 32, 20)


def candle_stand(cv):
    cv.rect(7, 6, 2, 16, C["gold_dk"])
    cv.rect(4, 21, 8, 2, C["gold_dk"])
    cv.rect(5, 4, 6, 2, C["gold"])
    cv.rect(7, 1, 2, 3, C["cream"])
    cv.outline(0, 0, 16, 24)


def clock(cv):
    box3d(cv, 2, 2, 12, 30, 2, C["wood"], C["wood_lt"])
    cv.rect(4, 5, 8, 8, C["cream"])
    cv.set(8, 7, C["iron"])
    cv.vline(8, 7, 3, C["iron"])
    cv.hline(8, 9, 2, C["iron"])
    cv.rect(5, 16, 6, 12, C["wood_xdk"])
    cv.vline(8, 17, 7, C["gold"])
    cv.rect(7, 23, 3, 3, C["gold"])
    cv.outline(0, 0, 16, 32)


def stove(cv):
    box3d(cv, 1, 8, 30, 32, 5, C["iron"], C["iron_lt"])
    cv.rect(4, 18, 10, 10, hx("1a1010"))
    cv.rect(5, 23, 8, 4, hx("c0502a"))
    cv.rect(18, 18, 10, 14, C["iron_lt"])
    cv.rect(20, 3, 9, 6, hx("8a8a92"))     # a pot
    cv.rect(19, 2, 11, 2, hx("aaaab2"))
    cv.rect(24, 0, 2, 2, C["iron"])
    cv.rect(26, 10, 4, 30, C["iron"])      # flue
    cv.outline(0, 0, 32, 40)


def window(cv, curtain):
    cv.rect(0, 0, 24, 18, C["wood_dk"])
    cv.rect(2, 2, 20, 14, hx("1a2040"))
    for x, y in ((5, 4), (14, 6), (18, 3), (9, 9)):
        cv.set(x, y, hx("e8e8ff"))
    cv.vline(11, 2, 14, C["wood_dk"])
    cv.vline(12, 2, 14, C["wood_dk"])
    cv.hline(2, 8, 20, C["wood_dk"])
    if curtain:
        cv.rect(0, 0, 5, 18, curtain)
        cv.rect(19, 0, 5, 18, curtain)
        cv.vline(2, 0, 18, shade(curtain, 0.8))
        cv.vline(21, 0, 18, shade(curtain, 0.8))
    cv.hline(0, 17, 24, C["wood_lt"])


def star_chart(cv):
    cv.rect(0, 0, 32, 18, hx("c8b890"))
    cv.rect(1, 1, 30, 16, hx("1a1a40"))
    rnd = random.Random(4)
    for k in range(14):
        cv.set(rnd.randint(2, 29), rnd.randint(2, 15), hx("f5e08a"))
    for k in range(20):
        x = int(16 + math.cos(k * 0.4) * (3 + k * 0.5))
        y = int(9 + math.sin(k * 0.4) * (2 + k * 0.25))
        cv.set(x, y, hx("8a8ad0"))


def painting(cv):
    cv.rect(0, 0, 16, 14, C["gold_dk"])
    cv.rect(1, 1, 14, 12, hx("6aa0d0"))
    cv.rect(1, 8, 14, 5, hx("4a8a4a"))
    cv.rect(9, 4, 3, 3, hx("f5e08a"))
    cv.rect(3, 6, 4, 3, hx("3e6a3a"))


def herbs(cv):
    cv.hline(0, 1, 32, C["wood_dk"])
    for x in range(2, 32, 6):
        cv.vline(x, 2, 3, hx("6a5a40"))
        cv.rect(x - 1, 5, 3, 6, [hx("5a8a4a"), hx("8a7a4a"), hx("7a5a8a")][x % 3])


def crest(cv):
    cv.rect(2, 0, 12, 14, C["red_dk"])
    cv.rect(3, 1, 10, 12, C["red"])
    cv.rect(5, 4, 6, 4, C["gold"])
    cv.rect(7, 2, 2, 8, C["gold"])
    cv.set(7, 12, C["red_dk"])


ITEMS = [
    # name, w, h, foot (w, h), kind, painter
    ("shelf_potions", 32, 40, (2, 1), "block", lambda cv: shelf(cv, "potions")),
    ("shelf_goods", 32, 40, (2, 1), "block", lambda cv: shelf(cv, "goods")),
    ("bookshelf", 32, 40, (2, 1), "block", lambda cv: shelf(cv, "books")),
    ("shelf_bottles", 32, 40, (2, 1), "block", lambda cv: shelf(cv, "bottles")),
    ("shelf_jars", 32, 40, (2, 1), "block", lambda cv: shelf(cv, "jars")),
    ("cupboard", 32, 40, (2, 1), "block", lambda cv: shelf(cv, "dishes")),
    ("fireplace", 32, 40, (2, 1), "block", fireplace),
    ("stairs", 32, 40, (2, 1), "block", stairs),
    ("stove", 32, 40, (2, 1), "block", stove),
    ("counter_l", 16, 24, (1, 1), "block", lambda cv: counter(cv, "l")),
    ("counter_m", 16, 24, (1, 1), "block", lambda cv: counter(cv, "m")),
    ("counter_r", 16, 24, (1, 1), "block", lambda cv: counter(cv, "r")),
    ("counter_till", 16, 24, (1, 1), "block", lambda cv: counter(cv, "till")),
    ("counter_mugs", 16, 24, (1, 1), "block", lambda cv: counter(cv, "mugs")),
    ("display", 32, 24, (2, 1), "block", display_table),
    ("table", 32, 24, (2, 1), "block", table),
    ("table_cloth", 32, 24, (2, 1), "block", lambda cv: table(cv, hx("e8dfc8"))),
    ("low_table", 32, 20, (2, 1), "block", low_table),
    ("barrel", 16, 24, (1, 1), "block", barrel),
    ("crate", 16, 24, (1, 1), "block", crate),
    ("sack", 16, 20, (1, 1), "block", sack),
    ("plant", 16, 28, (1, 1), "block", plant),
    ("stool", 16, 16, (1, 1), "block", stool),
    ("clock", 16, 32, (1, 1), "block", clock),
    ("candle_stand", 16, 24, (1, 1), "block", candle_stand),
    ("crystal", 16, 24, (1, 1), "block", crystal),
    ("cauldron", 24, 24, (1, 1), "block", cauldron),
    ("bed_blue", 16, 32, (1, 2), "block", lambda cv: bed(cv, C["blue"], C["blue_dk"])),
    ("bed_red", 16, 32, (1, 2), "block", lambda cv: bed(cv, C["red"], C["red_dk"])),
    ("bed_green", 16, 32, (1, 2), "block", lambda cv: bed(cv, C["green"], C["green_dk"])),
    ("rug_red", 48, 32, (3, 2), "floor", lambda cv: rug(cv, 48, 32, C["red"], C["red_dk"], C["gold_dk"])),
    ("rug_blue", 48, 32, (3, 2), "floor", lambda cv: rug(cv, 48, 32, C["blue"], C["blue_dk"], C["cream_dk"])),
    ("rug_green", 64, 32, (4, 2), "floor", lambda cv: rug(cv, 64, 32, C["green"], C["green_dk"], C["oak_dk"])),
    ("rug_rune", 64, 48, (4, 3), "floor", lambda cv: rug(cv, 64, 48, C["purple_dk"], hx("c8a8ff"), C["purple"], rune=True)),
    ("window", 24, 18, (0, 0), "wall", lambda cv: window(cv, None)),
    ("window_red", 24, 18, (0, 0), "wall", lambda cv: window(cv, C["red"])),
    ("window_blue", 24, 18, (0, 0), "wall", lambda cv: window(cv, C["blue"])),
    ("star_chart", 32, 18, (0, 0), "wall", star_chart),
    ("painting", 16, 14, (0, 0), "wall", painting),
    ("herbs", 32, 12, (0, 0), "wall", herbs),
    ("crest", 16, 14, (0, 0), "wall", crest),
]

FLOORS = [("wood_a", lambda cv: floor_wood(cv, 0)), ("wood_b", lambda cv: floor_wood(cv, 1)),
          ("check_a", lambda cv: floor_check(cv, 0)), ("check_b", lambda cv: floor_check(cv, 1)),
          ("stone_a", lambda cv: floor_stone(cv, 0)), ("stone_b", lambda cv: floor_stone(cv, 1)),
          ("purple_a", lambda cv: floor_stone(cv, 0, "4a3a5e", "2e2440", "5e4a76")),
          ("purple_b", lambda cv: floor_stone(cv, 1, "4a3a5e", "2e2440", "5e4a76")),
          ("green_a", lambda cv: floor_check(cv, 0, "a8c8a0", "8ab088", "6a906a")),
          ("green_b", lambda cv: floor_check(cv, 1, "a8c8a0", "8ab088", "6a906a")),
          ("doormat", doormat)]
WALLS = [("panel", (C["wood"], C["wood_dk"], "panel")), ("paper_green", (hx("7aa07a"), hx("5a805a"), "paper")),
         ("paper_red", (hx("a04a42"), hx("7a3430"), "paper")), ("stone", (hx("4e4660"), hx("342e44"), "stone")),
         ("plaster", (hx("e4d8bc"), hx("c8b898"), "plaster")), ("paper_blue", (hx("7a8ab0"), hx("5a6a90"), "paper"))]


def build():
    rows = []
    img = Image.new("RGBA", (W, 400), (0, 0, 0, 0))
    root = Canvas(img)
    art = {}
    x = 0
    for name, painter in FLOORS:
        painter(root.at(x, 0))
        art[name] = (x, 0, 16, 16, 1, 1, "tile")
        x += 16
    x = 0
    for name, (body, dk, pat) in WALLS:
        for v in range(2):
            wall_strip(root.at(x, 16), body, dk, pat, v)
            art[name + ("_b" if v else "")] = (x, 16, 16, 32, 1, 2, "wallstrip")
            x += 16
    # pack the furniture in rows
    x, y, row_h = 0, 48, 0
    for name, w, h, foot, kind, painter in ITEMS:
        if x + w > W:
            x, y, row_h = 0, y + row_h + 1, 0
        painter(root.at(x, y))
        art[name] = (x, y, w, h, foot[0], foot[1], kind)
        x += w + 1
        row_h = max(row_h, h)
    height = y + row_h + 1
    img = img.crop((0, 0, W, height))
    img.save(OUT / "interiors.png")
    lines = ["# Generated by tools/make_interiors.py -- don't edit by hand.",
             "class_name InteriorArt", "", "## name -> [Rect2 in assets/interiors.png, footprint w, footprint h, kind]",
             "const ART := {"]
    for name, (ax, ay, aw, ah, fw, fh, kind) in art.items():
        lines.append(f'\t"{name}": [Rect2({ax}, {ay}, {aw}, {ah}), {fw}, {fh}, "{kind}"],')
    lines.append("}")
    (ROOT / "scripts" / "interior_art.gd").write_text("\n".join(lines) + "\n")
    print("wrote interiors.png", img.size, len(art), "sprites")


if __name__ == "__main__":
    build()
