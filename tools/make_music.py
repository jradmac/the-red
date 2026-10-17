"""Composes and renders the game's music: assets/music/*.ogg

One theme -- "the Labyrinth's song" -- runs through every track, so the
whole game feels like one piece. Each landscape gives it its own key, mode,
tempo and instruments; by day it's brighter, fuller and moving, by night the
same landscape turns minor, slow, sparse and echoing, with a low drone under
it. Battles get a fast, driving version.

    python3 tools/make_music.py            (needs numpy, scipy, ffmpeg)

Every track is 32 bars: 4 bars of intro, the theme (A), an answering
variation (B), the theme again, more ornamented (A'), 4 bars of outro --
rendered so its echo tail wraps around to the start, so it loops seamlessly.
"""
from pathlib import Path
import subprocess
import sys
import wave

import numpy as np
from scipy import signal as sg

OUT = Path(__file__).resolve().parent.parent / "assets" / "music"
SR = 22050
rng = np.random.default_rng(3)

MODES = {
    "ionian": [0, 2, 4, 5, 7, 9, 11], "dorian": [0, 2, 3, 5, 7, 9, 10], "phrygian": [0, 1, 3, 5, 7, 8, 10],
    "lydian": [0, 2, 4, 6, 7, 9, 11], "mixolydian": [0, 2, 4, 5, 7, 9, 10], "aeolian": [0, 2, 3, 5, 7, 8, 10],
    "harmonic": [0, 2, 3, 5, 7, 8, 11],
}

# The theme: (scale degree, beats). None = rest. 8 bars of 4/4.
THEME = [(0, 1), (2, 1), (4, 1.5), (3, 0.5),
         (2, 2), (1, 1), (0, 1),
         (-1, 1), (0, 1), (2, 1), (4, 1),
         (3, 3), (None, 1),
         (4, 1), (5, 1), (4, 1), (2, 1),
         (3, 1.5), (2, 0.5), (1, 2),
         (0, 1), (-1, 1), (-3, 1), (-1, 1),
         (0, 4)]
# The answer: the theme's shape turned upside down and lifted.
ANSWER = [(4, 1.5), (5, 0.5), (4, 1), (2, 1),
          (3, 2), (4, 1), (5, 1),
          (7, 2), (6, 1), (4, 1),
          (5, 3), (None, 1),
          (4, 1), (3, 1), (2, 1), (0, 1),
          (1, 1.5), (2, 0.5), (3, 2),
          (2, 1), (1, 1), (0, 1), (-1, 1),
          (-3, 2), (None, 2)]
PROG = [0, 5, 3, 4, 0, 3, 4, 0]           # chord roots (scale degrees), one per bar
PROG_B = [3, 4, 2, 5, 3, 4, 1, 4]


# --- synthesis -------------------------------------------------------------------------
def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def adsr(n, a, d, s, r):
    a_n, d_n, r_n = max(1, int(a * SR)), max(1, int(d * SR)), max(1, int(r * SR))
    sus = max(0, n - a_n - d_n)
    e = np.concatenate([np.linspace(0, 1, a_n), np.linspace(1, s, d_n), np.full(sus, s)])[:n]
    tail = np.linspace(s if len(e) else 1, 0, r_n) * (e[-1] if len(e) else 1) / max(s, 1e-6) if s > 0 else np.zeros(r_n)
    return np.concatenate([e, tail])


def phase(f, n):
    return 2 * np.pi * np.cumsum(np.full(n, f)) / SR


def inst_pluck(f, dur, vel, bright=0.5):
    """Karplus-Strong string: harp, lute, harpsichord."""
    n = int((dur + 1.2) * SR)
    N = max(2, int(SR / f))
    burst = np.zeros(n)
    burst[:N] = rng.uniform(-1, 1, N)
    burst[:N] = sg.lfilter([bright, 1 - bright], [1], burst[:N])
    d = 0.996
    a = np.zeros(N + 2)
    a[0] = 1
    a[N] = -d * 0.5
    a[N + 1] = -d * 0.5
    y = sg.lfilter([1], a, burst)
    y *= np.minimum(1, np.linspace(3, 0, n) ** 1.0)
    return y * vel * 0.8


