"""More sounds: the dread, the night's life, the creatures. assets/sfx/*.wav

Built with the same synth parts as tools/make_sfx.py (which is left as it is,
so none of the first sounds change):

  heart_low       your own heart, close to dying: a heavy, muffled lub-dub
  screech         the Wolf Man, as it starts toward you: a tearing, wavering
                  shriek -- several throats a little out of tune, a rasp
  screech_far     the same, far off in the dark (when your light is failing)
  snarl           it drops onto all fours: a wet, low growl
  breath          its breathing as it comes: a ragged rasp in and out
  lantern_sputter your flame starving for oil
  owl, howl_far, frog, crow, drip, chains, moan_far, wind_whistle,
  water_lap, toll_far   -- the life (and death) of each land at night / by day
  chitter, growl  insects and demons near you, before they see you
  ladder          climbing rungs

    python3 tools/make_sfx_more.py
"""
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_sfx as fx  # noqa: E402
from make_sfx import (SR, at, bp, brown, crush, echo, env, exp_env, fade, fast_reverb, hp, lp, mix,  # noqa: E402
                      noise, norm, osc, reverb, save, sweep, t_axis)

rng = np.random.default_rng(1013)
fx.rng = rng


def thump(f0, f1, dur, vel):
    n = int(dur * SR)
    body = osc(sweep(f0, f1, dur, 0.6), dur, "sine") * exp_env(n, 9) * vel
    knock = lp(rng.uniform(-1, 1, n), 300) * exp_env(n, 40) * vel * 0.5
    return body + knock


