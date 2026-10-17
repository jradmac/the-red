# The Longman patch (for any session that keeps its own copy of Scythe)

This folder has the Longman: it replaces the ghosts (what comes for you in the dark), and if it
reaches you it eats you and the run ends. Two players: one Longman each.

If you work from your own copy of the project and unpack it over this folder, merge these in
first or they'll be overwritten. `scythe_longman_patch.tgz` (next to this file) holds every file
the Longman touches, at the paths they go to:

New files
- scripts/longman.gd            the Longman itself
- assets/longman.png            its sprite sheet (32 frames, 80 x 80)
- tools/make_longman.py         builds the sprite sheet

Changed files (small edits; diff them against yours)
- scripts/main.gd               `longmen`, `_tick_longmen`, `_in_partners_light` (a partner's lantern protects you), `_on_eaten`;
                                bombs.exploded scares it; dawn / good-morning text
- scripts/enemies.gd            GHOSTS := 0 (no ghosts spawn; the ghost code is inert)
- scripts/hud.gd                "IT'S COMING" / "SOMETHING IS WATCHING YOU..." / "SAFE IN YOUR PARTNER'S LIGHT"; var shelter
- scripts/ghost_mirror.gd       also draws the Longmen on player 2's half
- scripts/save_game.gd          VERSION 4 (creature uids moved with the ghosts gone)
- scripts/lore.gd               commandment I, Lume's guide (THE LANTERN, THE DARK, DAY AND NIGHT,
                                BOMBS, VILLAGES)
- scripts/village_talk.gd, scripts/village_screen.gd   villagers' lines
- scripts/lantern.gd, day_cycle.gd, companion.gd, eyes.gd   comments only
- README.md                     ghost mentions updated; "The Longman" section at the end

## Also in this patch: fights just start
No fight button and no lead-in text: an insect or demon touching you, or you walking into one,
starts the battle at once. Files: scripts/main.gd (`_start_fight`, trade input), scripts/hud.gd
(hint bar, removed the ATTACK THE ... prompt), scripts/controls.gd (no "attack" action:
Space / K / pad Y freed), scripts/enemies.gd (removed engageable_demon), scripts/lore.gd
(FIGHTING, CONTROLS, PLAYER 2 KEYS), README.md.
