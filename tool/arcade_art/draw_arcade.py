"""Draw the arcade hall pixel art (work package J1) at native resolution.

Each sprite is drawn on flat magenta (#FF00FF) at a small native size with
the world palette (web_dashboard/assets/world_ui.css), then keyed and scaled
with nearest-neighbour by the shared tool:

  python -I tool/arcade_art/draw_arcade.py <source_dir>
  python -I tool/cabin_art/key_sprites.py <source_dir> web_dashboard/assets/arcade tool/arcade_art/spec.json

Every source touches all four edges so key_sprites' trim keeps whole-number
scaling (checked at the end of this script). Card faces for the memory game
are thumbnails of the App's existing companion and badge art.

Prompts these sprites stand in for (shared prefix + reference images as in
the work package) are kept beside each function.
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

MAGENTA = (255, 0, 255, 255)
P = {
    'outline': (42, 26, 20), 'wood': (138, 90, 52), 'wood_dark': (90, 56, 38), 'wood_deep': (58, 34, 22),
    'frame': (201, 147, 79), 'parch': (246, 231, 200), 'parch_hi': (255, 250, 240), 'gold': (255, 197, 77),
    'gold_deep': (196, 113, 11), 'violet': (139, 108, 240), 'violet_deep': (75, 47, 168), 'green': (76, 138, 58),
    'red': (216, 69, 46), 'night': (27, 21, 48), 'dusk': (74, 42, 94), 'dusk_mid': (44, 29, 68),
    'blue': (78, 140, 220), 'blue_deep': (36, 64, 130), 'teal_soft': (120, 170, 200), 'white': (255, 250, 240),
    'pink': (240, 150, 170), 'moss': (110, 150, 80), 'stone': (110, 92, 110), 'stone_dark': (72, 58, 80),
}


def canvas(w, h, fill=MAGENTA):
    img = Image.new('RGBA', (w, h), fill)
    return img, ImageDraw.Draw(img)


def c(name, a=255):
    r, g, b = P[name]
    return (r, g, b, a)


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def dither_gradient(d, x0, y0, x1, y1, top, bottom, steps=6):
    """Banded gradient with a 2x2 ordered dither between bands (pixel-art style)."""
    h = y1 - y0
    for y in range(y0, y1):
        t = (y - y0) / max(1, h - 1)
        band = t * (steps - 1)
        lo = math.floor(band)
        frac = band - lo
        for x in range(x0, x1):
            k = lo + (1 if frac > [0.25, 0.75][(x + y) % 2] else 0)
            d.point((x, y), fill=mix(top, bottom, min(steps - 1, k) / (steps - 1)))


# ---------------------------------------------------------------------------
# "arcade hall interior background, wooden floor, string lights, 4 empty
#  spots for arcade cabinets, 1280x720 scene, no characters"
def hall(out):
    img, d = canvas(320, 180)
    dither_gradient(d, 0, 0, 320, 112, c('dusk'), c('dusk_mid'))
    # wall planks
    for x in range(0, 320, 16):
        d.line([(x, 14), (x, 111)], fill=c('night'))
    # wainscot
    d.rectangle([0, 92, 319, 111], fill=c('wood_dark'))
    d.line([(0, 92), (319, 92)], fill=c('frame'))
    d.line([(0, 111), (319, 111)], fill=c('outline'))
    for x in range(4, 320, 12):
        d.rectangle([x, 96, x + 7, 107], outline=c('wood_deep'))
    # two arched windows with dusk sky
    for wx in (40, 252):
        d.rectangle([wx, 30, wx + 28, 70], fill=c('outline'))
        dither_gradient(d, wx + 2, 32, wx + 27, 69, (240, 160, 120), c('violet_deep'), 5)
        d.line([(wx + 14, 32), (wx + 14, 69)], fill=c('wood_dark'))
        d.line([(wx + 2, 50), (wx + 27, 50)], fill=c('wood_dark'))
        d.rectangle([wx - 2, 70, wx + 30, 72], fill=c('frame'))
    # sign board
    d.rectangle([118, 20, 202, 40], fill=c('wood'), outline=c('outline'))
    d.rectangle([121, 23, 199, 37], fill=c('wood_dark'))
    for i, x in enumerate(range(127, 196, 8)):
        d.rectangle([x, 28, x + 3, 31], fill=c('gold') if i % 2 == 0 else c('violet'))
    # ceiling beam + string lights (two swags)
    d.rectangle([0, 0, 319, 13], fill=c('wood_deep'))
    d.line([(0, 13), (319, 13)], fill=c('outline'))
    bulbs = ['gold', 'violet', 'green', 'red', 'gold']
    for sx0, sx1 in ((0, 160), (160, 319)):
        prev = None
        for i in range(0, 41):
            t = i / 40
            x = round(sx0 + (sx1 - sx0) * t)
            y = round(15 + 12 * math.sin(math.pi * t))
            if prev:
                d.line([prev, (x, y)], fill=c('outline'))
            prev = (x, y)
            if i % 5 == 2:
                col = c(bulbs[(i // 5 + sx0 // 160) % len(bulbs)])
                d.rectangle([x - 1, y + 1, x + 1, y + 3], fill=col)
                d.point((x, y + 4), fill=mix(col, (255, 255, 255), 0.5))
    # floor
    d.rectangle([0, 112, 319, 179], fill=c('wood'))
    for y in range(112, 180, 6):
        d.line([(0, y), (319, y)], fill=c('wood_dark'))
        off = (y // 6) % 2 * 20
        for x in range(off, 320, 40):
            d.line([(x, y), (x, y + 5)], fill=c('wood_dark'))
    rng = random.Random(4)
    for _ in range(140):
        x, y = rng.randrange(320), rng.randrange(113, 180)
        d.point((x, y), fill=c('wood_dark') if rng.random() < 0.6 else c('frame'))
    # 4 empty spots: round rugs where cabinets stand
    for cx in (52, 124, 196, 268):
        d.ellipse([cx - 30, 120, cx + 30, 140], fill=c('violet_deep'), outline=c('outline'))
        d.ellipse([cx - 25, 123, cx + 25, 137], outline=c('gold_deep'))
    # warm lamp glow dither on floor center
    for y in range(146, 180):
        for x in range(0, 320):
            if (x + y) % 4 == 0 and abs(x - 160) < 120 - (y - 146) * 2:
                d.point((x, y), fill=c('frame'))
    img.save(out / 'hall_bg.png')


# ---------------------------------------------------------------------------
# "pixel arcade cabinet, wooden body with violet trim and gold star on top,
#  glowing screen, front view, 96x160" (x4: blue, violet, gold, green screens)
SCREENS = {'blue': (P['blue'], P['blue_deep']), 'violet': (P['violet'], P['violet_deep']),
           'gold': (P['gold'], P['gold_deep']), 'green': ((120, 200, 100), P['green'])}


def star(d, cx, cy, r, fill, outline):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=fill, outline=outline)


def cabinet(out, name):
    hi, lo = SCREENS[name]
    img, d = canvas(48, 80)
    star(d, 24, 6, 6.4, c('gold'), c('outline'))
    # marquee
    d.rectangle([4, 12, 43, 21], fill=c('violet'), outline=c('outline'))
    d.line([(6, 14), (41, 14)], fill=c('parch_hi'))
    for x in range(9, 40, 6):
        d.point((x, 17), fill=c('gold'))
    # body
    d.rectangle([3, 21, 44, 79], fill=c('wood'), outline=c('outline'))
    d.rectangle([0, 46, 47, 52], fill=c('violet_deep'), outline=c('outline'))  # control deck spans full width
    d.line([(1, 47), (46, 47)], fill=c('violet'))
    # screen
    d.rectangle([8, 24, 39, 44], fill=c('outline'))
    d.rectangle([10, 26, 37, 42], fill=lo + (255,))
    for y in range(26, 43):
        for x in range(10, 38):
            if (x + y) % 2 == 0 and 12 <= x <= 35 and 28 <= y <= 40:
                d.point((x, y), fill=hi + (255,))
    d.line([(11, 27), (16, 27)], fill=c('parch_hi'))
    # joystick and buttons
    d.line([(12, 44), (12, 49)], fill=c('outline'))
    d.rectangle([11, 42, 13, 44], fill=c('red'), outline=c('outline'))
    for i, bx in enumerate((28, 34, 40)):
        d.rectangle([bx - 2, 48, bx, 50], fill=c(['gold', 'green', 'red'][i]))
    # lower body
    d.rectangle([7, 56, 40, 74], fill=c('wood_dark'), outline=c('outline'))
    d.rectangle([20, 61, 27, 66], fill=c('outline'))  # coin slot
    d.rectangle([22, 62, 25, 65], fill=c('gold'))
    d.line([(4, 22), (4, 78)], fill=c('violet'))
    d.line([(43, 22), (43, 78)], fill=c('violet'))
    d.rectangle([3, 76, 44, 79], fill=c('wood_deep'), outline=c('outline'))
    img.save(out / f'cabinet_{name}.png')


# ---------------------------------------------------------------------------
# "night lake fishing scene background with moon reflection and wooden pier,
#  1280x720, no characters"
def lake(out):
    img, d = canvas(320, 180)
    dither_gradient(d, 0, 0, 320, 96, c('night'), c('dusk'), 6)
    rng = random.Random(9)
    for _ in range(70):
        x, y = rng.randrange(320), rng.randrange(0, 80)
        d.point((x, y), fill=c('parch_hi') if rng.random() < 0.3 else c('teal_soft'))
    d.ellipse([236, 14, 260, 38], fill=c('parch'), outline=c('gold'))
    d.ellipse([242, 18, 248, 24], fill=c('parch_hi'))
    d.point((252, 30), fill=c('frame'))
    # far hills and pine silhouettes
    for x in range(320):
        y = round(84 + 6 * math.sin(x / 23) + 3 * math.sin(x / 7))
        d.line([(x, y), (x, 96)], fill=c('dusk_mid'))
    for x in range(4, 320, 13):
        h = 8 + (x * 7) % 9
        d.polygon([(x, 96 - h), (x - 4, 96), (x + 4, 96)], fill=c('night'))
    # water
    dither_gradient(d, 0, 96, 320, 180, c('violet_deep'), c('night'), 5)
    for y in range(98, 180, 5):
        for x in range((y * 3) % 17, 320, 17):
            d.line([(x, y), (x + 4, y)], fill=c('violet'))
    # moon reflection
    for i, y in enumerate(range(100, 170, 4)):
        w = 10 - i // 3
        if w > 0:
            d.line([(248 - w, y), (248 + w, y)], fill=c('parch') if i % 2 == 0 else c('gold'))
    # pier
    d.polygon([(0, 132), (112, 132), (124, 142), (0, 142)], fill=c('wood'), outline=c('outline'))
    for x in range(8, 112, 10):
        d.line([(x, 133), (x + 2, 141)], fill=c('wood_dark'))
    d.rectangle([0, 142, 124, 147], fill=c('wood_dark'), outline=c('outline'))
    for px in (8, 52, 100):
        d.rectangle([px, 147, px + 5, 179], fill=c('wood_deep'), outline=c('outline'))
    d.rectangle([104, 118, 108, 132], fill=c('wood_deep'), outline=c('outline'))
    d.rectangle([101, 114, 111, 118], fill=c('gold_deep'), outline=c('outline'))  # lantern post
    d.rectangle([103, 110, 109, 114], fill=c('gold'), outline=c('outline'))
    img.save(out / 'lake_bg.png')


# ---------------------------------------------------------------------------
# "fishing bobber red and white, 3 frames bobbing strip, 24x24 each"
def bobber(out):
    img, d = canvas(36, 12)
    for f, dy in enumerate((0, 1, 2)):
        ox = f * 12
        d.line([(ox + 6, 0), (ox + 6, 3 + dy)], fill=c('outline'))
        d.ellipse([ox + 3, 3 + dy, ox + 9, 9 + dy], fill=c('white'), outline=c('outline'))
        d.rectangle([ox + 4, 4 + dy, ox + 8, 5 + dy], fill=c('red'))
        d.line([(ox, 11), (ox + 11, 11)], fill=c('teal_soft'))
        d.point((ox + 2 + f, 10), fill=c('teal_soft'))
    img.save(out / 'bobber.png')


# ---------------------------------------------------------------------------
# "collection of 10 cute fantasy fish icons in one row, glowing rare ones
#  have sparkles, 48x48 each" (order = arcade_fishing_core.js FISH)
FISH = [
    ('stone', 'parch', False), ('moss', 'gold', False),
    ('gold_deep', 'gold', False), ('violet', 'pink', False),
    ('red', 'white', False), ('green', 'moss', False),
    ('blue', 'gold', True), ('teal_soft', 'violet', True),
    ('blue_deep', 'parch_hi', True), ('gold', 'red', True),
]


def fish(out):
    img, d = canvas(240, 24)
    for i, (body, accent, sparkle) in enumerate(FISH):
        ox = i * 24
        d.ellipse([ox, 0, ox + 23, 23], fill=c('night'), outline=c('violet_deep'))
        big = i >= 8
        bx0, bx1 = ox + (4 if big else 5), ox + (17 if big else 16)
        by0, by1 = (6, 17) if big else (8, 16)
        d.polygon([(bx1 - 1, 12), (ox + 21, by0 + 1), (ox + 21, by1 - 1)], fill=c(accent), outline=c('outline'))
        d.ellipse([bx0, by0, bx1, by1], fill=c(body), outline=c('outline'))
        d.line([(bx0 + 3, by1 - 2), (bx1 - 3, by1 - 2)], fill=mix(c(body), (255, 255, 255), 0.35))
        d.point((bx0 + 3, by0 + 3), fill=c('outline'))
        d.point((bx0 + 2, by0 + 3), fill=c('white'))
        d.line([(bx0 + 6, by0 - 1), (bx0 + 9, by0 - 1)], fill=c(accent))
        if i == 9:
            d.point((bx0 + 1, by0 + 6), fill=c('red'))  # little dragon whisker
            d.line([(bx0, by0 + 6), (bx0 - 2, by0 + 8)], fill=c('gold_deep'))
        if sparkle:
            for sx, sy in ((ox + 4, 4), (ox + 19, 5), (ox + 17, 19)):
                d.point((sx, sy), fill=c('parch_hi'))
                d.point((sx - 1, sy), fill=c('gold'))
                d.point((sx + 1, sy), fill=c('gold'))
                d.point((sx, sy - 1), fill=c('gold'))
                d.point((sx, sy + 1), fill=c('gold'))
    img.save(out / 'fish.png')


# ---------------------------------------------------------------------------
# "clock tower rhythm game background, inside a bell tower at dusk, 3 vertical
#  lanes of brass, 720x1280"
def tower(out):
    img, d = canvas(180, 320)
    d.rectangle([0, 0, 179, 319], fill=c('stone_dark'))
    for y in range(0, 320, 8):
        off = (y // 8) % 2 * 10
        d.line([(0, y), (179, y)], fill=c('outline'))
        for x in range(off, 180, 20):
            d.line([(x, y), (x, y + 7)], fill=c('outline'))
    rng = random.Random(3)
    for _ in range(300):
        d.point((rng.randrange(180), rng.randrange(320)), fill=c('stone'))
    # arched window, dusk sky
    d.rectangle([60, 18, 120, 84], fill=c('outline'))
    d.ellipse([60, 2, 120, 50], fill=c('outline'))
    d.ellipse([63, 5, 117, 47], fill=(240, 160, 120, 255))
    dither_gradient(d, 63, 26, 118, 82, (240, 160, 120), c('violet_deep'), 5)
    d.line([(90, 6), (90, 82)], fill=c('wood_dark'))
    # bell
    d.rectangle([40, 86, 140, 92], fill=c('wood_deep'), outline=c('outline'))
    d.polygon([(76, 94), (104, 94), (114, 128), (66, 128)], fill=c('gold_deep'), outline=c('outline'))
    d.line([(80, 98), (76, 124)], fill=c('gold'))
    d.rectangle([62, 128, 118, 132], fill=c('gold'), outline=c('outline'))
    d.ellipse([86, 132, 94, 140], fill=c('gold_deep'), outline=c('outline'))
    # three brass lanes
    for i, x0 in enumerate((18, 72, 126)):
        d.rectangle([x0, 146, x0 + 36, 319], fill=c('wood_deep'), outline=c('outline'))
        d.line([(x0 + 2, 147), (x0 + 2, 318)], fill=c('gold_deep'))
        d.line([(x0 + 34, 147), (x0 + 34, 318)], fill=c('gold_deep'))
        for y in range(160, 320, 24):
            d.point((x0 + 2, y), fill=c('gold'))
            d.point((x0 + 34, y), fill=c('gold'))
    # judgement plate
    d.rectangle([0, 284, 179, 290], fill=c('gold'), outline=c('outline'))
    d.line([(0, 286), (179, 286)], fill=c('parch_hi'))
    img.save(out / 'tower_bg.png')


# ---------------------------------------------------------------------------
# "rhythm note gem, 3 colours violet gold green, 32x32 each, in one row"
def gems(out):
    img, d = canvas(48, 16)
    for i, (hi, lo) in enumerate((('violet', 'violet_deep'), ('gold', 'gold_deep'), ('moss', 'green'))):
        ox = i * 16
        d.polygon([(ox + 7, 0), (ox + 8, 0), (ox + 15, 7), (ox + 15, 8), (ox + 8, 15), (ox + 7, 15), (ox, 8), (ox, 7)],
                  fill=c(lo), outline=c('outline'))
        d.polygon([(ox + 7, 2), (ox + 12, 7), (ox + 7, 12), (ox + 3, 7)], fill=c(hi))
        d.line([(ox + 5, 5), (ox + 7, 3)], fill=c('parch_hi'))
    img.save(out / 'gems.png')


# ---------------------------------------------------------------------------
# "memory card back design, wooden frame with violet center and gold star, 64x80"
def card_back(out):
    img, d = canvas(32, 40)
    d.rectangle([0, 0, 31, 39], fill=c('wood'), outline=c('outline'))
    d.rectangle([2, 2, 29, 37], outline=c('frame'))
    d.rectangle([4, 4, 27, 35], fill=c('violet_deep'), outline=c('outline'))
    for y in range(5, 35):
        for x in range(5, 27):
            if (x + y) % 4 == 0:
                d.point((x, y), fill=c('violet'))
    star(d, 15.5, 19.5, 8, c('gold'), c('outline'))
    for x, y in ((1, 1), (30, 1), (1, 38), (30, 38)):
        d.point((x, y), fill=c('gold'))
    img.save(out / 'card_back.png')


def card_faces(repo: Path, out_dir: Path):
    """64x64 card art from existing App images (no new characters)."""
    out_dir.mkdir(parents=True, exist_ok=True)
    chars = repo / 'web_dashboard/assets/avatar/icons'
    for i in (0, 3, 6, 9, 12, 15):
        im = Image.open(chars / f'icon_{i}.png').convert('RGBA')
        im.resize((64, 64), Image.LANCZOS).save(out_dir / f'c{i}.png', optimize=True)
    badge = Image.open(repo / 'assets/home/badge.png').convert('RGBA')
    fit(badge, 48).save(out_dir / 'badge.png', optimize=True)
    for name in ('focus', 'quest', 'health', 'stats', 'room', 'letter', 'calendar', 'social'):
        im = Image.open(repo / f'assets/ui/icons/icon_{name}.png').convert('RGBA')
        fit(im, 48).save(out_dir / f'{name}.png', optimize=True)


def fit(im, size):
    """Fit inside size x size on a transparent square (keeps aspect)."""
    box = im.getbbox() or (0, 0, im.width, im.height)
    im = im.crop(box)
    ratio = size / max(im.width, im.height)
    small = im.resize((max(1, round(im.width * ratio)), max(1, round(im.height * ratio))), Image.LANCZOS)
    sq = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    sq.paste(small, ((size - small.width) // 2, (size - small.height) // 2), small)
    return sq


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    hall(out); lake(out); tower(out); bobber(out); fish(out); gems(out); card_back(out)
    for name in SCREENS:
        cabinet(out, name)
    for f in sorted(out.glob('*.png')):
        im = Image.open(f).convert('RGBA')
        px = im.load()
        keyed = Image.new('L', im.size, 0)
        kp = keyed.load()
        for y in range(im.height):
            for x in range(im.width):
                r, g, b, _ = px[x, y]
                kp[x, y] = 0 if (r, g, b) == (255, 0, 255) else 255
        assert keyed.getbbox() == (0, 0, im.width, im.height), f'{f.name} must touch every edge'
        print('drew', f.name, im.size)
    repo = Path(__file__).resolve().parents[2]
    card_faces(repo, repo / 'web_dashboard/assets/arcade/cards')
    print('wrote card faces')


if __name__ == '__main__':
    main()
