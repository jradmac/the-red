"""Builds the hero's getting-out-of-bed frames (hero_wake*.png), one sheet
per body sheet (hero.png, hero_blue.png, hero_p2.png, hero_p2_blue.png), so
every look and colour matches. Used by HeroLook.draw_pose (the waking on the
bier, and the inns' beds).

Rows: the looks (as in hero.png, 7). Columns, each a 40 x 32 cell with the hip
at HIP:
  0 LYING     lying back, seen from above: the plain front figure, feet
              showing at the bottom as usual
  1 RISING    sitting up: the feet drawn up into the hood, a pixel higher
  2 TUCKED    sat up, legs drawn up out of sight under the cloak
  3 PERCHED   the same, a pixel lower (settled on the edge, about to hop)
(hopping down, the feet come back out: the plain standing frame.)

The body is cut from the standing front frame and the legs from the
right-facing side frame. Turned whole quarter turns where it can; the in-
between angles are turned at 8x and brought back down by majority, then the
outline is drawn again round the whole figure, so the hip never shows a seam.
Run:  python3 tools/make_wake_frames.py
"""
from collections import Counter
from pathlib import Path

from PIL import Image

ASSETS = Path(__file__).resolve().parent.parent / "assets"
CELL = (40, 32)
HIP = (20, 22)
FW, FH = 16, 24
LOOKS = 7
OUT = (28, 16, 32, 255)   # the outline colour (hero.png's)


def frame(sheet, look, facing):
    return sheet.crop((0, (look * 4 + facing) * FH, FW, (look * 4 + facing) * FH + FH))


def upper(front):
    """Head and body (rows 0-19) and the lantern hanging from the right hand."""
    u = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    u.paste(front.crop((0, 0, FW, 20)), (0, 0))
    for y in range(20, FH):
        for x in range(13, FW):
            p = front.getpixel((x, y))
            if p[3]:
                u.putpixel((x, y), p)
    return u


