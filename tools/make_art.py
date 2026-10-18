"""Generates the game's pixel art as PNG sprite sheets.

Run from the project folder:  python3 tools/make_art.py
Needs Pillow (pip install pillow). Output goes to assets/.

Every sprite is hand-placed pixels written as text grids below, so the art can
be tweaked here and regenerated, or the PNGs can be repainted in any pixel
editor (Aseprite, Piskel, LibreSprite) as long as the layout stays the same.
"""
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets"

# ---------------------------------------------------------------------------
# Shared palette (letters used in the grids below; "." = transparent)
# ---------------------------------------------------------------------------
PAL = {
    "K": "1a1022",  # outline
    # red hood
    "R": "c0393f", "H": "ec6a5c", "r": "862636", "d": "561a2a",
    # skin, face
    "S": "f6dcc0", "s": "d9a98a", "P": "ef8f8f", "E": "20142a", "W": "ffffff",
    # hair
    "N": "5b3426", "n": "3b2019",
    # clothes, boots
    "C": "3a3352", "c": "262036", "B": "6b4630", "b": "422a1e",
    # lantern
    "M": "2a2430", "Y": "ffe08a", "y": "f5a33a",
    # ghost
    "G": "dcd7f0", "g": "a49ec6", "w": "ffffff", "p": "ff5a6a",
    # demons: skin (k/h, recoloured per demon), horns, mouth
    "x": "b8ad9e", "k": "3f3339", "h": "6b5862", "m": "b0182c",
    "D": "4f1828", "O": "cbb89c", "T": "f2ead8", "Z": "ffcf3f",
    # insect
    "I": "2a2640", "i": "4a4670", "j": "8d88c0", "X": "ff3b4d",
    # moth wings
    "A": "8b7d6b", "a": "5e5345",
    # bone mask
    "F": "e8dfc8", "f": "b0a58c",

}


def grid_to_image(rows, pal=PAL):
    h, w = len(rows), len(rows[0])
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        assert len(row) == w, f"row {y} is {len(row)} wide, expected {w}: {row!r}"
        for x, ch in enumerate(row):
            if ch != ".":
                img.putpixel((x, y), tuple(int(pal[ch][i:i + 2], 16) for i in (0, 2, 4)) + (255,))
    return img


# ---------------------------------------------------------------------------
# HERO  (16 x 24 frames; rows: down, up, left, right; cols: stand, step A, step B)
# ---------------------------------------------------------------------------
HERO_PAL = {
    "K": "1c1020",
    "R": "b8343c", "H": "e2574f", "h": "f59a78", "r": "8a2433", "d": "5a1828",
    "S": "f6d7b8", "s": "d9a283", "P": "f0908a", "E": "1f1530", "W": "ffffff",
    "N": "7a4630", "n": "4d2a1e",
    "B": "8a5a36", "b": "5e3b25", "L": "b88250", "U": "7f90ad", "u": "4f5a75",
    "C": "3c3550", "c": "28223a", "O": "6a4430", "o": "3a2418",
    "G": "e8b850", "M": "3a3240", "Y": "ffe9a0", "y": "f5a33a",
}

HERO_DOWN = [
    "................",
    ".....KKKKKK.....",
    "...KKhHHRRRKK...",
    "..KhHHRRRRRRrK..",
    ".KhHRRRRRRRRrrK.",
    ".KHRRRRRRRRRRrK.",
    "KHRRRKKKKKKRRrrK",
    "KRRKKnNNNNnKKrrK",
    "KRKnNNNnNNNNnKrK",
    "KRKNNnSSSSnNNKrK",
    "KrKNSSSSSSSSNKdK",
    "KrKSSEESSEESSKdK",
    "KrKSSEWSSEWSSKdK",
    ".KKPSSSSSSSSPKK.",
    "..KKsSSssSSsKK..",
    "..KRRrddddrRRK..",
    ".KHRRrCCCCrRRrK.",
    ".KHRRbbGGbbRRrK.",
    "KSKRrCCCCCCrRKSK",
    "KKKrdCCCCCCdrKMK",
]
LEGS_DOWN = {
    "stand": ["..KdKCCKKCCKdKYK", "....KccK.KccK.yK", "....KOOK.KOOK.K.", "....KKKK.KKKK..."],
    "a":     ["..KdKCCKKCCKdKYK", "....KOOK.KccK.yK", "....KKKK.KOOK.K.", ".........KKKK..."],
    "b":     ["..KdKCCKKCCKdKYK", "....KccK.KOOK.yK", "....KOOK.KKKK.K.", "....KKKK........"],
}
HERO_UP = [
    "................",
    ".....KKKKKK.....",
    "...KKRRHHRRKK...",
    "..KRRRHHhHRRrK..",
    ".KRRRRRHHRRRrrK.",
    ".KRRRRRRRRRRRrK.",
    "KRRRRRRRRRRRRrrK",
    "KRRRRRRRRRRRRrrK",
    "KRrRRRRRRRRRrrrK",
    "KRrKKKKKKKKKKrdK",
    "KrKuUUUUUUUUuKdK",
    "KrKUUuUUUUuUUKdK",
    "KrKKBBBBBBBBKKdK",
    ".KKBLLBBBBBBbKK.",
    "..KBLBBBBBBBbK..",
    ".KRKBBBGGBBBbKRK",
    ".KRKBBBBBBBBbKrK",
    ".KRKbBBBBBBbbKrK",
    "KSKRKbbbbbbKrKSK",
    "KMKdrKKKKKKrdKKK",
]
LEGS_UP = {
    "stand": ["KYKdKCCKKCCKdK..", "KyK.KccK.KccK...", ".K..KOOK.KOOK...", "....KKKK.KKKK..."],
    "a":     ["KYKdKCCKKCCKdK..", "KyK.KOOK.KccK...", ".K..KKKK.KOOK...", ".........KKKK..."],
    "b":     ["KYKdKCCKKCCKdK..", "KyK.KccK.KOOK...", ".K..KOOK.KKKK...", "....KKKK........"],
}
HERO_RIGHT = [
    "................",
    "....KKKKKK......",
    "..KKhHHRRRKK....",
    ".KhHHRRRRRRrK...",
    ".KHRRRRRRRRRrK..",
    "KHRRRRRRKKKKKK..",
    "KRRRRRRKnNNNNnK.",
    "KRRRRRKnNNNNNNNK",
    "KRrRRRKNNSSSSSNK",
    "KrrRRRKNSSSSESSK",
    "KrrRRRKNSSSSEWSK",
    "KrdRRRKKSSSPSSSK",
    "KBdrRRRKsSSSSSK.",
    "KBBdrrRKKsssKK..",
    "KBLBdrrrKKKK....",
    "KBLBKRRRRRrK....",
    "KBBBKRRRRrrK....",
    "KbBBKGRRRrKSK...",
    "KbbbKCRRrrKMK...",
    ".KKKKdrrrdKYK...",
]
LEGS_RIGHT = {
    "stand": ["....KCCCCK.yK...", "....KcCCcK.KK...", "....KOOOOOK.....", "....KKKKKKK....."],
    "a":     ["...KCCKKCCKyK...", "..KccK..KccKK...", ".KOOK....KOOK...", ".KKKK....KKKK..."],
    "b":     ["....KCCCKKyK....", ".....KcCKKK.....", ".....KOOOK......", ".....KKKKK......"],
}


# Armour looks. Each maps hood (head rows), body and leg letters to new
# colours; a (c1, c2) pair is a checker pattern (chainmail); "ribs" alternates
# by row. Unlisted letters keep the base palette.
ARMOR_LOOKS = [
    ("none", {   # no armour: the hood comes off, hair and a plain blue tunic
        "head": {"R": "6b3d2a", "H": "8a5236", "h": "a8683f", "r": "4d2a1e", "d": "3a1f16"},
        "body": {"R": "5b6e8c", "H": "7d90ad", "r": "3e4c66", "d": "2b3548"},
        "legs": {}}),
    ("worn_cloak", {"head": {}, "body": {}, "legs": {}}),
    ("leather_vest", {
        "head": {},
        "body": {"R": "8a5a32", "H": "b07a48", "r": "5e3b22", "d": "3e2616", "C": "7a4a2a", "c": "4f2f1c"},
        "legs": {"O": "4f2f1c"}}),
    ("chain_shirt", {
        "head": {},
        "body": {"R": ("8d96a8", "6b7385"), "H": ("b5bdcc", "8d96a8"), "r": ("5a6274", "434a5a"),
                 "d": ("3a4050", "2c313d"), "C": ("7c8598", "5a6274"), "c": ("4a5162", "383e4c")},
        "legs": {}}),
    ("bone_mail", {
        "head": {"R": "4a4252", "H": "6a6176", "h": "8a8196", "r": "352f3d", "d": "241f2a"},
        "body": {"R": "e8dfc8", "H": "fff6e0", "r": "b0a58c", "d": "7a705c", "C": "ribs", "c": "2a2430"},
        "legs": {"O": "3a3440"}}),
    ("iron_plate", {
        "head": {"R": "9aa3b5", "H": "d0d8e6", "h": "f4f8ff", "r": "6a7286", "d": "454b5c"},
        "body": {"C": "aab3c4", "c": "6a7286", "b": "6a7286"},
        "legs": {"C": "8d96a8", "c": "5a6274", "O": "6a7286", "o": "454b5c"}}),
]


