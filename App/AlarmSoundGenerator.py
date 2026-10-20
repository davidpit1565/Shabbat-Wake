#!/usr/bin/env python3
"""Generate original short WAV tones for Shabbat Wake; no third-party audio."""
import math, os, struct, wave
ROOT = os.path.join(os.path.dirname(__file__), "Resources")
os.makedirs(ROOT, exist_ok=True)
RATE = 44100

def tone_bytes(notes, duration, rate=RATE):
    frames = int(rate * duration)
    data = bytearray()
    for i in range(frames):
        t=i/rate; env=min(1.0,t/.025,(duration-t)/.18); sample=0.0
        for start,length,freq,gain in notes:
            local=t-start
            if 0 <= local <= length:
                fade=min(1.0,local/.012,(length-local)/.12)
                sample += gain*fade*math.sin(2*math.pi*freq*local)
                sample += gain*.18*fade*math.sin(2*math.pi*freq*2.01*local)
        data.extend(struct.pack('<h',int(max(-1.0,min(1.0,sample*env*.65))*32767)))
    return bytes(data)

def mulaw(sample):
    """G.711 mu-law for one signed 16-bit sample."""
    BIAS, CLIP = 0x84, 32635
    sign = 0x80 if sample < 0 else 0
    sample = min(abs(sample), CLIP) + BIAS
    exponent = 7
    mask = 0x4000
    while exponent > 0 and not (sample & mask):
        exponent -= 1
        mask >>= 1
    mantissa = (sample >> (exponent + 3)) & 0x0F
    return (~(sign | (exponent << 4) | mantissa)) & 0xFF

TAIL_SECONDS = 300

def write_loop(filename, notes, duration, seconds, rate=8000):
    """The alarm tone repeated for `seconds`, then silence up to five minutes.
    The system alarm repeats its sound file until someone stops it, and gives no way to stop it by itself.
    A file that goes quiet after the chosen time is how the sound ends by itself."""
    pcm = tone_bytes(notes, duration, rate) + bytes(int(rate * 0.5) * 2)
    unit = [struct.unpack_from('<h', pcm, i)[0] for i in range(0, len(pcm), 2)]
    tone_samples = int(rate * seconds)
    samples = (unit * (tone_samples // len(unit) + 1))[:tone_samples]
    samples += [0] * (rate * TAIL_SECONDS - len(samples))
    data = bytes(mulaw(v) for v in samples)
    with open(os.path.join(ROOT, filename), "wb") as out:
        fmt = struct.pack('<HHIIHHH', 7, 1, rate, rate, 1, 8, 0)
        fact = struct.pack('<I', len(data))
        body = b'WAVE' + b'fmt ' + struct.pack('<I', len(fmt)) + fmt + b'fact' + struct.pack('<I', len(fact)) + fact + b'data' + struct.pack('<I', len(data)) + data
        out.write(b'RIFF' + struct.pack('<I', len(body)) + body)

def write_notification(filename, notes, duration, seconds, rate=22050):
    """The tone repeated for `seconds` and then it ends. Notification sounds must be under 30 seconds, and a notification
    plays its sound once, so this is how a Shabbat alarm stops by itself."""
    unit = tone_bytes(notes, duration, rate) + bytes(int(rate * 0.5) * 2)
    total = int(rate * seconds) * 2
    data = (unit * (total // len(unit) + 1))[:total]
    with wave.open(os.path.join(ROOT, filename), "wb") as out:
        out.setnchannels(1); out.setsampwidth(2); out.setframerate(rate)
        out.writeframes(data)

def write_tone(filename, notes, duration):
    frames = int(RATE * duration)
    with wave.open(os.path.join(ROOT, filename), "wb") as out:
        out.setnchannels(1); out.setsampwidth(2); out.setframerate(RATE)
        data = bytearray()
        for i in range(frames):
            t=i/RATE; env=min(1.0,t/.025,(duration-t)/.18); sample=0.0
            for start,length,freq,gain in notes:
                local=t-start
                if 0 <= local <= length:
                    fade=min(1.0,local/.012,(length-local)/.12)
                    sample += gain*fade*math.sin(2*math.pi*freq*local)
                    sample += gain*.18*fade*math.sin(2*math.pi*freq*2.01*local)
            data.extend(struct.pack('<h',int(max(-1.0,min(1.0,sample*env*.65))*32767)))
        out.writeframes(data)

TONES = {
    'GentleChime': ([(0,1.1,880,.38),(.32,1.2,1174.66,.3),(.66,1.35,1396.91,.24)], 2.4),
    'SunriseSequence': ([(0,.55,523.25,.36),(.48,.55,659.25,.34),(.96,.65,783.99,.32),(1.52,.95,1046.5,.3)], 2.8),
    'ClassicWake': ([(0,.42,880,.34),(.58,.42,880,.34),(1.16,.42,1046.5,.34),(1.74,.42,880,.34),(2.32,.65,1046.5,.34)], 3.2),
}
for name, (notes, length) in TONES.items():
    write_tone(name + '.wav', notes, length)
    for seconds in (10, 15, 20, 30, 40, 50):
        write_loop('%s_%ds.wav' % (name, seconds), notes, length, seconds)
    # Notification pieces: 10, 15, 20 and 29.5 seconds ("n29"); 40 and 50 seconds are two pieces one after the other.
    for label, seconds in (('n10', 10), ('n15', 15), ('n20', 20), ('n29', 29.5)):
        write_notification('%s_%ss.wav' % (name, label), notes, length, seconds)
print('Generated three original alarm tones, each also as 10 to 50 second versions.')
