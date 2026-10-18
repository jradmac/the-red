"""The Wolf Man, up close: a head-and-shoulders portrait for the intro.

    python3 tools/make_wolfman_closeup.py   ->  assets/wolfman_closeup.png

It's the creature the game already has (tools/make_longman.py), seen from an
arm's length: pale and starved, a long blank face like a skull wearing skin,
hollow at the temples and cheeks, and where a face should be, one hole --
cracks running out of it and a dried trail down to the chin. Stringy hair
hangs either side. A long neck all tendon, collarbones, the top of the ribs.
One hand comes up out of the dark below, fingers too long, nails black.
Lit from beneath by a lantern; a cold rim of light behind. The name is
symbolic: no fur, no snout.

Four 160 x 128 frames side by side:
    0  still                    1  the head tilted, the hand reaching closer
    2  frame 0's glint alone    3  frame 1's glint alone
(the glint: a pale pinprick deep in the hole; the intro draws it again,
glowing, when the light is gone)

Built like a small sculpture -- lit volumes (a tapered ellipsoid head, tube
neck and fingers) shaded in the same cold-purple-to-bone ramp as the sprite,
crushed to the palette with ordered dithering so it sits with the pixel art.
"""
from pathlib import Path
import math

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "wolfman_closeup.png"
W, H = 160, 128
# the sprite's skin ramp (make_longman.py): cold purple shadows up to warm bone
SK = ["0d0912", "1c1424", "2b2236", "463c55", "685d74", "8f8594", "b4aaab", "d3cabf", "ece5d8", "fbf6ec"]
HAIR = ["0a070d", "1a121e", "2c2232", "3e3246"]
NAIL = ["060408", "151018", "2a2230"]
TRAIL = ["1a0c10", "2e1418", "44201f"]
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def hx(s):
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], dtype=float)


