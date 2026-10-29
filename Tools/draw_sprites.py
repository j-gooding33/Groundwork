#!/usr/bin/env python3
"""Draws Groundwork's first sprites as code and writes them as text grids.

Each sprite becomes Art/sprites/<name>.txt: a short header, a line of three
dashes, then one character per pixel using Art/palette.json keys ('.' is
clear). The text grids are the source of truth after this runs: edit them by
hand freely. This script never overwrites an existing grid unless you pass
--force with sprite names.

Usage: python3 Tools/draw_sprites.py            # write any missing sprites
       python3 Tools/draw_sprites.py --force cottage brick_kiln
"""
import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Art" / "sprites"


class Canvas:
    def __init__(self, w, h, fill="."):
        self.w, self.h = w, h
        self.px = [[fill] * w for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            self.px[y][x] = c

    def get(self, x, y):
        return self.px[y][x] if 0 <= x < self.w and 0 <= y < self.h else "."

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, c)

    def hline(self, x0, x1, y, c):
        for x in range(x0, x1 + 1):
            self.set(x, y, c)

    def vline(self, x, y0, y1, c):
        for y in range(y0, y1 + 1):
            self.set(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(self.h):
            for x in range(self.w):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.set(x, y, c)

    def outline(self, c, inside=None):
        """Draws an outline of colour c around every non-clear region."""
        marks = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] != ".":
                    continue
                if any(self.get(x + dx, y + dy) not in (".", c) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    marks.append((x, y))
        for x, y in marks:
            self.set(x, y, c)

    def shade_edges(self, region, light, dark):
        """Lights the top-left edge and darkens the bottom-right edge of a colour region."""
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] != region:
                    continue
                if self.get(x - 1, y) != region or self.get(x, y - 1) != region:
                    self.set(x, y, light)
                elif self.get(x + 1, y) != region or self.get(x, y + 1) != region:
                    self.set(x, y, dark)

    def text(self):
        return "\n".join("".join(row) for row in self.px)


def speckle(c, rng, colours, chance, only=None):
    """Scatters colours at random. With `only`, touches just pixels of that colour."""
    for y in range(c.h):
        for x in range(c.w):
            if only is not None and c.get(x, y) != only:
                continue
            for colour, p in zip(colours, chance):
                if rng.random() < p:
                    c.set(x, y, colour)
                    break


# ---------------------------------------------------------------- terrain

def grass(seed, light=0.05, dark=0.10, flowers=False):
    rng = random.Random(seed)
    c = Canvas(16, 16, "c")
    speckle(c, rng, ["b", "d"], [dark, light])
    # Small tufts: a dark pixel with a light one above-left.
    for _ in range(3):
        x, y = rng.randrange(1, 15), rng.randrange(1, 15)
        c.set(x, y, "b"); c.set(x - 1, y - 1, "d")
    if flowers:
        for _ in range(2):
            x, y = rng.randrange(2, 14), rng.randrange(2, 14)
            c.set(x, y, "F"); c.set(x + 1, y, "D")
    return c


def water():
    c = Canvas(16, 16, "f")
    rng = random.Random(7)
    speckle(c, rng, ["e"], [0.06])
    for (x, y) in [(1, 2), (9, 5), (4, 9), (12, 12), (7, 14)]:
        c.hline(x, x + 2, y, "h"); c.set(x + 1, y - 1, "i")
    return c


def ground(base, specks, chances, seed):
    c = Canvas(16, 16, base)
    speckle(c, random.Random(seed), specks, chances)
    return c


def paper_fog():
    c = Canvas(16, 16, "F")
    for y in range(16):
        for x in range(16):
            if (x * 3 + y * 5) % 11 == 0:
                c.set(x, y, "A")
    return c


# ---------------------------------------------------------------- nature

