"""Generate Nudge's original town sounds with Python's standard library.

Run from the repository root: python scripts/generate_town_audio.py
All tones/noise are synthesized here; no sampled third-party material is used.
"""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 16000
OUT = Path(__file__).resolve().parents[1] / "web_dashboard" / "assets" / "audio"
OUT.mkdir(parents=True, exist_ok=True)


def write(name, seconds, sound, *, loop=False):
    count = int(seconds * RATE)
    frames = bytearray()
    for i in range(count):
        t = i / RATE
        edge = min(1.0, t / 0.16, (seconds - t) / 0.16) if loop else 1.0
        value = max(-1.0, min(1.0, sound(t, i) * edge))
        frames.extend(struct.pack("<h", int(value * 26000)))
    with wave.open(str(OUT / name), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(frames)


def ambience(night):
    rng = random.Random(4201 if night else 2401)
    noise = 0.0

    def sound(t, _):
        nonlocal noise
        noise = noise * 0.965 + rng.uniform(-1, 1) * 0.035
        wind = noise * (0.15 + 0.05 * math.sin(2 * math.pi * t / 8))
        fountain = rng.uniform(-1, 1) * (0.027 if night else 0.052)
        if night:
            chirp_time = t % 2.3
            insect = 0.035 * math.sin(2 * math.pi * 2800 * t) if chirp_time < 0.18 else 0
            return wind + fountain + insect
        bird = 0.0
        for start in (2.2, 7.4, 11.3):
            local = t - start
            if 0 <= local < 0.27:
                envelope = math.sin(math.pi * local / 0.27) ** 2
                bird += 0.075 * envelope * math.sin(2 * math.pi * (1400 * local + 1800 * local * local))
        return wind + fountain + bird

    return sound


write("town_day.wav", 16, ambience(False), loop=True)
write("town_night.wav", 16, ambience(True), loop=True)
write("ui_click.wav", 0.12, lambda t, _: 0.18 * math.exp(-35 * t) * math.sin(2 * math.pi * 740 * t))
write("door_open.wav", 0.42, lambda t, _: 0.17 * math.exp(-6 * t) *
      (math.sin(2 * math.pi * (230 * t + 180 * t * t)) + .35 * math.sin(2 * math.pi * 510 * t)))
write("door_close.wav", 0.27, lambda t, _: 0.26 * math.exp(-18 * t) *
      (math.sin(2 * math.pi * 110 * t) + .25 * math.sin(2 * math.pi * 390 * t)))
write("stamp.wav", 0.25, lambda t, _: 0.24 * math.exp(-22 * t) *
      (math.sin(2 * math.pi * 150 * t) + .25 * math.sin(2 * math.pi * 900 * t)))


def level_up(t, _):
    notes = (523.25, 659.25, 783.99, 1046.5)
    index = min(3, int(t / 0.17))
    local = t - index * 0.17
    return 0.16 * math.exp(-10 * max(0, local)) * math.sin(2 * math.pi * notes[index] * local)


write("level_up.wav", 0.72, level_up)
