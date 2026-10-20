import sys, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter
W, H = 1320, 2868
WIMG, OUT = sys.argv[1], sys.argv[2]; os.makedirs(OUT, exist_ok=True)
INTER = "/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf"
INTERR = "/usr/share/fonts/opentype/inter/Inter-Medium.otf"
HEB = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
TITLE = {"en": "The next Shabbat time, right on your Home Screen.", "he": "זמן השבת הבא, ישר על מסך הבית.",
         "ru": "Ближайшее время Шаббата — прямо на экране «Домой».", "fr": "La prochaine heure de Chabbat, sur votre écran d’accueil.",
         "es": "La próxima hora de Shabat, en tu pantalla de inicio."}
PILL = {"en": "All widgets are free", "he": "כל הווידג'טים בחינם", "ru": "Все виджеты бесплатны", "fr": "Tous les widgets sont gratuits", "es": "Todos los widgets son gratis"}

def bg():
    top, bottom = (214, 233, 255), (92, 150, 245)
    im = Image.new("RGB", (W, H)); px = im.load()
    for y in range(H):
        t = y / (H - 1); c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(W): px[x, y] = c
    return im.convert("RGBA")

def shadowed(img, wdg, x, y, r):
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((x, y + 24, x + wdg.width, y + wdg.height + 24), r, fill=(10, 30, 90, 120))
    img = Image.alpha_composite(img, sh.filter(ImageFilter.GaussianBlur(30)))
    img.alpha_composite(wdg, (x, y)); return img

def load(lang, name, width):
    im = Image.open(os.path.join(WIMG, f"w-{lang}-{name}.png")).convert("RGBA")
    return im.resize((width, int(im.height * width / im.width)), Image.LANCZOS)

def make(lang):
    rtl = lang == "he"
    img = bg(); d = ImageDraw.Draw(img)
    font = ImageFont.truetype(HEB if rtl else INTER, 112)
    kw = dict(direction="rtl") if rtl else {}
    words, lines, cur = TITLE[lang].split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if d.textlength(t, font=font, **kw) <= W - 200: cur = t
        else: lines.append(cur); cur = w
    lines.append(cur)
    y = 150
    for line in lines:
        w = d.textlength(line, font=font, **kw)
        d.text(((W - w) / 2, y), line, font=font, fill=(10, 30, 80), **({"direction": "rtl", "language": "he"} if rtl else {}))
        y += 135
    top = y + 130
    med = load(lang, "medium-ends", 1000)
    img = shadowed(img, med, (W - 1000) // 2, top, 96)
    r2 = top + med.height + 100
    smalls = [load(lang, "small-candle", 460), load(lang, "small-home", 460)]
    if rtl: smalls.reverse()
    for i, s in enumerate(smalls):
        img = shadowed(img, s, 160 + i * (460 + 80), r2, 96)
    ly = r2 + 460 + 100
    lw, lh = 1000, 640
    tile = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
    g = Image.new("RGBA", (lw, lh)); gp = g.load()
    for yy in range(lh):
        for xx in range(lw):
            t = (xx / lw + yy / lh) / 2
            gp[xx, yy] = (int(12 + 12 * t), int(22 + 30 * t), int(52 + 60 * t), 255)
    m = Image.new("L", (lw, lh), 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, lw, lh), 96, fill=255)
    tile.paste(g, (0, 0), m)
    td = ImageDraw.Draw(tile)
    clock = ImageFont.truetype(INTERR, 190)
    cw = td.textlength("9:41", font=clock)
    td.text(((lw - cw) / 2, 40), "9:41", font=clock, fill=(255, 255, 255))
    rect = load(lang, "lock-ends", 520)
    plate = Image.new("RGBA", (rect.width + 40, rect.height + 30), (0, 0, 0, 0))
    ImageDraw.Draw(plate).rounded_rectangle((0, 0, plate.width, plate.height), 44, fill=(255, 255, 255, 52))
    plate.alpha_composite(rect, (20, 15))
    tile.alpha_composite(plate, ((lw - plate.width) // 2, 310))
    img = shadowed(img, tile, (W - lw) // 2, ly, 96)
    pill = PILL[lang]
    pf = ImageFont.truetype(HEB if rtl else INTER, 64)
    kw2 = dict(direction="rtl", language="he") if rtl else {}
    tw = d.textlength(pill, font=pf, **kw2)
    d = ImageDraw.Draw(img)
    py = ly + lh + 120
    d.rounded_rectangle(((W - tw) / 2 - 60, py, (W + tw) / 2 + 60, py + 130), 65, fill=(255, 255, 255, 235))
    d.text(((W - tw) / 2, py + 26), pill, font=pf, fill=(20, 60, 160), **kw2)
    img.convert("RGB").save(os.path.join(OUT, f"{lang}-6-widgets.png"))

for lang in TITLE: make(lang)
print(sorted(os.listdir(OUT)))