def tree():
    c = Canvas(16, 16)
    c.rect(7, 11, 2, 4, "u"); c.vline(8, 11, 14, "t")
    c.ellipse(8, 7, 6.5, 5.5, "c")
    c.ellipse(6.5, 5.5, 3.5, 3, "d")
    c.ellipse(10, 9.5, 3.5, 2.5, "b")
    for (x, y) in [(5, 4), (9, 3), (4, 7), (11, 6)]:
        c.set(x, y, "d")
    c.set(12, 10, "a"); c.set(3, 9, "b")
    c.outline("a")
    return c


def rock():
    c = Canvas(16, 16)
    c.ellipse(8, 10, 6, 4.5, "y")
    c.ellipse(6.5, 8.5, 3.5, 2.5, "z")
    c.set(5, 7, "A"); c.set(6, 7, "A")
    c.ellipse(10.5, 12, 3, 1.6, "x")
    c.set(9, 9, "x")
    c.outline("x")
    return c


def clay_marker():
    c = Canvas(16, 16)
    for cx, cy, r in [(5, 10, 2.5), (10, 9, 3), (8, 12.5, 2.2)]:
        c.ellipse(cx, cy, r, r * 0.75, "o")
        c.set(int(cx - r / 2), int(cy - r / 2), "p")
    c.outline("n")
    return c


# ---------------------------------------------------------------- buildings

def clay_pit():
    c = Canvas(16, 16)
    c.rect(1, 4, 14, 11, "l")             # earth rim, lit top-left
    c.hline(1, 14, 4, "m"); c.vline(1, 4, 14, "m")
    c.hline(2, 14, 14, "k"); c.vline(14, 5, 14, "k")
    c.rect(3, 6, 10, 7, "n")              # first step down, in shadow
    c.rect(4, 8, 8, 4, "o")               # clay floor
    c.hline(4, 11, 11, "p"); c.vline(11, 8, 11, "p")
    c.set(6, 9, "p"); c.set(9, 10, "n")
    # A shovel stuck in the rim.
    c.vline(13, 0, 5, "u"); c.set(12, 0, "v"); c.set(14, 0, "t")
    c.rect(12, 5, 3, 2, "z"); c.set(14, 6, "y")
    c.outline("j")
    return c


def lumber_camp():
    c = Canvas(16, 16)
    # A stack of logs, round ends facing us.
    for (cx, cy) in [(4, 11), (8, 11), (12, 11), (6, 7.5), (10, 7.5)]:
        c.ellipse(cx, cy, 2.2, 2.0, "v")
        c.set(int(cx), int(cy), "u")
        c.set(int(cx) - 1, int(cy) - 1, "w")
    c.outline("t")
    # A stump with an axe on the left.
    c.rect(1, 3, 3, 2, "u"); c.hline(1, 3, 3, "v")
    c.vline(3, 0, 2, "t"); c.set(2, 0, "z"); c.set(4, 0, "y")
    return c


