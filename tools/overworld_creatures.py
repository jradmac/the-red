"""Overworld sprites for the creatures: 24 x 24, three-quarter view (seen from
the front and a little above, like the hero and like Pokemon's overworld
sprites), so they stand in the 3D world instead of lying flat on a card.

Each design is a function (sprite, facing, frame):
    facing  "down" (toward you), "up" (away), "side" (to the right; the game
            mirrors it for left)
    frame   0..3 of the walk / flap cycle

Walkers move their legs in a real gait and bob with their steps; fliers
flap and hover (the game lifts them off the ground, their shadow stays).
Light comes from the upper left, like the battle sprites (pixkit.py).
"""
import math

from pixkit import Sprite

W = H = 24
BOB = [0, -1, 0, -1]          # walkers: the body rises while a set of legs swings


def tri_lift(f, group):
    """Tripod gait: legs in group 0 swing on frame 1, group 1 on frame 3."""
    return -2 if (f == 1 and group == 0) or (f == 3 and group == 1) else 0


def tri_reach(f, group):
    """...and while they swing they reach forward; on the ground they push back."""
    if (f == 1 and group == 0) or (f == 3 and group == 1):
        return 1.5
    if f in (1, 3):
        return -1.0
    return 0.0


# --- Beetle ------------------------------------------------------------------------------

