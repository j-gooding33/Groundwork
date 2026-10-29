#!/usr/bin/env python3
"""Converts <name>_<W>x<H>.rgba files from GroundworkPreview into <name>.png."""
import re
import sys
from pathlib import Path

import make_art

for path in sorted(Path(sys.argv[1]).glob("*.rgba")):
    match = re.match(r"(.+)_(\d+)x(\d+)$", path.stem)
    if not match:
        continue
    name, w, h = match.group(1), int(match.group(2)), int(match.group(3))
    raw = path.read_bytes()
    rows = [[tuple(raw[(y * w + x) * 4:(y * w + x) * 4 + 4]) for x in range(w)] for y in range(h)]
    make_art.write_png(path.with_name(f"{name}.png"), w, h, rows)
    path.unlink()
    print(f"wrote {path.with_name(name + '.png')}")
