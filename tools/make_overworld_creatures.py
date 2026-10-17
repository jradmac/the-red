"""Builds assets/insects_walk.png: the insects as they walk the labyrinth
(three-quarter view, see overworld_creatures.py).

    columns   one per insect, 24 px, same order as CreatureData / insects.png
    rows      facing x frame: down 0-3, side 4-7, up 8-11 (24 px each)

Insects whose design isn't drawn yet are left empty (the game falls back to
their old sprite). Run:  python3 tools/make_overworld_creatures.py
"""
from pathlib import Path
import sys

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_battle_sprites import INSECTS  # noqa: E402  (names, designs, palettes)
import overworld_creatures as oc        # noqa: E402
from pixkit import Sprite               # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
FACINGS = ["down", "side", "up"]
FRAMES = 4


def main():
    sheet = Image.new("RGBA", (24 * len(INSECTS), 24 * FRAMES * len(FACINGS)), (0, 0, 0, 0))
    done = []
    for i, (name, design, pal) in enumerate(INSECTS):
        if design not in oc.DESIGNS:
            continue
        done.append(i)
        for fi, facing in enumerate(FACINGS):
            for f in range(FRAMES):
                s = Sprite(24, 24)
                oc.DESIGNS[design](s, facing, f)
                sheet.paste(s.image(pal), (i * 24, (fi * FRAMES + f) * 24))
    sheet.save(ROOT / "assets" / "insects_walk.png")
    print("wrote assets/insects_walk.png; drawn:", done)


if __name__ == "__main__":
    main()