def _look_frame(rows, look):
    img = Image.new("RGBA", (16, 24), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        region = "head" if y < 15 else ("body" if y < 20 else "legs")
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            col = look[region].get(ch, HERO_PAL[ch])
            if col == "ribs":
                col = "e8dfc8" if y % 2 == 0 else "2a2430"
            elif isinstance(col, tuple):
                col = col[(x + y) % 2]
            img.putpixel((x, y), tuple(int(col[i:i + 2], 16) for i in (0, 2, 4)) + (255,))
    return img


# --- Animation -----------------------------------------------------------------
# 9 columns: 0 stand, 1-4 walk (contact, pass, contact, pass), 5-8 run.
# Each frame is the standing pose with the arms and legs moved: the arms
# swing opposite the legs, the lantern swinging with its hand; running pumps
# the arms harder, lifts the knees higher and (from the side) leans forward.
#                 (left arm, right arm, left leg lift, right leg lift)
WALK = [(-1, 1, 1, 0), (0, 0, 0, 0), (1, -1, 0, 1), (0, 0, 0, 0)]
RUN = [(-2, 2, 2, 0), (-1, 1, 1, 1), (2, -2, 0, 2), (1, -1, 1, 1)]
SIDE_ARM = {"stand": 0, "walk": [1, 0, -1, 0], "run": [2, 0, -2, 0]}
SIDE_LEGS = {
    "stand": ["....KCCCCK......", "....KcCCcK......", "....KOOOOOK.....", "....KKKKKKK....."],
    "walk": [
        ["...KCCKKCCK.....", "..KccK..KCCK....", ".KOOK....KOOOK..", ".KKKK....KKKKK.."],
        ["....KCCCKK......", ".....KcCKK......", ".....KOOOK......", ".....KKKKK......"],
        ["...KCCKKccK.....", "..KCCK..KccK....", ".KOOK....KOOOK..", ".KKKK....KKKKK.."],
        ["....KCCCKK......", ".....KCCKK......", ".....KOOOK......", ".....KKKKK......"],
    ],
    "run": [
        ["..KKCCCKKCCK....", ".KOOKcK...KCCK..", ".KKKKK.....KOOK.", "...........KKKK."],
        ["....KCCCCCK.....", "...KOOKKCCK.....", "...KKKKKOOK.....", "........KKK....."],
        ["..KKccCKKCCK....", ".KOOKCK...KccK..", ".KKKKK.....KOOK.", "...........KKKK."],
        ["....KCCCCCK.....", "....KCCKOOK.....", "....KOOKKKK.....", "....KKK........."],
    ],
}


def _g(rows):
    return [list(r) for r in rows]


def _set(g, x, y, ch):
    if 0 <= y < len(g) and 0 <= x < 16:
        g[y][x] = ch


def _front_legs(g, lift_l, lift_r):
    """Down / up views: each leg (rows 21-23) rises by its lift."""
    for (x0, lift) in ((4, lift_l), (9, lift_r)):
        leg = ["KccK", "KOOK", "KKKK"]
        for y in range(20 if lift >= 2 else 21, 24):
            for i in range(4):
                if y >= 21:
                    _set(g, x0 + i, y, ".")
        for k, row in enumerate(leg[min(lift, 1):] if lift < 2 else leg[1:]):
            y = 21 + k - (lift if lift < 2 else 1)
            if lift >= 2:
                y = 20 + k
            for i, ch in enumerate(row):
                _set(g, x0 + i, y, ch)


def _down_arms(g, s_l, s_r, view):
    """Swing the arms. In the down view the lantern hangs from the right
    hand; from behind (up view) it's on the left of the screen."""
    if view == "down":
        lantern_side, free_x, lant_x = "right", 0, 13
        # erase both arms (keep the cloak's outline)
        for y in range(16, 24):
            for x in (0, 1):
                if y <= 20:
                    _set(g, x, y, ".")
            for x in (14, 15):
                _set(g, x, y, ".")
        for y in range(16, 20):
            _set(g, 2, y, "K")
        for y in (18, 19):
            _set(g, 13, y, "K")
        # left (free) arm
        hand = 18 + s_l
        for y in range(16, hand):
            _set(g, 1, y, "K")
            _set(g, 2, y, "H")
        _set(g, 0, hand, "K"); _set(g, 1, hand, "S"); _set(g, 2, hand, "K")
        for x in (0, 1, 2):
            _set(g, x, hand + 1, "K")
        # right arm with the lantern
        hand = 18 + s_r
        for y in range(16, hand):
            _set(g, 13, y, "r")
            _set(g, 14, y, "K")
        _set(g, 13, hand, "K"); _set(g, 14, hand, "S"); _set(g, 15, hand, "K")
        for k, row in enumerate(["KMK", "KYK", ".yK", ".K."]):
            for i, ch in enumerate(row):
                if ch != ".":
                    _set(g, 13 + i, hand + 1 + k, ch)
    else:   # up view: mirror image -- lantern on the left, free hand on the right
        for y in range(15, 24):
            for x in (0, 1, 2):
                if y <= 22:
                    _set(g, x, y, ".")
            for x in (14, 15):
                if y <= 19:
                    _set(g, x, y, ".")
        for y in range(15, 20):
            _set(g, 13, y, "K")
        for y in range(15, 18):
            _set(g, 3, y, "K")
        hand = 18 + s_l
        for y in range(15, hand):
            _set(g, 1, y, "K"); _set(g, 2, y, "R")
        _set(g, 0, hand, "K"); _set(g, 1, hand, "S"); _set(g, 2, hand, "K")
        for k, row in enumerate(["KMK", "KYK", "KyK", ".K."]):
            for i, ch in enumerate(row):
                if ch != ".":
                    _set(g, i, hand + 1 + k, ch)
        hand = 18 + s_r
        for y in range(15, hand):
            _set(g, 14, y, "R" if y == 15 else "r"); _set(g, 15, y, "K")
        _set(g, 13, hand, "K"); _set(g, 14, hand, "S"); _set(g, 15, hand, "K")
        for x in (13, 14, 15):
            _set(g, x, hand + 1, "K")


def _side_frame(top, legs, arm_dx, lean):
    g = _g(top + legs)
    # take the hand and lantern off, then put them back swung forward / back
    for y in range(17, 22):
        for x in (11, 12):
            if not (y in (17, 18, 19) and x == 10):
                _set(g, x, y, ".")
    hx = 11 + arm_dx
    _set(g, hx - 1, 17, "K"); _set(g, hx, 17, "S"); _set(g, hx + 1, 17, "K")
    for y, ch in ((18, "M"), (19, "Y")):
        _set(g, hx - 1, y, "K"); _set(g, hx, y, ch); _set(g, hx + 1, y, "K")
    _set(g, hx, 20, "y"); _set(g, hx + 1, 20, "K")
    _set(g, hx, 21, "K"); _set(g, hx + 1, 21, "K")
    if lean:   # running: the upper body tips forward a pixel
        for y in range(0, 20):
            g[y] = ["."] + g[y][:15]
    return g


def hero_frames(view):
    """All 9 frames (as char grids) for one view: down / up / right."""
    out = []
    if view in ("down", "up"):
        top = HERO_DOWN if view == "down" else HERO_UP
        legs = LEGS_DOWN if view == "down" else LEGS_UP
        for key, spec in [("stand", (0, 0, 0, 0))] + [("walk", w) for w in WALK] + [("run", r) for r in RUN]:
            g = _g(top + legs["stand"])
            _front_legs(g, spec[2], spec[3])
            _down_arms(g, spec[0], spec[1], view)
            out.append(g)
    else:
        out.append(_side_frame(HERO_RIGHT, SIDE_LEGS["stand"], 0, False))
        for i in range(4):
            out.append(_side_frame(HERO_RIGHT, SIDE_LEGS["walk"][i], SIDE_ARM["walk"][i], False))
        for i in range(4):
            out.append(_side_frame(HERO_RIGHT, SIDE_LEGS["run"][i], SIDE_ARM["run"][i], True))
    return [["".join(r) for r in g] for g in out]


HERO_COLS = 9


# Player 2: the red hood and cloak turned deep blue.
P2_CLOTHES = {"b8343c": "3a5cc0", "e2574f": "5a86e8", "f59a78": "8ab8ff", "8a2433": "283c8a", "5a1828": "18245a"}


def recolor(path, mapping):
    img = Image.open(path).convert("RGBA")
    px = img.load()
    swap = {tuple(int(k[i:i + 2], 16) for i in (0, 2, 4)): tuple(int(v[i:i + 2], 16) for i in (0, 2, 4))
            for k, v in mapping.items()}
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in swap:
                px[x, y] = swap[(r, g, b)] + (a,)
    return img


def blue_lantern_sheet(path):
    """The same hero, but the lantern's glass burns blue (blue berries)."""
    img = Image.open(path).convert("RGBA")
    px = img.load()
    swap = {(0xff, 0xe9, 0xa0): (0xc8, 0xe0, 0xff), (0xf5, 0xa3, 0x3a): (0x4a, 0x7c, 0xf5)}
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in swap:
                px[x, y] = swap[(r, g, b)] + (a,)
    return img


def hero_sheet():
    """The hero's sheet -- now drawn seen from above, to sit in the 3D view
    (tools/make_hero_tilt.py; same layout). The eye-level version that was
    here is hero_sheet_flat()."""
    import make_hero_tilt
    return make_hero_tilt.hero_sheet()


def hero_sheet_flat():
    """9 columns (stand, walk x4, run x4) x 4 rows (down, up, left, right) per
    armour look, looks stacked top to bottom in ARMOR_LOOKS order."""
    sheet = Image.new("RGBA", (16 * HERO_COLS, 24 * 4 * len(ARMOR_LOOKS)), (0, 0, 0, 0))
    views = [("down", False), ("up", False), ("right", True), ("right", False)]
    frames = {v: hero_frames(v) for v in ("down", "up", "right")}
    for li, (_, look) in enumerate(ARMOR_LOOKS):
        for row, (view, mirror) in enumerate(views):
            for col, grid in enumerate(frames[view]):
                frame = _look_frame(grid, look)
                if mirror:
                    frame = frame.transpose(Image.FLIP_LEFT_RIGHT)
                sheet.paste(frame, (col * 16, (li * 4 + row) * 24))
    return sheet


# ---------------------------------------------------------------------------
# GEAR: weapons as worn on the back (16 x 16, diagonal: butt at bottom-left,
# business end at top-right). Order matches HeroLook.WEAPONS.
# ---------------------------------------------------------------------------
def _diag(img, i, col, off=(0, 0)):
    x, y = 2 + i + off[0], 13 - i + off[1]
    if 0 <= x < 16 and 0 <= y < 16:
        img.putpixel((x, y), tuple(int(col[k:k + 2], 16) for k in (0, 2, 4)) + (255,))


def _px(img, x, y, col):
    if 0 <= x < 16 and 0 <= y < 16:
        img.putpixel((x, y), tuple(int(col[k:k + 2], 16) for k in (0, 2, 4)) + (255,))


def gear_weapon(kind):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    K = "1c1020"
    WOOD, WOOD_D = "8a5e3c", "5a3a24"
    STEEL, STEEL_D, STEEL_H = "aab3c4", "6a7286", "eef4ff"
    if kind == "rusty_dagger":
        for i in range(0, 3):
            _diag(img, i, WOOD_D)
        _diag(img, 3, STEEL_D, (-1, -1)); _diag(img, 3, STEEL_D, (1, 1)); _diag(img, 3, STEEL_D)
        for i in range(4, 9):
            _diag(img, i, "a08a70" if i % 3 == 0 else STEEL)
            _diag(img, i, STEEL_D, (1, 0))
        _diag(img, 9, STEEL_H)
    elif kind == "bone_club":
        for i in range(0, 10):
            _diag(img, i, "e8dfc8")
            _diag(img, i, "b0a58c", (1, 0))
        for (dx, dy) in [(-1, -1), (1, 1), (0, -1)]:
            _diag(img, 0, "e8dfc8", (dx, dy)); _diag(img, 10, "fff6e0", (dx, dy))
    elif kind == "hatchet":
        for i in range(0, 11):
            _diag(img, i, WOOD)
            _diag(img, i, WOOD_D, (1, 0))
        # axe head on the outer side near the top
        for (x, y) in [(11, 5), (12, 6), (13, 7), (11, 6), (12, 7), (10, 6), (11, 7), (12, 8), (13, 8), (14, 7)]:
            _px(img, x, y, STEEL)
        for (x, y) in [(14, 8), (13, 9), (12, 9)]:
            _px(img, x, y, STEEL_D)
        _px(img, 14, 6, STEEL_H)
    elif kind == "hooked_sickle":
        for i in range(0, 6):
            _diag(img, i, WOOD)
            _diag(img, i, WOOD_D, (1, 0))
        for (x, y) in [(8, 6), (9, 5), (10, 4), (11, 3), (12, 3), (13, 3), (14, 4), (14, 5), (13, 6)]:
            _px(img, x, y, STEEL)
        for (x, y) in [(9, 6), (10, 5), (11, 4), (12, 4), (13, 4)]:
            _px(img, x, y, STEEL_D)
        _px(img, 12, 2, STEEL_H)
    elif kind == "iron_mace":
        for i in range(0, 9):
            _diag(img, i, "4a4252")
            _diag(img, i, "2a2430", (1, 0))
        cx, cy = 12, 3
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                if dx * dx + dy * dy <= 5:
                    _px(img, cx + dx, cy + dy, STEEL if dx + dy < 1 else STEEL_D)
        for (x, y) in [(12, 0), (15, 3), (9, 3), (14, 1), (14, 5)]:
            _px(img, x, y, STEEL_H)
        _px(img, 11, 2, STEEL_H)
    elif kind == "grave_blade":
        _diag(img, -1, "b06cff")
        for i in range(0, 3):
            _diag(img, i, "3a2a4a")
        for d in (-2, -1, 0, 1, 2):
            _diag(img, 3, "8a8196" if d else "c08aff", (d, d))
        for i in range(4, 13):
            _diag(img, i, STEEL_H if i % 4 == 0 else STEEL)
            _diag(img, i, "b06cff", (1, 0))
            _diag(img, i, STEEL_D, (0, -1)) if i < 12 else None
        _diag(img, 13, STEEL_H)
    return img


def _gear_outline(img, col="1c1020"):
    out = img.copy()
    w, h = img.size
    px = img.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3]:
                continue
            for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
                if 0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3]:
                    out.putpixel((x, y), tuple(int(col[k:k + 2], 16) for k in (0, 2, 4)) + (255,))
                    break
    return out


