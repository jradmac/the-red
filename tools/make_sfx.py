"""Builds every sound in the game: assets/sfx/*.wav (22 kHz mono).

All synthesized from scratch -- oscillators, filtered noise, envelopes and
pitch sweeps -- in a dark, retro style to match the pixel art. Tweak a
recipe and re-run:  python3 tools/make_sfx.py
"""
from pathlib import Path
import wave

import numpy as np
from scipy import signal as sg

OUT = Path(__file__).resolve().parent.parent / "assets" / "sfx"
SR = 22050
rng = np.random.default_rng(7)


# --- building blocks ------------------------------------------------------------
def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def env(n, a=0.005, d=0.1, s=0.0, r=0.05, hold=0.0):
    """Attack / decay / sustain / release, sized to n samples."""
    a_n, d_n, h_n, r_n = int(a * SR), int(d * SR), int(hold * SR), int(r * SR)
    e = np.concatenate([np.linspace(0, 1, max(a_n, 1)), np.linspace(1, s, max(d_n, 1)),
                        np.full(max(h_n, 0), s), np.linspace(s, 0, max(r_n, 1))])
    if len(e) < n:
        e = np.concatenate([e, np.zeros(n - len(e))])
    return e[:n]


def exp_env(n, k):
    return np.exp(-np.arange(n) / SR * k)


def osc(freq, dur, wave="sine", duty=0.5):
    """freq may be a number or an array (a sweep)."""
    n = int(dur * SR)
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,)) if np.ndim(freq) == 0 else np.asarray(freq)[:n]
    ph = np.cumsum(f) / SR
    ph = ph - np.floor(ph)
    if wave == "sine":
        return np.sin(2 * np.pi * ph)
    if wave == "square":
        return np.where(ph < duty, 1.0, -1.0)
    if wave == "tri":
        return 4 * np.abs(ph - 0.5) - 1
    if wave == "saw":
        return 2 * ph - 1
    raise ValueError(wave)


def sweep(f0, f1, dur, curve=1.0):
    k = np.linspace(0, 1, int(dur * SR)) ** curve
    return f0 * (f1 / f0) ** k


def noise(dur):
    return rng.uniform(-1, 1, int(dur * SR))


def brown(dur):
    b = np.cumsum(rng.uniform(-1, 1, int(dur * SR)))
    b = sg.lfilter([1, -1], [1, -0.995], b)
    return b / (np.max(np.abs(b)) + 1e-9)


def bp(x, lo, hi, order=2):
    b, a = sg.butter(order, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], "band")
    return sg.lfilter(b, a, x)


def lp(x, f, order=2):
    b, a = sg.butter(order, min(f / (SR / 2), 0.99), "low")
    return sg.lfilter(b, a, x)


def hp(x, f, order=2):
    b, a = sg.butter(order, f / (SR / 2), "high")
    return sg.lfilter(b, a, x)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(x, sec, total=None):
    pad = np.zeros(int(sec * SR))
    y = np.concatenate([pad, x])
    if total:
        y = np.concatenate([y, np.zeros(max(0, int(total * SR) - len(y)))])[:int(total * SR)]
    return y


def crush(x, bits=6):
    q = 2 ** (bits - 1)
    return np.round(x * q) / q


def echo(x, delay=0.12, fb=0.35, taps=4):
    out = np.concatenate([x, np.zeros(int(delay * SR * taps))])
    for k in range(1, taps + 1):
        d = int(delay * SR * k)
        out[d:d + len(x)] += x * (fb ** k)
    return out


def reverb(x, size=0.3, wet=0.3):
    """A cheap dark room: a few comb filters."""
    out = np.concatenate([x, np.zeros(int(size * SR * 4))])
    acc = np.zeros_like(out)
    for dl, g in ((0.0297, 0.7), (0.0371, 0.68), (0.0411, 0.66), (0.0437, 0.64)):
        d = int(dl * SR * (size / 0.3))
        y = out.copy()
        for i in range(d, len(y)):
            y[i] += g * y[i - d]
        acc += y
    acc = lp(acc, 3500)
    return out * (1 - wet) + acc / (np.max(np.abs(acc)) + 1e-9) * np.max(np.abs(x)) * wet


