#!/usr/bin/env python3
"""Builds the app icon from the game's own sprites: a brick kiln on grass,
with a belt of bricks running past, under a warm paper sky.

Writes App/Groundwork/Assets.xcassets/AppIcon.appiconset (one 1024x1024 PNG,
which Xcode scales for every size). Run after `python3 Tools/make_art.py`.
Standard library only.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import make_art  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SIZE = 64           # pixel-art canvas
SCALE = 16          # 64 x 16 = 1024
OUT = ROOT / "App/Groundwork/Assets.xcassets"


def main():
    manifest = json.loads((ROOT / "Art/generated/atlas.json").read_text())
    _, _, atlas = make_art.read_png(ROOT / "Art/generated/atlas.png")
    sprites = manifest["sprites"]
    palette = json.loads((ROOT / "Art/palette.json").read_text())["colors"]
    paper = make_art.hex_rgba(palette["F"])
    gold = make_art.hex_rgba(palette["D"])
    glow = make_art.hex_rgba(palette["w"])

    canvas = [[paper for _ in range(SIZE)] for _ in range(SIZE)]
    # A low sun behind the kiln's chimney.
    for y in range(SIZE):
        for x in range(SIZE):
            d = (x - 46) ** 2 + (y - 12) ** 2
            if d <= 36:
                canvas[y][x] = gold
            elif d <= 64:
                canvas[y][x] = glow

    def stamp(name, left, top):
        r = sprites[name]
        for dy in range(r["h"]):
            for dx in range(r["w"]):
                px = atlas[r["y"] + dy][r["x"] + dx]
                if px[3] > 0 and 0 <= top + dy < SIZE and 0 <= left + dx < SIZE:
                    canvas[top + dy][left + dx] = px

    for top in (40, 56):
        for left in range(0, SIZE, 16):
            stamp("terrain_grass_1", left, top)
    stamp("brick_kiln", 16, 14)
    for left in range(0, SIZE, 16):
        stamp("belt_h", left, 44)
    for left in (6, 22, 38, 54):
        stamp("item_brick", left, 48)

    rows = [[px for px in row for _ in range(SCALE)] for row in canvas for _ in range(SCALE)]
    icon_dir = OUT / "AppIcon.appiconset"
    icon_dir.mkdir(parents=True, exist_ok=True)
    make_art.write_png(icon_dir / "icon_1024.png", SIZE * SCALE, SIZE * SCALE,
                       [[(r, g, b, 255) for (r, g, b, _) in row] for row in rows])
    (icon_dir / "Contents.json").write_text(json.dumps({
        "images": [{"filename": "icon_1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")
    (OUT / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    print(f"wrote {icon_dir / 'icon_1024.png'}")


if __name__ == "__main__":
    main()
