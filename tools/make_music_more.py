"""More music: alternate takes, deep versions and more battles.

The first tracks (tools/make_music.py) are left exactly as they are. This adds,
built from the same instruments, song form and theme:

  <land>_<day|night>_b      a second take: a new verse of the theme (THEME2,
                            the same first three notes, then its own way),
                            another key and tempo, the instruments swapped
  <land>_<day|night>_deep   the same land deeper in the labyrinth: a lower key,
                            a darker mode, slower, a falling melody (THEME3),
                            a drone, a bell tolling every few bars, the odd
                            clash of a semitone in the pad
  village_<day|night>_b     a second take for the villages (no deep version:
                            the villages stay safe)
  battle_b, battle_c        two more fights; battle_deep for the deep ones

    python3 tools/make_music_more.py [names...]     (needs numpy, scipy, ffmpeg)

The game picks among them (scripts/music_pick.gd).
"""
from pathlib import Path
import subprocess
import sys
import wave

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_music as mm  # noqa: E402

OUT = mm.OUT
SR = mm.SR

# A second verse: the theme's first three notes, then its own way up and home.
THEME2 = [(0, 1), (2, 1), (4, 2),
          (5, 1), (4, 1), (2, 1), (1, 1),
          (2, 1.5), (1, 0.5), (0, 2),
          (-1, 2), (None, 2),
          (4, 1), (4, 0.5), (5, 0.5), (7, 2),
          (6, 1), (4, 1), (5, 1), (3, 1),
          (2, 1), (1, 1), (0, 1), (1, 1),
          (0, 3), (None, 1)]
ANSWER2 = [(7, 2), (6, 1), (5, 1),
           (4, 1.5), (3, 0.5), (2, 2),
           (3, 1), (4, 1), (5, 1), (3, 1),
           (2, 3), (None, 1),
           (0, 1), (1, 1), (2, 1), (4, 1),
           (3, 2), (2, 1), (1, 1),
           (-1, 1), (0, 1), (1, 1), (-1, 1),
           (0, 2), (None, 2)]
PROG2 = [0, 3, 5, 4, 0, 5, 3, 4]
PROG2B = [5, 3, 0, 4, 5, 3, 4, 4]

# Deep: the theme sinking -- long notes, falling, leaning on the lowered second.
THEME3 = [(0, 2), (1, 1), (0, 1),
          (-1, 3), (None, 1),
          (0, 1), (2, 1), (1, 2),
          (0, 3), (None, 1),
          (4, 2), (3, 1), (1, 1),
          (2, 2), (0, 2),
          (1, 1), (0, 1), (-1, 1), (-2, 1),
          (0, 4)]
ANSWER3 = [(-3, 2), (-2, 1), (-1, 1),
           (0, 3), (None, 1),
           (1, 2), (0, 1), (-1, 1),
           (-2, 3), (None, 1),
           (2, 2), (1, 2),
           (0, 1), (-1, 1), (1, 2),
           (0, 2), (-1, 2),
           (0, 4)]
PROG3 = [0, 1, 0, 4, 0, 5, 1, 0]
PROG3B = [5, 1, 0, 4, 3, 1, 4, 0]

