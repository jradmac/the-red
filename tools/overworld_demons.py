"""Overworld sprites for the demons: 24 x 32, three-quarter view, three
facings ("down" toward you, "up" away, "side" to the right -- the game
mirrors it), four frames each. Same looks and palettes as the battle art
(battle_demons.py), each with its own way of moving:

    grinner     shuffles under its hood, claws swinging
    many_eyes   oozes: squashes and stretches as it creeps
    wraith      drifts above the ground, its rags fluttering
    hollow      a skeleton stepping along in its cloak (the king wears his crown)
    maw         hops: crouch, spring, airborne, land
    weeper      glides, hair swaying; the bride in her veil the same way
"""
import math

from pixkit import Sprite

W, H = 24, 32
GROUND = 30
STEP = [0, -1, 0, -1]            # walkers: the body rises on each step
SWAY = [0, 1, 0, -1]


def _feet(s, f, xs, mat, y=GROUND, r=1.3, side=False):
    """Two feet stepping in turn (frames 1 and 3 lift one each)."""
    for i, x in enumerate(xs):
        lift = 2 if (f == 1 and i == 0) or (f == 3 and i == 1) else 0
        fwd = (1.5 if lift else -0.5) if side else 0
        s.limb([(x + fwd * 0.4, y - 4 - lift * 0.5), (x + fwd, y - lift)], r, mat, r_end=r * 0.9)


def _hem(x0, x1, y, f, rag=1.5):
    pts = []
    n = 6
    for k in range(n + 1):
        x = x0 + (x1 - x0) * k / n
        pts.append((x, y + (rag if (k + f) % 2 else 0)))
    return pts


def _cloak(s, f, top, x0, x1, hem_y, mat="cloak", lean=0.0):
    """A cloak: shoulders at `top`, flaring to a ragged hem."""
    hem = _hem(x0 - 1, x1 + 1, hem_y, f)
    pts = [(9 + lean, top), (15 + lean, top), (x1 + 1, hem_y - 4)] + hem[::-1] + [(x0 - 1, hem_y - 4)]
    s.poly(pts, mat, grad=(3, 1))
    for xf in (10, 12.5, 15):
        s.line([(xf + lean * 0.5, top + 3), (xf + (xf - 12) * 0.35, hem_y - 1)], mat, 0)


def _grin(s, cx, cy, w, open_=1.0):
    """A wide red mouth full of pointed teeth."""
    s.blob(cx, cy, w, 1.6 + open_, "mouth", bands=(9,), outline=False)
    s.line([(cx - w + 0.5, cy - 1), (cx + w - 0.5, cy - 1)], "gum", 2)
    for x in range(int(cx - w + 1), int(cx + w)):
        s.dot(x, cy - 1 + (x % 2) * 0, "teeth", 4 if x % 2 else 3)
        if x % 2 == 0:
            s.dot(x, cy, "teeth", 3)
    for x in range(int(cx - w + 1), int(cx + w), 2):
        s.dot(x, cy + 1 + open_, "teeth", 3)


# --- Grinner ------------------------------------------------------------------------------

