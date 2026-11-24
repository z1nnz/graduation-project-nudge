#!/usr/bin/env python3
"""Build fixed-size nearest-neighbor copies of existing character art."""
import argparse
from pathlib import Path
from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--indices', nargs='+', type=int, default=[i for i in range(18) if i != 11])
    # Character 11 is a dynamic avatar without a bundled static PNG.
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = root / 'web_dashboard/assets/growth/characters'
    output.mkdir(parents=True, exist_ok=True)
    for index in args.indices:
        if not 0 <= index < 18:
            parser.error('Character indices must be between 0 and 17')
        source = root / f'web_dashboard/assets/avatar/characters/character_{index}.png'
        with Image.open(source) as image:
            width, height = image.size
            if width % 128 or height % 192 or width // 128 != height // 192:
                raise ValueError(f'{source}: expected an integer multiple of 128x192')
            image.convert('RGBA').resize((128, 192), Image.Resampling.NEAREST).save(
                output / source.name)


if __name__ == '__main__':
    main()
