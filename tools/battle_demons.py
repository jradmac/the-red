"""Battle sprites for the demons: 48 x 72, facing you. Horror, not satanic:
teeth, eyes, wrong proportions. Each design: (sprite, frame, opts)."""
import math

from pixkit import Sprite

W, H = 48, 72
BREATH = [0, 0, 1, 0]      # frame 2: a breath (shoulders sink)
LEAN = [0, -1, 0, 1]       # sway left / right on the steps


def tooth(s, x, y, w, h, mat="teeth", down=True):
    """One pointed tooth hanging from y (or standing up from it): lit left, shaded right."""
    tip = y + h if down else y - h
    s.poly([(x - w, y), (x + w + 0.4, y), (x + 0.2, tip)], mat, tone=4, outline=False)
    s.line([(x + w * 0.6, y), (x + 0.3, tip - (0.5 if down else -0.5))], mat, 2)


def teeth(s, x0, x1, y, h, mat, down=True, gap=2):
    """A row of pointed teeth along y (pointing down, or up)."""
    x = x0
    k = 0
    while x <= x1:
        hh = h + (0.6 if k % 3 == 1 else 0)
        tooth(s, x + 0.5, y + (0 if down else 1), 0.85 * gap / 2, hh, mat, down)
        x += gap
        k += 1


def claw(s, base, d, mat, n=3, length=5):
    """Curved claws fanning out from base, pointing in direction d (+1 right / -1 left)."""
    bx, by = base
    for k in range(n):
        a = (k - (n - 1) / 2) * 0.45
        tip = (bx + d * math.sin(a) * length, by + math.cos(a) * length)
        mid = (bx + d * math.sin(a) * length * 0.55 - d * 0.6, by + math.cos(a) * length * 0.6)
        s.limb([base, mid, tip], 0.9, mat, r_end=0.3)


def feet(s, f, xs, y, mat, r=2.6):
    for i, x in enumerate(xs):
        lift = (2 if (f == 1 and i == 0) or (f == 3 and i == 1) else 0)
        s.limb([(x, y - 9 - lift), (x, y - 2 - lift)], r, mat, r_end=r * 0.8)
        claw(s, (x, y - 2 - lift), 1 if i else -1, "claw", n=3, length=3)


