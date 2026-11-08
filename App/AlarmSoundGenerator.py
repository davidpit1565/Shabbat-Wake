#!/usr/bin/env python3
"""Generate original short WAV tones for Shabbat Wake; no third-party audio."""
import array, glob, math, os, shutil, struct, subprocess, tempfile, wave
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

# ---------------------------------------------------------------------------
# Sounds from App/SoundSources (CC0, see LICENSES.md). Each one is looped to the ring length, with a short gap
# between repeats, and written in the same file families as the original tones.
# ---------------------------------------------------------------------------
SOURCES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "SoundSources")
MULAW_TABLE = bytes(mulaw(v) for v in range(-32768, 32768))   # index = sample + 32768
SILENCE_BYTE = mulaw(0)

def find_tool(name):
    for candidate in (shutil.which(name), "/opt/homebrew/bin/" + name, "/usr/local/bin/" + name):
        if candidate and os.path.exists(candidate):
            return candidate
    return None

def decode_mono(path, rate):
    """The file as signed 16-bit mono samples at `rate`, using ffmpeg, or afconvert (macOS) if there is no ffmpeg."""
    ffmpeg = find_tool("ffmpeg")
    if ffmpeg:
        out = subprocess.run([ffmpeg, "-v", "error", "-i", path, "-ac", "1", "-ar", str(rate), "-f", "s16le", "-"],
                             stdout=subprocess.PIPE, check=True).stdout
        samples = array.array("h"); samples.frombytes(out)
        return samples
    afconvert = find_tool("afconvert")
    if not afconvert:
        raise RuntimeError("Need ffmpeg or afconvert to read " + path)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "decoded.wav")
        subprocess.run([afconvert, "-f", "WAVE", "-d", "LEI16@%d" % rate, "-c", "1", path, wav], check=True)
        with wave.open(wav, "rb") as reader:
            samples = array.array("h"); samples.frombytes(reader.readframes(reader.getnframes()))
            return samples

def looped(clip, rate, seconds):
    """The clip repeated until `seconds`, with a gap after each copy (longer for very short clips), ending on a short fade."""
    gap = int(rate * (1.6 if len(clip) < rate * 5 else 0.8))
    unit = array.array("h", clip) + array.array("h", [0]) * gap
    total = int(rate * seconds)
    out = (unit * (total // len(unit) + 1))[:total]
    fade = min(int(rate * 0.3), total)
    for i in range(fade):
        out[total - 1 - i] = int(out[total - 1 - i] * (i / float(fade)))
    return out

def write_source_loop(filename, clip8k, seconds, rate=8000):
    samples = looped(clip8k, rate, seconds)
    data = bytes(MULAW_TABLE[v + 32768] for v in samples) + bytes([SILENCE_BYTE]) * (rate * TAIL_SECONDS - len(samples))
    with open(os.path.join(ROOT, filename), "wb") as out:
        fmt = struct.pack('<HHIIHHH', 7, 1, rate, rate, 1, 8, 0)
        fact = struct.pack('<I', len(data))
        body = b'WAVE' + b'fmt ' + struct.pack('<I', len(fmt)) + fmt + b'fact' + struct.pack('<I', len(fact)) + fact + b'data' + struct.pack('<I', len(data)) + data
        out.write(b'RIFF' + struct.pack('<I', len(body)) + body)

def write_source_pcm(filename, clip, rate, seconds):
    samples = looped(clip, rate, seconds)
    with wave.open(os.path.join(ROOT, filename), "wb") as out:
        out.setnchannels(1); out.setsampwidth(2); out.setframerate(rate)
        out.writeframes(samples.tobytes() if hasattr(samples, "tobytes") else samples.tostring())

def generate_sources():
    names = []
    script_time = os.path.getmtime(os.path.abspath(__file__))
    for path in sorted(glob.glob(os.path.join(SOURCES, "*.mp3")) + glob.glob(os.path.join(SOURCES, "*.wav"))):
        name = os.path.splitext(os.path.basename(path))[0]
        names.append(name)
        marker = os.path.join(ROOT, name + "_n29s.wav")
        if os.path.exists(marker) and os.path.getmtime(marker) > max(os.path.getmtime(path), script_time):
            continue   # already up to date
        clip22 = decode_mono(path, 22050)
        clip8 = decode_mono(path, 8000)
        # Plain preview for the sound library (22.05 kHz, the clip once).
        write_source_pcm(name + ".wav", clip22, 22050, len(clip22) / 22050.0)
        for seconds in (10, 15, 20, 30, 40, 50):
            write_source_loop("%s_%ds.wav" % (name, seconds), clip8, seconds)
        for label, seconds in (('n10', 10), ('n15', 15), ('n20', 20), ('n29', 29.5)):
            write_source_pcm("%s_%ss.wav" % (name, label), clip22, 22050, seconds)
    return names

sourced = generate_sources()
print('Generated %d sounds from App/SoundSources.' % len(sourced))
