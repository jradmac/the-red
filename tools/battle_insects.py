"""Battle sprites for the insects: 48 x 48, front three-quarter view.
Each design is a function (sprite, frame) -> draws; palettes are per variant."""
import math

from pixkit import Sprite

W = H = 48
STEP = [0, -1, 0, 1]      # per-frame bob
FOOT = [(0, 0), (1, -2), (0, 0), (-1, 2)]   # tripod gait: alternating feet lift


def mirror_pts(pts, cx=24):
    return [(2 * cx - x, y) for (x, y) in pts]


def legs(s, base, knee, foot, r, mat, f, phase):
    lift = FOOT[(f + phase * 2) % 4][1]
    k = (knee[0], knee[1] + lift * 0.5)
    ft = (foot[0], foot[1] + lift)
    s.limb([base, k, ft], r, mat, r_end=max(0.6, r * 0.55))
    s.limb(mirror_pts([base, k, ft]), r, mat, r_end=max(0.6, r * 0.55))


def antenna(s, pts, mat, club=None):
    s.limb(pts, 0.7, mat, r_end=0.5)
    s.limb(mirror_pts(pts), 0.7, mat, r_end=0.5)
    if club:
        x, y = pts[-1]
        s.blob(x, y, club, club, mat)
        s.blob(48 - x, y, club, club, mat)


