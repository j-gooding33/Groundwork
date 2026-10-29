# Groundwork: Game Design Document

Oct 28, 2026 · @Joseph Gooding

## Vision

Groundwork is a landscape iOS game about building an automated chain of industry, from raw nature up to a self-running pixel city, where every item can be traced back to the lake, mine or forest it came from.

It takes the factory-builder idea, removes the fiddly parts for touch, and makes a living society the reward. The player starts with empty land and a handful of tools, builds a few machines by hand, automates them, houses people, and ends as a quiet god over a city that feeds, powers and houses itself.

The game is loosely inspired by *The World Between Shifts*: a world built piece by piece in spare moments, which you can finally stand inside. The opening screen is blank paper that fills in as the player imagines land into existence, and Walk Mode lets them stand in the city they made.

### Design pillars

- **Everything comes from somewhere.** No item appears from nothing, and the player can always trace any item back to a natural source.
- **Never overwhelming.** Each level adds one big idea and at most five new buildings. The build menu starts with three buttons.
- **Automation is the reward.** Every era replaces something the player did by hand with something that runs itself.
- **People are the payoff.** Citizens arrive into a town that already works, and their lives are the scoreboard.
- **Looks handmade.** Pixel art with deliberate imperfection, never clean or symmetrical.

### Target and platform

- iPhone first, iPad supported, landscape only, iOS 17 or later.
- Swift in Xcode, SpriteKit for the world, SwiftUI for menus. Single player, fully offline.
- Sessions of 5 to 15 minutes, with progress saved automatically.

### Art and sound direction

- Pixel art on one shared 32-colour palette, 16×16 tiles, rendered at a low internal resolution (about 480×270) and scaled up with nearest-neighbour filtering.
- Dithered shading instead of gradients. Rooftops, smoke and trees vary slightly, so no two houses look the same.
- Light follows the time of day: warm dawn, flat midday, orange dusk, lit windows at night.
- Soft lo-fi music, with machine sounds layered in so a busy factory has its own rhythm.

## Prototype 1: the smallest version that proves the game

The full design below is the long-term vision, but the first build is a small slice that tests one question: is the loop of building, spotting a bottleneck, fixing it and watching it run itself actually fun? Nothing else is started until it is.

### Include

- A scrolling pixel-art map with a lake, a forest and a clay deposit.
- Three or four gathering and processing buildings: clay pit, lumber camp, brick kiln, sawmill.
- Hand-carrying, then a working belt system with visible moving items.
- A brick and plank production chain, and a cottage as the first home.
- One simple demand rule that orders cottages automatically once supply is steady.
- A save system and one clear objective.
- A Trace view that shows the whole chain and where it is blocked.

### Leave out until it is fun

- Individual citizens, shops, taxes and detailed economics.
- Rail, drones, electricity and the data network.
- Walk Mode and the character creator.
- Procedural world generation.

### How to judge it

The prototype succeeds if a player can spend 10 minutes building, notice a bottleneck, fix it, see the system run on its own, and want to keep improving the settlement. If that loop is not satisfying, adding more items will not fix it.

## Why Groundwork stands apart

The pitch in one line: *build the ground, trace everything back to nature, and watch a town come alive on it.* Most mobile factory games are about optimising a machine. Groundwork differs in five ways.

| What | How it works | Why it matters |
| --- | --- | --- |
| Trace, always | Tap anything to see its whole chain and why it is blocked, with a jump to the broken building | The game explains itself, so no wiki or spreadsheet is needed |
| Made for touch | Drag to build, belts and roads auto-route, one-thumb play, rates shown on buildings | Factory games usually feel cramped on a phone |
| A town as the payoff | Citizens, named characters, landmarks and visible era changes | Gives a reason to build beyond efficiency |
| A handmade pixel look | One palette, deliberate imperfection, light that changes through the day | Recognisable in a single screenshot |
| An archipelago to grow into | Separate islands with different resources, linked by sea | A long-term goal after the first city |

Groundwork will not use ratio calculators, walls of tech-tree text, or punishment for experimenting.

## Game feel and the first ten minutes

The game has to feel good to touch within the first two minutes, before any system matters. The opening is built around a first belt in two minutes, not a chore of carrying things.

| Time | What happens | The feeling |
| --- | --- | --- |
| 0:00 | A blank paper map. The camera finds a clay deposit beside a lake. | Calm curiosity |
| 0:20 | The player taps the deposit and places the Clay Pit. It pops in with a puff of dust and the first clay appears. | First spark |
| 1:00 | The Brick Kiln goes down. The player carries the first clay in by hand and a chime sounds as the first brick pops out. | First reward |
| 2:00 | The game hands over a starter belt. The player drags it from pit to kiln and clay flows on its own, with a low hum. | Breakthrough |
| 4:00 | The Lumber Camp joins. The kiln now needs logs, Trace shows the gap, and the player fixes it. | I understand this |
| 6:00 | The foundation fills, chimney smoke rises, the map fills with colour and the music gains a layer. | Payoff |
| 8:00 | Level 2 opens with a waterwheel and a bigger map. | I want more |

### What makes touches feel good

- **Placing:** a building drops in with a small bounce and a dust puff.
- **Items:** they spawn with a quick squash, and belts show direction with moving stripes.
- **Sound as feedback:** each working machine adds a layer, throughput raises the pitch, and a blocked machine goes quiet and dims, which is itself a signal.
- **Bottlenecks:** a stalled building pulses amber and Trace draws its line.
- **Rewards:** each goal gives a warm light sweep, a new music layer and colour spreading across the map.
- **Haptics:** a light tap for placing and a double tap for completing a goal.
- **Responsiveness:** every tap reacts within 100 milliseconds, with no loading screens and no confirmation dialogs for normal actions.
- **Restraint:** floating +1 numbers appear only for the first few items, so the screen never fills with noise.

### The fun test

These must pass, using placeholder art, before any new system is built.

- [ ] A new player gets their first belt running within 2 minutes.
- [ ] They find and fix a bottleneck within 10 minutes without being told how.
- [ ] They ask to keep playing, or restart unprompted, after the first session.
- [ ] Three people who have never seen the game can play Level 1 without help.
- [ ] Placing, belts and reward moments feel good before the final art exists.

If these fail, fix the feel or the loop. Do not add features.

## Core loop and the Trace Rule

Every action in Groundwork sits inside three loops, and one rule ties them together: nothing exists without a source the player can see.

### The three loops

1. **Moment (under a minute).** Place a building, connect it, watch the first item travel.
2. **Session (5 to 15 minutes).** Find the bottleneck, fix it, reach the level goal, unlock the next idea.
3. **Era (hours).** Replace a hand-run process with an automated one, then use the freed attention to build the next layer.

### The Trace Rule

- Every item has a recipe, and every recipe ends at a natural source: water, soil, forest, stone, clay, coal, ore, sand, wind or sun.
- Tapping any item, building or meal opens **Trace**, which highlights the whole chain back to its sources in gold and marks the blocked step in red.
- Every machine needs inputs, power and an output path. If one is missing, a small icon above the machine says which.
- Sources are finite or slow to regrow, so growth forces the player to expand or adopt better technology.

### Trace as a problem-solving tool

Trace explains why production stopped, not only where an item came from. Tapping a blocked item walks down the chain to the first broken step, and tapping that step jumps the camera to the building.

| Step | State | Reason shown |
| --- | --- | --- |
| Bread | Blocked | Bakery output is 0 per minute |
| Bakery | Blocked | Waiting for flour |
| Flour Mill | Slow | Wheat delivery is too slow |
| Wheat Field | Normal | Producing as expected |

This is an illustrative layout. Every building also shows its rate (made per minute, used per minute) so shortages are predicted before they happen.

### Example traces

| Item | Chain back to nature |
| --- | --- |
| Cottage | Brick + plank → brick kiln + sawmill → clay pit + lumber camp → clay and forest; power from a waterwheel |
| Loaf of bread | Bakery → flour mill → wheat field → soil, plus water pump → lake |
| Street light at night | Lamp → power pole → power station → coal mine → coal seam |
| Steel beam | Steel mill → iron plate + coal → smelter → iron mine → iron vein |
| Citizen's mood | Meals, warmth, light, clean water and a job, each traced back through its own chain |

## Systems: how power, water, goods, data and food travel

Seven systems carry everything in the world, and each is introduced in a single level so the player only ever learns one at a time. Level numbers refer to the level table below.

### Power