# The first tracks' recipes (as in make_music.py): root, mode, bpm, form, render.
BASE = {
    "crypt_night": (62, "harmonic", 58, dict(lead="bell", harm="organ", lead_vel=0.7, harm_vel=0.35, octave=1, sparse=True, drone="pad"), (0.55, 0.9)),
    "crypt_day": (62, "dorian", 70, dict(lead="bell", harm="organ", lead_vel=0.7, harm_vel=0.4, octave=1, counter="flute", arp=[0, None, 4, 2, None, 4, 0, None], arp_inst="pluck"), (0.4, 0.7)),
    "forest_day": (67, "ionian", 96, dict(lead="flute", harm="pad", lead_vel=0.75, harm_vel=0.4, arp=[0, 2, 4, 7, 4, 2, 0, 2], arp_inst="pluck", bass="bass", drums=True, counter="pluck"), (0.25, 0.4)),
    "forest_night": (64, "aeolian", 68, dict(lead="flute", harm="pad", lead_vel=0.6, harm_vel=0.45, octave=-1, arp=[0, 4, 7, 4, 9, 4, 7, 4], arp_inst="pluck", sparse=True), (0.5, 0.8)),
    "court_day": (60, "lydian", 88, dict(lead="bell", harm="organ", lead_vel=0.65, harm_vel=0.3, octave=1, arp=[0, 4, 7, 4, 9, 4, 7, 4], arp_inst="pluck", bass="bass", counter="reed"), (0.3, 0.6)),
    "court_night": (60, "aeolian", 62, dict(lead="bell", harm="choir", lead_vel=0.6, harm_vel=0.35, octave=1, sparse=True, drone="pad"), (0.55, 1.0)),
    "mountain_day": (57, "mixolydian", 80, dict(lead="flute", harm="pad", lead_vel=0.75, harm_vel=0.45, arp=[0, 4, 7, 11, 7, 4, 0, 4], arp_inst="marimba", bass="bass", drums=True, counter="reed"), (0.35, 0.8)),
    "mountain_night": (57, "aeolian", 56, dict(lead="reed", harm="choir", lead_vel=0.45, harm_vel=0.4, octave=-1, sparse=True, drone="pad"), (0.6, 1.0)),
    "river_day": (65, "ionian", 100, dict(lead="flute", harm="pad", lead_vel=0.75, harm_vel=0.35, arp=[0, 2, 4, 7, 9, 7, 4, 2], arp_inst="marimba", bass="bass", counter="bell"), (0.3, 0.5)),
    "river_night": (62, "aeolian", 72, dict(lead="bell", harm="pad", lead_vel=0.55, harm_vel=0.45, octave=1, arp=[0, 4, 7, 9, 7, 4, 0, None], arp_inst="pluck", sparse=True), (0.5, 0.8)),
    "swamp_day": (58, "dorian", 78, dict(lead="reed", harm="pad", lead_vel=0.7, harm_vel=0.35, arp=[0, None, 4, None, 7, None, 4, 2], arp_inst="pluck", bass="bass", drums=True, counter="flute"), (0.35, 0.6)),
    "swamp_night": (58, "phrygian", 54, dict(lead="choir", harm="pad", lead_vel=0.6, harm_vel=0.4, octave=-1, sparse=True, drone="pad"), (0.6, 1.0)),
    "village_day": (67, "ionian", 108, dict(lead="reed", harm="pad", lead_vel=0.7, harm_vel=0.35, arp=[0, 4, 7, 4, 2, 4, 7, 9], arp_inst="pluck", bass="bass", drums=True, counter="flute"), (0.25, 0.4)),
    "village_night": (65, "ionian", 66, dict(lead="bell", harm="pad", lead_vel=0.6, harm_vel=0.45, octave=1, arp=[0, 4, 7, 4, 9, 7, 4, 2], arp_inst="marimba", counter="flute"), (0.45, 0.7)),
}

