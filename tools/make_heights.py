"""Builds the cliffs, ledges and slopes around raised ground.

    python3 tools/make_heights.py

assets/heights.png   16x16 tiles, one row per style:
    0 earth (forest, river)  1 swamp  2 mountain  3 courtyard (cut stone)  4 crypt
  columns:
    0 face_a  1 face_b   the cliff face (raised ground to the north)
    2 face_l  3 face_r   the face's west / east end, turning the corner
    4 rim_n              raised ground to the south: its back edge, seen from behind
    5 rim_w   6 rim_e    raised ground to the east / west: its side edge
    7 corner_nw 8 corner_ne   the back corners
    9 ramp_s             a slope (stairs indoors) up to the north
    10 ramp_w 11 ramp_e  a slope up to the east / to the west
Transparent pixels show the low ground drawn underneath.
"""
from pathlib import Path
import sys

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_env import hx, mix, shade  # noqa: E402
from make_village import Canvas, noise  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "assets"
T = 16

STYLES = [
    dict(name="earth", rock=hx("7a6248"), rock_dk=hx("54402e"), rock_lt=hx("9a8060"), top=hx("4a7a3a"), top_lt=hx("6a9a4a"),
         strata=True, steps=False),
    dict(name="swamp", rock=hx("5a5a3e"), rock_dk=hx("3c3c28"), rock_lt=hx("767654"), top=hx("4a6a2e"), top_lt=hx("62843c"),
         strata=True, steps=False),
    dict(name="mountain", rock=hx("8a8478"), rock_dk=hx("5e5a52"), rock_lt=hx("aaa496"), top=hx("8a7862"), top_lt=hx("a49076"),
         strata=True, steps=False),
    dict(name="court", rock=hx("b8b0a0"), rock_dk=hx("8a8272"), rock_lt=hx("d4ccbc"), top=hx("c8c0ae"), top_lt=hx("e0d8c8"),
         strata=False, steps=True),
    dict(name="crypt", rock=hx("4e4860"), rock_dk=hx("342e44"), rock_lt=hx("6a6480"), top=hx("5a5470"), top_lt=hx("7a7490"),
         strata=False, steps=True),
]


