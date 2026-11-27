"""Build the layered player from the earlier companion art (work package J1).

  python -I tool/character_art/recolor_player.py [--preview <dir>]

The companion sheet drawn before (assets/characters/companion/sheet.webp,
128 px cells) stays the base, so the player looks exactly like it. Layers:

  body       the companion itself; hair recoloured for the other hair colours
  outfit     only the jacket and shorts pixels, recoloured per colourway
  headwear   hats drawn per frame on top of the hair (the star clip is the
             companion's own; hats come off while sleeping)
  accessory  the scarf is the companion's own; round glasses sit on the eyes

Regions are found per frame: hair is blue above the chin line, the jacket is
blue below it, the shorts are the cream band above the boots. A "turn" row
(facing down, right, up, left) is added from the walk rows. Sheets go to
web_dashboard/assets/characters/player/ and assets/characters/player/ with
player.json.
"""
from __future__ import annotations

import colorsys
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import draw_player as dp  # noqa: E402  (pixel helpers)

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'assets/characters/companion/sheet.webp'
CELL = 128
FOOT = 123
COLS = 6

# Source rows (characters.json "companion" layout) and the player rows.
SRC_ROWS = [('idle', 4), ('walk_down', 4), ('walk_left', 4), ('walk_right', 4), ('walk_up', 4),
            ('happy', 6), ('wave', 4), ('think', 4), ('sleep', 4)]
ANIMS = [  # name, fps, loop  (8-12 fps for every character clip)
    ('idle', 8, True), ('turn', 8, True), ('walk_down', 8, True), ('walk_left', 8, True),
    ('walk_right', 8, True), ('walk_up', 8, True), ('happy', 10, False), ('wave', 8, False),
    ('think', 8, True), ('sleep', 8, True),
]
# Actions the art has no row for play the nearest one (the scenes add a
# small code-drawn motion on top).
ALIASES = {
    'look': 'idle', 'sit': 'idle', 'read': 'think', 'stretch': 'happy', 'snack': 'idle', 'talk': 'idle',
    'run_down': 'walk_down', 'run_left': 'walk_left', 'run_right': 'walk_right', 'run_up': 'walk_up',
}

HAIRS = [('navy', '夜空藍髮', None), ('chestnut', '栗子棕髮', (0.065, 0.62, 1.15, True)), ('rose', '莓果粉髮', (0.93, 0.42, 1.45, True))]
OUTFITS = [  # id, name, jacket (hue, sat scale, value scale) or None, shorts (hue, sat, value) or None
    ('adventurer', '冒險藍外套', None, None),
    ('forest', '森林綠外套', (0.31, 1.0, 1.05), None),
    ('sunset', '晚霞紅外套', (0.99, 1.05, 1.05), None),
    ('starnight', '星夜紫外套', (0.78, 1.0, 1.0), (0.78, 0.25, 0.95)),
    ('sunny', '晨光黃外套', (0.13, 0.85, 2.1), None),
    ('snow', '雪原白外套', (0.6, 0.12, 1.75), (0.62, 0.55, 0.62)),
]
HEADWEAR = [('starclip', '星星髮夾'), ('strawhat', '向陽草帽'), ('wizard', '星光巫師帽'),
            ('catears', '貓耳髮箍'), ('beanie', '暖暖毛線帽'), ('flowers', '春日花冠')]
ACCESSORIES = [('scarf', '白色長圍巾'), ('glasses', '圓框眼鏡')]


def hsv(a):
    rgb = a[..., :3].astype(float) / 255
    mx, mn = rgb.max(-1), rgb.min(-1)
    v = mx
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    h = np.zeros_like(v)
    d = np.maximum(mx - mn, 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6, h)
    h = np.where(mx == g, (b - r) / d + 2, h)
    h = np.where(mx == b, (r - g) / d + 4, h)
    return (h / 6) % 1, s, v


def regions(cell, row):
    a = cell[..., 3] > 0
    h, s, v = hsv(cell)
    blue = (h > 0.55) & (h < 0.76) & (s > 0.22) & a
    ys = np.where(a.any(1))[0]
    xs = np.where(a.any(0))[0]
    top, left, right = ys[0], xs[0], xs[-1]
    yy, xx = np.mgrid[0:CELL, 0:CELL]
    if row == 'sleep':  # lying, head on the left
        head = xx < left + 0.42 * (right - left)
        hair = blue & head
        jacket = blue & ~head
        cream = (s < 0.28) & (v > 0.72) & a
        shorts = cream & (xx > left + 0.62 * (right - left)) & (xx < left + 0.82 * (right - left))
    else:
        chin = top + 0.36 * (FOOT - top)
        hair = blue & (yy < chin)
        jacket = blue & (yy >= chin)
        cream = (s < 0.28) & (v > 0.72) & a
        shorts = cream & (yy > top + 0.7 * (FOOT - top)) & (yy < top + 0.83 * (FOOT - top))
    hb = np.argwhere(hair)
    head_box = (hb[:, 1].min(), hb[:, 0].min(), hb[:, 1].max(), hb[:, 0].max()) if len(hb) else (left, top, right, top + 30)
    return {'hair': hair, 'jacket': jacket, 'shorts': shorts, 'head': head_box, 'top': top, 'h': h, 's': s, 'v': v}


