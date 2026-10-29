# Groundwork
iOS landscape pixel-art factory and town builder. Swift, SpriteKit for the world, SwiftUI for menus, iOS 17+.

- Design: docs/DESIGN.md. Read the relevant section before each task.
- App hand-over: docs/INTEGRATION.md explains how SpriteKit and SwiftUI plug into GameSession.
- Build plan, data formats, GameSession API and design decisions: docs/PLAN.md. Follow it; if it conflicts with DESIGN.md, PLAN.md's "Contradictions" section wins.

## Current track
No Mac yet. Linux cloud sessions cover phases 0 to 5: GroundworkCore, data, Trace, belts, Level 1 as data, the art pipeline and docs/INTEGRATION.md. These are done. Rendering, touch UI and sound wait for the Mac (master prompt phases 6 to 11, starting from docs/INTEGRATION.md). Without a Mac, work is limited to the simulation, data, art and tests.

Scope is Prototype 1 only: clay pit, lumber camp, brick kiln, sawmill, storage crate, foundation, builder's yard, cottage, hand carry, belts, one demand rule, Trace, saving, the Level 1 script. No citizens, shops, taxes, roads, rail, power grids, data networks, islands, Walk Mode or character creator. Ask before going outside this.

## Rules
- All game logic lives in the GroundworkCore Swift package. Standard library and Foundation only: no UIKit, SpriteKit, SwiftUI or other Apple-only imports, so it builds on Linux and macOS.
- Content is data. Recipes, buildings, levels, tutorial steps and maps are files in Data/. Never hard-code a recipe, cost, rate or level goal in Swift.
- Fixed simulation tick of 10 per second. Fast-forward runs more ticks, never longer ticks. Integer maths only.
- Determinism: the same save and the same inputs give identical results. No randomness without the seeded generator stored in the save.
- Everything on the map is a Codable value type. The simulation never knows sprites exist.
- Belts move items as discrete slots, not physics.
- Trace is a pure function that works headless.
- The renderer and UI talk only to GameSession.
- Every new system gets XCTest unit tests in GroundworkCore.
- Art: one 32-colour palette (Art/palette.json), sprites as text grids in Art/sprites, 16x16 tiles. Hand-edited PNGs in Art/manual always win and are never overwritten. Tools are Python 3, standard library only.
- No third-party dependencies without asking.

## Commands
- Install Swift (once per new cloud container): `bash Tools/install_swift_linux.sh`, then `export PATH=/opt/swift-image/usr/bin:$PATH`
- Test: `cd GroundworkCore && swift test`
- Art: `python3 Tools/make_art.py` (checks sprites, builds Art/generated/atlas.png, atlas.json and Art/contact_sheet.png); `--check` only validates
- New sprites: draw them as text grids in Art/sprites, or add them to Tools/draw_sprites.py (it never overwrites existing grids)
- Art tests: `cd Tools && python3 -m unittest test_make_art`

## How to work
- One phase at a time. After each phase: run `swift test`, fix failures, commit with a clear message, push, then stop and report (what works, what was tested, what to check, what is uncertain). Wait for "go" before the next phase.
- If tests fail twice for the same reason, stop and say what was tried.
- Don't delete or rewrite working code to tidy up unless asked.
- Be honest that you can't feel the game. Say what needs human play-testing.

## Definition of done
Tests pass, the change is committed and pushed, and CLAUDE.md is updated if a rule changed.
