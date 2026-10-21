"""Builds assets/journal_lands.png (and journal_lands_small.png): each land of
the journal (JournalData.LANDS order) as a little floating island -- a
chunky voxel diorama of what the land is like, its ground on top and its
rock hanging below.

The blocks are big and clear: each is a cube 8 pixels across, drawn straight
at pixel size (isometric, lit from the upper left: bright tops, a lit left
face, a shaded right face), each face edged a shade darker so every block
reads on its own. What shines (lava, lamps, candles, gold) glows.
Run:  python3 tools/make_land_islands.py
"""
import math
import random
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ORDER = ["crypt", "forest", "court", "mountain", "river", "swamp", "village", "beach", "jungle", "snow",
         "volcano", "gold", "home"]
W, H = 92, 98            # one picture
SW, SH = 30, 33          # the small one (the journal's grid)
N = 10                   # the island's footprint, in blocks
A = 5                    # half a block's width on screen (a block's top is 2A x A)
HV = 5                   # a block's height on screen
OUTLINE = (12, 8, 18)

# material -> (colour, shines?)
MAT = {
    "grass": ((96, 168, 64), False), "grass2": ((80, 148, 56), False), "dirt": ((124, 86, 54), False),
    "rock": ((96, 88, 104), False), "rock2": ((74, 68, 84), False), "deep": ((54, 48, 64), False),
    "brick": ((112, 96, 132), False), "brick2": ((92, 78, 112), False), "moss": ((78, 124, 68), False),
    "bone": ((228, 220, 196), False), "candle": ((255, 214, 120), True),
    "leaf": ((54, 128, 58), False), "leaf2": ((42, 104, 50), False), "trunk": ((104, 70, 44), False),
    "sand": ((232, 208, 150), False), "stone": ((226, 204, 160), False), "stone2": ((200, 176, 132), False),
    "water": ((60, 130, 210), False), "foam": ((214, 238, 250), False), "murk": ((62, 92, 52), False),
    "reed": ((168, 160, 76), False), "wisp": ((170, 255, 170), True), "wood": ((140, 94, 56), False),
    "roof": ((180, 68, 50), False), "wall": ((222, 204, 168), False), "lamp": ((255, 220, 130), True),
    "window": ((255, 196, 96), True), "jungle": ((60, 172, 64), False), "jungle2": ((44, 140, 54), False),
    "snow": ((240, 246, 252), False), "ice": ((156, 206, 244), False), "pine": ((44, 96, 76), False),
    "basalt": ((56, 46, 52), False), "basalt2": ((76, 62, 66), False), "lava": ((255, 124, 34), True),
    "lava2": ((255, 196, 64), True), "gold": ((244, 196, 70), False), "gold2": ((214, 158, 44), False),
    "goldhi": ((255, 238, 150), True), "ruby": ((226, 34, 66), True), "obsidian": ((58, 34, 80), False),
    "rune": ((180, 116, 255), True), "light": ((255, 250, 222), True), "flower": ((244, 124, 166), False),
    "flower2": ((252, 222, 96), False), "palm": ((80, 164, 76), False), "mushroom": ((120, 230, 255), True),
    "purple": ((130, 76, 180), False), "path": ((170, 128, 82), False),
}


class Island:
    def __init__(self, seed):
        self.v = {}
        self.rng = random.Random(seed)

    def put(self, x, y, z, m):
        self.v[(x, y, z)] = m

    def top(self, x, y):
        zs = [z for (a, b, z) in self.v if a == x and b == y]
        return max(zs) if zs else 0


def disc(rng, r=4.75):
    c = (N - 1) / 2
    cells = {}
    for y in range(N):
        for x in range(N):
            d = math.hypot(x - c, y - c)
            if d < r + rng.uniform(-0.25, 0.25):
                cells[(x, y)] = d / r
    return cells


def ground(isl, cells, top_mat, height=lambda x, y: 0, under=("dirt", "rock", "rock2", "deep"), depth=5.0):
    """The ground, and the rock hanging below it (deepest in the middle)."""
    for (x, y), d in cells.items():
        h = height(x, y)
        for z in range(0, h + 1):
            isl.put(x, y, z, top_mat(x, y, z, h))
        dd = max(1, int(round((1 - min(d, 1.0)) ** 0.7 * depth)) + (1 if isl.rng.random() < 0.15 else 0))
        for k in range(1, dd + 1):
            isl.put(x, y, -k, under[min(len(under) - 1, k - 1)])


