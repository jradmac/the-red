"""A tiny pixel-art renderer for the big battle sprites.

Forms are drawn as lit 3D shapes (ellipsoids, tapered limbs, plates) whose
shading is quantised onto hand-style colour ramps -- clean bands, no blur --
so a creature can be built from parts and re-posed for each animation frame.

    s = Sprite(48, 48)
    s.blob(24, 30, 12, 9, "shell")             # a lit ellipsoid
    s.limb([(10, 30), (4, 36), (2, 44)], 1.5, "leg")
    s.eye(20, 20, 2, "ff3b4d")
    img = s.image(palette)

Every part gets an outline: dark where it meets empty space, and a thin
inner line where it overlaps a part drawn before it, so parts read apart.
Light comes from the upper left (the hero's lantern); a cool rim light
from the lower right keeps dark bodies from sinking into the dark.
"""
import colorsys
import math

from PIL import Image

OUTLINE = (26, 16, 34, 255)
LIGHT = (-0.55, -0.62, 0.56)
_l = math.sqrt(sum(c * c for c in LIGHT))
LIGHT = tuple(c / _l for c in LIGHT)
RIM = (0.75, 0.55, 0.37)
_r = math.sqrt(sum(c * c for c in RIM))
RIM = tuple(c / _r for c in RIM)
BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def hexc(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def _shift(rgb, dh, ds, dv_mul, dv_add=0.0, hue_to=None, hue_k=0.0):
    r, g, b = (c / 255 for c in rgb[:3])
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if hue_to is not None:
        d = ((hue_to - h + 0.5) % 1.0) - 0.5
        h = (h + d * hue_k) % 1.0
    h = (h + dh) % 1.0
    s = max(0.0, min(1.0, s + ds))
    v = max(0.0, min(1.0, v * dv_mul + dv_add))
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (round(r * 255), round(g * 255), round(b * 255), 255)


def ramp(base, n=6):
    """Hue-shifted ramp from deep shadow to highlight; base sits at index 2."""
    c = hexc(base)
    return [
        _shift(c, 0, 0.08, 0.32, hue_to=0.74, hue_k=0.35),   # 0 deep shadow
        _shift(c, 0, 0.05, 0.55, hue_to=0.74, hue_k=0.22),   # 1 shadow
        c,                                                   # 2 base
        _shift(c, 0, -0.10, 1.0, 0.16, hue_to=0.12, hue_k=0.12),   # 3 light
        _shift(c, 0, -0.24, 1.0, 0.34, hue_to=0.12, hue_k=0.22),   # 4 highlight
        _shift(c, 0, -0.45, 1.0, 0.60, hue_to=0.12, hue_k=0.30),   # 5 gleam
    ][:n]


class Sprite:
    def __init__(self, w, h, k=1.0, grain=0.0, cast=False):
        """`k` scales every coordinate and radius (designs drawn on a 48-unit grid
        render bigger and finer at k > 1); `grain` roughens the shading bands
        like hand-placed pixels; `cast` makes each outlined part throw a small
        shadow down-right onto the parts drawn before it."""
        self.w, self.h = w, h
        self.k = k
        self.grain = grain
        self.cast = cast
        self.px = [[None] * w for _ in range(h)]     # (material, tone) or ("#", rgba)
        self.part = [[-1] * w for _ in range(h)]
        self._pid = 0
        self.rim = True

    # --- low level ---------------------------------------------------------
    def inside(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def _begin(self):
        self._pid += 1
        return self._pid, set()

    def _end(self, pid, cells, outline=True, inner=True):
        if not outline:
            return
        if self.cast:
            d = max(1, round(1.6 * self.k))
            hit = set()
            for (x, y) in cells:
                for dx, dy in ((1, 1), (d - 1, d), (d, d)):
                    nx, ny = x + dx, y + dy
                    if (nx, ny) in cells or (nx, ny) in hit or not self.inside(nx, ny):
                        continue
                    p = self.px[ny][nx]
                    if p is None or p[0] == "#" or self.part[ny][nx] == pid:
                        continue
                    hit.add((nx, ny))
                    self.px[ny][nx] = (p[0], max(0, min(p[1], 4) - 1))
        for (x, y) in list(cells):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not self.inside(nx, ny) or (nx, ny) in cells:
                    continue
                if self.px[ny][nx] is None:
                    self.px[ny][nx] = ("#", OUTLINE)
                    self.part[ny][nx] = pid
                elif inner and self.part[ny][nx] != pid and self.px[ny][nx][0] != "#":
                    m, t = self.px[ny][nx]
                    self.px[ny][nx] = (m, max(0, min(t, 1) - 1))   # a dark seam on the part beneath
                    self.part[ny][nx] = pid

    def _set(self, x, y, mat, tone, pid, cells):
        if self.inside(x, y):
            self.px[y][x] = (mat, tone)
            self.part[y][x] = pid
            cells.add((x, y))

    def _tone(self, n, x, y, bands, dither):
        i = n[0] * LIGHT[0] + n[1] * LIGHT[1] + n[2] * LIGHT[2]
        if self.grain:
            hsh = ((x * 73856093) ^ (y * 19349663)) % 1000 / 1000.0
            i += (hsh - 0.5) * self.grain
        if dither:
            i += (BAYER4[y % 4][x % 4] / 16.0 - 0.47) * dither
        for k, th in enumerate(bands):
            if i < th:
                return k
        return len(bands)

    def _rim(self, n):
        return self.rim and (n[0] * RIM[0] + n[1] * RIM[1] + n[2] * RIM[2]) > 0.80

    # --- forms ---------------------------------------------------------------
    def blob(self, cx, cy, rx, ry, mat, bands=(-0.25, 0.12, 0.48, 0.80, 0.95), dither=0.0,
             outline=True, inner=True, clip=None, flat=1.0):
        """A lit ellipsoid. `flat` < 1 flattens it (a plate)."""
        k = self.k
        cx, cy, rx, ry = cx * k, cy * k, rx * k, ry * k
        if clip and k != 1.0:
            c0 = clip
            clip = lambda x, y: c0(x / k, y / k)
        pid, cells = self._begin()
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                d = nx * nx + ny * ny
                if d > 1.0 or (clip and not clip(x, y)):
                    continue
                nz = math.sqrt(max(0.0, 1.0 - d)) * flat
                ln = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
                n = (nx / ln, ny / ln, nz / ln)
                t = self._tone(n, x, y, bands, dither)
                if self._rim(n) and t < 1:
                    t = -1   # rim light
                self._set(x, y, mat, t, pid, cells)
        self._end(pid, cells, outline, inner)
        return cells

    def limb(self, pts, r, mat, r_end=None, bands=(-0.2, 0.2, 0.62, 0.9), outline=True, inner=True):
        """A tapered tube through `pts` (radius r -> r_end)."""
        k = self.k
        pts = [(x * k, y * k) for x, y in pts]
        r *= k
        pid, cells = self._begin()
        r_end = r if r_end is None else r_end * k
        total = sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1)) or 1.0
        run = 0.0
        best = {}
        for i in range(len(pts) - 1):
            (x0, y0), (x1, y1) = pts[i], pts[i + 1]
            seg = math.dist(pts[i], pts[i + 1]) or 1e-6
            ux, uy = (x1 - x0) / seg, (y1 - y0) / seg
            rr = max(r, r_end) + 1
            for y in range(int(min(y0, y1) - rr), int(max(y0, y1) + rr) + 1):
                for x in range(int(min(x0, x1) - rr), int(max(x0, x1) + rr) + 1):
                    px, py = x + 0.5 - x0, y + 0.5 - y0
                    t = max(0.0, min(seg, px * ux + py * uy))
                    dx, dy = px - ux * t, py - uy * t
                    dist = math.hypot(dx, dy)
                    rad = r + (r_end - r) * (run + t) / total
                    if dist <= rad and (best.get((x, y), 9e9) > dist / max(rad, 0.01)):
                        best[(x, y)] = dist / max(rad, 0.01)
                        k = dist / max(rad, 0.01)
                        side = (dx * -uy + dy * ux)
                        sx, sy = -uy * (1 if side >= 0 else -1), ux * (1 if side >= 0 else -1)
                        nz = math.sqrt(max(0.0, 1 - k * k))
                        n = (sx * k, sy * k, nz)
                        tone = self._tone(n, x, y, bands, 0)
                        if self._rim(n) and tone < 1:
                            tone = -1
                        self._set(x, y, mat, tone, pid, cells)
            run += seg
        self._end(pid, cells, outline, inner)
        return cells

    def poly(self, pts, mat, tone=2, grad=None, outline=True, inner=True):
        """A flat polygon; `grad` = (tone_top, tone_bottom) shades it top to bottom."""
        pts = [(x * self.k, y * self.k) for x, y in pts]
        pid, cells = self._begin()
        ys = [p[1] for p in pts]
        y0, y1 = int(min(ys)), int(max(ys))
        for y in range(y0, y1 + 1):
            yc = y + 0.5
            xs = []
            for i in range(len(pts)):
                (ax, ay), (bx, by) = pts[i], pts[(i + 1) % len(pts)]
                if (ay <= yc < by) or (by <= yc < ay):
                    xs.append(ax + (yc - ay) * (bx - ax) / (by - ay))
            xs.sort()
            for j in range(0, len(xs) - 1, 2):
                for x in range(int(math.ceil(xs[j] - 0.5)), int(math.floor(xs[j + 1] - 0.5)) + 1):
                    t = tone
                    if grad:
                        k = (y - y0) / max(1, y1 - y0)
                        t = round(grad[0] + (grad[1] - grad[0]) * k)
                    self._set(x, y, mat, t, pid, cells)
        self._end(pid, cells, outline, inner)
        return cells

    # --- details (no outline) --------------------------------------------------
    def dot(self, x, y, mat, tone=None):
        """One design-grid cell: at k > 1 it covers the pixels of that cell."""
        k = self.k
        if k == 1.0:
            return self.pdot(x, y, mat, tone)
        x0, y0 = int(math.floor(int(x) * k + 0.01)), int(math.floor(int(y) * k + 0.01))
        x1, y1 = int(math.ceil((int(x) + 1) * k - 0.01)), int(math.ceil((int(y) + 1) * k - 0.01))
        for yy in range(y0, max(y1, y0 + 1)):
            for xx in range(x0, max(x1, x0 + 1)):
                self.pdot(xx, yy, mat, tone)

    def pdot(self, x, y, mat, tone=None):
        """One pixel (pixel coordinates)."""
        if self.inside(int(x), int(y)):
            if tone is None:
                self.px[int(y)][int(x)] = ("#", hexc(mat) if isinstance(mat, str) else mat)
            else:
                self.px[int(y)][int(x)] = (mat, tone)

    def line(self, pts, mat, tone=None, only_on=True):
        """1px line through pts; with only_on, only over existing pixels."""
        pts = [(x * self.k, y * self.k) for x, y in pts]
        self.pline(pts, mat, tone, only_on)

    def pline(self, pts, mat, tone=None, only_on=True):
        """line() in pixel coordinates."""
        for i in range(len(pts) - 1):
            (x0, y0), (x1, y1) = pts[i], pts[i + 1]
            n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
            for k in range(n + 1):
                x = round(x0 + (x1 - x0) * k / max(n, 1))
                y = round(y0 + (y1 - y0) * k / max(n, 1))
                if self.inside(x, y) and (not only_on or self.px[y][x] is not None):
                    self.pdot(x, y, mat, tone)

    def shade(self, cells_or_fn, delta):
        """Darken (delta<0) or lighten the tone of existing pixels."""
        for y in range(self.h):
            for x in range(self.w):
                p = self.px[y][x]
                if p is None or p[0] == "#":
                    continue
                hit = cells_or_fn(x / self.k, y / self.k) if callable(cells_or_fn) else (x, y) in cells_or_fn
                if hit:
                    self.px[y][x] = (p[0], max(-1, min(5, p[1] + delta)))

    def eye(self, cx, cy, r, color, glint=True):
        """A glossy eye: dark socket ring, glowing iris, white glint."""
        col = hexc(color)
        dark = _shift(col, 0, 0.1, 0.35)
        cx, cy, r = cx * self.k, cy * self.k, r * self.k
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                if d <= r + 0.6:
                    self.pdot(x, y, OUTLINE)
                if d <= r - 0.15:
                    k = d / max(r, 0.5)
                    c = _shift(col, 0, -0.15, 1.0, 0.25) if k < 0.45 else (col if k < 0.8 else dark)
                    self.pdot(x, y, c)
        if glint:
            self.pdot(int(cx - r * 0.45), int(cy - r * 0.45), (255, 255, 255, 255))

    # --- surface passes (pixel space, after the forms) --------------------------
    @staticmethod
    def _hash(x, y, seed=0):
        return (((x + seed * 31) * 73856093) ^ ((y + seed * 17) * 19349663) ^ (seed * 83492791)) % 1000 / 1000.0

    def cells_of(self, mat, tones=None):
        out = []
        for y in range(self.h):
            for x in range(self.w):
                p = self.px[y][x]
                if p and p[0] == mat and (tones is None or p[1] in tones):
                    out.append((x, y))
        return out

    def texture(self, mat, density=0.12, delta=-1, tones=(1, 2, 3, 4), seed=1, clip=None):
        """Speckle a material: pits, pores, scales (a hashed sprinkle of tone shifts)."""
        for (x, y) in self.cells_of(mat, tones):
            if clip and not clip(x / self.k, y / self.k):
                continue
            if self._hash(x, y, seed) < density:
                m, t = self.px[y][x]
                self.px[y][x] = (m, max(0, min(5, t + delta)))

    def fuzz(self, mat, density=0.35, seed=3, tone=1, clip=None):
        """Bristles: hairs poke one pixel out of the silhouette wherever `mat` meets the dark."""
        adds = []
        for y in range(self.h):
            for x in range(self.w):
                p = self.px[y][x]
                if not p or p[0] != "#" or p[1] != OUTLINE:
                    continue
                if clip and not clip(x / self.k, y / self.k):
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ix, iy, ox, oy = x - dx, y - dy, x + dx, y + dy
                    if not (self.inside(ix, iy) and self.inside(ox, oy)):
                        continue
                    q = self.px[iy][ix]
                    if q and q[0] == mat and self.px[oy][ox] is None and self._hash(x, y, seed + dx * 3 + dy) < density:
                        adds.append((x, y, ox, oy))
                        break
        for (x, y, ox, oy) in adds:
            self.px[y][x] = (mat, tone)
            self.px[oy][ox] = ("#", OUTLINE)

    def glints(self, mat, density=0.05, seed=5, tones=(3, 4)):
        """Wet or polished: scattered single-pixel highlights on the lit side."""
        for (x, y) in self.cells_of(mat, tones):
            if self._hash(x, y, seed) < density:
                self.px[y][x] = (mat, 5)

    # --- output -----------------------------------------------------------------
    def image(self, pal):
        """pal: material -> base hex (ramps are derived) or a list of rgba."""
        ramps = {}
        for m, v in pal.items():
            ramps[m] = ramp(v) if isinstance(v, str) else v
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                p = self.px[y][x]
                if p is None:
                    continue
                if p[0] == "#":
                    img.putpixel((x, y), p[1])
                    continue
                m, t = p
                rr = ramps[m]
                if t == -1:   # rim light: a soft, slightly cool lift of the shadow tone
                    c = _shift(rr[1], 0, -0.08, 1.0, 0.13, hue_to=0.60, hue_k=0.12)
                else:
                    c = rr[max(0, min(len(rr) - 1, t))]
                img.putpixel((x, y), c)
        return img
