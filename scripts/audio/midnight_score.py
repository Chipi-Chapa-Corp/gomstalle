from pathlib import Path
import json

import numpy as np
from scipy import signal
from scipy.io import wavfile


RATE = 48000
DURATION = 38.0
TOTAL_SAMPLES = round(RATE * DURATION)
TRAILER_DURATION = 60.0
ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets/sounds/midnight/midnight.wav"
REPORT = ROOT / ".ci/midnight/audio/generation.json"
TRAILER_OUTPUT = ROOT / "assets/sounds/midnight/midnight_60.wav"
TRAILER_REPORT = ROOT / ".ci/midnight/audio/generation_60.json"
RNG = np.random.default_rng(150926)


def frequency(note):
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


def timeline(duration):
    return np.arange(round(duration * RATE), dtype=np.float64) / RATE


def equal_power_pan(pan):
    bounded_pan = float(np.clip(pan, -1.0, 1.0))
    angle = (bounded_pan + 1.0) * np.pi / 4.0
    return np.array([np.cos(angle), np.sin(angle)])


def edge_fade(samples, attack=0.008, release=0.04):
    result = np.asarray(samples, dtype=np.float64).copy()
    attack_samples = min(round(attack * RATE), len(result) // 2)
    release_samples = min(round(release * RATE), len(result) // 2)
    if attack_samples:
        attack_curve = np.sin(np.linspace(0.0, np.pi / 2.0, attack_samples)) ** 2
        result[:attack_samples] *= attack_curve
    if release_samples:
        release_curve = np.sin(np.linspace(np.pi / 2.0, 0.0, release_samples)) ** 2
        result[-release_samples:] *= release_curve
    return result


def envelope(duration, attack, decay, sustain, release):
    sample_count = round(duration * RATE)
    result = np.ones(sample_count, dtype=np.float64) * sustain
    attack_samples = min(round(attack * RATE), sample_count)
    decay_samples = min(round(decay * RATE), sample_count - attack_samples)
    release_samples = min(round(release * RATE), sample_count)
    if attack_samples:
        result[:attack_samples] = np.sin(np.linspace(0.0, np.pi / 2.0, attack_samples)) ** 2
    decay_start = attack_samples
    decay_end = min(decay_start + decay_samples, sample_count)
    if decay_end > decay_start:
        decay_curve = np.linspace(1.0, sustain, decay_end - decay_start)
        result[decay_start:decay_end] = decay_curve
    if release_samples:
        release_start = max(sample_count - release_samples, 0)
        release_curve = np.sin(np.linspace(np.pi / 2.0, 0.0, sample_count - release_start)) ** 2
        result[release_start:] *= release_curve
    return result


def filtered_noise(duration, low, high):
    samples = RNG.normal(0.0, 1.0, round(duration * RATE))
    filtered = signal.sosfilt(signal.butter(2, [low, high], btype="bandpass", fs=RATE, output="sos"), samples)
    standard_deviation = np.std(filtered)
    return filtered / max(standard_deviation, 1e-9)


def sine_voice(note, duration, harmonics, decay_rates, vibrato=0.0, brightness=1.0):
    seconds = timeline(duration)
    base_frequency = frequency(note)
    vibrato_phase = vibrato * np.sin(2.0 * np.pi * 5.1 * seconds) if vibrato else 0.0
    result = np.zeros_like(seconds)
    for harmonic_index, harmonic_gain in enumerate(harmonics, start=1):
        partial_frequency = base_frequency * harmonic_index
        partial = np.sin(2.0 * np.pi * partial_frequency * seconds + vibrato_phase)
        result += partial * harmonic_gain * np.exp(-seconds * decay_rates[harmonic_index - 1] * brightness)
    return result


def piano_tone(note, duration=1.8, velocity=1.0):
    harmonics = [1.0, 0.47, 0.22, 0.12, 0.067, 0.033, 0.017]
    decay_rates = [0.9, 1.35, 2.1, 3.2, 4.7, 6.2, 8.0]
    result = sine_voice(note, duration, harmonics, decay_rates, brightness=0.92)
    seconds = timeline(duration)
    hammer = filtered_noise(min(duration, 0.095), 1100.0, 6200.0)
    hammer *= np.exp(-timeline(len(hammer) / RATE) * 55.0) * 0.045
    result[:len(hammer)] += hammer
    result *= envelope(duration, 0.002, 0.12, 0.68, min(0.5, duration * 0.38))
    result *= velocity * 0.36
    return edge_fade(result, 0.001, min(0.08, duration * 0.25))


def celesta_tone(note, duration=1.4, velocity=1.0):
    harmonics = [1.0, 0.31, 0.15, 0.075, 0.033, 0.013]
    decay_rates = [2.6, 3.9, 5.7, 7.8, 10.8, 14.5]
    result = sine_voice(note, duration, harmonics, decay_rates, brightness=0.9)
    seconds = timeline(duration)
    base_frequency = frequency(note)
    tine = np.sin(2.0 * np.pi * base_frequency * 2.71 * seconds) * np.exp(-seconds * 5.4) * 0.08
    result += tine
    transient = filtered_noise(min(duration, 0.035), 3000.0, 10500.0)
    transient *= np.exp(-timeline(len(transient) / RATE) * 120.0) * 0.018
    result[:len(transient)] += transient
    result *= envelope(duration, 0.001, 0.04, 0.42, min(0.28, duration * 0.3))
    result *= velocity * 0.33
    return edge_fade(result, 0.0008, min(0.045, duration * 0.2))


def bowed_string(note, duration, velocity=1.0, vibrato=0.004):
    harmonics = [1.0, 0.46, 0.22, 0.105, 0.052, 0.022]
    decay_rates = [0.04, 0.05, 0.07, 0.1, 0.13, 0.17]
    result = sine_voice(note, duration, harmonics, decay_rates, vibrato=vibrato, brightness=0.2)
    seconds = timeline(duration)
    bow_noise = filtered_noise(duration, 160.0, 3400.0)
    bow_noise *= (0.012 + 0.008 * np.sin(2.0 * np.pi * 0.37 * seconds))
    result += bow_noise
    result *= envelope(duration, min(0.72, duration * 0.28), 0.35, 0.82, min(0.85, duration * 0.28))
    result *= velocity * 0.22
    return edge_fade(result, 0.012, min(0.2, duration * 0.2))


def cello_tone(note, duration, velocity=1.0):
    harmonics = [1.0, 0.42, 0.19, 0.095, 0.04]
    decay_rates = [0.04, 0.05, 0.065, 0.09, 0.12]
    result = sine_voice(note, duration, harmonics, decay_rates, vibrato=0.008, brightness=0.16)
    seconds = timeline(duration)
    body = np.sin(2.0 * np.pi * frequency(note) * 0.5 * seconds) * np.exp(-seconds * 0.45) * 0.08
    result += body
    result *= envelope(duration, min(0.22, duration * 0.18), 0.26, 0.84, min(0.66, duration * 0.25))
    result *= velocity * 0.31
    return edge_fade(result, 0.008, min(0.16, duration * 0.17))


def choir_tone(note, duration, velocity=1.0):
    seconds = timeline(duration)
    base_frequency = frequency(note)
    vibrato_phase = 0.007 * np.sin(2.0 * np.pi * 4.6 * seconds)
    formants = [(1.0, 0.62), (2.0, 0.23), (3.0, 0.1), (4.0, 0.045), (5.0, 0.018)]
    result = np.zeros_like(seconds)
    for multiplier, gain in formants:
        result += np.sin(2.0 * np.pi * base_frequency * multiplier * seconds + vibrato_phase) * gain
    breath = filtered_noise(duration, 360.0, 2500.0) * 0.018
    result += breath
    result *= envelope(duration, min(1.05, duration * 0.3), 0.5, 0.72, min(1.1, duration * 0.24))
    result *= velocity * 0.16
    return edge_fade(result, 0.04, min(0.3, duration * 0.18))


def pizzicato(note, duration=0.72, velocity=1.0):
    harmonics = [1.0, 0.44, 0.2, 0.09, 0.04]
    decay_rates = [3.4, 4.2, 5.5, 7.4, 10.0]
    result = sine_voice(note, duration, harmonics, decay_rates, brightness=0.62)
    transient_duration = min(duration, 0.028)
    transient = filtered_noise(transient_duration, 1300.0, 5900.0) * np.exp(-timeline(transient_duration) * 105.0) * 0.023
    result[:len(transient)] += transient
    result *= envelope(duration, 0.001, 0.035, 0.23, min(0.16, duration * 0.3))
    result *= velocity * 0.3
    return edge_fade(result, 0.001, min(0.06, duration * 0.22))


def bell_tone(note, duration=4.4, velocity=1.0):
    seconds = timeline(duration)
    base_frequency = frequency(note)
    partials = [(1.0, 1.7, 1.0), (2.01, 2.35, 0.33), (2.99, 3.15, 0.2), (4.08, 4.15, 0.1), (5.43, 5.1, 0.06), (6.81, 6.4, 0.035)]
    result = np.zeros_like(seconds)
    for multiplier, decay_rate, gain in partials:
        result += np.sin(2.0 * np.pi * base_frequency * multiplier * seconds + multiplier * 0.31) * gain * np.exp(-seconds * decay_rate)
    result *= envelope(duration, 0.001, 0.025, 0.34, min(0.65, duration * 0.18))
    result *= velocity * 0.24
    return edge_fade(result, 0.001, min(0.2, duration * 0.2))


def magic_swell(duration, low_frequency=380.0, high_frequency=2800.0, velocity=1.0):
    seconds = timeline(duration)
    filtered = filtered_noise(duration, 500.0, 6200.0)
    rise = np.sin(np.pi * seconds / duration) ** 1.7
    sweep_phase = 2.0 * np.pi * (low_frequency * seconds + (high_frequency - low_frequency) * seconds ** 2 / (2.0 * duration))
    sweep = np.sin(sweep_phase) * 0.16
    upper_phase = 2.0 * np.pi * (920.0 * seconds + 1800.0 * seconds ** 2 / (2.0 * duration))
    upper = np.sin(upper_phase) * 0.07
    result = (filtered * 0.14 + sweep + upper) * rise
    result *= velocity * 0.35
    return edge_fade(result, 0.04, min(0.25, duration * 0.22))


def armor_impact(duration=0.82, variant=0, velocity=1.0):
    seconds = timeline(duration)
    low_frequency = 64.0 + variant * 5.0
    falling_frequency = low_frequency + 30.0 * np.exp(-seconds * 22.0)
    low_phase = 2.0 * np.pi * np.cumsum(falling_frequency) / RATE
    body = np.sin(low_phase) * np.exp(-seconds * 7.3)
    body += np.sin(low_phase * 1.93) * np.exp(-seconds * 10.5) * 0.28
    metal_frequencies = [510.0 + variant * 31.0, 930.0 + variant * 43.0, 1730.0 + variant * 57.0]
    metal = np.zeros_like(seconds)
    for partial_index, partial_frequency in enumerate(metal_frequencies):
        metal += np.sin(2.0 * np.pi * partial_frequency * seconds) * np.exp(-seconds * (24.0 + partial_index * 5.0)) / (partial_index + 1.0)
    impact_noise = filtered_noise(duration, 90.0, 2600.0) * np.exp(-seconds * 58.0) * 0.23
    result = body * 0.6 + metal * 0.09 + impact_noise
    result *= envelope(duration, 0.0008, 0.032, 0.2, min(0.18, duration * 0.3))
    result *= velocity * 0.34
    return edge_fade(result, 0.001, 0.07)


def book_thump(duration=0.42, velocity=1.0):
    seconds = timeline(duration)
    pitch = 92.0 + 21.0 * np.exp(-seconds * 17.0)
    phase = 2.0 * np.pi * np.cumsum(pitch) / RATE
    body = np.sin(phase) * np.exp(-seconds * 13.0)
    body += np.sin(phase * 2.31) * np.exp(-seconds * 21.0) * 0.18
    paper = filtered_noise(duration, 1500.0, 7200.0) * np.exp(-seconds * 42.0) * 0.11
    result = (body * 0.58 + paper) * envelope(duration, 0.001, 0.02, 0.12, 0.15)
    result *= velocity * 0.3
    return edge_fade(result, 0.001, 0.06)


def page_flutter(duration=0.24):
    seconds = timeline(duration)
    flutter = filtered_noise(duration, 1700.0, 8500.0)
    shape = np.sin(np.pi * seconds / duration) ** 1.6
    result = flutter * shape * 0.08
    return edge_fade(result, 0.006, 0.03)


def room_air(duration):
    seconds = timeline(duration)
    left_air = filtered_noise(duration, 75.0, 720.0)
    right_air = filtered_noise(duration, 90.0, 790.0)
    air_level = 0.012 + 0.004 * np.sin(2.0 * np.pi * seconds / 13.0)
    left_channel = left_air * air_level
    right_channel = right_air * air_level * 0.93
    low_organ = np.sin(2.0 * np.pi * 41.0 * seconds) * 0.0032
    return np.column_stack((left_channel + low_organ, right_channel + low_organ))


def mix_event(dry_bus, send_bus, source, start_seconds, gain, pan=0.0, reverb_amount=0.2):
    start_sample = round(start_seconds * RATE)
    if start_sample >= len(dry_bus):
        return
    if start_sample < 0:
        raise ValueError("events cannot start before zero")
    available_samples = min(len(source), len(dry_bus) - start_sample)
    stereo_gain = equal_power_pan(pan) * gain
    source_slice = source[:available_samples, None]
    dry_bus[start_sample:start_sample + available_samples] += source_slice * stereo_gain
    send_bus[start_sample:start_sample + available_samples] += source_slice * (stereo_gain * reverb_amount)


def add_chord(dry_bus, send_bus, notes, start_seconds, duration, gain, pan_width, instrument, reverb_amount):
    note_count = len(notes)
    for note_index, note in enumerate(notes):
        if note_count == 1:
            pan = 0.0
        else:
            pan = (note_index / (note_count - 1) * 2.0 - 1.0) * pan_width
        mix_event(dry_bus, send_bus, instrument(note, duration), start_seconds, gain, pan, reverb_amount)


def stereo_reverb(send_bus):
    wet_bus = np.zeros_like(send_bus)
    early_taps = [(0.023, 0.31), (0.037, 0.24), (0.061, 0.2), (0.089, 0.17), (0.127, 0.13), (0.181, 0.1)]
    late_taps = [(0.257, 0.13), (0.371, 0.1), (0.523, 0.075), (0.713, 0.055), (0.947, 0.038), (1.283, 0.024)]
    for delay_seconds, gain in early_taps + late_taps:
        delay_samples = round(delay_seconds * RATE)
        delayed_left = np.zeros(len(send_bus), dtype=np.float64)
        delayed_right = np.zeros(len(send_bus), dtype=np.float64)
        delayed_left[delay_samples:] = send_bus[:-delay_samples, 0]
        delayed_right[delay_samples:] = send_bus[:-delay_samples, 1]
        cross_mix = 0.12 if delay_seconds < 0.2 else 0.2
        wet_bus[:, 0] += (delayed_left * (1.0 - cross_mix) + delayed_right * cross_mix) * gain
        wet_bus[:, 1] += (delayed_right * (1.0 - cross_mix) + delayed_left * cross_mix) * gain
    filtered_wet = signal.sosfilt(signal.butter(2, 6200.0, btype="lowpass", fs=RATE, output="sos"), wet_bus, axis=0)
    return filtered_wet


def render_score():
    dry_bus = np.zeros((TOTAL_SAMPLES, 2), dtype=np.float64)
    send_bus = np.zeros_like(dry_bus)
    dry_bus += room_air(DURATION)

    add_chord(dry_bus, send_bus, [50, 57, 60, 64], 0.0, 6.7, 0.52, 0.65, bowed_string, 0.48)
    add_chord(dry_bus, send_bus, [57, 64], 0.0, 6.8, 0.32, 0.45, choir_tone, 0.62)
    mix_event(dry_bus, send_bus, bell_tone(74, 3.8, 0.72), 0.62, 0.32, -0.36, 0.78)
    mix_event(dry_bus, send_bus, piano_tone(62, 2.4, 0.55), 2.35, 0.34, 0.24, 0.62)
    mix_event(dry_bus, send_bus, page_flutter(), 3.64, 0.28, 0.72, 0.76)
    mix_event(dry_bus, send_bus, celesta_tone(69, 1.2, 0.42), 4.48, 0.28, -0.5, 0.67)

    add_chord(dry_bus, send_bus, [46, 53, 57, 60], 6.0, 5.9, 0.55, 0.67, bowed_string, 0.51)
    add_chord(dry_bus, send_bus, [53, 57, 60], 6.25, 5.45, 0.33, 0.58, choir_tone, 0.67)
    discovery_phrase = [(69, 0.0, 0.46), (72, 0.34, 0.46), (74, 0.68, 0.54), (77, 1.06, 0.58), (76, 1.49, 0.46), (74, 1.86, 0.72)]
    for note, offset_seconds, note_duration in discovery_phrase:
        pan = -0.36 + offset_seconds * 0.28
        mix_event(dry_bus, send_bus, celesta_tone(note, note_duration, 0.92), 6.18 + offset_seconds, 0.56, pan, 0.56)
    answer_phrase = [(69, 0.0, 0.46), (72, 0.34, 0.46), (74, 0.68, 0.5), (79, 1.12, 0.92)]
    for note, offset_seconds, note_duration in answer_phrase:
        mix_event(dry_bus, send_bus, celesta_tone(note, note_duration, 0.76), 8.85 + offset_seconds, 0.48, 0.4, 0.6)
    mix_event(dry_bus, send_bus, piano_tone(50, 2.1, 0.56), 8.12, 0.3, -0.25, 0.55)
    mix_event(dry_bus, send_bus, bell_tone(79, 2.55, 0.36), 9.74, 0.22, 0.52, 0.74)

    add_chord(dry_bus, send_bus, [43, 50, 58, 62], 11.0, 5.55, 0.6, 0.62, bowed_string, 0.48)
    add_chord(dry_bus, send_bus, [50, 58, 62], 11.1, 5.25, 0.28, 0.5, choir_tone, 0.67)
    mix_event(dry_bus, send_bus, cello_tone(43, 2.2, 0.88), 11.05, 0.8, -0.12, 0.47)
    mix_event(dry_bus, send_bus, cello_tone(45, 1.7, 0.76), 13.18, 0.72, 0.08, 0.5)
    mix_event(dry_bus, send_bus, cello_tone(38, 2.25, 0.86), 14.78, 0.83, -0.03, 0.5)
    for impact_index, impact_time in enumerate([11.24, 12.83, 14.46]):
        mix_event(dry_bus, send_bus, armor_impact(0.86, impact_index, 0.95), impact_time, 0.78, -0.2 + impact_index * 0.2, 0.64)
    mix_event(dry_bus, send_bus, piano_tone(38, 1.6, 0.62), 11.05, 0.42, -0.26, 0.59)
    mix_event(dry_bus, send_bus, piano_tone(45, 1.4, 0.5), 13.22, 0.35, 0.25, 0.56)
    mix_event(dry_bus, send_bus, bell_tone(62, 2.5, 0.22), 12.16, 0.18, 0.48, 0.72)

    chase_chords = [[50, 57, 62, 65], [46, 53, 57, 60], [43, 50, 55, 58], [45, 52, 57, 61]]
    for chord_index, chord in enumerate(chase_chords):
        chord_time = 16.0 + chord_index * 1.22
        add_chord(dry_bus, send_bus, chord, chord_time, 1.5, 0.42, 0.58, bowed_string, 0.4)
    chase_bursts = [
        (16.08, [62, 65, 69, 72]),
        (17.74, [65, 69, 72, 74]),
        (19.3, [67, 71, 74, 77]),
    ]
    for burst_time, burst_notes in chase_bursts:
        for note_index, note in enumerate(burst_notes):
            mix_event(dry_bus, send_bus, pizzicato(note, 0.66, 0.82), burst_time + note_index * 0.24, 0.57, -0.38 + note_index * 0.26, 0.39)
    for note_time, note in [(16.0, 50), (16.94, 53), (18.42, 43), (19.54, 45), (20.26, 52)]:
        mix_event(dry_bus, send_bus, piano_tone(note, 1.0, 0.64), note_time, 0.36, -0.18, 0.42)
    for knock_time, knock_gain in [(16.72, 0.34), (18.12, 0.31), (19.64, 0.34), (20.42, 0.27)]:
        mix_event(dry_bus, send_bus, book_thump(0.28, 0.72), knock_time, knock_gain, 0.46, 0.32)
    mix_event(dry_bus, send_bus, magic_swell(1.55, 410.0, 2200.0, 0.8), 20.24, 0.65, 0.0, 0.72)

    activation_chords = [
        (21.0, [46, 53, 57, 60, 65]),
        (22.45, [48, 55, 60, 64, 69]),
        (23.9, [41, 48, 53, 57, 64]),
        (25.25, [45, 52, 57, 61, 67]),
    ]
    for chord_index, (chord_time, chord) in enumerate(activation_chords):
        intensity = 0.56 + chord_index * 0.09
        add_chord(dry_bus, send_bus, chord, chord_time, 1.95, intensity, 0.78, bowed_string, 0.63)
        add_chord(dry_bus, send_bus, chord[1:], chord_time + 0.08, 1.8, 0.28 + chord_index * 0.03, 0.76, choir_tone, 0.77)
    for shimmer_time, shimmer_notes in [(21.38, [74, 81]), (22.6, [77, 84]), (24.08, [76, 81, 88]), (25.36, [79, 84, 88])]:
        for note_index, note in enumerate(shimmer_notes):
            mix_event(dry_bus, send_bus, celesta_tone(note, 1.45, 0.76), shimmer_time + note_index * 0.14, 0.38, -0.62 + note_index * 0.6, 0.78)
    mix_event(dry_bus, send_bus, magic_swell(2.2, 470.0, 3200.0, 0.95), 21.05, 0.48, -0.12, 0.9)
    mix_event(dry_bus, send_bus, magic_swell(1.15, 850.0, 4100.0, 0.75), 25.56, 0.35, 0.34, 0.92)
    mix_event(dry_bus, send_bus, bell_tone(86, 2.8, 0.56), 25.76, 0.34, 0.4, 0.86)

    add_chord(dry_bus, send_bus, [41, 48, 53, 57, 60], 27.0, 5.45, 0.42, 0.74, bowed_string, 0.56)
    escape_bursts = [
        (27.08, [69, 72, 76]),
        (28.95, [72, 76, 79]),
        (30.42, [74, 77, 81]),
    ]
    for burst_time, burst_notes in escape_bursts:
        for note_index, note in enumerate(burst_notes):
            mix_event(dry_bus, send_bus, pizzicato(note, 0.52, 0.7), burst_time + note_index * 0.19, 0.48, 0.52 - note_index * 0.34, 0.43)
    for bass_time, bass_note in [(27.03, 41), (28.02, 45), (29.08, 43), (30.04, 48), (31.0, 41)]:
        mix_event(dry_bus, send_bus, piano_tone(bass_note, 0.78, 0.58), bass_time, 0.32, -0.34, 0.4)
    for tap_index, tap_time in enumerate([27.62, 28.18, 29.52, 30.23, 31.18]):
        mix_event(dry_bus, send_bus, book_thump(0.24, 0.6), tap_time, 0.24 + tap_index % 2 * 0.05, 0.62 if tap_index % 2 else -0.58, 0.34)
    mix_event(dry_bus, send_bus, book_thump(0.58, 1.0), 28.5, 1.0, 0.0, 0.68)
    mix_event(dry_bus, send_bus, magic_swell(0.72, 520.0, 2550.0, 0.5), 28.55, 0.27, 0.18, 0.83)
    mix_event(dry_bus, send_bus, celesta_tone(88, 0.92, 0.62), 29.24, 0.31, 0.55, 0.67)

    final_chords = [
        (32.0, [43, 50, 53, 58, 62]),
        (33.45, [48, 55, 58, 62, 67]),
        (35.0, [41, 48, 53, 57, 60, 64, 67]),
    ]
    for chord_index, (chord_time, chord) in enumerate(final_chords):
        duration = 1.9 if chord_index < 2 else 3.0
        gain = 0.52 if chord_index < 2 else 0.66
        add_chord(dry_bus, send_bus, chord, chord_time, duration, gain, 0.72, bowed_string, 0.68)
        if chord_index == 2:
            add_chord(dry_bus, send_bus, chord[2:], chord_time + 0.06, 2.8, 0.3, 0.7, choir_tone, 0.82)
    title_motif = [(69, 0.0, 0.52), (72, 0.38, 0.56), (74, 0.8, 0.58), (77, 1.2, 0.7), (76, 1.76, 0.56), (74, 2.2, 0.98)]
    for note, offset_seconds, note_duration in title_motif:
        mix_event(dry_bus, send_bus, celesta_tone(note, note_duration, 0.68), 32.18 + offset_seconds, 0.36, -0.36 + offset_seconds * 0.26, 0.67)
    for note_index, note in enumerate([41, 48, 57, 60, 64, 67]):
        mix_event(dry_bus, send_bus, piano_tone(note, 3.0, 0.56), 35.08 + note_index * 0.033, 0.2, -0.46 + note_index * 0.18, 0.63)
    mix_event(dry_bus, send_bus, bell_tone(77, 3.25, 0.86), 35.24, 0.68, 0.24, 0.92)
    mix_event(dry_bus, send_bus, bell_tone(84, 2.25, 0.34), 35.86, 0.26, -0.4, 0.94)

    score = dry_bus + stereo_reverb(send_bus)
    score = signal.sosfilt(signal.butter(2, 28.0, btype="highpass", fs=RATE, output="sos"), score, axis=0)
    score = np.tanh(score * 1.08) / 1.08
    score[:round(0.025 * RATE)] *= (np.sin(np.linspace(0.0, np.pi / 2.0, round(0.025 * RATE))) ** 2)[:, None]
    fade_start = round(36.65 * RATE)
    fade_curve = np.sin(np.linspace(np.pi / 2.0, 0.0, TOTAL_SAMPLES - fade_start)) ** 1.35
    score[fade_start:] *= fade_curve[:, None]
    sample_peak = float(np.max(np.abs(score)))
    score *= min(1.0, 10.0 ** (-1.55 / 20.0) / sample_peak)
    return score


def render_trailer_score():
    trailer_samples = round(TRAILER_DURATION * RATE)
    dry_bus = np.zeros((trailer_samples, 2), dtype=np.float64)
    send_bus = np.zeros_like(dry_bus)
    dry_bus += room_air(TRAILER_DURATION)

    add_chord(dry_bus, send_bus, [50, 57, 60, 64], 0.0, 8.7, 0.42, 0.65, bowed_string, 0.5)
    add_chord(dry_bus, send_bus, [57, 64], 0.0, 8.6, 0.25, 0.46, choir_tone, 0.62)
    mix_event(dry_bus, send_bus, bell_tone(74, 4.0, 0.68), 0.72, 0.28, -0.38, 0.8)
    mix_event(dry_bus, send_bus, piano_tone(62, 2.35, 0.46), 2.55, 0.3, 0.2, 0.62)
    mix_event(dry_bus, send_bus, page_flutter(), 4.02, 0.25, 0.68, 0.76)
    mix_event(dry_bus, send_bus, celesta_tone(69, 1.25, 0.36), 5.48, 0.24, -0.48, 0.69)
    mix_event(dry_bus, send_bus, page_flutter(), 6.68, 0.18, -0.58, 0.8)

    plan_chords = [
        (8.0, [46, 53, 57, 60]),
        (10.18, [43, 50, 55, 58]),
        (12.36, [45, 52, 57, 61]),
        (14.54, [50, 57, 62, 65]),
    ]
    for chord_time, chord in plan_chords:
        add_chord(dry_bus, send_bus, chord, chord_time, 2.48, 0.47, 0.6, bowed_string, 0.47)
    add_chord(dry_bus, send_bus, [53, 57, 60], 8.16, 7.95, 0.22, 0.58, choir_tone, 0.67)
    plan_phrases = [
        (8.24, [(69, 0.0), (72, 0.38), (74, 0.76), (76, 1.2), (74, 1.72)]),
        (11.18, [(67, 0.0), (69, 0.42), (72, 0.86), (74, 1.34)]),
        (14.72, [(69, 0.0), (72, 0.4), (76, 0.84), (79, 1.4)]),
    ]
    for phrase_time, phrase in plan_phrases:
        for note_index, (note, offset_seconds) in enumerate(phrase):
            instrument = piano_tone if note_index == len(phrase) - 1 else celesta_tone
            note_duration = 1.0 if instrument is piano_tone else 0.62
            mix_event(dry_bus, send_bus, instrument(note, note_duration, 0.78), phrase_time + offset_seconds, 0.42, -0.42 + note_index * 0.26, 0.55)
    mix_event(dry_bus, send_bus, piano_tone(50, 2.0, 0.48), 9.58, 0.25, -0.24, 0.54)
    mix_event(dry_bus, send_bus, piano_tone(45, 1.95, 0.5), 13.82, 0.28, 0.2, 0.54)
    mix_event(dry_bus, send_bus, bell_tone(79, 2.8, 0.32), 16.08, 0.2, 0.46, 0.78)

    chair_chords = [
        (17.0, [50, 57, 62, 65]),
        (19.18, [46, 53, 57, 60]),
        (21.36, [43, 50, 55, 58]),
        (23.54, [45, 52, 57, 61]),
    ]
    for chord_time, chord in chair_chords:
        add_chord(dry_bus, send_bus, chord, chord_time, 2.45, 0.4, 0.57, bowed_string, 0.43)
    chair_bursts = [
        (17.25, [62, 65, 69, 72]),
        (19.76, [65, 69, 72, 74]),
        (22.25, [67, 71, 74, 77]),
        (24.56, [69, 72, 76, 79]),
    ]
    for burst_time, burst_notes in chair_bursts:
        for note_index, note in enumerate(burst_notes):
            mix_event(dry_bus, send_bus, pizzicato(note, 0.62, 0.78), burst_time + note_index * 0.255, 0.46, -0.42 + note_index * 0.28, 0.42)
    for bass_time, bass_note in [(17.04, 50), (19.22, 46), (21.4, 43), (23.58, 45), (25.0, 52)]:
        mix_event(dry_bus, send_bus, piano_tone(bass_note, 0.95, 0.54), bass_time, 0.3, -0.18, 0.43)
    for tap_index, tap_time in enumerate([18.44, 20.62, 22.74, 24.86]):
        mix_event(dry_bus, send_bus, book_thump(0.27, 0.66), tap_time, 0.25 + tap_index % 2 * 0.05, 0.58 if tap_index % 2 else -0.58, 0.35)
    mix_event(dry_bus, send_bus, magic_swell(1.25, 390.0, 1650.0, 0.48), 25.22, 0.32, 0.08, 0.72)

    chase_chords = [
        (26.0, [50, 57, 62, 65]),
        (27.78, [46, 53, 57, 60]),
        (29.56, [43, 50, 55, 58]),
        (31.34, [45, 52, 57, 61]),
        (33.12, [41, 48, 53, 57]),
    ]
    for chord_index, (chord_time, chord) in enumerate(chase_chords):
        add_chord(dry_bus, send_bus, chord, chord_time, 2.12, 0.42 + chord_index * 0.025, 0.63, bowed_string, 0.46)
    chase_bursts = [
        (26.14, [62, 65, 69, 72]),
        (28.06, [65, 69, 72, 74]),
        (29.98, [67, 71, 74, 77]),
        (31.9, [69, 72, 76, 79]),
        (33.66, [71, 74, 77, 81]),
    ]
    for burst_time, burst_notes in chase_bursts:
        for note_index, note in enumerate(burst_notes):
            mix_event(dry_bus, send_bus, pizzicato(note, 0.54, 0.82), burst_time + note_index * 0.22, 0.53, -0.42 + note_index * 0.28, 0.42)
    for bass_time, bass_note in [(26.03, 50), (27.82, 46), (29.6, 43), (31.38, 45), (33.16, 41), (34.1, 48)]:
        mix_event(dry_bus, send_bus, piano_tone(bass_note, 0.82, 0.6), bass_time, 0.35, -0.24, 0.43)
    for tap_index, tap_time in enumerate([26.78, 28.72, 30.65, 32.54, 34.3]):
        mix_event(dry_bus, send_bus, book_thump(0.23, 0.62), tap_time, 0.22 + tap_index % 2 * 0.04, 0.55 if tap_index % 2 else -0.55, 0.34)
    mix_event(dry_bus, send_bus, magic_swell(1.7, 430.0, 2250.0, 0.78), 33.98, 0.5, 0.0, 0.75)

    shrine_chords = [
        (35.0, [43, 50, 53, 58, 62]),
        (37.42, [46, 53, 57, 60, 65]),
        (39.84, [48, 55, 60, 64, 69]),
        (42.26, [41, 48, 53, 57, 64]),
    ]
    for chord_index, (chord_time, chord) in enumerate(shrine_chords):
        add_chord(dry_bus, send_bus, chord, chord_time, 2.95, 0.51 + chord_index * 0.04, 0.76, bowed_string, 0.64)
        add_chord(dry_bus, send_bus, chord[1:], chord_time + 0.08, 2.7, 0.25 + chord_index * 0.03, 0.72, choir_tone, 0.77)
    for bell_index, (bell_time, note) in enumerate([(35.34, 74), (37.88, 79), (40.34, 81), (42.78, 86)]):
        mix_event(dry_bus, send_bus, bell_tone(note, 3.25, 0.5 + bell_index * 0.07), bell_time, 0.3 + bell_index * 0.04, -0.42 + bell_index * 0.28, 0.88)
    shrine_motif = [(69, 0.0), (72, 0.43), (74, 0.86), (77, 1.31), (76, 1.78), (74, 2.24)]
    for note, offset_seconds in shrine_motif:
        mix_event(dry_bus, send_bus, celesta_tone(note, 0.8, 0.7), 36.02 + offset_seconds, 0.32, -0.4 + offset_seconds * 0.26, 0.72)
    mix_event(dry_bus, send_bus, magic_swell(1.55, 540.0, 3200.0, 0.6), 43.18, 0.36, 0.18, 0.88)

    portal_chords = [
        (45.0, [46, 53, 57, 60, 65]),
        (47.0, [48, 55, 60, 64, 69]),
        (49.0, [41, 48, 53, 57, 64]),
        (51.0, [45, 52, 57, 61, 67]),
    ]
    for chord_index, (chord_time, chord) in enumerate(portal_chords):
        add_chord(dry_bus, send_bus, chord, chord_time, 2.45, 0.58 + chord_index * 0.06, 0.8, bowed_string, 0.71)
        add_chord(dry_bus, send_bus, chord[1:], chord_time + 0.1, 2.2, 0.27 + chord_index * 0.04, 0.78, choir_tone, 0.83)
    for shimmer_time, shimmer_notes in [(45.26, [74, 81]), (46.28, [77, 84]), (48.12, [76, 81, 88]), (49.84, [79, 84, 88]), (51.24, [81, 86, 91])]:
        for note_index, note in enumerate(shimmer_notes):
            mix_event(dry_bus, send_bus, celesta_tone(note, 1.35, 0.8), shimmer_time + note_index * 0.16, 0.38, -0.64 + note_index * 0.62, 0.84)
    mix_event(dry_bus, send_bus, magic_swell(3.2, 420.0, 3550.0, 0.96), 44.74, 0.58, -0.1, 0.92)
    mix_event(dry_bus, send_bus, magic_swell(1.5, 900.0, 4500.0, 0.76), 50.74, 0.36, 0.36, 0.94)
    mix_event(dry_bus, send_bus, bell_tone(86, 3.0, 0.66), 50.86, 0.38, 0.38, 0.9)

    title_chords = [
        (53.0, [43, 50, 53, 58, 62]),
        (54.5, [48, 55, 58, 62, 67]),
        (56.0, [41, 48, 53, 57, 60, 64, 67]),
    ]
    for chord_index, (chord_time, chord) in enumerate(title_chords):
        duration = 2.05 if chord_index < 2 else 4.0
        gain = 0.48 if chord_index < 2 else 0.66
        add_chord(dry_bus, send_bus, chord, chord_time, duration, gain, 0.74, bowed_string, 0.7)
        if chord_index == 2:
            add_chord(dry_bus, send_bus, chord[2:], chord_time + 0.06, 3.8, 0.31, 0.72, choir_tone, 0.84)
    title_motif = [(69, 0.0, 0.56), (72, 0.42, 0.6), (74, 0.88, 0.62), (77, 1.35, 0.76), (76, 1.92, 0.62), (74, 2.4, 1.02)]
    for note, offset_seconds, note_duration in title_motif:
        mix_event(dry_bus, send_bus, celesta_tone(note, note_duration, 0.68), 53.22 + offset_seconds, 0.34, -0.4 + offset_seconds * 0.24, 0.7)
    for note_index, note in enumerate([41, 48, 57, 60, 64, 67]):
        mix_event(dry_bus, send_bus, piano_tone(note, 3.8, 0.55), 56.08 + note_index * 0.035, 0.21, -0.46 + note_index * 0.18, 0.66)
    mix_event(dry_bus, send_bus, bell_tone(77, 3.65, 0.9), 56.22, 0.68, 0.22, 0.94)
    mix_event(dry_bus, send_bus, bell_tone(84, 2.6, 0.38), 56.96, 0.26, -0.42, 0.95)

    score = dry_bus + stereo_reverb(send_bus)
    score = signal.sosfilt(signal.butter(2, 28.0, btype="highpass", fs=RATE, output="sos"), score, axis=0)
    score = np.tanh(score * 1.08) / 1.08
    fade_in_samples = round(0.025 * RATE)
    score[:fade_in_samples] *= (np.sin(np.linspace(0.0, np.pi / 2.0, fade_in_samples)) ** 2)[:, None]
    fade_start = round(58.0 * RATE)
    fade_curve = np.sin(np.linspace(np.pi / 2.0, 0.0, trailer_samples - fade_start)) ** 1.35
    score[fade_start:] *= fade_curve[:, None]
    sample_peak = float(np.max(np.abs(score)))
    score *= min(1.0, 10.0 ** (-1.55 / 20.0) / sample_peak)
    return score


def true_peak(samples):
    oversampled = signal.resample_poly(samples, 4, 1, axis=0)
    return float(np.max(np.abs(oversampled)))


def write_output(score, destination, report_path):
    destination.parent.mkdir(parents=True, exist_ok=True)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    peak = float(np.max(np.abs(score)))
    oversampled_peak = true_peak(score)
    if oversampled_peak > 10.0 ** (-1.15 / 20.0):
        score *= 10.0 ** (-1.35 / 20.0) / oversampled_peak
        peak = float(np.max(np.abs(score)))
        oversampled_peak = true_peak(score)
    pcm = np.round(np.clip(score, -1.0, 1.0) * 32767.0).astype(np.int16)
    wavfile.write(destination, RATE, pcm)
    report = {
        "path": str(destination),
        "sample_rate": RATE,
        "channels": 2,
        "samples": int(len(pcm)),
        "duration_seconds": len(pcm) / RATE,
        "sample_peak_dbfs": 20.0 * np.log10(max(peak, 1e-12)),
        "true_peak_dbtp": 20.0 * np.log10(max(oversampled_peak, 1e-12)),
        "rms_dbfs": 20.0 * np.log10(max(float(np.sqrt(np.mean(score ** 2))), 1e-12)),
        "finite_samples": bool(np.isfinite(score).all()),
        "clipped_samples": int(np.count_nonzero(np.abs(pcm) >= 32767)),
    }
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


def main():
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--duration", choices=["38", "60", "both"], default="38")
    arguments = parser.parse_args()
    if arguments.duration in ["38", "both"]:
        write_output(render_score(), OUTPUT, REPORT)
    if arguments.duration in ["60", "both"]:
        write_output(render_trailer_score(), TRAILER_OUTPUT, TRAILER_REPORT)


if __name__ == "__main__":
    main()
