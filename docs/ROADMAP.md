# Ant Colony Wars — Development Roadmap

Build one phase at a time. Do not start the next phase until acceptance criteria for the current phase pass.

## Long-Term Design Commitments

- The final game is multiplayer-first at the architecture level, even while single-player is built first.
- Maps will be much larger than the current prototype world.
- Worlds will be procedurally generated from deterministic seeds, similar to a Minecraft-style seed flow: the same seed must produce the same terrain, food distribution, chambers, obstacles, and starting colony positions on every machine.
- Multiplayer must share only the seed plus validated player commands where possible; clients must never invent map state locally.
- Large seeded maps require chunk-aware generation, deterministic pathfinding inputs, and performance budgets for many ants, rooms, jobs, and soldiers.

---

## Phase 0 — Project Setup ✓

**Goal:** Clean folder structure, asset loader working, project runs without errors.

### Features
- All folders created (scenes, scripts, assets, data, docs)
- `ASSET_MANIFEST.json` populated with all known asset paths
- `asset_loader.gd` autoload registered in `project.godot`
- Placeholder system confirmed: missing assets print warnings, never crash
- All planning docs present in `docs/`

### Files Likely Changed
- `project.godot` — add `[autoload]` entry
- `data/ASSET_MANIFEST.json` — created
- `scripts/assets/asset_loader.gd` — created
- `docs/*.md` — created

### Test Checklist
- [ ] Open Godot 4.6, no import errors in FileSystem panel
- [ ] Press F5 — project starts without errors
- [ ] Output panel shows "AssetLoader: manifest loaded (5 categories)."
- [ ] Output panel shows per-asset warnings (not crashes) for every missing file
- [ ] `AssetLoader.get_ant_sprite("worker")` returns a non-null texture in the debugger

### Acceptance Criteria
- Project runs with zero errors
- Asset loader is registered as an autoload singleton
- All planning docs are in `docs/` or `data/`

### What NOT to Do in This Phase
- Do not create any game scenes (.tscn files)
- Do not write any game logic
- Do not add real art files yet
- Do not configure networking or multiplayer

---

## Phase 0.5 — Asset Pipeline Tool ✓

**Goal:** One command converts any dropped sprite sheet into correctly named, background-removed PNGs in the right Godot asset folders. All 20 placeholder sprites generated so the game can run with zero real art.

### How It Works
1. Drop a PNG (single sprite or sprite sheet) into `assets_inbox/{category}/`
2. Add an entry in `assets_inbox/pipeline_config.json` (or skip for single sprites — auto-detect applies)
3. Run `python process_assets.py`
4. Processed sprites land in `assets/sprites/{category}/` ready for Godot to import

### Features
- **Background removal**: auto-detect BG color from image corners, or specify an exact hex color (`"#FF00FF"`)
- **Sprite sheet cropping**: grid mode (`columns` × `rows`) for uniform sheets; auto mode for content-aware separation
- **Rename on export**: map sheet cells to exact filenames the manifest expects (`outputs` list in config)
- **Resize**: `output_size: [w, h]` forces sprites to a standard size (tiles → 16×16, rooms → 64×64, etc.)
- **Placeholder generator**: `python tools/generate_placeholders.py` — generates all 20 sprites programmatically
- **Dry-run**: `--dry-run` previews what would be written without touching any files
- **Manifest gap report**: `--check` lists which manifest-expected files are still missing

### Test Checklist
- [x] `pip install -r requirements.txt` — no errors
- [x] `python process_assets.py --dry-run` — runs without crash on empty inbox
- [x] `python tools/generate_placeholders.py` — 20 placeholder PNGs generated
- [x] `python process_assets.py --check` — all 5 categories show "coverage OK"
- [ ] Open Godot, confirm 20 assets import with no errors in FileSystem panel

### Acceptance Criteria
- Single command processes all categories
- All 20 placeholder PNGs exist in correct asset folders
- No crash on empty inbox or missing config

