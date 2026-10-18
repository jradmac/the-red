"""Builds assets/gear_big.png: the weapons at 64 x 64, one column each, in the
same order and pose as gear.png at 4x -- butt at the bottom left, point to the
upper right, gripped at (10, 50) -- so HeroLook can swap one for the other
when it draws the big hero (bag, battle swing).

Also the weapons as carried on the back seen from the side, grip up and point
down and back (steeper than any flip of the diagonal can make them):
gear_side_big.png (64 x 64) and gear_side.png (16 x 16, shrunk from it).
Run:  python3 tools/make_gear_big.py
"""
import math
from pathlib import Path

from PIL import Image

from pixkit import Sprite

ROOT = Path(__file__).resolve().parent.parent
S = 64
ORDER = ["rusty_dagger", "bone_club", "hatchet", "hooked_sickle", "iron_mace", "grave_blade"]
PAL = {"metal": "8e98ac", "rust": "8a4a2a", "leather": "6a4028", "wood": "7a5232", "bone": "ddd2b6",
       "dark": "3a3444", "grave": "5a4a8a", "brass": "c8913a", "rune": "c890ff", "wrap": "4a3a5a"}

B = (9.0, 55.0)             # the butt
U = (1 / math.sqrt(2), -1 / math.sqrt(2))   # along the weapon
N = (U[1] * -1, U[0])       # across it (pointing down-right of the axis)
N = (-U[1], U[0])


def at(t, o=0.0):
    """t along the weapon from the butt, o across it."""
    return (B[0] + U[0] * t + N[0] * o, B[1] + U[1] * t + N[1] * o)


def blade(s, t0, t1, w0, mat, w1=0.0, edge_tone=5, back=None):
    """A flat blade from t0 (width w0 each side) tapering to t1."""
    back = w0 if back is None else back
    s.poly([at(t0, -back), at(t1 - 4, -back * 0.7 - w1), at(t1, 0), at(t1 - 4, w0 * 0.6 + w1), at(t0, w0)], mat,
           tone=3)
    s.line([at(t0 + 1, 0), at(t1 - 2, 0)], mat, 2)                        # the fuller / ridge
    s.line([at(t0 + 1, w0 - 0.8), at(t1 - 3, w0 * 0.5)], mat, edge_tone)   # the lit edge
    s.line([at(t0 + 1, -back + 0.8), at(t1 - 3, -back * 0.6)], mat, 1)


def guard(s, t, w, r, mat):
    s.limb([at(t, -w), at(t, w)], r, mat)


def grip(s, t0, t1, r, mat, wraps=True):
    s.limb([at(t0), at(t1)], r, mat)
    if wraps:
        for t in range(int(t0) + 2, int(t1), 3):
            s.line([at(t, -r), at(t + 1.5, r)], mat, 1)


def rusty_dagger(s):
    s.blob(*at(2), 2.6, 2.6, "metal")
    grip(s, 3, 15, 2.2, "leather")
    guard(s, 16, 6, 1.6, "metal")
    blade(s, 17, 44, 3.4, "metal")
    s.texture("metal", 0.0)
    for (t, o, r) in ((24, 1.5, 1.4), (31, -1.2, 1.1), (37, 0.8, 0.9), (21, -2, 0.8)):   # rust
        s.blob(*at(t, o), r, r * 0.8, "rust", outline=False, bands=(-0.3, 0.2, 0.7))
    s.line([at(40, 2.0), at(41, 1.2)], "metal", 0)   # a nick in the edge


def bone_club(s):
    s.limb([at(1), at(30), at(56)], 2.6, "bone", r_end=4.0)
    s.blob(*at(58, -2.8), 4.0, 4.0, "bone")
    s.blob(*at(58, 2.8), 4.0, 4.0, "bone")
    s.blob(*at(1, -1.6), 2.6, 2.6, "bone")
    s.blob(*at(1, 1.6), 2.6, 2.6, "bone")
    grip(s, 3, 16, 3.0, "leather")
    s.line([at(34, 1), at(38, -0.5), at(41, 1.5)], "bone", 0)   # a crack
    s.texture("bone", 0.12, -1, tones=(2, 3, 4), seed=3)


def hatchet(s):
    s.limb([at(0), at(58)], 1.9, "wood")
    s.line([at(2, -0.6), at(56, -0.6)], "wood", 4)
    grip(s, 2, 15, 2.3, "leather")
    # the head: a bearded axe blade on the far side, a flat poll behind
    s.poly([at(46, 1), at(57, 1), at(60, 13), at(52, 14), at(47, 8)], "metal", tone=3)
    s.line([at(60, 13), at(52, 14)], "metal", 5)
    s.line([at(59, 12), at(52, 13)], "metal", 4)
    s.line([at(48, 2), at(56, 2)], "metal", 1)
    s.poly([at(48, -1), at(56, -1), at(55, -5), at(49, -5)], "metal", tone=2)
    s.blob(*at(52, 0), 1.0, 1.0, "dark", outline=False)
    s.texture("wood", 0.12, -1, tones=(2, 3, 4), seed=5)