def inst_bell(f, dur, vel, ratio=3.5, index=2.0, decay=2.2):
    """FM bell: music box, celesta, chimes."""
    n = int((dur + 1.8) * SR)
    t = np.arange(n) / SR
    env = np.exp(-t * decay)
    mod = np.sin(2 * np.pi * f * ratio * t) * index * np.exp(-t * decay * 1.6)
    return np.sin(2 * np.pi * f * t + mod) * env * vel * 0.6


def inst_flute(f, dur, vel, breath=0.08):
    n = int((dur + 0.25) * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.25) * 3, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    tone = np.sin(ph) + 0.25 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)
    b = sg.lfilter(*sg.butter(2, [min(f * 1.5, 9000) / (SR / 2), min(f * 3.5, 10000) / (SR / 2)], "band"),
                   rng.uniform(-1, 1, n)) * breath * 3
    e = adsr(n, 0.07, 0.1, 0.8, 0.0)[:n]
    e[-int(0.2 * SR):] *= np.linspace(1, 0, int(0.2 * SR))
    return (tone + b) * e * vel * 0.5


def inst_pad(f, dur, vel, warm=1200, detune=0.006):
    n = int((dur + 1.5) * SR)
    t = np.arange(n) / SR
    x = sum(2 * ((f * (1 + d) * t) % 1) - 1 for d in (-detune, 0, detune))
    x = sg.lfilter(*sg.butter(2, warm / (SR / 2), "low"), x)
    e = adsr(n, 0.8, 0.5, 0.75, 0.0)[:n]
    e[-int(1.4 * SR):] *= np.linspace(1, 0, int(1.4 * SR))
    return x * e * vel * 0.18


def inst_organ(f, dur, vel):
    n = int((dur + 0.4) * SR)
    t = np.arange(n) / SR
    x = sum(a * np.sin(2 * np.pi * f * h * t) for h, a in ((0.5, 0.5), (1, 1), (2, 0.5), (3, 0.25), (4, 0.15)))
    e = adsr(n, 0.06, 0.1, 0.85, 0.0)[:n]
    e[-int(0.35 * SR):] *= np.linspace(1, 0, int(0.35 * SR))
    return x * e * vel * 0.22


def inst_choir(f, dur, vel):
    """Breathy 'ahh': a saw through two vowel formants."""
    n = int((dur + 1.0) * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.004 * np.sin(2 * np.pi * 4.6 * t)
    ph = np.cumsum(f * vib) / SR
    src = 2 * (ph % 1) - 1 + rng.uniform(-0.15, 0.15, n)
    x = np.zeros(n)
    for fc, bw, g in ((700, 140, 1.0), (1150, 160, 0.6), (2600, 300, 0.25)):
        x += sg.lfilter(*sg.butter(2, [(fc - bw) / (SR / 2), (fc + bw) / (SR / 2)], "band"), src) * g
    e = adsr(n, 0.5, 0.3, 0.8, 0.0)[:n]
    e[-int(0.9 * SR):] *= np.linspace(1, 0, int(0.9 * SR))
    return x * e * vel * 0.9


def inst_marimba(f, dur, vel):
    n = int((dur + 0.8) * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t) * np.exp(-t * 5) + 0.3 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t * 18)
    return x * vel * 0.6


def inst_reed(f, dur, vel):
    """Square through a soft filter: a clarinet / old chiptune lead."""
    n = int((dur + 0.15) * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.005 * np.sin(2 * np.pi * 5 * t) * np.clip((t - 0.2) * 3, 0, 1)
    ph = np.cumsum(f * vib) / SR
    x = np.where(ph % 1 < 0.5, 1.0, -1.0)
    x = sg.lfilter(*sg.butter(2, min(f * 4, 6000) / (SR / 2), "low"), x)
    e = adsr(n, 0.02, 0.1, 0.7, 0.0)[:n]
    e[-int(0.12 * SR):] *= np.linspace(1, 0, int(0.12 * SR))
    return x * e * vel * 0.3


def inst_bass(f, dur, vel):
    n = int((dur + 0.1) * SR)
    t = np.arange(n) / SR
    x = 2 * np.abs(2 * ((f * t) % 1) - 1) - 1
    e = adsr(n, 0.01, 0.15, 0.6, 0.0)[:n]
    e[-int(0.08 * SR):] *= np.linspace(1, 0, int(0.08 * SR))
    return x * e * vel * 0.5


def inst_drum(f, dur, vel):
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    fr = 120 * np.exp(-t * 18) + 45
    x = np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t * 7)
    return x * vel


