#!/usr/bin/env python3
"""Builds Groundwork's sprite atlas from the text grids in Art/sprites.

Checks every sprite (palette, size, building variants), adds generated
versions (building variants with a seeded flaw pixel, night versions with lit
windows, belt animation frames), packs one atlas, writes a manifest the game
loads, and renders a 4x contact sheet for review.

A hand-edited PNG at Art/manual/<name>.png always replaces the generated one
of the same name, and this script never writes into Art/manual.

Usage: python3 Tools/make_art.py          # check and build
       python3 Tools/make_art.py --check  # check only
Exits with status 1 and a list of problems if anything is wrong.

Python 3 standard library only.
"""
import json
import random
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "Art"
SPRITES = ART / "sprites"
MANUAL = ART / "manual"
OUT = ART / "generated"
TILE = 16
ATLAS_WIDTH = 1024
PADDING = 2


# ---------------------------------------------------------------- PNG

def write_png(path, width, height, rgba_rows):
    """rgba_rows: list of rows, each a list of (r, g, b, a) tuples."""
    raw = b"".join(b"\x00" + bytes(v for px in row for v in px) for row in rgba_rows)
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path.write_bytes(png)


def read_png(path):
    """Reads an 8-bit RGB or RGBA, non-interlaced PNG. Returns (w, h, rows of RGBA tuples)."""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    pos, idat, header = 8, b"", None
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            idat += body
        pos += 12 + length
    w, h, depth, colour, _, _, interlace = header
    if depth != 8 or colour not in (2, 6) or interlace:
        raise ValueError("only 8-bit RGB/RGBA non-interlaced PNGs are supported")
    channels = 4 if colour == 6 else 3
    raw = zlib.decompress(idat)
    stride = w * channels
    rows, prev = [], bytearray(stride)
    for y in range(h):
        kind = raw[y * (stride + 1)]
        line = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = line[i - channels] if i >= channels else 0
            b = prev[i]
            c = prev[i - channels] if i >= channels else 0
            if kind == 1: line[i] = (line[i] + a) & 0xFF
            elif kind == 2: line[i] = (line[i] + b) & 0xFF
            elif kind == 3: line[i] = (line[i] + (a + b) // 2) & 0xFF
            elif kind == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 0xFF
        prev = line
        rows.append([tuple(line[x * channels:x * channels + channels]) + (() if channels == 4 else (255,))
                     for x in range(w)])
    return w, h, rows


# ---------------------------------------------------------------- palette and sprites

def hex_rgba(value):
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), 255)


def load_palette(problems):
    palette = json.loads((ART / "palette.json").read_text())
    colours = palette["colors"]
    clear = palette.get("transparent", ".")
    if len(colours) != 32:
        problems.append(f"palette.json must have exactly 32 colours, found {len(colours)}")
    for key in colours:
        if len(key) != 1 or key == clear:
            problems.append(f"palette key '{key}' must be one character and not '{clear}'")
    for name, ramp in palette["materials"].items():
        if len(ramp) > 4:
            problems.append(f"material '{name}' has {len(ramp)} shades; at most 4 allowed")
        for key in ramp:
            if key not in colours:
                problems.append(f"material '{name}' uses unknown colour '{key}'")
    return palette


def building_for(name, buildings):
    """The building a sprite belongs to: its name, or the longest building id it
    starts with (foundation_2, cottage_scaffold)."""
    parts = name.split("_")
    for n in range(len(parts), 0, -1):
        prefix = "_".join(parts[:n])
        if prefix in buildings:
            return prefix
    return None


def expected_size(name, buildings):
    owner = building_for(name, buildings)
    if owner:
        w, h = buildings[owner]["size"]
        return (w * TILE, h * TILE)
    if name.startswith(("item_", "fx_smoke_")):
        return (8, 8)
    if name.startswith(("person_",)):
        return (8, 12)
    if name.startswith(("car_",)):
        return (8, 14)
    return (TILE, TILE)


