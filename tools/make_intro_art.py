"""Close-up art for the intro's lesson pictures.

    python3 tools/make_intro_art.py   ->  assets/intro_art.png
                                          assets/intro_wolfman.png
                                          scripts/intro_art.gd   (where each picture is)

The lessons used to blow the 16 px game sprites up 3-4x; these are drawn at
the size they're shown, with the same care as the battle creatures: stone
arches block by block, plank doors with grain and riveted straps in the
key's metal, ornate keys, lit chests, a brass lantern with real glass, a
matchbox, a stone wall to set the gates in -- and the Wolf Man, no longer a
cut-out head and shoulders but a shape in the dark that the lantern catches
from one side: face, hand and the edge of a shoulder lit, the rest of him
falling away into black.

Everything is lit from the upper left (a lantern held up beside you), shaded
onto hand-picked ramps with clean bands, outlined in near-black.
"""
from pathlib import Path
import math

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "intro_art.png"
OUT_WOLF = ROOT / "assets" / "intro_wolfman.png"
OUT_GD = ROOT / "scripts" / "intro_art.gd"

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
INK = "120c18"


def hx(s):
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


R = {   # ramps, darkest to lightest
    "stone": ["0c0a12", "17141f", "231f2c", "322d3c", "443e50", "585166", "6e677c", "8a8396"],
    "mortar": ["07060b", "0e0c14", "16131d"],
    "moss": ["16200f", "22301a", "324426", "465c34"],
    "wood": ["160b07", "26140b", "3a2010", "502e17", "6a3e1f", "84512a", "9e6638", "b67c4a"],
    "iron": ["0b0b11", "17171f", "24242f", "343442", "484858", "62627a"],
    "bronze": ["240f06", "421f0c", "673313", "8f4f1d", "b56c2e", "d48c48", "eaae6c", "fbd59e"],
    "silver": ["181822", "2e3040", "4a4e62", "6c7288", "9298ae", "b8bdcf", "dcdfe9", "fbfcff"],
    "gold": ["281604", "4c2e08", "77500e", "a37616", "cc9a26", "e8bc48", "f6d978", "fff2c2"],
    "violet": ["0c0614", "170b28", "26103e", "381858", "4e2478", "6a34a0", "8c50cc", "b682f0", "dcc0ff"],
    "obsid": ["08060c", "100c18", "1a1426", "261d36", "33284a", "43365e"],
    "red": ["2a0a0c", "4a1016", "701a20", "96282a", "b83c34", "d65a44", "ee8a62"],
    "card": ["3a2a1e", "6a5038", "9a7c58", "c8ae84", "e8d6b0", "faf0d8"],
    "pine": ["3a2410", "5e3c1c", "86602e", "ad8648", "cfae70", "ead2a0"],
    "glass": ["0a0806", "1a130c", "2c2014"],
}