# ---------------------------------------------------------------------------
def grinner(s, f, o):
    b, l = BREATH[f], LEAN[f]
    feet(s, f, (19, 29), 70, "skin")
    # tattered cloak: a bell of cloth with ragged hem
    hem = []
    for k in range(13):
        x = 9 + k * 2.5
        hem.append((x, 64 + (3 if k % 2 else 0) + (1 if (k + f) % 3 == 0 else 0)))
    s.poly([(17 + l, 26 + b), (31 + l, 26 + b), (40, 50)] + hem[::-1][:1] + [(39, 64)] +
           [(x, y) for x, y in hem[::-1]] + [(9, 64), (8, 50)], "cloak", grad=(2, 1))
    for x0 in (15, 21, 27, 33):   # folds
        s.line([(x0 + l * 0.5, 32 + b), (x0 - 1 + (x0 - 24) * 0.3, 62)], "cloak", 0)
        s.line([(x0 + 1 + l * 0.5, 33 + b), (x0 + (x0 - 24) * 0.3, 61)], "cloak", 3)
    # long arms hanging out of the cloak, grasping claws
    ah = [0, 1, 1, -1][f]
    for side in (-1, 1):
        sh = (24 + side * 9 + l, 30 + b)
        el = (24 + side * 15, 42 + b + ah * side)
        hd = (24 + side * 16, 52 + ah * side)
        s.limb([sh, el, hd], 2.4, "cloak", r_end=1.8)
        s.limb([(hd[0], hd[1] - 1), (hd[0] + side * 0.5, hd[1] + 2)], 2.2, "skin", r_end=1.8)
        claw(s, (hd[0], hd[1] + 2), side, "claw", n=4, length=6)
    # hunched shoulders, hood, and the head inside it
    s.blob(24 + l, 33 + b, 14, 6, "cloak", bands=(-0.3, 0.1, 0.65, 0.92))
    s.blob(24 + l, 18 + b, 15, 14, "cloak", bands=(-0.3, 0.1, 0.65, 0.92, 0.99))
    s.blob(24 + l, 21 + b, 12.5, 10.5, "skin", bands=(-0.25, 0.1, 0.55, 0.85, 0.97))
    s.shade(lambda x, y: y < 15 + b and abs(x - 24 - l) < 13, -1)   # the hood's shadow over the brow
    # the grin: far too wide, corners hooked up into the cheeks, full of teeth
    c = 24 + l
    mouth = [(c - 12, 16 + b), (c - 9, 19 + b), (c + 9, 19 + b), (c + 12, 16 + b), (c + 11, 22 + b),
             (c + 7, 29 + b), (c - 7, 29 + b), (c - 11, 22 + b)]
    s.poly(mouth, "mouth", grad=(1, 0))
    s.poly([(c - 10, 19 + b), (c + 10, 19 + b), (c + 10, 21 + b), (c - 10, 21 + b)], "gum", grad=(3, 1),
           outline=False)
    s.poly([(c - 7, 27 + b), (c + 7, 27 + b), (c + 6, 29 + b), (c - 6, 29 + b)], "gum", grad=(1, 2),
           outline=False)
    x = c - 9
    k = 0
    while x <= c + 9:   # upper fangs, uneven
        tooth(s, x + 0.5, 21 + b, 0.85, 4.2 if k % 3 == 1 else 3.0)
        x += 2
        k += 1
    x = c - 6
    while x <= c + 6:   # lower teeth
        tooth(s, x + 0.5, 28 + b, 0.8, 2.6, down=False)
        x += 2
    s.blob(c, 25 + b, 3, 1.2, "tongue", bands=(-0.2, 0.4), outline=False)
    # cheek creases pulled up by the grin, and pinprick eyes deep in the hood
    s.line([(c - 13, 15 + b), (c - 12, 19 + b), (c - 12, 23 + b)], "skin", 0)
    s.line([(c + 13, 15 + b), (c + 12, 19 + b), (c + 12, 23 + b)], "skin", 0)
    s.line([(c - 6, 31 + b), (c, 32 + b), (c + 6, 31 + b)], "skin", 1)
    for side in (-1, 1):
        s.blob(c + side * 6, 12.5 + b, 2.2, 1.5, "mouth", bands=(9,), outline=False)
        s.dot(c + side * 6, 12 + b, "ffffff")
    s.line([(c - 10, 10 + b), (c - 6, 8 + b)], "cloak", 4)