def brick_kiln():
    c = Canvas(32, 32)
    c.ellipse(16, 18, 13, 12, "r")        # brick dome
    # Courses of bricks: mortar lines, offset every row.
    for y in range(7, 31):
        for x in range(32):
            if c.get(x, y) != "r":
                continue
            if y % 3 == 0:
                c.set(x, y, "q")
            elif (x + (y // 3) * 2) % 5 == 0:
                c.set(x, y, "q")
    c.ellipse(11, 12, 6, 4.5, "s")        # light on the top-left of the dome
    for y in range(7, 31):
        for x in range(32):
            if c.get(x, y) == "s" and y % 3 == 0:
                c.set(x, y, "r")
    c.rect(4, 28, 25, 3, "y")             # stone footing
    c.hline(4, 28, 28, "z")
    # Fire mouth.
    c.ellipse(16, 26, 4.5, 4, "K")
    c.rect(12, 26, 9, 2, "K")
    c.ellipse(16, 26.8, 3, 2.3, "E")
    c.ellipse(16, 27.3, 1.6, 1.2, "D")
    # Chimney.
    c.rect(21, 1, 5, 9, "r")
    c.vline(21, 1, 9, "s"); c.hline(20, 26, 1, "q"); c.hline(21, 25, 5, "q")
    c.outline("q")
    return c


def sawmill():
    c = Canvas(32, 32)
    # Plank walls.
    c.rect(3, 14, 26, 15, "u")
    for x in range(3, 29, 3):
        c.vline(x, 14, 28, "t")
    for x in range(4, 29, 3):
        c.vline(x, 14, 28, "v")
    # Roof.
    for y in range(4, 15):
        inset = max(0, (14 - y) // 2)
        c.hline(1 + inset, 30 - inset, y, "C")
    for y in range(5, 15, 3):
        c.hline(1, 30, y, "B")
    c.hline(4, 27, 4, "C")
    c.rect(2, 14, 28, 1, "B")
    # Door.
    c.rect(6, 20, 6, 9, "t"); c.rect(7, 21, 4, 8, "j")
    # Saw blade at the front, with a log on the bench.
    c.rect(14, 25, 14, 2, "k"); c.hline(14, 27, 25, "l")
    c.ellipse(22, 22, 4.2, 4.2, "z")
    c.ellipse(22, 22, 2.2, 2.2, "y")
    c.set(22, 22, "x")
    for (x, y) in [(22, 17), (27, 22), (22, 27), (17, 22), (25, 19), (19, 19)]:
        c.set(x, y, "A")
    c.ellipse(16.5, 23.5, 2, 1.6, "v"); c.set(16, 23, "w")
    c.outline("t")
    return c


def storage_crate():
    c = Canvas(16, 16)
    c.rect(2, 3, 12, 12, "v")
    for y in range(4, 15, 3):
        c.hline(3, 12, y, "u")
    c.rect(2, 3, 12, 1, "w")
    c.vline(2, 3, 14, "w")
    for i in range(10):                    # diagonal brace
        c.set(3 + i, 13 - i, "t")
    c.vline(13, 3, 14, "u"); c.hline(2, 13, 14, "u")
    c.outline("t")
    return c


def foundation():
    c = Canvas(32, 32)
    c.rect(2, 4, 28, 26, "k")             # dug earth
    speckle(c, random.Random(3), ["l", "j"], [0.08, 0.05], only="k")
    # Low stone wall around the edge.
    for x in range(2, 30):
        c.set(x, 4, "z"); c.set(x, 5, "y"); c.set(x, 28, "y"); c.set(x, 29, "x")
    for y in range(4, 30):
        c.set(2, y, "z"); c.set(3, y, "y"); c.set(28, y, "y"); c.set(29, y, "x")
    for x in range(5, 28, 4):
        c.set(x, 4, "A")
    # Corner stakes and a string line.
    for (x, y) in [(1, 2), (30, 2), (1, 30), (30, 30)]:
        c.vline(x, y - 1, y + 1, "u")
    for x in range(4, 28, 2):
        c.set(x, 2, "F")
    c.outline("j")
    return c


def cottage():
    c = Canvas(32, 32)
    # Brick front wall.
    c.rect(4, 16, 24, 13, "r")
    for y in range(16, 29):
        for x in range(4, 28):
            if y % 3 == 1 or (x + (y // 3) * 2) % 4 == 0:
                c.set(x, y, "q" if y % 3 == 1 else "r")
    c.vline(4, 16, 28, "s"); c.vline(5, 16, 28, "s")
    # Slate roof, lighter on the left slope.
    for y in range(3, 17):
        half = (y - 3) + 2
        c.hline(16 - half, 15, y, "C")
        c.hline(16, 15 + half, y, "B")
    for y in range(6, 17, 3):
        for x in range(32):
            if c.get(x, y) == "C":
                c.set(x, y, "B")
    c.hline(1, 30, 16, "K")
    # Chimney.
    c.rect(21, 2, 4, 8, "r"); c.vline(21, 2, 9, "s"); c.hline(20, 25, 2, "q")
    # Door and windows (window panes are B so the night pass can light them).
    c.rect(14, 21, 5, 8, "u"); c.vline(14, 21, 28, "v"); c.set(17, 25, "D")
    for wx in (7, 22):
        c.rect(wx, 20, 4, 4, "B")
        c.set(wx, 20, "C")
        c.hline(wx - 1, wx + 4, 24, "z")
    c.outline("q")
    return c


def builders_yard():
    c = Canvas(32, 32)
    c.rect(2, 6, 28, 23, "k")
    speckle(c, random.Random(5), ["l"], [0.07], only="k")
    # Fence.
    for x in range(1, 31):
        c.set(x, 6, "v"); c.set(x, 29, "u")
    for y in range(6, 30):
        c.set(1, y, "v"); c.set(30, y, "u")
    for x in range(1, 31, 4):
        c.vline(x, 4, 6, "v")
    # Brick stack.
    for row in range(3):
        for col in range(3 - row % 2):
            x = 5 + col * 4 + (row % 2) * 2
            y = 22 - row * 3
            c.rect(x, y, 4, 2, "r"); c.hline(x, x + 3, y, "s")
    # Plank stack.
    for row in range(4):
        y = 22 - row * 2
        c.hline(18, 27, y, "w"); c.hline(18, 27, y + 1, "v")
    # A sawhorse.
    c.hline(10, 18, 11, "u"); c.set(11, 12, "t"); c.set(17, 12, "t"); c.set(10, 13, "t"); c.set(18, 13, "t")
    c.outline("t")
    return c


# ---------------------------------------------------------------- belts

def belt(kind):
    """Belts run along a band from column/row 3 to 12. Chevrons point the way items move."""
    c = Canvas(16, 16)
    band = range(3, 13)
    if kind == "h":
        for y in band:
            c.hline(0, 15, y, "y")
        c.hline(0, 15, 3, "x"); c.hline(0, 15, 12, "x"); c.hline(0, 15, 4, "z")
        for x0 in (1, 9):
            for i in range(3):
                c.set(x0 + i, 6 + i, "A"); c.set(x0 + i, 10 - i, "A")
        return c
    if kind == "v":
        for x in band:
            c.vline(x, 0, 15, "y")
        c.vline(3, 0, 15, "x"); c.vline(12, 0, 15, "x"); c.vline(4, 0, 15, "z")
        for y0 in (1, 9):
            for i in range(3):
                c.set(6 + i, y0 + i, "A"); c.set(10 - i, y0 + i, "A")
        return c
    # Corners join two edges: kind is e.g. "ne" (north and east).
    vertical, horizontal = kind[0], kind[1]
    ys = range(0, 13) if vertical == "n" else range(3, 16)
    xs = range(3, 16) if horizontal == "e" else range(0, 13)
    for y in ys:
        c.hline(3, 12, y, "y")
    for x in xs:
        c.vline(x, 3, 12, "y")
    # Outer rails on the far sides of the turn, short inner rails on the near sides.
    outer_x = 3 if horizontal == "e" else 12
    outer_y = 12 if vertical == "n" else 3
    for y in ys:
        c.set(outer_x, y, "x")
    for x in xs:
        c.set(x, outer_y, "x")
    inner_x = 12 if horizontal == "e" else 3
    inner_y = 3 if vertical == "n" else 12
    for y in (range(0, 3) if vertical == "n" else range(13, 16)):
        c.set(inner_x, y, "x")
    for x in (range(13, 16) if horizontal == "e" else range(0, 3)):
        c.set(x, inner_y, "x")
    c.set(inner_x, inner_y, "x")
    # A curved stripe through the middle of the turn.
    cx = 15.5 if horizontal == "e" else 0.5
    cy = -0.5 if vertical == "n" else 16.5
    for y in range(16):
        for x in range(16):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if c.get(x, y) == "y" and 7.4 <= d <= 8.4:
                c.set(x, y, "A")
    return c


# ---------------------------------------------------------------- items (8x8)

def item_clay():
    c = Canvas(8, 8)
    c.ellipse(4, 4.5, 3, 2.6, "o"); c.set(2, 3, "p"); c.set(3, 3, "p")
    c.outline("n")
    return c


def item_log():
    c = Canvas(8, 8)
    c.rect(1, 3, 6, 3, "u"); c.hline(1, 6, 3, "v")
    c.ellipse(1.8, 4.5, 1.4, 1.6, "w"); c.set(1, 4, "v")
    c.outline("t")
    return c


def item_brick():
    c = Canvas(8, 8)
    c.rect(1, 3, 6, 3, "r"); c.hline(1, 6, 3, "s"); c.vline(1, 3, 5, "s")
    c.outline("q")
    return c


def item_plank():
    c = Canvas(8, 8)
    c.rect(0, 4, 8, 2, "w"); c.hline(0, 7, 5, "v"); c.set(3, 4, "v")
    c.outline("u")
    return c


# ---------------------------------------------------------------- effects

def smoke(frame):
    c = Canvas(8, 8)
    if frame == 1:
        c.ellipse(4, 5, 1.6, 1.4, "z"); c.set(3, 4, "A")
    elif frame == 2:
        c.ellipse(4, 4, 2.8, 2.4, "z"); c.ellipse(3.3, 3.3, 1.4, 1.2, "A"); c.set(5, 5, "y")
    else:
        c.ellipse(4, 3.5, 3.4, 3, "A")
        for y in range(8):
            for x in range(8):
                if (x + y) % 2 == 0:
                    c.set(x, y, "." if c.get(x, y) == "A" else c.get(x, y))
    return c


def pop(frame):
    c = Canvas(16, 16)
    radius = {1: 2.5, 2: 5, 3: 7}[frame]
    steps = {1: 8, 2: 12, 3: 10}[frame]
    for k in range(steps):
        angle = 2 * math.pi * k / steps
        x = int(round(7.5 + radius * math.cos(angle)))
        y = int(round(7.5 + radius * math.sin(angle) * 0.7))
        c.set(x, y, "m" if frame < 3 else "l")
        if frame == 1:
            c.set(x, y + 1, "l")
    if frame == 1:
        c.rect(7, 7, 2, 2, "F")
    return c


# ---------------------------------------------------------------- icons

def icon(name):
    c = Canvas(16, 16)
    if name == "build":                   # hammer
        for i in range(8):
            c.set(4 + i, 12 - i, "u"); c.set(5 + i, 12 - i, "t")
        c.rect(9, 2, 6, 3, "z"); c.hline(9, 14, 2, "A"); c.set(14, 4, "y")
    elif name == "trace":                 # a gold chain of three nodes
        for (x, y) in [(3, 12), (8, 6), (13, 3)]:
            c.ellipse(x + 0.5, y + 0.5, 2, 2, "D"); c.set(x - 1, y - 1, "F")
        for i in range(5):
            c.set(4 + i, 11 - i, "E"); c.set(9 + i, 5 - i // 2, "E")
    elif name == "undo":                  # arrow pointing back, curling round
        art = [
            "....F...........",
            "...FF...........",
            "..FFFFFFFFF.....",
            ".FFFFFFFFFFFF...",
            "..FFFFFFFFFFFF..",
            "...FF......FFF..",
            "....F.......FF..",
            "............FF..",
            "...........FFF..",
            "......FFFFFFF...",
            "......FFFFFF....",
        ]
        for y, row in enumerate(art):
            for x, ch in enumerate(row):
                if ch == "F":
                    c.set(x, y + 3, "F")
    elif name == "demolish":              # a brick with a cross
        c.rect(2, 6, 12, 5, "r"); c.hline(2, 13, 6, "s")
        for i in range(10):
            c.set(3 + i, 3 + i, "F"); c.set(12 - i, 3 + i, "F")
    elif name == "play_pause":
        for y in range(3, 13):
            half = 5 - abs(8 - y)
            c.hline(2, 2 + max(0, half), y, "F")
        c.rect(10, 3, 2, 10, "F"); c.rect(13, 3, 2, 10, "F")
    elif name == "cancel":
        for i in range(10):
            for d in (0, 1):
                c.set(3 + i + d, 3 + i, "F"); c.set(12 - i + d, 3 + i, "F")
    elif name == "bricks":
        for (x, y) in [(2, 10), (8, 10), (5, 6)]:
            c.rect(x, y, 6, 3, "r"); c.hline(x, x + 5, y, "s")
    elif name == "goal":                  # flag
        c.vline(4, 2, 14, "u"); c.set(4, 1, "D")
        for y in range(2, 8):
            c.hline(5, 12 - abs(5 - y), y, "E" if y > 4 else "D")
    c.outline("K")
    return c


SPRITES = {
    # name: (drawing, header lines)
    "terrain_grass_1": (lambda: grass(1), {}),
    "terrain_grass_2": (lambda: grass(2, light=0.12, dark=0.06, flowers=True), {}),
    "terrain_grass_3": (lambda: grass(3, light=0.02, dark=0.22), {}),
    "terrain_water": (water, {}),
    "terrain_shore": (lambda: ground("m", ["l", "k"], [0.10, 0.03], 4), {}),
    "terrain_dirt": (lambda: ground("k", ["l", "j"], [0.10, 0.06], 5), {}),
    "terrain_clay_ground": (lambda: ground("o", ["n", "p"], [0.10, 0.08], 6), {}),
    "terrain_paper_fog": (paper_fog, {}),
    "nature_tree": (tree, {"variants": "3"}),
    "nature_clay_marker": (clay_marker, {}),
    "nature_rock": (rock, {}),
    "clay_pit": (clay_pit, {"variants": "3"}),
    "lumber_camp": (lumber_camp, {"variants": "3"}),
    "brick_kiln": (brick_kiln, {"variants": "3"}),
    "sawmill": (sawmill, {"variants": "3"}),
    "storage_crate": (storage_crate, {"variants": "2"}),
    "foundation": (foundation, {"variants": "2"}),
    "cottage": (cottage, {"variants": "3", "night": "B=D"}),
    "builders_yard": (builders_yard, {"variants": "2"}),
    "belt_h": (lambda: belt("h"), {"frames": "roll-x 2 4"}),
    "belt_v": (lambda: belt("v"), {"frames": "roll-y 2 4"}),
    "belt_ne": (lambda: belt("ne"), {}),
    "belt_nw": (lambda: belt("nw"), {}),
    "belt_se": (lambda: belt("se"), {}),
    "belt_sw": (lambda: belt("sw"), {}),
    "item_clay": (item_clay, {}),
    "item_log": (item_log, {}),
    "item_brick": (item_brick, {}),
    "item_plank": (item_plank, {}),
    "fx_smoke_1": (lambda: smoke(1), {}),
    "fx_smoke_2": (lambda: smoke(2), {}),
    "fx_smoke_3": (lambda: smoke(3), {}),
    "fx_pop_1": (lambda: pop(1), {}),
    "fx_pop_2": (lambda: pop(2), {}),
    "fx_pop_3": (lambda: pop(3), {}),
    "icon_build": (lambda: icon("build"), {}),
    "icon_trace": (lambda: icon("trace"), {}),
    "icon_undo": (lambda: icon("undo"), {}),
    "icon_demolish": (lambda: icon("demolish"), {}),
    "icon_play_pause": (lambda: icon("play_pause"), {}),
    "icon_cancel": (lambda: icon("cancel"), {}),
    "icon_bricks": (lambda: icon("bricks"), {}),
    "icon_goal": (lambda: icon("goal"), {}),
}


def main(argv):
    force = set()
    if argv and argv[0] == "--force":
        force = set(argv[1:]) or set(SPRITES)
    OUT.mkdir(parents=True, exist_ok=True)
    written = 0
    for name, (draw, header) in SPRITES.items():
        path = OUT / f"{name}.txt"
        if path.exists() and name not in force:
            continue
        canvas = draw()
        lines = [f"size: {canvas.w}x{canvas.h}"] + [f"{k}: {v}" for k, v in header.items()]
        path.write_text("\n".join(lines) + "\n---\n" + canvas.text() + "\n")
        written += 1
    print(f"Wrote {written} sprite grids to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main(sys.argv[1:])
