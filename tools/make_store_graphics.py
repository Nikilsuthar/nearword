"""Builds professional Play Store graphics from real device captures.

Output (store/): 7 phone screenshots 1080x1920, feature graphic 1024x500, icon 512.
Captures are read from %LOCALAPPDATA%/Temp/nw_shots (dark theme, English/Hindi).
"""
import math
import os
import pathlib

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHOTS = pathlib.Path(os.path.expandvars(r"%LOCALAPPDATA%\Temp\nw_shots"))
OUT = ROOT / "store"
(OUT / "screenshots").mkdir(parents=True, exist_ok=True)

FONTS = r"C:\Windows\Fonts"
BOLD = FONTS + r"\segoeuib.ttf"
SEMI = FONTS + r"\seguisb.ttf" if os.path.exists(FONTS + r"\seguisb.ttf") else BOLD
REG = FONTS + r"\segoeui.ttf"

W, H = 1080, 1920
GOLD = (255, 209, 102)
WHITE = (255, 255, 255)


def font(path, size):
    return ImageFont.truetype(path, size)


# ---------------------------------------------------------------- background
def background(w, h, accent):
    """Deep navy gradient with soft coloured glows and a fine dot grid."""
    base = Image.new("RGB", (w, h), (8, 14, 32))
    top = Image.new("RGB", (w, h), (14, 40, 105))
    base = Image.composite(top, base, Image.linear_gradient("L").resize((w, h)))
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    d.ellipse([w * 0.35, -h * 0.12, w * 1.35, h * 0.42], fill=accent + (120,))
    d.ellipse([-w * 0.45, h * 0.55, w * 0.65, h * 1.15], fill=(37, 99, 235, 90))
    glow = glow.filter(ImageFilter.GaussianBlur(120))
    base = base.convert("RGBA")
    base.alpha_composite(glow)
    dots = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dots)
    for x in range(30, w, 54):
        for y in range(30, h, 54):
            dd.ellipse([x - 1.5, y - 1.5, x + 1.5, y + 1.5], fill=(255, 255, 255, 22))
    base.alpha_composite(dots)
    return base


# ------------------------------------------------------------------- phone
def prepare_screen(name, crop_bottom, screen_w):
    """Crop the capture, replace the status bar with a clean one."""
    im = Image.open(SHOTS / f"{name}.png").convert("RGB")
    body = im.crop((8, 105, im.width - 8, crop_bottom))
    bg = body.getpixel((12, 4))
    scale = screen_w / body.width
    body = body.resize((screen_w, int(body.height * scale)), Image.LANCZOS)
    bar_h = int(78 * screen_w / 1080 * 1.2)
    screen = Image.new("RGB", (screen_w, body.height + bar_h), bg)
    screen.paste(body, (0, bar_h))
    d = ImageDraw.Draw(screen)
    k = screen_w / 800
    ft = font(SEMI, max(10, int(bar_h * 0.42)))
    d.text((int(screen_w * 0.075), bar_h * 0.52), "9:41", font=ft, fill=(235, 240, 250), anchor="lm")
    # signal + battery
    bx = screen_w - int(screen_w * 0.075)
    cy = bar_h * 0.52
    d.rounded_rectangle([bx - 46 * k, cy - 12 * k, bx, cy + 12 * k], 6 * k, outline=(235, 240, 250), width=max(1, int(3 * k)))
    d.rounded_rectangle([bx - 42 * k, cy - 8 * k, bx - 14 * k, cy + 8 * k], 3 * k, fill=(235, 240, 250))
    sx = bx - 90 * k
    for i in range(4):
        hh = (8 + i * 6) * k
        d.rectangle([sx + i * 11 * k, cy + 12 * k - hh, sx + i * 11 * k + 7 * k, cy + 12 * k], fill=(235, 240, 250))
    # punch-hole camera
    r = 15 * k
    d.ellipse([screen_w / 2 - r, bar_h * 0.52 - r, screen_w / 2 + r, bar_h * 0.52 + r], fill=(4, 5, 8))
    return screen


