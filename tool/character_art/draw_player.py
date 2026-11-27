"""Draw the layered player character (work package J1) at native pixel size.

  python -I tool/character_art/draw_player.py [--preview <dir>]

Designed after the earlier companion: spiky navy hair with a crown tuft,
big brown eyes, gold star clip and earring, a thick cream scarf, a navy
jacket with gold trim and cream cuffs, fingerless gloves, a belt pouch,
cream shorts and fur-topped boots.

Every frame is built from one pose rig (head, torso, arms, legs, props), and
each wardrobe layer is drawn from that same rig, so a body, an outfit, a
headwear and an accessory sheet always line up when stacked in this order:

  body -> outfit -> headwear -> accessory

Cells are 64x80 px (feet stand on row 76, centre column 32), one row per
animation. Sheets go to web_dashboard/assets/characters/player/ and
assets/characters/player/ together with player.json. Shown at whole-number
scale with nearest-neighbour (2x = 128x160).

The prompts these sprites stand in for (shared prefix as in the work
package, reference sheet attached on every call) are in player_prompts.json.
Other drawing scripts import the mask and Layer helpers from here.
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
W, H = 64, 80
CX = 32
FOOT = 76
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
    'navy': ((66, 84, 160), (40, 50, 112), (118, 140, 212)),
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
# Poses in rows() are written in the small units of the first version; the
# rig scales limb offsets by K so the same poses fit the bigger cell.

K = 1.5
K_ARM = 1.8  # chibi arms hang to the belt like the earlier companion


def sc(v):
    return int(round(v * K))


def sca(v):
    return int(round(v * K_ARM))


def rig(p):
    d = p.get('dir', 'down')
    side = d in ('left', 'right')
    jy = sc(p.get('y', 0))
    drop = sc(p.get('sit', 0))
    bob = p.get('bob', 0)
    lean = p.get('lean', 0)
    hip = 59 + jy + drop
    tt = 42 + jy + drop + bob
    hdx, hdy = p.get('head', (0, 0))
    g = {'dir': d, 'side': side, 'hip': hip, 'tt': tt, 'pose': p}
    g['head'] = (21 + hdx + lean, 22 + jy + drop + bob + hdy)  # 22 x 20 head box
    g['torso'] = (26 + lean, tt, 37, hip) if side else (25, tt, 38, hip)
    foot = FOOT + jy
    legs = []
    if side:
        feet = p.get('feet', {})
        for k in ('far', 'near'):
            fdx, lift = feet.get(k, (0, 0))
            knee = p.get('knees', {}).get(k)
            pts = [(32, hip + 1)] + ([(sc(knee[0] - 23) + 32, knee[1] + 24)] if knee else []) + [(32 + sc(fdx), foot - sc(lift))]
            legs.append({'pts': pts, 'near': k == 'near', 'key': k})
    else:
        lL, lR = p.get('lift', (0, 0))
        sp = sc(p.get('spread', 0))
        legs.append({'pts': [(28 - sp, hip + 1), (28 - sp, foot - sc(lL))], 'near': True, 'key': 'L'})
        legs.append({'pts': [(35 + sp, hip + 1), (35 + sp, foot - sc(lR))], 'near': True, 'key': 'R'})
    g['legs'] = legs
    arms = []
    spec = p.get('arms', {})
    if side:
        sh = (32 + lean, tt + 2)
        for k, z in (('far', 'back'), ('near', 'front')):
            a = spec.get(k, {})
            pts = a.get('pts', [(0, 6)])
            arms.append({'key': k, 'z': a.get('z', z), 'pts': [sh] + [(sh[0] + sca(x), sh[1] + sca(y)) for x, y in pts], 'ax': 1})
    else:
        for k, sx, ax in (('L', 22, 0), ('R', 41, 2)):
            a = spec.get(k, {})
            pts = a.get('pts', [(-1 if k == 'L' else 1, 6)])
            sh = (sx, tt + 2)
            arms.append({'key': k, 'z': a.get('z', 'side'), 'pts': [sh] + [(sh[0] + sca(x), sh[1] + sca(y)) for x, y in pts], 'ax': ax})
    g['arms'] = arms
    return g


def arm_mask(a, upto=1.0, w=3):
    pts = poly_pts(a['pts'])
    n = max(1, math.ceil(len(pts) * upto))
    ax = a['ax'] if w == 3 else (1 if w == 4 else 0)
    return stamp(pts[:n], w, 2, ax=min(ax, w - 1), ay=0)


def hand_mask(a):
    x, y = a['pts'][-1]
    return stamp([(x, y)], 3, 3, ax=a['ax'], ay=1)


def leg_mask(leg, upto=1.0, w=4):
    pts = poly_pts(leg['pts'])
    n = max(1, math.ceil(len(pts) * upto))
    return stamp(pts[:n], w, 1, ax=w // 2 - (0 if w % 2 else 1) + (0 if w == 4 else 0))


# ---------------------------------------------------------------- head art
# Origin (hx - 4, hy - 8). H hair, h shade, d deep shade, l highlight,
# S skin, s skin shade. One outline goes around the whole head.

def _pad(rows, w=30):
    return [r.ljust(w, '.')[:w] for r in rows]


HEAD_DOWN = _pad([
    "................hh",
    "...............hlhh",
    "..............hlHh.h",
    "........hh....hHHh......hh",
    ".......hHh..hhHHHhh...hhHh",
    ".....h.hHHhhHlHHHHHhhhHHHh..h",
    "....hHhHlHHHlHHHHHHHHHHHHHhhHh",
    "...hHHHlHHHlHHHHHHHlHHHHHHHHHHh",
    "..hHHlHHHHHHHHHlHHHHHHHHlHHHHHHh",
    ".hHHHHHHHlHHHHHHHHHHHHHHHHHHHHHHh",
    "hHHHlHHHHHHHHHHHHHHHHHHHHHHlHHHHHh",
    ".hHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHhd",
    "hHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHhd",
    ".hHHHHHHHHHHhHHHHHHHHhHHHHHHHHHhd",
    "hHHHHHHHHHhSHHHHHHHHhSHHHHHhHHHhd",
    ".hHHHHHHHhSShHHHHHHhSSShHHHhSHHhhd",
    "..hHHHHHhSSShHHHHHHhSSSShHHHhSHhd",
    "...hHHHhSSSSShHHHHhSSSSSShHhSSHhd",
    "....hHhSSSSSSShHHhSSSSSSSShSSSShd",
    "....hHSSSSSSSSShhSSSSSSSSSSSSSShd",
    "....hHSSSSSSSSSSSSSSSSSSSSSSSShd",
    "....dHSSSSSSSSSSSSSSSSSSSSSSSShd",
    "....dhSSSSSSSSSSSSSSSSSSSSSSSShd",
    "....dhSSSSSSSSSSSSSSSSSSSSSSSShd",
    ".....dSSSSSSSSSSSSSSSSSSSSSSSSd",
    ".....dSSSSSSSSSSSSSSSSSSSSSSSsd",
    "......SSSSSSSSSSSSSSSSSSSSSSss",
    "......sSSSSSSSSSSSSSSSSSSSSSs",
    ".......sSSSSSSSSSSSSSSSSSSSs",
    "........ssSSSSSSSSSSSSSSss",
    "..........ssssssssssssss",
], 34)
HEAD_UP = _pad([
    "................hh",
    "...............hlhh",
    "..............hlHh.h",
    "........hh....hHHh......hh",
    ".......hHh..hhHHHhh...hhHh",
    ".....h.hHHhhHlHHHHHhhhHHHh..h",
    "....hHhHlHHHlHHHHHHHHHHHHHhhHh",
    "...hHHHlHHHlHHHHHHHlHHHHHHHHHHh",
    "..hHHlHHHHHHHHHlHHHHHHHHlHHHHHHh",
    ".hHHHHHHHlHHHHHHHHHHHHHHHHHHHHHHh",
    "hHHHlHHHHHHHHHHHHHHHHHHHHHHlHHHHHh",
    ".hHHHHHHHHHHlHHHHHHHHHHHlHHHHHHHhd",
    "hHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHhd",
    ".hHHHHHHlHHHHHHHHHHHHHHHHHlHHHHhd",
    "hHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHhd",
    ".hHHHHHHHHHHHHHHHHHHHHHHHHHHHHhhd",
    "..hHHHHHHHHhHHHHHHHHhHHHHHHHHhhd",
    "...hHHHHHHhHHHHHHHHHHhHHHHHHhhd",
    "....hHHHHhHHHHHHHHHHHHhHHHHhhd",
    "....hhHHHhHHHHHHHHHHHHHhHHhhhd",
    "....dhhHhHHHHHHhHHhHHHHHhhhhd",
    "....dhhhHHHHHHhHHHHhHHHHhhhd",
    ".....dhhhHHHHhHHHHHHhHHhhhd",
    ".....ddhhhhhhhhhhhhhhhhhhdd",
    ".......ddhhhhhhhhhhhhhhdd",
    ".........ddhhhhhhhhhhdd",
    "............sSSSSSSSs",
    "............sSSSSSSSs",
], 34)
HEAD_SIDE = _pad([
    "..................hh",
    ".................hlhh",
    "..................hh",
    ".................hHh..h",
    "............h...hHHh.hh....h",
    "...........hHh.hHlHhhHh..hHh",
    "..........hHHhhHlHHHHHHhhHHh..h",
    "........hHHlHHHlHHHHHHHHHHHhhHh",
    ".......hHlHHHlHHHHHHHHHHHHHHHHh",
    "......hHlHHHlHHHHHHHHHHHHHHHHHHh",
    ".....hHlHHHHHHHHHHHHHHHHHHHHHHHh",
    "....hHHHHHHHHHHHHHHHHHHHHHHHHHh",
    "...hHHHHHHHHHHHHHHHHHHHHHHHHHHHh",
    "...hHHHHhHHHHHHHHHHHHHHHHHHHHHhd",
    "..hHHHhShHHHhHHHHHHHHHHHHHHHHhd",
    "..hHHhSSShHhSShHHHHHHHHHHHHHHhd",
    "...hhSSSSShSSSShHHHHHHHHHHHHhd",
    "....SSSSSSSSSSSShHHHHHHHHHHHhd",
    "...SSSSSSSSSSSSSShHHHHHHHHHhd",
    "...SSSSSSSSSSSSSSShHHHHHHHhd",
    "..SSSSSSSSSSSSSSSSsHHHHHHhd",
    "..SSSSSSSSSSSSSSSSsshHHHhd",
    "..SSSSSSSSSSSSSSSSSshHHhd",
    "...SSSSSSSSSSSSSSSSshHhd",
    "..SSSSSSSSSSSSSSSSSsshhd",
    "...SSSSSSSSSSSSSSSSsd",
    "...SSSSSSSSSSSSSSSss",
    "....SSSSSSSSSSSSSss",
    ".....sSSSSSSSSSSss",
    "......sssSSSSSss",
    "........ssssss",
], 34)

EYE_BROWN, EYE_DARK, EYE_LIGHT = (126, 76, 48), (58, 32, 26), (196, 136, 84)


def head_origin(g):
    hx, hy = g['head']
    return hx - 6, hy - 10


def draw_head(L, g, hair):
    base, shade, light = HAIR[hair]
    deep = darken(shade, 0.72)
    ox, oy = head_origin(g)
    rows = {'down': HEAD_DOWN, 'up': HEAD_UP}.get(g['dir'], HEAD_SIDE)
    parts = template(rows, ox, oy, {'H': base, 'h': shade, 'd': deep, 'l': light, 'S': SKIN, 's': SKIN_SH})
    painted = L.art(parts, darken(shade, 0.5))
    if g['dir'] != 'up':
        draw_face(L, g, ox, oy, shade)
    return painted


EYE_OPEN = ["####", "#Wbb", "bWbb", "bbpb", "bppb", ".LL."]


def draw_face(L, g, ox, oy, brow):
    p = g['pose']
    side = g['side']
    lx, ly = p.get('look', (0, 0))
    eyes = p.get('eyes', 'open')
    cols = [8] if side else [10, 20]
    er = 19 + ly
    for c in cols:
        x = ox + c + lx
        y = oy + er
        if eyes in ('open', 'wide'):
            pal = {'#': INK, 'W': WHITE, 'b': EYE_BROWN, 'p': EYE_DARK, 'L': EYE_LIGHT}
            for r, row in enumerate(EYE_OPEN):
                for k, ch in enumerate(row):
                    if ch != '.':
                        L.fill(pix([(x + k, y + r - (1 if eyes == 'wide' and r == 0 else 0))]), pal[ch])
        elif eyes == 'half':
            L.fill(pix([(x + k, y + 2) for k in range(4)]), INK)
            L.fill(pix([(x + k, y + 3) for k in range(4)] + [(x + 1, y + 4), (x + 2, y + 4)]), EYE_BROWN)
            L.fill(pix([(x + 1, y + 3)]), EYE_DARK)
        elif eyes == 'happy':
            L.fill(pix([(x - 1, y + 4), (x, y + 3), (x + 1, y + 2), (x + 2, y + 2), (x + 3, y + 3), (x + 4, y + 4)]), INK)
        else:  # closed
            L.fill(pix([(x - 1, y + 2), (x, y + 3), (x + 1, y + 4), (x + 2, y + 4), (x + 3, y + 3), (x + 4, y + 2)]), INK)
        # brows
        if eyes not in ('closed', 'happy'):
            L.fill(pix([(x, y - 2), (x + 1, y - 2), (x + 2, y - 2)] if not side else [(x, y - 2), (x + 1, y - 2), (x + 2, y - 2)]), darken(brow, 0.8))
    if p.get('blush', False) or eyes == 'happy':
        bc = [11] if side else [7, 24]
        L.fill(pix([(ox + c + k, oy + 25) for c in bc for k in (0, 1, 2)]), BLUSH)
    mx = ox + (5 if side else 16)
    my = oy + 27
    m = p.get('mouth', 'smile')
    if m == 'smile':
        L.fill(pix([(mx, my), (mx + 1, my)] + ([] if side else [(mx - 1, my - 1), (mx + 2, my - 1)])), MOUTH)
    elif m == 'flat':
        L.fill(pix([(mx, my), (mx + 1, my)]), MOUTH)
    elif m in ('open', 'o'):
        L.fill(pix([(mx - 1, my), (mx, my), (mx + 1, my), (mx + 2, my)] if not side else [(mx, my), (mx + 1, my)]), MOUTH)
        L.fill(pix([(mx, my + 1), (mx + 1, my + 1)]), MOUTH if m == 'o' else TONGUE)
    elif m == 'grin':
        L.fill(pix([(mx - 2, my - 1), (mx - 1, my), (mx, my), (mx + 1, my), (mx + 2, my), (mx + 3, my - 1)] if not side else [(mx, my), (mx + 1, my), (mx + 2, my)]), MOUTH)
        L.fill(pix([(mx, my + 1), (mx + 1, my + 1)]), TONGUE)
    elif m == 'yawn':
        L.fill(pix([(mx, my - 1), (mx + 1, my - 1), (mx - 1, my), (mx, my), (mx + 1, my), (mx + 2, my)]), MOUTH)
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
        x0, y0 = 22, tt + 4
        painted = L.part(rect(x0, y0 + 1, x0 + 19, y0 + 9), (150, 70, 60), ring_color=darken((150, 70, 60), 0.45))
        L.fill(rect(x0 + 1, y0, x0 + 9, y0 + 8), PARCH)
        L.fill(rect(x0 + 10, y0, x0 + 18, y0 + 8), PARCH)
        L.fill(rect(x0 + 9, y0, x0 + 10, y0 + 8), PARCH_SH)
        for r in (2, 4, 6):
            L.fill(rect(x0 + 2, y0 + r, x0 + 7, y0 + r), PARCH_SH)
            L.fill(rect(x0 + 12, y0 + r, x0 + 17, y0 + r), PARCH_SH)
        if k:
            shapes = {1: (x0 + 10, y0 - 2, x0 + 16, y0 + 7), 2: (x0 + 9, y0 - 5, x0 + 11, y0 + 7), 3: (x0 + 3, y0 - 2, x0 + 9, y0 + 7)}[k]
            m = rect(*shapes)
            L.part(m, WHITE, shade=PARCH, ring_color=PARCH_SH)
            painted |= dilate(m)
        return painted
    if kind == 'cookie':
        a = next(a for a in g['arms'] if a['key'] in ('L', 'near'))
        x, y = a['pts'][-1]
        size = {3: 6, 2: 5, 1: 3}[k]
        m = rect(x - 1, y - size + 1, x - 2 + size, y) & ~pix([(x - 1, y - size + 1), (x - 2 + size, y - size + 1), (x - 1, y), (x - 2 + size, y)])
        painted = L.part(m, COOKIE, shade=COOKIE_SH, ring_color=darken(COOKIE_SH, 0.6))
        if size >= 5:
            L.fill(pix([(x, y - 2), (x + 2, y - 3)]), CHOC)
        if size == 6:
            L.fill(pix([(x + 3, y - 1), (x + 1, y - 4)]), CHOC)
        return painted
    return empty()


# ---------------------------------------------------------------- body

def draw_body(g, hair):
    L = Layer()
    masks = {'head': empty(), 'front_arms': empty(), 'hands': empty(), 'prop': empty()}
    ring = darken(SKIN_SH, 0.55)

    def arm(a):
        painted = L.part(arm_mask(a), SKIN, shade=SKIN_SH, ring_color=ring)
        hp = L.part(hand_mask(a), SKIN, shade=SKIN_SH, ring_color=ring)
        masks['hands'] |= hp
        if a['z'] == 'front':
            masks['front_arms'] |= painted | hp

    for a in g['arms']:
        if a['z'] == 'back':
            arm(a)
    for leg in sorted(g['legs'], key=lambda l: l['near']):
        L.part(leg_mask(leg), SKIN, shade=SKIN_SH, ring_color=ring)
    x0, y0, x1, y1 = g['torso']
    L.part(rect(x0, y0, x1, y1), UNDER, shade=UNDER_SH, ring_color=darken(UNDER_SH, 0.5))
    for a in g['arms']:
        if a['z'] == 'side':
            arm(a)
    masks['head'] = draw_head(L, g, hair)
    fronts = [a for a in g['arms'] if a['z'] == 'front']
    for a in fronts:
        masks['front_arms'] |= L.part(arm_mask(a), SKIN, shade=SKIN_SH, ring_color=ring)
    masks['prop'] = draw_prop(L, g)
    for a in fronts:
        hp = L.part(hand_mask(a), SKIN, shade=SKIN_SH, ring_color=ring)
        masks['hands'] |= hp
        masks['front_arms'] |= hp
    return L, masks


# ---------------------------------------------------------------- outfits

CREAM, CREAM_SH = (240, 228, 200), (204, 188, 158)
OUTFITS = [
    {'id': 'adventurer', 'name': '冒險外套', 'top': (52, 66, 140), 'top_sh': (32, 40, 96), 'trim': GOLD,
     'sleeve': 0.8, 'sleeve_c': (52, 66, 140), 'cuff': CREAM, 'inner': WHITE, 'bottom': 'shorts', 'bot': (238, 226, 198),
     'bot_sh': (198, 180, 142), 'shoe': (132, 82, 46), 'shoe_top': CREAM, 'boot': 6, 'belt': (110, 70, 40),
     'gloves': (120, 76, 44), 'pouch': True},
    {'id': 'gardener', 'name': '園丁吊帶褲', 'top': (244, 204, 92), 'top_sh': (200, 156, 52), 'sleeve': 0.45,
     'sleeve_c': (244, 204, 92), 'bottom': 'pants', 'bot': (88, 144, 74), 'bot_sh': (58, 100, 50),
     'over': (88, 144, 74), 'shoe': (100, 64, 40), 'boot': 4},
    {'id': 'stargown', 'name': '星夜法袍', 'top': (104, 76, 180), 'top_sh': (70, 50, 134), 'sleeve': 1.0,
     'sleeve_c': (104, 76, 180), 'wide': True, 'bottom': 'robe', 'bot': (104, 76, 180), 'bot_sh': (70, 50, 134),
     'stars': GOLD, 'shoe': (60, 40, 90), 'boot': 2, 'belt': GOLD, 'trim': GOLD},
    {'id': 'scholar', 'name': '書院學者', 'top': (138, 92, 56), 'top_sh': (98, 62, 38), 'sleeve': 1.0,
     'sleeve_c': (236, 230, 218), 'inner': (236, 230, 218), 'tie': (204, 64, 64), 'bottom': 'pants',
     'bot': (70, 58, 86), 'bot_sh': (48, 38, 62), 'shoe': (86, 52, 34), 'boot': 2, 'buttons': GOLD},
    {'id': 'sporty', 'name': '晨跑運動服', 'top': (214, 72, 62), 'top_sh': (160, 46, 40), 'sleeve': 1.0,
     'sleeve_c': (214, 72, 62), 'stripe': WHITE, 'bottom': 'pants', 'bot': (214, 72, 62), 'bot_sh': (160, 46, 40),
     'shoe': (246, 242, 232), 'shoe_trim': (214, 72, 62), 'boot': 3},
    {'id': 'raincoat', 'name': '雨天黃雨衣', 'top': (246, 196, 58), 'top_sh': (204, 150, 30), 'sleeve': 1.0,
     'sleeve_c': (246, 196, 58), 'bottom': 'coat', 'bot': (246, 196, 58), 'bot_sh': (204, 150, 30),
     'shoe': (74, 124, 204), 'boot': 7, 'buttons': (120, 80, 30)},
]


def sleeve(L, a, o):
    if o['sleeve'] <= 0:
        return empty()
    w = 4 if o.get('wide') else 3
    pts = poly_pts(a['pts'])
    n = max(1, math.ceil(len(pts) * o['sleeve']))
    m = stamp(pts[:n], w, 3, ax=min(a['ax'], w - 1) if w == 3 else (0 if a['ax'] == 0 else 3 if a['ax'] == 2 else 1), ay=1)
    painted = L.part(m, o['sleeve_c'], shade=o['top_sh'] if o['sleeve_c'] == o['top'] else darken(o['sleeve_c'], 0.82))
    end = pts[n - 1]
    if o.get('stripe'):
        L.fill(m & stamp(pts[:n], 1, 1), o['stripe'])
    cuff = o.get('cuff') or (o.get('trim') if o['sleeve'] >= 1 else None)
    if cuff:
        cm = stamp([end, pts[max(0, n - 2)]], w + 1, 2, ax=1, ay=1) & dilate(m)
        L.part(cm & ~shift(cm, 0, 0) | cm, cuff, shade=darken(cuff, 0.85), ring_color=darken(cuff, 0.5))
    return painted


def draw_outfit(g, o, masks):
    L = Layer()
    side = g['side']
    d = g['dir']
    x0, tt, x1, hip = g['torso']
    for a in g['arms']:
        if a['z'] == 'back':
            sleeve(L, a, o)
    for leg in sorted(g['legs'], key=lambda l: l['near']):
        if o['bottom'] in ('pants', 'shorts', 'coat'):
            frac = {'pants': 0.78, 'shorts': 0.3, 'coat': 0.3}[o['bottom']]
            L.part(leg_mask(leg, frac, 7 if o['bottom'] == 'shorts' else 4), o['bot'], shade=o['bot_sh'])
            if o.get('stripe'):
                L.fill(leg_mask(leg, frac, 1), o['stripe'])
        fx, fy = leg['pts'][-1]
        boot = o.get('boot', 2)
        if side:
            sm = rect(fx - 3, fy - boot, fx + 1, fy) | rect(fx - 4, fy - 1, fx + 1, fy)
        else:
            sm = rect(fx - 3, fy - boot, fx + 2, fy) | (rect(fx - 4, fy - 2, fx + 2, fy) if leg['key'] == 'L' else rect(fx - 3, fy - 2, fx + 3, fy))
        L.part(sm, o['shoe'], shade=darken(o['shoe'], 0.75))
        top = sm & ~shift(sm, 0, -1)
        if o.get('shoe_top') and boot >= 4:
            L.part(dilate(top) & rect(0, fy - boot - 1, W - 1, fy - boot + 1), o['shoe_top'], shade=darken(o['shoe_top'], 0.85), ring_color=darken(o['shoe_top'], 0.55))
        if o.get('shoe_trim'):
            L.fill(sm & ~shift(sm, 0, 1), o['shoe_trim'])
        if not o.get('shoe_top'):
            L.fill(pix([(fx - 1, fy - 1)]), darken(o['shoe'], 1.25) if sum(o['shoe']) < 500 else (255, 255, 255))
    if o['bottom'] in ('robe', 'coat'):
        feet_y = max(l['pts'][-1][1] for l in g['legs'])
        hem = max(feet_y - (2 if o['bottom'] == 'robe' else 7), hip + 4)
        m = empty()
        for y in range(hip - 1, hem + 1):
            t = (y - hip + 1) / max(1, hem - hip + 1)
            grow = int(round(t * (3 if o['bottom'] == 'robe' else 2)))
            if side:
                walk = g['pose'].get('feet', {}).get('near', (0, 0))[0]
                sx = int(round(t * min(3, abs(walk) / 2))) * (-1 if walk < 0 else 1)
                m |= rect(x0 - grow + min(0, sx), y, x1 + grow + max(0, sx), y)
            else:
                m |= rect(x0 - grow, y, x1 + grow, y)
        L.part(m, o['bot'], shade=o['bot_sh'])
        if o.get('trim') and o['bottom'] == 'robe':
            L.fill(m & ~shift(m, 0, 1), o['trim'])
        if o.get('stars'):
            for sx, sy in ((x0 + 3, hip + 4), (x1 - 3, hip + 8), (x0 + 6, hem - 2), (x1 - 1, hem - 4)):
                if 0 <= sy < H and 0 <= sx < W and m[sy, sx]:
                    L.fill(pix([(sx, sy), (sx - 1, sy), (sx + 1, sy), (sx, sy - 1), (sx, sy + 1)]), o['stars'])
    tm = rect(x0, tt, x1, hip - (0 if o['bottom'] in ('robe', 'coat') else 1))
    L.part(tm, o['top'], shade=o['top_sh'])
    cx = (x0 + x1) // 2
    if d == 'down':
        if o.get('inner'):
            L.fill(rect(cx - 1, tt + 1, cx + 2, hip - 3), o['inner'])
            L.fill(rect(cx - 1, tt + 1, cx + 2, tt + 1), darken(o['inner'], 0.9))
        if o.get('trim'):
            L.fill(rect(cx - 2, tt + 1, cx - 2, hip - 2) | rect(cx + 3, tt + 1, cx + 3, hip - 2), o['trim'])
            L.fill(rect(x0, hip - 2, x1, hip - 2) & ~rect(cx - 1, 0, cx + 2, H - 1), o['trim'])
        if o.get('tie'):
            L.fill(pix([(cx, tt + 1), (cx + 1, tt + 1), (cx, tt + 2), (cx + 1, tt + 2), (cx, tt + 3), (cx + 1, tt + 4)]), o['tie'])
        if o.get('buttons'):
            bx = cx - 2 if o['id'] == 'scholar' else cx
            L.fill(pix([(bx, tt + 5), (bx, tt + 9), (bx, tt + 13)]), o['buttons'])
        if o.get('stars'):
            L.fill(pix([(x0 + 3, tt + 4), (x1 - 3, tt + 7), (x0 + 4, tt + 11)]), o['stars'])
        if o.get('stripe'):
            L.fill(rect(cx, tt + 1, cx + 1, hip - 2), o['stripe'])
    elif side:
        if o.get('trim'):
            L.fill(rect(x0 + 1, tt + 1, x0 + 1, hip - 2), o['trim'])
        if o.get('inner'):
            L.fill(rect(x0, tt + 1, x0, tt + 5), o['inner'])
        if o.get('stars'):
            L.fill(pix([(x0 + 4, tt + 6)]), o['stars'])
    else:
        if o.get('stars'):
            L.fill(pix([(cx, tt + 6), (x0 + 3, tt + 10), (x1 - 3, tt + 4)]), o['stars'])
        if o['id'] == 'adventurer':
            L.fill(rect(x0, hip - 2, x1, hip - 2), o['trim'])
    if o['bottom'] == 'pants' and o.get('over'):
        ov = rect(x0 + 1, tt + 6, x1 - 1, hip)
        L.part(ov, o['over'], shade=darken(o['over'], 0.75))
        if d != 'up':
            L.part(rect(cx - 3, tt + 8, cx + 4, tt + 11), darken(o['over'], 0.85))
        if not side:
            L.fill(rect(x0 + 1, tt, x0 + 2, tt + 5) | rect(x1 - 2, tt, x1 - 1, tt + 5), o['over'])
            L.fill(pix([(x0 + 2, tt + 6), (x1 - 2, tt + 6)]), GOLD)
    if o.get('belt') and o['bottom'] != 'pants':
        by = hip - 2 if o['bottom'] == 'shorts' else hip - 3
        L.fill(rect(x0, by, x1, by + 1), o['belt'])
        if d == 'down':
            L.part(rect(cx, by, cx + 1, by + 1), GOLD if o['belt'] != GOLD else WHITE, ring=False)
        if o.get('pouch') and d != 'up':
            px = x0 - 1 if d == 'down' else x0 + 2
            pm = rect(px, by + 1, px + 4, by + 5)
            L.part(pm, (150, 96, 54), shade=(110, 66, 36))
            L.fill(pix([(px + 2, by + 3)]), GOLD)
    L.erase(masks['head'] | masks['front_arms'])
    for a in g['arms']:
        if a['z'] in ('side', 'front'):
            sleeve(L, a, o)
    L.erase(masks['hands'] | masks['prop'])
    if o.get('gloves'):
        for a in g['arms']:
            hm = hand_mask(a)
            if a['z'] == 'back':
                hm &= ~masks['front_arms']
            L.part(hm & ~masks['prop'], o['gloves'], shade=darken(o['gloves'], 0.75), ring_color=darken(o['gloves'], 0.5))
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
STAR_BIG = ["...G...", "..GGG..", "GGGlGGG", ".GGGGG.", "..GgG..", ".GG.GG.", "Gg...gG"]


def draw_headwear(g, hw, masks):
    L = Layer()
    hx, hy = g['head']
    d = g['dir']
    side = g['side']
    hid = hw['id']
    star = lambda x, y: L.art(template(STAR_BIG, x, y, {'G': GOLD, 'g': GOLD_SH, 'l': (255, 240, 180)}), darken(GOLD_SH, 0.5))
    if hid == 'starclip':
        if d == 'down':
            star(hx + 15, hy - 3)
            L.art(template(STAR5, hx + 22, hy + 16, {'G': GOLD}), darken(GOLD_SH, 0.5))  # earring
            L.fill(pix([(hx + 23, hy + 14), (hx + 23, hy + 15)]), GOLD_SH)
        elif d == 'up':
            star(hx + 16, hy - 1)
        else:
            star(hx + 9, hy - 3)
            L.art(template(STAR5, hx + 9, hy + 16, {'G': GOLD}), darken(GOLD_SH, 0.5))
    elif hid == 'strawhat':
        straw, straw_sh, band = (238, 200, 118), (196, 150, 76), (206, 70, 70)
        brim = rect(hx - 6, hy + 1, hx + 27, hy + 4) & ~pix([(hx - 6, hy + 1), (hx + 27, hy + 1), (hx - 6, hy + 4), (hx + 27, hy + 4)])
        crown = rect(hx + 2, hy - 9, hx + 19, hy + 1) & ~pix([(hx + 2, hy - 9), (hx + 19, hy - 9), (hx + 3, hy - 9), (hx + 18, hy - 9), (hx + 2, hy - 8), (hx + 19, hy - 8)])
        L.part(crown | brim, straw, shade=straw_sh, ring_color=darken(straw_sh, 0.5))
        L.fill(rect(hx + 2, hy - 2, hx + 19, hy), band)
        L.fill(pix([(hx - 2 + k * 4, hy + 3) for k in range(8)]), straw_sh)
        L.fill(pix([(hx + 5 + k * 4, hy - 6 + (k % 2)) for k in range(4)]), straw_sh)
    elif hid == 'wizard':
        cloth, cloth_sh = (86, 60, 160), (58, 38, 116)
        brim = rect(hx - 5, hy + 1, hx + 26, hy + 4) & ~pix([(hx - 5, hy + 1), (hx + 26, hy + 1)])
        cone = empty()
        for k, y in enumerate(range(hy + 1, hy - 20, -1)):
            half = max(1, 10 - k // 2)
            bend = (k * k) // 60
            c = hx + 11 + bend
            cone |= rect(c - half, y, c + half - 1, y)
        L.part(cone | brim, cloth, shade=cloth_sh, ring_color=darken(cloth_sh, 0.5))
        L.fill(rect(hx + 1, hy - 2, hx + 20, hy), GOLD)
        L.art(template(STAR_BIG, hx + 8, hy - 11, {'G': GOLD, 'g': GOLD_SH, 'l': (255, 240, 180)}), darken(GOLD_SH, 0.5), ring=False)
    elif hid == 'catears':
        fur, inner = (236, 230, 220), (246, 170, 186)
        for ex, flip in ([(hx + 1, 1), (hx + 14, -1)] if not side else [(hx + 6, 1), (hx + 14, -1)]):
            m = empty()
            for k in range(8):
                w = k // 2 + 1
                left = ex + (0 if flip == 1 else 7 - w * 2 + 1)
                m |= rect(left + (k // 4 if flip == 1 else 0), hy - 8 + k, left + w * 2 - 1 + (k // 4 if flip == -1 else 0), hy - 8 + k)
            L.part(m, fur, shade=(200, 194, 190), ring_color=darken(fur, 0.45))
            if d != 'up':
                L.fill(m & shift(m, 1, 0) & shift(m, -1, 0) & shift(m, 0, 1) & shift(m, 0, 2), inner)
        L.fill(rect(hx + 2, hy, hx + 19, hy), (70, 60, 70))
    elif hid == 'beanie':
        knit, knit_sh, cuff = (96, 168, 150), (62, 120, 108), (168, 214, 196)
        dome = empty()
        rows = [(7, 14), (4, 17), (2, 19), (1, 20), (0, 21), (-1, 22), (-1, 22), (-2, 23), (-2, 23)]
        for k, (a, b) in enumerate(rows):
            dome |= rect(hx + a, hy - 7 + k, hx + b, hy - 7 + k)
        cuffm = rect(hx - 2, hy + 2, hx + 23, hy + 5)
        L.part(dome, knit, shade=knit_sh, ring_color=darken(knit_sh, 0.5))
        L.fill(pix([(hx + k, hy - 4 + (k % 3)) for k in range(1, 21, 3)]), knit_sh)
        L.part(cuffm, cuff, shade=knit_sh, ring_color=darken(knit_sh, 0.5))
        L.fill(pix([(hx - 1 + k, y) for k in range(0, 25, 2) for y in (hy + 3, hy + 4)]), knit)
        L.part(rect(hx + 8, hy - 12, hx + 13, hy - 8) & ~pix([(hx + 8, hy - 12), (hx + 13, hy - 12), (hx + 8, hy - 8), (hx + 13, hy - 8)]), WHITE, shade=(220, 214, 220), ring_color=(140, 130, 150))
    elif hid == 'flowers':
        leaf, leaf_sh = (98, 160, 80), (62, 112, 52)
        band = rect(hx - 1, hy, hx + 22, hy + 1) if not side else rect(hx + 3, hy, hx + 22, hy + 1)
        L.part(band, leaf, shade=leaf_sh, ring_color=darken(leaf_sh, 0.6))
        cols = [(240, 140, 170), WHITE, GOLD, (240, 140, 170), (190, 150, 240), WHITE]
        xs = [0, 5, 10, 15, 20] if not side else [5, 10, 15, 20]
        for k, x in enumerate(xs):
            c = cols[k % len(cols)]
            fl = template(["..p..", ".ppp.", "ppcpp", ".ppp.", "..p.."], hx + x - 2, hy - 3, {'p': c, 'c': GOLD if c != GOLD else WHITE})
            L.art(fl, darken(c, 0.5))
    L.erase(masks['hands'] | masks['prop'])
    return L


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
    moving = g['pose'].get('moving', 0)
    aid = acc['id']
    if aid == 'scarf':
        c, sh = CREAM, CREAM_SH
        band = rect(x0 - 2, tt - 1, x1 + 2, tt + 3) & ~pix([(x0 - 2, tt - 1), (x1 + 2, tt - 1), (x0 - 2, tt + 3), (x1 + 2, tt + 3)])
        if d == 'down':
            tail = rect(x1 - 5, tt + 4, x1 - 2, tt + 9) & ~pix([(x1 - 5, tt + 9)])
        elif d == 'up':
            tail = rect(x0 + 3, tt + 4, x0 + 6, tt + 8) | rect(x0 + 7, tt + 4, x0 + 9, tt + 6)
        else:
            if moving:
                lift = moving
                tail = rect(x1 + 2, tt - lift, x1 + 6, tt + 2 - lift) | rect(x1 + 5, tt - lift - 2, x1 + 9, tt - lift)
            else:
                tail = rect(x1, tt + 3, x1 + 3, tt + 8)
        painted = L.part(band | tail, c, shade=sh, ring_color=darken(sh, 0.55))
        L.fill(pix([(x, tt + 1) for x in range(x0, x1 + 1, 3)]), sh)  # knit folds
        L.erase(painted & ~(band | tail) & masks['head'] & rect(0, 0, W - 1, tt - 2))
    elif aid == 'glasses':
        if d != 'up':
            ox, oy = head_origin(g)
            frame, lens = (70, 50, 40), (200, 230, 246)
            for c in ([7] if side else [9, 19]):
                x, y = ox + c, oy + 18
                ring = rect(x, y, x + 5, y + 6) & ~rect(x + 1, y + 1, x + 4, y + 5)
                L.fill(ring & ~pix([(x, y), (x + 5, y), (x, y + 6), (x + 5, y + 6)]), frame)
                L.fill(pix([(x + 4, y + 1), (x + 3, y + 2)]), lens)
            L.fill(rect(ox + 15, oy + 20, ox + 18, oy + 20) if not side else rect(ox + 13, oy + 20, ox + 18, oy + 20), frame)
    elif aid == 'satchel':
        leather, leather_sh, strap = (156, 98, 54), (112, 66, 36), (96, 58, 34)
        if d == 'down':
            L.fill(stamp(line_pts((x1, tt), (x0 + 1, hip - 4)), 2, 1), strap)
            bag = rect(x0 - 7, hip - 6, x0, hip + 1)
        elif d == 'up':
            L.fill(stamp(line_pts((x0, tt), (x1 - 1, hip - 4)), 2, 1), strap)
            bag = rect(x1, hip - 6, x1 + 7, hip + 1)
        else:
            L.fill(stamp(line_pts((x1 - 2, tt), (x0 + 2, hip - 4)), 2, 1), strap)
            bag = rect(x0 + 1, hip - 5, x0 + 8, hip + 2)
        L.part(bag, leather, shade=leather_sh, ring_color=darken(leather_sh, 0.5))
        bx0 = int(np.argwhere(bag.any(axis=0))[0][0])
        by0 = int(np.argwhere(bag.any(axis=1))[0][0])
        L.fill(rect(bx0, by0, bx0 + 7, by0 + 2), leather_sh)
        L.fill(pix([(bx0 + 3, by0 + 3), (bx0 + 4, by0 + 3)]), GOLD)
    elif aid == 'backpack':
        pack, pack_sh, strap = (60, 74, 150), (38, 46, 104), (150, 96, 54)
        star = template(STAR5, 0, 0, {'G': GOLD})
        if d == 'down':
            L.fill(rect(x0 + 2, tt + 1, x0 + 3, tt + 9) | rect(x1 - 3, tt + 1, x1 - 2, tt + 9), strap)
            L.part(rect(x0 - 3, tt - 1, x0 - 1, tt + 2) | rect(x1 + 1, tt - 1, x1 + 3, tt + 2), pack, ring_color=darken(pack_sh, 0.5))
        elif d == 'up':
            body = rect(x0 - 1, tt + 1, x1 + 1, hip - 1) & ~pix([(x0 - 1, tt + 1), (x1 + 1, tt + 1)])
            L.part(body, pack, shade=pack_sh, ring_color=darken(pack_sh, 0.5))
            L.part(rect(x0, tt + 1, x1, tt + 5), pack_sh, ring_color=darken(pack_sh, 0.5))
            cx = (x0 + x1) // 2
            L.art(template(STAR_BIG, cx - 3, tt + 7, {'G': GOLD, 'g': GOLD_SH, 'l': (255, 240, 180)}), darken(GOLD_SH, 0.5), ring=False)
            L.fill(rect(cx - 1, tt + 4, cx + 1, tt + 6), strap)
        else:
            body = rect(x1 + 1, tt + 1, x1 + 7, hip - 2) & ~pix([(x1 + 7, tt + 1), (x1 + 7, hip - 2)])
            L.part(body, pack, shade=pack_sh, ring_color=darken(pack_sh, 0.5))
            L.art(template(STAR5, x1 + 3, tt + 7, {'G': GOLD}), darken(GOLD_SH, 0.5), ring=False)
            L.fill(rect(x1 - 1, tt, x1, tt + 7), strap)
        del star
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
    """Rotate a standing frame onto its back: head on the left, feet right."""
    n = 80
    sq = np.zeros((n, n, 4), np.uint8)
    sq[:, 8:72] = a
    r = np.rot90(sq, k=1)
    out = np.zeros((H, W, 4), np.uint8)
    dx, dy = -15, 22
    for y in range(H):
        sy = y - dy
        if 0 <= sy < n:
            for_x = slice(max(0, dx), min(W, n + dx))
            out[y, for_x] = r[sy][for_x.start - dx:for_x.stop - dx]
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
