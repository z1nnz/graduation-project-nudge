"""Turn Codex-generated cabin art into game-ready pixel layers.

Item images are generated on flat magenta (#FF00FF). This removes the
magenta, trims to the visible pixels and resizes with nearest-neighbour so
the pixel grid stays crisp.

  python -I tool/cabin_art/key_sprites.py <generated_dir> <assets/home> <spec.json>

spec.json maps output names to {"source": "...png", "width": int}; the base
room uses {"source": "room_base.png", "width": 720, "key": false}.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image


def key(src: Path, dst: Path, target_width: int, remove_magenta: bool = True) -> None:
    image = Image.open(src).convert("RGBA")
    if remove_magenta:
        pixels = image.load()
        width, height = image.size
        for y in range(height):
            for x in range(width):
                r, g, b, _ = pixels[x, y]
                # Distance to pure magenta; anti-aliased fringes are dropped too.
                if (255 - r) ** 2 + g ** 2 + (255 - b) ** 2 < 60 ** 2 or (
                    r > 180 and b > 180 and g < 90
                ):
                    pixels[x, y] = (0, 0, 0, 0)
        box = image.getbbox()
        if box:
            image = image.crop(box)
    ratio = target_width / image.width
    # Items keep a crisp pixel grid; the painted base room is smoothed.
    image = image.resize(
        (target_width, max(1, round(image.height * ratio))),
        Image.NEAREST if remove_magenta else Image.LANCZOS,
    )
    dst.parent.mkdir(parents=True, exist_ok=True)
    image.save(dst, optimize=True)


def main() -> None:
    source_dir, out_dir, spec_path = (Path(arg) for arg in sys.argv[1:4])
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    for name, item in spec.items():
        key(
            source_dir / item["source"],
            out_dir / name,
            int(item["width"]),
            remove_magenta=item.get("key", True),
        )
        print("wrote", out_dir / name)


if __name__ == "__main__":
    main()
