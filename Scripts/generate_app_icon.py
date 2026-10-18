#!/usr/bin/env python3
"""Generates the 1024x1024 App Store icon (opaque RGB, no alpha) into the asset catalog.

Re-run after editing: python3 Scripts/generate_app_icon.py
Requires Pillow (pip install pillow).
"""
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SS = 2  # supersampling factor
OUT = Path(__file__).resolve().parent.parent / "App/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

NAVY_TOP = (14, 32, 66)
NAVY_BOTTOM = (5, 12, 26)
CYAN = (89, 230, 255)
BLUE = (40, 116, 255)
SILVER = (201, 216, 236)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def background(n):
    img = Image.new("RGB", (n, n))
    px = img.load()
    for y in range(n):
        row = lerp(NAVY_TOP, NAVY_BOTTOM, y / (n - 1))
        for x in range(n):
            px[x, y] = row
    glow = Image.new("RGB", (n, n), (0, 0, 0))
    ImageDraw.Draw(glow).ellipse((n * 0.15, n * 0.05, n * 0.85, n * 0.75), fill=(18, 60, 130))
    glow = glow.filter(ImageFilter.GaussianBlur(n * 0.12))
    return Image.blend(img, Image.composite(glow, img, glow.convert("L")), 0.55)


def main():
    n = SIZE * SS
    c = n / 2
    img = background(n)

    # thin silver outer ring
    ring = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(ring)
    r = n * 0.355
    d.ellipse((c - r, c - r, c + r, c + r), outline=SILVER + (70,), width=int(n * 0.006))
    ticks = ImageDraw.Draw(ring)
    for i in range(60):
        a = math.radians(i * 6 - 90)
        long = i % 5 == 0
        r0, r1 = n * (0.318 if long else 0.328), n * 0.338
        ticks.line((c + r0 * math.cos(a), c + r0 * math.sin(a), c + r1 * math.cos(a), c + r1 * math.sin(a)),
                   fill=SILVER + ((120 if long else 55),), width=int(n * (0.005 if long else 0.003)))
    img = Image.alpha_composite(img.convert("RGBA"), ring)

    # soft warm glow where the sun meets the horizon
    warm = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    hy = c + n * 0.055
    ImageDraw.Draw(warm).ellipse((c - n * 0.24, hy - n * 0.09, c + n * 0.24, hy + n * 0.09), fill=(255, 176, 96, 150))
    img = Image.alpha_composite(img, warm.filter(ImageFilter.GaussianBlur(n * 0.04)))

    # luminous progress arc (cyan -> blue), starting top, sweeping clockwise
    arc = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(arc)
    r = n * 0.355
    width = int(n * 0.03)
    start, sweep = -90 + 20, 250
    steps = 250
    for i in range(steps):
        a0 = start + sweep * i / steps
        a1 = start + sweep * (i + 1) / steps + 0.6
        col = lerp(CYAN, BLUE, i / (steps - 1))
        d.arc((c - r, c - r, c + r, c + r), a0, a1, fill=col + (255,), width=width)
    glow = arc.filter(ImageFilter.GaussianBlur(n * 0.018))
    img = Image.alpha_composite(img, glow)
    img = Image.alpha_composite(img, arc)

    # orbit marker at the end of the arc
    end = math.radians(start + sweep)
    mx, my = c + r * math.cos(end), c + r * math.sin(end)
    marker = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(marker).ellipse((mx - n * 0.022, my - n * 0.022, mx + n * 0.022, my + n * 0.022), fill=(255, 255, 255, 255))
    img = Image.alpha_composite(img, marker.filter(ImageFilter.GaussianBlur(n * 0.012)))
    img = Image.alpha_composite(img, marker)

    # rising sun over a horizon line, kept perfectly still and centred
    sun = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(sun)
    sr = n * 0.145
    horizon = c + n * 0.055
    for step in range(40):
        t = step / 39
        rr = sr * (1 - t * 0.85)
        col = lerp((255, 214, 150), (255, 255, 255), t)
        d.pieslice((c - rr, horizon - rr, c + rr, horizon + rr), 180, 360, fill=col + (255,))
    d.rounded_rectangle((c - n * 0.2, horizon + n * 0.012, c + n * 0.2, horizon + n * 0.034), radius=n * 0.011, fill=SILVER + (255,))
    for deg in (-150, -120, -90, -60, -30):
        a = math.radians(deg)
        d.line((c + (sr + n * 0.03) * math.cos(a), horizon + (sr + n * 0.03) * math.sin(a),
                c + (sr + n * 0.075) * math.cos(a), horizon + (sr + n * 0.075) * math.sin(a)),
               fill=CYAN + (255,), width=int(n * 0.014))
    img = Image.alpha_composite(img, sun.filter(ImageFilter.GaussianBlur(n * 0.02)))
    img = Image.alpha_composite(img, sun)

    final = img.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    final.save(OUT, "PNG")
    print(f"Wrote {OUT} ({final.size[0]}x{final.size[1]}, mode {final.mode})")


if __name__ == "__main__":
    main()
