#!/usr/bin/env python3
"""Generate short original WAV alarm tones; no third-party audio is bundled."""
import math
import os
import struct
import wave

ROOT = os.path.join(os.path.dirname(__file__), "..", "App", "Resources")
os.makedirs(ROOT, exist_ok=True)
RATE = 44100

def write_tone(filename, notes, duration=4.0):
    frames = int(RATE * duration)
    with wave.open(os.path.join(ROOT, filename), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        data = bytearray()
        for i in range(frames):
            t = i / RATE
            envelope = min(1.0, t / 0.025, (duration - t) / 0.18)
            sample = 0.0
            for start, length, freq, gain in notes:
                local = t - start
                if 0 <= local <= length:
                    fade = min(1.0, local / 0.012, (length - local) / 0.12)
                    sample += gain * fade * math.sin(2 * math.pi * freq * local)
                    sample += gain * 0.18 * fade * math.sin(2 * math.pi * freq * 2.01 * local)
            value = int(max(-1.0, min(1.0, sample * envelope * 0.65)) * 32767)
            data.extend(struct.pack("<h", value))
        out.writeframes(data)

# Original synthesized tones. These are not recordings or copies of existing melodies.
write_tone("GentleChime.wav", [(0.0, 1.1, 880, 0.38), (0.32, 1.2, 1174.66, 0.3), (0.66, 1.35, 1396.91, 0.24)], 2.4)
write_tone("SunriseSequence.wav", [(0.0, 0.55, 523.25, 0.36), (0.48, 0.55, 659.25, 0.34), (0.96, 0.65, 783.99, 0.32), (1.52, 0.95, 1046.5, 0.3)], 2.8)
write_tone("ClassicWake.wav", [(0.0, 0.42, 880, 0.34), (0.58, 0.42, 880, 0.34), (1.16, 0.42, 1046.5, 0.34), (1.74, 0.42, 880, 0.34), (2.32, 0.65, 1046.5, 0.34)], 3.2)
print("Generated original tones:", ", ".join(sorted(os.listdir(ROOT))))
