#!/usr/bin/env python3
"""Generate original short WAV tones for Shabbat Wake; no third-party audio."""
import math, os, struct, wave
ROOT = os.path.join(os.path.dirname(__file__), "Resources")
os.makedirs(ROOT, exist_ok=True)
RATE = 44100

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

write_tone('GentleChime.wav',[(0,1.1,880,.38),(.32,1.2,1174.66,.3),(.66,1.35,1396.91,.24)],2.4)
write_tone('SunriseSequence.wav',[(0,.55,523.25,.36),(.48,.55,659.25,.34),(.96,.65,783.99,.32),(1.52,.95,1046.5,.3)],2.8)
write_tone('ClassicWake.wav',[(0,.42,880,.34),(.58,.42,880,.34),(1.16,.42,1046.5,.34),(1.74,.42,880,.34),(2.32,.65,1046.5,.34)],3.2)
print('Generated three original alarm tones.')
