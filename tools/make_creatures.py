"""Builds the creature sprites and their data:

    assets/insects.png   16 x 16 frames, one column per creature
    assets/demons.png    16 x 24 frames, one column per creature
    scripts/creature_data.gd   names, stats, battle habits and eye pixels

Each DESIGN is a pixel grid; each design comes in a couple of colour
variants (different names and stats). Every creature gets pale markings and
a rim of light along its top-left edge so it stands out against the dark
stone.  Run:  python3 tools/make_creatures.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent

# Shared letters. Variants override any of these.
BASE = {
    "K": "1a1022",                                 # outline
    "I": "3a3452", "i": "5c5680", "j": "d8d0f0",   # insect body dark / mid / pale marking
    "X": "ff3b4d", "Z": "ffcf3f", "W": "ffffff",   # eyes (red / yellow / white)
    "F": "e8dfc8", "f": "b0a58c", "T": "f2ead8",   # bone, bone shade, teeth
    "O": "cbb89c", "o": "8f7f66",                  # beige skin / shade
    "D": "2a0c14", "m": "b0182c",                  # mouth dark, gums
    "k": "2b2433", "h": "4a4058",                  # demon cloak / skin
    "A": "c8b89c", "a": "8b7d6b",                  # moth wings
    "G": "c8d8e8", "g": "8fa0b8",                  # insect wings
    "M": "b8d8a0", "n": "141018",                  # mantis green / black hair
}
EYE_LETTERS = {"X", "Z", "W"}

# ---------------------------------------------------------------------------
# Insects (16 x 16)
# ---------------------------------------------------------------------------
BEETLE = [
    "................",
    "...K........K...",
    "....K......K....",
    ".....KKKKKK.....",
    "....KiXiiXiK....",
    "K..KiiiiiiiiK..K",
    ".KKKKKKKKKKKKKK.",
    "...KIjIIKIIjIK..",
    "KKKIjIIIKIIIjIKK",
    "...KIIjIKIjIIK..",
    "KKKIIIIjKjIIIIKK",
    "...KIIjIKIjIIK..",
    "....KIIIKIIIK...",
    ".....KKKKKKK....",
    "....K.....K.....",
    "...K.......K....",
]
SPIDER = [
    "................",
    "..K..........K..",
    "...K..KKKK..K...",
    ".K..KKIIIIKK..K.",
    "..KKIiiIIiiIKK..",
    "K..KIIIIIIIIK..K",
    ".KKKIXIXXIXIKKK.",
    "...KIIXIIXIIK...",
    "KKKKIjjjjjjIKKKK",
    "...KIjKjjKjIK...",
    ".KKKIjjjjjjIKKK.",
    "K...KIjKKjIK...K",
    "...K.KKIIKK.K...",
    "..K...KKKK...K..",
    ".K............K.",
    "................",
]
MOTH = [
    "................",
    "......K..K......",
    ".......KK.......",
    ".KKK..KTTK..KKK.",
    "KAAaK.KTTK.KaAAK",
    "KAjjAKKIIKKAjjAK",
    "KAjXAAKIIKAAXjAK",
    "KAjjAAKIIKAAjjAK",
    "KaAAAaKIIKaAAAaK",
    ".KaaaKKIIKKaaaK.",
    "..KAAaKIIKaAAK..",
    "..KAjAKIIKAjAK..",
    "...KaAKIIKAaK...",
    "....KK.KK.KK....",
    "................",
    "................",
]
CENTIPEDE = [
    "................",
    "...K..K.........",
    "....KKK.........",
    "...KFXFK........",
    "..K.KFFK.K......",
    "....KfFFKFK.....",
    "...K.KfFFfK.K...",
    "......KKfFFKFK..",
    "....K..KFfFFfK..",
    "...KFK.KfFFK.K..",
    "..KfFFKFFfK.....",
    ".K.KFfFFfK.K....",
    "...KfFFK.K......",
    "..K.KKK.........",
    "................",
    "................",
]
TICK = [
    "................",
    "................",
    "......KKKK......",
    ".....KXKKXK.....",
    "..K..KIIIIK..K..",
    "...KKFFFFFFKK...",
    "K.KFFTTFFFFFfK.K",
    ".KFTTFFIFFFFffK.",
    "K.KFFFIIIFFFfK.K",
    ".KFFFFFIFFFFffK.",
    "K.KFFFFFFFFffK.K",
    "...KfFFFFFffK...",
    "..K.KffffffK.K..",
    ".....KKKKKK.....",
    "................",
    "................",
]
SCARAB = [
    "................",
    "....K......K....",
    ".....K.KK.K.....",
    "......KOOK......",
    "..K..KOXXOK..K..",
    "...KKKKKKKKKK...",
    "..KTTFFKFFFTTK..",
    "KKTFFFFKFFFFfTKK",
    "..KTFjFKFjFFfK..",
    "KKKTFFFKFFFFfKKK",
    "..KTFFFKFFFFfK..",
    "...KTFFKFFFfK...",
    "..K.KKfKfKKK.K..",
    "......KKK.......",
    "................",
    "................",
]
WASP = [
    "................",
    "...KK......KK...",
    "..KGGK....KGGK..",
    "..KGgGK..KGgGK..",
    "...KGGGKKGGGK...",
    "....KKKZZKKK....",
    ".....KTIITK.....",
    "......KTTK......",
    ".....KIIIIK.....",
    ".....KTTTTK.....",
    ".....KIIIIK.....",
    ".....KTTTTK.....",
    "......KIIK......",
    ".......KK.......",
    ".......K........",
    "................",
]
MANTIS = [
    "................",
    "....KK....KK....",
    "...KXK....KXK...",
    "....KMMKKMMK....",
    ".....KMMMMK.....",
    "..KK..KMMK..KK..",
    ".KMK..KMMK..KMK.",
    ".KMMK.KoMK.KMMK.",
    "..KMMKKooKKMMK..",
    "...KKKMooMKKK...",
    "....KMMooMMK....",
    "...K.KMooMK.K...",
    "..K..KMooMK..K..",
    "......KooK......",
    ".......KK.......",
    "................",
]

# ---------------------------------------------------------------------------
# Demons (16 x 24): horror, not satanic -- teeth, eyes, wrong proportions.
# ---------------------------------------------------------------------------
GRINNER = [
    "................",
    "................",
    ".....KKKKKK.....",
    "....KkhhkkkK....",
    "...KkhkkkkkkK...",
    "...KkWKkkKWkK...",
    "..KkkkkkkkkkkK..",
    "..KKKKKKKKKKKK..",
    "..KTTTTTTTTTTK..",
    "..KTDTDDTDDTDK..",
    "..KDDmDDmDDmDK..",
    "..KDTDDTDDTDTK..",
    "..KTTTTTTTTTTK..",
    "...KkKKKKKKkK...",
    "...KKkkkkkkKK...",
    "..KkkkkkkkkkkK..",
    ".KkKkhkkkkkKkkK.",
    ".KkKkhkkkkkKkkK.",
    ".KkKkkkkkkkKkkK.",
    ".KkKkkkkkkkKkkK.",
    ".KTKKkkKkkkKKTK.",
    ".T.TKkkKKkkKT.T.",
    "....KKK..KKK....",
    "................",
]
MANY_EYES = [
    "................",
    "................",
    "................",
    "......KKKK......",
    "....KKkkkkKK....",
    "...KkZKkkkkkK...",
    "..KkkkkkkKXkkK..",
    "..KkXKkkkkkZkK..",
    ".KkkkkkZKkkkkkK.",
    ".KkZKkkkkkkXKkK.",
    ".KkkkKKKKKKkkkK.",
    ".KkkKTKTKTKKkkK.",
    ".KkkKmmmmmmKZKK.",
    ".KkkKTKTKTKKkkK.",
    ".KkXKKKKKKKkkkK.",
    "KkkkkkkZKkkkkkkK",
    "KkKkkkkkkkkXKKkK",
    "KkKkZKkkkkkkkKkK",
    "KTKkkkkkkXKkkKTK",
    ".T.KkkkkkkkkkK.T",
    "...KkkKKKKkkK...",
    "...KTTK..KTTK...",
    "....KK....KK....",
    "................",
]
WRAITH = [
    "KK............KK",
    "KFK..........KFK",
    "KFfK........KFfK",
    ".KFfK..KK..KFfK.",
    "..KFfKKkkKKFfK..",
    "...KKkhkkkkKK...",
    "...KkKKkkKKkK...",
    "...KkKXkkXKkK...",
    "...KkKKkkKKkK...",
    "...KkkkKKkkkK...",
    "...KKTKTTKTKK...",
    "...KTDDDDDDTK...",
    "...KTDmDDmDTK...",
    "...KDDDDDDDDK...",
    "...KKTKTTKTKK...",
    "..KKkKKKKKKkKK..",
    ".KkkkhkkkkkkkkK.",
    "KkKkhkkkkkkkKkK.",
    "KkKkkkkkkkkkKkK.",
    "KTKkkkkkkkkkKTK.",
    "T.TKkkkkkkkkKT.T",
    "...KkK.KK.KkK...",
    "...K.K....K.K...",
    "................",
]
HOLLOW = [
    "................",
    ".....KKKKKK.....",
    "....KFFFFFFK....",
    "...KFTFFFFFfK...",
    "...KFKKFFKKfK...",
    "...KFKWFFKWfK...",
    "...KFKKFFKKfK...",
    "...KFFFFFFFfK...",
    "....KFKKKKfK....",
    "....KfKDDKfK....",
    ".....KffffK.....",
    "...KKkkkkkkKK...",
    "..KkkkkkkkkkkK..",
    ".KFKkkkkkkkkKFK.",
    ".KFKkkhkkkkkKFK.",
    ".KFKkkhkkkkkKFK.",
    ".KFKkkkkkkkkKFK.",
    ".KFKkkkkkkkkKFK.",
    ".KFKkkkkkkkkKFK.",
    "KFFFKkkkkkkKFFFK",
    "KF.FKkkKKkkKF.FK",
    "....KkkKKkkK....",
    "....KFFK.KFFK...",
    "....KKKK.KKKK...",
]
MAW = [
    "................",
    "................",
    "................",
    "......KKKK......",
    "....KKOOOOKK....",
    "...KOOOOOOOOK...",
    "..KOOXOOOOXOOK..",
    "..KOOOKKKKOOOK..",
    ".KOOOKTKKTKOOOK.",
    ".KOOKTmmmmTKOOK.",
    ".KOOKmDDDDmKOOK.",
    "KOOOKTDDDDTKOOOK",
    "KOOOKmDDDDmKOOOK",
    "KOOOKTDDDDTKOOOK",
    "KOOOKmmDDmmKOOOK",
    "KOOOOKTmmTKOOOOK",
    "KOKOOOKKKKOOOKOK",
    "KOKOOOOOOOOOOKOK",
    "KTKOOooooooOOKTK",
    ".T.KOoooooooOK.T",
    "...KOOKKKKOOK...",
    "...KOOK..KOOK...",
    "...KKKK..KKKK...",
    "................",
]
WEEPER = [
    "................",
    ".....KKKKKK.....",
    "....KnnnnnnK....",
    "...KnnnnnnnnK...",
    "...KnnFFFFnnK...",
    "...KnFWFFWFnK...",
    "..KnnFKFFKFnnK..",
    "..KnnFKFFKFnnK..",
    "..KnnFFKKFFnnK..",
    "..KnnnFDDFnnnK..",
    "..KnnnnFFnnnnK..",
    "..KnnKKKKKKnnK..",
    ".KnnKkkkkkkKnnK.",
    ".KnKkkkkkkkkKnK.",
    ".KnKkkhkkkkkKnK.",
    "..KKkkhkkkkkKK..",
    "..KFKkkkkkkKFK..",
    "..KFKkkkkkkKFK..",
    "..KFKkkkkkkKFK..",
    "...KkkkkkkkkK...",
    "..KkkkkkkkkkkK..",
    "..KkkkkkkkkkkK..",
    "...KKKKKKKKKK...",
    "................",
]


# --- Added with the rarity system -------------------------------------------
FIREFLY = [
    "................",
    ".....KKKKKK.....",
    "....KZZZZZZK....",
    "...KZZZWZZZZK...",
    "...KZZZZZZZZK...",
    "GK..KZZZZZZK..KG",
    "GGK.KKZZZZKK.KGG",
    ".GGKIIKKKKIIKGG.",
    "..GKIIIIIIIIKG..",
    "...KKPPPPPPKK...",
    "...KPKPPPPKPK...",
    "....KPPPPPPK....",
    "....KIXIIXIK....",
    ".....KIIIIK.....",
    "....K.K..K.K....",
    "...K..K..K..K...",
]
SCORPION = [
    "......KSK.......",
    ".......KSK......",
    "......KiiK......",
    ".....KiIiK......",
    ".....KiIK.......",
    "......KiiK......",
    "..K..KKiiKK..K..",
    "...KKIiIIiIKK...",
    "KKKKIiIIIIiIKKKK",
    "...KIiXIIXiIK...",
    "KKKKKIIIIIIKKKKK",
    ".KFFKKIIIIKKFFK.",
    "KFKFK.KKKK.KFKFK",
    "KF.FK......KF.FK",
    ".K.K........K.K.",
    "................",
]
STAG = [
    "................",
    ".....KKKKKK.....",
    "....KIjIIjIK....",
    "K..KIIjIIjIIK..K",
    ".KKKIIIKKIIIKKK.",
    "...KIIjIIjIIK...",
    "KKKKIIIIIIIIKKKK",
    "...KKKKKKKKKK...",
    "..KiiiiiiiiiiK..",
    "KKKiXiiiiiiXiKKK",
    "...KiiiiiiiiK...",
    "..KFKKKKKKKKFK..",
    ".KFFK......KFFK.",
    ".KF.FK....KF.FK.",
    "..K..FK..KF..K..",
    "......K..K......",
]
MARIONETTE = [
    "...j....j....j..",
    "...j....j....j..",
    "...j..KKKK...j..",
    "...j.KFFFFK..j..",
    "...jKFWFFWFK.j..",
    "...jKFmFFmFK.j..",
    "...jKFFDDFFK.j..",
    "...j.KFDDFK..j..",
    "...j..KmmK...j..",
    "...jKKmmmmKK.j..",
    "..KOKkmkkmkKKOK.",
    "..KOKmkmmkmKKOK.",
    "..KOKkmkkmkK.KOK",
    "..KOKmkmmkmKKOK.",
    "..KOKkmkkmkK.K..",
    "...KKmkmmkmK....",
    "....KKKKKKKK....",
    ".....KOKKOK.....",
    ".....KOK.KOK....",
    ".....KOK.KOK....",
    ".....KoK.KoK....",
    ".....KOK.KOK....",
    "....KOOK.KOOK...",
    "....KKKK.KKKK...",
]
WITCH = [
    "................",
    "......KKKK......",
    ".....KkkkkK.....",
    "....KkkkkkkK....",
    "...KkkhhhhkkK...",
    "...KknhZhZhnK.KK",
    "..KknnhhhhhnK.KZ",
    "..KknhhhhOhnKKZK",
    "..KkknhhOOhkK.K.",
    "..KkkkhDDhkkK.K.",
    "...KkkkhhkkK..K.",
    "..KKkkkkkkkkK.K.",
    ".KkkkkkkkkkkkKK.",
    ".KkKkkkkkkkkhhK.",
    "KhKkkkkkkkkkkKK.",
    "KhKkkkkkkkkkkKK.",
    ".TKkkkkkkkkkkKK.",
    "..KkkkkkkkkkkKK.",
    "..KkkkkkkkkkkkK.",
    ".KkkkkkkkkkkkkK.",
    ".KkkkkkkkkkkkkK.",
    "..KhhKKKKKKhhKK.",
    "..KKK......KKK..",
    "................",
]
GRANDMA = [
    "...K........K...",
    "..KhK......KhK..",
    "..KhhKjjjjKhhK..",
    "..KjjjjjjjjjjK..",
    ".KjjjhhhhhhjjjK.",
    ".KjjhZKhhKZhjjK.",
    ".KjjhhhhhhhhjjK.",
    "..KjhhhDDhhhjK..",
    "..KjKTDDDDTKjK..",
    "...KKTKTTKTKK...",
    "..KjjjDDDDjjjK..",
    ".KjjjjjjjjjjjjK.",
    "KkkKjjjjjjjjKkkK",
    "KhkKkkkkkkkkKkhK",
    "KhkKkkmkkmkkKkhK",
    "KTTKkkkkkkkkKTTK",
    ".T.KkmkkkkmkK.T.",
    "...KkkkkkkkkkK..",
    "..KkkkkmkkkkkK..",
    "..KkmkkkkkmkkkK.",
    ".KjjjjjjjjjjjjK.",
    ".KjKjKjKjKjKjK..",
    "...KhhK..KhhK...",
    "...KKKK..KKKK...",
]


# name, grid, palette overrides, stats, nature (how it picks Attack / Defend --
# see NATURES in scripts/battle.gd). Your starting gear is ATK 2, DEF 1, 10 HP.
def st(atk, df, hp, step, aggro, **kw):
    return dict(atk=[atk, atk], df=[df, df], hp=hp, step=step, aggro=aggro, **kw)


INSECTS = [
    ("BEETLE", BEETLE, {}, st(1, 1, 4, 0.36, 4), "timid"),
    ("BONE BEETLE", BEETLE, {"I": "8f8670", "i": "c8bfa6", "j": "f6f0de"}, st(2, 2, 5, 0.40, 4), "timid"),
    ("SPIDER", SPIDER, {}, st(2, 0, 3, 0.22, 5), "bold"),
    ("PALE SPIDER", SPIDER, {"I": "b8b0c8", "i": "e0dae8", "j": "2a2433"}, st(3, 0, 4, 0.20, 6), "bold"),
    ("MOTH", MOTH, {}, st(1, 0, 3, 0.30, 4, moth=True), "alternate"),
    ("DEATH MOTH", MOTH, {"A": "e8e0d0", "a": "a49a88", "j": "2a2433", "I": "5a3a2a"},
     st(2, 1, 4, 0.28, 5, moth=True), "alternate"),
    ("CENTIPEDE", CENTIPEDE, {}, st(2, 1, 4, 0.24, 5), "bold"),
    ("RUST CENTIPEDE", CENTIPEDE, {"F": "e0a070", "f": "a8643a"}, st(3, 1, 5, 0.24, 5), "bold"),
    ("TICK", TICK, {}, st(1, 2, 4, 0.42, 3), "mirror"),
    ("BLOOD TICK", TICK, {"F": "e8a0a8", "f": "a85462", "T": "ffd8dc"}, st(2, 2, 5, 0.40, 4), "mirror"),
    ("SCARAB", SCARAB, {}, st(2, 2, 5, 0.38, 4), "timid"),
    ("GILDED SCARAB", SCARAB, {"F": "f2d070", "f": "b08a30", "T": "fff4c0"}, st(2, 3, 6, 0.36, 4), "timid"),
    ("WASP", WASP, {"I": "2a2433", "T": "f2e0a0"}, st(3, 0, 3, 0.20, 6), "bold"),
    ("BONE WASP", WASP, {"I": "4a4058", "T": "f2ead8"}, st(3, 1, 4, 0.21, 6), "bold"),
    ("MANTIS", MANTIS, {}, st(3, 1, 4, 0.30, 5), "contrary"),
    ("GHOST MANTIS", MANTIS, {"M": "e8ecf0", "o": "a8b0bc"}, st(4, 1, 5, 0.28, 5), "contrary"),
    ("FIREFLY", FIREFLY, {"I": "2c2a34", "P": "d0623a", "Z": "dff07a", "W": "ffffd0"}, st(1, 1, 3, 0.26, 4, moth=True),
     "timid"),
    ("EMBER FLY", FIREFLY, {"I": "3a1e22", "P": "8a2a2e", "Z": "ffa040", "W": "ffe0a0"},
     st(2, 1, 4, 0.25, 5, moth=True), "alternate"),
    ("SCORPION", SCORPION, {"I": "8a6a3a", "i": "b08448", "F": "c8a060", "f": "8a6a3a", "S": "e8d090"},
     st(3, 2, 5, 0.30, 5), "punisher"),
    ("BLACK SCORPION", SCORPION, {"I": "2c2834", "i": "4a4456", "F": "5a5468", "f": "3a3446", "S": "e04050"},
     st(4, 2, 6, 0.28, 6), "punisher"),
    ("STAG BEETLE", STAG, {"I": "5e3624", "i": "7c4a30", "j": "a0705a", "F": "9a6040"}, st(3, 3, 6, 0.40, 4),
     "desperate"),
    ("GOLDEN STAG", STAG, {"I": "c8962e", "i": "e8c050", "j": "fff0b0", "F": "f6dc80"}, st(3, 4, 7, 0.36, 3),
     "timid"),
]
DEMONS = [
    ("GRINNER", GRINNER, {"k": "2b2433", "h": "4a4058"}, st(4, 2, 6, 0.34, 6), "desperate"),
    ("PALE GRINNER", GRINNER, {"k": "8a8296", "h": "c8c0d4"}, st(5, 2, 7, 0.34, 6), "desperate"),
    ("MANY-EYES", MANY_EYES, {"k": "5a2230", "h": "7e3444"}, st(3, 3, 7, 0.50, 9), "contrary"),
    ("THOUSAND-EYES", MANY_EYES, {"k": "b8a890", "h": "e0d4bc"}, st(4, 4, 8, 0.48, 10), "contrary"),
    ("WRAITH", WRAITH, {"k": "3f3339", "h": "6b5862"}, st(5, 2, 6, 0.30, 6), "bold"),
    ("ASH WRAITH", WRAITH, {"k": "9a9490", "h": "d0cac4"}, st(6, 2, 7, 0.30, 7), "bold"),
    ("HOLLOW", HOLLOW, {"k": "241f2a", "h": "3a3344"}, st(4, 3, 6, 0.28, 7), "mirror"),
    ("HOLLOW KING", HOLLOW, {"k": "3a1420", "h": "5a2232", "F": "f6f0e0"}, st(5, 4, 8, 0.32, 7), "mirror"),
    ("MAW", MAW, {}, st(6, 1, 8, 0.40, 6), "alternate"),
    ("GRAVE MAW", MAW, {"O": "a8b8a0", "o": "6e7e68"}, st(7, 2, 9, 0.42, 6), "alternate"),
    ("WEEPER", WEEPER, {"k": "2a2433", "h": "4a4058"}, st(4, 3, 7, 0.36, 8), "punisher"),
    ("BRIDE", WEEPER, {"k": "d8d0c8", "h": "f2ece4", "n": "2a1a20"}, st(5, 3, 8, 0.34, 8), "punisher"),
    ("MARIONETTE", MARIONETTE, {"k": "7a2030", "O": "a87c50", "o": "7a5838", "F": "ece4d8", "j": "8a8478"},
     st(4, 3, 7, 0.32, 7), "mirror"),
    ("CUT MARIONETTE", MARIONETTE, {"k": "2c2c3e", "O": "6e5c48", "o": "4e4034", "F": "c8c0b8", "j": "141018"},
     st(5, 3, 8, 0.30, 8), "mirror"),
    ("BOG WITCH", WITCH, {"k": "2a3224", "h": "9aaa7c", "n": "c8c8b8", "O": "6a7a52", "Z": "a8f070"},
     st(5, 3, 8, 0.36, 7), "contrary"),
    ("CANDLE WITCH", WITCH, {"k": "3a2a2c", "h": "c8b8a0", "n": "e8e0d0", "O": "a89880", "Z": "ffb040"},
     st(6, 3, 9, 0.34, 8), "contrary"),
    ("GRANDMOTHER", GRANDMA, {"k": "b4a6c8", "h": "8c867c", "j": "efe9e0", "m": "c06070"}, st(7, 4, 10, 0.30, 9),
     "punisher"),
    ("BIG BAD WOLF", GRANDMA, {"k": "5e5670", "h": "4c4852", "j": "c8c0b8", "Z": "ff3b4d"}, st(8, 4, 11, 0.28, 10),
     "desperate"),
]

## How often each creature turns up: its share among creatures of its kind
## (insects / demons), in percent, at the middle of the labyrinth. Deeper,
## the rarer ones get likelier (Enemies.rarity_weight); a few only show up
## past a certain depth (MIN_DEPTH). Tiers are what the codex and battle call them.
RARITY = {
    # insects
    "BEETLE": 13.0, "BONE BEETLE": 4.5, "SPIDER": 11.0, "PALE SPIDER": 4.0, "MOTH": 11.0, "DEATH MOTH": 4.0,
    "CENTIPEDE": 10.0, "RUST CENTIPEDE": 3.5, "TICK": 10.0, "BLOOD TICK": 3.5, "SCARAB": 7.0, "GILDED SCARAB": 1.6,
    "WASP": 8.0, "BONE WASP": 2.5, "MANTIS": 5.5, "GHOST MANTIS": 1.2, "FIREFLY": 6.0, "EMBER FLY": 2.0,
    "SCORPION": 1.5, "BLACK SCORPION": 0.5, "STAG BEETLE": 1.0, "GOLDEN STAG": 0.07,
    # demons
    "GRINNER": 14.0, "PALE GRINNER": 4.5, "MANY-EYES": 12.0, "THOUSAND-EYES": 4.0, "WRAITH": 12.0,
    "ASH WRAITH": 4.0, "HOLLOW": 11.0, "HOLLOW KING": 1.8, "MAW": 9.0, "GRAVE MAW": 3.0, "WEEPER": 8.0,
    "BRIDE": 1.5, "MARIONETTE": 7.0, "CUT MARIONETTE": 2.4, "BOG WITCH": 2.0, "CANDLE WITCH": 0.6,
    "GRANDMOTHER": 0.12, "BIG BAD WOLF": 0.035,
}
MIN_DEPTH = {"BIG BAD WOLF": 0.5, "GRANDMOTHER": 0.3, "CANDLE WITCH": 0.25, "HOLLOW KING": 0.2}


def tier(pct):
    return "COMMON" if pct >= 5 else "UNCOMMON" if pct >= 2 else "RARE" if pct >= 0.5 else "LEGENDARY"


def to_rgba(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def render(grid, overrides, w, h):
    pal = dict(BASE, **overrides)
    assert len(grid) == h, (len(grid), h)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    eyes = []
    for y, row in enumerate(grid):
        assert len(row) == w, f"row {y} is {len(row)} wide: {row!r}"
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            img.putpixel((x, y), to_rgba(pal[ch]))
            if ch in EYE_LETTERS:
                eyes.append((x, y, pal[ch]))
    return rim_light(img, grid), eyes


def rim_light(img, grid):
    """Brighten body pixels that sit just inside the top/left outline, as if
    lit from above -- the silhouette pops off dark floors."""
    out = img.copy()
    px = img.load()
    h, w = len(grid), len(grid[0])
    for y in range(h):
        for x in range(w):
            ch = grid[y][x]
            if ch in (".", "K") or ch in EYE_LETTERS:
                continue
            up = grid[y - 1][x] if y > 0 else "."
            left = grid[y][x - 1] if x > 0 else "."
            if up in ".K" or left in ".K":
                r, g, b, a = px[x, y]
                out.putpixel((x, y), (min(255, int(r + (255 - r) * 0.35)), min(255, int(g + (255 - g) * 0.35)),
                                      min(255, int(b + (255 - b) * 0.38)), a))
    return out


# ---------------------------------------------------------------------------
# Animation: 4 frames per creature (rows of the sheet). Frame 0 is the
# drawing above, untouched. Insects scuttle -- every thin leg stroke steps,
# alternating sides (a tripod gait), antennae twitch, wings beat; demons
# walk -- feet lift in turn, clawed hands swing, cloaks and skirts sway.
# Eyes never move, so the glowing-eye overlay always lines up.
# ---------------------------------------------------------------------------
FRAMES = 4
STEP = [0, -1, 0, 1]


def _cells(grid):
    return [list(r) for r in grid]


def _rows(g):
    return ["".join(r) for r in g]


def _body(ch):
    return ch not in (".", "K")


def insect_frames(grid, design):
    h, w = len(grid), len(grid[0])
    body_rows = [y for y in range(h) if any(_body(c) for c in grid[y])]
    top, bottom = min(body_rows), max(body_rows)
    limbs = []
    for y in range(h):
        for x in range(w):
            if grid[y][x] != "K":
                continue
            near = [grid[yy][xx] for (xx, yy) in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))
                    if 0 <= xx < w and 0 <= yy < h]
            if not any(_body(c) for c in near):
                limbs.append((x, y))
    frames = []
    for f in range(FRAMES):
        g = _cells(grid)
        for (x, y) in limbs:
            g[y][x] = "."
        for (x, y) in limbs:
            side = 0 if x < w // 2 else 1
            phase = (side + y // 3) % 2
            d = STEP[(f + 2 * phase) % 4]
            if y < top or y > bottom:   # antennae / legs above and below: sweep sideways
                nx, ny = x + d * (1 if side == 0 else -1), y
            else:                       # legs out to the sides: step up and down
                nx, ny = x, y + d
            if 0 <= nx < w and 0 <= ny < h and g[ny][nx] == ".":
                g[ny][nx] = "K"
            elif g[y][x] == ".":
                g[y][x] = "K"
        if design == "wasp" and f % 2 == 1:   # wings beat: up, then down
            wing = [g[y][:] for y in range(1, 5)]
            for y in range(1, 5):
                g[y] = ["."] * w
            for i, row in enumerate(wing):
                ty = 1 + i + (-1 if f == 1 else 1)
                for x, c in enumerate(row):
                    if c != "." and 0 <= ty < h and (g[ty][x] == "." or ty >= 5):
                        if ty < 5 or g[ty][x] == ".":
                            g[ty][x] = c
        if design == "moth" and f % 2 == 1:   # wings fold in a little
            for y in range(h):
                row = g[y]
                left = row[:7]
                right = row[9:]
                if f == 1:
                    left = ["."] + left[:-1] if left[-1] in ".K" else left
                    right = right[1:] + ["."] if right[0] in ".K" else right
                g[y] = left + row[7:9] + right
        if design == "mantis":   # raptorial arms: cocked back, then strike
            dy = [0, -1, 0, 1][f]
            for (c0, c1) in ((0, 5), (11, 16)):
                block = [g[y][c0:c1] for y in range(4, 10)]
                for y in range(4, 10):
                    for x in range(c0, c1):
                        if g[y][x] in "KM":
                            g[y][x] = "."
                for i, row in enumerate(block):
                    ty = 4 + i + dy
                    for j, c in enumerate(row):
                        if c != "." and 0 <= ty < h and g[ty][c0 + j] == ".":
                            g[ty][c0 + j] = c
        frames.append(_rows(g))
    return frames


# (rows, cols) regions for each demon design
DEMON_RIG = {
    "grinner": {"hands": ((19, 21), (0, 3), (12, 15)), "legs": ((21, 22), (4, 7), (8, 11))},
    "many_eyes": {"hands": ((17, 19), (0, 2), (13, 15)), "legs": ((20, 22), (3, 6), (9, 12)), "blink": True},
    "wraith": {"hands": ((19, 20), (0, 2), (12, 15)), "legs": ((21, 22), (3, 6), (9, 12)),
               "claws": ((0, 4), (0, 4), (11, 15))},
    "hollow": {"hands": ((19, 20), (0, 3), (12, 15)), "legs": ((22, 23), (4, 7), (9, 12))},
    "maw": {"hands": ((18, 19), (0, 2), (13, 15)), "legs": ((20, 22), (3, 6), (9, 12))},
    "weeper": {"hands": ((16, 18), (1, 4), (11, 14)), "skirt": (19, 22)},
    "marionette": {"hands": ((10, 14), (2, 4), (12, 15)), "legs": ((17, 23), (4, 7), (9, 12))},
    "witch": {"hands": ((13, 16), (0, 2), (13, 15)), "skirt": (17, 21)},
    "grandmother": {"hands": ((12, 16), (0, 3), (12, 15)), "legs": ((22, 23), (3, 6), (9, 12)), "skirt": (17, 20)},
}


def _shift(g, rows, cols, dx, dy, onto_empty=True):
    (r0, r1), (c0, c1) = rows, cols
    block = {}
    for y in range(r0, r1 + 1):
        for x in range(c0, c1 + 1):
            if g[y][x] != ".":
                block[(x, y)] = g[y][x]
                g[y][x] = "."
    for (x, y), c in block.items():
        nx, ny = x + dx, y + dy
        if 0 <= ny < len(g) and 0 <= nx < len(g[0]) and (g[ny][nx] == "." or not onto_empty):
            g[ny][nx] = c


def _lift(g, rows, cols):
    """A foot comes off the ground: the leg's rows slide up one."""
    (r0, r1), (c0, c1) = rows, cols
    for y in range(r0, r1):
        for x in range(c0, c1 + 1):
            g[y][x] = g[y + 1][x] if g[y + 1][x] != "." else (g[y][x] if y == r0 else ".")
    for x in range(c0, c1 + 1):
        g[r1][x] = "."


