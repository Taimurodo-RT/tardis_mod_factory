"""Turn raw generated art (art/round-1/chatgpt) into game-ready sprites in graphics/twelve.

    python tools/prepare_art.py

ChatGPT cut-outs leave red/green fringes in half-transparent pixels; those are recoloured
to the glow colour. Outputs are square, centred and sized for the scales used in Lua.
Pure Pillow, no numpy.
"""
import math
import pathlib
import sys

from PIL import Image

sys.stdout.reconfigure(encoding='utf-8')
ROOT = pathlib.Path(__file__).resolve().parents[1]
RAW = ROOT / 'art/round-1/chatgpt'
OUT = ROOT / 'graphics/twelve'


def load(name):
    return Image.open(RAW / name).convert('RGBA')


def square(img):
    n = max(img.size)
    out = Image.new('RGBA', (n, n))
    out.paste(img, ((n - img.width) // 2, (n - img.height) // 2))
    return out


def save(img, name, size):
    img.resize((size, size), Image.LANCZOS).save(OUT / name, optimize=True)
    print(f'{name}: {size}x{size}')


def process(img, fn):
    """Apply fn(x, y, r, g, b, a) -> (r, g, b, a) to every pixel; r is distance from centre."""
    px = img.load()
    cx, cy = (img.width - 1) / 2, (img.height - 1) / 2
    for y in range(img.height):
        for x in range(img.width):
            px[x, y] = fn(x, y, math.hypot(x - cx, y - cy), *px[x, y])
    return img


def tint(glow, r, g, b, a, below):
    """Half-transparent pixels take the glow hue at their own brightness."""
    if a >= below:
        return r, g, b, a
    k = min(1.0, max(0.35, max(r, g, b) / 255 * 1.15))
    return int(glow[0] * k), int(glow[1] * k), int(glow[2] * k), a


# Console: already a clean cut-out.
save(square(load('console.png')), 'console.png', 512)

# Star: keep the disc, rebuild a smooth corona fade so no fringe can show around it.
star = load('star.png')
disc, span = 0.29 * star.width, 0.24 * star.width


def star_px(x, y, d, r, g, b, a):
    if d <= disc:
        return tint((255, 150, 60), r, g, b, a, 250)
    # Outside the disc: a clean round corona (the generated one had a ragged, fringed cut-out).
    fade = max(0.0, 1 - (d - disc) / span) ** 1.8
    k = 0.62 + 0.38 * fade
    return int(255 * k), int(150 * k), int(60 * k), int(235 * fade)


save(square(process(star, star_px)), 'star.png', 1024)

# Containment ring: drop the clipped stub at the top edge, clean the glow fringe.
ring = load('ring.png')
save(square(process(ring, lambda x, y, d, r, g, b, a: (0, 0, 0, 0) if y < 22 else tint((255, 145, 45), r, g, b, a, 235))),
     'eye-ring.png', 1024)

# Glass floor: keep the round panel only, with a soft edge.
glass = load('glass-floor.png')
edge = 0.437 * glass.width
process(glass, lambda x, y, d, r, g, b, a: (r, g, b, int(255 * min(1.0, max(0.0, (edge - d) / 4)))))
c, half = glass.width // 2, int(edge) + 4
save(glass.crop((c - half, c - half, c + half, c + half)), 'glass-floor.png', 1024)

# Soft white glow for additive light effects (tinted at runtime).
glow = Image.new('RGBA', (256, 256))
process(glow, lambda x, y, d, r, g, b, a: (255, 255, 255, int(255 * max(0.0, 1 - d / 127) ** 2.2)))
glow.save(OUT / 'glow.png', optimize=True)
print('glow.png: 256x256')