BAG_ICON = [
    "................",
    ".....KKKKKK.....",
    "....KbK..KbK....",
    "....Kb....bK....",
    "..KKKKKKKKKKKK..",
    ".KLLLLLLLLLLLLK.",
    ".KLBBBBBBBBBBbK.",
    ".KBBBBBGGBBBBbK.",
    ".KKKKKKGGKKKKKK.",
    ".KBBBBBBBBBBBbK.",
    ".KBBBBBBBBBBBbK.",
    ".KBBBBBBBBBBBbK.",
    ".KbBBBBBBBBBbbK.",
    ".KbbbbbbbbbbbbK.",
    "..KKKKKKKKKKKK..",
    "................",
]


# ---------------------------------------------------------------------------
# SPRITES: floating flames with faces (16 x 16, 2 flicker frames each).
#   o outer flame, f flame, c hot core, E eyes, M mouth, B blush
# ---------------------------------------------------------------------------
WISP_SHAPES = {
    "round": [[
        "................",
        ".......o........",
        "......ofo.......",
        ".....offo..o....",
        "....offfo.ofo...",
        "...offffoofffo..",
        "..offfcccfffffo.",
        "..offccccccffo..",
        ".offcEccccEcffo.",
        ".offcEccccEcffo.",
        ".offBccMMccBffo.",
        "..offccccccffo..",
        "..offfccccfffo..",
        "...offfffffo....",
        ".....ooooo......",
        "................",
    ], [
        "................",
        "........o.......",
        ".......ofo......",
        "...o..offo......",
        "..ofo.offfo.....",
        "..offoofffffo...",
        ".offfffcccffo...",
        "..offccccccffo..",
        ".offcEccccEcffo.",
        ".offcEccccEcffo.",
        ".offBccMMccBffo.",
        "..offccccccffo..",
        "..offfccccfffo..",
        "....offffffo....",
        ".....ooooo......",
        "................",
    ]],
    "tall": [[
        ".......o........",
        "......ofo.......",
        "......ofo.......",
        ".....offfo......",
        ".....offfo..o...",
        "....offcffoofo..",
        "....ofcccfffo...",
        "...offccccffo...",
        "...ofEccEcffo...",
        "...ofEccEcffo...",
        "...offcMMcffo...",
        "...offccccffo...",
        "....offccffo....",
        "....offfffo.....",
        ".....ooooo......",
        "................",
    ], [
        "........o.......",
        ".......ofo......",
        ".......ofo......",
        "......offfo.....",
        "..o...offfo.....",
        ".ofooffcffo.....",
        "..offfcccfo.....",
        "...offccccffo...",
        "...ofEccEcffo...",
        "...ofEccEcffo...",
        "...offcMMcffo...",
        "...offccccffo...",
        "....offccffo....",
        ".....offfffo....",
        ".....ooooo......",
        "................",
    ]],
    "twin": [[
        "................",
        "...o.......o....",
        "..ofo.....ofo...",
        "..offo...offo...",
        "..offfo.offfo...",
        "...offfofffo....",
        "..offfccccfo....",
        ".offccccccffo...",
        ".ofcEEccEEcfo...",
        ".ofcEWccEWcfo...",
        ".offccMMccffo...",
        "..offcccccfo....",
        "...offfffffo....",
        "....ooooooo.....",
        "................",
        "................",
    ], [
        "................",
        "....o.......o...",
        "...ofo.....ofo..",
        "...offo...offo..",
        "...offfo.offfo..",
        "....offfofffo...",
        "...offfccccfo...",
        "..offccccccffo..",
        ".ofcEEccEEcfo...",
        ".ofcEWccEWcfo...",
        ".offccMMccffo...",
        "..offcccccfo....",
        "...offfffffo....",
        "....ooooooo.....",
        "................",
        "................",
    ]],
}
# name, shape, (outer, flame, core)
WISP_KINDS = [
    ("round", ("2a6ad0", "5fb4ff", "e6f6ff")),   # blue
    ("tall", ("2f9a4a", "7fe88a", "efffe0")),    # green
    ("twin", ("7a3ac8", "c08aff", "fbeaff")),    # violet
    ("round", ("c8781a", "ffc04a", "fff6c8")),   # gold
    ("tall", ("c83a6a", "ff8ab4", "fff0f4")),    # rose
    ("twin", ("1a8a8a", "5fe8d8", "eafffa")),    # teal
]


