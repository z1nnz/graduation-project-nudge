"""Key the sky and window glass out of scene art (live sky layer shows through).

  python -I tool/world_art/key_sky.py [--preview <dir>]

For each job in sky_spec.json: inside [rect], pixels close to the colours
under [seeds] and connected to a seed become transparent; small holes
(painted stars, moon) inside the keyed area are keyed too. Writes the same WebP to
web_dashboard/assets/<out> and assets/<out>.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]


def key(job):
    im = Image.open(ROOT / job['src']).convert('RGBA')
    a = np.asarray(im).copy()
    h, w = a.shape[:2]
    x0, y0, x1, y1 = job['rect']
    box = np.zeros((h, w), bool)
    box[int(y0 * h):int(y1 * h), int(x0 * w):int(x1 * w)] = True
    rgb = a[..., :3].astype(np.int32)
    seeds = [(min(w - 1, int(sx * w)), min(h - 1, int(sy * h))) for sx, sy in job['seeds']]
    near = np.zeros((h, w), bool)
    tol = job.get('tol', 60) ** 2
    for sx, sy in seeds:
        patch = rgb[max(0, sy - 2):sy + 3, max(0, sx - 2):sx + 3].reshape(-1, 3)
        for c in patch[::3]:
            near |= ((rgb - c) ** 2).sum(-1) < tol
    near &= box
    lab, _ = ndimage.label(near)
    keep = {lab[sy, sx] for sx, sy in seeds if lab[sy, sx]}
    sky = np.isin(lab, list(keep))
    # Painted stars and moons inside the sky go too; window frames stay.
    holes = ndimage.binary_fill_holes(sky) & ~sky
    hl, n = ndimage.label(holes)
    if n:
        sizes = ndimage.sum(holes, hl, range(1, n + 1))
        small = np.isin(hl, [i + 1 for i, s in enumerate(sizes) if s <= job.get('hole', 160)])
        sky |= small
    a[sky, 3] = 0
    return Image.fromarray(a, 'RGBA'), sky.mean()


def main(argv):
    spec = json.loads((ROOT / 'tool/world_art/sky_spec.json').read_text(encoding='utf-8'))
    prev = Path(argv[argv.index('--preview') + 1]) if '--preview' in argv else None
    for job in spec['jobs']:
        im, share = key(job)
        for base in ('web_dashboard/assets', 'assets'):
            out = ROOT / base / job['out']
            out.parent.mkdir(parents=True, exist_ok=True)
            im.save(out, quality=job.get('quality', 80), method=6, alpha_quality=90)
        size = (ROOT / 'assets' / job['out']).stat().st_size
        print(f"{job['out']}: {share:.1%} keyed, {size // 1024} KB")
        assert size < 300 * 1024, job['out']
        if prev:
            prev.mkdir(parents=True, exist_ok=True)
            bg = Image.new('RGBA', im.size, (255, 0, 255, 255))
            bg.alpha_composite(im)
            bg.convert('RGB').resize((im.width // 3, im.height // 3)).save(prev / (Path(job['out']).stem + '.png'))


if __name__ == '__main__':
    main(sys.argv[1:])