def phone(name, crop_bottom, screen_w=800, bezel=18):
    screen = prepare_screen(name, crop_bottom, screen_w)
    sw, sh = screen.size
    pw, ph = sw + 2 * bezel, sh + 2 * bezel
    pad = 14  # room for side buttons
    canvas = Image.new("RGBA", (pw + 2 * pad, ph + 2 * pad), (0, 0, 0, 0))
    d = ImageDraw.Draw(canvas)
    ox = oy = pad
    kk = screen_w / 800
    r_out = max(28, int(104 * kk * 1.15))
    r_in = r_out - bezel
    # side buttons
    d.rounded_rectangle([ox + pw - 2, oy + 330, ox + pw + 8, oy + 470], 5, fill=(54, 60, 76))
    d.rounded_rectangle([ox + pw - 2, oy + 520, ox + pw + 8, oy + 600], 5, fill=(54, 60, 76))
    d.rounded_rectangle([ox - 8, oy + 400, ox + 2, oy + 520], 5, fill=(54, 60, 76))
    # metallic outer edge, then black body
    d.rounded_rectangle([ox, oy, ox + pw, oy + ph + 400], r_out, fill=(92, 100, 122))
    d.rounded_rectangle([ox + 3, oy + 3, ox + pw - 3, oy + ph + 400], r_out - 3, fill=(20, 22, 30))
    d.rounded_rectangle([ox + 8, oy + 8, ox + pw - 8, oy + ph + 400], r_out - 8, fill=(8, 9, 13))
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw, sh + 400], r_in, fill=255)
    canvas.paste(screen, (ox + bezel, oy + bezel), mask)
    # glass reflection
    refl = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(refl)
    rd.polygon([(ox + bezel, oy + bezel), (ox + bezel + sw * 0.55, oy + bezel),
                (ox + bezel, oy + bezel + sh * 0.35)], fill=(255, 255, 255, 14))
    rmask = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(rmask).rounded_rectangle(
        [ox + bezel, oy + bezel, ox + bezel + sw, oy + bezel + sh + 400], r_in, fill=255)
    refl.putalpha(ImageChops.multiply(refl.getchannel("A"), rmask))
    canvas.alpha_composite(refl)
    return canvas


def shadow_for(img, blur=36, alpha=160, color=(0, 0, 0)):
    """Blurred silhouette; padded so the blur is never clipped.

    Returns (image, offset) where offset is the amount to subtract from the
    paste position."""
    pad = blur * 3
    a = Image.new("L", (img.width + 2 * pad, img.height + 2 * pad), 0)
    a.paste(img.getchannel("A").point(lambda v: int(v * alpha / 255)), (pad, pad))
    sh = Image.new("RGBA", a.size, color + (0,))
    sh.putalpha(a)
    return sh.filter(ImageFilter.GaussianBlur(blur)), pad


def put_shadow(canvas, shape, pos, blur, alpha, color=(0, 0, 0)):
    sh, pad = shadow_for(shape, blur, alpha, color)
    canvas.alpha_composite(sh, (max(0, pos[0] - pad), max(0, pos[1] - pad)))


# -------------------------------------------------------------------- cards
def text_with_accent(d, xy, parts, f, anchor_center_x=None):
    """parts: list of (text, color). Draw in a row; returns width."""
    total = sum(d.textlength(t, font=f) for t, _ in parts)
    x = xy[0] if anchor_center_x is None else anchor_center_x - total / 2
    for t, c in parts:
        d.text((x, xy[1]), t, font=f, fill=c)
        x += d.textlength(t, font=f)
    return total


def card(eyebrow, lines, sub, shot, crop_bottom, name, accent=(37, 99, 235)):
    img = background(W, H, accent)
    d = ImageDraw.Draw(img)
    # eyebrow pill
    fe = font(BOLD, 32)
    tw = d.textlength(eyebrow, font=fe)
    pill = [W / 2 - tw / 2 - 30, 92, W / 2 + tw / 2 + 30, 92 + 62]
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(ov).rounded_rectangle(pill, 31, fill=(255, 255, 255, 34), outline=(255, 255, 255, 90), width=2)
    img.alpha_composite(ov)
    d = ImageDraw.Draw(img)
    d.text((W / 2, 92 + 31), eyebrow, font=fe, fill=GOLD, anchor="mm")
    # headline (centred, accent words in gold)
    fh = font(BOLD, 96)
    y = 196
    for parts in lines:
        text_with_accent(d, (0, y), parts, fh, anchor_center_x=W / 2)
        y += 112
    fs = font(REG, 42)
    y += 14
    for line in sub.split("\n"):
        d.text((W / 2, y), line, font=fs, fill=(214, 224, 245), anchor="ma")
        y += 56
    # phone, bleeding off the bottom edge
    ph = phone(shot, crop_bottom)
    px = (W - ph.width) // 2
    py = y + 56
    put_shadow(img, ph, (px, py + 30), 70, 200, accent)
    put_shadow(img, ph, (px, py + 22), 28, 170)
    img.alpha_composite(ph, (px, py))
    img.convert("RGB").crop((0, 0, W, H)).save(OUT / "screenshots" / name, quality=96)


