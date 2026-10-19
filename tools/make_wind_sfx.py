"""The rush of air as a puff of wind runs past: assets/sfx/wind_puff0..2.wav
(22 kHz mono, like the rest -- see make_sfx.py). Three takes, so the puffs
don't all sound alike. Run:  python3 tools/make_wind_sfx.py
"""
from pathlib import Path
import wave

import numpy as np
from scipy import signal as sg

OUT = Path(__file__).resolve().parent.parent / "assets" / "sfx"
SR = 22050


def band(x, lo, hi):
    sos = sg.butter(2, [lo, hi], btype="bandpass", fs=SR, output="sos")
    return sg.sosfilt(sos, x)


def puff(seed, dur, rise, pitch):
    rng = np.random.default_rng(seed)
    n = int(dur * SR)
    t = np.arange(n) / SR
    # the swell: up quickly, then a long tail as it goes on by
    e = np.where(t < rise, (t / rise) ** 1.6, np.exp(-(t - rise) * 2.6))
    e *= 1.0 + 0.18 * np.sin(t * 2 * np.pi * rng.uniform(5, 8)) * e   # gusting inside it
    noise = rng.standard_normal(n)
    low = band(noise, 120, 420)
    mid = band(noise, 380 * pitch, 1100 * pitch)
    high = band(noise, 1400 * pitch, 3600 * pitch)
    # brighter at the peak (the air rushing fastest), duller as it fades
    x = low * (0.8 + 0.4 * e) + mid * (0.25 + 1.1 * e) + high * 0.35 * e ** 2
    # a thin whistle through the stonework, wavering
    f = 820 * pitch * (1 + 0.04 * np.sin(t * 2 * np.pi * 3.1)) * (0.95 + 0.1 * e)
    whistle = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.05 * e ** 1.5
    x = x * e + whistle
    fade = np.minimum(1.0, (n - np.arange(n)) / (0.08 * SR))
    return x * fade


def save(name, x, peak=0.7):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


if __name__ == "__main__":
    for i, (dur, rise, pitch) in enumerate([(1.5, 0.32, 1.0), (1.7, 0.45, 0.85), (1.3, 0.25, 1.15)]):
        save(f"wind_puff{i}", puff(41 + i, dur, rise, pitch))
    print("wrote assets/sfx/wind_puff0..2.wav")
