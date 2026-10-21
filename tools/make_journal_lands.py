"""Builds assets/journal_lands.png: one 92 x 98 picture of each land for the
journal (journal_screen.gd), in JournalData.LANDS order.

The pictures are the game itself: shots of each land taken in the game's 3D
view (dev/lands/<id>.png, 1080 x 720 -- the game's 360 x 240 at 3x, the hero
hidden, lantern up), brought back down to the game's pixels and cut around
the middle of the screen. The way home is the open purple gate from the
intro's art (assets/intro_art.png, IntroArt "master_open").
Run:  python3 tools/make_journal_lands.py   (after capturing dev/lands/)
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ORDER = ["crypt", "forest", "court", "mountain", "river", "swamp", "village", "beach", "jungle", "snow",
         "volcano", "gold", "home"]
W, H = 92, 98
# where each shot is cut: the middle of the picture, in the game's 360 x 240
# (picked to frame each land well)
CENTER = {"crypt": (172, 105), "forest": (95, 100), "court": (190, 140), "mountain": (200, 95),
          "river": (222, 140), "swamp": (290, 150), "village": (95, 80), "beach": (205, 70),
          "jungle": (110, 92), "snow": (110, 55), "volcano": (240, 160), "gold": (262, 150)}
GATE_OPEN = (81, 307, 80, 112)   # IntroArt "master_open"


def shot(name):
    im = Image.open(ROOT / "dev" / "lands" / (name + ".png")).convert("RGB")
    im = im.resize((im.width // 3, im.height // 3), Image.NEAREST)   # back to the game's pixels
    cx, cy = CENTER.get(name, (im.width // 2, im.height // 2))
    cx = min(max(cx, W // 2), im.width - W // 2)
    cy = min(max(cy, H // 2), im.height - H // 2)
    return im.crop((cx - W // 2, cy - H // 2, cx - W // 2 + W, cy - H // 2 + H))


def home():
    art = Image.open(ROOT / "assets" / "intro_art.png").convert("RGBA")
    x, y, w, h = GATE_OPEN
    gate = art.crop((x, y, x + w, y + h))
    out = Image.new("RGBA", (W, H), (14, 10, 26, 255))
    # daylight spilling out through the open gate
    for yy in range(H):
        for xx in range(W):
            d = ((xx - W / 2) ** 2 / 1600 + (yy - H * 0.55) ** 2 / 2600)
            k = max(0.0, 1.0 - d)
            out.putpixel((xx, yy), (int(14 + 60 * k), int(10 + 40 * k), int(26 + 60 * k), 255))
    out.alpha_composite(gate, ((W - w) // 2, H - h + 8 if h > H else (H - h) // 2))
    return out.convert("RGB")


def main():
    sheet = Image.new("RGB", (W * len(ORDER), H))
    for i, name in enumerate(ORDER):
        im = home() if name == "home" else shot(name)
        sheet.paste(im, (i * W, 0))
    sheet.save(ROOT / "assets" / "journal_lands.png")
    print("wrote the journal's lands")


if __name__ == "__main__":
    main()
