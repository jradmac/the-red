"""The spirit a fallen hero leaves behind in two-player games: assets/spirit.png.

    row 0 (24 px high):  the spirit hovering where they fell -- 4 frames for
                         Red, then 4 for Blue (16 x 24 each)
    row 1 (y 24, 16 px): its bag icon, Red then Blue (16 x 16)
    row 2 (y 40, 64 px): its close-up in the bag, Red then Blue (64 x 64)

A ghost of the hero in her hood, pale and glowing in her colour, her cloak
trailing away into wisps instead of feet, eyes lit. Run:
python3 tools/make_spirit_art.py
"""
from pathlib import Path
import math

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PAL = {
    "red":  ["3c0e26", "8e2c4c", "d8506c", "ff8a9e", "ffc4ce", "fff2f4"],
    "blue": ["10183c", "2c449c", "4a78e0", "86b2ff", "c4dcff", "f2f8ff"],
}
EYE = {"red": "fff6c8", "blue": "f4fff0"}


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def shape(u, v, frame, tail_k=1.0):
    """Signed inside-ness of the spirit at (u, v) in 0..1 (positive = inside),
    and the face opening."""
    sway = math.sin(frame * math.pi / 2.0) * 0.06 * tail_k
    # hood: a round head with a little peak, slightly forward
    hd = 0.2 - math.hypot((u - 0.5) / 1.0, (v - 0.27) / 1.05)
    peak = 0.06 - math.hypot((u - 0.5 + (v - 0.06) * 0.6) / 0.5, (v - 0.07) / 1.6)
    head = max(hd, peak)
    # cloak: widening from the shoulders, then trailing away into a tail
    if v < 0.36:
        body = -1.0
    else:
        t = (v - 0.36) / 0.64
        # shoulders, a cloak swelling out, then trailing away to a curling tail
        if t < 0.3:
            half = 0.2 + 0.11 * math.sin(t / 0.3 * math.pi / 2)
        else:
            half = 0.31 * (1.0 - (t - 0.3) / 0.7) ** 1.25 + 0.015
        cx = 0.5 + (sway * 1.6 + 0.07 * tail_k) * (t ** 2) * (1 if frame % 4 < 2 else 0.6) \
            + sway * math.sin(t * math.pi * 1.2 + frame * 0.8) * t
        # the hem frays into wisps
        wisp = 0.0
        if t > 0.5:
            wisp = 0.035 * math.sin((u - cx) * 30.0 + frame * 1.4 + t * 6.0) * (t - 0.5) * 2.0
        body = half - abs(u - cx) + wisp
    inside = max(head, body)
    face = 0.105 - math.hypot((u - 0.5) / 1.1, (v - 0.31) / 0.85)
    return inside, face


def render(W, H, col, frame, ss=6, tail_k=1.0, detail=False):
    pal = [np.array(rgb(c)) for c in PAL[col]]
    img = np.zeros((H, W, 4), np.uint8)
    for y in range(H):
        for x in range(W):
            ins = 0
            fac = 0
            for sy in range(ss):
                for sx in range(ss):
                    u = (x + (sx + 0.5) / ss) / W
                    v = (y + (sy + 0.5) / ss) / H
                    a, f = shape(u, v, frame, tail_k)
                    ins += a > 0
                    fac += f > 0 and a > 0
            if ins < ss * ss * 0.45:
                continue
            u = (x + 0.5) / W
            v = (y + 0.5) / H
            # light from inside, brightest at the heart, and from above left
            heart = math.hypot((u - 0.48) * 1.3, (v - 0.48) * 0.9)
            k = 1.0 - heart * 1.9 + (0.5 - u) * 0.35 + (0.4 - v) * 0.25
            lvl = int(np.clip(1 + k * 4.6, 1, 5))
            if fac > ss * ss * 0.5:
                lvl = 1 if detail else 0   # the dark inside of the hood
            img[y, x] = pal[lvl]
    # outline: any empty pixel beside the figure gets the darkest colour
    a = img[..., 3] > 0
    pad = np.pad(a, 1)
    ring = (pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]) & ~a
    img[ring] = pal[0]
    # its eyes, lit, in the shadow of the hood
    ey = int(round(H * 0.315))
    ex = W * 0.5
    gap = max(1, round(W * 0.09))
    for sgn in (-1, 1):
        xx = int(round(ex + sgn * gap - (0.5 if sgn < 0 else 0.5)))
        img[ey, xx] = rgb(EYE[col])
        if detail:
            img[ey - 1, xx] = rgb(EYE[col])
    return img


def motes(img, col, frame, n, seed):
    """A few sparks drifting up off it."""
    rng = np.random.default_rng(seed + frame)
    H, W = img.shape[:2]
    for i in range(n):
        x = int(rng.integers(1, W - 1))
        y = int((rng.integers(2, H - 4) - frame * 2) % (H - 3))
        if img[y, x, 3] == 0:
            img[y, x] = rgb(PAL[col][4])


def main():
    sheet = Image.new("RGBA", (128, 104), (0, 0, 0, 0))
    for ci, col in enumerate(["red", "blue"]):
        for f in range(4):
            fr = render(16, 24, col, f)
            motes(fr, col, f, 2, 7 + ci)
            sheet.paste(Image.fromarray(fr), (ci * 64 + f * 16, 0))
        icon = render(16, 16, col, 1, tail_k=0.6)
        sheet.paste(Image.fromarray(icon), (ci * 16, 24))
        big = render(64, 64, col, 1, ss=4, tail_k=1.2, detail=True)
        motes(big, col, 0, 9, 31 + ci)
        sheet.paste(Image.fromarray(big), (ci * 64, 40))
    sheet.save(ROOT / "assets" / "spirit.png")
    print("wrote assets/spirit.png")


if __name__ == "__main__":
    main()
