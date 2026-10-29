#!/usr/bin/env python3
"""Draws Groundwork's sprites as code and writes them as text grids.

Each sprite becomes Art/sprites/<name>.txt: a short header, a line of three
dashes, then one character per pixel using Art/palette.json keys ('.' is
clear). The text grids are the source of truth after this runs: edit them by
hand freely. This script never overwrites an existing grid unless you pass
--force with sprite names (or --force alone for all of them).

Usage: python3 Tools/draw_sprites.py            # write any missing sprites
       python3 Tools/draw_sprites.py --force cottage brick_kiln
"""
import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Art" / "sprites"
TAU = 2 * math.pi


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

    def pixels(self, rows, x0=0, y0=0, keep="."):
        """Stamps a small hand-drawn grid; `keep` characters are left as they are."""
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch not in keep:
                    self.set(x0 + x, y0 + y, ch)

    def outline(self, c, around=None):
        """Outlines clear pixels next to drawn ones (or only next to colours in `around`)."""
        marks = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] != ".":
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    n = self.get(x + dx, y + dy)
                    if n != "." and n != c and (around is None or n in around):
                        marks.append((x, y))
                        break
        for x, y in marks:
            self.set(x, y, c)

    def replace(self, old, new, region=None):
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] == old and (region is None or region(x, y)):
                    self.px[y][x] = new

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


def lit(x, y, cx, cy, rx, ry):
    """How much a point on a rounded shape faces the light from the top left (-1 to 1)."""
    nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
    return -(nx * 0.6 + ny * 0.8)


# ---------------------------------------------------------------- terrain

def grass(seed, light=0.05, dark=0.10, flowers=False):
    rng = random.Random(seed)
    c = Canvas(16, 16, "c")
    speckle(c, rng, ["b", "d"], [dark, light])
    for _ in range(4):
        x, y = rng.randrange(1, 15), rng.randrange(1, 15)
        c.set(x, y, "b"); c.set(x - 1, y - 1, "d"); c.set(x + 1, y, "b")
    if flowers:
        for _ in range(2):
            x, y = rng.randrange(2, 14), rng.randrange(2, 14)
            c.set(x, y, "F"); c.set(x + 1, y, "D"); c.set(x, y + 1, "b")
    return c


def water():
    c = Canvas(16, 16, "f")
    speckle(c, random.Random(7), ["e"], [0.07])
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


TERRAIN = {
    "water": water,
    "shore": lambda: ground("m", ["l", "k"], [0.10, 0.03], 4),
    "clay_ground": lambda: ground("o", ["n", "p"], [0.10, 0.08], 6),
    "dirt": lambda: ground("k", ["l", "j"], [0.10, 0.06], 5),
    "fog": paper_fog,
}
# The colour of the ragged line where each terrain meets lower ground.
EDGE_ACCENT = {"water": "i", "shore": "l", "clay_ground": "n", "dirt": "j", "fog": "A"}


def profile(i, seed):
    """Fringe depth along an edge: wavy, and periodic over 16 pixels so edges
    on neighbouring tiles join up."""
    return 3 + round(1.3 * math.sin(TAU * i / 16 + seed) + 0.8 * math.sin(TAU * 2 * i / 16 + seed * 2.3))


