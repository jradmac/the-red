"""Adds the tools to assets/items.png: the Seer Stone (29), the Portal Flare
(30) and the Ladder (31). Run after make_art.py and make_village.py (which
build icons 0-28).
Run:  python3 tools/make_tool_items.py
"""
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets"
FIRST = 29

SEER_STONE = [
    "................",
    "......g..g......",
    ".....KKKKKK.....",
    "....KhhssssK....",
    "...KhssssssDK...",
    "..KhssGGGGssDK..",
    "..KssGWWWWGsDK..",
    ".gKssGWKKWGsDKg.",
    "..KssGWWWWGsDK..",
    "..KsssGGGGssDK..",
    "...KssssssDDK...",
    "....KDDDDDDK....",
    ".....KKKKKK.....",
    "......g..g......",
    "................",
    "................",
]
SEER_PAL = {"K": "142018", "D": "24402e", "s": "3f6e50", "h": "86c09c", "G": "7dff9a", "W": "eafff0",
            "g": "3fbf6a"}

PORTAL_FLARE = [
    ".....p....p.....",
    "...p..PPPP..p...",
    "..p.PPWWWWPP.p..",
    "....PW....WP....",
    "..p.PPWWWWPP.p..",
    "...p..PPPP..p...",
    ".....p.KK.p.....",
    ".......KVK......",
    ".......KVK......",
    ".......KvK......",
    ".......KvK......",
    ".......KvK......",
    "......KKKKK.....",
    "......KbbbK.....",
    ".......KKK......",
    "................",
]
PORTAL_PAL = {"K": "1e1030", "V": "c890ff", "v": "7a3ad0", "P": "a060ff", "W": "f0e0ff", "p": "6a3ab0",
              "b": "4a3a2a"}

LADDER = [
    "..KK.......KK...",
    "..KhK......KhK..",
    "..KbKKKKKKKKbK..",
    "..KbhhhhhhhhbK..",
    "..KbKKKKKKKKbK..",
    "..KbK......KbK..",
    "..KbKKKKKKKKbK..",
    "..KbhhhhhhhhbK..",
    "..KbKKKKKKKKbK..",
    "..KbK......KbK..",
    "..KbKKKKKKKKbK..",
    "..KbhhhhhhhhbK..",
    "..KbKKKKKKKKbK..",
    "..KbK......KbK..",
    "..KdK......KdK..",
    "..KKK......KKK..",
]
LADDER_PAL = {"K": "2a1a10", "b": "8a5a32", "h": "c08a52", "d": "5a3a20"}


def grid(rows, pal):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        assert len(row) == 16, (y, row)
        for x, ch in enumerate(row):
            if ch in pal:
                h = pal[ch]
                img.putpixel((x, y), (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255))
    return img


def main():
    base = Image.open(OUT / "items.png").convert("RGBA")
    base = base.crop((0, 0, FIRST * 16, 16))
    icons = [grid(SEER_STONE, SEER_PAL), grid(PORTAL_FLARE, PORTAL_PAL), grid(LADDER, LADDER_PAL)]
    sheet = Image.new("RGBA", (base.width + 16 * len(icons), 16), (0, 0, 0, 0))
    sheet.paste(base, (0, 0))
    for i, ic in enumerate(icons):
        sheet.paste(ic, (base.width + i * 16, 0))
    sheet.save(OUT / "items.png")
    print("wrote the tool icons (%d-%d)" % (FIRST, FIRST + len(icons) - 1))


if __name__ == "__main__":
    main()