def wisp_sheet():
    sheet = Image.new("RGBA", (16 * 2, 16 * len(WISP_KINDS)), (0, 0, 0, 0))
    for row, (shape, (o, f, c)) in enumerate(WISP_KINDS):
        pal = {"o": o, "f": f, "c": c, "E": "1a1022", "W": "ffffff", "M": "6a1a3a", "B": "ff9ab0"}
        for col, grid in enumerate(WISP_SHAPES[shape]):
            sheet.paste(grid_to_image(grid, pal), (col * 16, row * 16))
    return sheet


def gear_sheet():
    kinds = ["rusty_dagger", "bone_club", "hatchet", "hooked_sickle", "iron_mace", "grave_blade"]
    sheet = Image.new("RGBA", (16 * len(kinds), 16), (0, 0, 0, 0))
    for i, k in enumerate(kinds):
        sheet.paste(_gear_outline(gear_weapon(k)), (i * 16, 0))
    return sheet


# ---------------------------------------------------------------------------
# ENEMY STYLE PREVIEW (16 x 16 each): ghost, demon, insect
# ---------------------------------------------------------------------------
GHOST = [
    "................",
    ".....KKKKKK.....",
    "...KKGGGGGGKK...",
    "..KGGwwGGGGGgK..",
    "..KGwGGGGGGGgK..",
    ".KGGGEEGGEEGGgK.",
    ".KGGEEEGGEEEGgK.",
    ".KGGEpEGGEpEGgK.",
    ".KGGEEEGGEEEGgK.",
    ".KGGGGGGGGGGGgK.",
    ".KGGGGGEEGGGggK.",
    ".KgGGGEEEEGGggK.",
    ".KgGGGGEEGGGggK.",
    ".KggGGgGGGgGggK.",
    ".KgK.KgKKgK.KgK.",
    "..K...K..K...K..",
]
INSECT = [
    "................",
    "...K........K...",
    "....K......K....",
    ".....KKKKKK.....",
    "....KiXiiXiK....",
    "K..KiiXiiXiiK..K",
    ".KKKKKKKKKKKKKK.",
    "...KIjIIKIIIIK..",
    "KKKIjIIIKIIIIIKK",
    "...KIIIIKIIIIK..",
    "KKKIIIIIKIIIIIKK",
    "...KIIIIKIIIIK..",
    "....KIIIKIIIK...",
    ".....KKKKKKK....",
    "....K.....K.....",
    "...K.......K....",
]


SPIDER = [
    "................",
    "..K..........K..",
    "...K..KKKK..K...",
    ".K..KKIIIIKK..K.",
    "..KKIiiIIiiIKK..",
    "K..KIIIIIIIIK..K",
    ".KKKIXIXXIXIKKK.",
    "...KIIXIIXIIK...",
    "KKKKIIIIIIIIKKKK",
    "...KIjIIIIiIK...",
    ".KKKIIjIIIIIKKK.",
    "K...KIIIIIIK...K",
    "...K.KKTTKK.K...",
    "..K...KKKK...K..",
    ".K............K.",
    "................",
]
MOTH = [
    "................",
    "......K..K......",
    ".......KK.......",
    ".KKK..KTTK..KKK.",
    "KAAaK.KTTK.KaAAK",
    "KAZZAKKIIKKAZZAK",
    "KAZXAAKIIKAAXZAK",
    "KAZZAAKIIKAAZZAK",
    "KaAAAaKIIKaAAAaK",
    ".KaaaKKIIKKaaaK.",
    "..KAAaKIIKaAAK..",
    "..KAXAKIIKAXAK..",
    "...KaAKIIKAaK...",
    "....KK.KK.KK....",
    "................",
    "................",
]


# DEMONS: humanoid horror, same 16 x 24 size as the hero.
# Grinner (all mouth), Many-Eyes (eyes everywhere), Wraith (horns, fangs, claws)
GRINNER = [
    "................",
    "................",
    ".....KKKKKK.....",
    "....KkhhkkkK....",
    "...KkhkkkkkkK...",
    "...KkWKkkKWkK...",
    "..KkkkkkkkkkkK..",
    "..KKKKKKKKKKKK..",
    "..KTTTTTTTTTTK..",
    "..KTDTDDTDDTDK..",
    "..KDDmDDmDDmDK..",
    "..KDTDDTDDTDTK..",
    "..KTTTTTTTTTTK..",
    "...KkKKKKKKkK...",
    "...KKkkkkkkKK...",
    "..KkkkkkkkkkkK..",
    ".KkKkhkkkkkKkkK.",
    ".KkKkhkkkkkKkkK.",
    ".KkKkkkkkkkKkkK.",
    ".KkKkkkkkkkKkkK.",
    ".KTKKkkKkkkKKTK.",
    ".T.TKkkKKkkKT.T.",
    "....KKK..KKK....",
    "................",
]
MANY_EYES = [
    "................",
    "................",
    "................",
    "......KKKK......",
    "....KKkkkkKK....",
    "...KkZKkkkkkK...",
    "..KkkkkkkKXkkK..",
    "..KkXKkkkkkZkK..",
    ".KkkkkkZKkkkkkK.",
    ".KkZKkkkkkkXKkK.",
    ".KkkkKKKKKKkkkK.",
    ".KkkKTKTKTKKkkK.",
    ".KkkKmmmmmmKZKK.",
    ".KkkKTKTKTKKkkK.",
    ".KkXKKKKKKKkkkK.",
    "KkkkkkkZKkkkkkkK",
    "KkKkkkkkkkkXKKkK",
    "KkKkZKkkkkkkkKkK",
    "KTKkkkkkkXKkkKTK",
    ".T.KkkkkkkkkkK.T",
    "...KkkKKKKkkK...",
    "...KTTK..KTTK...",
    "....KK....KK....",
    "................",
]
WRAITH = [
    "KK............KK",
    "KxK..........KxK",
    "KxxK........KxxK",
    ".KxxK..KK..KxxK.",
    "..KxxKKkkKKxxK..",
    "...KKkhkkkkKK...",
    "...KkKKkkKKkK...",
    "...KkKXkkXKkK...",
    "...KkKKkkKKkK...",
    "...KkkkKKkkkK...",
    "...KKTKTTKTKK...",
    "...KTDDDDDDTK...",
    "...KTDmDDmDTK...",
    "...KDDDDDDDDK...",
    "...KKTKTTKTKK...",
    "..KKkKKKKKKkKK..",
    ".KkkkhkkkkkkkkK.",
    "KkKkhkkkkkkkKkK.",
    "KkKkkkkkkkkkKkK.",
    "KTKkkkkkkkkkKTK.",
    "T.TKkkkkkkkkKT.T",
    "...KkK.KK.KkK...",
    "...K.K....K.K...",
    "................",
]
DEMON_SKINS = [
    ("2b2433", "4a4058"),  # Grinner: shadow violet
    ("5a2230", "7e3444"),  # Many-Eyes: raw crimson
    ("3f3339", "6b5862"),  # Wraith: ashen grey
]

