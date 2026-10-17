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

def beetle(s, facing, f):
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
        s.limb([(10, 18 + b), (8 - o, 19.5 + b), (9.5 - o, 21 + b)], 0.8, "bone", r_end=0.45)
        s.limb([(14, 18 + b), (16 + o, 19.5 + b), (14.5 + o, 21 + b)], 0.8, "bone", r_end=0.45)
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
        s.limb([(21.5, 16.5 + b), (23, 17 + b + o), (22, 18.5 + b + o)], 0.7, "bone", r_end=0.4)
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


DESIGNS = {"beetle": beetle, "moth": moth}
FLIERS = {"moth"}
