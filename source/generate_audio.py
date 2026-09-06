"""Synthesize all original Wormhole Wardens audio. Python 3, standard library only.

No recordings, samples, soundfonts, external compositions, or network access.
Run from any directory: python source/generate_audio.py
"""
from array import array
from pathlib import Path
import math
import random
import wave

RATE = 22050
TAU = math.tau
DEST = Path(__file__).resolve().parents[1] / "assets" / "audio"


def envelope(t, duration, attack=0.01, release=0.12):
    return min(1.0, t / attack) * min(1.0, (duration - t) / release)


def write(name, samples, peak=0.7):
    highest = max(max(samples), -min(samples), 0.001)
    # Normalize source assets; gameplay further attenuates and caps voice count.
    pcm = array("h", (int(max(-1, min(1, s / highest * peak)) * 32767) for s in samples))
    with wave.open(str(DEST / (name + ".wav")), "wb") as output:
        output.setparams((1, 2, RATE, len(pcm), "NONE", "not compressed"))
        output.writeframes(pcm.tobytes())


def add_note(buffer, start, length, frequency, gain, attack=.02, release=.15, bright=False):
    offset = round(start * RATE)
    for i in range(round(length * RATE)):
        t = i / RATE
        tone = math.sin(TAU * frequency * t)
        tone += (.22 if bright else .07) * math.sin(TAU * frequency * 2 * t)
        buffer[(offset + i) % len(buffer)] += tone * envelope(t, length, attack, release) * gain


def music(name, bpm, root, active):
    beat = 60 / bpm
    duration = beat * 32
    buffer = [0.0] * round(duration * RATE)
    # Four original suspended/minor voicings; note tails wrap around the loop.
    chords = [(0, 7, 14), (-3, 4, 9), (-5, 2, 7), (-2, 5, 12)]
    for bar, chord in enumerate(chords):
        for semitone in chord:
            frequency = root * 2 ** (semitone / 12)
            add_note(buffer, bar * 8 * beat, 9 * beat, frequency, .11, .7, 1.4)
        for step in range(16):
            frequency = root * 2 ** ((chord[step % 3] + 12) / 12)
            add_note(buffer, (bar * 8 + step / 2) * beat, beat * .68,
                     frequency, .035 if active else .022, .018, .2, True)
        for step in range(8):
            add_note(buffer, (bar * 8 + step) * beat, beat * .78,
                     root / 2 * 2 ** (chord[0] / 12), .08 if active else .035, .04, .25)
    if active:
        for hit in range(32):
            offset = round(hit * beat * RATE)
            for i in range(round(.13 * RATE)):
                t = i / RATE
                buffer[(offset + i) % len(buffer)] += math.sin(TAU * (65 * t - 120 * t * t)) * math.exp(-30 * t) * .09
    # Circular microfade ensures sample-level seam continuity while preserving tails.
    seam = (buffer[0] + buffer[-1]) / 2
    ramp = round(.004 * RATE)
    for i in range(ramp):
        amount = i / ramp
        buffer[i] = seam * (1 - amount) + buffer[i] * amount
        buffer[-1-i] = seam * (1 - amount) + buffer[-1-i] * amount
    write(name, buffer, .55)


def effect(name, duration, mode, seed):
    rng = random.Random(seed)
    data = []
    filtered = 0.0
    for i in range(round(duration * RATE)):
        t = i / RATE
        x = t / duration
        noise = rng.uniform(-1, 1)
        filtered = filtered * .87 + noise * .13
        if mode == "laser":
            signal = math.sin(TAU * (1600 * t - 3500 * t*t)) * math.exp(-17*t)
        elif mode == "missile":
            signal = .8 * filtered + .3 * math.sin(TAU * (130*t + 600*t*t))
        elif mode == "pulse":
            signal = math.sin(TAU * (180*t - 90*t*t)) * (.6 + .4*math.sin(TAU*24*t))
        elif mode == "cryo":
            signal = .7 * filtered + .2 * math.sin(TAU * 2400*t) * math.sin(TAU*71*t)
        elif mode == "rail":
            signal = (noise * math.exp(-65*t) + .4*math.sin(TAU*(480*t-600*t*t))) * math.exp(-8*t)
        elif mode == "impact":
            signal = (.7*noise + .5*math.sin(TAU*110*t))*math.exp(-25*t)
        elif mode == "implode":
            signal = (filtered + .5*math.sin(TAU*(240*t-160*t*t)))*math.exp(-3*t)
        elif mode == "thruster":
            signal = filtered * (math.sin(math.pi*x)**2) + .08*math.sin(TAU*65*t)
        elif mode == "core":
            signal = .5*math.sin(TAU*93*t) + .2*math.sin(TAU*98*t) + filtered*.4
        else:
            notes = {
                "deploy": [330, 440, 660], "upgrade": [440, 554.365, 659.255, 880],
                "salvage": [660, 440, 330], "ui": [1100], "wave": [220, 330, 440],
                "complete": [330, 440, 554.365, 660], "bonus": [659.255, 880, 1108.73],
                "victory": [261.626, 329.628, 391.995, 523.251, 659.255],
                "defeat": [220, 207.652, 164.814, 110], "support": [440, 660, 880],
            }[mode]
            note_index = min(len(notes)-1, int(x*len(notes)))
            local_time = (x*len(notes) % 1) * duration / len(notes)
            signal = math.sin(TAU*notes[note_index]*local_time) * envelope(local_time, duration/len(notes), .006, .025)
            signal += .1*math.sin(TAU*notes[note_index]*2*local_time)*envelope(local_time, duration/len(notes), .006, .025)
        data.append(signal * envelope(t, duration, .003, min(.1, duration/3)))
    write(name, data, .68)


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    music("music_menu", 80, 146.832, False)
    music("music_game", 96, 164.814, True)
    cues = {"laser": .16, "missile": .36, "pulse": .5, "cryo": .4, "rail": .28,
            "support": .45, "impact": .18, "implode": .65, "thruster": .35,
            "deploy": .55, "upgrade": .7, "salvage": .55, "ui": .09,
            "wave": .9, "complete": 1.0, "bonus": .75, "core": .45,
            "victory": 2.0, "defeat": 1.8}
    for seed, (name, duration) in enumerate(cues.items()):
        effect(name, duration, name, 4700 + seed)
    print(f"Generated {len(cues)} original cues and 2 seamless music loops in {DEST}")


if __name__ == "__main__":
    main()