- **Mechanical (Level 2).** A waterwheel turns a shaft that drives machines within about 6 tiles. Power cannot travel far, so early industry has to sit beside the river.
- **Steam (Level 7).** A boiler burning wood or coal feeds a steam engine that powers a whole factory floor through a shaft line.
- **Electric (Level 9).** A coal power station sends power through poles and cables into a grid. Cables show load by colour: green is fine, amber is near capacity, red is overloaded. Substations (Level 11) extend range and split the city into districts.
- **Clean power (Level 12).** Wind turbines, solar arrays and battery banks replace coal for power, and the kiln, smelter and glassworks get electric upgrades so heavy industry can run coal-free too. Output depends on where they are placed, so wind strength and sun exposure appear as a map overlay.
- **Failure is visible.** When supply falls short, machines slow down and street lights flicker. The grid never breaks silently.

### Water

Pumps lift water from a lake or river into pipes. Water towers buffer supply and set pressure for a district. Wells give a slower, local supply. Water is used by farms, bakeries, boilers and every home. Treatment plants (Level 12) clean outflow so the lake stays usable.

### Logistics: how things move

- **Hand carry (Level 1).** The player carries about 10 items by hand.
- **Belts (Level 2).** Drag a path and belts lay themselves. Splitters and mergers arrive within the same level, bridges later.
- **Roads and trucks (Level 4).** Roads become the main network. Trucks follow fixed routes between depots and shops, and the same roads carry citizens and, from Level 6, their cars. Belts stay for short hops inside a site.
- **Rail (Level 8).** Carts on tracks haul bulk goods such as ore and coal. Stations load and unload on a simple schedule.
- **Drones (Level 11).** Stretch goal: a drone port moves small, high-value items between depots over any terrain. Cargo ships cover sea links in Level 11 instead.

### Data: how information travels

Data appears in Level 10 and is what lets the city run itself.

- **Sensors** on depots, shops, homes and generators report stock, demand and power.
- **Data cable**, laid alongside roads, carries the reports. **Relay masts** cover gaps wirelessly within about 12 tiles.
- A **Control Hub** reads the reports and gives orders. When housing runs short it orders the Construction Yard to build, and when bread runs low it reroutes flour.
- Without a data link an area still runs on hand-set rules. Data adds the smart part, not the basics.

### Automation the player directs

The Control Hub runs simple, readable rules the player chooses, then watches work. Automation should be about deciding what happens, not only laying more infrastructure.

- If bread stock falls below a set level, increase flour deliveries.
- If a district needs housing, order the Construction Yard to build a cottage.
- If a power station nears capacity, switch off non-essential consumers first.
- If a mine runs low, suggest another source and reroute deliveries.

Player control grows by era:

| Stage | What the player controls |
| --- | --- |
| Early game | Places buildings and connects every production step |
| Mid game | Sets delivery routes, stock targets and priorities |
| Late game | Sets district policies and lets the city adjust itself |

Automation is never entirely effortless: the challenge is choosing rules and diagnosing why a rule is not behaving as expected.

### Food: how people get fed

Wheat field → flour mill → bakery → market stall or shop → citizen. Later chains add orchards, dairy and fishing for variety. Citizens walk to shops and pay from their wages, and shops restock by truck or belt. Food variety (bread, vegetables, fruit, dairy, fish) drives health and mood, not just quantity.

Soil quality drops slowly with repeated use. A field shows a clear warning before its yield falls, and a compost heap restores it quickly, so it is a gentle reminder rather than a management burden.

### Materials: four tiers

1. **Raw:** clay, logs, stone, sand, coal, ore, water, wheat.
2. **Processed:** brick, plank, glass, flour, iron plate, steel beam, copper wire.
3. **Components:** nails, gears, pipes, tools, circuit boards.
4. **Assemblies:** windows, doors, sensors, drones, machine parts.

A new tier is introduced only when its level begins, so early recipes stay two steps deep.

### Fuel ledger

Logs feed three things: planks, fuel and heating. Every recipe lists its fuel use explicitly, and the Lumber Camp's panel shows where its logs are going (planks, kilns, homes) as a simple split bar. When logs run short, the player can see which use is taking the most.

### Waste and pollution

Factories produce smoke and waste. Smoke and dirty water lower the health and mood of nearby homes. Waste goes to a landfill (Level 7) and later to a recycler (Level 12), which turns scrap back into raw material and closes the loop.

## Roads, vehicles and islands

Roads carry the world's traffic, and islands carry its growth: the first island teaches the game, and the next ones make the player build connections.

### Roads, trucks and cars

- **Roads are the main network from Level 4.** The player drags a road, junctions snap automatically, and the same road serves factories and homes.
- **Belts stay for short hops** inside a factory or between neighbouring buildings. Anything longer goes on a road.
- **Trucks** follow fixed routes the player sets by tapping a depot and then a destination. They load, drive and unload on their own, with no steering.
- **Cars** appear from Level 6. Citizens walk short distances and drive when a commute is long, so cars share the roads with trucks.
- **Traffic** is simple. Each road has a capacity shown by colour, and widening a road doubles it. From Level 8, heavy trucks passing homes lower mood through noise and smoke, so a separate **freight road** becomes a useful upgrade.
- **No manual driving or steering.** Vehicles route themselves, which keeps the game playable with one thumb.

### Islands

Each island has its own map and its own natural resources, so the player must connect them. The Trace Rule crosses the sea: a sea link shows up as a step in any chain.

| Island | Opens | Natural resources | Why the player needs it |
| --- | --- | --- | --- |
| Home Island | Level 1 | Clay, forest, lake, stone, soil, sand, coal, iron | Teaches everything up to Level 8 |
| Copper Isle | Level 9 | Copper vein, windy ridge | Copper is needed for wire, power poles and circuits, and wind for Level 12 |
| Sun Isle | Level 12 | Open sunny flats, room for a large city | Solar arrays and the final city. Oil and hydro sites appear here in Sandbox |

### Sea links

| Link | What it carries | Level |
| --- | --- | --- |
| Ferry Dock and Ferry | Citizens and light goods between islands | 9 |
| Bridge | Everything, across short gaps only | 10, optional |
| Cargo Port and Cargo Ship | Bulk goods such as ore and coal | 11 |
| Sea Cable | Power and data across water | 11 |

Level 9 swaps the Street Lamp out of its required list to make room for the Ferry Dock, so Street Lamps become an optional extra there. Citizens can commute by ferry or bridge, so islands grow into one connected society, and each island can specialise (mining, farming, housing).

Only one island is built first. Copper Isle is added after Prototype 1 works and the citizen system is done.

## Item and building catalogue

The full game has about 90 items, buildings and sources, grouped here by category. The Level column says when each first appears; it is the level at which the player is taught it, not when it becomes available in Sandbox.

### Natural sources (found in the world, not built)

| Source | Gives | Behaviour | Level |
| --- | --- | --- | --- |
| Lake and river | Water | Renewable, but each pump has a fixed draw rate | 1 |
| Clay deposit | Clay | Slowly depletes, then the player must find another | 1 |
| Forest | Logs | Regrows if the lumber camp replants | 1 |
| Stone outcrop | Stone | Finite | 2 |
| Fertile soil | Crops | Quality drops with repeated use, restored by compost | 5 |
| Coal seam | Coal | Finite | 7 |
| Iron vein | Iron ore | Finite | 7 |
| Sand bank | Sand | Renewable slowly | 8 |
| Copper vein | Copper ore | Finite | 9 |
| Wind and sun sites | Wind, sunlight | Renewable, strength varies by location | 12 |
| Hill with river | Hydro head | Allows a hydro dam in Sandbox | Beyond |
| Oil field | Crude oil | Finite, Sandbox only | Beyond |

### Gathering buildings

| Building | Takes from | Output | Level |
| --- | --- | --- | --- |
| Clay Pit | Clay deposit | Clay | 1 |
| Lumber Camp | Forest | Logs | 1 |
| Quarry | Stone outcrop | Stone | 2 |
| Water Pump | Lake or river | Water | 2 |
| Wheat Field | Fertile soil + water | Wheat | 5 |
| Coal Mine | Coal seam | Coal | 7 |
| Iron Mine | Iron vein | Iron ore | 7 |
| Sand Dredger | Sand bank | Sand | 8 |
| Copper Mine | Copper vein | Copper ore | 9 |
| Orchard and Fishing Pier | Soil, lake | Fruit, fish (food variety) | 8, optional |

### Processing buildings

| Building | Input | Output | Level |
| --- | --- | --- | --- |
| Brick Kiln | Clay + logs (fuel) | Brick | 1 |
| Sawmill | Logs | Planks | 3 |
| Flour Mill | Wheat | Flour | 5 |
| Bakery | Flour + water | Bread | 5 |
| Smelter | Iron ore + coal | Iron plate | 7 |
| Steam Engine | Coal or logs + water | Mechanical power | 7 |
| Workshop | Iron plate + planks | Nails, gears, pipes, tools | 8 |
| Glassworks | Sand + coal | Glass | 8 |
| Dairy | Water + feed | Milk, cheese (food variety) | 8, optional |
| Wire Mill | Copper ore | Copper wire | 9 |
| Circuit Works | Copper wire + glass | Circuit boards | 10 |
| Compost Heap | Food scraps | Fertiliser | 6, optional |
| Recycler | Waste | Raw materials | 12 |