def beetle(s, facing, f, mat_bone="bone"):
    b = BOB[f]
    if facing == "down":
        # legs (behind the body): three pairs, out to the sides, alternating
        for i, (by, fx, fy) in enumerate(((10, 1, 12.5), (12.5, 0, 17), (15, 2.5, 21.5))):
            for side in (-1, 1):
                group = (i + (0 if side < 0 else 1)) % 2
                lift = tri_lift(f, group)
                reach = tri_reach(f, group)
                base = (12 + side * 4, by + b)
                knee = (12 + side * 9.5, by - 2 + b + lift * 0.7)
                foot = (12 + side * (12 - fx), fy + lift * 1.2 + reach * 0.8)
                s.limb([base, knee, foot], 1.0, "leg", r_end=0.6)
        # wing cases: a dome seen from the front and above
        s.blob(12, 9.5 + b, 7.5, 6, "shell", bands=(-0.35, 0.05, 0.55, 0.86, 0.97))
        s.line([(12, 3.5 + b), (12, 12 + b)], "shell", 0)
        for side in (-1, 1):
            s.blob(12 + side * 4.5, 7 + b, 1.3, 1.0, "mark", outline=False)
            s.blob(12 + side * 6, 10.5 + b, 1.0, 0.8, "mark", outline=False)
        s.line([(6, 7 + b), (7, 5 + b), (9, 4 + b)], "shell", 5)
        # pronotum, head, mandibles, eyes, antennae
        s.blob(12, 13.5 + b, 5.5, 2.6, "shell", bands=(-0.4, 0.0, 0.6, 0.9, 0.99), flat=0.7)
        s.blob(12, 16.5 + b, 3.6, 2.6, "leg", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        o = 1 if f in (1, 3) else 0
        s.limb([(10, 18 + b), (8 - o, 19.5 + b), (9.5 - o, 21 + b)], 0.8, mat_bone, r_end=0.45)
        s.limb([(14, 18 + b), (16 + o, 19.5 + b), (14.5 + o, 21 + b)], 0.8, mat_bone, r_end=0.45)
        tw = [0, 1, 0, -1][f]
        for side in (-1, 1):
            s.limb([(12 + side * 2.5, 15 + b), (12 + side * 5, 13.5 + b), (12 + side * (7.5 + tw * 0.5), 11.5 + b)], 0.5, "leg", r_end=0.45)
        s.dot(9, 16 + b, "ff3b4d")
        s.dot(15, 16 + b, "ff3b4d")
        s.dot(9, 15 + b, (255, 210, 210, 255))
    elif facing == "up":
        for i, (by, fx, fy) in enumerate(((9, 3, 18.5), (12, 1.5, 20), (14.5, 3.5, 22))):
            for side in (-1, 1):
                group = (i + (0 if side < 0 else 1)) % 2
                lift = tri_lift(f, group)
                base = (12 + side * 4, by + b)
                knee = (12 + side * 8.5, by - 2 + b + lift * 0.5)
                foot = (12 + side * (12 - fx), fy + lift)
                s.limb([base, knee, foot], 0.9, "leg", r_end=0.55)
        # the back: the whole dome of the wing cases, the seam, the tip of the abdomen
        s.blob(12, 11 + b, 8.5, 8, "shell", bands=(-0.35, 0.05, 0.55, 0.86, 0.97))
        s.line([(12, 3.5 + b), (12, 18.5 + b)], "shell", 0)
        s.line([(13, 4.5 + b), (13, 17.5 + b)], "shell", 1)
        for side in (-1, 1):
            for k in range(0, 12, 2):
                s.dot(12 + side * (4 + round(1.5 * math.sin(k / 11 * math.pi))), 6 + k + b, "shell", 1)
            s.blob(12 + side * 5, 8 + b, 1.3, 1.0, "mark", outline=False)
            s.blob(12 + side * 4, 14 + b, 1.1, 0.9, "mark", outline=False)
        s.line([(6, 8 + b), (7, 6 + b), (9, 4 + b)], "shell", 5)
        # antenna tips peeking over the far side
        tw = [0, 1, 0, -1][f]
        s.limb([(9, 4 + b), (7 + tw * 0.5, 1.5 + b)], 0.5, "leg", r_end=0.45)
        s.limb([(15, 4 + b), (17 - tw * 0.5, 1.5 + b)], 0.5, "leg", r_end=0.45)
    else:   # side, facing right
        # far legs (darker, a little higher)
        for i, bx in enumerate((7, 10.5, 14)):
            group = (i + 1) % 2
            lift = tri_lift(f, group)
            reach = tri_reach(f, group)
            s.limb([(bx, 14 + b), (bx + 1.5 + reach * 0.5, 15.5 + b + lift * 0.5), (bx + 0.5 + reach, 19.5 + lift)],
                   0.8, "leg", r_end=0.5)
        s.shade(lambda x, y: y > 13, -1)
        # the shell: a dome in profile
        s.blob(10.5, 13 + b, 8, 6.5, "shell", bands=(-0.35, 0.05, 0.55, 0.86, 0.97),
               clip=lambda x, y: y <= 15 + b)
        s.line([(4, 15 + b), (17, 15 + b)], "shell", 0)
        s.blob(7, 9 + b, 1.4, 1.0, "mark", outline=False)
        s.blob(12, 8.5 + b, 1.2, 0.9, "mark", outline=False)
        s.blob(14.5, 12 + b, 1.0, 0.8, "mark", outline=False)
        s.line([(5, 10 + b), (7, 8 + b), (10, 7 + b)], "shell", 5)
        # pronotum and head
        s.blob(17.5, 13.5 + b, 3, 2.5, "shell", bands=(-0.4, 0.0, 0.6, 0.9, 0.99))
        s.blob(20, 15 + b, 2.6, 2.2, "leg", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        o = 1 if f in (1, 3) else 0
        s.limb([(21.5, 16.5 + b), (23, 17 + b + o), (22, 18.5 + b + o)], 0.7, mat_bone, r_end=0.4)
        tw = [0, 1, 0, -1][f]
        s.limb([(20.5, 13 + b), (22, 10.5 + b), (23, 8.5 + b + tw * 0.5)], 0.5, "leg", r_end=0.45)
        s.dot(21, 14 + b, "ff3b4d")
        # near legs
        for i, bx in enumerate((6.5, 10, 13.5)):
            group = i % 2
            lift = tri_lift(f, group)
            reach = tri_reach(f, group)
            s.limb([(bx, 15 + b), (bx + 1.5 + reach * 0.5, 17 + b + lift * 0.5), (bx + 0.5 + reach, 21.5 + lift)],
                   0.9, "leg", r_end=0.55)


# --- Moth (flies) ------------------------------------------------------------------------

FLAP = [3, 0, -3, 0]   # wing tip height through the beat: up, level, down, level


def moth(s, facing, f):
    fl = FLAP[f]
    hover = [0, 1, 1, 0][f]   # the body lifts a little on the downstroke
    if facing in ("down", "up"):
        back = facing == "up"
        for side in (-1, 1):
            def m(pts):
                return [(12 + side * x, y + hover) for x, y in pts]
            # hind wing, then fore wing; on the upstroke they fold up and narrow
            span = 1.0 if fl == 0 else (0.82 if fl > 0 else 0.92)
            hw = m([(1.5, 12), (6 * span, 12 - fl * 0.4), (10 * span, 15 - fl * 0.3), (8 * span, 19 - fl * 0.2), (3, 18)])
            s.poly(hw, "wing", grad=(2, 1))
            fw = m([(1.5, 10), (4 * span, 5 - fl), (8.5 * span, 2.5 - fl * 1.2), (11.5 * span, 4 - fl), (10 * span, 9 - fl * 0.5),
                    (6 * span, 13), (2.5, 13)])
            s.poly(fw, "wing", grad=(4 if back else 3, 1))
            s.line(m([(2, 10), (6 * span, 6 - fl), (10 * span, 4 - fl)]), "wing", 0)
            # the eye-spot (its full pattern shows from behind, the wing's top side)
            cx, cy = m([(6.5 * span, 8 - fl * 0.6)])[0]
            if back or fl >= 0:
                s.blob(cx, cy, 2.1, 2.1, "spot", bands=(-9, 9), outline=False)
                s.dot(cx, cy, "ff3b4d")
            hx, hy = m([(6.5 * span, 16 - fl * 0.25)])[0]
            s.blob(hx, hy, 1.2, 1.2, "spot", bands=(-9, 9), outline=False)
        # body
        s.blob(12, 13 + hover, 2.0, 5, "body", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        for y in (12, 14, 16):
            s.line([(11, y + hover), (13, y + hover)], "body", 0)
        s.blob(12, 8.5 + hover, 2.8, 2.6, "fur", dither=0.5)
        if not back:
            s.blob(12, 6 + hover, 2.2, 1.9, "body", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
            s.dot(11, 6 + hover, "ff3b4d")
            s.dot(13, 6 + hover, "ff3b4d")
        tw = [0, 1, 0, -1][f]
        for side in (-1, 1):
            s.limb([(12 + side, 5 + hover), (12 + side * 3, 2.5 + hover), (12 + side * (5 + tw * 0.4), 1 + hover)], 0.45,
                   "fur", r_end=0.4)
    else:   # side, facing right
        # far wing (behind the body), then the body, then the near wing
        def wing(dx, dark):
            if fl > 0:      # up: a sail standing over the body, swept back
                pts = [(10, 11), (6, 6), (4.5, 2), (7, 0.5), (11, 0.5), (14, 3), (15.5, 7), (15, 11)]
            elif fl < 0:    # down: hanging below the body
                pts = [(10, 12), (7, 16), (6.5, 19), (10, 20.5), (14, 19), (15.5, 15), (15, 12)]
            else:           # level: seen edge on, a long thin blade
                pts = [(4, 10), (10, 9), (17, 9.5), (16, 11), (9, 11.5), (3.5, 11.5)]
            pts = [(x + dx, y + hover) for x, y in pts]
            s.poly(pts, "wing", grad=(1, 0) if dark else (4, 1))
            if not dark and fl != 0:
                cy = 4.5 if fl > 0 else 16.5
                s.line([(12.5 + dx, 11 + hover), (8.5 + dx, cy - 1.5 + hover)], "wing", 0)
                s.blob(10 + dx, cy + hover, 1.7, 1.7, "spot", bands=(-9, 9), outline=False)
                s.dot(10 + dx, cy + hover, "ff3b4d")
        wing(-2.0, True)
        s.blob(9.5, 12 + hover, 5.5, 2.0, "body", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        for x in (5, 7, 9):
            s.line([(x, 11 + hover), (x, 13 + hover)], "body", 0)
        s.blob(14.5, 11.5 + hover, 2.5, 2.4, "fur", dither=0.5)
        s.blob(17.5, 11.5 + hover, 2.0, 1.9, "body", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        s.dot(18.5, 11 + hover, "ff3b4d")
        tw = [0, 1, 0, -1][f]
        s.limb([(18, 10 + hover), (20, 7.5 + hover), (22, 6 + hover + tw * 0.4)], 0.45, "fur", r_end=0.4)
        for k in range(3):   # dangling legs
            s.limb([(12 + k * 1.5, 13.5 + hover), (12.5 + k * 1.5, 15 + hover)], 0.4, "body", r_end=0.35)
        wing(0.0, False)



# --- Spider -------------------------------------------------------------------------------

def _spider_legs(s, facing, f, b, near_only=False):
    if facing in ("down", "up"):
        sgn = 1 if facing == "down" else -1
        for i in range(4):
            for side in (-1, 1):
                group = (i + (0 if side < 0 else 1)) % 2
                lift = tri_lift(f, group)
                by = 12 + (i - 1.5) * 1.6 * sgn + b
                knee = (12 + side * (7.5 + i * 0.4), by - 5 + lift * 0.6)
                foot = (12 + side * (10.5 + (1.5 - abs(i - 1.5)) * 0.8), 13 + i * 2.6 * sgn + (4 if sgn < 0 else 0) + lift)
                s.limb([(12 + side * 2.5, by), knee, foot], 0.75, "leg", r_end=0.45)


def spider(s, facing, f):
    b = BOB[f]
    if facing == "down":
        _spider_legs(s, "down", f, b)
        # abdomen behind, with its mark, then the head end with its eyes and fangs
        s.blob(12, 8.5 + b, 6.5, 5.5, "body", bands=(-0.35, 0.05, 0.55, 0.86, 0.97), dither=0.12)
        s.poly([(10.5, 5 + b), (13.5, 5 + b), (14.5, 7.5 + b), (12, 9.5 + b), (9.5, 7.5 + b)], "mark", grad=(4, 1), outline=False)
        s.dot(11, 6.5 + b, "body", 0)
        s.dot(13, 6.5 + b, "body", 0)
        s.blob(12, 14 + b, 4.6, 3.6, "body", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        for (x, y) in ((10.5, 14), (13.5, 14), (11.5, 12.8), (12.5, 12.8)):
            s.dot(x, y + b, "ff3b4d")
        s.dot(10, 13 + b, (255, 210, 210, 255))
        o = 1 if f in (1, 3) else 0
        s.limb([(11, 16.5 + b), (10.5 - o * 0.5, 18.5 + b)], 0.7, "fang", r_end=0.4)
        s.limb([(13, 16.5 + b), (13.5 + o * 0.5, 18.5 + b)], 0.7, "fang", r_end=0.4)
    elif facing == "up":
        # the head end beyond, the big abdomen (and its mark) nearest
        s.blob(12, 7 + b, 4, 3, "body", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        _spider_legs(s, "up", f, b)
        s.blob(12, 13.5 + b, 7, 6.2, "body", bands=(-0.35, 0.05, 0.55, 0.86, 0.97), dither=0.12)
        s.poly([(10, 10 + b), (14, 10 + b), (15.5, 13 + b), (12, 16.5 + b), (8.5, 13 + b)], "mark", grad=(4, 1), outline=False)
        s.blob(10.8, 12 + b, 0.9, 1.0, "body", bands=(9,), outline=False)
        s.blob(13.2, 12 + b, 0.9, 1.0, "body", bands=(9,), outline=False)
        s.line([(12, 14 + b), (12, 15 + b)], "body", 0)
    else:
        # far legs (only their tips show), abdomen, head, near legs -- each leg
        # rises to a high knee and comes down to a fine foot
        KNEES = ((7, 5.5), (10.5, 4.5), (15, 4.5), (18.5, 6))
        FEET = (3, 8, 15.5, 21)
        def legs(near, which=(0, 1, 2, 3)):
            for i in which:
                group = (i + (0 if near else 1)) % 2
                lift = tri_lift(f, group)
                reach = tri_reach(f, group)
                kx, ky = KNEES[i]
                if not near:
                    kx += 1.5
                    ky += 1.5
                s.limb([(11.5 + i * 1.2, 13.5 + b), (kx + reach * 0.4, ky + b + lift * 0.5),
                        (FEET[i] + reach, (21.5 if near else 19.5) + lift)], 0.7 if near else 0.55, "leg", r_end=0.4)
        legs(False, (2, 3))
        s.shade(lambda x, y: True, -1)
        legs(True, (0, 1))   # the back legs pass behind the abdomen
        s.blob(6.5, 12.5 + b, 5.6, 4.6, "body", bands=(-0.35, 0.05, 0.55, 0.86, 0.97), dither=0.12)
        s.poly([(4.5, 9.5 + b), (7.5, 9 + b), (9, 11 + b), (6.5, 12.5 + b)], "mark", grad=(4, 1), outline=False)
        s.blob(13.5, 14 + b, 3.6, 2.8, "body", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        s.dot(16, 13 + b, "ff3b4d")
        s.dot(15, 12.5 + b, "ff3b4d")
        s.limb([(16.5, 15.5 + b), (17.5, 17 + b)], 0.6, "fang", r_end=0.4)
        legs(True, (2, 3))


# --- Centipede ----------------------------------------------------------------------------

def centipede(s, facing, f):
    n = 9
    ph = f / 4.0
    pts = []
    for k in range(n):
        t = k / (n - 1)                       # 0 = head .. 1 = tail
        wave = math.sin((t * 1.6 - ph) * 2 * math.pi)
        if facing == "down":
            pts.append((12 + wave * 1.8, 18.5 - t * 14))
        elif facing == "up":
            pts.append((12 + wave * 1.8, 5 + t * 14))
        else:
            pts.append((20 - t * 17, 15 + wave * 1.2))
    # legs: a pair per segment, flicking forward and back in a ripple down the body
    for k in range(1, n):
        x, y = pts[k]
        flick = 1 if (k + f) % 2 else -1
        if facing == "side":
            for dark in (True, False):
                lx = x + flick * 1.2 - (0.6 if dark else 0)
                s.limb([(x, y + 1), (lx, y + (3 if not dark else 2.5))], 0.45, "leg", r_end=0.35)
        else:
            dy = 1 if facing == "down" else -1
            for side in (-1, 1):
                s.limb([(x + side * 2, y), (x + side * 5, y + flick * dy * 1.3)], 0.5, "leg", r_end=0.35)
    order = range(n - 1, -1, -1) if facing in ("down", "side") else range(n)
    for k in order:
        x, y = pts[k]
        r = (2.4 if k == 0 else 2.2 - k * 0.08) * (1.0 if facing == "side" else 1.25)
        s.blob(x, y, r, r * (0.8 if facing == "side" else 0.62), "body", bands=(-0.3, 0.1, 0.55, 0.88, 0.99))
        if k > 0:
            s.dot(x, y - 1, "body", 4)
    # head details: fangs and long antennae
    hx, hy = pts[0]
    tw = [0, 1, 0, -1][f]
    if facing == "down":
        s.limb([(hx - 1, hy + 1.5), (hx - 2, hy + 3)], 0.6, "fang", r_end=0.4)
        s.limb([(hx + 1, hy + 1.5), (hx + 2, hy + 3)], 0.6, "fang", r_end=0.4)
        s.limb([(hx - 1, hy - 1), (hx - 4, hy - 3), (hx - 6 + tw * 0.5, hy - 2)], 0.4, "leg", r_end=0.35)
        s.limb([(hx + 1, hy - 1), (hx + 4, hy - 3), (hx + 6 - tw * 0.5, hy - 2)], 0.4, "leg", r_end=0.35)
        s.dot(hx - 1, hy, "ff3b4d")
        s.dot(hx + 1, hy, "ff3b4d")
    elif facing == "up":
        s.limb([(hx - 1, hy - 1), (hx - 3, hy - 3.5), (hx - 5 + tw * 0.5, hy - 4)], 0.4, "leg", r_end=0.35)
        s.limb([(hx + 1, hy - 1), (hx + 3, hy - 3.5), (hx + 5 - tw * 0.5, hy - 4)], 0.4, "leg", r_end=0.35)
    else:
        s.limb([(hx + 1.5, hy + 1), (hx + 3, hy + 2.5)], 0.6, "fang", r_end=0.4)
        s.limb([(hx + 1, hy - 1.5), (hx + 2.5, hy - 4), (hx + 3.5, hy - 6 + tw * 0.5)], 0.4, "leg", r_end=0.35)
        s.dot(hx + 1, hy - 0.5, "ff3b4d")
    # a pair of tail feelers
    tx, ty = pts[-1]
    if facing == "side":
        s.limb([(tx - 1, ty), (tx - 3, ty - 1.5)], 0.4, "leg", r_end=0.3)


# --- Tick ---------------------------------------------------------------------------------

def tick(s, facing, f):
    sway = [0, 0.5, 0, -0.5][f]          # a slow, heavy waddle
    b = [0, 0, -1, 0][f]
    if facing in ("down", "up"):
        fwd = 1 if facing == "down" else -1
        for i in range(4):
            for side in (-1, 1):
                group = (i + (0 if side < 0 else 1)) % 2
                lift = tri_lift(f, group) * 0.6
                by = 12 + (i - 1.5) * 2.4 * fwd
                foot = (12 + side * 9.5, by + 2.5 * fwd + 3 + lift)
                s.limb([(12 + side * 5, by + b), (12 + side * 8, by - 1 + b + lift * 0.5), foot], 0.8, "leg", r_end=0.5)
        if facing == "down":
            s.blob(12 + sway, 10 + b, 7.5, 6.5, "body", bands=(-0.35, 0.05, 0.55, 0.86, 0.97))
            s.line([(7 + sway, 9 + b), (9 + sway, 7 + b)], "body", 5)
            s.blob(12 + sway, 15 + b, 3.6, 2.2, "plate", bands=(-0.4, 0.0, 0.6, 0.9, 0.99), flat=0.6)
            s.blob(12 + sway, 17.5 + b, 1.8, 1.4, "plate", bands=(-0.4, 0.0, 0.6, 0.9, 0.99))
            s.limb([(11.3 + sway, 18.5 + b), (11 + sway, 20 + b)], 0.5, "fang", r_end=0.35)
            s.limb([(12.7 + sway, 18.5 + b), (13 + sway, 20 + b)], 0.5, "fang", r_end=0.35)
            s.dot(11 + sway, 16.5 + b, "ff3b4d")
            s.dot(13 + sway, 16.5 + b, "ff3b4d")
        else:
            s.blob(12 + sway, 6.5 + b, 2.8, 1.8, "plate", bands=(-0.4, 0.0, 0.6, 0.9, 0.99), flat=0.6)
            s.blob(12 + sway, 12 + b, 7.5, 7, "body", bands=(-0.35, 0.05, 0.55, 0.86, 0.97))
            s.line([(7 + sway, 10 + b), (9 + sway, 8 + b)], "body", 5)
            for k in range(3):   # the wrinkles of the swollen back
                s.line([(9 + sway, 12 + k * 2 + b), (15 + sway, 12 + k * 2 + b)], "body", 1)
    else:
        for i in range(4):
            group = (i + 1) % 2
            lift = tri_lift(f, group) * 0.6
            s.limb([(8 + i * 2.5, 15 + b), (9 + i * 2.8, 17 + b + lift * 0.5), (8.5 + i * 3.2, 20.5 + lift)], 0.7, "leg", r_end=0.45)
        s.shade(lambda x, y: True, -1)
        s.blob(10 + sway * 0.5, 12.5 + b, 7.5, 5.8, "body", bands=(-0.35, 0.05, 0.55, 0.86, 0.97))
        s.line([(5, 10 + b), (7, 8 + b), (10, 7 + b)], "body", 5)
        s.blob(16.5, 12.5 + b, 3, 2.4, "plate", bands=(-0.4, 0.0, 0.6, 0.9, 0.99))
        s.blob(19.5, 13.5 + b, 1.8, 1.4, "plate", bands=(-0.4, 0.0, 0.6, 0.9, 0.99))
        s.limb([(20.5, 14.5 + b), (21.5, 16 + b)], 0.5, "fang", r_end=0.35)
        s.dot(19, 12.5 + b, "ff3b4d")
        for i in range(4):
            group = i % 2
            lift = tri_lift(f, group) * 0.6
            s.limb([(7.5 + i * 2.6, 16 + b), (8.5 + i * 2.9, 18 + b + lift * 0.5), (8 + i * 3.4, 21.5 + lift)], 0.8, "leg", r_end=0.5)


# --- Scarab (a horned beetle with a ridged shell) ------------------------------------------

def scarab(s, facing, f):
    beetle(s, facing, f, mat_bone="horn")
    b = BOB[f]
    # the ridges and the horn
    if facing == "down":
        for x in (8, 16):
            s.line([(x, 4.5 + b), (x + (1 if x < 12 else -1), 12 + b)], "mark", 3)
        s.limb([(12, 16 + b), (12, 13.5 + b), (11, 11.5 + b)], 0.9, "horn", r_end=0.45)
    elif facing == "up":
        for x in (7.5, 16.5):
            s.line([(x, 6 + b), (x + (1 if x < 12 else -1), 16 + b)], "mark", 3)
    else:
        s.line([(5, 10 + b), (9, 7.5 + b), (14, 8.5 + b)], "mark", 3)
        s.limb([(20.5, 13.5 + b), (22, 11 + b), (21.5, 9 + b)], 0.8, "horn", r_end=0.4)


# --- Wasp (flies) -------------------------------------------------------------------------

def wasp(s, facing, f):
    up = f % 2 == 0                      # wings beat every frame: a buzz
    hover = [0, 1, 0, 1][f]
    pump = [0, 1, 0, -1][f]              # the abdomen pumps
    if facing in ("down", "up"):
        back = facing == "up"
        hy, ty, ay = (15, 11, 6) if not back else (5, 9.5, 15)
        # wings, out to the sides from the thorax
        for side in (-1, 1):
            if up:
                pts = [(12 + side * 2, ty - 1), (12 + side * 9, ty - 6), (12 + side * 10, ty - 3.5), (12 + side * 3, ty + 1)]
            else:
                pts = [(12 + side * 2, ty), (12 + side * 10, ty + 1), (12 + side * 9, ty + 3.5), (12 + side * 3, ty + 2)]
            s.poly([(x, y + hover) for x, y in pts], "wing", grad=(4, 2))
        # legs dangling under the thorax
        for side in (-1, 1):
            for k in range(2):
                s.limb([(12 + side * 1.5, ty + 1 + hover), (12 + side * (3 + k), ty + 4 + k + hover)], 0.45, "leg", r_end=0.35)
        # abdomen (striped), thorax, head
        def abdomen():
            s.blob(12, ay + hover + pump * 0.5, 3.3, 4.2, "body", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
            for k in (-2, 0, 2):
                s.line([(9.5, ay + k + hover + pump * 0.5), (14.5, ay + k + hover + pump * 0.5)], "band", 3)
            if back:
                s.limb([(12, ay + 4 + hover + pump * 0.5), (12, ay + 6.5 + hover + pump)], 0.5, "fang", r_end=0.3)
        if not back:
            abdomen()
        s.blob(12, ty + hover, 2.6, 2.4, "body", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        s.blob(12, hy + hover, 2.5, 2.2, "body", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        if back:
            abdomen()
        else:
            s.dot(10.5, hy + hover, "band", 4)
            s.dot(13.5, hy + hover, "band", 4)
            s.dot(11, hy - 0.5 + hover, "ff3b4d")
            s.dot(13, hy - 0.5 + hover, "ff3b4d")
            s.limb([(11, hy + 2 + hover), (10.5, hy + 3.5 + hover)], 0.5, "fang", r_end=0.3)
            s.limb([(13, hy + 2 + hover), (13.5, hy + 3.5 + hover)], 0.5, "fang", r_end=0.3)
        tw = [0, 1, 0, -1][f]
        ay2 = hy - 2 if not back else hy - 1
        s.limb([(11, ay2 + hover), (9, ay2 - 3 + hover), (8 + tw * 0.4, ay2 - 4.5 + hover)], 0.4, "leg", r_end=0.3)
        s.limb([(13, ay2 + hover), (15, ay2 - 3 + hover), (16 - tw * 0.4, ay2 - 4.5 + hover)], 0.4, "leg", r_end=0.3)
    else:
        # far wing, abdomen, thorax, head, legs, near wing
        def wingp(dx):
            if up:
                return [(13 + dx, 9), (8 + dx, 2), (11 + dx, 1), (16 + dx, 8)]
            return [(13 + dx, 10), (6 + dx, 8.5), (7 + dx, 11), (14 + dx, 11)]
        s.poly([(x, y + hover) for x, y in wingp(-1)], "wing", grad=(2, 1))
        s.blob(7, 13.5 + hover + pump * 0.5, 4.3, 2.8, "body", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        for x in (5, 7.5, 10):
            s.line([(x, 11.5 + hover + pump * 0.5), (x - 0.5, 15.5 + hover + pump * 0.5)], "band", 3)
        s.limb([(3, 15 + hover + pump * 0.5), (1, 17 + hover + pump)], 0.5, "fang", r_end=0.3)
        s.blob(14, 11 + hover, 2.6, 2.4, "body", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        s.blob(18, 11 + hover, 2.2, 2.2, "body", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        s.dot(19, 10.5 + hover, "ff3b4d")
        s.limb([(19.5, 12.5 + hover), (20.5, 14 + hover)], 0.5, "fang", r_end=0.3)
        tw = [0, 1, 0, -1][f]
        s.limb([(18.5, 9 + hover), (20.5, 6.5 + hover), (22, 6 + hover + tw * 0.4)], 0.4, "leg", r_end=0.3)
        for k in range(3):
            s.limb([(13 + k, 13 + hover), (12.5 + k * 1.5, 16 + hover + (k % 2))], 0.45, "leg", r_end=0.35)
        s.poly([(x, y + hover) for x, y in wingp(0.5)], "wing", grad=(4, 2))


# --- Mantis (rocks as it walks, arms folded and raised) ------------------------------------

def mantis(s, facing, f):
    rock = [0, 1, 0, -1][f]
    b = BOB[f]
    if facing in ("down", "up"):
        back = facing == "up"
        # four walking legs, long and thin
        for i, (by, fy) in enumerate(((13, 18), (15, 21.5))):
            for side in (-1, 1):
                group = (i + (0 if side < 0 else 1)) % 2
                lift = tri_lift(f, group)
                s.limb([(12 + side * 1.5, by + b), (12 + side * 7, by - 3 + b + lift * 0.6), (12 + side * 9, fy + lift)],
                       0.6, "leg", r_end=0.4)
        if not back:
            s.blob(12 + rock * 0.3, 15 + b, 2.4, 5, "body", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))   # abdomen, behind
            s.limb([(12 + rock * 0.5, 13 + b), (12 + rock, 7 + b)], 1.3, "body", r_end=1.0)      # neck / thorax
            # the folded raptor arms, praying in front
            for side in (-1, 1):
                s.limb([(12 + side * 1.2 + rock, 9 + b), (12 + side * 4 + rock, 12 + b), (12 + side * 2 + rock, 8 + b),
                        (12 + side * 1 + rock, 10 + b)], 0.85, "arm", r_end=0.6)
            # the triangular head with its big eyes
            hx = 12 + rock
            s.poly([(hx - 4, 4 + b), (hx + 4, 4 + b), (hx, 8 + b)], "body", grad=(3, 1))
            s.blob(hx - 3.2, 4 + b, 1.5, 1.5, "eye", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
            s.blob(hx + 3.2, 4 + b, 1.5, 1.5, "eye", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
            s.dot(hx - 3, 4 + b, "fang", 1)
            s.dot(hx + 3, 4 + b, "fang", 1)
            tw = [0, 1, 0, -1][f]
            s.limb([(hx - 1, 3.5 + b), (hx - 3, 0.5 + b + tw * 0.3)], 0.35, "leg", r_end=0.3)
            s.limb([(hx + 1, 3.5 + b), (hx + 3, 0.5 + b - tw * 0.3)], 0.35, "leg", r_end=0.3)
        else:
            hx = 12 + rock
            s.poly([(hx - 3.5, 3 + b), (hx + 3.5, 3 + b), (hx, 6.5 + b)], "body", grad=(3, 1))
            for side in (-1, 1):   # elbows of the folded arms showing past the body
                s.limb([(hx + side * 1.5, 8 + b), (hx + side * 4, 10 + b)], 0.8, "arm", r_end=0.6)
            s.limb([(12 + rock * 0.5, 13 + b), (hx, 6 + b)], 1.3, "body", r_end=1.0)
            # the folded wings covering the abdomen, nearest
            s.blob(12, 15 + b, 3, 5.5, "wing", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
            s.line([(12, 10.5 + b), (12, 20 + b)], "wing", 0)
    else:
        lean = rock * 0.6
        for i, bx in enumerate((11, 13.5)):
            group = (i + 1) % 2
            lift = tri_lift(f, group)
            reach = tri_reach(f, group)
            s.limb([(bx, 14 + b), (bx - 2 + reach, 11 + b + lift * 0.6), (bx - 3 + reach * 1.5, 21 + lift)], 0.55, "leg", r_end=0.4)
        s.shade(lambda x, y: True, -1)
        s.limb([(3, 16 + b), (8, 14.5 + b), (12, 13.5 + b)], 2.2, "wing", r_end=1.6)    # abdomen under folded wings
        s.limb([(12, 13.5 + b), (15 + lean, 8 + b), (16.5 + lean, 5 + b)], 1.2, "body", r_end=0.9)   # thorax, rearing up
        s.limb([(15.5 + lean, 7.5 + b), (19 + lean, 9.5 + b), (17 + lean, 6 + b), (18 + lean, 8 + b)], 0.85, "arm", r_end=0.6)
        hx = 17.5 + lean
        s.poly([(hx - 1.5, 3 + b), (hx + 2.5, 3 + b), (hx + 2, 6.5 + b)], "body", grad=(3, 1))
        s.blob(hx + 1, 3 + b, 1.4, 1.4, "eye", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        s.limb([(hx, 2.5 + b), (hx + 3, -0.5 + b)], 0.35, "leg", r_end=0.3)
        for i, bx in enumerate((10.5, 13)):
            group = i % 2
            lift = tri_lift(f, group)
            reach = tri_reach(f, group)
            s.limb([(bx, 15 + b), (bx - 2.5 + reach, 12 + b + lift * 0.6), (bx - 3.5 + reach * 1.5, 22 + lift)], 0.6, "leg", r_end=0.4)


DESIGNS = {"beetle": beetle, "moth": moth, "spider": spider, "centipede": centipede, "tick": tick,
           "scarab": scarab, "wasp": wasp, "mantis": mantis}
FLIERS = {"moth", "wasp"}


# --- Added with the rarity system ----------------------------------------------------------

# Firefly (flies): a little beetle hanging from a glowing lantern of a tail

def firefly(s, facing, f):
    up = f % 2 == 0
    hover = [0, 1, 0, 1][f]
    glow = [0, 0.3, 0.6, 0.3][f]
    if facing in ("down", "up"):
        back = facing == "up"
        ty, hy, gy = (11, 15, 6) if not back else (9, 5, 14)

        def lantern():
            for k in range(6):   # a haze of light around it
                a = k * 1.05 + f * 0.5
                s.dot(12 + math.cos(a) * 6, gy + hover + math.sin(a) * 5, "glow", 3 + (k + f) % 2)
            s.blob(12, gy + hover, 4 + glow, 4 + glow, "glow", bands=(-0.2, 0.25, 0.6, 0.85, 0.97))
            s.blob(11, gy - 1 + hover, 1.5, 1.3, "glow", bands=(-9, -9, -9, -9), outline=False)
        if not back:
            lantern()
        for side in (-1, 1):   # wings
            if up:
                pts = [(12 + side * 2, ty - 1), (12 + side * 9, ty - 5), (12 + side * 9.5, ty - 2.5), (12 + side * 3, ty + 1)]
            else:
                pts = [(12 + side * 2, ty), (12 + side * 9.5, ty + 1.5), (12 + side * 8.5, ty + 3.5), (12 + side * 3, ty + 2)]
            s.poly([(x, y + hover) for x, y in pts], "wing", grad=(4, 2))
        s.blob(12, ty + hover, 3, 2.6, "shell", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        for side in (-1, 1):
            s.limb([(12 + side * 1.5, ty + 1.5 + hover), (12 + side * 3, ty + 4.5 + hover)], 0.45, "leg", r_end=0.35)
        s.blob(12, hy + hover, 2.6, 1.9, "plate", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        if back:
            lantern()
        else:
            s.dot(11, hy + hover, "ffcf3f")
            s.dot(13, hy + hover, "ffcf3f")
        tw = [0, 1, 0, -1][f]
        s.limb([(11, hy - 1.5 + hover), (9, hy - 4 + hover), (8 + tw * 0.4, hy - 5 + hover)], 0.4, "leg", r_end=0.3)
        s.limb([(13, hy - 1.5 + hover), (15, hy - 4 + hover), (16 - tw * 0.4, hy - 5 + hover)], 0.4, "leg", r_end=0.3)
    else:
        def wingp(dx):
            if up:
                return [(13 + dx, 9), (8 + dx, 3), (11 + dx, 2), (16 + dx, 8)]
            return [(13 + dx, 10), (6 + dx, 9), (7 + dx, 11.5), (14 + dx, 11)]
        s.poly([(x, y + hover) for x, y in wingp(-1)], "wing", grad=(2, 1))
        for k in range(6):
            a = k * 1.05 + f * 0.5
            s.dot(7 + math.cos(a) * 6, 13 + hover + math.sin(a) * 4.5, "glow", 3 + (k + f) % 2)
        s.blob(7, 13 + hover, 4.2 + glow, 3.6 + glow, "glow", bands=(-0.2, 0.25, 0.6, 0.85, 0.97))
        s.blob(6, 12 + hover, 1.5, 1.2, "glow", bands=(-9, -9, -9, -9), outline=False)
        s.blob(13.5, 11 + hover, 3, 2.3, "shell", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        s.blob(17.5, 11.5 + hover, 2.2, 1.9, "plate", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        s.dot(18.5, 11 + hover, "ffcf3f")
        tw = [0, 1, 0, -1][f]
        s.limb([(18, 9.5 + hover), (20, 7 + hover), (21.5, 6.5 + hover + tw * 0.4)], 0.4, "leg", r_end=0.3)
        for k in range(3):
            s.limb([(12.5 + k, 13 + hover), (12 + k * 1.5, 16 + hover + (k % 2))], 0.45, "leg", r_end=0.35)
        s.poly([(x, y + hover) for x, y in wingp(0.5)], "wing", grad=(4, 2))


# Scorpion: low on eight legs, pincers out front, the tail arched over its back

def scorpion(s, facing, f):
    b = BOB[f] * 0.5
    sway = [0, 0.5, 0, -0.5][f]
    if facing in ("down", "up"):
        back = facing == "up"
        d = 1 if not back else -1     # +1: the head is toward the bottom of the picture

        def tail():
            pts = []
            for i in range(6):
                t = i / 5
                # from the rear of the body, up, and curling over toward the head
                y = 12 - d * 4.5 - t * 9 + (t ** 2) * 6 * (1 if not back else 0.4)
                pts.append((12 + sway * t * 2, y + b))
            for i, (x, y) in enumerate(pts):
                s.blob(x, y, 1.9 - i * 0.12, 1.6 - i * 0.1, "shell", bands=(-0.35, 0.05, 0.55, 0.86, 0.97))
            tx, ty = pts[-1]
            s.blob(tx, ty + 1.5 * (1 if not back else -0.3), 1.5, 1.6, "sting", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
            s.dot(tx, ty + 3 * (1 if not back else -0.2), "sting", 0)
        # legs, four pairs, splayed
        for i, by in enumerate((10, 12, 14, 16)):
            for side in (-1, 1):
                group = (i + (0 if side < 0 else 1)) % 2
                lift = tri_lift(f, group)
                s.limb([(12 + side * 3, by + b), (12 + side * 7, by - 1.5 + b + lift * 0.5),
                        (12 + side * 9.5, by + 3 + lift)], 0.6, "leg", r_end=0.4)
        if back:
            tail_first = False
        else:
            tail_first = True
        if tail_first:
            tail()
        s.blob(12, 13 + b, 4.5, 4, "shell", bands=(-0.4, 0.0, 0.55, 0.88, 0.98), flat=0.7)
        for y in (11.5, 13.5):
            s.line([(8.5, y + b), (15.5, y + b)], "shell", 1)
        cy = 17.5 + b if not back else 8 + b
        o = [0, 1, 0, 1][f]
        for side in (-1, 1):   # the pincers
            s.limb([(12 + side * 3, 13 + b + d * 2), (12 + side * 6, cy)], 0.9, "claw", r_end=0.8)
            s.blob(12 + side * 6.5, cy + d * 1.5, 2, 1.6, "claw", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
            s.limb([(12 + side * 6.5, cy + d * 2.5), (12 + side * (4.5 - o * 0.5), cy + d * 3.5)], 0.5, "claw",
                   r_end=0.3)
        if not back:
            s.blob(12, 16.5 + b, 2.6, 1.8, "shell", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
            s.dot(11, 16 + b, "ff3b4d")
            s.dot(13, 16 + b, "ff3b4d")
        else:
            tail()
    else:
        # far legs, body, tail arching over to the front, pincers ahead, near legs
        for i, bx in enumerate((7, 9.5, 12, 14.5)):
            group = (i + 1) % 2
            lift = tri_lift(f, group)
            reach = tri_reach(f, group)
            s.limb([(bx, 16 + b), (bx + 1 + reach * 0.4, 16 + b + lift * 0.4), (bx + reach * 0.8, 20 + lift)], 0.5,
                   "leg", r_end=0.35)
        s.shade(lambda x, y: y > 15, -1)
        pts = []
        for i in range(6):
            t = i / 5
            a = math.pi * (1.0 - t * 0.95)
            pts.append((9 + math.cos(a) * 6.5 + 1.5, 15 - math.sin(a) * (8 + sway) + b))
        for i, (x, y) in enumerate(pts):
            s.blob(x, y, 1.8 - i * 0.1, 1.6 - i * 0.1, "shell", bands=(-0.35, 0.05, 0.55, 0.86, 0.97))
        tx, ty = pts[-1]
        s.blob(tx + 0.5, ty + 1.5, 1.5, 1.4, "sting", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        s.limb([(tx + 1, ty + 2.5), (tx + 0.5, ty + 4)], 0.4, "sting", r_end=0.25)
        s.blob(11.5, 16 + b, 5.5, 2.4, "shell", bands=(-0.4, 0.0, 0.55, 0.88, 0.98))
        s.blob(17, 16 + b, 2, 1.8, "shell", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        s.dot(17.5, 15 + b, "ff3b4d")
        o = [0, 1, 0, 1][f]
        s.limb([(17, 17 + b), (19.5, 18.5 + b)], 0.8, "claw", r_end=0.8)
        s.blob(21, 18 + b, 1.9, 1.5, "claw", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        s.limb([(22.5, 17.5 + b), (23.5, 16.5 + b - o * 0.5)], 0.45, "claw", r_end=0.3)
        for i, bx in enumerate((6.5, 9, 11.5, 14)):
            group = i % 2
            lift = tri_lift(f, group)
            reach = tri_reach(f, group)
            s.limb([(bx, 17 + b), (bx + 1 + reach * 0.4, 18 + b + lift * 0.4), (bx + reach * 0.8, 21.5 + lift)], 0.6,
                   "leg", r_end=0.4)


# Stag beetle: a beetle with a great pair of antler-jaws

def stag(s, facing, f):
    beetle(s, facing, f, mat_bone="horn")
    b = BOB[f]
    o = [0, 0.8, 0, 0.8][f]
    if facing == "down":
        for side in (-1, 1):
            s.limb([(12 + side * 2, 18 + b), (12 + side * (5.5 + o), 19 + b), (12 + side * (6.5 + o), 21.5 + b),
                    (12 + side * (4 + o * 0.5), 23 + b)], 1.2, "horn", r_end=0.45)
            s.limb([(12 + side * (6.5 + o), 21 + b), (12 + side * (8.5 + o), 20 + b)], 0.6, "horn", r_end=0.3)
    elif facing == "up":
        for side in (-1, 1):
            s.limb([(12 + side * 3, 4 + b), (12 + side * (5 + o), 1.5 + b), (12 + side * (3.5 + o), 0.3 + b)], 0.8,
                   "horn", r_end=0.35)
    else:
        s.limb([(21, 16 + b), (23, 14.5 + b), (23.5, 12 + b + o), (22, 11 + b + o)], 1.0, "horn", r_end=0.4)
        s.limb([(23.3, 13.5 + b), (23.8, 15 + b)], 0.5, "horn", r_end=0.3)


DESIGNS.update({"firefly": firefly, "scorpion": scorpion, "stag": stag})
FLIERS.add("firefly")
