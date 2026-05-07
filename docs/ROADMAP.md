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

## Phase 1 — Single-Player Colony Prototype ✓

**Goal:** A playable bare-bones colony driven by markers and a simple job queue. Player places markers; ants execute them autonomously.

### Design Summary
The player is the colony brain. Clicking a dirt tile places ONE Dig Marker (destination). The claiming ant autonomously navigates through existing tunnel and digs its own path to the destination — one tile at a time, updating as new tunnel opens. Workers also auto-seek food and stop gathering when food is maxed.

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
- No soldier ants, rooms, enemies, or multiplayer
- Do not build full A* — BFS is sufficient

---

## Phase 2 — Priority System & Job Score ✓

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
- No rooms, soldiers, or upgrade system yet

---

## Phase 3 — Ant Autonomy & World Quality

**Goal:** Ants feel alive. Workers explore, gather, and dig without constant player guidance. The world is bigger, procedurally generated, and ready for larger ant counts.

### Design Summary
Phase 2 workers are reactive: they only work jobs placed by the player. Phase 3 workers are proactive: they explore dark tunnels, automatically discover and gather food sources, and extend the tunnel network organically when idle. The static hand-crafted world is replaced by a procedural generator. The map grows to 120×80 tiles.

### Features
- **Single-destination dig**: player places ONE marker; ant self-navigates to the frontier and digs one tile at a time without pre-queued path tiles (implemented in Phase 2 — verified here)
- **Auto-explore**: idle workers with no claimed jobs wander toward unexplored (unvisited) tunnel-adjacent dirt tiles; extend the tunnel network organically
- **Auto-gather**: workers automatically detect nearby food sources during exploration; add GATHER jobs to the queue without requiring player markers
- **Procedural food**: remove static food sources; replace with randomly placed food items generated at world-gen time; food positions from config (count, min/max distance from queen)
- **World gen v2**: replace hand-coded layout with procedural generator — random rock formations, stone veins, cave pockets; all driven by `world_generation_config.json`
- **Bigger world**: increase to 120×80 tiles; verify camera/zoom still covers it or add basic camera scrolling
- **Chunk-dirty tracking**: only re-score jobs near tiles that actually changed (performance prep for large worlds)
- **Worker sprite animation**: placeholder is static amber square — add basic 2-frame walk cycle using AssetLoader

### Files Likely Changed
- `scripts/core/world_generator.gd` — new file; procedural gen from config
- `scripts/main.gd` — swap hand-coded layout for world_generator call; grow map to 120×80
- `scripts/ants/worker_ant.gd` — add auto-explore wander logic; food discovery during wander
- `scripts/core/job_queue.gd` — chunk-dirty flag on tile changes; skip re-score for unaffected jobs
- `data/world/world_generation_config.json` — tile counts, stone density, food count/placement rules
- `data/colony/colony_config.json` — update world_width / world_height

### Test Checklist
- [ ] Press F5 — 120×80 map generates; no layout errors
- [ ] Idle workers wander into unvisited tunnel branches
- [ ] Workers discover food automatically without player placing Gather Markers
- [ ] Different `world_seed` values in config produce different maps
- [ ] Stone veins and cave pockets visible in generated world
- [ ] Dig marker placed deep → ant navigates autonomously; no pre-queued path tiles
- [ ] No framerate drops on 120×80 map with 5+ workers

### Acceptance Criteria
- Procedural world generator replaces hand-coded layout entirely
- Workers explore and gather without player markers
- Map is 120×80 tiles minimum
- No stuck ants or infinite wander loops

### What NOT to Do in This Phase
- No rooms, soldiers, or enemies
- Do not add multiplayer code
- Do not hardcode world gen constants — all values from JSON
- Do not add camera edge-scrolling complexity if zoom=1 still fits the world

---

## Phase 4 — Main Menu & Settings

**Goal:** The game has a proper entry point. Audio, settings, and keybinds are in place before more systems are layered on top.

### Features
- **Main menu scene** (`scenes/ui/main_menu.tscn`) — New Game, Settings, Quit
- **Settings panel** — master volume, SFX volume, music volume, resolution, fullscreen toggle
- **Keybinds panel** — rebindable actions stored in `data/settings/keybinds.json`; display current binding next to each action name
- **SFX hooks**: dig complete, food gathered, ant spawned, queen damaged — all routed through `audio_manager.gd`
- **Background music**: loop track during gameplay; crossfade between peace/alert states (alert triggered when enemies spawn)
- **Save/load settings**: persist to `user://settings.json` on change; load on startup
- **Compact in-game HUD**: collapse priority panel to icon-only row; expand on hover or toggle key
- **Visual feedback on marker placement**: brief flash and particle burst when Dig Marker is placed
- **`scripts/core/audio_manager.gd`** autoload — single entry point for all audio; never load audio inline in other scripts

