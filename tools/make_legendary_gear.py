"""Builds the legendary gear (tools/legendary_gear.py) into every sheet that shows it:

    gear_big.png, gear_side_big.png, gear_side.png   -- via make_gear_big.py (column 6)
    hero_big*.png, hero_big_arm.png                  -- via make_hero_big.py (look 6)
    hero.png, hero_blue.png, hero_p2.png, hero_p2_blue.png   look 6 (rows 24-27)
    gear.png                                          column 6
    items.png                                         icons 32 (axe) and 33 (cloak)

The last three are sheets other tools build whole (make_art.py, make_tool_items.py):
run this after them. Run:  python3 tools/make_legendary_gear.py
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import legendary_gear as lg            # noqa: E402
import make_gear_big                   # noqa: E402
import make_hero_big                   # noqa: E402
import make_art                        # noqa: E402

A = Path(__file__).resolve().parent.parent / "assets"
LOOK_INDEX = 6
AXE_COL = 6
ICON_AXE, ICON_CLOAK = 32, 33


def _put(path, img, at, min_size):
    """Paste img into the sheet at `path` at `at`, growing the sheet if it's too small."""
    sheet = Image.open(path).convert("RGBA")
    w, h = max(sheet.width, min_size[0]), max(sheet.height, min_size[1])
    if (w, h) != sheet.size:
        grown = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        grown.paste(sheet, (0, 0))
        sheet = grown
    sheet.paste(Image.new("RGBA", img.size, (0, 0, 0, 0)), at)
    sheet.alpha_composite(img, at)
    sheet.save(path)


def small_hero_block():
    """The four rows (down, up, left, right) x 9 frames of the wolfskin look."""
    views = [("down", False, "down"), ("up", False, "up"), ("right", True, "left"), ("right", False, "right")]
    frames = {v: make_art.hero_frames(v) for v in ("down", "up", "right")}
    block = Image.new("RGBA", (16 * make_art.HERO_COLS, 24 * 4), (0, 0, 0, 0))
    for row, (view, mirror, ears) in enumerate(views):
        for col, grid in enumerate(frames[view]):
            f = make_art._look_frame(grid, lg.SMALL_LOOK[1])
            if mirror:
                f = f.transpose(Image.FLIP_LEFT_RIGHT)
            block.paste(lg.ears_small(f, ears), (col * 16, row * 24))
    return block


def main():
    make_gear_big.main()      # (column 6 comes from the hook in make_gear_big.py)
    make_hero_big.main()      # (look 6 comes from the hook in make_hero_big.py)
    # the small hero, in all four of its sheets
    block = small_hero_block()
    tmp = A / "_legendary_tmp.png"
    block.save(tmp)
    variants = {"hero.png": block, "hero_blue.png": make_art.blue_lantern_sheet(tmp)}
    variants["hero_p2.png"] = make_art.recolor(tmp, make_art.P2_CLOTHES)
    variants["hero_p2.png"].save(tmp)
    variants["hero_p2_blue.png"] = make_art.blue_lantern_sheet(tmp)
    tmp.unlink()
    for name, img in variants.items():
        _put(A / name, img, (0, LOOK_INDEX * 96), (img.width, (LOOK_INDEX + 1) * 96))
    # the axe carried on the back (gear.png) and its icon, from the big diagonal drawing
    diag = make_gear_big.render((9.0, 55.0), (1.0, -1.0)).crop((AXE_COL * 64, 0, AXE_COL * 64 + 64, 64))
    axe16 = lg.small_axe(diag)
    _put(A / "gear.png", axe16, (AXE_COL * 16, 0), ((AXE_COL + 1) * 16, 16))
    _put(A / "items.png", axe16, (ICON_AXE * 16, 0), ((ICON_AXE + 1) * 16, 16))
    _put(A / "items.png", lg.cloak_icon(), (ICON_CLOAK * 16, 0), ((ICON_CLOAK + 1) * 16, 16))
    print("wrote the huntsman's axe and the wolfskin cloak into the gear, hero and item sheets")


if __name__ == "__main__":
    main()
