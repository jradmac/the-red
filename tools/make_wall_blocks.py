"""Builds assets/wall_blocks.png: the 3D walls (scripts/terrain3d.gd) as one
material per landscape, so a wall's top, front and sides read as a single
block of stone (or turf-capped rock) with a rounded edge where they meet.

  y  0 / 8 / 16   TOPS, 8x8 quarters, laid out like walls3d.png:
                  x = (variant * 20 + quarter * 5 + kind) * 8
                  quarter 0 NW 1 NE 2 SW 3 SE; kind 0 fill, 1 open N/S,
                  2 open W/E, 3 outer corner, 4 inner corner
  y 24 / 40 / 56  FRONTS 16x16, x = (variant * 4 + ends) * 16
                  ends: +1 the wall turns a corner on the left, +2 on the right
  y 72 / 88 / 104 SIDES 16x16 (seen from the west: north on the left),
                  x = (variant * 2 + south_end) * 16
  rows: crypt, courtyard, mountain

The same stone pattern runs through all three: the coping round a crypt
wall's top is the cap on its front, the turf on a mountain wall hangs over
its edges. Everything tiles at 16 px, so neighbouring blocks join up.
Run:  python3 tools/make_wall_blocks.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
CLEAR = (0, 0, 0, 0)


def hx(s):
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


def nz(x, y, s):
    """A repeatable 0..1 value per pixel."""
    h = (x * 374761393 + y * 668265263 + s * 1442695041) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def pick(ramp, i):
    return ramp[max(0, min(len(ramp) - 1, i))]


# --- materials ---------------------------------------------------------------------
# Each one knows how to colour a pixel of the top (given how far it is from
# each open edge), of the front and of the side.

class Crypt:
    # castle stone: flagstones on top, a coping of pale stone round the edge
    S = [hx("1c1826"), hx("2a2536"), hx("3e384c"), hx("524b62"), hx("625c70"), hx("6a6478"),
         hx("736b7e"), hx("7a7390"), hx("8a829c"), hx("a49cb4"), hx("c4bcd2")]
    MORTAR = hx("2a2536")
    BAND = 3                           # coping width, px

    def surface(self, x, y, v):
        """The flagstones (tile-periodic)."""
        xs = (x + (4 if (y // 8) % 2 else 0)) % 16
        if y % 8 == 0 or xs % 8 == 0:
            return self.MORTAR if nz(x, y, 7 + v) < 0.85 else self.S[2]
        sid = (xs // 8, (y // 8) % 2, v)
        tone = 4 + int(nz(*sid) * 3)            # 4..6
        lx, ly = xs % 8, y % 8
        if lx == 1 or ly == 1:
            tone += 1                           # lit upper-left edge of the stone
        elif lx == 7 or ly == 7:
            tone -= 1
        r = nz(x, y, 30 + v)
        if r < 0.12:
            tone -= 1
        elif r > 0.94:
            tone += 1
        return self.S[tone]

    def coping(self, along, depth, side):
        """The pale band round an open edge. depth 0 = the very edge."""
        if along % 8 == 0 and depth < self.BAND:
            return self.S[6]                    # a joint between coping stones
        if depth >= self.BAND:
            return self.MORTAR                  # the line inside the coping
        if side == "N":
            return [self.S[3], self.S[9], self.S[8]][depth]
        if side == "S":
            return [self.S[10], self.S[9], self.S[8]][depth]
        if side == "W":
            return [self.S[9], self.S[9], self.S[8]][depth]
        return [self.S[5], self.S[7], self.S[8]][depth]   # E: the shaded side

    def front_row(self, x, y, v):
        """The front below the cap: two courses of blocks."""
        if y >= 15:
            return self.S[1]                    # where it meets the ground
        if y == 9:
            return self.MORTAR
        off = 4 if y < 9 else 0
        xs = (x + off) % 16
        if xs % 8 == 0:
            return self.MORTAR
        sid = (xs // 8, 0 if y < 9 else 1, v + 3)
        tone = 4 + int(nz(*sid) * 3)
        ly = (y - 4) if y < 9 else (y - 10)
        if ly == 0 or xs % 8 == 1:
            tone += 1
        elif ly == 4 or xs % 8 == 7:
            tone -= 1
        r = nz(x, y, 50 + v)
        if r < 0.1:
            tone -= 1
        elif r > 0.95:
            tone += 1
        if y >= 13:
            tone -= 1                           # darker toward the foot
        return self.S[tone]

    def face(self, x, y, v):
        if y <= 2:                              # the coping's front: the same stones as round the top
            if x % 8 == 0:
                return self.S[6]
            return [self.S[9], self.S[8], self.S[7]][y]
        if y == 3:
            return self.S[1]                    # shadow under the coping
        return self.front_row(x, y, v)

    def edge_col(self, y, left):
        """The upright edge of a front / side where the wall turns a corner."""
        if left:
            return self.S[10] if y <= 2 else (self.S[8] if y < 15 else self.S[2])
        return self.S[2] if y <= 2 else self.S[1]


class Court:
    # weathered sandstone: worn paving, moss in the joints, soft rounded edges
    S = [hx("1a1612"), hx("3a332c"), hx("4a3e32"), hx("62574a"), hx("796d61"), hx("8a7e6c"),
         hx("98897a"), hx("a19181"), hx("b8ac98"), hx("c8bca6"), hx("e0d6c0"), hx("f0e6d0")]
    MOSS = [hx("2f523b"), hx("3e7a44"), hx("4f8058")]
    BAND = 2

    def surface(self, x, y, v):
        xs = (x + (8 if (y // 8) % 2 else 0)) % 16
        r = nz(x, y, 11 + v)
        if y % 8 == 0 or xs % 8 == 0:
            if r < 0.3:
                return self.MOSS[int(nz(x, y, 12) * 3)]
            return self.S[5] if r < 0.7 else self.S[6]
        sid = (xs // 8, (y // 8) % 2, v + 9)
        tone = 6 + int(nz(*sid) * 3)           # 6..8
        lx, ly = xs % 8, y % 8
        if lx == 1 or ly == 1:
            tone += 1
        if r < 0.1:
            tone -= 2                          # pits in the stone
        elif r > 0.93:
            tone += 1
        # a crack across one slab
        if v == 1 and xs // 8 == 1 and (y // 8) % 2 == 0 and 2 <= ly <= 6 and lx == 3 + ly // 2:
            return self.S[3]
        return self.S[tone]

    def coping(self, along, depth, side):
        if depth >= self.BAND:
            return None                         # no separate coping: the paving runs to the edge
        chip = nz(along, depth, 40 + "NSWE".index(side)) < 0.08
        if side == "N":
            return self.S[2] if depth == 0 else (self.S[8] if chip else self.S[10])
        if side == "S":
            return self.S[8] if chip else (self.S[10] if depth == 0 else self.S[9])
        if side == "W":
            return self.S[10] if depth == 0 else self.S[9]
        return self.S[5] if depth == 0 else self.S[7]

    def face(self, x, y, v):
        if y == 0:
            return self.S[9] if nz(x, 0, 60 + v) > 0.12 else self.S[7]    # the worn round of the edge
        if y == 1:
            return self.S[8] if nz(x, 1, 60 + v) > 0.12 else self.S[6]
        if y >= 15:
            return self.S[2]
        joint_y = 8
        if y == joint_y:
            return self.MOSS[1] if nz(x, y, 61) < 0.3 else self.S[3]
        off = 8 if y < joint_y else 0
        xs = (x + off + 3) % 16
        if xs % 8 == 0:
            return self.MOSS[0] if (y > joint_y and nz(x, y, 62) < 0.35) else self.S[3]
        sid = (xs // 8, 0 if y < joint_y else 1, v + 21)
        tone = 6 + int(nz(*sid) * 3)
        ly = (y - 2) if y < joint_y else (y - joint_y - 1)
        if ly == 0 or xs % 8 == 1:
            tone += 1
        elif (y == joint_y - 1 or y == 14) or xs % 8 == 7:
            tone -= 1
        r = nz(x, y, 63 + v)
        if r < 0.1:
            tone -= 2
        elif r > 0.95:
            tone += 1
        if y >= 13:
            tone -= 1
        return self.S[tone]

    def edge_col(self, y, left):
        if left:
            return self.S[10] if y < 15 else self.S[3]
        return self.S[3] if y > 1 else self.S[5]


class Mountain:
    # rock under a cap of turf that spills over every edge
    G = [hx("1a3020"), hx("24402f"), hx("2f523b"), hx("3f6a4a"), hx("4f8058"), hx("62a65e"), hx("74ab69"), hx("9cd47e")]
    D = [hx("2a1c12"), hx("4a3220"), hx("765638"), hx("9a7650")]
    R = [hx("1e1a17"), hx("2e2824"), hx("3c352f"), hx("524840"), hx("685c52"), hx("85786d"), hx("a6988a"), hx("c0b4a6")]
    BAND = 2

    def surface(self, x, y, v):
        r = nz(x, y, 70 + v)
        tone = 3
        # blades: a light tip with a dark root under it
        if nz(x, y - 1, 70 + v) > 0.86:
            tone = 2
        if r > 0.86:
            tone = 4 if nz(x, y, 71) < 0.6 else 5
        elif r < 0.07:
            tone = 2
        # soft lighter patches
        if nz(x // 4, y // 4, 72 + v) > 0.75 and tone == 3:
            tone = 4
        return self.G[tone]

    def coping(self, along, depth, side):
        if depth >= self.BAND:
            return None
        if side == "N":
            return self.D[1] if depth == 0 else self.G[6]
        if side == "S":
            if depth == 0:
                return self.G[6] if nz(along, 0, 85) > 0.3 else self.G[5]
            return self.G[5] if nz(along, 1, 85) > 0.5 else self.G[4]
        if side == "W":
            return self.G[6] if depth == 0 else self.G[5]
        return self.G[2] if depth == 0 else self.G[3]

    def hang(self, x, v):
        """How far the turf hangs over a face at column x."""
        r = nz(x, 0, 80 + v)
        return 2 + int(r * 3) + (2 if nz(x // 2, 1, 84 + v) > 0.8 else 0)   # 2..4, now and then a longer tuft

    def face(self, x, y, v):
        h = self.hang(x, v)
        if y < h:
            if y == 0:
                return self.G[6]
            if y == h - 1:
                return self.G[2]                # the dark tip of the overhang
            return self.G[5] if y == 1 else self.G[4]
        if y < h + 2:
            return self.D[1] if y == h else self.D[2] if nz(x, y, 81) < 0.5 else self.D[1]   # soil under the turf
        if y >= 15:
            return self.R[1]
        # rock in leaning strata, cracked here and there
        band = (y + (x // 5)) // 3
        tone = 3 + int(nz(band, v, 82) * 3)    # 3..5
        if (y + (x // 5)) % 3 == 0:
            tone += 1                           # the lit top of each layer
        if nz(x, y, 83 + v) < 0.08:
            tone = 1                            # a crack
        if y <= h + 3:
            tone -= 1                           # shadow under the turf
        if y >= 13:
            tone -= 1
        return self.R[max(1, tone)]

    def edge_col(self, y, left):
        if left:
            return self.G[6] if y < 3 else self.R[6] if y < 15 else self.R[2]
        return self.G[2] if y < 3 else self.R[1]


MATS = [Crypt(), Court(), Mountain()]


# --- the pieces -------------------------------------------------------------------

def top_tile(mat, v, open_n, open_s, open_w, open_e, inner):
    """A whole 16x16 top for one set of open edges (inner: diagonal corners open)."""
    img = Image.new("RGBA", (16, 16), CLEAR)
    px = img.load()
    for y in range(16):
        for x in range(16):
            c = mat.surface(x, y, v)
            best = None
            for side, d, along, open_ in (("N", y, x, open_n), ("S", 15 - y, x, open_s),
                                          ("W", x, y, open_w), ("E", 15 - x, y, open_e)):
                if open_ and d < 4 and (best is None or d < best[1]):
                    best = (side, d, along)
            if best:
                cc = mat.coping(best[2], best[1], best[0])
                if cc is not None:
                    c = cc
            # inside corners: a small square of coping where the diagonal is open
            for (cx, cy) in inner:
                dx = x if cx == 0 else 15 - x
                dy = y if cy == 0 else 15 - y
                if dx < mat.BAND and dy < mat.BAND:
                    side = "N" if cy == 0 else "S"
                    cc = mat.coping(x, min(dx, dy), side)
                    if cc is not None:
                        c = cc
            px[x, y] = c
    # round the two far (north) outside corners; the near ones run into the
    # front's own corner, so they stay square
    for (ox, oy, op) in ((0, 0, open_n and open_w), (15, 0, open_n and open_e)):
        if op:
            px[ox, oy] = CLEAR
            px[ox + (1 if ox == 0 else -1), oy] = mat.coping(0, 0, "N")
            px[ox, oy + 1] = mat.coping(0, 0, "N")
    return img


def top_quarter(mat, v, q, kind):
    vside = "N" if q < 2 else "S"
    hside = "W" if q % 2 == 0 else "E"
    open_v = kind in (1, 3)
    open_h = kind in (2, 3)
    inner = []
    if kind == 4:
        inner = [(0 if hside == "W" else 1, 0 if vside == "N" else 1)]
    t = top_tile(mat, v, open_v and vside == "N", open_v and vside == "S",
                 open_h and hside == "W", open_h and hside == "E", inner)
    qx, qy = (q % 2) * 8, (q // 2) * 8
    return t.crop((qx, qy, qx + 8, qy + 8))


def front(mat, v, left_end, right_end):
    img = Image.new("RGBA", (16, 16), CLEAR)
    px = img.load()
    for y in range(16):
        for x in range(16):
            px[x, y] = mat.face(x, y, v)
        if left_end:
            px[0, y] = mat.edge_col(y, True)
        if right_end:
            px[15, y] = mat.edge_col(y, False)
    return img


def side(mat, v, south_end):
    """A side face. Seen nearly edge-on it's squeezed into a few pixels, so it
    keeps only the front's horizontal layers (a joint pattern would shimmer);
    the south end (right) turns onto the front."""
    img = Image.new("RGBA", (16, 16), CLEAR)
    px = img.load()
    col = 3 + 2 * v
    for y in range(16):
        for x in range(16):
            px[x, y] = mat.face(col, y, v)
        if south_end:
            px[15, y] = mat.edge_col(y, True)
    return img


def main():
    out = Image.new("RGBA", (320, 120), CLEAR)
    for b, mat in enumerate(MATS):
        for v in range(2):
            for q in range(4):
                for kind in range(5):
                    out.paste(top_quarter(mat, v, q, kind), ((v * 20 + q * 5 + kind) * 8, b * 8))
            for ends in range(4):
                out.paste(front(mat, v, ends & 1, ends & 2), ((v * 4 + ends) * 16, 24 + b * 16))
            for se in range(2):
                out.paste(side(mat, v, se), ((v * 2 + se) * 16, 72 + b * 16))
    out.save(ROOT / "assets" / "wall_blocks.png")
    print("wrote assets/wall_blocks.png")


if __name__ == "__main__":
    main()