A = lambda t: (t, GOLD)
P = lambda t: (t, WHITE)

card("GUESS BY MEANING", [[P("Every guess gets a")], [A("rank"), P(". Find #1!")]],
     "The closer in meaning, the lower the rank.", "d_game", 2330, "1_guess_by_meaning.png", (16, 185, 129))
card("DAILY PUZZLE", [[P("A new word")], [A("every day")]],
     "Same word for everyone. Climb the board.", "d_home", 2160, "2_daily_word.png", (37, 99, 235))
card("CATEGORIES", [[P("Pick a "), A("theme")], [P("play your way")]],
     "Animals, food, sports, India and more.", "d_cats", 2160, "3_categories.png", (124, 58, 237))
card("LIVE BATTLE", [[P("Race your")], [A("friends"), P(" live")]],
     "Same secret word, live scoreboard.", "d_battle", 2330, "4_live_battle.png", (234, 88, 12))
card("COIN STAKES", [[P("Stake coins,")], [A("win the pot")]],
     "Pick level, timer and stake. Winner takes all.", "d_room", 2330, "5_stakes.png", (5, 150, 105))
card("RESULTS", [[P("See the "), A("winning")], [A("word"), P(" and top 3")]],
     "Final ranking, nearest words and coins won.", "d_finish1", 2330, "6_results.png", (234, 179, 8))
card("HINDI + ENGLISH", [[P("Play in "), A("Hindi")], [P("or English")]],
     "Easy, Medium or Hard. Regular or India words.", "d_hindi", 2160, "7_hindi_english.png", (225, 29, 72))

# ------------------------------------------------------------ feature graphic
FW, FH = 1024, 500
fg = background(FW, FH, (37, 99, 235))
d = ImageDraw.Draw(fg)
icon = Image.open(ROOT / "assets/icon/icon.png").convert("RGBA").resize((132, 132), Image.LANCZOS)
m = Image.new("L", icon.size, 0)
ImageDraw.Draw(m).rounded_rectangle([0, 0, 132, 132], 30, fill=255)
icon.putalpha(m)
put_shadow(fg, icon, (60, 78), 14, 150)
fg.alpha_composite(icon, (56, 70))
d.text((214, 100), "NearWord", font=font(BOLD, 74), fill=WHITE, anchor="lm")
d.text((218, 158), "Guess the word by meaning", font=font(SEMI, 27), fill=GOLD, anchor="lm")
bx, by = 58, 262
for label in ("Daily puzzle", "Live battles", "Hindi + English"):
    f = font(SEMI, 26)
    wlab = d.textlength(label, font=f)
    ov = Image.new("RGBA", fg.size, (0, 0, 0, 0))
    ImageDraw.Draw(ov).rounded_rectangle([bx, by, bx + wlab + 36, by + 52], 26, fill=(255, 255, 255, 34),
                                         outline=(255, 255, 255, 90), width=2)
    fg.alpha_composite(ov)
    d = ImageDraw.Draw(fg)
    d.text((bx + 18, by + 26), label, font=f, fill=WHITE, anchor="lm")
    by += 66
# two phones, slightly rotated
def tilted(name, crop, width, angle):
    p = phone(name, crop, screen_w=width, bezel=8)
    return p.rotate(angle, expand=True, resample=Image.BICUBIC)
p1 = tilted("d_battle", 2330, 200, 5)
p2 = tilted("d_game", 2330, 200, -4)
put_shadow(fg, p1, (560, 70), 20, 160)
fg.alpha_composite(p1, (552, 56))
put_shadow(fg, p2, (744, 112), 20, 160)
fg.alpha_composite(p2, (736, 96))
fg.convert("RGB").save(OUT / "feature_graphic_1024x500.png")

Image.open(ROOT / "assets/icon/icon.png").convert("RGBA").resize((512, 512), Image.LANCZOS).save(OUT / "icon_512.png")
print("done")