def many_eyes(s, f, o):
    b, l = BREATH[f], LEAN[f]
    feet(s, f, (17, 31), 70, "skin", r=3.2)
    # stubby clawed arms
    ah = [0, 1, 1, -1][f]
    for side in (-1, 1):
        s.limb([(24 + side * 13, 40 + b), (24 + side * 19, 46 + b + ah * side), (24 + side * 19, 52 + ah * side)],
               3.0, "skin", r_end=2.4)
        claw(s, (24 + side * 19, 53 + ah * side), side, "claw", n=4, length=5)
    # a lumpy body, one great mass
    s.blob(24 + l, 42 + b, 17, 19, "skin", bands=(-0.35, 0.05, 0.55, 0.86, 0.97), dither=0.08)
    s.blob(17 + l, 30 + b, 9, 8, "skin", bands=(-0.35, 0.05, 0.55, 0.86, 0.97))
    s.blob(31 + l, 28 + b, 8, 9, "skin", bands=(-0.35, 0.05, 0.55, 0.86, 0.97))
    s.blob(24 + l, 24 + b, 7, 6, "skin", bands=(-0.35, 0.05, 0.55, 0.86, 0.97))
    # wrinkles
    for (pts) in ([(10, 40), (13, 44), (12, 49)], [(36, 38), (38, 43)], [(20, 55), (24, 57), (28, 55)]):
        s.line([(x + l, y + b) for x, y in pts], "skin", 0)
    # the mouth: a lipless band of teeth across the belly
    s.poly([(14 + l, 44 + b), (34 + l, 44 + b), (32 + l, 50 + b), (16 + l, 50 + b)], "mouth", grad=(1, 0))
    teeth(s, 15 + l, 33 + l, 45 + b, 3, "teeth", down=True, gap=2)
    teeth(s, 17 + l, 31 + l, 49 + b, 2, "teeth", down=False, gap=2)
    s.line([(14 + l, 44 + b), (34 + l, 44 + b)], "gum", 2)
    # eyes everywhere; on frame 2 some of them blink shut
    eyes = [(16, 28, 2.4, "ffcf3f"), (31, 26, 2.6, "ff3b4d"), (24, 22, 2.0, "ffcf3f"), (11, 36, 1.6, "ff3b4d"),
            (37, 35, 1.8, "ffcf3f"), (20, 35, 1.5, "ff3b4d"), (28, 34, 1.3, "ffcf3f"), (35, 53, 1.4, "ff3b4d"),
            (13, 52, 1.6, "ffcf3f"), (24, 59, 1.4, "ff3b4d"), (9, 46, 1.2, "ffcf3f"), (39, 47, 1.3, "ff3b4d"),
            (19, 22, 1.0, "ff3b4d"), (30, 19, 1.1, "ffcf3f"), (27, 40, 1.0, "ff3b4d"), (18, 41, 1.0, "ffcf3f")]
    for i, (x, y, r, c) in enumerate(eyes):
        if f == 2 and i % 3 == 0:
            s.line([(x - r + l, y + b), (x + r + l, y + b)], "skin", 0)
            continue
        s.eye(x + l, y + b, r, c, glint=r > 1.2)


def wraith(s, f, o):
    b, l = BREATH[f], LEAN[f]
    # it drifts: no feet, a ragged robe trailing into wisps
    hem = [(8 + k * 2.7, 66 + (4 if (k + f) % 2 else 0)) for k in range(12)]
    s.poly([(17 + l, 28 + b), (31 + l, 28 + b), (39, 52), (40, 66)] + hem[::-1] + [(8, 66), (9, 52)], "cloak",
           grad=(2, 0))
    for x0 in (14, 20, 26, 32):
        s.line([(x0 + l * 0.5, 36 + b), (x0 + (x0 - 24) * 0.4, 65)], "cloak", 0)
    for k in range(5):   # wisps dripping from the hem
        x = 11 + k * 6.5
        s.line([(x, 67), (x + [0, 1, 0, -1][(k + f) % 4], 70)], "cloak", 1, only_on=False)
    # gaunt arms, too long, with hooked fingers
    ah = [0, 1, 1, -1][f]
    for side in (-1, 1):
        sh = (24 + side * 8 + l, 31 + b)
        el = (24 + side * 16, 40 + b)
        hd = (24 + side * 18, 52 + ah * side)
        s.limb([sh, el, hd], 1.9, "cloak", r_end=1.2)
        s.limb([(hd[0], hd[1]), (hd[0] + side, hd[1] + 3)], 1.4, "skin", r_end=1.1)
        claw(s, (hd[0] + side, hd[1] + 3), side, "claw", n=3, length=7)
    # antlers of bone, branching
    tw = [0, 1, 0, -1][f]
    for side in (-1, 1):
        def m(pts):
            return [(24 + l + side * x, y + b) for x, y in pts]
        s.limb(m([(5, 14), (9, 8), (12, 3), (13 + tw * 0.5, 0)]), 1.5, "bone", r_end=0.6)
        s.limb(m([(9, 8), (15, 7), (19, 3)]), 1.1, "bone", r_end=0.5)
        s.limb(m([(11, 5), (8, 1)]), 0.9, "bone", r_end=0.4)
        s.limb(m([(15, 7), (19, 10)]), 0.9, "bone", r_end=0.4)
    # long narrow skull-face
    s.blob(24 + l, 21 + b, 7, 10, "skin", bands=(-0.3, 0.1, 0.6, 0.88, 0.98))
    s.blob(24 + l, 31 + b, 5, 3, "cloak", bands=(-0.3, 0.1, 0.6, 0.9))   # the collar
    for side in (-1, 1):   # deep eye pits with a pinprick of light
        s.blob(24 + l + side * 3, 19 + b, 2.2, 2.6, "mouth", bands=(9,), outline=False)
        s.eye(24 + l + side * 3, 19.5 + b, 0.8, "ff3b4d", glint=False)
    s.line([(24 + l, 21 + b), (24 + l, 23 + b)], "skin", 0)
    s.poly([(20 + l, 25 + b), (28 + l, 25 + b), (27 + l, 29 + b), (21 + l, 29 + b)], "mouth", grad=(1, 0))
    teeth(s, 21 + l, 27 + l, 25 + b, 3, "teeth", down=True, gap=1)
    teeth(s, 21 + l, 27 + l, 29 + b, 2, "teeth", down=False, gap=2)
    s.line([(19 + l, 15 + b), (21 + l, 13 + b)], "skin", 4)


