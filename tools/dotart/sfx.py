"""8-bit style SFX, stdlib only.

    python3 tools/dotart/sfx.py

A sound is a list of notes: (wave, start_hz, end_hz, seconds, volume). Each note
gets a 4 ms attack and a linear decay, so nothing clicks.
"""

import math
import os
import random
import struct
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "Resources", "Sounds")
RATE = 22050
PEAK = 0.45  # modest: these play over each other during a rush

C5, D5, E5, G5, A5, B5 = 523.25, 587.33, 659.25, 783.99, 880.0, 987.77
C6, E6, G6, C7 = 1046.5, 1318.5, 1568.0, 2093.0


def note(kind, f0, f1, dur, vol=1.0, duty=0.5, hold=0.0, rng=None):
    n = int(RATE * dur)
    out, phase, lfsr = [], 0.0, 0.0
    rng = rng or random.Random(1)
    held = rng.uniform(-1, 1)
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        phase += f / RATE
        p = phase % 1.0
        if kind == "square":
            v = 1.0 if p < duty else -1.0
        elif kind == "triangle":
            v = 4 * abs(p - 0.5) - 1
        else:
            # noise: resample white noise at f so pitch still means something
            lfsr += f / RATE
            if lfsr >= 1:
                lfsr -= 1
                held = rng.uniform(-1, 1)
            v = held
        attack = min(1.0, i / (0.004 * RATE))
        decay = 1.0 if t < hold else 1 - (t - hold) / (1 - hold)
        out.append(v * vol * attack * decay)
    return out


def seq(*notes):
    out = []
    for n in notes:
        out += n
    return out


def mix(a, b, offset=0.0):
    start = int(offset * RATE)
    out = a + [0.0] * max(0, start + len(b) - len(a))
    for i, v in enumerate(b):
        out[start + i] += v
    return out


def rest(dur):
    return [0.0] * int(RATE * dur)


def build():
    r = random.Random(7)
    s = {}
    s["sfx_tap"] = note("square", 880, 660, 0.05, 0.6, duty=0.25)
    s["sfx_plant"] = seq(note("noise", 900, 300, 0.07, 0.5, rng=r), note("triangle", 220, 330, 0.09, 0.9))
    s["sfx_harvest"] = seq(note("noise", 4000, 1500, 0.04, 0.4, rng=r), note("square", E5, E5, 0.06, 0.6, 0.25),
                           note("square", A5, A5, 0.1, 0.6, 0.25))
    s["sfx_golden"] = mix(seq(*[note("square", f, f, 0.07, 0.55, 0.25, hold=0.5) for f in (E6, G6, C7)],
                              note("square", C7, C7, 0.22, 0.55, 0.25)),
                          note("triangle", C6, C6, 0.4, 0.5), 0.0)
    s["sfx_cook_done"] = seq(note("triangle", G5, G5, 0.09, 0.9, hold=0.4), note("triangle", C6, C6, 0.09, 0.9, hold=0.4),
                             note("triangle", E6, E6, 0.2, 0.9))
    s["sfx_coin"] = seq(note("square", B5, B5, 0.05, 0.55, 0.5, hold=0.6), note("square", E6, E6, 0.2, 0.55, 0.5))
    s["sfx_purchase"] = seq(note("square", C5, C5, 0.07, 0.55, 0.25, hold=0.5), note("square", E5, E5, 0.07, 0.55, 0.25, hold=0.5),
                            note("square", G5, G5, 0.07, 0.55, 0.25, hold=0.5), note("square", C6, C6, 0.24, 0.55, 0.25))
    s["sfx_error"] = seq(note("square", 196, 185, 0.11, 0.6, 0.5, hold=0.6), rest(0.03),
                         note("square", 147, 139, 0.2, 0.6, 0.5, hold=0.4))
    s["sfx_fever_start"] = mix(note("square", 330, 1320, 0.34, 0.5, 0.25, hold=0.8),
                               seq(rest(0.3), note("square", C6, C6, 0.07, 0.6, 0.5, hold=0.5),
                                   note("square", G6, G6, 0.2, 0.6, 0.5)))
    s["sfx_mission_done"] = seq(note("square", G5, G5, 0.08, 0.55, 0.5, hold=0.6), note("square", G5, G5, 0.08, 0.55, 0.5, hold=0.6),
                                note("square", C6, C6, 0.08, 0.55, 0.5, hold=0.6), note("square", E6, E6, 0.08, 0.55, 0.5, hold=0.6),
                                note("square", G6, G6, 0.24, 0.55, 0.5))
    rain = note("noise", 6000, 3500, 0.55, 0.45, hold=0.3, rng=r)
    for off, f in ((0.05, 1800), (0.17, 1400), (0.3, 2000), (0.4, 1500)):
        rain = mix(rain, note("triangle", f, f * 0.5, 0.04, 0.5), off)
    s["sfx_rain_start"] = rain[: int(RATE * 0.58)]
    return s


USES = {
    "sfx_tap": "any button / tab", "sfx_plant": "seed goes into a plot",
    "sfx_harvest": "cabbage harvested", "sfx_golden": "golden cabbage harvested",
    "sfx_cook_done": "a dish finishes cooking", "sfx_coin": "customer served, coin flies",
    "sfx_purchase": "upgrade / hire / plot bought", "sfx_error": "not enough coins, refused",
    "sfx_fever_start": "fever begins", "sfx_mission_done": "mission reward claimed",
    "sfx_rain_start": "rain begins",
}
_built = build()
SOUNDS = [(name, len(data) / RATE, USES[name]) for name, data in _built.items()]


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, data in _built.items():
        assert len(data) / RATE < 0.6, name
        with wave.open(os.path.join(OUT, f"{name}.wav"), "wb") as w:
            w.setnchannels(1), w.setsampwidth(2), w.setframerate(RATE)
            w.writeframes(b"".join(
                struct.pack("<h", int(max(-1.0, min(1.0, v)) * PEAK * 32767)) for v in data))
        print(f"{name}.wav {len(data) / RATE:.2f}s")


if __name__ == "__main__":
    main()
