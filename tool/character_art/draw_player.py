"""Draw the layered player character (work package J1) at native pixel size.

  python -I tool/character_art/draw_player.py [--preview <dir>]

Every frame is built from one pose rig (head, torso, arms, legs, props), and
each wardrobe layer is drawn from that same rig, so a body, an outfit, a
headwear and an accessory sheet always line up when stacked in this order:

  body -> outfit -> headwear -> accessory

Cells are 48x56 px (feet stand on row 53, centre column 24), one row per
animation. Sheets go to web_dashboard/assets/characters/player/ and
assets/characters/player/ together with player.json. Shown at whole-number
scale with nearest-neighbour (2x = 96x112, 3x = 144x168).

The prompts these sprites stand in for (shared prefix as in the work
package, reference sheet attached on every call) are in player_prompts.json.
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
W, H = 48, 56
CX = 24
FOOT = 53
COLS = 12

# ---------------------------------------------------------------- palette

INK = (40, 26, 36)
SKIN = (250, 214, 178)
SKIN_SH = (226, 170, 132)
UNDER = (236, 228, 214)
UNDER_SH = (196, 182, 170)
BLUSH = (240, 140, 150)
MOUTH = (128, 48, 58)
TONGUE = (226, 110, 120)
WHITE = (255, 250, 240)
GOLD = (255, 197, 77)
GOLD_SH = (196, 130, 30)
PARCH = (246, 231, 200)
PARCH_SH = (214, 188, 146)
COOKIE = (196, 132, 70)
COOKIE_SH = (140, 86, 44)
CHOC = (82, 48, 34)

HAIR = {
    'navy': ((54, 64, 140), (34, 38, 96), (96, 112, 196)),
    'chestnut': ((132, 78, 44), (90, 50, 30), (180, 118, 70)),
    'rose': ((214, 118, 150), (160, 74, 112), (244, 170, 192)),
}


def darken(c, k=0.5):
    return tuple(int(v * k) for v in c[:3])


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


# ---------------------------------------------------------------- masks

def empty():
    return np.zeros((H, W), bool)


def shift(m, dx, dy):
    """s[y, x] = m[y + dy, x + dx], False outside."""
    s = np.zeros_like(m)
    ys, ye = max(0, -dy), H - max(0, dy)
    xs, xe = max(0, -dx), W - max(0, dx)
    s[ys:ye, xs:xe] = m[ys + dy:ye + dy, xs + dx:xe + dx]
    return s


def dilate(m):
    return m | shift(m, 1, 0) | shift(m, -1, 0) | shift(m, 0, 1) | shift(m, 0, -1)


def rect(x0, y0, x1, y1):
    m = empty()
    x0, x1 = sorted((int(x0), int(x1)))
    y0, y1 = sorted((int(y0), int(y1)))
    m[max(0, y0):max(0, y1 + 1), max(0, x0):max(0, x1 + 1)] = True
    return m


def pix(points):
    m = empty()
    for x, y in points:
        if 0 <= x < W and 0 <= y < H:
            m[int(y), int(x)] = True
    return m


def line_pts(p0, p1):
    x0, y0 = map(int, p0)
    x1, y1 = map(int, p1)
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    out = []
    while True:
        out.append((x0, y0))
        if x0 == x1 and y0 == y1:
            return out
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def poly_pts(pts):
    out = [tuple(map(int, pts[0]))]
    for a, b in zip(pts, pts[1:]):
        out += line_pts(a, b)[1:]
    return out


def stamp(points, w, h, ax=0, ay=0):
    """w x h block at every point; (ax, ay) is the block cell on the point."""
    m = empty()
    for x, y in points:
        m |= rect(x - ax, y - ay, x - ax + w - 1, y - ay + h - 1)
    return m


def template(rows, ox, oy, colors):
    """ASCII art at (ox, oy): {char: color}; '.' is empty."""
    out = {}
    for r, line in enumerate(rows):
        for c, ch in enumerate(line):
            if ch == '.':
                continue
            x, y = ox + c, oy + r
            if 0 <= x < W and 0 <= y < H:
                out.setdefault(ch, []).append((x, y))
    return {ch: (pix(p), colors[ch]) for ch, p in out.items()}


class Layer:
    def __init__(self):
        self.a = np.zeros((H, W, 4), np.uint8)

    def fill(self, m, c):
        self.a[m] = (*c[:3], 255)

    def part(self, m, c, shade=None, ring=True, ring_color=None, light=None):
        """Fill m with c, shade its right/bottom edge, outline it; returns painted mask."""
        if not m.any():
            return m
        r = dilate(m) & ~m if ring else empty()
        self.fill(m, c)
        if shade is not None:
            self.fill(m & (~shift(m, 1, 0) | ~shift(m, 0, 1)), shade)
        if light is not None:
            self.fill(m & ~shift(m, -1, 0) & ~shift(m, 0, -1) & shift(m, 1, 1), light)
        if ring:
            self.fill(r, ring_color or darken(c, 0.42))
        return m | r

    def art(self, parts, ring_color, ring=True):
        """Paint template parts; one outline around all of them."""
        union = empty()
        for m, c in parts.values():
            self.fill(m, c)
            union |= m
        if ring:
            r = dilate(union) & ~union
            self.fill(r, ring_color)
            return union | r
        return union

    def erase(self, m):
        self.a[m] = 0


# ---------------------------------------------------------------- the rig

def rig(p):
    d = p.get('dir', 'down')
    side = d in ('left', 'right')
    jy = p.get('y', 0)
    drop = p.get('sit', 0)
    bob = p.get('bob', 0)
    lean = p.get('lean', 0)
    hip = 45 + jy + drop
    tt = 36 + jy + drop + bob
    hdx, hdy = p.get('head', (0, 0))
    g = {'dir': d, 'side': side, 'hip': hip, 'tt': tt, 'pose': p}
    g['head'] = (16 + hdx + lean, 21 + jy + drop + bob + hdy)
    g['torso'] = (20 + lean, tt, 27, hip) if side else (19, tt, 28, hip)
    foot = FOOT + jy
    legs = []
    if side:
        feet = p.get('feet', {})
        for k in ('far', 'near'):
            fdx, lift = feet.get(k, (0, 0))
            knee = p.get('knees', {}).get(k)
            pts = [(23, hip + 1)] + ([knee] if knee else []) + [(23 + fdx, foot - lift)]
            legs.append({'pts': pts, 'near': k == 'near', 'key': k})
    else:
        lL, lR = p.get('lift', (0, 0))
        sp = p.get('spread', 0)
        legs.append({'pts': [(21 - sp, hip + 1), (21 - sp, foot - lL)], 'near': True, 'key': 'L'})
        legs.append({'pts': [(26 + sp, hip + 1), (26 + sp, foot - lR)], 'near': True, 'key': 'R'})
    g['legs'] = legs
    arms = []
    spec = p.get('arms', {})
    if side:
        sh = (23 + lean, tt + 1)
        for k, z in (('far', 'back'), ('near', 'front')):
            a = spec.get(k, {})
            pts = a.get('pts', [(0, 6)])
            arms.append({'key': k, 'z': a.get('z', z), 'pts': [sh] + [(sh[0] + x, sh[1] + y) for x, y in pts], 'ax': 0})
    else:
        for k, sx, ax in (('L', 17, 0), ('R', 30, 1)):
            a = spec.get(k, {})
            pts = a.get('pts', [(-1 if k == 'L' else 1, 6)])
            sh = (sx, tt + 1)
            arms.append({'key': k, 'z': a.get('z', 'side'), 'pts': [sh] + [(sh[0] + x, sh[1] + y) for x, y in pts], 'ax': ax})
    g['arms'] = arms
    return g


def arm_mask(a, upto=1.0, w=2):
    pts = poly_pts(a['pts'])
    n = max(1, math.ceil(len(pts) * upto))
    return stamp(pts[:n], w, 2 if w == 2 else w, ax=a['ax'] if w == 2 else 1, ay=0)


def hand_mask(a):
    x, y = a['pts'][-1]
    return stamp([(x, y)], 2, 2, ax=a['ax'])


def leg_mask(leg, upto=1.0, w=3):
    pts = poly_pts(leg['pts'])
    n = max(1, math.ceil(len(pts) * upto))
    return stamp(pts[:n], w, 1, ax=w // 2)


# ---------------------------------------------------------------- head art

HEAD_DOWN = [
    "......h..h.h......",
    ".....hHl.hlH......",
    "...hHHlHHHHHHh....",
    "..HHlHHHHHHHHHh...",
    ".HHlHHHHHHHHHHHh..",
    ".HlHHHHHHHHHHHHhh.",
    "HHHHHHHHHHHHHHHHh.",
    "HHHHHHHHHHHHHHHHhh",
    "HHHHHHHHHHHHHHHHhh",
    "HHHhHHHHHhHHHHHHhh",
    "HHhSShHHhSSHhSSHhh",
    "HhSSSSHhSSSSSSSShh",
    "HhSSSSSSSSSSSSSShh",
    "HSSSSSSSSSSSSSSSSh",
    "HSSSSSSSSSSSSSSSSh",
    ".SSSSSSSSSSSSSSSs.",
    ".SSSSSSSSSSSSSSSs.",
    "..SSSSSSSSSSSSSss.",
    "..sSSSSSSSSSSSss..",
    "...sSSSSSSSSSss...",
]
HEAD_UP = [
    "......h..h.h......",
    ".....hHl.hlH......",
    "...hHHlHHHHHHh....",
    "..HHlHHHHHHHHHh...",
    ".HHlHHHHHHHHHHHh..",
    ".HlHHHHHHHHHHHHhh.",
    "HHHHHHHHHHHHHHHHh.",
    "HHHHHHHHHHHHHHHHhh",
    "HHHHHHHHHHHHHHHHhh",
    "HHHHHHHHHHHHHHHHhh",
    "HHHHHHHHHHHHHHHhhh",
    "HHHHHHHHHHHHHHHhhh",
    "hHHHHHHHHHHHHHHhhh",
    "hHHHHHHHHHHHHHhhhh",
    "hhHHHHHHHHHHHHhhhh",
    ".hhHHHHHHHHHHhhhh.",
    ".hhhHHHHHHHHhhhhh.",
    "..hhhhHHHHhhhhhh..",
    "...hhhhhhhhhhhh...",
    ".....sSSSSSSs.....",
]
HEAD_SIDE = [
    ".......h..h.h.....",
    "......hHl.hlH.....",
    "....hHHlHHHHHHh...",
    "...HHlHHHHHHHHHh..",
    "..HHlHHHHHHHHHHHh.",
    "..HlHHHHHHHHHHHHhh",
    ".HHHHHHHHHHHHHHHhh",
    ".HHHHHHHHHHHHHHHhh",
    "HHHHHHHHHHHHHHHHhh",
    "HHHhHHHHHHHHHHHHhh",
    "HhSShHHHHHHHHHHHhh",
    "SSSSSShHHHHHHHHhhh",
    "SSSSSSSShHHHHHHhhh",
    "SSSSSSSSShHHHHHhh.",
    "SSSSSSSSSShHHHhhh.",
    "SSSSSSSSSSsHHhhh..",
    ".SSSSSSSSSSshhh...",
    ".SSSSSSSSSSsh.....",
    "..sSSSSSSSss......",
    "...sSSSSSss.......",
]


def head_origin(g):
    hx, hy = g['head']
    return hx - 1, hy - 4


def draw_head(L, g, hair):
    base, shade, light = HAIR[hair]
    ox, oy = head_origin(g)
    rows = {'down': HEAD_DOWN, 'up': HEAD_UP}.get(g['dir'], HEAD_SIDE)
    parts = template(rows, ox, oy, {'H': base, 'h': shade, 'l': light, 'S': SKIN, 's': SKIN_SH})
    painted = L.art(parts, darken(shade, 0.55))
    if g['dir'] != 'up':
        draw_face(L, g, ox, oy)
    return painted


def draw_face(L, g, ox, oy):
    p = g['pose']
    side = g['side']
    lx, ly = p.get('look', (0, 0))
    eyes = p.get('eyes', 'open')
    cols = [3] if side else [4, 12]
    er = 12 + ly
    pts_dark, pts_white = [], []
    for c in cols:
        x = ox + c + lx
        y = oy + er
        if eyes == 'open':
            pts_dark += [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1), (x, y + 2), (x + 1, y + 2)]
            pts_white.append((x + 1 if side else x, y))
        elif eyes == 'wide':
            pts_dark += [(x, y - 1), (x + 1, y - 1), (x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1), (x, y + 2), (x + 1, y + 2)]
            pts_white += [(x, y - 1), (x + 1, y)]
        elif eyes == 'half':
            pts_dark += [(x - 1, y + 1), (x, y + 1), (x + 1, y + 1), (x, y + 2), (x + 1, y + 2)]
        elif eyes == 'happy':
            pts_dark += [(x - 1, y + 2), (x, y + 1), (x + 1, y + 1), (x + 2, y + 2)]
        else:  # closed
            pts_dark += [(x - 1, y + 1), (x, y + 2), (x + 1, y + 2), (x + 2, y + 1)]
    L.fill(pix(pts_dark), INK)
    L.fill(pix(pts_white), WHITE)
    if p.get('blush', False) or eyes == 'happy':
        bc = [5] if side else [3, 13]
        L.fill(pix([(ox + c + k, oy + 16) for c in bc for k in (0, 1)]), BLUSH)
    mx = ox + (1 if side else 8)
    my = oy + 17
    m = p.get('mouth', 'smile')
    if m == 'smile':
        L.fill(pix([(mx, my), (mx + 1, my)] + ([] if side else [(mx - 1, my - 1), (mx + 2, my - 1)])), MOUTH)
    elif m == 'flat':
        L.fill(pix([(mx, my), (mx + 1, my)]), MOUTH)
    elif m in ('open', 'o'):
        L.fill(pix([(mx, my), (mx + 1, my)]), MOUTH)
        L.fill(pix([(mx, my + 1), (mx + 1, my + 1)]), MOUTH if m == 'o' else TONGUE)
    elif m == 'grin':
        L.fill(pix([(mx - 1, my), (mx, my), (mx + 1, my), (mx + 2, my)] if not side else [(mx, my), (mx + 1, my), (mx + 2, my)]), MOUTH)
        L.fill(pix([(mx, my + 1), (mx + 1, my + 1)]), TONGUE)
    elif m == 'yawn':
        L.fill(pix([(mx, my - 1), (mx + 1, my - 1), (mx, my), (mx + 1, my)]), MOUTH)
        L.fill(pix([(mx, my + 1), (mx + 1, my + 1)]), TONGUE)
    elif m == 'munch':
        L.fill(pix([(mx - 1, my), (mx, my + 1), (mx + 1, my + 1), (mx + 2, my)]), MOUTH)


# ---------------------------------------------------------------- props

def draw_prop(L, g):
    prop = g['pose'].get('prop')
    if not prop:
        return empty()
    kind, k = prop
    tt = g['tt']
    if kind == 'book':
        x0, y0 = 17, tt + 3
        painted = L.part(rect(x0, y0 + 1, x0 + 13, y0 + 6), (150, 70, 60), ring_color=darken((150, 70, 60), 0.45))
        L.fill(rect(x0 + 1, y0, x0 + 6, y0 + 5), PARCH)
        L.fill(rect(x0 + 7, y0, x0 + 12, y0 + 5), PARCH)
        L.fill(rect(x0 + 6, y0, x0 + 7, y0 + 5), PARCH_SH)
        for r in (1, 3):
            L.fill(rect(x0 + 2, y0 + r, x0 + 4, y0 + r), PARCH_SH)
            L.fill(rect(x0 + 9, y0 + r, x0 + 11, y0 + r), PARCH_SH)
        if k:  # a page rises from the right, stands up, falls left
            shapes = {
                1: [(x0 + 7, y0 - 1, x0 + 11, y0 + 4)],
                2: [(x0 + 6, y0 - 3, x0 + 8, y0 + 4)],
                3: [(x0 + 2, y0 - 1, x0 + 6, y0 + 4)],
            }[k]
            for s in shapes:
                m = rect(*s)
                L.part(m, WHITE, shade=PARCH, ring_color=PARCH_SH)
                painted |= dilate(m)
        return painted
    if kind == 'cookie':
        a = next(a for a in g['arms'] if a['key'] in ('L', 'near'))
        x, y = a['pts'][-1]
        size = {3: 4, 2: 3, 1: 2}[k]
        m = rect(x - 1, y - size + 1, x - 2 + size, y)
        painted = L.part(m, COOKIE, shade=COOKIE_SH, ring_color=darken(COOKIE_SH, 0.6))
        if size >= 3:
            L.fill(pix([(x, y - 1)]), CHOC)
        if size == 4:
            L.fill(pix([(x + 1, y - 2), (x - 1, y)]), CHOC)
        return painted
    return empty()


# ---------------------------------------------------------------- body

def draw_body(g, hair):
    L = Layer()
    masks = {'head': empty(), 'front_arms': empty(), 'hands': empty(), 'prop': empty()}

    def arm(a):
        m = arm_mask(a)
        painted = L.part(m, SKIN, ring_color=darken(SKIN_SH, 0.55))
        hp = L.part(hand_mask(a), SKIN, ring_color=darken(SKIN_SH, 0.55))
        masks['hands'] |= hp
        if a['z'] == 'front':
            masks['front_arms'] |= painted | hp

    for a in g['arms']:
        if a['z'] == 'back':
            arm(a)
    for leg in sorted(g['legs'], key=lambda l: l['near']):
        L.part(leg_mask(leg), SKIN, shade=SKIN_SH, ring_color=darken(SKIN_SH, 0.55))
    x0, y0, x1, y1 = g['torso']
    L.part(rect(x0, y0, x1, y1), UNDER, shade=UNDER_SH, ring_color=darken(UNDER_SH, 0.5))
    for a in g['arms']:
        if a['z'] == 'side':
            arm(a)
    masks['head'] = draw_head(L, g, hair)
    fronts = [a for a in g['arms'] if a['z'] == 'front']
    for a in fronts:
        m = arm_mask(a)
        masks['front_arms'] |= L.part(m, SKIN, ring_color=darken(SKIN_SH, 0.55))
    masks['prop'] = draw_prop(L, g)
    for a in fronts:
        hp = L.part(hand_mask(a), SKIN, ring_color=darken(SKIN_SH, 0.55))
        masks['hands'] |= hp
        masks['front_arms'] |= hp
    return L, masks


# ---------------------------------------------------------------- outfits

OUTFITS = [
    {'id': 'adventurer', 'name': '冒險外套', 'top': (52, 66, 140), 'top_sh': (32, 40, 96), 'trim': GOLD,
     'sleeve': 1.0, 'sleeve_c': (52, 66, 140), 'inner': WHITE, 'bottom': 'shorts', 'bot': (226, 208, 166),
     'bot_sh': (184, 160, 116), 'shoe': (124, 76, 44), 'shoe_top': (240, 226, 196), 'boot': 3, 'belt': (110, 70, 40)},
    {'id': 'gardener', 'name': '園丁吊帶褲', 'top': (244, 204, 92), 'top_sh': (200, 156, 52), 'sleeve': 0.45,
     'sleeve_c': (244, 204, 92), 'bottom': 'pants', 'bot': (88, 144, 74), 'bot_sh': (58, 100, 50),
     'over': (88, 144, 74), 'shoe': (100, 64, 40), 'boot': 2},
    {'id': 'stargown', 'name': '星夜法袍', 'top': (104, 76, 180), 'top_sh': (70, 50, 134), 'sleeve': 1.0,
     'sleeve_c': (104, 76, 180), 'wide': True, 'bottom': 'robe', 'bot': (104, 76, 180), 'bot_sh': (70, 50, 134),
     'stars': GOLD, 'shoe': (60, 40, 90), 'boot': 1, 'belt': GOLD},
    {'id': 'scholar', 'name': '書院學者', 'top': (138, 92, 56), 'top_sh': (98, 62, 38), 'sleeve': 1.0,
     'sleeve_c': (236, 230, 218), 'inner': (236, 230, 218), 'tie': (204, 64, 64), 'bottom': 'pants',
     'bot': (70, 58, 86), 'bot_sh': (48, 38, 62), 'shoe': (86, 52, 34), 'boot': 1, 'buttons': GOLD},
    {'id': 'sporty', 'name': '晨跑運動服', 'top': (214, 72, 62), 'top_sh': (160, 46, 40), 'sleeve': 1.0,
     'sleeve_c': (214, 72, 62), 'stripe': WHITE, 'bottom': 'pants', 'bot': (214, 72, 62), 'bot_sh': (160, 46, 40),
     'shoe': (246, 242, 232), 'shoe_trim': (214, 72, 62), 'boot': 1},
    {'id': 'raincoat', 'name': '雨天黃雨衣', 'top': (246, 196, 58), 'top_sh': (204, 150, 30), 'sleeve': 1.0,
     'sleeve_c': (246, 196, 58), 'bottom': 'coat', 'bot': (246, 196, 58), 'bot_sh': (204, 150, 30),
     'shoe': (74, 124, 204), 'boot': 4, 'buttons': (120, 80, 30)},
]


def sleeve(L, a, o):
    if o['sleeve'] <= 0:
        return empty()
    w = 3 if o.get('wide') else 2
    if w == 3:
        pts = poly_pts(a['pts'])
        n = max(1, math.ceil(len(pts) * o['sleeve']))
        m = stamp(pts[:n], 3, 2, ax=1 if a['ax'] == 0 else 1)
    else:
        m = arm_mask(a, o['sleeve'])
    painted = L.part(m, o['sleeve_c'], shade=o.get('top_sh') if o['sleeve_c'] == o['top'] else None)
    end = poly_pts(a['pts'])[max(0, math.ceil(len(poly_pts(a['pts'])) * o['sleeve']) - 1)]
    if o.get('stripe'):
        L.fill(arm_mask(a, o['sleeve'], 2) & stamp(poly_pts(a['pts']), 1, 1), o['stripe'])
    if o.get('trim') and o['sleeve'] >= 1:
        L.fill(stamp([end], 2, 1, ax=a['ax']) & m, o['trim'])
    return painted


def draw_outfit(g, o, masks):
    L = Layer()
    side = g['side']
    d = g['dir']
    x0, tt, x1, hip = g['torso']
    for a in g['arms']:
        if a['z'] == 'back':
            sleeve(L, a, o)
    # legs: pants / shorts and shoes
    for leg in sorted(g['legs'], key=lambda l: l['near']):
        if o['bottom'] in ('pants', 'shorts', 'coat'):
            frac = {'pants': 0.8, 'shorts': 0.4, 'coat': 0.35}[o['bottom']]
            L.part(leg_mask(leg, frac, 4 if o['bottom'] == 'shorts' else 3), o['bot'], shade=o['bot_sh'])
            if o.get('stripe') and side:
                L.fill(leg_mask(leg, frac, 1), o['stripe'])
        fx, fy = leg['pts'][-1]
        boot = o.get('boot', 1)
        if side:
            sm = rect(fx - 2, fy - boot, fx + 1, fy)
        else:
            sm = rect(fx - 2 if leg['key'] == 'L' else fx - 1, fy - boot, fx + 1 if leg['key'] == 'L' else fx + 2, fy)
        L.part(sm, o['shoe'], shade=darken(o['shoe'], 0.75))
        if o.get('shoe_top') and boot >= 3:
            L.fill(sm & ~shift(sm, 0, -1), o['shoe_top'])
        if o.get('shoe_trim'):
            L.fill(sm & ~shift(sm, 0, 1), o['shoe_trim'])
    # robe / coat skirt
    if o['bottom'] in ('robe', 'coat'):
        feet_y = max(l['pts'][-1][1] for l in g['legs'])
        hem = feet_y - (1 if o['bottom'] == 'robe' else 4)
        hem = max(hem, hip + 3)
        pts = []
        for y in range(hip - 1, hem + 1):
            t = (y - hip + 1) / max(1, hem - hip + 1)
            grow = int(round(t * (2 if o['bottom'] == 'robe' else 1)))
            if side:
                walk = g['pose'].get('feet', {}).get('near', (0, 0))[0]
                sx = int(round(t * min(2, abs(walk) / 2))) * (-1 if walk < 0 else 1)
                pts.append((x0 - grow + min(0, sx), y, x1 + grow + max(0, sx)))
            else:
                pts.append((x0 - grow, y, x1 + grow))
        m = empty()
        for xa, y, xb in pts:
            m |= rect(xa, y, xb, y)
        L.part(m, o['bot'], shade=o['bot_sh'])
        if o.get('stars'):
            for sx, sy in ((x0 + 2, hip + 3), (x1 - 2, hip + 6), (x0 + 5, hem - 1)):
                if m[min(H - 1, sy), min(W - 1, sx)]:
                    L.fill(pix([(sx, sy)]), o['stars'])
    # torso
    tm = rect(x0, tt, x1, hip - (0 if o['bottom'] in ('robe', 'coat') else 1))
    L.part(tm, o['top'], shade=o['top_sh'])
    cx = (x0 + x1) // 2
    if d == 'down':
        if o.get('inner'):
            L.fill(rect(cx, tt + 1, cx + 1, hip - 2), o['inner'])
        if o.get('trim'):
            L.fill(rect(cx - 1, tt + 1, cx - 1, hip - 2) | rect(cx + 2, tt + 1, cx + 2, hip - 2), o['trim'])
        if o.get('tie'):
            L.fill(pix([(cx, tt + 1), (cx + 1, tt + 1), (cx, tt + 2), (cx + 1, tt + 3)]), o['tie'])
        if o.get('buttons'):
            L.fill(pix([(cx - 1 if o['id'] == 'scholar' else cx, tt + 4), (cx - 1 if o['id'] == 'scholar' else cx, tt + 7)]), o['buttons'])
        if o.get('stars'):
            L.fill(pix([(x0 + 2, tt + 3), (x1 - 2, tt + 5)]), o['stars'])
        if o.get('stripe'):
            L.fill(rect(cx, tt + 1, cx + 1, tt + 1), o['stripe'])
            L.fill(rect(cx, tt + 2, cx, hip - 2), o['stripe'])
    elif side:
        if o.get('trim'):
            L.fill(rect(x0 + 1, tt + 1, x0 + 1, hip - 2), o['trim'])
        if o.get('inner'):
            L.fill(rect(x0, tt + 1, x0, tt + 3), o['inner'])
        if o.get('stars'):
            L.fill(pix([(x0 + 3, tt + 4)]), o['stars'])
    else:  # up
        if o.get('stars'):
            L.fill(pix([(cx, tt + 4), (x0 + 2, tt + 7)]), o['stars'])
        if o['id'] == 'adventurer':
            L.fill(pix([(cx, tt + 4), (cx + 1, tt + 4), (cx, tt + 5), (cx + 1, tt + 5)]), GOLD)
    if o['bottom'] == 'pants' and o.get('over'):
        ov = rect(x0 + 1, tt + 4, x1 - 1, hip)
        L.part(ov, o['over'], shade=darken(o['over'], 0.75))
        if d != 'up':
            L.fill(rect(x0 + 3, tt + 6, x1 - 3, tt + 7), darken(o['over'], 0.8))
        if not side:
            L.fill(rect(x0 + 1, tt, x0 + 2, tt + 3) | rect(x1 - 2, tt, x1 - 1, tt + 3), o['over'])
    if o.get('belt') and o['bottom'] != 'pants':
        by = hip - 1 if o['bottom'] == 'shorts' else hip - 2
        L.fill(rect(x0, by, x1, by), o['belt'])
        if d == 'down':
            L.fill(pix([(cx, by), (cx + 1, by)]), GOLD if o['belt'] != GOLD else WHITE)
    L.erase(masks['head'] | masks['front_arms'])
    for a in g['arms']:
        if a['z'] in ('side', 'front'):
            sleeve(L, a, o)
    L.erase(masks['hands'] | masks['prop'])
    return L


# ---------------------------------------------------------------- headwear

HEADWEAR = [
    {'id': 'starclip', 'name': '星星髮夾'},
    {'id': 'strawhat', 'name': '向陽草帽'},
    {'id': 'wizard', 'name': '星光巫師帽'},
    {'id': 'catears', 'name': '貓耳髮箍'},
    {'id': 'beanie', 'name': '暖暖毛線帽'},
    {'id': 'flowers', 'name': '春日花冠'},
]

STAR5 = [".G.", "GGG", ".G."]
STAR_BIG = ["..G..", ".GGG.", "GGGGG", ".GgG.", ".G.g."]


def draw_headwear(g, hw, masks):
    L = Layer()
    hx, hy = g['head']
    d = g['dir']
    side = g['side']
    hid = hw['id']
    if hid == 'starclip':
        if d == 'down':
            x, y = hx + 11, hy - 1
        elif d == 'up':
            x, y = hx + 11, hy
        else:
            x, y = hx + 9, hy - 1
        L.art(template(STAR_BIG, x, y, {'G': GOLD, 'g': GOLD_SH}), darken(GOLD_SH, 0.5))
    elif hid == 'strawhat':
        straw, straw_sh, band = (238, 200, 118), (196, 150, 76), (206, 70, 70)
        if side:
            brim = rect(hx - 4, hy + 2, hx + 17, hy + 3)
            crown = rect(hx + 2, hy - 4, hx + 13, hy + 1)
        else:
            brim = rect(hx - 4, hy + 2, hx + 19, hy + 3)
            crown = rect(hx + 2, hy - 4, hx + 15, hy + 1)
        crown &= ~pix([(hx + 2, hy - 4), (hx + (13 if side else 15), hy - 4)])
        painted = L.part(crown | brim, straw, shade=straw_sh, ring_color=darken(straw_sh, 0.5))
        bx1 = hx + (13 if side else 15)
        L.fill(rect(hx + 2, hy, bx1, hy + 1), band)
        L.fill(pix([(hx + 4 + k * 3, hy + 3) for k in range(5)]), straw_sh)
        if d == 'down':
            L.fill(pix([(hx + 4, hy - 2), (hx + 5, hy - 3)]), (252, 230, 170))
    elif hid == 'wizard':
        cloth, cloth_sh = (86, 60, 160), (58, 38, 116)
        brim = rect(hx - 3, hy + 2, hx + (17 if side else 18), hy + 3)
        cone = empty()
        tip = 3 if side else 2
        for k, y in enumerate(range(hy + 1, hy - 14, -1)):
            half = max(1, 7 - k // 2)
            bend = (k * k) // 40
            c = hx + 8 + bend * (1 if d != 'left' else 1)
            cone |= rect(c - half, y, c + half - 1, y)
        painted = L.part(cone | brim, cloth, shade=cloth_sh, ring_color=darken(cloth_sh, 0.5))
        L.fill(rect(hx + 1, hy, hx + 14, hy + 1), GOLD)
        L.art(template(STAR5, hx + 8, hy - 7, {'G': GOLD}), darken(GOLD_SH, 0.5), ring=False)
    elif hid == 'catears':
        fur, inner = HAIR_FOR_EARS
        ears = []
        if d == 'down' or d == 'up':
            ears = [(hx + 1, 1), (hx + 11, -1)]
        else:
            ears = [(hx + 5, 1), (hx + 11, -1)]
        for ex, flip in ears:
            m = empty()
            for k in range(5):
                if flip == 1:
                    m |= rect(ex + k, hy - 5 + k, ex + 4, hy - 5 + k)
                    m |= rect(ex, hy - 5 + k, ex + min(4, k), hy - 5 + k)
                else:
                    m |= rect(ex, hy - 5 + k, ex + 4 - k, hy - 5 + k)
                    m |= rect(ex + 4 - min(4, k), hy - 5 + k, ex + 4, hy - 5 + k)
            m = empty()
            for k in range(5):
                w = k + 1
                left = ex + (0 if flip == 1 else 4 - w + 1)
                m |= rect(left, hy - 5 + k, left + w - 1 + (1 if k > 2 else 0), hy - 5 + k)
            L.part(m, fur, ring_color=darken(fur, 0.45))
            if d != 'up':
                inn = m & shift(m, 1, 0) & shift(m, -1, 0) & shift(m, 0, 1)
                L.fill(inn, inner)
        L.fill(rect(hx + 1, hy, hx + 14, hy), (70, 60, 70))
    elif hid == 'beanie':
        knit, knit_sh, cuff = (96, 168, 150), (62, 120, 108), (168, 214, 196)
        dome = empty()
        rows = [(5, 10), (2, 13), (1, 14), (0, 15), (-1, 16), (-1, 16), (-1, 16)]
        if side:
            rows = [(4, 10), (2, 13), (1, 14), (0, 15), (-1, 16), (-1, 16), (-1, 16)]
        for k, (a, b) in enumerate(rows):
            dome |= rect(hx + a, hy - 4 + k, hx + b, hy - 4 + k)
        cuffm = rect(hx - 1, hy + 3, hx + 16, hy + 4)
        L.part(dome, knit, shade=knit_sh, ring_color=darken(knit_sh, 0.5))
        L.part(cuffm, cuff, shade=knit_sh, ring_color=darken(knit_sh, 0.5))
        L.fill(pix([(hx + k, hy + 3) for k in range(0, 16, 2)]), knit)
        L.part(rect(hx + 6, hy - 7, hx + 9, hy - 5), WHITE, shade=(220, 214, 220), ring_color=(140, 130, 150))
    elif hid == 'flowers':
        leaf, leaf_sh = (98, 160, 80), (62, 112, 52)
        band = rect(hx, hy + 1, hx + 15, hy + 1) if not side else rect(hx + 2, hy + 1, hx + 15, hy + 1)
        L.part(band, leaf, ring_color=darken(leaf_sh, 0.6))
        cols = [(240, 140, 170), WHITE, GOLD, (240, 140, 170), (190, 150, 240)]
        xs = [0, 4, 8, 12, 15] if not side else [3, 7, 11, 15]
        for k, x in enumerate(xs):
            c = cols[k % len(cols)]
            fl = template(["..p..", ".ppp.", "ppcpp", ".ppp.", "..p.."], hx + x - 2, hy - 2, {'p': c, 'c': GOLD if c != GOLD else WHITE})
            L.art(fl, darken(c, 0.5))
        if d == 'up':
            L.fill(rect(hx + 3, hy + 2, hx + 12, hy + 2), leaf_sh)
    L.erase(masks['hands'] | masks['prop'])
    return L


HAIR_FOR_EARS = ((236, 230, 220), (246, 170, 186))


# ---------------------------------------------------------------- accessories

ACCESSORIES = [
    {'id': 'scarf', 'name': '白色長圍巾'},
    {'id': 'glasses', 'name': '圓框眼鏡'},
    {'id': 'satchel', 'name': '皮革斜背包'},
    {'id': 'backpack', 'name': '星星背包'},
]


def draw_accessory(g, acc, masks):
    L = Layer()
    x0, tt, x1, hip = g['torso']
    d = g['dir']
    side = g['side']
    p = g['pose']
    moving = p.get('moving', 0)
    aid = acc['id']
    if aid == 'scarf':
        c, sh = (246, 242, 232), (200, 192, 186)
        band = rect(x0 - 1, tt, x1 + 1, tt + 1)
        if d == 'down':
            tail = rect(x1 - 3, tt + 2, x1 - 2, tt + 6)
        elif d == 'up':
            tail = rect(x0 + 3, tt + 2, x0 + 4, tt + 5) | rect(x0 + 5, tt + 2, x0 + 6, tt + 4)
        else:
            if moving:
                lift = moving
                tail = rect(x1 + 1, tt - lift, x1 + 4, tt + 1 - lift) | rect(x1 + 3, tt - lift - 1, x1 + 6, tt - lift)
            else:
                tail = rect(x1, tt + 1, x1 + 2, tt + 5)
        painted = L.part(band | tail, c, shade=sh, ring_color=darken(sh, 0.55))
        L.fill(rect(x0, tt + 1, x1, tt + 1) & band, sh)
        # The outline above the band would cover the mouth: give the chin back.
        L.erase(painted & ~(band | tail) & masks['head'] & rect(0, 0, W - 1, tt - 1))
    elif aid == 'glasses':
        if d != 'up':
            ox, oy = head_origin(g)
            frame = (70, 50, 40)
            lens = (200, 230, 246)
            rings = [3] if side else [3, 11]
            for c in rings:
                x, y = ox + c, oy + 11
                ring = rect(x, y, x + 3, y + 4) & ~rect(x + 1, y + 1, x + 2, y + 3)
                L.fill(ring, frame)
                L.fill(pix([(x + 2, y + 1)]), lens)
            if side:
                L.fill(rect(ox + 7, oy + 12, ox + 10, oy + 12), frame)
            else:
                L.fill(rect(ox + 7, oy + 12, ox + 10, oy + 12), frame)
    elif aid == 'satchel':
        leather, leather_sh, strap = (156, 98, 54), (112, 66, 36), (96, 58, 34)
        if d == 'down':
            L.fill(pix(line_pts((x1, tt), (x0 + 1, hip - 3))), strap)
            bag = rect(x0 - 5, hip - 4, x0, hip + 1)
        elif d == 'up':
            L.fill(pix(line_pts((x0, tt), (x1 - 1, hip - 3))), strap)
            bag = rect(x1, hip - 4, x1 + 5, hip + 1)
        else:
            L.fill(pix(line_pts((x1 - 2, tt), (x0 + 2, hip - 3))), strap)
            bag = rect(x0 + 1, hip - 3, x0 + 6, hip + 2)
        L.part(bag, leather, shade=leather_sh, ring_color=darken(leather_sh, 0.5))
        bx0 = int(np.argwhere(bag.any(axis=0))[0][0])
        by0 = int(np.argwhere(bag.any(axis=1))[0][0])
        L.fill(rect(bx0, by0, bx0 + 5, by0 + 1), leather_sh)
        L.fill(pix([(bx0 + 2, by0 + 2), (bx0 + 3, by0 + 2)]), GOLD)
    elif aid == 'backpack':
        pack, pack_sh, strap = (60, 74, 150), (38, 46, 104), (44, 52, 112)
        if d == 'down':
            L.fill(rect(x0 + 1, tt, x0 + 2, tt + 5) | rect(x1 - 2, tt, x1 - 1, tt + 5), strap)
            L.part(rect(x0 - 2, tt - 1, x0 - 1, tt + 1) | rect(x1 + 1, tt - 1, x1 + 2, tt + 1), pack, ring_color=darken(pack_sh, 0.5))
        elif d == 'up':
            body = rect(x0, tt + 1, x1, hip - 1)
            L.part(body, pack, shade=pack_sh, ring_color=darken(pack_sh, 0.5))
            L.fill(rect(x0, tt + 1, x1, tt + 3), pack_sh)
            cx = (x0 + x1) // 2
            L.art(template(STAR5, cx - 1, tt + 5, {'G': GOLD}), darken(GOLD_SH, 0.5), ring=False)
        else:
            body = rect(x1 + 1, tt + 1, x1 + 4, hip - 2)
            L.part(body, pack, shade=pack_sh, ring_color=darken(pack_sh, 0.5))
            L.fill(pix([(x1 + 2, tt + 4)]), GOLD)
            L.fill(rect(x1 - 1, tt, x1, tt + 4), strap)
    L.erase(masks['hands'] | masks['prop'])
    return L


# ---------------------------------------------------------------- animations

def walk_frames(d, n=6, run=False):
    out = []
    for i in range(n):
        t = 2 * math.pi * i / n
        s, c = math.sin(t), math.cos(t)
        if d in ('left', 'right'):
            amp = 5 if run else 3.5
            near = -amp * s
            far = amp * s
            nl = int(round((2.5 if run else 1.5) * c)) if c > 0 else 0
            fl = int(round(-(2.5 if run else 1.5) * c)) if c < 0 else 0
            bob = (-1 if abs(s) < 0.6 else 0) if not run else (-2 if abs(s) < 0.6 else 0)
            hand_amp = 3 if run else 2.5
            arms = {
                'near': {'pts': ([(int(round(-hand_amp * s * 0.5)), 3), (int(round(hand_amp * s)), 4)] if run else [(int(round(hand_amp * s)), 6)])},
                'far': {'pts': ([(int(round(hand_amp * s * 0.5)), 3), (int(round(-hand_amp * s)), 4)] if run else [(int(round(-hand_amp * s)), 6)])},
            }
            out.append({'dir': d, 'feet': {'near': (int(round(near)), nl), 'far': (int(round(far)), fl)},
                        'bob': bob, 'y': (-1 if run and abs(s) < 0.6 else 0), 'arms': arms,
                        'lean': -1 if run else 0, 'moving': 2 if run else 1, 'mouth': 'open' if run else 'smile'})
        else:
            amp = 3 if run else 2
            lL = int(round(amp * max(0, s)))
            lR = int(round(amp * max(0, -s)))
            bob = (-1 if abs(c) < 0.6 else 0) * (2 if run else 1)
            ha = 2 if run else 1
            arms = {'L': {'pts': [(-1 if not run else -2, int(round(6 - ha * s)) if not run else int(round(4 - ha * s)))]},
                    'R': {'pts': [(1 if not run else 2, int(round(6 + ha * s)) if not run else int(round(4 + ha * s)))]}}
            out.append({'dir': d, 'lift': (lL, lR), 'bob': bob, 'arms': arms, 'y': (-1 if run and abs(c) < 0.6 else 0),
                        'moving': 2 if run else 1, 'mouth': 'open' if run else 'smile'})
    return out


def rows():
    R = []

    def add(name, frames, fps, loop=True):
        R.append({'name': name, 'fps': fps, 'loop': loop, 'poses': frames})

    # Character clips run at 8-12 fps; slow moves hold a pose for several frames.
    breath = [0, 0, 0, -1, -1, -1, -1, 0, 0, 0, 0, 0]
    add('idle', [{'bob': b, 'eyes': 'closed' if i == 9 else 'open'} for i, b in enumerate(breath)], 8)
    look = [0, -1, -1, -1, -1, 0, 0, 1, 1, 1, 1, 0]
    add('look', [{'head': (l, 0), 'look': (l, 0), 'eyes': 'closed' if i == 5 else 'open',
                  'mouth': 'flat' if l else 'smile'} for i, l in enumerate(look)], 8)
    add('turn', [{'dir': d} for d in ('down', 'right', 'up', 'left')], 8)
    for d in ('down', 'left', 'right', 'up'):
        add(f'walk_{d}', walk_frames(d), 10)
    for d in ('down', 'left', 'right', 'up'):
        add(f'run_{d}', walk_frames(d, run=True), 12)
    sit = {'sit': 3, 'spread': 1, 'arms': {'L': {'pts': [(1, 5)]}, 'R': {'pts': [(-1, 5)]}}}
    add('sit', [{**sit, 'bob': b, 'eyes': 'closed' if i == 6 else 'open'}
                for i, b in enumerate([0, 0, -1, -1, -1, 0, 0, 0])], 8)
    hold = {'L': {'pts': [(1, 4), (2, 8)], 'z': 'front'}, 'R': {'pts': [(-1, 4), (-2, 8)], 'z': 'front'}}
    read = []
    for i in range(12):
        flip = [0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 0, 0][i]
        read.append({**sit, 'arms': hold, 'prop': ('book', flip), 'look': ([-1, -1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0][i], 1),
                     'eyes': 'open', 'mouth': 'smile' if flip else 'flat', 'bob': -1 if 3 <= i <= 6 else 0})
    add('read', read, 8)
    sleep_bob = [0, 0, 0, -1, -1, -1, -1, -1, 0, 0, 0, 0]
    add('sleep', [{'lie': True, 'eyes': 'closed', 'mouth': 'o' if b else 'flat', 'bob': b} for b in sleep_bob], 8)
    up = {'L': {'pts': [(-2, -1), (-3, -5)]}, 'R': {'pts': [(2, -1), (3, -5)]}}
    happy = [
        {'sit': 2, 'spread': 1, 'eyes': 'happy', 'mouth': 'grin'},
        {'y': -3, 'arms': up, 'eyes': 'happy', 'mouth': 'grin', 'lift': (1, 1)},
        {'y': -6, 'arms': up, 'eyes': 'happy', 'mouth': 'grin', 'lift': (2, 2)},
        {'y': -5, 'arms': up, 'eyes': 'happy', 'mouth': 'grin', 'lift': (1, 1)},
        {'y': -2, 'arms': up, 'eyes': 'happy', 'mouth': 'grin'},
        {'sit': 1, 'eyes': 'happy', 'mouth': 'grin'},
    ]
    add('happy', happy, 10, loop=False)
    wave = []
    for i, hx in enumerate([None, 3, 5, 3, 5, None]):
        arms = {'R': {'pts': [(3, 0), (hx, -7)]}} if hx is not None else {'R': {'pts': [(3, 2), (3, -2)]}}
        wave.append({'arms': arms, 'eyes': 'happy' if i in (2, 3) else 'open', 'mouth': 'open' if i % 2 else 'smile'})
    add('wave', wave, 8, loop=False)
    think = []
    for i in range(8):
        tap = (i // 2) % 2
        think.append({'arms': {'R': {'pts': [(0, 5), (-3, -1 + tap)], 'z': 'front'}, 'L': {'pts': [(1, 5)], 'z': 'side'}},
                      'head': (1 if i >= 4 else 0, 0), 'look': (1 if i < 4 else -1, -1), 'mouth': 'flat'})
    add('think', think, 8)
    stretch = [
        {'eyes': 'open'},
        {'arms': {'L': {'pts': [(-2, 2), (-3, -1)]}, 'R': {'pts': [(2, 2), (3, -1)]}}, 'eyes': 'closed', 'mouth': 'o'},
        {'arms': {'L': {'pts': [(-2, -1), (-3, -6)]}, 'R': {'pts': [(2, -1), (3, -6)]}}, 'bob': -1, 'eyes': 'closed', 'mouth': 'yawn'},
        {'arms': {'L': {'pts': [(-2, -2), (-2, -7)]}, 'R': {'pts': [(2, -2), (2, -7)]}}, 'bob': -1, 'y': -1, 'eyes': 'closed', 'mouth': 'yawn'},
        {'arms': {'L': {'pts': [(-2, -1), (-3, -6)]}, 'R': {'pts': [(2, -1), (3, -6)]}}, 'bob': -1, 'eyes': 'closed', 'mouth': 'o'},
        {'eyes': 'happy', 'mouth': 'smile'},
    ]
    stretch = stretch[:3] + [stretch[3], stretch[3], stretch[3]] + stretch[4:]
    add('stretch', stretch, 8, loop=False)
    snack = []
    seq = [((1, 5), 3, 'smile', 'open'), ((3, 3), 3, 'o', 'open'), ((5, -1), 3, 'open', 'open'),
           ((5, -1), 2, 'munch', 'happy'), ((3, 3), 2, 'munch', 'happy'), ((5, -1), 2, 'open', 'open'),
           ((5, -1), 1, 'munch', 'happy'), ((3, 3), 1, 'munch', 'happy')]
    for (hx, hy), size, mouth, eyes in seq:
        z = 'front' if hx >= 3 else 'side'
        pts = [(1, 4), (hx, hy)] if hx >= 3 else [(hx, hy)]
        snack.append({'arms': {'L': {'pts': pts, 'z': z}}, 'prop': ('cookie', size), 'mouth': mouth, 'eyes': eyes})
    add('snack', snack, 8)
    talk = []
    for i in range(4):
        talk.append({'mouth': ['open', 'smile', 'o', 'smile'][i], 'bob': [0, -1, 0, 0][i],
                     'arms': {'R': {'pts': [(2, 4), (3, 1 + (i % 2))] if i in (1, 2) else [(1, 6)]}}})
    add('talk', talk, 8)
    return R


# ---------------------------------------------------------------- render

def render(pose, hair, outfit, headwear, accessory):
    lie = pose.get('lie')
    d = pose.get('dir', 'down')
    p = dict(pose)
    if lie:
        p['dir'] = 'down'
    flip = d == 'right'
    if flip:
        p['dir'] = 'left'
    g = rig(p)
    body, masks = draw_body(g, hair)
    layers = {'body': body.a}
    layers['outfit'] = draw_outfit(g, outfit, masks).a if outfit else None
    layers['headwear'] = draw_headwear(g, headwear, masks).a if headwear else None
    layers['accessory'] = draw_accessory(g, accessory, masks).a if accessory else None
    out = {}
    for k, a in layers.items():
        if a is None:
            continue
        if flip:
            a = a[:, ::-1]
        if lie:
            a = lay_down(a)
        out[k] = a
    return out


def lay_down(a):
    sq = np.zeros((56, 56, 4), np.uint8)
    sq[:, 4:52] = a
    r = np.rot90(sq, k=1)
    out = np.zeros((H, W, 4), np.uint8)
    dx, dy = -8, 14
    for y in range(H):
        sy = y - dy
        if 0 <= sy < 56:
            row = r[sy]
            xs = slice(max(0, dx), min(W, 56 + dx))
            out[y, xs] = row[xs.start - dx:xs.stop - dx]
    return out


def composite(stack):
    base = np.zeros_like(stack[0])
    for a in stack:
        m = a[..., 3] > 0
        base[m] = a[m]
    return base


def build(out_dirs, preview=None):
    R = rows()
    nrows = len(R)
    sheets = {}

    def sheet(key):
        if key not in sheets:
            sheets[key] = np.zeros((nrows * H, COLS * W, 4), np.uint8)
        return sheets[key]

    for ri, row in enumerate(R):
        assert 4 <= len(row['poses']) <= COLS, row['name']
        for fi, pose in enumerate(row['poses']):
            oy, ox = ri * H, fi * W
            for hair in HAIR:
                a = render(pose, hair, None, None, None)['body']
                assert (a[..., 3] > 0).sum() > 120, (row['name'], fi, hair)
                sheet(f'body_{hair}')[oy:oy + H, ox:ox + W] = a
            for o in OUTFITS:
                a = render(pose, 'navy', o, None, None)['outfit']
                assert (a[..., 3] > 0).any(), (row['name'], fi, o['id'])
                sheet(f'outfit_{o["id"]}')[oy:oy + H, ox:ox + W] = a
            for hw in HEADWEAR:
                a = render(pose, 'navy', None, hw, None)['headwear']
                sheet(f'headwear_{hw["id"]}')[oy:oy + H, ox:ox + W] = a
            for acc in ACCESSORIES:
                a = render(pose, 'navy', None, None, acc)['accessory']
                sheet(f'accessory_{acc["id"]}')[oy:oy + H, ox:ox + W] = a

    manifest = {
        'frameWidth': W, 'frameHeight': H, 'columns': COLS, 'pivot': [CX, FOOT],
        'order': ['body', 'outfit', 'headwear', 'accessory'],
        'animations': [{'name': r['name'], 'frames': len(r['poses']), 'fps': r['fps'], 'loop': r['loop']} for r in R],
        'layers': {
            'body': [{'id': h, 'name': n, 'file': f'body_{h}.webp'} for h, n in
                     (('navy', '夜空藍髮'), ('chestnut', '栗子棕髮'), ('rose', '莓果粉髮'))],
            'outfit': [{'id': o['id'], 'name': o['name'], 'file': f'outfit_{o["id"]}.webp'} for o in OUTFITS],
            'headwear': [{'id': h['id'], 'name': h['name'], 'file': f'headwear_{h["id"]}.webp'} for h in HEADWEAR],
            'accessory': [{'id': a['id'], 'name': a['name'], 'file': f'accessory_{a["id"]}.webp'} for a in ACCESSORIES],
        },
        'default': {'body': 'navy', 'outfit': 'adventurer', 'headwear': 'starclip', 'accessory': 'scarf'},
    }
    for d in out_dirs:
        d.mkdir(parents=True, exist_ok=True)
        for k, a in sheets.items():
            Image.fromarray(a, 'RGBA').save(d / f'{k}.webp', lossless=True, quality=100, method=6, exact=True)
        (d / 'player.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    reference(sheets, R)
    if preview:
        preview_sheets(sheets, R, Path(preview))
    return sheets, manifest


def reference(sheets, R):
    """Character sheet kept for the next round: the default look in four views."""
    look = ['body_navy', 'outfit_adventurer', 'headwear_starclip', 'accessory_scarf']
    ti = next(i for i, r in enumerate(R) if r['name'] == 'turn')
    frames = []
    for f in range(4):
        frames.append(composite([sheets[k][ti * H:(ti + 1) * H, f * W:(f + 1) * W] for k in look]))
    strip = np.concatenate(frames, axis=1)
    im = Image.fromarray(strip, 'RGBA').resize((strip.shape[1] * 4, strip.shape[0] * 4), Image.NEAREST)
    im.save(ROOT / 'tool/character_art/reference/player.png', optimize=True)


def preview_sheets(sheets, R, out):
    out.mkdir(parents=True, exist_ok=True)
    looks = [
        ['body_navy', 'outfit_adventurer', 'headwear_starclip', 'accessory_scarf'],
        ['body_chestnut', 'outfit_gardener', 'headwear_strawhat', 'accessory_satchel'],
        ['body_rose', 'outfit_stargown', 'headwear_wizard', 'accessory_glasses'],
        ['body_navy', 'outfit_scholar', 'headwear_catears', 'accessory_glasses'],
        ['body_chestnut', 'outfit_sporty', 'headwear_beanie', 'accessory_backpack'],
        ['body_rose', 'outfit_raincoat', 'headwear_flowers', 'accessory_scarf'],
    ]
    for i, look in enumerate(looks):
        a = composite([sheets[k] for k in look])
        bg = np.zeros_like(a)
        bg[..., :3] = (70, 58, 92)
        bg[..., 3] = 255
        for ri in range(len(R)):
            if ri % 2:
                bg[ri * H:(ri + 1) * H, :, :3] = (80, 66, 104)
        m = a[..., 3] > 0
        bg[m] = a[m]
        Image.fromarray(bg, 'RGBA').resize((bg.shape[1] * 2, bg.shape[0] * 2), Image.NEAREST).save(out / f'look_{i}.png')


def main(argv):
    preview = None
    if '--preview' in argv:
        preview = argv[argv.index('--preview') + 1]
    outs = [ROOT / 'web_dashboard/assets/characters/player', ROOT / 'assets/characters/player']
    build(outs, preview)
    print('player sheets written to', ', '.join(str(o.relative_to(ROOT)) for o in outs))


if __name__ == '__main__':
    main(sys.argv[1:])