# The rare lands' own music (no extra takes: they're rare enough).
RARE = {
    # the shore: a breezy lydian flute over marimba; at night bells and the sea's swell
    "beach_day": (64, "lydian", 84, dict(lead="flute", harm="pad", lead_vel=0.7, harm_vel=0.4, arp=[0, 4, 7, 9, 7, 4, 2, 4], arp_inst="marimba", bass="bass", counter="bell"), (0.35, 0.7)),
    "beach_night": (61, "aeolian", 62, dict(lead="bell", harm="pad", lead_vel=0.6, harm_vel=0.45, octave=1, arp=[0, 4, 7, 4, None, 4, 7, None], arp_inst="pluck", sparse=True, drone="pad"), (0.6, 1.0)),
    # the jungle: reed and marimba over hand drums; by night something calls in the canopy
    "jungle_day": (62, "dorian", 104, dict(lead="reed", harm="pad", lead_vel=0.7, harm_vel=0.35, arp=[0, 2, 4, 7, 4, 2, 0, 4], arp_inst="marimba", bass="bass", drums=True, counter="flute"), (0.3, 0.6)),
    "jungle_night": (59, "phrygian", 70, dict(lead="marimba", harm="choir", lead_vel=0.6, harm_vel=0.4, arp=[0, None, 1, None, 4, None, 1, None], arp_inst="pluck", drums=True, sparse=True, drone="pad"), (0.5, 0.9)),
    # the snow: glassy bells, a lot of air; at night the choir and the wind
    "snow_day": (69, "lydian", 72, dict(lead="bell", harm="pad", lead_vel=0.65, harm_vel=0.45, octave=1, arp=[0, 4, 7, 11, 7, 4, None, None], arp_inst="pluck", counter="flute"), (0.55, 1.0)),
    "snow_night": (64, "aeolian", 54, dict(lead="bell", harm="choir", lead_vel=0.55, harm_vel=0.4, octave=1, sparse=True, drone="pad"), (0.7, 1.1)),
    # the volcano: organ and choir over heavy drums, all in the phrygian
    "volcano_day": (52, "phrygian", 92, dict(lead="organ", harm="choir", lead_vel=0.7, harm_vel=0.45, arp=[0, 1, 4, 1, 0, 1, 7, 1], arp_inst="pluck", bass="bass", drums=True, counter="reed"), (0.35, 0.7)),
    "volcano_night": (50, "harmonic", 70, dict(lead="choir", harm="organ", lead_vel=0.6, harm_vel=0.45, sparse=True, drums=True, drone="pad"), (0.55, 0.9)),
    # the gold vault: wonder -- glittering bells and marimba, a choir in the vault's echo
    "gold_day": (67, "lydian", 76, dict(lead="bell", harm="choir", lead_vel=0.65, harm_vel=0.35, octave=1, arp=[0, 4, 7, 11, 14, 11, 7, 4], arp_inst="marimba", counter="flute"), (0.55, 1.0)),
    "gold_night": (66, "lydian", 66, dict(lead="bell", harm="pad", lead_vel=0.6, harm_vel=0.4, octave=1, arp=[0, 4, 7, 11, 14, 11, 7, 4], arp_inst="marimba", counter="flute", drone="pad"), (0.6, 1.0)),
}


def rare(name):
    root, mode, bpm, form, (rev, room) = RARE[name]
    s = mm.Song(root, mode, bpm)
    mm.standard_form(s, **form)
    return s.render(32, rev, room)


SWAP = {"flute": "reed", "reed": "flute", "bell": "pluck", "pluck": "bell", "choir": "organ", "organ": "choir",
        "marimba": "bell", "pad": "pad"}
DARKER = {"ionian": "aeolian", "lydian": "dorian", "mixolydian": "dorian", "dorian": "phrygian",
          "aeolian": "phrygian", "harmonic": "phrygian", "phrygian": "phrygian"}
DEEP_LEAD = {"flute": "reed", "reed": "choir", "bell": "bell", "choir": "choir", "pluck": "bell", "marimba": "bell"}


def _with(theme, answer, prog, prog_b, fn):
    keep = mm.THEME, mm.ANSWER, mm.PROG, mm.PROG_B
    mm.THEME, mm.ANSWER, mm.PROG, mm.PROG_B = theme, answer, prog, prog_b
    try:
        return fn()
    finally:
        mm.THEME, mm.ANSWER, mm.PROG, mm.PROG_B = keep


def take_b(name):
    root, mode, bpm, form, (rev, room) = BASE[name]
    night = name.endswith("night")
    f = dict(form)
    # another key and pace; the voices trade places
    root = root - 2 if night else (root + 5 if root + 5 <= 68 else root - 7)
    bpm = bpm * (0.94 if night else 1.07)
    if f.get("counter"):
        f["lead"], f["counter"] = f["counter"], f["lead"]
        if f["lead"] == "pluck":
            f["lead"] = "bell"
    else:
        f["lead"] = SWAP.get(f["lead"], f["lead"])
    if f.get("arp"):
        a = f["arp"]
        f["arp"] = a[4:] + a[:4]
    s = mm.Song(root, mode, bpm)
    _with(THEME2, ANSWER2, PROG2, PROG2B, lambda: mm.standard_form(s, **f))
    return s.render(32, rev, room)


