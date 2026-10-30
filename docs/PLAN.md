# Groundwork: Prototype 1 build plan (no-Mac track)

## Context
Phase 0 of the no-Mac track (see "No Mac yet" in docs/DESIGN.md): check the toolchain, settle the plan and write CLAUDE.md, without writing game code. Approved on 2026-10-29. Phases 1 to 5 build on the decisions below.

## Toolchain (done in Phase 0)
- The cloud container (Ubuntu 24.04, x86_64) had no Swift. `download.swift.org` and GitHub releases are blocked by the network policy, and Ubuntu 24.04 has no `swiftlang` package.
- `Tools/install_swift_linux.sh` unpacks the official `swift:6.2-noble` Docker image straight from the registry API (no Docker daemon needed), checking each layer's sha256 digest. It tries Google's Docker Hub mirror (`mirror.gcr.io`) first, because the shared egress IP often uses up Docker Hub's anonymous rate limit, then Docker Hub. It also apt-installs swift.org's Ubuntu 24.04 dependency list.
- Result: Swift 6.2.4 at `/opt/swift-image/usr/bin`, and `swift test` works for an XCTest package.
- Containers are temporary, so each new cloud session re-runs the script.

## Contradictions and gaps in the design, with proposed resolutions
1. **DESIGN.md location.** It's at the root, but everything else refers to `docs/DESIGN.md`. → `git mv DESIGN.md docs/DESIGN.md`.
2. **The Level 1 script and the beat sheet disagree.** The script places the Lumber Camp before the kiln. The beat sheet adds it at 4:00, when "the kiln now needs logs, Trace shows the gap". → Follow the beat sheet (the prompt says "exactly"). The kiln starts with a small fuel stock (5 logs, set in level data). The first bricks work right away, the fuel runs out, Trace shows "Waiting for logs", and the player places the Lumber Camp.
3. **The Foundation isn't in the building catalogue**, although the Level 1 goal and the sprite list use it. → Add a `foundation` construction-site building, pre-placed by the level, that takes 8 bricks by belt or by hand.
4. **Who orders cottages?** The prototype wants an automatic demand rule. The catalogue says the Builder's Yard builds on request and only the Level 11 Construction Yard builds automatically. → For the prototype, put the rule on the **Builder's Yard**: it takes brick and plank by belt and, once supply is steady, builds the next cottage on the next free plot the level defines. "Steady" means over the last 600 ticks (60 s) the yard received at least the cottage cost, net inflow of both brick and plank was positive, and its stock covers the cost. All thresholds live in JSON.
5. **No build costs or production times are given.** → Placeholder numbers, all in JSON. Gatherers, the kiln, the sawmill and the crate cost nothing in Levels 1 to 3, in keeping with "no punishment for experimenting". Clay Pit makes 1 clay every 30 ticks. Lumber Camp makes 1 log every 40 ticks. Kiln turns 2 clay plus 1 log (fuel) into 1 brick every 50 ticks. Sawmill turns 1 log into 2 planks every 40 ticks. A cottage costs 10 brick and 6 plank.
6. **Power.** The design says every machine needs inputs, power and an output path, but power arrives in Level 2 and is outside phases 0 to 5. → Recipes keep a `power` field set to 0, and Trace has a power branch that never triggers yet.
7. **Fuel ledger.** → A recipe input carries `"role": "fuel"`, so the Lumber Camp's split of logs between planks and fuel can be worked out from data.
8. **Splitters and mergers.** Level 2's goal, two pits feeding one kiln, needs merging. → Phase 4 supports side-loading: a belt ending against the side of another belt merges into it. Formal splitter and merger buildings come later.
9. **Unlimited undo.** Rewinding to a snapshot would also undo production since then. → Undo applies the inverse of each structural action: place, remove, lay belt. Undoing a placement refunds its cost, and so does demolition within 100 ticks of placing. Hand-carry moves can't be undone.
10. **Map.** The map question is still open. → For the prototype, use one handcrafted 64×64 Level 1 map stored as a text grid (`Data/maps/level1.txt`). No procedural generation, and no chunks until the world gets large.
11. **Hand carry.** "About 10 items". → The hand holds up to 10 of one item type. Pick-up and drop are instant in the simulation, and the UI handles the animation.
12. **Trace states.** The table shows "Normal", while the rules say running, slow and blocked. → Use `running`, `slow`, `blocked`, plus `notBuilt` for recipe steps that have no building yet.
13. **One world, not a level list (owner's call, 2026-10-29).** A new player can't choose between level names they don't understand. → There is one world, `"world"` in `levels.json`, on the Level 1 map. The design's Levels 1 to 3 are its first three **chapters** (Bare Ground, First Belts, Stone to Roof), followed by Free Build. Buildings carry over. Each chapter draws more of the map (a reveal radius around the start; nothing can be built on undrawn paper) and opens the next when the player taps Continue on the chapter card. Every building, item and source has a one-line description, and landmarks ("Clay", "Forest") are named on the map until used. Level 2's separate map is retired.
14. **Demand rule when the yard is full.** A full yard receives nothing, so "received a cottage's worth this minute" could never hold again and the yard stalled for good. → A yard holding its full capacity of a material counts as steadily supplied with it.
15. **Tutorial belts must stay built.** A step that teaches a belt finishes on `linked:<from>:<to>`, checked live, rather than on the first item delivered. If the player later undoes or removes a belt an earlier step taught, the tutorial asks for it again before carrying on.
16. **Tutorial, then your own worlds (owner's call, 2026-10-30).** This changes 10 (no procedural maps). The handcrafted world is the tutorial; it ends when five cottages stand, and the player can keep building there (Free Build) or make a new world. A new world takes a name, a seed (a number, or any text, which is hashed) and Few / Normal / Lots of water, forest and clay. `MapGenerator` builds it from integer value noise, deterministically, and picks a start with open grass and clay and forest close by (`Data/worldgen.json`). Everything is unlocked and belts are unlimited. For the first hour of game time, `Data/hints.json` offers one tip at a time when it becomes useful, and drops it once the player does the thing.
17. **Splitter and milestones (owner's call, 2026-10-30).** This settles 8: a **Splitter** is a 1x1 storage building holding 2 items; every belt that starts at a building takes turns pulling from it, so a splitter (or a crate) shares its supply evenly. Merging stays side-loading. After the tutorial's five cottages, and from the start of a new world, **milestones** give direction: one goal at a time in the top bar with a tip on how to get there, a banner and celebration when reached, and the town's title growing (Hamlet, Village, Town, Market Town). Goals use the tutorial's conditions plus `rate:<item>:<n>` and `stored:<item>:<n>`.

## Folder layout
```
CLAUDE.md
docs/DESIGN.md, docs/PLAN.md (this plan), docs/INTEGRATION.md (phase 5)
GroundworkCore/Package.swift          swift-tools-version 5.10, platforms iOS 17 / macOS 14, XCTest
  Sources/GroundworkCore/
    Content/   IDs.swift, ItemDef, SourceDef, BuildingDef, RecipeDef, LevelDef, TutorialStep, ContentDatabase (load and validate)
    World/     GridPoint, Direction, TileMap, Terrain, SourceDeposit, World (the root Codable struct)
    Sim/       Simulation (tick loop), Production, BeltSystem, HandCarry, DemandRule, Rates, SeededRNG
    Trace/     Trace.swift (pure function), TraceResult, BlockReason
    Session/   GameSession, Command, GameEvent, UndoStack, LevelRunner, SaveFile
  Tests/GroundworkCoreTests/          one file per system, plus a scripted Level 1 player
Data/ recipes.json, buildings.json, items.json, sources.json, levels.json, tutorial.json, maps/level1.txt
Art/  palette.json, sprites/*.txt, manual/ (hand-edited PNGs always win), generated/ (atlas, manifest), contact_sheet.png
Tools/ install_swift_linux.sh, make_art.py (Python 3, standard library only, writes PNGs via zlib)
```
GroundworkCore finds `Data/` through an explicit URL passed to `ContentDatabase.load(from:)`. Tests resolve it from `#filePath`. The iOS app will bundle the same folder.

## Core data types (all Codable value types except GameSession)
- IDs: `ItemID`, `BuildingTypeID`, `RecipeID`, `SourceID`, `LevelID`, string-backed. `EntityID` is a UInt32 handed out by `World.nextEntityID`.
- `GridPoint {x, y}` and `Direction {north, east, south, west}`.
- `TileMap`: width, height, `[Terrain]` (grass, water, shore, dirt, clayGround, forest, rock), plus `[GridPoint: SourceDeposit]`.
- `SourceDeposit`: source, remaining (nil means infinite), `regrowPerMinute`.
- `Building`: id, type, origin, facing, `input: Inventory`, `output: Inventory`, `progressTicks`, `status: MachineStatus`, `rates: RateTracker`, `placedAtTick`.
- `Inventory`: `[ItemID: Int]` with capacity rules taken from the BuildingDef.
- `BeltTile`: point, direction, `slots: [ItemID?]` (4 slots per tile). `BeltLine` is an ordered list of tiles.
- `RateTracker`: per-item ring buffers of made and used counts over 600 ticks. Gives made/min and used/min, and is saved.
- `World`: tick, rng (`SplitMix64` state), map, buildings, belts, hand, level state (goal progress, tutorial step, belt budget), demand-rule state, nextEntityID.
- `MachineStatus`: `.running`, `.idle`, `.blocked(BlockReason)`.
- `BlockReason`: `.missingInput(ItemID)`, `.missingFuel(ItemID)`, `.outputFull`, `.sourceDepleted(SourceID)`, `.noSource`, `.noPower`. Each has an `englishText`.

## JSON formats (one worked example each)
recipes.json
```json
{ "id": "brick", "building": "brick_kiln", "durationTicks": 50, "power": 0, "level": 1,
  "inputs":  [ {"item": "clay", "count": 2, "role": "material"},
               {"item": "log",  "count": 1, "role": "fuel"} ],
  "outputs": [ {"item": "brick", "count": 1} ] }
{ "id": "gather_clay", "building": "clay_pit", "source": "clay_deposit", "durationTicks": 30,
  "inputs": [], "outputs": [ {"item": "clay", "count": 1} ], "power": 0, "level": 1 }
```
buildings.json
```json
{ "id": "brick_kiln", "name": "Brick Kiln", "kind": "processor", "size": [2, 2],
  "recipes": ["brick"], "inputCapacity": 10, "outputCapacity": 10,
  "cost": [], "level": 1, "placeOn": "any_land" }
```
levels.json (one world; abbreviated)
```json
{ "id": "world", "name": "Groundwork", "map": "maps/level1.txt",
  "focus": {"x": 36, "y": 30}, "revealCenter": {"x": 37, "y": 29},
  "unlocked": ["clay_pit"], "beltsAvailable": 0,
  "preplaced": [ {"building": "foundation", "at": {"x": 45, "y": 27}} ],
  "firstPlacementStock": [ {"building": "brick_kiln", "item": "log", "count": 5} ],
  "landmarks": [ {"text": "Clay", "at": {"x": 35, "y": 31}, "hideWhenBuilt": "clay_pit"},
                 {"text": "Lake", "at": {"x": 26, "y": 31}, "untilChapter": 1} ],
  "chapters": [
    { "id": "bare_ground", "name": "Bare Ground", "tutorial": "chapter1", "reveal": 12,
      "goal": { "kind": "deliver", "text": "Fill the foundation with bricks", "count": 8, "item": "brick", "to": "foundation" } },
    { "id": "first_belts", "name": "First Belts", "tutorial": "chapter2", "reveal": 17, "beltTiles": 50,
      "preplaced": [ {"building": "storage_crate", "at": {"x": 45, "y": 31}} ], "goal": { "...": "20 bricks in the crate" } },
    { "id": "free_build", "name": "Free Build", "unlockAll": true, "unlimitedBelts": true } ] }
```
tutorial.json (each line of text is checked to be at most 2 lines and 80 characters)
```json
{ "id": "l1_place_pit", "text": "Start with the ground.",
  "highlight": {"tile": [24, 18]}, "only": ["clay_pit"],
  "advanceOn": {"event": "buildingPlaced", "building": "clay_pit"},
  "grant": null, "pauseSim": true }
{ "id": "l1_belt", "text": "Drag a belt from the pit to the kiln.",
  "grant": {"beltTiles": 12}, "advanceOn": {"event": "itemDelivered", "item": "clay", "via": "belt"} }
```
`ContentDatabase` validation runs as a test: every item's chain must end at a source (the Trace Rule), every ID must resolve, and tutorial text must fit its limit.

## GameSession API (the only thing the renderer and UI use)
```swift
public final class GameSession {
  public init(content: ContentDatabase, level: LevelID) throws
  public static func load(_ data: Data, content: ContentDatabase) throws -> GameSession
  public func save() throws -> Data                      // JSON with sorted keys

  public private(set) var world: World                   // read-only for callers
  public func advance(ticks: Int)                        // fast-forward means more ticks per frame

  // commands are applied at the next tick boundary and logged for replay
  @discardableResult public func place(_ type: BuildingTypeID, at: GridPoint, facing: Direction) -> CommandResult
  @discardableResult public func remove(_ id: EntityID) -> CommandResult
  public func previewBelt(from: GridPoint, to: GridPoint) -> [GridPoint]?   // auto-routed ghost
  @discardableResult public func layBelt(from: GridPoint, to: GridPoint) -> CommandResult
  @discardableResult public func pickUp(from: EntityID, item: ItemID?, count: Int) -> CommandResult
  @discardableResult public func drop(into: EntityID) -> CommandResult
  @discardableResult public func undo() -> CommandResult

  public func trace(_ target: TraceTarget) -> TraceResult // .item(ItemID) or .building(EntityID)
  public func rates(of: EntityID) -> [ItemID: Rate]       // made/min, used/min, predicted shortage
  public var goal: GoalProgress { get }
  public var tutorialStep: TutorialStep? { get }
  public func drainEvents() -> [GameEvent]  // itemProduced, buildingPlaced/Removed, beltLaid,
                                            // statusChanged, goalProgress, goalReached,
                                            // tutorialAdvanced, cottageStarted/Completed, sourceDepleted
}
```
`CommandResult` is `.ok` or `.rejected(reason)`, with reasons such as "Needs a clay deposit" or "Out of belt". `TraceResult` is a tree of `TraceNode {label, item?, entity?, state, reason, children}` plus `firstBlocked: [EntityID]`, which gives tap-to-jump its target.

## Simulation rules
- Each tick runs in a fixed order: apply queued commands → gatherers → belts (each line from its output end backwards, so items move without gaps) → processors and construction → demand rule → rates → goal and tutorial. Entities and lines go in ascending ID order. No floating-point maths, only integer ticks and counts.
- Ports: a belt tile next to a building that points away from it pulls from the building's output. A belt tile that points into a building pushes into its input, if the input accepts that item.
- Auto-routing: an A* search on the grid avoiding water, buildings and other belts (except a side-load at the end of the path). Ties break in a fixed order that prefers straight runs. Paths are capped by the level's belt budget.

## Phases and acceptance tests (stop after each one, run `swift test`, commit, push, report)
0. **Toolchain, plan, CLAUDE.md.** Swift installed via the script. `swift --version` works. CLAUDE.md, docs/PLAN.md and the moved DESIGN.md are committed.
1. **Core.** (Done.) Grid, content loaders and validation, tick loop, seeded RNG. The prototype content JSON and the Level 1 map also landed here, so phase 2 adds only the Trace search. Tests: content loads, unknown IDs are rejected, the map parses, and the tick count advances deterministically.
2. **Trace.** (Done, after production: blocked-step reasons need machines that run.) Items, sources and recipes for clay, log, brick and plank, plus the reverse search. Tests: brick traces to clay and log. A kiln with no fuel reports exactly "Waiting for logs". An unbuilt step reports notBuilt. A slow input is flagged slow.
3. **Production.** (Done.) Gatherers (with depletion and regrowth), processors, the storage crate, hand carry and rates. Tests: a placed pit produces at the data rate, a full output blocks, the hand holds 10 of one item type, carrying fills the kiln, rates match produced counts, and undo plus refund works.
4. **Belts, cottage and demand rule.** (Done.) Tests: items arrive in order and the total count is conserved (no loss or duplication across 10,000 ticks). Auto-routing avoids obstacles and is deterministic. Side-load merges work. Save → load → run equals an uninterrupted run. 1000 single ticks equal `advance(1000)`. The yard orders a cottage only when supply is steady.
5. **Level 1, art, integration.** (Done. Also Level 3 "Stone to Roof" as data, and a Builder's Yard sprite, making 43.) Level 1 and its tutorial as data. A headless scripted player completes Level 1 through GameSession alone. `make_art.py` builds the 42 sprites into an atlas and manifest and checks palette and sizes. I'll look at the 4× contact sheet, fix what reads badly, and commit `Art/contact_sheet.png`. docs/INTEGRATION.md explains how SpriteKit and SwiftUI read `world`, call commands and use `drainEvents()`.

## CLAUDE.md content (written in Phase 0)
The starter rules from the design, adapted for Linux: GroundworkCore uses only Foundation; content is JSON; fixed 10 ticks per second; determinism and seeded RNG; prototype scope only. Commands: `bash Tools/install_swift_linux.sh` (once per new container), `cd GroundworkCore && swift test`, `python3 Tools/make_art.py`. Working rules: one phase at a time; stop and report; stop after two failures for the same reason. Definition of done: tests pass, the change is committed and pushed, and CLAUDE.md is updated.

## Verification for Phase 0
- `swift --version` prints 6.2.x and a scratch XCTest package passes `swift test`.

## What's left (updated 2026-10-29)

### Done without a Mac
- **Simulation:** core, Trace, production, hand carry, belts with auto-routing, the cottage demand rule, Level 1 and Level 3 with the tutorial runner, saving, fun-test metrics, predicted shortages.
- **Art:** 107 sprite grids building 185 images. Real building variants, terrain edges, animation, night glow, decorative villagers, UI pieces.
- **GroundworkView**, the tested presentation layer: scene, camera, touches, tools, effects, HUD, day and night, autosave timing.
- **The iPhone app code** (SwiftUI and SpriteKit), checked against stand-ins.
- **Screenshots** rendered from the real code: `docs/screenshots/`.
- **Tutorial upgrade:** Trace is now taught (time stops until the player traces the kiln). New Level 2 "First Belts". Level 3 rewritten. Stuck hints, tuck-away bubble and Skip tutorial.
- **Insight features:** Trace panel (the chain as a list, tap to jump), status bubbles over stuck machines, and a rates view with shortage warnings.
- **One world in chapters** (after the first Mac run): no level menu; Play continues the world. Chapters reveal more of the map, buildings carry over, everything has a one-line description, landmarks are labelled, and the first building of each type wears a name tag.

### Recommended next (from the 10-feature list)
5 splitter and merger, 6 belt bridges and reversing, 7 move a building, 8 fun-test overlay, 9 accessibility settings, 10 Sandbox. Power for Level 2's waterwheel needs your go-ahead.

Performance (Linux, release build): 8,000 belt items cost 0.35 ms per tick.

### Needs the Mac
- Build the app in Xcode following docs/INTEGRATION.md, and fix the compile errors the stand-ins could not catch.
- Measure frame rate on an iPhone. If the static layer is slow, bake it into one texture.
- Play on an iPhone, run the fun test with three new players, then TestFlight.
- Level 2 needs mechanical power (waterwheel), which is outside the current scope. Ask first.

### Needs the owner
- Confirm or change the calls in "Contradictions" above: kiln starting logs, yard-built cottages, placeholder numbers, side-loading instead of splitters.
- The open questions and decisions at the end of DESIGN.md.
- Play-testing and balance.
- Real audio, and hand-polished key sprites in Art/manual.
