"""Battle sprites for the creatures added with the rarity system: three insects
(firefly, scorpion, stag beetle) and three demons (marionette, bog witch,
shepherd), each in a common and a rarer colour. Same conventions as
battle_insects.py (48 x 48, facing you) and battle_demons.py (48 x 72);
make_battle_sprites.py registers them (see register()).
"""
import math

from battle_demons import BREATH, LEAN, claw, feet, teeth, tooth
from battle_insects import FOOT, STEP, antenna, legs, mirror_pts

# ---------------------------------------------------------------------------------------
# Insects
# ---------------------------------------------------------------------------------------


def firefly(s, f):
    """A lightning bug hanging in the air, its whole tail a lantern."""
    b = [0, -2, 0, 2][f]
    flap = [0, -4, 0, 4][f]
    glow = [0, 1, 2, 1][f]          # the light pulses
    # the lantern: a fat glowing abdomen behind and above, ringed with segments
    for k in range(10):             # a haze of light motes around it
        a = k * 0.63 + f * 0.4
        r = 13 + (k % 3) * 1.6
        s.dot(24 + math.cos(a) * r, 13 + b + math.sin(a) * r * 0.8, "glow", 3 + (k + f) % 2)
    s.blob(24, 13 + b, 10 + glow * 0.3, 10 + glow * 0.3, "glow", bands=(-0.2, 0.25, 0.6, 0.85, 0.97))
    for y in (8, 12, 16):
        s.line([(16, y + b), (24, y + b + 1), (32, y + b)], "glow", 2)
    s.blob(22, 10 + b, 3.5, 3, "glow", bands=(-9, -9, -9, -9), outline=False)     # the hot heart of it
    # flight wings, a blur either side
    for side in (-1, 1):
        def m(pts):
            return [(24 + side * x, y) for x, y in pts]
        s.poly(m([(5, 24 + b), (13, 12 + flap + b), (22, 9 + flap + b), (21, 16 + flap // 2 + b), (10, 27 + b)]),
               "wing", grad=(4, 2))
        s.line(m([(6, 24 + b), (14, 15 + flap + b), (21, 11 + flap + b)]), "wing", 1)
    # wing cases, lifted open like a beetle's
    for side in (-1, 1):
        s.poly(mirror_pts([(23, 22 + b), (14, 17 + b), (10, 24 + b), (16, 33 + b), (22, 31 + b)]) if side > 0 else
               [(23, 22 + b), (14, 17 + b), (10, 24 + b), (16, 33 + b), (22, 31 + b)], "shell", grad=(3, 1))
        s.line([(24 + side * 8, 21 + b), (24 + side * 12, 26 + b)], "shell", 4)
    # dangling legs
    for side in (-1, 1):
        for k, (x1, y1, x2, y2) in enumerate(((6, 36, 8, 42), (8, 38, 11, 45), (4, 37, 5, 44))):
            sw = [0, 1, 0, -1][(f + k) % 4]
            s.limb([(24 + side * 3, 33 + k + b), (24 + side * x1, y1 + b), (24 + side * (x2 + sw), y2 + b)],
                   0.8, "leg", r_end=0.5)
    # the shield over the head: orange-red with two black spots, then the little head
    s.blob(24, 31 + b, 8, 5, "plate", bands=(-0.3, 0.1, 0.6, 0.9, 0.99), flat=0.75)
    s.blob(21.5, 31 + b, 1.6, 1.3, "shell", bands=(9,), outline=False)
    s.blob(26.5, 31 + b, 1.6, 1.3, "shell", bands=(9,), outline=False)
    s.line([(18, 29 + b), (21, 28 + b)], "plate", 4)
    s.blob(24, 37 + b, 4.5, 3.5, "shell", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    tw = [0, 1, 0, -1][f]
    antenna(s, [(22, 35 + b), (17, 32 + b), (13 + tw, 27 + b)], "shell")
    s.eye(21.5, 37.5 + b, 1.7, "ffcf3f")
    s.eye(26.5, 37.5 + b, 1.7, "ffcf3f")


def scorpion(s, f):
    """Low and wide, pincers out front, the tail curled up over its back with the sting aimed at you."""
    b = STEP[f]
    sway = [0, 1, 0, -1][f]
    strike = [0, 0, 0, 3][f]
    # four pairs of legs, splayed
    for k, (by, kx, ky, fx, fy) in enumerate(((26, 13, 22, 19, 30), (28, 15, 27, 21, 36), (30, 15, 32, 20, 42),
                                             (32, 12, 36, 16, 46))):
        lift = FOOT[(f + k) % 4][1]
        for side in (-1, 1):
            s.limb([(24 + side * 8, by + b), (24 + side * kx, ky + b), (24 + side * fx, fy + lift)], 1.2, "leg",
                   r_end=0.5)
    # the tail: a chain of bulbs rising from the back, curling over toward you
    segs = []
    for i in range(6):
        t = i / 5
        x = 24 + math.sin(t * 2.2) * 2.5 * sway
        y = 22 - t * 19 + strike * t
        segs.append((x, y + b))
    for i, (x, y) in enumerate(segs):
        r = 3.6 - i * 0.25
        s.blob(x, y, r, r * 0.85, "shell", bands=(-0.35, 0.05, 0.55, 0.86, 0.97))
        s.line([(x - r + 0.8, y), (x + r - 0.8, y)], "shell", 1)
    tx, ty = segs[-1]
    s.blob(tx, ty + 4 + strike, 3.2, 3.6, "sting", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))    # the venom bulb
    s.limb([(tx, ty + 6 + strike), (tx + 0.5, ty + 10 + strike), (tx - 1, ty + 12 + strike)], 1.0, "sting",
           r_end=0.3)
    # the body: flat plates, one behind another
    s.blob(24, 29 + b, 11, 7.5, "shell", bands=(-0.4, 0.0, 0.55, 0.88, 0.98), flat=0.7)
    for y in (25, 28, 31):
        s.line([(15, y + b), (24, y + 1 + b), (33, y + b)], "shell", 1)
    s.line([(16, 25 + b), (20, 23 + b)], "shell", 5)
    # pedipalps and the great pincers
    o = [0, 1, 0, 1][f]
    for side in (-1, 1):
        sh = (24 + side * 7, 34 + b)
        el = (24 + side * 14, 37 + b)
        wr = (24 + side * 15, 41 + b)
        s.limb([sh, el, wr], 1.8, "claw", r_end=1.6)
        cx, cy = 24 + side * 16, 43 + b
        s.blob(cx, cy, 4.6, 3.6, "claw", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        s.limb([(cx + side * 1, cy + 2), (cx - side * 2, cy + 5 + o), (cx - side * 5, cy + 4 + o)], 1.3, "claw",
               r_end=0.4)
        s.limb([(cx - side * 1, cy + 1), (cx - side * 4, cy + 2 - o), (cx - side * 6, cy + 1 - o)], 1.2, "claw",
               r_end=0.4)
        s.line([(cx - 2, cy - 2), (cx, cy - 3)], "claw", 4)
    # head, with a cluster of eyes
    s.blob(24, 36 + b, 6, 4, "shell", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    s.limb([(22, 39 + b), (21, 42 + b)], 0.8, "fang", r_end=0.4)
    s.limb([(26, 39 + b), (27, 42 + b)], 0.8, "fang", r_end=0.4)
    s.eye(22.5, 34.5 + b, 1.2, "ff3b4d")
    s.eye(25.5, 34.5 + b, 1.2, "ff3b4d")
    s.eye(19.5, 36 + b, 0.8, "ff3b4d", glint=False)
    s.eye(28.5, 36 + b, 0.8, "ff3b4d", glint=False)


def stag(s, f):
    """A great stag beetle: a broad head carrying a pair of branching mandibles like antlers."""
    b = STEP[f]
    legs(s, (15, 16 + b), (6, 14 + b), (3, 23), 1.6, "leg", f, 0)
    legs(s, (15, 23 + b), (6, 26 + b), (3, 35), 1.6, "leg", f, 1)
    # wing cases: a long dome, split down the middle
    s.blob(24, 14 + b, 12.5, 11, "shell", bands=(-0.4, 0.0, 0.55, 0.86, 0.97), dither=0.08)
    s.line([(24, 3 + b), (24, 25 + b)], "shell", 0)
    s.line([(14, 10 + b), (16, 7 + b), (20, 5 + b)], "shell", 5)
    s.line([(15, 11 + b), (17, 8 + b)], "shell", 4)
    # pronotum
    s.blob(24, 25 + b, 10, 4.5, "shell", bands=(-0.45, -0.05, 0.6, 0.9, 0.99), flat=0.7)
    # front legs
    legs(s, (17, 29 + b), (11, 31 + b), (10, 37), 1.2, "leg", f, 0)
    # the head: as wide as the body
    s.blob(24, 31 + b, 10.5, 5.5, "horn", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    s.line([(16, 29 + b), (21, 27.5 + b)], "horn", 4)
    # mandibles: long, curving in, toothed and forked at the tips; they open and close
    o = [0, 1.5, 0, 1.5][f]
    for side in (-1, 1):
        pts = [(24 + side * 6, 34 + b), (24 + side * (13 + o), 36 + b), (24 + side * (18 + o), 41 + b),
               (24 + side * (17 + o * 0.6), 45.5 + b), (24 + side * (10 + o * 0.3), 47 + b)]
        s.limb(pts, 3.0, "horn", r_end=0.8)
        s.limb([(24 + side * (18 + o), 41 + b), (24 + side * (21.5 + o), 39 + b), (24 + side * (22.5 + o), 35 + b)], 1.5,
               "horn", r_end=0.5)   # the fork
        for k in range(3):   # teeth along the inside edge
            s.dot(24 + side * (11 + k * 1.2 + o * 0.8), 39 + k * 1.5 + b, "horn", 5)
        s.line([(24 + side * 7, 34 + b), (24 + side * (12 + o), 36 + b)], "horn", 5)
    tw = [0, 1, 0, -1][f]
    antenna(s, [(18, 32 + b), (13, 30 + b), (10 + tw, 33 + b)], "leg", club=1.2)
    s.eye(16.5, 31 + b, 1.6, "ff3b4d")
    s.eye(31.5, 31 + b, 1.6, "ff3b4d")


# ---------------------------------------------------------------------------------------
# Demons
# ---------------------------------------------------------------------------------------


def marionette(s, f, o):
    """A puppet the size of a man: a porcelain face with a hinged jaw, wooden limbs
    on ball joints, a harlequin coat. Its strings rise into the dark above -- or,
    for the cut one, hang snapped and loose, and it moves anyway."""
    cut = o.get("cut", False)
    b = [0, -1, 1, -1][f]
    # the strings pull one side, then the other: jerky
    pull = [(0, 0), (-3, 2), (0, 0), (2, -3)][f]
    lh, rh = pull
    knees = [(0, 0), (-2, 0), (0, 0), (0, -2)][f]
    # legs: wooden, ball-jointed, toes dangling just off the floor
    for side, kl in ((-1, knees[0]), (1, knees[1])):
        hip = (24 + side * 4, 46 + b)
        knee = (24 + side * 5, 56 + b + kl)
        foot = (24 + side * 5, 66 + b + kl * 0.5)
        s.limb([hip, knee], 1.8, "wood", r_end=1.5)
        s.limb([knee, foot], 1.6, "wood", r_end=1.3)
        s.blob(knee[0], knee[1], 1.9, 1.9, "wood", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        s.blob(foot[0] + side * 1, foot[1] + 1.5, 2.8, 1.6, "wood", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    # harlequin coat: short, flared, in diamonds
    s.poly([(17, 28 + b), (31, 28 + b), (34, 40 + b), (36, 48 + b), (12, 48 + b), (14, 40 + b)], "cloak",
           grad=(3, 1))
    for k in range(-2, 3):
        for j in range(3):
            x, y = 24 + k * 4.5 + (j % 2) * 2.2, 32 + j * 5 + b
            s.poly([(x, y - 2), (x + 1.6, y), (x, y + 2), (x - 1.6, y)], "cloak", tone=0 if (k + j) % 2 else 4,
                   outline=False)
    hem = [(12 + k * 4, 48 + b + (2 if k % 2 else 0)) for k in range(7)]   # the zigzag hem
    for x, y in hem:
        s.poly([(x - 2, 47 + b), (x + 2, 47 + b), (x, y + 2)], "cloak", tone=1, outline=True)
    s.poly([(19, 27 + b), (29, 27 + b), (27, 31 + b), (24, 30 + b), (21, 31 + b)], "gum", grad=(3, 1))   # ruff
    # arms on joints, hands like wooden mittens
    for side, lift in ((-1, lh), (1, rh)):
        sh = (24 + side * 8, 30 + b)
        el = (24 + side * 13, 38 + b + lift)
        hd = (24 + side * 14, 46 + b + lift * 2)
        s.limb([sh, el], 1.6, "wood", r_end=1.4)
        s.limb([el, hd], 1.5, "wood", r_end=1.3)
        s.blob(el[0], el[1], 1.7, 1.7, "wood", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        s.blob(hd[0], hd[1] + 1, 2.2, 2.6, "wood", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        for k in range(3):
            s.limb([(hd[0] + (k - 1) * 1.1, hd[1] + 2.5), (hd[0] + (k - 1) * 1.3, hd[1] + 5)], 0.5, "wood",
                   r_end=0.4)
    # the head: a porcelain mask with painted cheeks and a hinged jaw
    hx, hy = 24 + [0, -1, 0, 1][f] * 0.5, 17 + b
    s.blob(hx, hy, 7.5, 9, "skin", bands=(-0.25, 0.15, 0.6, 0.9, 0.98))
    s.blob(hx, hy - 7, 8, 4, "wood", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))   # carved hair
    for side in (-1, 1):
        s.blob(hx + side * 3, hy - 1, 1.9, 2.2, "mouth", bands=(9,), outline=False)
        s.eye(hx + side * 3, hy - 0.5, 0.7, "ff3b4d", glint=False)
        s.blob(hx + side * 4.5, hy + 3, 1.6, 1.0, "gum", bands=(-9, 9), outline=False)   # painted rouge
        s.line([(hx + side * 2.2, hy + 3.5), (hx + side * 2.6, hy + 9)], "skin", 0)    # the jaw hinge
    jaw = [0, 1.5, 0, 1][f]
    s.poly([(hx - 2.2, hy + 4.5), (hx + 2.2, hy + 4.5), (hx + 2.2, hy + 6 + jaw), (hx - 2.2, hy + 6 + jaw)],
           "mouth", tone=0, outline=False)
    s.line([(hx - 2, hy + 4.5), (hx + 2, hy + 4.5)], "gum", 2)
    s.line([(hx + 4, hy - 6), (hx + 2, hy - 2), (hx + 3, hy + 1)], "skin", 1)   # a crack across the porcelain
    s.line([(hx - 5, hy - 3), (hx - 3, hy - 6)], "skin", 5)
    # strings: from the wrists, knees and crown, up into the dark (or snapped)
    anchors = [(hx, hy - 10), (24 - 14, 46 + b + lh * 2), (24 + 14, 46 + b + rh * 2), (24 - 5, 56 + b + knees[0]),
               (24 + 5, 56 + b + knees[1])]
    for i, (x, y) in enumerate(anchors):
        if cut:
            sw = [0, 1, 0, -1][(f + i) % 4]
            s.line([(x, y), (x + sw, y - 4), (x + sw * 1.5, y - 7)], "string", 3, only_on=False)
        else:
            s.line([(x, y), (x + (x - 24) * 0.25, 0)], "string", 4 if i % 2 else 3, only_on=False)


def witch(s, f, o):
    """The Bog Witch: bent double under a sodden shawl, a nose like a root, a
    staff with a skull-lantern of witch-light. The Candle Witch wears the
    candles on her head instead, burning down into her hair."""
    candles = o.get("candles", False)
    b, l = BREATH[f], LEAN[f]
    hob = [0, 1, 0, -1][f]
    # the skirts: heavy, dragging, muddy at the hem
    hem = [(9 + k * 2.6, 66 + (2 if (k + f) % 2 else 0)) for k in range(12)]
    s.poly([(16 + l, 34 + b), (33 + l, 34 + b), (39, 52), (40, 66)] + hem[::-1] + [(9, 66), (11, 52)], "cloak",
           grad=(2, 0))
    s.shade(lambda x, y: y > 61 + 2 * math.sin(x * 1.3), -1)
    for x0 in (14, 20, 27, 34):
        s.line([(x0 + l * 0.5, 40 + b), (x0 + (x0 - 24) * 0.3, 65)], "cloak", 0)
    feet(s, f, (19, 30), 71, "skin", r=1.6)
    # the staff, gripped in her right hand, planted beside her
    sx = 37 + hob * 0.5
    s.limb([(sx, 70), (sx - 0.5, 40), (sx + 0.5, 20 + b)], 1.2, "wood", r_end=1.0)
    for k in range(3):
        s.dot(sx - 0.5 + k % 2, 30 + k * 9, "wood", 4)
    if not candles:
        # a little skull lantern hanging from the staff's crook, green witch-light inside
        s.limb([(sx + 0.5, 20 + b), (sx + 4, 17 + b), (sx + 6, 20 + b)], 0.9, "wood", r_end=0.6)
        lx, ly = sx + 6, 24 + b + hob * 0.5
        s.line([(sx + 6, 20 + b), (lx, ly - 3)], "wood", 1, only_on=False)
        for k in range(8):
            a = k * 0.8 + f * 0.5
            s.dot(lx + math.cos(a) * 5.5, ly + math.sin(a) * 5, "glow", 3 + (k + f) % 2)
        s.blob(lx, ly, 3.4, 3.2, "bone", bands=(-0.25, 0.1, 0.55, 0.86, 0.97))
        for side in (-1, 1):
            s.blob(lx + side * 1.3, ly - 0.3, 0.9, 1.0, "glow", bands=(-9, 9), outline=False)
        s.line([(lx - 1, ly + 2), (lx + 1, ly + 2)], "glow", 4, only_on=False)
    # the shawl over the hump of her back
    s.blob(24 + l, 34 + b, 14, 8, "cloak", bands=(-0.3, 0.1, 0.65, 0.92))
    for k in range(8):   # fringe
        x = 12 + k * 3.4 + l
        s.line([(x, 40 + b), (x + [0, 1, 0, -1][(k + f) % 4], 44 + b)], "cloak", 1, only_on=False)
    # arms: one on the staff, one clawing the air
    s.limb([(30 + l, 34 + b), (35, 38 + b), (sx - 1, 34 + b)], 1.6, "cloak", r_end=1.4)
    s.blob(sx - 0.5, 34 + b, 2, 2.2, "skin", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    ah = [0, -2, 0, 2][f]
    s.limb([(17 + l, 35 + b), (11, 41 + b + ah), (9, 46 + b + ah)], 1.6, "cloak", r_end=1.3)
    s.limb([(9, 46 + b + ah), (8.5, 48 + b + ah)], 1.3, "skin", r_end=1.0)
    claw(s, (8.5, 49 + b + ah), -1, "claw", n=4, length=5)
    # the head: thrust forward under the hood, long chin, longer nose
    hx, hy = 22 + l, 25 + b
    s.blob(hx, hy - 3, 10, 9, "cloak", bands=(-0.3, 0.1, 0.65, 0.92))   # hood
    for side in (-1, 1):   # stringy hair falling from the hood
        for k in range(3):
            x = hx + side * (6 + k * 1.3)
            s.limb([(x, hy - 4), (x + side * 0.6 + hob * 0.3, hy + 8 - k)], 0.6, "hair", r_end=0.4)
    s.blob(hx, hy + 0.5, 7, 7.5, "skin", bands=(-0.4, 0.0, 0.45, 0.8, 0.95))
    s.limb([(hx, hy - 1), (hx + 1.5, hy + 3), (hx + 3.5, hy + 7.5)], 1.9, "skin", r_end=0.9)     # the nose
    s.blob(hx + 2.5, hy + 4, 0.8, 0.8, "skin", bands=(-9, 9), outline=False)               # a wart
    s.blob(hx - 0.5, hy + 7, 3, 1.2, "mouth", bands=(9,), outline=False)
    s.dot(hx - 1.5, hy + 6.5, "teeth", 4)
    s.dot(hx + 0.5, hy + 7, "teeth", 3)
    s.blob(hx, hy + 9, 2.5, 1.6, "skin", bands=(-0.25, 0.1, 0.55, 0.86, 0.97))             # the chin
    for side in (-1, 1):
        s.blob(hx + side * 2.6, hy - 1.5, 1.4, 1.2, "mouth", bands=(9,), outline=False)
        s.eye(hx + side * 2.6, hy - 1.3, 0.9, "glow" if False else ("ffb040" if candles else "a8f070"),
              glint=False)
    s.line([(hx - 5, hy - 4), (hx - 3, hy - 6)], "skin", 4)
    if candles:
        # candles stuck into the crown of her head, wax running down into the hood
        for k, (dx, h) in enumerate(((-6, 6), (-2, 9), (2, 7), (6, 5))):
            x0, y0 = hx + dx, hy - 9 - abs(dx) * 0.2
            s.poly([(x0 - 1.2, y0), (x0 + 1.2, y0), (x0 + 1.2, y0 - h), (x0 - 1.2, y0 - h)], "wax", grad=(4, 2))
            s.line([(x0 + 0.6, y0 - h + 1), (x0 + 0.8, y0 + 2)], "wax", 5, only_on=False)
            fl = [(0, 0), (0.5, -0.5), (0, 0), (-0.5, 0.5)][(f + k) % 4]
            s.blob(x0 + fl[0], y0 - h - 2.2 + fl[1], 1.2, 2.0, "glow", bands=(-0.2, 0.3, 0.7, 0.95), outline=False)
            s.dot(x0, y0 - h - 1.5, "fff6d0")


def shepherd(s, f, o):
    """The Shepherd: very tall in a long hooded robe, a mask of bone with two thin
    slits where the hood should hold a face, a crook taller than itself. From the
    crook hangs a cage-lantern, and in the cage a captured flame -- one of the
    wandering lights, herded in. The Pale Shepherd wears bone-white, and what it
    keeps burns red."""
    pale = o.get("pale", False)
    b, l = BREATH[f], LEAN[f]
    sway = [0, 1, 0, -1][f]
    # the robe: narrow at the shoulders, falling straight to a long ragged hem that trails into nothing
    hem = [(9 + k * 2.4, 66 + (3 if (k + f) % 2 else 0) + (1 if k % 3 == 1 else 0)) for k in range(12)]
    s.poly([(18 + l, 24 + b), (30 + l, 24 + b), (36, 44), (37, 66)] + hem[::-1] + [(10, 66), (12, 44)], "cloak",
           grad=(2, 0))
    for x0 in (15, 20, 26, 31):
        s.line([(x0 + l * 0.5, 30 + b), (x0 + (x0 - 24) * 0.3, 65)], "cloak", 0)
        s.line([(x0 + 1 + l * 0.5, 31 + b), (x0 + 1 + (x0 - 24) * 0.3, 64)], "cloak", 2)
    for k in range(5):   # wisps trailing off the hem
        x = 12 + k * 6
        s.line([(x, 67), (x + [0, 1, 0, -1][(k + f) % 4], 71)], "cloak", 1, only_on=False)
    # the crook, gripped in its right hand, planted beside it, curling over at the top
    cx = 38 + sway * 0.3
    s.limb([(cx, 70), (cx - 0.5, 30), (cx, 8 + b)], 1.1, "wood", r_end=1.0)
    crook = [(cx + 4.5 * math.sin(a * 0.35), 8 + b - 4.5 * (1 - math.cos(a * 0.35)) + (a * 0.35 > 2.4) * 0)
             for a in range(0, 12)]
    crook = [(cx + 4 * math.sin(t), 8 + b - 4 * math.cos(t) + 4) for t in [k * 0.38 for k in range(0, 10)]]
    s.limb([(cx, 8 + b)] + [(x - 4 * 0 , y - 4) for x, y in crook], 1.0, "wood", r_end=0.7)
    # the cage-lantern hanging from the crook's tip, its prisoner flame inside
    lx, ly = crook[-1][0] - 0.5, crook[-1][1] + 3 + abs(sway) * 0.5
    s.line([(crook[-1][0], crook[-1][1] - 4), (lx, ly - 3)], "wood", 1, only_on=False)
    for k in range(7):   # its light, a little haze of it
        a = k * 0.9 + f * 0.6
        s.dot(lx + math.cos(a) * 5.5, ly + 2 + math.sin(a) * 4.5, "glow", 3 + (k + f) % 2)
    s.blob(lx, ly + 2.5, 2.4, 3.2, "glow", bands=(-0.2, 0.25, 0.6, 0.85, 0.97))
    s.blob(lx - 0.5, ly + 2, 1.0, 1.4, "glow", bands=(-9, -9, -9, -9), outline=False)
    for dx in (-2.6, 0, 2.6):   # the cage bars
        s.line([(lx + dx, ly - 1), (lx + dx * 1.1, ly + 6)], "wood", 1, only_on=False)
    s.limb([(lx - 3, ly - 1), (lx + 3, ly - 1)], 0.7, "wood")
    s.limb([(lx - 3, ly + 6.5), (lx + 3, ly + 6.5)], 0.7, "wood")
    # arms: too long, thin hands; one on the crook, one hanging with its fingers spread
    ah = [0, 1, 1, -1][f]
    s.limb([(29 + l, 27 + b), (35, 34 + b), (cx - 1, 38 + b)], 1.8, "cloak", r_end=1.5)
    for k in range(4):
        s.limb([(cx - 1.5, 37 + b + k * 1.1), (cx + 1.2, 37.5 + b + k * 1.1)], 0.5, "bone", r_end=0.4)
    s.limb([(19 + l, 27 + b), (13, 37 + b), (12, 48 + ah)], 1.8, "cloak", r_end=1.5)
    for k in range(4):
        s.limb([(12, 48.5 + ah), (10.5 + k * 1.1, 54 + ah - abs(k - 1.5) * 0.6)], 0.5, "bone", r_end=0.3)
    # the hood, tall and peaked, and the mask inside it
    hx = 24 + l
    s.blob(hx, 16 + b, 8.5, 11, "cloak", bands=(-0.3, 0.1, 0.65, 0.92, 0.99))
    s.poly([(hx - 3, 7 + b), (hx + 3, 7 + b), (hx + 1, 1 + b)], "cloak", grad=(3, 1))
    s.blob(hx, 17 + b, 6, 8, "mouth", bands=(9,), outline=False)                  # the dark inside the hood
    s.blob(hx, 18 + b, 4.6, 6.4, "bone", bands=(-0.25, 0.1, 0.55, 0.86, 0.97))    # the mask
    for side in (-1, 1):   # two thin slits, and the light it has stolen showing in them
        s.poly([(hx + side * 1.0, 15 + b), (hx + side * 3.4, 15.5 + b), (hx + side * 3.2, 17 + b),
                (hx + side * 1.0, 16.5 + b)], "mouth", tone=0, outline=False)
        s.dot(hx + side * 2.2, 16 + b, "ff6a5a" if pale else "b8ff9a")
    s.line([(hx, 19 + b), (hx, 23 + b)], "bone", 1)                                # a seam down the mask
    s.line([(hx - 3, 13 + b), (hx - 1, 12 + b)], "bone", 5)

# ---------------------------------------------------------------------------------------
# details (the bigger render's finer touches)
# ---------------------------------------------------------------------------------------

def _firefly_d(s, f):
    s.glints("glow", 0.12)
    s.texture("shell", 0.08, -1, tones=(2, 3), seed=3)
    s.texture("wing", 0.06, -1, tones=(2, 3, 4), seed=5)
    s.fuzz("leg", 0.3)


def _scorpion_d(s, f):
    s.texture("shell", 0.10, -1, tones=(2, 3), seed=4)
    s.glints("shell", 0.04)
    s.glints("sting", 0.15)
    s.fuzz("leg", 0.3, seed=6)
    s.texture("claw", 0.08, -1, tones=(2, 3), seed=2)


def _stag_d(s, f):
    s.texture("shell", 0.09, -1, tones=(2, 3), seed=7)
    s.glints("shell", 0.05)
    s.glints("horn", 0.06)
    s.fuzz("leg", 0.3)


def _marionette_d(s, f, o):
    s.texture("wood", 0.16, -1, tones=(1, 2, 3), seed=4)   # grain
    s.texture("cloak", 0.06, -1, tones=(1, 2, 3), seed=6)
    s.texture("skin", 0.05, -1, tones=(3, 4), seed=2)
    s.glints("skin", 0.05)


def _witch_d(s, f, o):
    s.texture("cloak", 0.14, -1, tones=(1, 2, 3), seed=5)
    s.fuzz("cloak", 0.3, seed=3, tone=0)
    s.texture("skin", 0.14, -1, tones=(2, 3), seed=8)    # warty
    s.fuzz("hair", 0.4, seed=2)
    if o.get("candles"):
        s.glints("wax", 0.1)


def _shepherd_d(s, f, o):
    s.texture("cloak", 0.12, -1, tones=(1, 2, 3), seed=7)
    s.fuzz("cloak", 0.3, seed=5, tone=0)
    s.texture("bone", 0.08, -1, tones=(2, 3, 4), seed=3)
    s.texture("wood", 0.12, -1, tones=(1, 2, 3), seed=9)


INSECT_DESIGNS = {"firefly": firefly, "scorpion": scorpion, "stag": stag}
INSECT_DETAILS = {"firefly": _firefly_d, "scorpion": _scorpion_d, "stag": _stag_d}
DEMON_DESIGNS = {"marionette": marionette, "witch": witch, "shepherd": shepherd}
DEMON_DETAILS = {"marionette": _marionette_d, "witch": _witch_d, "shepherd": _shepherd_d}

# name, design, palette -- appended after the original sixteen (same column order as make_creatures.py)
INSECTS = [
    ("FIREFLY", "firefly", {"shell": "2c2a34", "plate": "d0623a", "glow": "dff07a", "wing": "a8b8c4", "leg": "2a2430"}),
    ("EMBER FLY", "firefly", {"shell": "3a1e22", "plate": "8a2a2e", "glow": "ffa040", "wing": "c8b0a8", "leg": "2e1c20"}),
    ("SCORPION", "scorpion", {"shell": "9a7440", "claw": "b08448", "leg": "5e462a", "sting": "d8c080",
                              "fang": "3a2a1a"}),
    ("BLACK SCORPION", "scorpion", {"shell": "2c2834", "claw": "3c3646", "leg": "201c28", "sting": "c8384a",
                                    "fang": "e0d0c0"}),
    ("STAG BEETLE", "stag", {"shell": "5e3624", "horn": "7c4a30", "leg": "2a1a14", "mark": "a0705a"}),
    ("GOLDEN STAG", "stag", {"shell": "d8a838", "horn": "f2d070", "leg": "6a4a18", "mark": "fff0b0"}),
]
_D = {"teeth": "e8dfc8", "gum": "b0182c", "mouth": "3a0c18", "claw": "d8ccb0", "bone": "e0d6bc",
      "tongue": "c84a5a", "gold": "d8a838"}


def _p(**kw):
    d = dict(_D)
    d.update(kw)
    return d


DEMONS = [
    ("MARIONETTE", "marionette", _p(cloak="7a2030", wood="a87c50", skin="ece4d8", string="d8d0c0", gum="c04050"), {}),
    ("CUT MARIONETTE", "marionette", _p(cloak="2c2c3e", wood="6e5c48", skin="c8c0b8", string="b8b0a0",
                                        gum="7a3a4a"), {"cut": True}),
    ("BOG WITCH", "witch", _p(cloak="2a3224", skin="9aaa7c", hair="c8c8b8", wood="4a3424", glow="a8f070"), {}),
    ("CANDLE WITCH", "witch", _p(cloak="3a2a2c", skin="c8b8a0", hair="e8e0d0", wood="4a3424", wax="f0e6c8",
                                 glow="ffb040"), {"candles": True}),
    ("SHEPHERD", "shepherd", _p(cloak="23202c", bone="e6dcc4", wood="5a4030", glow="b8ff9a"), {}),
    ("PALE SHEPHERD", "shepherd", _p(cloak="c8c0b4", bone="f4eee0", wood="4a3428", glow="ff7a5a"), {"pale": True}),
]


def register(battle_insects, battle_demons):
    battle_insects.DESIGNS.update(INSECT_DESIGNS)
    battle_insects.DETAILS.update(INSECT_DETAILS)
    battle_demons.DESIGNS.update(DEMON_DESIGNS)
    battle_demons.DETAILS.update(DEMON_DETAILS)
