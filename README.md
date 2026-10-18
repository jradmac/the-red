# Red Riding

A dark, retro-style labyrinth crawler built in Godot 4, loosely after Little Red Riding Hood. (Working titles: Pack-Man, Scythe.) Design doc lives in Claude Docs.

## Run it

1. Install Godot 4 (standard version, not .NET) from https://godotengine.org/download
2. Open Godot → **Import** → select this folder's `project.godot` → **Import & Edit**
3. Press **F5** (or the ▶ button, top right) to play

## Controls

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Move | Arrow keys / WASD | D-pad |
| Open chest or door / pick up item you're standing on / confirm | Z or Enter | A |
| Back / cancel | X | B |
| Sprint (hold) — uses energy, refills when you stop | Z or Shift | B |
| Bag (in bag: Z use potion, X drop, I close) | I | Start |
| Strike a match (refuel lantern) | E or Q | R |
| Plant a flare (maps the room) | F | L |
| Map | M or Tab | Select |
| Matches, flares and lanterns | just walk over them | |
| New labyrinth (any time; Start after dying) | R | Start |

## Day and night

`scripts/day_cycle.gd`: 15 minutes of night, then 5 minutes of day (25 s
sunrise / sunset), on repeat; a run starts 5 minutes before the first dawn.
By day the whole screen is lit, the lantern is put away (no fuel burns), and
demons and the Longman are gone -- only insects remain. DAYBREAK / NIGHTFALL
banners announce the change; the clock at the top shows time to dawn/dusk.
Past 80% of the way through the labyrinth: ETERNAL NIGHT, no more days.

Wind: drafty corridors burn fuel faster; random gusts (every 1-2 min, at
night, with a 2 s "THE WIND PICKS UP..." warning) blow the lantern out.
A Windbreak potion protects the flame.

## Progression

How deep you are = how many locked doors stand between you and the start
(`Doors.depth_at`, shown as DEPTH n when you push into new ground). Deeper:
- more of the creatures are demons (12% near the start -> 60% at the end),
  more of them are the tougher colour, and all get stronger
  (`Enemies.SCALING`: up to +6/+8 ATK, +4/+5 DEF, ~2.7x HP)
- chests and demon drops lean toward better gear (`Items.GEAR_TIER`), and
  deep gear can come already blessed (+1 to +4)

## Project layout