def fast_reverb(x, size=0.3, wet=0.3):
    out = np.concatenate([x, np.zeros(int(size * SR * 4))])
    acc = np.zeros_like(out)
    for dl, g in ((0.0297, 0.7), (0.0371, 0.68), (0.0411, 0.66), (0.0437, 0.64)):
        d = max(1, int(dl * SR * (size / 0.3)))
        acc += sg.lfilter([1], np.concatenate([[1], np.zeros(d - 1), [-g]]), out)
    acc = lp(acc, 3500)
    peak = np.max(np.abs(acc)) + 1e-9
    return out * (1 - wet) + acc / peak * np.max(np.abs(x)) * wet


def norm(x, peak=0.85):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def fade(x, fin=0.002, fout=0.01):
    n = len(x)
    a, b = int(fin * SR), int(fout * SR)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def save(name, x, peak=0.85):
    x = fade(norm(np.asarray(x, dtype=float), peak))
    OUT.mkdir(parents=True, exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def note(f, dur, wave="square", a=0.003, d=0.08, s=0.3, r=0.05, duty=0.5):
    n = int(dur * SR)
    return osc(f, dur, wave, duty) * env(n, a, d, s, r, hold=max(0, dur - a - d - r))


def loopable(x, xfade=0.4):
    """Crossfade the tail into the head so it loops without a click."""
    n = int(xfade * SR)
    head, tail = x[:n], x[-n:]
    k = np.linspace(0, 1, n)
    body = x[n:-n] if len(x) > 2 * n else x[n:]
    return np.concatenate([tail * (1 - k) + head * k, body])


# --- the sounds -------------------------------------------------------------------
def build():
    # ---- footsteps --------------------------------------------------------------
    for i in range(3):   # stone: a short gritty tap
        d = 0.09
        n = int(d * SR)
        x = bp(noise(d), 300 + i * 90, 2200) * exp_env(n, 55) + osc(110 + i * 15, d, "sine") * exp_env(n, 70) * 0.5
        save(f"step_stone{i}", x, 0.5)
    for i in range(3):   # grass: a soft brush
        d = 0.12
        n = int(d * SR)
        x = hp(noise(d), 1800) * env(n, 0.01, 0.05, 0.2, 0.05) * 0.6 + lp(noise(d), 400) * exp_env(n, 40) * 0.5
        save(f"step_grass{i}", x, 0.4)
    for i in range(2):   # mud: a wet squelch
        d = 0.16
        n = int(d * SR)
        f = sweep(240 + i * 30, 90, d, 0.6)
        x = lp(osc(f, d, "sine") * env(n, 0.005, 0.06, 0.2, 0.08), 900) + lp(noise(d), 700) * exp_env(n, 30) * 0.5
        save(f"step_mud{i}", x, 0.45)

    # ---- light ------------------------------------------------------------------
    d = 0.55
    scratch = bp(noise(0.12), 2500, 7000) * env(int(0.12 * SR), 0.002, 0.03, 0.4, 0.06)
    ignite = lp(noise(0.45), 1800) * env(int(0.45 * SR), 0.01, 0.1, 0.35, 0.3)
    hiss = hp(noise(0.4), 4000) * env(int(0.4 * SR), 0.02, 0.1, 0.2, 0.25) * 0.3
    save("match_strike", mix(scratch, at(ignite, 0.08), at(hiss, 0.1)), 0.7)
    d = 0.5
    save("lantern_out", lp(noise(d), sweep(2500, 200, d)[0]) * env(int(d * SR), 0.005, 0.15, 0.2, 0.3)
         + osc(sweep(300, 90, d), d, "sine") * exp_env(int(d * SR), 9) * 0.3, 0.6)
    d = 1.6   # the wind picks up: a rising, howling whoosh
    w = bp(noise(d), 300, 1400) * env(int(d * SR), 0.6, 0.6, 0.6, 0.4)
    howl = osc(sweep(220, 520, d, 0.7), d, "sine") * env(int(d * SR), 0.8, 0.5, 0.3, 0.3) * 0.15
    save("gust_warn", mix(w, howl), 0.6)
    d = 0.9
    save("gust", bp(noise(d), 200, 3000) * env(int(d * SR), 0.03, 0.2, 0.5, 0.6), 0.8)

    # ---- items, chests, doors ---------------------------------------------------------
    save("pickup", mix(note(880, 0.07, "square", d=0.04, duty=0.25), at(note(1318, 0.12, "square", d=0.08, duty=0.25), 0.06)) * 0.6, 0.5)
    save("pickup_match", note(1567, 0.06, "tri", d=0.05), 0.35)
    save("key", fast_reverb(mix(note(1046, 0.25, "tri", d=0.2), at(note(1568, 0.3, "tri", d=0.25), 0.07),
                                 at(note(2093, 0.4, "sine", d=0.35), 0.14)), 0.3, 0.35), 0.6)
    d = 0.5   # wooden creak, then a shimmer of light
    creak = bp(osc(sweep(90, 140, d), d, "saw"), 200, 1600) * env(int(d * SR), 0.03, 0.2, 0.4, 0.2)
    shimmer = mix(*[at(note(f, 0.5, "sine", d=0.45), i * 0.05) for i, f in enumerate([1046, 1318, 1568, 2093])]) * 0.35
    save("chest_open", mix(creak, at(fast_reverb(shimmer, 0.4, 0.4), 0.3)), 0.7)
    d = 0.6   # iron: a heavy clunk, the lock turning, a groaning hinge
    clunk = mix(lp(noise(0.08), 900) * exp_env(int(0.08 * SR), 30), osc(70, 0.2, "sine") * exp_env(int(0.2 * SR), 18))
    turn = bp(noise(0.06), 1500, 5000) * exp_env(int(0.06 * SR), 50)
    hinge = bp(osc(sweep(60, 95, 0.6), 0.6, "saw"), 150, 1200) * env(int(0.6 * SR), 0.05, 0.3, 0.4, 0.2) * 0.6
    save("door_open", fast_reverb(mix(clunk, at(turn, 0.12), at(turn, 0.2), at(hinge, 0.28)), 0.45, 0.3), 0.8)
    save("door_locked", mix(*[at(bp(noise(0.05), 800, 4000) * exp_env(int(0.05 * SR), 60), k * 0.07) for k in range(3)]), 0.5)
    save("flare", mix(bp(noise(0.7), 1500, 6000) * env(int(0.7 * SR), 0.01, 0.1, 0.5, 0.4),
                      osc(sweep(300, 900, 0.3), 0.3, "sine") * exp_env(int(0.3 * SR), 8) * 0.3), 0.6)
    save("drink", mix(*[at(lp(osc(sweep(300 + k * 40, 600, 0.06), 0.06, "sine"), 1500) * exp_env(int(0.06 * SR), 40), k * 0.09)
                        for k in range(4)]), 0.5)
    heal = mix(*[at(note(f, 0.25, "tri", d=0.2), i * 0.06) for i, f in enumerate([523, 659, 784, 1046])])
    save("heal", fast_reverb(heal, 0.3, 0.3), 0.55)
    save("berry_pick", mix(hp(noise(0.15), 2000) * env(int(0.15 * SR), 0.01, 0.06, 0.3, 0.06) * 0.6,
                           at(note(988, 0.06, "sine", d=0.05), 0.08), at(note(1318, 0.08, "sine", d=0.06), 0.13)), 0.5)
    save("eat", mix(*[at(bp(noise(0.05), 500, 3000) * exp_env(int(0.05 * SR), 45), k * 0.11) for k in range(3)]), 0.5)
    d = 1.0   # blue flame: a cold magical whoosh
    save("blue_flame", fast_reverb(mix(bp(noise(d), 600, 3000) * env(int(d * SR), 0.05, 0.3, 0.3, 0.5) * 0.5,
                                      osc(sweep(400, 1200, d, 0.5), d, "sine") * env(int(d * SR), 0.05, 0.4, 0.3, 0.4) * 0.4,
                                      osc(sweep(600, 1800, d, 0.5), d, "sine") * env(int(d * SR), 0.1, 0.4, 0.2, 0.4) * 0.2),
                                  0.4, 0.4), 0.6)
    d = 2.2   # sunstone: a bright chord swelling up like sunrise
    chord = mix(*[osc(f, d, "sine") * env(int(d * SR), 0.6, 0.6, 0.6, 0.8) for f in (392, 494, 587, 784, 988)])
    sparkle = mix(*[at(note(f, 0.3, "sine", d=0.25), 0.3 + i * 0.12) for i, f in enumerate([1568, 1976, 2349, 3136])]) * 0.3
    save("sunstone", fast_reverb(mix(chord * 0.5, sparkle), 0.5, 0.4), 0.65)

    # ---- bombs -------------------------------------------------------------------
    save("bomb_plant", mix(lp(noise(0.08), 700) * exp_env(int(0.08 * SR), 35), osc(90, 0.1, "sine") * exp_env(int(0.1 * SR), 30)), 0.6)
    d = 1.0   # fuse: a crackling sizzle (looped while a bomb is planted)
    fz = hp(noise(d), 3000) * (0.5 + 0.5 * (rng.uniform(0, 1, int(d * SR)) > 0.97))
    save("fuse", loopable(fz * 0.6 + bp(noise(d), 1500, 5000) * 0.3, 0.1), 0.35)
    d = 2.4   # the explosion: a sharp crack, a deep body, a rolling rumble, falling debris
    crack = hp(noise(0.05), 800) * exp_env(int(0.05 * SR), 60)
    body = lp(noise(d), 600) * exp_env(int(d * SR), 2.6)
    thump = osc(sweep(120, 30, 0.8, 0.5), 0.8, "sine") * exp_env(int(0.8 * SR), 4)
    rumble = lp(brown(d), 180) * env(int(d * SR), 0.05, 0.5, 0.5, 1.6)
    debris = mix(*[at(bp(noise(0.04), 1000, 4000) * exp_env(int(0.04 * SR), 70) * rng.uniform(0.2, 0.6),
                      0.4 + rng.uniform(0, 1.2)) for _ in range(14)])
    save("explosion", crush(mix(crack * 0.8, body, thump * 1.2, rumble * 0.9, debris * 0.5), 8), 0.95)

    # ---- creatures ------------------------------------------------------------------
    d = 0.5   # insect skitter: a burst of tiny clicks
    clicks = np.zeros(int(d * SR))
    for k in range(18):
        p = int(rng.uniform(0, d - 0.02) * SR)
        c = bp(noise(0.012), 2500, 7000) * exp_env(int(0.012 * SR), 300)
        clicks[p:p + len(c)] += c * rng.uniform(0.4, 1)
    save("insect", clicks, 0.5)
    d = 0.9   # demon: a low wet growl
    f = 70 + 15 * np.sin(np.linspace(0, 18, int(d * SR)))
    g = osc(f, d, "saw") * (0.6 + 0.4 * np.abs(np.sin(np.linspace(0, 30, int(d * SR)))))
    save("demon", lp(g, 700) * env(int(d * SR), 0.05, 0.3, 0.6, 0.4) + lp(noise(d), 500) * 0.2 * env(int(d * SR), 0.05, 0.3, 0.5, 0.4), 0.7)
    d = 1.2   # a ghost takes shape: an airy rising moan
    moan = osc(sweep(330, 520, d, 0.6) * (1 + 0.02 * np.sin(np.linspace(0, 40, int(d * SR)))), d, "sine")
    save("ghost_appear", fast_reverb(mix(moan * env(int(d * SR), 0.3, 0.4, 0.5, 0.4) * 0.6,
                                         bp(noise(d), 800, 2500) * env(int(d * SR), 0.4, 0.3, 0.4, 0.4) * 0.3), 0.6, 0.45), 0.55)
    d = 0.45  # it strikes: a shriek
    shriek = osc(sweep(1400, 500, d, 0.7), d, "saw") * env(int(d * SR), 0.005, 0.1, 0.5, 0.25)
    save("ghost_strike", fast_reverb(mix(bp(shriek, 600, 4000), hp(noise(d), 2000) * exp_env(int(d * SR), 8) * 0.4), 0.4, 0.35), 0.7)
    d = 0.5
    save("ghost_scatter", fast_reverb(osc(sweep(700, 200, d), d, "sine") * env(int(d * SR), 0.01, 0.2, 0.3, 0.2), 0.4, 0.4), 0.45)

    # ---- battle ----------------------------------------------------------------------
    d = 0.9   # the screen flashes: an alarm sting
    sting = mix(note(220, 0.12, "square", d=0.1, duty=0.25), at(note(233, 0.12, "square", d=0.1, duty=0.25), 0.14),
                at(note(220, 0.5, "square", d=0.45, s=0.2, duty=0.25), 0.28))
    save("encounter", crush(mix(sting, at(lp(noise(0.5), 300) * exp_env(int(0.5 * SR), 4), 0.28) * 0.6), 6), 0.7)
    save("ui_move", note(660, 0.04, "square", d=0.03, duty=0.25), 0.3)
    save("ui_select", mix(note(660, 0.05, "square", d=0.04, duty=0.25), at(note(990, 0.08, "square", d=0.06, duty=0.25), 0.045)), 0.38)
    save("ui_back", mix(note(523, 0.05, "square", d=0.04, duty=0.25), at(note(392, 0.08, "square", d=0.06, duty=0.25), 0.045)), 0.35)
    save("ui_deny", mix(note(150, 0.08, "square", d=0.07), at(note(140, 0.12, "square", d=0.1), 0.09)), 0.4)
    save("swing", bp(noise(0.22), sweep(800, 3000, 0.22)[0], 6000) * env(int(0.22 * SR), 0.03, 0.08, 0.3, 0.1), 0.55)
    d = 0.3
    save("hit", mix(lp(noise(d), 1200) * exp_env(int(d * SR), 22), osc(sweep(160, 50, d), d, "sine") * exp_env(int(d * SR), 14),
                    bp(noise(0.03), 2000, 6000) * exp_env(int(0.03 * SR), 90) * 0.5), 0.8)
    save("hurt", crush(mix(lp(noise(0.35), 900) * exp_env(int(0.35 * SR), 15),
                           osc(sweep(220, 70, 0.35), 0.35, "square", 0.3) * exp_env(int(0.35 * SR), 10) * 0.5), 7), 0.75)
    d = 0.6   # block: a metallic clang
    clang = mix(*[osc(f, d, "sine") * exp_env(int(d * SR), k) for f, k in ((520, 8), (1340, 12), (2170, 18), (3080, 26))])
    save("block", mix(clang, bp(noise(0.03), 2000, 8000) * exp_env(int(0.03 * SR), 80)), 0.6)
    save("dodge", bp(noise(0.25), 1200, 5000) * env(int(0.25 * SR), 0.06, 0.1, 0.2, 0.1)
         + osc(sweep(600, 1200, 0.25), 0.25, "sine") * env(int(0.25 * SR), 0.05, 0.1, 0.1, 0.1) * 0.15, 0.45)
    save("miss", mix(note(330, 0.08, "tri", d=0.07), at(note(247, 0.14, "tri", d=0.12), 0.08)), 0.4)
    d = 1.1   # a creature dissolves: a falling, bubbling hiss
    bub = np.zeros(int(d * SR))
    for k in range(16):
        p = int(rng.uniform(0, d - 0.08) * SR)
        b = osc(sweep(rng.uniform(300, 900), rng.uniform(150, 300), 0.06), 0.06, "sine") * exp_env(int(0.06 * SR), 40)
        bub[p:p + len(b)] += b * 0.4
    save("dissolve", fast_reverb(mix(osc(sweep(500, 80, d, 0.6), d, "saw") * env(int(d * SR), 0.01, 0.3, 0.3, 0.5) * 0.3,
                                     bp(noise(d), 400, 2500) * env(int(d * SR), 0.05, 0.4, 0.3, 0.5) * 0.5, bub), 0.4, 0.3), 0.65)
    save("flare_up", mix(bp(noise(0.5), 800, 6000) * env(int(0.5 * SR), 0.005, 0.1, 0.4, 0.3),
                         osc(sweep(200, 1200, 0.3), 0.3, "saw") * exp_env(int(0.3 * SR), 9) * 0.25), 0.7)
    win = mix(*[at(note(f, 0.18 if i < 3 else 0.6, "square", d=0.12, s=0.35, duty=0.25), i * 0.12)
                for i, f in enumerate([392, 523, 659, 784])])
    save("win", fast_reverb(win, 0.3, 0.25), 0.5)
    d = 2.6   # you fall: a slow, sinking toll
    toll = mix(*[osc(f, d, "sine") * exp_env(int(d * SR), k) for f, k in ((110, 1.4), (165, 1.8), (220, 2.4), (277, 3.2))])
    fall = osc(sweep(440, 110, 1.6, 0.5), 1.6, "tri") * env(int(1.6 * SR), 0.01, 0.4, 0.4, 1.0) * 0.4
    save("death", fast_reverb(mix(toll, fall), 0.7, 0.45), 0.8)

    # ---- traps -----------------------------------------------------------------------
    save("trap_spike", mix(bp(noise(0.12), 3000, 9000) * exp_env(int(0.12 * SR), 30),
                           *[at(osc(f, 0.25, "sine") * exp_env(int(0.25 * SR), 20) * 0.3, 0.01) for f in (2600, 3900)]), 0.65)
    save("trap_thud", mix(lp(noise(0.4), 500) * exp_env(int(0.4 * SR), 10), osc(sweep(90, 40, 0.4), 0.4, "sine") * exp_env(int(0.4 * SR), 8)), 0.8)
    save("trap_dart", mix(osc(sweep(2500, 900, 0.15), 0.15, "sine") * exp_env(int(0.15 * SR), 18) * 0.5,
                          at(bp(noise(0.04), 1000, 5000) * exp_env(int(0.04 * SR), 60), 0.14)), 0.55)
    d = 1.4
    rocks = mix(*[at(lp(noise(0.12), 1500) * exp_env(int(0.12 * SR), 30) * rng.uniform(0.3, 1), rng.uniform(0, 1.0)) for _ in range(16)])
    save("trap_rocks", mix(rocks, lp(brown(d), 200) * env(int(d * SR), 0.1, 0.5, 0.4, 0.6) * 0.8), 0.8)
    save("trap_gas", hp(noise(1.0), 2500) * env(int(1.0 * SR), 0.05, 0.3, 0.5, 0.5), 0.45)
    save("trap_snap", mix(bp(noise(0.05), 1500, 8000) * exp_env(int(0.05 * SR), 70),
                          *[osc(f, 0.3, "sine") * exp_env(int(0.3 * SR), 25) * 0.4 for f in (700, 1650)]), 0.75)
    save("trap_sink", mix(*[at(lp(osc(sweep(400, 120, 0.12), 0.12, "sine"), 900) * exp_env(int(0.12 * SR), 18), k * 0.18) for k in range(4)]), 0.55)
    save("trap_click", bp(noise(0.03), 2000, 7000) * exp_env(int(0.03 * SR), 80), 0.4)

    # ---- riddles, sprites, Lume ----------------------------------------------------------
    d = 1.0
    save("riddle", fast_reverb(mix(*[at(note(f, 0.5, "sine", d=0.45), i * 0.09) for i, f in enumerate([523, 622, 784, 932, 1046])])
                               * 0.6, 0.5, 0.45), 0.55)
    save("correct", fast_reverb(mix(*[at(note(f, 0.14 if i < 4 else 0.5, "square", d=0.1, s=0.3, duty=0.25), i * 0.08)
                                      for i, f in enumerate([523, 659, 784, 1046, 1318])]), 0.3, 0.25), 0.5)
    save("wrong", mix(note(311, 0.18, "square", d=0.15, duty=0.25), at(note(233, 0.4, "square", d=0.35, s=0.2, duty=0.25), 0.16)), 0.45)
    save("fade_away", fast_reverb(mix(osc(sweep(900, 300, 0.9), 0.9, "sine") * env(int(0.9 * SR), 0.01, 0.4, 0.3, 0.4) * 0.5,
                                      hp(noise(0.9), 3000) * env(int(0.9 * SR), 0.05, 0.3, 0.3, 0.5) * 0.3), 0.5, 0.45), 0.5)
    save("upgrade", fast_reverb(mix(*[at(note(f, 0.3, "tri", d=0.25), i * 0.07) for i, f in enumerate([392, 523, 659, 784, 1046, 1318])]),
                                0.4, 0.35), 0.6)
    for i, f in enumerate([880, 988, 1046, 1175]):   # Lume speaking: tiny bubbly blips
        save(f"voice{i}", note(f, 0.045, "sine", a=0.004, d=0.03, s=0.2, r=0.01) + note(f * 2, 0.045, "tri", d=0.03) * 0.15, 0.25)
    save("type", note(1200, 0.02, "square", d=0.015, duty=0.25), 0.12)
    save("page", hp(noise(0.12), 2500) * env(int(0.12 * SR), 0.02, 0.05, 0.2, 0.05), 0.3)
    save("bag_open", mix(lp(noise(0.12), 1200) * env(int(0.12 * SR), 0.01, 0.05, 0.3, 0.05), at(note(523, 0.06, "tri", d=0.05), 0.06)), 0.4)
    save("bag_close", mix(lp(noise(0.1), 1000) * env(int(0.1 * SR), 0.01, 0.05, 0.3, 0.04), at(note(392, 0.06, "tri", d=0.05), 0.04)), 0.35)

    # ---- the world -----------------------------------------------------------------------
    d = 3.0   # dawn: a warm, rising chord
    save("dawn", fast_reverb(mix(*[osc(f, d, "sine") * env(int(d * SR), 0.8 + i * 0.2, 0.8, 0.5, 1.0) for i, f in enumerate((262, 330, 392, 523, 659))])
                             * 0.5, 0.6, 0.4), 0.55)
    d = 3.2   # dusk: a low bell, and something answering far off
    bell = mix(*[osc(f, d, "sine") * exp_env(int(d * SR), k) for f, k in ((98, 1.2), (196, 1.6), (247, 2.2), (294, 2.6), (415, 3.5))])
    save("dusk", fast_reverb(mix(bell, at(moan * 0.15, 1.2)), 0.8, 0.5), 0.65)
    save("eternal", fast_reverb(mix(*[osc(f, 4.0, "sine") * exp_env(int(4.0 * SR), k) for f, k in ((55, 0.9), (82, 1.1), (110, 1.4), (131, 2.0))]),
                                0.9, 0.5), 0.75)
    save("heartbeat", mix(lp(osc(55, 0.15, "sine") * exp_env(int(0.15 * SR), 25), 200),
                          at(lp(osc(50, 0.15, "sine") * exp_env(int(0.15 * SR), 28), 200) * 0.7, 0.22)), 0.6)
    save("bump", lp(noise(0.06), 600) * exp_env(int(0.06 * SR), 50), 0.35)
    d = 0.45   # brushing through leaves: a few soft, crackly shakes
    rus = np.zeros(int(d * SR))
    for k in range(5):
        p = int((k * 0.07 + rng.uniform(0, 0.02)) * SR)
        b = bp(noise(0.09), 1500, 7000) * env(int(0.09 * SR), 0.01, 0.03, 0.3, 0.04) * (1 - k * 0.15)
        rus[p:p + len(b)] += b
    save("rustle", mix(rus, lp(noise(d), 900) * env(int(d * SR), 0.02, 0.1, 0.2, 0.2) * 0.3), 0.5)
    d = 1.2   # the intro: the voice in the dark
    save("whisper", fast_reverb(bp(noise(d), 1500, 5000) * env(int(d * SR), 0.2, 0.4, 0.3, 0.5) * (0.6 + 0.4 * np.sin(np.linspace(0, 20, int(d * SR)))),
                                0.7, 0.5), 0.35)
    save("wake", mix(lp(noise(0.25), 900) * env(int(0.25 * SR), 0.01, 0.1, 0.3, 0.1),
                     at(note(392, 0.1, "tri", d=0.08), 0.05), at(note(523, 0.16, "tri", d=0.12), 0.12)), 0.5)

    # ---- ambient loops (seamless) --------------------------------------------------------------
    d = 12.0   # the crypts at night: a low drone, far-off drips
    n = int(d * SR)
    drone = lp(brown(d), 160) * 0.9 + osc(55, d, "sine") * (0.15 + 0.05 * np.sin(np.linspace(0, 2 * np.pi * 3, n)))
    drips = np.zeros(n)
    for _ in range(9):
        p = int(rng.uniform(0.5, d - 1.0) * SR)
        dr = osc(sweep(rng.uniform(1500, 2400), rng.uniform(600, 900), 0.08), 0.08, "sine") * exp_env(int(0.08 * SR), 40)
        drips[p:p + len(dr)] += dr * rng.uniform(0.15, 0.35)
    save("amb_night", loopable(mix(drone, fast_reverb(drips, 0.8, 0.6)[:n]), 1.5), 0.5)
    d = 12.0   # outdoors at night: wind through the trees, crickets
    n = int(d * SR)
    wind = bp(brown(d), 120, 900) * (0.6 + 0.4 * np.sin(np.linspace(0, 2 * np.pi * 2, n)))
    crick = np.zeros(n)
    for k in range(int(d * 2.2)):
        p = int(rng.uniform(0, d - 0.3) * SR)
        c = osc(4200, 0.25, "sine") * (osc(28, 0.25, "square") > 0) * env(int(0.25 * SR), 0.02, 0.1, 0.5, 0.1)
        crick[p:p + len(c)] += c * rng.uniform(0.05, 0.15)
    save("amb_outdoor", loopable(mix(wind, crick), 1.5), 0.5)
    d = 12.0   # daytime: a light breeze and birds
    n = int(d * SR)
    breeze = bp(brown(d), 200, 1500) * 0.4
    birds = np.zeros(n)
    for k in range(10):
        p = int(rng.uniform(0, d - 0.6) * SR)
        f0 = rng.uniform(2200, 3400)
        for j in range(rng.integers(2, 5)):
            c = osc(sweep(f0, f0 * rng.uniform(1.2, 1.5), 0.07), 0.07, "sine") * env(int(0.07 * SR), 0.005, 0.04, 0.2, 0.02)
            q = p + int(j * 0.1 * SR)
            if q + len(c) < n:
                birds[q:q + len(c)] += c * 0.25
    save("amb_day", loopable(mix(breeze, birds), 1.5), 0.45)
    d = 10.0   # rain
    n = int(d * SR)
    save("amb_rain", loopable(mix(lp(noise(d), 4000) * 0.5, hp(noise(d), 5000) * 0.2), 1.0), 0.4)

    # ---- villages -------------------------------------------------------------------
    # a ruby: a bright glassy two-note chime with a sparkle on top
    sparkle = hp(noise(0.12), 6000) * exp_env(int(0.12 * SR), 25) * 0.25
    save("coin", fast_reverb(mix(note(1760, 0.09, "tri", d=0.07), at(note(2637, 0.22, "sine", d=0.2), 0.06),
                                 at(sparkle, 0.05)), 0.25, 0.3), 0.5)
    # buying: a little cascade of coins and a confirming chime
    cas = mix(*[at(note(2000 + k * 230, 0.05, "tri", d=0.04), k * 0.045) for k in range(5)])
    save("buy", fast_reverb(mix(cas, at(note(1318, 0.3, "sine", d=0.28), 0.22), at(note(1976, 0.35, "sine", d=0.3), 0.26)), 0.3, 0.3), 0.55)
    # the gate: a long wooden creak and the bar lifting
    d = 0.9
    creak = bp(osc(sweep(70, 120, d, 0.8), d, "saw"), 180, 1400) * env(int(d * SR), 0.05, 0.4, 0.5, 0.3) * 0.7
    latch = mix(lp(noise(0.06), 1200) * exp_env(int(0.06 * SR), 40), osc(90, 0.15, "sine") * exp_env(int(0.15 * SR), 20))
    save("gate", fast_reverb(mix(latch, at(creak, 0.08)), 0.4, 0.25), 0.7)
    # a shop bell over the door
    bell = mix(*[at(osc(f, 1.0, "sine") * exp_env(int(1.0 * SR), 5) * a, t0)
                 for f, a, t0 in ((2093, 0.6, 0.0), (2637, 0.35, 0.0), (4186, 0.15, 0.0), (2093, 0.4, 0.16), (2637, 0.25, 0.16))])
    save("shop_bell", fast_reverb(bell, 0.3, 0.25), 0.5)
    # the sage: a soft shimmering chord
    chord = mix(*[at(osc(f, 1.4, "sine") * env(int(1.4 * SR), 0.15, 0.5, 0.5, 0.6) * 0.3, i * 0.08)
                  for i, f in enumerate([392, 494, 587, 784, 988])])
    save("sage", fast_reverb(chord, 0.5, 0.45), 0.55)
    # sleeping: a slow falling lullaby, then morning: a bright rising call
    lull = mix(*[at(note(f, 0.5, "tri", a=0.05, d=0.3, s=0.3, r=0.15), i * 0.32)
                 for i, f in enumerate([784, 659, 523, 440, 392])])
    save("sleep", fast_reverb(lull, 0.5, 0.4), 0.5)
    morning = mix(*[at(note(f, 0.3, "tri", d=0.25), i * 0.09) for i, f in enumerate([523, 659, 784, 1046, 1318])])
    save("morning", fast_reverb(morning, 0.4, 0.3), 0.55)


if __name__ == "__main__":
    build()
    print("wrote", len(list(OUT.glob("*.wav"))), "sounds")
