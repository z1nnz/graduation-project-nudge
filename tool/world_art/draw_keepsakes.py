"""The 24 keepsakes of the collection book (J10) as one pixel atlas.

  python -I tool/world_art/draw_keepsakes.py [--preview <png>]

24x24 cells, 6 columns x 4 rows, in CollectionBook.catalog order (16 common,
then 8 rare). Written to web_dashboard/assets/scenes/collection/keepsakes.png
and assets/scenes/collection/keepsakes.png.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'character_art'))
import draw_player as dp  # noqa: E402

S = 24
dp.W = dp.H = S
R, P, E, D = dp.rect, dp.pix, dp.empty, dp.darken
GOLD, GOLD_SH = dp.GOLD, dp.GOLD_SH


def ell(cx, cy, rx, ry):
    ys, xs = np.mgrid[0:S, 0:S]
    return ((xs + 0.5 - cx) / rx) ** 2 + ((ys + 0.5 - cy) / ry) ** 2 <= 1


def poly(pts):
    im = Image.new('L', (S, S), 0)
    ImageDraw.Draw(im).polygon(pts, fill=255)
    return np.asarray(im) > 0


def line(p0, p1, w=1):
    return dp.stamp(dp.line_pts(p0, p1), w, w)


def star(cx, cy, r1, r2, n=5, rot=-math.pi / 2):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = rot + i * math.pi / n
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return poly(pts)


def item(kind):
    L = dp.Layer()
    part = L.part
    if kind == 'acorn':
        part(ell(12, 14, 6, 7), (176, 112, 64), shade=(130, 78, 44))
        part(ell(12, 8, 7, 3.5), (110, 74, 44), shade=(80, 52, 30))
        part(R(11, 3, 12, 5), (90, 56, 38))
    elif kind == 'leaf':
        part(star(12, 12, 9, 4, 5), (226, 110, 52), shade=(176, 72, 32))
        L.fill(line((12, 12), (12, 21)) | line((12, 12), (6, 8)) | line((12, 12), (18, 8)), (150, 60, 30))
    elif kind == 'shell':
        part(poly([(3, 18), (12, 3), (21, 18), (12, 21)]), (248, 214, 210), shade=(220, 160, 166))
        for x in (7, 10, 14, 17):
            L.fill(line((12, 5), (x, 19)), (214, 140, 150))
    elif kind == 'pencil':
        part(poly([(4, 20), (6, 15), (17, 4), (20, 7), (9, 18)]), (244, 196, 70), shade=(200, 150, 40))
        part(poly([(4, 20), (6, 15), (9, 18)]), (246, 220, 180))
        L.fill(P([(4, 20), (5, 19)]), (60, 40, 40))
        part(poly([(17, 4), (20, 7), (21, 6), (18, 3)]), (240, 140, 160))
    elif kind == 'tea':
        part(R(5, 9, 16, 19), (246, 236, 214), shade=(210, 196, 176))
        part(R(17, 11, 19, 15) & ~R(17, 12, 18, 14), (246, 236, 214))
        L.fill(R(6, 9, 15, 10), (170, 90, 50))
        L.fill(P([(8, 6), (9, 4), (11, 6), (12, 4), (13, 6)]), (220, 220, 230))
        part(R(3, 20, 18, 21), (200, 170, 140))
    elif kind == 'candle':
        part(R(8, 9, 15, 21), (246, 236, 214), shade=(210, 196, 176))
        part(ell(11.5, 5.5, 2, 3.5), (255, 197, 77), ring_color=(196, 113, 11))
        L.fill(P([(11, 6), (12, 6)]), (255, 250, 220))
        part(R(5, 20, 18, 22), (196, 113, 11), shade=(150, 80, 10))
    elif kind == 'clover':
        for cx, cy in ((8, 8), (16, 8), (8, 15), (16, 15)):
            part(ell(cx, cy, 4, 4), (96, 176, 80), shade=(62, 120, 52))
        L.fill(line((12, 12), (15, 22)), (62, 120, 52))
    elif kind == 'feather':
        part(poly([(19, 2), (22, 4), (9, 18), (6, 16)]), (246, 240, 255), shade=(190, 180, 220))
        L.fill(line((20, 3), (4, 21)), (120, 100, 160))
    elif kind == 'mushroom':
        part(ell(12, 10, 9, 6) & R(0, 0, 23, 12), (216, 69, 46), shade=(160, 44, 30))
        part(R(9, 12, 14, 20), (246, 236, 214), shade=(210, 196, 176))
        L.fill(P([(8, 7), (9, 7), (15, 6), (16, 6), (12, 9)]), (255, 250, 240))
    elif kind == 'cookie':
        part(ell(12, 12, 9, 9), (200, 140, 76), shade=(150, 96, 50))
        L.fill(P([(8, 8), (14, 7), (16, 13), (9, 15), (12, 12), (13, 17)]), (82, 48, 34))
    elif kind == 'button':
        part(ell(12, 12, 8, 8), (120, 150, 210), shade=(80, 100, 160))
        L.fill(P([(10, 10), (14, 10), (10, 14), (14, 14)]), (40, 50, 90))
    elif kind == 'stamp':
        m = R(4, 4, 19, 19)
        teeth = P([(x, y) for x in range(4, 20, 2) for y in (4, 19)] + [(x, y) for y in range(4, 20, 2) for x in (4, 19)])
        part(m & ~teeth, (246, 231, 200), ring_color=(190, 160, 120))
        part(R(7, 7, 16, 16), (139, 108, 240), shade=(75, 47, 168))
        part(star(11.5, 11.5, 4, 1.8), GOLD)
    elif kind == 'marble':
        part(ell(12, 12, 8, 8), (110, 190, 220), shade=(60, 130, 180))
        L.fill(line((8, 14), (15, 9), 2) & ell(12, 12, 7, 7), (230, 100, 160))
        L.fill(P([(9, 8), (10, 8), (9, 9)]), (255, 255, 255))
    elif kind == 'ribbon':
        part(poly([(12, 11), (3, 5), (3, 17)]) | poly([(12, 11), (21, 5), (21, 17)]), (240, 140, 170), shade=(200, 90, 130))
        part(poly([(11, 12), (7, 21), (10, 21), (12, 14), (14, 21), (17, 21), (13, 12)]), (220, 100, 140))
        part(R(10, 9, 13, 13), (250, 180, 200))
    elif kind == 'key':
        part(ell(7, 8, 5, 5) & ~ell(7, 8, 2, 2), GOLD, shade=GOLD_SH)
        part(line((10, 11), (20, 21), 2), GOLD, shade=GOLD_SH)
        part(R(15, 18, 17, 20) | R(18, 15, 20, 17), GOLD, shade=GOLD_SH)
    elif kind == 'flower':
        part(R(4, 3, 19, 21), (246, 231, 200), shade=(214, 188, 146))
        for a in range(5):
            ang = a * 2 * math.pi / 5
            part(ell(12 + math.cos(ang) * 3.5, 11 + math.sin(ang) * 3.5, 2.5, 2.5), (250, 220, 90), ring=False)
        L.fill(ell(12, 11, 1.6, 1.6), (220, 120, 40))
        L.fill(line((12, 14), (12, 19)), (98, 160, 80))
    elif kind == 'star':
        part(star(12, 12, 10, 4.5), GOLD, shade=GOLD_SH)
        L.fill(P([(2, 21), (4, 19), (6, 17)]), (255, 240, 200))
        L.fill(P([(11, 8), (12, 9)]), (255, 255, 230))
    elif kind == 'crown':
        part(poly([(3, 18), (3, 7), (8, 12), (12, 5), (16, 12), (21, 7), (21, 18)]), (246, 231, 200), shade=(214, 188, 146))
        L.fill(P([(8, 15), (12, 15), (16, 15)]), (216, 69, 46))
        part(R(3, 18, 21, 20), GOLD, shade=GOLD_SH)
    elif kind == 'compass':
        part(ell(12, 12, 9, 9), GOLD, shade=GOLD_SH)
        part(ell(12, 12, 6.5, 6.5), (246, 236, 214), ring=False)
        L.fill(poly([(12, 6), (14, 12), (12, 13), (10, 12)]), (216, 69, 46))
        L.fill(poly([(12, 18), (10, 12), (12, 11), (14, 12)]), (60, 60, 80))
    elif kind == 'crystal':
        part(poly([(12, 2), (19, 9), (12, 22), (5, 9)]), (170, 150, 250), shade=(110, 90, 210))
        L.fill(poly([(12, 2), (15, 9), (12, 20), (9, 9)]), (210, 200, 255))
        L.fill(P([(10, 7), (11, 6)]), (255, 255, 255))
    elif kind == 'lantern':
        part(R(11, 1, 12, 3), (90, 56, 38))
        part(ell(12, 12, 7, 8), (216, 69, 46), shade=(160, 44, 30))
        L.fill(ell(12, 12, 3, 5), (255, 197, 77))
        part(R(9, 3, 14, 5) | R(9, 19, 14, 21), (90, 56, 38))
    elif kind == 'scroll':
        part(R(5, 6, 18, 18), (246, 231, 200), shade=(214, 188, 146))
        part(ell(5, 12, 2.5, 7.5) | ell(18, 12, 2.5, 7.5), (196, 150, 90), shade=(150, 100, 60))
        for y in (9, 12, 15):
            L.fill(R(8, y, 15, y), (150, 110, 80))
    elif kind == 'rainbow':
        part(R(8, 2, 15, 5), (139, 90, 52))
        part(ell(12, 14, 7, 8) | R(9, 5, 14, 8), (200, 230, 246), shade=(150, 190, 220))
        for i, c in enumerate([(226, 70, 70), (244, 170, 60), (250, 220, 90), (100, 190, 110), (90, 140, 230)]):
            L.fill(R(6, 10 + i * 2, 17, 10 + i * 2) & ell(12, 14, 6, 7), c)
    elif kind == 'egg':
        part(ell(12, 13, 7, 9), (246, 240, 228), shade=(214, 200, 190))
        L.fill(P([(8, 12), (9, 11), (10, 12), (11, 11), (12, 12), (13, 11), (14, 12), (15, 11), (16, 12)]), (139, 108, 240))
        L.fill(P([(9, 16), (14, 8), (15, 17)]), (255, 197, 77))
    return L.a


ORDER = ['acorn', 'leaf', 'shell', 'pencil', 'tea', 'candle', 'clover', 'feather', 'mushroom', 'cookie', 'button',
         'stamp', 'marble', 'ribbon', 'key', 'flower', 'star', 'crown', 'compass', 'crystal', 'lantern', 'scroll',
         'rainbow', 'egg']


def main(argv):
    atlas = np.zeros((4 * S, 6 * S, 4), np.uint8)
    for i, k in enumerate(ORDER):
        a = item(k)
        assert (a[..., 3] > 0).sum() > 40, k
        atlas[(i // 6) * S:(i // 6 + 1) * S, (i % 6) * S:(i % 6 + 1) * S] = a
    root = Path(__file__).resolve().parents[2]
    for d in (root / 'web_dashboard/assets/scenes/collection', root / 'assets/scenes/collection'):
        d.mkdir(parents=True, exist_ok=True)
        Image.fromarray(atlas, 'RGBA').save(d / 'keepsakes.png', optimize=True)
    if '--preview' in argv:
        bg = Image.new('RGBA', (atlas.shape[1], atlas.shape[0]), (70, 58, 92, 255))
        bg.alpha_composite(Image.fromarray(atlas, 'RGBA'))
        bg.resize((bg.width * 5, bg.height * 5), Image.NEAREST).save(argv[argv.index('--preview') + 1])
    print('keepsakes written')


if __name__ == '__main__':
    main(sys.argv[1:])