- `scenes/main.tscn` — the main scene
- `scripts/labyrinth.gd` — generates a new labyrinth each run. The map is split into zones, each a landscape: crypt (rooms + corridors), forest, ruined courtyard, mountain (cliffs, waterfalls), river (bridges) or swamp. Tune BIOME_WEIGHTS at the top
- `scripts/wisps.gd` + `scripts/riddle_screen.gd` + `scripts/riddles.gd` — sprites: floating flames that ask riddles (8 kinds, mostly generated). Right answer: upgrade a weapon/armor (+2..+4) or a clue (next door / its key shown on the map)
- `tools/make_walls3d.py` — raised-terrain autotiles: every wall top and water edge is drawn as four 8x8 quarters with rounded corners, lit lips and sloped sides (Pokemon-style depth); wall faces are tall sprites that rise over the tile above
- `tools/make_wall_blocks.py` — the stone of the 3D walls (`wall_blocks.png`): tops, fronts and sides drawn from one material per landscape (castle stone with a pale coping in the crypt, weathered sandstone in the courtyard, rock under a cap of turf in the mountains), so they meet in a rounded edge. In 3D every wall is a single block one tile high: the top shows over its own tile and the front fills the bottom row (a wall one tile deep gets a strip of top along its front)
- `tools/make_wall_details.py` — the landscape details laid over the 3D walls and cliffs (`wall_details.png`, `cliff_details.png`): moss, hanging moss, cobwebs, seeping damp and pale toadstools in the crypt; ivy, flowering creepers, lichen and cracks in the courtyard; snow caps, icicles, lichen, ore veins and crystals in the mountains; roots, ferns and mushrooms on woodland cliffs; slime, vines and bracket fungus in the swamp. `terrain3d.gd` puts one on a face now and then, more of them in patches (`DETAIL_CHANCE` sets how often per landscape)
- `tools/make_battle_sprites.py` (designs in `battle_insects.py`, `battle_demons.py`) — the creatures up close in battle: 64 x 64 insects, 64 x 96 demons (`insects_battle.png`, `demons_battle.png`), 4 frames each. Drawn by `tools/pixkit.py` as lit 3D forms on a 48-unit grid rendered at 4/3, with cast shadows between parts, grain in the shading and a per-creature surface pass (pitted shells, bristles, dusty wing scales, pocked flesh, wet glints). The Weeper and the Bride have their own designs: hair over a face of wet black eye-holes, hands clawing at it; the Bride in a veil and a hem-stained dress, holding a dead bouquet
- `tools/make_hero_big.py` + `tools/make_gear_big.py` — the detailed hero (64 x 96: 4 facings x the 6 armor looks, player 1 / player 2, normal / blue lantern) with the pack and bedroll from behind, and the 6 weapons at 64 x 64. `HeroLook.draw_big()` draws them in battle (from behind; the right arm, `hero_big_arm.png`, swings the weapon on its own) and turning on the pedestal in the bag
- `tools/make_straps.py` — how the weapon is carried, small hero and big: slung across the back on a leather baldric, grip up over the right shoulder. Facing you the grip shows over your shoulder and the strap (with its buckle) crosses your chest; from behind it lies over the pack, bound by two loops; from the side a steeper sprite (`gear_side*.png`, from `make_gear_big.py`) runs down along the pack. `HeroLook.CARRY_OFF` / `CARRY_OFF_BIG` place it. When you swing it in battle the strap stays and the weapon leaves your back
- `scripts/arches.gd` + `tools/make_tall.py` — stone archways where crypts open to the outdoors, and the tall sprites (castle walls, cliffs, ruined walls, tree crowns, boulders) that give the outdoors height
- `scripts/traps.gd` — traps per landscape (spike plates, spike rows, trapdoors, darts, falling masonry, bear traps, thorns, rockfalls, quicksand, poison gas vents). ~1 per 400 open tiles, none near the start; direct damage, a little more deeper in
- `scripts/mist.gd` — drifting fog over rivers, swamps, forests and mountains
- `scripts/world.gd` — the tile map: collision, line of sight, drawing
- `scripts/automap.gd` — the map screen (shows only flared areas)
- `scripts/flares.gd` — flare markers
- `scripts/lantern.gd` — fuel and matches. When it runs out you can keep going in the dark, but the Longman comes for you (see below) until you relight it
- `scripts/wind.gd` — drafty corridors and random gusts
- `scripts/pickups.gd` — hovering items on the floor (loose matches, flares, dropped gear)
- `scripts/items.gd` — item catalog and chest loot table (rebalance here)
- `scripts/inventory.gd` — 4 slots, health, attack/defense, potion effects
- `scripts/chests.gd` — chest placement and contents
- `scripts/chest_screen.gd` — the open-chest screen (take and store)
- `scripts/doors.gd` — door placement, the always-solvable key rule, opening doors
- `scripts/lock_puzzle.gd` — the lockpicking mini-game
- `scripts/enemies.gd` — enemy types, spawning, and AI (light-based behavior)
- `scripts/enemy.gd`, `scripts/enemy_eyes.gd` — one enemy's movement/drawing; eyes glowing in the dark
- `scripts/battle.gd` — combat: each round you and the enemy secretly pick ATTACK / DEFEND / DODGE (or use an item), then both are revealed and play out. ATK = all your weapons added up, DEF = all your armor added up. Enemy natures + tells live at the top
- `scripts/master.gd` — the master chamber gate and the purple chest (the win condition)
- `scripts/stats.gd`, `scripts/ending.gd` — run stats and the victory screen
- `scripts/dialog.gd` — text box and choice prompts
- `scripts/bag.gd` — the bag screen
- `scripts/hud.gd`, `scripts/pixel_font.gd` — on-screen counters and tiny pixel text
- `scripts/player.gd` — grid movement, input, and the character sprite
- `scripts/main.gd` — wires world, player, and camera together

- `scripts/lighting.gd` + `shaders/lighting.gdshader` — darkness and light sources
- `scripts/eyes.gd` — glowing eyes that watch from the dark
- `assets/` — sprite sheets (hero, tiles, props, enemy style preview)
- `tools/make_art.py` — regenerates the sprite sheets from pixel grids (`python3 tools/make_art.py`)
- `tools/make_creatures.py` — builds the insect and demon sprites (16 insects, 12 demons) and `scripts/creature_data.gd` (their stats)
- `tools/make_env.py` — builds the detailed environment tileset (`assets/env.png`) and door sprites (`assets/doors.png`)
- `shaders/lighting_core.gdshaderinc` — lighting: walls cast soft shadows, warm bloom near flames