def hollow(s, f, o):
    b, l = BREATH[f], LEAN[f]
    feet(s, f, (19, 29), 71, "bone", r=1.8)
    # the cloak, open at the chest to show the ribs
    s.poly([(15 + l, 29 + b), (33 + l, 29 + b), (38, 48), (37, 64), (28, 65), (24, 61), (20, 65), (11, 64),
            (10, 48)], "cloak", grad=(2, 0))
    s.poly([(20 + l, 31 + b), (28 + l, 31 + b), (27, 50), (24, 53), (21, 50)], "mouth", grad=(0, 0),
           outline=False)
    s.limb([(24 + l, 31 + b), (24, 52)], 0.9, "bone", r_end=0.8)   # spine
    for k in range(5):   # ribs
        y = 34 + b + k * 3.4
        w = 4.2 - k * 0.35
        s.limb([(24 + l * 0.6, y), (24 - w, y + 1.4), (24 - w + 0.5, y + 2.6)], 0.7, "bone", r_end=0.5)
        s.limb([(24 + l * 0.6, y), (24 + w, y + 1.4), (24 + w - 0.5, y + 2.6)], 0.7, "bone", r_end=0.5)
    for x0 in (13, 18, 30, 35):
        s.line([(x0 + l * 0.5, 34 + b), (x0 + (x0 - 24) * 0.25, 63)], "cloak", 0)
    # bone arms
    ah = [0, 1, 1, -1][f]
    for side in (-1, 1):
        sh = (24 + side * 10 + l, 32 + b)
        el = (24 + side * 14, 44 + b)
        hd = (24 + side * 13, 54 + ah * side)
        s.limb([sh, el], 1.3, "bone", r_end=1.0)
        s.limb([el, hd], 1.1, "bone", r_end=0.9)
        s.blob(el[0], el[1], 1.6, 1.6, "bone")
        claw(s, hd, side, "bone", n=4, length=4)
    # cowl and skull
    s.blob(24 + l, 21 + b, 11, 11, "cloak", bands=(-0.3, 0.1, 0.65, 0.92))
    s.blob(24 + l, 21 + b, 7.5, 8.5, "bone", bands=(-0.25, 0.1, 0.55, 0.86, 0.97))
    s.blob(24 + l, 28 + b, 5, 3, "bone", bands=(-0.3, 0.1, 0.6, 0.9))   # jaw
    for side in (-1, 1):
        s.blob(24 + l + side * 3.2, 20 + b, 2.4, 2.6, "mouth", bands=(9,), outline=False)
        s.eye(24 + l + side * 3.2, 20.5 + b, 1.0, "ffffff", glint=False)
    s.poly([(23 + l, 24 + b), (25 + l, 24 + b), (24 + l, 26 + b)], "mouth", outline=False)
    for x in range(20, 29, 2):
        s.line([(x + l, 27 + b), (x + l, 29 + b)], "mouth", 0)
    s.line([(19 + l, 15 + b), (22 + l, 13 + b)], "bone", 5)
    s.line([(28 + l, 18 + b), (29 + l, 22 + b)], "bone", 1)   # a crack
    if o.get("crown"):
        for k in range(5):
            x = 17 + k * 3.5 + l
            s.limb([(x, 13 + b), (x + (k - 2) * 0.4, 8 + b - (2 if k == 2 else 0))], 1.0, "gold", r_end=0.4)
        s.poly([(16 + l, 12 + b), (32 + l, 12 + b), (31 + l, 15 + b), (17 + l, 15 + b)], "gold", grad=(4, 1))
        s.eye(24 + l, 13.5 + b, 1.0, "ff3b4d")


