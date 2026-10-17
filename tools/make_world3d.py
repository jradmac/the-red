"""Tileable pixel-art materials for the 3D world (16 px per tile, so they sit
with the rest of the art). Every texture repeats seamlessly.

    python3 tools/make_world3d.py      ->  assets/w3d/*.png

Walls are built like real walls: a body of coursed stone (`*_side`), a
coping of cap stones along the top (`*_cap_side` / `*_cap_top`), and the solid
ground between walls (`*_mass`). Rock and earth for cliffs, bark and leaves for
trees.
"""
from pathlib import Path
import random

from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "w3d"
OUT.mkdir(parents=True, exist_ok=True)


def hx(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


def shade(c, k):
    return tuple(max(0, min(255, int(c[i] * k))) for i in range(3)) + (255,)


def noise(x, y, s):
    h = (x * 374761393 + y * 668265263 + s * 1442695041) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def save(img, name):
    img.save(OUT / (name + ".png"))


# --- Coursed stone -----------------------------------------------------------------

def masonry(w, h, pal, course=6, seed=1, moss=None, moss_amt=0.0, irregular=True):
    """Stone blocks in courses, offset every other course, with mortar lines,
    a lit top edge and a shaded bottom edge on every block (a little relief)."""
    img = Image.new("RGBA", (w, h))
    rng = random.Random(seed)
    rows = h // course
    for r in range(rows):
        y0 = r * course
        # block widths for this course (they must wrap round the texture)
        widths = []
        total = 0
        while total < w:
            bw = rng.choice([7, 8, 9, 10, 11, 12]) if irregular else 8
            widths.append(bw)
            total += bw
        widths[-1] -= total - w
        if widths[-1] < 4:
            widths[-2] += widths[-1]
            widths.pop()
        off = rng.randrange(w)
        x = 0
        for bi, bw in enumerate(widths):
            tone = rng.choice([0, 0, 1, 1, 2]) * 0.06 + rng.random() * 0.04
            base = mix(pal["stone"], pal["stone_lt"], tone * 3)
            for dy in range(course):
                for dx in range(bw):
                    px = (off + x + dx) % w
                    py = y0 + dy
                    c = base
                    if dy == course - 1 or dx == bw - 1:
                        c = pal["mortar"]
                    elif dy == 0:
                        c = pal["stone_lt"]
                    elif dy == course - 2:
                        c = shade(base, 0.82)
                    elif dx == 0:
                        c = mix(base, pal["stone_lt"], 0.4)
                    # grain and pits
                    n = noise(px, py, seed)
                    if c != pal["mortar"] and n < 0.08:
                        c = shade(c, 0.85)
                    if c != pal["mortar"] and n > 0.96:
                        c = mix(c, pal["stone_lt"], 0.5)
                    img.putpixel((px, py), c)
            x += bw
    if moss:
        for y in range(h):
            for x in range(w):
                # moss collects low down and in the mortar
                low = y / h
                m = noise(x // 2, y // 2, seed + 7)
                if m < moss_amt * (0.3 + low):
                    c = img.getpixel((x, y))
                    img.putpixel((x, y), mix(c, moss, 0.75))
    return img


def cap_top(w, h, pal, seed=2):
    """Cap stones seen from above: square-ish slabs, bevelled, worn and cracked."""
    img = Image.new("RGBA", (w, h))
    rng = random.Random(seed)
    for by in range(0, h, 8):
        off = 4 if (by // 8) % 2 else 0
        for bx in range(-8, w, 8):
            tone = rng.random() * 0.3
            base = mix(pal["cap"], pal["cap_lt"], tone)
            for dy in range(8):
                for dx in range(8):
                    x = (bx + dx + off) % w
                    y = by + dy
                    c = base
                    if dx == 7 or dy == 7:
                        c = pal["mortar"]
                    elif dx == 0 or dy == 0:
                        c = mix(base, pal["cap_hi"], 0.35)
                    elif dx == 6 or dy == 6:
                        c = shade(base, 0.82)
                    n = noise(x, y, seed)
                    if c != pal["mortar"] and n < 0.08:
                        c = shade(c, 0.86)
                    img.putpixel((x, y), c)
    return img


def cap_side(w, h, pal, seed=3):
    """The coping's front edge: a lit lip, the stone, a dark drip line under it."""
    img = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            t = y / max(1, h - 1)
            c = mix(pal["cap_lt"], pal["cap"], t * 0.8)
            if y == 0:
                c = pal["cap_hi"]
            if y == h - 1:
                c = shade(pal["mortar"], 0.8)
            if x % 8 == 7 and 0 < y < h - 1:
                c = pal["mortar"]
            if noise(x, y, seed) < 0.06:
                c = shade(c, 0.85)
            img.putpixel((x, y), c)
    return img


def rubble(w, h, pal, seed=4, grass=None, grass_amt=0.0):
    """Packed earth and broken stone: the solid ground between walls, seen from above."""
    img = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            n = noise(x, y, seed)
            n2 = noise(x // 3, y // 3, seed + 1)
            c = mix(pal["mass"], pal["mass_lt"], n2 * 0.7)
            if n < 0.12:
                c = pal["mass_dk"]
            elif n > 0.9:
                c = mix(c, pal["mass_lt"], 0.6)
            img.putpixel((x, y), c)
    # a few stones with a lit top-left edge
    rng = random.Random(seed)
    for k in range(w * h // 70):
        sx, sy = rng.randrange(w), rng.randrange(h)
        r = rng.choice([1, 2, 2, 3])
        tone = mix(pal["mass_lt"], pal["cap"], rng.random() * 0.5)
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r:
                    c = tone
                    if dx + dy < -r * 0.6:
                        c = mix(tone, pal["cap_lt"], 0.5)
                    elif dx + dy > r * 0.6:
                        c = shade(tone, 0.75)
                    img.putpixel(((sx + dx) % w, (sy + dy) % h), c)
    if grass:
        for y in range(h):
            for x in range(w):
                if noise(x // 2, y // 2, seed + 5) < grass_amt:
                    img.putpixel((x, y), mix(img.getpixel((x, y)), grass, 0.7))
    return img


def strata(w, h, pal, seed=5, lip=None):
    """Layered rock / earth: a cliff face. `lip`: grass hanging over the top."""
    img = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            band = (y + int(noise(x // 4, 0, seed) * 3)) % 6
            c = [pal["rock_lt"], pal["rock"], pal["rock"], pal["rock_dk"], pal["rock"], pal["rock"]][band]
            n = noise(x, y, seed)
            if n < 0.07:
                c = shade(c, 0.8)
            elif n > 0.95:
                c = mix(c, pal["rock_lt"], 0.5)
            # vertical cracks
            if noise(x, y // 5, seed + 3) < 0.05:
                c = pal["rock_dk"]
            img.putpixel((x, y), c)
    if lip:
        for x in range(w):
            hang = 2 + int(noise(x, 0, seed + 9) * 3)
            for y in range(hang):
                img.putpixel((x, y), lip if y < hang - 1 else shade(lip, 0.7))
    return img


def leaves(w, h, pal, seed=6):
    """A tangle of leaves, lit from the upper left, for the round tree crowns."""
    img = Image.new("RGBA", (w, h), pal["leaf_dk"])
    rng = random.Random(seed)
    for k in range(w * h // 14):
        cx, cy = rng.randrange(w), rng.randrange(h)
        r = rng.choice([2, 3, 3, 4])
        tone = rng.choice([pal["leaf"], pal["leaf"], pal["leaf_lt"], pal["leaf_dk"]])
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r + 1:
                    c = tone
                    if dx + dy < -r:
                        c = mix(tone, pal["leaf_lt"], 0.6)
                    elif dx + dy > r * 0.8:
                        c = pal["leaf_dk"]
                    img.putpixel(((cx + dx) % w, (cy + dy) % h), c)
    return img


def bark(w, h, pal, seed=7):
    img = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            stripe = (x + int(noise(0, y // 3, seed) * 2)) % 5
            c = [pal["bark_lt"], pal["bark"], pal["bark"], pal["bark_dk"], pal["bark"]][stripe]
            if noise(x, y, seed) < 0.1:
                c = pal["bark_dk"]
            img.putpixel((x, y), c)
    return img


# --- Palettes (from the hand-drawn art, so nothing changes mood) -------------------

CRYPT = dict(stone=hx("3a3349"), stone_lt=hx("4d4560"), stone_hi=hx("6c6384"), mortar=hx("16121c"),
             ivy=hx("2c4a34"), ivy_lt=hx("3f6646"), ivy_dk=hx("1a2e20"),
             cap=hx("5c536e"), cap_lt=hx("6c6282"), cap_hi=hx("968cae"),
             mass=hx("2a2533"), mass_lt=hx("3a3446"), mass_dk=hx("1c1824"))
COURT = dict(stone=hx("7e6c56"), stone_lt=hx("98846a"), stone_hi=hx("bba78a"), mortar=hx("3a3028"),
             ivy=hx("4a6a36"), ivy_lt=hx("6a8a48"), ivy_dk=hx("2c4420"),
             cap=hx("a89a80"), cap_lt=hx("b8aa90"), cap_hi=hx("dacbac"),
             mass=hx("7e7262"), mass_lt=hx("8a7e6c"), mass_dk=hx("62574a"))
ROCK = dict(rock=hx("85786d"), rock_lt=hx("a6988a"), rock_dk=hx("524840"),
            mass=hx("5a5048"), mass_lt=hx("7a6e60"), mass_dk=hx("3e3630"),
            cap=hx("8a7e70"), cap_lt=hx("a6988a"))
EARTH = dict(rock=hx("7a6248"), rock_lt=hx("9a8060"), rock_dk=hx("54402e"))
SWAMP_EARTH = dict(rock=hx("5a5a3e"), rock_lt=hx("767654"), rock_dk=hx("3c3c28"))
CRYPT_EARTH = dict(rock=hx("4e4860"), rock_lt=hx("6a6480"), rock_dk=hx("342e44"))
COURT_EARTH = dict(rock=hx("b8b0a0"), rock_lt=hx("d4ccbc"), rock_dk=hx("8a8272"))
FOREST = dict(leaf=hx("2f5f38"), leaf_lt=hx("4c8a4a"), leaf_dk=hx("17331f"),
              bark=hx("4a3326"), bark_lt=hx("6a4a34"), bark_dk=hx("2c1e17"))
SWAMP = dict(leaf=hx("4a5a2e"), leaf_lt=hx("6a7a3c"), leaf_dk=hx("242c16"),
             bark=hx("3e3a2a"), bark_lt=hx("5a5440"), bark_dk=hx("221e14"))


def planks(w, h, pal, seed=8, vertical=True, bands=None, band_rows=(), rivets=True):
    """Wooden planks; `bands`: a metal colour for iron straps across them."""
    img = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            k = x if vertical else y
            board = k // 4
            c = mix(pal["wood"], pal["wood_lt"], (noise(board, 0, seed) * 0.6))
            if k % 4 == 3:
                c = pal["wood_dk"]
            elif k % 4 == 0:
                c = mix(c, pal["wood_lt"], 0.4)
            g = noise((x if not vertical else x // 4), (y if vertical else y // 4) + x, seed + 1)
            if g < 0.1:
                c = shade(c, 0.85)
            img.putpixel((x, y), c)
    if bands:
        for r in band_rows:
            for x in range(w):
                for dy in range(2):
                    c = bands["metal"] if dy == 0 else bands["metal_dk"]
                    if (vertical and x % 4 == 1 and dy == 0 and rivets):
                        c = bands["metal_lt"]
                    img.putpixel((x, r + dy) if vertical else (r + dy, x), c)
    return img


def stone_block(w, h, pal, seed=9, carve=None):
    img = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            n = noise(x, y, seed)
            c = mix(pal["cap"], pal["cap_lt"], noise(x // 3, y // 3, seed + 2) * 0.6)
            if n < 0.08:
                c = shade(c, 0.85)
            elif n > 0.95:
                c = pal["cap_hi"]
            if x == 0 or y == 0:
                c = mix(c, pal["cap_hi"], 0.4)
            if x == w - 1 or y == h - 1:
                c = shade(c, 0.75)
            img.putpixel((x, y), c)
    if carve == "cross":
        cx = w // 2
        for y in range(3, h - 4):
            img.putpixel((cx, y), shade(pal["cap"], 0.55))
        for x in range(cx - 3, cx + 4):
            img.putpixel((x, 6), shade(pal["cap"], 0.55))
    return img


WOOD = dict(wood=hx("6a4426"), wood_lt=hx("8a5c34"), wood_dk=hx("3a2416"))
METALS = {
    "bronze": dict(metal=hx("b07a3a"), metal_lt=hx("e0a860"), metal_dk=hx("6a4420")),
    "silver": dict(metal=hx("a8b0bc"), metal_lt=hx("e4e8f0"), metal_dk=hx("5c6270")),
    "gold": dict(metal=hx("e0b040"), metal_lt=hx("fff0a0"), metal_dk=hx("8a6418")),
    "purple": dict(metal=hx("9a5ad0"), metal_lt=hx("d0a0ff"), metal_dk=hx("4a2470")),
    "iron": dict(metal=hx("4a4650"), metal_lt=hx("7a7684"), metal_dk=hx("26232c")),
}



# --- The villages -----------------------------------------------------------------

VILLAGE = [   # per village style: roof, roof light, roof dark, wall wood / stone
    dict(roof=hx("5a7341"), roof_lt=hx("739c5a"), roof_dk=hx("415a31"), wood=hx("7a5232"), wood_lt=hx("a07448"), wood_dk=hx("4e321e")),
    dict(roof=hx("6a83b4"), roof_lt=hx("8b9ccd"), roof_dk=hx("415273"), stone=hx("cfc6b4"), stone_lt=hx("ece5d4"), mortar=hx("857c6a")),
    dict(roof=hx("c84e42"), roof_lt=hx("ee6252"), roof_dk=hx("8a3a32"), stone=hx("8e887c"), stone_lt=hx("aea898"), mortar=hx("4e4a43")),
    dict(roof=hx("e6ac5a"), roof_lt=hx("ffd68a"), roof_dk=hx("a87a3a"), wood=hx("8a6440"), wood_lt=hx("b08858"), wood_dk=hx("5a3e26")),
    dict(roof=hx("73834a"), roof_lt=hx("98a868"), roof_dk=hx("505a30"), wood=hx("4e4434"), wood_lt=hx("6e624a"), wood_dk=hx("2e281e")),
]


def shingles(w, h, pal, seed=81):
    """Roof tiles in staggered rows, each lit along its top edge."""
    img = Image.new("RGBA", (w, h))
    for y in range(h):
        row = y // 4
        for x in range(w):
            k = (x + (2 if row % 2 else 0)) // 4
            c = mix(pal["roof"], pal["roof_lt"], noise(k, row, seed) * 0.5)
            if y % 4 == 3:
                c = pal["roof_dk"]
            elif y % 4 == 0:
                c = mix(c, pal["roof_lt"], 0.5)
            if (x + (2 if row % 2 else 0)) % 4 == 3 and y % 4 != 0:
                c = mix(c, pal["roof_dk"], 0.6)
            img.putpixel((x, y), c)
    return img


def thatch(w, h, pal, seed=82):
    img = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            n = noise(x, y // 2, seed)
            c = mix(pal["roof"], pal["roof_lt"], n * 0.7)
            if n < 0.18:
                c = pal["roof_dk"]
            if y % 6 == 5:
                c = mix(c, pal["roof_dk"], 0.6)
            img.putpixel((x, y), c)
    return img


def palisade(w, h, pal, seed=83):
    """Sharpened logs standing side by side; above the points it is see-through."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for x in range(w):
        log = x // 4
        k = x % 4
        tip = 3 - abs(2 * k - 3) // 2 * 2 + int(noise(log, 0, seed) * 2)
        for y in range(tip, h):
            c = [pal["wood_lt"], pal["wood"], pal["wood"], pal["wood_dk"]][k]
            if noise(x, y // 2, seed + 1) < 0.12:
                c = shade(c, 0.85)
            if y in (h - 7, h - 6) and k != 3:
                c = pal["wood_dk"]   # the rope binding them
            img.putpixel((x, y), c)
    return img


def plaster(w, h, seed=84):
    base, lt, dk = hx("e8dcc0"), hx("f4ecd8"), hx("c8b898")
    img = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            n = noise(x // 2, y // 2, seed)
            c = mix(base, lt, n * 0.6)
            if noise(x, y, seed + 1) < 0.06:
                c = dk
            img.putpixel((x, y), c)
    return img


def window(w, h):
    frame, glass, lt = hx("4a2c18"), hx("ffe08a"), hx("fff6c8")
    img = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            c = glass
            if x in (0, w - 1) or y in (0, h - 1) or x == w // 2 or y == h // 2:
                c = frame
            elif (x + y) % 5 == 0 and y < h // 2:
                c = lt
            img.putpixel((x, y), c)
    return img


def awning(w, h):
    img = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            c = hx("d84a3a") if (x // 4) % 2 == 0 else hx("f4ecdc")
            if y == h - 1:
                c = shade(c, 0.7)
            img.putpixel((x, y), c)
    return img


def straw(w, h, seed=85):
    pal = dict(roof=hx("d8b048"), roof_lt=hx("f4d878"), roof_dk=hx("9a7428"))
    return thatch(w, h, pal, seed)


def clay(w, h, seed=86):
    img = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            c = mix(hx("b0603a"), hx("d07a48"), noise(x // 2, y, seed) * 0.6)
            if y % 5 == 0:
                c = hx("7a3e24")
            img.putpixel((x, y), c)
    return img



# --- Walls, distinct from floors -----------------------------------------------------
# The floors are small light cobbles. Walls are big dark dressed blocks with
# deep joints and strong relief (lit top edge, shadowed underside, chipped
# corners), moss and damp running down from the top; their tops are smooth
# pale capstones; the thick wall between corridors is overgrown with ivy.

def ashlar(w, h, pal, course=10, seed=1, moss=None):
    img = Image.new("RGBA", (w, h))
    rng = random.Random(seed)
    for r in range(h // course):
        y0 = r * course
        widths, total = [], 0
        while total < w:
            bw = rng.choice([12, 14, 16, 18])
            widths.append(bw)
            total += bw
        widths[-1] -= total - w
        if widths[-1] < 6:
            widths[-2] += widths[-1]
            widths.pop()
        off = rng.randrange(w)
        x = 0
        for bw in widths:
            base = mix(pal["stone"], pal["stone_lt"], rng.random() * 0.45)
            chip = rng.random() < 0.5
            for dy in range(course):
                for dx in range(bw):
                    px, py = (off + x + dx) % w, y0 + dy
                    c = base
                    if dy == course - 1 or dx == bw - 1:
                        c = pal["mortar"]
                    elif dy == course - 2 or dx == bw - 2:
                        c = shade(base, 0.62)          # the block's shadowed underside / right
                    elif dy == 0 or dx == 0:
                        c = mix(base, pal["stone_hi"], 0.55)   # lit top / left edge
                    elif dy == 1:
                        c = mix(base, pal["stone_hi"], 0.2)
                    if chip and dx < 2 and dy < 2 and (dx + dy) < 2:
                        c = pal["mortar"]
                    n = noise(px, py, seed)
                    if c not in (pal["mortar"],) and n < 0.07:
                        c = shade(c, 0.8)
                    img.putpixel((px, py), c)
            # a crack now and then
            if rng.random() < 0.25:
                cx, cy = x + rng.randrange(2, max(3, bw - 3)), y0 + 2
                for k in range(course - 4):
                    cx += rng.choice([-1, 0, 0, 1])
                    img.putpixel(((off + cx) % w, cy + k), pal["mortar"])
            x += bw
    if moss:
        # damp and moss running down from the top in streaks
        for x in range(w):
            run = int(noise(x // 2, 0, seed + 9) * h * 0.55)
            for y in range(run):
                if noise(x, y, seed + 3) < 0.55 - y / max(run, 1) * 0.4:
                    c = img.getpixel((x, y))
                    img.putpixel((x, y), mix(c, moss, 0.35 if y > 3 else 0.6))
    return img


def capstone(w, h, pal, seed=2):
    """Long smooth slabs seen from above, bevelled bright on the lit side."""
    img = Image.new("RGBA", (w, h))
    rng = random.Random(seed)
    for by in range(0, h, 8):
        for bx in (0, 16):
            base = mix(pal["cap"], pal["cap_lt"], 0.3 + rng.random() * 0.35)
            for dy in range(8):
                for dx in range(16):
                    x, y = (bx + dx + (8 if (by // 8) % 2 else 0)) % w, by + dy
                    c = base
                    if dx == 15 or dy == 7:
                        c = pal["mortar"]
                    elif dx == 0 or dy == 0:
                        c = pal["cap_hi"]
                    elif dx == 14 or dy == 6:
                        c = shade(base, 0.78)
                    n = noise(x, y, seed)
                    if c == base and n < 0.06:
                        c = shade(c, 0.9)
                    img.putpixel((x, y), c)
    return img


def ivy_top(w, h, pal, seed=4):
    """The overgrown top of a thick wall: dark stone almost lost under ivy."""
    img = rubble(w, h, pal, seed)
    rng = random.Random(seed)
    for k in range(w * h // 9):
        x, y = rng.randrange(w), rng.randrange(h)
        if noise(x // 6, y // 6, seed + 2) < 0.55:
            leaf = rng.choice([pal["ivy"], pal["ivy"], pal["ivy_lt"], pal["ivy_dk"]])
            for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
                if rng.random() < 0.8:
                    img.putpixel(((x + dx) % w, (y + dy) % h), leaf)
            img.putpixel(((x + 1) % w, (y + 2) % h), pal["ivy_dk"])
    return img



def leaf_clumps(w, h, pal, seed=6):
    """Foliage as the hand-drawn trees have it: round scalloped clumps of
    leaves, each lit on its upper left and outlined dark underneath, layered
    so the clumps lower down sit in the shade of the ones above."""
    img = Image.new("RGBA", (w, h), pal["leaf_dk"])
    rng = random.Random(seed)
    clumps = []
    for k in range(w * h // 40):
        clumps.append((rng.randrange(w), rng.randrange(h), rng.choice([3, 4, 4, 5])))
    clumps.sort(key=lambda c: c[1])        # top first: lower clumps overlap them
    for cx, cy, r in clumps:
        tone = mix(pal["leaf"], pal["leaf_lt"], rng.random() * 0.35)
        for dy in range(-r - 1, r + 2):
            for dx in range(-r - 1, r + 2):
                # a scalloped edge: the radius wobbles round the clump
                import math
                a = math.atan2(dy, dx)
                rr = r + 0.6 * math.sin(a * 5 + cx)
                d = math.hypot(dx, dy)
                if d > rr + 0.7:
                    continue
                x, y = (cx + dx) % w, (cy + dy) % h
                if d > rr - 0.3 and dy >= -1:
                    c = shade(pal["leaf_dk"], 0.75)            # dark outline below
                elif dx + dy < -r * 0.7:
                    c = mix(tone, pal["leaf_lt"], 0.7)         # lit upper left
                elif dx + dy > r * 0.55:
                    c = mix(tone, pal["leaf_dk"], 0.55)
                else:
                    c = tone
                if noise(x, y, seed) < 0.08:
                    c = mix(c, pal["leaf_lt"], 0.5)            # a single leaf catching light
                img.putpixel((x, y), c)
    return img


def needles(w, h, pal, seed=9):
    """Pine boughs: layers of drooping needle sprays (chevrons pointing down),
    light along their upper edges, dark in the gaps."""
    img = Image.new("RGBA", (w, h), shade(pal["leaf_dk"], 0.8))
    rng = random.Random(seed)
    for row in range(-2, h, 5):
        off = rng.randrange(8)
        for cx in range(-8 + off, w + 8, 8):
            for dx in range(-4, 5):
                top = row + abs(dx) // 2            # the spray droops at its tips
                for dy in range(4):
                    x, y = (cx + dx) % w, (top + dy) % h
                    c = pal["leaf"]
                    if dy == 0:
                        c = pal["leaf_lt"] if dx <= 0 else mix(pal["leaf"], pal["leaf_lt"], 0.4)
                    elif dy == 3:
                        c = pal["leaf_dk"]
                    if noise(x, y, seed) < 0.1:
                        c = mix(c, pal["leaf_dk"], 0.5)
                    img.putpixel((x, y), c)
    return img



# --- Terrace ground and the little things growing on it ----------------------------------

def flagstones(w, h, base, lt, dk, gap, moss, seed=101, broken=0.25):
    """Old paving seen from above: irregular slabs, cracked, moss in the joints,
    some slabs missing (earth showing)."""
    img = Image.new("RGBA", (w, h), gap)
    rng = random.Random(seed)
    y = 0
    while y < h:
        rh = rng.choice([6, 7, 8, 9])
        x = rng.randrange(6)
        while x < w + 6:
            rw = rng.choice([7, 8, 10, 12])
            if rng.random() > broken:
                tone = mix(base, lt, rng.random() * 0.5)
                for dy in range(rh - 1):
                    for dx in range(rw - 1):
                        px, py = (x + dx) % w, (y + dy) % h
                        c = tone
                        if dy == 0 or dx == 0:
                            c = mix(tone, lt, 0.5)
                        elif dy == rh - 2 or dx == rw - 2:
                            c = mix(tone, dk, 0.5)
                        if noise(px, py, seed) < 0.06:
                            c = mix(c, dk, 0.4)
                        img.putpixel((px, py), c)
                if rng.random() < 0.4:       # a crack across it
                    cx, cy = x + rng.randrange(1, rw - 1), y + 1
                    for k in range(rh - 2):
                        cx += rng.choice([-1, 0, 1])
                        img.putpixel((cx % w, (cy + k) % h), dk)
            x += rw
        y += rh
    # moss creeping out of the joints
    for yy in range(h):
        for xx in range(w):
            if img.getpixel((xx, yy)) == gap and noise(xx // 2, yy // 2, seed + 3) < 0.6:
                img.putpixel((xx, yy), moss if noise(xx, yy, seed + 4) < 0.7 else shade(moss, 1.25))
    return img


def gravel(w, h, base, lt, dk, seed=102):
    img = Image.new("RGBA", (w, h), dk)
    rng = random.Random(seed)
    for k in range(w * h // 3):
        x, y = rng.randrange(w), rng.randrange(h)
        c = mix(base, lt, rng.random())
        img.putpixel((x, y), c)
        if rng.random() < 0.5:
            img.putpixel(((x + 1) % w, y), shade(c, 0.85))
            img.putpixel((x, (y + 1) % h), shade(c, 0.7))
    return img


def meadow(w, h, grass, grass_lt, grass_dk, flowers, seed=103):
    img = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            n = noise(x, y, seed)
            c = mix(grass, grass_lt, noise(x // 3, y // 3, seed + 1) * 0.6)
            if n < 0.18:
                c = grass_dk
            elif n > 0.9:
                c = grass_lt
            img.putpixel((x, y), c)
    rng = random.Random(seed)
    for k in range(w * h // 40):
        x, y = rng.randrange(w), rng.randrange(h)
        f = rng.choice(flowers)
        img.putpixel((x, y), f)
        img.putpixel(((x + 1) % w, (y + 1) % h), shade(f, 0.7))
    return img


def tuft(w, h, blade, blade_lt, blade_dk, seed=110, flowers=None, fern=False):
    """A clump of grass (or a fern) for a little upright cross of quads: the
    background is see-through."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rng = random.Random(seed)
    if fern:
        import math
        for k in range(6):
            a = math.radians(-75 + k * 30 + rng.uniform(-8, 8))
            ln = rng.uniform(h * 0.55, h * 0.9)
            for t in range(int(ln)):
                f = t / ln
                ang = a * (0.6 + 0.6 * f)                  # fronds arch outward
                x = int(round(w / 2 + math.sin(ang) * t))
                y = int(round(h - 1 - math.cos(ang) * t + f * f * 3))
                if 0 <= x < w and 0 <= y < h:
                    img.putpixel((x, y), blade_lt if t % 3 == 0 else blade)
                    for side in (-1, 1):
                        if t % 2 == 0 and 1 < t < ln - 1:
                            xx, yy = x + side, y + (1 if side > 0 else 0)
                            if 0 <= xx < w and 0 <= yy < h:
                                img.putpixel((xx, yy), blade_dk if f > 0.6 else blade)
        return img
    n = 14
    for k in range(n):
        x0 = w // 2 + rng.randint(-w // 3, w // 3)
        hh = rng.randint(h // 2, h - 1)
        lean = rng.uniform(-0.45, 0.45) if not fern else (k - n // 2) * 0.55
        for t in range(hh):
            x = int(round(x0 + lean * t * (0.6 if not fern else 1.0) * (t / hh)))
            y = h - 1 - t
            if 0 <= x < w:
                c = blade_dk if t < hh * 0.3 else (blade if t < hh * 0.75 else blade_lt)
                img.putpixel((x, y), c)
                if fern and t % 2 == 0 and t > 2:
                    for side in (-1, 1):
                        xx = x + side
                        if 0 <= xx < w:
                            img.putpixel((xx, y), blade)
    if flowers:
        for k in range(3):
            x, y = rng.randrange(2, w - 2), rng.randrange(0, h // 2)
            f = rng.choice(flowers)
            img.putpixel((x, y), f)
            img.putpixel((x + 1, y), f)
            img.putpixel((x, y + 1), shade(f, 0.7))
    return img


def hanging(w, h, leaf, leaf_lt, leaf_dk, seed=120):
    """Ivy or roots hanging down over a ledge: strands of leaves, see-through between."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rng = random.Random(seed)
    for x in range(0, w, 2):
        if rng.random() < 0.25:
            continue
        ln = rng.randint(h // 3, h)
        xx = x
        for y in range(ln):
            if rng.random() < 0.15:
                xx = max(0, min(w - 1, xx + rng.choice([-1, 1])))
            c = leaf if y % 3 else leaf_lt
            if y > ln - 3:
                c = leaf_dk
            img.putpixel((xx, y), c)
            if y % 3 == 1 and xx + 1 < w:
                img.putpixel((xx + 1, y), leaf_dk)
    return img


def build():
    save(ashlar(32, 30, CRYPT, 10, 11, moss=hx("2f4a38")), "crypt_side")
    save(capstone(32, 16, CRYPT, 12), "crypt_cap_top")
    save(cap_side(16, 4, CRYPT, 13), "crypt_cap_side")
    save(ivy_top(32, 32, CRYPT, 14), "crypt_mass")

    save(ashlar(32, 30, COURT, 10, 21, moss=hx("5a6a3a")), "court_side")
    save(capstone(32, 16, COURT, 22), "court_cap_top")
    save(cap_side(16, 4, COURT, 23), "court_cap_side")
    save(ivy_top(32, 32, COURT, 24), "court_mass")

    save(strata(32, 32, ROCK, 31), "rock_side")
    save(rubble(32, 32, ROCK, 32, grass=hx("6a8a4a"), grass_amt=0.18), "rock_top")

    save(strata(32, 16, EARTH, 41, lip=hx("4a7a3a")), "earth_side")
    save(strata(32, 16, SWAMP_EARTH, 42, lip=hx("4a6a2e")), "swamp_side")
    save(strata(32, 16, CRYPT_EARTH, 43), "cryptstep_side")
    save(strata(32, 16, COURT_EARTH, 44), "courtstep_side")
    save(strata(32, 16, ROCK, 45, lip=hx("8a7862")), "mtn_side")

    save(leaf_clumps(32, 32, FOREST, 51), "leaves")
    save(leaf_clumps(32, 32, SWAMP, 52), "swamp_leaves")
    save(needles(16, 16, dict(leaf=hx("1e4232"), leaf_lt=hx("2e6046"), leaf_dk=hx("0e2219")), 53), "needles")
    save(bark(16, 16, FOREST, 53), "bark")
    save(bark(16, 16, SWAMP, 54), "swamp_bark")
    for name, m in METALS.items():
        save(planks(16, 20, WOOD, 61, True, m, (3, 15)), "door_" + name)
        save(planks(16, 16, WOOD, 62, False, m, (2, 12)), "chest_" + name)
        img = Image.new("RGBA", (8, 8))
        for y in range(8):
            for x in range(8):
                c = m["metal"]
                if x == 0 or y == 0:
                    c = m["metal_lt"]
                if x == 7 or y == 7:
                    c = m["metal_dk"]
                img.putpixel((x, y), c)
        save(img, "metal_" + name)
    save(stone_block(16, 16, CRYPT, 71, "cross"), "grave")
    save(stone_block(16, 16, COURT, 72), "pillar")
    save(stone_block(16, 16, CRYPT, 73), "slab")
    for i, pal in enumerate(VILLAGE):
        save(thatch(16, 16, pal, 90 + i) if i == 3 else shingles(16, 16, pal, 90 + i), "roof_%d" % i)
        if "stone" in pal:
            save(masonry(32, 24, dict(stone=pal["stone"], stone_lt=pal["stone_lt"], mortar=pal["mortar"]), 6, 95 + i, irregular=False), "vwall_%d" % i)
            save(planks(16, 16, WOOD, 97 + i, True), "vwood_%d" % i)
        else:
            save(palisade(16, 24, pal, 95 + i), "vwall_%d" % i)
            save(planks(16, 16, pal, 97 + i, True), "vwood_%d" % i)
    save(plaster(16, 16), "plaster")
    save(window(8, 8), "window")
    save(awning(16, 8), "awning")
    save(straw(16, 16), "straw")
    save(clay(16, 16), "clay")
    save(planks(16, 16, dict(wood=hx("4a2c18"), wood_lt=hx("6a4024"), wood_dk=hx("2a180c")), 99, True), "house_door")
    # terrace ground, per landscape
    save(flagstones(32, 32, hx("8a7e70"), hx("a6988a"), hx("524840"), hx("3e3630"), hx("5a6a3a"), 131, 0.15), "rock_slab")
    save(gravel(32, 32, hx("85786d"), hx("b0a292"), hx("4a4038"), 132), "scree")
    save(flagstones(32, 32, hx("4a4258"), hx("5e5670"), hx("221e2b"), hx("1c1824"), hx("2c4a34"), 133, 0.3), "crypt_paving")
    save(gravel(32, 32, hx("3e3648"), hx("5a5268"), hx("1c1824"), 134), "crypt_rubble")
    save(flagstones(32, 32, hx("a89a80"), hx("c4b698"), hx("6a5e4a"), hx("5a5040"), hx("5a7a3a"), 135, 0.2), "court_paving")
    save(meadow(32, 32, hx("5a7a3a"), hx("7a9a4a"), hx("3a5428"), [hx("e8d050"), hx("e86060"), hx("f0f0f0"), hx("b080e0")], 136), "court_meadow")
    save(meadow(32, 32, hx("4a6a3a"), hx("6a8a48"), hx("2e4426"), [hx("f0f0f0"), hx("c090e8"), hx("e8d050")], 137), "alpine_meadow")
    # things that grow on the terraces (cut out, upright)
    save(tuft(16, 16, hx("8a9a4a"), hx("b8c070"), hx("5a6a30"), 141), "tuft_dry")
    save(tuft(16, 16, hx("4a8a3a"), hx("7ab858"), hx("2a5228"), 142), "tuft_green")
    save(tuft(16, 16, hx("4a8a3a"), hx("7ab858"), hx("2a5228"), 143, [hx("f0f0f0"), hx("e8d050"), hx("c090e8")]), "tuft_flowers")
    save(tuft(16, 16, hx("2e5a3a"), hx("4a8050"), hx("1a3424"), 144, fern=True), "fern")
    save(tuft(16, 16, hx("3a6a2e"), hx("5a8a3a"), hx("22401c"), 145, [hx("e86060"), hx("e8d050")]), "tuft_court")
    save(hanging(16, 24, hx("2c4a34"), hx("3f6646"), hx("1a2e20"), 151), "ivy_hang")
    save(hanging(16, 24, hx("4a6a36"), hx("6a8a48"), hx("2c4420"), 152), "vine_hang")
    save(hanging(16, 24, hx("6a7a3a"), hx("8a9a4a"), hx("4a5428"), 153), "grass_hang")
    print("wrote", sorted(p.name for p in OUT.glob("*.png")))


if __name__ == "__main__":
    build()
