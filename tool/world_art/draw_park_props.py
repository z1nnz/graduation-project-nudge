"""Park props for the two new rides (J6): firefly lantern post and telescope.

  python -I tool/world_art/draw_park_props.py

Keyed PNG to web_dashboard/assets/scenes/park/ and assets/scenes/park/.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'character_art'))
import draw_player as dp  # noqa: E402

WOOD, WOOD_SH = (90, 56, 38), (58, 34, 22)


def lantern():
    dp.W, dp.H = 24, 56
    L = dp.Layer()
    L.part(dp.rect(10, 14, 13, 54), WOOD, shade=WOOD_SH)
    L.part(dp.rect(5, 52, 18, 55), WOOD_SH)
    L.part(dp.rect(13, 14, 20, 15), WOOD, shade=WOOD_SH)
    L.part(dp.rect(16, 16, 23, 30) & ~dp.pix([(16, 16), (23, 16), (16, 30), (23, 30)]), (255, 214, 107), shade=(220, 160, 50), ring_color=(90, 56, 38))
    L.fill(dp.rect(17, 19, 22, 27), (255, 245, 200))
    L.fill(dp.pix([(19, 22), (20, 23), (18, 25)]), (233, 255, 138))
    L.part(dp.rect(15, 15, 24, 16) & dp.rect(0, 0, 23, 55), (60, 40, 30))
    return L.a


def telescope():
    dp.W, dp.H = 40, 44
    L = dp.Layer()
    for leg in (((19, 22), (9, 42)), ((20, 22), (30, 42)), ((20, 22), (20, 42))):
        L.part(dp.stamp(dp.line_pts(*leg), 2, 1), WOOD, ring_color=WOOD_SH)
    tube = dp.stamp(dp.line_pts((6, 22), (32, 6)), 5, 4, ax=2, ay=2)
    L.part(tube, (139, 108, 240), shade=(75, 47, 168))
    L.part(dp.stamp(dp.line_pts((30, 7), (35, 4)), 6, 6, ax=3, ay=3), dp.GOLD, shade=dp.GOLD_SH)
    L.fill(dp.pix([(33, 3), (34, 3)]), (200, 230, 255))
    L.fill(dp.pix([(14, 16), (22, 12)]), dp.GOLD)
    return L.a


def main():
    root = Path(__file__).resolve().parents[2]
    out = {'lantern_post': lantern(), 'telescope': telescope()}
    for d in (root / 'web_dashboard/assets/scenes/park', root / 'assets/scenes/park'):
        for k, a in out.items():
            Image.fromarray(a, 'RGBA').save(d / f'{k}.png', optimize=True)
    print('park props written')


if __name__ == '__main__':
    main()
