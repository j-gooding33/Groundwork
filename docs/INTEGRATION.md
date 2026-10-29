# Plugging the iOS app into GroundworkCore

This is the hand-over for the Mac session (master prompt phases 6 to 11). The simulation, Trace, belts, levels and the art atlas are done and tested on Linux. The app's job is to **draw what `GameSession` says exists and send it the player's taps**. The app never changes the world any other way.

## 1. Project setup (once, in Xcode)

1. Clone the repo and create the iOS app inside it: iOS App, Swift, SwiftUI, named Groundwork, landscape only (Landscape Left and Right), iOS 17.
2. **File → Add Package Dependencies → Add Local…** and pick `GroundworkCore/`. Link the `GroundworkCore` library to the app target.
3. Drag `Data/` and `Art/generated/` into the app as **folder references** (blue folders), so the files keep their paths inside the bundle.
4. Open `GroundworkCore/Package.swift` in Xcode and run its tests (Cmd+U). They should pass on macOS exactly as on Linux. Do this before writing any app code.

```swift
import GroundworkCore

let dataURL = Bundle.main.url(forResource: "Data", withExtension: nil)!
let content = try ContentDatabase.load(from: dataURL)   // throws a readable list of problems if data is broken
let session = try GameSession(content: content, level: "level1")
```

`GameSession` is not thread-safe. Keep it on the main thread; SpriteKit's `update(_:)` already runs there.

## 2. The frame loop

```swift
final class WorldScene: SKScene {
    var session: GameSession!
    var clock = TickClock()          // speed 1; set clock.speed = 2 or 4 for fast-forward, 0 to pause
    private var last: TimeInterval?

    override func update(_ now: TimeInterval) {
        defer { last = now }
        guard let last else { return }
        session.advance(ticks: clock.ticks(forElapsed: now - last))
        for event in session.drainEvents() { react(to: event) }   // sounds, haptics, effects
        sync(with: session.world, fraction: clock.fraction)        // move nodes to match the world
    }
}
```

- The simulation runs at exactly 10 ticks per second whatever the frame rate. Fast-forward means more ticks, never longer ones.
- `clock.fraction` (0 to 1) is how far the next tick has progressed. Use it to glide belt items between slots. It is for drawing only.
- While the first tutorial step shows, `advance` does nothing (`session.isPausedByTutorial`). That's deliberate.

## 3. Drawing the world

**Coordinates.** `GridPoint(x, y)` has y growing *south*, with (0, 0) in the north-west corner. SpriteKit's y grows up. For a sprite of `w × h` tiles at `origin`:

```swift
let tile: CGFloat = 16
func position(_ origin: GridPoint, w: Int, h: Int, mapHeight: Int) -> CGPoint {
    CGPoint(x: (CGFloat(origin.x) + CGFloat(w) / 2) * tile,
            y: (CGFloat(mapHeight - origin.y) - CGFloat(h) / 2) * tile)
}
```

**Low resolution.** Make the scene 480×270 points of world (`scaleMode = .aspectFill`), put the camera on an `SKCameraNode`, and set `filteringMode = .nearest` on every texture so pixels stay crisp.

**Atlas.** `Art/generated/atlas.png` plus `atlas.json` (`sprites[name] = {x, y, w, h}`, top-left origin, in pixels). Cut sub-textures with `SKTexture(rect:in:)`. SpriteKit's rect is normalised and bottom-left based, so flip y: `rect.y = 1 - (y + h) / atlasHeight`.

| What | Sprite name |
| --- | --- |
| Terrain `grass`, `grassLight`, `grassDark` | `terrain_grass_1`, `terrain_grass_2`, `terrain_grass_3` |
| `water`, `shore`, `dirt`, `clayGround` | `terrain_water`, `terrain_shore`, `terrain_dirt`, `terrain_clay_ground` |
| `forest` / `rock` tile | grass underneath, then `nature_tree` (variants `_v1`, `_v2`) / `nature_rock` on top |
| Clay deposit tiles | `terrain_clay_ground`, with `nature_clay_marker` on some |
| Unexplored edge | `terrain_paper_fog` |
| Building of type `T` | `T`, or `T_v1`, `T_v2` (pick by `id % variants`); cottage at night: `cottage_night` |
| Belt flowing east or south | `belt_h` / `belt_v`, animated with `_f1`, `_f2`, `_f3`. For west use `belt_h` with `xScale = -1`; for north use `belt_v` with `yScale = -1`, so the chevrons point the way items move |
| Belt corner | `belt_ne`, `belt_nw`, `belt_se`, `belt_sw` (named by the two edges it joins: its own exit edge and the edge it is fed from) |
| Items on belts and in hands | `item_clay`, `item_log`, `item_brick`, `item_plank` (8×8) |
| Effects | `fx_pop_1…3` (placing), `fx_smoke_1…3` (chimneys, 8×8) |
| UI | `icon_build`, `icon_trace`, `icon_undo`, `icon_demolish`, `icon_play_pause`, `icon_cancel`, `icon_bricks`, `icon_goal` |

Skip drawing a tree or marker under a building's footprint.

**Belts.** `world.belts` is an array of `BeltTile { point, direction, slots, pullsFrom }`. A tile is a corner when the belt feeding it (the one whose `next` is this tile, from behind or the side) comes in at a right angle to its `direction`. Slot `s` of `n` sits `(s + 0.5) / n` of the way across the tile in `direction`. Glide it forward by `fraction / beltTicksPerSlot` of a slot, but only if the slot ahead is empty.