def demon_frames(grid, design):
    rig = DEMON_RIG[design]
    frames = []
    for f in range(FRAMES):
        g = _cells(grid)
        hl = [0, 1, 1, -1][f]    # left hand
        hr = [0, -1, 1, 1][f]    # right hand (frame 2: both hang low -- a breath)
        if "hands" in rig:
            rows, lc, rc = rig["hands"]
            _shift(g, rows, lc, 0, hl)
            _shift(g, rows, rc, 0, hr)
        if "claws" in rig:
            rows, lc, rc = rig["claws"]
            _shift(g, rows, lc, [0, -1, 0, 1][f], 0)
            _shift(g, rows, rc, [0, 1, 0, -1][f], 0)
        if "legs" in rig:
            rows, lc, rc = rig["legs"]
            if f == 1:
                _lift(g, rows, lc)
            elif f == 3:
                _lift(g, rows, rc)
        if "skirt" in rig and f in (1, 3):
            r0, r1 = rig["skirt"]
            d = 1 if f == 1 else -1
            for y in range(r0 + 1, r1 + 1):
                row = g[y]
                g[y] = (["."] + row[:-1]) if d > 0 else (row[1:] + ["."])
        if rig.get("blink") and f == 2:
            for y in range(len(g)):
                for x in range(len(g[0])):
                    if g[y][x] == "Z" and (x + y) % 3 == 0:
                        g[y][x] = "K"
        frames.append(_rows(g))
    return frames


