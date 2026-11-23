"""Key out walk-cycle pairs with one shared crop box per character, so the
two step frames line up and the sprite does not jitter while walking.

  python tool/pose_art/key_walk_pairs.py <generated_dir> assets/avatar/poses
"""
import sys
from pathlib import Path

from PIL import Image


def keyed(path):
    im = Image.open(path).convert('RGBA')
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            if (255 - r) ** 2 + g ** 2 + (255 - b) ** 2 < 60 ** 2 or (r > 180 and b > 180 and g < 90):
                px[x, y] = (0, 0, 0, 0)
    return im


def main():
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    for a in sorted(src.glob('walk_*_a.png')):
        b = a.with_name(a.name.replace('_a.png', '_b.png'))
        ia, ib = keyed(a), keyed(b)
        boxes = [ia.getbbox(), ib.getbbox()]
        box = (min(x[0] for x in boxes), min(x[1] for x in boxes),
               max(x[2] for x in boxes), max(x[3] for x in boxes))
        for im, name in ((ia, a.name), (ib, b.name)):
            c = im.crop(box)
            scale = 256 / c.height
            c = c.resize((max(1, round(c.width * scale)), 256), Image.NEAREST)
            c.save(out / name, optimize=True)
            print('wrote', out / name, c.size)


if __name__ == '__main__':
    main()
