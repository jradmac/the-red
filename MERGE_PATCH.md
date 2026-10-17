# Scythe merge patch (built on scythe_fix39)

Another chat added these features to Scythe. Every save that unpacks a full copy of the project
over this folder has wiped them, so **merge this into your copy before your next save**.
Everything was tested in the engine on top of scythe_fix39 (solo, two players, 3D on and off).

`scythe_merge_patch.tgz` contains:
- `files/` -- every changed or new file, complete, at the path it goes to. If your copy of a file
  still matches fix39, just drop the patched file in.
- `scythe_changes.diff` -- the same changes as a unified diff against fix39
  (`cd scythe && patch -p1 < scythe_changes.diff`), for files you've changed since fix39.
  (assets/longman.png is binary: copy it from files/.)

## What it does
1. **The Longman replaces the ghosts.** scripts/longman.gd (new), assets/longman.png (new),
   tools/make_longman.py (new). In the dark it watches from the edge of the screen, then comes for
   you over walls; light sends it back; if it reaches you it eats you and the run ends.
   Two players: one each. main.gd (`longmen`, `_tick_longmen`, `_on_eaten`), enemies.gd
   (GHOSTS := 0), hud.gd, ghost_mirror.gd, save_game.gd (VERSION 4), lore.gd, village_talk.gd,
   village_screen.gd; comments in lantern.gd, day_cycle.gd, companion.gd, eyes.gd.
2. **Light protects whoever stands in it** (two players): a partner's lantern counts like your
   own; flares already did. main.gd `_in_partners_light`; hud.gd `shelter` message.
3. **Fights just start.** No lead-in text and no fight button: touching a creature (or it touching
   you) starts the battle. main.gd `_start_fight` + trade input, controls.gd (no "attack" action),
   hud.gd (hint + prompt removed), enemies.gd (engageable_demon removed), lore.gd.
4. **The battle screen.** scripts/battle_fx.gd (new): an arena matching the landscape, floating
   particles, fog, bursts on impacts. battle.gd: slide-in intro; ATTACK / DEFEND / DODGE as three
   big cards across the bottom; the BAG as a button beneath them (down to reach it); compact
   player panel. README.md documents all four.
