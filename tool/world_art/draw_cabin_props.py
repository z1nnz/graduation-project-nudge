"""Cabin 3.0 props (J4) on the rug: folded futon, laid-out futon, blanket.

  python -I tool/world_art/draw_cabin_props.py

Drawn at native size with the player's outline rules; written as keyed PNG
to web_dashboard/assets/scenes/cabin/ and assets/scenes/cabin/. The blanket
goes over the sleeping companion, the futon under it.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'character_art'))
import draw_player as dp  # noqa: E402

QUILT, QUILT_SH, SHEET, PILLOW = (139, 108, 240), (75, 47, 168), (246, 236, 214), (255, 250, 240)


def canvas(w, h):
    dp.W, dp.H = w, h
    return dp.Layer()


def futon(open_):
    L = canvas(56, 22)
    L.part(dp.rect(2, 6, 53, 19), SHEET, shade=(214, 196, 170))
    L.part(dp.rect(4, 7, 15, 13), PILLOW, shade=(220, 214, 220))
    if open_:
        q = dp.rect(24, 6, 53, 19)
        L.part(q, QUILT, shade=QUILT_SH)
        L.part(dp.rect(18, 6, 24, 19), (180, 160, 250), shade=QUILT)  # folded-back edge
        L.fill(dp.pix([(30 + k * 6, 12 + (k % 2) * 3) for k in range(4)]), dp.GOLD)
    return L.a


def folded():
    L = canvas(30, 22)
    for i, y in enumerate((14, 9, 4)):
        L.part(dp.rect(2, y, 27, y + 5), QUILT if i != 1 else SHEET, shade=QUILT_SH if i != 1 else (214, 196, 170))
    L.part(dp.rect(8, 0, 21, 4), PILLOW, shade=(220, 214, 220))
    return L.a


def blanket():
    L = canvas(40, 14)
    q = dp.rect(1, 2, 38, 12) & ~dp.pix([(1, 2), (38, 2), (1, 12), (38, 12)])
    L.part(q, QUILT, shade=QUILT_SH)
    L.fill(dp.rect(2, 2, 37, 3), (180, 160, 250))
    L.fill(dp.pix([(8, 7), (16, 9), (24, 7), (32, 9)]), dp.GOLD)
    return L.a


def main():
    out = {'futon_open': futon(True), 'futon_folded': folded(), 'blanket': blanket()}
    root = Path(__file__).resolve().parents[2]
    for d in (root / 'web_dashboard/assets/scenes/cabin', root / 'assets/scenes/cabin'):
        d.mkdir(parents=True, exist_ok=True)
        for k, a in out.items():
            Image.fromarray(a, 'RGBA').save(d / f'{k}.png', optimize=True)
    print('cabin props written')


if __name__ == '__main__':
    main()
