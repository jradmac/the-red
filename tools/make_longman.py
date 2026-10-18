"""The Longman: intricate sprite sheet for Scythe.

Pixel density is fixed by the game (its 3D view renders at 360 x 240, about one
texture pixel per screen pixel), so the detail comes from craft, not size:

  - every part is a lit volume (tapered tubes, ellipsoids) shaded in an 8-tone
    hue-shifted ramp: cold purple shadows up to warm bone highlights
  - selective outlines: near-black on the shadow side, a dark skin tone on the lit side
  - anatomy: ribs with the gaps between them, sternum, neck tendons, collarbones,
    hip bones, kneecaps, shin ridges, knuckles, toes, long dark nails, veins
  - the face: a long blank skull-shaped oval, temple and cheek hollows, one hole
    with cracks running out of it and a dried trail running down to the chest
  - stringy hair, a rotted shroud at the hips, and a dead lantern on a chain from
    its wrist; all three hang toward the ground whatever pose it's in

Frames are 80 x 80; the pivot is the bottom middle (40, 79).

Seen from above (like the hero, make_hero_tilt.py): the 3D view looks down on
the labyrinth, so each pose is drawn for that camera rather than at eye level --
WARP squeezes the pose's heights the way the camera foreshortens them (standing:
legs most, the torso less, the head not at all; crawling and lunging: evenly,
so you see along its back), the face sits lower on the head so the crown shows,
and the light comes from above. The shapes and anatomy are untouched. Set
LONGMAN_FLAT=1 for the old eye-level drawing.

    python3 tools/make_longman.py assets   (writes assets/longman.png)
"""
import math
import os
import sys
from PIL import Image

FW, FH = 80, 80
XO = 8   # poses are laid out on 64 px; 8 px spare each side