def maw(s, f, o):
    b, l = BREATH[f], LEAN[f]
    feet(s, f, (16, 32), 70, "skin", r=3.4)
    ah = [0, 1, 1, -1][f]
    for side in (-1, 1):
        s.limb([(24 + side * 14, 44 + b), (24 + side * 20, 50 + b + ah * side), (24 + side * 20, 56 + ah * side)],
               2.8, "skin", r_end=2.2)
        claw(s, (24 + side * 20, 57 + ah * side), side, "claw", n=3, length=4)
    # a swollen fleshy body that is mostly mouth
    s.blob(24 + l, 40 + b, 18, 22, "skin", bands=(-0.35, 0.05, 0.55, 0.86, 0.97), dither=0.08)
    s.blob(24 + l, 58 + b, 13, 6, "skin", bands=(-0.35, 0.05, 0.55, 0.86, 0.97))
    gape = [0, 2, 1, 3][f]   # it chews
    top, bot = 30 + b, 52 + b + gape
    s.blob(24 + l, (top + bot) / 2, 12, (bot - top) / 2, "gum", bands=(-0.2, 0.3, 0.7, 0.95))
    s.blob(24 + l, (top + bot) / 2 + 1, 9, (bot - top) / 2 - 3, "mouth", bands=(-0.3, 0.3), outline=False)
    # rings of teeth inside, and a tongue
    for ring, (rx, ry) in enumerate(((11.0, (bot - top) / 2 - 0.5), (7.5, (bot - top) / 2 - 4))):
        cy = (top + bot) / 2
        for k in range(18 if ring == 0 else 12):
            a = k * 2 * math.pi / (18 if ring == 0 else 12)
            x, y = 24 + l + math.cos(a) * rx, cy + math.sin(a) * ry
            ix, iy = -math.cos(a), -math.sin(a)       # pointing into the throat
            ln, w = 3.2 - ring * 0.9, 0.9 - ring * 0.15
            s.poly([(x - iy * w, y + ix * w), (x + iy * w, y - ix * w), (x + ix * ln, y + iy * ln)], "teeth",
                   tone=4 if math.sin(a) < 0.3 else 3, outline=False)
    s.blob(24 + l, bot - 5, 4, 2.2, "tongue", bands=(-0.2, 0.3, 0.75, 0.95), outline=False)
    # little eyes above the mouth, and folds of skin
    for (x, y, r) in ((17, 24, 1.6), (31, 24, 1.6), (24, 21, 1.2)):
        s.eye(x + l, y + b, r, "ff3b4d")
    for pts in ([(9, 36), (8, 42), (10, 48)], [(39, 36), (40, 42), (38, 48)], [(14, 59), (24, 61), (34, 59)]):
        s.line([(x + l, y + b) for x, y in pts], "skin", 0)
    s.line([(12 + l, 26 + b), (16 + l, 21 + b), (21 + l, 19 + b)], "skin", 5)


