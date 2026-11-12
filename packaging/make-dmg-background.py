#!/usr/bin/env python3
"""Draw the macOS disk image window background: Kobo Deluxe on the left,
an arrow, and the Applications folder on the right, with a note on how to
get past Gatekeeper on first launch (the app is not notarized).

Usage: packaging/make-dmg-background.py   (needs Pillow)
Writes packaging/dmg/background.png and background@2x.png. The layout
numbers must match packaging/dmg-settings.py.
"""

import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "dmg")

W, H = 640, 400                 # window content size, in points
APP_X, APPS_X, ICON_Y = 170, 470, 185
FONT = "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf"
NOTE = "First launch: System Settings  ›  Privacy & Security  ›  Open Anyway"


def draw(scale):
    w, h = W * scale, H * scale
    img = Image.new("RGB", (w, h))
    px = img.load()
    top, bottom = (248, 249, 251), (232, 235, 241)
    for y in range(h):
        t = y / (h - 1)
        c = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))
        for x in range(w):
            px[x, y] = c

    d = ImageDraw.Draw(img)
    # Arrow from the app towards Applications
    col = (150, 158, 172)
    x0, x1, y = (APP_X + 90) * scale, (APPS_X - 90) * scale, ICON_Y * scale
    lw = 6 * scale
    d.line((x0, y, x1 - 10 * scale, y), fill=col, width=lw)
    head = 22 * scale
    d.polygon(((x1, y), (x1 - head, y - head * 0.8), (x1 - head, y + head * 0.8)),
              fill=col)
    for cx in (x0,):
        r = lw / 2
        d.ellipse((cx - r, y - r, cx + r, y + r), fill=col)

    font = ImageFont.truetype(FONT, 12 * scale)
    tw = d.textlength(NOTE, font=font)
    d.text(((w - tw) / 2, (H - 46) * scale), NOTE, font=font,
           fill=(120, 128, 142))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    draw(1).save(os.path.join(OUT, "background.png"))
    big = draw(2)
    big.info["dpi"] = (144, 144)
    big.save(os.path.join(OUT, "background@2x.png"), dpi=(144, 144))


if __name__ == "__main__":
    main()