def grinner(s, facing, f, o):
    b = STEP[f]
    sw = SWAY[f]
    if facing == "side":
        _feet(s, f, (10, 13), "skin", side=True)
        _cloak(s, f, 13 + b, 6, 17, 27 + b * 0.5)
        # the hood in profile, the grin under its rim
        s.blob(13 + sw * 0.3, 9 + b, 5.2, 5.5, "cloak", bands=(-0.35, 0.05, 0.55, 0.86, 0.97))
        s.blob(16 + sw * 0.3, 10.5 + b, 2.6, 3.4, "mouth", bands=(9,), outline=False)
        _grin(s, 16.5 + sw * 0.3, 12 + b, 2.2, 0.5)
        s.dot(16 + sw * 0.3, 8.5 + b, "ff3b4d")
        # the arm swinging, claws out
        a = [0, 2, 0, -2][f]
        s.limb([(12, 15 + b), (13 + a * 0.5, 19 + b), (14 + a, 22 + b)], 1.1, "cloak", r_end=0.9)
        for k in range(3):
            s.limb([(14 + a, 22 + b), (15 + a + k * 0.6, 24.5 + b - k * 0.3)], 0.45, "claw", r_end=0.3)
        return
    back = facing == "up"
    _feet(s, f, (9.5, 14.5), "skin")
    # claws hanging from the sleeves, swinging with the steps
    for side in (-1, 1):
        a = [0, 1, 0, -1][f] * side
        x = 12 + side * 6.5
        s.limb([(x, 15 + b), (x + side * 0.5, 20 + b + a)], 1.1, "cloak", r_end=1.0)
        if not back:
            for k in range(3):
                s.limb([(x + side * 0.5, 20.5 + b + a), (x + side * 0.5 + (k - 1) * 0.9, 23 + b + a)], 0.45, "claw", r_end=0.3)
    _cloak(s, f, 13 + b, 5, 19, 27 + b * 0.5)
    s.blob(12 + sw * 0.3, 9 + b, 6, 5.8, "cloak", bands=(-0.35, 0.05, 0.55, 0.86, 0.97))
    if back:
        s.line([(12 + sw * 0.3, 4 + b), (12 + sw * 0.3, 13 + b)], "cloak", 0)   # the hood's seam
        return
    # the dark inside of the hood and the grin
    s.blob(12 + sw * 0.3, 10.5 + b, 4.4, 3.8, "mouth", bands=(9,), outline=False)
    _grin(s, 12 + sw * 0.3, 11.5 + b, 3.8, [0.4, 0.8, 0.4, 0.8][f])
    s.dot(10 + sw * 0.3, 8.5 + b, "ff3b4d")
    s.dot(14 + sw * 0.3, 8.5 + b, "ff3b4d")


# --- Many-eyes (oozes) --------------------------------------------------------------------

SQUASH = [(1.0, 1.0), (1.12, 0.88), (1.0, 1.0), (0.9, 1.1)]   # (width, height) through the creep