### Files Likely Changed
- `scenes/ui/main_menu.tscn`
- `scripts/ui/main_menu.gd`
- `scenes/ui/settings_menu.tscn`
- `scripts/ui/settings_menu.gd`
- `scripts/core/audio_manager.gd` — new autoload
- `project.godot` — register AudioManager autoload
- `scripts/ui/hud.gd` — compact mode
- `scenes/ui/hud.tscn`
- `data/settings/keybinds.json`

### Test Checklist
- [ ] Launch game → main menu appears
- [ ] New Game button loads the main game scene
- [ ] Settings changes save to `user://settings.json`; restored after restart
- [ ] Dig complete → SFX plays once; no duplicate sounds
- [ ] Music loops during gameplay; no audio gap at loop point
- [ ] Fullscreen toggle works on all target resolutions
- [ ] Keybinds panel shows current binding; rebinding works without crash
- [ ] Priority panel collapses to icons; expands on hover

### Acceptance Criteria
- Main menu functional with New Game / Settings / Quit
- All SFX hooks fire at correct game moments
- Settings persist between sessions
- No audio loaded outside `audio_manager.gd`

### What NOT to Do in This Phase
- No rooms or soldiers
- Do not add background music that requires real audio files — use silent AudioStreamPlayer stubs until real audio is ready
- Do not block game launch on missing audio files

---

## Phase 5 — Rooms & Colony Growth

**Goal:** The colony expands structurally. Workers build rooms that produce colony outputs automatically.

### Design Summary
The player never places a finished room. They place a Room Plan Marker in cleared tunnel space. This creates a BUILD job. Workers claim it, deliver food to the site, and the room appears once the build cost is paid. Rooms then produce colony outputs on timers from JSON config.

### Features
- Room Plan Marker: player opens menu, selects room type, clicks empty tunnel tile
- BUILD job added to queue with `room_type`, `build_cost`, `location`
- Worker BUILD state: pathfind to site, deliver one food per trip, update progress bar
- Room appears when `build_cost` food delivered (from config JSON)
- 6 room types with config JSON in `data/rooms/`:
  - **Queen Chamber** — marks queen's location; cannot be destroyed; queen HP bar
  - **Nursery** — hatches egg on timer → `GameManager.spawn_worker()`
  - **Food Storage** — raises `colony_state.max_food`
  - **Soldier Barracks** — trains one soldier per timer tick (uses food)
  - **Mushroom Farm** — passive food income over time
  - **Guard Post** — increases nearby soldier detection radius
- `room_manager.gd` — tracks placed and under-construction rooms
- Under-construction visual: blueprint tint + progress bar
- Debug mode skips build time (`[debug]` in `project.godot`)

### Files Likely Changed
- `scripts/core/room_manager.gd` — new file
- `scripts/core/job_queue.gd` — add TYPE_BUILD constant
- `scripts/ants/worker_ant.gd` — add BUILD working state
- `scripts/rooms/nursery.gd`, `food_storage.gd`, `soldier_barracks.gd`, `mushroom_farm.gd`, `guard_post.gd`
- `scenes/rooms/*.tscn` — one scene per room type
- `data/rooms/*_config.json` — build_cost, timer, output per room

### Test Checklist
- [ ] Place Room Plan Marker → blueprint appears; BUILD job in queue
- [ ] Worker claims BUILD job; carries food to site; progress increments
- [ ] Nursery completes → hatches egg after timer; worker count increases
- [ ] Food Storage raises max food shown in HUD
- [ ] Debug mode: room appears instantly
- [ ] Cannot place Room Plan Marker on dirt or stone tile

### Acceptance Criteria
- All 6 room types placeable and functional
- Rooms built by workers over time; never instant outside debug
- Each room has a config JSON file
- `room_manager.gd` tracks all room states correctly

### What NOT to Do in This Phase
- No soldier ants yet — Barracks can be placed but trains nothing until Phase 6
- No enemies
- Do not hardcode room stats — all values from config JSON

---

## Phase 6 — Combat & Enemies

**Goal:** The colony faces threats. Soldiers defend autonomously; the player directs them with markers and priorities.

### Design Summary
Soldiers are trained by the Barracks (Phase 5). They patrol near the queen by default. Enemies spawn from world edges. Soldiers auto-engage based on `defense` priority. The player can redirect soldiers with Rally Markers and push them into enemy territory.

### Features
- Soldier ant type with FSM: `IDLE_PATROL → ENGAGE → RETURN`
- Soldiers auto-engage enemies within detection radius; radius scales with `defense` priority
- **Rally Marker** (right-click): soldiers path to it and hold position
- **Raid Rally Marker** (right-click enemy territory): soldiers push toward enemy queen
- Spider enemy: spawns from world edges on timer; walks toward queen
- Beetle enemy: slower, higher HP
- HP bars above all ants and enemies
- `enemy_spawner.gd` + `data/enemies/*_config.json`
- Queen death → game over screen

