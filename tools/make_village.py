"""Builds the village art.

    python3 tools/make_village.py

assets/village.png   one block per village style (rows of 152 px), in host
                     landscape order: 0 forest, 1 courtyard, 2 mountain,
                     3 river, 4 swamp. Inside a block (x, y, w, h):
      walls      y 0    16x24: 0 run E-W, 16 run E-W (variant), 32 run N-S, 48 post
      gate       y 0    64,0 48x40 frame (centred on the gate tile);
                        112.. 4 frames 16x24 of the gate leaves, closed -> open
      buildings  y 40   shop 0 (80x64), sage 80 (64x64), inn 144 (96x64),
                        home 240 (64x48), home_wide 304 (80x48),
                        home b 384 (64x48), home_wide b 448 (80x48)
      props      y 108  lamp 0 (16x32), barrel 16, crate 32, pots 48, hay 64 (16x16 at y+16),
                        well 80 (32x40), tree 112 (32x40), bench 144, sign 160 (16x24),
                        road 176.. (4 x 16x16), plaza 240.. (2), soil 272,
                        fence E-W 288, N-S 304, post 320 (16x24), flowers 336.. (4)
assets/npcs.png      16x24 frames, 5 columns (stand, walk x4) x 4 rows (down, up,
                     left, right) per character, characters stacked: villagers 0-9,
                     guards 10-14 (one per style), shopkeeper 15, sage 16, innkeeper 17,
                     children 18-19.
"""
from pathlib import Path
import random
import sys

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_env import hx, mix, shade, dith  # noqa: E402
import make_art  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "assets"
BLOCK = 152
SHEET_W = 544
OUTLINE = hx("1c1020")


class Canvas:
    def __init__(self, img, ox=0, oy=0):
        self.img = img
        self.px = img.load()
        self.ox, self.oy = ox, oy

    def at(self, ox, oy):
        return Canvas(self.img, ox, oy)

    def set(self, x, y, c):
        x += self.ox
        y += self.oy
        if not (0 <= x < self.img.width and 0 <= y < self.img.height) or c is None:
            return
        if len(c) == 3:
            c = c + (255,)
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

    def get(self, x, y):
        x += self.ox
        y += self.oy
        if 0 <= x < self.img.width and 0 <= y < self.img.height:
            return self.px[x, y]
        return (0, 0, 0, 0)

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, c)

    def hline(self, x, y, w, c):
        self.rect(x, y, w, 1, c)

    def vline(self, x, y, h, c):
        self.rect(x, y, 1, h, c)

    def outline(self, x0, y0, w, h, col=OUTLINE):
        """Dark outline around everything drawn inside the box."""
        pts = []
        for y in range(y0 - 1, y0 + h + 1):
            for x in range(x0 - 1, x0 + w + 1):
                if self.get(x, y)[3] != 0:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if x0 <= x + dx < x0 + w and y0 <= y + dy < y0 + h and self.get(x + dx, y + dy)[3] > 200:
                        pts.append((x, y))
                        break
        for p in pts:
            self.set(p[0], p[1], col)


# ---------------------------------------------------------------------------
# Styles
# ---------------------------------------------------------------------------
STYLES = [
    dict(name="forest", fence="logs", wall="timber", roofkind="shingle",
         log=hx("7a5232"), log_dk=hx("4e321e"), log_lt=hx("a07448"), log_end=hx("c09868"),
         plaster=hx("d9c9a2"), plaster_dk=hx("b3a07a"), beam=hx("5a3a22"),
         roof=hx("4f6b3c"), roof_dk=hx("33482a"), roof_lt=hx("6f8f50"), ridge=hx("2a3a22"),
         road=hx("7a6248"), road_dk=hx("5e4a36"), road_lt=hx("947a5c"), trim=hx("6a4426")),
    dict(name="court", fence="stone", wall="whitestone", roofkind="slate",
         stone=hx("cfc6b4"), stone_dk=hx("9c937f"), stone_lt=hx("ece5d4"), mortar=hx("857c6a"),
         plaster=hx("e4dccb"), plaster_dk=hx("b8ae99"), beam=hx("7a6a58"),
         roof=hx("4d5f80"), roof_dk=hx("34425c"), roof_lt=hx("6f84a8"), ridge=hx("26304a"),
         road=hx("a8a092"), road_dk=hx("847c6e"), road_lt=hx("c4bcae"), trim=hx("6a5a48")),
    dict(name="mountain", fence="stone", wall="greystone", roofkind="tile",
         stone=hx("8e887c"), stone_dk=hx("625d54"), stone_lt=hx("aea898"), mortar=hx("4e4a43"),
         plaster=hx("9a9486"), plaster_dk=hx("6e695e"), beam=hx("4e3a2a"),
         roof=hx("a3483a"), roof_dk=hx("70302a"), roof_lt=hx("c8664e"), ridge=hx("4e2420"),
         road=hx("7e786c"), road_dk=hx("5c574e"), road_lt=hx("9a9486"), trim=hx("4e3a2a")),
    dict(name="river", fence="logs", wall="planks", roofkind="thatch",
         log=hx("8a6440"), log_dk=hx("5a3e26"), log_lt=hx("b08858"), log_end=hx("d0aa78"),
         plaster=hx("a07a50"), plaster_dk=hx("7a5a38"), beam=hx("5a3e26"),
         roof=hx("c9a457"), roof_dk=hx("94763a"), roof_lt=hx("e6c878"), ridge=hx("6e5428"),
         road=hx("8a7458"), road_dk=hx("6a5842"), road_lt=hx("a48e70"), trim=hx("5a3e26")),
    dict(name="swamp", fence="logs", wall="darkplanks", roofkind="reed",
         log=hx("4e4434"), log_dk=hx("2e281e"), log_lt=hx("6e624a"), log_end=hx("8a7c5c"),
         plaster=hx("5c5040"), plaster_dk=hx("40382c"), beam=hx("2e281e"),
         roof=hx("5c6a3c"), roof_dk=hx("3c4826"), roof_lt=hx("7c8c50"), ridge=hx("2a321a"),
         road=hx("5e5440"), road_dk=hx("443c2e"), road_lt=hx("766a52"), trim=hx("2e281e"),
         moss=hx("6a8a3a")),
]
WINDOW = dict(frame=hx("3a2618"), glass=hx("ffcf6a"), glass_dk=hx("e08a2e"), glass_lt=hx("fff0b0"))
DOOR = dict(wood=hx("6a4024"), wood_dk=hx("43261a"), wood_lt=hx("8a5a34"), iron=hx("2a2228"), knob=hx("e8c060"))


