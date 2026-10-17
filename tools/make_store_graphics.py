"""Builds Play Store screenshots, feature graphic and 512 icon from device captures."""
import os, pathlib
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHOTS = pathlib.Path(os.path.expandvars(r"%LOCALAPPDATA%\Temp\nw_shots"))
OUT = ROOT / "store"
(OUT / "screenshots").mkdir(parents=True, exist_ok=True)
BOLD = r"C:\Windows\Fonts\segoeuib.ttf"
REG = r"C:\Windows\Fonts\segoeui.ttf"
W, H = 1080, 1920

def gradient(w, h, c1, c2):
    base = Image.new("RGB", (w, h), c1)
    top = Image.new("RGB", (w, h), c2)
    mask = Image.linear_gradient("L").resize((w, h))
    return Image.composite(top, base, mask)

def decorate(img):
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    d.polygon([(W, 380), (W, 1100), (330, 1100)], fill=(255, 255, 255, 26))
    d.ellipse([-260, 1250, 520, 2030], fill=(255, 255, 255, 20))
    d.ellipse([700, -220, 1300, 380], fill=(255, 255, 255, 22))
    for r in (80, 150, 220):
        d.ellipse([900 - r, 330 - r, 900 + r, 330 + r], outline=(255, 255, 255, 40), width=4)
    img.paste(ov, (0, 0), ov)

def phone(shot_name, crop_bottom, width=860):
    shot = Image.open(SHOTS / f"{shot_name}.png").convert("RGB")
    shot = shot.crop((6, 105, shot.width - 6, crop_bottom))
    sw = width - 44
    sh = int(shot.height * sw / shot.width)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    ph, pw = sh + 44, width
    frame = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle([0, 0, pw, ph + 200], radius=92, fill=(16, 18, 26, 255))
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw, sh + 200], radius=70, fill=255)
    frame.paste(shot, (22, 22), mask)
    d.rounded_rectangle([pw // 2 - 90, 34, pw // 2 + 90, 62], radius=14, fill=(16, 18, 26, 255))
    return frame

def card(title, sub, shot, crop_bottom, name, c1=(37, 99, 235), c2=(20, 184, 166)):
    img = gradient(W, H, c1, c2)
    decorate(img)
    d = ImageDraw.Draw(img)
    ft = ImageFont.truetype(BOLD, 84)
    fs = ImageFont.truetype(REG, 44)
    y = 120
    for line in title.split("\n"):
        d.text((70, y), line, font=ft, fill="white")
        y += 100
    y += 12
    for line in sub.split("\n"):
        d.text((72, y), line, font=fs, fill=(255, 255, 255, 235))
        y += 58
    ph = phone(shot, crop_bottom)
    px = (W - ph.width) // 2
    py = max(y + 70, 540)
    shadow = Image.new("RGBA", (ph.width + 80, ph.height + 80), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([40, 40, ph.width + 40, ph.height + 40], 92, fill=(0, 0, 0, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    img.paste(shadow, (px - 40, py - 20), shadow)
    img.paste(ph, (px, py), ph)
    img.crop((0, 0, W, H)).save(OUT / "screenshots" / name, quality=95)

card("Guess the word\nby meaning", "Every guess gets a rank.\nRank 1 is the secret word.", "s_game", 2330, "1_guess_by_meaning.png")
card("A new word\nevery day", "Climb the daily leaderboard\nwith friends and players.", "s_home", 2160, "2_daily_word.png", (14, 116, 144), (37, 99, 235))
card("Pick a theme,\nplay your way", "Animals, food, sports, India\nand more categories.", "s_cats", 2160, "3_categories.png", (79, 70, 229), (14, 165, 233))
card("Battle friends\nlive", "Same secret word, live scoreboard,\nthe nearest guess wins.", "s_battle", 2330, "4_live_battle.png", (234, 88, 12), (244, 63, 94))
card("Stake coins,\nwin the pot", "Choose level, timer and stake.\nWinner takes all.", "s_room", 2330, "5_stakes.png", (5, 150, 105), (37, 99, 235))
card("Hindi and\nEnglish", "Easy, Medium or Hard.\nRegular or India word style.", "s_hindi", 2160, "6_hindi_english.png", (124, 58, 237), (37, 99, 235))

# Feature graphic 1024x500
fg = gradient(1024, 500, (37, 99, 235), (20, 184, 166))
d = ImageDraw.Draw(fg, "RGBA")
for r in (120, 200, 280):
    d.ellipse([820 - r, 250 - r, 820 + r, 250 + r], outline=(255, 255, 255, 50), width=5)
icon = Image.open(ROOT / "assets/icon/icon.png").convert("RGBA").resize((150, 150), Image.LANCZOS)
fg.paste(icon, (70, 90), icon)
d.text((250, 95), "NearWord", font=ImageFont.truetype(BOLD, 84), fill="white")
d.text((72, 270), "Guess the word by meaning", font=ImageFont.truetype(BOLD, 40), fill="white")
d.text((72, 340), "Daily puzzle · Live battles · Hindi + English", font=ImageFont.truetype(REG, 28), fill=(255, 255, 255, 235))
ph = phone("s_game", 2300, 270)
fg.paste(ph, (735, 70), ph)
fg.convert("RGB").save(OUT / "feature_graphic_1024x500.png")

# 512 icon
Image.open(ROOT / "assets/icon/icon.png").convert("RGBA").resize((512, 512), Image.LANCZOS).save(OUT / "icon_512.png")
print("done")