### Files Likely Changed
- `scripts/ants/soldier_ant.gd`
- `scenes/ants/soldier_ant.tscn`
- `scripts/enemies/spider.gd`, `beetle.gd`
- `scenes/enemies/spider.tscn`, `beetle.tscn`
- `scripts/core/enemy_spawner.gd`
- `scripts/core/job_queue.gd` — add RALLY, RAID, PATROL job types
- `data/enemies/spider_config.json`, `beetle_config.json`

### Test Checklist
- [ ] Enemies spawn from world edges on timer
- [ ] Enemies walk toward queen; queen takes damage on contact
- [ ] Soldier on `normal` defense patrols near queen; engages enemy within radius
- [ ] Right-click in tunnel → Rally Marker placed; soldiers pathfind to it
- [ ] Set defense to `emergency` → all soldiers rush nearest enemy immediately
- [ ] HP bars visible and decrease correctly
- [ ] Queen dies → game over screen
- [ ] No framerate drops with 15 soldiers + 10 enemies

### Acceptance Criteria
- Soldiers defend without explicit orders when `defense` priority is non-low
- Player can redirect soldiers with Rally Markers
- Two enemy types functional
- Game over triggers on queen death

### What NOT to Do in This Phase
- No A* for enemies — straight-line approach only
- No multiplayer code
- Do not rewrite the room system

---

## Phase 7 — Full Marker Set & Upgrades

**Goal:** Complete the marker vocabulary. Add efficiency upgrades.

### New Markers in This Phase

| Marker | Input | Effect |
|---|---|---|
| Repair | Left-click damaged room/wall | Worker repairs and removes marker |
| Emergency | Shift+right-click | All idle ants re-score toward location |
| Patrol Zone | Drag on tunnel area | Soldiers loop between endpoints |
| Fortify | Left-click tunnel entrance | Soldier stands guard; attacks on entry |

### Upgrade System
Upgrades purchased with food from the HUD upgrades panel.

| Upgrade | Effect | Config key |
|---|---|---|
| Dig Speed + | `dig_duration` shorter | `worker_config.json` |
| Carry Capacity + | food per trip increases | `worker_config.json` |
| Ant Limit + | raises max ant cap | `colony_config.json` |
| Faster Hatch | nursery timer shorter | `nursery_config.json` |
| Soldier Damage + | base damage multiplier | `soldier_config.json` |

All levels and costs in `data/upgrades/upgrades_config.json`.

### Files Likely Changed
- `scripts/core/job_queue.gd` — REPAIR, EMERGENCY, PATROL, FORTIFY job types
- `scripts/ants/worker_ant.gd` — REPAIR state
- `scripts/ants/soldier_ant.gd` — PATROL, FORTIFY states
- `scripts/ui/upgrades_panel.gd` + `scenes/ui/upgrades_panel.tscn`
- `data/upgrades/upgrades_config.json`

### Test Checklist
- [ ] Repair Marker on damaged room → worker repairs; marker removed when done
- [ ] Emergency Marker → all idle ants immediately re-score toward it
- [ ] Patrol Zone → soldiers loop indefinitely
- [ ] Fortify → soldier holds position; attacks first enemy that enters
- [ ] Dig Speed upgrade noticeably speeds up workers
- [ ] Upgrade costs correctly deducted from food count

### Acceptance Criteria
- All marker types functional
- Upgrade system reads from JSON; applies multipliers correctly
- Priority system interacts correctly with all marker types

### What NOT to Do in This Phase
- No multiplayer networking
- No new room types
- No new enemy types

---

## Phase 8 — Advanced Colony AI & Seeded World Scale

**Goal:** Make the colony feel self-organizing at large scale. Establish deterministic seeded generation required for multiplayer.

### Features
- **Seeded world generation**: same seed → same terrain, food positions, stone veins, chamber layout on every machine; seed displayed in lobby and saved with save file
- **Dynamic job clustering**: ants group on nearby dig/build jobs; diminishing returns prevent all ants piling onto one tile
- **Emergency auto-escalation**: low food, queen damage, or critical room damage temporarily raises the relevant priority to `emergency`; restores previous level when crisis ends; never permanently overrides player-set priorities
- **Path optimization**: when `food` priority is high, colony can auto-queue tunnel expansion toward known food sources
- **Room auto-maintenance**: when `repair` priority is above normal, workers generate REPAIR jobs for damaged structures without Repair Markers
- **Pheromone trails**: high-traffic paths gain temporary movement speed bonuses, encouraging natural highways