def shriek(dur, base, wobble=7.0, voices=4, rasp=0.35):
    """Several throats a little out of tune: each a saw sweeping up then
    falling, wavering; through a mouth-like band and a rasp of noise."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for v in range(voices):
        det = 1.0 + (v - voices / 2) * 0.018
        shape = np.interp(t / dur, [0, 0.18, 0.55, 1.0], [0.55, 1.15, 1.0, 0.5])
        f = base * det * shape * (1 + 0.04 * np.sin(2 * np.pi * (wobble + v) * t))
        x = osc(f, dur, "saw")
        out += x
    out = bp(out, 700, 3600) + bp(out, 2400, 5200) * 0.6
    grit = bp(noise(dur), 1800, 6000) * rasp
    e = env(n, 0.03, 0.15, 0.85, dur * 0.45, hold=dur * 0.3)
    x = (out * 0.6 + grit) * e
    return np.tanh(x * 2.5) * 0.6


def build():
    # ---- your heart, nearly dead ------------------------------------------------------
    beat = mix(thump(70, 38, 0.32, 1.0), at(thump(62, 34, 0.32, 0.75), 0.17))
    save("heart_low", lp(fade(np.concatenate([beat, np.zeros(int(0.15 * SR))])), 600), 0.95)

    # ---- the Wolf Man --------------------------------------------------------------------
    s = shriek(1.5, 900)
    save("screech", fast_reverb(mix(s, at(shriek(1.1, 1250, 11, 3, 0.5) * 0.5, 0.35)), 0.55, 0.35), 0.9)
    far = lp(shriek(1.8, 820, 6, 3, 0.25), 2200) * 0.6
    save("screech_far", fast_reverb(echo(far, 0.21, 0.38, 4), 0.85, 0.6), 0.55)
    d = 1.2
    n = int(d * SR)
    am = 0.55 + 0.45 * np.sin(2 * np.pi * np.interp(np.arange(n) / SR, [0, d], [22, 34]) * np.arange(n) / SR)
    growl = bp(osc(sweep(85, 62, d), d, "saw") + noise(d) * 0.6, 120, 900) * am * env(n, 0.08, 0.3, 0.8, 0.4, hold=0.4)
    wet = bp(noise(d), 1500, 4000) * exp_env(n, 6) * 0.15
    save("snarl", fast_reverb(np.tanh(mix(growl, wet) * 2.2), 0.4, 0.25), 0.8)
    inhale = bp(noise(0.45), 500, 2600) * env(int(0.45 * SR), 0.2, 0.1, 0.8, 0.12) * 0.8
    exhale = bp(noise(0.55), 250, 1600) * env(int(0.55 * SR), 0.04, 0.2, 0.6, 0.25)
    rattle = osc(38, 0.55, "square") * 0.12 * env(int(0.55 * SR), 0.04, 0.2, 0.6, 0.25)
    save("breath", fast_reverb(mix(inhale, at(exhale + rattle, 0.5)), 0.3, 0.2), 0.6)

    # ---- the flame starving ---------------------------------------------------------------
    d = 0.7
    n = int(d * SR)
    pops = np.zeros(n)
    for k in range(9):
        p = int(rng.uniform(0, d - 0.04) * SR)
        c = hp(noise(0.025), 1500) * exp_env(int(0.025 * SR), 120)
        pops[p:p + len(c)] += c * rng.uniform(0.4, 1.0)
    gutter = bp(brown(d), 120, 700) * (0.5 + 0.5 * np.sin(2 * np.pi * 7 * np.arange(n) / SR)) * env(n, 0.05, 0.2, 0.6, 0.3)
    save("lantern_sputter", mix(pops, gutter * 0.8), 0.55)

    # ---- the night, the day --------------------------------------------------------------
    def hoot(f, dur):
        n = int(dur * SR)
        return osc(f * (1 + 0.02 * np.sin(np.linspace(0, 3, n))), dur, "sine") * env(n, 0.05, 0.1, 0.8, 0.12)
    owl = mix(hoot(410, 0.22), at(hoot(380, 0.5), 0.35), at(hoot(395, 0.18), 0.98), at(hoot(370, 0.42), 1.22))
    save("owl", fast_reverb(lp(owl, 1500), 0.7, 0.45), 0.45)
    d = 2.6
    hw = osc(sweep(300, 520, d, 0.35) * np.interp(np.arange(int(d * SR)) / SR, [0, 1.4, 2.6], [1.0, 1.0, 0.78]), d, "tri")
    hw = lp(hw, 1400) * env(int(d * SR), 0.4, 0.6, 0.8, 1.0, hold=0.6)
    save("howl_far", fast_reverb(echo(hw * 0.7, 0.33, 0.4, 3), 0.9, 0.6), 0.45)
    croak = mix(*[at(bp(osc(sweep(140, 110, 0.09), 0.09, "saw"), 200, 1200) * exp_env(int(0.09 * SR), 25), k * 0.11)
                  for k in range(3)])
    save("frog", fast_reverb(croak, 0.4, 0.25), 0.5)
    caw = mix(*[at(bp(osc(sweep(900, 700, 0.18), 0.18, "saw") + noise(0.18) * 0.5, 600, 2500)
                   * env(int(0.18 * SR), 0.01, 0.05, 0.7, 0.08), k * 0.32) for k in range(2)])
    save("crow", fast_reverb(caw, 0.5, 0.3), 0.45)
    drip = mix(osc(sweep(1800, 900, 0.05), 0.05, "sine") * exp_env(int(0.05 * SR), 60),
               at(osc(sweep(1400, 1100, 0.12), 0.12, "sine") * exp_env(int(0.12 * SR), 30) * 0.4, 0.04))
    save("drip", fast_reverb(echo(drip, 0.18, 0.4, 4), 0.8, 0.5), 0.4)
    links = np.zeros(int(1.2 * SR))
    for k in range(7):
        p = int((0.08 + k * 0.14 + rng.uniform(-0.03, 0.03)) * SR)
        c = mix(*[osc(f, 0.25, "sine") * exp_env(int(0.25 * SR), 22) * a for f, a in ((1830, 0.5), (2710, 0.35), (4120, 0.2))])
        k0 = int(0.02 * SR)
        c[:k0] += hp(noise(0.02), 3000)[:k0] * 0.3 * exp_env(k0, 150)
        links[p:p + len(c)] += c[:len(links) - p] * rng.uniform(0.4, 0.9)
    save("chains", fast_reverb(links, 0.7, 0.45), 0.4)
    d = 2.8
    m = osc(sweep(180, 140, d) * (1 + 0.03 * np.sin(np.linspace(0, 9, int(d * SR)))), d, "saw")
    m = bp(m, 300, 900) * env(int(d * SR), 0.7, 0.5, 0.7, 1.2, hold=0.5)
    save("moan_far", fast_reverb(m, 0.9, 0.7), 0.4)
    d = 3.0
    wl = bp(noise(d), 700, 1100) * 0.5 + osc(sweep(820, 980, d, 0.5), d, "sine") * 0.12
    save("wind_whistle", wl * env(int(d * SR), 0.9, 0.5, 0.7, 1.3, hold=0.4), 0.35)
    d = 1.6
    lap = np.zeros(int(d * SR))
    for k in range(4):
        p = int((0.1 + k * 0.35) * SR)
        c = bp(noise(0.3), 300, 1600) * env(int(0.3 * SR), 0.08, 0.1, 0.4, 0.12)
        lap[p:p + len(c)] += c
    save("water_lap", lp(lap, 2200), 0.35)
    toll = mix(*[osc(f, 3.0, "sine") * exp_env(int(3.0 * SR), 1.6) * a for f, a in ((196, 0.6), (233, 0.3), (392, 0.25), (587, 0.12))])
    save("toll_far", fast_reverb(lp(toll, 1800), 0.8, 0.6), 0.4)

    # ---- creatures near you ---------------------------------------------------------------
    d = 0.5
    ch = np.zeros(int(d * SR))
    for k in range(10):
        p = int(k * 0.045 * SR)
        c = bp(osc(rng.uniform(2800, 4200), 0.02, "square"), 2000, 6000) * exp_env(int(0.02 * SR), 90)
        ch[p:p + len(c)] += c * rng.uniform(0.5, 1.0)
    save("chitter", ch, 0.4)
    d = 0.9
    n = int(d * SR)
    am = 0.6 + 0.4 * np.sin(2 * np.pi * 18 * np.arange(n) / SR)
    g = bp(osc(sweep(70, 55, d), d, "saw") + noise(d) * 0.4, 90, 700) * am * env(n, 0.1, 0.3, 0.7, 0.3, hold=0.2)
    save("growl", fast_reverb(np.tanh(g * 2.0), 0.35, 0.25), 0.6)
    d = 0.22
    rung = mix(lp(noise(0.05), 900) * exp_env(int(0.05 * SR), 50), osc(sweep(180, 140, d), d, "tri") * exp_env(int(d * SR), 18) * 0.5)
    save("ladder", fast_reverb(rung, 0.2, 0.15), 0.55)

    # ---- the rare lands -------------------------------------------------------------------
    # lava catching you: a hiss and crackle
    d = 0.6
    n = int(d * SR)
    hiss = hp(noise(d), 2500) * env(n, 0.005, 0.1, 0.5, 0.35) * 0.8
    crk = np.zeros(n)
    for k in range(14):
        p = int(rng.uniform(0, d - 0.03) * SR)
        c = noise(0.012) * exp_env(int(0.012 * SR), 200)
        crk[p:p + len(c)] += c * rng.uniform(0.4, 1.0)
    save("sizzle", mix(hiss, crk * 0.6, osc(sweep(300, 120, d), d, "saw") * exp_env(n, 9) * 0.15), 0.8)
    # the volcano's deep rumble, and lava bubbling
    d = 2.4
    n = int(d * SR)
    rum = lp(brown(d), 90) * env(n, 0.5, 0.6, 0.8, 0.9, hold=0.4) * 1.6
    save("rumble", rum, 0.6)
    bub = np.zeros(int(1.0 * SR))
    for k in range(5):
        p = int(rng.uniform(0, 0.8) * SR)
        f0 = rng.uniform(140, 260)
        c = osc(sweep(f0, f0 * 1.8, 0.09), 0.09, "sine") * env(int(0.09 * SR), 0.005, 0.03, 0.4, 0.04)
        c = c + lp(noise(0.09), 600) * 0.3 * exp_env(int(0.09 * SR), 30)
        bub[p:p + len(c)] += c * rng.uniform(0.5, 1.0)
    save("lava_bubble", fast_reverb(lp(bub, 1200), 0.3, 0.3), 0.5)
    # the sea: a wave rolling in and drawing back
    d = 3.2
    n = int(d * SR)
    swell = np.interp(np.arange(n) / SR, [0, 1.1, 1.5, 3.2], [0, 1, 0.8, 0])
    wave_ = (bp(noise(d), 200, 1800) * 0.7 + hp(noise(d), 3000) * 0.25 * swell) * swell
    save("waves", wave_, 0.4)
    # gulls far off
    gull = mix(*[at(bp(osc(sweep(1500, 1050, 0.22) * (1 + 0.03 * np.sin(np.linspace(0, 30, int(0.22 * SR)))), 0.22, "saw"), 900, 3200)
                    * env(int(0.22 * SR), 0.02, 0.08, 0.6, 0.1), k * 0.3) for k in range(3)])
    save("gull", fast_reverb(gull, 0.6, 0.4), 0.35)
    # a jungle bird: a rising whistle and a trill
    d1 = 0.25
    w1 = osc(sweep(900, 2100, d1, 0.6), d1, "sine") * env(int(d1 * SR), 0.01, 0.1, 0.6, 0.08)
    tr = osc(1800 * (1 + 0.08 * np.sin(2 * np.pi * 28 * np.arange(int(0.35 * SR)) / SR)), 0.35, "sine") * env(int(0.35 * SR), 0.01, 0.1, 0.5, 0.1)
    save("bird_call", fast_reverb(mix(w1, at(tr * 0.7, 0.32)), 0.5, 0.35), 0.4)
    # the vault: a soft glassy chime, as if the gold itself rang
    chime = mix(*[at(osc(f, 1.6, "sine") * exp_env(int(1.6 * SR), 3.5) * a, t0)
                  for f, a, t0 in ((1318, 0.5, 0), (1976, 0.35, 0.05), (2637, 0.25, 0.1), (3951, 0.12, 0.12))])
    save("chime", fast_reverb(chime, 0.7, 0.5), 0.4)


if __name__ == "__main__":
    build()
    print("ok")