def hooked_sickle(s):
    s.limb([at(0), at(36)], 2.0, "wood")
    grip(s, 2, 14, 2.4, "leather")
    s.blob(*at(37), 2.6, 2.6, "brass")
    # the hooked blade sweeping round from the top of the haft
    pts = []
    for k in range(12):
        a = -0.4 + k * 0.30
        pts.append(at(46 + math.sin(a) * 12, -2 + (1 - math.cos(a)) * 10 - 8))
    s.limb([at(37)] + pts, 3.4, "metal", r_end=0.6)
    s.limb([at(37)] + pts[:-1], 1.0, "metal", r_end=0.3, outline=False, bands=(9,))   # the bright inner edge
    s.texture("wood", 0.12, -1, tones=(2, 3, 4), seed=6)
    s.glints("metal", 0.08)


def iron_mace(s):
    s.limb([at(0), at(46)], 2.0, "dark")
    grip(s, 2, 16, 2.5, "leather")
    s.blob(*at(1), 2.4, 2.4, "dark")
    # the head: an iron ball with flanges and studs
    for k in range(6):
        a = k * math.pi / 3 + 0.3
        s.limb([at(52, 0), at(52 + math.cos(a) * 10, math.sin(a) * 10)], 1.6, "metal", r_end=0.5)
    s.blob(*at(52), 7.0, 7.0, "metal", bands=(-0.3, 0.05, 0.5, 0.85, 0.96))
    for (dt, do) in ((-3, -3), (3, 3), (-3, 3), (3, -3), (0, 0)):
        s.dot(*at(52 + dt, do), "metal", 5 if dt <= 0 and do <= 0 else 1)
    s.blob(*at(44), 2.8, 2.0, "metal")
    s.glints("metal", 0.06)


def grave_blade(s):
    s.blob(*at(1.5), 2.6, 2.6, "brass")
    grip(s, 3, 15, 2.2, "wrap")
    guard(s, 16, 7.5, 1.8, "brass")
    s.blob(*at(16), 2.4, 2.4, "grave")
    blade(s, 17, 64, 3.6, "grave")
    # runes down the fuller, glowing
    for t in range(21, 58, 5):
        x, y = at(t, 0)
        for (dx, dy) in ((0, 0), (1, 0), (0, -1)) if (t // 5) % 2 else ((0, 0), (1, -1), (-1, 0)):
            s.pdot(round(x + dx), round(y + dy), "e8c8ff")
    s.glints("grave", 0.05)


DESIGNS = [rusty_dagger, bone_club, hatchet, hooked_sickle, iron_mace, grave_blade]
# the legendary weapon, the warden's axe, is column 6 (tools/legendary_gear.py)
import legendary_gear  # noqa: E402
legendary_gear.register_gear(ORDER, DESIGNS, PAL, globals())


def set_axis(butt, along):
    """Where the weapon lies in its box: butt point, and the direction to its point."""
    global B, U, N
    ln = math.hypot(*along)
    B = butt
    U = (along[0] / ln, along[1] / ln)
    N = (-U[1], U[0])


SIDE_BUTT = (20.0, 3.0)        # carried on the back, seen from the side: grip up, point down and back
SIDE_ALONG = (4.0, 56.0)


def render(butt, along):
    set_axis(butt, along)
    sheet = Image.new("RGBA", (S * len(ORDER), S), (0, 0, 0, 0))
    for i, fn in enumerate(DESIGNS):
        s = Sprite(S, S, grain=0.10, cast=True)
        fn(s)
        sheet.paste(s.image(PAL), (i * S, 0))
    return sheet


def shrink(img):
    """The big side view at 1/4 for the small hero: each 4 x 4 block becomes the
    colour most of it is, then a dark outline goes round it."""
    from collections import Counter
    w, h = img.width // 4, img.height // 4
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            cs = [px[x * 4 + i, y * 4 + j] for i in range(4) for j in range(4)]
            solid = [c for c in cs if c[3] > 0 and c[:3] != (26, 16, 34)]
            if len(solid) >= 5:
                out.putpixel((x, y), Counter(solid).most_common(1)[0][0])
    o = out.load()
    edge = []
    for y in range(h):
        for x in range(w):
            if o[x, y][3] == 0 and any(0 <= x + dx < w and 0 <= y + dy < h and o[x + dx, y + dy][3] > 0
                                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                edge.append((x, y))
    for (x, y) in edge:
        out.putpixel((x, y), (26, 16, 34, 255))
    return out


def main():
    render((9.0, 55.0), (1.0, -1.0)).save(ROOT / "assets" / "gear_big.png")
    side = render(SIDE_BUTT, SIDE_ALONG)
    side.save(ROOT / "assets" / "gear_side_big.png")
    shrink(side).save(ROOT / "assets" / "gear_side.png")
    print("wrote %d big weapons, and the side views for carrying them" % len(ORDER))


if __name__ == "__main__":
    main()