### Files Likely Changed
- `scripts/core/world_generator.gd` — add seed parameter; make generation fully deterministic
- `scripts/core/job_clusterer.gd` — new file
- `scripts/core/pheromone_map.gd` — new file
- `scripts/core/colony_state.gd` — auto-escalation logic
- `data/world/world_generation_config.json`
- `data/colony/automation_config.json`

### Test Checklist
- [ ] Same seed → identical terrain after restart
- [ ] Different seeds → meaningfully different maps
- [ ] Nearby dig/build jobs attract small groups; other jobs still get workers
- [ ] Low food auto-escalates food priority; later restores previous level
- [ ] Pheromone paths speed up repeated ant traffic

### Acceptance Criteria
- Seeded generation is deterministic; ready for multiplayer
- Advanced automation flows through priorities, markers, and the job queue — no direct world mutation
- Performance stable on 120×80 map with 30+ ants

### What NOT to Do in This Phase
- No online networking yet
- Do not let auto-expansion ignore queen/room protection rules
- Do not let emergency auto-escalation permanently overwrite player-set priorities

---

## Phase 9 — Local Multiplayer Prototype

**Goal:** Two colonies on one screen. Validate PvP mechanics before networking.

### Features
- Split-screen: Player 1 controls left colony, Player 2 controls right colony
- Shared TileMap — both colonies dig in the same world
- Shared seeded map from Phase 8 generator
- Seed selection UI for local matches
- Victory condition: destroy enemy queen
- No networking — both players on same keyboard or controllers
- All game-state mutations go through `GameManager` command functions with `colony_id` parameter

### Files Likely Changed
- `scenes/multiplayer/local_multiplayer.tscn`
- `scripts/multiplayer/local_multiplayer_manager.gd`
- `scripts/core/game_manager.gd` — extend for two-colony state; `colony_id` on all colony calls

### Test Checklist
- [ ] Both colonies start on opposite sides of TileMap
- [ ] Each player controls their own colony independently
- [ ] Soldiers from Colony A attack Colony B's ants
- [ ] Queen death ends game and declares winner
- [ ] No shared resource bugs (food counters separate per colony)

### Acceptance Criteria
- Two-player local game works end-to-end
- Win condition functional
- No cross-contamination of colony state

### What NOT to Do in This Phase
- No network code
- No Steam
- Do not add new game mechanics not present in Phases 1–7

---

## Phase 10 — Online Multiplayer

**Goal:** Two players over network. Server is authoritative.

### Features
- Godot high-level multiplayer (ENet)
- Dedicated server mode (headless)
- Server selects or validates the map seed; all clients generate the same map from it
- Clients send command packets only: `place_marker`, `set_priority`, `approve_room_plan`, `send_raid`
- Server validates and applies all state changes
- Basic lobby: host game, join via IP
- Latency compensation: client-side prediction for ant movement only

### Client Command Packets (not game results)
- `place_marker(type, tile_pos, priority_level, colony_id)`
- `set_priority(category, level, colony_id)`
- `approve_room_plan(room_type, tile_pos, colony_id)`
- `cancel_marker(marker_id, colony_id)`
- `purchase_upgrade(upgrade_id, colony_id)`

### Files Likely Changed
- `scripts/multiplayer/network_manager.gd`
- `scripts/multiplayer/server.gd`
- `scripts/multiplayer/client.gd`
- `scripts/multiplayer/command_packets.gd`
- `scenes/multiplayer/lobby.tscn`

### Test Checklist
- [ ] Host on LAN, second machine joins by IP
- [ ] Both players see identical game state
- [ ] Server rejects invalid `place_marker` (e.g., on stone tile)
- [ ] Disconnect handled gracefully
- [ ] Server runs headless without crash

### Acceptance Criteria
- Online 1v1 completes without desyncs
- Server rejects invalid commands
- Disconnect handled

### What NOT to Do in This Phase
- No Steam lobbies yet (Phase 11)
- Do not trust any client data for game-state decisions
- Do not add new gameplay features

---

## Phase 11 — Polish & Steam

**Goal:** Ship-ready. Steam integration, full audio, real art, stable performance.

### Features
- Steamworks GDNative/GDExtension integration
- Steam lobbies (host + join)
- 5 achievements (e.g., "First Queen Kill", "100 Ants Raised", "Emergency Resolved")
- Full SFX pass: dig, gather, hatch, combat hit, death, victory
- Background music tracks with crossfade
- Animated ant sprites (replace placeholder art)
- Performance profiling: stable 60fps with 200 ants + 20 enemies
- Final UI polish pass

### Acceptance Criteria
- Builds and runs on Steam
- Achievements appear in Steam profile
- Zero placeholder textures in final build
- Stable 60fps in stress test (200 ants + 20 enemies)

### What NOT to Do in This Phase
- Do not add new gameplay systems
- Do not redesign multiplayer architecture
