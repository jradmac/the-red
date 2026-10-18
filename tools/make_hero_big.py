"""Builds the big hero -- the hero as you see them up close, in battle (from
behind) and in the bag (turning on the pedestal):

    assets/hero_big.png          64 x 96 frames
    assets/hero_big_blue.png     the same with the lantern burning blue
    assets/hero_big_p2.png       player 2 (blue cloth where player 1 wears red)
    assets/hero_big_p2_blue.png
    assets/hero_big_arm.png      16 x 28: the right arm on its own, seen from
                                 behind (battle swing), one per armor; row 0
                                 player 1, row 1 player 2

Columns: 0 facing down (at you), 1 up (your back), 2 left, 3 right,
4 up without the right arm (it's drawn on its own, swinging).
Rows: the armor looks in HeroLook.LOOKS order -- none, worn cloak, leather
vest, chain shirt, bone mail, iron plate.

The frame is the 16 x 24 overworld frame at 4x: feet at the bottom middle,
so HeroLook can swap one for the other. Drawn with pixkit, lit from the upper
left like the creatures.
Run:  python3 tools/make_hero_big.py
"""
import math
from pathlib import Path

from PIL import Image

from pixkit import Sprite

ROOT = Path(__file__).resolve().parent.parent
W, H = 64, 96
LOOKS = ["", "worn_cloak", "leather_vest", "chain_shirt", "bone_mail", "iron_plate"]
ARM_W, ARM_H = 16, 28
ARM_SHOULDER = (8, 4)     # in the arm piece; the hand is 16 px straight below it

BASE = {
    "skin": "f0bf9c", "hair": "6e4128", "tunic": "4d5a7a", "pants": "3a3448", "boot": "5c3a26",
    "belt": "4a2e20", "buckle": "e8b850", "leather": "8e5a32", "chain": "8a92a4", "bone": "ddd2b6",
    "metal": "8a93a8", "dark": "4a4452", "pack": "7a4e2e", "roll": "5d7aa6", "brass": "c8913a",
    "eye": "2a1e2e", "blush": "e88a80", "strap": "5a3820",
}
CLOTH = {1: "c4323e", 2: "3a5cc4"}       # the red (player 1) or blue (player 2) cloth
FLAME = {False: ("fff4c0", "ffd060", "ff9a30"), True: ("e8fbff", "8fd8ff", "3a88ff")}


