"""Dressing room props (J2): standing mirror and clothes rack, native size.

  python -I tool/world_art/draw_dressing.py

Keyed PNG to web_dashboard/assets/scenes/dressing/ and assets/scenes/dressing/.
The mirror glass is left transparent: the reflection is the live player.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'character_art'))
import draw_player as dp  # noqa: E402

GOLD, GOLD_SH = dp.GOLD, dp.GOLD_SH
WOOD, WOOD_SH = (138, 90, 52), (90, 56, 38)


def mirror():
    dp.W, dp.H = 34, 64
    L = dp.Layer()
    frame = dp.rect(3, 2, 30, 54) & ~dp.rect(6, 6, 27, 51)
    frame &= ~dp.pix([(3, 2), (30, 2), (3, 3), (30, 3), (4, 2), (29, 2)])
    L.part(frame, GOLD, shade=GOLD_SH, ring_color=dp.darken(GOLD_SH, 0.5))
    L.part(dp.rect(14, 0, 19, 2), GOLD, shade=GOLD_SH, ring_color=dp.darken(GOLD_SH, 0.5))
    L.part(dp.rect(9, 55, 11, 62) | dp.rect(22, 55, 24, 62) | dp.rect(6, 61, 27, 62), WOOD, shade=WOOD_SH)
    return L.a


def rack():
    dp.W, dp.H = 96, 44
    L = dp.Layer()
    L.part(dp.rect(4, 6, 91, 8), WOOD, shade=WOOD_SH)
    L.part(dp.rect(6, 8, 8, 40) | dp.rect(87, 8, 89, 40), WOOD, shade=WOOD_SH)
    L.part(dp.rect(1, 40, 13, 42) | dp.rect(82, 40, 94, 42), WOOD_SH)
    L.part(dp.rect(2, 4, 6, 9) | dp.rect(89, 4, 93, 9), GOLD, shade=GOLD_SH)
    return L.a


def hanger():
    dp.W, dp.H = 20, 10
    L = dp.Layer()
    hook = dp.pix([(9, 0), (10, 0), (11, 1), (11, 2), (10, 3)])
    bar = dp.pix([(10 - k, 4 + k // 2) for k in range(9)] + [(10 + k, 4 + k // 2) for k in range(9)]) | dp.rect(2, 8, 18, 8)
    L.fill(hook, (200, 200, 210))
    L.part(bar, WOOD, ring_color=WOOD_SH)
    return L.a


def main():
    root = Path(__file__).resolve().parents[2]
    out = {'mirror': mirror(), 'rack': rack(), 'hanger': hanger()}
    for d in (root / 'web_dashboard/assets/scenes/dressing', root / 'assets/scenes/dressing'):
        d.mkdir(parents=True, exist_ok=True)
        for k, a in out.items():
            Image.fromarray(a, 'RGBA').save(d / f'{k}.png', optimize=True)
    print('dressing props written')


if __name__ == '__main__':
    main()
