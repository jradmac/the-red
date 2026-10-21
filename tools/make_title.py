"""Builds the title logo: assets/title_logo.png, "THE RED" carved and
scratched -- heavy Roman capitals, THE over RED, their edges eroded and chipped, gouges
slashed across them, a chiselled bevel and a grain like hammered metal, lit
red-hot from below like the lantern.

The letters start from TeX Gyre Bonum Bold (tools/fonts, GUST Font License),
are worked at 4x and brought down to pixels on a small ramp. The title screen
itself (scripts/title_screen.gd) is just the dark, drifting motes and this.
Run:  python3 tools/make_title.py
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT = Path(__file__).resolve().parent / "fonts" / "texgyrebonum-bold.otf"
SS = 4
LINES = ["THE", "RED"]    # stacked, both the same size
TRACK = 0.04                 # extra space between letters (of the size)
LEAD = 1.08                  # line spacing (of the cap height)
LOGO_W, LOGO_H = 300, 112
CAP = 44                     # cap height, pixels
# dark crimson -> red-hot ember
RAMP = [(28, 3, 7), (58, 6, 12), (96, 10, 16), (138, 18, 20), (182, 36, 26), (222, 82, 44), (250, 156, 92),
        (255, 220, 170)]


def value_noise(w, h, cell, rng):
    """Smooth noise 0..1 at a cell size (bilinear between random lattice points)."""
    gw, gh = w // cell + 2, h // cell + 2
    img = Image.new("L", (gw, gh))
    img.putdata([int(rng.random() * 255) for _ in range(gw * gh)])
    return img.resize((gw * cell, gh * cell), Image.BICUBIC).crop((0, 0, w, h))


def letters():
    W, H = LOGO_W * SS, LOGO_H * SS
    probe = ImageFont.truetype(str(FONT), 100)
    bb = probe.getbbox("H")
    size = int(100 * CAP * SS / (bb[3] - bb[1]))
    font = ImageFont.truetype(str(FONT), size)
    cap_top = font.getbbox("H")[1]
    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    block = CAP * SS * (1 + LEAD)
    y0 = (H - block) / 2
    for i, line in enumerate(LINES):
        widths = [font.getlength(c) for c in line]
        total = sum(widths) + TRACK * size * (len(line) - 1)
        x = (W - total) / 2
        y = y0 + i * CAP * SS * LEAD - cap_top
        for c, w in zip(line, widths):
            d.text((x, y), c, font=font, fill=255)
            x += w + TRACK * size
    return mask


def distress(mask, rng):
    W, H = mask.size
    # 1. eroded, ragged edges: keep a pixel where the softened letter plus noise is solid enough
    soft = mask.filter(ImageFilter.GaussianBlur(2.0 * SS / 2))
    n1 = value_noise(W, H, 6, rng)
    n2 = value_noise(W, H, 2, rng)
    sp, p1, p2, mp = soft.load(), n1.load(), n2.load(), mask.load()
    out = Image.new("L", (W, H), 0)
    op = out.load()
    for y in range(H):
        for x in range(W):
            if mp[x, y] < 128:
                continue
            v = sp[x, y] / 255 + (p1[x, y] / 255 - 0.5) * 0.38 + (p2[x, y] / 255 - 0.5) * 0.22
            if v > 0.42:
                op[x, y] = 255
    d = ImageDraw.Draw(out)
    # 2. chips knocked out of the edges
    edge_pts = [(x, y) for y in range(0, H, 3) for x in range(0, W, 3)
                if op[x, y] and (not op[min(W - 1, x + 6), y] or not op[x, min(H - 1, y + 6)]
                                 or not op[max(0, x - 6), y] or not op[x, max(0, y - 6)])]
    for _ in range(45):
        cx, cy = rng.choice(edge_pts)
        r = rng.uniform(1.5, 4.5) * SS / 2
        pts = [(cx + math.cos(a) * r * rng.uniform(0.6, 1.3), cy + math.sin(a) * r * rng.uniform(0.6, 1.3))
               for a in [i * math.tau / 6 for i in range(6)]]
        d.polygon(pts, fill=0)
    # 3. gouges: long slashes across the word, a few deep (cut right through)
    gouges = []
    for i in range(13):
        y0 = rng.uniform(0.12, 0.88) * H
        a = rng.uniform(-0.2, 0.2) + (0.0 if i % 3 else rng.choice((-0.45, 0.45)))
        x0 = rng.uniform(-0.1, 0.65) * W
        ln = rng.uniform(0.25, 0.7) * W
        x1, y1 = x0 + math.cos(a) * ln, y0 + math.sin(a) * ln
        deep = i < 6
        width = (rng.uniform(0.9, 1.6) if deep else rng.uniform(0.5, 0.9)) * SS
        gouges.append((x0, y0, x1, y1, width, deep))
        if deep:   # tapered: thin at both ends
            steps = 40
            for s in range(steps):
                t0, t1 = s / steps, (s + 1) / steps
                w = width * math.sin(math.pi * (t0 + t1) / 2) + 0.6
                d.line([(x0 + (x1 - x0) * t0, y0 + (y1 - y0) * t0), (x0 + (x1 - x0) * t1, y0 + (y1 - y0) * t1)],
                       fill=0, width=max(1, int(w)))
    # 4. pits and pocks
    for _ in range(140):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.choice((1, 1, 1, 2, 2)) * SS / 4
        d.ellipse([x - r, y - r, x + r, y + r], fill=0)
    return out, gouges


def shade(carved, gouges, rng):
    W, H = carved.size
    # height: thick in the middle of a stroke, sloping at the edges (the chisel bevel)
    hmap = carved.filter(ImageFilter.GaussianBlur(1.6 * SS))
    w, h = W // SS, H // SS
    cov = carved.resize((w, h), Image.BOX).load()
    hs = hmap.resize((w, h), Image.BOX).load()
    grain = value_noise(w, h, 1, rng).load()
    blotch = value_noise(w, h, 5, rng).load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    o = out.load()
    L = (-0.45, -0.75, 0.5)
    ln = math.sqrt(sum(c * c for c in L))
    L = tuple(c / ln for c in L)
    for y in range(h):
        for x in range(w):
            if cov[x, y] < 120:
                continue
            gx = (hs[min(w - 1, x + 1), y] - hs[max(0, x - 1), y]) / 255.0
            gy = (hs[x, min(h - 1, y + 1)] - hs[x, max(0, y - 1)]) / 255.0
            n = (-gx * 1.8, -gy * 1.8, 1.0)
            nl = math.sqrt(sum(c * c for c in n))
            lit = sum(n[k] / nl * L[k] for k in range(3)) - 0.5
            heat = 0.25 + 0.55 * (y / h) ** 1.4      # red-hot towards the bottom, like lantern light from below
            v = 1.45 + lit * 5.5 + heat * 2.0 + (grain[x, y] / 255 - 0.5) * 0.9 + (blotch[x, y] / 255 - 0.5) * 1.2
            k = int(max(1, min(len(RAMP) - 1, round(v))))
            o[x, y] = RAMP[k] + (255,)
    # shallow scratches: thin bright or dark lines across the face, not through it
    for (x0, y0, x1, y1, width, deep) in gouges:
        if deep:
            continue
        col = RAMP[rng.choice((1, 1, 6))] + (255,)
        p0, p1 = (x0 / SS, y0 / SS), (x1 / SS, y1 / SS)
        n = int(math.dist(p0, p1))
        for s in range(n):
            t = s / max(1, n)
            px, py = round(p0[0] + (p1[0] - p0[0]) * t), round(p0[1] + (p1[1] - p0[1]) * t)
            if 0 <= px < w and 0 <= py < h and o[px, py][3] and rng.random() < 0.85:
                o[px, py] = col
    for _ in range(60):   # short nicks
        x, y = rng.randrange(w), rng.randrange(h)
        if o[x, y][3]:
            a = rng.uniform(-0.6, 0.6)
            for t in range(rng.randint(2, 6)):
                px, py = round(x + math.cos(a) * t), round(y + math.sin(a) * t)
                if 0 <= px < w and 0 <= py < h and o[px, py][3]:
                    o[px, py] = RAMP[1] + (255,)
    # the deep gouges' lips catch the light on their lower edge
    for (x0, y0, x1, y1, width, deep) in gouges:
        if not deep:
            continue
        a = math.atan2(y1 - y0, x1 - x0)
        nx, ny = -math.sin(a), math.cos(a)
        n = int(math.dist((x0, y0), (x1, y1)) / SS)
        for s in range(n):
            t = s / max(1, n)
            cx, cy = (x0 + (x1 - x0) * t) / SS, (y0 + (y1 - y0) * t) / SS
            px, py = round(cx + nx * (width / SS + 0.8)), round(cy + ny * (width / SS + 0.8))
            if 0 <= px < w and 0 <= py < h and o[px, py][3]:
                o[px, py] = RAMP[5] + (255,)
    # a dark outline so it holds against the dark
    rim = [(x, y) for y in range(h) for x in range(w) if not o[x, y][3] and any(
        0 <= x + dx < w and 0 <= y + dy < h and o[x + dx, y + dy][3] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for (x, y) in rim:
        o[x, y] = (10, 2, 6, 220)
    return out


def main():
    rng = random.Random(300)
    carved, gouges = distress(letters(), rng)
    shade(carved, gouges, rng).save(ROOT / "assets" / "title_logo.png")
    print("wrote the title logo")


if __name__ == "__main__":
    main()
