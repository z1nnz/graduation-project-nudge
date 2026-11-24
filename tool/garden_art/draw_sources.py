"""Draw the starlight garden pixel art on flat magenta.

Growth strips (5 frames of 48x64) and the garden plot background are drawn
at their native pixel size in the town palette, then go through the shared
key step so they match every other sprite:

  python -I tool/garden_art/draw_sources.py <out_dir>
  python -I tool/cabin_art/key_sprites.py <out_dir> web_dashboard/assets/garden tool/garden_art/spec.json

The background is drawn at 320x180 and scaled 4x (nearest) to 1280x720.
Its soil plot spans native y 42–178 so four rows of plants fit on it.
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from PIL import Image

MAGENTA = (255, 0, 255, 255)
OUTLINE = (58, 34, 22, 255)      # --w-wood-deep
SOIL = (90, 56, 38, 255)          # --w-wood-dark
SOIL_HI = (138, 90, 52, 255)      # --w-wood
SOIL_LO = (70, 42, 28, 255)
GREEN = (76, 138, 58, 255)        # --w-green
GREEN_HI = (124, 186, 82, 255)
GREEN_LO = (47, 94, 42, 255)
VIOLET = (139, 108, 240, 255)     # --w-violet
VIOLET_HI = (184, 162, 255, 255)
VIOLET_LO = (75, 47, 168, 255)    # --w-violet-deep
GOLD = (255, 197, 77, 255)        # --w-gold
GOLD_HI = (255, 230, 163, 255)
GOLD_LO = (196, 113, 11, 255)     # --w-gold-deep
PARCH = (246, 231, 200, 255)      # --w-parchment
PARCH_HI = (255, 250, 240, 255)
BARK = (138, 90, 52, 255)
BARK_LO = (90, 56, 38, 255)
RED = (216, 69, 46, 255)

FW, FH = 48, 64


class Sprite:
    """A small canvas whose filled pixels get an automatic dark outline."""

    def __init__(self, w: int = FW, h: int = FH) -> None:
        self.w, self.h = w, h
        self.px: dict[tuple[int, int], tuple] = {}

    def set(self, x: int, y: int, c) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[(x, y)] = c

    def rect(self, x0, y0, x1, y1, c) -> None:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def disc(self, cx, cy, r, c, shade=None, hi=None) -> None:
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                dx, dy = x - cx, y - cy
                if dx * dx + dy * dy <= r * r + 0.5:
                    col = c
                    if shade and dx + dy > r * 0.45:
                        col = shade
                    if hi and dx + dy < -r * 0.75:
                        col = hi
                    self.set(x, y, col)

    def ellipse(self, cx, cy, rx, ry, c, shade=None) -> None:
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.set(x, y, shade if shade and y > cy + ry * 0.35 else c)

    def line(self, x0, y0, x1, y1, c, w: int = 1) -> None:
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(steps + 1):
            x = round(x0 + (x1 - x0) * i / steps)
            y = round(y0 + (y1 - y0) * i / steps)
            for k in range(w):
                self.set(x + k, y, c)

    def outlined(self) -> Image.Image:
        img = Image.new("RGBA", (self.w, self.h), MAGENTA)
        for (x, y), c in self.px.items():
            img.putpixel((x, y), c)
        for (x, y) in list(self.px):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < self.w and 0 <= ny < self.h and (nx, ny) not in self.px:
                    img.putpixel((nx, ny), OUTLINE)
        return img


def soil(s: Sprite) -> None:
    # Mound across the whole frame so every frame keeps the same footprint.
    s.ellipse(24, 60, 23, 5, SOIL, SOIL_LO)
    s.rect(1, 60, 46, 63, SOIL)
    s.rect(1, 62, 46, 63, SOIL_LO)
    for x in (8, 19, 31, 40):
        s.set(x, 58, SOIL_HI)
        s.set(x + 1, 58, SOIL_HI)


def leaf(s: Sprite, x, y, direction, size=3, c=GREEN, hi=GREEN_HI) -> None:
    for i in range(size + 2):
        for j in range(-(size - abs(i - size // 2 - 1)) // 2, (size - abs(i - size // 2 - 1)) // 2 + 1):
            s.set(x + direction * i, y + j - i // 2, c)
    s.set(x + direction * (size // 2 + 1), y - size // 3 - 1, hi)


def stem(s: Sprite, x, top, bottom=57, c=GREEN, w=2) -> None:
    for y in range(top, bottom + 1):
        sway = round(math.sin((bottom - y) / 9.0))
        s.rect(x + sway, y, x + sway + w - 1, y, c)


def sprout(s: Sprite, x=23, top=50, c=GREEN) -> None:
    stem(s, x, top, c=c)
    leaf(s, x - 1, top + 1, -1, 3)
    leaf(s, x + 2, top + 1, 1, 3)


def flower_head(s, cx, cy, r, petal, petal_hi, petal_lo, centre, centre_hi) -> None:
    for k in range(5):
        a = -math.pi / 2 + k * 2 * math.pi / 5
        s.disc(cx + math.cos(a) * r * 0.95, cy + math.sin(a) * r * 0.95, r * 0.62, petal, petal_lo, petal_hi)
    s.disc(cx, cy, max(1.5, r * 0.45), centre, None, centre_hi)


def seed(s: Sprite, c=SOIL_HI) -> None:
    s.ellipse(24, 55, 4, 2, c)
    s.set(23, 54, GOLD_HI)


def flower_frames(petal, petal_hi, petal_lo, centre, centre_hi, sparkle):
    frames = []
    # 1 seed with first leaf.
    s = Sprite(); soil(s); seed(s); s.rect(24, 50, 24, 53, GREEN); leaf(s, 25, 51, 1, 2); frames.append(s)
    # 2 sprout.
    s = Sprite(); soil(s); sprout(s, 23, 43); frames.append(s)
    # 3 bud.
    s = Sprite(); soil(s); stem(s, 23, 30); leaf(s, 22, 46, -1, 4); leaf(s, 25, 40, 1, 4)
    s.ellipse(24, 28, 3, 4, petal, petal_lo); s.rect(23, 31, 25, 32, GREEN); frames.append(s)
    # 4 first bloom.
    s = Sprite(); soil(s); stem(s, 23, 26); leaf(s, 22, 46, -1, 5); leaf(s, 25, 38, 1, 5)
    flower_head(s, 24, 20, 6, petal, petal_hi, petal_lo, centre, centre_hi); frames.append(s)
    # 5 full bloom with a second flower and sparkles.
    s = Sprite(); soil(s); stem(s, 22, 22); stem(s, 33, 38, c=GREEN_LO)
    leaf(s, 21, 47, -1, 6); leaf(s, 24, 36, 1, 5); leaf(s, 33, 48, 1, 3)
    flower_head(s, 23, 15, 9, petal, petal_hi, petal_lo, centre, centre_hi)
    flower_head(s, 35, 34, 4, petal, petal_hi, petal_lo, centre, centre_hi)
    for x, y in ((8, 10), (40, 8), (6, 30)):
        s.set(x, y, sparkle); s.set(x - 1, y, sparkle); s.set(x + 1, y, sparkle); s.set(x, y - 1, sparkle); s.set(x, y + 1, sparkle)
    frames.append(s)
    return frames


def tree_frames():
    frames = []
    s = Sprite(); soil(s); seed(s, BARK); s.rect(24, 50, 24, 53, GREEN); leaf(s, 25, 50, 1, 2); frames.append(s)
    s = Sprite(); soil(s); stem(s, 23, 42, c=BARK); leaf(s, 22, 44, -1, 4); leaf(s, 25, 42, 1, 4); leaf(s, 23, 40, 1, 2); frames.append(s)
    # 3 sapling.
    s = Sprite(); soil(s); s.rect(22, 34, 25, 57, BARK); s.rect(24, 34, 25, 57, BARK_LO)
    s.disc(24, 28, 9, GREEN, GREEN_LO, GREEN_HI); frames.append(s)
    # 4 young tree.
    s = Sprite(); soil(s); s.rect(21, 30, 26, 57, BARK); s.rect(24, 30, 26, 57, BARK_LO)
    s.line(25, 38, 31, 33, BARK, 2)
    s.disc(18, 24, 9, GREEN, GREEN_LO, GREEN_HI); s.disc(30, 24, 9, GREEN, GREEN_LO, GREEN_HI)
    s.disc(24, 15, 10, GREEN, GREEN_LO, GREEN_HI); frames.append(s)
    # 5 grown oak with golden acorns; reaches the top row.
    s = Sprite(); soil(s); s.rect(20, 32, 27, 57, BARK); s.rect(24, 32, 27, 57, BARK_LO)
    s.rect(18, 55, 29, 57, BARK)
    s.disc(12, 26, 10, GREEN, GREEN_LO, GREEN_HI); s.disc(36, 26, 10, GREEN, GREEN_LO, GREEN_HI)
    s.disc(17, 14, 11, GREEN, GREEN_LO, GREEN_HI); s.disc(31, 14, 11, GREEN, GREEN_LO, GREEN_HI)
    s.disc(24, 11, 10, GREEN, GREEN_LO, GREEN_HI)
    for x, y in ((14, 24), (33, 20), (24, 30), (20, 9)):
        s.disc(x, y, 1.6, GOLD, GOLD_LO, GOLD_HI)
    frames.append(s)
    return frames


def meadow_frames():
    rng = random.Random(7)
    frames = []
    counts = (3, 7, 12, 18, 24)
    for stage, n in enumerate(counts, start=1):
        s = Sprite(); soil(s)
        spread = 6 + stage * 4
        for _ in range(n):
            x = 24 + rng.randint(-spread, spread)
            h = rng.randint(4, 6 + stage * 3)
            lean = rng.choice((-1, 0, 1))
            col = rng.choice((GREEN, GREEN, GREEN_HI, GREEN_LO))
            s.line(x, 57, x + lean * 2, 57 - h, col)
            s.set(x + 1, 57, col)
        if stage >= 4:
            for _ in range(stage - 2):
                x = 24 + rng.randint(-spread + 2, spread - 2)
                y = 57 - rng.randint(8, 10 + stage * 2)
                s.line(x, y + 1, x, 57, GREEN_LO)
                c = rng.choice((GOLD, PARCH_HI, VIOLET_HI))
                for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, -1), (0, 1)):
                    s.set(x + dx, y + dy, c)
                s.set(x, y, GOLD_LO if c != GOLD else RED)
        if stage == 5:  # a tiny butterfly and a firefly high above.
            for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, -1), (0, 1)):
                s.set(10 + dx, 2 + dy, GOLD_HI)
            for dx, dy in ((0, 0), (-1, -1), (1, -1), (-1, 1), (1, 1)):
                s.set(36 + dx, 22 + dy, VIOLET)
            s.set(36, 22, OUTLINE)
        frames.append(s)
    return frames


def strip(frames) -> Image.Image:
    img = Image.new("RGBA", (FW * len(frames), FH), MAGENTA)
    for i, fr in enumerate(frames):
        img.paste(fr.outlined(), (i * FW, 0))
    return img


def background() -> Image.Image:
    W, H = 320, 180
    img = Image.new("RGBA", (W, H), MAGENTA)
    p = img.load()
    sky = [(74, 42, 94), (88, 50, 104), (110, 62, 112), (140, 80, 112), (176, 104, 106), (214, 140, 98)]
    for y in range(0, 30):
        band = sky[min(len(sky) - 1, y * len(sky) // 30)]
        for x in range(W):
            p[x, y] = band
    rng = random.Random(3)
    for _ in range(26):
        x, y = rng.randrange(W), rng.randrange(0, 16)
        p[x, y] = GOLD_HI
    # Far hedge.
    for x in range(W):
        top = 24 + round(3 * math.sin(x / 11) + 2 * math.sin(x / 5.3))
        for y in range(top, 38):
            p[x, y] = GREEN_LO if y > top + 1 else OUTLINE
    # Grass field.
    for y in range(38, H):
        for x in range(W):
            p[x, y] = GREEN if (x * 7 + y * 13) % 23 else GREEN_HI
    for _ in range(420):
        x, y = rng.randrange(W), rng.randrange(40, H)
        p[x, y] = GREEN_LO
    # Wooden fence along the back.
    for y in (30, 31, 35, 36):
        for x in range(W):
            p[x, y] = BARK if y in (30, 35) else BARK_LO
    for x in range(4, W, 18):
        for y in range(26, 41):
            for dx in range(4):
                p[x + dx, y] = BARK if dx < 2 else BARK_LO
        for dx in range(4):
            p[x + dx, 25] = OUTLINE
            p[x + dx, 41] = OUTLINE
        for y in range(25, 42):
            p[x - 1, y] = OUTLINE
            p[x + 4, y] = OUTLINE
    # Soil plot in the middle with a wooden border.
    x0, y0, x1, y1 = 26, 42, 294, 178
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            edge = x in (x0, x1) or y in (y0, y1)
            border = x in (x0 + 1, x0 + 2, x1 - 1, x1 - 2) or y in (y0 + 1, y0 + 2, y1 - 1, y1 - 2)
            if edge:
                p[x, y] = OUTLINE
            elif border:
                p[x, y] = BARK if y != y1 - 1 else BARK_LO
            else:
                p[x, y] = SOIL if (x + y * 3) % 17 else SOIL_LO
    for _ in range(160):
        x, y = rng.randint(x0 + 4, x1 - 4), rng.randint(y0 + 4, y1 - 4)
        p[x, y] = SOIL_HI
    # Stepping stones from the bottom-left corner to the gate.
    for i, (cx, cy) in enumerate(((10, 172), (15, 158), (9, 144), (14, 130), (9, 116), (14, 102), (9, 88), (14, 74), (9, 60), (13, 47))):
        rx, ry = 5 - i % 2, 3
        for y in range(cy - ry - 1, cy + ry + 2):
            for x in range(cx - rx - 1, cx + rx + 2):
                d = ((x - cx) / (rx + 1)) ** 2 + ((y - cy) / (ry + 1)) ** 2
                if 0 <= x < W and 0 <= y < H:
                    if d <= 0.6:
                        p[x, y] = PARCH if y < cy else (190, 170, 140)
                    elif d <= 1.0:
                        p[x, y] = OUTLINE
    # Two lanterns at the plot's back corners.
    for lx in (20, 300):
        for y in range(30, 44):
            p[lx, y] = OUTLINE
            p[lx + 1, y] = BARK_LO
        for y in range(24, 31):
            for x in range(lx - 2, lx + 4):
                p[x, y] = GOLD if 25 <= y <= 29 and lx - 1 <= x <= lx + 2 else OUTLINE
        p[lx, 26] = GOLD_HI
    return img.resize((W * 4, H * 4), Image.NEAREST)


def main() -> None:
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    strip(flower_frames(VIOLET, VIOLET_HI, VIOLET_LO, GOLD, GOLD_HI, GOLD)).save(out / "flower_src.png")
    strip(tree_frames()).save(out / "tree_src.png")
    strip(flower_frames(PARCH_HI, PARCH_HI, VIOLET_HI, VIOLET_LO, VIOLET, GOLD_HI)).save(out / "moonflower_src.png")
    strip(meadow_frames()).save(out / "meadow_src.png")
    background().save(out / "garden_plot_bg_src.png")
    print("wrote sources to", out)


if __name__ == "__main__":
    main()