class Hero:
    """Draws one frame. All x are mirrored for facing right (3), so the side
    view is drawn once; the light stays upper left."""

    def __init__(self, look, facing, blue, arm=True):
        self.s = Sprite(W, H, grain=0.12, cast=True)
        self.look = look
        self.facing = facing
        self.blue = blue
        self.with_arm = arm
        self.flip = facing == 3

    # coordinate helpers (mirror for facing right)
    def X(self, x):
        return W - x if self.flip else x

    def P(self, pts):
        return [(self.X(x), y) for x, y in pts]

    def blob(self, cx, cy, rx, ry, mat, **kw):
        return self.s.blob(self.X(cx), cy, rx, ry, mat, **kw)

    def limb(self, pts, r, mat, **kw):
        return self.s.limb(self.P(pts), r, mat, **kw)

    def poly(self, pts, mat, **kw):
        return self.s.poly(self.P(pts), mat, **kw)

    def line(self, pts, mat, tone=None, only_on=True):
        self.s.line(self.P(pts), mat, tone, only_on)

    def dot(self, x, y, mat, tone=None):
        self.s.dot(self.X(x), y, mat, tone)

    # --- shared parts ----------------------------------------------------------
    @property
    def hooded(self):
        return self.look in ("worn_cloak", "leather_vest", "chain_shirt", "bone_mail")

    @property
    def hood_mat(self):
        return "dark" if self.look == "bone_mail" else "cloth"

    def lantern(self, hx, hy):
        """The lantern hanging from a hand at (hx, hy): brass cage, glass, flame."""
        s = self.s
        top = hy + 3
        self.line([(hx, hy), (hx, top)], "brass", 1, only_on=False)
        self.blob(hx, top + 1, 3.2, 1.6, "brass")                       # the cap
        self.poly([(hx - 3.5, top + 2), (hx + 3.5, top + 2), (hx + 3, top + 10), (hx - 3, top + 10)], "brass",
                  tone=1)
        hot, mid, low = FLAME[self.blue]
        for y in range(top + 3, top + 10):
            for x in range(int(hx) - 2, int(hx) + 3):
                k = abs(x - hx) / 2.5 + abs(y - (top + 6.5)) / 4.0
                c = hot if k < 0.45 else (mid if k < 0.8 else low)
                s.pdot(self.X(x) - (1 if self.flip else 0), y, c)
        for x in (hx - 3, hx + 3):   # the cage bars
            self.line([(x, top + 2), (x, top + 10)], "brass", 3)
        self.blob(hx, top + 11, 3.8, 1.4, "brass")                      # the base

    def boots_legs(self, front):
        lp, rp = (26, 38) if front else (25, 39)
        for x in (lp, rp):
            self.limb([(x + (1 if x < 32 else -1), 70), (x, 84)], 3.7, "pants", r_end=3.4)
        for x in (lp, rp):
            self.limb([(x, 81), (x, 90)], 3.6, "boot", r_end=3.6)
            self.blob(x + (0 if front else 0), 91, 4.4, 2.8, "boot")
            self.line([(x - 3, 82), (x + 3, 82)], "boot", 4)              # the turned-down cuff
        if self.look == "iron_plate":   # greaves
            for x in (lp, rp):
                self.limb([(x, 77), (x, 88)], 3.9, "metal", r_end=3.7)
                self.line([(x - 1, 78), (x - 1, 87)], "metal", 5)
                self.blob(x, 77, 3.4, 2.2, "metal")

    def torso_front(self):
        look = self.look
        body = {"chain_shirt": "chain", "bone_mail": "tunic"}.get(look, "tunic")
        if look == "iron_plate":
            body = "cloth"
        # the tunic, flaring a little at the hips
        self.poly([(21, 50), (43, 50), (45, 72), (44, 77), (20, 77), (19, 72)], body, grad=(3, 1))
        self.blob(32, 58, 12, 10, body, bands=(-0.3, 0.1, 0.6, 0.92))
        self.line([(32, 51), (32, 64)], body, 1)
        for x0 in (24, 29, 35, 40):   # hem folds
            self.line([(x0, 70), (x0 + (x0 - 32) * 0.15, 76)], body, 1)
        if look == "chain_shirt":
            # rings: rows of little arcs
            for y in range(50, 77, 2):
                for x in range(19, 46, 2):
                    if self.s.px[y][self.X(x)] and self.s.px[y][self.X(x)][0] == "chain":
                        self.s.pdot(self.X(x + (y // 2) % 2), y, "chain", 4 if (x + y) % 4 == 0 else 1)
        if look == "leather_vest":
            self.poly([(21, 51), (29, 51), (31, 74), (21, 75), (19, 66)], "leather", grad=(3, 1))
            self.poly([(35, 51), (43, 51), (45, 66), (43, 75), (33, 74)], "leather", grad=(3, 1))
            for y in range(54, 72, 3):   # lacing across the gap
                self.line([(30, y), (34, y + 2)], "strap", 1, only_on=False)
                self.line([(34, y), (30, y + 2)], "strap", 3, only_on=False)
            for x0 in (22, 42):          # stitching
                for y in range(53, 73, 2):
                    self.dot(x0 + (1 if x0 < 32 else -1) * (y - 53) * 0.05, y, "leather", 4)
        if look == "bone_mail":
            for k in range(5):           # overlapping plates of bone, like ribs
                y = 52 + k * 4.6
                w = 11.5 - abs(k - 2) * 0.8
                self.blob(32, y, w, 2.6, "bone", bands=(-0.3, 0.1, 0.55, 0.88, 0.97), flat=0.6)
                self.line([(32 - w + 2, y + 1), (32 + w - 2, y + 1)], "bone", 1)
            self.blob(32, 52, 3, 2.2, "bone")
        if look == "iron_plate":
            self.blob(32, 59, 12.5, 11, "metal", bands=(-0.3, 0.05, 0.5, 0.85, 0.96))   # the breastplate
            self.line([(32, 49), (32, 69)], "metal", 2)
            self.line([(25, 53), (28, 50)], "metal", 5)
            for x in (23, 41):
                self.dot(x, 64, "metal", 0)
        # the belt and its buckle
        self.poly([(20, 69), (44, 69), (44, 72), (20, 72)], "belt", grad=(3, 1))
        self.poly([(30, 68.5), (34.5, 68.5), (34.5, 72.5), (30, 72.5)], "buckle", tone=3)
        self.dot(31, 69, "buckle", 5)
        self.dot(32, 70, "belt", 0)
        # the pouch on the hip
        self.blob(24, 74, 3, 3.2, "leather", bands=(-0.3, 0.1, 0.6, 0.9))
        self.line([(21.5, 73), (26.5, 73)], "leather", 1)

    def arm(self, sh, el, hd, sleeve, near=True):
        self.limb([sh, el], 3.5, sleeve, r_end=3.0)
        self.limb([el, hd], 3.0, sleeve, r_end=2.7)
        if self.look == "iron_plate":
            self.blob(sh[0], sh[1] + 1, 5.2, 4.2, "metal", bands=(-0.3, 0.05, 0.5, 0.85, 0.96))   # pauldron
            self.blob(el[0], el[1] + 3, 3.4, 3.6, "metal")
        if self.look == "bone_mail":
            self.blob(sh[0], sh[1] + 1, 4.6, 3.6, "bone")
        self.blob(hd[0], hd[1] + 2, 2.8, 2.7, "skin")

    def head_front(self):
        hood = self.hooded
        if hood:
            self.blob(32, 31, 17, 16.5, self.hood_mat, bands=(-0.3, 0.1, 0.6, 0.9, 0.98))
        elif self.look == "iron_plate":
            pass
        else:
            self.blob(32, 30, 15.5, 15, "hair", bands=(-0.3, 0.1, 0.6, 0.9, 0.98))
        self.blob(32, 35, 12.5, 11.5, "skin", bands=(-0.4, 0.0, 0.5, 0.86, 0.98))
        # hair: a fringe over the brow and locks at the temples
        self.poly([(20, 28), (25, 22), (32, 20), (40, 22), (44, 28), (43, 32), (39, 29), (35, 31), (32, 28),
                   (28, 31), (24, 29), (21, 33)], "hair", grad=(4, 1))
        self.line([(26, 25), (30, 23)], "hair", 5)
        for x in (22, 42):
            self.limb([(x, 30), (x + (1 if x < 32 else -1), 40)], 1.6, "hair", r_end=1.0)
        # eyes, brows, nose, mouth
        for x in (26.5, 37.5):
            self.poly([(x - 1.5, 33), (x + 1.5, 33), (x + 1.5, 38), (x - 1.5, 38)], "eye", tone=1, outline=False)
            self.dot(x - 1.2, 33.5, "eye", 5)
            self.dot(x + 0.6, 36.5, "eye", 3)
            self.line([(x - 2, 31), (x + 1.5, 30.5)], "hair", 0, only_on=False)
        self.dot(32, 38, "skin", 1)
        self.line([(30.5, 41), (33.5, 41)], "skin", 0)
        self.dot(24, 39.5, "blush", 2)
        self.dot(25, 39.5, "blush", 3)
        self.dot(39, 39.5, "blush", 2)
        self.dot(40, 39.5, "blush", 3)
        if hood:
            # the rim of the hood around the face, and its peak
            self.limb([(20, 40), (19, 30), (24, 19), (32, 16.5), (40, 19), (45, 30), (44, 40)], 1.8,
                      self.hood_mat, r_end=1.8)
            self.line([(25, 19), (31, 17)], self.hood_mat, 5)
        if self.look == "iron_plate":
            # the helm: a rounded cap with a brow ridge and cheek guards
            self.blob(32, 27, 16, 13, "metal", bands=(-0.3, 0.05, 0.5, 0.85, 0.96),
                      clip=lambda x, y: y < 31)
            self.limb([(19, 30), (44.5, 30)], 1.6, "metal")
            for x in (19.5, 44.5):
                self.limb([(x, 30), (x + (0.5 if x < 32 else -0.5), 41)], 2.0, "metal", r_end=1.6)
            self.line([(32, 15), (32, 29)], "metal", 1)
            self.line([(24, 20), (29, 17)], "metal", 5)
            for x in (22, 42):
                self.dot(x, 27, "metal", 0)

    def head_back(self):
        if self.hooded:
            m = self.hood_mat
            self.blob(32, 31, 17, 16.5, m, bands=(-0.3, 0.1, 0.6, 0.9, 0.98))
            self.line([(32, 15), (32, 44)], m, 1)                              # the seam
            self.line([(33, 16), (33, 43)], m, 4)
            for side in (-1, 1):                                               # folds gathering at the neck
                self.line([(32 + side * 9, 20), (32 + side * 11, 32), (32 + side * 7, 45)], m, 1)
                self.line([(32 + side * 9 + 1, 21), (32 + side * 11 + 1, 32), (32 + side * 7 + 1, 44)], m,
                          3 if side < 0 else 2)
            hood = lambda x, y: y > 41 and y < 49 and abs(x - 32) < 17                   # shadow at the nape
            self.s.shade(lambda x, y: hood(x, y) and self.s.px[int(y)][int(x)] is not None
                         and self.s.px[int(y)][int(x)][0] == m, -1)
            self.line([(25, 20), (30, 18)], m, 5)
        elif self.look == "iron_plate":
            self.blob(32, 30, 16, 15, "metal", bands=(-0.3, 0.05, 0.5, 0.85, 0.96))
            self.line([(32, 15), (32, 44)], "metal", 1)
            self.limb([(18.5, 37), (45.5, 37)], 1.6, "metal")
            self.line([(24, 20), (29, 17)], "metal", 5)
        else:
            self.blob(32, 30, 15.5, 15, "hair", bands=(-0.3, 0.1, 0.6, 0.9, 0.98))
            for x0 in (23, 28, 33, 38):   # strands
                self.line([(x0, 18 + abs(x0 - 31) * 0.3), (x0 + (x0 - 31) * 0.2, 43)], "hair", 1)
                self.line([(x0 + 1, 19), (x0 + 1 + (x0 - 31) * 0.2, 40)], "hair", 3)
            self.line([(24, 21), (29, 18)], "hair", 5)

    def head_side(self):
        # facing left: face on the left, back of the head on the right
        if self.hooded:
            self.blob(33, 31, 16, 16, self.hood_mat, bands=(-0.3, 0.1, 0.6, 0.9, 0.98))
        elif self.look == "iron_plate":
            self.blob(33, 30, 15.5, 15, "metal", bands=(-0.3, 0.05, 0.5, 0.85, 0.96))
        else:
            self.blob(33, 30, 15, 15, "hair", bands=(-0.3, 0.1, 0.6, 0.9, 0.98))
        self.blob(28, 35, 10, 11, "skin", bands=(-0.4, 0.0, 0.5, 0.86, 0.98))
        self.blob(18.6, 37.5, 1.6, 1.8, "skin")                               # the nose
        self.poly([(19, 27), (24, 21), (33, 19), (37, 24), (34, 26), (28, 26), (22, 30)], "hair", grad=(4, 1))
        if not self.hooded and self.look != "iron_plate":
            self.poly([(34, 22), (44, 26), (46, 38), (42, 44), (37, 40), (36, 30)], "hair", grad=(3, 1))
        if not self.hooded and self.look != "iron_plate":
            self.blob(35, 36, 2.6, 3.2, "skin")                               # the ear
            self.dot(35, 36, "skin", 1)
        x = 23
        self.poly([(x - 1, 33), (x + 1.5, 33), (x + 1.5, 38), (x - 1, 38)], "eye", tone=1, outline=False)
        self.dot(x - 0.5, 33.5, "eye", 5)
        self.line([(x - 2, 31), (x + 2, 30.5)], "hair", 0, only_on=False)
        self.line([(20, 41), (22.5, 41)], "skin", 0)
        self.dot(26, 39.5, "blush", 2)
        self.dot(27, 39.5, "blush", 3)
        if self.hooded:
            # the rim of the hood's opening: over the brow and down behind the cheek
            self.limb([(18, 25), (24, 19.5), (32, 19), (37, 25), (38, 34), (36, 42), (31, 46)], 1.8,
                      self.hood_mat, r_end=1.8)
            self.line([(22, 20), (29, 18)], self.hood_mat, 5)
        if self.look == "iron_plate":
            self.blob(33, 27, 15.5, 12.5, "metal", bands=(-0.3, 0.05, 0.5, 0.85, 0.96),
                      clip=lambda x, y: y < 30.5 or ((x < W - 36) if self.flip else (x > 36)))
            self.limb([(19, 30), (47, 30)], 1.6, "metal")
            self.line([(24, 20), (29, 17)], "metal", 5)

    def capelet(self, back):
        """The hood's short cape over the shoulders (all the hooded looks); the
        worn cloak's falls much further."""
        if not self.hooded or self.look == "bone_mail":
            return   # (bone mail: just the hood, so the plates show)
        m = self.hood_mat
        long = self.look == "worn_cloak"
        bottom = 84 if long else 55
        pts = [(18, 46), (46, 46), (49, bottom - 4), (47, bottom)]
        hem = [(47 - k * 3.5, bottom + (2 if k % 2 else 0) + (1 if k % 3 == 0 else 0)) for k in range(10)]
        pts += hem + [(15, bottom), (15, bottom - 4)]
        if back or not long:
            self.poly(pts, m, grad=(3, 1) if not long else (2, 0))
            for x0 in (22, 28, 36, 42):
                self.line([(x0, 49), (x0 + (x0 - 32) * 0.2, bottom - 1)], m, 1)
        else:
            # from the front the cloak hangs open: just its two edges, falling past the knees
            for side in (-1, 1):
                self.poly([(32 + side * 8, 46), (32 + side * 15, 47), (32 + side * 17, 82), (32 + side * 14, 86),
                           (32 + side * 11, 83), (32 + side * 10, 70)], m, grad=(3, 1))
                self.line([(32 + side * 11, 52), (32 + side * 13, 82)], m, 4 if side < 0 else 1)
        if self.look == "worn_cloak":   # patches and frayed edges
            self.s.fuzz(m, 0.3, seed=11, tone=1)

    def backpack(self):
        # the pack, its flap and buckles, and the bedroll strapped on top
        self.poly([(21, 49), (43, 49), (44, 74), (20, 74)], "pack", grad=(3, 1))
        self.blob(32, 62, 11.5, 12, "pack", bands=(-0.3, 0.1, 0.6, 0.9))
        self.poly([(21, 50), (43, 50), (42, 62), (32, 64), (22, 62)], "pack", grad=(4, 2))   # the flap
        self.line([(22, 62), (32, 64), (42, 62)], "pack", 0)
        for x in (27, 37):
            self.line([(x, 52), (x, 70)], "strap", 1)
            self.poly([(x - 1.5, 63), (x + 1.5, 63), (x + 1.5, 66), (x - 1.5, 66)], "buckle", tone=3)
        self.blob(32, 70, 4, 2.4, "pack", bands=(-0.3, 0.1, 0.6, 0.9))         # the front pocket
        self.limb([(19, 47), (45, 47)], 4.5, "roll")
        for x in (24, 40):
            self.line([(x, 43), (x, 51)], "strap", 1)
        self.line([(20, 45), (44, 45)], "roll", 4)

    # --- the facings -------------------------------------------------------------
    def down(self):
        sl = "metal" if self.look == "iron_plate" else ("chain" if self.look == "chain_shirt" else "tunic")
        sl = "cloth" if self.look == "worn_cloak" else sl
        if self.look == "worn_cloak":
            self.capelet(back=True)   # the back of the cloak, behind the legs
        self.boots_legs(True)
        self.torso_front()
        if self.look == "worn_cloak":
            self.capelet(back=False)
        self.arm((19, 50), (15.5, 60), (17, 68), sl)
        self.arm((45, 50), (48.5, 60), (47, 68), sl)
        self.lantern(47, 71)
        if self.look != "worn_cloak":
            self.capelet(back=False)
        self.head_front()

    def up(self):
        sl = "metal" if self.look == "iron_plate" else ("chain" if self.look == "chain_shirt" else "tunic")
        sl = "cloth" if self.look == "worn_cloak" else sl
        self.boots_legs(False)
        self.torso_front()            # (from behind it's the same shape, under the pack)
        self.capelet(back=True)
        self.backpack()
        self.arm((19, 50), (15.5, 60), (17, 68), sl)
        self.lantern(17, 71)
        if self.with_arm:
            self.arm_back_right(sl)
        self.head_back()

    def arm_back_right(self, sl):
        self.arm((45, 50), (48.5, 60), (47, 68), sl)

    def side(self):
        sl = "metal" if self.look == "iron_plate" else ("chain" if self.look == "chain_shirt" else "tunic")
        sl = "cloth" if self.look == "worn_cloak" else sl
        # far arm (behind), legs mid-stride, body, pack behind, near arm with the lantern
        self.limb([(33, 50), (36, 60), (38, 68)], 3.0, sl, r_end=2.6)
        self.blob(38, 70, 2.5, 2.5, "skin")
        if self.look == "worn_cloak":
            self.poly([(28, 46), (42, 47), (46, 82), (40, 86), (30, 84), (26, 70)], "cloth", grad=(2, 0))
        for (x0, x1) in ((35, 37), (29, 27)):
            self.limb([(x0, 70), (x1, 84)], 3.7, "pants", r_end=3.4)
            self.limb([(x1, 81), (x1, 90)], 3.6, "boot")
            self.blob(x1 - 1.5, 91, 5, 2.8, "boot")
            self.line([(x1 - 3, 82), (x1 + 3, 82)], "boot", 4)
        if self.look == "iron_plate":
            for x1 in (37, 27):
                self.limb([(x1, 77), (x1, 88)], 3.9, "metal", r_end=3.7)
                self.line([(x1 - 1, 78), (x1 - 1, 87)], "metal", 5)
        body = {"chain_shirt": "chain"}.get(self.look, "tunic")
        if self.look == "iron_plate":
            body = "cloth"
        self.poly([(25, 50), (39, 50), (40, 72), (39, 77), (24, 77), (23, 72)], body, grad=(3, 1))
        self.blob(31, 58, 8.5, 9.5, body, bands=(-0.3, 0.1, 0.6, 0.92))
        if self.look == "chain_shirt":
            for y in range(50, 77, 2):
                for x in range(23, 41, 2):
                    p = self.s.px[y][self.X(x)]
                    if p and p[0] == "chain":
                        self.s.pdot(self.X(x + (y // 2) % 2), y, "chain", 4 if (x + y) % 4 == 0 else 1)
        if self.look == "leather_vest":
            self.poly([(24, 51), (38, 51), (40, 66), (38, 75), (25, 74), (23, 66)], "leather", grad=(3, 1))
            self.line([(25, 54), (25, 72)], "leather", 4)
        if self.look == "bone_mail":
            for k in range(5):
                y = 52 + k * 4.6
                self.blob(30, y, 8.5, 2.6, "bone", bands=(-0.3, 0.1, 0.55, 0.88, 0.97), flat=0.6)
        if self.look == "iron_plate":
            self.blob(30, 59, 9, 10.5, "metal", bands=(-0.3, 0.05, 0.5, 0.85, 0.96))
            self.line([(24, 53), (27, 50)], "metal", 5)
        self.poly([(23, 69), (40, 69), (40, 72), (23, 72)], "belt", grad=(3, 1))
        self.poly([(22.5, 68.5), (26, 68.5), (26, 72.5), (22.5, 72.5)], "buckle", tone=3)
        # the pack on the back
        self.poly([(38, 50), (46, 52), (47, 72), (39, 74)], "pack", grad=(3, 1))
        self.limb([(42, 44), (42, 52)], 4.5, "roll")
        self.line([(40, 47), (44, 47)], "roll", 4)
        self.capelet_side()
        # near arm, swinging forward a little, lantern in hand
        self.limb([(30, 50), (27, 60), (24, 67)], 3.4, sl, r_end=2.8)
        if self.look == "iron_plate":
            self.blob(30, 51, 5, 4.2, "metal", bands=(-0.3, 0.05, 0.5, 0.85, 0.96))
        if self.look == "bone_mail":
            self.blob(30, 51, 4.4, 3.6, "bone")
        self.blob(24, 69, 2.8, 2.7, "skin")
        self.lantern(24, 72)
        self.head_side()

    def capelet_side(self):
        if not self.hooded or self.look in ("worn_cloak", "bone_mail"):
            if self.look == "worn_cloak":
                self.poly([(23, 46), (40, 46), (44, 58), (36, 60), (24, 58)], "cloth", grad=(3, 1))
            return
        self.poly([(22, 46), (41, 46), (45, 57), (40, 59), (30, 58), (23, 58)], self.hood_mat, grad=(3, 1))
        self.line([(30, 48), (31, 57)], self.hood_mat, 1)

    def draw(self):
        {0: self.down, 1: self.up, 2: self.side, 3: self.side}[self.facing]()
        return self.s

    def finish(self, pal):
        s = self.s
        s.texture("cloth", 0.08, -1, tones=(2, 3, 4), seed=3)
        s.texture("dark", 0.08, -1, tones=(2, 3, 4), seed=3)
        s.texture("leather", 0.12, -1, tones=(2, 3, 4), seed=5)
        s.texture("pack", 0.10, -1, tones=(2, 3, 4), seed=7)
        s.texture("bone", 0.10, -1, tones=(2, 3, 4), seed=9)
        s.glints("metal", 0.06)
        s.texture("hair", 0.10, +1, tones=(1, 2, 3), seed=4)
        return s.image(pal)


# the legendary armour, the king's mantle, is look 6 (tools/legendary_gear.py)
import legendary_gear  # noqa: E402
Hero = legendary_gear.mantle_hero(Hero)
LOOKS.append(legendary_gear.CLOAK)


def palette(p2):
    pal = dict(BASE)
    pal["cloth"] = CLOTH[2 if p2 else 1]
    return pal


def arm_piece(look, pal):
    """The right arm seen from behind, shoulder at ARM_SHOULDER, hand 16 px below."""
    h = Hero(look, 1, False)
    s = Sprite(ARM_W, ARM_H, grain=0.12, cast=True)
    h.s = s
    sl = "metal" if look == "iron_plate" else ("chain" if look == "chain_shirt" else "tunic")
    sl = "cloth" if look == "worn_cloak" else sl
    sx, sy = ARM_SHOULDER
    h.arm((sx, sy), (sx + 1, sy + 9), (sx, sy + 15), sl)
    return h.finish(pal)


def main():
    for p2 in (False, True):
        pal = palette(p2)
        for blue in (False, True):
            sheet = Image.new("RGBA", (W * 5, H * len(LOOKS)), (0, 0, 0, 0))
            for row, look in enumerate(LOOKS):
                for col in range(5):
                    h = Hero(look, 1 if col == 4 else col, blue)
                    h.with_arm = col != 4
                    h.draw()
                    sheet.paste(h.finish(pal), (col * W, row * H))
            name = "hero_big" + ("_p2" if p2 else "") + ("_blue" if blue else "") + ".png"
            sheet.save(ROOT / "assets" / name)
    arms = Image.new("RGBA", (ARM_W * len(LOOKS), ARM_H * 2), (0, 0, 0, 0))
    for r, p2 in enumerate((False, True)):
        for i, look in enumerate(LOOKS):
            arms.paste(arm_piece(look, palette(p2)), (i * ARM_W, r * ARM_H))
    arms.save(ROOT / "assets" / "hero_big_arm.png")
    print("wrote the big hero: 4 sheets of %d looks, and the arm pieces" % len(LOOKS))


if __name__ == "__main__":
    main()
