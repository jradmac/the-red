"""The small (overworld) hero, drawn for the camera: seen from above.

    python3 tools/make_hero_tilt.py      -> assets/hero.png, hero_blue.png, hero_p2.png, hero_p2_blue.png

Why: the 3D view looks down on the labyrinth at ~52 degrees. The hero used to be
drawn at eye level (face in the middle of the head, the body at full height,
the feet a flat line, steps sideways), so she stood in the world like a paper
cut-out. Pokemon draws its people for its overhead camera; so does this. Here
she's a little 3D figure -- head, hood, cloak, tunic, arms, legs, boots, the
lantern in her hand -- *rendered from above* (PITCH), then put on the sheet's
own palette with clean bands and an outline, one sprite pixel per screen pixel:
  - you see the top of the hood; the face sits low, the eyes near its bottom
  - the shoulders and the hood's crown catch the light from above
  - the body is short, the legs shorter; the feet are two boots on the ground
  - a stride moves them up and down the screen (toward and away from you)
The faces are placed by hand-made rules (eyes, blush, a profile at the side).

Same layout as before (tools/make_art.py hero_sheet): 9 columns (stand, walk
x4, run x4) x 4 rows (down, up, left, right) per look, 16 x 24 frames, looks in
HeroLook.LOOKS order (0 none .. 6 the King's Mantle). The left row is the right
row mirrored, as before. The other three sheets are the same recolours as
before (make_art.blue_lantern_sheet / recolor(P2_CLOTHES)), so the hood and
cloak colours below are exactly the ones those swap.

make_art.py's hero_sheet() hands over to this (so rerunning it keeps her), and
make_legendary_gear.py no longer pastes its own look 6 into these sheets.
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets"

PITCH = math.radians(42.0)      # the drawing's viewing angle (the 3D camera is 52; a little less reads better)
FW, FH = 16, 24
FOOT = (8.0, 22.6)              # where the ground under her middle lands in the frame
SCALE = 1.12                    # model pixels -> sprite pixels
SS = 4                          # supersampling per axis
COLS = 9

INK = "1c1020"
SKIN = ["c28c70", "d9a283", "f6d7b8"]
HAIR = ["3a1f16", "4d2a1e", "5e3b25", "7a4630", "8a5a36"]
RED = ["5a1828", "8a2433", "b8343c", "e2574f", "f59a78"]        # (P2_CLOTHES turns exactly these blue)
TUNIC = ["28223a", "3c3550", "4f5a75", "7f90ad"]
LEGS = ["1f1530", "28223a", "3c3550", "4f5a75"]
BOOT = ["3a2418", "4d2a1e", "6a4430", "8a5a36"]
BRASS = ["3a3240", "b88250", "e8b850"]
BLUSH = "f0908a"

LOOKS = [
    # name, head ("hair" | "hood" | "helm"), cloak ("none" | "capelet" | "long"), materials
    ("none", "hair", "none", {"torso": ["2b3548", "3e4c66", "5b6e8c", "7d90ad"], "hair": ["3a1f16", "4d2a1e", "6b3d2a", "8a5236", "a8683f"]}),
    ("worn_cloak", "hood", "long", {"torso": TUNIC, "hood": RED}),
    ("leather_vest", "hood", "capelet", {"torso": ["3e2616", "5e3b22", "8a5a32", "b07a48"], "hood": RED,
                                         "boot": ["2a1810", "4f2f1c", "6a4430"]}),
    ("chain_shirt", "hood", "capelet", {"torso": ["2c313d", "434a5a", "5a6274", "8d96a8", "b5bdcc"], "hood": RED, "chain": True}),
    ("bone_mail", "hood", "capelet", {"torso": ["7a705c", "b0a58c", "e8dfc8", "fff6e0"], "hood": ["241f2a", "352f3d", "4a4252", "6a6176", "8a8196"],
                                      "ribs": True, "boot": ["241f2a", "3a3440", "4a4252"]}),
    ("iron_plate", "helm", "long", {"torso": ["454b5c", "6a7286", "8d96a8", "aab3c4", "d0d8e6"], "hood": RED,
                                    "helm": ["3a4050", "5a6274", "8d96a8", "b5bdcc", "d0d8e6"],
                                    "legs": ["454b5c", "5a6274", "8d96a8"], "boot": ["2c313d", "454b5c", "6a7286"]}),
    ("kings_mantle", "hood", "long", {"torso": TUNIC, "hood": ["2a163e", "3e2258", "5a3480", "7e52a8", "a27cc8"],
                                      "ermine": ["a8a094", "d8d2c6", "f0ece4"], "gold": ["8a6a1e", "d8a838", "f0d070"], "crown": True}),
]


def hx(s):
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], float)


# --- signed distances (units: model pixels; y up, z = the way she faces) -------------------

def sph(p, c, r):
    return np.linalg.norm(p - c, axis=-1) - r


def ell(p, c, r):
    q = (p - c) / r
    k0 = np.linalg.norm(q, axis=-1)
    k1 = np.linalg.norm(q / r, axis=-1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)


def cap(p, a, b, r):
    pa, ba = p - a, b - a
    h = np.clip((pa * ba).sum(-1) / (ba * ba).sum(), 0, 1)
    return np.linalg.norm(pa - ba * h[..., None], axis=-1) - r


def bell(p, top, bottom_y, r_top, r_bot, flat=0.85):
    """Cloth falling from the shoulders: a capped cone, a little flattened front to back."""
    y = p[..., 1]
    k = np.clip((top[1] - y) / (top[1] - bottom_y), 0, 1)
    r = r_top + (r_bot - r_top) * k
    dx = p[..., 0] - top[0]
    dz = (p[..., 2] - top[2]) / flat
    d = np.sqrt(dx * dx + dz * dz) - r
    d = np.maximum(d, y - top[1] - 0.5)
    return np.maximum(d, bottom_y - y)


def figure(look, facing, col):
    """The parts [(material, sdf)] for one frame, and the head centre / lantern (model space)."""
    _, head, cloak, mats = look
    if col == 0:
        s, bob, lean, run = 0.0, 0.0, 0.0, False
    else:
        run = col >= 5
        k = (col - 1) % 4                       # contact, pass, contact (other foot), pass
        s = [1.0, 0.0, -1.0, 0.0][k] * (1.35 if run else 1.0)
        bob = (0.0 if k % 2 == 0 else 0.45) * (1.4 if run else 1.0)
        lean = 0.7 if run else 0.0
    parts = []
    # legs and boots: the leading foot reaches forward (+z) and down the screen
    for side, sgn in ((-1, 1), (1, -1)):
        fz = sgn * s * 2.1
        lift = max(0.0, -sgn * s) * (1.3 if run else 0.8)
        foot = np.array([side * 1.8, 0.9 + lift, fz + 0.4])
        hip = np.array([side * 1.6, 5.2 + bob, lean * 0.4])
        parts.append(("legs", lambda p, hip=hip, foot=foot: cap(p, hip, foot + [0, 0.6, -0.3], 1.25)))
        parts.append(("boot", lambda p, foot=foot: ell(p, foot, np.array([1.5, 1.0, 2.0]))))
    tz = lean * 0.8
    # the torso (tunic, vest, mail, plate...)
    parts.append(("torso", lambda p: ell(p, np.array([0.0, 7.7 + bob, 0.2 + tz]), np.array([3.4, 3.3, 2.6]))))
    # cloth over it
    if cloak == "long":
        parts.append(("hood", lambda p: np.maximum(bell(p, np.array([0.0, 11.0 + bob, -0.3 + tz]), 3.4 + bob, 3.6, 5.6),
                                                   (p[..., 2] - 1.6 - tz - (11.0 + bob - p[..., 1]) * 0.12))))   # open at the front
    elif cloak == "capelet":
        parts.append(("hood", lambda p: bell(p, np.array([0.0, 11.0 + bob, -0.2 + tz]), 8.6 + bob, 3.7, 4.6)))
    # arms swing against the legs; the right hand carries the lantern
    sleeve = "hood" if cloak == "long" else "torso"
    for side, sgn in ((-1, -1), (1, 1)):
        sh = np.array([side * 3.6, 10.0 + bob, tz])
        hand = np.array([side * 4.4, 5.8 + bob + (0.8 if run else 0.0), sgn * s * (2.2 if run else 1.6) + 0.6 + tz])
        parts.append((sleeve, lambda p, sh=sh, hand=hand: cap(p, sh, hand + [0, 1.4, 0], 1.3)))
        parts.append(("skin", lambda p, hand=hand: sph(p, hand, 1.0)))
    lantern = np.array([4.6, 3.8 + bob + (0.8 if run else 0.0), s * (2.2 if run else 1.6) + 1.2 + tz])
    if mats.get("spear"):
        grip = np.array([4.6, 6.0 + bob, 1.0])
        parts.append(("spear", lambda p: cap(p, grip + [0, -5.0, 0], grip + [0, 15.0, 0], 0.55)))
        parts.append(("helm", lambda p: ell(p, grip + [0, 16.4, 0], np.array([0.9, 1.8, 0.9]))))   # its blade
    elif mats.get("basket"):
        parts.append(("brass", lambda p: ell(p, lantern + [0, 0.4, 0], np.array([1.8, 1.4, 1.6]))))
    else:
        parts.append(("brass", lambda p: ell(p, lantern, np.array([1.2, 1.6, 1.2]))))
    # the head
    hc = np.array([0.0, 15.0 + bob, 0.6 + tz * 1.2])
    parts.append(("skin", lambda p: ell(p, hc + [0, -0.8, 0.8], np.array([4.1, 3.7, 3.7]))))
    if head in ("hair", "short"):
        # no hood: hair over the crown and down the back, a fringe at the front
        parts.append(("hair", lambda p: np.maximum(ell(p, hc + [0, 0.5, -0.1], np.array([4.7, 4.6, 4.4])),
                                                   -(p[..., 1] - (hc[1] + 1.9) + np.maximum(p[..., 2] - hc[2] - 2.2, 0) * 0.35))))
        if head == "hair":
            parts.append(("hair", lambda p: cap(p, hc + [0, 1.0, -3.2], hc + [0, -3.6, -3.6], 2.0)))   # hair down her back
    else:
        parts.append(("hair", lambda p: np.maximum(ell(p, hc + [0, 0.5, 0.1], np.array([4.5, 4.3, 4.1])),
                                                   -(p[..., 1] - (hc[1] + 1.3) + np.maximum(p[..., 2] - hc[2] - 2.5, 0) * 0.5))))
        mat = "helm" if head == "helm" else "hood"
        rz = 4.4 if head == "helm" else 4.6

        def hood(p, mat=mat, rz=rz):
            shell = ell(p, hc + [0, 0.5, -1.3 if mat == "hood" else -0.9], np.array([5.5, 5.4, rz]))
            rxy = np.linalg.norm((p - hc - [0, -1.3, 0])[..., :2], axis=-1)
            opening = np.maximum(-(p[..., 2] - (hc[2] + 0.6)), rxy - (4.3 if mat == "hood" else 3.9))
            return np.maximum(shell, -opening)
        parts.append((mat, hood))
        if head == "hood":
            parts.append(("hood", lambda p: cap(p, hc + [0, 4.6, -2.2], hc + [0, 2.4, -4.4], 1.1)))   # its point, hanging back
        else:
            parts.append(("helm", lambda p: cap(p, hc + [0, 5.6, -2.0], hc + [0, 5.6, 2.0], 0.7)))    # a crest over the helm
    if "ermine" in mats:
        parts.append(("ermine", lambda p: np.maximum(ell(p, np.array([0.0, 10.9 + bob, 0.0 + tz]), np.array([4.9, 1.6, 4.0])),
                                                     -(p[..., 2] - 2.6 - tz))))
    return parts, hc, lantern


class Frame:
    def __init__(self, look, facing, col):
        self.look, self.facing, self.col = look, facing, col
        self.parts, self.hc, self.lantern = figure(look, facing, col)
        self.yaw = {0: 0.0, 1: math.pi, 3: math.pi / 2}[facing]
        self.shift = {0: 0.0, 1: 0.0, 3: -1.2}[facing]
        self.fwd = np.array([0.0, -math.sin(PITCH), -math.cos(PITCH)])
        self.up = np.array([0.0, math.cos(PITCH), -math.sin(PITCH)])

    def to_model(self, p):
        cy, sy = math.cos(self.yaw), math.sin(self.yaw)
        x, y, z = p[..., 0] / SCALE, p[..., 1] / SCALE, p[..., 2] / SCALE
        return np.stack([x * cy - z * sy, y, x * sy + z * cy], -1)

    def to_world(self, pm):
        cy, sy = math.cos(self.yaw), math.sin(self.yaw)
        x, y, z = np.asarray(pm) * SCALE
        return np.array([x * cy + z * sy, y, -x * sy + z * cy])

    def screen(self, pm):
        q = self.to_world(pm)
        return (FOOT[0] - 0.5 + q[0] - self.shift, FOOT[1] - 0.5 - (q[1] * self.up[1] + q[2] * self.up[2]))

    def scene(self, pw):
        pm = self.to_model(pw)
        best = np.full(pm.shape[:-1], 1e9)
        mat = np.full(pm.shape[:-1], -1)
        for i, (_, f) in enumerate(self.parts):
            d = f(pm)
            take = d < best
            best = np.where(take, d, best)
            mat = np.where(take, i, mat)
        return best * SCALE, mat

    def render(self):
        H, W = FH * SS, FW * SS
        ys, xs = np.mgrid[0:H, 0:W].astype(float)
        sx = (xs + 0.5) / SS - FOOT[0] + self.shift
        su = FOOT[1] - (ys + 0.5) / SS
        right = np.array([1.0, 0.0, 0.0])
        o = sx[..., None] * right + su[..., None] * self.up - self.fwd * 40.0
        t = np.zeros((H, W))
        hit = np.zeros((H, W), bool)
        for _ in range(110):
            d, _m = self.scene(o + self.fwd * t[..., None])
            hit |= d < 0.04
            t = np.where(hit, t, t + np.maximum(d * 0.8, 0.04))
        p = o + self.fwd * t[..., None]
        d, mat = self.scene(p)
        hit &= p[..., 1] > -0.5
        e = 0.12
        n = np.stack([self.scene(p + [e, 0, 0])[0] - self.scene(p - [e, 0, 0])[0],
                      self.scene(p + [0, e, 0])[0] - self.scene(p - [0, e, 0])[0],
                      self.scene(p + [0, 0, e])[0] - self.scene(p - [0, 0, e])[0]], -1)
        n /= np.linalg.norm(n, axis=-1, keepdims=True) + 1e-9
        L = np.array([-0.45, 0.8, 0.45]); L /= np.linalg.norm(L)    # from above, a little left and in front
        light = 0.22 + 0.78 * np.clip((n * L).sum(-1), 0, 1)
        # down to sprite pixels: covered if most of it is; the commonest part wins; its median light
        img = np.zeros((FH, FW, 4), np.uint8)
        depth = np.full((FH, FW), 1e9)
        names = [m for m, _ in self.parts]
        mats = self.look[3]
        self.matmap = [[None] * FW for _ in range(FH)]
        for y in range(FH):
            for x in range(FW):
                hs = hit[y * SS:(y + 1) * SS, x * SS:(x + 1) * SS]
                if hs.sum() < SS * SS * 0.45:
                    continue
                ms = mat[y * SS:(y + 1) * SS, x * SS:(x + 1) * SS][hs]
                ls = light[y * SS:(y + 1) * SS, x * SS:(x + 1) * SS][hs]
                ts = t[y * SS:(y + 1) * SS, x * SS:(x + 1) * SS][hs]
                kinds = [names[i] for i in ms]
                m = max(sorted(set(kinds)), key=kinds.count)   # (sorted: ties break the same way every run)
                sel = np.array([k == m for k in kinds])
                v = float(np.median(ls[sel]))
                ramp = self.ramp(m)
                k = int(np.clip((v ** 1.25) * len(ramp) - 0.35, 0, len(ramp) - 1))
                self.matmap[y][x] = m
                img[y, x, :3] = hx(ramp[k])
                img[y, x, 3] = 255
                depth[y, x] = float(np.median(ts[sel]))
        self.img, self.depth = img, depth
        self.details()
        self.outline()
        return Image.fromarray(self.img, "RGBA")

    def ramp(self, m):
        mats = self.look[3]
        return {"skin": mats.get("skin", SKIN), "hair": mats.get("hair", HAIR), "hood": mats.get("hood", RED),
                "helm": mats.get("helm", RED), "torso": mats["torso"], "legs": mats.get("legs", LEGS),
                "boot": mats.get("boot", BOOT), "brass": mats.get("brass", BRASS), "spear": ["4a3420", "6a4a2a", "8a6a40"],
                "ermine": mats.get("ermine", ["f0ece4"])}[m]

    def put(self, x, y, col):
        if 0 <= x < FW and 0 <= y < FH and self.img[y, x, 3]:
            self.img[y, x, :3] = hx(col)

    def details(self):
        img, mm, f = self.img, self.matmap, self.facing
        mats = self.look[3]
        # seams where one part passes in front of another
        for y in range(FH):
            for x in range(FW):
                for dy, dx in ((1, 0), (0, 1)):
                    yy, xx = y + dy, x + dx
                    if yy < FH and xx < FW and img[y, x, 3] and img[yy, xx, 3] and self.depth[yy, xx] - self.depth[y, x] > 1.8 \
                            and mm[yy][xx] != mm[y][x]:
                        img[yy, xx, :3] = (img[yy, xx, :3] * 0.6).astype(np.uint8)
        # mail and bone: patterns on the torso
        for y in range(FH):
            for x in range(FW):
                if mm[y][x] != "torso":
                    continue
                if mats.get("chain") and (x + y) % 2 == 0:
                    ramp = mats["torso"]
                    c = [hx(r) for r in ramp]
                    cur = img[y, x, :3].astype(float)
                    i = int(np.argmin([((cur - cc) ** 2).sum() for cc in c]))
                    img[y, x, :3] = c[max(i - 1, 0)]
                if mats.get("ribs") and y % 2 == 1 and f != 1:
                    img[y, x, :3] = hx("2a2430")
        # the lantern: its glass glows (blue_lantern_sheet turns these blue)
        X, Y = self.screen(self.lantern)
        xi, yi = int(round(X)), int(round(Y))
        if 0 <= xi < FW and 0 <= yi < FH and img[yi, xi, 3] and mats.get("lantern", True):
            img[yi, xi, :3] = hx("ffe9a0")
            if yi + 1 < FH and img[yi + 1, xi, 3]:
                img[yi + 1, xi, :3] = hx("f5a33a")
        # the face
        skin = [hx(c) for c in SKIN]
        if f == 0:
            rows = [y for y in range(FH) if any(mm[y][x] == "skin" for x in range(4, 12))]
            # (the face, not the hands: the hands are low)
            rows = [y for y in rows if y < 14]
            if rows:
                r = rows[0]
                for ex in (5, 10):
                    self.put(ex, r, "1f1530")
                    self.put(ex, r + 1, "1f1530")
                    self.put(ex, r, "1f1530")
                for bx in (4, 11):
                    if mm[r + 2][bx] == "skin":
                        self.put(bx, r + 2, mats.get("blush", BLUSH))
        elif f == 3:
            _, Yc = self.screen(self.hc + np.array([0.0, -1.4, 0.0]))
            yc = int(round(Yc))
            fr = mats.get("hair", HAIR)
            for dy, w in ((-3, 2), (-2, 3), (-1, 3), (0, 3), (1, 3), (2, 2)):
                y = yc + dy
                xs_ = [x for x in range(FW) if img[y, x, 3]]
                if not xs_:
                    continue
                edge = max(xs_)
                for k in range(w):
                    x = edge - k
                    sk = self.ramp("skin")
                    tone = sk[2] if k > 0 else sk[1]
                    if dy == -3:
                        tone = fr[3] if k == 0 else fr[2]
                    img[y, x, :3] = hx(tone)
                    mm[y][x] = "skin"
                if dy in (-1, 0):
                    img[y, edge - 2, :3] = hx("1f1530")
                if dy == 1:
                    img[y, edge - 2, :3] = hx(BLUSH)
        # the King's Mantle: a gold circlet round the hood, a red stone, gold down the cloak's edges
        if mats.get("crown"):
            g = mats["gold"]
            ys_ = [y for y in range(FH) if any(img[y, x, 3] for x in range(FW))]
            row = ys_[0] + (2 if f != 1 else 2)
            xs_ = [x for x in range(FW) if img[row, x, 3]]
            if len(xs_) >= 4:
                for x in xs_[1:-1]:
                    img[row, x, :3] = hx(g[2] if x < 8 else g[1])
                img[row, xs_[len(xs_) // 2], :3] = hx("ff3b4d")
                for x in xs_[2:-2:2]:
                    if row - 1 >= 0:
                        self.put(x, row - 1, g[1])
            if f == 0:
                for y in range(12, FH - 3):
                    for x in range(FW):
                        if mm[y][x] == "hood" and x + 1 < FW and mm[y][x + 1] == "torso" and x < 8:
                            img[y, x, :3] = hx(g[1])
                        if mm[y][x] == "hood" and x - 1 >= 0 and mm[y][x - 1] == "torso" and x > 8:
                            img[y, x, :3] = hx(g[1])
            for y in range(FH):
                for x in range(FW):
                    if mm[y][x] == "ermine" and (x * 3 + y) % 5 == 0:
                        img[y, x, :3] = hx("2a2430")

    def outline(self):
        img = self.img
        a = img[..., 3] > 0
        pad = np.pad(a, 1)
        near = pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]   # (no wrapping round the edges)
        out = (~a) & near
        img[out, :3] = hx(INK)
        img[out, 3] = 255


def hero_sheet(looks=None):
    """The hero.png sheet (7 looks x 4 rows x 9 columns of 16 x 24)."""
    looks = looks or LOOKS
    sheet = Image.new("RGBA", (FW * COLS, FH * 4 * len(looks)), (0, 0, 0, 0))
    for li, look in enumerate(looks):
        for row, facing in enumerate((0, 1, 2, 3)):
            for col in range(COLS):
                if facing == 2:
                    continue
                fr = Frame(look, facing, col).render()
                sheet.paste(fr, (col * FW, (li * 4 + row) * FH))
                if facing == 3:
                    sheet.paste(fr.transpose(Image.FLIP_LEFT_RIGHT), (col * FW, (li * 4 + 2) * FH))
        print("  look", li, look[0], file=sys.stderr)
    return sheet


# --- the villagers (make_village.py's npcs.png: 5 columns, 20 people) ---------------------------

def _dark(c, k=0.8):
    return "".join("%02x" % int(int(c[i:i + 2], 16) * k) for i in (0, 2, 4))


def _person(skin, hair, tunic, pants="3c3550", pants_dk="28223a", head="hair", cloak="none", **extra):
    s_, sd, blush = skin
    mats = {"skin": [_dark(sd), sd, s_], "blush": blush, "hair": [_dark(hair[3]), hair[3], hair[0], hair[1], hair[2]],
            "torso": [tunic[3], tunic[2], tunic[0], tunic[1]], "hood": [tunic[3], tunic[2], tunic[0], tunic[1]],
            "legs": [_dark(pants_dk), pants_dk, pants], "lantern": False, "basket": True,
            "brass": ["6a4024", "8a6a3a", "c89a5a"]}
    mats.update(extra)
    return ("person", head, cloak, mats)


def npc_looks():
    """The same 20 people as make_village.npc_sheet(), in the same order and colours."""
    import random
    import make_village as mv
    rnd = random.Random(5)
    looks = []
    for i in range(10):
        looks.append(_person(mv.SKINS[rnd.randrange(len(mv.SKINS))], mv.HAIRS[i % len(mv.HAIRS)],
                             mv.TUNICS[(i * 3) % len(mv.TUNICS)], pants=["3c3550", "4a3a2a", "3a4a3a", "5a4a3a"][i % 4],
                             head="short" if i % 3 == 0 else "hair", cloak="long" if i % 2 == 0 else "none"))
    steel = ["3a4050", "5a6274", "8d96a8", "b5bdcc", "d0d8e6"]
    for t in mv.GUARD_TABARDS:
        looks.append(_person(mv.SKINS[rnd.randrange(2)], mv.HAIRS[0], (t[0], t[1], t[2], "454b5c"), head="helm",
                             helm=steel, legs=["2e3240", "454b5c", "8d96a8"], boot=["2c313d", "454b5c", "6a7286"],
                             spear=True, basket=False))
    looks.append(_person(mv.SKINS[1], mv.HAIRS[3], mv.TUNICS[3], cloak="long", torso=["8a8070", "b8ae99", "e8dfc8"]))   # the shopkeeper's apron
    looks.append(_person(mv.SKINS[0], ("e8e8f0", "f4f4fa", "ffffff", "b0b0c0"), ("5a3e8a", "7e5ab8", "3a2660", "2a1a48"),
                         pants="3a2660", pants_dk="2a1a48", head="hood", cloak="long",
                         hood=["2a1a48", "3a2660", "5a3e8a", "7e5ab8", "a07ad8"], torso=["2a1a48", "3a2660", "4a3270"]))   # the sage
    looks.append(_person(mv.SKINS[2], mv.HAIRS[5], mv.TUNICS[1], cloak="long", torso=["7a6a4a", "a09070", "c8b898"]))   # the innkeeper
    looks.append(_person(mv.SKINS[0], mv.HAIRS[2], mv.TUNICS[2]))
    looks.append(_person(mv.SKINS[3], mv.HAIRS[1], mv.TUNICS[4], head="short"))
    return looks


def npc_sheet():
    looks = npc_looks()
    sheet = Image.new("RGBA", (FW * 5, FH * 4 * len(looks)), (0, 0, 0, 0))
    for li, look in enumerate(looks):
        for row, facing in enumerate((0, 1, 2, 3)):
            if facing == 2:
                continue
            for col in range(5):
                fr = Frame(look, facing, col).render()
                sheet.paste(fr, (col * FW, (li * 4 + row) * FH))
                if facing == 3:
                    sheet.paste(fr.transpose(Image.FLIP_LEFT_RIGHT), (col * FW, (li * 4 + 2) * FH))
    return sheet


def main():
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import make_art
    sheet = hero_sheet()
    sheet.save(OUT / "hero.png")
    make_art.blue_lantern_sheet(OUT / "hero.png").save(OUT / "hero_blue.png")
    make_art.recolor(OUT / "hero.png", make_art.P2_CLOTHES).save(OUT / "hero_p2.png")
    make_art.blue_lantern_sheet(OUT / "hero_p2.png").save(OUT / "hero_p2_blue.png")
    print("wrote hero.png, hero_blue.png, hero_p2.png, hero_p2_blue.png")


if __name__ == "__main__":
    main()
