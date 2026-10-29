#!/usr/bin/env python3
"""Tests for make_art.py. Run: python3 -m unittest discover -s Tools -p 'test_*.py'"""
import json
import shutil
import tempfile
import unittest
from pathlib import Path

import make_art as M


class ArtCheckTests(unittest.TestCase):
    def setUp(self):
        self.palette = json.loads((M.ART / "palette.json").read_text())
        self.buildings = {b["id"]: b for b in json.loads((M.ROOT / "Data" / "buildings.json").read_text())}

    def sprite(self, name, grid, **header):
        header.setdefault("size", f"{len(grid[0])}x{len(grid)}")
        return {"name": name, "header": header, "grid": grid}

    def problems(self, sprite):
        found = []
        M.check_sprite(sprite, self.palette, self.buildings, found)
        return found

    def test_real_sprites_pass(self):
        found = []
        palette = M.load_palette(found)
        for path in sorted(M.SPRITES.glob("*.txt")):
            sprite = M.parse_sprite(path, found)
            M.check_sprite(sprite, palette, self.buildings, found)
        self.assertEqual(found, [])

    def test_off_palette_pixel_fails(self):
        grid = ["c" * 16] * 15 + ["c" * 15 + "#"]
        self.assertTrue(any("off-palette pixel '#' at (15, 15)" in p for p in self.problems(self.sprite("terrain_x", grid))))

    def test_wrong_size_fails(self):
        grid = ["c" * 15] * 16
        found = self.problems(self.sprite("terrain_x", grid, size="16x16"))
        self.assertTrue(any("expected 16x16" in p for p in found), found)

    def test_buildings_are_two_by_two_tiles(self):
        grid = ["r" * 16] * 16
        found = self.problems(self.sprite("brick_kiln", grid, variants="3"))
        self.assertTrue(any("expected 32x32" in p for p in found), found)

    def test_building_without_variants_fails(self):
        grid = ["v" * 16] * 16
        found = self.problems(self.sprite("storage_crate", grid))
        self.assertTrue(any("variants" in p for p in found), found)

    def test_variants_change_only_a_pixel_or_two(self):
        grid = ["rrrrsss."] * 8
        for seed in range(20):
            out = M.variant(grid, seed, self.palette)
            changed = sum(a != b for ra, rb in zip(grid, out) for a, b in zip(ra, rb))
            self.assertIn(changed, (1, 2))
            self.assertTrue(all(ch in "qrs." for row in out for ch in row), "Stays in the brick ramp")

    def test_night_version_lights_windows(self):
        sprite = self.sprite("cottage", ["Br" * 16] * 32, variants="2", night="B=D", flaws="no")
        names = dict(M.expand(sprite, self.palette))
        self.assertEqual(sorted(names), ["cottage", "cottage_glow", "cottage_night", "cottage_v1",
                                         "cottage_v1_glow", "cottage_v1_night"])
        self.assertTrue(all(ch in "Dr" for row in names["cottage_night"] for ch in row))
        # The glow holds only the pixels that light up, so it can sit above the night tint.
        self.assertTrue(all(ch in "D." for row in names["cottage_glow"] for ch in row))
        self.assertEqual(names["cottage_glow"][0][:2], "D.")

    def test_stage_names_take_their_buildings_size(self):
        self.assertEqual(M.expected_size("foundation_2", self.buildings), (32, 32))
        self.assertEqual(M.expected_size("cottage_scaffold", self.buildings), (32, 32))
        self.assertEqual(M.expected_size("clay_pit", self.buildings), (16, 16))
        self.assertEqual(M.expected_size("person_side_0", self.buildings), (8, 12))

    def test_recolor_variants(self):
        sprite = self.sprite("person_front_0", ["sC"] * 2, recolor="s=f | s=c,C=x", flaws="no")
        names = dict(M.expand(sprite, self.palette))
        self.assertEqual(names["person_front_0_v1"], ["fC", "fC"])
        self.assertEqual(names["person_front_0_v2"], ["cx", "cx"])

    def test_swap_frames_animate_every_version(self):
        sprite = self.sprite("brick_kiln", ["ED"] * 32, recolor="q=n", frames="swap E=D,D=E 2")
        names = dict(M.expand(sprite, self.palette))
        self.assertIn("brick_kiln_v1_f1", names)
        self.assertEqual(names["brick_kiln_f1"][0], "DE")

    def test_png_round_trip(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            rows = [[(26, 28, 44, 255), (0, 0, 0, 0)], [(255, 244, 214, 255), (74, 154, 72, 255)]]
            M.write_png(tmp / "a.png", 2, 2, rows)
            self.assertEqual(M.read_png(tmp / "a.png"), (2, 2, rows))
        finally:
            shutil.rmtree(tmp)


if __name__ == "__main__":
    unittest.main()
