"""Soft, cute UI sounds, synthesised. Three families (bubble, marimba, kalimba), same set of
events in each, so Julia can pick a family by ear. Writes 44.1 kHz mono 16-bit WAV."""
import sys, wave
from pathlib import Path
import numpy as np

SR = 44100
OUT = Path(sys.argv[1])
rng = np.random.default_rng(7)


def note(n):  # semitones from A4
    return 440.0 * 2 ** (n / 12)


C5, D5, E5, G5, A5 = note(3), note(5), note(7), note(10), note(12)
C6, D6, E6, G6, A6, C7 = note(15), note(17), note(19), note(22), note(24), note(27)


def t_axis(sec):
    return np.arange(int(sec * SR)) / SR


def env(t, attack, decay):
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-np.maximum(t - attack, 0) / decay)


def soft_noise(sec, cutoff):
    """Noise through a one-pole lowpass: a felt mallet's thump, not a hiss."""
    n = rng.standard_normal(int(sec * SR))
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(n)
    acc = 0.0
    for i, x in enumerate(n):
        acc = (1 - a) * x + a * acc
        y[i] = acc
    return y / (np.abs(y).max() + 1e-9)


def bubble(f0, f1, sec=0.07, decay=0.022):
    t = t_axis(sec + 0.05)
    k = np.clip(t / sec, 0, 1)
    f = f0 * (f1 / f0) ** (k ** 0.6)
    ph = 2 * np.pi * np.cumsum(f) / SR
    y = np.sin(ph) + 0.12 * np.sin(2 * ph)
    return y * env(t, 0.002, decay)


def marimba(f, length=0.32):
    t = t_axis(length)
    d = 0.16 * (880 / f) ** 0.3
    y = (np.sin(2 * np.pi * f * t) * env(t, 0.0015, d)
         + 0.22 * np.sin(2 * np.pi * 4.0 * f * t) * env(t, 0.0008, d * 0.22)
         + 0.05 * np.sin(2 * np.pi * 9.2 * f * t) * env(t, 0.0005, d * 0.08))
    thump = soft_noise(0.012, 1800) * env(t_axis(0.012), 0.0005, 0.003) * 0.12
    y[:thump.size] += thump
    return y


def kalimba(f, length=0.38):
    t = t_axis(length)
    d = 0.2 * (880 / f) ** 0.25
    y = (np.sin(2 * np.pi * f * t) * env(t, 0.001, d)
         + 0.28 * np.sin(2 * np.pi * 5.9 * f * t) * env(t, 0.0005, d * 0.12)
         + 0.08 * np.sin(2 * np.pi * 2.0 * f * t) * env(t, 0.001, d * 0.5))
    tick = soft_noise(0.006, 4000) * env(t_axis(0.006), 0.0003, 0.0015) * 0.08
    y[:tick.size] += tick
    return y


def seq(parts):
    """[(start_seconds, samples, gain)] mixed together."""
    end = max(int(s * SR) + p.size for s, p, _ in parts)
    y = np.zeros(end)
    for s, p, g in parts:
        i = int(s * SR)
        y[i:i + p.size] += g * p
    return y


def finish(y, peak_db):
    y = y - np.mean(y)
    # Trim the silent tail, short fade so nothing clicks at the cut.
    loud = np.nonzero(np.abs(y) > np.abs(y).max() * 0.003)[0]
    y = y[:loud[-1] + 1]
    fade = min(int(0.008 * SR), y.size // 4)
    y[-fade:] *= np.linspace(1, 0, fade)
    return y / np.abs(y).max() * 10 ** (peak_db / 20)


def write(path, y):
    path.parent.mkdir(parents=True, exist_ok=True)
    data = (np.clip(y, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


GAP = 0.075
families = {
    "bubble": {
        "click": bubble(520, 1250),
        "back": bubble(1150, 480, sec=0.08),
        "play": seq([(0, bubble(500, 1000), 1), (GAP, bubble(700, 1500), 0.9)]),
        "mute": seq([(0, bubble(1100, 700), 1), (GAP, bubble(800, 420), 0.9)]),
        "unmute": seq([(0, bubble(450, 850), 1), (GAP, bubble(750, 1400), 0.9)]),
        "save": seq([(0, bubble(500, 900), 1), (GAP, bubble(650, 1200), 0.9), (2 * GAP, bubble(850, 1700), 0.85)]),
        "key": bubble(1400, 1900, sec=0.035, decay=0.012),
    },
    "marimba": {
        "click": marimba(C6),
        "back": seq([(0, marimba(G5), 1), (GAP, marimba(C5), 0.9)]),
        "play": seq([(0, marimba(C6), 1), (GAP, marimba(G6), 0.9)]),
        "mute": seq([(0, marimba(E6), 1), (GAP, marimba(A5), 0.85)]),
        "unmute": seq([(0, marimba(A5), 1), (GAP, marimba(E6), 0.85)]),
        "save": seq([(0, marimba(C6), 1), (GAP, marimba(E6), 0.9), (2 * GAP, marimba(G6), 0.85), (3 * GAP, marimba(C7), 0.8)]),
        "key": marimba(A6, length=0.08),
    },
    "kalimba": {
        "click": kalimba(E6),
        "back": seq([(0, kalimba(A5), 1), (GAP, kalimba(D5), 0.9)]),
        "play": seq([(0, kalimba(D6), 1), (GAP, kalimba(A6), 0.9)]),
        "mute": seq([(0, kalimba(E6), 1), (GAP, kalimba(A5), 0.85)]),
        "unmute": seq([(0, kalimba(A5), 1), (GAP, kalimba(E6), 0.85)]),
        "save": seq([(0, kalimba(D6), 1), (GAP, kalimba(E6), 0.9), (2 * GAP, kalimba(A6), 0.85), (3 * GAP, kalimba(D6 * 2), 0.8)]),
        "key": kalimba(A6, length=0.08),
    },
}

for fam, sounds in families.items():
    for name, y in sounds.items():
        write(OUT / fam / f"{name}.wav", finish(y, -9.0 if name == "key" else -4.0))
print("ok")