def inst_shaker(f, dur, vel):
    n = int(0.12 * SR)
    x = sg.lfilter(*sg.butter(2, 5000 / (SR / 2), "high"), rng.uniform(-1, 1, n)) * np.exp(-np.arange(n) / SR * 40)
    return x * vel * 0.4


INSTRUMENTS = {"pluck": inst_pluck, "bell": inst_bell, "flute": inst_flute, "pad": inst_pad, "organ": inst_organ,
               "choir": inst_choir, "marimba": inst_marimba, "reed": inst_reed, "bass": inst_bass,
               "drum": inst_drum, "shaker": inst_shaker}


# --- composing ----------------------------------------------------------------------------------
class Song:
    def __init__(self, root, mode, bpm):
        self.root, self.scale, self.bpm = root, MODES[mode], bpm
        self.events = []   # (beat, beats, midi, instrument, velocity)

    def deg(self, d, octave=0):
        o, i = divmod(d, 7)
        return self.root + 12 * (o + octave) + self.scale[i]

    def add(self, beat, beats, midi, inst, vel):
        self.events.append((beat, beats, midi, inst, vel))

    def melody(self, line, start_bar, inst, vel, octave=0, ornament=False, sparse=False):
        b = start_bar * 4
        for k, (d, ln) in enumerate(line):
            if d is not None and not (sparse and k % 3 == 2):
                if ornament and ln >= 1 and k % 4 == 1:   # a grace note from above
                    self.add(b, 0.25, self.deg(d + 1, octave), inst, vel * 0.7)
                    self.add(b + 0.25, ln - 0.25, self.deg(d, octave), inst, vel)
                else:
                    self.add(b, ln, self.deg(d, octave), inst, vel)
            b += ln

    def chord(self, bar, root_deg, inst, vel, octave=-1, beats=4, voicing=(0, 2, 4)):
        for v in voicing:
            self.add(bar * 4, beats, self.deg(root_deg + v, octave), inst, vel)

    def arp(self, bar, root_deg, inst, vel, pattern, step=0.5, octave=0):
        b = bar * 4
        for k, v in enumerate(pattern):
            if v is not None:
                self.add(b + k * step, step * 1.5, self.deg(root_deg + v, octave), inst, vel * (1.0 if k % 2 == 0 else 0.8))

    def bassline(self, bar, root_deg, inst, vel, pattern=(0, None, 0, 4), octave=-2):
        for k, v in enumerate(pattern):
            if v is not None:
                self.add(bar * 4 + k, 0.9, self.deg(root_deg + v, octave), inst, vel)

    def render(self, bars, reverb=0.3, room=0.4):
        beat = 60.0 / self.bpm
        total = int(bars * 4 * beat * SR)
        out = np.zeros(total + int(4 * SR))
        for (b, ln, m, inst, vel) in self.events:
            x = INSTRUMENTS[inst](mtof(m), ln * beat, vel)
            s = int(b * beat * SR)
            e = min(len(out), s + len(x))
            out[s:e] += x[:e - s]
        out = space(out, reverb, room)
        # wrap the tail around: the loop seam is seamless
        loop = out[:total].copy()
        tail = out[total:]
        loop[:len(tail)] += tail[:total]
        return loop