def tree(isl, x, y, z, leaves=("leaf", "leaf2"), trunk_h=2, big=False):
    for k in range(1, trunk_h + 1):
        isl.put(x, y, z + k, "trunk")
    cz = z + trunk_h + 1
    r = 1
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            isl.put(x + dx, y + dy, cz, leaves[(dx + dy) % 2 == 0 and 0 or 1])
    isl.put(x, y, cz + 1, leaves[0])
    for dx, dy in [(1, 0), (0, 1), (-1, 0), (0, -1)]:
        isl.put(x + dx, y + dy, cz + 1, leaves[1] if big else leaves[0])
    if big:
        isl.put(x, y, cz + 2, leaves[0])


def build_crypt():
    isl = Island(1)
    cells = disc(isl.rng)
    ground(isl, cells, lambda x, y, z, h: "brick" if (x + y) % 2 else "brick2", under=("rock2", "deep", "deep", "deep"))
    for (x, y) in [(1, 3), (1, 4), (1, 5), (2, 2), (3, 2)]:   # broken walls
        isl.put(x, y, 1, "brick")
        isl.put(x, y, 2, "moss" if (x + y) % 3 == 0 else "brick2")
    for (x, y) in [(7, 6), (7, 7), (6, 7)]:
        isl.put(x, y, 1, "brick2")
    for x in (4, 5):   # the bier, a candle at each end
        isl.put(x, 4, 1, "stone2")
        isl.put(x, 5, 1, "stone2")
    isl.put(4, 4, 2, "candle")
    isl.put(5, 5, 2, "candle")
    isl.put(7, 3, 1, "bone")
    isl.put(3, 7, 1, "bone")
    return isl


def build_forest():
    isl = Island(2)
    cells = disc(isl.rng)
    ground(isl, cells, lambda x, y, z, h: "path" if x == y or x == y + 1 else ("grass" if (x * 3 + y) % 4 else "grass2"))
    tree(isl, 2, 3, 0, big=True)
    tree(isl, 6, 2, 0)
    tree(isl, 3, 7, 0)
    tree(isl, 7, 6, 0, big=True)
    return isl


def build_court():
    isl = Island(3)
    cells = disc(isl.rng)
    ground(isl, cells, lambda x, y, z, h: "stone" if (x + y) % 2 else "stone2", under=("stone2", "rock", "rock2", "deep"))
    for (x, y, hgt) in [(2, 2, 4), (2, 7, 4), (7, 2, 4), (7, 7, 2)]:   # the colonnade, one fallen
        for z in range(1, hgt + 1):
            isl.put(x, y, z, "stone")
        if hgt == 4:
            isl.put(x, y, 5, "stone2")
    isl.put(8, 6, 1, "stone")   # the fallen top
    for x in (4, 5):   # the throne
        for y in (4, 5):
            isl.put(x, y, 1, "stone2")
    isl.put(4, 4, 2, "stone")
    isl.put(4, 4, 3, "stone")
    isl.put(5, 4, 2, "purple")
    isl.put(1, 5, 0, "moss")
    isl.put(6, 8, 0, "moss")
    return isl


def build_mountain():
    isl = Island(4)
    cells = disc(isl.rng)

    def h(x, y):
        return max(0, int(5 - math.hypot(x - 4, y - 3.5) * 1.3))
    ground(isl, cells, lambda x, y, z, hh: ("grass" if hh == 0 else ("snow" if z >= 5 else "rock")) if z == hh
           else ("rock2" if z % 2 else "rock"), height=h)
    return isl


def build_river():
    isl = Island(5)
    cells = disc(isl.rng)

    def water(x, y):
        return y in (4, 5) or (y == 3 and x > 6)
    ground(isl, cells, lambda x, y, z, h: "water" if water(x, y) else ("grass" if z == h else "dirt"),
           height=lambda x, y: 0 if water(x, y) else 1)
    for y in (4, 5):   # a bridge
        isl.put(3, y, 2, "wood")
    tree(isl, 2, 7, 1)
    tree(isl, 7, 1, 1)
    isl.put(6, 6, 2, "reed")
    isl.put(5, 3, 2, "reed")
    return isl