# GHOSTS: one design, recoloured. (body, shade, eyes)
GHOST_COLORS = [
    ("dcd7f0", "a49ec6", "ff5a6a"),  # bone white
    ("c2f0cf", "7fbf94", "1a1022"),  # grave green
    ("bfe0ff", "7aa6d6", "ff5a6a"),  # cold blue
    ("e5c6f5", "a87bc9", "ffcf3f"),  # violet
    ("ffc4c4", "d6727f", "1a1022"),  # blood red
]


def insect_sheet():
    """3 insects, 16 x 16 each: beetle, spider, moth."""
    sheet = Image.new("RGBA", (16 * 3, 16), (0, 0, 0, 0))
    for i, g in enumerate([INSECT, SPIDER, MOTH]):
        sheet.paste(grid_to_image(g), (i * 16, 0))
    return sheet


def demon_sheet():
    """3 demons, 16 x 24 each: grinner, many-eyes, wraith."""
    sheet = Image.new("RGBA", (16 * 3, 24), (0, 0, 0, 0))
    for i, g in enumerate([GRINNER, MANY_EYES, WRAITH]):
        k, h = DEMON_SKINS[i]
        sheet.paste(grid_to_image(g, dict(PAL, k=k, h=h)), (i * 16, 0))
    return sheet


def ghost_sheet():
    """The ghost in each colour, 16 x 16 each."""
    sheet = Image.new("RGBA", (16 * len(GHOST_COLORS), 16), (0, 0, 0, 0))
    for i, (body, shade, eyes) in enumerate(GHOST_COLORS):
        pal = dict(PAL, G=body, g=shade, p=eyes)
        sheet.paste(grid_to_image(GHOST, pal), (i * 16, 0))
    return sheet


# ---------------------------------------------------------------------------
# TILES (16 x 16, one row): see TILE_* indices in scripts/world.gd
# ---------------------------------------------------------------------------
import random


def hexc(h, a=255):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def rect(img, x, y, w, h, col):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            if 0 <= xx < 16 and 0 <= yy < 16:
                img.putpixel((xx, yy), hexc(col))


def stone(img, x, y, w, h, base, hi, sh):
    rect(img, x, y, w, h, base)
    rect(img, x, y, w, 1, hi)
    rect(img, x, y, 1, h, hi)
    rect(img, x, y + h - 1, w, 1, sh)
    rect(img, x + w - 1, y, 1, h, sh)
    for cx, cy in [(x, y), (x + w - 1, y), (x, y + h - 1), (x + w - 1, y + h - 1)]:
        img.putpixel((cx, cy), hexc("221e2c"))  # rounded corners


FLOOR = dict(mortar="221e2c", base="4a4458", hi="5e5770", sh="37324a")
FLOOR_LAYOUTS = [
    [(0, 0, 7, 5), (8, 0, 7, 5), (0, 6, 4, 4), (5, 6, 5, 4), (11, 6, 4, 4), (0, 11, 7, 4), (8, 11, 7, 4)],
    [(0, 0, 4, 4), (5, 0, 6, 4), (12, 0, 3, 4), (0, 5, 7, 5), (8, 5, 7, 5), (0, 11, 5, 4), (6, 11, 4, 4), (11, 11, 4, 4)],
    [(0, 0, 7, 5), (8, 0, 7, 5), (0, 6, 6, 4), (7, 6, 8, 4), (0, 11, 4, 4), (5, 11, 10, 4)],
]


def floor_tile(v):
    img = Image.new("RGBA", (16, 16), hexc(FLOOR["mortar"]))
    for (x, y, w, h) in FLOOR_LAYOUTS[v]:
        stone(img, x, y, w, h, FLOOR["base"], FLOOR["hi"], FLOOR["sh"])
    if v == 2:  # crack + a weed in the mortar
        for (x, y) in [(9, 7), (10, 8), (10, 9), (11, 8)]:
            img.putpixel((x, y), hexc("2a2535"))
        for (x, y, c) in [(4, 10, "4f7a55"), (3, 9, "4f7a55"), (5, 9, "3b5a47")]:
            img.putpixel((x, y), hexc(c))
    return img


GRASS = dict(base="34503f", dark="2a4234", tuft="4f7a58", hi="6b9a6e")


def moss_tile(v):
    rnd = random.Random(10 + v)
    img = Image.new("RGBA", (16, 16), hexc(GRASS["base"]))
    for _ in range(14):
        img.putpixel((rnd.randrange(16), rnd.randrange(16)), hexc(GRASS["dark"]))
    for _ in range(3 + v):
        x, y = rnd.randrange(1, 13), rnd.randrange(2, 15)
        for (dx, dy, c) in [(0, 0, "tuft"), (2, 0, "tuft"), (1, 1, "dark"), (0, -1, "hi"), (2, -1, "hi")]:
            img.putpixel((x + dx, y + dy), hexc(GRASS[c]))
    return img


def tall_grass_tile():
    img = moss_tile(1)
    blade_rows = [(-1, [0, 4, 8, 12]), (6, [2, 6, 10, 14])]
    for top, xs in blade_rows:
        for bx in xs:
            # one pointed blade: dark outline, mid fill, light left edge
            shape = [
                "..K..",
                ".KLK.",
                ".KLMK",
                "KLMMK",
                "KLMMK",
                "KLMMK",
                "KMMMK",
                "KKKKK",
            ]
            cols = {"K": "1f3329", "L": "79b07a", "M": "4f8558"}
            for yy, row in enumerate(shape):
                for xx, ch in enumerate(row):
                    if ch != ".":
                        X, Y = (bx - 2 + xx) % 16, top + yy
                        if 0 <= Y < 16:
                            img.putpixel((X, Y), hexc(cols[ch]))
    return img


def water_tile(frame):
    img = Image.new("RGBA", (16, 16), hexc("1c2540"))
    rnd = random.Random(3)
    for _ in range(20):
        img.putpixel((rnd.randrange(16), rnd.randrange(16)), hexc("172036"))
    ripples = [(2, 3, 4), (9, 6, 3), (4, 10, 3), (11, 12, 4)]
    for (x, y, w) in ripples:
        x = (x + frame * 2) % 16
        for i in range(w):
            img.putpixel(((x + i) % 16, y), hexc("3a4d78"))
        img.putpixel(((x + 1) % 16, y - 1), hexc("4f669a"))
    return img


WALL = dict(top="2c2838", top_dk="25212f", top_lt="332e41", ledge="5a5170",
            brick="433c54", brick_hi="564d6b", brick_sh="332d43", mortar="1d1a27", base="17141f")


def wall_top_tile():
    rnd = random.Random(7)
    img = Image.new("RGBA", (16, 16), hexc(WALL["top"]))
    for _ in range(18):
        img.putpixel((rnd.randrange(16), rnd.randrange(16)), hexc(rnd.choice([WALL["top_dk"], WALL["top_lt"]])))
    return img