### What NOT to Do in This Phase
- Do not build any game code
- Do not hand-edit output sprites — fix the source and re-run the pipeline
- Do not add animation support yet (that's Phase 8)

---

## Phase 1 — Single-Player Colony Prototype

**Goal:** A playable bare-bones colony driven by markers and a simple job queue. Player places markers; ants execute them autonomously.

### Design Summary
The player is the colony brain. The player clicks a dirt tile to mark a dig destination. The game traces the shortest path from the existing tunnel network to that tile and queues Dig Markers for every dirt tile along the route. Workers score all unclaimed jobs, claim the best one, pathfind to it, and dig. Workers auto-seek food when idle but stop gathering when food is maxed so they redirect effort to digging. Nothing moves because the player told it to — everything moves because an ant scored and claimed a job.

### Features
- TileMap with `dirt_tile`, `tunnel_tile`, `stone_tile`, `queen` tile types (TileSet built in code via AssetLoader)
- Left-click dirt tile → multi-source BFS from whole tunnel network → Dig Markers + DIG jobs for all tiles along shortest path to target
- `job_queue.gd` — TYPE_DIG / TYPE_GATHER int constants, Job class, claim/release/complete/score
- Worker ant scene with 4-state FSM: `IDLE → MOVING → WORKING → IDLE_WANDER`
- Workers score jobs: `priority_weight + (10 / (distance + 1))` — simplified, no danger score yet
- BFS pathfinding for worker navigation; unreachable jobs released and skipped
- 5 starting workers — 4 handle food, 1+ available for digging at all times
- Workers skip GATHER jobs when food is at max; re-evaluate all jobs before re-adding food source (prevents ants from looping on food forever)
- `colony_state.gd` — food count, max_food, priority dictionary
- `game_manager.gd` — autoload, food/ant-count signals
- HUD: food counter and worker count labels
- Queen Chamber — 3×3 protected tiles; cannot be dug
- Camera: zoom=1.0, entire 60×40 tile world fits in 1280×720 viewport

### Files Changed
- `scenes/main/main.tscn` — root scene with TileMap
- `scenes/ants/worker_ant.tscn` — worker ant scene
- `scenes/ui/hud.tscn` — food and worker count labels
- `scripts/core/game_manager.gd` — autoload
- `scripts/core/colony_state.gd` — food, priority dictionary
- `scripts/core/job_queue.gd` — plain int constants, claim/release/score API
- `scripts/ants/worker_ant.gd` — FSM + BFS + job scoring + gather re-evaluation
- `scripts/ui/hud.gd` — updates labels from signals
- `scripts/main.gd` — auto-path dig, world gen, food sources
- `project.godot` — display settings, autoloads
- `data/colony/colony_config.json` — 5 starting workers

### Test Checklist
- [ ] Press F5 — no errors, 5 workers visible and moving
- [ ] Workers autonomously walk to surface food tiles; food counter increments
- [ ] Left-click a deep dirt tile → orange markers trace full path from tunnel to target
- [ ] Ants dig path tiles outward from tunnel; markers clear as each tile finishes
- [ ] Fill food to 200 → ants switch from gathering to digging
- [ ] Cannot place Dig Marker on Queen Chamber tiles
- [ ] No null-reference errors in Output

### Acceptance Criteria
- Player places markers; ants autonomously execute them — no direct ant control
- Worker FSM cycles correctly without getting stuck
- Job queue correctly prevents two ants from claiming the same job
- BFS pathfinding finds a route or skips the job if unreachable
- Food counter increments from worker behavior, not player action
- Zero errors on F5

### What NOT to Do in This Phase
- Do not move ants directly from any script outside their FSM
- Do not add priority levels yet — all jobs are equal weight (simplified scoring only)
- No soldier ants
- No room placement
- No enemy spawning
- No split-screen or multiplayer code
- Do not build full A* — simple BFS is enough

---

## Phase 2 — Priority System & Job Score

**Goal:** Give the player meaningful colony-level control. Workers make smarter decisions based on priorities. The colony brain has real levers to pull.

**Status:** Implementation started. Priority cycling, JSON priority weights, scored jobs, emergency re-score, and the HUD Priority Panel are in place. Godot editor/runtime validation is still required.

### Design Summary
Phase 1 workers pick the nearest available job. Phase 2 workers pick the *best* job based on a score that includes colony priorities, distance, resource urgency, and whether the colony is undercovered in a job category. The player can change priorities from the HUD Priority Panel.

### Features
- **8 colony priorities** stored in `colony_state.priorities`: food, digging, building, nursery, soldiers, defense, raid, repair
- **4 priority levels**: low (0.5×), normal (1.0×), high (1.5×), emergency (2.5×)
- **Full job score formula**:
  ```
  job_score = priority_weight(job.category)
            + (10.0 / (distance + 1.0))
            - (danger_level * 5.0)
            + (resource_urgency * 3.0)
            + (solo_bonus * 2.0)
  ```
- Priority Panel in HUD — player clicks +/- buttons to cycle each category's level
- Changing a priority to `emergency` forces all ants to re-score on next tick
- `job_queue.gd` extended: jobs now carry a `category` field for scoring
- Workers re-score every time they enter IDLE state (not on a timer)
- `data/colony/priority_weights.json` — maps level names to float multipliers

### Files Likely Changed
- `scripts/core/colony_state.gd` — add priorities dictionary, `set_priority()`, `get_priority_weight()`
- `scripts/core/job_queue.gd` — add `category` to Job, add `score_job(ant, job)` function
- `scripts/ants/worker_ant.gd` — replace nearest-job logic with scored-job logic
- `scripts/ui/priority_panel.gd` — HUD panel for priority controls
- `scenes/ui/priority_panel.tscn` — priority panel scene
- `scenes/ui/hud.tscn` — embed priority panel
- `data/colony/priority_weights.json` — `{"low": 0.5, "normal": 1.0, "high": 1.5, "emergency": 2.5}`

### Test Checklist
- [ ] Set food priority to `high` → workers shift away from digging toward food gathering
- [ ] Set digging to `emergency` → all idle workers immediately re-score and prioritize DIG jobs
- [ ] Set food to `low` → workers stop prioritizing gathering unless nothing else is available
- [ ] Priority Panel displays correct level for each category
- [ ] `colony_state.get_priority_weight("food")` returns correct float
- [ ] No stuck ants or infinite re-scoring loops

### Acceptance Criteria
- All 8 priority categories adjustable from HUD
- Priority changes visibly affect worker behavior
- Emergency priority causes immediate re-scoring
- Score formula pulls weights from JSON, not hardcoded values

### What NOT to Do in This Phase
- No room placement yet
- No soldier ants yet
- Do not add more job types — score existing types only
- Do not add upgrade system yet

---

## Phase 3 — Rooms & Room Plan Markers

**Goal:** Player places room blueprints; workers autonomously build them over time.

### Design Summary
The player never places a finished room. They place a Room Plan Marker in cleared tunnel space. This creates a BUILD job in the queue. Workers score the BUILD job like any other, claim it, deliver resources to the site, and the room materialises once the build cost is paid. Rooms then produce colony outputs on timers driven by JSON config.

Additional planned room autonomy:
- Queen egg laying: queen auto-produces eggs based on `nursery` and `food` priority, available nursery capacity, and current food supply
- Adaptive nursery spawning: nursery hatch rate adjusts to current food surplus so the colony grows faster when food is abundant and slows down when food is scarce

### Features
- Room Plan Marker: player opens menu, selects room type, clicks empty tunnel tile
- BUILD job added to queue with `room_type`, `build_cost`, `location`
- Worker BUILD state: pathfind to site, deliver one food per trip, update progress bar
- Room appears when progress reaches `build_cost` (from config JSON)
- 6 room types with config JSON in `data/rooms/`:
  - **Queen Chamber** — marks queen's location; cannot be destroyed; queen HP bar
  - **Nursery** — hatches egg on timer → adds 1 worker to colony
  - **Food Storage** — raises max food cap; stores delivered food
  - **Soldier Barracks** — trains one soldier per timer tick (uses food)
  - **Mushroom Farm** — passive food income over time
  - **Guard Post** — increases nearby soldier detection radius
- `room_manager.gd` — tracks placed and under-construction rooms
- Under-construction visual: blueprint tint on room sprite + progress bar
- Debug mode skips build time (set in `project.godot` `[debug]` section)

### Files Likely Changed
- `scripts/core/room_manager.gd`
- `scripts/core/job_queue.gd` — add BUILD job type
- `scripts/ants/worker_ant.gd` — add BUILD working state
- `scripts/rooms/nursery.gd`, `food_storage.gd`, `soldier_barracks.gd`, `mushroom_farm.gd`, `guard_post.gd`
- `scenes/rooms/*.tscn` — one scene per room type
- `data/rooms/*_config.json` — build_cost, timer, output per room

### Test Checklist
- [ ] Place Room Plan Marker → blueprint appears, BUILD job in queue
- [ ] Worker claims BUILD job, carries food to site, progress increments
- [ ] Nursery appears after build completes; hatches egg after timer; worker count increases
- [ ] Food Storage raises max food shown in HUD
- [ ] Debug mode: room appears instantly
- [ ] Cannot place Room Plan Marker on dirt or stone tile

### Acceptance Criteria
- All 6 room types placeable and functional
- Rooms built by workers over time; never instant outside debug
- Each room has a config JSON file
- room_manager.gd tracks all room states correctly

### What NOT to Do in This Phase
- No soldier ants yet
- No enemies
- Do not hardcode room stats — all values from config JSON
- Do not add upgrades yet

---

## Phase 4 — Soldiers & Combat

**Goal:** Soldiers defend the nest and can raid the enemy. Combat is autonomous; player directs via markers and priorities.

### Design Summary
Soldiers are trained by the Barracks (Phase 3). They patrol near the queen by default. When enemies spawn, soldiers automatically engage based on `defense` priority. The player can redirect soldiers with Rally Markers and push them into enemy territory with Raid Rally Markers. Soldiers never wait for explicit orders — they always have something to do.

### Features
- Soldier ant type with 4-state FSM: `IDLE → MOVING → FIGHTING → IDLE`
- Threat response: soldiers auto-patrol high-value rooms such as Nursery, Food Storage, Soldier Barracks, and Queen Chamber based on `defense` priority
- Soldier formations: high defense creates temporary guard lines at tunnel entrances and choke points
- Raid AI: soldiers auto-retreat when low on HP, when the queen is threatened, or when raid priority drops below defense priority
- Soldier IDLE behavior scales with defense priority:
  - `low`: soldiers only fight if directly attacked
  - `normal`: soldiers patrol within N tiles of queen; engage any enemy nearby
  - `high`: soldiers actively seek and chase enemies in a larger radius
  - `emergency`: all soldiers rush toward any known enemy immediately
- **Rally Marker** (right-click): soldiers score and claim RALLY jobs; engage enemies en route; timeout after arrival
- **Raid Rally Marker** (right-click enemy territory): soldiers push toward enemy queen; fight anything in the way
- Spider enemy type: spawns from world edge on timer, walks toward queen in straight line
- Beetle enemy type: slower, higher HP
- Enemies do not pathfind — straight-line movement only until Phase 5
- HP bars above all ants and enemies
- `enemy_spawner.gd` — spawns enemies on timer; escalating difficulty curve from config
- Queen death → game over screen
- `data/enemies/spider_config.json`, `beetle_config.json` — HP, damage, speed

### Files Likely Changed
- `scripts/ants/soldier_ant.gd`
- `scenes/ants/soldier_ant.tscn`
- `scripts/enemies/spider.gd`, `beetle.gd`
- `scenes/enemies/spider.tscn`, `beetle.tscn`
- `scripts/core/enemy_spawner.gd`
- `scripts/core/job_queue.gd` — add RALLY, RAID, PATROL job types
- `scripts/core/colony_state.gd` — add enemy awareness list
- `data/enemies/spider_config.json`, `beetle_config.json`

### Test Checklist
- [ ] Enemies spawn from world edges on timer
- [ ] Enemies walk toward queen; queen takes damage on contact
- [ ] Soldier on `normal` defense patrols near queen; engages enemy within radius
- [ ] Right-click in tunnel → Rally Marker placed; soldiers pathfind to it
- [ ] Soldiers attack enemies during movement without extra player input
- [ ] Set defense to `emergency` → all soldiers rush nearest enemy immediately
- [ ] HP bars visible and decrease correctly
- [ ] Queen dies → game over screen
- [ ] No framerate drops with 15 soldiers + 10 enemies

### Acceptance Criteria
- Soldiers autonomous — defend without explicit orders when defense priority is non-low
- Player can redirect soldiers with Rally Markers
- Two enemy types functional
- Game over triggers on queen death
- No stuck soldiers or pathfinding loops

### What NOT to Do in This Phase
- No A* for enemies — straight-line only
- No multiplayer code
- No new room types
- Do not rewrite room system from Phase 3

---

## Phase 5 — Full Marker Set & Upgrades

**Goal:** Complete the marker vocabulary. Add efficiency upgrades.

### All Marker Types

| Marker | Phase Added |
|---|---|
| Dig | Phase 1 |
| Gather | Phase 1 (auto-gather) → explicit marker here |
| Room Plan | Phase 3 |
| Rally | Phase 4 |
| Raid Rally | Phase 4 |
| Repair | **Phase 5** |
| Emergency | **Phase 5** |
| Patrol Zone | **Phase 5** |
| Fortify | **Phase 5** |

### New Phase 5 Markers

- **Repair Marker** — left-click damaged room/wall; worker repairs and removes marker
- **Emergency Marker** — shift+right-click; all idle ants re-score, prioritizing location; one at a time
- **Patrol Zone** — drag on tunnel area; soldiers loop back and forth between endpoints
- **Fortify** — left-click tunnel entrance; soldier stands guard, attacks anything entering

### Upgrade System
Upgrades purchased with food from the HUD upgrades panel.

| Upgrade | Effect | Config key |
|---|---|---|
| Dig Speed + | `dig_duration` shorter | `worker_config.json` |
| Carry Capacity + | food per trip increases | `worker_config.json` |
| Ant Limit + | raises max ant cap | `colony_config.json` |
| Faster Hatch | nursery timer shorter | `nursery_config.json` |
| Soldier Damage + | base damage multiplier | `soldier_config.json` |

All upgrade levels and costs live in `data/upgrades/upgrades_config.json`.

### Files Likely Changed
- `scripts/core/job_queue.gd` — REPAIR, EMERGENCY, PATROL, FORTIFY job types
- `scripts/ants/worker_ant.gd` — handle REPAIR
- `scripts/ants/soldier_ant.gd` — handle PATROL, FORTIFY
- `scripts/ui/upgrades_panel.gd` + `scenes/ui/upgrades_panel.tscn`
- `data/upgrades/upgrades_config.json`

### Test Checklist
- [ ] Repair Marker on damaged room → worker repairs; marker removed when done
- [ ] Emergency Marker → all idle ants immediately re-score toward it
- [ ] Patrol Zone → soldiers loop back and forth indefinitely
- [ ] Fortify → soldier stands at entrance; attacks first enemy that enters
- [ ] Purchase Dig Speed upgrade → workers dig noticeably faster
- [ ] Upgrade costs correctly deducted from food count

### Acceptance Criteria
- All 9 marker types functional
- Upgrade system reads from JSON, applies multipliers correctly
- Priority system interacts correctly with all marker types

### What NOT to Do in This Phase
- No multiplayer networking
- No new room types
- No new enemy types

---

## Phase 5.5 — Advanced Colony AI & Seeded World Scale

**Goal:** Make the colony feel self-organizing at large map scale before multiplayer multiplies the simulation load.

### Features
- Dynamic job clustering: ants group on nearby dig/build jobs to complete tunnels and rooms faster, with diminishing returns so every ant does not pile onto one tile
- Emergency auto-escalation: low food, queen damage, or critical room damage temporarily raises the relevant priority to `emergency`, then restores the previous priority when the crisis ends
- Path optimization: when `food` priority is high, the colony can automatically queue tunnel expansion toward known food sources without direct player tile-by-tile planning
- Room auto-maintenance: when `repair` priority is above normal, workers automatically generate REPAIR jobs for damaged structures without requiring Repair Markers
- Pheromone trails: high-traffic paths gain temporary movement speed bonuses, encouraging natural highways through the tunnel network
- Seeded large map foundation: replace the fixed prototype world with deterministic procedural generation driven by a seed; terrain, food sources, stone bands, entrances, chambers, and player start locations must be reproducible from the same seed

### Files Likely Changed
- `scripts/core/world_generator.gd`
- `scripts/core/job_clusterer.gd`
- `scripts/core/colony_state.gd`
- `scripts/core/job_queue.gd`
- `scripts/core/pheromone_map.gd`
- `data/world/world_generation_config.json`
- `data/colony/automation_config.json`

### Test Checklist
- [ ] Same seed produces identical terrain and food layout after restart
- [ ] Different seeds produce meaningfully different maps
- [ ] Large map pathfinding remains responsive with many queued jobs
- [ ] Nearby dig/build jobs attract small groups of workers without starving other jobs
- [ ] Low food auto-escalates food priority and later restores the previous level
- [ ] Damaged rooms generate repair jobs automatically when repair priority is high
- [ ] Pheromone paths speed up repeated ant traffic without permanently breaking balance

### Acceptance Criteria
- Seeded world generation is deterministic and ready for local/online multiplayer
- Advanced automation still flows through priorities, markers, and the job queue
- No autonomous system directly mutates the world without a queued job or validated room/world rule
- Performance remains stable on a map larger than the Phase 1 prototype

### What NOT to Do in This Phase
- Do not add online networking yet
- Do not let auto-expansion ignore queen/room protection rules
- Do not let emergency auto-escalation permanently overwrite player-set priorities

---

## Phase 6 — Local Multiplayer Prototype

**Goal:** Two colonies on one screen. Validate PvP mechanics before networking.

### Features
- Split-screen: Player 1 controls left colony, Player 2 controls right colony
- Shared TileMap — both colonies dig in the same world
- Shared seeded map: both colonies spawn into the same deterministic large map generated from the selected seed
- Seed selection UI for local matches
- Victory condition: destroy enemy queen
- No networking — both players on same keyboard or controllers

### Files Likely Changed
- `scenes/multiplayer/local_multiplayer.tscn`
- `scripts/multiplayer/local_multiplayer_manager.gd`
- `scripts/core/game_manager.gd` — extend for two-colony state

### Test Checklist
- [ ] Both colonies start on opposite sides of TileMap
- [ ] Each player controls their own colony independently
- [ ] Soldiers from Colony A can attack Colony B's ants
- [ ] Queen death ends game and declares winner
- [ ] No shared resource bugs (food counters separate per colony)

### Acceptance Criteria
- Two-player local game works end-to-end
- Win condition functional
- No cross-contamination of colony state

### What NOT to Do in This Phase
- No network code
- No Steam
- Do not add new game mechanics not present in Phases 1–5

---

## Phase 7 — Online Multiplayer

**Goal:** Two players over network. Server is authoritative.

### Features
- Godot high-level multiplayer (ENet)
- Dedicated server mode (headless)
- Server selects or validates the map seed and all clients generate the same large procedural map from that seed
- Server remains authoritative over revealed map state, resource depletion, digging, room placement, combat, and all generated world mutations
- Clients send command packets only: `place_marker`, `set_priority`, `approve_room_plan`, `send_raid`
- Server validates and applies all state changes
- Basic lobby: host game, join via IP
- Latency compensation: client-side prediction for ant movement only

### Client Command Packets (not game results)
Clients never send final game state — only intent:
- `place_marker(type, tile_pos, priority_level)`
- `set_priority(category, level)`
- `approve_room_plan(room_type, tile_pos)`
- `cancel_marker(marker_id)`
- `purchase_upgrade(upgrade_id)`

### Files Likely Changed
- `scripts/multiplayer/network_manager.gd`
- `scripts/multiplayer/server.gd`
- `scripts/multiplayer/client.gd`
- `scripts/multiplayer/command_packets.gd`
- `scenes/multiplayer/lobby.tscn`

### Test Checklist
- [ ] Host on LAN, second machine joins by IP
- [ ] Both players see identical game state
- [ ] Server rejects invalid `place_marker` commands (e.g., on stone tile)
- [ ] Disconnect handled gracefully
- [ ] Server runs headless without crash

### Acceptance Criteria
- Online 1v1 completes without desyncs
- Server rejects invalid commands
- Disconnect handled

### What NOT to Do in This Phase
- No Steam lobbies yet (Phase 8)
- Do not trust any client data for game state decisions
- Do not add new gameplay features

---

## Phase 8 — Steam Polish

**Goal:** Ship-ready. Steam integration, polish, performance.

### Features
- Steamworks GDNative/GDExtension integration
- Steam lobbies (host + join)
- 5 achievements (e.g., "First Queen Kill", "100 Ants Raised", "Emergency Resolved")
- Sound effects for dig, hatch, combat, victory
- Background music tracks
- Animated ant sprites (replace placeholder art)
- Performance profiling: stable 60fps with 200 ants
- Settings menu: resolution, volume, key rebinding

### Acceptance Criteria
- Builds and runs on Steam
- Achievements appear in Steam profile
- Zero placeholder textures in final build
- Stable 60fps in stress test (200 ants + 20 enemies)

### What NOT to Do in This Phase
- Do not add new gameplay systems
- Do not redesign multiplayer architecture