def hexc(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


def ramp(*cs):
    return [hexc(c) for c in cs]


OUTLINE = hexc("120b18")
INNER = hexc("221829")
SK = ramp("2b2236", "463c55", "685d74", "8f8594", "b4aaab", "d3cabf", "ece5d8", "fbf6ec")
FAR = ramp("181220", "241c2f", "342a40", "463b52", "574c63", "685d74", "786d84", "877c92")
BK = ramp("251d30", "3d344b", "5c5268", "807688", "a49b9f", "c4bbb2", "ddd5c9", "eee8dc")
RAGR = ramp("0d0809", "171112", "211a1a", "2c2422", "382e2a", "463a33", "54463d", "5f5045")
IRONR = ramp("0e0b12", "1a1620", "24202a", "322c38", "4a4452", "625b6a", "7a7282", "8e8696")
VEIN = hexc("6b7593")
VEIN2 = hexc("7e88a6")
HAIR = hexc("2e2734")
HAIR_HI = hexc("5a5166")
HOLE = hexc("030105")
THROAT = hexc("2a0c14")
GUM = hexc("5a2230")
TOOTH = hexc("efe8da")
STAIN = hexc("3e2230")
STAIN2 = hexc("5a3440")
NAIL = hexc("231b29")
GLASS = hexc("2c3a42")
GLASS_HI = hexc("8fa6ab")
RUST = hexc("6b3a2a")

FLAT = bool(os.environ.get("LONGMAN_FLAT"))
L = (-0.72, -0.52, 0.46) if FLAT else (-0.5, -0.76, 0.42)   # (seen from above: lit from above)
_n = math.sqrt(sum(c * c for c in L))
L = tuple(c / _n for c in L)
LXY = (L[0], L[1])


def tone(v, r):
    i = int((v + 0.5) / 1.42 * len(r))
    return r[max(0, min(len(r) - 1, i))]


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def add(a, b, k=1.0):
    return (a[0] + b[0] * k, a[1] + b[1] * k)


def norm(v):
    l = math.hypot(v[0], v[1]) or 1e-6
    return (v[0] / l, v[1] / l)


def lit_side(a, b):
    """Unit vector perpendicular to a->b, pointing toward the light."""
    d = norm((b[0] - a[0], b[1] - a[1]))
    p = (-d[1], d[0])
    if p[0] * LXY[0] + p[1] * LXY[1] < 0:
        p = (-p[0], -p[1])
    return p


# --- The camera: how each pose's heights are foreshortened seen from above --------------
GROUND_Y = 78.0
WARP = None   # set per frame in main(): y -> y on screen (None = as drawn)


def warp_upright(y):
    """Standing: the legs shortened most, the torso less, the head and neck kept."""
    h = GROUND_Y - y
    hip, sho = 30.0, 53.0
    if h <= hip:
        h2 = h * 0.66
    elif h <= sho:
        h2 = hip * 0.66 + (h - hip) * 0.86
    else:
        h2 = hip * 0.66 + (sho - hip) * 0.86 + (h - sho)
    return GROUND_Y - h2


def warp_low(y):
    """On all fours, lunging, perched: squeezed evenly -- you see along its back."""
    return GROUND_Y - (GROUND_Y - y) * 0.84


def _wy(y):
    return y if WARP is None else WARP(y)


UPRIGHT_LOOK = 0.0 if FLAT else -1.7   # the face lower on the head: you see the crown


class Frame:
    def __init__(self):
        self.px = {}
        self.val = {}
        self.mat = {}

    @staticmethod
    def tube(a, b, ra, rb):
        out = {}
        r0 = max(ra, rb)
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln2 = dx * dx + dy * dy or 1e-6
        ln = math.sqrt(ln2)
        px_, py_ = -dy / ln, dx / ln
        for y in range(int(min(a[1], b[1]) - r0 - 1), int(max(a[1], b[1]) + r0 + 2)):
            for x in range(int(min(a[0], b[0]) - r0 - 1), int(max(a[0], b[0]) + r0 + 2)):
                cx, cy = x + 0.5, y + 0.5
                t = max(0.0, min(1.0, ((cx - a[0]) * dx + (cy - a[1]) * dy) / ln2))
                r = ra + (rb - ra) * t
                ex, ey = cx - (a[0] + dx * t), cy - (a[1] + dy * t)
                d = math.hypot(ex, ey)
                if d <= r + 0.15:
                    s = max(-1.0, min(1.0, (ex * px_ + ey * py_) / max(r, 0.5)))
                    nz = math.sqrt(max(0.0, 1 - s * s))
                    out[(x, y)] = px_ * s * L[0] + py_ * s * L[1] + nz * L[2]
        return out

    @staticmethod
    def blob(c, rx, ry, rot=0.0):
        out = {}
        a = math.radians(rot)
        ca, sa = math.cos(a), math.sin(a)
        r = max(rx, ry) + 1
        for y in range(int(c[1] - r), int(c[1] + r) + 1):
            for x in range(int(c[0] - r), int(c[0] + r) + 1):
                dx, dy = x + 0.5 - c[0], y + 0.5 - c[1]
                u = (dx * ca + dy * sa) / rx
                v = (-dx * sa + dy * ca) / ry
                q = u * u + v * v
                if q <= 1.0:
                    nz = math.sqrt(1 - q)
                    out[(x, y)] = (u * ca - v * sa) * L[0] + (u * sa + v * ca) * L[1] + nz * L[2]
        return out

    @staticmethod
    def rect(x0, y0, x1, y1):
        out = {}
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                fx = (x - x0) / max(x1 - x0, 1)
                out[(x, y)] = 0.6 - fx * 0.7
        return out

    def inside(self, c):
        return -XO <= c[0] < FW - XO and 0 <= c[1] < FH

    def group(self, shapes, r=SK, mat="skin", outline=True, bias=0.0):
        cells = {}
        for s in shapes:
            cells.update(s)
        if WARP is not None:
            cells = {(x, int(math.floor(_wy(y + 0.5)))): v for (x, y), v in cells.items()}
        cells = {c: v for c, v in cells.items() if self.inside(c)}
        if outline:
            for (x, y), v in cells.items():
                for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    n = (x + d[0], y + d[1])
                    if n in cells or not self.inside(n):
                        continue
                    if n in self.px and self.mat.get(n) != "line":
                        col = INNER
                    elif v + bias > 0.62:
                        col = r[2]           # selective outline on the lit edge
                    elif v + bias > 0.3:
                        col = r[1]
                    else:
                        col = OUTLINE
                    # never lighten an outline already darker
                    if n in self.px and self.mat.get(n) == "line" and self.px[n] == OUTLINE:
                        continue
                    self.px[n] = col
                    self.mat[n] = "line"
        for c, v in cells.items():
            self.px[c] = tone(v + bias, r)
            self.val[c] = v + bias
            self.mat[c] = mat
        return set(cells)

    def put(self, c, col, only=None):
        c = (int(round(c[0])), int(round(_wy(c[1]))))
        if not self.inside(c) or (only is not None and c not in only):
            return
        self.px[c] = col

    def line(self, a, b, col, only=None, every=1):
        n = int(max(abs(b[0] - a[0]), abs(b[1] - a[1]))) * 2 + 1
        seen = []
        for i in range(n + 1):
            p = lerp(a, b, i / n)
            c = (int(round(p[0])), int(round(p[1])))
            if c not in seen:
                seen.append(c)
        for k, c in enumerate(seen):
            if k % every == 0:
                self.put(c, col, only)

    def image(self):
        im = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            if 0 <= x + XO < FW:
                im.putpixel((x + XO, y), c)
        return im


# --- Dangling things: always fall toward the ground ------------------------------------------
def dangle(f, start, length, swing=0.0, col=HAIR, hi=HAIR_HI, out=(0.0, 0.0)):
    """A strand of hair: out from the scalp a little, then down, with a slight curl."""
    p0 = start
    p1 = add(p0, out, 1.4)
    p2 = (p1[0] + swing * 0.4, p1[1] + length * 0.45)
    p3 = (p2[0] + swing * 0.9 + (0.6 if swing >= 0 else -0.6), p2[1] + length * 0.55)
    f.line(p0, p1, hi)
    f.line(p1, p2, col)
    f.line(p2, p3, col)


def tatters(f, x0, x1, y, lengths, swing=0.0, down=1):
    """The rotted shroud: a band and strips hanging from it toward the ground."""
    shapes = [Frame.tube((x0, y), (x1, y + 0.4), 1.1, 1.1)]
    n = len(lengths)
    for i, ln in enumerate(lengths):
        x = x0 + (x1 - x0) * (i + 0.5) / n
        w = 0.9 if i % 2 else 0.6
        top = (x, y + 1)
        mid = (x + swing * 0.3 + (0.5 if i % 3 == 0 else -0.3), y + 1 + ln * 0.5 * down)
        tip = (x + swing * 0.8 + (0.8 if i % 2 else -0.5), y + 1 + ln * down)
        shapes += [Frame.tube(top, mid, w, w * 0.9), Frame.tube(mid, tip, w * 0.9, 0.45)]
    cells = f.group(shapes, RAGR, "rag")
    # frayed tips and a few holes
    for i, ln in enumerate(lengths):
        x = x0 + (x1 - x0) * (i + 0.5) / n
        tip = (x + swing * 0.8 + (0.8 if i % 2 else -0.5), y + 1 + ln * down)
        f.put(tip, RAGR[0], cells)
    for k in range(int(x0) + 1, int(x1), 3):
        f.put((k, y), RAGR[5], cells)
    return cells


def lantern(f, wrist, drop=4.0, swing=0.0):
    """The dead lantern, on a short chain from the wrist."""
    top = (wrist[0] + swing, wrist[1] + drop)
    # chain
    n = int(drop) + 1
    for i in range(n):
        p = lerp(wrist, top, i / max(n - 1, 1))
        f.put(p, IRONR[5] if i % 2 else IRONR[2])
    x, y = int(round(top[0])), int(round(top[1]))
    shapes = [Frame.rect(x - 2, y + 1, x + 2, y + 7), Frame.rect(x - 1, y, x + 1, y)]
    cells = f.group(shapes, IRONR, "iron")
    for gy in range(y + 2, y + 6):        # the glass: dark, cracked, cold
        for gx in range(x - 1, x + 2):
            f.put((gx, gy), GLASS)
    f.put((x - 1, y + 2), GLASS_HI)
    f.put((x + 1, y + 4), SK[1])
    f.put((x, y + 3), SK[1])
    f.put((x + 2, y + 6), RUST)
    f.put((x - 2, y + 1), RUST)
    f.put((x, y - 1), IRONR[4])           # the ring
    return cells


# --- Body parts --------------------------------------------------------------------------------
def ridge(f, a, b, cells, r=SK, t0=0.15, t1=0.85, k=0.45, col=6, dark=2, step=1):
    """A bone catching the light along a limb, with its shadow on the far side."""
    p = lit_side(a, b)
    ln = math.hypot(b[0] - a[0], b[1] - a[1])
    n = max(int(ln * (t1 - t0)), 1)
    for i in range(0, n + 1, step):
        q = lerp(a, b, t0 + (t1 - t0) * i / n)
        f.put(add(q, p, k), r[col], cells)
        f.put(add(q, p, -k - 0.6), r[dark], cells)


def arm(f, sho, elb, wri, tips, r=SK, mat="skin", vein=False):
    shapes = [Frame.blob(sho, 2.0, 1.8), Frame.tube(sho, elb, 1.36, 0.9),
              Frame.blob(elb, 1.45, 1.45), Frame.tube(elb, wri, 0.95, 0.68),
              Frame.blob(wri, 1.25, 1.1)]
    cells = f.group(shapes, r, mat)
    if mat in ("skin", "back"):
        f.put(add(elb, lit_side(sho, elb), 0.6), r[7], cells)
        f.put(add(elb, lit_side(sho, elb), -0.9), r[1], cells)
        f.put(add(sho, (-0.8, -1.0)), r[7], cells)
        ridge(f, elb, wri, cells, r, 0.2, 0.85, 0.3, 6, 2, 2)
        f.put(add(wri, (-0.5, -0.4)), r[7], cells)
        if vein:
            d = norm((wri[0] - elb[0], wri[1] - elb[1]))
            for i, w in enumerate((0, 0.6, 0, -0.5, 0)):
                q = lerp(elb, wri, 0.3 + i * 0.09)
                f.put((q[0] + d[1] * w, q[1] - d[0] * w), VEIN if i % 2 else VEIN2, cells)
    for tip in tips:
        mid = lerp(wri, tip, 0.45)
        kn = (mid[0] + (tip[1] - wri[1]) * 0.08, mid[1] - (tip[0] - wri[0]) * 0.08)
        fc = f.group([Frame.tube(wri, kn, 0.55, 0.5), Frame.blob(kn, 0.7, 0.7), Frame.tube(kn, tip, 0.5, 0.35)], r, mat)
        if mat in ("skin", "back"):
            f.put(kn, r[6], fc)
        d = norm((tip[0] - kn[0], tip[1] - kn[1]))
        f.put(tip, NAIL, fc)
        f.put(add(tip, d, 1.0), NAIL)            # long, dark nails past the fingertip
        cells |= fc
    return cells


def leg(f, hip, knee, ankle, toe, r=SK, mat="skin", vein=False):
    shapes = [Frame.tube(hip, knee, 2.0, 1.25), Frame.blob(knee, 1.7, 1.6), Frame.tube(knee, ankle, 1.1, 0.8),
              Frame.blob(ankle, 1.1, 1.0), Frame.tube(ankle, toe, 0.9, 0.5)]
    cells = f.group(shapes, r, mat)
    if mat in ("skin", "back"):
        ls = lit_side(hip, knee)
        f.put(add(knee, ls, 0.5), r[7], cells)           # kneecap
        f.put(add(knee, (0, -0.8)), r[6], cells)
        f.put(lerp(knee, ankle, 0.14), r[2], cells)      # under the kneecap
        ridge(f, knee, ankle, cells, r, 0.25, 0.85, 0.15, 5, 2, 2)   # shin bone
        ridge(f, hip, knee, cells, r, 0.2, 0.75, 0.7, 5, 2, 3)
        f.put(add(ankle, (-0.5, -0.3)), r[7], cells)
        if vein:
            for i in range(4):
                q = lerp(hip, knee, 0.35 + i * 0.1)
                f.put((q[0] + (0.6 if i % 2 else 0), q[1]), VEIN, cells)
    # toes: long, splayed, nailed
    d = norm((toe[0] - ankle[0], toe[1] - ankle[1]))
    f.put(toe, NAIL)
    f.put(add(toe, (d[1], -d[0]), 1.0), r[3] if mat != "far" else r[2])
    f.put(add(add(toe, (d[1], -d[0]), 1.0), d, 1.0), NAIL)
    return cells


def hair_behind(f, c, tilt=0.0, look=0.0, swing=0.0):
    """Thin, matted hair from the back of the crown, hanging down past both sides of the head."""
    a = math.radians(tilt)
    def at(u, v):
        return (c[0] + u * math.cos(a) - v * math.sin(a), c[1] + u * math.sin(a) + v * math.cos(a))
    for i, (u, v, ln) in enumerate(((-4.6, -3.0, 13), (-4.2, -4.6, 17), (-3.0, -5.8, 11), (3.4, -5.4, 12), (4.5, -3.4, 15), (4.8, -1.0, 9))):
        s = at(u, v - look)
        out = norm((s[0] - c[0], s[1] - c[1]))
        dangle(f, s, ln, swing + (0.5 if i % 2 else -0.5), out=(out[0] * 0.8, out[1] * 0.3))


def face_front(f, c, tilt=0.0, look=0.0, hair=True, swing=0.0, hole_r=1.8):
    """The long blank face. tilt: degrees (180 = upside down)."""
    a = math.radians(tilt)
    def at(u, v):
        return (c[0] + u * math.cos(a) - v * math.sin(a), c[1] + u * math.sin(a) + v * math.cos(a))
    if hair:
        hair_behind(f, c, tilt, look, swing)
    cells = f.group([Frame.blob(c, 4.8, 6.6, tilt), Frame.blob(at(0, 2.6), 3.7, 4.5, tilt)], SK, "face")
    # skull under the skin: brow, temples, cheekbones, the hollows under them, the chin
    for u, v, col in ((-2.6, -3.1, 7), (-1.6, -3.4, 6), (2.0, -3.2, 5),
                      (-4.0, -1.4, 3), (4.0, -1.4, 2), (-3.9, -0.4, 4), (3.9, -0.4, 2),
                      (-2.2, -1.6, 4), (2.2, -1.6, 3), (-2.2, -0.9, 5), (2.2, -0.9, 4),
                      (-3.3, 0.7, 7), (3.3, 0.7, 5), (-3.0, 2.4, 3), (3.0, 2.4, 2), (-2.6, 3.2, 4),
                      (0, 6.0, 5), (-1, 5.8, 6)):
        f.put(at(u, v - look), SK[col], cells)
    hc = at(0, 1.4 - look)
    for p in Frame.blob(hc, hole_r, hole_r * 1.2, tilt):
        f.put(p, HOLE, cells)
    f.put(at(-0.5, 1.4 - look - hole_r * 0.5), THROAT, cells)
    f.put(at(0, 1.4 - look - hole_r * 1.2 - 0.6), SK[1], cells)     # the rim, in shadow above
    f.put(at(0, 1.4 - look + hole_r * 1.2 + 0.5), SK[7], cells)     # ...and catching light below
    f.put(at(-1, 1.4 - look + hole_r * 1.2 + 0.4), SK[6], cells)
    # cracks running out of the hole
    for ang, ln in ((205, 3.2), (290, 2.4), (335, 3.0), (150, 2.2), (35, 1.8)):
        g = math.radians(ang)
        for k in range(int(ln * 2)):
            d = hole_r + 0.7 + k * 0.5
            f.put(at(math.cos(g) * d, 1.4 - look + math.sin(g) * d * 1.1), SK[2] if k < ln else SK[3], cells)
    # the dried trail down to the chin
    for k in range(5):
        f.put(at(0.3 + (0.4 if k > 2 else 0), 1.4 - look + hole_r * 1.2 + 1.2 + k), STAIN if k % 3 else STAIN2, cells)
    if hair:
        # one strand falls across the face; the rest is drawn behind the head (see hair_behind)
        s0 = at(-1.2, -6.3 - look)
        dangle(f, s0, 9, swing - 0.3, out=(0.15, 0.2))
    return cells, at


def face_side(f, c, ang=0.0, open_mouth=False, hole_r=1.3, swing=0.0):
    """Profile, facing right: the long head, the hole on its front, hair hanging from the back."""
    a = math.radians(ang)
    def at(u, v):
        return (c[0] + u * math.cos(a) - v * math.sin(a), c[1] + u * math.sin(a) + v * math.cos(a))
    cells = f.group([Frame.blob(c, 4.2, 5.4, ang), Frame.blob(at(1.8, 1.2), 3.5, 4.2, ang)], SK, "face")
    for u, v, col in ((-1.5, -3.5, 7), (0.5, -3.8, 6), (2.6, -1.2, 6), (1.2, 1.0, 2), (3.4, 3.4, 5), (-2.5, 1.5, 3)):
        f.put(at(u, v), SK[col], cells)
    h = at(4.2, 1.5)
    if open_mouth:
        for p in Frame.blob(h, 2.3, 2.9, ang):
            f.put(p, THROAT, cells)
        for p in Frame.blob(h, 1.2, 1.7, ang):
            f.put(p, HOLE)
        for dy in (-2.6, -1.3, 0.2, 1.6, 2.8):
            f.put(add(h, (1.6, dy)), TOOTH)
            f.put(add(h, (2.4, dy * 1.1)), TOOTH if abs(dy) > 1 else GUM)
    else:
        for p in Frame.blob(h, hole_r, hole_r * 1.3, ang):
            f.put(p, HOLE, cells)
        for k in (1, 2):
            f.put(at(4.2 - k, 1.5 - k * 0.9), SK[2], cells)    # cracks
            f.put(at(4.2 - k * 0.8, 1.5 + k * 1.1), SK[2], cells)
        for k in range(3):
            f.put(at(3.6, 3.2 + k), STAIN, cells)
    for i, (u, v, ln) in enumerate(((-3.6, -1.0, 12), (-2.6, -3.4, 15), (-1.0, -4.6, 9), (-3.9, 1.0, 8))):
        dangle(f, at(u, v), ln, swing + (-0.5 if i % 2 else 0.3), out=norm((at(u, v)[0] - c[0], at(u, v)[1] - c[1])))
    return cells


def back_head(f, c, swing=0.0):
    cells = f.group([Frame.blob(c, 4.7, 6.4)], BK, "back")
    f.put((c[0], c[1] + 5.0), BK[0], cells)
    f.put((c[0] - 1.8, c[1] - 3.0), BK[7], cells)
    f.put((c[0] - 2.6, c[1] - 2.0), BK[6], cells)
    # more hair from behind: a thin, matted fall down the back of the skull
    for i, u in enumerate((-3.5, -2.2, -0.8, 0.6, 2.0, 3.3)):
        s = (c[0] + u, c[1] - 5.5 + abs(u) * 0.5)
        dangle(f, s, 9 + (i * 5) % 7, swing + (0.4 if i % 2 else -0.4), out=(0, 0.2))
    return cells


def chest_front(f, c, w=6.6, h=7.4, breath=0.0):
    cells = f.group([Frame.blob((c[0], c[1] - breath * 0.5), w + breath * 0.3, h + breath * 0.4)], SK, "skin")
    # ribs: three a side, bone lit on top, the gap under each in shadow
    for i in range(3):
        y0 = c[1] - 3.4 + i * 2.9 - breath * 0.4
        for s in (-1, 1):
            for k in range(5):
                x = c[0] + s * (1.6 + k * 0.95 + i * 0.15)
                y = y0 + k * 0.38 + (k * k) * 0.06
                if k < 4:
                    f.put((x, y), SK[6 if s < 0 else 4], cells)
                f.put((x, y + 1), SK[2 if s < 0 else 1], cells)
    for k in range(-4, 3):   # sternum
        f.put((c[0], c[1] + k), SK[4] if k % 2 else SK[5], cells)
    for s in (-1, 1):        # the lower edge of the ribcage, and the hollow under it
        f.line((c[0] + s * 1.6, c[1] + 4.0), (c[0] + s * 5.0, c[1] + 5.2), SK[1], cells)
    return cells


def neck_front(f, cx, top_y, base_y, tilt=0.0):
    cells = f.group([Frame.tube((cx, base_y), (cx + tilt * 0.12, top_y), 1.8, 1.45)], SK, "skin")
    for s in (-1, 1):
        f.line((cx + tilt * 0.1 + s * 1.3, top_y + 1), (cx + s * 0.5, base_y - 0.5), SK[6] if s < 0 else SK[2], cells)
    f.put((cx + tilt * 0.05, top_y + 2.5), SK[7], cells)   # Adam's apple
    f.put((cx, base_y - 0.3), SK[0], cells)                # the notch above the sternum
    return cells


def clavicles(f, cx, y, spread=7.5):
    for s in (-1, 1):
        cells = f.group([Frame.tube((cx + s * 0.8, y), (cx + s * spread, y - 2.2), 1.0, 1.2)], SK, "skin")
        f.line((cx + s * 1.2, y - 0.6), (cx + s * (spread - 0.5), y - 2.8), SK[7 if s < 0 else 5], cells)
        f.line((cx + s * 1.2, y + 1.0), (cx + s * (spread - 1.0), y - 1.0), SK[2], None)


def belly_front(f, cx, top, bot):
    cells = f.group([Frame.blob((cx, bot + 1), 5.2, 3.0), Frame.tube((cx, top), (cx, bot), 3.4, 3.2)], SK, "skin")
    for y in range(int(top) + 1, int(bot)):
        f.put((cx - 2.4, y), SK[3], cells)
        f.put((cx + 2.4, y), SK[1], cells)
        f.put((cx, y), SK[4] if y % 2 else SK[3], cells)
    f.put((cx, top + 5), SK[0], cells)         # navel
    for s in (-1, 1):                          # hip bones
        f.put((cx + s * 3.7, bot - 0.5), SK[7] if s < 0 else SK[5], cells)
        f.put((cx + s * 3.2, bot - 1.0), SK[6] if s < 0 else SK[4], cells)
        f.line((cx + s * 3.0, bot + 0.5), (cx + s * 1.4, bot + 2.5), SK[2], cells)
    return cells


# --- Poses ----------------------------------------------------------------------------------
def upright(step=0, lift=0, sway=0.0, tilt=0.0, twitch=0, breath=0.0, swing=0.0):
    """Front view, standing, facing the camera."""
    f = Frame()
    cx = 32 + sway
    for s in (-1, 1):
        up = lift if s == step else 0
        leg(f, (cx + s * 3.2, 48), (cx + s * 4.0 + s * (1.2 if up else 0), 62 - up),
            (cx + s * 3.6, 77 - up * 0.7), (cx + s * 5.8, 78 - up * 0.7), vein=(s > 0))
    belly_front(f, cx, 38, 46)
    tatters(f, cx - 5.4, cx + 1.5, 47, [4, 8, 3, 6], swing=swing - sway * 0.5)
    chest_front(f, (cx, 31), breath=breath)
    neck_front(f, cx, 20, 26.5, tilt)
    clavicles(f, cx, 26.5 - breath * 0.3)
    wrists = {}
    for s in (-1, 1):
        sw = -step * s * 2.2
        sho = (cx + s * 8.2, 24.5 - breath * 0.4)
        elb = (cx + s * 11.5 + sw * 0.35, 45)
        wri = (cx + s * 12.0 + sw, 62)
        tw = twitch * s
        tips = [(wri[0] + s * 3.0 + tw, 73), (wri[0] + s * 1.0, 77), (wri[0] - s * 1.2, 76), (wri[0] - s * 3.0 + tw, 72)]
        arm(f, sho, elb, wri, tips, vein=(s < 0))
        wrists[s] = wri
    # the dead lantern, hanging off the outside of its left hand (our left)
    lantern(f, (wrists[-1][0] - 1.5, wrists[-1][1] + 0.5), drop=3.5, swing=-2.6 + swing * 0.6)
    face_front(f, (cx + tilt * 0.12 + tilt * 0.06, 12.5 + abs(tilt) * 0.035), tilt=tilt, swing=swing, look=UPRIGHT_LOOK)
    return f


def climb_back(phase=0):
    """From behind, flat against a wall, going up: arms overhead, knees out."""
    f = Frame()
    cx = 32
    hi, lo = (6, 12) if phase == 0 else (12, 6)
    leg(f, (cx - 3, 54), (cx - 11, 62 + (2 if phase else -2)), (cx - 7, 74 + (0 if phase else -4)), (cx - 5.5, 78 + (0 if phase else -4)), BK, "back")
    leg(f, (cx + 3, 54), (cx + 11, 62 - (2 if phase else -2)), (cx + 7, 74 - (4 if phase else 0)), (cx + 5.5, 78 - (4 if phase else 0)), BK, "back")
    cells = f.group([Frame.blob((cx, 52), 5.0, 3.2), Frame.tube((cx, 44), (cx, 51), 3.4, 3.4), Frame.blob((cx, 36), 6.8, 8.0)], BK, "back")
    for s in (-1, 1):   # shoulder blades
        f.group([Frame.blob((cx + s * 3.7, 33), 2.6, 3.4, s * 15)], BK, "back", outline=False, bias=0.18)
        f.line((cx + s * 2.0, 31), (cx + s * 4.6, 36.8), BK[1], cells)
    for i, y in enumerate(range(27, 51, 2)):   # spine
        f.put((cx, y), BK[7] if i % 2 == 0 else BK[5])
        f.put((cx, y + 1), BK[1])
        f.put((cx + 1, y), BK[2])
    for i in range(4):   # ribs through the back
        for s in (-1, 1):
            f.line((cx + s * 2, 38 + i * 2), (cx + s * 6, 39.5 + i * 2.2), BK[2 if s < 0 else 1], cells)
    tatters(f, cx - 1.5, cx + 5.4, 53, [3, 6, 4, 7], swing=1.0)
    arm(f, (cx - 6.8, 29), (cx - 14, 20 + (hi - 6)), (cx - 10, hi + 2), [(cx - 12, hi - 4), (cx - 10, hi - 5), (cx - 8, hi - 4), (cx - 13, hi - 2)], BK, "back")
    arm(f, (cx + 6.8, 29), (cx + 14, 20 + (lo - 6)), (cx + 10, lo + 2), [(cx + 12, lo - 4), (cx + 10, lo - 5), (cx + 8, lo - 4), (cx + 13, lo - 2)], BK, "back")
    lantern(f, (cx - 10, hi + 3), drop=4, swing=-0.6)
    back_head(f, (cx, 22.5))
    return f


def climb_front_up(phase=0):
    """Facing you, coming up over something: hands on the top, face between the arms."""
    f = Frame()
    cx = 32
    hi, lo = (5, 10) if phase == 0 else (10, 5)
    leg(f, (cx - 3, 56), (cx - 10, 64), (cx - 6, 75), (cx - 7.5, 78))
    leg(f, (cx + 3, 56), (cx + 10, 66), (cx + 6, 76), (cx + 7.5, 78), vein=True)
    belly_front(f, cx, 46, 53)
    tatters(f, cx - 5.4, cx + 1.5, 54, [3, 7, 3, 5], swing=0.5)
    chest_front(f, (cx, 38), 6.4, 7.2)
    clavicles(f, cx, 32.5)
    arm(f, (cx - 7.5, 31), (cx - 14, 20 + hi - 5), (cx - 9, hi + 2), [(cx - 11, hi - 3), (cx - 9, hi - 4), (cx - 7, hi - 3), (cx - 12.5, hi - 1)], vein=True)
    arm(f, (cx + 7.5, 31), (cx + 14, 20 + lo - 5), (cx + 9, lo + 2), [(cx + 11, lo - 3), (cx + 9, lo - 4), (cx + 7, lo - 3), (cx + 12.5, lo - 1)])
    lantern(f, (cx - 9.5, hi + 3), drop=5, swing=-0.4)
    face_front(f, (cx, 22), look=0.6, swing=0.3)
    return f


def climb_front_down(phase=0):
    """Head first down a wall at you, knees hooked over the top, reaching for the floor."""
    f = Frame()
    cx = 32
    a, b = (0, 3) if phase == 0 else (3, 0)
    leg(f, (cx - 3, 26), (cx - 10, 14), (cx - 7, 4), (cx - 9, 1))
    leg(f, (cx + 3, 26), (cx + 10, 15), (cx + 7, 4), (cx + 9, 1), vein=True)
    cells = f.group([Frame.blob((cx, 27), 5.0, 3.0), Frame.tube((cx, 28), (cx, 36), 3.2, 3.5)], SK, "skin")
    for y in range(29, 36):
        f.put((cx - 2.4, y), SK[3], cells); f.put((cx + 2.4, y), SK[1], cells)
    # upside down, the shroud falls back over its belly
    tatters(f, cx - 5.2, cx + 1.5, 25, [3, 6, 4, 5], swing=0.3)
    chest_front(f, (cx, 43), 6.6, 7.4)
    face_front(f, (cx, 60), tilt=180, hair=False)
    # its hair hangs from the crown of its head, down toward the floor
    for i, u in enumerate((-3.2, -1.8, -0.4, 1.0, 2.6)):
        dangle(f, (cx + u, 66.5 - abs(u) * 0.4), 6 + (i * 3) % 5, swing=(0.5 if i % 2 else -0.5), out=(0, 0.3))
    arm(f, (cx - 7.5, 51), (cx - 14, 60 - a), (cx - 13, 71 - a), [(cx - 15, 78 - a), (cx - 13, 79 - a), (cx - 11, 78 - a), (cx - 16.5, 76 - a)], vein=True)
    arm(f, (cx + 7.5, 51), (cx + 14, 60 - b), (cx + 13, 71 - b), [(cx + 15, 78 - b), (cx + 13, 79 - b), (cx + 11, 78 - b), (cx + 16.5, 76 - b)])
    lantern(f, (cx - 15.5, 72 - a), drop=1.0, swing=-1.5)
    return f


def crawl_front(phase=0):
    """On all fours straight at you: head hanging low, elbows high and wide."""
    f = Frame()
    cx = 32
    a, b = (0, 4) if phase == 0 else (4, 0)
    leg(f, (cx - 3, 36), (cx - 13, 26 - a), (cx - 16, 70 - a * 0.5), (cx - 17, 74 - a * 0.5), FAR, "far")
    leg(f, (cx + 3, 36), (cx + 13, 26 - b), (cx + 16, 70 - b * 0.5), (cx + 17, 74 - b * 0.5), FAR, "far")
    tatters(f, cx - 4, cx + 4, 35, [3, 5, 2, 4, 3], swing=0.4)
    cells = f.group([Frame.blob((cx, 38), 4.4, 3.4), Frame.tube((cx, 39), (cx, 47), 3.4, 5.0), Frame.blob((cx, 50), 7.2, 5.0)], SK, "skin")
    for i, y in enumerate(range(37, 48, 2)):
        f.put((cx, y), SK[7] if i % 2 == 0 else SK[6]); f.put((cx, y + 1), SK[2])
    for s in (-1, 1):
        f.group([Frame.blob((cx + s * 3.8, 47.5), 2.4, 2.8, s * 20)], SK, "skin", outline=False, bias=0.2)
        for i in range(3):
            f.line((cx + s * 2, 42 + i * 2), (cx + s * 5, 43 + i * 2), SK[2], cells)
    arm(f, (cx - 7.5, 50), (cx - 18, 34 + a), (cx - 22, 70 - a), [(cx - 25, 78 - a), (cx - 23, 79 - a), (cx - 21, 79 - a), (cx - 26.5, 76 - a)], vein=True)
    arm(f, (cx + 7.5, 50), (cx + 18, 34 + b), (cx + 22, 70 - b), [(cx + 25, 78 - b), (cx + 23, 79 - b), (cx + 21, 79 - b), (cx + 26.5, 76 - b)])
    lantern(f, (cx - 22, 70.5 - a), drop=1.5, swing=2.5)
    neck_front(f, cx, 55, 51)
    face_front(f, (cx, 63), tilt=8 if phase else -8, swing=0.2)
    return f


CRAWL = [
    dict(hn=[(18, 58), (10, 40), (6, 76), (8, 78)], hf=[(19, 58), (16, 39), (16, 76), (18, 78)],
         fn=[(38, 56), (46, 37), (55, 73)], ff=[(37, 56), (40, 38), (45, 75)], body=0),
    dict(hn=[(18, 57), (13, 38), (11, 76), (13, 78)], hf=[(19, 57), (12, 41), (5, 76), (7, 78)],
         fn=[(38, 55), (42, 36), (48, 75)], ff=[(37, 55), (47, 39), (57, 71)], body=-1),
    dict(hn=[(18, 58), (16, 39), (16, 76), (18, 78)], hf=[(19, 58), (10, 40), (6, 76), (8, 78)],
         fn=[(38, 56), (40, 38), (45, 75)], ff=[(37, 56), (46, 37), (55, 73)], body=0),
    dict(hn=[(18, 57), (12, 41), (5, 76), (7, 78)], hf=[(19, 57), (13, 38), (11, 76), (13, 78)],
         fn=[(38, 55), (47, 39), (57, 71)], ff=[(37, 55), (42, 36), (48, 75)], body=-1),
]


def _rot(p, ang, about=(30, 58)):
    if not ang:
        return p
    a = math.radians(ang)
    dx, dy = p[0] - about[0], p[1] - about[1]
    return (about[0] + dx * math.cos(a) - dy * math.sin(a), about[1] + dx * math.sin(a) + dy * math.cos(a))


def _tips(wri, ang):
    return [_rot((wri[0] + 3.2, wri[1] + 2.2), ang, wri), _rot((wri[0] + 4.0, wri[1] + 0.8), ang, wri),
            _rot((wri[0] + 2.2, wri[1] + 3.2), ang, wri), _rot((wri[0] + 0.8, wri[1] + 3.4), ang, wri)]


def side_body(f, R, b, hips, sho):
    """The arched back seen from the side: spine knuckles, shoulder blade, ribs down the flank."""
    cells = f.group([Frame.blob(R((hips[0], hips[1] + b)), 4.2, 3.6), Frame.tube(R((hips[0] + 2, hips[1] - 1 + b)), R((sho[0] - 5, sho[1] - 1 + b)), 3.4, 3.8),
                     Frame.blob(R((sho[0], sho[1] + b)), 5.6, 4.6)], SK, "skin")
    n = 7
    for i in range(n):
        t = i / (n - 1)
        x = hips[0] + 1 + (sho[0] - hips[0]) * t
        y = hips[1] - 4.2 + (sho[1] - hips[1]) * t - math.sin(t * math.pi) * 1.4 + b
        f.put(R((x, y)), SK[7])
        f.put(R((x + 1, y)), SK[5])
        f.put(R((x, y + 1)), SK[2])
    for i in range(4):   # ribs down the flank
        x = sho[0] - 1 - i * 1.7
        f.line(R((x, sho[1] - 1.5 + b)), R((x - 0.8, sho[1] + 3.0 + b)), SK[2], cells)
        f.line(R((x + 0.7, sho[1] - 1.5 + b)), R((x + 0.1, sho[1] + 2.5 + b)), SK[6], cells)
    f.group([Frame.blob(R((sho[0] - 0.5, sho[1] - 2.4 + b)), 2.4, 1.8)], SK, "skin", outline=False, bias=0.22)   # shoulder blade
    f.put(R((hips[0] + 1.5, hips[1] - 1 + b)), SK[7], cells)   # hip bone
    f.put(R((hips[0] + 2.2, hips[1] - 0.4 + b)), SK[5], cells)
    return cells


def crawl_side(i, ang=0.0):
    """Side view on all fours, facing right. ang tilts the whole body (up or down a face)."""
    p = CRAWL[i]
    f = Frame()
    b = p["body"]
    R = lambda q: _rot(q, ang)
    def jt(lst, k):
        return [R((x, y + (b if j == 0 else 0))) for j, (x, y) in enumerate(lst[:k])]
    hf = jt(p["hf"], 4); leg(f, hf[0], hf[1], hf[2], hf[3], FAR, "far")
    ff = jt(p["ff"], 3); arm(f, ff[0], ff[1], ff[2], _tips(ff[2], ang), FAR, "far")
    side_body(f, R, b, (17, 56), (35, 52))
    hip = R((17, 58 + b))
    tatters(f, hip[0] - 3.5, hip[0] + 2.5, hip[1] - 0.5, [3, 5, 4, 6], swing=-1.2)
    f.group([Frame.tube(R((39, 53 + b)), R((44, 60 + b)), 1.8, 1.5)], SK, "skin")
    f.line(R((40, 54 + b)), R((44, 59 + b)), SK[6])
    face_side(f, R((47, 63 + b)), ang, swing=-0.6)
    hn = jt(p["hn"], 4); leg(f, hn[0], hn[1], hn[2], hn[3], vein=True)
    fn = jt(p["fn"], 3); arm(f, fn[0], fn[1], fn[2], _tips(fn[2], ang), vein=True)
    lantern(f, add(fn[2], (-1.5, 0.8)), drop=1.2, swing=-2.0)
    return f


def perch(tilt=0.0):
    """Crouched on top of something, side view: knees up by its shoulders, head hanging over."""
    f = Frame()
    leg(f, (20, 62), (28, 50), (24, 76), (28, 78), FAR, "far")
    arm(f, (30, 50), (36, 44), (44, 76), [(46, 79), (47.5, 78), (45, 79), (43.5, 79)], FAR, "far")
    cells = f.group([Frame.blob((19, 63), 4.4, 4.0), Frame.tube((20, 60), (28, 50), 3.6, 4.0), Frame.blob((30, 50), 5.6, 4.8)], SK, "skin")
    for k in range(7):
        q = (19.5 + k * 1.5, 58.5 - k * 1.65)
        f.put(q, SK[7] if k % 2 == 0 else SK[5]); f.put((q[0] + 0.6, q[1] + 1), SK[2])
    for k in range(3):
        f.line((25 + k * 1.6, 54 - k * 1.2), (24 + k * 1.6, 58.5 - k * 1.2), SK[2], cells)
    tatters(f, 15.5, 22, 64, [4, 7, 5, 8], swing=0.5)
    f.group([Frame.tube((34, 51), (39, 57), 1.8, 1.5)], SK, "skin")
    face_side(f, (42, 61), 20 + tilt, swing=0.2)
    leg(f, (18, 64), (27, 52), (22, 77), (26, 78), vein=True)
    arm(f, (31, 51), (38, 46), (40, 76), [(42, 79), (43.5, 78), (41, 79), (39.5, 79)], vein=True)
    lantern(f, (38.5, 76), drop=0.5, swing=-2.5)
    return f


def dropping():
    f = Frame()
    leg(f, (25, 50), (28, 64), (24, 77), (27, 78), FAR, "far")
    arm(f, (36, 44), (44, 56), (45, 70), _tips((45, 70), 60), FAR, "far")
    cells = f.group([Frame.blob((24, 49), 4.6, 4.0), Frame.tube((25, 47), (34, 40), 3.6, 4.2), Frame.blob((36, 40), 5.6, 4.6)], SK, "skin")
    for k in range(6):
        q = (25 + k * 2, 45.2 - k * 1.5)
        f.put(q, SK[7] if k % 2 == 0 else SK[5]); f.put((q[0], q[1] + 1), SK[2])
    tatters(f, 20.5, 27, 50, [5, 8, 4, 7], swing=-0.5)
    leg(f, (23, 51), (26, 65), (21, 77), (24, 78), vein=True)
    f.group([Frame.tube((39, 38), (42, 33), 1.8, 1.5)], SK, "skin")
    face_side(f, (44, 30), -10, swing=0.3)
    arm(f, (35, 43), (40, 57), (40, 71), _tips((40, 71), 60), vein=True)
    lantern(f, (38.5, 72), drop=2.5, swing=-0.5)
    return f


def lunge():
    f = Frame()
    leg(f, (14, 52), (10, 62), (6, 72), (3, 75), FAR, "far")
    arm(f, (34, 43), (44, 40), (52, 37), [(57, 33), (58.5, 36), (57, 39), (54, 31)], FAR, "far")
    cells = f.group([Frame.blob((14, 50), 4.4, 3.8), Frame.tube((16, 49), (28, 44), 3.4, 3.9), Frame.blob((33, 44), 5.6, 4.6)], SK, "skin")
    for k in range(7):
        q = (16 + k * 2.4, 46.6 - k * 0.75 - 1)
        f.put(q, SK[7] if k % 2 == 0 else SK[5]); f.put((q[0], q[1] + 1), SK[2])
    for k in range(3):
        f.line((29 + k * 1.6, 44), (28.5 + k * 1.6, 47.5), SK[2], cells)
    tatters(f, 10, 16.5, 51, [4, 6, 3, 5], swing=-2.0)
    leg(f, (13, 53), (10, 64), (6, 74), (4, 77), vein=True)
    arm(f, (35, 46), (45, 52), (54, 52), [(60, 49), (61.5, 52), (60, 55), (58, 57)], vein=True)
    lantern(f, (52, 53), drop=3.0, swing=-2.5)
    f.group([Frame.tube((37, 44), (41, 45), 1.8, 1.6)], SK, "skin")
    face_side(f, (44, 44), 0, open_mouth=True, swing=-2.0)
    return f


def grime(f):
    """Mottled, dirty skin: flecks and bruises, never on the outline or the details."""
    for (x, y), m in list(f.mat.items()):
        if m not in ("skin", "back"):
            continue
        h = (x * 73856093 ^ y * 19349663 ^ (x * y * 83492791)) & 0xFFFF
        col = f.px[(x, y)]
        r = BK if m == "back" else SK
        if col in (r[4], r[5]) and h % 19 == 0:
            f.px[(x, y)] = r[3]
        elif col in (r[5], r[6]) and h % 37 == 0:
            f.px[(x, y)] = hexc("a69788")
        elif col == r[2] and h % 29 == 0:
            f.px[(x, y)] = hexc("6c5664")


def fit(f):
    xs = [x for x, _ in f.px]; ys = [y for _, y in f.px]
    dx = 32 - (min(xs) + max(xs)) // 2
    dy = (FH - 1) - max(ys)
    f.px = {(x + dx, y + dy): c for (x, y), c in f.px.items() if 0 <= y + dy < FH}
    f.mat = {(x + dx, y + dy): m for (x, y), m in f.mat.items()}


FRAMES = [
    ("idle", lambda: upright(swing=0.3)),
    ("breathe", lambda: upright(breath=1.0, swing=-0.2)),
    ("tilt", lambda: upright(tilt=-48, twitch=1, swing=0.8)),
    ("tilt far", lambda: upright(tilt=-74, twitch=1, swing=1.4)),
    ("walk 1", lambda: upright(step=1, lift=4, sway=-1, swing=1.0)),
    ("walk 2", lambda: upright(tilt=-7, swing=0.2)),
    ("walk 3", lambda: upright(step=-1, lift=4, sway=1, swing=-1.0)),
    ("walk 4", lambda: upright(tilt=7, swing=-0.2)),
    ("drop", dropping),
    ("crawl 1", lambda: crawl_side(0)), ("crawl 2", lambda: crawl_side(1)),
    ("crawl 3", lambda: crawl_side(2)), ("crawl 4", lambda: crawl_side(3)),
    ("lunge", lunge),
    ("up, back 1", lambda: climb_back(0)), ("up, back 2", lambda: climb_back(1)),
    ("over 1", lambda: climb_front_up(0)), ("over 2", lambda: climb_front_up(1)),
    ("down 1", lambda: climb_front_down(0)), ("down 2", lambda: climb_front_down(1)),
    ("toward 1", lambda: crawl_front(0)), ("toward 2", lambda: crawl_front(1)),
    ("perch", lambda: perch()), ("perch tilt", lambda: perch(tilt=35)),
    ("side up 1", lambda: crawl_side(0, -38)), ("side up 2", lambda: crawl_side(1, -38)),
    ("side up 3", lambda: crawl_side(2, -38)), ("side up 4", lambda: crawl_side(3, -38)),
    ("side down 1", lambda: crawl_side(0, 34)), ("side down 2", lambda: crawl_side(1, 34)),
    ("side down 3", lambda: crawl_side(2, 34)), ("side down 4", lambda: crawl_side(3, 34)),
]
FIT = ("side", "perch", "lunge", "drop", "crawl")


def main(out):
    os.makedirs(out, exist_ok=True)
    sheet = Image.new("RGBA", (FW * len(FRAMES), FH), (0, 0, 0, 0))
    global WARP
    for i, (name, fn) in enumerate(FRAMES):
        WARP = None
        if not FLAT:
            if name.startswith(("idle", "breathe", "tilt", "walk")):
                WARP = warp_upright
            elif name.startswith(("crawl", "lunge", "drop", "perch", "toward", "side")):
                WARP = warp_low
        f = fn()
        WARP = None
        if name.startswith(FIT):
            fit(f)
        grime(f)
        sheet.paste(f.image(), (i * FW, 0))
    sheet.save(os.path.join(out, "longman.png"))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets"))
