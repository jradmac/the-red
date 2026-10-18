"""The tall grass clumps (scripts/tall_grass.gd): assets/w3d/tall_grass.png.

Two clumps for each land, side by side, one row per land (the order of
TallGrass.PAL). Drawn smooth rather than as blocky pixels: each leaf a tapered,
gently curving blade, dark at the root and lighter toward the tip, lit down
one side, with a thin dark rim; drawn four times over size and shrunk, so the
edges are clean at the game's texture size (4x the 16-pixels-a-tile grid).
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets" / "w3d" / "tall_grass.png"
CW, CH = 64, 48          # one clump in the texture (1 tile wide, 3/4 tall)
SS = 4                   # drawn this much bigger, then shrunk

# per land: rim, root, body, light, tip -- same order as TallGrass.PAL
PAL = [
    ["17301f", "24452e", "3a6b44", "5c9058", "8cbc76"],   # crypt gardens
    ["163218", "214d24", "3b7a34", "62a248", "a6d878"],   # forest
    ["2b4218", "45652a", "6c9434", "94b848", "cce082"],   # courtyard meadow
    ["3e3a22", "5e5832", "887e46", "aea064", "d4c890"],   # mountain: dry
    ["14402a", "22603c", "3c8a50", "62b064", "a4e09a"],   # river: lush
    ["232f18", "3c4c22", "5e6c30", "848e44", "b4b878"],   # swamp: sedge
]


def hx(s):
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def leaf_points(x0, h, lean, w):
    """The blade's centre line: from its root up to the tip, curving over."""
    pts = []
    n = 24
    for i in range(n + 1):
        t = i / n
        x = x0 + lean * t * t
        y = CH * SS - 1 - h * t
        r = w * (1.0 - t) ** 0.8 + 0.6 * SS * (1.0 - t)
        pts.append((x, y, r, t))
    return pts


def clump(pal, seed):
    big = Image.new("RGBA", (CW * SS, CH * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    rng = random.Random(seed)
    rim, root, body, light, tip = (hx(c) for c in pal)
    leaves = []
    # back leaves (taller, darker), then front ones (shorter, brighter)
    for layer in (0, 1):
        n = 6 if layer == 0 else 5
        for k in range(n):
            x0 = (k + 0.5 + rng.uniform(-0.35, 0.35)) / n * CW * SS
            x0 = min(max(x0, 11 * SS), (CW - 11) * SS)
            h = rng.uniform(0.62, 0.95) * CH * SS if layer == 0 else rng.uniform(0.42, 0.7) * CH * SS
            lean = rng.uniform(-1.0, 1.0) * 6 * SS
            w = rng.uniform(2.4, 3.2) * SS
            leaves.append((layer, leaf_points(x0, h, lean, w)))
    for layer, pts in leaves:
        dim = 0.82 if layer == 0 else 1.0
        # the dark rim, then the body over it, then the lit side
        for x, y, r, t in pts:
            d.ellipse([x - r - 1.6 * SS, y - r - 1.6 * SS, x + r + 1.6 * SS, y + r + 1.6 * SS], fill=rim + (255,))
        for x, y, r, t in pts:
            c = mix(root, body, min(1.0, t * 1.6)) if t < 0.6 else mix(body, tip, (t - 0.6) / 0.4)
            c = tuple(int(v * dim) for v in c)
            d.ellipse([x - r, y - r, x + r, y + r], fill=c + (255,))
        for x, y, r, t in pts:
            if 0.15 < t < 0.92 and r > 1.2 * SS:
                c = tuple(int(v * dim) for v in mix(light, tip, t))
                rr = r * 0.45
                d.ellipse([x - r * 0.55 - rr, y - rr, x - r * 0.55 + rr, y + rr], fill=c + (255,))
    small = big.resize((CW, CH), Image.LANCZOS)
    # firm the edge: either there or not (the game cuts at half), no fringe
    px = small.load()
    for yy in range(CH):
        for xx in range(CW):
            r, g, b, a = px[xx, yy]
            px[xx, yy] = (r, g, b, 255 if a >= 110 else 0) if a else (0, 0, 0, 0)
    return small


def build():
    out = Image.new("RGBA", (CW * 2, CH * len(PAL)), (0, 0, 0, 0))
    for b, pal in enumerate(PAL):
        for v in range(2):
            out.paste(clump(pal, b * 10 + v + 3), (v * CW, b * CH))
    out.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    build()
