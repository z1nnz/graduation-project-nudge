"""Rebuild Web demo PNGs from the unchanged firmware painter.
Requires C++17, Pillow, and the firmware's installed classic 5x7 font:
  python tool/virtual_device/generate.py --font <Seeed_GFX/Fonts/glcdfont.c>
The output is a host rendering, not evidence of a physical display test.
"""
import argparse
import json
import re
import subprocess
import tempfile
from pathlib import Path
from PIL import Image, ImageDraw

repo = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--font', required=True, type=Path)
args = parser.parse_args()
raw = args.font.read_text()
# The installed classic font is five vertical bit columns per ASCII glyph.
body = raw.split('{', 1)[1].split('}', 1)[0]
body = re.sub(r'//[^\n]*|/\*.*?\*/', '', body, flags=re.S)
font = [int(v, 16) for v in re.findall(r'0x[0-9a-fA-F]+', body)]
if len(font) < 128 * 5:
    raise ValueError('Incomplete classic firmware font')
firmware = repo / 'firmware/nudge_competition_demo'
out = repo / 'web_dashboard/assets/virtual-device'
out.mkdir(parents=True, exist_ok=True)

def rgb(value):
    return ((value >> 11) * 255 // 31, ((value >> 5) & 63) * 255 // 63, (value & 31) * 255 // 31)

with tempfile.TemporaryDirectory(prefix='nudge-virtual-render-') as temp:
    build = Path(temp)
    subprocess.run(['c++', '-std=c++17', '-Wall', '-Wextra', '-Werror', '-I'+str(firmware/'include'),
                    str(repo/'tool/virtual_device/export_frames.cpp'), *[str(firmware/'src'/f) for f in ['core.cpp', 'drawing.cpp', 'station.cpp', 'character.cpp']], '-o', str(build/'export')], check=True)
    subprocess.run([str(build/'export'), str(build)], check=True)
    for file in sorted(build.glob('*.json')):
        image = Image.new('RGB', (240, 320 if file.name.startswith('station') else 240))
        draw = ImageDraw.Draw(image)
        for command in json.loads(file.read_text()):
            op, *data = command
            if op == 'rect':
                x, y, w, h, c = data
                if w > 0 and h > 0: draw.rectangle((x,y,x+w-1,y+h-1), fill=rgb(c))
            elif op == 'line':
                x,y,x2,y2,c=data;draw.line((x,y,x2,y2),fill=rgb(c))
            elif op == 'circle':
                x,y,r,c=data;draw.ellipse((x-r,y-r,x+r,y+r),fill=rgb(c))
            elif op == 'text':
                x,y,text,size,c=data
                for i,ch in enumerate(text):
                    code=ord(ch)
                    if code >= 128: raise ValueError('Unexpected non-bitmap text')
                    for col in range(5):
                        bits=font[code*5+col]
                        for row in range(8):
                            if bits & (1 << row):
                                a=x+(i*6+col)*size;b=y+row*size
                                draw.rectangle((a,b,a+size-1,b+size-1),fill=rgb(c))
        image.save(out/(file.stem+'.png'), optimize=True)
print('Exported 50 native-size firmware scene PNGs')