### Materials and goods

| Item | Tier | Made from | Used for | Level |
| --- | --- | --- | --- | --- |
| Clay, logs, stone, water | Raw | Gathered | Bricks, planks, foundations | 1 to 2 |
| Brick | Processed | Clay + fuel | Houses, kilns, chimneys | 1 |
| Plank | Processed | Logs | Houses, doors, carts | 3 |
| Wheat, flour, bread | Raw, processed | Field, mill, bakery | Meals | 5 |
| Iron ore, coal | Raw | Mines | Plate, steel, power | 7 |
| Iron plate | Processed | Ore + coal | Nails, gears, pipes, rails | 7 |
| Nails, gears, pipes, tools | Components | Iron plate (+ planks) | Houses, machines, water network | 8 |
| Glass | Processed | Sand + coal | Windows | 8 |
| Window, door | Assembly | Glass + plank, plank + nails | Terrace rows, apartments | 8 |
| Copper wire | Processed | Copper ore | Cables, circuits | 9 |
| Circuit board | Component | Wire + glass | Sensors, hubs, drones | 10 |
| Sensor, drone | Assembly | Circuit + wire, circuit + steel | Data network, delivery | 10 to 11 |
| Steel beam | Processed | Iron plate + coal | Apartments, hospital, rail bridges | 11 |

### Transport and storage

| Item | What it does | Level |
| --- | --- | --- |
| Storage Crate | Holds 50 items by hand | 1 |
| Belt | Moves items along a dragged path, auto-routes around obstacles | 2 |
| Splitter and Merger | Divide or combine belt lines | 2 |
| Depot | Larger store that belts and trucks load and unload | 3 |
| Road | Carries trucks and citizens | 4 |
| Truck | Delivers between depots and shops on set routes | 4 |
| Bridge Belt | Crosses another belt or a road | 4 |
| Rail and Station | Bulk haul over long distance on a schedule | 8 |
| Drone Port | Stretch goal: sends small items between depots by air | 11 |

### Cars and sea links

| Item | What it does | Level |
| --- | --- | --- |
| Car | Carries citizens on long commutes, shares roads with trucks | 6 |
| Freight Road | Truck-only road that keeps heavy traffic away from homes | 8 |
| Ferry Dock and Ferry | Moves citizens and light goods between islands | 9 |
| Bridge | Links islands across short gaps | 10, optional |
| Cargo Port and Cargo Ship | Carries bulk goods between islands | 11 |
| Sea Cable | Carries power and data across water | 11 |

### Power and water network

| Item | What it does | Level |
| --- | --- | --- |
| Waterwheel | Mechanical power beside a river, range about 6 tiles | 2 |
| Well and Water Tower | Local supply, then district pressure and storage | 4 |
| Pipe | Carries water to farms, homes and boilers | 4 |
| Steam Engine | Power for a whole factory floor from coal or logs | 7 |
| Landfill | Holds waste, fills up over time | 7 |
| Coal Power Station | Feeds the electric grid | 9 |
| Power Pole and Cable | Connects stations and buildings, colour shows load | 9 |
| Street Lamp | Lights roads at night, raises safety and mood | 9 |
| Substation | Extends range and splits the grid into districts | 11 |
| Wind Turbine and Solar Array | Clean power, output depends on location | 12 |
| Battery Bank | Stores surplus, covers dark and calm periods | 12 |
| Treatment Plant | Cleans used water before it returns to the lake | 12 |

### Data and automation

| Item | What it does | Level |
| --- | --- | --- |
| Sensor | Reports stock, demand or power from the building it sits on | 10 |
| Data Cable | Carries reports along roads | 10 |
| Relay Mast | Wireless link, about 12 tiles | 10 |
| Control Hub | Reads reports, issues orders, shows the district dashboard | 10 |
| Builder's Yard | Builds one house at a time when the player orders it | 3 |
| Construction Yard | Builds houses automatically from Control Hub demand | 11 |

### Homes

| Building | Houses | Needs | Level |
| --- | --- | --- | --- |
| Cottage | 2 | Brick, plank | 3 |
| Terrace Row | 6 | Brick, plank, window, door | 8 |
| Apartment Block | 24 | Brick, steel beam, window, door | 11 |
| Tower Block | 80 | Steel, glass, circuits | Beyond |

### Services, shops and jobs

| Building | Role | Level |
| --- | --- | --- |
| Market Stall | Sells bread and basic food, first shop | 5 |
| Town Hall | Sets taxes and policies, shows citizen stats | 6 |
| Clinic | Treats illness, lifts health | 6 |
| Pub | Leisure and social need | 6 |
| Park | Leisure, calms noise and smoke nearby | 6 |
| School | Education, improves wages | 8, optional |
| Library | Education and leisure | 9, optional |
| Hospital | Serious care, larger catchment | 11 |
| Fire Station | Reduces fire risk in dense areas | 11, optional |
| Bus Stop and Tram | Faster commute for large cities | Beyond |

## Levels: what comes out, and when

The game has 12 levels of about 20 to 40 minutes each, then an open Sandbox. Every level adds one big idea and up to five required buildings, and the town gets a working livelihood (homes, roads, water, food, shops, services) before the first citizen arrives in Level 6.

A level can span several sessions, so saving, stopping and returning must feel natural. Each level is built around three beats:

1. **First five minutes:** discover the new mechanic.
2. **Next five minutes:** build a working version of it.
3. **Final stretch:** improve it enough to reach the goal and see a satisfying payoff.

Anything longer comes from optional improvement, never from waiting on production timers.

| Level | Name | New idea | New buildings | Goal |
| --- | --- | --- | --- | --- |
| 1 | Bare Ground | The Trace Rule: everything has a source | Clay Pit, Lumber Camp, Brick Kiln, Storage Crate | Fill the first foundation with bricks from a kiln fed by your first belt |
| 2 | First Belts | Belts and mechanical power | Belt, Waterwheel, Quarry, Water Pump | Feed a kiln from two pits without carrying anything |
| 3 | Stone to Roof | Demand-driven building | Sawmill, Depot, Builder's Yard, Cottage | Five cottages from an automated brick and plank supply |
| 4 | Roads and Water | Roads and a water network | Road, Truck, Well, Water Tower | Every cottage has a road and running water |
| 5 | Daily Bread | A food chain that ends at a shop | Wheat Field, Flour Mill, Bakery, Market Stall | A stall stocked with bread and no hand delivery |
| 6 | First Settlers | Citizens, needs and taxes | Town Hall, Clinic, Pub, Park | 20 citizens settle and stay content for 3 days (Walk Mode unlocks) |
| 7 | Steam and Steel | Mining, fuel and smelting | Coal Mine, Iron Mine, Smelter, Steam Engine | A steady iron plate supply for the town |
| 8 | Rails and Workshops | Rail haul and components | Rail and Station, Workshop, Glassworks, Terrace Row | 60 citizens in terraces, ore arriving by rail |
| 9 | The Wired Town | Electricity | Ferry Dock, Copper Mine, Wire Mill, Coal Power Station, Power Pole | The whole town on the grid for one full day cycle with no blackout |
| 10 | Signals | A data network | Circuit Works, Sensor, Data Cable, Relay Mast, Control Hub | A Control Hub dashboard showing live stock and demand |
| 11 | The Self-Building City | Full automation | Construction Yard, Cargo Port, Substation, Apartment Block, Hospital | A district grows by 100 citizens with no building placed by hand |
| 12 | The Perfect City | Sustainability | Wind Turbine, Solar Array, Battery Bank, Recycler, Treatment Plant | Industry on clean power with electric upgrades, no coal burned, no landfill growth, wellbeing index of 80 or more |

### What gets automated, era by era

1. **Levels 1 to 2:** hauling. The player stops carrying and belts take over.
2. **Levels 3 to 5:** supply. Houses and food arrive from chains the player built once.
3. **Level 6:** daily life. Citizens run their own routines, so the player stops placing people and starts shaping conditions.
4. **Levels 7 to 9:** heavy industry and power, which the player sets up once and then only expands.
5. **Levels 10 to 11:** decisions. Sensors and the Control Hub notice shortages and order construction.
6. **Level 12:** resources. Waste and energy loop back so the city can run indefinitely.

### After Level 12: Sandbox

Sandbox keeps the save and unlocks every item, plus Beyond-only extras: oil field, refinery, plastics works, hydro dam, tower block, tram. There is no goal, only a wellbeing index and the Walk Mode camera.

