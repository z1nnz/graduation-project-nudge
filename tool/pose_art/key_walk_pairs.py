"""Key out walk-cycle frames (step a, step b and the passing frame p) so they
line up and the sprite does not jitter while walking.

Frames are generated separately, so instead of one shared crop box every
frame is aligned on two anchors: the feet (bottom of the visible pixels) and
the head (horizontal centre of the top third). All frames of one character
use one scale.

  python tool/pose_art/key_walk_pairs.py <generated_dir>... assets/avatar/poses

Each generated_dir is searched for walk_<face>_{a,b,p}.png.
"""
import sys
from pathlib import Path

from PIL import Image

HEIGHT = 256


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


def head_x(im):
    """Horizontal centre of the top third of the visible pixels."""
    left, top, right, bottom = im.getbbox()
    head = im.crop((left, top, right, top + (bottom - top) // 3)).getbbox()
    return left + (head[0] + head[2]) / 2


def main():
    *sources, out = (Path(a) for a in sys.argv[1:])
    found = {}
    for src in sources:
        for f in src.glob('walk_*_[abp].png'):
            found[f.name] = f
    faces = sorted({n.split('_')[1] for n in found}, key=int)
    for face in faces:
        names = [f'walk_{face}_{k}.png' for k in 'abp' if f'walk_{face}_{k}.png' in found]
        ims = {n: keyed(found[n]) for n in names}
        boxes = {n: im.getbbox() for n, im in ims.items()}
        heads = {n: head_x(im) for n, im in ims.items()}
        scale = HEIGHT / max(b[3] - b[1] for b in boxes.values())
        # Room left and right of the head anchor, shared by every frame.
        left = max(heads[n] - boxes[n][0] for n in names)
        right = max(boxes[n][2] - heads[n] for n in names)
        width = round((left + right) * scale)
        for n in names:
            box = boxes[n]
            part = ims[n].crop(box)
            part = part.resize(
                (max(1, round(part.width * scale)), max(1, round(part.height * scale))),
                Image.NEAREST,
            )
            canvas = Image.new('RGBA', (width, HEIGHT), (0, 0, 0, 0))
            x = round((left - (heads[n] - box[0])) * scale)
            canvas.paste(part, (x, HEIGHT - part.height), part)
            canvas.save(out / n, optimize=True)
            print('wrote', out / n, canvas.size)


if __name__ == '__main__':
    main()