def wall_face_tile(v):
    img = Image.new("RGBA", (16, 16), hexc(WALL["mortar"]))
    rect(img, 0, 0, 16, 2, WALL["top"])
    rect(img, 0, 2, 16, 1, WALL["ledge"])
    for r, y in enumerate([3, 7, 11]):
        off = 0 if r % 2 == 0 else -4
        x = off
        while x < 16:
            w = 7
            stone_x, stone_w = max(x, 0), min(x + w, 16) - max(x, 0)
            if stone_w > 0:
                rect(img, stone_x, y, stone_w, 3, WALL["brick"])
                rect(img, stone_x, y, stone_w, 1, WALL["brick_hi"])
                rect(img, stone_x, y + 2, stone_w, 1, WALL["brick_sh"])
            x += w + 1
    rect(img, 0, 15, 16, 1, WALL["base"])
    if v == 1:  # broken brick, dark hole
        rect(img, 9, 7, 4, 3, WALL["mortar"])
        img.putpixel((10, 8), hexc("0d0a12"))
        img.putpixel((11, 8), hexc("0d0a12"))
    if v == 2:  # moss dripping from the ledge
        for x, ln in [(1, 3), (2, 5), (3, 2), (7, 4), (8, 6), (9, 3), (13, 4), (14, 2)]:
            for yy in range(3, 3 + ln):
                img.putpixel((x, yy), hexc(GRASS["tuft"] if yy < 3 + ln - 1 else GRASS["dark"]))
    return img


def tiles_sheet():
    tiles = [floor_tile(0), floor_tile(1), floor_tile(2), moss_tile(0), moss_tile(1),
             tall_grass_tile(), water_tile(0), water_tile(1), wall_top_tile(),
             wall_face_tile(0), wall_face_tile(1), wall_face_tile(2)]
    sheet = Image.new("RGBA", (16 * len(tiles), 16), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        sheet.paste(t, (i * 16, 0))
    return sheet


# ---------------------------------------------------------------------------
# PROPS (16 x 16): grave, candles, skull, mushrooms, dead bush
# ---------------------------------------------------------------------------
PROP_PAL = dict(PAL)
PROP_PAL.update({
    "h": "958fb0", "S": "726b8b", "s": "524b67", "x": "3b3550",
    "g": "34503f", "G": "4f7a58", "o": "000000",
    "W": "efe4c8", "w": "c4b590",
    "B": "e8dfc8", "b": "b0a58c",
    "M": "6fe0e8", "m": "38a2b5", "v": "e6fdff", "F": "d6cfe6",
    "T": "4a3a36",
    "Q": "e4ffe9", "q": "7dff9a",
})

GRAVE = [
    "................",
    ".....KKKKKK.....",
    "....KhhSSSSK....",
    "...KhSSSSSSsK...",
    "...KhSSxSSSsK...",
    "...KSSxxxSSsK...",
    "...KSSSxSSSsK...",
    "...KSSSxSSSsK...",
    "...KSSSSSSSsK...",
    "...KSSSSSSssK...",
    "...KsSSSSSssK...",
    "..KKGgGggGgsKK..",
    "..KgGgggGggGgK..",
    "..KKKKKKKKKKKK..",
    "..oooooooooooo..",
    "................",
]
CANDLES = [
    "................",
    ".......Y........",
    "......YyY.......",
    ".......y....Y...",
    "......KWK..YyY..",
    "......KWK...y...",
    "..Y...KWK..KWK..",
    ".YyY..KWw..KWK..",
    "..y...KWw..KWw..",
    ".KWK..KWw..KWw..",
    ".KWw..KWw..KWw..",
    ".KWwKKKWwKKKWwK.",
    ".KwwwwwwwwwwwwK.",
    "..KKKKKKKKKKKK..",
    "..oooooooooooo..",
    "................",
]
SKULL = [
    "................",
    "................",
    "................",
    "......KKKK......",
    "....KKBBBBKK....",
    "...KBBBBBBBbK...",
    "...KBKKBBKKbK...",
    "...KBKKBBKKbK...",
    "...KBBBKKBBbK...",
    "....KbBBBBbK....",
    "..K.KKbKbKKK.K..",
    ".KBK..KKKK..KBK.",
    "..KBBKK..KKBBK..",
    "....KBBBBBBK....",
    "..oooooooooooo..",
    "................",
]
MUSHROOMS = [
    "................",
    "................",
    "................",
    "................",
    "....KKKKK.......",
    "...KMMvMMK......",
    "..KMvMMMMmK.....",
    "..KmmMMMmmK.KKK.",
    "...KKKFKKK.KMvmK",
    ".KKK..KFK...KFK.",
    "KMvmK.KFK...KFK.",
    ".KFK..KFK...KFK.",
    ".KFKKKKFKKKKKFK.",
    "..KKKKKKKKKKKK..",
    "..oooooooooooo..",
    "................",
]
DEAD_BUSH = [
    "................",
    "................",
    "......K.........",
    "..K...K..K......",
    "...K..K.K...K...",
    "...KK.KK...K....",
    ".K..K.K..KK.....",
    "..K.KKK.K....K..",
    "...KKTKKK..KK...",
    "....KTTK.KK.....",
    "....KTTKK.......",
    ".....KTK........",
    "....KTTTK.......",
    "...KKKKKKK......",
    "..oooooooooooo..",
    "................",
]


FLARE = [
    "................",
    ".......Q........",
    "......QqQ.......",
    "......qQq.......",
    ".......q........",
    "......KMK.......",
    "......KRK.......",
    "......KRK.......",
    "......KrK.......",
    "......KTK.......",
    "......KTK.......",
    "......KTK.......",
    ".....KKTKK......",
    ".....KKKKK......",
    "....ooooooo.....",
    "................",
]


MATCHBOX = [
    "................",
    "................",
    "................",
    "................",
    ".........KK.....",
    "........KRHK....",
    "........KrRK....",
    ".........KOK....",
    "...KKKKKKKOKK...",
    "..KRRRRRRRRRrK..",
    "..KRWWWWWWWWrK..",
    "..KRWYyYWWWWrK..",
    "..KRWWWWWWWWrK..",
    "..KrrrrrrrrrrK..",
    "..KKKKKKKKKKKK..",
    "...oooooooooo...",
]
FLARE_ITEM = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "...KKKKKKKKKKKK.",
    "...KMRRHRRRrTTK.",
    "...KMRRRRRRrTTK.",
    "...KKKKKKKKKKKK.",
    "...oooooooooooo.",
    "................",
    "................",
]


def props_sheet():
    props = [GRAVE, CANDLES, SKULL, MUSHROOMS, DEAD_BUSH, FLARE, MATCHBOX, FLARE_ITEM]
    extra = [_shadowed(CHEST_CLOSED, CHEST_PAL), _shadowed(CHEST_OPEN, CHEST_PAL),
             door_img("bronze"), door_img("silver"), door_img("gold"), door_open_img()]
    sheet = Image.new("RGBA", (16 * (len(props) + len(extra)), 16), (0, 0, 0, 0))
    for k, img in enumerate(extra):
        sheet.paste(img, ((len(props) + k) * 16, 0))
    for i, g in enumerate(props):
        img = grid_to_image(g, PROP_PAL)
        # make the "o" shadow pixels semi-transparent
        for y in range(16):
            for x in range(16):
                if g[y][x] == "o":
                    img.putpixel((x, y), (0, 0, 0, 90))
        sheet.paste(img, (i * 16, 0))
    return sheet


# ---------------------------------------------------------------------------
# CHESTS (16 x 16): closed, open. Appended to props.png after the pickups.
# ---------------------------------------------------------------------------
CHEST_PAL = dict(PAL)
CHEST_PAL.update({
    "W": "8a5a3a", "w": "5e3b26", "h": "b07a4e",
    "S": "8d8fa6", "s": "5c5e73", "Y": "e8b84a", "y": "a87a26",
    "n": "0d0910", "o": "000000",
})
CHEST_CLOSED = [
    "................",
    "................",
    "................",
    "..KKKKKKKKKKKK..",
    ".KWWhWWWWWWWWwK.",
    ".KWhWWWWWWWWWwK.",
    ".KSSSSSKKSSSSsK.",
    ".KKKKKKYYKKKKKK.",
    ".KWWWWKYyKWWWwK.",
    ".KWWWWWKKWWWWwK.",
    ".KWWWWWWWWWWWwK.",
    ".KSSSSSSSSSSSsK.",
    ".KwwwwwwwwwwwwK.",
    ".KKKKKKKKKKKKKK.",
    "..oooooooooooo..",
    "................",
]
CHEST_OPEN = [
    "................",
    "..KKKKKKKKKKKK..",
    ".KWWWWWWWWWWWwK.",
    ".KwwwwwwwwwwwwK.",
    ".KKKKKKKKKKKKKK.",
    ".KnnnnnnnnnnnnK.",
    ".KnYnnnnnnnYnnK.",
    ".KKKKKKKKKKKKKK.",
    ".KWWWWWWWWWWWwK.",
    ".KWWWWWWWWWWWwK.",
    ".KWWWWWWWWWWWwK.",
    ".KSSSSSSSSSSSsK.",
    ".KwwwwwwwwwwwwK.",
    ".KKKKKKKKKKKKKK.",
    "..oooooooooooo..",
    "................",
]