def many_eyes(s, facing, f, o):
    wk, hk = SQUASH[f]
    rx, ry = 8.5 * wk, 9.5 * hk
    cy = GROUND - ry - 0.5
    cx = 12 + ([0, 0.5, 0, -0.5][f] if facing == "side" else 0)
    # stubby pseudopods pushing at the ground
    for k, x in enumerate((6.5, 10, 14, 17.5)):
        push = 1 if (k + f) % 2 else 0
        s.blob(x + (push if facing == "side" else 0), GROUND - 1.2, 1.6, 1.4 - push * 0.3, "skin",
               bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    s.blob(cx, cy, rx, ry, "skin", bands=(-0.35, 0.05, 0.55, 0.86, 0.97), dither=0.1)
    # lumps on the hide
    for (dx, dy, r) in ((-4, -5, 2.4), (4, -6, 2.0), (-5, 2, 2.0), (5, 3, 2.2), (0, -8, 1.8)):
        s.blob(cx + dx * wk, cy + dy * hk, r, r, "skin", bands=(-0.3, 0.1, 0.6, 0.9, 0.99), outline=False)
    # eyes everywhere -- they look where it's going
    look = {"down": (0, 1), "up": (0, -1), "side": (1, 0)}[facing]
    eyes = ((-4, -4), (3, -6), (0, -1), (-5, 2), (5, 1), (2, 4), (-2, -8), (6, -3))
    blink = f == 2
    for i, (ex, ey) in enumerate(eyes):
        if facing == "up" and i in (2, 5):
            continue
        x = cx + ex * wk + (look[0] * 1.2 if facing == "side" else 0)
        y = cy + ey * hk
        s.blob(x, y, 1.4, 1.2 if not (blink and i % 3 == 0) else 0.5, "bone", bands=(-9, 9), outline=False)
        if not (blink and i % 3 == 0):
            s.dot(x + look[0] * 0.6, y + look[1] * 0.4, "ff3b4d")
    if facing == "down":
        _grin(s, cx, cy + 5 * hk, 4.5, 0.8)
    elif facing == "side":
        _grin(s, cx + 6 * wk, cy + 4 * hk, 2.0, 0.6)


# --- Wraith (drifts) ----------------------------------------------------------------------

def wraith(s, facing, f, o):
    hover = [0, -1, -1, 0][f]
    flut = f
    top = 12 + hover
    # a long robe tapering into rags that flutter -- no feet
    def robe(lean):
        rags = []
        for k in range(7):
            x = 6 + k * 2 + lean * (k / 6)
            rags.append((x, 27 + hover + (2 if (k + flut) % 2 else 0) + (1 if k in (0, 6) else 0)))
        pts = [(9, top), (15, top), (18.5, 20 + hover)] + rags[::-1] + [(5.5, 20 + hover)]
        s.poly(pts, "cloak", grad=(2, 0))
        for xf in (9, 12, 15):
            s.line([(xf, top + 3), (xf + (xf - 12) * 0.3 + lean * 0.4, 26 + hover)], "cloak", 0)
    if facing == "side":
        robe(-3)   # the rags stream out behind
        a = [1, 0, -1, 0][f]
        s.limb([(13, 14 + hover), (16, 17 + hover + a), (18, 18 + hover + a)], 1.0, "cloak", r_end=0.8)
        for k in range(3):
            s.limb([(18, 18 + hover + a), (19.5, 18.5 + hover + a + k)], 0.4, "claw", r_end=0.3)
        s.blob(13, 8 + hover, 3.4, 3.8, "bone", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        s.blob(15, 8 + hover, 1.0, 1.2, "mouth", bands=(9,), outline=False)
        s.dot(15, 8 + hover, "ff3b4d")
        s.line([(14, 10.5 + hover), (16, 10.5 + hover)], "mouth", 0)
        for d in (-1, 1):   # antlers, one behind the other
            x0 = 12 + d * 0.8
            s.limb([(x0, 5 + hover), (x0 - 2, 1.5 + hover), (x0 - 4, 0.5 + hover)], 0.45, "bone", r_end=0.35)
            s.limb([(x0 - 2, 1.5 + hover), (x0 - 1.5, -0.5 + hover)], 0.4, "bone", r_end=0.3)
        return
    back = facing == "up"
    robe(0)
    for side in (-1, 1):
        a = [0, 1, 0, -1][f] * side
        s.limb([(12 + side * 4.5, 14 + hover), (12 + side * 7, 19 + hover + a)], 1.0, "cloak", r_end=0.8)
        if not back:
            for k in range(3):
                s.limb([(12 + side * 7, 19 + hover + a), (12 + side * (7 + (k - 1) * 0.8), 21.5 + hover + a)], 0.4, "claw", r_end=0.3)
    s.blob(12, 8 + hover, 3.6, 4, "bone", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    if not back:
        s.blob(10.5, 7.5 + hover, 1.1, 1.3, "mouth", bands=(9,), outline=False)
        s.blob(13.5, 7.5 + hover, 1.1, 1.3, "mouth", bands=(9,), outline=False)
        s.dot(10.5, 7.5 + hover, "ff3b4d")
        s.dot(13.5, 7.5 + hover, "ff3b4d")
        s.line([(10.5, 10.5 + hover), (13.5, 10.5 + hover)], "mouth", 0)
        s.dot(11, 11 + hover, "teeth", 4)
        s.dot(13, 11 + hover, "teeth", 4)
    for d in (-1, 1):   # antlers
        s.limb([(12 + d * 2, 5 + hover), (12 + d * 5, 2 + hover), (12 + d * 7, 0.5 + hover)], 0.5, "bone", r_end=0.35)
        s.limb([(12 + d * 4.5, 2.5 + hover), (12 + d * 4, 0 + hover)], 0.4, "bone", r_end=0.3)
        s.limb([(12 + d * 6, 1.3 + hover), (12 + d * 7.5, 2.5 + hover)], 0.4, "bone", r_end=0.3)


# --- Hollow (a skeleton in a cloak) -------------------------------------------------------

def hollow(s, facing, f, o):
    b = STEP[f]
    crown = o.get("crown", False)
    if facing == "side":
        _feet(s, f, (10.5, 13.5), "bone", r=0.8, side=True)
        _cloak(s, f, 13 + b, 7, 16, 25 + b)
        # ribs showing at the open front of the cloak
        for k in range(3):
            s.line([(14, 16 + k * 2 + b), (16, 16.5 + k * 2 + b)], "bone", 3, only_on=False)
        a = [0, 2, 0, -2][f]
        s.limb([(12.5, 14 + b), (14 + a * 0.5, 18.5 + b), (15 + a, 21 + b)], 0.55, "bone", r_end=0.45)
        s.blob(13.5, 9 + b, 3.6, 4, "bone", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        s.blob(15.5, 8.5 + b, 1.1, 1.3, "mouth", bands=(9,), outline=False)
        s.dot(15.5, 8.5 + b, "ff3b4d")
        s.line([(14.5, 11.5 + b), (16.5, 11.5 + b)], "mouth", 0)
        s.dot(15, 12 + b, "teeth", 4)
        if crown:
            s.poly([(10.5, 5.5 + b), (16, 5.5 + b), (16, 3 + b), (14.5, 4.5 + b), (13, 2.5 + b), (11.5, 4.5 + b), (10.5, 3 + b)],
                   "gold", grad=(4, 2))
        return
    back = facing == "up"
    _feet(s, f, (10, 14), "bone", r=0.8)
    _cloak(s, f, 13 + b, 6, 18, 25 + b)
    if not back:
        # the open front: ribs and spine
        s.poly([(10.5, 14 + b), (13.5, 14 + b), (13, 24 + b), (11, 24 + b)], "mouth", tone=0, outline=False)
        for k in range(4):
            s.line([(10.5, 15.5 + k * 2 + b), (13.5, 15.5 + k * 2 + b)], "bone", 3, only_on=False)
        s.line([(12, 15 + b), (12, 23 + b)], "bone", 2, only_on=False)
    for side in (-1, 1):
        a = [0, 1, 0, -1][f] * side
        s.limb([(12 + side * 5, 14.5 + b), (12 + side * 6.5, 18 + b + a), (12 + side * 6, 21 + b + a)], 0.55, "bone", r_end=0.45)
    s.blob(12, 9 + b, 3.8, 4.2, "bone", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    if not back:
        s.blob(10.5, 8.5 + b, 1.2, 1.4, "mouth", bands=(9,), outline=False)
        s.blob(13.5, 8.5 + b, 1.2, 1.4, "mouth", bands=(9,), outline=False)
        s.dot(10.5, 8.5 + b, "ff3b4d")
        s.dot(13.5, 8.5 + b, "ff3b4d")
        s.dot(12, 10.5 + b, "mouth", 0)
        s.line([(10.5, 12 + b), (13.5, 12 + b)], "mouth", 0)
        for x in (11, 12, 13):
            s.dot(x, 12.5 + b, "teeth", 4)
    if crown:
        s.poly([(8.5, 6 + b), (15.5, 6 + b), (15.5, 3 + b), (14, 4.5 + b), (12, 2 + b), (10, 4.5 + b), (8.5, 3 + b)],
               "gold", grad=(4, 2))
        if not back:
            s.dot(12, 4.5 + b, "ff3b4d")


# --- Maw (hops) ---------------------------------------------------------------------------

HOP = [(0, 1.12, 0.86), (-3, 0.92, 1.1), (-5, 0.96, 1.04), (-1, 1.08, 0.92)]   # (lift, width, height)


def maw(s, facing, f, o):
    lift, wk, hk = HOP[f]
    rx, ry = 8.5 * wk, 9 * hk
    cy = GROUND - ry - 1 + lift
    cx = 12
    # stubby legs: tucked in the air, spread when it lands
    for side in (-1, 1):
        spread = 1.5 if f in (0, 3) else 0
        s.limb([(cx + side * 4, cy + ry - 2), (cx + side * (5 + spread), GROUND - 0.5 + lift * 0.6)], 1.3, "skin",
               r_end=1.1)
    s.blob(cx, cy, rx, ry, "skin", bands=(-0.35, 0.05, 0.55, 0.86, 0.97), dither=0.1)
    if facing == "up":
        for (dx, dy, r) in ((-3, -3, 2.2), (3, -4, 2.0), (0, 2, 2.4)):
            s.blob(cx + dx * wk, cy + dy * hk, r, r, "skin", bands=(-0.3, 0.1, 0.6, 0.9, 0.99), outline=False)
        return
    if facing == "side":
        mx, mr = cx + 4.5 * wk, 4.2
        s.blob(mx, cy + 1, mr * 0.75, mr, "gum", bands=(-0.3, 0.1, 0.6, 0.9, 0.99), outline=False)
        s.blob(mx + 0.5, cy + 1, mr * 0.5, mr * 0.75, "mouth", bands=(9,), outline=False)
        for k in range(5):
            a = -1.2 + k * 0.6
            s.dot(mx + 0.5 + math.cos(a) * mr * 0.55, cy + 1 + math.sin(a) * mr * 0.8, "teeth", 4)
        s.blob(cx - 1, cy - 6 * hk, 1.3, 1.2, "bone", bands=(-9, 9), outline=False)
        s.dot(cx - 0.5, cy - 6 * hk, "ff3b4d")
        return
    # the great round mouth, rings of teeth around a red throat
    mr = 5.2 if f in (1, 2) else 4.6
    s.blob(cx, cy + 1, mr, mr * 0.95, "gum", bands=(-0.3, 0.1, 0.6, 0.9, 0.99), outline=False)
    s.blob(cx, cy + 1.5, mr * 0.62, mr * 0.6, "mouth", bands=(9,), outline=False)
    s.blob(cx, cy + 2.5, mr * 0.3, mr * 0.25, "tongue", bands=(9,), outline=False)
    for k in range(10):
        a = k * math.tau / 10
        s.dot(cx + math.cos(a) * mr * 0.78, cy + 1 + math.sin(a) * mr * 0.75, "teeth", 4)
    for (dx, dy) in ((-4, -6.5), (4, -6.5)):
        s.blob(cx + dx, cy + dy * hk, 1.3, 1.2, "bone", bands=(-9, 9), outline=False)
        s.dot(cx + dx, cy + dy * hk + 0.3, "ff3b4d")


# --- Weeper / Bride (glide) ---------------------------------------------------------------

def weeper(s, facing, f, o):
    bride = o.get("bride", False)
    sway = [0, 0.5, 0, -0.5][f]
    glide = [0, -1, 0, -1][f] * 0.5
    back = facing == "up"
    side = facing == "side"
    hx = 12 + sway + (1.5 if side else 0)
    if bride and not back:
        # the veil streams down behind her, past the shoulders
        tail = -2 if side else 0
        s.poly([(hx - 2.5, 4), (hx + 2.5, 4), (hx + 6 + tail, 22 + glide), (hx - 6 + tail * 2, 22 + glide)],
               "veil", grad=(4, 2))
    # a long gown to the ground, its hem drifting
    hem = _hem(4, 20, 29 + glide, f, rag=1.0)
    pts = [(10 + sway, 12), (14 + sway, 12), (19, 26)] + hem[::-1] + [(5, 26)]
    s.poly(pts, "cloak", grad=(3, 1))
    for xf in (9, 12, 15):
        s.line([(xf + sway, 15), (xf + (xf - 12) * 0.5, 28)], "cloak", 0)
    if not back:   # thin pale arms hanging
        for d in ((1,) if side else (-1, 1)):
            s.limb([(hx + d * 3, 13), (hx + d * 3.5, 19 + sway * d)], 0.6, "skin", r_end=0.5)
    if bride and not back:
        s.blob(hx + (1 if side else 0), 18.5, 2.2, 1.6, "flower", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    s.blob(hx, 8, 3.2, 3.6, "skin", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    hair = "veil" if bride and back else "hair"
    if back:
        s.blob(hx, 7.5, 3.8, 3.6, hair, bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        s.poly([(hx - 3.8, 7.5), (hx + 3.8, 7.5), (hx + 4.5 + sway, 18 if not bride else 23),
                (hx - 4.5 + sway, 18 if not bride else 23)], hair, grad=(2, 1) if not bride else (3, 1))
        return
    # the crown of the head, then long strands falling either side of the face
    s.blob(hx - (1 if side else 0), 6, 3.6, 2.6, hair, bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    strands = ((-1,) if side else (-1, 1))
    for d in strands:
        x0 = hx + d * (2.6 if not side else 3.0)
        s.limb([(x0, 6), (x0 + d * 0.6, 11), (x0 + d * 0.9 + sway * 0.6, 16)], 1.3, hair, r_end=0.8)
    if side:
        s.limb([(hx + 1.5, 5.5), (hx + 2.4, 8)], 0.9, hair, r_end=0.6)   # a lock over the brow
        s.dot(hx + 2, 8, "mouth", 0)
        s.line([(hx + 2, 9), (hx + 2, 11 + (f % 2))], "tear", 2, only_on=False)
    else:
        for d in (-1, 1):
            s.dot(hx + d, 8, "mouth", 0)
            s.line([(hx + d, 9), (hx + d, 11 + (f % 2))], "tear", 2, only_on=False)
        s.dot(hx, 10.5, "mouth", 0)
    if bride:   # the veil's crown and a flower in it
        s.blob(hx - (1 if side else 0), 4.5, 3.8, 1.6, "veil", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))


DESIGNS = {"grinner": grinner, "many_eyes": many_eyes, "wraith": wraith, "hollow": hollow, "maw": maw,
           "weeper": weeper, "bride": weeper}
HOVERERS = {"wraith"}