DESIGNS = {"grinner": grinner, "many_eyes": many_eyes, "wraith": wraith, "hollow": hollow, "maw": maw}


def detail(s, design, f, o):
    """Finer touches only the bigger render has room for (pixel coordinates)."""
    fn = DETAILS.get(design)
    if fn:
        fn(s, f, o)


def weeper(s, f, o):
    """A tall thin woman who drifts instead of walking, hair hanging over a face
    that is all wet black eye-holes and a long wailing mouth. The Bride wears a
    stained wedding dress and a veil, and holds a dead bouquet."""
    bride = o.get("bride", False)
    b, l = BREATH[f], LEAN[f]
    sway = [0, 1, 0, -1][f]
    dress = "cloak"
    # the dress: narrow at the waist, falling to a long ragged hem that trails into nothing
    hem = []
    for k in range(15):
        x = 7 + k * 2.4
        hem.append((x, 64 + (3 if (k + f) % 2 else 0) + (2 if k % 4 == 1 else 0)))
    s.poly([(19 + l, 30 + b), (29 + l, 30 + b), (31 + l, 40 + b), (41, 66)] + hem[::-1] + [(7, 66), (17 + l, 40 + b)],
           dress, grad=(3, 0) if bride else (2, 0))
    for x0 in ((15, 24, 33) if bride else (13, 18, 24, 30, 35)):   # long folds
        s.line([(x0 * 0.5 + 12 + l * 0.6, 42 + b), (x0 + (x0 - 24) * 0.35, 64)], dress, 1 if bride else 0)
        s.line([(x0 * 0.5 + 12.6 + l * 0.6, 43 + b), (x0 + 0.8 + (x0 - 24) * 0.35, 63)], dress, 4 if bride else 3)
    if bride:
        # the hem soaked dark from the ground up, in uneven runs
        s.shade(lambda x, y: y > 60 + 3 * math.sin(x * 0.9) + 2 * math.sin(x * 2.3) and y < 70, -1)
        s.shade(lambda x, y: y > 64 + 2 * math.sin(x * 1.7) and y < 70, -1)
    for k in range(6):   # wisps trailing off the hem
        x = 9 + k * 6
        s.line([(x, 67), (x + [0, 1, 0, -1][(k + f) % 4], 71)], dress, 1, only_on=False)
    # the bodice and thin chest
    s.blob(24 + l, 34 + b, 6, 6, dress, bands=(-0.3, 0.1, 0.6, 0.9))
    s.line([(22 + l, 31 + b), (24 + l, 36 + b), (26 + l, 31 + b)], dress, 1)
    if bride:
        # the bouquet: dead flowers, brown and wine-dark, trailing ribbon
        bx, by = 21 + l, 49 + b
        s.limb([(bx, by), (bx + 1, by + 8)], 1.0, "flower", r_end=0.6)
        for (dx, dy, r) in ((-3, -1, 2.2), (2, -2, 2.0), (0, -4, 2.3), (-1, 1, 1.8), (3, 1, 1.7)):
            s.blob(bx + dx, by + dy, r, r * 0.9, "gum" if (dx + dy) % 2 else "flower",
                   bands=(-0.3, 0.1, 0.6, 0.9))
        s.line([(bx + 1, by + 2), (bx + 3, by + 10), (bx + 2 + sway, by + 14)], "veil", 4, only_on=False)
        s.line([(bx - 1, by + 2), (bx - 2, by + 9), (bx - 2 - sway, by + 12)], "veil", 3, only_on=False)
    # hair: long, black, wet, hanging straight down past the shoulders
    hx = 24 + l
    s.blob(hx, 18 + b, 9, 10, "hair", bands=(-0.3, 0.15, 0.7, 0.95))
    for side in (-1, 1):
        s.poly([(hx + side * 4, 12 + b), (hx + side * 10, 16 + b), (hx + side * (11 + sway * 0.5), 38 + b),
                (hx + side * (8 + sway * 0.5), 44 + b), (hx + side * 6, 36 + b), (hx + side * 6, 20 + b)],
               "hair", grad=(2, 0))
        for k in range(4):   # strands
            x = hx + side * (6.5 + k * 1.1)
            s.line([(x, 16 + b), (x + side * 0.4 + sway * 0.3, 40 + b - k * 2)], "hair", 3 if k % 2 else 0)
    # the face: long, grey, hollow-cheeked
    s.blob(hx, 21 + b, 5.5, 8, "skin", bands=(-0.25, 0.1, 0.55, 0.86, 0.97))
    s.line([(hx - 4, 23 + b), (hx - 3, 26 + b)], "skin", 0)      # hollow cheeks
    s.line([(hx + 4, 23 + b), (hx + 3, 26 + b)], "skin", 0)
    # eyes: wet black holes, weeping dark lines down the face
    tear = [0, 1, 2, 3][f]
    for side in (-1, 1):
        s.blob(hx + side * 2.4, 19 + b, 1.8, 2.3, "mouth", bands=(9,), outline=False)
        s.dot(hx + side * 2.4 - 0.5, 18 + b, "teeth", 4)            # a wet glint in the dark
        s.line([(hx + side * 2.6, 21 + b), (hx + side * 2.8, 25 + b), (hx + side * 2.5, 28 + b + tear * 0.5)],
               "tear", 1)
        s.line([(hx + side * 2.2, 21 + b), (hx + side * 2.0, 23 + b)], "tear", 2)
    # the mouth: a long dark O, jaw hanging, a few small teeth
    gape = [0, 1, 1, 0][f]
    s.blob(hx, 26.5 + b + gape * 0.5, 1.7, 3 + gape * 0.6, "mouth", bands=(9,), outline=False)
    s.dot(hx - 1, 24 + b, "teeth", 3)
    s.dot(hx + 1, 24 + b, "teeth", 3)
    s.line([(hx - 3, 15 + b), (hx - 1, 14 + b)], "skin", 4)      # light on the brow
    if bride:
        # the veil: a sheer fall of lace from a band of dead flowers over the crown
        s.poly([(hx - 7, 12 + b), (hx + 7, 12 + b), (hx + 12 + sway, 40 + b), (hx + 9 + sway, 46 + b),
                (hx + 14 + sway, 52 + b), (hx + 6, 50 + b), (hx + 7, 22 + b), (hx - 7, 22 + b), (hx - 6, 50 + b),
                (hx - 14 + sway, 52 + b), (hx - 9 + sway, 46 + b), (hx - 12 + sway, 40 + b)], "veil",
               grad=(4, 2), outline=True)
        # it's sheer: let the face show through the middle
        s.blob(hx, 21 + b, 5.5, 8, "skin", bands=(-0.1, 0.3, 0.7, 0.92), outline=False)
        for side in (-1, 1):
            s.blob(hx + side * 2.4, 19 + b, 1.8, 2.3, "mouth", bands=(9,), outline=False)
            s.line([(hx + side * 2.6, 21 + b), (hx + side * 2.8, 25 + b), (hx + side * 2.5, 28 + b + tear * 0.5)],
                   "tear", 1)
        s.blob(hx, 26.5 + b + gape * 0.5, 1.7, 3 + gape * 0.6, "mouth", bands=(9,), outline=False)
        for k in range(6):   # lace pattern in the veil
            for side in (-1, 1):
                s.dot(hx + side * (8 + k * 0.6), 26 + k * 4 + b, "veil", 5)
        for k in range(5):   # the crown of dried flowers
            x = hx - 6 + k * 3
            s.blob(x, 12 + b - (1 if k % 2 else 0), 1.6, 1.4, "flower" if k % 2 else "gum", bands=(-0.2, 0.3, 0.8))
    # arms: far too long and thin, elbows out, long fingers -- one hand (both, for
    # the Weeper) clawing at her own face
    ah = [0, 1, 0, -1][f]
    for side in (-1, 1):
        sh = (24 + side * 6 + l, 31 + b)
        el = (24 + side * 14, 37 + b + ah * side)
        on_face = not (bride and side < 0)
        hd = (hx + side * 5.5, 27 + b + ah * 0.5) if on_face else (21 + l, 47 + b)
        s.limb([sh, el], 1.4, "skin", r_end=1.1)
        s.limb([el, hd], 1.2, "skin", r_end=1.0)
        s.blob(el[0], el[1], 1.3, 1.3, "skin")
        for kf in range(4):   # long fingers
            if on_face:   # up over the cheek, to the eye
                tip = (hd[0] - side * (0.5 + kf * 1.0), hd[1] - 6.5 + abs(kf - 1.5) * 0.8)
                mid = (hd[0] - side * (0.2 + kf * 0.6) + side * 0.8, hd[1] - 3.5)
            else:         # curled around the bouquet's stems
                tip = (hd[0] + 2.5, hd[1] - 1 + kf * 1.2)
                mid = (hd[0] + 2.0, hd[1] - 2 + kf * 1.1)
            s.limb([hd, mid, tip], 0.5, "skin", r_end=0.3)