**Buildings.** `world.buildings`: `type`, `origin`, `status`, `input`, `output`, `progress`, `buildRemaining`. Size comes from `content.building(type)!.size`. Status drives the look:

| `status` | Look and sound |
| --- | --- |
| `.running` | Normal, machine hum layer on |
| `.blocked(_)` | Dim, amber pulse, hum off. The icon above shows what's missing (`reason.text(content)`) |
| `.idle` | Normal, quiet |
| `.constructing` | Scaffold or partial alpha |
| `.complete` | Normal; a full foundation gets a sparkle |

**Day and night** are a rendering choice: derive time of day from `world.tick` (for example a 10-minute day) and tint the scene. Swap `cottage` for `cottage_night` after dusk. Never store the time of day back into the world.

## 4. Player input → commands

Every command returns `CommandResult`: `.ok`, or `.rejected(error)` with `error.message`, a short sentence for a toast ("The Clay Pit needs a clay deposit", "This belt needs 7 tiles and you have 3").

| Gesture | Call |
| --- | --- |
| Tap a tile with a build tool | `session.place(type, at: tile)` |
| Drag from a building or tile with the belt tool | while dragging: `session.previewBelt(from: start, to: current)` returns the ghost path (or nil); on release: `session.layBelt(from: start, to: end)` |
| Tap a building with empty hands | `session.pickUp(from: id)` |
| Tap a building with full hands | `session.drop(into: id)` |
| Demolish | `session.remove(id)` / `session.removeBelt(at: tile)` |
| Undo button | `session.undo()`, enabled when `session.canUndo` |
| Long press | inspect card: `session.rates(of: id)` (made, used and received per minute) and `session.trace(.building(id))` |

Starting a belt **on** a building takes items from it. Ending a belt on a building, or on the side of another belt, feeds into it. Routing avoids obstacles by itself and prefers straight runs.

## 5. Trace

```swift
let result = session.trace(.building(id))   // or .item("brick")
result.root          // TraceNode tree: label, state (.running .slow .blocked .notBuilt), reason, children
result.brokenPath    // root → first broken step (empty when everything runs)
result.firstBroken   // the step to fix; for .missingBuilding(type) show "Build a …"
result.jumpTarget    // EntityID to centre the camera on
```

Draw lines along the tree between the buildings it names (`node.entity`). Use gold for running, amber for slow and red for blocked, plus the design's shape and icon cues for colour-blind players. Trace is a pure function: call it as often as you like.

## 6. Events → feel

| Event | Effect |
| --- | --- |
| `buildingPlaced` | small bounce, `fx_pop` frames, light haptic, place sound |
| `itemProduced` | squash on the new item; floating "+1" only for the first few of each item |
| `itemDelivered(_, _, via: .hand)` | pickup and drop sound |
| `statusChanged(id, .blocked)` | start the amber pulse; hum fades out |
| `statusChanged(id, .running)` | hum back on; pitch up with throughput (`rates(of:)`) |
| `homeStarted` / `homeCompleted` | scaffold, then chimney smoke |
| `sourceDepleted` | gentle warning on that tile |
| `tutorialStep(id)` | show `session.tutorialStep!.text` (two short lines) and pulse its `highlight` (tile, building type or UI control) |
| `goalReached` | double haptic, warm light sweep, new music layer, colour spreading across the map |

## 7. The SwiftUI overlay

- **Left: build palette** from `world.unlocked`, with names from `content.building(type)!.name`. Show remaining belt tiles from `world.beltsAvailable`.
- **Top:** `session.goal` (`text`, `current` / `target`) and the clock.
- **Right:** context panel for the selection (status text, rates, Trace button, demolish).
- **Bottom:** mode tabs. Level 1 starts with only Build, Trace and Undo.

## 8. Saving

```swift
let data = try session.save()                       // deterministic JSON
try data.write(to: saveURL, options: .atomic)       // Application Support/save.json
let session = try GameSession.load(data, content: content)
```

Save every 30 seconds and when `scenePhase` becomes `.background`. A loaded world continues exactly as if it had never stopped (tested). The undo history is not saved.

## 9. Rules that keep it working

- Never change the world except through `GameSession` commands and `advance`. The renderer only reads.
- No randomness in the app may affect the world. Visual-only randomness (tree jitter, smoke wobble) is fine; seed it from the tile position so it doesn't flicker.
- New items, buildings, recipes and levels are JSON in `Data/`. If loading fails, `ContentError` lists every problem.
- After changing sprites: `python3 Tools/make_art.py` rebuilds the atlas. Put hand-edited PNGs in `Art/manual/` (same name); they always win.

## 10. Known gaps for the renderer

- **Terrain transitions:** water, sand, clay and dirt currently meet in hard squares. Add edge or corner tiles chosen from neighbours.
- **Trees** sit one per tile in a grid. Jitter them a few pixels from a hash of the point.
- **Sound** is hooks only. Generate placeholder tones until real audio exists.
- **Balance numbers** in `Data/` are placeholders. The scripted test player finishes Level 1 in about 63 seconds of game time; real players will be slower. Play-test and tune.
