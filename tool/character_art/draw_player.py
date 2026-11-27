"""Pixel-art helpers shared by the drawing scripts in tool/.

Masks (rect, pix, stamp, template, shift, dilate), a Layer that fills,
shades and outlines shapes in one step, and the town palette. Scripts set
W and H for their canvas before drawing:

  import draw_player as dp
  dp.W, dp.H = 32, 32
  L = dp.Layer()

The player character itself is built from the earlier companion art by
recolor_player.py.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
W, H = 64, 80

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