def side_legs(front, length):
    """Legs seen from the side, stretched out to the right from the hip (at
    (0, 3.5)), toes up -- one leg over the other, in the look's own trousers
    and boots (picked off the standing frame)."""
    a = OUT
    n = front.getpixel((6, 20))     # trousers
    s = front.getpixel((5, 21))     # ...in shadow
    u = front.getpixel((5, 22))     # boots
    L = length
    rows = [
        "." * (L - 3) + "aa.",
        "." * (L - 3) + "aua",
        "a" * (L - 3) + "aua",
        "a" + "n" * (L - 4) + "uua",
        "a" + "s" * (L - 4) + "uua",
        "." + "a" * (L - 1),
    ]
    pal = {"a": a, "n": n, "s": s, "u": u}
    out = Image.new("RGBA", (L, len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal:
                out.putpixel((x, y), pal[ch])
    return out


def tucked(front, drop=0):
    """Sat up with the legs drawn in under the cloak: the standing front frame
    with the legs (rows 20+) painted over in whatever the body is wearing just
    above them, and the figure ending 2 rows higher -- a seated lump."""
    t = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    t.paste(front.crop((0, 0, FW, 20)), (0, drop))
    for x in range(FW):
        # the colour of the garment at the bottom of the body in this column
        above = None
        for y in (19, 18, 17):
            p = front.getpixel((x, y))
            if p[3] and p != OUT:
                above = p
                break
        if above is None:
            continue
        for y in (20, 21):
            # a hem that curves in at the sides
            if (x <= 1 or x >= FW - 2) and y == 21:
                continue
            if 0 <= y + drop < FH:
                t.putpixel((x, y + drop), above if y == 20 else tuple(max(0, int(v * 0.72)) for v in above[:3]) + (255,))
    # keep the lantern hanging from the right hand
    for y in range(20, FH):
        for x in range(13, FW):
            p = front.getpixel((x, y))
            if p[3] and 0 <= y + drop < FH:
                t.putpixel((x, y + drop), p)
    return t


def turn(img, deg, pivot):
    """Turns `img` by `deg` (counter-clockwise) about `pivot`, crisp: done at
    8x and each pixel taken from the most common colour in its 8 x 8 block."""
    if deg % 90 == 0:
        k = (deg // 90) % 4
        out = img
        px, py = pivot
        w, h = img.size
        for _ in range(k):
            out = out.transpose(Image.ROTATE_90)
            px, py = py, w - px
            w, h = h, w
        return out, (px, py)
    S = 8
    big = img.resize((img.width * S, img.height * S), Image.NEAREST)
    pad = max(img.size) * S * 2
    canvas = Image.new("RGBA", (pad, pad), (0, 0, 0, 0))
    off = (pad // 2 - int(pivot[0] * S), pad // 2 - int(pivot[1] * S))
    canvas.paste(big, off)
    rot = canvas.rotate(deg, resample=Image.NEAREST, center=(pad // 2, pad // 2))
    n = pad // S
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    rp = rot.load()
    for y in range(n):
        for x in range(n):
            c = Counter()
            for yy in range(y * S + 1, y * S + S, 2):
                for xx in range(x * S + 1, x * S + S, 2):
                    p = rp[xx, yy]
                    c[p if p[3] >= 128 else None] += 1
            best, cnt = c.most_common(1)[0]
            if best is not None and cnt >= 7:
                out.putpixel((x, y), best)
            elif best is None and len(c) > 1 and c[None] < 10:
                out.putpixel((x, y), [k for k, _ in c.most_common() if k is not None][0])
    return out, (n / 2, n / 2)


def put(cell, img, pivot, at):
    x0, y0 = round(at[0] - pivot[0]), round(at[1] - pivot[1])
    cell.alpha_composite(img, (0, 0), (0, 0)) if False else None
    for y in range(img.height):
        for x in range(img.width):
            p = img.getpixel((x, y))
            if p[3] and 0 <= x0 + x < CELL[0] and 0 <= y0 + y < CELL[1]:
                cell.putpixel((x0 + x, y0 + y), p)


def outline(cell):
    """Redraws the outline round the outside of the whole figure."""
    w, h = cell.size
    px = cell.load()
    add = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3]:
                continue
            if any(0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3] and px[x + dx, y + dy] != OUT
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                add.append((x, y))
    for p in add:
        px[p] = OUT


def build(sheet):
    out = Image.new("RGBA", (CELL[0] * 4, CELL[1] * LOOKS), (0, 0, 0, 0))
    for look in range(LOOKS):
        front = frame(sheet, look, 0)
        up = upper(front)
        body_hip = (8, 19.5)      # the hip in the upper piece
        leg_hip = (0.5, 3.5)      # ...and in the legs
        legs_flat = side_legs(front, 10)
        legs_long = side_legs(front, 11)
        legs_half, lh_hip = turn(side_legs(front, 9), -45, leg_hip)
        cells = []
        # 0 lying back: the plain front figure, seen from above, feet at the bottom
        c = Image.new("RGBA", CELL, (0, 0, 0, 0))
        put(c, front, body_hip, HIP)
        cells.append(c)
        # 1 sitting up: the feet drawn up into the hood, the body lifting a pixel
        c = Image.new("RGBA", CELL, (0, 0, 0, 0))
        put(c, tucked(front), body_hip, (HIP[0], HIP[1] - 1))
        cells.append(c)
        # 2 sat up, legs tucked away under the cloak
        c = Image.new("RGBA", CELL, (0, 0, 0, 0))
        put(c, tucked(front), body_hip, HIP)
        cells.append(c)
        # 3 perched on the edge, settled a pixel lower, about to hop down
        c = Image.new("RGBA", CELL, (0, 0, 0, 0))
        put(c, tucked(front), body_hip, (HIP[0], HIP[1] + 1))
        cells.append(c)
        for i, c in enumerate(cells):
            outline(c)
            out.paste(c, (i * CELL[0], look * CELL[1]))
    return out


def main():
    for name in ("hero", "hero_blue", "hero_p2", "hero_p2_blue"):
        sheet = Image.open(ASSETS / (name + ".png")).convert("RGBA")
        build(sheet).save(ASSETS / (name.replace("hero", "hero_wake") + ".png"))
    print("wrote the waking frames")


if __name__ == "__main__":
    main()
