"""Builds the map-detail art: proper 3D rocks, ground decor and ground patches.

    python3 tools/make_detail.py

assets/rocks.png    32x32 cells. Row = kind * 5 + palette, col = variant (4).
                    Every rock stands with its foot at (16, 27) of its cell and
                    carries its own soft cast shadow (down-right).
    kinds:    0 pebbles   1 small rock   2 boulder   3 big flat-top rock
              4 stacked spire   5 cluster
    palettes: 0 mountain  1 grey stone   2 mossy   3 swamp   4 sandstone
assets/decor.png    16x16 ground decor, 8 per row:
    0 mountain  1 forest  2 river  3 swamp  4 courtyard  5 crypt
assets/patches.png  32x32 soft ground patches that break up the tiling,
                    3 per row, rows by biome as in decor.png.
"""
from pathlib import Path
import math
import random
import sys

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_env import hx, mix, shade, dith, MOSS  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "assets"
LIGHT = (-0.72, -0.69)   # light from the upper left


class Spr:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.px = self.img.load()

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return (0, 0, 0, 0)

    def set(self, x, y, c):
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        if c[3] == 255:
            self.px[x, y] = c
            return
        b = self.px[x, y]
        a = c[3] / 255.0
        if b[3] == 0:
            self.px[x, y] = c
        else:
            self.px[x, y] = (int(b[0] + (c[0] - b[0]) * a), int(b[1] + (c[1] - b[1]) * a),
                             int(b[2] + (c[2] - b[2]) * a), max(b[3], c[3]))


# ---------------------------------------------------------------------------
# Rocks
# ---------------------------------------------------------------------------
def pal(outline, f_dk, f, f_lt, t_dk, t, t_hi, t_lt, speck, moss=None, moss_hi=None):
    return dict(outline=hx(outline), f_dk=hx(f_dk), f=hx(f), f_lt=hx(f_lt), t_dk=hx(t_dk), t=hx(t),
                t_hi=hx(t_hi), t_lt=hx(t_lt), speck=hx(speck),
                moss=hx(moss) if moss else None, moss_hi=hx(moss_hi) if moss_hi else None)


PALETTES = [
    # mountain: warm earthy stone, the classic HGSS route rock
    pal("2a1f1a", "5a4232", "74563f", "8c6a4c", "8a6b50", "a5835f", "c19d74", "dcbf93", "6a5040"),
    # grey stone (crypt)
    pal("1c1a22", "3e3b46", "55515e", "6b6776", "706c7a", "8b8794", "a8a4b0", "c6c2cc", "605c6a"),
    # mossy stone (forest, river)
    pal("17201c", "39403e", "4e5654", "646c68", "68706a", "838b82", "9fa79b", "bcc4b4", "5a625c",
        "3f7a46", "6fae5e"),
    # swamp: dark, slick, covered in slime
    pal("101510", "2a2f28", "3a4136", "4c5444", "4a5242", "5f6852", "778266", "93a07c", "424a3a",
        "4d6e2c", "7e9c3c"),
    # sandstone (courtyard rubble)
    pal("3a2e24", "6c5e4c", "857560", "9c8a72", "9e8e76", "b6a58a", "cdbd9f", "e3d6ba", "8a7a64",
        "4e7a44", "72a45e"),
]


def poly(cx, cy, rx, ry, rnd, n=None, jag=0.14):
    n = n or rnd.randrange(6, 9)
    pts = []
    off = rnd.random() * math.tau
    for k in range(n):
        a = off + k * math.tau / n + rnd.uniform(-0.25, 0.25) * math.tau / n
        r = 1 + rnd.uniform(-jag, jag)
        pts.append((cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r))
    return pts


def inside(pts, x, y):
    c = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi:
            c = not c
        j = i
    return c