DESIGN_OF = {}


def sheet(entries, w, h, animate):
    img = Image.new("RGBA", (w * len(entries), h * FRAMES), (0, 0, 0, 0))
    all_eyes = []
    for i, (name, grid, over, stats, nature) in enumerate(entries):
        for f, fg in enumerate(animate(grid, DESIGN_OF[id(grid)])):
            frame, eyes = render(fg, over, w, h)
            img.paste(frame, (i * w, f * h))
            if f == 0:
                all_eyes.append(eyes)
    return img, all_eyes


def gd_entry(name, stats, nature):
    parts = [f'"name": "{name}"', f'"atk": {stats["atk"]}', f'"def": {stats["df"]}', f'"hp": {stats["hp"]}',
             f'"step": {stats["step"]}', f'"aggro": {stats["aggro"]}', f'"nature": "{nature}"']
    if stats.get("moth"):
        parts.append('"moth": true')
    pct = RARITY[name]
    parts.append(f'"rarity": {pct}')
    parts.append(f'"tier": "{tier(pct)}"')
    if name in MIN_DEPTH:
        parts.append(f'"min_depth": {MIN_DEPTH[name]}')
    return "\t\t{" + ", ".join(parts) + "},"


def gd_eyes(eyes, y_off):
    rows = []
    for variant in eyes:
        items = ", ".join(f'[Vector2({x}, {y + y_off}), Color("{c}")]' for (x, y, c) in variant)
        rows.append(f"\t\t[{items}],")
    return "\n".join(rows)