### Reasons to keep going after Level 12

- **New land and resources:** unexplored regions to imagine into existence, with new deposits and new terrain.
- **Era changes:** the settlement visibly turns into a dense city as new eras unlock, with taller buildings, busier roads and a changing skyline.
- **Landmarks and history:** the player's first buildings stay in the city and tell its story (see the society section).
- **Free build:** Sandbox stays open for players who want no objectives.

## Tutorial and onboarding

The tutorial is the game itself: Levels 1 and 2 are the tutorial, and every later level opens with one short guided step instead of a text wall.

### Rules that keep it from feeling overwhelming

- **One idea per level.** A level introduces a single concept and at most five buildings, and the build menu shows only what has been unlocked.
- **Three buttons at the start.** Level 1 shows Build, Trace and Undo. Menus, stats and policies appear when they become useful.
- **Show, do not tell.** A pulsing outline marks where to tap next, and text never exceeds two short lines.
- **Trace is the teacher.** When something is not working, tapping it explains why in plain words: no input, no power, output blocked.
- **Nothing is lost by mistakes.** Unlimited undo, free demolition within a short window, and no failure states before Level 6.
- **Optional extras stay quiet.** Items marked optional unlock after the goal is met, so they never compete with the main task.
- **Time is on the player's side.** Fast-forward and pause are always available, and the simulation waits during tutorial steps.

### Level 1 script (about 10 minutes, with a belt in the first two)

1. A blank paper map. A line appears: *Start with the ground.* The camera shows a clay deposit beside a lake.
2. The player taps the clay deposit and the Clay Pit appears as the only build option. Placing it makes the first clay appear.
3. Trace shows clay with a gold line back to the deposit: *Everything starts somewhere.*
4. The player places a Lumber Camp on the forest and gets logs.
5. The Brick Kiln unlocks. The player carries the very first lump of clay in by hand, one satisfying trip, and the first brick pops out with a chime.
6. Within two minutes the game hands over a starter belt. The player drags it from pit to kiln and clay flows on its own with a rising hum. Bricks stack beside the kiln and the foundation fills as they arrive, and a Storage Crate holds any spare.
7. The foundation completes, chimney smoke rises and the paper map widens into colour. Level 2 begins with: *One belt is a start. Let us build a real supply line.*

### Level 2 and beyond

Level 1's hand-carrying is short and tactile, with satisfying pickup and drop feedback, so it never feels like a chore. Level 1 gives the player a single starter belt within two minutes, and Level 2 turns it into the full belt toolkit, so belts are an early reward rather than a fix for an invented inconvenience. From there the pattern repeats for every level: a small problem, one new tool, a visible fix, and a reward that opens the map.

### Complexity budget

| Levels | Max buildings on screen to manage | New concept | Failure states |
| --- | --- | --- | --- |
| 1 to 2 | About 8 | Sources, flow | None |
| 3 to 5 | About 25 | Demand, roads, supply chains | Shortages only warn |
| 6 to 8 | About 60 | Citizens, ore, rail | Unhappy citizens leave slowly |
| 9 to 12 | Unlimited, but district-based | Grids, data, automation | Blackouts, shortages, pollution |

From Level 6 on, a district view groups buildings into named districts. The player can zoom out to a one-line status per district (power, water, food, housing) instead of managing individual machines.

## Society: citizens, needs and the god's-eye view

Citizens arrive in Level 6 into a town that already works, and from then on the player's job is to shape conditions, not to rescue people. Each citizen is a small pixel person with a home, a job, a routine and a mood the player can watch.

The citizen system is built in stages. First comes aggregate population (counts, mood and needs per district), then individual routines, then Follow mode. Each stage must feel good before the next begins.

### Citizen needs

| Need | Met by | First available |
| --- | --- | --- |
| Shelter | A home with a free bed | Level 3 |
| Food | Shops stocked with bread, later more variety | Level 5 |
| Water | Pipes, well or tower within reach of the home | Level 4 |
| Warmth | Firewood delivered to homes, later electric heating | Level 6 |
| Health | Clinic, clean air and water, good food | Level 6 |
| Work | A job at a factory, mine, shop or office | Level 6 |
| Leisure | Pub, park, library | Level 6 |
| Safety and light | Street lamps, fire station | Level 9 |
| Education | School, library | Level 8 |

### A day in a citizen's life

Wake at home, walk or ride to work, work a shift, buy food on the way back, spend time at leisure, sleep. Routines use the roads the player built, so a badly planned city produces long commutes and visible crowds.

### Mood and the wellbeing index

Each need has a satisfaction value from 0 to 1. A citizen's mood is a weighted sum, with food, shelter and health weighted highest.

```latex
M = \sum_i w_i s_i
```

`M` is the citizen's mood, `s_i` is the satisfaction of need `i`, and `w_i` is its weight. The **wellbeing index** shown to the player is the average mood across all citizens, scaled to 0 to 100.

### Money, taxes and policies

- Citizens earn wages from jobs and spend them in shops, which creates a small town economy.
- The Town Hall sets **income tax** and **shop tax**. Higher tax pays for services and infrastructure but lowers mood.
- **Policies** are single switches with a trade-off: shorter working days (happier, slower output), free clinic care (healthier, costs money), free school meals (better education, costs food).
- If mood stays low, citizens move away slowly. If it stays high, new households arrive.

### How money flows

The economy is deliberately simple and never a hidden financial simulation.

1. **Workplaces pay wages** based on how productive they are, so money enters through jobs.
2. **Citizens spend wages** on food and services at shops.
3. **Shops earn revenue** from sales and use it to pay for the goods they receive from depots.
4. **The city collects tax** and pays a fixed share of public-service costs such as the clinic, Town Hall and street lamps.
5. **Construction uses physical materials** and a small money cost where it makes sense.

If nobody can afford bread, the dashboard warns the player in plain words (for example *Shops are empty: wages are too low or prices are too high*) rather than expecting them to infer it. Level 6 starts with a single tax rate. Separate income and shop tax, and detailed budgets, only appear if they make decisions more interesting.

### Stats the player sees

- **The average citizen card:** home, job, commute time, hours worked, meals eaten, mood, and what they would change.
- **City dashboard:** population, wellbeing index, income and costs, power and water balance, food variety.
- **Follow mode:** tap any citizen and the camera follows them through their day, with a one-line thought bubble showing what they currently want.

### Events

A short list of fair events keeps the world alive without turning it into a disaster game: drought lowers water, a mine runs dry, a harvest boom, a festival. Each event is visible a day ahead and has a clear way to respond.

### A world with a history

The city should show its progress without the player opening Stats.

- **Landmarks:** the first kiln, first cottage and first power station are remembered. The player can name them, and small plaques mark milestones. They stay in the city as it grows around them.
- **Named citizens:** a handful of recurring characters with names, workplaces and changing routines, rather than hundreds of identical people. A character who first walks a long way to work can later move into a new house near the factory, so the player sees a shorter commute and a better life.
- **Small visible stories:** a baker opens a shop, workers gather at a bus stop, a new family moves into a cottage, an empty street fills with people.
- **Visible era changes:** when a new era unlocks, the map changes. More lights appear, buildings get taller and roads get busier.

## Walk Mode and the character creator

Walk Mode is an optional feature (more work than it looks) that lets the player stand inside the city they built, at street level, and it unlocks in Level 6 with the first citizens. It is never required to progress.

### Character creator

- A quick pixel avatar editor with body shape, skin tone, hair style and colour, outfit, and one accessory, all drawn from the game's 32-colour palette.
- The avatar is made once, can be changed any time, and appears in Follow mode and on the Town Hall wall as the city's founder.
- Shown as a small paper-doll on a plain background, so it takes about 30 seconds.

### Walking the city

- A low-resolution first-person view (about 240×135 internal) scaled with nearest-neighbour filtering, so it matches the pixel look.
- Left thumb moves, right thumb looks, a tap on a citizen or building opens a one-line card.
- Citizens say one short line about their day, pulled from their real state: where they work, what they ate, how they feel.
- Day and night, weather and street lamps all show here. Seeing lit windows and smoke from chimneys is the payoff.
- A photo button saves a pixel snapshot to the Photos library.

### Why it is small

Walk Mode reuses the existing map data and draws each building as a simple extruded block with the same pixel textures, so it needs no new simulation, though it still needs collision, perspective rendering and navigation. It is built last, and if time runs short the game ships without it. The point is the feeling of standing in the world you made, not a second game.

## Landscape UI and touch controls

The world fills the screen and every control sits at an edge within thumb reach, so the player's hands never cover the thing they are building.

### Screen layout

