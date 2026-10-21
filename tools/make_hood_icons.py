"""The starting hoods' icons in assets/items.png: the Red Hood (40) and the
Blue Hood (41) -- the same hood the heroes wear (hero.png / hero_p2.png), in
their colours: a deep cowl with the face opening dark inside, a short cape
falling from it, lit from the upper left, ringed in the outline colour."""
from pathlib import Path

from PIL import Image

ITEMS = Path(__file__).resolve().parent.parent / "assets" / "items.png"
RED, BLUE = 40, 41
OUTLINE = (28, 16, 32)
PALS = {   # light, mid, shade, deep -- as on the hero sprites
    RED: [(226, 87, 79), (184, 52, 60), (138, 36, 51), (90, 24, 40)],
    BLUE: [(90, 134, 232), (58, 92, 192), (40, 60, 138), (24, 36, 90)],
}


def hood(pal):
    li, mid, sh, deep = pal
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()
    inside = set()
    for y in range(16):
        for x in range(16):
            cx, cy = x + 0.5, y + 0.5
            cowl = ((cx - 8) / 5.6) ** 2 + ((cy - 7.2) / 5.4) ** 2 <= 1.0 and cy >= 1.5
            # the cape: widening below the cowl
            t = (cy - 9.0) / 5.5
            cape = 0.0 <= t <= 1.0 and abs(cx - 8) <= 4.6 + t * 2.2 and cy <= 14.5
            if cowl or cape:
                inside.add((x, y))
    for (x, y) in inside:
        cx, cy = x + 0.5, y + 0.5
        # light from the upper left
        k = (cx - 8) * 0.55 + (cy - 6) * 0.45
        c = li if k < -2.4 else mid if k < 1.2 else sh if k < 3.6 else deep
        # cape folds
        if cy > 10 and int(cx) in (5, 10):
            c = sh if c in (li, mid) else deep
        px[x, y] = c + (255,)
    # the face opening: dark inside, lit rim along its top
    for y in range(16):
        for x in range(16):
            cx, cy = x + 0.5, y + 0.5
            if ((cx - 8) / 2.9) ** 2 + ((cy - 8.6) / 3.0) ** 2 <= 1.0:
                px[x, y] = (40, 22, 40, 255) if cy > 6.8 else deep + (255,)
    # the hem: a darker last row of the cape
    for x in range(16):
        if (x, 14) in inside:
            px[x, 14] = deep + (255,)
    # outline round the outside
    for (x, y) in list(inside):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if 0 <= q[0] < 16 and 0 <= q[1] < 16 and q not in inside:
                px[q] = OUTLINE + (255,)
    return img


def build():
    sheet = Image.open(ITEMS).convert("RGBA")
    need = (BLUE + 1) * 16
    if sheet.width < need:
        wide = Image.new("RGBA", (need, sheet.height), (0, 0, 0, 0))
        wide.paste(sheet, (0, 0))
        sheet = wide
    for slot, pal in PALS.items():
        sheet.paste(Image.new("RGBA", (16, 16), (0, 0, 0, 0)), (slot * 16, 0))
        sheet.paste(hood(pal), (slot * 16, 0))
    sheet.save(ITEMS)
    print("wrote hood icons", RED, BLUE, "to", ITEMS)


if __name__ == "__main__":
    build()
