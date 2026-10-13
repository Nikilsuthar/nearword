"""Draws the NearWord launcher icon (assets/icon/icon.png + icon_fg.png)."""
import pathlib
from PIL import Image, ImageDraw

OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "icon"
S = 1024


def rings(draw, c, r, alpha_scale=1.0):
    for i in range(3):
        rad = r * (0.30 + i * 0.2)
        a = int(255 * (0.85 - i * 0.28) * alpha_scale)
        w = int(r * 0.07)
        draw.ellipse([c - rad, c - rad, c + rad, c + rad],
                     outline=(255, 255, 255, a), width=w)
    d = r * 0.13
    draw.ellipse([c - d, c - d, c + d, c + d], fill=(255, 209, 102, 255))


# Full icon: gradient background.
bg = Image.new("RGBA", (S, S))
px = bg.load()
for y in range(S):
    for x in range(S):
        t = (x + y) / (2 * S)
        px[x, y] = (int(124 + (74 - 124) * t), int(92 + (47 - 92) * t),
                    int(255 + (214 - 255) * t), 255)
d = ImageDraw.Draw(bg)
rings(d, S / 2, S / 2)
bg.save(OUT / "icon.png")

# Adaptive foreground: transparent, artwork inside the safe zone.
fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
rings(ImageDraw.Draw(fg), S / 2, S / 2 * 0.62)
fg.save(OUT / "icon_fg.png")