def parse_sprite(path, problems):
    text = path.read_text()
    if "\n---\n" not in text:
        problems.append(f"{path.name}: missing the '---' line between header and pixels")
        return None
    head, body = text.split("\n---\n", 1)
    header = {}
    for line in head.splitlines():
        if line.strip() and not line.startswith("#"):
            key, _, value = line.partition(":")
            header[key.strip()] = value.strip()
    grid = [line for line in body.splitlines() if line != ""]
    return {"name": path.stem, "header": header, "grid": grid}


def check_sprite(sprite, palette, buildings, problems):
    name, grid, header = sprite["name"], sprite["grid"], sprite["header"]
    clear = palette.get("transparent", ".")
    w, h = expected_size(name, buildings)
    declared = header.get("size")
    if declared != f"{w}x{h}":
        problems.append(f"{name}: header says size {declared}, expected {w}x{h}")
    if len(grid) != h or any(len(row) != w for row in grid):
        widths = sorted({len(row) for row in grid})
        problems.append(f"{name}: grid is {widths}x{len(grid)}, expected {w}x{h}")
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch != clear and ch not in palette["colors"]:
                problems.append(f"{name}: off-palette pixel '{ch}' at ({x}, {y})")
    if name in buildings and variant_count(header) < 2:
        problems.append(f"{name}: buildings need 2 to 3 variants (add 'variants: 3' to the header)")


def to_rgba(grid, palette):
    clear = palette.get("transparent", ".")
    return [[(0, 0, 0, 0) if ch == clear else hex_rgba(palette["colors"][ch]) for ch in row] for row in grid]


# ---------------------------------------------------------------- generated versions

def ramp_of(palette):
    lookup = {}
    for ramp in palette["materials"].values():
        for i, key in enumerate(ramp):
            lookup[key] = (ramp, i)
    return lookup


def variant_count(header):
    recolors = [r for r in header.get("recolor", "").split("|") if r.strip()]
    return max(int(header.get("variants", "1")), 1 + len(recolors))


def parse_mapping(text):
    return dict(pair.strip().split("=") for pair in text.split(",") if pair.strip())


def variant(grid, seed, palette):
    """Copies a grid with one or two seeded flaw pixels: a pixel nudged one shade
    along its material ramp, so no two buildings match."""
    rng = random.Random(seed)
    rows = [list(row) for row in grid]
    ramps = ramp_of(palette)
    candidates = [(x, y) for y, row in enumerate(rows) for x, ch in enumerate(row)
                  if ch in ramps and len(ramps[ch][0]) > 1 and ramps[ch][1] > 0]
    for _ in range(rng.choice((1, 2))):
        if not candidates:
            break
        x, y = rng.choice(candidates)
        ramp, i = ramps[rows[y][x]]
        j = i + rng.choice((-1, 1))
        j = min(max(j, 1), len(ramp) - 1) if len(ramp) > 1 else i
        if j == i:
            j = i - 1 if i > 1 else min(i + 1, len(ramp) - 1)
        rows[y][x] = ramp[j]
    return ["".join(r) for r in rows]


def recolour(grid, mapping):
    return ["".join(mapping.get(ch, ch) for ch in row) for row in grid]


def roll(grid, axis, step):
    if axis == "x":
        return [row[-step:] + row[:-step] for row in grid]
    return grid[-step:] + grid[:-step]


def sway(grid, rows, step):
    """Shifts the top `rows` rows sideways, for trees moving in the wind."""
    out = []
    for y, row in enumerate(grid):
        if y < rows:
            shift = step if y < rows // 2 else (step + 1) // 2 if step > 0 else 0
            row = ("." * shift + row)[:len(row)] if shift > 0 else row
        out.append(row)
    return out