## Milestones

- [x] 1. Walk around a tile map with collision
- [x] 2. Random labyrinth generation + flare-built map
- [x] 3. Lantern fuel meter, matches, wind, light-out
- [x] 4. Chests, items, 4-slot inventory, health
- [x] 5. Doors, keys, lockpicking (always solvable)
- [x] 6. Enemies with light-based behavior
- [x] 7. Turn-based combat
- [x] 8. Master chamber + win/lose loop
- [ ] 9. Art, audio, balance

## Depth pass
- Walk-behind occlusion: trees, tall walls, cliffs and boulders just south of the hero are redrawn over him (world.gd `_over`, driven by `world.focus`).
- Edge trees are 3 tiles tall (tall.png, `tall_tree`), with cast shadows.
- Directional cast shadows (light from upper-left), stepped grass edges, stronger top/face contrast and softer outlines (make_env.py, make_walls3d.py).

## Map detail
`tools/make_detail.py` builds `rocks.png` (6 rock kinds x 5 stone palettes x 4 variants, shaded in 3D with their own cast shadows), `decor.png` (8 ground details per landscape) and `patches.png` (soft ground patches that break up the tile grid). world.gd places them: blocking `b` cells become boulders, flat-topped rocks, spires and clusters; mountain plateaus carry big rocks; every landscape gets its own scatter of decor.

## Light budget
Lantern drains 0.65 fuel/s (full = ~2.5 min); a match adds 30 (~45 s); the matchbox holds 6 (a full box leaves matches on the ground for later). One loose match per ~60 floor tiles. A map holds ~230 matches + ~20 lamp oils: about 3.4 h of light if you found everything, against ~2.75 h of night in a 3.5 h run. Explorers stay lit; rushers spend stretches in the dark.
Riddle sprites drift around within 3 tiles of where they appeared, and hold still once you're beside them.
Ghosts are gone (Enemies.GHOSTS = 0); the Longman replaced them -- see "The Longman" below.