def chunk(s, cx, foot, w, d, hgt, P, rnd, moss=0.0, crack=True, jag=0.14):
    """One rock: a faceted top surface (w x d) raised hgt px above its foot.

    Drawn on its own layer with an outline, then pasted over what's there.
    """
    rx, ry = w / 2.0, d / 2.0
    cy = foot - hgt - ry
    pts = poly(cx, cy, rx, ry, rnd, jag=jag)
    W, H = s.w, s.h
    top = [[inside(pts, x + 0.5, y + 0.5) for x in range(W)] for y in range(H)]
    body = [[False] * W for _ in range(H)]
    # a rounder foot: the face is shorter towards the sides, so it reads as a
    # boulder rather than a drum
    hcol = []
    for x in range(W):
        u = min(1.0, abs(x + 0.5 - cx) / rx)
        hcol.append(max(1, int(round(hgt * (0.62 + 0.38 * math.sqrt(1 - u * u)) + rnd.uniform(-0.6, 0.6)))))
    for y in range(H):
        for x in range(W):
            if top[y][x]:
                for k in range(hcol[x] + 1):
                    if y + k < H:
                        body[y + k][x] = True
    # the bottom of the rock is a little rounder than the top
    layer = Spr(W, H)
    # distance from the top surface's edge (for the bevel)
    def edge_dist(x, y, lim=4):
        for r in range(1, lim + 1):
            for (dx, dy) in ((r, 0), (-r, 0), (0, r), (0, -r), (r, r), (-r, -r), (r, -r), (-r, r)):
                xx, yy = x + dx, y + dy
                if not (0 <= xx < W and 0 <= yy < H) or not top[yy][xx]:
                    return r
        return lim + 1

    facets = rnd.randrange(2, 4)   # a couple of facet ridges across the top
    ridge = [(rnd.uniform(-0.6, 0.6), rnd.uniform(-1.0, 1.0)) for _ in range(facets)]
    for y in range(H):
        for x in range(W):
            if not body[y][x]:
                continue
            u = (x + 0.5 - cx) / rx
            if top[y][x]:
                v = (y + 0.5 - cy) / ry
                e = edge_dist(x, y)
                nl = math.hypot(u, v) or 1
                lit = (u / nl) * LIGHT[0] + (v / nl) * LIGHT[1]   # >0: faces the light
                bevel = max(0.0, 1 - (e - 1) / 3.0)
                val = 0.15 * (-u - v) + bevel * lit * 1.1
                for (a, b) in ridge:   # facet planes: one side a touch lighter
                    if u * a + v - b * 0.3 > 0:
                        val += 0.08
                val += (dith(x, y) - 0.5) * 0.16
                if val > 0.55:
                    c = P["t_lt"]
                elif val > 0.2:
                    c = P["t_hi"]
                elif val > -0.3:
                    c = P["t"]
                else:
                    c = P["t_dk"]
            else:
                # the front face: lit on the left, dark on the right and at the foot
                k = 0
                while y - k - 1 >= 0 and not top[y - k - 1][x]:
                    k += 1
                depth = k   # rows below the top's edge
                side = u + (rnd.random() - 0.5) * 0.15
                if side < -0.55:
                    c = P["f_lt"]
                elif side < 0.35:
                    c = P["f"]
                else:
                    c = P["f_dk"]
                if depth == 0:   # the rim where the top meets the face
                    c = mix(c, P["outline"], 0.45) if side > -0.55 else mix(P["t_dk"], c, 0.5)
                elif y >= foot - 1:
                    c = mix(c, P["outline"], 0.35)
                elif depth >= hcol[x] - 1 and side > -0.2:
                    c = P["f_dk"]
            layer.set(x, y, c)
    # vertical strata / cracks on the face, specks on the top
    if crack:
        for _ in range(max(1, w // 9)):
            x = int(cx + rnd.uniform(-rx * 0.7, rx * 0.7))
            y0 = None
            for y in range(H):
                if body[y][x] and not top[y][x]:
                    y0 = y
                    break
            if y0 is None:
                continue
            for y in range(y0 + 1, min(H, y0 + hgt)):
                if body[y][x] and not top[y][x]:
                    layer.set(x, y, P["f_dk"] if x > cx - rx * 0.5 else P["f"])
                    if rnd.random() < 0.25:
                        x += rnd.choice([-1, 1])
                        if not (0 <= x < W) or not body[y][x]:
                            break
    for _ in range(int(w * d / 14)):
        x, y = rnd.randrange(W), rnd.randrange(H)
        if top[y][x] and rnd.random() < 0.8:
            layer.set(x, y, P["speck"] if rnd.random() < 0.6 else P["t_lt"])
    if w >= 16 and rnd.random() < 0.6:   # a crack across the top
        x, y = int(cx - rx * 0.3), int(cy + rnd.uniform(-ry * 0.3, ry * 0.3))
        for i in range(int(rx)):
            if 0 <= x < W and 0 <= y < H and top[y][x]:
                layer.set(x, y, P["t_dk"])
                if 0 <= y + 1 < H and top[y + 1][x]:
                    layer.set(x, y + 1, P["t_hi"])
            x += 1
            if rnd.random() < 0.35:
                y += rnd.choice([-1, 1])
    # moss and slime: on the top, creeping down the lit side
    if moss and P["moss"]:
        blobs = [(cx + rnd.uniform(-rx * 0.6, rx * 0.3), cy + rnd.uniform(-ry * 0.6, ry * 0.2),
                  rnd.uniform(2, max(3, rx * 0.7))) for _ in range(2 + int(moss * 2))]
        for y in range(H):
            for x in range(W):
                if not top[y][x]:
                    continue
                for (bx, by, br) in blobs:
                    dd = math.hypot((x - bx), (y - by) * 1.4)
                    if dd < br * moss + dith(x, y) * 1.5:
                        hi = (x - bx) + (y - by) < -1
                        layer.set(x, y, P["moss_hi"] if hi else P["moss"])
                        # drips onto the face
                        if y + 1 < H and not top[y + 1][x] and body[y + 1][x] and rnd.random() < 0.5:
                            for k in range(1, rnd.randrange(2, 4)):
                                if y + k < H and body[y + k][x]:
                                    layer.set(x, y + k, P["moss"])
                        break
    # outline
    for y in range(H):
        for x in range(W):
            if body[y][x]:
                continue
            n = 0
            for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < W and 0 <= yy < H and body[yy][xx]:
                    n += 1
            if n:
                layer.set(x, y, P["outline"])
    s.img.alpha_composite(layer.img)
    s.px = s.img.load()


def cast_shadow(s, cx, foot, w, a=95):
    rx, ry = w / 2.0 + 2, max(2.5, w / 7.0)
    sx, sy = cx + 3, foot - 0.5
    for y in range(s.h):
        for x in range(s.w):
            dd = ((x + 0.5 - sx) / rx) ** 2 + ((y + 0.5 - sy) / ry) ** 2
            if dd < 1 and s.get(x, y)[3] == 0:
                aa = a if dd < 0.55 else int(a * 0.6)
                if dd > 0.8 and dith(x, y) < 0.5:
                    continue
                s.set(x, y, (12, 8, 22, aa))


def tufts_at_base(s, cx, foot, w, rnd, green):
    cols = [hx("4f8058"), hx("74a96f"), hx("2f523b")] if green else [hx("8a8450"), hx("b0a868"), hx("5e5a38")]
    for _ in range(rnd.randrange(1, 3)):
        x = int(cx + rnd.choice([-1, 1]) * (w / 2 - rnd.uniform(0, 2)))
        for (dx, h) in ((0, 2), (1, 3), (2, 2)):
            for k in range(h):
                s.set(x + dx, foot - k, cols[1] if k == h - 1 else cols[0])
        s.set(x + 1, foot + 1, cols[2])


def rock(kind, p, v):
    rnd = random.Random(7000 + kind * 101 + p * 13 + v * 977)
    P = PALETTES[p]
    s = Spr(32, 32)
    F = 27
    mossy = {2: 0.9, 3: 0.75, 4: 0.35}.get(p, 0.0)
    if p == 0 and v == 3:
        mossy = 0.0
    green = p in (2, 3, 4)
    if kind == 0:   # pebbles
        stones = [(rnd.uniform(9, 13), F - rnd.randrange(0, 3), rnd.randrange(4, 7)),
                  (rnd.uniform(17, 22), F - rnd.randrange(0, 2), rnd.randrange(5, 8)),
                  (rnd.uniform(13, 18), F + 1, rnd.randrange(3, 5))]
        for (x, f, w) in sorted(stones, key=lambda t: t[1]):
            cast_shadow(s, x, f, w, 70)
        for (x, f, w) in sorted(stones, key=lambda t: t[1]):
            chunk(s, x, f, w, max(3, w // 2), 2, P, rnd, 0, crack=False)
    elif kind == 1:   # small rock
        w = rnd.randrange(12, 15)
        cast_shadow(s, 16, F, w)
        chunk(s, 16 + rnd.uniform(-1, 1), F, w, rnd.randrange(6, 8), rnd.randrange(3, 5), P, rnd, mossy * 0.7)
        chunk(s, 16 + w / 2 + 1, F + 1, 4, 3, 2, P, rnd, 0, crack=False)
        if rnd.random() < 0.6:
            tufts_at_base(s, 16, F, w + 4, rnd, green)
    elif kind == 2:   # boulder
        w = rnd.randrange(17, 21)
        cast_shadow(s, 16, F, w)
        chunk(s, 16, F, w, rnd.randrange(8, 11), rnd.randrange(6, 9), P, rnd, mossy)
        if v % 2:
            chunk(s, 16 + rnd.choice([-1, 1]) * (w / 2 - 1), F + 1, 7, 4, 3, P, rnd, 0, crack=False)
        tufts_at_base(s, 16, F, w + 2, rnd, green)
    elif kind == 3:   # big flat-topped rock
        w = rnd.randrange(20, 23)
        cast_shadow(s, 16, F, w + 2, 105)
        chunk(s, 16, F, w, rnd.randrange(10, 13), rnd.randrange(9, 12), P, rnd, mossy)
        if v % 2 == 0:
            chunk(s, 16 + rnd.choice([-1, 1]) * (w / 2 - 2), F + 1, 8, 5, 3, P, rnd, 0)
        tufts_at_base(s, 16, F, w + 2, rnd, green)
    elif kind == 4:   # stacked spire
        cast_shadow(s, 16, F, 16)
        w1 = rnd.randrange(14, 18)
        h1 = rnd.randrange(7, 10)
        d1 = rnd.randrange(6, 8)
        chunk(s, 16, F, w1, d1, h1, P, rnd, mossy * 0.5, jag=0.22)
        f2 = F - h1 - d1 // 2 + 1
        w2 = w1 - rnd.randrange(4, 6)
        h2 = rnd.randrange(5, 8)
        d2 = max(4, d1 - 2)
        x2 = 16 + rnd.choice([-1, 1]) * rnd.uniform(1.5, 3)
        chunk(s, x2, f2, w2, d2, h2, P, rnd, mossy * 0.5, jag=0.24)
        if v % 2 == 0:
            f3 = f2 - h2 - d2 // 2 + 1
            chunk(s, x2 + rnd.uniform(-2, 2), f3, max(5, w2 - 5), 3, rnd.randrange(3, 5), P, rnd, mossy, crack=False, jag=0.3)
    else:   # cluster
        a = (rnd.uniform(12, 14), F - 2, rnd.randrange(12, 15), rnd.randrange(8, 11))
        b = (rnd.uniform(20, 22), F - 1, rnd.randrange(10, 12), rnd.randrange(5, 7))
        c = (rnd.uniform(9, 12), F + 1, rnd.randrange(7, 9), rnd.randrange(3, 5))
        cast_shadow(s, 16, F, 22)
        for (x, f, w, h) in (a, b, c):
            chunk(s, x, f, w, max(4, w // 2), h, P, rnd, mossy * 0.8)
        tufts_at_base(s, 16, F, 22, rnd, green)
    return s.img


def rocks_sheet():
    sheet = Image.new("RGBA", (32 * 4, 32 * 6 * len(PALETTES)), (0, 0, 0, 0))
    for kind in range(6):
        for p in range(len(PALETTES)):
            for v in range(4):
                sheet.paste(rock(kind, p, v), (v * 32, (kind * len(PALETTES) + p) * 32))
    return sheet


# ---------------------------------------------------------------------------
# Ground decor (16x16)
# ---------------------------------------------------------------------------
def d_ripple(rnd, col_dk, col_lt):
    s = Spr(16, 16)
    for k in range(3):
        y0 = 3 + k * 5 + rnd.randrange(-1, 2)
        ph = rnd.random() * 6
        for x in range(1, 15):
            if rnd.random() < 0.12:
                continue
            y = y0 + int(round(math.sin(x * 0.55 + ph) * 1.2))
            s.set(x, y, col_dk)
            s.set(x, y - 1, col_lt)
    return s.img


def d_pebbles(rnd, P, n=5):
    s = Spr(16, 16)
    for _ in range(n):
        x, y = rnd.randrange(2, 13), rnd.randrange(3, 14)
        w = rnd.choice([1, 2, 2, 3])
        for i in range(w):
            s.set(x + i, y, P["t_hi"] if i == 0 else P["t"])
            s.set(x + i, y + 1, P["f_dk"])
        s.set(x + w, y + 1, (12, 8, 22, 90))
    return s.img


def d_crack(rnd, c_dk, c_lt):
    s = Spr(16, 16)
    x, y = 1, rnd.randrange(4, 12)
    while x < 15:
        s.set(x, y, c_dk)
        s.set(x, y + 1, c_lt)
        if rnd.random() < 0.3:   # a branch
            bx, by = x, y
            for _ in range(rnd.randrange(2, 4)):
                by += rnd.choice([-1, 1])
                bx += 1
                s.set(bx, by, c_dk)
        x += 1
        y = max(2, min(13, y + rnd.choice([-1, 0, 0, 1])))
    return s.img


def d_tuft(rnd, cols, n=3, tall=(3, 6)):
    s = Spr(16, 16)
    for _ in range(n):
        x, y = rnd.randrange(2, 12), rnd.randrange(8, 15)
        for (dx, lean) in ((0, -1), (1, 0), (2, 0), (3, 1)):
            h = rnd.randrange(*tall)
            for k in range(h):
                xx = x + dx + (lean if k >= h - 2 else 0)
                s.set(xx, y - k, cols[2] if k == h - 1 else (cols[1] if k > h // 2 else cols[0]))
        s.set(x + 1, y + 1, (12, 8, 22, 100))
        s.set(x + 2, y + 1, (12, 8, 22, 100))
    return s.img


def d_flowers(rnd, petal, center, n=4):
    s = Spr(16, 16)
    stem = MOSS["mid"]
    for _ in range(n):
        x, y = rnd.randrange(2, 13), rnd.randrange(3, 12)
        s.set(x, y + 2, stem)
        s.set(x, y + 3, MOSS["dark"])
        for (dx, dy) in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            s.set(x + dx, y + dy, petal)
        s.set(x, y, center)
        s.set(x + 1, y + 1, shade(petal, 0.7))
    return s.img


def d_mushrooms(rnd, cap, cap_hi, glow=False):
    s = Spr(16, 16)
    for _ in range(rnd.randrange(2, 4)):
        x, y = rnd.randrange(3, 12), rnd.randrange(7, 14)
        r = rnd.choice([1, 2])
        s.set(x, y + 1, (12, 8, 22, 110))
        s.set(x + 1, y + 1, (12, 8, 22, 110))
        for k in range(2):
            s.set(x, y - k, hx("e8dfc8"))
        for dx in range(-r, r + 1):
            s.set(x + dx, y - 2, cap)
        for dx in range(-r + 1, r):
            s.set(x + dx, y - 3, cap)
        s.set(x - r + 1 if r > 1 else x, y - 3, cap_hi)
        if not glow:
            s.set(x + (1 if r > 1 else 0), y - 2, hx("f4ecd8"))
    return s.img


def d_twig(rnd):
    s = Spr(16, 16)
    x, y = 2, rnd.randrange(5, 11)
    for i in range(12):
        s.set(x + i, y, hx("6a4a34"))
        s.set(x + i, y + 1, hx("2c1e17", 160))
        if i in (4, 8):
            for k in range(1, 3):
                s.set(x + i + k, y - k, hx("6a4a34"))
        if rnd.random() < 0.2:
            y += rnd.choice([-1, 1])
    for _ in range(4):
        lx, ly = rnd.randrange(1, 14), rnd.randrange(2, 14)
        c = rnd.choice([hx("8a5a2a"), hx("a8743a"), hx("6a7a30")])
        s.set(lx, ly, c)
        s.set(lx + 1, ly, c)
        s.set(lx, ly + 1, shade(c, 0.6))
    return s.img


def d_leaves(rnd, cols):
    s = Spr(16, 16)
    for _ in range(8):
        x, y = rnd.randrange(1, 14), rnd.randrange(1, 14)
        c = rnd.choice(cols)
        s.set(x, y, c)
        s.set(x + 1, y, shade(c, 1.15))
        s.set(x + 1, y + 1, shade(c, 0.6))
    return s.img


def d_stump(rnd, rotten=False):
    s = Spr(16, 16)
    bark, bark_dk, ring, ring2 = (hx("5a4232"), hx("33241b"), hx("b08a5e"), hx("8a6a46"))
    if rotten:
        bark, bark_dk, ring, ring2 = hx("3e3a2a"), hx("1e1c14"), hx("6e6a48"), hx("54503a")
    for y in range(16):
        for x in range(16):
            dx, dy = (x + 0.5 - 8) / 5.0, (y + 0.5 - 7) / 2.6
            if dx * dx + dy * dy <= 1:
                s.set(x, y, ring if dx * dx + dy * dy < 0.45 else ring2)
            elif abs(x + 0.5 - 8) <= 5 and 7 <= y <= 12:
                s.set(x, y, bark if x < 9 else bark_dk)
    for x in range(4, 13):
        s.set(x, 13, (12, 8, 22, 110))
    s.set(8, 7, bark_dk)
    s.set(7, 7, ring2)
    s.set(3, 12, bark)
    s.set(12, 12, bark_dk)   # roots
    if rotten:
        for (x, y) in ((5, 6), (6, 5), (10, 7)):
            s.set(x, y, MOSS["mid"])
    else:
        s.set(11, 9, MOSS["mid"])
        s.set(4, 10, MOSS["hi"])
    return s.img


def d_puddle(rnd, deep, hi):
    s = Spr(16, 16)
    cx, cy = rnd.uniform(7, 9), rnd.uniform(7, 9)
    rx, ry = rnd.uniform(4.5, 6.5), rnd.uniform(2.5, 3.8)
    for y in range(16):
        for x in range(16):
            dd = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if dd < 1:
                s.set(x, y, deep if dd > 0.35 or y > cy else hi)
            elif dd < 1.35 and y < cy:
                s.set(x, y, (12, 8, 22, 90))
    s.set(int(cx) - 1, int(cy) - 1, hx("dfe8ff", 200))
    return s.img


def d_bubbles(rnd):
    s = Spr(16, 16)
    for _ in range(4):
        x, y = rnd.randrange(3, 13), rnd.randrange(3, 13)
        s.set(x, y, hx("9ab06a"))
        s.set(x + 1, y, hx("c8d8a0"))
        s.set(x, y + 1, hx("4a5a2c"))
    return s.img


def d_rubble(rnd, P):
    s = Spr(16, 16)
    for _ in range(rnd.randrange(3, 5)):
        x, y = rnd.randrange(2, 12), rnd.randrange(4, 13)
        w, h = rnd.randrange(2, 4), rnd.randrange(2, 3)
        for yy in range(h + 1):
            for xx in range(w):
                c = P["t_hi"] if yy == 0 else (P["f"] if yy < h else P["f_dk"])
                if xx == w - 1 and yy:
                    c = P["f_dk"]
                s.set(x + xx, y + yy, c)
        s.set(x + w, y + h, (12, 8, 22, 100))
    return s.img


def d_bones(rnd, skull=False):
    s = Spr(16, 16)
    bone, bone_dk = hx("e8dfc8"), hx("8a826f")
    if skull:
        g = ["..xxxx..", ".xxxxxx.", ".xKxxKx.", ".xKxxKx.", "..xxxx..", "..x.x..."]
        for j, row in enumerate(g):
            for i, ch in enumerate(row):
                if ch == "x":
                    s.set(4 + i, 5 + j, bone if j < 3 else bone_dk)
                elif ch == "K":
                    s.set(4 + i, 5 + j, hx("1a1622"))
        s.set(5, 11, (12, 8, 22, 100))
        s.set(9, 11, (12, 8, 22, 100))
    else:
        for _ in range(3):
            x, y = rnd.randrange(2, 9), rnd.randrange(3, 13)
            ln = rnd.randrange(4, 7)
            for i in range(ln):
                s.set(x + i, y, bone)
                s.set(x + i, y + 1, bone_dk)
            s.set(x - 1, y - 1, bone)
            s.set(x - 1, y + 1, bone)
            s.set(x + ln, y - 1, bone)
            s.set(x + ln, y + 1, bone)
    return s.img


def d_candle(rnd):
    s = Spr(16, 16)
    for (x, h) in ((6, 5), (9, 3), (11, 4)):
        for k in range(h):
            s.set(x, 13 - k, hx("e8e0c8") if k < h - 1 else hx("fff4c8"))
            s.set(x + 1, 13 - k, hx("a89e88"))
        s.set(x, 13 - h, hx("ffd27a"))
    for x in range(5, 13):
        s.set(x, 14, hx("d8d0b8", 160))
    return s.img


def d_moss(rnd, a, b):
    s = Spr(16, 16)
    for _ in range(3):
        cx, cy, r = rnd.uniform(4, 12), rnd.uniform(4, 12), rnd.uniform(2, 3.5)
        for y in range(16):
            for x in range(16):
                if math.hypot(x - cx, y - cy) < r + dith(x, y) - 0.5:
                    s.set(x, y, b if (x - cx) + (y - cy) < -1 else a)
    return s.img


def d_urn(rnd):
    s = Spr(16, 16)
    clay, clay_dk, clay_hi = hx("9a5a3a"), hx("5e3422"), hx("c4805a")
    for y in range(6, 13):
        for x in range(4, 13):
            dx, dy = (x + 0.5 - 8.5) / 4.2, (y + 0.5 - 9.5) / 3.4
            if dx * dx + dy * dy < 1 and not (x > 9 and y < 9):
                s.set(x, y, clay_hi if dx < -0.4 else (clay if dx < 0.4 else clay_dk))
    for (x, y) in ((11, 11), (12, 12), (13, 11)):
        s.set(x, y, clay)
    for x in range(5, 13):
        s.set(x, 13, (12, 8, 22, 100))
    return s.img


def d_branch(rnd):
    s = Spr(16, 16)
    x, y = 1, rnd.randrange(8, 12)
    for i in range(14):
        s.set(x + i, y, hx("4a4232"))
        s.set(x + i, y + 1, hx("1e1c14"))
        if i in (3, 9):
            for k in range(1, 4):
                s.set(x + i + k, y - k, hx("4a4232"))
        if rnd.random() < 0.15:
            y += rnd.choice([-1, 1])
    return s.img


def decor_sheet():
    MP, GP, MS, SW, SS = PALETTES
    rows = []
    r = random.Random
    rows.append([d_ripple(r(1), hx("5a4e44"), hx("8c7e6c")), d_ripple(r(2), hx("5a4e44"), hx("8c7e6c")),
                 d_pebbles(r(3), MP), d_pebbles(r(4), MP, 8), d_crack(r(5), hx("3e342c"), hx("8a7c6c")),
                 d_tuft(r(6), [hx("6e6a3e"), hx("9a9458"), hx("c4bc78")]),
                 d_tuft(r(7), [hx("6e6a3e"), hx("9a9458"), hx("c4bc78")], 2, (4, 7)), d_bones(r(8))])
    green = [MOSS["dark"], MOSS["mid"], MOSS["tip"]]
    rows.append([d_tuft(r(11), green), d_tuft(r(12), green, 2, (4, 8)),
                 d_flowers(r(13), hx("f4f0ff"), hx("f5c542")), d_flowers(r(14), hx("f2d24a"), hx("c87a2a")),
                 d_flowers(r(15), hx("e88ab0"), hx("fff0a0"), 6), d_mushrooms(r(16), hx("c83c3c"), hx("f07a6a")),
                 d_twig(r(17)), d_stump(r(18))])
    rows.append([d_moss(r(21), hx("4f8a4a"), hx("7ab868")), d_flowers(r(22), hx("8ab4ff"), hx("f4f0ff")),
                 d_tuft(r(23), green, 4), d_pebbles(r(24), MS, 6), d_mushrooms(r(25), hx("8a5a3a"), hx("b07a52")),
                 d_leaves(r(26), [hx("8a5a2a"), hx("a8743a"), hx("6a7a30")]),
                 d_tuft(r(27), [hx("3e6a3a"), hx("5e9a52"), hx("9fcf86")], 3, (5, 9)),
                 d_flowers(r(28), hx("ffffff"), hx("f5c542"), 6)])
    marsh = [hx("4a5a2c"), hx("7a9a5a"), hx("a8c07a")]
    rows.append([d_puddle(r(31), hx("18241c", 230), hx("3c5a44", 230)), d_puddle(r(32), hx("18241c", 230), hx("3c5a44", 230)),
                 d_tuft(r(33), marsh, 3, (4, 8)), d_tuft(r(34), marsh, 4, (3, 6)), d_branch(r(35)),
                 d_mushrooms(r(36), hx("7ad8c0"), hx("c8fff0"), True), d_bubbles(r(37)), d_stump(r(38), True)])
    rows.append([d_crack(r(41), hx("4e463e"), hx("cfc3ac")), d_tuft(r(42), green, 2, (2, 4)),
                 d_moss(r(43), hx("4e7a44"), hx("72a45e")), d_rubble(r(44), SS), d_rubble(r(45), SS),
                 d_leaves(r(46), [hx("8a5a2a"), hx("a8743a"), hx("6e4a2c")]), d_tuft(r(47), green, 3, (3, 5)), d_urn(r(48))])
    rows.append([d_bones(r(51)), d_bones(r(52), True), d_rubble(r(53), GP), d_candle(r(54)),
                 d_crack(r(55), hx("2b2633"), hx("a39cae")), d_crack(r(56), hx("2b2633"), hx("a39cae")),
                 d_puddle(r(57), hx("1d2c44", 220), hx("4f7aa4", 220)), d_moss(r(58), hx("3f6a4a"), hx("5f9a5e"))])
    sheet = Image.new("RGBA", (16 * 8, 16 * len(rows)), (0, 0, 0, 0))
    for j, row in enumerate(rows):
        for i, im in enumerate(row):
            sheet.paste(im, (i * 16, j * 16))
    return sheet


# ---------------------------------------------------------------------------
# Ground patches (32x32, crisp dithered edges)
# ---------------------------------------------------------------------------
def patch(seed, cols, weights, alpha=255, specks=None):
    rnd = random.Random(seed)
    s = Spr(32, 32)
    blobs = [(16 + rnd.uniform(-5, 5), 16 + rnd.uniform(-4, 4), rnd.uniform(6, 10)) for _ in range(4)]
    for y in range(32):
        for x in range(32):
            f = 0.0
            for (bx, by, br) in blobs:
                dd = math.hypot(x + 0.5 - bx, (y + 0.5 - by) * 1.25) / br
                f = max(f, 1 - dd)
            edge = min(1.0, math.hypot(x - 15.5, y - 15.5) / 15.5)
            f -= max(0.0, edge - 0.75) * 2
            if f <= dith(x, y) * 0.35:
                continue
            k = rnd.random()
            acc = 0
            c = cols[0]
            for cc, w in zip(cols, weights):
                acc += w
                if k < acc:
                    c = cc
                    break
            s.set(x, y, (c[0], c[1], c[2], alpha))
    if specks:
        for _ in range(specks[1]):
            x, y = rnd.randrange(32), rnd.randrange(32)
            if s.get(x, y)[3]:
                s.set(x, y, specks[0])
    return s.img


def patches_sheet():
    rows = [
        [patch(1, [hx("857560"), hx("7a6c58"), hx("958670")], [0.6, 0.25, 0.15], 255, (hx("a89a84"), 10)),   # light sand
         patch(2, [hx("5a5048"), hx("4e463e"), hx("6a5e54")], [0.5, 0.3, 0.2], 255, (hx("8f8478"), 18)),   # gravel
         patch(3, [hx("6e6a3e"), hx("5e5a36"), hx("847e4a")], [0.5, 0.3, 0.2], 255, (hx("a8a060"), 12))],  # dry grass
        [patch(11, [hx("4a3a2c"), hx("5a4636"), hx("3e3026")], [0.5, 0.3, 0.2], 255, (hx("8a5a2a"), 22)),  # leaf litter
         patch(12, [hx("2f523b"), hx("355a40"), hx("24402f")], [0.5, 0.3, 0.2], 255, (hx("4f8058"), 14)),  # dark moss
         patch(13, [hx("4f8058"), hx("47764f"), hx("5a8c5e")], [0.5, 0.3, 0.2], 255, (hx("9fcf86"), 10))],  # clover
        [patch(21, [hx("4a3e30"), hx("54463a"), hx("3e342a")], [0.5, 0.3, 0.2], 255, (hx("2c241c"), 10)),  # wet earth
         patch(22, [hx("4f8058"), hx("47764f"), hx("5a8c5e")], [0.5, 0.3, 0.2], 255, (hx("c9d8ff"), 6)),
         patch(23, [hx("5a4e40"), hx("4e4436"), hx("665a4a")], [0.5, 0.3, 0.2], 255, (hx("8f8a96"), 20))],
        [patch(31, [hx("2a2a1c"), hx("323222"), hx("242418")], [0.5, 0.3, 0.2], 255, (hx("4a5a2c"), 10)),  # black mud
         patch(32, [hx("3e5a24"), hx("4a6a2a"), hx("34501e")], [0.5, 0.3, 0.2], 255, (hx("7e9c3c"), 12)),  # algae
         patch(33, [hx("3a3226"), hx("443a2c"), hx("30291f")], [0.5, 0.3, 0.2], 255, (hx("6a5a3a"), 10))],
        [patch(41, [hx("6e7a52"), hx("627048"), hx("7a865a")], [0.5, 0.3, 0.2], 200, (hx("9fcf86"), 8)),   # moss stain
         patch(42, [hx("8a7c68"), hx("7e705e"), hx("968872")], [0.5, 0.3, 0.2], 220, (hx("4e463e"), 10)),  # worn
         patch(43, [hx("6a5a48"), hx("5e5040"), hx("766652")], [0.5, 0.3, 0.2], 220, (hx("8a7a64"), 10))],
        [patch(51, [hx("3f6a4a"), hx("2f523b"), hx("4f8058")], [0.5, 0.3, 0.2], 190, None),               # crypt moss
         patch(52, [hx("4a4458"), hx("423c50"), hx("524c60")], [0.5, 0.3, 0.2], 170, None),               # damp
         patch(53, [hx("8a8278"), hx("7e766e"), hx("968e84")], [0.5, 0.3, 0.2], 120, None)],              # dust
    ]
    sheet = Image.new("RGBA", (32 * 3, 32 * len(rows)), (0, 0, 0, 0))
    for j, row in enumerate(rows):
        for i, im in enumerate(row):
            sheet.paste(im, (i * 32, j * 32))
    return sheet


# ---------------------------------------------------------------------------
# Berry bushes (32x32, foot at (16, 27) like the rocks):
#   0 forest bush, picked   1 forest bush with red berries
#   2 marsh bush, picked    3 marsh bush with blue berries
# ---------------------------------------------------------------------------
def bush(marsh, berries, seed):
    rnd = random.Random(seed)
    s = Spr(32, 32)
    if marsh:
        leaf = [hx("1c3326"), hx("2a4a36"), hx("3d6648"), hx("5a8a60"), hx("7fae78")]
        outline = hx("0e1a12")
    else:
        leaf = [hx("17331f"), hx("234a2c"), hx("2f5f38"), hx("4c8a4a"), hx("74b064")]
        outline = hx("0c1a10")
    cast_shadow(s, 16, 27, 18, 100)
    blobs = [(16, 18, 8.5), (10, 21, 6), (22, 21, 6), (13, 13, 5.5), (20, 14, 5.5)]
    body = [[False] * 32 for _ in range(32)]
    shade_v = [[0.0] * 32 for _ in range(32)]
    for y in range(32):
        for x in range(32):
            best = None
            for (bx, by, br) in blobs:
                d = math.hypot(x + 0.5 - bx, (y + 0.5 - by) * 1.1) / br
                if d <= 1 and y <= 27:
                    lit = ((bx - x) + (by - y)) / br * 0.6 + (1 - d) * 0.4 - (y - 12) / 30.0
                    best = lit if best is None else max(best, lit)
            if best is not None:
                body[y][x] = True
                shade_v[y][x] = best
    for y in range(32):
        for x in range(32):
            if not body[y][x]:
                continue
            v = shade_v[y][x] + (dith(x, y) - 0.5) * 0.35
            k = 0 if v < -0.25 else 1 if v < 0.05 else 2 if v < 0.3 else 3 if v < 0.55 else 4
            if y >= 25:
                k = min(k, 1)
            s.set(x, y, leaf[k])
    # leaf clusters: little bright crescents
    for _ in range(14):
        x, y = rnd.randrange(6, 26), rnd.randrange(9, 24)
        if body[y][x] and body[y + 1][x]:
            s.set(x, y, leaf[4] if y < 17 else leaf[3])
            s.set(x + 1, y + 1, leaf[1])
    for y in range(32):
        for x in range(32):
            if body[y][x]:
                continue
            if any(0 <= x + dx < 32 and 0 <= y + dy < 32 and body[y + dy][x + dx]
                   for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                s.set(x, y, outline)
    if berries:
        if marsh:
            b, bd, bh = hx("4a6cf0"), hx("22307a"), hx("d8e4ff")
        else:
            b, bd, bh = hx("e0303c"), hx("7a1020"), hx("ffc8c8")
        spots = [(10, 14), (19, 11), (22, 19), (13, 20), (17, 16), (24, 14)]
        for (x, y) in spots:
            x += rnd.randrange(-1, 2)
            y += rnd.randrange(-1, 2)
            for (dx, dy, c) in ((0, -1, b), (1, -1, b), (-1, 0, b), (0, 0, bh), (1, 0, b), (2, 0, bd),
                                (-1, 1, b), (0, 1, b), (1, 1, bd), (2, 1, bd), (0, 2, bd), (1, 2, bd)):
                s.set(x + dx, y + dy, c)
            s.set(x, y + 3, (8, 6, 14, 110))
            s.set(x + 1, y + 3, (8, 6, 14, 110))
    return s.img


def bushes_sheet():
    sheet = Image.new("RGBA", (32 * 4, 32), (0, 0, 0, 0))
    for i, (marsh, ber) in enumerate([(False, False), (False, True), (True, False), (True, True)]):
        sheet.paste(bush(marsh, ber, 900 + (i // 2)), (i * 32, 0))
    return sheet


# ---------------------------------------------------------------------------
# Lume, your companion flame: 12x14 frames.
#   0, 1 idle flicker   2 talking (mouth open)   3 eyes closed (blink)
# ---------------------------------------------------------------------------
def lume(frame):
    s = Spr(12, 14)
    core, mid, edge, rim = hx("fffbea"), hx("ffe7a0"), hx("ffb45a"), hx("c8642e")
    tip = 1 if frame == 1 else 0
    for y in range(14):
        for x in range(12):
            cx = 5.5 + (0.6 if frame == 1 and y < 6 else 0)
            # teardrop: round bottom (r=4.6 around y=9), tapering to a tip
            if y >= 8:
                d = math.hypot(x + 0.5 - 6, (y + 0.5 - 8.6) * 1.05) / 4.7
            else:
                wdt = 4.7 * (max(0.0, y + 0.5 - tip) / 8.0) ** 0.8
                d = abs(x + 0.5 - cx - (8 - y) * 0.12) / max(0.3, wdt)
            if d > 1.0:
                continue
            c = core if d < 0.45 else mid if d < 0.72 else edge
            if d > 0.88:
                c = rim
            s.set(x, y, c)
    dark = hx("2a1a20")
    if frame == 3:
        s.set(4, 9, dark); s.set(5, 9, dark); s.set(7, 9, dark); s.set(8, 9, dark)
    else:
        for (x, y) in ((4, 8), (4, 9), (8, 8), (8, 9)):
            s.set(x, y, dark)
        s.set(4, 8, hx("ffffff")) if False else None
    if frame == 2:
        s.set(6, 11, dark); s.set(6, 12, hx("c8642e"))
    else:
        s.set(6, 11, hx("e08a50"))
    s.set(3, 10, hx("ffb0a0")); s.set(9, 10, hx("ffb0a0"))   # blush
    return s.img


def lume_sheet():
    sheet = Image.new("RGBA", (12 * 4, 14), (0, 0, 0, 0))
    for f in range(4):
        sheet.paste(lume(f), (f * 12, 0))
    return sheet


if __name__ == "__main__":
    lume_sheet().save(OUT / "lume.png")
    teal = lume_sheet()   # player 2's spirit: a teal flame
    tp = teal.load()
    for y in range(teal.height):
        for x in range(teal.width):
            r, g, b, a = tp[x, y]
            if a and not (r < 60 and g < 40):   # leave the dark eyes alone
                tp[x, y] = (int(r * 0.35), int(min(255, g * 1.0)), int(min(255, b * 0.9 + 90)), a)
    teal.save(OUT / "lume_teal.png")
    bushes_sheet().save(OUT / "bushes.png")
    rocks_sheet().save(OUT / "rocks.png")
    decor_sheet().save(OUT / "decor.png")
    patches_sheet().save(OUT / "patches.png")
    print("wrote rocks.png, decor.png, patches.png")