class Canvas:
    """RGBA pixels plus a per-pixel 'part' id (for outlines between parts)."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.c = np.zeros((h, w, 4), np.uint8)
        self.part = np.zeros((h, w), np.int32)
        self.ys, self.xs = np.mgrid[0:h, 0:w]

    def put(self, mask, ramp, tone, part=0, alpha=255):
        """Fill `mask` with ramp[tone] (tone may be an array, clipped)."""
        cols = np.array([hx(c) for c in R[ramp]] if isinstance(ramp, str) else [hx(c) for c in ramp])
        t = np.clip(np.asarray(tone), 0, len(cols) - 1)
        if np.ndim(t) == 0:
            t = np.full((self.h, self.w), t)
        t = np.round(t).astype(int)
        m = mask.astype(bool)
        self.c[m, :3] = cols[t[m]]
        self.c[m, 3] = alpha
        if part:
            self.part[m] = part

    def px(self, x, y, col, a=255):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.c[y, x, :3] = hx(col) if isinstance(col, str) else col
            self.c[y, x, 3] = a

    def tone_px(self, x, y, ramp, t):
        r = R[ramp]
        self.px(x, y, r[int(np.clip(round(t), 0, len(r) - 1))])

    def shade(self, mask, d, ramp):
        """Shift the tone of already-painted pixels by `d` steps along `ramp`."""
        cols = np.array([hx(c) for c in R[ramp]])
        m = mask & (self.c[..., 3] > 0)
        if not m.any():
            return
        cur = self.c[m, :3].astype(int)
        dist = ((cur[:, None, :] - cols[None, :, :]) ** 2).sum(-1)
        idx = np.clip(dist.argmin(1) + d, 0, len(cols) - 1)
        self.c[m, :3] = cols[idx]

    def outline(self, col=INK, inner=True):
        a = self.c[..., 3] > 0
        p = self.part
        out = np.zeros_like(a)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            na = np.roll(np.roll(a, dy, 0), dx, 1)
            out |= (~a) & na
        rgb = hx(col)
        self.c[out, :3] = rgb
        self.c[out, 3] = 255
        if inner:
            # where a part sits over a different part, darken a 1-px seam (below/right side only)
            for dy, dx in ((-1, 0), (0, -1)):
                np_ = np.roll(np.roll(p, dy, 0), dx, 1)
                seam = a & (p > 0) & (np_ > 0) & (np_ != p) & (p < np_)
                self.c[seam, :3] = (self.c[seam, :3] * 0.45).astype(np.uint8)

    def image(self):
        return Image.fromarray(self.c, "RGBA")


def dither(c, v):
    """A value 0..1 (array) -> True where the ordered dither says 'on'."""
    th = BAYER[c.ys % 4, c.xs % 4]
    return v > th


def hsh(x, y, s=0):
    n = (x * 374761393 + y * 668265263 + s * 2246822519) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return (n & 0xFFFF) / 65535.0


# ---------------------------------------------------------------- stone work

def stone_block(c, x0, y0, x1, y1, base, seed, ramp="stone", part=1, round_tl=True):
    """One dressed stone block, x0..x1, y0..y1 inclusive: bevelled (light top/left),
    a few pits, sometimes a chipped corner or a crack."""
    m = (c.xs >= x0) & (c.xs <= x1) & (c.ys >= y0) & (c.ys <= y1)
    if round_tl:   # knock the corners off
        for (cx, cy) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
            m &= ~((c.xs == cx) & (c.ys == cy))
    t = np.full((c.h, c.w), float(base))
    t[(c.ys == y0) | (c.xs == x0)] += 1.0
    t[(c.ys == y0 + 1) & (c.xs > x0)] += 0.5
    t[(c.ys == y1) | (c.xs == x1)] -= 1.0
    # mottling
    nz = np.vectorize(lambda x, y: hsh(int(x) // 2, int(y) // 2, seed))(c.xs, c.ys)
    t += (nz - 0.5) * 0.9
    c.put(m, ramp, t, part)
    # pits
    rng = np.random.default_rng(seed)
    area = (x1 - x0) * (y1 - y0)
    for _ in range(max(1, area // 40)):
        px_, py_ = rng.integers(x0 + 1, max(x0 + 2, x1)), rng.integers(y0 + 1, max(y0 + 2, y1))
        c.tone_px(int(px_), int(py_), ramp, base - 2)
        if px_ + 1 <= x1:
            c.tone_px(int(px_) + 1, int(py_), ramp, base + 1)
    # a chipped corner
    if rng.random() < 0.3:
        cx, cy = (x1, y0) if rng.random() < 0.5 else (x0, y1)
        for k in range(2):
            c.px(cx, cy + (k if cy == y0 else -k), R["mortar"][1])
    # a hairline crack
    if rng.random() < 0.25 and x1 - x0 > 8:
        x = float(rng.integers(x0 + 2, x1 - 2))
        y = y0 + 1
        while y < y1:
            c.tone_px(int(round(x)), y, ramp, base - 2)
            x += rng.uniform(-0.8, 0.8)
            y += 1
    return m


def moss(c, mask, seed, amount=0.25, from_bottom=None):
    rng = np.random.default_rng(seed)
    ys, xs = np.nonzero(mask & (c.c[..., 3] > 0))
    for y, x in zip(ys, xs):
        k = amount
        if from_bottom is not None:
            k *= np.clip((y - from_bottom[0]) / max(1, from_bottom[1] - from_bottom[0]), 0, 1)
        if rng.random() < k * hsh(x // 3, y // 3, seed) * 2:
            c.px(x, y, R["moss"][int(rng.integers(0, 4))])


def wall(w=240, h=112, seed=11):
    """A dungeon wall of dressed stone, fading into the dark at the sides and top."""
    c = Canvas(w, h)
    c.put(np.ones((h, w), bool), "mortar", 1)
    rng = np.random.default_rng(seed)
    y = 0
    row = 0
    heights = [9, 11, 10, 12, 9, 11, 10, 12, 10, 11, 9, 12]
    while y < h:
        bh = heights[row % len(heights)]
        x = -int(rng.integers(0, 14))
        while x < w:
            bw = int(rng.integers(14, 30))
            stone_block(c, max(x, 0), y, min(x + bw - 2, w - 1), min(y + bh - 2, h - 1),
                        3 + rng.integers(-1, 2) * 0.5, seed * 100 + row * 31 + x)
            x += bw
        y += bh
        row += 1
    moss(c, c.ys > h - 30, seed, 0.18, from_bottom=(h - 30, h))
    # damp streaks running down from a few joints
    for _ in range(6):
        x = int(rng.integers(10, w - 10))
        y0 = int(rng.integers(0, h // 2))
        for y in range(y0, min(h, y0 + int(rng.integers(10, 40)))):
            c.shade((c.xs == x) & (c.ys == y), -1, "stone")
    # fade: dithered alpha falling off to the sides and the top
    fx = np.minimum(c.xs, w - 1 - c.xs) / 46.0
    fy = c.ys / 30.0
    k = np.clip(np.minimum(fx, 1.0) * np.minimum(fy + 0.15, 1.0), 0, 1)
    c.c[..., 3] = np.where(dither(c, k ** 1.3), c.c[..., 3], 0)
    # and darken toward the edges as well, so the fade reads as falling light
    dark = np.clip(1.0 - k, 0, 1)
    c.c[..., :3] = (c.c[..., :3] * (1.0 - 0.55 * dark[..., None])).astype(np.uint8)
    return c.image()


# ---------------------------------------------------------------- gates

def arch_masks(c, cx, spring, r_in, r_out, x_in0, x_in1, x_out0, x_out1, bottom):
    xs, ys = c.xs, c.ys
    d = np.hypot(xs - cx + 0.5, ys - spring + 0.5)
    opening = ((ys >= spring) & (xs >= x_in0) & (xs <= x_in1) & (ys <= bottom)) | ((ys < spring) & (d < r_in))
    outer = ((ys >= spring) & (xs >= x_out0) & (xs <= x_out1) & (ys <= bottom)) | ((ys < spring) & (d < r_out))
    return opening, outer & ~opening, d


def stone_frame(c, cx, spring, r_in, r_out, x_in0, x_in1, x_out0, x_out1, bottom, seed, ramp="stone", key_ramp=None, base=3.5):
    """An arched stone doorway: jamb blocks either side, voussoirs round the top,
    a keystone, a threshold slab."""
    opening, frame, d = arch_masks(c, cx, spring, r_in, r_out, x_in0, x_in1, x_out0, x_out1, bottom)
    c.put(frame, "mortar", 1)
    rng = np.random.default_rng(seed)
    # jambs
    for side, (a, b) in enumerate(((x_out0, x_in0 - 1), (x_in1 + 1, x_out1))):
        y = spring - 1
        k = 0
        while y < bottom - 3:
            bh = (8, 11, 9, 12)[(k + side) % 4]
            y1 = min(y + bh - 2, bottom - 4)
            # alternate long and short blocks bonding into the wall
            stone_block(c, a, y, b, y1, base + rng.uniform(-0.4, 0.4), seed + side * 50 + k, ramp)
            y += bh
            k += 1
    # voussoirs
    n = 9
    ang = np.degrees(np.arctan2(c.ys - spring + 0.5, c.xs - cx + 0.5))   # -180..0 over the top
    ring = (d >= r_in) & (d < r_out) & (c.ys < spring)
    for i in range(n):
        a0 = -180 + i * 180 / n
        a1 = a0 + 180 / n
        seg = ring & (ang >= a0 + 1.2) & (ang < a1 - 1.2)
        if i == n // 2:
            continue
        tb = base + rng.uniform(-0.3, 0.5)
        t = np.full((c.h, c.w), tb)
        t[d >= r_out - 1.5] += 1     # outer edge catches light
        t[d < r_in + 1.2] -= 1       # soffit in shade
        t += (np.vectorize(lambda x, y: hsh(x // 2, y // 2, seed + i))(c.xs, c.ys) - 0.5) * 0.8
        c.put(seg, ramp, t, 2)
    # keystone: taller, standing proud
    kw = int(r_out * 0.32)
    ks = (np.abs(c.xs - cx + 0.5) <= kw / 2 + (spring - r_in - c.ys) * 0.12) & (c.ys >= spring - r_out - 3) & (d >= r_in) & (c.ys < spring - r_in + 4)
    t = np.full((c.h, c.w), base + 1.0)
    t[c.xs < cx - 1] += 0.6
    t[c.ys <= spring - r_out - 2] += 1
    t[c.xs > cx + kw / 2 - 2] -= 1
    c.put(ks, key_ramp or ramp, t, 3)
    # threshold
    th = (c.ys > bottom - 4) & (c.ys <= bottom) & (c.xs >= x_out0 - 2) & (c.xs <= x_out1 + 2)
    t = np.full((c.h, c.w), base + 0.5)
    t[c.ys == bottom - 3] += 1.5
    t[c.ys == bottom] -= 1.5
    c.put(th, ramp, t, 4)
    moss(c, frame & (c.ys > bottom - 20), seed, 0.22, from_bottom=(bottom - 20, bottom))
    return opening


def rivet(c, x, y, metal):
    c.tone_px(x, y, metal, 6)
    c.tone_px(x + 1, y + 1, metal, 1)
    c.tone_px(x + 1, y, metal, 3)
    c.tone_px(x, y + 1, metal, 3)


def metal_band(c, mask, metal, part=6, horizontal=True):
    t = np.full((c.h, c.w), 4.0)
    ys, xs = np.nonzero(mask)
    if len(ys) == 0:
        return
    if horizontal:
        top, bot = ys.min(), ys.max()
        t[c.ys == top] = 6
        t[c.ys == top + 1] = 5
        t[c.ys == bot] = 2
    else:
        lft, rgt = xs.min(), xs.max()
        t[c.xs == lft] = 6
        t[c.xs == rgt] = 2
    # a soft gleam drifting across
    t += np.where((c.xs + c.ys) % 17 == 0, 1, 0)
    c.put(mask, metal, t, part)


def plank_door(c, opening, x0, x1, top, bottom, seed, wood="wood", plank=5, tint=0.0):
    """Vertical planks filling `opening` with grain, gaps and a shadowed top."""
    rng = np.random.default_rng(seed)
    t = np.zeros((c.h, c.w))
    for i, px0 in enumerate(range(x0, x1 + 1, plank)):
        pm = (c.xs >= px0) & (c.xs < px0 + plank)
        base = 3.6 + rng.uniform(-0.6, 0.6) + tint
        t[pm] = base
        t[pm & (c.xs == px0)] = base + 1.2           # lit edge
        t[pm & (c.xs == px0 + plank - 1)] = base - 1.4   # shadowed edge
        # grain: streaks that wander down the plank
        for g in range(3):
            gx = px0 + 1 + rng.integers(0, plank - 2) + 0.0
            for y in range(top, bottom + 1):
                gx += rng.uniform(-0.25, 0.25)
                gx = min(max(gx, px0 + 1), px0 + plank - 2)
                if rng.random() < 0.8:
                    t[y, int(round(gx))] -= 0.9
        # a knot
        if rng.random() < 0.6:
            ky = int(rng.integers(top + 10, bottom - 6))
            kx = px0 + plank // 2
            for dy, dx, d in ((0, 0, -2.2), (-1, 0, -1), (1, 0, -1), (0, -1, -0.8), (0, 1, -0.6), (-2, 0, 0.6)):
                if 0 <= ky + dy < c.h:
                    t[ky + dy, kx + dx] += d
    # the arch's shadow on the top of the door, and the floor bounce
    depth = np.clip(1.0 - (c.ys - top) / 10.0, 0, 1)
    t -= depth * 1.6
    c.put(opening, wood, t, 5)
    gaps = opening & ((c.xs - x0) % plank == plank - 1) & (c.ys > top + 1)
    c.shade(gaps & (np.vectorize(lambda x, y: hsh(x, y // 3, seed))(c.xs, c.ys) < 0.6), -2, wood)


def keyhole_plate(c, cx, cy, metal, w=11, h=15, ornate=False):
    m = (np.abs(c.xs - cx) <= w // 2) & (np.abs(c.ys - cy) <= h // 2)
    # notched corners
    m &= ~((np.abs(c.xs - cx) == w // 2) & (np.abs(c.ys - cy) == h // 2))
    if ornate:   # pointed top and bottom
        m |= (np.abs(c.xs - cx) <= (h // 2 + 3 - np.abs(c.ys - cy))) & (np.abs(c.ys - cy) <= h // 2 + 3) & (np.abs(c.xs - cx) <= 2)
    t = np.full((c.h, c.w), 4.0)
    t[(c.ys <= cy - h // 2 + 1) | (c.xs <= cx - w // 2)] = 6
    t[(c.ys >= cy + h // 2) | (c.xs >= cx + w // 2)] = 2
    t[(c.ys == cy - h // 2 + 2) & (np.abs(c.xs - cx) < w // 2 - 1)] = 5
    c.put(m, metal, t, 7)
    # keyhole: a round top and a slot, with a lit lower lip
    for (x, y) in ((cx, cy - 2), (cx - 1, cy - 2), (cx + 1, cy - 2), (cx, cy - 3), (cx, cy - 1), (cx, cy), (cx, cy + 1), (cx, cy + 2)):
        c.px(x, y, "050308")
    c.px(cx - 1, cy - 3, R[metal][2])
    c.tone_px(cx, cy + 3, metal, 6)
    c.tone_px(cx + 1, cy + 2, metal, 3)
    for (x, y) in ((cx - w // 2 + 1, cy - h // 2 + 1), (cx + w // 2 - 2, cy - h // 2 + 1),
                   (cx - w // 2 + 1, cy + h // 2 - 2), (cx + w // 2 - 2, cy + h // 2 - 2)):
        rivet(c, x, y, metal)


def ring_pull(c, cx, cy, metal, r=3):
    d = np.hypot(c.xs - cx, c.ys - cy)
    m = (d >= r - 0.9) & (d <= r + 0.6)
    t = np.where(c.ys < cy, 5.0, 2.5) + np.where(c.xs < cx, 0.8, -0.4)
    c.put(m, metal, t, 8)
    c.tone_px(cx, cy - r - 1, metal, 3)   # the staple it hangs from
    c.tone_px(cx, cy - r - 2, metal, 5)


def gate(metal, opened=False, seed=3):
    W, H = 64, 96
    c = Canvas(W, H)
    cx, spring, r_in, r_out = 32, 34, 19, 31
    x_in0, x_in1 = 13, 50
    bottom = 95
    opening = stone_frame(c, cx, spring, r_in, r_out, x_in0, x_in1, 1, 62, bottom, seed + 7, key_ramp=None)
    door_bottom = bottom - 4
    opening &= c.ys <= door_bottom
    if not opened:
        plank_door(c, opening, x_in0, x_in1, spring - r_in, door_bottom, seed)
        # an iron-coloured strap following the arch, in the gate's metal
        d = np.hypot(c.xs - cx + 0.5, c.ys - spring + 0.5)
        arch_strap = opening & (((c.ys < spring) & (d >= r_in - 2.2)) | ((c.ys >= spring) & ((c.xs <= x_in0 + 1) | (c.xs >= x_in1 - 1))))
        t = np.where(c.xs < cx, 5.0, 3.0) - np.where(c.ys > spring + 30, 1, 0)
        c.put(arch_strap, metal, t, 6)
        # two cross straps, with hinge ends curling out on the left
        for sy in (44, 76):
            band = opening & (c.ys >= sy) & (c.ys <= sy + 3)
            metal_band(c, band, metal)
            for x in range(x_in0 + 3, x_in1 - 1, 6):
                rivet(c, x, sy + 1, metal)
            # hinge pin on the jamb side
            for y in range(sy - 1, sy + 5):
                c.tone_px(x_in0 - 1, y, metal, 5 if y < sy + 2 else 3)
            # the curl at the strap's end
            for (x, y, tn) in ((x_in1 - 4, sy - 1, 5), (x_in1 - 3, sy - 2, 5), (x_in1 - 2, sy - 2, 4), (x_in1 - 4, sy + 4, 3), (x_in1 - 3, sy + 5, 2)):
                c.tone_px(x, y, metal, tn)
        keyhole_plate(c, cx + 6, 60, metal)
        ring_pull(c, cx - 6, 62, metal)
        # a stud at the arch's apex
        rivet(c, cx, spring - r_in + 3, metal)
    else:
        # the passage beyond: dark, a floor leading away, the door swung in against the left
        t = np.full((c.h, c.w), 0.0)
        depth = np.clip((c.ys - (spring - 6)) / 60.0, 0, 1)
        t += depth * 2.2
        floor = c.ys > 70
        rows = (c.ys - 70)
        t[floor] += 0.6
        c.put(opening, "stone", t, 5)
        for y in range(72, door_bottom + 1, 1):
            if (y - 70) in (3, 7, 12, 18):
                c.shade(opening & (c.ys == y), -1, "stone")
        # the door seen edge-on, swung inward
        door = opening & (c.xs >= x_in0) & (c.xs <= x_in0 + 5)
        tt = np.where(c.xs == x_in0 + 5, 1.6, 2.6) + 0.0
        c.put(door, "wood", tt, 6)
        for sy in (44, 76):
            c.put(door & (c.ys >= sy) & (c.ys <= sy + 2), metal, 3, 6)
        # light from your side spills onto the near floor
        spill = opening & (c.ys > 84)
        c.shade(spill & dither(c, np.clip((c.ys - 84) / 10.0, 0, 1) * 0.7), 1, "stone")
    c.outline()
    return c.image()


def master_gate(opened=False, seed=21, W=80, H=112):
    """The purple gate of the master chamber: an obsidian arch carved with runes
    that glow, and two leaves of dark stone bound in gold with an eye for a lock."""
    c = Canvas(W, H)
    cx = W // 2
    s = W / 80.0
    spring, r_in, r_out = int(44 * s), int(24 * s), int(38 * s)
    x_in0, x_in1 = cx - r_in, cx + r_in - 1
    bottom = H - 1
    opening = stone_frame(c, cx, spring, r_in, r_out, x_in0, x_in1, 1, W - 2, bottom, seed, ramp="obsid", key_ramp="obsid", base=2.6)
    # a violet stone set in the keystone
    gy = spring - r_out + 3
    for (dx, dy, tn) in ((0, -2, 8), (-1, -1, 7), (0, -1, 8), (1, -1, 6), (-2, 0, 6), (-1, 0, 7), (0, 0, 6), (1, 0, 5), (2, 0, 4),
                         (-1, 1, 5), (0, 1, 4), (1, 1, 3), (0, 2, 3)):
        c.px(cx + dx, gy + dy, R["violet"][tn])
    # runes on the voussoirs and jambs, glowing violet
    rng = np.random.default_rng(seed)
    d = np.hypot(c.xs - cx + 0.5, c.ys - spring + 0.5)
    for i in range(10):
        a = math.radians(-170 + i * 18 + 9)
        rr = (r_in + r_out) / 2
        x, y = int(cx + math.cos(a) * rr), int(spring + math.sin(a) * rr)
        if abs(x - cx) < 4:
            continue
        glyph = rng.integers(0, 4)
        pts = [((0, -1), (0, 0), (0, 1)), ((-1, 0), (0, 0), (1, 0), (0, 1)), ((-1, -1), (0, 0), (1, 1), (1, -1)), ((0, -1), (-1, 0), (1, 0), (0, 1))][glyph]
        for (dx, dy) in pts:
            c.px(x + dx, y + dy, R["violet"][7])
    for side in (0, 1):
        jx = 3 + int(5 * s) if side == 0 else W - 4 - int(5 * s)
        for k in range(4):
            y = spring + 6 + k * int(13 * s)
            for (dx, dy) in ((0, 0), (0, 1), (0, 2), (-1 if k % 2 else 1, 1)):
                c.px(jx + dx, y + dy, R["violet"][6 + (k % 2)])
    door_bottom = bottom - 4
    opening &= c.ys <= door_bottom
    if not opened:
        # two leaves of carved dark stone
        t = np.full((c.h, c.w), 2.2)
        t += (np.vectorize(lambda x, y: hsh(x // 2, y // 2, seed + 4))(c.xs, c.ys) - 0.5) * 0.6
        t[c.xs < cx - 6] += 0.5
        t -= np.clip(1.0 - (c.ys - (spring - r_in)) / 10.0, 0, 1) * 1.4
        c.put(opening, "violet", t + 0.6, 5)
        # carved panels on each leaf
        for side in (-1, 1):
            px0 = cx + (2 if side > 0 else -r_in + 4)
            px1 = px0 + r_in - 7
            for (py0, py1) in ((spring - 4, spring + int(22 * s)), (spring + int(30 * s), door_bottom - 6)):
                panel = opening & (c.xs >= px0) & (c.xs <= px1) & (c.ys >= py0) & (c.ys <= py1)
                c.shade(panel, -1, "violet")
                c.shade(panel & ((c.ys == py0) | (c.xs == px0)), -1, "violet")
                c.shade(panel & ((c.ys == py1) | (c.xs == px1)), 2, "violet")
        # the seam between the leaves
        c.put(opening & (np.abs(c.xs - cx + 0.5) < 1), "violet", 0, 6)
        # gold binding round the arch and down the jambs
        gold = opening & (((c.ys < spring) & (d >= r_in - 2.2)) | ((c.ys >= spring) & ((c.xs <= x_in0 + 1) | (c.xs >= x_in1 - 1))))
        c.put(gold, "gold", np.where(c.xs < cx, 5.0, 3.5), 7)
        for y in range(spring, door_bottom, 7):
            rivet(c, x_in0, y, "gold")
            rivet(c, x_in1 - 1, y, "gold")
        # the eye: a gold almond with a violet iris and a keyhole for a pupil
        ey = spring + int(14 * s)
        ex, ery = int(12 * s), int(7 * s)
        u = ((c.xs - cx + 0.5) / ex) ** 2 + ((c.ys - ey) / ery) ** 2
        almond = (np.abs(c.ys - ey) <= ery * (1 - np.abs(c.xs - cx + 0.5) / ex) ** 0.7) & (np.abs(c.xs - cx + 0.5) <= ex)
        c.put(almond, "gold", np.where(c.ys < ey, 5.5, 3.5), 8)
        inner = (np.abs(c.ys - ey) <= (ery - 2) * np.clip(1 - np.abs(c.xs - cx + 0.5) / (ex - 2), 0, 1) ** 0.7) & (np.abs(c.xs - cx + 0.5) <= ex - 2)
        c.put(inner, "violet", 1, 8)
        iris = np.hypot(c.xs - cx + 0.5, c.ys - ey) < 4.6 * s
        c.put(iris & inner, "violet", np.where(c.ys < ey, 7.5, 6.0), 9)
        for (x, y) in ((cx, ey - 2), (cx - 1, ey - 2), (cx, ey - 1), (cx - 1, ey - 1), (cx, ey), (cx - 1, ey), (cx - 1, ey + 1), (cx, ey + 1), (cx, ey + 2), (cx - 1, ey + 2)):
            c.px(x, y, "06030a")
        c.px(cx - 2, ey - 3, R["violet"][8])
        # rays carved out from the eye
        for k in range(7):
            a = math.radians(-160 + k * 23.3)
            for rr in range(int(ex + 3), int(ex + 3 + 7 * s)):
                x, y = int(round(cx - 0.5 + math.cos(a) * rr)), int(round(ey + math.sin(a) * rr * 0.8))
                if 0 <= x < W and 0 <= y < H and opening[y, x]:
                    c.px(x, y, R["violet"][6] if rr % 2 else R["violet"][5])
        # handles: two gold rings
        for side in (-1, 1):
            ring_pull(c, cx + side * int(6 * s), spring + int(36 * s), "gold", r=max(2, int(3 * s)))
    else:
        # the leaves thrown open on warm light: daylight, a meadow -- home?
        t = np.clip((c.ys - (spring - r_in)) / (door_bottom - (spring - r_in)), 0, 1)
        sky = ["fff6dc", "ffeec4", "fde3a6", "f6d08a"]
        cols = np.array([hx(x) for x in sky])
        idx = np.clip((t * 3.2 + (BAYER[c.ys % 4, c.xs % 4] - 0.5) * 0.6).round().astype(int), 0, 3)
        c.c[opening, :3] = cols[idx[opening]]
        c.c[opening, 3] = 255
        # a green hill far off, a path of light
        hill = opening & (c.ys > door_bottom - int(22 * s) + (np.abs(c.xs - cx) ** 2) * 0.02)
        c.c[hill, :3] = hx("b8d68a")
        hill2 = opening & (c.ys > door_bottom - int(14 * s) + (np.abs(c.xs - cx - 8) ** 2) * 0.015)
        c.c[hill2, :3] = hx("94c070")
        path = opening & (c.ys > door_bottom - int(14 * s)) & (np.abs(c.xs - cx + 0.5) < 1 + (c.ys - (door_bottom - 14 * s)) * 0.5)
        c.c[path, :3] = hx("f4e2b0")
        # the leaves, edge-on, against each side
        for side in (-1, 1):
            leaf = opening & ((c.xs <= x_in0 + 4) if side < 0 else (c.xs >= x_in1 - 4))
            c.put(leaf, "violet", np.where(np.abs(c.xs - cx) > r_in - 3, 2.5, 4.0), 6)
            c.put(leaf & ((c.ys - spring) % 12 == 0), "gold", 4, 6)
    c.outline()
    return c.image()


# ---------------------------------------------------------------- keys

def key(metal, gem=None, W=40, H=17):
    c = Canvas(W, H)
    cy = 8
    # the bow: a ring with three lobes (a trefoil), a hole through the middle
    bx = 8
    d = np.hypot(c.xs - bx, c.ys - cy)
    bow = d < 6.6
    for a in (math.pi, math.pi * 0.42, -math.pi * 0.42):
        lx, ly = bx + math.cos(a) * 5.2, cy + math.sin(a) * 5.2
        bow |= np.hypot(c.xs - lx, c.ys - ly) < 3.1
    hole = d < 2.6
    bow &= ~hole
    nx_ = (c.xs - bx) / 7.0
    ny_ = (c.ys - cy) / 7.0
    t = 4.0 - nx_ * 1.6 - ny_ * 2.0
    t[(d > 2.6) & (d < 3.8)] -= 1.0          # the inner bevel in shadow...
    t[(d > 2.6) & (d < 3.8) & (c.ys > cy) & (c.xs > bx - 1)] += 2.6   # ...lit on the far side
    c.put(bow, metal, t, 1)
    # collar
    col = (c.xs >= 14) & (c.xs <= 16) & (np.abs(c.ys - cy) <= 3)
    c.put(col, metal, np.where(c.xs == 14, 6.0, np.where(c.xs == 16, 2.0, 4.5)) - np.where(c.ys > cy + 1, 1.0, 0.0), 2)
    # shaft
    sh = (c.xs > 16) & (c.xs <= W - 4) & (np.abs(c.ys - cy) <= 1)
    c.put(sh, metal, np.where(c.ys < cy, 6.0, np.where(c.ys > cy, 2.0, 4.0)), 3)
    ring2 = (c.xs >= 23) & (c.xs <= 24) & (np.abs(c.ys - cy) <= 2)
    c.put(ring2, metal, np.where(c.xs == 23, 5.0, 2.5), 3)
    # the bit, hanging down with teeth cut into it
    bit = (c.xs >= W - 11) & (c.xs <= W - 4) & (c.ys > cy) & (c.ys <= cy + 7)
    for tx in (W - 9, W - 6):
        bit &= ~((c.xs == tx) & (c.ys >= cy + 5))
    bit &= ~((c.xs == W - 11) & (c.ys == cy + 7))
    c.put(bit, metal, np.where(c.xs == W - 11, 5.5, 3.5) - (c.ys - cy) * 0.2, 4)
    # the tip
    c.put((c.xs == W - 3) & (c.ys == cy), metal, 3, 3)
    if gem:
        g = np.hypot(c.xs - bx, c.ys - cy) < 2.6
        c.put(g, gem, np.where(c.ys < cy, 7.0, 5.0) - (c.xs - bx) * 0.3, 5)
        c.px(bx - 1, cy - 1, R[gem][-1])
    c.outline()
    # glints
    c.tone_px(bx - 3, cy - 4, metal, 7)
    c.tone_px(20, cy - 1, metal, 7)
    return c.image()


# ---------------------------------------------------------------- chests

def chest(opened=False, wood="wood", band="iron", lockm="gold", seed=4, glow=("fff2c2", "f6d978", "e8bc48")):
    W, H = 52, 44
    c = Canvas(W, H)
    x0, x1 = 4, 47
    body_top, bottom = 22, 41
    rng = np.random.default_rng(seed)
    body = (c.xs >= x0) & (c.xs <= x1) & (c.ys >= body_top) & (c.ys <= bottom)
    # planks laid sideways
    t = np.full((c.h, c.w), 3.6)
    for i, py in enumerate(range(body_top, bottom + 1, 5)):
        rowm = (c.ys >= py) & (c.ys < py + 5)
        t[rowm] = 3.6 + rng.uniform(-0.5, 0.5)
        t[rowm & (c.ys == py)] += 1.0
        t[rowm & (c.ys == py + 4)] -= 1.6
    t += (np.vectorize(lambda x, y: hsh(x // 3, y, seed))(c.xs, c.ys) - 0.5) * 0.9
    t[c.xs > x1 - 6] -= 0.8            # the far end turns away from the light
    c.put(body, wood, t, 1)
    # corner bands and two straps
    for (a, b) in ((x0, x0 + 2), (x1 - 2, x1), (x0 + 11, x0 + 13), (x1 - 13, x1 - 11)):
        m = body & (c.xs >= a) & (c.xs <= b)
        metal_band(c, m, band, part=2, horizontal=False)
        for y in range(body_top + 2, bottom, 5):
            c.tone_px(a + 1, y, band, 5)
    bot = body & (c.ys >= bottom - 1)
    metal_band(c, bot, band, part=2)
    if not opened:
        # the barrel lid
        ly = body_top
        lid = (c.xs >= x0) & (c.xs <= x1) & (c.ys < ly) & (c.ys >= ly - 12) & (((c.ys - (ly - 12)) * 1.0) >= 0)
        lid &= (c.ys - (ly - 13)) ** 2 * 3.2 + 0 >= 0
        rel = (c.ys - ly) / 12.0       # -1 top .. 0
        curve = np.sqrt(np.clip(1 - (rel + 1) ** 2 * 0, 0, 1))
        lid = (c.xs >= x0) & (c.xs <= x1) & (c.ys >= ly - 12) & (c.ys < ly)
        tl = 3.6 + (-(c.ys - (ly - 6)) / 6.0) * 1.8
        tl += (np.vectorize(lambda x, y: hsh(x // 4, y // 2, seed + 1))(c.xs, c.ys) - 0.5) * 0.8
        tl[c.xs > x1 - 6] -= 0.8
        for (ccx, ccy) in ((x0 + 4, ly - 8), (x1 - 4, ly - 8)):   # rounded like a barrel lid
            corner = ((c.xs < x0 + 4) if ccx < 26 else (c.xs > x1 - 4)) & (c.ys < ly - 8)
            lid &= ~(corner & (np.hypot(c.xs - ccx, c.ys - ccy) > 4.3))
        c.put(lid, wood, tl, 3)
        for k in (ly - 8, ly - 4):
            c.shade(lid & (c.ys == k), -1, wood)
        for (a, b) in ((x0, x0 + 2), (x1 - 2, x1), (x0 + 11, x0 + 13), (x1 - 13, x1 - 11)):
            m = lid & (c.xs >= a) & (c.xs <= b)
            metal_band(c, m, band, part=4, horizontal=False)
        lip = (c.xs >= x0) & (c.xs <= x1) & (c.ys >= ly - 1) & (c.ys <= ly)
        metal_band(c, lip, band, part=4)
        # the lock: a hasp from the lid onto a plate
        cxl = (x0 + x1) // 2
        plate = (np.abs(c.xs - cxl) <= 4) & (c.ys >= ly - 2) & (c.ys <= ly + 7)
        tp = np.where(c.ys <= ly - 1, 6.0, 4.0) - np.where(c.xs > cxl + 2, 1.5, 0) + np.where(c.xs < cxl - 2, 1.0, 0)
        c.put(plate, lockm, tp, 5)
        for (x, y) in ((cxl, ly + 2), (cxl, ly + 3), (cxl, ly + 4)):
            c.px(x, y, "050308")
        c.tone_px(cxl, ly + 5, lockm, 7)
    else:
        # the lid thrown back: its underside, then the light inside
        ly = body_top
        under = (c.xs >= x0) & (c.xs <= x1) & (c.ys >= ly - 18) & (c.ys < ly - 7)
        tu = np.full((c.h, c.w), 1.8) + (c.ys - (ly - 18)) * 0.12
        c.put(under, wood, tu, 3)
        for (a, b) in ((x0, x0 + 2), (x1 - 2, x1)):
            c.put(under & (c.xs >= a) & (c.xs <= b), band, 2, 3)
        rimm = (c.xs >= x0) & (c.xs <= x1) & (c.ys >= ly - 7) & (c.ys <= ly - 6)
        metal_band(c, rimm, band, part=4)
        # the open mouth, full of light
        mouth = (c.xs >= x0 + 2) & (c.xs <= x1 - 2) & (c.ys >= ly - 5) & (c.ys <= ly)
        cols = np.array([hx(x) for x in glow])
        k = np.clip((c.ys - (ly - 5)) / 5.0 + (BAYER[c.ys % 4, c.xs % 4] - 0.5) * 0.5, 0, 0.99)
        idx = (k * 3).astype(int)
        c.c[mouth, :3] = cols[idx[mouth]]
        c.c[mouth, 3] = 255
        c.part[mouth] = 6
        rim2 = (c.xs >= x0) & (c.xs <= x1) & (c.ys >= ly - 1) & (c.ys <= ly)
        c.put(rim2 & ~mouth, band, 4, 4)
        # the plate, hanging open
        cxl = (x0 + x1) // 2
        plate = (np.abs(c.xs - cxl) <= 3) & (c.ys >= ly + 1) & (c.ys <= ly + 6)
        c.put(plate, lockm, np.where(c.ys == ly + 1, 6.0, 3.5), 5)
    c.outline()
    return c.image()


# ---------------------------------------------------------------- the lantern

def lantern(lit_glass=True):
    """A brass lantern: ring and cap, four panes of glass in a brass cage, a
    fuel well below. Returns (back, front): `back` is everything with the panes
    left open for the flame; `front` is the cage bars and the glass glints that
    go over the flame."""
    W, H = 30, 46
    back, front = Canvas(W, H), Canvas(W, H)
    cx = 15
    metal = "bronze"
    # ring on top
    d = np.hypot(back.xs - cx + 0.5, back.ys - 4)
    ring = (d >= 2.2) & (d <= 3.6) & (back.ys <= 6)
    back.put(ring, metal, np.where(back.xs < cx, 6.0, 3.5), 1)
    # cap: a little roof with a chimney and vents
    cap = (np.abs(back.xs - cx + 0.5) <= 4 + (back.ys - 7) * 1.4) & (back.ys >= 7) & (back.ys <= 13)
    t = 4.5 - (back.xs - cx) * 0.22 + np.where(back.ys == 13, -1.5, 0)
    back.put(cap, metal, t, 2)
    for vx in (cx - 4, cx - 1, cx + 2):
        back.px(vx, 10, R[metal][1])
        back.px(vx, 11, R[metal][1])
    brim = (np.abs(back.xs - cx + 0.5) <= 13) & (back.ys >= 13) & (back.ys <= 14)
    back.put(brim, metal, np.where(back.ys == 13, 6.0, 3.0), 3)
    # the glass chamber
    g0, g1 = 15, 34
    pane = (np.abs(back.xs - cx + 0.5) <= 10) & (back.ys >= g0) & (back.ys <= g1)
    back.put(pane, "glass", np.where(back.xs < cx, 1.0, 0.0) + 0.0, 4, alpha=150 if lit_glass else 235)
    # base: fuel well
    base = (np.abs(back.xs - cx + 0.5) <= 12 - np.maximum(back.ys - 40, 0) * 1.0) & (back.ys >= 35) & (back.ys <= 44)
    t = 4.3 - (back.xs - cx) * 0.2
    t = np.where(back.ys == 35, 6.0, t)
    t = np.where(back.ys >= 43, t - 1.6, t)
    t = np.where(back.ys == 39, t - 1.0, t)
    back.put(base, metal, t, 5)
    for x in range(cx - 9, cx + 9, 4):
        rivet(back, x, 37, metal)
    # the wick holder inside, at the bottom of the glass
    back.put((np.abs(back.xs - cx + 0.5) <= 2) & (back.ys >= g1 - 2) & (back.ys <= g1), metal, 3, 6)
    back.outline()
    # front: four bars and the glints on the glass
    for bx in (cx - 11, cx - 4, cx + 3, cx + 10):
        bar = (back.xs >= bx) & (back.xs <= bx + 1) & (back.ys >= g0) & (back.ys <= g1)
        front.put(bar, metal, np.where(front.xs == bx, 5.5, 3.0) + (0.5 if bx < cx else -0.6), 1)
    for (x, y0, y1) in ((cx - 8, g0 + 2, g0 + 9), (cx - 7, g0 + 3, g0 + 5), (cx + 6, g0 + 10, g0 + 13)):
        for y in range(y0, y1):
            front.px(x, y, "fff8e8", 150)
    band = (np.abs(front.xs - cx + 0.5) <= 11) & (front.ys == (g0 + g1) // 2)
    front.put(band, metal, 4, 2)
    return back.image(), front.image()


def matchbox():
    W, H = 46, 30
    c = Canvas(W, H)
    # 3/4 view: a top face (a slanted parallelogram), the front, the right end
    top = (c.ys >= 2) & (c.ys <= 9) & (c.xs >= 6 - (c.ys - 2) * 0.6) & (c.xs <= 38 - (c.ys - 2) * 0.6)
    front = (c.ys >= 10) & (c.ys <= 25) & (c.xs >= 1) & (c.xs <= 33)
    end = (c.xs >= 34) & (c.xs <= 38 + 0 * c.ys) & (c.ys >= 10 - (c.xs - 34) * 1.6) & (c.ys <= 25 - (c.xs - 34) * 1.6)
    c.put(top, "red", 4.6 - (c.xs / 40.0), 1)
    c.put(front, "red", 3.4 - (c.ys - 10) * 0.08 - c.xs * 0.02, 2)
    c.put(end, "red", 2.2, 3)
    # the striker on the end: gritty brown
    for y in range(4, 26):
        for x in range(34, 39):
            if end[y, x] and hsh(x, y, 7) < 0.55:
                c.px(x, y, ["2a160c", "4a2a16", "5e3a20"][int(hsh(x, y, 8) * 3)])
    # a cream label on the front with a little flame
    lab = (c.xs >= 6) & (c.xs <= 28) & (c.ys >= 13) & (c.ys <= 22)
    c.put(lab, "card", 4 - (c.ys - 13) * 0.12, 4)
    c.put(lab & ((c.ys == 13) | (c.ys == 22) | (c.xs == 6) | (c.xs == 28)), "card", 2, 4)
    fl = [(17, 15, "e8bc48"), (17, 16, "e06a2a"), (16, 17, "e06a2a"), (17, 17, "f6d978"), (18, 17, "e06a2a"),
          (16, 18, "c0402a"), (17, 18, "e8bc48"), (18, 18, "c0402a"), (17, 19, "8a2a1c"),
          (16, 20, "4a2a16"), (17, 20, "4a2a16"), (18, 20, "4a2a16")]
    for (x, y, col) in fl:
        c.px(x, y, col)
    for x in range(9, 15):
        c.px(x, 18, "6a5038")
    for x in range(20, 26):
        c.px(x, 18, "6a5038")
    # the drawer slid out of the left end, matches lying in it
    drawer = (c.xs >= 0) & (c.xs <= 7) & (c.ys >= 3) & (c.ys <= 9) & (c.xs >= 2 - (c.ys - 3) * 0.3)
    c.put(drawer, "card", 2.4, 5)
    for k, y in enumerate((4, 6, 8)):
        for x in range(0, 6):
            c.px(x + (k % 2), y, R["pine"][4 - (x == 5)])
        c.px(0 + (k % 2), y, R["red"][5])
        c.px(1 + (k % 2), y, R["red"][3])
    c.outline()
    return c.image()


def match_stick(burnt=False):
    W, H = 4, 24
    c = Canvas(W, H)
    stick = (c.xs >= 1) & (c.xs <= 2) & (c.ys >= 3)
    c.put(stick, "pine", np.where(c.xs == 1, 4.0, 2.5) - np.where(c.ys > 20, 0.5, 0), 1)
    head = ((c.xs >= 0) & (c.xs <= 3) & (c.ys >= 1) & (c.ys <= 4)) & ~(((c.xs == 0) | (c.xs == 3)) & ((c.ys == 1) | (c.ys == 4)))
    if burnt:
        c.put(head, ["120c0c", "241818", "3a2a26"], np.where(c.xs < 2, 2, 0), 2)
        c.put(stick & (c.ys < 9), ["120c0c", "241818", "3a2a26"], np.where(c.xs == 1, 2, 1), 2)
    else:
        c.put(head, "red", np.where(c.xs < 2, 5.0, 3.0) - np.where(c.ys == 4, 1, 0), 2)
        c.px(1, 1, R["red"][6])
    return c.image()


# ---------------------------------------------------------------- the Wolf Man

SK = ["0d0912", "1c1424", "2b2236", "463c55", "685d74", "8f8594", "b4aaab", "d3cabf", "ece5d8", "fbf6ec"]
HAIR = ["0a070d", "1a121e", "2c2232", "3e3246"]
NAIL = ["060408", "151018", "2a2230"]
TRAIL = ["1a0c10", "2e1418", "44201f"]
WW, WH = 128, 156


def _noise(w, h, scale, seed):
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
        self.ys, self.xs = np.mgrid[0:WH, 0:WW].astype(float)
        self.z = np.full((WH, WW), -999.0)
        self.part = np.zeros((WH, WW), int)

    def blob(self, cx, cy, rx, ry, rz, cz, pid, taper=None):
        k = (self.ys - cy) / ry
        sx = rx * (taper(k) if taper else 1.0)
        u = ((self.xs - cx) / sx) ** 2 + k ** 2
        zz = cz + rz * np.sqrt(np.clip(1 - u, 0, 1))
        take = (u < 1) & (zz > self.z)
        self.z[take] = zz[take]
        self.part[take] = pid

    def tube(self, pts, r0, r1, cz, pid):
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


def wolf_build(tilt, reach):
    """A tall stooped figure: the head hangs forward on a long neck, shoulders
    slope away, one long arm comes up toward the light with its hand open."""
    s = Sculpt()
    hx0, hy0 = 62 + tilt * 4, 46 + tilt * 2
    # the torso: narrow, sunken, leaning in from the right
    s.blob(68, 150, 30, 52, 18, -26, 1, taper=lambda k: 1 - 0.25 * np.clip(-k, 0, 1))
    # shoulders: bony knobs, the near one (left, toward the light) higher
    s.blob(38, 104, 13, 9, 10, -12, 1)
    s.blob(98, 112, 13, 9, 10, -18, 1)
    s.tube([(44, 104), (60, 99), (80, 101), (94, 109)], 6.5, 6.5, -14, 1)
    # the neck, hanging the head forward
    s.tube([(68, 104), (66, 86), (hx0 + 2, hy0 + 26)], 8, 7, -4, 1)
    # the head: a long oval narrowing to the jaw
    s.blob(hx0, hy0, 22, 37, 20, 4, 2, taper=lambda k: 1 - 0.5 * np.clip(k - 0.15, 0, None) ** 1.2)
    # the near arm: shoulder, elbow down by the ribs, forearm up toward you
    elbow = (30 - reach * 4, 140)
    wrist = (22 - reach * 10, 110 - reach * 14)
    s.tube([(34, 108), elbow], 7, 6, 2, 3)
    s.tube([elbow, wrist], 6, 4.5, 6, 3)
    palm = (wrist[0] - 1, wrist[1] - 9)
    s.blob(palm[0], palm[1], 6.5, 8, 6, 12, 3)
    fingers = []
    for i, (dx, ln, bend) in enumerate(((-6, 24, 0.6), (-2, 30, 0.45), (2, 29, 0.3), (6, 22, 0.15))):
        base = (palm[0] + dx, palm[1] - 6)
        mid = (base[0] + dx * 0.5 + 3, base[1] - ln * 0.55)
        tip = (mid[0] + 5 + bend * 8, mid[1] - ln * 0.3 + bend * 9)    # curling over toward the light
        fingers.append(tip)
        s.tube([base, mid, tip], 2.2, 1.2, 16 + i, 3)
    thumb_base = (palm[0] + 6, palm[1] + 2)
    tip = (thumb_base[0] + 9, thumb_base[1] - 8)
    s.tube([thumb_base, tip], 2.4, 1.4, 15, 3)
    fingers.append(tip)
    return s, (hx0, hy0), fingers


def wolf_frame(tilt, reach, light, seed=5):
    """Shade the figure for one light: `light` = (lx, ly, strength, reach)."""
    s, centre, fingers = wolf_build(tilt, reach)
    z, part, xs, ys = s.z, s.part, s.xs, s.ys
    mask = part > 0
    zf = np.where(mask, z, -40.0)
    gx, gy = np.gradient(zf, axis=1), np.gradient(zf, axis=0)
    nx, ny, nz = -gx, -gy, np.full_like(gx, 1.2)
    ln = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    nx, ny, nz = nx / ln, ny / ln, nz / ln
    lx, ly, strength, falloff = light
    # light from a point (the lantern) off to the left: direction per pixel
    dx, dy, dz = lx - xs, ly - ys, np.full_like(xs, 60.0)
    dl = np.sqrt(dx ** 2 + dy ** 2 + dz ** 2)
    key = np.clip((nx * dx + ny * dy + nz * dz) / dl, 0, 1)
    dist = np.hypot(lx - xs, ly - ys)
    fall = np.clip(1.0 - (dist - 30) / falloff, 0, 1) ** 1.6
    # a faint cold rim from behind keeps the far edge from vanishing entirely
    rim = np.clip(1 - nz, 0, 1) ** 3 * np.clip(nx * 0.8 - ny * 0.5, 0, 1) * 0.22
    v = 0.04 + key * fall * strength + rim * (1 - fall)
    hx0, hy0 = centre
    def hollow(cx, cy, rx, ry, amt):
        u = ((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2
        return np.where(u < 1, (1 - u) * amt, 0)
    head = part == 2
    dark = np.zeros_like(v)
    for side in (-1, 1):
        dark += hollow(hx0 + side * 17, hy0 - 14, 6, 11, 0.3)
        dark += hollow(hx0 + side * 12, hy0 + 14, 5, 12, 0.35)
        dark += hollow(hx0 + side * 9, hy0 - 4, 6, 4, 0.2)
    v = np.where(head, v - dark * np.clip(v * 2.5, 0, 1), v)
    # collarbone and tendon ridges where the light reaches them
    for side in (-1, 1):
        cb = (np.abs(ys - (100 + np.abs(xs - 66) * 0.14)) < 1.0) & (np.abs(xs - 66) > 6) & (np.abs(xs - 66) < 32) & (part == 1)
        v = np.where(cb, v + 0.12 * fall, v)
        cbs = (np.abs(ys - (102 + np.abs(xs - 66) * 0.14)) < 1.0) & (np.abs(xs - 66) > 6) & (np.abs(xs - 66) < 32) & (part == 1)
        v = np.where(cbs, v - 0.14 * fall, v)
    for r in range(4):
        rib = (np.abs(ys - (112 + r * 6 + np.abs(xs - 66) * 0.06)) < 0.8) & (np.abs(xs - 66) > 3) & (np.abs(xs - 66) < 26 - r) & (part == 1)
        v = np.where(rib, v - 0.16 * fall, v)
    v = v + _noise(WW, WH, 1.3, seed) * 0.04
    th = BAYER[(np.arange(WH)[:, None] % 4), (np.arange(WW)[None, :] % 4)]
    cols = np.array([hx(c) for c in SK])
    t = np.clip(v, 0, 0.999) * (len(cols) - 1)
    idx = np.clip(np.floor(t + th - 0.5 + 0.5), 0, len(cols) - 1).astype(int)
    img = np.zeros((WH, WW, 3))
    img[mask] = cols[idx[mask]]
    # how much is there at all: what the light doesn't reach dissolves into the dark
    vis = np.clip((v - 0.05) / 0.12, 0, 1)
    ragged = _noise(WW, WH, 6.0, seed + 3) * 0.35
    vis *= np.clip((WH - 10 - ys) / 60.0 + ragged, 0, 1)   # and the body sinks away below, unevenly
    alpha = mask & (vis > th * 0.95)
    rng = np.random.default_rng(seed)
    # the hole where the face should be, cracks, the dried trail
    hcx, hcy = hx0 + 1, hy0 + 2
    glint = np.zeros((WH, WW), bool)
    for y in range(int(hcy - 9), int(hcy + 10)):
        for x in range(int(hcx - 8), int(hcx + 8)):
            a = math.atan2(y - hcy, x - hcx)
            rr = 6.0 + 1.5 * math.sin(a * 3 + 1) + 1.1 * math.sin(a * 7)
            d = math.hypot((x - hcx) * 1.15, (y - hcy) * 0.85)
            if d < rr:
                img[y, x] = hx(SK[0]) if d < rr - 1.5 else hx(SK[1])
            elif d < rr + 1.2 and x < hcx + 2:
                img[y, x] = cols[min(idx[y, x] + 2, 9)]     # the torn lip catches the light
    gx_, gy_ = int(hcx), int(hcy + 1)
    img[gy_, gx_] = hx("fffbe8")
    glint[gy_, gx_] = True
    for k in range(7):
        a = rng.uniform(0, math.tau)
        x, y = hcx + math.cos(a) * 7, hcy + math.sin(a) * 8
        for step in range(int(rng.integers(6, 15))):
            a += rng.uniform(-0.6, 0.6)
            x += math.cos(a); y += math.sin(a)
            xi, yi = int(round(x)), int(round(y))
            if 0 <= xi < WW and 0 <= yi < WH and part[yi, xi] == 2:
                img[yi, xi] = hx(SK[1])
    x = hcx + 1
    for y in range(int(hcy + 8), 100):
        x += rng.uniform(-0.6, 0.6)
        xi = int(round(x))
        if part[y, xi] > 0:
            img[y, xi] = hx(TRAIL[(y // 3) % 3])
    # stringy hair hanging round the face, lit only where it crosses the light
    for side in (-1, 1):
        for k in range(9):
            x = hx0 + side * (9 + k * 1.7 + rng.uniform(-1, 1))
            y = hy0 - 34 + k * 1.5 + rng.uniform(0, 3)
            ln_ = rng.integers(36, 76)
            sway = rng.uniform(0.05, 0.25) * side
            for step in range(int(ln_)):
                x += sway + math.sin(step * 0.15 + k) * 0.25
                y += 1
                xi, yi = int(round(x)), int(round(y))
                if 0 <= xi < WW and 0 <= yi < WH:
                    lit = fall[yi, xi] * strength
                    img[yi, xi] = hx(HAIR[min(3, int(lit * 4 + (k + step // 7) % 2))])
                    if lit > 0.12 or alpha[yi, xi]:
                        alpha[yi, xi] = True
    for tip in fingers:
        for d in range(4):
            xi, yi = int(round(tip[0] + d * 0.5)), int(round(tip[1] + d * 0.6))
            if 0 <= xi < WW and 0 <= yi < WH and alpha[yi, xi]:
                img[yi, xi] = hx(NAIL[min(d, 2)])
    # outline only where it's lit: a dark line against the light, nothing in the dark
    a = alpha
    edge = a & ~(np.roll(a, 1, 0) & np.roll(a, -1, 0) & np.roll(a, 1, 1) & np.roll(a, -1, 1))
    lit_edge = edge & (v > 0.3) & ~glint
    img[lit_edge] = img[lit_edge] * 0.55
    out = np.zeros((WH, WW, 4), np.uint8)
    out[..., :3] = np.clip(img, 0, 255).astype(np.uint8)
    out[..., 3] = np.where(a, 255, 0)
    g = np.zeros((WH, WW, 4), np.uint8)
    g[glint, :3] = 255
    g[glint, 3] = 255
    gi = Image.fromarray(g, "RGBA")
    im = Image.fromarray(out, "RGBA")
    if tilt:
        im = im.rotate(-tilt * 5, resample=Image.NEAREST, center=(66, 100))
        gi = gi.rotate(-tilt * 5, resample=Image.NEAREST, center=(66, 100))
    return im, gi


def wolfman_sheet():
    """Five 128 x 156 frames: 0 waiting at the edge of your light, 1 the head
    tilted and the hand lifting, 2/3 their glints alone, 4 caught full in the
    flare of a match, close."""
    lantern = (-60, 92, 1.1, 165)     # off the left edge, at hand height
    flash = (-20, 120, 1.25, 190)
    a, ag = wolf_frame(0.0, 0.0, lantern)
    b, bg = wolf_frame(1.0, 1.0, lantern)
    f, _ = wolf_frame(1.0, 1.0, flash)
    sheet = Image.new("RGBA", (WW * 5, WH), (0, 0, 0, 0))
    for i, im in enumerate((a, b, ag, bg, f)):
        sheet.paste(im, (i * WW, 0))
    return sheet


# ---------------------------------------------------------------- the atlas

def pack(items, width=256):
    """Shelf-pack named images; returns (atlas, {name: (x, y, w, h)})."""
    rects = {}
    x = y = shelf = 0
    for name, im in items:
        w, h = im.size
        if x + w > width:
            x, y, shelf = 0, y + shelf + 1, 0
        rects[name] = (x, y, w, h)
        x += w + 1
        shelf = max(shelf, h)
    atlas = Image.new("RGBA", (width, y + shelf), (0, 0, 0, 0))
    for name, im in items:
        r = rects[name]
        atlas.paste(im, (r[0], r[1]))
    return atlas, rects


def main():
    items = [("wall", wall())]
    for m in ("bronze", "silver", "gold"):
        items.append((f"gate_{m}", gate(m)))
    for m in ("bronze", "silver", "gold"):
        items.append((f"gate_{m}_open", gate(m, opened=True)))
    items += [("master", master_gate()), ("master_open", master_gate(opened=True)),
              ("master_small", master_gate(W=56, H=80)), ("master_small_open", master_gate(opened=True, W=56, H=80))]
    for m in ("bronze", "silver", "gold"):
        items.append((f"key_{m}", key(m)))
    items.append(("key_purple", key("gold", gem="violet")))
    items += [("chest", chest()), ("chest_open", chest(opened=True)),
              ("chest_purple", chest(wood="violet", band="gold", lockm="gold", seed=9)),
              ("chest_purple_open", chest(opened=True, wood="violet", band="gold", lockm="gold", seed=9,
                                          glow=("f2e4ff", "c8a0ff", "8c50cc")))]
    back, front = lantern()
    items += [("lantern", back), ("lantern_front", front), ("matchbox", matchbox()),
              ("match", match_stick()), ("match_burnt", match_stick(burnt=True))]
    atlas, rects = pack(items)
    atlas.save(OUT)
    wolfman_sheet().save(OUT_WOLF)
    lines = [
        "class_name IntroArt",
        "extends RefCounted",
        "## Where each picture sits in assets/intro_art.png. Generated by",
        "## tools/make_intro_art.py -- don't edit by hand.",
        "",
        'const TEX: Texture2D = preload("res://assets/intro_art.png")',
        'const WOLF: Texture2D = preload("res://assets/intro_wolfman.png")   # 5 x (128 x 156)',
        "const WOLF_SIZE := Vector2(128, 156)",
        "const RECTS := {",
    ]
    for name, (x, y, w, h) in rects.items():
        lines.append(f'\t"{name}": Rect2({x}, {y}, {w}, {h}),')
    lines += ["}", "", "", "static func rect(name: String) -> Rect2:", "\treturn RECTS[name]", ""]
    OUT_GD.write_text("\n".join(lines))
    print("wrote", OUT, atlas.size, OUT_WOLF, OUT_GD)


if __name__ == "__main__":
    main()