## Healing budget (scripts/forage.gd)
Per section (between locked doors): expected damage = tiles/105 creatures x 50% fought x (3.4 + 6p) damage per fight x 1.15 (traps; this used to include ghost hits). The map places 80% of that as healing: chest tonics already there, then red-berry bushes (forest/riverbank, 2 berries x 3 HP, regrow at dawn), then extra tonics (half in the section's chests, half on the floor, mostly dead ends). Blue-berry bushes (swamp/mountain, ~1 per 350 tiles): crush into the lantern for 60 s of blue flame - creatures flee its light. Damage-per-fight comes from simulating the battle rules with a tell-reading player; enemy ATK scaling was softened (insect +3, demon +4 at the deepest) because deep fights were averaging more than your whole health bar.
Clock: shows DAY / NIGHT; only the last minute before dawn or dusk counts down. F11 or Alt+Enter toggles fullscreen.

## The opening and Lume
Every run begins in the Waking Chamber (labyrinth.gd `_place_start_room`): a fixed 9x7 room in the middle of the start zone with a stone bier, two candles, two graves and moss; the rest of the map is random. `intro.gd` plays the opening every run (ESC / pad Start skips): a voice in the dark, Lume appearing, the hero waking on the bier, the backstory, the Commandments (on a stone tablet), and the basics. The game is paused underneath. All the words live in `lore.gd`.
Lume (`companion.gd`, art in tools/make_detail.py -> lume.png) follows you all game at your shoulder with a small light of its own. In the bag, G opens Lume's guide: 11 pages (lantern, dark, fighting, gear, doors, flames, day/night, healing, dangers, the Commandments, controls).
Tests: set SCYTHE_NO_INTRO=1 to skip the intro.

## Bombs, chest berries, sunstones
Bombs (bombs.gd, Fx.explosion): B or from the bag; 2.2 s fuse; kills insects/demons within 2.6 tiles (with drops), sends the Longman back for 6 s if it is close, chains other bombs, hurts you for 2 within 1.2 tiles; scorch mark. Chests can now hold red berries, blue berries, and (rarely) sunstones: 2 minutes of daylight-strength light of your own (lighting.sun_glow), no fuel burn, no gusts, relights a dead lantern.

## Sound
Every sound is synthesized by `tools/make_sfx.py` into assets/sfx/ (80 wavs). `scripts/sfx.gd` plays them: `Sfx.play(name)`, `Sfx.play_at(name, pos)` (fades with distance), `Sfx.ambient(loop)` (crossfades: crypt drone, night wind + crickets, day birds). Footsteps change with the ground; heartbeat under 4 hearts; - and = change the volume.

## Music
`tools/make_music.py` composes 13 looping tracks (assets/music/*.ogg) around one theme: day and night for each landscape (crypt, forest, courtyard, mountain, river, swamp) plus battle. Each landscape has its own key, mode, tempo and instruments; night turns it minor, slow, sparse and echoing over a drone. main.gd picks the track by where you are (after 2.5 s, so borders don't flicker) and crossfades; battles switch to the battle theme; tracks resume where they left off. N toggles music.

## Title screen
`scripts/title_screen.gd`, before anything else: RED RIDING carved out of the dark -- heavy Roman capitals, eroded, chipped and gouged, red-hot at the bottom like lantern light (`assets/title_logo.png`, built by `tools/make_title.py` from TeX Gyre Bonum Bold in `tools/fonts`). It flickers in like a wick catching, a band of heat passes over it now and then, and motes of warm lantern light and deep violet shadow drift up past it. PRESS START (Z, Enter, a controller's A or Start), then CONTINUE (with the saved run's summary) when there is one, or NEW GAME, which asks before erasing a save. New game goes on to the waking scene.

## Saving and settings
One save slot (save_game.gd, user://scythe_save.dat). The labyrinth is rebuilt from its seed and the changes are re-applied (you, bag, light, flares, open doors, chests, floor items, berries, living/dead creatures by uid, sprites, clock, map, hints, stats). Save from the bag's bottom row (SAVE GAME / SAVE + QUIT); at start-up a title screen offers CONTINUE or NEW GAME (which asks before erasing). Dying or winning deletes the save. SETTINGS (same row) has separate sound-effect and music volumes, kept in user://settings.cfg.

## Two players (split screen)
- Join: Start on a second controller, or J on the keyboard. Leave: LEAVE GAME in the bag.
- Shared keyboard: P1 = WASD + Z X E F I M B Shift T. P2 = arrows, Enter (act / hold to run),
  / or Backspace (back), . match, , flare, ; bag, L map, ' bomb, P ask Lume, J trade.
- 5 hearts each; when one leaves, the survivor gets both players' hearts (out of 10). If one dies,
  their bag spills on the floor and the other carries on; game over when nobody is left.
- Own: bag, lantern, matches, hearts, spirit (P2: teal Lume, blue clothes). Shared: map, flares,
  doors, chests, day/night.
- Screen: one view while close; splits along an angled line as you separate (scripts/coop_view.gd,
  shaders/split.gdshader); straight down the middle while either player is in a battle or menu.
- Trade: stand within 2 tiles and press trade (T / J / X on a pad) -> scripts/trade_screen.gd.
- Per-player systems live in scripts/hero.gd; shared world systems get bind(hero) + hero_tick().
- Saving in co-op saves the game as a one-player game (player 1's things).

## Villages and rubies
- 4 villages per run, spread by depth (about 12%, 33%, 53%, 72% of the way; never past 80%, where
  the sun stops rising). World.generate builds the labyrinth, works out each zone's depth with a
  scratch set of doors, stamps a village into the best zone for each depth
  (LabyrinthGenerator.add_villages / _stamp_village), then checks again with the real doors and
  re-picks if one landed too deep. The map is 8 zones across (241 x 135) so the villages don't
  shrink the landscapes. Each sits in a zone carved like the land around it, inside a
  wall with gates north and south (they swing open as you come near), guards, lamp posts, a well
  and square, a shop, a sage, an inn, a fenced berry farm and 1-3 homes. The look follows the land:
  timber + moss roofs (forest), white stone + slate (courtyard), grey stone + red tile (mountain),
  planks + thatch (river), dark planks + reed (swamp). Art: tools/make_village.py -> assets/village.png,
  assets/npcs.png (villagers, guards, keepers).
- Safe haven: no creatures, no Longman, traps, eyes or wind inside; the lantern burns no fuel.
- scripts/villages.gd draws them and walks the people; scripts/village_screen.gd is the inside of
  each building; scripts/village_talk.gd is what people say.
- Shop: always tonics, flares, matches, lamp oil, red berries and three lanterns (brass, storm -
  windproof - and witchglass), plus four one-off finds that suit the depth. Prices: Items.PRICES.
- Sage: full heal for 2 rubies per missing heart (min 3). Inn: 12 to sleep till morning (everyone,
  the screen goes dark), or a 4-ruby meal (+3 hearts).
- Rubies (Inventory.rubies, per player): on the floor (Pickups.CELLS_PER_RUBY), in ~35-55% of
  chests (more deeper), and dropped by creatures you beat. A run hands out roughly 300-350.
- Save version 2 (older saves are from a smaller map and are ignored).

## Creatures and battle balance
- ATK = all your weapons added together (the strongest -- or, of equals, the last picked up -- is the one shown in your hand); DEF = your best armor.
- Density rises with depth (Enemies.DENSITY): ~0.35x average near the start, ~1.6x at the bottom.
- 40% of insects are hunters; the rest keep their distance and only fight if you walk right up.
  Anything chasing gives up if you open a gap or it chases too long, then ignores you for 5-9 s.
- Creature stats (Enemies.SCALING) were tuned with tools/battle_sim.py: fights last ~3-4 rounds
  and cost ~3 hearts near the start rising to ~8 at the bottom; Forage.damage_per_fight uses this.

## High ground
- LabyrinthGenerator._raise_land: in open zones, compact blobs of open field become plateaus (level 1,
  sometimes a level-2 rise on top), ringed by cliff tiles ("#", World.cliffs) with 1-2 slopes
  (World.ramps "s"/"w"/"e"). Crypt rooms (7x5+) sometimes get a raised dais: the back two rows go
  up a level, the row below becomes a ledge with stairs in the middle.
- Cliffs are ordinary walls for movement and pathing, so nothing else needed changing; World draws
  them from assets/heights.png (tools/make_heights.py), tints raised ground a touch lighter and
  shades the ground below each cliff. Light spills over cliffs.

## The Longman (replaces the ghosts)
`scripts/longman.gd`, art `assets/longman.png` (32 frames, 80 x 80) from `tools/make_longman.py`.
A gaunt pale figure about 4.5 tiles tall with a blank face and one hole in it, a dead lantern on
its wrist. One per player (main.gd `longmen`, `_tick_longmen`, `_on_eaten`).
- Flame in its last quarter (`Lantern.ghosts_gather`): it appears standing at the edge of the
  screen, to one side, and watches. HUD: SOMETHING IS WATCHING YOU...
- Light out (`Enemies.in_the_dark`: no lantern, candle, mushroom, flare, village or sun): it
  watches for WATCH_TIME, drops to all fours and comes (APPROACH_SPEED tiles/s), along an
  AStarGrid2D path where everything is passable -- walls, cliffs, closed doors, chests, graves
  are climbed (villages are closed to it). Where the next tile is higher or lower it goes to the
  edge and climbs the face; the frame depends on the direction (the camera looks north).
  HUD: IT'S COMING. Your heartbeat speeds up as it gets within DREAD_RANGE.
- Light again: it turns and crawls back (RETREAT_SPEED, slower) until it's off the screen, then
  waits there. Dark again: it comes back from wherever it got to (or reappears at the edge if
  it's more than FORGET tiles away).
- Reaches you in the dark (REACH): a lunge, then it eats you -- it crouches over the spot and the
  run is over (THE LONGMAN TOOK YOU). If the light comes back during the lunge, it backs off.
  Two players: each has their own Longman, so both in the dark means two of them. Light
  protects whoever stands in it: your partner's lantern (main.gd `_in_partners_light`) and
  anyone's flare count the same as your own; the HUD says SAFE IN YOUR PARTNER'S LIGHT /
  SAFE IN THE LIGHT instead of IT'S COMING (Hud.shelter). It shows itself at
  the edge of that player's own half of the split screen. The one it eats is gone for good
  (their things stay on the floor); the other carries on; when nobody is left, it's over.
- A bomb going off near it sends it back for SCARE_TIME. By day it's simply not there. It
  freezes while that player is in a menu or a fight.
- 3D view: an upright Sprite3D in the world (unshaded, pale) with a faint cold light. 2D view
  (and player 2's half): drawn above the darkness on the eyes layer, lifted by its height.
- Save version 4: older saves are ignored (with the ghosts gone the creatures moved).

## Starting a fight
There's no fight button: an insect or demon touching you, or you walking into one, starts the
battle straight away (main.gd `_start_fight`; no lead-in text). Demons and insects engage the
same way. (`transition.gd` is no longer used for fights.)

## The battle screen
- `scripts/battle_fx.gd` (BattleFX): the place you're fighting in, drawn behind the fighters to match
  where the fight broke out -- a crypt colonnade (arches, pillars, sconces, flagstones in
  perspective), or outdoors a night sky with stars and a moon over a tree line (forest, river with
  its water, swamp with dead snags), peaks with snow (mountain) or broken columns (courtyard).
  Everything that floats: embers off your lantern, dust in its light, soft out-of-focus motes, the
  creature's aura (red malice off a demon, spores off an insect), the landscape's drift (fireflies,
  grit from the ceiling, snow, ash, swamp bubbles and spores), rolling fog, a vignette; and bursts
  when blows land (sparks + impact ring, ichor, a guard's shards, dodge dust, heal crosses, the flare).
- Fighters slide in from the sides as the screen fades up from black (INTRO_TIME).
- Choosing a move: ATTACK, DEFEND and DODGE are three big cards across the bottom (battle.gd DECK,
  `_big_card`): name, icon at twice size, the number that matters and what happens either way. The
  one you're on lifts, glows and gives off its move (sparks / cold motes / wind). What the creature
  gives away sits on a banner above them. The BAG is a button beneath the deck: DOWN to reach it,
  Z to open (potions, flare), UP back to the cards.

## Tools (seer stone, portal flare, ladder)
Three items that take a bag slot (kind "tool", stacking to 3), used from the bag; the better they are, the rarer (chest weights 3 / 2 / 1; shop prices 22 / 40 / 55). Icons 29-31 in `items.png` come from `tools/make_tool_items.py`.
- **Seer Stone** (`scripts/seer_trail.gd`): lays a trail of glowing green dust along the ground from where you stand to the nearest gate -- the same gate a sprite's clue would name (`Doors.clue_door`; `Doors.seer_path` walks the way there), or the master seal once no locked door is left in reach. It runs out from your feet, pulses toward the gate, motes drift up from it, a swirl hangs at the gate, faint green lights tint the floor along it; it lasts 90 seconds. In 3D it's unshaded billboards plus a soft glow lying on the ground (two MultiMeshes), so it shines in the dark and walls still hide it.
- **Portal Flare** (`Flares.portals`): plant it and it burns violet forever and maps the room like a flare. On the map (M), Z picks a portal flare (arrows go from one to the next), Z again steps you through to it from anywhere (`main._travel`), X backs out. Shared by both players; saved.
- **Ladder** (`scripts/ladders.gd`): set it against a crypt brick wall that's one tile thick with floor on the other side (not the outer wall, not the master seal). It hooks over the top, a ladder down each face, and stays. Face it and press Z: `Player.climb_over` climbs up the ladder, over the top and hops down on the far side (never walking along the wall); in 3D the sprite and its lantern rise with `climb_lift`. Works from either side; saved. Both sides must be in the same part of the labyrinth (`Doors.section_of`, via `Ladders.area_of`): a ladder never takes you past a locked door.

## Selling at the shop
In a village shop, left/right turns the list between BUY and SELL. The SELL side lists everything in your bag; Z sells one of the chosen item for `Items.sell_price` -- 70% of what the shop charges for it (`SELL_RATE`, upgrades included, at least 1 ruby). Shops won't take keys.

## Lockpicking
Picking a lock (lock_puzzle.gd) burns your lantern fast: about 3 light/s on the first doors, about 4.5 on the deepest, on top of the normal drain. The big LANTERN meter at the bottom of the screen shows it. Every miss takes a bite of 14 light, up to 20 deep, marked in red on the meter with a "-N LIGHT" popup. A silver miss drops your last set pin; a gold or purple miss drops them all. You don't need your own lantern, just light by the door: a planted flare, your partner's lantern or a candle is enough to see the pins by (`Doors.light_at` → `Enemies.is_lit`), and picking by it costs nothing. The lock only closes if every light by the door goes out, yours included. By day, in a village or under sunstone the lantern isn't burning, so there's no drain and no miss cost.
Depth (doors.gd passes the deeper side of the door's progress; the master lock is always 1.0) makes pins up to 60% faster with a 15% tighter window, and past halfway the pins speed up and slow down unevenly. The timing window runs from about 245 ms (bronze, first doors) to about 70 ms (gold, deepest).