def _shadowed(grid, pal):
    img = grid_to_image(grid, pal)
    for y in range(16):
        for x in range(16):
            if grid[y][x] == "o":
                img.putpixel((x, y), (0, 0, 0, 90))
    return img


# ---------------------------------------------------------------------------
# DOORS (16 x 16): bronze, silver, gold (closed), then open. In props.png.
# KEYS: bronze, silver, gold, purple. In items.png.
# ---------------------------------------------------------------------------
METALS = {
    "bronze": ("c07a3a", "7a4a20", "f0b070"),
    "silver": ("c9cbd8", "7d8399", "ffffff"),
    "gold": ("e8b84a", "a87a26", "fff1c2"),
    "purple": ("a060ff", "5a2fb0", "e0c8ff"),
}
DOOR_CLOSED = [
    "................",
    ".KKKKKKKKKKKKKK.",
    ".KMMMMMMMMMMMmK.",
    ".KWWwWWWwWWWwWK.",
    ".KWWwWWWwWWWwWK.",
    ".KWWwWWWwWWWwWK.",
    ".KMMMMMKKMMMMmK.",
    ".KWWwWKMMKWWwWK.",
    ".KWWwWKMKKWWwWK.",
    ".KWWwWKMMKWWwWK.",
    ".KMMMMMKKMMMMmK.",
    ".KWWwWWWwWWWwWK.",
    ".KWWwWWWwWWWwWK.",
    ".KMMMMMMMMMMMmK.",
    ".KKKKKKKKKKKKKK.",
    "................",
]
DOOR_OPEN = [
    "................",
    ".KKK........KKK.",
    ".KMK........KsK.",
    ".KWK........KsK.",
    ".KWK........KsK.",
    ".KWK........KsK.",
    ".KMK........KsK.",
    ".KWK........KsK.",
    ".KWK........KsK.",
    ".KWK........KsK.",
    ".KMK........KsK.",
    ".KWK........KsK.",
    ".KWK........KsK.",
    ".KMK........KsK.",
    ".KKK........KKK.",
    "................",
]
KEY = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "..KKKK..........",
    ".KMMMMK.........",
    "KMhKKMMKKKKKKKK.",
    "KMK..KMMMMMMMMmK",
    "KMhKKMMKKKKmKKmK",
    ".KMMMMK....KMKMK",
    "..KKKK.....KKKKK",
    "................",
    "................",
    "................",
    "................",
]


def door_img(metal):
    m = METALS[metal]
    pal = dict(PAL, M=m[0], m=m[1], W="6e4a30", w="4a301e", s="524b67")
    return grid_to_image(DOOR_CLOSED, pal)


def door_open_img():
    pal = dict(PAL, M="6e6880", m="4a4458", W="6e4a30", w="4a301e", s="524b67")
    return grid_to_image(DOOR_OPEN, pal)


def key_img(metal):
    m = METALS[metal]
    return grid_to_image(KEY, dict(PAL, M=m[0], m=m[1], h=m[2]))


# ---------------------------------------------------------------------------
# MASTER CHAMBER GATE (16 x 24, drawn rising above its tile like the hero)
# and the PURPLE CHEST. Saved as assets/master.png: gate, chest closed, chest open.
# ---------------------------------------------------------------------------
GATE = [
    "................",
    "................",
    "................",
    "....KKKKKKKK....",
    "..KKSSSSSSSSKK..",
    ".KSSShSSSShSSSK.",
    ".KSSKKKKKKKKSSK.",
    "KSSKVVVVVVVVKSSK",
    "KSKVVvVVVVvVVKSK",
    "KSKVvVVPPVVvVKSK",
    "KSKVVVPPPPVVVKSK",
    "KhKVVPPKKPPVVKhK",
    "KSKVVPPKKPPVVKSK",
    "KSKVVVPKKPVVVKSK",
    "KSKVvVVKKVVvVKSK",
    "KSKVVVVVVVVVVKSK",
    "KSKVVvVVVVvVVKSK",
    "KhKVVVVVVVVVVKhK",
    "KSKVvVVVVVVvVKSK",
    "KSKVVVVVVVVVVKSK",
    "KSKKKKKKKKKKKKSK",
    "KSSSSSSSSSSSSSSK",
    "KssssssssssssssK",
    "KKKKKKKKKKKKKKKK",
]
GATE_PAL = dict(PAL, S="5a5170", s="3e3650", h="7a7090", V="6a2fb0", v="a060ff", P="e0c8ff")


def master_sheet():
    sheet = Image.new("RGBA", (48, 24), (0, 0, 0, 0))
    sheet.paste(grid_to_image(GATE, GATE_PAL), (0, 0))
    purple = dict(CHEST_PAL, S="a060ff", s="5a2fb0", Y="e0c8ff", y="a060ff")
    sheet.paste(_shadowed(CHEST_CLOSED, purple), (16, 8))
    sheet.paste(_shadowed(CHEST_OPEN, purple), (32, 8))
    return sheet


# ---------------------------------------------------------------------------
# ITEM ICONS (16 x 16, one row) -- order must match scripts/items.gd ICON
# ---------------------------------------------------------------------------
IC = {
    "W": "8a5a3a", "w": "5e3b26", "S": "b9bfd0", "s": "7d8399", "h": "eef1f8",
    "B": "e8dfc8", "b": "b0a58c", "Y": "e8b84a", "y": "a87a26",
    "D": "4a4a62", "d": "2f2f42", "v": "b06cff", "K": "1a1022",
}


def _outline(px):
    """px: dict (x,y)->hex. Adds a dark outline around filled pixels."""
    out = dict(px)
    for (x, y) in px:
        for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
            n = (x + dx, y + dy)
            if n not in px and 0 <= n[0] < 16 and 0 <= n[1] < 16:
                out[n] = IC["K"]
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for (x, y), c in out.items():
        if 0 <= x < 16 and 0 <= y < 16:
            img.putpixel((x, y), hexc(c))
    return img


def weapon_icon(kind):
    px = {}
    def put(x, y, c):
        px[(x, y)] = IC[c]
    def diag(i0, i1, light, dark, thick=2):
        for i in range(i0, i1 + 1):
            x, y = 2 + i, 13 - i
            put(x, y, light)
            if thick >= 2:
                put(x + 1, y, dark)
            if thick >= 3:
                put(x, y - 1, light)
    if kind == "dagger":
        diag(0, 2, "W", "w")
        for d in (-1, 0, 1, 2):
            put(5 + d, 10 + d, "Y")
        diag(4, 8, "h", "s")
        put(11, 4, "h")
    elif kind == "club":
        diag(0, 3, "b", "b")
        diag(4, 9, "B", "b", 3)
        for (x, y) in [(12, 2), (13, 2), (12, 3), (13, 3), (11, 2)]:
            put(x, y, "B")
    elif kind == "hatchet":
        diag(0, 9, "W", "w")
        for k in range(1, 4):
            for i in range(6, 10):
                x, y = 2 + i - k, 13 - i - k
                put(x, y, "h" if k == 3 else "S")
                put(x + 1, y, "h" if k == 3 else "s")
    elif kind == "sickle":
        diag(0, 4, "W", "w")
        x0, y0 = 6, 9
        for (dx, dy) in [(1, -1), (2, -2), (3, -3), (4, -4), (5, -4), (6, -4), (7, -3), (7, -2), (6, -1)]:
            put(x0 + dx, y0 + dy, "S")
        for (dx, dy) in [(2, -3), (3, -4), (4, -5), (5, -5), (6, -5)]:
            put(x0 + dx, y0 + dy, "h")
    elif kind == "mace":
        diag(0, 6, "W", "w")
        cx, cy = 10, 5
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                put(cx + dx, cy + dy, "S")
        put(cx - 1, cy - 1, "h")
        for (dx, dy) in [(0, -2), (2, 0), (0, 2), (-2, 0)]:
            put(cx + dx, cy + dy, "s")
    elif kind == "graveblade":
        diag(0, 2, "d", "d")
        for d in (-1, 0, 1, 2):
            put(5 + d, 10 + d, "v")
        diag(4, 10, "D", "d", 3)
        for i in range(4, 11):
            put(2 + i, 12 - i, "v")
    return _outline(px)