def deep(name):
    root, mode, bpm, form, (rev, room) = BASE[name]
    night = name.endswith("night")
    f = dict(form)
    root -= 3
    mode = DARKER[mode]
    bpm *= 0.82
    f["lead"] = DEEP_LEAD.get(f["lead"], f["lead"])
    f["harm"] = "organ" if night else "choir"
    f["drone"] = "pad"
    f["sparse"] = True if night else f.get("sparse", False)
    f["drums"] = False
    f["lead_vel"] = f.get("lead_vel", 0.7) * 0.9
    if f.get("counter"):
        f["counter"] = DEEP_LEAD.get(f["counter"], f["counter"])
    s = mm.Song(root, mode, bpm)
    _with(THEME3, ANSWER3, PROG3, PROG3B, lambda: mm.standard_form(s, **f))
    # a bell tolling, low, every four bars; a slow drum like a heart by day
    for bar in range(0, 32, 4):
        s.add(bar * 4, 4, s.deg(0, -1), "bell", 0.35)
    if not night:
        for bar in range(0, 32, 2):
            s.add(bar * 4, 0.5, 36, "drum", 0.4)
            s.add(bar * 4 + 0.6, 0.5, 36, "drum", 0.25)
    # the odd clash: a semitone rubbing against the root, held in the pad
    for bar in (11, 19, 27):
        s.add(bar * 4, 4, s.deg(0, -1) + 1, "pad", 0.3)
    return s.render(32, min(rev + 0.15, 0.75), min(room + 0.2, 1.1))


def battle(root, mode, bpm, theme, answer, prog_a, prog_b, lead, counter, arp_inst, arp_pat, bass_pat, heavy):
    s = mm.Song(root, mode, bpm)
    prog = prog_a[:4] + prog_a + prog_b + prog_a + prog_a[-4:]
    for bar, r in enumerate(prog):
        s.bassline(bar, r, "bass", 0.7, pattern=bass_pat)
        s.arp(bar, r, arp_inst, 0.35, arp_pat)
        for k in range(4):
            if heavy:   # half-time: kick on 1, a crash of drum on 3, shaker running
                if k == 0:
                    s.add(bar * 4, 0.5, 36, "drum", 0.75)
                    s.add(bar * 4 + 0.75, 0.5, 36, "drum", 0.45)
                if k == 2:
                    s.add(bar * 4 + 2, 0.5, 40, "drum", 0.6)
            else:
                s.add(bar * 4 + k, 0.5, 36, "drum", 0.6 if k % 2 == 0 else 0.4)
            s.add(bar * 4 + k + 0.5, 0.2, 80, "shaker", 0.35)
    s.melody(theme, 4, lead, 0.8, 1)
    s.melody(answer, 12, counter, 0.75, 1)
    s.melody(theme, 20, lead, 0.8, 1, ornament=True)
    s.melody(theme, 20, counter, 0.35, 0)
    return s.render(32, 0.15, 0.3)


def build():
    tracks = {}
    for name in BASE:
        tracks[name + "_b"] = lambda n=name: take_b(n)
        if not name.startswith("village"):
            tracks[name + "_deep"] = lambda n=name: deep(n)
    for name in RARE:
        tracks[name] = lambda n=name: rare(n)
    tracks["battle_b"] = lambda: battle(62, "dorian", 146, THEME2, ANSWER2, PROG2, PROG2B, "flute", "reed",
                                        "marimba", [0, 4, 7, 4, 0, 4, 7, 9], (0, 4, 0, 7), False)
    tracks["battle_c"] = lambda: battle(59, "phrygian", 132, mm.THEME, mm.ANSWER, mm.PROG, mm.PROG_B, "organ", "reed",
                                        "pluck", [0, 1, 4, 1, 0, 1, 4, 7], (0, 0, 1, 0), True)
    tracks["battle_deep"] = lambda: battle(57, "harmonic", 118, THEME3, ANSWER3, PROG3, PROG3B, "organ", "choir",
                                           "bell", [0, 2, 4, 2, 0, 1, 0, -1], (0, 0, 0, 1), True)
    only = set(sys.argv[1:])
    OUT.mkdir(parents=True, exist_ok=True)
    for name, make in tracks.items():
        if only and name not in only:
            continue
        x = make()
        x = x / (np.max(np.abs(x)) + 1e-9) * 0.7
        x[:200] *= np.linspace(0, 1, 200)
        tmp = OUT / f"{name}.wav"
        with wave.open(str(tmp), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(tmp), "-c:a", "libvorbis", "-q:a", "3",
                        str(OUT / f"{name}.ogg")], check=True)
        tmp.unlink()
        print(f"{name}: {len(x) / SR:.0f}s")


if __name__ == "__main__":
    build()