def expand(sprite, palette):
    """Returns [(name, grid)] for the sprite and everything generated from it.

    Header options:
      variants: N        N versions, each extra one with a seeded flaw pixel or two
      recolor: A=B,C=D | E=F   extra versions with colours swapped (plus a flaw pixel)
      flaws: no          skip the flaw pixels (people, where one pixel matters)
      night: A=B         a _night copy of every version with colours swapped (lit windows)
      frames: roll-x STEP N | roll-y STEP N | swap A=B,C=D N | sway ROWS N
                         animation frames _f1.._f(N-1) for every version above
    """
    name, grid, header = sprite["name"], sprite["grid"], sprite["header"]
    out = [(name, grid)]
    recolors = [parse_mapping(r) for r in header.get("recolor", "").split("|") if r.strip()]
    for v in range(1, variant_count(header)):
        base = recolour(grid, recolors[v - 1]) if v - 1 < len(recolors) else grid
        if header.get("flaws") != "no":
            base = variant(base, zlib.crc32(name.encode()) + v, palette)
        out.append((f"{name}_v{v}", base))
    if "night" in header:
        mapping = parse_mapping(header["night"])
        out += [(f"{n}_night", recolour(g, mapping)) for n, g in list(out)]
    if "frames" in header:
        parts = header["frames"].split()
        kind, count = parts[0], int(parts[-1])
        animated = []
        for n, g in out:
            for f in range(1, count):
                if kind in ("roll-x", "roll-y"):
                    frame = roll(g, kind[-1], int(parts[1]) * f)
                elif kind == "swap":
                    frame = recolour(g, parse_mapping(parts[1])) if f % 2 == 1 else g
                elif kind == "sway":
                    frame = sway(g, int(parts[1]), 1 if f % 2 == 1 else 0)
                else:
                    raise ValueError(f"{name}: unknown frames kind '{kind}'")
                animated.append((f"{n}_f{f}", frame))
        out += animated
    return out


# ---------------------------------------------------------------- atlas and contact sheet

def pack(images):
    """Shelf packing: tallest first, then by name, so the layout is stable."""
    order = sorted(images, key=lambda n: (-len(images[n]), n))
    x = y = shelf = 0
    placed = {}
    for name in order:
        rows = images[name]
        w, h = len(rows[0]), len(rows)
        if x + w + PADDING > ATLAS_WIDTH:
            x, y, shelf = 0, y + shelf + PADDING, 0
        placed[name] = (x, y, w, h)
        x += w + PADDING
        shelf = max(shelf, h)
    height = y + shelf
    height = 1 << (height - 1).bit_length()
    return placed, height


FONT = {  # 3x5 glyphs for contact sheet labels
    "a": "111101111101101", "b": "110101110101110", "c": "111100100100111", "d": "110101101101110",
    "e": "111100110100111", "f": "111100110100100", "g": "111100101101111", "h": "101101111101101",
    "i": "111010010010111", "j": "001001001101111", "k": "101101110101101", "l": "100100100100111",
    "m": "101111111101101", "n": "110101101101101", "o": "111101101101111", "p": "111101111100100",
    "q": "111101101111001", "r": "110101110101101", "s": "111100111001111", "t": "111010010010010",
    "u": "101101101101111", "v": "101101101101010", "w": "101101111111101", "x": "101101010101101",
    "y": "101101111010010", "z": "111001010100111", "_": "000000000000111",
    "0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111",
    "4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "7": "111001001001001",
    "8": "111101111101111", "9": "111101111001111",
}


