"""Builds the big battle sprites -- the creatures as you see them up close:

    assets/insects_battle.png   64 x 64 frames, one column per insect
    assets/demons_battle.png    64 x 96 frames, one column per demon

The designs are written on a 48-unit grid (48 x 48 insects, 48 x 72 demons)
and rendered at K = 4/3, so the forms get finer shading, grain and cast
shadows rather than fatter pixels.

Columns follow the same order as tools/make_creatures.py (and CreatureData);
rows are the 4 animation frames, as in the small sheets. The art is drawn by
pixkit.py from the designs in battle_insects.py and battle_demons.py; the
The Weeper and the Bride have their own designs too.
Run:  python3 tools/make_battle_sprites.py
"""
from pathlib import Path

from PIL import Image

import battle_demons
import battle_insects
from pixkit import Sprite

ROOT = Path(__file__).resolve().parent.parent

# name, design, palette (material -> base colour), options
INSECTS = [
    ("BEETLE", "beetle", {"shell": "3a3c6e", "mark": "9fb8e0", "leg": "2e2840", "bone": "c8bca0"}),
    ("BONE BEETLE", "beetle", {"shell": "b0a68c", "mark": "f4ead0", "leg": "5e5244", "bone": "e8dcc0"}),
    ("SPIDER", "spider", {"body": "3a3448", "mark": "c04050", "leg": "2e2838", "fang": "d8d0c0"}),
    ("PALE SPIDER", "spider", {"body": "b0a8c0", "mark": "4a2a50", "leg": "8a8298", "fang": "f0e8e0"}),
    ("MOTH", "moth", {"wing": "8a7a62", "spot": "4a3a5a", "body": "5a4a3a", "fur": "c8b898"}),
    ("DEATH MOTH", "moth", {"wing": "d0c8b8", "spot": "6a2030", "body": "4a3030", "fur": "e8e0d8"}),
    ("CENTIPEDE", "centipede", {"body": "b8a888", "leg": "7a6a52", "fang": "3a2a2a"}),
    ("RUST CENTIPEDE", "centipede", {"body": "c06a38", "leg": "7a3e22", "fang": "2a1a1a"}),
    ("TICK", "tick", {"body": "b8aca0", "plate": "4a3a3a", "leg": "5a4a40", "fang": "d8c8b0"}),
    ("BLOOD TICK", "tick", {"body": "a83848", "plate": "3a1a22", "leg": "4a2a2e", "fang": "e0b0b0"}),
    ("SCARAB", "scarab", {"shell": "3e6a58", "mark": "c8b060", "leg": "2a3a32", "horn": "5a7a68"}),
    ("GILDED SCARAB", "scarab", {"shell": "c09a38", "mark": "fff0b0", "leg": "6a5020", "horn": "d8b050"}),
    ("WASP", "wasp", {"body": "2a2433", "band": "e8c040", "wing": "a8b8d0", "leg": "3a3444", "fang": "e8d8a0"}),
    ("BONE WASP", "wasp", {"body": "4a4058", "band": "e8e0cc", "wing": "b8c0cc", "leg": "5a5068",
                           "fang": "f0e8d8"}),
    ("MANTIS", "mantis", {"body": "6a8a4a", "arm": "8aa860", "wing": "9ab870", "leg": "4a6232", "eye": "c8d070",
                          "fang": "3a3020"}),
    ("GHOST MANTIS", "mantis", {"body": "b8c0c8", "arm": "d0d8e0", "wing": "e0e6ec", "leg": "8a929a",
                                "eye": "f0f4f8", "fang": "4a4a52"}),
]

_D = {"teeth": "e8dfc8", "gum": "b0182c", "mouth": "3a0c18", "claw": "d8ccb0", "bone": "e0d6bc",
      "tongue": "c84a5a", "gold": "d8a838"}


def _p(**kw):
    d = dict(_D)
    d.update(kw)
    return d


DEMONS = [
    ("GRINNER", "grinner", _p(cloak="2e2838", skin="5a5068"), {}),
    ("PALE GRINNER", "grinner", _p(cloak="8a8296", skin="c8c0d4"), {}),
    ("MANY-EYES", "many_eyes", _p(skin="6a2a38"), {}),
    ("THOUSAND-EYES", "many_eyes", _p(skin="b8a890"), {}),
    ("WRAITH", "wraith", _p(cloak="3f3339", skin="7a6870"), {}),
    ("ASH WRAITH", "wraith", _p(cloak="9a9490", skin="d0cac4", bone="f0ece4"), {}),
    ("HOLLOW", "hollow", _p(cloak="241f2a"), {}),
    ("HOLLOW KING", "hollow", _p(cloak="4a1828", bone="f6f0e0"), {"crown": True}),
    ("MAW", "maw", _p(skin="cbb89c"), {}),
    ("GRAVE MAW", "maw", _p(skin="a0b098"), {}),
    ("WEEPER", "weeper", _p(cloak="2e2836", skin="9a90a0", hair="1c1820", tear="7a1020"), {}),
    ("BRIDE", "bride", _p(cloak="d8d0c4", skin="c8bcb0", hair="2a2028", veil="e8e2da", tear="7a1020",
                         flower="6a5a4a"), {"bride": True}),
]
# the creatures added with the rarity system (designs in battle_extra.py)
import battle_extra  # noqa: E402
battle_extra.register(battle_insects, battle_demons)
INSECTS += battle_extra.INSECTS
DEMONS += battle_extra.DEMONS

FRAMES = 4
K = 4 / 3
IW = IH = 64          # insect frame
DW, DH = 64, 96       # demon frame


def sprite(w, h):
    return Sprite(w, h, k=K, grain=0.16, cast=True)


def main():
    ins = Image.new("RGBA", (IW * len(INSECTS), IH * FRAMES), (0, 0, 0, 0))
    for i, (name, design, pal) in enumerate(INSECTS):
        for f in range(FRAMES):
            s = sprite(IW, IH)
            battle_insects.DESIGNS[design](s, f)
            battle_insects.detail(s, design, f)
            ins.paste(s.image(pal), (i * IW, f * IH))
    dem = Image.new("RGBA", (DW * len(DEMONS), DH * FRAMES), (0, 0, 0, 0))
    for i, (name, design, pal, opts) in enumerate(DEMONS):
        for f in range(FRAMES):
            s = sprite(DW, DH)
            battle_demons.DESIGNS[design](s, f, opts)
            battle_demons.detail(s, design, f, opts)
            dem.paste(s.image(pal), (i * DW, f * DH))
    ins.save(ROOT / "assets" / "insects_battle.png")
    dem.save(ROOT / "assets" / "demons_battle.png")
    print(f"wrote {len(INSECTS)} insects, {len(DEMONS)} demons (battle size)")


if __name__ == "__main__":
    main()