def face(cv, st, v, end=None):
    """The cliff face: a lip of the raised ground on top, then rock."""
    for y in range(T):
        for x in range(T):
            if y < 3:
                c = st["top_lt"] if y == 0 else st["top"]
                if y == 2 and noise(x, y, 5 + v) < 0.4:
                    c = st["rock_lt"]
            elif st["strata"]:
                band = (y + (x * 3 + v * 5) // 11) % 5
                c = [st["rock_lt"], st["rock"], st["rock"], st["rock_dk"], st["rock"]][band]
                if noise(x, y, 11 + v) < 0.08:
                    c = shade(c, 0.85)
                if noise(x // 3, y // 2, 17 + v) < 0.06:
                    c = st["rock_dk"]
            else:   # cut stone blocks
                row = (y - 3) // 4
                off = 4 if row % 2 else 0
                c = st["rock"]
                if (y - 3) % 4 == 3 or (x + off) % 8 == 7:
                    c = st["rock_dk"]
                elif (y - 3) % 4 == 0:
                    c = st["rock_lt"]
            cv.set(x, y, c)
    for x in range(T):
        cv.set(x, 3, st["rock_dk"] if x % 3 else shade(st["rock_dk"], 0.8))   # the lip's shadow
        cv.set(x, T - 1, shade(st["rock_dk"], 0.7))
    if end == "l":
        for y in range(T):
            for x in range(3):
                if y > 2 and x < 2 - (y // 8):
                    cv.set(x, y, (0, 0, 0, 0))
            cv.set(2 - (y // 8) if y > 2 else 0, y, st["rock_dk"])
    if end == "r":
        for y in range(T):
            for x in range(T - 3, T):
                if y > 2 and x > T - 3 + (y // 8):
                    cv.set(x, y, (0, 0, 0, 0))
            cv.set(T - 3 + (y // 8) if y > 2 else T - 1, y, st["rock_lt"])


def rim_n(cv, st):
    """The back edge of raised ground (it lies to the south): the top of a
    rock wall seen from above, the low ground behind it in shadow."""
    for x in range(T):
        h = 8 + int(noise(x, 0, 3) * 2)
        for y in range(T - h, T):
            k = y - (T - h)
            c = st["rock_dk"] if k == 0 else (st["rock"] if k < 3 else (st["rock_lt"] if k < 4 else st["top"]))
            if 0 < k < 3 and noise(x, y, 9) < 0.2:
                c = st["rock_lt"]
            cv.set(x, y, c)
        for y in range(max(0, T - h - 3), T - h):
            cv.set(x, y, (0, 0, 0, 60))


def rim_side(cv, st, side):
    """A side edge: raised ground on one side, a band of rock dropping to the low ground."""
    for y in range(T):
        wdt = 9 + int(noise(0, y, 7) * 2)
        for k in range(wdt):
            x = (T - wdt + k) if side == "w" else (wdt - 1 - k)
            if k >= wdt - 3:
                c = st["top"]
            elif k == wdt - 4:
                c = st["rock_lt"]
            else:
                band = (y + k * 2) % 5
                c = [st["rock_lt"], st["rock"], st["rock"], st["rock_dk"], st["rock"]][band] if st["strata"] else \
                    (st["rock_dk"] if y % 4 == 3 else st["rock"])
            cv.set(x, y, c)
        edge = T - wdt - 1 if side == "w" else wdt
        cv.set(edge, y, st["rock_dk"])
        for k in range(2):   # its shadow on the low ground
            ex = edge - 1 - k if side == "w" else edge + 1 + k
            cv.set(ex, y, (0, 0, 0, 50))


def corner(cv, st, which):
    for y in range(T - 10, T):
        for x in range(T - 10, T):
            xx = x if which == "nw" else T - 1 - x
            d = (x - (T - 10)) + (y - (T - 10))
            if d >= 7:
                cv.set(xx, y, st["top"] if d >= 10 else st["rock"])
            elif d == 6:
                cv.set(xx, y, st["rock_dk"])


def ramp_s(cv, st):
    if st["steps"]:
        for k in range(4):
            y0 = k * 4
            c = mix(st["rock_lt"], st["rock"], k / 3)
            for y in range(y0, y0 + 4):
                for x in range(1, T - 1):
                    cv.set(x, y, c if y < y0 + 3 else st["rock_dk"])
        for y in range(T):
            cv.set(0, y, st["rock_dk"])
            cv.set(T - 1, y, st["rock_dk"])
    else:
        # a grassy slope: lighter at the top, little worn steps of earth
        for y in range(T):
            for x in range(T):
                t = y / (T - 1)
                c = mix(st["top_lt"], shade(st["top"], 0.8), t)
                if noise(x, y, 23) < 0.1:
                    c = shade(c, 0.85)
                cv.set(x, y, c)
        for k in range(3):
            y = 3 + k * 5
            for x in range(4, 12):
                cv.set(x, y, st["rock"])
                cv.set(x, y + 1, st["rock_dk"])
        for y in range(T):   # the slope's sides
            cv.set(0, y, st["rock_dk"])
            cv.set(1, y, st["rock"])
            cv.set(T - 2, y, st["rock"])
            cv.set(T - 1, y, st["rock_dk"])


def ramp_side(cv, st, side):
    for y in range(T):
        for x in range(T):
            t = x / (T - 1) if side == "w" else 1 - x / (T - 1)
            c = mix(shade(st["top"], 0.8), st["top_lt"], t)
            if st["steps"]:
                c = st["rock_lt"] if (x // 4) % 2 == 0 else st["rock"]
                if x % 4 == 3:
                    c = st["rock_dk"]
            cv.set(x, y, c)
    for x in range(T):
        cv.set(x, 0, st["rock_dk"])
        cv.set(x, T - 1, st["rock_dk"])


def build():
    img = Image.new("RGBA", (T * 12, T * len(STYLES)), (0, 0, 0, 0))
    root = Canvas(img)
    for si, st in enumerate(STYLES):
        y0 = si * T
        face(root.at(0, y0), st, 0)
        face(root.at(T, y0), st, 1)
        face(root.at(2 * T, y0), st, 2, "l")
        face(root.at(3 * T, y0), st, 3, "r")
        rim_n(root.at(4 * T, y0), st)
        rim_side(root.at(5 * T, y0), st, "w")
        rim_side(root.at(6 * T, y0), st, "e")
        corner(root.at(7 * T, y0), st, "nw")
        corner(root.at(8 * T, y0), st, "ne")
        ramp_s(root.at(9 * T, y0), st)
        ramp_side(root.at(10 * T, y0), st, "w")
        ramp_side(root.at(11 * T, y0), st, "e")
    img.save(OUT / "heights.png")
    print("wrote heights.png", img.size)


if __name__ == "__main__":
    build()
