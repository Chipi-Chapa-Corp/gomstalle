from pathlib import Path
import json

import numpy as np
from scipy import signal
from scipy.io import wavfile

from generate import RATE, edges, mix_at, noise, pluck, recorder, room, timeline

TEMPO = 144
BEAT = 60 / TEMPO
BAR = BEAT * 4
DURATION = 40
OUTPUT = Path(__file__).resolve().parents[2] / "assets/sounds/castle/trailer_score.wav"


def frequency(note):
    return 440 * 2 ** ((note - 69) / 12)


def frame_drum(accent):
    seconds = timeline(0.42)
    phase = 2 * np.pi * (76 * seconds + 26 * (1 - np.exp(-seconds * 30)) / 30)
    membrane = (np.sin(phase) + 0.3 * np.sin(phase * 1.59) + 0.15 * np.sin(phase * 2.17)) * np.exp(-seconds * 13)
    skin = noise(0.42, 180, 2400) * np.exp(-seconds * 65)
    return edges(membrane * (0.7 if accent else 0.32) + skin * 0.12, 0.001)


def rim():
    seconds = timeline(0.16)
    return edges((np.sin(2 * np.pi * 610 * seconds) + np.sin(2 * np.pi * 973 * seconds) * 0.4) * np.exp(-seconds * 55) * 0.4 + noise(0.16, 900, 4800) * np.exp(-seconds * 95) * 0.13, 0.001)


def tambourine():
    seconds = timeline(0.22)
    metal = noise(0.22, 3900, 12500) * np.exp(-seconds * 31)
    for partial in [4037, 5891, 7313, 9173]:
        metal += np.sin(2 * np.pi * partial * seconds) * np.exp(-seconds * 40) * 0.08
    return edges(metal * 0.12, 0.002)


def lute(note, duration=1.7):
    return room(pluck(frequency(note), duration), 0.19)


def flute(note, beats):
    return room(recorder(frequency(note), beats * BEAT + 0.095), 0.28)


def main():
    score = np.zeros((RATE * DURATION, 2))
    harmony = [(50, 57, 62, 65), (48, 55, 60, 64), (43, 50, 59, 62), (50, 57, 62, 65), (53, 60, 65, 69), (48, 55, 60, 64), (43, 50, 59, 62), (45, 52, 61, 64)]
    melody = [
        [(74, 0.75), (77, 0.25), (76, 0.5), (74, 0.5), (69, 1), (72, 1)],
        [(72, 0.5), (76, 0.5), (79, 1), (76, 0.75), (74, 0.25), (72, 1)],
        [(71, 0.5), (74, 0.5), (79, 1), (78, 0.5), (74, 0.5), (71, 1)],
        [(69, 0.5), (72, 0.5), (74, 1.5), (77, 0.5), (76, 0.5), (74, 0.5)],
        [(77, 1), (81, 0.5), (79, 0.5), (77, 0.5), (76, 0.5), (74, 1)],
        [(76, 0.75), (79, 0.25), (84, 1), (79, 0.5), (76, 0.5), (72, 1)],
        [(74, 0.5), (71, 0.5), (67, 1), (71, 0.5), (74, 0.5), (79, 1)],
        [(76, 0.5), (73, 0.5), (69, 1), (73, 0.5), (76, 0.5), (81, 1)],
    ]
    for bar in range(22):
        chord = harmony[bar % len(harmony)]
        intensity = 0.62 if bar < 3 else 0.9 if bar < 15 else 1.0
        for beat in range(8):
            note = chord[[0, 2, 1, 3, 0, 2, 1, 3][beat]]
            timing = bar * BAR + beat * BEAT / 2 + (0.008 if beat % 2 else 0)
            gain = 0.2 * intensity * (1 if beat % 2 == 0 else 0.72)
            mix_at(score, lute(note), timing, gain, -0.36)
            if bar >= 6:
                mix_at(score, lute(note + 12, 0.8), timing + 0.012, gain * 0.32, 0.47)
        mix_at(score, lute(chord[0] - 12, 2.7), bar * BAR, 0.35 * intensity, 0.02)
        if bar >= 3:
            for beat in [0, 1.5, 2, 3.5]:
                mix_at(score, room(frame_drum(beat in [0, 2]), 0.09), bar * BAR + beat * BEAT, 0.25 * intensity, -0.1)
            for beat in [1, 3]:
                mix_at(score, room(rim(), 0.15), bar * BAR + beat * BEAT + 0.006, 0.28 * intensity, 0.25)
            if bar >= 7:
                for beat in range(8):
                    mix_at(score, tambourine(), bar * BAR + beat * BEAT / 2 + 0.012, 0.32 if beat % 2 else 0.2, 0.5)
        if bar >= 4 and bar not in [11, 19]:
            phrase = melody[(bar - 4) % len(melody)]
            onset = bar * BAR + 0.025
            for note, beats in phrase:
                mix_at(score, flute(note, beats * 0.9), onset, 0.33 if bar < 16 else 0.38, 0.13)
                onset += beats * BEAT
        if bar in [6, 10, 14, 18]:
            for strum_index, note in enumerate(chord[1:]):
                mix_at(score, lute(note + 12, 2.3), bar * BAR + strum_index * 0.035, 0.1, -0.55)
        if bar in [7, 15, 21]:
            for fill_index in range(6):
                mix_at(score, frame_drum(fill_index % 3 == 0), bar * BAR + (2.5 + fill_index * 0.25) * BEAT, 0.16 + fill_index * 0.014, (fill_index % 2 * 2 - 1) * 0.2)
    resolve = 22 * BAR
    for index, note in enumerate([38, 50, 57, 62, 65, 69, 74]):
        mix_at(score, lute(note, 3.2), resolve + index * 0.022, 0.23 if index < 4 else 0.16, (index % 2 * 2 - 1) * 0.35)
    mix_at(score, flute(74, 4), resolve, 0.34, 0.13)
    mix_at(score, room(frame_drum(True), 0.3), resolve, 0.32)
    score = signal.sosfilt(signal.butter(2, 40, btype="highpass", fs=RATE, output="sos"), score, axis=0)
    score = np.tanh(score * 1.6)
    true_peak = np.max(np.abs(signal.resample_poly(score, 4, 1, axis=0)))
    score *= 10 ** (-1.5 / 20) / true_peak
    fade_samples = round(RATE * 1.25)
    score[-fade_samples:] *= np.linspace(1, 0, fade_samples)[:, None] ** 1.5
    score[:round(RATE * 0.007)] *= np.linspace(0, 1, round(RATE * 0.007))[:, None]
    wavfile.write(OUTPUT, RATE, np.round(score * 32767).astype(np.int16))
    print(json.dumps({"path": str(OUTPUT), "duration_seconds": DURATION, "tempo": TEMPO, "sample_peak_dbfs": float(20 * np.log10(np.max(np.abs(score)))), "true_peak_dbtp": float(20 * np.log10(np.max(np.abs(signal.resample_poly(score, 4, 1, axis=0))))), "rms_dbfs": float(20 * np.log10(np.sqrt(np.mean(score ** 2)))), "clipped_samples": int(np.count_nonzero(np.abs(score) >= 1)), "ending_sample": score[-1].tolist()}, indent=2))


if __name__ == "__main__":
    main()
