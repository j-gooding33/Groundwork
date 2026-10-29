#!/usr/bin/env bash
# Renders screenshots of the real game (no Mac needed) into docs/screenshots.
# Needs Swift on PATH and a built atlas (python3 Tools/make_art.py).
set -euo pipefail
cd "$(dirname "$0")/.."
python3 Tools/make_art.py >/dev/null
(cd GroundworkCore && swift run -c release GroundworkPreview "$PWD/../docs/screenshots")
python3 Tools/rgba_to_png.py docs/screenshots