def noise(x, y, salt=0):
    h = (x * 374761393 + y * 668265263 + salt * 2246822519) & 0xffffffff
    h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
    return (h & 0xffff) / 65535.0


# ---------------------------------------------------------------------------
# Walls and gates
# ---------------------------------------------------------------------------
def log_column(cv, x, top, bottom, st, w=4):
    """One upright log of a palisade, sharpened at the top."""
    for yy in range(top + 2, bottom):
        for i in range(w):
            c = st["log"] if 0 < i < w - 1 else st["log_dk"]
            if i == 1:
                c = st["log_lt"]
            if noise(x + i, yy, 3) < 0.12:
                c = shade(c, 0.85)
            cv.set(x + i, yy, c)
    # point
    cv.set(x + 1, top, st["log_lt"])
    cv.set(x + 2, top, st["log"])
    for i in range(w):
        cv.set(x + i, top + 1, st["log"] if i in (1, 2) else st["log_dk"])
    if "moss" in st:
        for yy in range(bottom - 6, bottom):
            if noise(x, yy, 9) < 0.35:
                cv.set(x + (yy % 2) + 1, yy, st["moss"])


def wall_run_ew(cv, st, variant):
    """A stretch of wall running east-west, seen from the south. 16x24, the tile
    is the bottom 16 rows."""
    if st["fence"] == "logs":
        for k in range(4):
            top = 1 + (k + variant) % 2 + (1 if noise(k, variant, 5) < 0.3 else 0)
            log_column(cv, k * 4, top, 22, st)
        # a cross-beam
        for xx in range(16):
            cv.set(xx, 9, st["log_dk"])
            cv.set(xx, 10, st["log"])
            cv.set(xx, 16, st["log_dk"])
        cv.rect(0, 22, 16, 2, (0, 0, 0, 70))
    else:
        # top of the wall (seen from above) then its face
        cv.rect(0, 0, 16, 5, st["stone_lt"])
        cv.hline(0, 0, 16, shade(st["stone_lt"], 1.06))
        cv.hline(0, 4, 16, st["stone_dk"])
        # crenellations
        for k in range(0, 16, 8):
            cv.rect(k + variant * 4 % 8, 0, 4, 2, shade(st["stone_lt"], 1.08))
        for yy in range(5, 22):
            row = (yy - 5) // 4
            off = 4 if row % 2 else 0
            for xx in range(16):
                c = st["stone"]
                if (yy - 5) % 4 == 3 or (xx + off) % 8 == 7:
                    c = st["mortar"]
                elif (yy - 5) % 4 == 0:
                    c = st["stone_lt"]
                if noise(xx, yy, 7 + variant) < 0.1 and c == st["stone"]:
                    c = st["stone_dk"]
                cv.set(xx, yy, c)
        cv.rect(0, 22, 16, 2, (0, 0, 0, 70))


def wall_run_ns(cv, st):
    """A stretch of wall running north-south: you see its top edge-on."""
    if st["fence"] == "logs":
        for yy in range(0, 24, 4):
            # log tops seen from the side, stacked down the tile
            for i in range(6):
                c = st["log"] if 0 < i < 5 else st["log_dk"]
                cv.set(5 + i, yy + 1, st["log_end"] if 1 <= i <= 4 else st["log_dk"])
                cv.set(5 + i, yy + 2, c)
                cv.set(5 + i, yy + 3, st["log_dk"] if i in (0, 5) else shade(c, 0.85))
            cv.set(6, yy, st["log_lt"])
            cv.set(9, yy, st["log"])
        cv.rect(11, 2, 2, 22, (0, 0, 0, 60))
    else:
        for yy in range(0, 24):
            for xx in range(4, 12):
                c = st["stone_lt"] if xx < 6 else (st["stone"] if xx < 10 else st["stone_dk"])
                if yy % 6 == 5:
                    c = st["mortar"]
                cv.set(xx, yy, c)
        for yy in range(0, 24, 6):
            cv.rect(4, yy, 2, 2, shade(st["stone_lt"], 1.08))
        cv.rect(12, 2, 2, 22, (0, 0, 0, 60))


def wall_post(cv, st):
    if st["fence"] == "logs":
        for yy in range(0, 22):
            for i in range(8):
                c = st["log"] if 1 < i < 6 else st["log_dk"]
                if i == 2:
                    c = st["log_lt"]
                cv.set(4 + i, yy + 2, c)
        cv.rect(5, 0, 6, 2, st["log_end"])
        cv.rect(4, 1, 8, 1, st["log"])
        cv.hline(4, 9, 8, st["log_dk"])
        cv.hline(4, 16, 8, st["log_dk"])
    else:
        cv.rect(2, 0, 12, 22, st["stone"])
        cv.rect(2, 0, 12, 4, st["stone_lt"])
        cv.hline(2, 4, 12, st["stone_dk"])
        for yy in range(6, 22, 4):
            cv.hline(2, yy, 12, st["mortar"])
        cv.vline(13, 4, 18, st["stone_dk"])
        cv.vline(2, 4, 18, st["stone_lt"])
    cv.rect(2, 22, 12, 2, (0, 0, 0, 70))
    cv.outline(0, 0, 16, 24)


