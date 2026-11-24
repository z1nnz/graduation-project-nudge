"""Create WebP companions for town art while keeping original image fallbacks."""

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "web_dashboard" / "assets"
FILES = [ROOT / "town" / "town_map.jpg", ROOT / "town" / "guide.png"]
FILES += sorted((ROOT / "avatar" / "characters").glob("character_*.png"))
FILES += sorted((ROOT / "avatar" / "poses").glob("walk_*.png"))

for source in FILES:
    with Image.open(source) as image:
        destination = source.with_suffix(".webp")
        if source.suffix == ".jpg":
            image.save(destination, "WEBP", quality=82, method=6)
        else:
            image.save(destination, "WEBP", lossless=True, method=6)
        print(f"{destination.relative_to(ROOT)}: {destination.stat().st_size} bytes")
