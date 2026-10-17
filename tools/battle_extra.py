"""Battle sprites for the creatures added with the rarity system: three insects
(firefly, scorpion, stag beetle) and three demons (marionette, bog witch,
grandmother), each in a common and a rarer colour. Same conventions as
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


def grandmother(s, f, o):
    """Grandmother, sitting up in her nightgown and bonnet, spectacles on her
    nose... and the nose is a muzzle, and the hands are paws. The Big Bad Wolf
    has stopped pretending: the bonnet torn, the gown split, the grin wide."""
    wolf = o.get("wolf", False)
    b, l = BREATH[f], LEAN[f]
    # the nightgown, long, frilled at the hem; big clawed feet poking out under it
    hem = [(8 + k * 2.7, 65 + (2 if (k + f) % 2 else 0)) for k in range(13)]
    s.poly([(17 + l, 30 + b), (31 + l, 30 + b), (38, 48), (42, 65)] + hem[::-1] + [(6, 65), (10, 48)], "cloak",
           grad=(3, 1))
    for k in range(13):   # the frill
        x = 7 + k * 2.75
        s.blob(x, 66, 1.5, 1.2, "veil", bands=(-0.2, 0.3, 0.7, 0.95))
    for x0 in (13, 19, 29, 35):
        s.line([(x0 + l * 0.5, 36 + b), (x0 + (x0 - 24) * 0.35, 63)], "cloak", 1)
    for k in range(9):   # a print of little flowers
        x, y = 12 + (k * 7) % 24, 40 + (k * 5) % 22
        s.dot(x + (y - 40) * 0.1, y, "gum", 3)
    if wolf:   # the gown split up the front, fur showing through
        s.poly([(22, 44), (26, 44), (28, 65), (20, 65)], "fur", grad=(2, 1))
        s.line([(22, 44), (20, 65)], "cloak", 0)
        s.line([(26, 44), (28, 65)], "cloak", 0)
    feet(s, f, (17, 31), 71, "fur", r=2.8)
    # the shawl over the shoulders
    s.poly([(15 + l, 29 + b), (33 + l, 29 + b), (34 + l, 34 + b), (24 + l, 40 + b), (14 + l, 34 + b)], "veil",
           grad=(3, 1))
    for k in range(5):
        s.line([(16 + k * 4 + l, 30 + b), (19 + k * 2 + l, 37 + b)], "veil", 1)
    # paws: one at the shawl, one reaching
    ah = [0, 1, 1, -1][f]
    s.limb([(14 + l, 33 + b), (9, 41 + b), (11, 49 + b + ah)], 2.4, "cloak", r_end=2.0)
    s.blob(11, 50 + b + ah, 3, 3, "fur", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    claw(s, (11, 52 + b + ah), -1, "claw", n=4, length=5)
    s.limb([(34 + l, 33 + b), (39, 40 + b - ah), (37, 47 + b - ah)], 2.4, "cloak", r_end=2.0)
    s.blob(37, 48 + b - ah, 3, 3, "fur", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    claw(s, (37, 50 + b - ah), 1, "claw", n=4, length=5)
    # the head: a wolf's, grey and long-muzzled, under the bonnet
    hx, hy = 24 + l, 20 + b
    # ears poke up through the bonnet (or stand free)
    for side in (-1, 1):
        s.poly([(hx + side * 4, hy - 6), (hx + side * 9, hy - 7), (hx + side * 8, hy - 15 - (2 if wolf else 0))],
               "fur", grad=(3, 1))
        s.poly([(hx + side * 5.5, hy - 7), (hx + side * 8, hy - 8), (hx + side * 7.5, hy - 12)], "mouth", tone=1,
               outline=False)
    for side in (-1, 1):   # a ruff of cheek fur, jagged
        s.poly([(hx + side * 5, hy - 3), (hx + side * 11, hy + 1), (hx + side * 8.5, hy + 2.5), (hx + side * 11, hy + 5),
                (hx + side * 7.5, hy + 6), (hx + side * 9, hy + 9), (hx + side * 4, hy + 8)], "fur", grad=(3, 1))
    s.blob(hx, hy - 1, 8.5, 8, "fur", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    if not wolf:
        # the frilled nightcap, tied under the chin
        s.blob(hx, hy - 5, 11, 7, "veil", bands=(-0.25, 0.15, 0.6, 0.9, 0.98))
        for k in range(9):
            a = math.pi * (0.95 + k * 0.14)
            s.blob(hx + math.cos(a) * 11, hy - 3 - math.sin(a) * -5, 1.6, 1.4, "veil", bands=(-0.2, 0.3, 0.7))
        s.line([(hx - 7, hy + 1), (hx - 5, hy + 8)], "veil", 4, only_on=False)
        s.line([(hx + 7, hy + 1), (hx + 5, hy + 8)], "veil", 4, only_on=False)
    else:
        # the bonnet torn off, hanging by its strings
        s.blob(hx + 9, hy + 7, 4, 3, "veil", bands=(-0.25, 0.15, 0.6, 0.9))
        s.line([(hx + 6, hy + 2), (hx + 8, hy + 5)], "veil", 4, only_on=False)
        for k in range(5):   # rough fur on the crown
            s.dot(hx - 5 + k * 2.5, hy - 8 - (k % 2), "fur", 4)
    # the muzzle, long and grey, with a black nose; a grin full of teeth
    gape = ([0, 1, 1, 0] if not wolf else [1, 2, 2, 3])[f]
    s.blob(hx, hy + 5.5, 5.5, 4.8, "fur", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    s.line([(hx - 1, hy + 1), (hx - 0.5, hy + 3.5)], "fur", 4)
    s.blob(hx, hy + 3.2, 2.4, 1.6, "mouth", bands=(-0.3, 0.3, 0.8))   # the nose
    s.poly([(hx - 5, hy + 6), (hx + 5, hy + 6), (hx + 3.5, hy + 8 + gape), (hx - 3.5, hy + 8 + gape)], "mouth",
           grad=(1, 0))
    s.line([(hx - 5, hy + 6), (hx + 5, hy + 6)], "gum", 2)
    for k in range(5):
        tooth(s, hx - 4 + k * 2, hy + 6, 0.7, 1.8 + (0.8 if k in (0, 4) else 0))
    for k in range(4):
        tooth(s, hx - 3 + k * 2, hy + 8 + gape, 0.6, 1.4, down=False)
    if wolf:
        s.blob(hx, hy + 9 + gape, 1.6, 0.9, "tongue", bands=(-0.2, 0.4), outline=False)
    # what big eyes -- behind little round spectacles
    eye = "ffcf3f" if not wolf else "ff3b4d"
    for side in (-1, 1):
        ex, ey = hx + side * 3.4, hy - 1
        s.blob(ex, ey, 1.9, 1.7, "teeth", bands=(-0.2, 0.3, 0.8), outline=False)
        s.eye(ex, ey, 1.2, eye)
        if not wolf or side < 0:   # the wolf has lost one lens
            for k in range(16):
                a = k * math.tau / 16
                if k % 4 != 1:
                    s.dot(ex + math.cos(a) * 2.7, ey + math.sin(a) * 2.5, "gold", 2)
    if not wolf:
        s.line([(hx - 0.6, hy - 1), (hx + 0.6, hy - 1)], "gold", 3, only_on=False)
    s.line([(hx - 6, hy - 4), (hx - 3, hy - 6)], "fur", 4)


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


def _grandmother_d(s, f, o):
    s.fuzz("fur", 0.55, seed=4)
    s.texture("fur", 0.14, -1, tones=(1, 2, 3), seed=7)
    s.texture("cloak", 0.05, -1, tones=(2, 3), seed=3)
    s.texture("veil", 0.06, +1, tones=(2, 3), seed=9)
    s.glints("gold", 0.3)
    s.glints("gum", 0.1)


INSECT_DESIGNS = {"firefly": firefly, "scorpion": scorpion, "stag": stag}
INSECT_DETAILS = {"firefly": _firefly_d, "scorpion": _scorpion_d, "stag": _stag_d}
DEMON_DESIGNS = {"marionette": marionette, "witch": witch, "grandmother": grandmother}
DEMON_DETAILS = {"marionette": _marionette_d, "witch": _witch_d, "grandmother": _grandmother_d}

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
    ("GRANDMOTHER", "grandmother", _p(cloak="b4a6c8", veil="efe9e0", fur="8c867c", gum="c06070"), {}),
    ("BIG BAD WOLF", "grandmother", _p(cloak="5e5670", veil="c8c0b8", fur="4c4852", gum="b0182c"), {"wolf": True}),
]


def register(battle_insects, battle_demons):
    battle_insects.DESIGNS.update(INSECT_DESIGNS)
    battle_insects.DETAILS.update(INSECT_DETAILS)
    battle_demons.DESIGNS.update(DEMON_DESIGNS)
    battle_demons.DETAILS.update(DEMON_DETAILS)
