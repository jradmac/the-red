"""Builds assets/walls3d.png: raised-terrain autotile pieces (Pokemon style).

Every wall top (and every patch of water) is drawn as four 8x8 quarters.
Each quarter looks at its two side neighbours and the diagonal one and
picks a piece:

    0 fill    surrounded: plain surface
    1 vedge   open above/below: a lit lip (north) or edge (south)
    2 hedge   open to the side: a sloped side band (east / west)
    3 outer   open on both: a ROUNDED outside corner
    4 inner   only the diagonal is open: a small inside-corner curve

Quarters: 0 NW, 1 NE, 2 SW, 3 SE.  Piece index = quarter * 5 + type.
Rows (8 px tall each), 2 variants side by side (20 pieces each):
    0 crypt stone   1 courtyard sandstone   2 mountain plateau (grass on top)
    3 forest canopy 4-7 water, animation frames 0-3 (1 variant)
Run: python3 tools/make_walls3d.py
"""
from pathlib import Path
import math
import random
import sys

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_env import hx, mix, shade, moss_tile, water_tile, canopy_top, MOSS, FOREST, COURT, MTN  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "assets"
R = 6.0   # corner radius (px)


def noise_tex(seed, base, others, weights, specks=None):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (16, 16), base)
    px = img.load()
    for y in range(16):
        for x in range(16):
            r = rnd.random()
            acc = 0
            for c, w in zip(others, weights):
                acc += w
                if r < acc:
                    px[x, y] = c
                    break
    if specks:
        for _ in range(specks[1]):
            x, y = rnd.randrange(16), rnd.randrange(16)
            px[x, y] = specks[0]
    return img


STYLES = {
    "crypt": dict(outline=hx("231d30"), lip=hx("a69ec0"), lip2=hx("7a7294"), side=[hx("3e3852"), hx("2e2940"), hx("221d30")]),
    "court": dict(outline=hx("4a3e32"), lip=hx("f0e6d0"), lip2=hx("cfc2aa"), side=[hx("7e705e"), hx("62574a"), hx("4c4238")]),
    "plateau": dict(outline=hx("4a3220"), lip=hx("bce89c"), lip2=hx("8cc874"), side=[hx("9a7650"), hx("765638"), hx("583e28")]),
    "canopy": dict(outline=hx("16301c"), lip=FOREST["can_tip"], lip2=FOREST["can_hi"], side=[FOREST["can"], FOREST["can_dk"], hx("12261a")]),
}
WATER_STYLE = dict(bank=hx("2e2418"), shadow=[hx("0a1424"), hx("0f1c30"), hx("16263c")], foam=hx("cfe8ff"), foam2=hx("8ab4d8"))


def piece(tex, q, kind, style, water=False):
    """One 8x8 quarter. tex is a 16x16 surface texture."""
    qx, qy = (q % 2) * 8, (q // 2) * 8
    out = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    src = tex.load()
    px = out.load()
    vside = "N" if q < 2 else "S"
    hside = "W" if q % 2 == 0 else "E"
    open_v = kind in (1, 3)
    open_h = kind in (2, 3)
    for y in range(8):
        for x in range(8):
            c = src[qx + x, qy + y]
            # distance from the open boundary, and which way that boundary faces
            dists = []
            if open_v:
                dists.append(((y + 0.5) if vside == "N" else (7.5 - y), vside))
            if open_h:
                dists.append(((x + 0.5) if hside == "W" else (7.5 - x), hside))
            de, face = 99.0, ""
            if kind == 3:
                cx = R if hside == "W" else 8 - R
                cy = R if vside == "N" else 8 - R
                in_corner = ((x + 0.5 < cx) if hside == "W" else (x + 0.5 > cx)) and \
                    ((y + 0.5 < cy) if vside == "N" else (y + 0.5 > cy))
                if in_corner:
                    dx, dy = x + 0.5 - cx, y + 0.5 - cy
                    de = R - math.hypot(dx, dy)
                    face = vside if abs(dy) > abs(dx) * 0.8 else hside
                else:
                    de, face = min(dists)
            elif kind == 4:
                # the open diagonal corner: a little curve cut into the corner
                cx = 0 if hside == "W" else 8
                cy = 0 if vside == "N" else 8
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                if d < 3.5:
                    de = d - 2.0
                    face = vside if abs(y + 0.5 - cy) < abs(x + 0.5 - cx) else hside
                    # inside corners face the other way
                    face = {"N": "S", "S": "N", "W": "E", "E": "W"}[face] if False else face
            elif dists:
                de, face = min(dists)
            if de < 0:
                continue   # cut away: the ground below shows
            if water:
                if de < 1:
                    c = WATER_STYLE["bank"]
                elif face == "N" and de < 4:
                    c = mix(c, WATER_STYLE["shadow"][int(de) - 1], 0.75)   # the bank shades the water
                elif face == "S" and de < 2:
                    c = WATER_STYLE["foam"]
                elif face in ("W", "E") and de < 2:
                    c = WATER_STYLE["foam2"]
            else:
                if de < 1:
                    c = style["outline"]
                elif face == "N" and de < 2:
                    c = style["lip"]
                elif face == "N" and de < 3:
                    c = mix(c, style["lip2"], 0.6)
                elif face in ("W", "E") and de < 4:
                    c = style["side"][min(2, int(de) - 1)] if face == "E" else style["side"][max(0, 3 - int(de) - 1)]
                elif face == "S" and de < 2:
                    c = style["lip2"]
            px[x, y] = c
    return out


def material_row(texs, style, water=False):
    row = Image.new("RGBA", (8 * 20 * len(texs), 8), (0, 0, 0, 0))
    for v, tex in enumerate(texs):
        for q in range(4):
            for kind in range(5):
                row.paste(piece(tex, q, kind, style, water), ((v * 20 + q * 5 + kind) * 8, 0))
    return row


def build():
    crypt = [noise_tex(10 + i, hx("4c4562"), [hx("433d58"), hx("564e6e"), hx("3a3550")], [0.25, 0.15, 0.1],
                       (hx("6a6286"), 6)) for i in range(2)]
    court = [noise_tex(20 + i, hx("7e7262"), [hx("746858"), hx("8a7e6c"), MOSS["mid"]], [0.25, 0.15, 0.05],
                       (MOSS["hi"], 3)) for i in range(2)]
    plateau = []
    for i in range(2):
        t = moss_tile(i * 2)
        plateau.append(t)
    canopy = [canopy_top(0), canopy_top(0).transpose(Image.FLIP_LEFT_RIGHT)]
    water = [water_tile(f) for f in range(4)]
    rows = [material_row(crypt, STYLES["crypt"]), material_row(court, STYLES["court"]),
            material_row(plateau, STYLES["plateau"]), material_row(canopy, STYLES["canopy"])]
    for f in range(4):
        rows.append(material_row([water[f]], None, water=True))
    sheet = Image.new("RGBA", (8 * 40, 8 * len(rows)), (0, 0, 0, 0))
    for i, r in enumerate(rows):
        sheet.paste(r, (0, i * 8))
    return sheet


if __name__ == "__main__":
    build().save(OUT / "walls3d.png")
    print("wrote walls3d.png")
