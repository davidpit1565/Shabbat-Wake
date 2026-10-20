import sys, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1320, 2868
SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)

SLIDES = [  # (raw name, headlines)
    ("1-home", {"en": "Never miss candle lighting again.", "he": "לא תפספסו הדלקת נרות. אף פעם.",
                "ru": "Больше не пропустите зажигание свечей.", "fr": "Ne manquez plus jamais l’allumage des bougies.",
                "es": "Nunca más te pierdas el encendido de velas."}),
    ("5-editor", {"en": "An alarm that respects Shabbat.", "he": "שעון מעורר שמכבד את השבת",
                  "ru": "Будильник, уважающий Шаббат.", "fr": "Un réveil qui respecte Chabbat.",
                  "es": "Una alarma que respeta el Shabat."}),
    ("2-alarms", {"en": "Rings when it should. Stops by itself.", "he": "מצלצל כשצריך. נעצר לבד.",
                  "ru": "Звонит вовремя. Выключается сам.", "fr": "Sonne à l’heure. S’arrête tout seul.",
                  "es": "Suena a tu hora. Se detiene sola."}),
    ("3-times", {"en": "Exact times for where you are.", "he": "הזמנים המדויקים של המקום שלכם",
                 "ru": "Точное время там, где вы.", "fr": "Les horaires exacts de votre lieu.",
                 "es": "Horarios exactos donde estés."}),
]
INTER = "/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf"
HEB = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"

def background():
    top, bottom = (214, 233, 255), (92, 150, 245)
    bg = Image.new("RGB", (W, H))
    px = bg.load()
    for y in range(H):
        t = y / (H - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(W):
            px[x, y] = c
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((W * 0.1, H * 0.55, W * 1.1, H * 1.05), fill=(255, 255, 255, 70))
    return Image.alpha_composite(bg.convert("RGBA"), glow.filter(ImageFilter.GaussianBlur(160)))

def wrap(draw, text, font, maxw, rtl):
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if draw.textlength(t, font=font, direction="rtl" if rtl else None) <= maxw: cur = t
        else: lines.append(cur); cur = w
    lines.append(cur)
    return lines

def make(lang, raw, title, bgimg):
    rtl = lang == "he"
    img = bgimg.copy()
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(HEB if rtl else INTER, 112)
    lines = wrap(d, title, font, W - 200, rtl)
    y = 150
    for line in lines:
        w = d.textlength(line, font=font, direction="rtl" if rtl else None)
        d.text(((W - w) / 2, y), line, font=font, fill=(10, 30, 80), direction="rtl" if rtl else None, language="he" if rtl else None)
        y += 135
    shot = Image.open(os.path.join(SRC, f"{lang}-{raw}.png")).convert("RGBA")
    top = y + 70
    scale = 0.84
    sw = int(W * scale); sh = int(shot.height * scale)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    r = 90
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw, sh), r, fill=255)
    x = (W - sw) // 2
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((x, top + 30, x + sw, top + sh + 30), r, fill=(10, 30, 90, 110))
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(40)))
    frame = Image.new("RGBA", (sw + 24, sh + 24), (20, 28, 48, 255))
    fm = Image.new("L", frame.size, 0)
    ImageDraw.Draw(fm).rounded_rectangle((0, 0, frame.width, frame.height), r + 12, fill=255)
    img.paste(frame, (x - 12, top - 12), fm)
    img.paste(shot, (x, top), mask)
    img.convert("RGB").save(os.path.join(OUT, f"{lang}-{raw.split('-')[0]}-{raw.split('-')[1]}.png"))

bg = background()
for lang in ["en", "he", "ru", "fr", "es"]:
    for raw, titles in SLIDES:
        if os.path.exists(os.path.join(SRC, f"{lang}-{raw}.png")):
            make(lang, raw, titles[lang], bg)
print(sorted(os.listdir(OUT)))