def gate_frame(cv, st):
    """48x40: two tall posts (on the tiles either side of the gate) and a beam
    across with a lantern. The gate tile is the middle 16 px; the frame's feet
    stand on row 24..40."""
    stone = st["fence"] == "stone"
    for px0 in (0, 34):
        for yy in range(4, 38):
            for i in range(14):
                if stone:
                    c = st["stone"] if 2 < i < 11 else (st["stone_lt"] if i <= 2 else st["stone_dk"])
                    if (yy - 4) % 6 == 5:
                        c = st["mortar"]
                else:
                    c = st["log"] if 3 < i < 10 else (st["log_lt"] if i <= 3 else st["log_dk"])
                    if noise(px0 + i, yy, 11) < 0.1:
                        c = shade(c, 0.85)
                cv.set(px0 + i, yy, c)
        cap = st["stone_lt"] if stone else st["log_end"]
        cv.rect(px0 - 1, 2, 16, 3, cap)
        cv.rect(px0 - 1, 5, 16, 1, shade(cap, 0.75))
    # the beam
    beam_c = st["stone"] if stone else st["log"]
    beam_dk = st["stone_dk"] if stone else st["log_dk"]
    cv.rect(12, 6, 24, 5, beam_c)
    cv.hline(12, 6, 24, shade(beam_c, 1.15))
    cv.hline(12, 10, 24, beam_dk)
    # hanging lantern
    cv.vline(24, 11, 3, OUTLINE)
    cv.rect(22, 14, 5, 5, WINDOW["frame"])
    cv.rect(23, 15, 3, 3, WINDOW["glass"])
    cv.set(24, 16, WINDOW["glass_lt"])
    cv.rect(0, 38, 48, 2, (0, 0, 0, 60))
    cv.outline(0, 0, 48, 40)


def gate_leaves(cv, st, frame):
    """16x24: the two gate doors in the opening, swinging inward (frame 0 shut, 3 open)."""
    wood, dk, lt = (st.get("log", hx("6a4a30")), st.get("log_dk", hx("40281a")), st.get("log_lt", hx("8a6a44")))
    if st["fence"] == "stone":
        wood, dk, lt = DOOR["wood"], DOOR["wood_dk"], DOOR["wood_lt"]
    w = [8, 6, 3, 1][frame]
    for side in (0, 1):
        for i in range(w):
            x = i if side == 0 else 15 - i
            for yy in range(6, 24):
                c = wood if i % 3 != 2 else dk
                if i == 0:
                    c = lt
                cv.set(x, yy, c)
            cv.set(x, 6, dk)
        if w >= 3:
            band_x = range(0, w) if side == 0 else range(16 - w, 16)
            for x in band_x:
                cv.set(x, 10, DOOR["iron"])
                cv.set(x, 19, DOOR["iron"])
    if frame == 0:
        cv.vline(7, 6, 18, OUTLINE)
        cv.set(6, 15, DOOR["knob"])
        cv.set(9, 15, DOOR["knob"])


