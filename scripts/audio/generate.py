from pathlib import Path
import argparse
import json
import subprocess
import tempfile

import numpy as np
from scipy import signal
from scipy.io import wavfile

RATE = 44100
RNG = np.random.default_rng(70431)
ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets/sounds/castle"


def timeline(duration):
    return np.arange(round(duration * RATE)) / RATE


def noise(duration, low, high):
    samples = RNG.normal(size=round(duration * RATE))
    filtered = signal.sosfilt(signal.butter(2, [low, high], btype="bandpass", fs=RATE, output="sos"), samples)
    return filtered / max(np.std(filtered), 0.0001)


def edges(samples, duration=0.008):
    samples = samples.copy()
    count = min(round(duration * RATE), len(samples) // 2)
    ramp = np.sin(np.linspace(0, np.pi / 2, count)) ** 2
    shape = ramp[:, None] if samples.ndim == 2 else ramp
    samples[:count] *= shape
    samples[-count:] *= shape[::-1]
    return samples


def room(samples, amount=0.15):
    result = np.pad(samples, (0, round(RATE * 0.65)))
    for delay, gain in [(0.043, 0.8), (0.079, -0.6), (0.127, 0.55), (0.193, 0.4), (0.311, -0.3), (0.487, 0.18)]:
        offset = round(delay * RATE)
        result[offset:offset + len(samples)] += samples * gain * amount
    return edges(result)


def pluck(frequency, duration=3.2):
    seconds = timeline(duration)
    result = np.zeros(len(seconds))
    for harmonic in range(1, 13):
        phase = RNG.uniform(0, 2 * np.pi)
        decay = np.exp(-seconds * (1.7 + harmonic * 0.48))
        result += np.sin(2 * np.pi * frequency * harmonic * seconds + phase) * decay / harmonic ** 1.45
    result += noise(duration, 900, 3800) * np.exp(-seconds * 100) * 0.045
    return edges(result, 0.003)


def recorder(frequency, duration):
    seconds = timeline(duration)
    envelope = np.minimum(seconds / 0.22, 1) * np.minimum((duration - seconds) / 0.35, 1)
    phase = 2 * np.pi * frequency * seconds + 0.045 * np.sin(2 * np.pi * 4.7 * seconds) * np.minimum(seconds, 1)
    return edges((np.sin(phase) + 0.16 * np.sin(phase * 2) + 0.06 * np.sin(phase * 3) + noise(duration, 800, 5000) * 0.025) * envelope * 0.36)


def mix_at(target, source, start, gain=1, pan=0, wrap=False):
    offset = round(start * RATE)
    stereo = source[:, None] * np.array([np.sqrt((1 - pan) / 2), np.sqrt((1 + pan) / 2)]) if source.ndim == 1 else source
    if wrap:
        indices = (np.arange(len(source)) + offset) % len(target)
        target[indices] += stereo * gain
    else:
        count = min(len(source), len(target) - offset)
        target[offset:offset + count] += stereo[:count] * gain


def music():
    result = np.zeros((RATE * 96, 2))
    chords = [(50, 57, 62, 65), (48, 55, 60, 64), (43, 50, 57, 62), (45, 52, 59, 64)]
    for bar in range(16):
        chord = chords[(bar // 2) % len(chords)]
        for offset, voice, gain in [(0, 0, 0.28), (1.48, 2, 0.16), (3.03, 1, 0.2), (4.51, 3, 0.13)]:
            note = chord[voice]
            mix_at(result, room(pluck(440 * 2 ** ((note - 69) / 12)), 0.28), bar * 6 + offset, gain, (-1) ** voice * 0.28, True)
    for phrase_start, notes in [(6, [74, 72, 69]), (30, [69, 67, 65]), (54, [74, 76, 72]), (78, [69, 67, 62])]:
        for index, note in enumerate(notes):
            mix_at(result, room(recorder(440 * 2 ** ((note - 69) / 12), 1.65 if index < 2 else 2.9), 0.33), phrase_start + index * 2.25, 0.19, 0.12, True)
    return result


def ambience():
    duration = 48
    result = np.zeros((RATE * duration, 2))
    seconds = timeline(duration)
    for channel in range(2):
        air = noise(duration + 2, 70, 550)
        overlap = RATE * 2
        blend = np.linspace(0, 1, overlap)
        air[:overlap] = air[:overlap] * blend + air[-overlap:] * (1 - blend)
        air = air[:RATE * duration]
        result[:, channel] = air * (0.045 + 0.012 * np.sin(2 * np.pi * seconds / 16 + channel))
    for _ in range(55):
        duration = RNG.uniform(0.04, 0.14)
        spark = noise(duration, 450, 4500) * np.exp(-timeline(duration) * 65)
        mix_at(result, spark, RNG.uniform(0, 47.8), RNG.uniform(0.004, 0.012), RNG.uniform(-0.8, 0.8), True)
    return result


def impact(duration, frequencies, decay, grit=0.15):
    seconds = timeline(duration)
    result = noise(duration, 180, 4500) * np.exp(-seconds * 65) * grit
    for index, frequency in enumerate(frequencies):
        result += np.sin(2 * np.pi * frequency * seconds) * np.exp(-seconds * decay * (1 + index * 0.4)) / (index + 1)
    return edges(result, 0.0015)


def footstep(armored, variant):
    duration = 0.3
    seconds = timeline(duration)
    result = impact(duration, [105 + variant * 7, 213, 347], 32, 0.7) * 0.55
    result += noise(duration, 450, 2800) * np.exp(-((seconds - 0.045) / 0.03) ** 2) * 0.08
    if armored:
        metal = impact(0.21, [730 + variant * 23, 1217, 1963, 2871], 29, 0.05) * 0.16
        offset = round(RATE * 0.035)
        result[offset:offset + len(metal)] += metal
    else:
        result += impact(duration, [320, 517, 837], 45, 0.06) * 0.12
    return room(result, 0.1)


def swell(duration, low, high):
    seconds = timeline(duration)
    return edges(noise(duration, low, high) * np.sin(np.pi * seconds / duration) ** 2)


def cues():
    result = {}
    for variant in range(3):
        result[f"step_wood_{variant}"] = footstep(False, variant)
        result[f"step_armor_{variant}"] = footstep(True, variant)
    result["swing"] = room(swell(0.32, 300, 5200) * 0.35, 0.12)
    result["roll"] = room(swell(0.4, 90, 1800) * 0.25 + impact(0.4, [95, 190], 28) * 0.3)
    result["jump"] = room(swell(0.2, 180, 2100) * 0.22)
    result["throw"] = room(swell(0.26, 400, 3700) * 0.27)
    result["capture"] = room(impact(0.7, [94, 147, 236, 393], 13, 0.2) * 0.65, 0.25)
    result["click"] = impact(0.045, [510, 947], 110, 0.15) * 0.3
    result["confirm"] = room(pluck(587.33, 0.3) * 0.3, 0.1)
    result["fuel"] = room(impact(0.34, [187, 341, 593], 25, 0.3) * 0.45, 0.2)
    seconds = timeline(0.75)
    creak = np.sin(2 * np.pi * (180 * seconds + 17 * np.sin(seconds * 19)))
    door = creak * np.exp(-((seconds - 0.26) / 0.16) ** 2) * 0.1 + noise(0.75, 110, 950) * np.sin(np.pi * seconds / 0.75) ** 2 * 0.05
    latch = impact(0.25, [98, 213, 1401], 27, 0.2) * 0.52
    door[round(RATE * 0.45):round(RATE * 0.45) + len(latch)] += latch
    result["door"] = room(door)
    for name, notes, length in [("shrine", [62, 69, 74], 3.4), ("round_start", [50, 57, 62], 3.4), ("round_end", [62, 65, 69, 74], 4.2), ("portal", [38, 50, 57, 62, 69], 5.5)]:
        chord = np.zeros((round(RATE * length), 2))
        for index, note in enumerate(notes):
            sound = room(pluck(440 * 2 ** ((note - 69) / 12)), 0.35)
            mix_at(chord, sound, index * 0.17, 0.27, (index % 2 * 2 - 1) * 0.25)
        if name in ["portal", "shrine"]:
            mix_at(chord, swell(length - 0.1, 120, 1400), 0, 0.035)
        result[name] = edges(chord)
    return result


def write(name, samples, loop=False):
    peak = float(np.max(np.abs(samples)))
    samples = samples * min(1, 0.82 / peak)
    pcm = np.round(samples * 32767).astype(np.int16)
    destination = OUTPUT / (name + (".ogg" if loop else ".wav"))
    if loop:
        with tempfile.NamedTemporaryFile(suffix=".wav") as source:
            wavfile.write(source.name, RATE, pcm)
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", source.name, "-c:a", "libvorbis", "-q:a", "5", str(destination)], check=True)
    else:
        wavfile.write(destination, RATE, pcm)
    return {"duration": round(len(samples) / RATE, 3), "peak_dbfs": round(20 * np.log10(np.max(np.abs(samples))), 2), "rms_dbfs": round(20 * np.log10(np.sqrt(np.mean(samples ** 2))), 2)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--demo", type=Path)
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    score = music()
    atmosphere = ambience()
    effects = cues()
    report = {"castle_music": write("castle_music", score, True), "castle_air": write("castle_air", atmosphere, True)}
    report.update({name: write(name, samples) for name, samples in effects.items()})
    if args.demo:
        demo = score[:RATE * 32].copy() * 10 ** (-15 / 20)
        demo += atmosphere[:len(demo)] * 10 ** (-20 / 20)
        for index in range(12):
            mix_at(demo, effects[f"step_armor_{index % 3}"], 3 + index * 0.43, 0.3, -0.1)
        for name, start in [("door", 9), ("fuel", 11), ("jump", 13), ("roll", 14), ("swing", 16), ("capture", 17), ("shrine", 19), ("portal", 24)]:
            mix_at(demo, effects[name], start, 0.4)
        args.demo.parent.mkdir(parents=True, exist_ok=True)
        wavfile.write(args.demo, RATE, np.round(demo * 32767).astype(np.int16))
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