def build_swamp():
    isl = Island(6)
    cells = disc(isl.rng)

    def pool(x, y):
        return (x - 3) ** 2 + (y - 5) ** 2 < 4 or (x - 7) ** 2 + (y - 3) ** 2 < 2
    ground(isl, cells, lambda x, y, z, h: "murk" if pool(x, y) else ("moss" if z == h else "dirt"),
           height=lambda x, y: 0 if pool(x, y) else 1)
    for z in range(2, 6):   # a dead tree
        isl.put(6, 6, z, "trunk")
    isl.put(7, 6, 5, "trunk")
    isl.put(6, 5, 4, "trunk")
    isl.put(5, 2, 2, "reed")
    isl.put(1, 4, 2, "reed")
    isl.put(8, 5, 2, "mushroom")
    isl.put(3, 5, 3, "wisp")
    isl.put(7, 3, 2, "wisp")
    return isl


def house(isl, x0, y0, w, d):
    for x in range(x0, x0 + w):
        for y in range(y0, y0 + d):
            isl.put(x, y, 1, "window" if (y == y0 + d - 1 and x == x0 + 1) else "wall")
            isl.put(x, y, 2, "wall")
            isl.put(x, y, 3, "roof")
    for x in range(x0, x0 + w):
        isl.put(x, y0 + d // 2, 4, "roof")


def build_village():
    isl = Island(7)
    cells = disc(isl.rng)
    ground(isl, cells, lambda x, y, z, h: "path" if x in (4, 5) else ("grass" if (x + y) % 3 else "grass2"))
    house(isl, 1, 2, 3, 2)
    house(isl, 6, 1, 3, 3)
    house(isl, 6, 6, 2, 2)
    for z in (1, 2):
        isl.put(3, 6, z, "wood")
    isl.put(3, 6, 3, "lamp")
    return isl


def build_beach():
    isl = Island(8)
    cells = disc(isl.rng)

    def sea(x, y):
        return x + y >= 11

    def mat(x, y, z, h):
        if sea(x, y):
            return "foam" if x + y == 11 else "water"
        return "sand"
    ground(isl, cells, mat, height=lambda x, y: 0 if sea(x, y) else 1, under=("sand", "rock", "rock2", "deep"))
    for z in range(2, 6):   # a palm, leaning
        isl.put(3 + (1 if z >= 4 else 0), 3, z, "trunk")
    for dx, dy in [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (0, 2)]:
        isl.put(4 + dx, 3 + dy, 6 if abs(dx) + abs(dy) < 2 else 5, "palm")
    isl.put(6, 3, 2, "wood")   # a washed-up chest
    return isl


def build_jungle():
    isl = Island(9)
    cells = disc(isl.rng)
    ground(isl, cells, lambda x, y, z, h: "murk" if x == 5 else ("jungle" if (x + y) % 2 else "jungle2"),
           height=lambda x, y: 0 if x == 5 else 1)
    tree(isl, 2, 2, 1, leaves=("jungle", "jungle2"), trunk_h=3, big=True)
    tree(isl, 7, 3, 1, leaves=("jungle", "jungle2"), trunk_h=2, big=True)
    tree(isl, 2, 7, 1, leaves=("jungle", "jungle2"), trunk_h=2)
    tree(isl, 7, 7, 1, leaves=("jungle", "jungle2"), trunk_h=3)
    return isl


def build_snow():
    isl = Island(10)
    cells = disc(isl.rng)

    def h(x, y):
        return max(0, int(5 - math.hypot(x - 3, y - 3) * 1.5), int(3 - math.hypot(x - 7, y - 6) * 1.4))
    ground(isl, cells, lambda x, y, z, hh: "snow" if z == hh else ("rock" if z < hh - 1 else "snow"), height=h,
           under=("rock", "rock2", "ice", "ice"))
    for (x, y) in [(7, 2), (2, 7)]:   # snowy pines
        isl.put(x, y, 1, "trunk")
        isl.put(x, y, 2, "pine")
        for dx, dy in [(1, 0), (0, 1), (-1, 0), (0, -1)]:
            isl.put(x + dx, y + dy, 2, "pine")
        isl.put(x, y, 3, "pine")
        isl.put(x, y, 4, "snow")
    return isl


def build_volcano():
    isl = Island(11)
    cells = disc(isl.rng)

    def h(x, y):
        d = math.hypot(x - 4.5, y - 4.5)
        return 4 if d < 1.0 else max(0, int(6 - d * 1.5))
    lava_cells = {(5, 6), (5, 7), (6, 8), (6, 5), (7, 6), (8, 7)}

    def mat(x, y, z, hh):
        if z == hh and math.hypot(x - 4.5, y - 4.5) < 1.0:
            return "lava2"
        if z == hh and (x, y) in lava_cells:
            return "lava"
        return "basalt" if (x + y + z) % 2 else "basalt2"
    ground(isl, cells, mat, height=h, under=("basalt", "basalt2", "deep", "deep"))
    isl.put(4, 4, 7, "lava2")   # an ember flung up
    return isl


def build_gold():
    isl = Island(12)
    cells = disc(isl.rng)
    ground(isl, cells, lambda x, y, z, h: "gold" if (x + y) % 2 else "gold2", under=("gold2", "rock", "rock2", "deep"))
    for (x, y, hh) in [(3, 3, 2), (2, 3, 1), (3, 2, 1), (4, 3, 1), (6, 6, 2), (7, 6, 1), (6, 7, 1), (6, 5, 1)]:
        for z in range(1, hh + 1):
            isl.put(x, y, z, "goldhi" if z == hh else "gold")
    for (x, y) in [(5, 2), (2, 6), (7, 4), (4, 7), (8, 6)]:
        isl.put(x, y, 1, "ruby")
    return isl


def build_home():
    isl = Island(13)
    cells = disc(isl.rng)
    ground(isl, cells, lambda x, y, z, h: "path" if x in (4, 5) and y >= 4 else ("grass" if (x + y) % 3 else "grass2"))
    # the purple gate, standing open, light pouring through
    gy = 3
    for z in range(1, 6):
        isl.put(2, gy, z, "rune" if z == 3 else "obsidian")
        isl.put(7, gy, z, "rune" if z == 3 else "obsidian")
    for x in range(2, 8):
        isl.put(x, gy, 6, "obsidian")
    isl.put(4, gy, 7, "obsidian")
    isl.put(5, gy, 7, "rune")
    for x in range(3, 7):
        for z in range(1, 6):
            isl.put(x, gy, z, "light")
    for (x, y) in [(1, 6), (8, 5), (2, 8), (7, 8)]:
        isl.put(x, y, 1, "flower" if (x + y) % 2 else "flower2")
    tree(isl, 8, 7, 0)
    return isl


# --- drawing ------------------------------------------------------------------------------

def shade(c, k):
    return tuple(max(0, min(255, int(round(v * k)))) for v in c)


def render(isl):
    vox = isl.v
    zs = [p[2] for p in vox]
    zmax, zmin = max(zs), min(zs)
    ox = N * A + 2
    oy = (zmax + 2) * HV
    w = 2 * N * A + 4
    h = oy + N * A + (-zmin + 2) * HV
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    glow = []

    def P(x, y, z):
        return (ox + (x - y) * A, oy + (x + y) * A // 2 - z * HV)

    for (x, y, z) in sorted(vox, key=lambda p: (p[0] + p[1], p[2], p[0])):
        col, shines = MAT[vox[(x, y, z)]]
        top_open = (x, y, z + 1) not in vox
        left_open = (x, y + 1, z) not in vox
        right_open = (x + 1, y, z) not in vox
        k_top, k_left, k_right = (1.12, 1.0, 0.88) if shines else (1.0, 0.8, 0.6)
        a, b, c, e = P(x, y, z + 1), P(x + 1, y, z + 1), P(x + 1, y + 1, z + 1), P(x, y + 1, z + 1)
        b0, c0, e0 = P(x + 1, y, z), P(x + 1, y + 1, z), P(x, y + 1, z)
        if left_open:
            face = [e, c, c0, e0]
            d.polygon(face, fill=shade(col, k_left), outline=shade(col, k_left * 0.78))
        if right_open:
            face = [c, b, b0, c0]
            d.polygon(face, fill=shade(col, k_right), outline=shade(col, k_right * 0.78))
        if top_open:
            face = [a, b, c, e]
            d.polygon(face, fill=shade(col, k_top), outline=shade(col, k_top * 0.82))
            # a bright edge along the top's two far sides, where the light catches it
            d.line([e, a, b], fill=shade(col, min(1.35, k_top * 1.18)))
        if shines:
            cx, cy = P(x + 0.5, y + 0.5, z + 0.5)
            glow.append((cx, cy, col))
    return img, glow


def finish(img, glow):
    w, h = img.size
    px = img.load()
    edge = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] == 0 and any(
        0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3] == 255 and px[x + dx, y + dy][:3] != OUTLINE
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for p in edge:
        px[p] = OUTLINE + (255,)
    layer = {}
    for (gx, gy, col) in glow:
        for y in range(int(gy) - 7, int(gy) + 8):
            for x in range(int(gx) - 7, int(gx) + 8):
                if 0 <= x < w and 0 <= y < h:
                    k = max(0.0, 1.0 - math.hypot(x - gx, y - gy) / 7.5) ** 2 * 0.2
                    L = layer.setdefault((x, y), [0.0, 0.0, 0.0, 0.0])
                    L[0] += col[0] / 255 * k
                    L[1] += col[1] / 255 * k
                    L[2] += col[2] / 255 * k
                    L[3] = max(L[3], k)
    for (x, y), L in layer.items():
        r, g, b, a = px[x, y]
        if a == 0:
            s = max(L[3], 1e-4)
            px[x, y] = (int(min(255, L[0] / s * 255)), int(min(255, L[1] / s * 255)), int(min(255, L[2] / s * 255)),
                        int(min(0.6, L[3] * 1.5) * 255))
        else:
            px[x, y] = (min(255, int(r + L[0] * 200)), min(255, int(g + L[1] * 200)), min(255, int(b + L[2] * 200)), a)
    return img


def fit(img, w, h):
    img = img.crop(img.getbbox())
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(img, ((w - img.width) // 2, (h - img.height) // 2))
    return out


def small(img):
    """The grid's little one: the island at a third, block by block."""
    im = img.crop(img.getbbox())
    k = min(SW / im.width, SH / im.height)
    tw, th = max(1, int(im.width * k)), max(1, int(im.height * k))
    src = im.load()
    out = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    for y in range(th):
        for x in range(tw):
            c = Counter()
            for yy in range(int(y / k), min(im.height, int((y + 1) / k))):
                for xx in range(int(x / k), min(im.width, int((x + 1) / k))):
                    p = src[xx, yy]
                    c[p if p[3] > 128 else None] += 1
            if not c:
                continue
            best = c.most_common(1)[0][0]
            if best is None and c[None] < sum(c.values()) * 0.6:
                best = [q for q, _ in c.most_common() if q is not None][0]
            if best is not None:
                out.putpixel((x, y), best)
    o2 = Image.new("RGBA", (SW, SH), (0, 0, 0, 0))
    o2.alpha_composite(out, ((SW - tw) // 2, (SH - th) // 2))
    return o2


def main():
    big = Image.new("RGBA", (W * len(ORDER), H), (0, 0, 0, 0))
    sm = Image.new("RGBA", (SW * len(ORDER), SH), (0, 0, 0, 0))
    for i, name in enumerate(ORDER):
        img, glow = render(globals()["build_" + name]())
        img = finish(img, glow)
        bb = img.getbbox()
        assert bb[2] - bb[0] <= W and bb[3] - bb[1] <= H, (name, bb)
        f = fit(img, W, H)
        big.alpha_composite(f, (i * W, 0))
        sm.alpha_composite(small(f), (i * SW, 0))
        print(name, bb[2] - bb[0], bb[3] - bb[1])
    big.save(ROOT / "assets" / "journal_lands.png")
    sm.save(ROOT / "assets" / "journal_lands_small.png")
    print("wrote the floating islands")


if __name__ == "__main__":
    main()
