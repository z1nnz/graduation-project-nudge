"""Draw the pets (work package J3): owl, fox and slime, three growth stages.

  python -I tool/character_art/draw_pets.py [--preview <dir>]

Cells are 32x32 px (feet on row 29, centre column 16), one row per
animation, same outline and shading rules as draw_player.py. Writes
<species>_<stage>.webp and pets.json to web_dashboard/assets/characters/pets/
and assets/characters/pets/. Stand-in prompts: pet_prompts.json.
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import draw_player as dp  # noqa: E402

dp.W, dp.H = 32, 32
W = H = 32
CX, FOOT = 16, 29
COLS = 8
ROOT = dp.ROOT
INK = dp.INK
WHITE = dp.WHITE
BLUSH = dp.BLUSH
rect, pix, empty, shift, dilate, darken, Layer = dp.rect, dp.pix, dp.empty, dp.shift, dp.dilate, dp.darken, dp.Layer
STAGES = ['baby', 'teen', 'adult']
SIZE = [0.62, 0.8, 1.0]


def ellipse(cx, cy, rx, ry):
    m = empty()
    ys, xs = np.mgrid[0:H, 0:W]
    m |= ((xs + 0.5 - cx) / max(0.5, rx)) ** 2 + ((ys + 0.5 - cy) / max(0.5, ry)) ** 2 <= 1.0
    return m


def tri(points):
    from PIL import ImageDraw
    im = Image.new('L', (W, H), 0)
    ImageDraw.Draw(im).polygon(points, fill=255)
    return np.asarray(im) > 0


def eyes_at(L, pts, state, size=2):
    for x, y in pts:
        if state == 'open':
            L.fill(rect(x, y, x + size - 1, y + size), INK)
            L.fill(pix([(x, y)]), WHITE)
        elif state == 'happy':
            L.fill(pix([(x - 1, y + 1), (x, y), (x + size - 1, y), (x + size, y + 1)]), INK)
        else:
            L.fill(pix([(x - 1, y + 1), (x, y + 2), (x + size - 1, y + 2), (x + size, y + 1)]), INK)


# ---------------------------------------------------------------- owl

OWL = {'body': (150, 108, 84), 'shade': (112, 76, 60), 'belly': (240, 224, 190), 'wing': (118, 82, 64),
       'beak': (244, 174, 64), 'ring': (250, 238, 214)}


def owl(p, st):
    k = SIZE[st]
    L = Layer()
    d = p['dir']
    lift = p.get('lift', 0)
    sx, sy = p.get('squash', (1, 1))
    rx, ry = 7.5 * k * sx, 8.5 * k * sy
    cy = FOOT - ry - lift + 0.5 + p.get('bob', 0)
    cx = CX + p.get('tilt', 0)
    if st == 0:
        col = {**OWL, 'body': (190, 160, 140), 'shade': (150, 120, 104)}
    else:
        col = OWL
    # feet
    fl, fr = p.get('feet', (0, 0))
    fy = int(FOOT - lift)
    if d in ('down', 'up'):
        L.part(rect(cx - 3, fy - fl, cx - 2, fy - fl) | rect(cx + 1, fy - fr, cx + 2, fy - fr), col['beak'])
    else:
        L.part(rect(cx - 2, fy - fl, cx - 1, fy - fl) | rect(cx + 1, fy - fr, cx + 2, fy - fr), col['beak'])
    wing = p.get('wing', 0)
    if d in ('down', 'up'):
        for side in (-1, 1):
            wx = cx + side * (rx - 0.5)
            wy = cy + 1 - wing * 3
            L.part(ellipse(wx, wy, 2.2 * k + 0.6, 4.5 * k + 0.5 - wing), col['wing'], shade=darken(col['wing'], 0.8))
    body = ellipse(cx, cy, rx if d in ('down', 'up') else rx * 0.9, ry)
    if st >= 1:
        for side in (-1, 1):
            tx = cx + side * rx * 0.55
            top = cy - ry
            body |= tri([(tx - 2 * k, top + 2), (tx + 2 * k, top + 2), (tx + side * 1.5 * k, top - 2.5 * k)])
    L.part(body, col['body'], shade=col['shade'])
    if d == 'down':
        L.fill(ellipse(cx, cy + ry * 0.35, rx * 0.6, ry * 0.5) & body, col['belly'])
        ey = int(cy - ry * 0.35)
        ex = [int(cx - rx * 0.45 - 1), int(cx + rx * 0.45 - 1)]
        for x in ex:
            L.fill(ellipse(x + 1, ey + 1.5, 2.4 * k + 0.6, 2.4 * k + 0.6) & body, col['ring'])
        eyes_at(L, [(x, ey) for x in ex], p.get('eyes', 'open'))
        L.fill(rect(cx - 1, ey + 3, cx, ey + 4), col['beak'])
        if st == 2:
            L.fill(pix([(cx - 1, int(cy + ry * 0.4)), (cx, int(cy + ry * 0.4)), (cx - 1, int(cy + ry * 0.4) - 1), (cx, int(cy + ry * 0.4) + 1)]), dp.GOLD)
        if p.get('blush'):
            L.fill(pix([(ex[0] - 1, ey + 4), (ex[1] + 2, ey + 4)]), BLUSH)
    elif d == 'up':
        L.fill(ellipse(cx, cy + 1, rx * 0.5, ry * 0.6) & body, col['shade'])
        L.fill(pix([(cx - 2, int(cy)), (cx + 1, int(cy) + 2), (cx - 1, int(cy) + 3)]), col['belly'])
    else:
        L.fill(ellipse(cx - rx * 0.3, cy + ry * 0.35, rx * 0.4, ry * 0.45) & body, col['belly'])
        ey = int(cy - ry * 0.35)
        ex = int(cx - rx * 0.55)
        L.fill(ellipse(ex + 1, ey + 1.5, 2.4 * k + 0.6, 2.4 * k + 0.6) & body, col['ring'])
        eyes_at(L, [(ex, ey)], p.get('eyes', 'open'))
        L.fill(rect(int(cx - rx) - 1, ey + 3, int(cx - rx), ey + 3), col['beak'])
        L.part(ellipse(cx + 1, cy + 1 - wing * 2, 2.8 * k + 0.5, 4.8 * k), col['wing'], shade=darken(col['wing'], 0.8))
        if p.get('blush'):
            L.fill(pix([(ex + 2, ey + 4)]), BLUSH)
    return L


# ---------------------------------------------------------------- fox

FOX = {'fur': (230, 132, 62), 'shade': (186, 92, 40), 'cream': (252, 238, 216), 'leg': (96, 54, 42), 'nose': (60, 36, 34)}


def fox(p, st):
    k = SIZE[st]
    L = Layer()
    d = p['dir']
    lift = p.get('lift', 0)
    sway = p.get('tail', 0)
    col = FOX if st else {**FOX, 'fur': (240, 168, 104), 'shade': (204, 124, 70)}
    base = FOOT - lift + p.get('bob', 0)
    leg = max(2, round(3 * k))
    if d in ('left', 'right'):
        bw, bh = 7 * k, 4 * k
        by = base - leg - bh + 0.5
        bx = CX + 1
        ph = p.get('step', 0)
        for i, lx in enumerate((bx - bw * 0.6, bx + bw * 0.55)):
            for j, off in enumerate((-1, 1)):
                dy = 1 if (ph + i + j) % 2 else 0
                if p.get('sleep'):
                    continue
                L.part(rect(int(lx + off), int(base - leg), int(lx + off), int(base - dy)), col['leg'])
        tail = ellipse(bx + bw + 2.5 * k, by - 1.5 * k - sway, 3.2 * k + 0.4, 2.2 * k + 0.4)
        L.part(tail, col['fur'], shade=col['shade'])
        L.fill(ellipse(bx + bw + 4.6 * k, by - 2 * k - sway, 1.4 * k + 0.3, 1.4 * k + 0.3) & tail, col['cream'])
        L.part(ellipse(bx, by, bw, bh), col['fur'], shade=col['shade'])
        L.fill(ellipse(bx - bw * 0.2, by + bh * 0.5, bw * 0.6, bh * 0.4), col['cream'])
        hx, hy = bx - bw - 0.5 + p.get('tilt', 0), by - bh - 0.5
        head = ellipse(hx, hy, 4.2 * k + 0.5, 3.6 * k + 0.5)
        head |= tri([(hx - 1, hy - 2 * k), (hx + 2, hy - 2 * k), (hx + 0.5, hy - 6 * k)])
        head |= tri([(hx + 1.5, hy - 2 * k), (hx + 4, hy - 1.5 * k), (hx + 3.5, hy - 5.5 * k)])
        head |= rect(int(hx - 4.2 * k - 1), int(hy + 0.5), int(hx - 2 * k), int(hy + 2))
        L.part(head, col['fur'], shade=col['shade'])
        L.fill(rect(int(hx - 4.2 * k - 1), int(hy + 1), int(hx - 1), int(hy + 2)) & head, col['cream'])
        L.fill(pix([(int(hx - 4.2 * k - 1), int(hy + 0.5))]), col['nose'])
        eyes_at(L, [(int(hx - 1.5 * k), int(hy - 1))], p.get('eyes', 'open'), size=1)
        if p.get('blush'):
            L.fill(pix([(int(hx + 0.5), int(hy + 1))]), BLUSH)
        return L
    # down / up: head in front, body and tail behind
    hx, hy = CX + p.get('tilt', 0), base - leg - 4.5 * k
    tail = ellipse(CX + 6 * k + sway, base - 5 * k, 2.4 * k + 0.4, 3.6 * k + 0.4)
    L.part(tail, col['fur'], shade=col['shade'])
    L.fill(ellipse(CX + 6 * k + sway, base - 7.5 * k, 1.4 * k + 0.4, 1.4 * k + 0.4) & tail, col['cream'])
    body = ellipse(CX, base - leg - 2 * k, 4.5 * k + 0.5, 3.6 * k + 0.5)
    L.part(body, col['fur'], shade=col['shade'])
    if not p.get('sleep'):
        fl, fr = p.get('feet', (0, 0))
        L.part(rect(CX - 2, int(base - leg), CX - 2, int(base - fl)) | rect(CX + 1, int(base - leg), CX + 1, int(base - fr)), col['leg'])
    head = ellipse(hx, hy, 5 * k + 0.6, 4 * k + 0.6)
    for side in (-1, 1):
        ex = hx + side * 3 * k
        head |= tri([(ex - 2 * k, hy - 2.5 * k), (ex + 2 * k, hy - 2.5 * k), (ex + side * 1.2 * k, hy - 7 * k)])
    L.part(head, col['fur'], shade=col['shade'])
    if d == 'down':
        L.fill(ellipse(hx, hy + 2 * k, 3.4 * k + 0.4, 2 * k + 0.4) & head, col['cream'])
        e = p.get('eyes', 'open')
        eyes_at(L, [(int(hx - 2.5 * k) - 1, int(hy - 1)), (int(hx + 2.5 * k), int(hy - 1))], e, size=1 if st == 0 else 2)
        L.fill(pix([(int(hx) - 1, int(hy + 1.5 * k)), (int(hx), int(hy + 1.5 * k))]), col['nose'])
        if p.get('blush'):
            L.fill(pix([(int(hx - 4 * k), int(hy + 1.5)), (int(hx + 4 * k), int(hy + 1.5))]), BLUSH)
    else:
        L.fill(ellipse(hx, hy + 1, 3 * k, 2 * k) & head, col['shade'])
    return L


# ---------------------------------------------------------------- slime

SLIME = [((150, 226, 196), (100, 180, 150)), ((116, 214, 180), (72, 164, 132)), ((128, 196, 236), (80, 140, 196))]


def slime(p, st):
    k = SIZE[st]
    L = Layer()
    d = p['dir']
    lift = p.get('lift', 0)
    sx, sy = p.get('squash', (1, 1))
    body_c, shade = SLIME[st]
    rx, ry = 7.5 * k * sx, 6.5 * k * sy
    base = FOOT - lift + p.get('bob', 0)
    cx = CX + p.get('tilt', 0)
    cy = base - ry + 1
    m = ellipse(cx, cy, rx, ry) & rect(0, 0, W - 1, int(base))
    m |= ellipse(cx, base - 1, rx, 1.5) & rect(0, int(base) - 2, W - 1, int(base))
    if st == 1:
        L.part(tri([(cx, cy - ry - 3), (cx + 3, cy - ry - 5), (cx + 1, cy - ry + 1)]), (110, 180, 80))
    L.part(m, body_c, shade=shade, ring_color=darken(shade, 0.45))
    L.fill(pix([(int(cx - rx * 0.55), int(cy - ry * 0.5)), (int(cx - rx * 0.55) + 1, int(cy - ry * 0.6)), (int(cx - rx * 0.55), int(cy - ry * 0.3))]), (250, 255, 250))
    if st == 2:
        top = int(cy - ry) - 1
        crown = rect(int(cx) - 2, top - 2, int(cx) + 2, top) & ~pix([(int(cx) - 1, top - 2), (int(cx) + 1, top - 2)])
        L.part(crown, dp.GOLD, ring_color=darken(dp.GOLD_SH, 0.5))
    ey = int(cy - ry * 0.05)
    e = p.get('eyes', 'open')
    if d == 'down':
        pts = [(int(cx - rx * 0.4) - 1, ey), (int(cx + rx * 0.4), ey)]
    elif d in ('left', 'right'):
        pts = [(int(cx - rx * 0.6), ey), (int(cx - rx * 0.1), ey)]
    else:
        pts = []
    if pts:
        eyes_at(L, pts, e, size=1 if st == 0 else 2)
        mx = (pts[0][0] + pts[-1][0]) // 2 + 1
        if p.get('mouth', 'smile') == 'open':
            L.fill(rect(mx - 1, ey + 3, mx, ey + 4), dp.MOUTH)
        else:
            L.fill(pix([(mx - 1, ey + 3), (mx, ey + 4), (mx + 1, ey + 3)]), dp.MOUTH)
        if p.get('blush'):
            L.fill(pix([(pts[0][0] - 1, ey + 3), (pts[-1][0] + 2, ey + 3)]), BLUSH)
    return L


DRAW = {'owl': owl, 'fox': fox, 'slime': slime}
SPECIES = [
    {'id': 'owl', 'name': '小貓頭鷹', 'stages': ['毛球雛鳥', '見習夜梟', '星夜貓頭鷹']},
    {'id': 'fox', 'name': '小狐狸', 'stages': ['小奶狐', '蓬尾狐', '晚霞狐']},
    {'id': 'slime', 'name': '小史萊姆', 'stages': ['小水滴', '發芽史萊姆', '王冠史萊姆']},
]


def rows(species):
    hop = species in ('owl', 'slime')
    R = []

    def add(name, poses, fps, loop=True):
        R.append({'name': name, 'fps': fps, 'loop': loop, 'poses': poses})

    breath = [0, 0, 0, 1, 1, 1, 0, 0]
    add('idle', [{'dir': 'down', 'squash': (1 + 0.04 * b, 1 - 0.05 * b) if hop else (1, 1), 'bob': 0,
                  'tail': [0, 1, 2, 1, 0, -1, -2, -1][i], 'eyes': 'closed' if i == 5 else 'open',
                  'wing': 0} for i, b in enumerate(breath)], 8)
    for d in ('down', 'left', 'right', 'up'):
        poses = []
        for i in range(6):
            t = 2 * math.pi * i / 6
            if species == 'slime':
                lift = [0, 1, 3, 4, 2, 0][i]
                sq = [(1.15, 0.82), (0.92, 1.1), (0.95, 1.05), (1, 1), (1, 1), (1.12, 0.86)][i]
                poses.append({'dir': d, 'lift': lift, 'squash': sq})
            elif species == 'owl':
                poses.append({'dir': d, 'lift': [0, 1, 2, 0, 1, 2][i], 'feet': ([1, 0][i % 2], [0, 1][i % 2]),
                              'wing': 1 if i in (2, 5) else 0})
            else:
                poses.append({'dir': d, 'step': i, 'bob': -1 if i % 3 == 1 else 0, 'tail': round(2 * math.sin(t)),
                              'feet': (1 if i % 2 else 0, 0 if i % 2 else 1)})
        add(f'walk_{d}', poses, 10)
    happy = [{'dir': 'down', 'lift': l, 'eyes': 'happy', 'blush': True, 'wing': w, 'tail': tl, 'mouth': 'open',
              'squash': sq} for l, w, tl, sq in
             [(0, 0, 0, (1.15, 0.85)), (3, 1, 2, (0.9, 1.12)), (6, 1, -2, (0.95, 1.05)), (5, 1, 2, (1, 1)),
              (2, 0, -2, (1, 1)), (0, 0, 0, (1.12, 0.88))]]
    add('happy', happy, 10, loop=False)
    sleep = []
    for i in range(8):
        b = [0, 0, 1, 1, 1, 1, 0, 0][i]
        if species == 'fox':
            sleep.append({'dir': 'left', 'sleep': True, 'lift': -2, 'eyes': 'closed', 'tail': -3 - b, 'bob': 0})
        else:
            sleep.append({'dir': 'down', 'eyes': 'closed', 'squash': (1.08 + 0.03 * b, 0.86 - 0.03 * b), 'wing': 0})
    add('sleep', sleep, 8)
    cuddle = []
    for i in range(8):
        tilt = [0, -1, -2, -1, 0, 1, 2, 1][i]
        cuddle.append({'dir': 'down', 'tilt': tilt, 'eyes': 'happy', 'blush': True, 'tail': tilt * 2,
                       'squash': (1.06, 0.94) if i % 4 == 2 else (1, 1), 'wing': 1 if i in (2, 6) else 0})
    add('cuddle', cuddle, 8)
    return R


def render(species, st, pose):
    p = dict(pose)
    flip = p.get('dir') == 'right'
    if flip:
        p['dir'] = 'left'
    a = DRAW[species](p, st).a
    return a[:, ::-1] if flip else a


def build(preview=None):
    outs = [ROOT / 'web_dashboard/assets/characters/pets', ROOT / 'assets/characters/pets']
    manifest = {'frameWidth': W, 'frameHeight': H, 'columns': COLS, 'pivot': [CX, FOOT], 'animations': None,
                'species': [], 'stageNames': STAGES}
    sheets = {}
    for sp in SPECIES:
        R = rows(sp['id'])
        anims = [{'name': r['name'], 'frames': len(r['poses']), 'fps': r['fps'], 'loop': r['loop']} for r in R]
        assert manifest['animations'] in (None, anims)
        manifest['animations'] = anims
        for st in range(3):
            sheet = np.zeros((len(R) * H, COLS * W, 4), np.uint8)
            for ri, r in enumerate(R):
                assert 4 <= len(r['poses']) <= COLS
                for fi, pose in enumerate(r['poses']):
                    a = render(sp['id'], st, pose)
                    assert (a[..., 3] > 0).sum() > 30, (sp['id'], st, r['name'], fi)
                    sheet[ri * H:(ri + 1) * H, fi * W:(fi + 1) * W] = a
            sheets[f'{sp["id"]}_{STAGES[st]}'] = sheet
        manifest['species'].append({'id': sp['id'], 'name': sp['name'], 'stages': [
            {'id': STAGES[i], 'name': sp['stages'][i], 'file': f'{sp["id"]}_{STAGES[i]}.webp'} for i in range(3)]})
    manifest['growth'] = {'unit': 'focusMinutes', 'teen': 300, 'adult': 1500}
    for d in outs:
        d.mkdir(parents=True, exist_ok=True)
        for k, a in sheets.items():
            Image.fromarray(a, 'RGBA').save(d / f'{k}.webp', lossless=True, quality=100, method=6, exact=True)
        (d / 'pets.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    if preview:
        out = Path(preview)
        out.mkdir(parents=True, exist_ok=True)
        keys = list(sheets)
        big = np.concatenate([sheets[k] for k in keys], axis=1)
        bg = np.zeros_like(big)
        bg[..., :3] = (70, 58, 92)
        bg[..., 3] = 255
        m = big[..., 3] > 0
        bg[m] = big[m]
        Image.fromarray(bg).resize((bg.shape[1] * 2, bg.shape[0] * 2), Image.NEAREST).save(out / 'pets.png')
    return manifest


def props():
    """Pet house props, native size, keyed PNG: house, bowl (empty/full), cushion, treat."""
    out = {}
    wood, wood_sh, roof, roof_sh = (176, 112, 64), (130, 78, 44), (124, 76, 160), (88, 52, 120)
    dp.W, dp.H = 48, 44
    L = Layer()
    body = rect(6, 18, 41, 41)
    L.part(body, wood, shade=wood_sh)
    for y in range(20, 41, 4):
        L.fill(rect(7, y, 40, y), wood_sh)
    door = rect(17, 26, 30, 41) & ~pix([(17, 26), (30, 26), (17, 27), (30, 27), (18, 26), (29, 26)])
    L.part(door, (52, 30, 40), ring_color=(40, 22, 30))
    r = empty()
    for k in range(15):  # gable roof, eaves past the walls
        inset = round(k * 1.45)
        r |= rect(2 + inset, 20 - k, 45 - inset, 20 - k)
    L.part(r, roof, shade=roof_sh)
    L.fill(rect(19, 21, 28, 23), (246, 231, 200))
    L.fill(pix([(21, 22), (23, 22), (25, 22), (27, 22)]), (138, 90, 52))
    L.part(rect(22, 6, 25, 9), dp.GOLD, ring_color=dp.GOLD_SH)
    out['house'] = L.a.copy()
    dp.W, dp.H = 18, 10
    for full in (False, True):
        L = Layer()
        bowl = rect(1, 4, 16, 8) & ~pix([(1, 8), (16, 8)])
        L.part(bowl, (216, 69, 46), shade=(160, 44, 30))
        L.fill(rect(2, 4, 15, 4), (110, 40, 30))
        if full:
            L.part(rect(4, 2, 13, 4) & ~pix([(4, 2), (13, 2)]), (200, 140, 76), shade=(150, 96, 50))
            L.fill(pix([(6, 3), (9, 2), (11, 3)]), (90, 52, 34))
        out['bowl_full' if full else 'bowl'] = L.a.copy()
    dp.W, dp.H = 28, 12
    L = Layer()
    L.part(rect(1, 3, 26, 10) & ~pix([(1, 3), (26, 3), (1, 10), (26, 10)]), (139, 108, 240), shade=(75, 47, 168))
    L.fill(rect(3, 4, 24, 4), (180, 160, 250))
    L.fill(pix([(7, 7), (13, 6), (20, 7)]), dp.GOLD)
    out['cushion'] = L.a.copy()
    dp.W, dp.H = 8, 8
    L = Layer()
    L.part(rect(1, 1, 6, 6) & ~pix([(1, 1), (6, 1), (1, 6), (6, 6)]), (200, 140, 76), shade=(150, 96, 50))
    L.fill(pix([(3, 3), (4, 4)]), (90, 52, 34))
    out['treat'] = L.a.copy()
    dp.W, dp.H = 32, 32
    for d in (ROOT / 'web_dashboard/assets/scenes/pet_house', ROOT / 'assets/scenes/pet_house'):
        d.mkdir(parents=True, exist_ok=True)
        for k, a in out.items():
            Image.fromarray(a, 'RGBA').save(d / f'{k}.png', optimize=True)
    return out


if __name__ == '__main__':
    pv = sys.argv[sys.argv.index('--preview') + 1] if '--preview' in sys.argv else None
    build(pv)
    props()
    print('pet sheets and pet house props written')