TUNIC = [
    "................",
    "................",
    "....KKKKKKKK....",
    "...KChCKKCCcK...",
    "..KChCCCCCCCcK..",
    ".KChCCCCCCCCCcK.",
    ".KCCKCCCCCCKCcK.",
    ".KKK.KCCCCcK.KK.",
    ".....KCCCCcK....",
    ".....KChCCcK....",
    ".....KCCCCcK....",
    ".....KCCCCcK....",
    "....KCCCCCCcK...",
    "....KcccccccK...",
    "....KKKKKKKKK...",
    "................",
]
CLOAK = [
    "................",
    ".....KKKKKK.....",
    "....KCChCCCK....",
    "...KCChKKKCcK...",
    "...KChK...KcK...",
    "...KCCK...KcK...",
    "..KCCCCKKKCCcK..",
    "..KCChCCCCCCcK..",
    ".KCChCCCCCCCCcK.",
    ".KCCCCCCCCCCCcK.",
    ".KCCCCCCCCCCccK.",
    "KCCCCCCCCCCCCccK",
    "KCCCCCCCCCCCcccK",
    "KcCcCcCcCcCcCccK",
    "KKKKKKKKKKKKKKKK",
    "................",
]


def armor_icon(kind):
    cols = {
        "cloak": ("5a4a5e", "3e3242", "7a6a80"),
        "vest": ("8a5a3a", "5e3b26", "b07a4e"),
        "chain": ("8d8fa6", "5c5e73", "c9cbe0"),
        "bone": ("b0a58c", "7a705c", "e8dfc8"),
        "plate": ("9aa0b8", "5c6278", "e6eaf5"),
    }[kind]
    pal = dict(PAL, C=cols[0], c=cols[1], h=cols[2])
    img = grid_to_image(CLOAK if kind == "cloak" else TUNIC, pal)
    if kind == "chain":
        for y in range(4, 13):
            for x in range(3, 13):
                if (x + y) % 2 == 0 and img.getpixel((x, y))[:3] == hexc(cols[0])[:3]:
                    img.putpixel((x, y), hexc(cols[1]))
    if kind == "bone":
        for y in (5, 8, 10, 12):
            for x in range(3, 13):
                if img.getpixel((x, y))[:3] == hexc(cols[0])[:3]:
                    img.putpixel((x, y), hexc(cols[2]))
    if kind == "plate":
        for (x, y) in [(4, 5), (11, 5), (7, 9), (8, 9), (6, 12), (9, 12)]:
            img.putpixel((x, y), hexc("1a1022"))
    return img


BOTTLE = [
    "................",
    "......KKKK......",
    "......KOOK......",
    "......KKKK......",
    ".......KGK......",
    ".......KGK......",
    ".....KKGgKK.....",
    "....KGGhGGgK....",
    "...KGhPPPPPgK...",
    "...KGPPhPPPpK...",
    "...KGPPPPPPpK...",
    "...KGPPPPPppK...",
    "...KgpPPPPppK...",
    "....KgppppgK....",
    ".....KKKKKK.....",
    "................",
]


def potion_icon(liquid, shade):
    pal = dict(PAL, O="a07850", G="cfd8e8", g="8e98ad", h="ffffff", P=liquid, p=shade)
    return grid_to_image(BOTTLE, pal)


LANTERN_ICON = [
    "................",
    "......KKKK......",
    ".....K....K.....",
    "......KKKK......",
    ".....KYYYYK.....",
    "....KYKKKKyK....",
    "....KYGXXGyK....",
    "....KYGXxGyK....",
    "....KYGxxGyK....",
    "....KYGGGGyK....",
    "....KYKKKKyK....",
    "...KYYYYYYyyK...",
    "...KyyyyyyyyK...",
    "....KKKKKKKK....",
    "................",
    "................",
]


def lantern_icon(metal, metal_dk, glass, flame, flame_dk):
    pal = dict(PAL, Y=metal, y=metal_dk, G=glass, X=flame, x=flame_dk)
    return grid_to_image(LANTERN_ICON, pal)


BERRY_ICON = [
    "................",
    ".......gg.......",
    "......gLLg......",
    ".....gLLg.......",
    "......Kg........",
    "....KKK.KKK.....",
    "...KhBBKKhBBK...",
    "...KBBBbKBBbK...",
    "...KBBbbKBbbK...",
    "....KbbKKKbK....",
    ".....KKhBBK.....",
    ".....KBBBBbK....",
    ".....KBBBbbK....",
    "......KbbbK.....",
    ".......KKK......",
    "................",
]


def berry_icon(berry, berry_dk, hi):
    pal = dict(PAL, K="1a1418", B=berry, b=berry_dk, h=hi, g="2f6a3a", L="5fae5a")
    return grid_to_image(BERRY_ICON, pal)


BOMB_ICON = [
    "..........y.....",
    ".........yOy....",
    "..........r.....",
    ".........r......",
    "........ss......",
    ".......KggK.....",
    ".....KKKKKKKK...",
    "....KBBBBBBBBK..",
    "...KBhhBBBBBBbK.",
    "...KBhBBBBBBBbK.",
    "...KBBBBBBBBBbK.",
    "...KBBBBBBBBbbK.",
    "...KBBBBBBBbbbK.",
    "....KbBBBbbbbK..",
    ".....KKKKKKKK...",
    "................",
]


def bomb_icon():
    pal = dict(PAL, K="0c0a12", B="3a3650", b="24202f", h="8a86a8", g="7a7488", s="c8b48a",
               r="d06030", y="ffd35a", O="ffffff")
    return grid_to_image(BOMB_ICON, pal)


SUNSTONE_ICON = [
    ".......w........",
    "...w...y...w....",
    "....y..y..y.....",
    "......KKK.......",
    ".....KhhYK......",
    "....KhWYYYK.....",
    "w..KhWYYYYOK..w.",
    "..yKYYYYYYOKy...",
    "...KYYYYYOOK....",
    "....KYYYOOK.....",
    ".....KYOOK......",
    "......KOK.......",
    "....y..K..y.....",
    "...w...y...w....",
    ".......w........",
    "................",
]


def sunstone_icon():
    pal = dict(PAL, K="5a3a10", Y="ffd35a", O="f5a33a", h="fff4c8", W="ffffff", y="ffe08a", w="fff8e0")
    return grid_to_image(SUNSTONE_ICON, pal)


def items_sheet():
    props = props_sheet()
    icons = [weapon_icon(k) for k in ["dagger", "club", "hatchet", "sickle", "mace", "graveblade"]]
    icons += [armor_icon(k) for k in ["cloak", "vest", "chain", "bone", "plate"]]
    icons += [potion_icon("e0453f", "8f1f2a"), potion_icon("f5a33a", "a3601a"),
              potion_icon("9fe3ff", "4f9fc4"), potion_icon("b06cff", "6a2fb0")]
    icons += [lantern_icon("e8b84a", "a87a26", "fff1c2", "ffcf3f", "f5a33a"),
              lantern_icon("6e7a8a", "46505e", "b8ffd0", "7dff9a", "2fbf6a")]
    icons += [props.crop((6 * 16, 0, 7 * 16, 16)), props.crop((5 * 16, 0, 6 * 16, 16))]
    icons += [key_img(m) for m in ["bronze", "silver", "gold", "purple"]]
    icons += [berry_icon("d8303c", "8a1424", "ffb0b0"), berry_icon("4a6cf0", "26348a", "c8d8ff")]
    icons += [bomb_icon(), sunstone_icon()]
    sheet = Image.new("RGBA", (16 * len(icons), 16), (0, 0, 0, 0))
    for i, ic in enumerate(icons):
        sheet.paste(ic, (i * 16, 0))
    return sheet


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    hero_sheet().save(OUT / "hero.png")
    blue_lantern_sheet(OUT / "hero.png").save(OUT / "hero_blue.png")
    recolor(OUT / "hero.png", P2_CLOTHES).save(OUT / "hero_p2.png")
    blue_lantern_sheet(OUT / "hero_p2.png").save(OUT / "hero_p2_blue.png")
    gear_sheet().save(OUT / "gear.png")
    wisp_sheet().save(OUT / "wisps.png")
    grid_to_image(BAG_ICON, HERO_PAL).save(OUT / "bag_icon.png")
    # insects / demons: see tools/make_creatures.py
    ghost_sheet().save(OUT / "ghosts.png")
    tiles_sheet().save(OUT / "tiles.png")
    props_sheet().save(OUT / "props.png")
    items_sheet().save(OUT / "items.png")
    master_sheet().save(OUT / "master.png")
    print("wrote hero, insects, demons, ghosts, tiles, props, items")
