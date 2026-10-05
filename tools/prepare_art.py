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

# Eye of Harmony: Blender loop (tools/blender/eye_star.py) -> 448 px frames, 9x9 per sheet.
loop = sorted((ROOT / 'art/render/star/loop').glob('*.png'))
if loop:
    frames = [Image.open(f).convert('RGBA').resize((448, 448), Image.LANCZOS) for f in loop]
    for old in OUT.glob('eye-core-*.png'):
        old.unlink()
    for n, start in enumerate(range(0, len(frames), 81), 1):
        chunk = frames[start:start + 81]
        rows = (len(chunk) + 8) // 9
        sheet = Image.new('RGBA', (9 * 448, rows * 448))
        for i, fr in enumerate(chunk):
            sheet.paste(fr, ((i % 9) * 448, (i // 9) * 448))
        sheet.save(OUT / f'eye-core-{n}.png', optimize=True)
        print(f'eye-core-{n}.png: {len(chunk)} frames, {rows} rows')

# Inner doors (ChatGPT, round 2): the alcove in the console room's south wall, closed and open.
for state in ('closed', 'open'):
    src = ROOT / f'art/round-2/chatgpt/doors-{state}.png'
    if src.exists():
        img = Image.open(src).convert('RGBA')
        process(img, lambda x, y, d, r, g, b, a: tint((255, 240, 210), r, g, b, a, 200) if a < 200 else (r, g, b, a))
        save(square(img), f'inner-doors-{state}.png', 1024)