# ---------------------------------------------------------------------------
def beetle(s, f):
    b = STEP[f]
    # back and middle legs (behind the shell), with a spur at the knee
    legs(s, (14, 22 + b), (6, 19 + b), (3, 30), 1.7, "leg", f, 0)
    legs(s, (14, 30 + b), (6, 33 + b), (4, 43), 1.7, "leg", f, 1)
    # wing cases: a big dome, split down the middle
    s.blob(24, 21 + b, 16, 12.5, "shell", bands=(-0.35, 0.05, 0.55, 0.86, 0.97), dither=0.10)
    s.line([(24, 9 + b), (24, 32 + b)], "shell", 0)
    s.line([(25, 10 + b), (25, 31 + b)], "shell", 1)
    for side in (-1, 1):
        # rows of punctures along each case
        for off in (6, 11):
            for k in range(0, 17, 2):
                y = 12 + k + b
                x = 24 + side * (off + round(2.2 * math.sin(k / 16 * math.pi)))
                s.dot(x, y, "shell", 1)
        # pale markings
        s.blob(24 + side * 8, 15 + b, 2.4, 1.7, "mark", outline=False)
        s.blob(24 + side * 12, 23 + b, 1.9, 1.5, "mark", outline=False)
        s.blob(24 + side * 5, 25 + b, 1.4, 1.2, "mark", outline=False)
    # specular streak on the upper left
    s.line([(12, 16 + b), (14, 13 + b), (17, 11 + b), (20, 10 + b)], "shell", 5)
    s.line([(13, 17 + b), (15, 14 + b)], "shell", 4)
    # front legs
    legs(s, (17, 33 + b), (10, 38 + b), (9, 46), 1.6, "leg", f, 0)
    # pronotum (the shield behind the head), with a ridge
    s.blob(24, 31 + b, 11, 5.5, "shell", bands=(-0.4, 0.0, 0.6, 0.9, 0.99), flat=0.7)
    s.line([(17, 29 + b), (21, 28 + b), (27, 28 + b), (31, 29 + b)], "shell", 3)
    s.dot(24, 30 + b, "shell", 1)
    # head
    s.blob(24, 37 + b, 7.5, 5, "leg", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    s.line([(21, 35 + b), (23, 34 + b)], "leg", 4)
    # mandibles: open on frames 1 and 3
    o = 1 if f in (1, 3) else 0
    s.limb([(20, 40 + b), (16 - o, 43 + b), (19 - o, 46)], 1.5, "bone", r_end=0.5)
    s.limb([(28, 40 + b), (32 + o, 43 + b), (29 + o, 46)], 1.5, "bone", r_end=0.5)
    # antennae with clubs
    tw = [0, 1, 0, -1][f]
    antenna(s, [(19, 35 + b), (13, 33 + b), (8 + tw, 29 + b)], "leg", club=1.7)
    # eyes
    s.eye(19.5, 37 + b, 2.0, "ff3b4d")
    s.eye(28.5, 37 + b, 2.0, "ff3b4d")


def spider(s, f):
    b = STEP[f]
    lift = [FOOT[(f + k * 2) % 4][1] for k in range(2)]
    # hind legs behind everything
    for side in (-1, 1):
        pts = [(24 + side * 6, 27 + b), (24 + side * 15, 16 + b), (24 + side * 21, 26 + lift[1])]
        s.limb(pts, 1.4, "leg", r_end=0.6)
        pts = [(24 + side * 6, 29 + b), (24 + side * 18, 22 + b), (24 + side * 23, 36 + lift[0])]
        s.limb(pts, 1.5, "leg", r_end=0.6)
    # abdomen: a hairy bulb with a skull marking
    s.blob(24, 15 + b, 13, 11, "body", bands=(-0.35, 0.05, 0.55, 0.86, 0.97), dither=0.14)
    sk = [(21, 9), (27, 9), (29, 12), (28, 16), (26, 17), (26, 19), (22, 19), (22, 17), (20, 16), (19, 12)]
    s.poly([(x, y + b) for x, y in sk], "mark", grad=(4, 1), outline=False)
    s.blob(22, 13 + b, 1.4, 1.6, "body", bands=(9,), outline=False)   # eye sockets of the skull
    s.blob(26, 13 + b, 1.4, 1.6, "body", bands=(9,), outline=False)
    s.line([(24, 15 + b), (24, 16 + b)], "body", 0)
    for x in (22, 24, 26):
        s.dot(x, 18 + b, "body", 0)
    for k in range(14):   # bristles on the rim
        a = math.pi * (0.95 + k * 0.075)
        x, y = 24 + math.cos(a) * 13.5, 15 + b + math.sin(a) * 11.5
        s.dot(x, y, "body", 3)
    # front legs, arching over the head
    for side in (-1, 1):
        l = lift[0] if side < 0 else lift[1]
        s.limb([(24 + side * 6, 31 + b), (24 + side * 14, 26 + b), (24 + side * 19, 44 + l)], 1.6, "leg", r_end=0.7)
        s.limb([(24 + side * 5, 33 + b), (24 + side * 10, 33 + b), (24 + side * 13, 46 - l)], 1.6, "leg", r_end=0.7)
        for k in range(3):   # spines
            s.dot(24 + side * (15 + k), 29 + k * 4 + b, "leg", 4)
    # cephalothorax
    s.blob(24, 31 + b, 9, 7, "body", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    s.line([(24, 25 + b), (24, 28 + b)], "body", 0)
    # chelicerae and fangs
    o = 1 if f in (1, 3) else 0
    for side in (-1, 1):
        s.blob(24 + side * 3, 38 + b, 2.6, 3, "body", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
        s.limb([(24 + side * 3, 40 + b), (24 + side * (2 + o), 43 + b), (24 + side * (3 + o), 45 + b)], 1.0,
               "fang", r_end=0.4)
    # pedipalps
    s.limb([(18, 36 + b), (15, 39 + b), (16, 42 + b)], 1.0, "leg", r_end=0.6)
    s.limb([(30, 36 + b), (33, 39 + b), (32, 42 + b)], 1.0, "leg", r_end=0.6)
    # eight eyes
    for (x, y, r) in ((21, 31.5, 2.0), (27, 31.5, 2.0), (22.5, 28, 1.2), (25.5, 28, 1.2),
                      (18, 29.5, 1.0), (30, 29.5, 1.0), (17.5, 32.5, 0.9), (30.5, 32.5, 0.9)):
        s.eye(x, y + b, r, "ff3b4d", glint=r > 1.1)


def moth(s, f):
    b = STEP[f] // 1
    flap = [0, -3, 0, 3][f]
    for side in (-1, 1):
        def m(pts):
            return [(24 + side * x, y) for x, y in pts]
        # hind wing
        s.poly(m([(3, 26), (10, 25 + flap // 2), (20, 33 + flap // 2), (16, 44 + flap // 3), (8, 42), (4, 34)]),
               "wing", grad=(2, 1))
        # fore wing
        fw = m([(3, 22), (6, 10 + flap), (14, 4 + flap), (23, 5 + flap), (22, 15 + flap // 2), (16, 26), (8, 30)])
        s.poly(fw, "wing", grad=(3, 1))
        # veins
        s.line(m([(4, 22), (12, 14 + flap), (20, 7 + flap)]), "wing", 0)
        s.line(m([(5, 24), (14, 20 + flap // 2), (22, 13 + flap)]), "wing", 0)
        s.line(m([(5, 27), (12, 33 + flap // 2), (15, 41 + flap // 3)]), "wing", 0)
        # dusty edge
        for k in range(6):
            s.dot(*m([(15 + k * 1.4, 5 + flap + (k % 2))])[0], "wing", 4)
        # the eye-spot: rings with a glowing pupil
        cx, cy = m([(13, 15 + flap // 2)])[0]
        s.blob(cx, cy, 4.2, 4.2, "spot", bands=(-9, 9), outline=False)
        s.blob(cx, cy, 3.0, 3.0, "spot", bands=(9,), outline=False)
        s.blob(cx, cy, 2.0, 2.0, "wing", bands=(-9, 9), outline=False)
        s.eye(cx, cy, 1.2, "ff3b4d")
        hc = m([(12, 36 + flap // 3)])[0]
        s.blob(hc[0], hc[1], 2.2, 2.2, "spot", bands=(-9, 9), outline=False)
    # body: furry thorax, striped abdomen, head
    s.blob(24, 33 + b, 3.6, 8, "body", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    for y in (30, 33, 36, 39):
        s.line([(22, y + b), (26, y + b)], "body", 0)
    s.blob(24, 22 + b, 5, 5.5, "fur", dither=0.5)
    s.blob(24, 15 + b, 4, 3.5, "body", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    # feathered antennae
    tw = [0, 1, 0, -1][f]
    for side in (-1, 1):
        pts = [(24 + side * 2, 12 + b), (24 + side * 6, 7 + b), (24 + side * (11 + tw), 3 + b)]
        s.limb(pts, 0.6, "fur", r_end=0.5)
        for k in range(1, 5):
            x = 24 + side * (2 + k * 2.2)
            y = 12 - k * 2.2 + b
            s.dot(x - side, y - 1, "fur", 3)
            s.dot(x + side, y + 1, "fur", 1)
    s.eye(21.5, 15.5 + b, 1.5, "ff3b4d")
    s.eye(26.5, 15.5 + b, 1.5, "ff3b4d")


def centipede(s, f):
    # a chain of armoured segments rearing up in an S, head on top facing you
    n = 12
    pts = []
    for i in range(n):
        t = i / (n - 1)
        x = 24 + math.sin(t * math.pi * 1.5 + 0.5 + f * math.pi / 2 * 0.35) * (11 - t * 6)
        y = 45 - t * 33
        pts.append((x, y))
    body = pts[:-1]
    for i, (x, y) in enumerate(body):   # legs first: one pair per segment
        ph = (i + f) % 2
        d = 1 if ph else -1
        r = 4.8 - i * 0.16
        for side in (-1, 1):
            s.limb([(x + side * (r - 1), y), (x + side * (r + 4), y - 2 + d), (x + side * (r + 7), y + 2 + d)],
                   0.9, "leg", r_end=0.5)
    for i in range(len(body) - 1, -1, -1):   # back to front: tail first
        x, y = body[i]
        r = 4.8 - i * 0.16
        s.blob(x, y, r + 1, r * 0.72, "body", bands=(-0.4, 0.0, 0.55, 0.88, 0.98))
        s.line([(x - r + 0.5, y + 1), (x + r - 0.5, y + 1)], "body", 1)
        s.line([(x - r * 0.6, y - r * 0.4), (x - r * 0.1, y - r * 0.55)], "body", 4)
    # head with long antennae and venom claws
    hx, hy = pts[-1]
    tw = [0, 1, 0, -1][f]
    for side in (-1, 1):
        s.limb([(hx + side * 2, hy - 2), (hx + side * 8, hy - 8), (hx + side * (15 + tw), hy - 8)], 0.7, "leg",
               r_end=0.4)
    s.blob(hx, hy, 5.5, 4.5, "body", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    s.line([(hx - 3, hy - 2), (hx - 1, hy - 3)], "body", 5)
    o = 1 if f in (1, 3) else 0
    for side in (-1, 1):
        s.limb([(hx + side * 3, hy + 2), (hx + side * (5 + o), hy + 5), (hx + side * (2 + o), hy + 7)], 1.1,
               "fang", r_end=0.4)
    s.eye(hx - 2.5, hy - 0.5, 1.3, "ff3b4d")
    s.eye(hx + 2.5, hy - 0.5, 1.3, "ff3b4d")


def tick(s, f):
    b = STEP[f]
    sw = [0, 1, 0, -1][f]
    # legs: four pairs, short and jointed
    for k, (by, ky, fy) in enumerate(((30, 30, 36), (32, 35, 42), (34, 39, 46), (28, 24, 30))):
        lift = FOOT[(f + k) % 4][1]
        for side in (-1, 1):
            s.limb([(24 + side * 8, by + b), (24 + side * (15 + k % 2), ky + b), (24 + side * (19 - k), fy + lift)],
                   1.4, "leg", r_end=0.6)
            s.dot(24 + side * (15 + k % 2), ky + b - 1, "leg", 4)
    # engorged abdomen, glossy, veined
    s.blob(24 + sw * 0.3, 18 + b, 16, 14 + sw * 0.4, "body", bands=(-0.45, -0.08, 0.45, 0.84, 0.96))
    for (pts) in ([(15, 12), (18, 18), (17, 25)], [(31, 10), (30, 16), (33, 22)], [(22, 8), (24, 14), (23, 20)],
                  [(26, 22), (28, 27)]):
        s.line([(x, y + b) for x, y in pts], "body", 1)
    s.line([(13, 12 + b), (15, 8 + b), (19, 6 + b)], "body", 5)
    s.dot(13, 14 + b, "body", 4)
    # the shield (scutum) and the mouthparts
    s.blob(24, 32 + b, 9, 5.5, "plate", bands=(-0.3, 0.1, 0.6, 0.9, 0.99), flat=0.75)
    s.line([(19, 31 + b), (23, 30 + b)], "plate", 4)
    s.blob(24, 38 + b, 3.5, 2.5, "plate", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    s.limb([(24, 40 + b), (24, 45 + b)], 1.2, "fang", r_end=0.5)
    for y in (41, 43):
        s.dot(23, y + b, "fang", 0)
        s.dot(25, y + b, "fang", 0)
    s.limb([(21, 39 + b), (19, 43 + b)], 0.8, "plate", r_end=0.5)
    s.limb([(27, 39 + b), (29, 43 + b)], 0.8, "plate", r_end=0.5)
    s.eye(19, 32.5 + b, 1.3, "ff3b4d")
    s.eye(29, 32.5 + b, 1.3, "ff3b4d")


def scarab(s, f):
    b = STEP[f]
    legs(s, (14, 22 + b), (5, 21 + b), (3, 31), 1.8, "leg", f, 0)
    legs(s, (14, 30 + b), (5, 34 + b), (4, 43), 1.8, "leg", f, 1)
    # round wing cases with a gilded rim and a sunburst fanning down from the seam
    s.blob(24, 20 + b, 15, 12, "shell", bands=(-0.4, 0.0, 0.55, 0.86, 0.97))
    for k in range(-4, 5):
        if k == 0:
            continue
        a = math.pi / 2 + k * 0.30
        s.line([(24 + math.cos(a) * 3, 9 + b + math.sin(a) * 3), (24 + math.cos(a) * 13, 9 + b + math.sin(a) * 15)],
               "mark", 3 if k < 0 else 2)
    s.blob(24, 9.5 + b, 3, 2, "mark", bands=(-0.1, 0.4, 0.85), outline=False)
    for k in range(40):   # gilded rim
        a = math.pi * (0.05 + k * 0.0225) + math.pi
        x, y = 24 + math.cos(a) * 14.4, 20 + b - math.sin(a) * 11.4
        if y > 20 + b - 11 and (k % 3):
            s.dot(round(x), round(y), "mark", 2)
    s.line([(24, 8 + b), (24, 31 + b)], "shell", 0)
    s.line([(12, 15 + b), (15, 11 + b), (19, 9 + b)], "shell", 5)
    s.line([(13, 16 + b), (15, 13 + b)], "shell", 4)
    # front legs: toothed digging legs
    for side in (-1, 1):
        lift = FOOT[(f + (0 if side < 0 else 2)) % 4][1]
        pts = [(24 + side * 7, 33 + b), (24 + side * 13, 37 + b), (24 + side * 15, 45 + lift)]
        s.limb(pts, 2.0, "leg", r_end=1.0)
        for k in range(3):
            s.dot(24 + side * (16 + k % 2), 38 + k * 2 + b, "leg", 4)
    # pronotum, then the head with its great curved horn
    s.blob(24, 31 + b, 10.5, 5, "shell", bands=(-0.45, -0.05, 0.6, 0.9, 0.99), flat=0.7)
    s.blob(24, 38 + b, 6.5, 4, "horn", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    s.limb([(24, 37 + b), (24, 31 + b), (25, 25 + b), (23, 20 + b), (20, 19 + b)], 2.4, "horn", r_end=0.5)
    s.line([(23, 35 + b), (23, 30 + b), (23, 26 + b)], "horn", 4)
    for k in range(4):   # serrated rim (clypeus)
        s.dot(20 + k * 2.6, 42 + b, "horn", 4)
        s.dot(21 + k * 2.6, 42 + b, "horn", 1)
    tw = [0, 1, 0, -1][f]
    antenna(s, [(19, 38 + b), (14, 39 + b), (10 + tw, 37 + b)], "leg", club=1.3)
    s.eye(19.5, 38 + b, 1.5, "ff3b4d")
    s.eye(28.5, 38 + b, 1.5, "ff3b4d")


def wasp(s, f):
    b = [0, -2, 0, 2][f]   # it hovers
    flap = [0, -4, 0, 4][f]
    # wings: translucent, veined
    for side in (-1, 1):
        def m(pts):
            return [(24 + side * x, y) for x, y in pts]
        s.poly(m([(4, 20 + b), (12, 6 + flap + b), (22, 2 + flap + b), (21, 9 + flap // 2 + b), (10, 22 + b)]),
               "wing", grad=(4, 2))
        s.poly(m([(4, 23 + b), (14, 17 + flap // 2 + b), (19, 20 + flap // 2 + b), (9, 27 + b)]), "wing",
               grad=(3, 2))
        s.line(m([(5, 20 + b), (13, 10 + flap + b), (21, 4 + flap + b)]), "wing", 0)
        s.line(m([(7, 21 + b), (16, 12 + flap // 2 + b)]), "wing", 1)
        s.dot(*m([(14, 8 + flap + b)])[0], "wing", 0)
    # dangling legs
    for side in (-1, 1):
        for k, (x1, y1, x2, y2) in enumerate(((7, 28, 9, 36), (9, 30, 12, 39), (6, 31, 7, 41))):
            sw = [0, 1, 0, -1][(f + k) % 4]
            s.limb([(24 + side * 3, 25 + k + b), (24 + side * x1, y1 + b), (24 + side * (x2 + sw), y2 + b)],
                   0.9, "leg", r_end=0.5)
    # abdomen: banded, ending in the sting
    s.blob(24, 35 + b, 6.5, 9, "body", bands=(-0.35, 0.05, 0.55, 0.86, 0.97))
    for y in (29, 33, 37, 41):
        s.blob(24, y + b, 6.3 - abs(y - 35) * 0.25, 1.4, "band", bands=(-0.2, 0.25, 0.7), outline=False,
               clip=lambda x, yy, cy=35 + b: (x - 24) ** 2 / 42 + (yy - cy) ** 2 / 81 < 1)
    s.limb([(24, 43 + b), (24, 47)], 1.0, "fang", r_end=0.3)
    # thorax and head
    s.blob(24, 24 + b, 5.5, 4.5, "body", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    s.line([(21, 22 + b), (24, 21 + b)], "band", 3)
    s.blob(24, 15 + b, 6, 5, "body", bands=(-0.3, 0.1, 0.6, 0.9, 0.99))
    s.blob(24, 18 + b, 2.5, 1.8, "band", bands=(-0.2, 0.3, 0.8), outline=False)
    o = 1 if f in (1, 3) else 0
    s.limb([(22, 19 + b), (21 - o, 21 + b), (23, 22 + b)], 0.8, "fang", r_end=0.4)
    s.limb([(26, 19 + b), (27 + o, 21 + b), (25, 22 + b)], 0.8, "fang", r_end=0.4)
    tw = [0, 1, 0, -1][f]
    antenna(s, [(22, 11 + b), (19, 6 + b), (15 + tw, 5 + b)], "body")
    s.eye(20.5, 14 + b, 2.2, "ffcf3f")
    s.eye(27.5, 14 + b, 2.2, "ffcf3f")


def mantis(s, f):
    b = STEP[f]
    strike = [0, -2, 0, 3][f]
    # hind and middle legs, long and thin
    for side in (-1, 1):
        lift = FOOT[(f + (0 if side < 0 else 2)) % 4][1]
        s.limb([(24 + side * 3, 28 + b), (24 + side * 12, 24 + b), (24 + side * 17, 40 + lift)], 1.0, "leg",
               r_end=0.5)
        s.limb([(24 + side * 3, 32 + b), (24 + side * 14, 34 + b), (24 + side * 19, 46 - lift)], 1.0, "leg",
               r_end=0.5)
    # abdomen with folded wings
    s.blob(24, 37 + b, 6.5, 9, "body", bands=(-0.35, 0.05, 0.55, 0.86, 0.97))
    s.poly([(19, 30 + b), (24, 28 + b), (29, 30 + b), (27, 44 + b), (24, 46 + b), (21, 44 + b)], "wing",
           grad=(3, 1), outline=True)
    s.line([(24, 29 + b), (24, 45 + b)], "wing", 0)
    s.line([(21, 33 + b), (23, 40 + b)], "wing", 1)
    s.line([(27, 33 + b), (25, 40 + b)], "wing", 1)
    # long neck (prothorax)
    s.limb([(24, 28 + b), (24, 14 + b)], 2.4, "body", r_end=1.8)
    # raptorial forelegs, folded as if praying; they snap out when it strikes
    for side in (-1, 1):
        femur = [(24 + side * 2, 18 + b), (24 + side * 9, 22 + b + strike)]
        tibia = [(24 + side * 9, 22 + b + strike), (24 + side * 5, 15 + b + strike * 2), (24 + side * 3, 18 + b + strike)]
        s.limb(femur, 2.2, "arm", r_end=1.6)
        s.limb(tibia, 1.4, "arm", r_end=0.6)
        for k in range(4):   # spines
            x = 24 + side * (3 + k * 1.6)
            s.dot(x, 19 + k * 0.8 + b + strike * 0.5, "arm", 0)
    # triangular head with huge eyes
    s.poly([(15, 7 + b), (33, 7 + b), (27, 14 + b), (24, 16 + b), (21, 14 + b)], "body", grad=(3, 1))
    s.line([(18, 8 + b), (23, 8 + b)], "body", 4)
    s.blob(16.5, 7.5 + b, 3, 3, "eye", bands=(-0.2, 0.3, 0.75, 0.95))
    s.blob(31.5, 7.5 + b, 3, 3, "eye", bands=(-0.2, 0.3, 0.75, 0.95))
    s.eye(16.5, 8 + b, 1.0, "ff3b4d")
    s.eye(31.5, 8 + b, 1.0, "ff3b4d")
    tw = [0, 1, 0, -1][f]
    s.limb([(22, 7 + b), (19, 2 + b), (12 + tw, 1)], 0.5, "leg")
    s.limb([(26, 7 + b), (29, 2 + b), (36 - tw, 1)], 0.5, "leg")
    s.limb([(23, 15 + b), (24, 17 + b), (25, 15 + b)], 0.6, "fang")


DESIGNS = {"beetle": beetle, "spider": spider, "moth": moth, "centipede": centipede, "tick": tick,
           "scarab": scarab, "wasp": wasp, "mantis": mantis}