def edge(terrain, side):
    """The fringe of `terrain` spilling onto a lower tile from one side or corner.
    Pixels come from the terrain's own tile, so the fringe continues its texture."""
    tile = TERRAIN[terrain]()
    c = Canvas(16, 16)
    accent = EDGE_ACCENT[terrain]
    seed = sum(map(ord, terrain)) % 7

    def inside(x, y):
        if side == "n": return y < profile(x, seed)
        if side == "s": return 15 - y < profile(x, seed + 1)
        if side == "w": return x < profile(y, seed + 2)
        if side == "e": return 15 - x < profile(y, seed + 3)
        cx = 16 if "e" in side else 0
        cy = 0 if "n" in side else 16
        angle = math.atan2(y + 0.5 - cy, x + 0.5 - cx)
        return math.hypot(x + 0.5 - cx, y + 0.5 - cy) < 4.2 + 0.9 * math.sin(angle * 5 + seed)

    for y in range(16):
        for x in range(16):
            if inside(x, y):
                c.set(x, y, tile.get(x, y))
    # A broken accent line along the fringe.
    for y in range(16):
        for x in range(16):
            if c.get(x, y) == "." and (x * 7 + y * 3) % 4 != 0:
                if any(c.get(x + dx, y + dy) not in (".", accent) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    c.set(x, y, accent)
    return c


# ---------------------------------------------------------------- nature

def tree():
    c = Canvas(16, 16)
    c.rect(7, 11, 2, 4, "u"); c.vline(8, 11, 14, "t"); c.set(6, 14, "t"); c.set(9, 14, "t")
    cx, cy, rx, ry = 8, 7, 6.5, 5.6
    for y in range(16):
        for x in range(16):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                l = lit(x, y, cx, cy, rx, ry)
                c.set(x, y, "d" if l > 0.45 else "b" if l < -0.35 else "c")
    for (x, y) in [(6, 3), (9, 4), (4, 6), (11, 8), (7, 9)]:
        c.set(x, y, "b"); c.set(x - 1, y - 1, "d")
    c.outline("a")
    return c


def rock():
    c = Canvas(16, 16)
    cx, cy, rx, ry = 8, 10, 6.2, 4.6
    for y in range(16):
        for x in range(16):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                l = lit(x, y, cx, cy, rx, ry)
                c.set(x, y, "A" if l > 0.6 else "z" if l > 0.1 else "y" if l > -0.45 else "x")
    c.set(9, 9, "x"); c.set(10, 10, "x"); c.set(6, 11, "y")
    c.outline("x")
    return c


def clay_marker():
    c = Canvas(16, 16)
    for cx, cy, r in [(5, 10, 2.6), (10, 9, 3.1), (8, 12.6, 2.2)]:
        c.ellipse(cx, cy, r, r * 0.75, "o")
        c.set(int(cx - r / 2), int(cy - r / 2), "p")
        c.set(int(cx + r / 2), int(cy + 1), "n")
    c.outline("n")
    return c


# ---------------------------------------------------------------- buildings

def brick_texture(c, x0, y0, w, h, light="s", mid="r", mortar="q", lit_cols=2):
    """Courses of bricks, offset every row, lit on the left."""
    for y in range(y0, y0 + h):
        course = (y - y0) // 3
        for x in range(x0, x0 + w):
            if (y - y0) % 3 == 2 or (x - x0 + course * 2) % 5 == 4:
                c.set(x, y, mortar)
            else:
                c.set(x, y, light if x < x0 + lit_cols else mid)


def window(c, x, y, w=5, h=5):
    """Wooden frame, glass that lights up at night (e becomes D), a sill below."""
    c.rect(x, y, w, h, "w")
    c.rect(x + 1, y + 1, w - 2, h - 2, "e")
    c.vline(x + w // 2, y + 1, y + h - 2, "w")
    c.hline(x + 1, x + w - 2, y + h // 2, "w")
    c.set(x + 1, y + 1, "h")
    c.hline(x - 1, x + w, y + h, "z")


def clay_pit():
    c = Canvas(16, 16)
    # Earth rim around an uneven dig, lit from the top left.
    cx, cy, rx, ry = 7.5, 9.5, 7.2, 5.8
    for y in range(16):
        for x in range(16):
            wobble = 0.35 * math.sin(x * 1.7) + 0.25 * math.cos(y * 2.1)
            if ((x + 0.5 - cx) / (rx + wobble)) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                l = lit(x, y, cx, cy, rx, ry)
                c.set(x, y, "m" if l > 0.5 else "k" if l < -0.4 else "l")
    # The hole: in shadow at the top (the far wall), lit clay on the near wall.
    hx, hy, hrx, hry = 7.5, 10, 4.8, 3.6
    for y in range(16):
        for x in range(16):
            if ((x + 0.5 - hx) / hrx) ** 2 + ((y + 0.5 - hy) / hry) ** 2 <= 1:
                l = lit(x, y, hx, hy, hrx, hry)
                c.set(x, y, "n" if l > 0.2 else "p" if l < -0.5 else "o")
    c.set(6, 10, "p"); c.set(9, 11, "n"); c.set(5, 11, "o")
    # A ladder down the far wall.
    c.vline(9, 6, 10, "u"); c.vline(11, 7, 11, "u")
    c.set(10, 7, "v"); c.set(10, 9, "v")
    # Spoil heap of dug clay, and a shovel.
    c.ellipse(2.5, 4.5, 2.4, 1.8, "o"); c.set(1, 3, "p"); c.set(2, 3, "p"); c.set(3, 5, "n")
    c.vline(13, 0, 5, "u"); c.set(12, 0, "v"); c.set(14, 0, "t")
    c.rect(12, 5, 3, 2, "z"); c.set(14, 6, "y")
    c.outline("j")
    return c


def lumber_camp():
    c = Canvas(16, 16)
    for (cx, cy) in [(6, 12), (10, 12), (14, 12), (8, 8.6), (12, 8.6), (10, 5.2)]:
        c.ellipse(cx, cy, 2.1, 1.9, "v")
        c.set(int(cx), int(cy), "u")
        c.set(int(cx) - 1, int(cy) - 1, "w")
        c.set(int(cx) + 1, int(cy) + 1, "u")
    c.outline("t")
    # Chopping stump with an axe, and wood chips.
    c.rect(0, 8, 4, 3, "u"); c.hline(0, 3, 8, "w"); c.set(1, 9, "v"); c.vline(3, 9, 10, "t")
    c.vline(2, 3, 7, "t"); c.rect(1, 3, 2, 2, "z"); c.set(1, 3, "A")
    for (x, y) in [(1, 13), (3, 14), (0, 15), (4, 12)]:
        c.set(x, y, "w")
    return c


def brick_kiln():
    c = Canvas(32, 32)
    cx, cy, rx, ry = 15.5, 18, 12.5, 11.5
    for y in range(32):
        for x in range(32):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                l = lit(x, y, cx, cy, rx, ry)
                mortar = y % 3 == 0 or (x + (y // 3) * 3) % 6 == 0
                if mortar:
                    c.set(x, y, "r" if l > 0.35 else "q")
                else:
                    c.set(x, y, "s" if l > 0.35 else "q" if l < -0.5 else "r")
    # Chimney with a stone cap and soot.
    c.rect(20, 1, 5, 10, "r")
    for y in range(2, 11):
        c.set(20, y, "s"); c.set(24, y, "q")
        if y % 3 == 0:
            c.hline(21, 23, y, "q")
    c.hline(19, 25, 1, "z"); c.hline(19, 25, 2, "y"); c.set(19, 1, "A")
    c.hline(21, 23, 3, "x")
    c.outline("q")
    # Stone footing.
    c.rect(3, 27, 26, 3, "y"); c.hline(3, 28, 27, "z"); c.hline(3, 28, 29, "x")
    for x in range(5, 28, 5):
        c.set(x, 28, "x")
    # Fire mouth: an arch with logs burning inside.
    c.ellipse(15.5, 24, 4.6, 4.2, "K"); c.rect(11, 24, 10, 4, "K")
    c.ellipse(15.5, 25, 3.2, 2.6, "E"); c.rect(13, 25, 6, 2, "E")
    c.ellipse(15.5, 25.6, 1.8, 1.4, "D")
    c.hline(12, 19, 27, "t"); c.set(14, 26, "t"); c.set(17, 26, "t")
    c.hline(11, 20, 21, "z")   # stone lintel
    # A small woodpile against the kiln.
    for (lx, ly) in [(26, 25), (29, 25), (27.5, 22.5)]:
        c.ellipse(lx, ly, 1.6, 1.5, "v"); c.set(int(lx), int(ly), "u")
    c.outline("x", around="yz")
    c.outline("t", around="vu")
    return c


def cottage():
    c = Canvas(32, 32)
    brick_texture(c, 4, 17, 24, 12)
    c.hline(4, 27, 17, "q")                    # shadow under the eaves
    # Roof: slate rows, lighter on the left slope.
    for y in range(4, 17):
        half = (y - 4) + 3
        for x in range(16 - half, 16 + half):
            left = x < 16
            row_line = (y - 4) % 3 == 2
            tick = (x + (y // 3) * 2) % 4 == 0 and not row_line
            if row_line:
                c.set(x, y, "B")
            elif tick:
                c.set(x, y, "B" if left else "K")
            else:
                c.set(x, y, "C" if left else "B")
    c.hline(13, 18, 4, "A")                    # ridge catching the light
    c.hline(0, 31, 16, "K")
    # Chimney.
    c.rect(21, 3, 4, 8, "r"); c.vline(21, 3, 10, "s"); c.hline(20, 25, 3, "z")
    c.hline(22, 24, 6, "q"); c.hline(22, 24, 9, "q")
    # Door with a step, windows with a flower box.
    c.rect(14, 21, 5, 8, "u"); c.vline(14, 21, 28, "v"); c.vline(16, 22, 28, "t")
    c.hline(14, 18, 21, "t"); c.set(17, 25, "D")
    c.hline(13, 19, 29, "z")
    window(c, 7, 19)
    window(c, 21, 19)
    c.hline(6, 12, 25, "u"); c.set(7, 24, "s"); c.set(9, 24, "D"); c.set(11, 24, "s")
    c.set(8, 24, "c"); c.set(10, 24, "c")
    c.hline(4, 27, 29, "y"); c.hline(4, 27, 30, "x")
    c.outline("q", around="rsquvtwyzx")
    c.outline("K")
    return c


def cottage_scaffold():
    c = Canvas(32, 32)
    c.rect(4, 29, 24, 2, "y"); c.hline(4, 27, 29, "z")
    brick_texture(c, 4, 24, 24, 5)              # the first courses of wall
    for x in (3, 15, 28):
        c.vline(x, 8, 28, "u")
    for y in (12, 19):
        c.hline(3, 28, y, "v"); c.hline(3, 28, y + 1, "t")
    for i in range(10):                         # a cross brace
        c.set(4 + i, 27 - i, "t")
    # A ladder and a pallet of bricks waiting.
    c.vline(21, 13, 28, "u"); c.vline(24, 13, 28, "u")
    for y in range(15, 28, 3):
        c.hline(22, 23, y, "v")
    c.rect(6, 20, 6, 3, "r"); c.hline(6, 11, 20, "s"); c.hline(6, 11, 23, "u")
    c.outline("t", around="uv")
    c.outline("x", around="yz")
    return c


def sawmill():
    c = Canvas(32, 32)
    # Plank walls.
    for x in range(3, 29):
        col = "t" if (x - 3) % 4 == 3 else ("v" if (x - 3) % 4 == 0 else "u")
        c.vline(x, 14, 28, col)
    c.vline(3, 14, 28, "w")
    # Roof: overlapping slate rows, one pitch, lit along the top.
    for y in range(4, 15):
        inset = max(0, (14 - y) // 3)
        for x in range(1 + inset, 31 - inset):
            c.set(x, y, "B" if (y - 4) % 3 == 2 else ("C" if x < 18 else "B"))
    c.hline(5, 26, 4, "A")
    c.hline(1, 30, 14, "K")
    # Open front with the saw.
    c.rect(13, 18, 15, 11, "j")
    c.ellipse(20.5, 22, 4.4, 4.4, "z")
    c.ellipse(20.5, 22, 2.4, 2.4, "y")
    c.set(20, 21, "x"); c.set(21, 22, "x")
    for k in range(10):
        a = TAU * k / 10
        c.set(int(20.5 + 4.6 * math.cos(a)), int(22 + 4.6 * math.sin(a)), "A")
    c.rect(13, 26, 15, 2, "u"); c.hline(13, 27, 26, "v")      # carriage
    c.rect(14, 24, 6, 2, "v"); c.ellipse(14.5, 25, 1.3, 1.2, "w")  # log
    c.rect(24, 27, 4, 2, "w"); c.set(25, 26, "m")              # sawdust
    window(c, 6, 18, 4, 4)
    # Planks stacked outside.
    for y in (26, 27, 28):
        c.hline(2, 10, y, "w" if y % 2 == 0 else "v")
    c.outline("t", around="uvwj")
    c.outline("K")
    return c


def storage_crate():
    c = Canvas(16, 16)
    c.rect(2, 3, 12, 12, "v")
    for y in range(5, 15, 3):
        c.hline(3, 12, y, "u")
    c.hline(2, 13, 3, "w"); c.vline(2, 3, 14, "w")
    for i in range(10):
        c.set(3 + i, 13 - i, "t"); c.set(4 + i, 13 - i, "u")
    c.vline(13, 3, 14, "u"); c.hline(2, 13, 14, "u")
    for (x, y) in [(2, 3), (13, 3), (2, 14), (13, 14)]:
        c.set(x, y, "z")
    c.outline("t")
    return c


def foundation(stage=0):
    """The empty foundation, or stages 1 to 4 with bricks laid from the front."""
    c = Canvas(32, 32)
    c.rect(2, 4, 28, 26, "k")
    speckle(c, random.Random(3), ["l", "j"], [0.08, 0.05], only="k")
    if stage:
        rows = 22 * stage // 4
        brick_texture(c, 4, 28 - rows, 24, rows, light="s", mid="r", mortar="q", lit_cols=0)
        c.hline(4, 27, 28 - rows, "s")
    for x in range(2, 30):
        c.set(x, 4, "z"); c.set(x, 5, "y"); c.set(x, 28, "y"); c.set(x, 29, "x")
    for y in range(4, 30):
        c.set(2, y, "z"); c.set(3, y, "y"); c.set(28, y, "y"); c.set(29, y, "x")
    for x in range(5, 28, 4):
        c.set(x, 4, "A")
    for (x, y) in [(1, 2), (30, 2), (1, 30), (30, 30)]:
        c.vline(x, y - 1, y + 1, "u"); c.set(x, y - 1, "v")
    for x in range(4, 28, 2):
        c.set(x, 2, "F")
    c.outline("j")
    return c


def builders_yard():
    c = Canvas(32, 32)
    c.rect(2, 6, 28, 23, "k")
    speckle(c, random.Random(5), ["l"], [0.07], only="k")
    for x in range(1, 31):
        c.set(x, 6, "v"); c.set(x, 7, "u"); c.set(x, 29, "u")
    for y in range(6, 30):
        c.set(1, y, "v"); c.set(30, y, "u")
    for x in range(1, 31, 4):
        c.vline(x, 4, 6, "v"); c.set(x, 4, "w")
    c.rect(13, 29, 6, 1, "k")                    # the gate
    # A small shed with a slate roof.
    c.rect(4, 10, 8, 7, "u"); c.vline(4, 10, 16, "v")
    for y in range(8, 11):
        c.hline(3, 12, y, "C" if y < 10 else "B")
    c.rect(7, 13, 2, 4, "t")
    # Brick stack and plank stack.
    for row in range(3):
        for col in range(3 - row % 2):
            x = 5 + col * 4 + (row % 2) * 2
            y = 24 - row * 3
            c.rect(x, y, 4, 2, "r"); c.hline(x, x + 3, y, "s"); c.set(x + 3, y + 1, "q")
    for row in range(4):
        y = 24 - row * 2
        c.hline(18, 27, y, "w"); c.hline(18, 27, y + 1, "v")
    c.set(17, 25, "t"); c.set(28, 25, "t")
    # Sawhorse.
    c.hline(16, 24, 12, "u"); c.hline(16, 24, 11, "v")
    for (x, y) in [(17, 13), (23, 13), (16, 14), (24, 14)]:
        c.set(x, y, "t")
    c.outline("t", around="uvwrsqC")
    return c


# ---------------------------------------------------------------- belts

def belt(kind):
    """Belts run along a band from column/row 3 to 12. Chevrons point the way items move."""
    c = Canvas(16, 16)
    band = range(3, 13)
    if kind == "h":
        for y in band:
            c.hline(0, 15, y, "y")
        c.hline(0, 15, 3, "x"); c.hline(0, 15, 12, "x"); c.hline(0, 15, 4, "z"); c.hline(0, 15, 11, "x")
        for x0 in (1, 9):
            for i in range(3):
                c.set(x0 + i, 6 + i, "A"); c.set(x0 + i, 10 - i, "A")
        for x in range(0, 16, 4):
            c.set(x, 3, "z")
        return c
    if kind == "v":
        for x in band:
            c.vline(x, 0, 15, "y")
        c.vline(3, 0, 15, "x"); c.vline(12, 0, 15, "x"); c.vline(4, 0, 15, "z"); c.vline(11, 0, 15, "x")
        for y0 in (1, 9):
            for i in range(3):
                c.set(6 + i, y0 + i, "A"); c.set(10 - i, y0 + i, "A")
        for y in range(0, 16, 4):
            c.set(3, y, "z")
        return c
    vertical, horizontal = kind[0], kind[1]
    ys = range(0, 13) if vertical == "n" else range(3, 16)
    xs = range(3, 16) if horizontal == "e" else range(0, 13)
    for y in ys:
        c.hline(3, 12, y, "y")
    for x in xs:
        c.vline(x, 3, 12, "y")
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
    c.ellipse(4, 4.5, 3, 2.6, "o"); c.set(2, 3, "p"); c.set(3, 3, "p"); c.set(5, 5, "n")
    c.outline("n")
    return c


def item_log():
    c = Canvas(8, 8)
    c.rect(1, 3, 6, 3, "u"); c.hline(1, 6, 3, "v"); c.set(4, 4, "t")
    c.ellipse(1.8, 4.5, 1.4, 1.6, "w"); c.set(1, 4, "v")
    c.outline("t")
    return c


def item_brick():
    c = Canvas(8, 8)
    c.rect(1, 3, 6, 3, "r"); c.hline(1, 6, 3, "s"); c.vline(1, 3, 5, "s"); c.set(5, 5, "q")
    c.outline("q")
    return c


def item_plank():
    c = Canvas(8, 8)
    c.rect(0, 4, 8, 2, "w"); c.hline(0, 7, 5, "v"); c.set(3, 4, "v")
    c.outline("u")
    return c


# ---------------------------------------------------------------- people (8x12)

PERSON = {
    # j hair, p skin, s shirt, C trousers, K shoes; villagers recolour these.
    "front": [
        ["..jjjj..", ".jjjjjj.", ".jppppj.", ".pKppKp.", "..pppp..", "..ssss..",
         ".ssssss.", "p.ssss.p", "..CCCC..", "..C..C..", "..C..C..", "..K..K.."],
        ["..jjjj..", ".jjjjjj.", ".jppppj.", ".pKppKp.", "..pppp..", "..ssss..",
         ".ssssss.", "p.ssss.p", "..CCCC..", "..C..C..", ".C....C.", ".K....K."],
    ],
    "side": [
        ["..jjjj..", ".jjjjj..", ".jjpppp.", ".jjpKp..", "..ppppp.", "..sss...",
         "..ssss..", "..spss..", "..CCC...", "..CC....", "..CC....", "..KK...."],
        ["..jjjj..", ".jjjjj..", ".jjpppp.", ".jjpKp..", "..ppppp.", "..sss...",
         "..ssss..", "..ssps..", "..CCC...", ".C..C...", "C....C..", "K....K.."],
    ],
    "back": [
        ["..jjjj..", ".jjjjjj.", ".jjjjjj.", ".jjjjjj.", "..jppj..", "..ssss..",
         ".ssssss.", "p.ssss.p", "..CCCC..", "..C..C..", "..C..C..", "..K..K.."],
        ["..jjjj..", ".jjjjjj.", ".jjjjjj.", ".jjjjjj.", "..jppj..", "..ssss..",
         ".ssssss.", "p.ssss.p", "..CCCC..", "..C..C..", ".C....C.", ".K....K."],
    ],
}
VILLAGERS = "j=m,s=f,C=t,p=w | j=K,s=c,C=x,p=l | j=u,s=D,C=B,p=k | j=A,s=v,C=u,p=w | j=t,s=h,C=j,p=p"


def person(view, frame):
    c = Canvas(8, 12)
    c.pixels(PERSON[view][frame])
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
                if (x + y) % 2 == 0 and c.get(x, y) == "A":
                    c.set(x, y, ".")
    return c


def pop(frame):
    c = Canvas(16, 16)
    radius = {1: 2.5, 2: 5, 3: 7}[frame]
    steps = {1: 8, 2: 12, 3: 10}[frame]
    for k in range(steps):
        angle = TAU * k / steps
        x = int(round(7.5 + radius * math.cos(angle)))
        y = int(round(7.5 + radius * math.sin(angle) * 0.7))
        c.set(x, y, "m" if frame < 3 else "l")
        if frame == 1:
            c.set(x, y + 1, "l")
    if frame == 1:
        c.rect(7, 7, 2, 2, "F")
    return c


# ---------------------------------------------------------------- icons and UI

def icon(name):
    c = Canvas(16, 16)
    if name == "build":
        for i in range(8):
            c.set(4 + i, 12 - i, "u"); c.set(5 + i, 12 - i, "t")
        c.rect(9, 2, 6, 3, "z"); c.hline(9, 14, 2, "A"); c.set(14, 4, "y")
    elif name == "trace":
        for (x, y) in [(3, 12), (8, 6), (13, 3)]:
            c.ellipse(x + 0.5, y + 0.5, 2, 2, "D"); c.set(x - 1, y - 1, "F")
        for i in range(5):
            c.set(4 + i, 11 - i, "E"); c.set(9 + i, 5 - i // 2, "E")
    elif name == "undo":
        c.pixels(["....F...........", "...FF...........", "..FFFFFFFFF.....", ".FFFFFFFFFFFF...",
                  "..FFFFFFFFFFFF..", "...FF......FFF..", "....F.......FF..", "............FF..",
                  "...........FFF..", "......FFFFFFF...", "......FFFFFF...."], 0, 3)
    elif name == "demolish":
        c.rect(2, 6, 12, 5, "r"); c.hline(2, 13, 6, "s")
        for i in range(10):
            c.set(3 + i, 3 + i, "F"); c.set(12 - i, 3 + i, "F")
    elif name == "play_pause":
        for y in range(3, 13):
            c.hline(2, 2 + max(0, 5 - abs(8 - y)), y, "F")
        c.rect(10, 3, 2, 10, "F"); c.rect(13, 3, 2, 10, "F")
    elif name == "pause":
        c.rect(4, 3, 3, 10, "F"); c.rect(9, 3, 3, 10, "F")
    elif name.startswith("speed_"):
        count = {"speed_1": 1, "speed_2": 2, "speed_4": 3}[name]
        start = 8 - (count * 5) // 2
        for k in range(count):
            for y in range(3, 13):
                half = min(y - 3, 12 - y)
                c.hline(start + k * 5, start + k * 5 + half, y, "F")
    elif name == "cancel":
        for i in range(10):
            for d in (0, 1):
                c.set(3 + i + d, 3 + i, "F"); c.set(12 - i + d, 3 + i, "F")
    elif name == "bricks":
        for (x, y) in [(2, 10), (8, 10), (5, 6)]:
            c.rect(x, y, 6, 3, "r"); c.hline(x, x + 5, y, "s")
    elif name == "goal":
        c.vline(4, 2, 14, "u"); c.set(4, 1, "D")
        for y in range(2, 8):
            c.hline(5, 12 - abs(5 - y), y, "E" if y > 4 else "D")
    elif name == "hand":
        c.pixels(["......F.F.......", ".....FF.FF.F....", ".....FF.FF.FF...", ".....FF.FF.FF...",
                  "..FF.FFFFFFFF...", "..FFFFFFFFFFF...", "...FFFFFFFFFF...", "....FFFFFFFF....",
                  ".....FFFFFF.....", ".....FFFFFF....."], 0, 3)
    elif name == "belt":
        c.rect(1, 5, 14, 6, "y"); c.hline(1, 14, 5, "z"); c.hline(1, 14, 10, "x")
        for x0 in (3, 9):
            for i in range(2):
                c.set(x0 + i, 7 + i, "A"); c.set(x0 + i, 8 - i + 1, "A")
    elif name == "sound":
        c.rect(2, 6, 3, 4, "F")
        for i in range(4):
            c.vline(5 + i, 6 - i, 9 + i, "F")
        for k, r in enumerate((3, 5)):
            for a in range(-3, 4):
                c.set(int(9 + r * math.cos(a * 0.35)), int(8 + r * math.sin(a * 0.35)), "F")
    elif name == "settings":
        c.ellipse(8, 8, 5, 5, "F"); c.ellipse(8, 8, 2, 2, ".")
        for k in range(8):
            a = TAU * k / 8
            c.rect(int(7.5 + 6 * math.cos(a)), int(7.5 + 6 * math.sin(a)), 2, 2, "F")
    c.outline("K")
    return c


def ui_panel():
    """A 16x16 tile for nine-slice panels: 5-pixel corners, a stretchable middle."""
    c = Canvas(16, 16, "F")
    c.hline(0, 15, 0, "K"); c.hline(0, 15, 15, "K"); c.vline(0, 0, 15, "K"); c.vline(15, 0, 15, "K")
    c.hline(1, 14, 1, "A"); c.vline(1, 1, 14, "A"); c.hline(1, 14, 14, "m"); c.vline(14, 1, 14, "m")
    for (x, y) in [(0, 0), (15, 0), (0, 15), (15, 15)]:
        c.set(x, y, ".")
    return c


def ui_highlight():
    """Corner brackets that pulse around the tile the tutorial points at."""
    c = Canvas(16, 16)
    for (x, y, dx, dy) in [(0, 0, 1, 1), (15, 0, -1, 1), (0, 15, 1, -1), (15, 15, -1, -1)]:
        for i in range(5):
            c.set(x + dx * i, y, "D"); c.set(x, y + dy * i, "D")
            c.set(x + dx * i, y + dy, "E"); c.set(x + dx, y + dy * i, "E")
    return c


def ui_banner():
    """A ribbon tile for the goal banner; repeat the middle column to stretch."""
    c = Canvas(16, 16)
    c.rect(0, 4, 16, 8, "E"); c.hline(0, 15, 4, "D"); c.hline(0, 15, 11, "n")
    c.hline(0, 15, 3, "K"); c.hline(0, 15, 12, "K")
    return c


def ui_trace_dot():
    c = Canvas(16, 16)
    c.ellipse(8, 8, 3, 3, "D"); c.set(7, 6, "F"); c.outline("E")
    return c


def ui_tile_cursor():
    """The outline under a finger while choosing where to build."""
    c = Canvas(16, 16)
    for i in range(16):
        if i % 3 != 2:
            c.set(i, 0, "F"); c.set(i, 15, "F"); c.set(0, i, "F"); c.set(15, i, "F")
    return c


# ---------------------------------------------------------------- the list

SPRITES = {
    # name: (drawing, header)
    "terrain_grass_1": (lambda: grass(1), {}),
    "terrain_grass_2": (lambda: grass(2, light=0.12, dark=0.06, flowers=True), {}),
    "terrain_grass_3": (lambda: grass(3, light=0.02, dark=0.22), {}),
    "terrain_water": (water, {"frames": "roll-x 2 3"}),
    "terrain_shore": (TERRAIN["shore"], {}),
    "terrain_dirt": (TERRAIN["dirt"], {}),
    "terrain_clay_ground": (TERRAIN["clay_ground"], {}),
    "terrain_paper_fog": (paper_fog, {}),
    "nature_tree": (tree, {"variants": "3", "recolor": "c=b,d=c,b=a", "frames": "sway 7 2"}),
    "nature_clay_marker": (clay_marker, {}),
    "nature_rock": (rock, {"variants": "2"}),
    "clay_pit": (clay_pit, {"variants": "3", "recolor": "l=m,m=F"}),
    "lumber_camp": (lumber_camp, {"variants": "3"}),
    "brick_kiln": (brick_kiln, {"recolor": "q=n,r=o,s=p | y=k,z=l,x=j", "frames": "swap E=D,D=E 2", "glow": "E,D"}),
    "sawmill": (sawmill, {"recolor": "C=u,B=t | u=l,v=m,t=k", "night": "e=D,h=F"}),
    "storage_crate": (storage_crate, {"variants": "2"}),
    "foundation": (foundation, {"variants": "2"}),
    "foundation_1": (lambda: foundation(1), {}),
    "foundation_2": (lambda: foundation(2), {}),
    "foundation_3": (lambda: foundation(3), {}),
    "foundation_4": (lambda: foundation(4), {}),
    "cottage": (cottage, {"recolor": "C=m,B=l | r=m,s=F,q=l,C=s,B=r", "night": "e=D,h=F"}),
    "cottage_scaffold": (cottage_scaffold, {}),
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
    "ui_panel": (ui_panel, {}),
    "ui_highlight": (ui_highlight, {}),
    "ui_banner": (ui_banner, {}),
    "ui_trace_dot": (ui_trace_dot, {}),
    "ui_tile_cursor": (ui_tile_cursor, {}),
}
for _name in ["build", "trace", "undo", "demolish", "play_pause", "pause", "speed_1", "speed_2", "speed_4",
              "cancel", "bricks", "goal", "hand", "belt", "sound", "settings"]:
    SPRITES[f"icon_{_name}"] = ((lambda n: lambda: icon(n))(_name), {})
for _terrain in TERRAIN:
    for _side in ["n", "e", "s", "w", "ne", "nw", "se", "sw"]:
        SPRITES[f"edge_{_terrain}_{_side}"] = ((lambda t, s: lambda: edge(t, s))(_terrain, _side), {})
for _view in PERSON:
    for _frame in range(2):
        SPRITES[f"person_{_view}_{_frame}"] = ((lambda v, f: lambda: person(v, f))(_view, _frame),
                                                {"recolor": VILLAGERS, "flaws": "no"})


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
