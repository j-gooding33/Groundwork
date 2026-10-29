# Running Groundwork on a Mac

The game code is written: the simulation (`GroundworkCore`), everything the app decides (`GroundworkView`), and the iPhone app itself (`App/Groundwork`, SwiftUI and SpriteKit). The first two are tested on Linux. The app layer has only been checked with stand-ins for Apple's frameworks, so **expect a short round of compile fixes the first time you build it in Xcode**. Paste any errors to Claude Code and it will fix them.

Screenshots of what the app should look like, rendered from the real code: `docs/screenshots/`.

## 1. Set up the Xcode project (once)

1. Install Xcode, open it once, and let it install the iOS simulator.
2. Clone the repo, then in Xcode: **File → New → Project → iOS → App**.
   - Product name `Groundwork`, interface **SwiftUI**, language **Swift**, no tests or storage.
   - Save it inside the cloned repo folder.
3. Delete the two files Xcode made for you, `ContentView.swift` and `GroundworkApp.swift` (Move to Trash). `App/Groundwork/` has its own.
4. Drag the `App/Groundwork` folder from Finder into the project navigator. Untick "Copy items if needed" and tick the Groundwork target.
5. **File → Add Package Dependencies → Add Local…**, choose the `GroundworkCore` folder, and add **both** libraries, `GroundworkCore` and `GroundworkView`, to the Groundwork target.
6. Drag `Data/` and `Art/generated/` into the project as **folder references** (blue folders), ticking the Groundwork target. The app looks for `Data/...` and `generated/atlas.png` / `generated/atlas.json` inside the bundle.
7. In the target's **General** tab:
   - Minimum deployment **iOS 17.0**.
   - Device orientation: **Landscape Left** and **Landscape Right** only.
   - Tick **Requires full screen**.
8. Choose an iPhone simulator and press **Run** (Cmd+R). If anything fails to compile, copy the errors to Claude Code.
9. Optional: open `GroundworkCore/Package.swift` in Xcode and run its tests (Cmd+U). They should pass on macOS exactly as on Linux.

To play on your own iPhone, sign in under **Settings → Accounts** with a free Apple ID, pick your team under **Signing & Capabilities**, plug in the phone and Run.

## 2. How it fits together

| Layer | Where | What it does | Tested |
| --- | --- | --- | --- |
| Simulation | `GroundworkCore` | World, ticks, production, belts, Trace, levels, saving | Linux, 98 tests |
| Presentation | `GroundworkView` | Which sprites to draw and where, terrain edges, belt pieces, item gliding, villagers, day and night, camera, touch gestures, tools, effects, HUD contents, autosave timing | Linux, 29 tests and the screenshots |
| App | `App/Groundwork` | Puts those sprites on screen with SpriteKit, the HUD with SwiftUI, plays haptics and sound | Stand-in type-check only, until Xcode |

The rule that keeps this working: **the app only reads `GameSession` and sends it commands, and makes no decisions of its own.** If something needs deciding (what a tap does, what to draw), it goes in `GroundworkView` with a test.

### App files

- `GroundworkApp.swift`: entry point; saves whenever the app leaves the foreground.
- `GameStore.swift`: owns the `GameSession`, the camera and input state. Runs the frame loop: ticks, effects, HUD refresh, autosave every 30 seconds. Turns touches into gestures and commands, and saves to Application Support.
- `TitleView.swift`: the blank-paper opening, Continue, New game (level select) and Settings (sound, haptics).
- `GameView.swift`: the world fills the screen, with controls at the edges:
  - build palette on the left;
  - goal bar and clock on top;
  - selected building on the right (status, rates, "runs out in", Pick up, Trace);
  - mode tabs at the bottom (Build, Trace, Undo to start; Demolish and speed after the tutorial);
  - tutorial bubble, toasts, the goal card and the pause menu.
- `WorldScene.swift`: an `SKScene` at 480×270, scaled up with nearest-neighbour filtering. It matches one node per sprite id to `SceneBuilder`'s output each frame, moves the camera, applies the day/night tint, and plays bounces, squashes, dust, floating "+1"s and the goal light sweep.
- `Atlas.swift`: textures from `atlas.png`, nearest filtering.
- `Feel.swift`: haptics, plus placeholder sound generated in code: a machine hum that follows throughput, every sound cue, and a soft music pad that gains layers with each milestone.
- `Theme.swift`: colours from the palette and atlas icons for SwiftUI.

### Controls

- **Tap a building with no tool:** pick up what it has made, or drop what you're carrying. Its panel opens either way.
- **Build palette:** tap a building, then tap the map; 2×2 buildings centre under your finger. Tap the selected button again to put the tool down.
- **Belt:** choose it in the palette, then drag from a building to where the belt should go. A ghost shows the route before you let go.
- **Trace tab:** tap a building to see its chain. Gold dots flow along working links, a red marker bobs over the step to fix, and the right-hand panel lists every step with its state and reason. Tap a row to jump the camera there.
- **Status bubbles** appear over stuck machines without opening anything: the missing item's icon, an up-arrow for a full output, a slashed circle for a used-up source, an hourglass for running slow.
- **Rates tab** (after the tutorial): labels under each working building with made and used per minute, and a warning when an input will run out within a minute.
- **Tutorial:** tap the bubble to tuck it away and "?" to bring it back. A gentle hint appears if a machine has been stuck for 30 seconds. **Skip tutorial** is in the pause menu.
- **Long press:** open a building's panel. **One finger:** pan. **Pinch:** zoom.

## 3. Day-to-day commands

| Task | Command |
| --- | --- |
| Simulation and view tests | `cd GroundworkCore && swift test` |
| Rebuild the sprite atlas after editing art | `python3 Tools/make_art.py` |
| Render screenshots of the real game | `bash Tools/preview.sh`, writes `docs/screenshots/` |
| Check app code without a Mac | `bash Tools/check_app.sh` |
| Performance check | `cd GroundworkCore && swift run -c release GroundworkBench` |

Edit sprites as text grids in `Art/sprites/`, or hand-paint PNGs into `Art/manual/` (they always win). Rebuild the atlas afterwards; the app picks up `Art/generated/` on the next build.

## 4. Known gaps

- **Not yet built against Apple's SDK.** The stand-ins match the real API as closely as I know it, but expect a few compile fixes.
- **Performance on a device is unmeasured.** The static layer (terrain, edges, trees) is about 5,000 sprite nodes drawn from one texture. If it's slow on an older iPhone, render that layer to a single texture once with `SKView.texture(from:)`.
- **Sound is generated placeholder tones.** Replace the buffers in `Feel.swift` with real audio when it exists.
- **Text uses the system monospaced font,** not a pixel font.
- **The balance numbers in `Data/` are placeholders.** Play it and tune.