| Area | Contents |
| --- | --- |
| Left edge | Build palette: category tabs (Gather, Make, Move, Power, Homes, Services), then the buildings unlocked in each |
| Top bar | Current level goal with progress, resources summary, shift or day clock, pause and fast-forward |
| Right edge | Context panel for the selected item: status, inputs and outputs, Trace button, demolish |
| Bottom bar | Mode tabs: Build, Roads, Policies, Stats, Trace. Policies and Stats appear from Level 6 |
| Centre | The world, with a minimap in a corner that can be hidden |

### Gestures

- **One finger drag** pans the map when nothing is selected, or lays belts and roads when a belt or road tool is active.
- **Pinch** zooms between detail view and district view.
- **Two-finger rotate** is not used. The map is fixed so pixel art stays crisp.
- **Tap** selects, **long press** opens the inspect card, **double tap** centres on a building.
- **Tap and drag from a machine's output port** starts a belt, with auto-routing around obstacles and a ghost preview before release.

### Quality of life for touch

- Everything snaps to the grid and large touch targets are at least 44 points.
- Copy and paste for sections of a factory arrives in Level 4 as Blueprints, so repeating a good layout is quick on a small screen.
- Haptics on placement, completed goals and errors, and sound for each action.
- Colour-blind safe palette, plus shape and icon cues on top of colour for Trace and power overlays.
- Text size follows the iOS dynamic type setting for menu text.

### Rates, previews and safe experiments

- **Show rates, not just stock.** Each building and district shows made per minute, used per minute and any predicted shortage, because 12 bricks a minute against 15 used says more than 40 bricks in storage.
- **One clear interaction per tool.** Every active tool shows a visible state and has an obvious cancel gesture, so a belt drag is never mistaken for a pan.
- **Preview big changes.** Moving a factory or changing a district's power shows its effect before the player confirms.
- **Searchable build menu.** Category tabs work early on, and a search box appears once more than about 30 items are unlocked.
- **District inspection.** Tapping a district shows its single biggest problem and a one-tap fix where possible.

## Art pipeline: drawing the game in code

Because the game is pixels on a fixed palette, Claude Code can draw the first full set of sprites as code, and you only hand-edit the few that need extra charm.

### How it works

1. `palette.json` holds the 32 colours, each with a one-letter key.
2. Each sprite is a text grid in `Art/sprites`, one character per pixel.
3. A script in `Tools` turns the grids into PNGs, packs them into atlases and writes a manifest the game loads.
4. A checker fails the build if a pixel is off-palette, a sprite is the wrong size, or a building has no variants.
5. Generators make terrain variation, water dither, smoke frames and lit-window night versions from rules.

An example sprite grid (colours are illustrative):

```text
legend: . clear   K outline   R brick   r brick shadow   M mortar

RRRMRRRR
RRRMRRRR
MMMMMMMM
RMRRRMRR
RMRRRMRR
MMMMMMMM
RRRMRRRR
rrrMrrrr
```

### Rules for a handmade look

- Light comes from the top left on everything, so shadows fall to the bottom right.
- Outlines are a darker shade of the sprite's own colour, never pure black.
- At most 4 shades per material.
- Each building has 2 to 3 hand-set variants and a seeded flaw pixel or two, so no two houses match and nothing is perfectly symmetrical.
- Animation is 2 to 4 frames at most: smoke, glow and belt stripes.

### The review loop

Claude Code renders a contact sheet of every sprite at 4× size, looks at it, fixes what is wrong and repeats. You review the sheet and say which sprites to change. For the ones that matter (kiln, cottage, citizens), open the PNG in Pixelorama, edit it by hand and save it in `Art/manual`. A hand-edited file always wins, and the script never overwrites it.

### People and vehicles

People and vehicles work well as code. A first test sheet of people, walk frames, cars and trucks was generated by a script and reads clearly at game size.

- **People:** 8×12 pixels with swappable hair, skin, shirt and trousers colours, so one template gives hundreds of citizens and powers the character creator. Front, side and back views, with side frames mirrored for left-facing.
- **Cars:** 8×14 pixels, top-down, one drawing rotated into four directions, with a palette swap per colour.
- **Trucks:** the same car body with a cargo bed whose colour shows what it carries.

The weak spots are the walk cycle, which needs a human eye because a one-pixel slip looks like limping, and the front-view walk frames, which barely change from standing. Fix those by hand in Pixelorama, or draw a few key sprites by hand where you want extra charm.

### The first 42 sprites (Prototype 1)

| Group | Sprites | Count |
| --- | --- | --- |
| Terrain | Three grass variants, water, shoreline edge, bare dirt, clay ground, paper-edge fog | 8 |
| Nature | Tree, clay deposit marker, rock | 3 |
| Buildings | Clay Pit, Lumber Camp, Brick Kiln, Sawmill, Storage Crate, Foundation, Cottage | 7 |
| Belts | Two straights and four corners | 6 |
| Items | Clay, log, brick, plank | 4 |
| Effects | Three smoke frames and three build-pop frames | 6 |
| Interface icons | Build, Trace, Undo, Demolish, Play and pause, Cancel, Bricks, Goal | 8 |

## Technical plan for Swift, SpriteKit and Xcode

The simulation is kept separate from rendering, so the world can run, save and be tested without any graphics. SpriteKit only draws what the simulation says exists.

### Architecture

| Layer | Technology | Responsibility |
| --- | --- | --- |
| Simulation | Plain Swift types, no UIKit | Grid, buildings, items, power, water, citizens, economy |
| Rendering | SpriteKit | Tile layers, sprites, belt items, lighting, camera |
| Interface | SwiftUI over the SpriteKit view | Build palette, panels, stats, policies, tutorial prompts |
| Persistence | Codable structs saved as JSON (or SwiftData) | Autosave every 30 seconds and on backgrounding |
| Walk Mode | SceneKit or a simple raycaster | Extruded buildings on the same map data |

### Simulation design

- **Fixed tick of 10 per second**, independent of frame rate, with a speed multiplier for fast-forward.
- **Grid of chunks** (for example 32×32 tiles). Only chunks near the camera render, and distant chunks run on a cheaper aggregate tick.
- **Belts** move items as discrete slots along each belt segment, not as physics objects.
- **Recipes are data**, stored in a JSON file (inputs, outputs, time, power use, level), so adding an item never needs new code.
- **Networks** (power, water, data) are graphs rebuilt only when something is placed or removed, and each tick solves supply against demand per graph.
- **Citizens** use flow-field pathfinding over the road graph, one field per destination type, so hundreds of citizens stay cheap.
- **Trace** is a reverse search through recipes and placed buildings from any item or building back to its sources.

### Art and audio pipeline

- Pixel art drawn in free tools such as Pixelorama or Aseprite, exported as sprite atlases on one shared palette.
- Nearest-neighbour filtering on all textures, with the scene rendered at low resolution and scaled up.
- Free or self-made audio, and a small sound-mixer layer so machine sounds fade with distance and zoom.

### Performance targets

- 60 frames per second on an iPhone 12 or newer, with a 30 fps fallback on older devices.
- 2,000 active belt items and 300 citizens on screen without dropped frames.
- Save file under 5 MB for a late-game city, with a load time under 3 seconds.

### Known risks and early tests

The architecture is sound, but several parts are harder than they look and must be tested before the world gets large.

- **Networks:** power and water need rules for disconnected sections, competing demand, capacity and fair distribution.
- **Time:** a 10-tick simulation must behave identically under fast-forward, saving, and backgrounding the app.
- **Crowds:** hundreds of citizens on a shared road network can cause congestion and pathfinding edge cases.
- **Walk Mode:** it needs collision, perspective rendering, navigation and a readable way to draw the same buildings, so it is a real feature, not a camera change.
- **Targets are assumptions:** the performance numbers above are goals, not facts, until measured.

First test: build a tiny headless simulation with about 20 buildings and a few moving items, run it without graphics, and confirm that saving, loading and fast-forward give identical results before adding a large world.

## Build roadmap and open questions

Build the game in vertical slices, so something playable exists after every milestone. The week counts are rough estimates for part-time solo work and will move.

### Milestones

| Milestone | What is playable at the end | Rough time |
| --- | --- | --- |
| M0: Prototype | A headless simulation test with about 20 buildings, plus a pixel map in landscape with camera pan and zoom and one placeable building | 1 to 2 weeks |
| M1: Levels 1 and 2 | Clay, logs, kiln, belts, waterwheel, Trace, tutorial script | 3 to 4 weeks |
| M2: Levels 3 to 5 | Houses, roads, water, food chain, first shop, level goals and save | 4 to 6 weeks |
| M3: Level 6 | Citizens, needs, mood, Town Hall, taxes, stats dashboard | 4 to 6 weeks |
| M4: Levels 7 to 9 | Mining, smelting, steam, rail, electricity, district view | 6 to 8 weeks |
| M5: Levels 10 to 12 | Data network, Control Hub, auto-construction, clean power, recycling | 6 to 8 weeks |
| M6: Polish | Audio, art pass, balancing, accessibility, TestFlight | 4 to 6 weeks |
| M7: Walk Mode | Character creator and street-level view | 2 to 4 weeks |

