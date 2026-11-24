"""Cut generated animation strips into 128x128 frames and pack the sheets.

  python -I tool/character_art/build_sheets.py <gen_dir> [--preview <dir>]

<gen_dir>/<id>/<animation>.png are strips generated from prompts.json on
flat magenta. For each character this keys out the magenta, finds the
frames along the strip, scales every frame of the character by one factor,
stands them on one baseline, centres them on the head, mirrors walk_left
into walk_right and writes assets/characters/<id>/sheet.webp plus the same
file under web_dashboard/. reference.png is kept, keyed, in
tool/character_art/reference/ for the next round of generation.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
CELL = 128
BASELINE = 124  # feet stand on this row of the cell
STAND_HEIGHT = 112  # tallest standing frame of a character
MIN_FRAME_SHARE = 0.25  # a blob narrower than this share of the median is a stray bit


def keyed(path: Path) -> Image.Image:
    a = np.asarray(Image.open(path).convert("RGBA")).astype(np.int32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    # Same rule as tool/cabin_art/key_sprites.py, fringes included.
    magenta = ((255 - r) ** 2 + g ** 2 + (255 - b) ** 2 < 60 ** 2) | ((r > 180) & (b > 180) & (g < 90))
    a[..., 3] = np.where(magenta, 0, a[..., 3])
    # Pink halo left by anti-aliasing: half-magenta pixels next to the key.
    halo = (r - g > 90) & (b - g > 90) & (a[..., 3] > 0)
    a[..., 3] = np.where(halo, 0, a[..., 3])
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def runs(mask: np.ndarray, gap: int) -> list[tuple[int, int]]:
    """Index ranges where mask is set, joining holes up to [gap] long."""
    out: list[list[int]] = []
    for i in np.flatnonzero(mask):
        if out and i - out[-1][1] <= gap:
            out[-1][1] = i
        else:
            out.append([i, i])
    return [(s, e + 1) for s, e in out]


def split_frames(im: Image.Image, count: int) -> list[Image.Image]:
    alpha = np.asarray(im)[..., 3] > 0
    cols = alpha.sum(axis=0) > 2
    gap = max(2, im.width // 200)
    spans = runs(cols, gap)
    widths = [e - s for s, e in spans]
    if spans:
        med = float(np.median(widths))
        spans = [sp for sp, w in zip(spans, widths) if w >= med * MIN_FRAME_SHARE]
    # Too many blobs (a prop floating beside a body): merge the closest pair.
    while len(spans) > count:
        gaps = [spans[i + 1][0] - spans[i][1] for i in range(len(spans) - 1)]
        i = int(np.argmin(gaps))
        spans[i:i + 2] = [(spans[i][0], spans[i + 1][1])]
    if len(spans) < count:
        # Frames touch: split the visible area into equal columns.
        left, _, right, _ = im.getbbox()
        step = (right - left) / count
        spans = [(round(left + k * step), round(left + (k + 1) * step)) for k in range(count)]
    frames = []
    for s, e in spans:
        part = im.crop((s, 0, e, im.height))
        box = part.getbbox()
        frames.append(part.crop(box) if box else part)
    return frames


def head_x(im: Image.Image) -> float:
    a = np.asarray(im)[..., 3] > 0
    top = a[: max(1, a.shape[0] // 3)]
    xs = np.flatnonzero(top.any(axis=0))
    return (xs[0] + xs[-1] + 1) / 2 if len(xs) else im.width / 2


def scaled(im: Image.Image, factor: float) -> Image.Image:
    w, h = max(1, round(im.width * factor)), max(1, round(im.height * factor))
    small = im.resize((w, h), Image.BOX)
    a = np.asarray(small).copy()
    a[..., 3] = np.where(a[..., 3] >= 128, 255, 0)  # hard pixel edges
    return Image.fromarray(a, "RGBA")


def place(frame: Image.Image, factor: float, centre_on_head: bool) -> Image.Image:
    f = scaled(frame, factor)
    if f.width > CELL - 2 or f.height > BASELINE:
        f = scaled(frame, factor * min((CELL - 2) / f.width, BASELINE / f.height))
    cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    cx = head_x(f) if centre_on_head else f.width / 2
    x = round(CELL / 2 - cx)
    x = min(max(x, 1), CELL - 1 - f.width)
    cell.alpha_composite(f, (x, BASELINE - f.height))
    return cell


def build(gen: Path, catalog: dict, preview: Path | None) -> None:
    for char in catalog["characters"]:
        cid = char["id"]
        rows = catalog["layouts"][char["layout"]]
        columns = max(r["frames"] for r in rows)
        strips: dict[str, list[Image.Image]] = {}
        for row in rows:
            name = row["name"]
            if name == "walk_right":
                continue
            src = gen / cid / f"{name}.png"
            if not src.exists():
                raise SystemExit(f"missing {src}")
            strips[name] = split_frames(keyed(src), row["frames"])
        strips["walk_right"] = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in strips["walk_left"]]

        standing = [f.height for n, fs in strips.items() if n != "sleep" for f in fs]
        factor = STAND_HEIGHT / max(standing)
        sheet = Image.new("RGBA", (columns * CELL, len(rows) * CELL), (0, 0, 0, 0))
        for r, row in enumerate(rows):
            for c, frame in enumerate(strips[row["name"]]):
                sheet.alpha_composite(place(frame, factor, row["name"].startswith("walk")), (c * CELL, r * CELL))

        for base in (ROOT / "assets/characters", ROOT / "web_dashboard/assets/characters"):
            out = base / cid / "sheet.webp"
            out.parent.mkdir(parents=True, exist_ok=True)
            sheet.save(out, lossless=True, method=6)
        ref = gen / cid / "reference.png"
        if ref.exists():
            r_im = keyed(ref)
            r_im = r_im.crop(r_im.getbbox())
            r_im = scaled(r_im, min(1.0, 512 / r_im.width))
            dst = ROOT / "tool/character_art/reference" / f"{cid}.webp"
            dst.parent.mkdir(parents=True, exist_ok=True)
            r_im.save(dst, lossless=True, method=6)
        size = (ROOT / "assets/characters" / cid / "sheet.webp").stat().st_size
        print(f"{cid}: {sheet.size[0]}x{sheet.size[1]} {size // 1024} KB")
        if preview:
            write_preview(sheet, rows, preview / f"{cid}.gif")


def write_preview(sheet: Image.Image, rows: list[dict], out: Path) -> None:
    """Every animation of one character side by side, 2x, on parchment."""
    out.parent.mkdir(parents=True, exist_ok=True)
    frames = []
    steps = 24
    for t in range(steps):
        canvas = Image.new("RGBA", (len(rows) * CELL, CELL), (246, 231, 200, 255))
        for r, row in enumerate(rows):
            k = (t * row["fps"] // 8) % row["frames"]
            canvas.alpha_composite(sheet.crop((k * CELL, r * CELL, (k + 1) * CELL, (r + 1) * CELL)), (r * CELL, 0))
        frames.append(canvas.resize((canvas.width * 2, CELL * 2), Image.NEAREST).convert("P", palette=Image.ADAPTIVE))
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=125, loop=0, disposal=2)


def main() -> None:
    args = sys.argv[1:]
    if not args:
        raise SystemExit(__doc__)
    preview = None
    if "--preview" in args:
        i = args.index("--preview")
        preview = Path(args[i + 1])
        del args[i:i + 2]
    catalog = json.loads((ROOT / "assets/characters/characters.json").read_text(encoding="utf-8"))
    build(Path(args[0]), catalog, preview)


if __name__ == "__main__":
    main()