def space(x, wet, room):
    acc = np.zeros(len(x))
    for dl, g in ((0.0297, 0.77), (0.0371, 0.75), (0.0411, 0.73), (0.0437, 0.71), (0.05, 0.7)):
        d = max(1, int(dl * SR * (0.6 + room)))
        acc += sg.lfilter([1], np.concatenate([[1], np.zeros(d - 1), [-g]]), x)
    acc = sg.lfilter(*sg.butter(2, 3000 / (SR / 2), "low"), acc)
    acc = acc / (np.max(np.abs(acc)) + 1e-9) * (np.max(np.abs(x)) + 1e-9)
    # a long pre-delayed echo for the night
    return x * (1 - wet) + acc * wet


# --- the tracks -------------------------------------------------------------------------------
def standard_form(s, lead, harm, lead_vel=0.8, harm_vel=0.5, octave=0, arp=None, arp_inst=None, bass=None,
                  drums=False, sparse=False, counter=None, drone=None):
    """Intro 4 | A 8 | B 8 | A' 8 | outro 4 = 32 bars."""
    prog = PROG[:4] + PROG + PROG_B + PROG + PROG[-4:]
    for bar, r in enumerate(prog):
        if harm:
            s.chord(bar, r, harm, harm_vel)
        if arp and arp_inst and not (sparse and bar % 2):
            s.arp(bar, r, arp_inst, 0.45, arp)
        if bass:
            s.bassline(bar, r, bass, 0.55)
        if drone:
            s.add(bar * 4, 4, s.deg(0, -2), drone, 0.35)
        if drums:
            for k in range(4):
                if k in (0, 2):
                    s.add(bar * 4 + k, 0.5, 36, "drum", 0.55 if k == 0 else 0.35)
                s.add(bar * 4 + k + 0.5, 0.2, 80, "shaker", 0.3)
    s.melody(THEME, 4, lead, lead_vel, octave, sparse=sparse)
    s.melody(ANSWER, 12, counter or lead, lead_vel * 0.9, octave, sparse=sparse)
    s.melody(THEME, 20, lead, lead_vel, octave + (0 if sparse else 0), ornament=not sparse, sparse=sparse)
    if counter and not sparse:   # the theme echoed low under A'
        s.melody(THEME, 20, counter, lead_vel * 0.45, octave - 1)