def contact_sheet(images, path, scale=4):
    names = sorted(images)
    cell_w, cell_h, cols = 32 * scale + 48, 32 * scale + 24, 6
    rows_n = (len(names) + cols - 1) // cols
    W, H = cols * cell_w, rows_n * cell_h
    bg_a, bg_b, ink = (236, 232, 220, 255), (222, 216, 202, 255), (60, 50, 50, 255)
    canvas = [[bg_a if ((x // 8) + (y // 8)) % 2 == 0 else bg_b for x in range(W)] for y in range(H)]
    for k, name in enumerate(names):
        cx, cy = (k % cols) * cell_w + 8, (k // cols) * cell_h + 4
        rows = images[name]
        for y, row in enumerate(rows):
            for x, px in enumerate(row):
                if px[3] == 0:
                    continue
                for dy in range(scale):
                    for dx in range(scale):
                        canvas[cy + y * scale + dy][cx + x * scale + dx] = px
        lx, ly = cx, cy + 32 * scale + 6
        for ch in name.lower()[:(cell_w - 16) // 8]:
            glyph = FONT.get(ch)
            if glyph:
                for gy in range(5):
                    for gx in range(3):
                        if glyph[gy * 3 + gx] == "1":
                            for d in range(4):
                                canvas[ly + gy * 2 + d // 2][lx + gx * 2 + d % 2] = ink
            lx += 8
    write_png(path, W, H, canvas)


# ---------------------------------------------------------------- main

def main(argv):
    check_only = "--check" in argv
    problems = []
    palette = load_palette(problems)
    buildings = {b["id"]: b for b in json.loads((ROOT / "Data" / "buildings.json").read_text())}
    sprites = [s for s in (parse_sprite(p, problems) for p in sorted(SPRITES.glob("*.txt"))) if s]
    for sprite in sprites:
        check_sprite(sprite, palette, buildings, problems)
    names = {s["name"] for s in sprites}
    for b in buildings:
        if b not in names:
            problems.append(f"building '{b}' has no sprite in Art/sprites")

    images = {}
    if not problems:
        for sprite in sprites:
            for name, grid in expand(sprite, palette):
                images[name] = to_rgba(grid, palette)

    allowed = {hex_rgba(v) for v in palette["colors"].values()}
    for path in sorted(MANUAL.glob("*.png")) if MANUAL.exists() else []:
        try:
            w, h, rows = read_png(path)
        except ValueError as error:
            problems.append(f"manual/{path.name}: {error}")
            continue
        ew, eh = expected_size(path.stem, buildings)
        if (w, h) != (ew, eh):
            problems.append(f"manual/{path.name}: is {w}x{h}, expected {ew}x{eh}")
        for y, row in enumerate(rows):
            for x, px in enumerate(row):
                if px[3] not in (0, 255):
                    problems.append(f"manual/{path.name}: partly transparent pixel at ({x}, {y})")
                elif px[3] == 255 and px not in allowed:
                    problems.append(f"manual/{path.name}: off-palette colour {px[:3]} at ({x}, {y})")
        images[path.stem] = [[(0, 0, 0, 0) if px[3] == 0 else px for px in row] for row in rows]

    if problems:
        print("Art check failed:")
        for p in problems:
            print(f"  - {p}")
        return 1
    if check_only:
        print(f"Art check passed: {len(sprites)} sprites, {len(images)} images with generated versions")
        return 0

    OUT.mkdir(parents=True, exist_ok=True)
    placed, height = pack(images)
    atlas = [[(0, 0, 0, 0)] * ATLAS_WIDTH for _ in range(height)]
    for name, (x, y, w, h) in placed.items():
        for dy, row in enumerate(images[name]):
            atlas[y + dy][x:x + w] = row
    write_png(OUT / "atlas.png", ATLAS_WIDTH, height, atlas)
    # Raw RGBA for tools that cannot decode PNG (the Swift preview renderer). Not committed.
    (OUT / "atlas.rgba").write_bytes(bytes(v for row in atlas for px in row for v in px))
    manifest = {
        "atlas": "atlas.png",
        "width": ATLAS_WIDTH,
        "height": height,
        "tileSize": TILE,
        "filtering": "nearest",
        "sprites": {name: {"x": x, "y": y, "w": w, "h": h} for name, (x, y, w, h) in sorted(placed.items())},
    }
    (OUT / "atlas.json").write_text(json.dumps(manifest, indent=1, sort_keys=True) + "\n")
    contact_sheet({s["name"]: images[s["name"]] for s in sprites}, ART / "contact_sheet.png")
    contact_sheet(images, OUT / "contact_sheet_all.png")
    print(f"Built {len(images)} images from {len(sprites)} sprites into Art/generated/atlas.png "
          f"({ATLAS_WIDTH}x{height}) and Art/contact_sheet.png")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