### Scope cuts: postponed until the core is fun

| Feature | Plan |
| --- | --- |
| First-person Walk Mode | Build last and only after the simulation is finished. Optional. |
| Detailed taxes and economy | Start with wages and one tax rate. Expand only if it makes decisions more interesting. |
| Citizen-level simulation | Start with aggregate population stats, then add routines and Follow mode. |
| Drones | Stretch goal. Trucks and rail give enough logistics, and Level 11 works without them. |
| Full waste recycling | Start with a landfill and a pollution number. Add the recycler loop later. |
| Weather and random events | Add after the base game is balanced, so they never hide design problems. |
| All 12 levels | Build the first three as a complete playable slice (Prototype 1), then continue. |

Islands follow the same rule: build only Home Island at first, and add Copper Isle once Prototype 1 passes the fun test and the citizen system works. Sea links, cargo ships and the second map are a separate milestone after M3.

### First thing to build

Start with M0 and the Trace Rule data model together: the recipe JSON, the grid, and a single reverse search from a brick back to clay. If that works cleanly on a tiny map, the rest of the game stands on it.

Prototype 1 (Levels 1 to 3) should be reached partway through M2, and no work on M3 starts until it passes the fun test described above.

### Open questions

- [ ] Is Groundwork the final name? Check the App Store for clashes before art or branding work.
- [ ] Is it a paid app, free with a one-time unlock, or free with cosmetic purchases?
- [ ] Should the map be a fixed handcrafted world per level, or generated with a seed?
- [ ] How large is a level map: one screen, or a scrolling region that grows as the player imagines new land?
- [ ] Do citizens ever die, or do they only move away? The current design avoids death to keep the tone gentle.
- [ ] Should the player have any named characters, such as a guide who appears in the tutorial?
- [ ] Is Walk Mode full 3D, or a simple raycaster to keep the pixel look?

### Decisions to settle before building much

- [ ] **Main feeling to chase:** solving factory puzzles, building a world from nothing, creating a living city, or a balance of the three.
- [ ] **How the world grows:** fixed handcrafted maps per level, a procedural world, or a handcrafted start that expands as the player progresses.
- [ ] **Pressure level:** relaxed with few consequences, strategic with manageable problems, or challenging with real risk of failure.
- [ ] **Development goal:** a learning project that grows slowly, a fun prototype as soon as possible, or a polished App Store release.

Current working assumption, until decided: a balance of all three feelings, a handcrafted start that expands, and relaxed-to-strategic pressure.

## Building Groundwork with Claude Code in Xcode on your MacBook

The practical split is that Claude Code writes, builds and tests the Swift code from the terminal, while you handle Xcode, the simulator, the art and the play-testing.

### One-time setup

