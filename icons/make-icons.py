#!/usr/bin/env python3
"""Build the Kobo Deluxe application icons from the game's own sprites:
the player ship heading north east, firing.

Usage: icons/make-icons.py   (from anywhere; needs Pillow)

Writes:
  icons/kobodl-1024.png    master image
  icons/kobodl.png         256x256, Linux desktop icon
  icons/macos/kobodl.icns  macOS app icon
  icons/windows/kobodl.ico Windows exe and installer icon
"""

import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
GFX = os.path.join(HERE, "..", "data", "gfx")

SIZE = 1024
# macOS icon grid: an 824px rounded square centred in the 1024px canvas
INSET = 100
RADIUS = 185


def sprite(sheet, frame_w, frame_h, col, row):
    img = Image.open(os.path.join(GFX, sheet)).convert("RGBA")
    return img.crop((col * frame_w, row * frame_h,
                     (col + 1) * frame_w, (row + 1) * frame_h))


def scaled(img, factor):
    # Nearest neighbour: keep the sprite's pixels crisp
    return img.resize((img.width * factor, img.height * factor),
                      Image.NEAREST)


def background():
    body = SIZE - 2 * INSET
    # Deep space: a soft blue glow behind the ship, fading to near black
    bg = Image.new("RGB", (body, body), (3, 5, 14))
    glow = Image.new("L", (body, body), 0)
    ImageDraw.Draw(glow).ellipse((60, 140, body - 140, body - 60), fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(170))
    bg = Image.composite(Image.new("RGB", (body, body), (16, 40, 92)), bg,
                         glow)
    # Fixed seed so the stars stay put between rebuilds
    rnd = random.Random(1995)
    d = ImageDraw.Draw(bg)
    for _ in range(140):
        x, y = rnd.uniform(0, body), rnd.uniform(0, body)
        r = rnd.choice((1.2, 1.6, 2.2, 3.0))
        v = rnd.randint(110, 255)
        d.ellipse((x - r, y - r, x + r, y + r), fill=(v, v, min(255, v + 30)))
    return bg


def add_glow(base, layer, radius, strength):
    # Additive bloom of a layer's colours, for the bolts and engine light
    blur = layer.filter(ImageFilter.GaussianBlur(radius))
    rgb = Image.new("RGB", base.size, (0, 0, 0))
    rgb.paste(blur.convert("RGB"), (0, 0), blur)
    rgb = Image.eval(rgb, lambda v: min(255, int(v * strength)))
    return ImageChops.add(base, rgb)


def compose():
    body = SIZE - 2 * INSET
    scene = background()

    ship = scaled(sprite("player.png", 40, 40, 2, 0), 11)
    bolt = scaled(sprite("bolt.png", 16, 16, 0, 1), 11)

    # Ship lower left of centre; bolts streaking off to the upper right
    sx, sy = 120, 300
    layer = Image.new("RGBA", (body, body), (0, 0, 0, 0))
    for i, (bx, by) in enumerate(((455, 205), (585, 75))):
        layer.alpha_composite(bolt, (bx, by))
    scene = add_glow(scene, layer, 28, 1.6)
    scene.paste(layer, (0, 0), layer)

    shadow = Image.new("RGBA", ship.size, (0, 0, 0, 0))
    shadow.putalpha(ship.getchannel("A").point(lambda a: a * 0.6))
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    scene.paste((0, 0, 0), (sx + 18, sy + 26), shadow)
    scene.paste(ship, (sx, sy), ship)

    # Round the corners and place on the transparent canvas
    mask = Image.new("L", (body, body), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, body - 1, body - 1),
                                           RADIUS, fill=255)
    icon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    icon.paste(scene, (INSET, INSET), mask)
    # Thin light edge, like the bevel on current macOS icons
    edge = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle(
        (INSET, INSET, SIZE - INSET - 1, SIZE - INSET - 1), RADIUS,
        outline=(255, 255, 255, 40), width=3)
    icon.alpha_composite(edge)
    return icon


def main():
    icon = compose()
    icon.save(os.path.join(HERE, "kobodl-1024.png"))
    icon.resize((256, 256), Image.LANCZOS).save(
        os.path.join(HERE, "kobodl.png"))
    icon.save(os.path.join(HERE, "macos", "kobodl.icns"))
    # Windows icons fill the whole square; crop the macOS margin away
    full = icon.crop((INSET - 8, INSET - 8, SIZE - INSET + 8,
                      SIZE - INSET + 8)).resize((256, 256), Image.LANCZOS)
    full.save(os.path.join(HERE, "windows", "kobodl.ico"),
              sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32),
                     (16, 16)])


if __name__ == "__main__":
    main()