def _weeper_d(s, f, o):
    s.texture("hair", 0.10, +1, tones=(0, 1, 2), seed=4)
    s.fuzz("hair", 0.35, seed=8, tone=0)
    s.texture("skin", 0.08, -1, tones=(2, 3), seed=2)
    s.texture("cloak", 0.06, -1, tones=(1, 2, 3, 4), seed=6)
    if o.get("bride"):
        s.texture("veil", 0.12, +1, tones=(2, 3), seed=9)


def _grinner_d(s, f, o):
    s.texture("cloak", 0.10, -1, tones=(1, 2, 3), seed=3)
    s.fuzz("cloak", 0.25, seed=5, tone=0)
    s.texture("skin", 0.08, -1, tones=(2, 3), seed=7)
    s.glints("teeth", 0.10)
    s.glints("gum", 0.12)


def _many_eyes_d(s, f, o):
    s.texture("skin", 0.16, -1, tones=(2, 3, 4), seed=3)   # pocked, wet flesh
    s.glints("skin", 0.05)
    s.glints("gum", 0.10)


def _wraith_d(s, f, o):
    s.texture("cloak", 0.12, -1, tones=(1, 2, 3), seed=5)
    s.fuzz("cloak", 0.35, seed=2, tone=0)
    s.texture("bone", 0.10, -1, tones=(2, 3, 4), seed=8)
    s.texture("skin", 0.10, -1, tones=(2, 3), seed=1)


def _hollow_d(s, f, o):
    s.texture("cloak", 0.10, -1, tones=(1, 2, 3), seed=6)
    s.fuzz("cloak", 0.25, seed=4, tone=0)
    s.texture("bone", 0.12, -1, tones=(2, 3, 4), seed=2)
    if o.get("crown"):
        s.glints("gold", 0.25)


def _maw_d(s, f, o):
    s.texture("skin", 0.14, -1, tones=(2, 3, 4), seed=9)
    s.glints("skin", 0.04)
    s.glints("gum", 0.15)
    s.glints("tongue", 0.2)


DETAILS = {"grinner": _grinner_d, "many_eyes": _many_eyes_d, "wraith": _wraith_d, "hollow": _hollow_d,
           "maw": _maw_d, "weeper": _weeper_d, "bride": _weeper_d}
DESIGNS["weeper"] = weeper
DESIGNS["bride"] = lambda s, f, o: weeper(s, f, dict(o, bride=True))
