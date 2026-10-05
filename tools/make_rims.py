"""Rim art for the round rooms.

    python tools/make_rims.py

eye-rim.png  : the console-room wall ring with its four openings filled in, for the closed Eye hall.
               Openings are replaced by the same wall rotated 45 degrees, so the style stays identical.
hull-ring.png: a dark hull band drawn just outside a rim to hide the stepped tile edge behind it.
"""
import math
import pathlib

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[1]
G = ROOT / 'graphics/twelve'

rim = Image.open(G / 'circular-rim.png').convert('RGBA')
n = rim.width
# Each opening (degrees counter-clockwise from east, half-width) is filled with the wall from a
# solid stretch: the image is turned so that stretch lands on the opening.
openings = [(0, 12, 45), (90, 12, 45), (180, 12, 45), (270, 30, 135)]
closed = rim.copy()
for centre, half, turn in openings:
    mask = Image.new('L', rim.size, 0)
    # PIL angles run clockwise from east.
    ImageDraw.Draw(mask).pieslice([0, 0, n, n], -centre - half, -centre + half, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(n / 400))
    closed.paste(rim.rotate(turn, resample=Image.BICUBIC), (0, 0), mask)
closed.save(G / 'eye-rim.png', optimize=True)
print('eye-rim.png', closed.size)

# Hull band: opaque dark steel from radius 0.86 to 1.0 of the image, soft inner edge.
# gaps: (degrees counter-clockwise from east, half-width) left open for corridors.
def hull(name, gaps=()):
    size = 1024
    img = Image.new('RGBA', (size, size))
    px = img.load()
    r_in, r_out = 0.86 * size / 2, size / 2
    for y in range(size):
        for x in range(size):
            dx, dy = x - size / 2 + 0.5, size / 2 - y - 0.5
            r = math.hypot(dx, dy)
            if not r_in <= r <= r_out:
                continue
            ang = math.degrees(math.atan2(dy, dx)) % 360
            if any(min(abs(ang - c), 360 - abs(ang - c)) < h for c, h in gaps):
                continue
            t = (r - r_in) / (r_out - r_in)
            shade = int(28 - 14 * t)
            a = int(255 * min(1.0, (r - r_in) / 6))
            if r > r_out - 3:
                a = int(a * (r_out - r) / 3)
            px[x, y] = (shade, shade, shade + 2, a)
    img.save(G / name, optimize=True)
    print(name, img.size)


hull('hull-ring.png')
# Console room: corridors leave north (rooms), east (cargo hold) and south (exit).
hull('hull-ring-console.png', gaps=[(90, 8), (0, 8), (270, 8)])