1. **Install Xcode** from the Mac App Store, open it once, accept the licence and let it install the iOS simulator. In Terminal, `xcode-select -p` should point at Xcode, not only the Command Line Tools.
2. **Install Claude Code.** In Terminal run `curl -fsSL https://claude.ai/install.sh | bash`, open a new Terminal window and check with `claude --version`. Homebrew also works with `brew install --cask claude-code`. It asks you to sign in on first use and needs a Claude subscription or Console account ([setup guide](https://code.claude.com/docs/en/overview)).
3. **Create the project in Xcode:** iOS App, Swift, SwiftUI, named Groundwork. Set the supported orientations to landscape only and the minimum iOS version to 17.
4. **Start the repo.** In Terminal, `cd` into the project folder, run `git init`, make a first commit, then run `claude`.

Recent Xcode projects use folders that sync with the files on disk, so files Claude Code adds appear in Xcode automatically. If a file does not appear, add it in Xcode or ask Claude Code to set up a project generator such as XcodeGen.

### Project structure

| Folder | Contents | Why |
| --- | --- | --- |
| GroundworkCore (Swift package) | Grid, recipes, belts, roads, networks, citizens, Trace, saving | No graphics, so it can be built and tested from the terminal |
| Groundwork (app target) | SpriteKit scene, SwiftUI menus, assets | A thin layer that draws what the simulation says |
| Data | recipes.json, levels.json, tutorial steps | Add content without changing code |
| Tools | Scripts that generate placeholder sprites and atlases | Gets the game visible before final art exists |
| docs/DESIGN.md | This design doc exported as Markdown | Claude Code reads the plan before each task |
| CLAUDE.md | Project rules | Read by Claude Code at the start of every session |

### How Claude Code checks its own work

- `swift test` runs the unit tests in GroundworkCore, such as "a brick traces back to clay".
- `xcodebuild` builds the app for the iOS Simulator from the terminal, so Claude Code reads compile errors and fixes them without you.
- `xcrun simctl` can boot a simulator, install and launch the app, and take a screenshot that Claude Code can look at.
- It cannot feel the game. Whether belts feel satisfying, or a level is too long, is your call after you play it.

### Starter CLAUDE.md

```markdown
# Groundwork
iOS landscape pixel-art factory and city builder.
Design doc: docs/DESIGN.md. Read the relevant section before each task.

## Rules
- Swift only. SpriteKit for the world, SwiftUI for menus. iOS 17+.
- All game logic lives in the GroundworkCore package with no UIKit or SpriteKit imports.
- Recipes, levels and tutorial steps are JSON in Data/. Never hard-code a recipe.
- The simulation runs at a fixed 10 ticks per second. Rendering never changes simulation state.
- Pixel art: one 32-colour palette, nearest-neighbour filtering, 16x16 tiles.
- Every new system gets unit tests in GroundworkCore.

## Commands
- Test: cd GroundworkCore && swift test
- Build: xcodebuild -scheme Groundwork -destination 'platform=iOS Simulator,name=<device from xcrun simctl list devices>' build

## Definition of done
Tests pass, the app builds, the change is committed with a clear message,
and CLAUDE.md is updated if a rule changed.
```

### Build order and what to ask for

| Step | What to ask Claude Code | How you know it worked |
| --- | --- | --- |
| 1. Scaffold | Read CLAUDE.md and docs/DESIGN.md. Create the GroundworkCore package with a tile grid, a recipe loader and a first test. | `swift test` passes |
| 2. Trace first | Add recipes.json with clay, log and brick. Build the reverse search from a brick to its sources and test it. | Tests show brick traces to clay and log |
| 3. Map on screen | Add a SpriteKit scene with a 64×64 placeholder tile map in landscape, with pan and pinch zoom. | You can pan and zoom in the simulator |
| 4. Placeholder art | Write a script in Tools that generates placeholder pixel tiles on the shared palette. | Tiles show on the map |
| 5. Buildings | Place a Clay Pit, Lumber Camp and Brick Kiln by tapping, and produce items on each tick. | Item counts rise on screen |
| 6. Hand carry | Add picking up and dropping items, and a Storage Crate. | You can move bricks by hand |
| 7. Belts | Add drag-to-lay belts that auto-route, with items moving as slots. | Clay flows to the kiln unaided |
| 8. Levels 1 and 2 | Load levels and tutorial steps from JSON and run the Level 1 script. | You can play both levels start to finish |
| 9. Save and load | Autosave every 30 seconds and on backgrounding. | A restarted app restores the same world |
| 10. Roads and trucks | Add drag-to-lay roads, depots and fixed-route trucks. | Trucks deliver between two depots |

### Working rules

- **One task per session**, and ask Claude Code to plan before any large change.
- **Commit after every working step**, so a bad change is one command away from undone.
- **Keep tests running from the start**, because the simulation gets harder to change safely as it grows.
- **You do:** run the game in the simulator and on your iPhone (Xcode can sign for your own device with a free Apple ID), judge the feel, make the final pixel art in a tool like Pixelorama or source a free pack, and answer the open design questions.
- **Claude Code does:** scaffolding, simulation, tests, UI, saving, refactors and placeholder art scripts.

### First week, roughly

Day 1: setup, repo and scaffold. Day 2: Trace and its tests. Day 3: map and camera. Day 4: buildings and production. Day 5: hand carry and the first belts. By then you have a playable Level 1 to test on your phone.

## The Claude Code master prompt

Paste the prompt below into Claude Code as your very first message, from inside the project folder. It builds Prototype 1 only, in phases, and stops after each one so you can play it before anything else is added.

### Which model to use

- **Opus 5.5 for the hard foundations:** the planning step and Phases 1 to 3 (simulation core, Trace, belts). Mistakes there are expensive, because everything else is built on them.
- **Sonnet 5.5 for everything after that:** UI, level scripts, saving, art scripts and polish. It is faster and cheaper, and the architecture is already settled.
- **Switch back to Opus** whenever Sonnet is going in circles on a bug. In Claude Code you switch with the `/model` command.
- **Skip Haiku** for this project. It is fine for small chores, but not for a simulation where correctness matters.
- Which models you can pick depends on your plan, so check what `/model` lists. You do not need the most powerful tier for a 2D game.

### Before you paste it

1. Export this doc as Markdown and save it as `docs/DESIGN.md` in the project.
2. Create the Xcode project yourself (iOS App, Swift, SwiftUI, landscape only, iOS 17 or later), then `git init` and make a first commit.
3. Run `claude` in the project folder, press Shift+Tab until plan mode is on, then paste the prompt.

### Master prompt

```text
You are building "Groundwork", an iOS landscape pixel-art factory and town builder, in Swift in Xcode. The full design is in docs/DESIGN.md. Read all of it before doing anything, then read it again whenever a task touches a system it describes.

THE ONE-LINE PITCH
Build the ground, trace everything back to nature, and watch a town come alive on it. The signature feature is Trace: tap any item or building and see its whole chain back to a natural source, and why it is blocked.

SCOPE: PROTOTYPE 1 ONLY
Build only what the "Prototype 1" section of the design describes: a pixel-art map with a lake, forest and clay deposit; clay pit, lumber camp, brick kiln, sawmill, storage crate; hand-carrying; belts; a brick and plank chain; a cottage; one simple demand rule that orders cottages automatically; Trace; saving; the Level 1 script. Do NOT build citizens, shops, taxes, roads and trucks, rail, power grids, data networks, islands, Walk Mode or the character creator. If you think something outside this scope is needed, ask me first.

ENVIRONMENT
- The Xcode project already exists. Never regenerate or overwrite the .xcodeproj. Add source files inside the project's synced folders. If a file does not show up in Xcode, tell me rather than editing the project file by hand.
- Swift only. SpriteKit draws the world, SwiftUI draws menus and overlays. iOS 17 or later. Landscape only. iPhone first, iPad supported.
- All game logic lives in a Swift package called GroundworkCore with NO imports of UIKit, SpriteKit or SwiftUI, so it builds and tests from the terminal with `swift test`.
- Content is data. Recipes, buildings, levels and tutorial steps are JSON files under Data/. Never hard-code a recipe, cost or level goal in Swift.
- Use only the Swift standard library, Foundation, SpriteKit and SwiftUI. Ask before adding any third-party dependency.

ARCHITECTURE RULES (do not break these)
1. The simulation is separate from rendering. The simulation never knows sprites exist. The renderer only reads simulation state and never changes it.
2. Fixed simulation tick of 10 per second, independent of frame rate. Fast-forward runs more ticks per frame, never longer ticks. Given the same save file and the same inputs, the simulation must produce identical results every time. No randomness without a seeded generator stored in the save.
3. Everything on the map is a Codable value type that can be saved and loaded.
4. Belts move items as discrete slots along each belt segment, not as physics objects.
5. Trace is a pure function: given an item or a building, it searches back through recipes and placed buildings and returns the chain, with a state (running, slow, blocked) and a plain-English reason for each step. It must work on a headless simulation with no graphics.
6. Every building reports its rate (made per minute, used per minute) so shortages can be shown before they happen.

THE FIRST TWO MINUTES (this decides whether the game is fun)
The opening must follow this beat sheet exactly, because the whole game depends on it feeling good:
- 0:00 blank paper map, camera finds a clay deposit beside a lake.
- 0:20 player taps the deposit and places the Clay Pit. It pops in with a small bounce and a dust puff. Clay appears.
- 1:00 the Brick Kiln is placed. The player hand-carries the very first clay in. A chime sounds and the first brick pops out.
- 2:00 the game hands over a starter belt. The player drags it from pit to kiln and clay flows on its own with a low hum.
A new player must reach the first working belt within 2 minutes without reading anything longer than two short lines of text.

GAME FEEL REQUIREMENTS
- Every tap reacts within 100 ms. No loading screens. No confirmation dialogs for normal actions.
- Placing: small bounce plus dust puff. Items spawn with a quick squash. Belts show direction with moving stripes.
- A working machine hums; throughput raises the pitch; a blocked machine goes quiet, dims and pulses amber.
- Light haptics when placing, a double tap when a goal completes.
- Unlimited undo, and free demolition for a short window after placing.
- Floating +1 numbers only for the first few items, never constant noise.
- Placeholder sounds are fine (generate simple tones in code) but the hooks for every sound above must exist.

LANDSCAPE UI
Build palette on the left edge, goal and clock along the top, context panel on the right when something is selected, mode tabs along the bottom (Build, Trace). The world fills the screen. One finger drags to pan when no tool is active; when a belt tool is active, one finger lays belts, with a visible tool state and an obvious cancel. Pinch zooms. Tap selects, long press inspects. Everything snaps to the grid. Touch targets at least 44 points. At the start show only three buttons: Build, Trace, Undo.

ART: DRAW IT IN CODE
No external art exists yet. Create an art pipeline:
- Art/palette.json: one 32-colour palette with one-letter keys. Every sprite uses only these colours.
- Art/sprites/: each sprite is a text grid, one character per pixel, 16x16 tiles (people 8x12, cars 8x14).
- Tools/make_art.py (Python 3, standard library only): turns the grids into PNGs, packs a texture atlas, writes a manifest, and fails if any pixel is off-palette or any sprite is the wrong size. A hand-edited PNG in Art/manual always overrides the generated one and must never be overwritten.
- Rules: light from the top left; outlines are a darker shade of the sprite's own colour, never pure black; at most 4 shades per material; 2 to 3 variants per building with a seeded flaw pixel or two so nothing is perfectly symmetrical.
- Render the world at low internal resolution (about 480x270) and scale up with nearest-neighbour filtering so pixels stay crisp.
- Make the first 42 sprites listed in the design's art section. After generating them, render a 4x contact sheet, LOOK at it, and fix anything that reads badly before showing me.

TESTS (required)
Every system in GroundworkCore gets unit tests. At minimum: a brick traces back to clay and a log; a blocked kiln reports exactly which input is missing; belts deliver items in order and never lose or duplicate one; save then load then run gives identical results to running without saving; running 1000 ticks at normal speed and the same 1000 ticks in fast-forward give identical results; the demand rule orders a cottage only when brick and plank supply is steady.

HOW TO WORK
1. FIRST, do not write code. Use plan mode. Read docs/DESIGN.md, then give me: the package and folder layout, the core data types, the recipe and level JSON formats with one worked example each, the phase list below with the acceptance test for each, and any questions or contradictions you found in the design. Wait for my approval.
2. Then work phase by phase. After each phase: run `swift test`, build the app for the iOS Simulator with xcodebuild, fix errors yourself, commit with a clear message, and STOP. Report in this format: what works, what you tested, what I should try by hand in the simulator, what felt wrong to you. Do not start the next phase until I say go.
3. If the build or tests fail twice for the same reason, stop and tell me what you tried instead of looping.
4. Never delete or rewrite working code to "clean up" unless I ask. Keep changes small and scoped to the phase.
5. Keep CLAUDE.md up to date. Create it in phase 0 with these rules, the build and test commands, and the definition of done: tests pass, the app builds, the change is committed.
6. Be honest about what you cannot judge. You cannot feel the game. Tell me what to play-test rather than claiming it feels good.

PHASES
0. Plan and CLAUDE.md (no code).
1. GroundworkCore: grid, recipe and building loaders, tick loop, first tests.
2. Trace: recipes.json with clay, log, brick, plank; the reverse search and its blocked-step reasons; tests.
3. Production: gathering and processing buildings producing on each tick, rates, storage crate, hand-carry rules; tests.
4. Belts: drag-to-lay with auto-routing, items as slots, splitters later; tests.
5. Art pipeline and the first 42 placeholder sprites; contact sheet for my review.
6. Rendering: SpriteKit scene, 64x64 map, low-res scaled output, pan and pinch zoom, buildings, moving items, day-night light.
7. Interaction and UI: build palette, placing, belt dragging, selection, Trace overlay with tap-to-jump, undo.
8. Level 1 script: the two-minute beat sheet, tutorial prompts as data, goal and completion.
9. Cottage and the demand rule, then Level 2 start (waterwheel and quarry only if time allows).
10. Saving and loading: autosave every 30 seconds and on backgrounding; restore the exact world.
11. Feel pass: bounce, dust, hum, haptics, sound hooks, amber pulse for blocked machines.

START NOW with phase 0 only.
```

### Follow-up prompts to reuse

| When | Paste this |
| --- | --- |
| After each phase passes | `Go. Start the next phase. Same rules: tests, build, commit, stop and report.` |
| Something feels wrong | `The [belt placing / opening / Trace] feels [describe it]. Do not add features. Propose two ways to fix the feel and wait for my choice.` |
| A bug you cannot explain | `Reproduce this bug in a unit test first, show me the failing test, then fix it. Bug: [describe].` |
| Before a big change | `Plan only, no code. What would change, what could break, and what tests protect it?` |
| Claude Code drifts from scope | `Stop. That is outside Prototype 1. Revert it and re-read the Prototype 1 section of docs/DESIGN.md.` |
| Art looks off | `Render the contact sheet at 4x, look at it, list what reads badly, then fix those sprites and re-render.` |
| End of a session | `Update CLAUDE.md with anything you learned, commit, and write a 5-line summary of where we are and what is next.` |
| Fun test time | `Add a debug overlay that logs time to first belt, time to first bottleneck fixed, and session length, so I can run the fun test with friends.` |

## No Mac yet: build the core in the cloud first

You can do phases 0 to 5 without a MacBook, using Claude Code on the web (claude.ai/code or the Claude mobile app) on a GitHub repo. Phases 6 to 11 (rendering, touch, sound, feel) need Xcode and the simulator, so they wait for the Mac.

### What works without a Mac

| Part | Works in the cloud? | Notes |
| --- | --- | --- |
| GroundworkCore Swift package and `swift test` | Yes, if Swift installs | Swift runs on Linux, but the cloud session may not have it. The prompt asks Claude Code to check and install it first. |
| Recipes, levels, tutorial data | Yes | Plain JSON |
| Art pipeline and the 42 placeholder sprites | Yes | Python 3, standard library only |
| CLAUDE.md, DESIGN.md, phase plan | Yes | Plain text |
| SpriteKit, SwiftUI, iOS Simulator, device testing | No | Needs Xcode on a Mac |

### Setup

1. Create a free GitHub account and a private repo named `groundwork` (tick the option to add a README).
2. Export this doc as Markdown, and add it to the repo as `docs/DESIGN.md` (on GitHub: Add file, Upload files, then rename it).
3. Open Claude Code on the web, connect the `groundwork` repo, and pick Opus 5.5 for these phases.
4. Paste the prompt below as your first message.
5. When you get the Mac: clone the repo, create the Xcode project inside it, and use the master prompt above from phase 6, with the "Project already exists" line adjusted to match.

### No-Mac prompt

```text
You are building the simulation core, data and art pipeline for "Groundwork", a landscape pixel-art factory and town builder for iOS. The full design is in docs/DESIGN.md. Read all of it before doing anything, and re-read the relevant section whenever a task touches a system it describes.

THE ONE-LINE PITCH
Build the ground, trace everything back to nature, and watch a town come alive on it. The signature feature is Trace: tap any item or building and see its whole chain back to a natural source, and why it is blocked.

SITUATION
I do not have a Mac yet, so there is no Xcode and no Xcode project. You are working in a Linux cloud session on a GitHub repo. Do phases 0 to 5 below ONLY, then stop. A later session on a Mac will add the Xcode app, SpriteKit rendering, touch UI and sound, so design everything here so it plugs into that cleanly.

SCOPE: PROTOTYPE 1 ONLY
Build only what the "Prototype 1" section of the design describes: clay pit, lumber camp, brick kiln, sawmill, storage crate; hand-carrying rules; belts; a brick and plank chain; a cottage; one simple demand rule that orders cottages automatically; Trace; saving; the Level 1 script as data. Do NOT build citizens, shops, taxes, roads and trucks, rail, power grids, data networks, islands, Walk Mode or the character creator. If you think something outside this scope is needed, ask me first.

FIRST, CHECK THE TOOLCHAIN
Run `swift --version`. If Swift is missing, try to install a Linux Swift toolchain (use the official swift.org instructions or swiftly) and tell me exactly what you did. If you cannot get Swift working after two attempts, STOP and tell me. Do not fake the tests or switch to another language without asking.

REPO LAYOUT
- GroundworkCore/ : a Swift package (Package.swift, Sources/GroundworkCore, Tests/GroundworkCoreTests). Standard library and Foundation only. NO imports of UIKit, SpriteKit, SwiftUI or anything Apple-only, so it builds and tests on Linux and also on macOS later.
- Data/ : recipes.json, buildings.json, levels.json, tutorial.json. Content is data. Never hard-code a recipe, cost or level goal in Swift.
- Art/ : palette.json, sprites/ (text grids), manual/ (hand-edited PNGs that always win and are never overwritten).
- Tools/ : make_art.py (Python 3, standard library only).
- docs/ : DESIGN.md (already here), plus docs/INTEGRATION.md (see phase 5).
- CLAUDE.md : rules, commands, definition of done.

ARCHITECTURE RULES (do not break these)
1. The simulation is separate from rendering. It never knows sprites exist. A future renderer will only read its state and never change it.
2. Fixed simulation tick of 10 per second. Fast-forward runs more ticks, never longer ticks. The same save and the same inputs must always give identical results. No randomness without a seeded generator stored in the save.
3. Everything on the map is a Codable value type that can be saved and loaded.
4. Belts move items as discrete slots along each belt segment, not as physics.
5. Trace is a pure function: given an item or building, it searches back through recipes and placed buildings and returns the chain, with a state (running, slow, blocked) and a plain-English reason for each step. It works headless.
6. Every building reports its rate (made per minute, used per minute) so shortages are visible before they happen.
7. Expose one clean public API (a GameSession type) that a UI can call: place, remove, undo, start a belt, hand-carry pick up and drop, advance by N ticks, query state, trace, save, load, and receive events (item produced, building placed, goal reached, blocked) for sound and animation hooks. The future renderer must need nothing else.

TESTS (required, run with `swift test`)
A brick traces back to clay and a log; a blocked kiln reports exactly which input is missing; belts deliver items in order and never lose or duplicate one; save then load then run gives identical results to running without saving; 1000 ticks at normal speed equal the same 1000 ticks in fast-forward; the demand rule orders a cottage only when brick and plank supply is steady; the Level 1 script can be completed by a scripted headless player (a test that places buildings and moves items through the public API and reaches the goal).

ART PIPELINE
Tools/make_art.py turns Art/sprites text grids into PNGs using Art/palette.json (one 32-colour palette, one-letter keys), packs an atlas, writes a manifest, and exits with an error if any pixel is off-palette or any sprite is the wrong size. Rules: 16x16 tiles (people 8x12, cars 8x14), light from the top left, outlines a darker shade of the sprite's own colour never pure black, at most 4 shades per material, 2 to 3 variants per building with a seeded flaw pixel or two. Make the first 42 sprites listed in the design's art section, render a 4x contact sheet, LOOK at it, fix anything that reads badly, and commit the sheet to the repo as Art/contact_sheet.png.

HOW TO WORK
1. Do not write code first. Read docs/DESIGN.md, check the toolchain, then give me: the folder layout, the core data types, the JSON formats with one worked example each, the GameSession API, the phases with acceptance tests, and any contradictions you found. Wait for my approval.
2. Then one phase at a time. After each phase: run `swift test`, fix failures yourself, commit with a clear message, push, and STOP. Report: what works, what you tested, what I should check, and what you are unsure about. Do not start the next phase until I say go.
3. If tests fail twice for the same reason, stop and tell me what you tried instead of looping.
4. Do not delete or rewrite working code to tidy up unless I ask.
5. Keep CLAUDE.md up to date.
6. Be honest: you cannot feel the game. Say what needs human play-testing.

PHASES
0. Toolchain check, plan, CLAUDE.md (no game code).
1. GroundworkCore: grid, loaders, tick loop, first tests.
2. Trace: recipes for clay, log, brick, plank; reverse search with blocked-step reasons; tests.
3. Production: gathering and processing buildings, rates, storage crate, hand-carry rules; tests.
4. Belts: drag-to-lay path with auto-routing, items as slots; tests. Then the cottage and the demand rule.
5. Level 1 as data plus the headless scripted-player test; the art pipeline and the 42 sprites with the contact sheet; and docs/INTEGRATION.md explaining exactly how a SpriteKit renderer and SwiftUI interface should plug into GameSession, so the Mac session can start straight away.

START NOW with phase 0 only.
```

### When the Mac arrives

- Clone the repo, then create the iOS app in Xcode inside the same folder (iOS App, Swift, SwiftUI, landscape only, iOS 17 or later).
- Add `GroundworkCore` to the app as a local package, and tell Claude Code: "Read docs/INTEGRATION.md, then start phase 6 of the master prompt. The Xcode project exists now and GroundworkCore is already tested."
- Switch to Sonnet 5.5 for phases 6 to 11 unless something gets hard.