# ---------------------------------------------------------------------------
# Buildings
# ---------------------------------------------------------------------------
def roof(cv, x0, y0, w, h, st, seed=0):
    """The roof seen from the front and above: a sloped plane with its ridge at
    the top and the eaves overhanging the wall at the bottom."""
    kind = st["roofkind"]
    for yy in range(h):
        t = yy / max(h - 1, 1)
        for xx in range(w):
            x, y = x0 + xx, y0 + yy
            base = mix(st["roof_lt"], st["roof"], min(1.0, t * 1.6))
            if kind in ("shingle", "slate", "tile"):
                row = yy // 3
                off = (row % 2) * 3
                c = base
                if yy % 3 == 2:
                    c = st["roof_dk"]
                elif (xx + off) % 6 == 5:
                    c = shade(base, 0.82)
                if kind == "tile" and (xx + off) % 6 in (0, 1) and yy % 3 == 0:
                    c = shade(base, 1.12)
                if noise(x, y, seed) < 0.06:
                    c = shade(c, 0.9)
            else:   # thatch / reed: vertical straw strokes
                c = base
                if (xx * 7 + (yy // 2) * 3) % 5 == 0:
                    c = st["roof_dk"]
                elif noise(xx, yy, 31 + seed) < 0.25:
                    c = st["roof_lt"]
                if kind == "reed" and noise(x, y, 13) < 0.1:
                    c = hx("8a9a5a")
            cv.set(x, y, c)
    # ridge and eaves
    cv.hline(x0, y0, w, st["ridge"])
    cv.hline(x0 + 1, y0 + 1, w - 2, shade(st["roof_lt"], 1.1))
    cv.hline(x0, y0 + h - 1, w, st["roof_dk"])
    cv.hline(x0, y0 + h, w, (0, 0, 0, 90))
    # gable ends: the slope seen at either side
    for yy in range(h):
        cv.set(x0, y0 + yy, st["roof_dk"])
        cv.set(x0 + w - 1, y0 + yy, st["roof_dk"])


def front_wall(cv, x0, y0, w, h, st, seed=0):
    mat = st["wall"]
    for yy in range(h):
        for xx in range(w):
            x, y = x0 + xx, y0 + yy
            if mat == "timber":
                c = st["plaster"]
                if noise(x, y, 41 + seed) < 0.08:
                    c = st["plaster_dk"]
                if xx in (0, 1, w - 2, w - 1) or yy in (0, h - 2, h - 1) or (xx % 16 == 8 and 0 < xx < w - 8):
                    c = st["beam"]
            elif mat in ("whitestone", "greystone"):
                row = yy // 4
                off = 4 if row % 2 else 0
                c = st["stone"]
                if yy % 4 == 3 or (xx + off) % 8 == 7:
                    c = st["mortar"]
                elif yy % 4 == 0:
                    c = st["stone_lt"]
                elif noise(x, y, 43 + seed) < 0.1:
                    c = st["stone_dk"]
            else:   # planks
                c = st["plaster"]
                if yy % 4 == 3:
                    c = st["plaster_dk"]
                elif noise(x, y // 4, 47 + seed) < 0.15:
                    c = shade(st["plaster"], 1.1)
                if (xx + (yy // 4) * 5) % 13 == 0:
                    c = st["plaster_dk"]
                if xx in (0, w - 1):
                    c = st["beam"]
            cv.set(x, y, c)
    # shade under the eaves
    cv.hline(x0, y0, w, shade(cv.get(x0 + 2, y0), 0.6))
    cv.hline(x0, y0 + 1, w, (0, 0, 0, 50))


def window(cv, x, y, w=8, h=8, shutters=None):
    cv.rect(x, y, w, h, WINDOW["frame"])
    for yy in range(1, h - 1):
        for xx in range(1, w - 1):
            c = WINDOW["glass"] if yy < h - 3 else WINDOW["glass_dk"]
            cv.set(x + xx, y + yy, c)
    cv.set(x + 1, y + 1, WINDOW["glass_lt"])
    cv.set(x + 2, y + 1, WINDOW["glass_lt"])
    cv.vline(x + w // 2, y + 1, h - 2, WINDOW["frame"])
    cv.hline(x + 1, y + h // 2, w - 2, WINDOW["frame"])
    cv.hline(x - 1, y + h, w + 2, shade(WINDOW["frame"], 1.4))
    if shutters:
        cv.rect(x - 3, y, 2, h, shutters)
        cv.rect(x + w + 1, y, 2, h, shutters)


def door(cv, x, y, h=14, color=None):
    """10 wide, arched top, standing on the bottom of the wall."""
    wood = color or DOOR["wood"]
    for yy in range(h):
        for xx in range(10):
            if yy == 0 and xx in (0, 1, 8, 9):
                continue
            if yy == 1 and xx in (0, 9):
                continue
            c = wood if xx % 3 else shade(wood, 0.75)
            if xx in (0, 9) or yy == 0 or (yy == 1 and xx in (1, 8)):
                c = DOOR["wood_dk"]
            cv.set(x + xx, y + yy, c)
    cv.set(x + 7, y + h // 2 + 1, DOOR["knob"])
    cv.hline(x + 1, y + 4, 8, DOOR["iron"])
    cv.hline(x + 1, y + h - 4, 8, DOOR["iron"])
    cv.rect(x - 1, y + h, 12, 1, shade(hx("6e6458"), 1.0))   # door step


def chimney(cv, x, y, st):
    cv.rect(x, y, 6, 9, hx("6e6458"))
    cv.rect(x, y, 6, 2, hx("8a8072"))
    cv.vline(x + 5, y + 2, 7, hx("4e463c"))
    cv.rect(x + 1, y - 1, 4, 1, hx("2a2428"))
    # smoke wisps
    for i, (dx, dy) in enumerate(((2, -3), (3, -5), (1, -7))):
        cv.set(x + dx, y + dy, (200, 200, 210, 120 - i * 30))


def sign(cv, x, y, w, h, icon):
    """A hanging sign on a bracket, with a little picture on it."""
    cv.hline(x - 2, y - 2, w + 4, OUTLINE)
    cv.vline(x + 1, y - 2, 2, OUTLINE)
    cv.vline(x + w - 2, y - 2, 2, OUTLINE)
    cv.rect(x, y, w, h, hx("8a5a34"))
    cv.rect(x + 1, y + 1, w - 2, h - 2, hx("a87448"))
    cv.hline(x, y + h - 1, w, hx("5a3a22"))
    icon(cv, x + 1, y + 1, w - 2, h - 2)


def icon_potion(cv, x, y, w, h):
    cx = x + w // 2
    cv.rect(cx - 1, y + 1, 2, 2, hx("e8dfc8"))
    cv.rect(cx - 2, y + 3, 4, 4, hx("e04a5a"))
    cv.set(cx - 1, y + 4, hx("ff9aa4"))


def icon_bed(cv, x, y, w, h):
    cv.rect(x + 1, y + h - 3, w - 2, 2, hx("e8dfc8"))
    cv.rect(x + 1, y + h - 5, 3, 2, hx("ffffff"))
    cv.rect(x + 4, y + h - 5, w - 5, 2, hx("4d6fb0"))
    cv.vline(x + 1, y + 1, h - 2, hx("5a3a22"))


def icon_star(cv, x, y, w, h):
    cx, cy = x + w // 2, y + h // 2
    for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (0, -2), (0, 2), (2, 0), (-2, 0)):
        cv.set(cx + dx, cy + dy, hx("f5e08a") if abs(dx) + abs(dy) < 2 else hx("c8a8ff"))


def flower_box(cv, x, y, w):
    cv.rect(x, y, w, 2, hx("5a3a22"))
    for i in range(w):
        if i % 2 == 0:
            cv.set(x + i, y - 1, [hx("e05a6a"), hx("f5d05a"), hx("c87af0")][(i // 2) % 3])
        else:
            cv.set(x + i, y - 1, hx("4a8a3a"))


def building(cv, kind, st, b_variant=0):
    """Draw one building into a canvas whose origin is its top-left."""
    sizes = {"shop": (80, 64), "sage": (64, 64), "inn": (96, 64), "home": (64, 48), "home_wide": (80, 48)}
    W, H = sizes[kind]
    roof_h = {"shop": 30, "sage": 32, "inn": 28, "home": 24, "home_wide": 24}[kind]
    wall_y = roof_h - 2
    wall_h = H - wall_y
    seed = hash(kind) % 97 + b_variant * 13
    # the building's own shadow, falling down-right onto the ground row below the wall
    front_wall(cv, 1, wall_y, W - 2, wall_h - 1, st, seed)
    if kind == "sage":
        # a round-topped tower roof: a pointed cone in a deep violet
        rs = dict(st)
        rs["roof"], rs["roof_dk"], rs["roof_lt"], rs["ridge"] = hx("5a3e8a"), hx("3a2660"), hx("7e5ab8"), hx("2a1a48")
        for yy in range(roof_h):
            half = int(4 + (W // 2 - 2) * (yy / roof_h) ** 0.8)
            for xx in range(W // 2 - half, W // 2 + half):
                t = yy / roof_h
                c = mix(rs["roof_lt"], rs["roof"], min(1, t * 1.4))
                if (yy // 3) % 2 == 0 and (xx + yy) % 5 == 0:
                    c = rs["roof_dk"]
                if xx > W // 2 + half * 0.4:
                    c = shade(c, 0.82)
                cv.set(xx, yy, c)
        cv.hline(2, roof_h - 1, W - 4, rs["roof_dk"])
        cv.hline(2, roof_h, W - 4, (0, 0, 0, 90))
        # a star on the tip
        cv.set(W // 2, 0, hx("f5e08a"))
        cv.set(W // 2 - 1, 1, hx("f5e08a"))
        cv.set(W // 2 + 1, 1, hx("f5e08a"))
        cv.set(W // 2, 1, hx("fff6c0"))
        # round window up in the roof, glowing violet
        cv.rect(W // 2 - 3, 12, 6, 6, WINDOW["frame"])
        cv.rect(W // 2 - 2, 13, 4, 4, hx("c8a8ff"))
        cv.set(W // 2 - 1, 13, hx("f0e8ff"))
    else:
        roof(cv, 0, 0, W, roof_h, st, seed)
    # the door: centred on the building's middle tile, standing on the bottom
    dx = (W // 32) * 16 + 3 if (W // 16) % 2 == 1 else (W // 2 // 16) * 16 + 3
    door_h = 15 if wall_h > 24 else 13
    door(cv, dx, H - door_h - 1, door_h, hx("4a3a6a") if kind == "sage" else None)
    # windows either side of the door
    wy = wall_y + 6
    spots = [x for x in range(6, W - 12, 16) if not (dx - 10 < x < dx + 12)]
    for i, x in enumerate(spots):
        window(cv, x + 1, wy, 8, 8, shutters=st["trim"] if (i + b_variant) % 2 == 0 and kind == "home" else None)
        if kind in ("home", "home_wide") and b_variant % 2 == 1:
            flower_box(cv, x, wy + 10, 10)
    if kind == "shop":
        # a striped awning over the front, and the potion sign
        for xx in range(4, W - 4):
            for yy in range(wall_y + 1, wall_y + 6):
                c = hx("c0393f") if (xx // 4) % 2 == 0 else hx("e8dfc8")
                if yy == wall_y + 5:
                    c = shade(c, 0.75)
                cv.set(xx, yy, c)
        for xx in range(4, W - 4, 4):
            cv.set(xx, wall_y + 6, hx("c0393f") if (xx // 4) % 2 == 0 else hx("e8dfc8"))
        cv.hline(4, wall_y + 7, W - 8, (0, 0, 0, 70))
        sign(cv, W - 18, wall_y + 10, 12, 10, icon_potion)
        # a crate of goods by the door
        cv.rect(dx - 13, H - 9, 9, 7, hx("8a5a34"))
        cv.rect(dx - 12, H - 10, 3, 2, hx("e04a5a"))
        cv.rect(dx - 8, H - 10, 3, 2, hx("f5d05a"))
        cv.hline(dx - 13, H - 6, 9, hx("5a3a22"))
    elif kind == "inn":
        sign(cv, 6, wall_y + 9, 14, 10, icon_bed)
        # a second storey: a row of small windows in the roof
        for x in range(14, W - 14, 18):
            cv.rect(x, 9, 9, 9, st["plaster"])
            cv.rect(x - 1, 7, 11, 3, st["roof_dk"])
            window(cv, x + 1, 10, 7, 7)
        chimney(cv, W - 14, -2 + 4, st)
    elif kind == "sage":
        sign(cv, W - 16, wall_y + 9, 11, 11, icon_star)
        # little potted herbs
        cv.rect(4, H - 6, 5, 4, hx("8a4a32"))
        cv.rect(4, H - 9, 5, 3, hx("5aa04a"))
    else:
        cx = 8 if b_variant % 2 == 0 else W - 16
        chimney(cv, cx, 2, st)
    # the dark line where the wall meets the ground
    cv.hline(1, H - 1, W - 2, shade(cv.get(3, H - 3), 0.55))
    cv.outline(0, -3, W, H + 3)
    return W, H


# ---------------------------------------------------------------------------
# Props
# ---------------------------------------------------------------------------
def lamp_post(cv, st):
    # 16x32; the post stands on the bottom tile
    cv.rect(7, 8, 2, 22, hx("2a2430"))
    cv.vline(7, 8, 22, hx("4a4250"))
    cv.rect(5, 29, 6, 2, hx("3a3440"))
    cv.rect(4, 2, 8, 7, WINDOW["frame"])
    cv.rect(5, 3, 6, 5, WINDOW["glass"])
    cv.rect(6, 4, 2, 2, WINDOW["glass_lt"])
    cv.rect(5, 1, 6, 1, hx("2a2430"))
    cv.set(7, 0, hx("2a2430"))
    cv.set(8, 0, hx("2a2430"))
    cv.outline(0, 0, 16, 32)


def barrel(cv):
    for yy in range(3, 15):
        for xx in range(3, 13):
            c = hx("8a5a34") if 4 < xx < 11 else hx("6a4024")
            if xx == 5:
                c = hx("a87448")
            if yy in (5, 12):
                c = hx("3a3440")
            cv.set(xx, yy, c)
    cv.rect(4, 2, 8, 2, hx("a87448"))
    cv.rect(5, 2, 6, 1, hx("6a4024"))
    cv.outline(0, 0, 16, 16)


def crate(cv):
    cv.rect(2, 4, 12, 11, hx("9a6a3e"))
    cv.rect(2, 4, 12, 3, hx("b8885a"))
    cv.hline(2, 7, 12, hx("6a4024"))
    for i in range(8):
        cv.set(3 + i, 8 + i * 6 // 8, hx("6a4024"))
    cv.vline(2, 4, 11, hx("6a4024"))
    cv.vline(13, 4, 11, hx("6a4024"))
    cv.outline(0, 0, 16, 16)


def pots(cv):
    for (x, y, w, h, c) in ((2, 6, 6, 8, hx("b0603e")), (8, 8, 6, 6, hx("8a4a32"))):
        cv.rect(x, y, w, h, c)
        cv.rect(x + 1, y - 1, w - 2, 1, shade(c, 1.2))
        cv.vline(x + 1, y + 1, h - 2, shade(c, 1.25))
        cv.rect(x + 1, y - 3, w - 2, 2, hx("5aa04a"))
    cv.outline(0, 0, 16, 16)


def hay(cv):
    for yy in range(4, 15):
        for xx in range(1, 15):
            c = hx("d8b050") if (xx + yy * 3) % 4 else hx("a88430")
            if yy < 6:
                c = hx("e8c868")
            cv.set(xx, yy, c)
    cv.hline(1, 9, 14, hx("8a6a28"))
    cv.outline(0, 0, 16, 16)


def well(cv, st):
    # 32x40: the 2x2 tiles are the bottom 32 rows; the roof rises above
    stone = st.get("stone", hx("8e887c"))
    stone_dk = st.get("stone_dk", hx("625d54"))
    stone_lt = st.get("stone_lt", hx("aea898"))
    for yy in range(22, 38):
        for xx in range(4, 28):
            c = stone if (xx + (yy // 3) * 3) % 6 else stone_dk
            if yy % 3 == 0:
                c = stone_lt
            cv.set(xx, yy, c)
    # the dark water seen over the rim
    cv.rect(6, 22, 20, 5, hx("1a2a3a"))
    cv.rect(8, 23, 6, 1, hx("4a7aa0"))
    cv.hline(4, 21, 24, stone_lt)
    # posts and a little roof
    for x in (5, 25):
        cv.rect(x, 6, 2, 17, hx("6a4024"))
    roof(cv, 2, 0, 28, 8, st, 5)
    cv.hline(7, 12, 18, hx("4a3020"))
    cv.vline(16, 12, 6, hx("a8a090"))
    cv.rect(14, 18, 4, 3, hx("6a4024"))
    cv.rect(4, 38, 24, 2, (0, 0, 0, 70))
    cv.outline(0, 0, 32, 40)


def tree(cv, st):
    # 32x40: a small round orchard tree on the bottom tile
    trunk = hx("5a3a22")
    cv.rect(14, 26, 4, 12, trunk)
    cv.vline(14, 26, 12, hx("7a5232"))
    leaf = {"swamp": (hx("4a5a2c"), hx("33401e"), hx("6a7a3c")),
            "mountain": (hx("3e5a3a"), hx("2a3e28"), hx("5a7a4e"))}.get(st["name"], (hx("4a7a3a"), hx("33582a"), hx("6a9a4a")))
    for yy in range(2, 30):
        for xx in range(3, 29):
            dx, dy = (xx - 16) / 13.0, (yy - 15) / 13.0
            if dx * dx + dy * dy > 1.0 - noise(xx, yy, 77) * 0.25:
                continue
            light = -(dx * 0.7 + dy * 0.7)
            c = leaf[0]
            if light > 0.35:
                c = leaf[2]
            elif light < -0.4:
                c = leaf[1]
            if noise(xx, yy, 91) < 0.15:
                c = shade(c, 0.85)
            cv.set(xx, yy, c)
    for (x, y) in ((10, 10), (19, 8), (22, 16), (12, 19), (17, 14)):
        cv.set(x, y, hx("e04a4a") if st["name"] != "swamp" else hx("8a9ad0"))
    cv.rect(9, 37, 14, 2, (0, 0, 0, 70))
    cv.outline(0, 0, 32, 40)


def bench(cv):
    cv.rect(1, 6, 14, 3, hx("8a5a34"))
    cv.hline(1, 6, 14, hx("a87448"))
    cv.rect(1, 10, 14, 2, hx("6a4024"))
    cv.rect(2, 12, 2, 3, hx("4a3020"))
    cv.rect(12, 12, 2, 3, hx("4a3020"))
    cv.outline(0, 0, 16, 16)


def signpost(cv):
    cv.rect(7, 8, 2, 15, hx("5a3a22"))
    cv.rect(1, 3, 14, 6, hx("a87448"))
    cv.hline(1, 8, 14, hx("6a4024"))
    cv.hline(3, 5, 9, hx("4a3020"))
    cv.outline(0, 0, 16, 24)


def road_tile(cv, st, v):
    cobble = st["name"] in ("court", "mountain")
    for yy in range(16):
        for xx in range(16):
            if cobble:
                cell = ((xx + (yy // 4 % 2) * 2) // 4, yy // 4)
                n = noise(cell[0] + v * 7, cell[1], 3)
                c = mix(st["road_dk"], st["road_lt"], 0.3 + n * 0.5)
                if (xx + (yy // 4 % 2) * 2) % 4 == 3 or yy % 4 == 3:
                    c = st["road_dk"]
            else:
                n = noise(xx, yy, 21 + v)
                c = st["road"]
                if n < 0.12:
                    c = st["road_dk"]
                elif n > 0.9:
                    c = st["road_lt"]
                if noise(xx // 2, yy // 2, 40 + v) < 0.05:
                    c = hx("9a9286")   # a pebble
            cv.set(xx, yy, c)


def plaza_tile(cv, st, v):
    for yy in range(16):
        for xx in range(16):
            off = 4 if (yy // 8) % 2 else 0
            c = mix(st["road"], st["road_lt"], 0.5 + noise((xx + off) // 8, yy // 8, 5 + v) * 0.4)
            if (xx + off) % 8 == 7 or yy % 8 == 7:
                c = st["road_dk"]
            elif (xx + off) % 8 == 0 or yy % 8 == 0:
                c = shade(c, 1.08)
            cv.set(xx, yy, c)


def soil_tile(cv):
    for yy in range(16):
        for xx in range(16):
            c = hx("5a4030") if yy % 4 < 2 else hx("4a3426")
            if noise(xx, yy, 99) < 0.1:
                c = hx("6e5040")
            cv.set(xx, yy, c)


def fence(cv, kind):
    wood, dk, lt = hx("8a6a44"), hx("5a4028"), hx("aa8a5c")
    if kind == "ew":
        for x in (1, 13):
            cv.rect(x, 6, 2, 16, wood)
            cv.set(x, 6, lt)
        cv.rect(0, 10, 16, 2, lt)
        cv.rect(0, 16, 16, 2, wood)
        cv.hline(0, 12, 16, dk)
        cv.hline(0, 18, 16, dk)
    elif kind == "ns":
        cv.rect(7, 0, 2, 24, wood)
        cv.vline(7, 0, 24, lt)
        cv.rect(6, 6, 4, 2, dk)
        cv.rect(6, 18, 4, 2, dk)
    else:
        cv.rect(6, 4, 4, 18, wood)
        cv.vline(6, 4, 18, lt)
        cv.rect(6, 3, 4, 1, lt)
    cv.outline(0, 0, 16, 24)


def flowers(cv, v):
    rnd = random.Random(v * 31 + 7)
    cols = [hx("e05a6a"), hx("f5d05a"), hx("c87af0"), hx("f0f0f0"), hx("6aa0f0")]
    for i in range(5):
        x, y = rnd.randint(2, 13), rnd.randint(3, 13)
        cv.set(x, y + 1, hx("3e7a34"))
        cv.set(x, y + 2, hx("3e7a34"))
        c = cols[(v + i) % len(cols)]
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, -1)):
            cv.set(x + dx, y + dy, c)
        cv.set(x, y, hx("fff2a0"))


# ---------------------------------------------------------------------------
def village_sheet():
    img = Image.new("RGBA", (SHEET_W, BLOCK * len(STYLES)), (0, 0, 0, 0))
    root = Canvas(img)
    for si, st in enumerate(STYLES):
        y0 = si * BLOCK
        wall_run_ew(root.at(0, y0), st, 0)
        wall_run_ew(root.at(16, y0), st, 1)
        wall_run_ns(root.at(32, y0), st)
        wall_post(root.at(48, y0), st)
        gate_frame(root.at(64, y0), st)
        for f in range(4):
            gate_leaves(root.at(112 + f * 16, y0), st, f)
        by = y0 + 40
        building(root.at(0, by + 3), "shop", st)
        building(root.at(80, by + 3), "sage", st)
        building(root.at(144, by + 3), "inn", st)
        building(root.at(240, by + 3 + 16), "home", st, 0)
        building(root.at(304, by + 3 + 16), "home_wide", st, 0)
        building(root.at(384, by + 3 + 16), "home", st, 1)
        building(root.at(448, by + 3 + 16), "home_wide", st, 1)
        py = y0 + 108
        lamp_post(root.at(0, py + 8), st)
        for i, fn in enumerate((barrel, crate, pots, hay)):
            fn(root.at(16 + i * 16, py + 24))
        well(root.at(80, py), st)
        tree(root.at(112, py), st)
        bench(root.at(144, py + 24))
        signpost(root.at(160, py + 16))
        for v in range(4):
            road_tile(root.at(176 + v * 16, py + 24), st, v)
        for v in range(2):
            plaza_tile(root.at(240 + v * 16, py + 24), st, v)
        soil_tile(root.at(272, py + 24))
        fence(root.at(288, py + 16), "ew")
        fence(root.at(304, py + 16), "ns")
        fence(root.at(320, py + 16), "post")
        for v in range(4):
            flowers(root.at(336 + v * 16, py + 24), v)
    return img


# ---------------------------------------------------------------------------
# People
# ---------------------------------------------------------------------------
SKINS = [("f6d7b8", "d9a283", "f0908a"), ("e8b890", "c08a62", "e08a7a"), ("c88a5e", "9a6440", "c07060"),
         ("8a5a3a", "684028", "9a5048")]
HAIRS = [("6b3d2a", "8a5236", "a8683f", "4d2a1e"), ("2a2228", "3e3440", "52485a", "1a141c"),
         ("c8a050", "e0c070", "f0d890", "9a7838"), ("a04a2a", "c8643a", "e08050", "70301c"),
         ("d8d8d8", "f0f0f0", "ffffff", "a8a8b0"), ("4a3020", "6a4630", "84603e", "2e1c12")]
TUNICS = [("5b6e8c", "7d90ad", "3e4c66", "2b3548"), ("7a4a3a", "9a6450", "5a3428", "3e2219"),
          ("4a7a4a", "6a9a64", "335a34", "223e24"), ("8a7a4a", "aa9a64", "6a5a34", "4a3e22"),
          ("7a4a7a", "9a6a9a", "5a3458", "3e223e"), ("a05a3a", "c87a50", "7a4028", "52281a"),
          ("4a6a7a", "6a8a9a", "334a58", "22323e")]
BASKET = {"M": "6a4024", "Y": "c89a5a", "y": "8a6a3a"}


def person_look(skin, hair, tunic, pants="3c3550", pants_dk="28223a", extra_body=None, extra_head=None):
    s, sd, sp = skin
    head = {"R": hair[0], "H": hair[1], "h": hair[2], "r": hair[3], "d": hair[3],
            "N": hair[0], "n": hair[3], "S": s, "s": sd, "P": sp}
    body = {"R": tunic[0], "H": tunic[1], "r": tunic[2], "d": tunic[3], "S": s, "s": sd,
            "C": pants, "c": pants_dk}
    legs = {"C": pants, "c": pants_dk, "S": s}
    for reg in (head, body, legs):
        reg.update(BASKET)
    if extra_body:
        body.update(extra_body)
    if extra_head:
        head.update(extra_head)
    return {"head": head, "body": body, "legs": legs}


def spear(img):
    """A spear held upright in the right hand (down view) on a 16x24 frame."""
    px = img.load()
    for y in range(0, 22):
        px[14, y] = (0x6a, 0x4a, 0x2a, 255)
    for (x, y, c) in ((14, 0, "e8e8f0"), (14, 1, "c0c4d0"), (13, 1, "8a8e9a"), (15, 1, "8a8e9a"), (14, 2, "a0a4b0")):
        px[x, y] = tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def person_sheet(looks, spears=()):
    """5 columns (stand, walk x4) x 4 rows (down, up, left, right) per look."""
    frames = {v: make_art.hero_frames(v) for v in ("down", "up", "right")}
    views = [("down", False), ("up", False), ("right", True), ("right", False)]
    sheet = Image.new("RGBA", (16 * 5, 24 * 4 * len(looks)), (0, 0, 0, 0))
    for li, look in enumerate(looks):
        for row, (view, mirror) in enumerate(views):
            for col in range(5):
                fr = make_art._look_frame(frames[view][col], look)
                if li in spears and view == "down":
                    spear(fr)
                if mirror:
                    fr = fr.transpose(Image.FLIP_LEFT_RIGHT)
                sheet.paste(fr, (col * 16, (li * 4 + row) * 24))
    return sheet


GUARD_TABARDS = [("3a6a3a", "5a8a54", "2a4a2a"), ("3a4a8a", "5a6aaa", "2a3460"), ("8a3a32", "aa5a4a", "5a2420"),
                 ("3a6a7a", "5a8a9a", "2a4a58"), ("5a5a2a", "7a7a44", "3e3e1a")]


def npc_sheet():
    """The villagers -- now drawn seen from above, like the hero, to sit in the
    3D view (tools/make_hero_tilt.py npc_sheet: the same people, colours and
    layout). The eye-level version is npc_sheet_flat()."""
    import make_hero_tilt
    return make_hero_tilt.npc_sheet()


def npc_sheet_flat():
    rnd = random.Random(5)
    looks = []
    for i in range(10):
        looks.append(person_look(SKINS[rnd.randrange(len(SKINS))], HAIRS[i % len(HAIRS)],
                                 TUNICS[(i * 3) % len(TUNICS)],
                                 pants=["3c3550", "4a3a2a", "3a4a3a", "5a4a3a"][i % 4]))
    for t in GUARD_TABARDS:
        steel = {"R": "9aa3b5", "H": "d0d8e6", "h": "f4f8ff", "r": "6a7286", "d": "454b5c"}
        looks.append(person_look(SKINS[rnd.randrange(2)], HAIRS[0], (t[0], t[1], t[2], "454b5c"),
                                 pants="454b5c", pants_dk="2e3240", extra_head=steel,
                                 extra_body={"C": "8d96a8", "c": "5a6274"}))
    # shopkeeper (an apron), sage (violet robe and hood), innkeeper
    looks.append(person_look(SKINS[1], HAIRS[3], TUNICS[3], extra_body={"C": "e8dfc8", "c": "b8ae99"}))
    looks.append(person_look(SKINS[0], ("5a3e8a", "7e5ab8", "a07ad8", "3a2660"), ("5a3e8a", "7e5ab8", "3a2660", "2a1a48"),
                             pants="3a2660", pants_dk="2a1a48", extra_head={"N": "e8e8f0", "n": "b0b0c0"},
                             extra_body={"C": "4a3270", "c": "3a2660"}))
    looks.append(person_look(SKINS[2], HAIRS[5], TUNICS[1], extra_body={"C": "c8b898", "c": "a09070"}))
    looks.append(person_look(SKINS[0], HAIRS[2], TUNICS[2]))
    looks.append(person_look(SKINS[3], HAIRS[1], TUNICS[4]))
    return person_sheet(looks, spears=range(10, 15))


RUBY_ICON = [
    "................",
    "................",
    "......KKKK......",
    ".....KhWRRK.....",
    "....KhWRRRrK....",
    "...KRRRRRRrrK...",
    "...KKKKKKKKKK...",
    "...KRhRRRRrrK...",
    "....KRRRRrrK....",
    ".....KRRrrK.....",
    "......KRrK......",
    ".......KK.......",
    "................",
    "....s......s....",
    "................",
    "................",
]


def ruby_icon():
    pal = dict(make_art.PAL, K="4a0a16", R="e0283c", r="9a1424", h="ffb0b8", W="ffffff", s="ffd0d8")
    return make_art.grid_to_image(RUBY_ICON, pal)


def extend_items():
    """Adds the ruby (27) and the storm lantern (28) to assets/items.png."""
    full = Image.open(OUT / "items.png").convert("RGBA")
    base = full.crop((0, 0, 27 * 16, 16))
    tail = full.crop((29 * 16, 0, full.width, 16)) if full.width > 29 * 16 else None   # the tools (29+)
    icons = [ruby_icon(), make_art.lantern_icon("5a6a7a", "333e4a", "d8ecff", "ffe08a", "f5a33a")]
    sheet = Image.new("RGBA", (base.width + 16 * len(icons), 16), (0, 0, 0, 0))
    sheet.paste(base, (0, 0))
    for i, ic in enumerate(icons):
        sheet.paste(ic, (base.width + i * 16, 0))
    if tail is not None:
        wide = Image.new("RGBA", (sheet.width + tail.width, 16), (0, 0, 0, 0))
        wide.paste(sheet, (0, 0))
        wide.paste(tail, (sheet.width, 0))
        sheet = wide
    sheet.save(OUT / "items.png")


if __name__ == "__main__":
    extend_items()
    village_sheet().save(OUT / "village.png")
    npc_sheet().save(OUT / "npcs.png")
    print("wrote village.png and npcs.png")