def build():
    tracks = {}
    UP = [0, 2, 4, 7, 4, 2, 0, 2]
    ROLL = [0, 4, 7, 4, 9, 4, 7, 4]
    WALTZ = [0, None, 4, 2, None, 4, 0, None]

    # The crypts: by night a lonely music box over an organ drone; by day (still
    # underground) the organ breathes and the bells sing the whole theme.
    s = Song(62, "harmonic", 58); standard_form(s, "bell", "organ", 0.7, 0.35, octave=1, sparse=True, drone="pad")
    tracks["crypt_night"] = s.render(32, 0.55, 0.9)
    s = Song(62, "dorian", 70); standard_form(s, "bell", "organ", 0.7, 0.4, octave=1, counter="flute", arp=WALTZ, arp_inst="pluck")
    tracks["crypt_day"] = s.render(32, 0.4, 0.7)

    # The forests: a flute and a lute in the green by day; at night the flute
    # alone, low, with a pad like mist between the trees.
    s = Song(67, "ionian", 96); standard_form(s, "flute", "pad", 0.75, 0.4, arp=UP, arp_inst="pluck", bass="bass", drums=True, counter="pluck")
    tracks["forest_day"] = s.render(32, 0.25, 0.4)
    s = Song(64, "aeolian", 68); standard_form(s, "flute", "pad", 0.6, 0.45, octave=-1, arp=ROLL, arp_inst="pluck", sparse=True)
    tracks["forest_night"] = s.render(32, 0.5, 0.8)

    # The courtyards: stately harpsichord and chimes by day; by night the
    # chimes alone and a choir behind the walls.
    s = Song(60, "lydian", 88); standard_form(s, "bell", "organ", 0.65, 0.3, octave=1, arp=ROLL, arp_inst="pluck", bass="bass", counter="reed")
    tracks["court_day"] = s.render(32, 0.3, 0.6)
    s = Song(60, "aeolian", 62); standard_form(s, "bell", "choir", 0.6, 0.35, octave=1, sparse=True, drone="pad")
    tracks["court_night"] = s.render(32, 0.55, 1.0)

    # The mountains: open fifths, a far horn and a drum by day; at night the
    # wind, a choir, and the horn very far away.
    s = Song(57, "mixolydian", 80); standard_form(s, "flute", "pad", 0.75, 0.45, arp=[0, 4, 7, 11, 7, 4, 0, 4], arp_inst="marimba", bass="bass", drums=True, counter="reed")
    tracks["mountain_day"] = s.render(32, 0.35, 0.8)
    s = Song(57, "aeolian", 56); standard_form(s, "reed", "choir", 0.45, 0.4, octave=-1, sparse=True, drone="pad")
    tracks["mountain_night"] = s.render(32, 0.6, 1.0)

    # The rivers: flowing marimba and flute by day; harp ripples and a pad by night.
    s = Song(65, "ionian", 100); standard_form(s, "flute", "pad", 0.75, 0.35, arp=[0, 2, 4, 7, 9, 7, 4, 2], arp_inst="marimba", bass="bass", counter="bell")
    tracks["river_day"] = s.render(32, 0.3, 0.5)
    s = Song(62, "aeolian", 72); standard_form(s, "bell", "pad", 0.55, 0.45, octave=1, arp=[0, 4, 7, 9, 7, 4, 0, None], arp_inst="pluck", sparse=True)
    tracks["river_night"] = s.render(32, 0.5, 0.8)

    # The swamps: a lazy clarinet over a plucked bass by day; by night something
    # sings out there -- a low choir, bent bells, a slow drum.
    s = Song(58, "dorian", 78); standard_form(s, "reed", "pad", 0.7, 0.35, arp=[0, None, 4, None, 7, None, 4, 2], arp_inst="pluck", bass="bass", drums=True, counter="flute")
    tracks["swamp_day"] = s.render(32, 0.35, 0.6)
    s = Song(58, "phrygian", 54); standard_form(s, "choir", "pad", 0.6, 0.4, octave=-1, sparse=True, drone="pad")
    for bar in range(0, 32, 2):
        s.add(bar * 4, 0.5, 36, "drum", 0.35)
    tracks["swamp_night"] = s.render(32, 0.6, 1.0)

    # Battle: the theme, fast and driving.
    s = Song(64, "harmonic", 138)
    prog = PROG[:4] + PROG + PROG_B + PROG + PROG[-4:]
    for bar, r in enumerate(prog):
        s.bassline(bar, r, "bass", 0.7, pattern=(0, 0, 4, 0))
        s.arp(bar, r, "pluck", 0.35, [0, 2, 4, 2, 0, 2, 4, 7])
        for k in range(4):
            s.add(bar * 4 + k, 0.5, 36, "drum", 0.6 if k % 2 == 0 else 0.4)
            s.add(bar * 4 + k + 0.5, 0.2, 80, "shaker", 0.35)
    s.melody(THEME, 4, "reed", 0.8, 1)
    s.melody(ANSWER, 12, "reed", 0.75, 1)
    s.melody(THEME, 20, "reed", 0.8, 1, ornament=True)
    s.melody(THEME, 20, "bell", 0.35, 0)
    tracks["battle"] = s.render(32, 0.15, 0.3)

    # The villages: safe at last. By day a bouncy folk dance -- fiddle-ish
    # reed, lute and a hand drum around the well; by night a music box lullaby
    # over warm strings, the lamps glowing in every window.
    s = Song(67, "ionian", 108); standard_form(s, "reed", "pad", 0.7, 0.35, arp=[0, 4, 7, 4, 2, 4, 7, 9], arp_inst="pluck", bass="bass", drums=True, counter="flute")
    tracks["village_day"] = s.render(32, 0.25, 0.4)
    s = Song(65, "ionian", 66); standard_form(s, "bell", "pad", 0.6, 0.45, octave=1, arp=[0, 4, 7, 4, 9, 7, 4, 2], arp_inst="marimba", counter="flute")
    tracks["village_night"] = s.render(32, 0.45, 0.7)

    OUT.mkdir(parents=True, exist_ok=True)
    only = set(sys.argv[1:])
    for name, x in tracks.items():
        if only and name not in only:
            continue
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