def recolor(cell, mask, R, hue, sat, val, absolute_sat=False):
    out = np.zeros_like(cell)
    ys, xs = np.where(mask)
    for y, x in zip(ys, xs):
        s = sat if absolute_sat else min(1, R['s'][y, x] * sat)
        v = min(1, R['v'][y, x] * val)
        r, g, b = colorsys.hsv_to_rgb(hue, s, v)
        out[y, x] = (round(r * 255), round(g * 255), round(b * 255), cell[y, x, 3])
    return out


# ---------------------------------------------------------------- hats

GOLD, GOLD_SH = dp.GOLD, dp.GOLD_SH


def hat(kind, box, side, flip):
    """A hat sized to the hair box (x0, y0, x1, y1) in a 128 px cell."""
    dp.W = dp.H = CELL
    L = dp.Layer()
    x0, y0, x1, y1 = box
    y0 += 9  # under the crown tuft, on the hair itself
    w = x1 - x0
    cx = (x0 + x1) // 2
    R = dp.rect
    if kind == 'strawhat':
        straw, sh = (238, 200, 118), (196, 150, 76)
        brim = R(x0 - 6, y0 + 12, x1 + 6, y0 + 17) & ~dp.pix([(x0 - 6, y0 + 12), (x1 + 6, y0 + 12), (x0 - 6, y0 + 17), (x1 + 6, y0 + 17)])
        crown = R(cx - w // 3, y0 - 4, cx + w // 3, y0 + 12) & ~dp.pix([(cx - w // 3, y0 - 4), (cx + w // 3, y0 - 4)])
        L.part(crown | brim, straw, shade=sh, ring_color=dp.darken(sh, 0.5))
        L.fill(R(cx - w // 3, y0 + 7, cx + w // 3, y0 + 10), (206, 70, 70))
        L.fill(dp.pix([(x0 - 3 + k * 5, y0 + 15) for k in range(w // 5 + 2)]), sh)
        L.fill(dp.pix([(cx - w // 3 + 3 + k * 5, y0 + 2 + (k % 2) * 2) for k in range(w // 8)]), sh)
    elif kind == 'wizard':
        cloth, sh = (86, 60, 160), (58, 38, 116)
        brim = R(x0 - 5, y0 + 13, x1 + 5, y0 + 18) & ~dp.pix([(x0 - 5, y0 + 13), (x1 + 5, y0 + 13)])
        cone = dp.empty()
        for k, y in enumerate(range(y0 + 13, y0 - 26, -1)):
            half = max(1, int(w * 0.36) - k // 2)
            bend = (k * k) // 90 * (-1 if flip else 1)
            cone |= R(cx - half + bend, y, cx + half + bend, y)
        L.part(cone | brim, cloth, shade=sh, ring_color=dp.darken(sh, 0.5))
        L.fill(R(cx - int(w * 0.34), y0 + 9, cx + int(w * 0.34), y0 + 12), GOLD)
        L.art(dp.template(["...G...", "..GGG..", "GGGGGGG", ".GGGGG.", "..GgG..", ".GG.GG.", "Gg...gG"], cx - 3, y0 - 6,
                          {'G': GOLD, 'g': GOLD_SH}), dp.darken(GOLD_SH, 0.5))
    elif kind == 'catears':
        fur, inner = (236, 230, 220), (246, 170, 186)
        for ex in ([x0 + 4, x1 - 14] if not side else [cx - 4]):
            m = dp.empty()
            for k in range(12):
                hw = k // 2 + 1
                m |= R(ex + 5 - hw, y0 - 6 + k, ex + 5 + hw, y0 - 6 + k)
            L.part(m, fur, shade=(200, 194, 190), ring_color=dp.darken(fur, 0.45))
            L.fill(m & dp.shift(m, 2, 0) & dp.shift(m, -2, 0) & dp.shift(m, 0, 2), inner)
        L.fill(R(x0 + 4, y0 + 6, x1 - 4, y0 + 7), (70, 60, 70))
    elif kind == 'beanie':
        knit, sh, cuff = (96, 168, 150), (62, 120, 108), (168, 214, 196)
        dome = dp.empty()
        for k in range(18):
            t = k / 17
            half = int((w / 2 + 3) * (0.55 + 0.45 * np.sin(t * np.pi / 2)))
            dome |= R(cx - half, y0 - 4 + k, cx + half, y0 - 4 + k)
        L.part(dome, knit, shade=sh, ring_color=dp.darken(sh, 0.5))
        L.fill(dp.pix([(cx - w // 2 + k * 4, y0 + 2 + (k % 3) * 3) for k in range(w // 4 + 1)]), sh)
        cm = R(x0 - 3, y0 + 13, x1 + 3, y0 + 18)
        L.part(cm, cuff, shade=sh, ring_color=dp.darken(sh, 0.5))
        L.fill(dp.pix([(x, y) for x in range(x0 - 2, x1 + 3, 2) for y in (y0 + 14, y0 + 16)]), knit)
        L.part(R(cx - 5, y0 - 12, cx + 5, y0 - 4) & ~dp.pix([(cx - 5, y0 - 12), (cx + 5, y0 - 12), (cx - 5, y0 - 4), (cx + 5, y0 - 4)]),
               dp.WHITE, shade=(220, 214, 220), ring_color=(140, 130, 150))
    elif kind == 'flowers':
        leaf, leaf_sh = (98, 160, 80), (62, 112, 52)
        L.part(R(x0 + 2, y0 + 9, x1 - 2, y0 + 11), leaf, shade=leaf_sh, ring_color=dp.darken(leaf_sh, 0.6))
        cols = [(240, 140, 170), dp.WHITE, GOLD, (190, 150, 240)]
        n = 5 if not side else 3
        for k in range(n):
            x = x0 + 6 + k * (w - 12) // max(1, n - 1)
            c = cols[k % len(cols)]
            fl = dp.template(["..pp..", ".pppp.", "ppccpp", "ppccpp", ".pppp.", "..pp.."], x - 3, y0 + 4, {'p': c, 'c': GOLD if c != GOLD else dp.WHITE})
            L.art(fl, dp.darken(c, 0.5))
    a = L.a
    return a


def glasses(box, row, frame_dir):
    dp.W = dp.H = CELL
    L = dp.Layer()
    x0, y0, x1, y1 = box
    cx = (x0 + x1) // 2
    ey = y0 + 31
    frame, lens = (70, 50, 40), (200, 230, 246)
    if frame_dir == 'down':
        eyes = [cx - 9, cx + 4]
    elif frame_dir == 'left':
        eyes = [x0 + 10]
    elif frame_dir == 'right':
        eyes = [x1 - 17]
    else:
        return L.a
    for ex in eyes:
        ring = dp.rect(ex, ey, ex + 7, ey + 7) & ~dp.rect(ex + 1, ey + 1, ex + 6, ey + 6)
        L.fill(ring & ~dp.pix([(ex, ey), (ex + 7, ey), (ex, ey + 7), (ex + 7, ey + 7)]), frame)
        L.fill(dp.pix([(ex + 5, ey + 1), (ex + 4, ey + 2), (ex + 5, ey + 2)]), lens)
    if len(eyes) == 2:
        L.fill(dp.rect(eyes[0] + 8, ey + 3, eyes[1] - 1, ey + 3), frame)
    elif frame_dir == 'left':
        L.fill(dp.rect(eyes[0] + 8, ey + 3, eyes[0] + 14, ey + 3), frame)
    else:
        L.fill(dp.rect(eyes[0] - 7, ey + 3, eyes[0] - 1, ey + 3), frame)
    return L.a


DIR = {'idle': 'down', 'walk_down': 'down', 'walk_left': 'left', 'walk_right': 'right', 'walk_up': 'up',
       'happy': 'down', 'wave': 'down', 'think': 'down', 'sleep': 'sleep'}


def build(preview=None):
    src = np.asarray(Image.open(SRC).convert('RGBA'))
    cells = {}
    for r, (name, n) in enumerate(SRC_ROWS):
        cells[name] = [src[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL].copy() for c in range(n)]
    cells['turn'] = [cells[k][0] for k in ('walk_down', 'walk_right', 'walk_up', 'walk_left')]
    dirs = dict(DIR, turn=None)
    turn_dirs = ['down', 'right', 'up', 'left']
    nrows = len(ANIMS)
    sheets = {}

    def sheet(key):
        return sheets.setdefault(key, np.zeros((nrows * CELL, COLS * CELL, 4), np.uint8))

    for ri, (name, _, _) in enumerate(ANIMS):
        src_name = 'turn' if name == 'turn' else name
        for fi, cell in enumerate(cells[src_name]):
            R = regions(cell, name)
            d = turn_dirs[fi] if name == 'turn' else dirs[name]
            oy, ox = ri * CELL, fi * CELL
            for hid, _, tint in HAIRS:
                body = cell.copy()
                if tint:
                    hue, sat, val, absolute = tint
                    rc = recolor(cell, R['hair'], R, hue, sat, val, absolute_sat=absolute)
                    body[R['hair']] = rc[R['hair']]
                sheet(f'body_{hid}')[oy:oy + CELL, ox:ox + CELL] = body
            for oid, _, jacket, shorts in OUTFITS:
                layer = np.zeros_like(cell)
                if jacket:
                    rc = recolor(cell, R['jacket'], R, *jacket)
                    layer[R['jacket']] = rc[R['jacket']]
                if shorts:
                    rc = recolor(cell, R['shorts'], R, shorts[0], shorts[1], shorts[2], absolute_sat=True)
                    layer[R['shorts']] = rc[R['shorts']]
                sheet(f'outfit_{oid}')[oy:oy + CELL, ox:ox + CELL] = layer
            for hw, _ in HEADWEAR:
                if hw == 'starclip' or name == 'sleep':
                    a = np.zeros_like(cell)
                else:
                    a = hat(hw, R['head'], d in ('left', 'right'), d == 'left')
                sheet(f'headwear_{hw}')[oy:oy + CELL, ox:ox + CELL] = a
            for ac, _ in ACCESSORIES:
                a = glasses(R['head'], name, d) if ac == 'glasses' else np.zeros_like(cell)
                sheet(f'accessory_{ac}')[oy:oy + CELL, ox:ox + CELL] = a

    manifest = {
        'frameWidth': CELL, 'frameHeight': CELL, 'columns': COLS, 'pivot': [64, FOOT],
        'order': ['body', 'outfit', 'headwear', 'accessory'],
        'animations': [{'name': n, 'frames': len(cells['turn' if n == 'turn' else n]), 'fps': f, 'loop': lp} for n, f, lp in ANIMS],
        'aliases': ALIASES,
        'layers': {
            'body': [{'id': i, 'name': n, 'file': f'body_{i}.webp'} for i, n, _ in HAIRS],
            'outfit': [{'id': i, 'name': n, 'file': f'outfit_{i}.webp'} for i, n, _, _ in OUTFITS],
            'headwear': [{'id': i, 'name': n, 'file': f'headwear_{i}.webp'} for i, n in HEADWEAR],
            'accessory': [{'id': i, 'name': n, 'file': f'accessory_{i}.webp'} for i, n in ACCESSORIES],
        },
        'default': {'body': 'navy', 'outfit': 'adventurer', 'headwear': 'starclip', 'accessory': 'scarf'},
    }
    for d in (ROOT / 'web_dashboard/assets/characters/player', ROOT / 'assets/characters/player'):
        d.mkdir(parents=True, exist_ok=True)
        for old in d.glob('*.webp'):
            old.unlink()
        for k, a in sheets.items():
            lossless = not k.startswith('body_')
            Image.fromarray(a, 'RGBA').save(d / f'{k}.webp', lossless=lossless, quality=100 if lossless else 90,
                                            method=6, exact=lossless, alpha_quality=100)
        (d / 'player.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    # the reference sheet: default look, four views
    ref = np.concatenate([np.asarray(Image.fromarray(sheets['body_navy'][1 * CELL:2 * CELL, f * CELL:(f + 1) * CELL])) for f in range(4)], axis=1)
    Image.fromarray(ref, 'RGBA').save(ROOT / 'tool/character_art/reference/player.png', optimize=True)
    if preview:
        out = Path(preview)
        out.mkdir(parents=True, exist_ok=True)
        looks = [('navy', 'adventurer', 'starclip', 'scarf'), ('chestnut', 'forest', 'strawhat', 'scarf'),
                 ('rose', 'starnight', 'wizard', 'glasses'), ('navy', 'sunset', 'catears', 'glasses'),
                 ('chestnut', 'sunny', 'beanie', 'scarf'), ('rose', 'snow', 'flowers', 'scarf')]
        for i, (b, o, h, a) in enumerate(looks):
            base = np.zeros_like(sheets['body_navy'])
            base[..., :3] = (70, 58, 92)
            base[..., 3] = 255
            for k in (f'body_{b}', f'outfit_{o}', f'headwear_{h}', f'accessory_{a}'):
                m = sheets[k][..., 3] > 0
                base[m] = sheets[k][m]
            Image.fromarray(base).save(out / f'look_{i}.png')
    return manifest


if __name__ == '__main__':
    pv = sys.argv[sys.argv.index('--preview') + 1] if '--preview' in sys.argv else None
    build(pv)
    print('player sheets written from the companion art')