def noise2(w, h, scale, seed):
    rng = np.random.default_rng(seed)
    gw, gh = int(w / scale) + 3, int(h / scale) + 3
    g = rng.uniform(-1, 1, (gh, gw))
    ys, xs = np.mgrid[0:h, 0:w] / scale
    x0, y0 = xs.astype(int), ys.astype(int)
    fx, fy = xs - x0, ys - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = g[y0, x0] * (1 - fx) + g[y0, x0 + 1] * fx
    b = g[y0 + 1, x0] * (1 - fx) + g[y0 + 1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


class Sculpt:
    def __init__(self):
        self.ys, self.xs = np.mgrid[0:H, 0:W].astype(float)
        self.z = np.full((H, W), -999.0)
        self.part = np.zeros((H, W), int)

    def blob(self, cx, cy, rx, ry, rz, cz, pid, taper=None):
        """An ellipsoid; `taper(k)` narrows it row by row (k: -1 top .. 1 bottom)."""
        k = (self.ys - cy) / ry
        sx = rx * (taper(k) if taper else 1.0)
        u = ((self.xs - cx) / sx) ** 2 + k ** 2
        zz = cz + rz * np.sqrt(np.clip(1 - u, 0, 1))
        take = (u < 1) & (zz > self.z)
        self.z[take] = zz[take]
        self.part[take] = pid

    def tube(self, pts, r0, r1, cz, pid):
        """A tapered tube through points (x, y), radius r0 at the start to r1."""
        segs = len(pts) - 1
        for i in range(segs):
            (x0, y0), (x1, y1) = pts[i], pts[i + 1]
            n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
            for j in range(n + 1):
                t = j / n
                x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
                g = (i + t) / segs
                r = r0 + (r1 - r0) * g
                self.blob(x, y, r, r, r, cz + 2 * g, pid)


def build(tilt=0.0, reach=0.0, seed=5):
    s = Sculpt()
    hx0, hy0 = 80 + tilt * 3, 46
    # shoulders and the top of the chest: bone under thin skin
    s.blob(80, 136, 74, 30, 18, -20, 1)
    s.blob(30, 122, 26, 18, 14, -14, 1)
    s.blob(130, 122, 26, 18, 14, -14, 1)
    # the neck: long, thin, all tendon
    s.blob(80, 100, 10, 26, 9, -4, 1)
    # the head: a long oval, narrowing to a sharp jaw
    s.blob(hx0, hy0, 25, 42, 22, 4, 2, taper=lambda k: 1 - 0.5 * np.clip(k - 0.15, 0, None) ** 1.2)
    # the hand, rising from the dark below on the right, fingers too long
    hb = (128 - reach * 8, 128)
    palm = (120 - reach * 10, 104 - reach * 10)
    s.blob(palm[0], palm[1] + 8, 9, 10, 7, 14, 3)
    s.tube([hb, (palm[0] + 2, palm[1] + 14)], 7, 6, 8, 3)                 # wrist
    fingers = []
    for i, (dx, ln, bend) in enumerate(((-9, 30, 0.5), (-3, 36, 0.35), (3, 34, 0.2), (8, 26, 0.0))):
        base = (palm[0] + dx, palm[1])
        mid = (base[0] + dx * 0.4 - 4, base[1] - ln * 0.55)
        tip = (mid[0] - 6 - bend * 10, mid[1] - ln * 0.35 + bend * 8)     # curling toward you
        fingers.append(tip)
        s.tube([base, mid, tip], 2.6, 1.4, 16 + i, 3)
    return s, (hx0, hy0), fingers


def shade(s, centre, fingers, tilt, seed):
    z, part, xs, ys = s.z, s.part, s.xs, s.ys
    mask = part > 0
    zf = np.where(mask, z, -40.0)
    gx, gy = np.gradient(zf, axis=1), np.gradient(zf, axis=0)
    nx, ny, nz = -gx, -gy, np.full_like(gx, 1.3)
    ln = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    nx, ny, nz = nx / ln, ny / ln, nz / ln
    L = np.array([0.25, 0.8, 0.55]); L /= np.linalg.norm(L)          # the lantern, low in front
    key = np.clip(nx * L[0] + ny * L[1] + nz * L[2], 0, 1)
    rim = np.clip(1 - nz, 0, 1) ** 2 * np.clip(-nx * 0.7 - ny * 0.7, 0, 1)
    up = np.clip(0.25 + ys / H * 0.95, 0, 1)                          # light falls off upward
    v = 0.05 + 0.92 * key * up + rim * 0.35
    hx0, hy0 = centre
    # hollows: temples, cheeks, the faint sockets where eyes should be
    def hollow(cx, cy, rx, ry, amt):
        u = ((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2
        return np.where(u < 1, (1 - u) * amt, 0)
    head = part == 2
    dark = np.zeros_like(v)
    for side in (-1, 1):
        dark += hollow(hx0 + side * 19, hy0 - 16, 7, 12, 0.35)
        dark += hollow(hx0 + side * 14, hy0 + 16, 6, 13, 0.4)
        dark += hollow(hx0 + side * 10, hy0 - 4, 7, 4, 0.22)
    v = np.where(head, v - dark, v)
    # tendons and collarbones: lit ridges with shade beside them
    for side in (-1, 1):
        ridge = (np.abs(xs - (80 + side * 4 - (ys - 80) * side * 0.12)) < 1.0) & (ys > 78) & (ys < 112) & (part == 1)
        v = np.where(ridge, v + 0.18, v)
        cb = (np.abs(ys - (112 + np.abs(xs - 80) * 0.12 - side * 0)) < 1.0) & (np.abs(xs - 80) > 8) & (np.abs(xs - 80) < 42) & (part == 1)
        v = np.where(cb, v + 0.16, v)
        cbs = (np.abs(ys - (114 + np.abs(xs - 80) * 0.12)) < 1.0) & (np.abs(xs - 80) > 8) & (np.abs(xs - 80) < 42) & (part == 1)
        v = np.where(cbs, v - 0.2, v)
    for r in range(3):   # the tops of the ribs
        rib = (np.abs(ys - (121 + r * 4 + np.abs(xs - 80) * 0.05)) < 0.8) & (np.abs(xs - 80) > 4) & (np.abs(xs - 80) < 34 - r * 2) & (part == 1)
        v = np.where(rib, v - 0.22, v)
    # knuckles on the fingers
    v = np.where(part == 3, v + 0.04, v)
    grain = noise2(W, H, 1.2, seed) * 0.05
    v = v + grain
    img = np.zeros((H, W, 3))
    th = BAYER[(np.arange(H)[:, None] % 4), (np.arange(W)[None, :] % 4)]
    cols = [hx(c) for c in SK]
    t = np.clip(v, 0, 0.999) * (len(cols) - 1)
    idx = np.clip(np.floor(t + th - 0.5 + 0.5), 0, len(cols) - 1).astype(int)
    for i, c in enumerate(cols):
        img[mask & (idx == i)] = c
    alpha = mask.copy()
    # --- the hole: one ragged dark opening where the face should be ---
    rng = np.random.default_rng(seed)
    hcx, hcy = hx0 + 2, hy0 + 2
    glint = np.zeros((H, W), bool)
    for y in range(int(hcy - 9), int(hcy + 10)):
        for x in range(int(hcx - 8), int(hcx + 8)):
            a = math.atan2(y - hcy, x - hcx)
            rr = 6.5 + 1.6 * math.sin(a * 3 + 1) + 1.2 * math.sin(a * 7)
            d = math.hypot((x - hcx) * 1.15, (y - hcy) * 0.85)
            if d < rr:
                img[y, x] = hx(SK[0]) if d < rr - 1.5 else hx(SK[1])
            elif d < rr + 1.2:
                img[y, x] = hx(SK[6])                 # a lit lip of torn skin
    # deep inside, a pinprick of pale light (or something looking out)
    for (x, y) in ((int(hcx), int(hcy + 1)),):
        img[y, x] = hx("fffbe8")
        glint[y, x] = True
    # cracks running out of it
    for k in range(7):
        a = rng.uniform(0, math.tau)
        x, y = hcx + math.cos(a) * 7, hcy + math.sin(a) * 8
        for step in range(int(rng.integers(6, 16))):
            a += rng.uniform(-0.6, 0.6)
            x += math.cos(a); y += math.sin(a)
            xi, yi = int(round(x)), int(round(y))
            if 0 <= xi < W and 0 <= yi < H and part[yi, xi] == 2:
                img[yi, xi] = hx(SK[1])
                if rng.random() < 0.3 and part[yi + 1, xi] == 2:
                    img[yi + 1, xi] = hx(SK[3])
    # the dried trail running down from the hole to the chin and the neck
    x = hcx + 1
    for y in range(int(hcy + 8), 112):
        x += rng.uniform(-0.6, 0.6)
        w = 2 if y < hcy + 30 else 1
        for dx in range(w):
            xi = int(round(x)) + dx
            if part[y, xi] > 0:
                img[y, xi] = hx(TRAIL[(y // 3 + dx) % 3])
    # --- stringy hair hanging either side of the face ---
    for side in (-1, 1):
        for k in range(9):
            x = hx0 + side * (10 + k * 1.8 + rng.uniform(-1, 1))
            y = hy0 - 38 + k * 1.5 + rng.uniform(0, 3)
            ln = rng.integers(40, 84)
            sway = rng.uniform(0.05, 0.25) * side
            for step in range(int(ln)):
                x += sway + math.sin(step * 0.15 + k) * 0.25
                y += 1
                xi, yi = int(round(x)), int(round(y))
                if 0 <= xi < W and 0 <= yi < H:
                    img[yi, xi] = hx(HAIR[(k + step // 7) % len(HAIR)])
                    alpha[yi, xi] = True
    # --- black nails on the fingers ---
    for tip in fingers:
        for d in range(4):
            xi, yi = int(round(tip[0] - d * 0.6)), int(round(tip[1] - d))
            if 0 <= xi < W and 0 <= yi < H:
                img[yi, xi] = hx(NAIL[min(d, 2)])
                alpha[yi, xi] = True
    # --- outline: near-black on the shadow side ---
    a = alpha
    edge = a & ~(np.roll(a, 1, 0) & np.roll(a, -1, 0) & np.roll(a, 1, 1) & np.roll(a, -1, 1))
    img[edge & ~glint] = img[edge & ~glint] * 0.3 + hx("120b18") * 0.7 * 0.5
    out = np.zeros((H, W, 4), np.uint8)
    out[..., :3] = np.clip(img, 0, 255).astype(np.uint8)
    out[..., 3] = np.where(a, 255, 0)
    g = np.zeros((H, W, 4), np.uint8)
    g[glint, :3] = 255
    g[glint, 3] = 255
    return Image.fromarray(out, "RGBA"), Image.fromarray(g, "RGBA")


def frame(tilt, reach, seed=5):
    s, centre, fingers = build(tilt, reach, seed)
    img, glint = shade(s, centre, fingers, tilt, seed)
    if tilt:
        # the head tilts: turn the whole picture a few degrees about the neck
        img = img.rotate(-tilt * 6, resample=Image.NEAREST, center=(80, 100))
        glint = glint.rotate(-tilt * 6, resample=Image.NEAREST, center=(80, 100))
    return img, glint


def main():
    a, ag = frame(0.0, 0.0)
    b, bg = frame(1.0, 1.0)
    sheet = Image.new("RGBA", (W * 4, H), (0, 0, 0, 0))
    for i, im in enumerate((a, b, ag, bg)):
        sheet.paste(im, (i * W, 0))
    sheet.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