def main():
    for grid, name in ((BEETLE, "beetle"), (SPIDER, "spider"), (MOTH, "moth"), (CENTIPEDE, "centipede"),
                       (TICK, "tick"), (SCARAB, "scarab"), (WASP, "wasp"), (MANTIS, "mantis"),
                       (GRINNER, "grinner"), (MANY_EYES, "many_eyes"), (WRAITH, "wraith"), (HOLLOW, "hollow"),
                       (MAW, "maw"), (WEEPER, "weeper"), (FIREFLY, "firefly"), (SCORPION, "scorpion"),
                       (STAG, "stag"), (MARIONETTE, "marionette"), (WITCH, "witch"), (GRANDMA, "grandmother")):
        DESIGN_OF[id(grid)] = name
    ins, ins_eyes = sheet(INSECTS, 16, 16, insect_frames)
    dem, dem_eyes = sheet(DEMONS, 16, 24, demon_frames)
    ins.save(ROOT / "assets" / "insects.png")
    dem.save(ROOT / "assets" / "demons.png")
    lines = [
        "class_name CreatureData",
        "## GENERATED by tools/make_creatures.py -- edit the stats there and re-run.",
        "## Column i of insects.png / demons.png is entry i of its list; rows are its 4 animation frames.",
        "",
        "const TYPES := {",
        '\t"insect": [',
        *[gd_entry(n, s, it) for (n, _, _, s, it) in INSECTS],
        "\t],",
        '\t"demon": [',
        *[gd_entry(n, s, it) for (n, _, _, s, it) in DEMONS],
        "\t],",
        "}",
        "",
        "## Eye pixels (offset from the tile's top-left, color) per creature, so",
        "## their eyes can glow in the dark.",
        "const EYES := {",
        '\t"insect": [',
        gd_eyes(ins_eyes, 0),
        "\t],",
        '\t"demon": [',
        gd_eyes(dem_eyes, -8),   # demon frames start 8px above the tile
        "\t],",
        "}",
        "",
    ]
    (ROOT / "scripts" / "creature_data.gd").write_text("\n".join(lines))
    print(f"wrote {len(INSECTS)} insects, {len(DEMONS)} demons")


if __name__ == "__main__":
    main()
