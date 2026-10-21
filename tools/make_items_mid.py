"""Builds assets/items_mid.png and assets/gear_mid.png: the up-close item
renders (items_big.png, gear_big.png) at half size, 32 x 32 -- for wherever an
item is shown at 32 pixels (Lume's lessons, the journal's slots, the chest
screen). Each 2 x 2 block becomes the colour most of it is (the brighter one
on a tie, so highlights survive), then a fresh dark outline goes round it.
Run after make_items_big.py / make_gear_big.py:  python3 tools/make_items_mid.py
"""
from collections import Counter
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = (26, 16, 34, 255)


def shrink(img):
    w, h = img.width // 2, img.height // 2
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            cs = [px[x * 2 + i, y * 2 + j] for i in range(2) for j in range(2)]
            op = [c for c in cs if c[3] > 0]
            solid = [c for c in op if c[:3] != OUT[:3]]
            if len(op) >= 2 and solid:
                cnt = Counter(solid).most_common()
                out.putpixel((x, y), max([c for c, n in cnt if n == cnt[0][1]], key=lambda c: sum(c[:3])))
    o = out.load()
    edge = [(x, y) for y in range(h) for x in range(w)
            if o[x, y][3] == 0 and any(0 <= x + dx < w and 0 <= y + dy < h and o[x + dx, y + dy][3] > 0
                                       and o[x + dx, y + dy][:3] != OUT[:3]
                                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for p in edge:
        out.putpixel(p, OUT)
    return out


def main():
    for src, dst in [("items_big.png", "items_mid.png"), ("gear_big.png", "gear_mid.png")]:
        shrink(Image.open(ROOT / "assets" / src).convert("RGBA")).save(ROOT / "assets" / dst)
        print("wrote", dst)


if __name__ == "__main__":
    main()
