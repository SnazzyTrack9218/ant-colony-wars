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
- [x] All folders created (scenes, scripts, assets, data, docs)
- [x] `ASSET_MANIFEST.json` populated with all known asset paths
- [x] `asset_loader.gd` autoload registered in `project.godot`
- [x] Placeholder system confirmed: missing assets print warnings, never crash
- [x] All planning docs present in `docs/`

### Files Likely Changed
- [x] `project.godot` — add `[autoload]` entry
- [x] `data/ASSET_MANIFEST.json` — created
- [x] `scripts/assets/asset_loader.gd` — created
- [x] `docs/*.md` — created

### Test Checklist
- [x] Open Godot 4.6, no import errors in FileSystem panel
- [x] Press F5 — project starts without errors
- [x] Output panel shows "AssetLoader: manifest loaded (5 categories)."
- [x] Output panel shows per-asset warnings (not crashes) for every missing file
- [x] `AssetLoader.get_ant_sprite("worker")` returns a non-null texture in the debugger

### Acceptance Criteria
- [x] Project runs with zero errors
- [x] Asset loader is registered as an autoload singleton
- [x] All planning docs are in `docs/` or `data/`

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
- [x] **Background removal**: auto-detect BG color from image corners, or specify an exact hex color (`"#FF00FF"`)
- [x] **Sprite sheet cropping**: grid mode (`columns` × `rows`) for uniform sheets; auto mode for content-aware separation
- [x] **Rename on export**: map sheet cells to exact filenames the manifest expects (`outputs` list in config)
- [x] **Resize**: `output_size: [w, h]` forces sprites to a standard size (tiles → 16×16, rooms → 64×64, etc.)
- [x] **Placeholder generator**: `python tools/generate_placeholders.py` — generates all 20 sprites programmatically
- [x] **Dry-run**: `--dry-run` previews what would be written without touching any files
- [x] **Manifest gap report**: `--check` lists which manifest-expected files are still missing

### Test Checklist
- [x] `pip install -r requirements.txt` — no errors
- [x] `python process_assets.py --dry-run` — runs without crash on empty inbox
- [x] `python tools/generate_placeholders.py` — 20 placeholder PNGs generated
- [x] `python process_assets.py --check` — all 5 categories show "coverage OK"
- [x] Open Godot, confirm 20 assets import with no errors in FileSystem panel

### Acceptance Criteria
- [x] Single command processes all categories
- [x] All 20 placeholder PNGs exist in correct asset folders
- [x] No crash on empty inbox or missing config

### What NOT to Do in This Phase
- Do not build any game code
- Do not hand-edit output sprites — fix the source and re-run the pipeline
- Do not add animation support yet (that's Phase 12)

---

## Phase 1 — Single-Player Colony Prototype ✓

**Goal:** A playable bare-bones colony driven by markers and a simple job queue. Player places markers; ants execute them autonomously.

### Design Summary
The player is the colony brain. Clicking a dirt tile places ONE Dig Marker (destination). The claiming ant autonomously navigates through existing tunnel and digs its own path to the destination — one tile at a time, updating as new tunnel opens. Workers also auto-seek food and stop gathering when food is maxed.

### Features
- [x] TileMap with `dirt_tile`, `tunnel_tile`, `stone_tile`, `queen` tile types (TileSet built in code via AssetLoader)
- [x] Left-click dirt tile → single destination Dig Marker; ant self-navigates and digs autonomously
- [x] `job_queue.gd` — TYPE_DIG / TYPE_GATHER int constants, Job class, claim/release/complete/score
- [x] Worker ant scene with 4-state FSM: `IDLE → MOVING → WORKING → IDLE_WANDER`
- [x] Workers score jobs: `priority_weight + (10 / (distance + 1))` — simplified, no danger score yet
- [x] BFS pathfinding for worker navigation; unreachable jobs released and skipped
- [x] 5 starting workers — 4 handle food, 1+ available for digging at all times
- [x] Workers skip GATHER jobs when food is at max; re-evaluate all jobs before re-adding food source (prevents ants from looping on food forever)
- [x] `colony_state.gd` — food count, max_food, priority dictionary
- [x] `game_manager.gd` — autoload, food/ant-count signals
- [x] HUD: food counter and worker count labels
- [x] Queen Chamber — 3×3 protected tiles; cannot be dug
- [x] Camera: zoom=1.0, entire 60×40 tile world fits in 1280×720 viewport

### Files Changed
- [x] `scenes/main/main.tscn` — root scene with TileMap
- [x] `scenes/ants/worker_ant.tscn` — worker ant scene
- [x] `scenes/ui/hud.tscn` — food and worker count labels
- [x] `scripts/core/game_manager.gd` — autoload
- [x] `scripts/core/colony_state.gd` — food, priority dictionary
- [x] `scripts/core/job_queue.gd` — plain int constants, claim/release/score API
- [x] `scripts/ants/worker_ant.gd` — FSM + BFS + job scoring + gather re-evaluation
- [x] `scripts/ui/hud.gd` — updates labels from signals
- [x] `scripts/main.gd` — single-marker dig, world gen, food sources
- [x] `project.godot` — display settings, autoloads
- [x] `data/colony/colony_config.json` — 5 starting workers

### Test Checklist
- [x] Press F5 — no errors, 5 workers visible and moving
- [x] Workers autonomously walk to surface food tiles; food counter increments
- [x] Left-click a deep dirt tile → ant navigates and digs autonomously to destination
- [x] Ants dig toward marker tile; marker clears when destination reached
- [x] Fill food to 200 → ants switch from gathering to digging
- [x] Cannot place Dig Marker on Queen Chamber tiles
- [x] No null-reference errors in Output

### Acceptance Criteria
- [x] Player places markers; ants autonomously execute them — no direct ant control
- [x] Worker FSM cycles correctly without getting stuck
- [x] Job queue correctly prevents two ants from claiming the same job
- [x] BFS pathfinding finds a route or skips the job if unreachable
- [x] Food counter increments from worker behavior, not player action
- [x] Zero errors on F5

### What NOT to Do in This Phase
- Do not add soldier ants, rooms, enemies, or multiplayer
- Do not build full A* — BFS is sufficient

---

## Phase 2 — Priority System & Job Score ✓

**Goal:** Give the player meaningful colony-level control. Workers make smarter decisions based on priorities. The colony brain has real levers to pull.

### Design Summary
Phase 1 workers pick the nearest available job. Phase 2 workers pick the *best* job based on a score that includes colony priorities, distance, resource urgency, and whether the colony is undercovered in a job category. The player can change priorities from the HUD Priority Panel.

### Features
- [x] **8 colony priorities** stored in `colony_state.priorities`: food, digging, building, nursery, soldiers, defense, raid, repair
- [x] **4 priority levels**: low (0.5×), normal (1.0×), high (1.5×), emergency (2.5×)
- [x] **Full job score formula**: `priority_weight + (10 / (distance+1)) - (danger×5) + (resource_urgency×3) + (solo_bonus×2)`
- [x] Priority Panel in HUD — player clicks +/- buttons to cycle each category's level
- [x] Changing a priority to `emergency` forces all ants to re-score on next tick
- [x] `job_queue.gd` extended: jobs now carry a `category` field for scoring
- [x] Workers re-score every time they enter IDLE state (not on a timer)
- [x] `data/colony/priority_weights.json` — maps level names to float multipliers

### Files Likely Changed
- [x] `scripts/core/colony_state.gd` — priorities dictionary, `set_priority()`, `get_priority_weight()`
- [x] `scripts/core/job_queue.gd` — `category` on Job, `score_job(ant, job)` function
- [x] `scripts/ants/worker_ant.gd` — replace nearest-job logic with scored-job logic
- [x] `scripts/ui/priority_panel.gd` — HUD panel for priority controls
- [x] `scenes/ui/priority_panel.tscn` — priority panel scene
- [x] `scenes/ui/hud.tscn` — embed priority panel
- [x] `data/colony/priority_weights.json` — `{"low": 0.5, "normal": 1.0, "high": 1.5, "emergency": 2.5}`

### Test Checklist
- [x] Set food priority to `high` → workers shift away from digging toward food gathering
- [x] Set digging to `emergency` → all idle workers immediately re-score and prioritize DIG jobs
- [x] Set food to `low` → workers stop prioritizing gathering unless nothing else is available
- [x] Priority Panel displays correct level for each category
- [x] `colony_state.get_priority_weight("food")` returns correct float
- [x] No stuck ants or infinite re-scoring loops

### Acceptance Criteria
- [x] All 8 priority categories adjustable from HUD
- [x] Priority changes visibly affect worker behavior
- [x] Emergency priority causes immediate re-scoring
- [x] Score formula pulls weights from JSON, not hardcoded values

### What NOT to Do in This Phase
- Do not add rooms, soldiers, or upgrade system yet

---

## Phase 3 — Ant Autonomy & World Quality (mostly done)

**Goal:** Ants feel alive. Workers explore, gather, and dig without constant player guidance. The world is bigger, procedurally generated, and ready for larger ant counts.

### Design Summary
Phase 2 workers are reactive: they only work jobs placed by the player. Phase 3 workers are proactive: they explore dark tunnels, automatically discover and gather food sources, and extend the tunnel network organically when idle. The static hand-crafted world is replaced by a procedural generator. The map grows to 120×80 tiles.

### Features
- [x] **Single-destination dig**: player places ONE marker; ant self-navigates to the frontier and digs one tile at a time without pre-queued path tiles
- [x] **Auto-explore**: idle workers with no claimed jobs queue nearby tunnel-frontier DIG jobs and extend the tunnel network organically
- [x] **Auto-gather**: workers automatically queue GATHER jobs from food sources during idle scoring without player markers
- [x] **Procedural food**: static food sources replaced with deterministic seeded buried food at world-gen time
- [x] **World gen v2**: hand-coded layout replaced by procedural generator with stone veins and cave pockets, driven by `world_generation_config.json`
- [x] **Bigger world**: 120×80 tiles, with WASD/arrow camera panning + zoom from `data/camera/camera_config.json`
- [ ] **Chunk-dirty tracking**: not implemented — full re-score still happens (performance acceptable at 120×80)
- [x] **Worker sprite animation**: walk-bob via parallel tween while moving (no atlas swap; simpler approach)

### Files Changed
- [x] `scripts/core/world_generator.gd` — new file; procedural gen from config
- [x] `scripts/main.gd` — swap hand-coded layout for world_generator call; grow map to 120×80
- [x] `scripts/ants/worker_ant.gd` — auto-explore wander logic; food discovery during scoring; food-route digging when stores low
- [ ] `scripts/core/job_queue.gd` — chunk-dirty flag (deferred)
- [x] `data/world/world_generation_config.json` — tile counts, stone density, food count/placement rules
- [x] `data/colony/colony_config.json` — world_width=120 / world_height=80
- [x] `data/camera/camera_config.json` — pan speed, zoom limits

### Test Checklist
- [x] Press F5 — 120×80 map generates; no layout errors
- [x] Idle workers wander into unvisited tunnel branches
- [x] Workers discover food automatically without player placing Gather Markers
- [x] Different `world_seed` values in config produce different maps
- [x] Stone veins and cave pockets visible in generated world
- [x] Dig marker placed deep → ant navigates autonomously; no pre-queued path tiles
- [ ] No framerate drops on 120×80 map with 5+ workers (needs in-engine perf check)

### Acceptance Criteria
- [x] Procedural world generator replaces hand-coded layout entirely
- [x] Workers explore and gather without player markers
- [x] Map is 120×80 tiles minimum
- [x] No stuck ants or infinite wander loops

### What NOT to Do in This Phase
- Do not add rooms, soldiers, or enemies
- Do not add multiplayer code
- Do not hardcode world gen constants — all values from JSON
- Do not add camera edge-scrolling complexity if zoom=1 still fits the world

---

## Phase 4 — Main Menu & Settings (mostly done)

**Goal:** The game has a proper entry point. Audio, settings, and keybinds are in place before more systems are layered on top.

### Features
- [x] **Main menu scene** (`scenes/ui/main_menu.tscn`) — New Game, Settings, Quit
- [x] **Settings panel** — master volume, SFX volume, music volume, resolution, fullscreen toggle
- [ ] **Keybinds panel** — config file exists (`data/settings/keybinds.json`) but no in-UI rebinding yet (deferred)
- [x] **SFX hooks**: dig complete, food gathered, ant spawned, queen damaged — all routed through `audio_manager.gd`
- [ ] **Background music**: stub player only — no real audio file loaded yet (deferred until Phase 12 polish)
- [x] **Save/load settings**: persist to `user://settings.json` on change; load on startup
- [x] **Compact in-game HUD**: priority panel collapses to dot row; expands on hover/toggle
- [x] **Visual feedback on marker placement**: pulse animation + SFX on Dig Marker placement
- [x] **`scripts/core/audio_manager.gd`** autoload — single entry point for all audio

### Files Likely Changed
- [x] `scenes/ui/main_menu.tscn`
- [x] `scripts/ui/main_menu.gd`
- [x] `scenes/ui/settings_menu.tscn`
- [x] `scripts/ui/settings_menu.gd`
- [x] `scripts/core/audio_manager.gd` — new autoload
- [x] `project.godot` — register AudioManager autoload
- [x] `scripts/ui/hud.gd` — compact mode
- [x] `scenes/ui/hud.tscn`
- [x] `data/settings/keybinds.json`
- [x] `scripts/core/settings_manager.gd` — persistence helper

### Test Checklist
- [x] Launch game → main menu appears
- [x] New Game button loads the main game scene
- [x] Settings changes save to `user://settings.json`; restored after restart
- [x] Dig complete → SFX plays once; no duplicate sounds
- [ ] Music loops during gameplay; no audio gap at loop point (no real music yet)
- [x] Fullscreen toggle works on all target resolutions
- [ ] Keybinds panel shows current binding; rebinding works without crash (no in-UI rebinding yet)
- [x] Priority panel collapses to icons; expands on hover

### Acceptance Criteria
- [x] Main menu functional with New Game / Settings / Quit
- [x] All SFX hooks fire at correct game moments
- [x] Settings persist between sessions
- [x] No audio loaded outside `audio_manager.gd`

### What NOT to Do in This Phase
- Do not add rooms or soldiers
- Do not add background music that requires real audio files — use silent AudioStreamPlayer stubs until real audio is ready
- Do not block game launch on missing audio files

---

## Phase 5 — UI Visual Design Language (mostly done)

**Goal:** Establish the dark, minimal, gradient aesthetic that all future UI inherits. Every pixel earns its place. Nothing visible that isn't needed in the next five seconds.

### Design Principles
- **Dark-first**: near-black backgrounds everywhere — no light grays, no white panels
- **Gradient accents**: amber→orange for resources/workers; blue for markers/info; red for threats — never flat solid fills on accent elements
- **Minimal**: at most 3–4 pieces of information visible at once; everything else collapsed or hidden until needed
- **No clutter**: if a player hasn't asked for it, they don't see it

### Color Palette (single source of truth in `ui_theme.gd`)

| Token | Hex | Use |
|---|---|---|
| `BG_DARK` | `#0B0B0F` | Scene background, fullscreen overlay |
| `PANEL_SURFACE` | `#12121C` | Panel, menu card background |
| `PANEL_EDGE` | `#2A2A3F` | 1px top edge highlight (glass shelf) |
| `TEXT_PRIMARY` | `#E8E8F0` | Labels, values |
| `TEXT_MUTED` | `#5A5A72` | Secondary info, disabled state |
| `ACCENT_AMBER` | `#FF9520` | Food icon, worker count, high priority |
| `ACCENT_BLUE` | `#4A9FFF` | Dig marker outline, info elements |
| `ACCENT_RED` | `#FF4040` | Queen HP, enemy presence, emergency |
| `ACCENT_PURPLE` | `#A070FF` | Building/room markers |

Panel gradient: linear top→bottom from `#14141E` to `#0B0B0F`.

### HUD Layout (collapsed state)
```
[food_icon] 42 / 200          [⚙ 5 workers]
                                              [priority dot-row]
```
- Top-left: food icon + `current / max` in `ACCENT_AMBER`, small text
- Top-right: worker icon + count
- Bottom-right corner: priority panel, collapsed to 8 color dots
- Nothing else visible

### Component Specs

**Priority panel (collapsed):** 8 dots in a single row, 8px diameter. Dot color = current level:
- `low` → `TEXT_MUTED` (grey)
- `normal` → `TEXT_PRIMARY` (white)
- `high` → `ACCENT_AMBER`
- `emergency` → `ACCENT_RED`

**Priority panel (expanded on hover):** slides up from bottom-right; each row shows icon + category name + level label + `−` / `+` buttons; max width 220px; `PANEL_SURFACE` background with `PANEL_EDGE` border; auto-collapses on mouse-leave.

**Dig marker:** thin 1px `ACCENT_AMBER` outlined square, no fill, 70% alpha. Single pulse-fade animation (scale 1.0 → 1.15 → 1.0 over 250ms) on placement.

**Buttons:** flat, no border radius; 1px `PANEL_EDGE` top edge; hover = `PANEL_SURFACE` fill at 20% brightness boost; active = 3px `ACCENT_AMBER` left strip.

**Main menu card:** centered `PANEL_SURFACE` panel, gradient fill, 1px `PANEL_EDGE` border, game title in large `TEXT_PRIMARY`, three flat buttons stacked.

### Features
- [x] `scripts/ui/ui_theme.gd` — color and StyleBox constants; helper functions used across UI scripts
- [ ] Godot Theme resource applied globally via `project.godot` (still applied per-script via helpers)
- [x] Redesigned HUD: food + worker count + soldier count; nothing else visible
- [x] Priority panel: collapsed dot-row; toggle button to expand
- [x] Dig marker visual: outlined square with placement pulse
- [x] Main menu: dark card layout using palette
- [x] Font size scale: FONT_MUTED=11 / FONT_PRIMARY=13 / FONT_HEADER=16 / FONT_TITLE=32 enforced via helpers

### Files Changed
- [x] `scripts/ui/ui_theme.gd` — color constants + StyleBox factory
- [x] `scenes/ui/hud.tscn` + `scripts/ui/hud.gd` — minimal layout
- [x] `scenes/ui/priority_panel.tscn` + `scripts/ui/priority_panel.gd` — dot-row collapse + toggle
- [x] `scenes/ui/main_menu.tscn` + `scripts/ui/main_menu.gd` — dark card style
- [x] `scripts/main.gd` — dig + rally marker visuals using outlined Panels with pulse tween

### Test Checklist
- [x] HUD shows only food count + worker/soldier counts; no other panels visible by default
- [x] Priority panel collapses to dot row; dots match current priority levels by color
- [x] Priority panel expands via toggle; closes on toggle (hover-expand not implemented; toggle works)
- [x] Dig marker is a thin outline square; pulses once on placement; no solid fill
- [x] Main menu uses `BG_DARK` background, `PANEL_SURFACE` card, flat buttons
- [x] No white or light-gray backgrounds anywhere in the UI
- [x] All colors come from `ui_theme.gd`; food markers now source amber from `ColonyUITheme.ACCENT_AMBER`
- [x] Consistent font sizes: 11 / 13 / 16 / 32 via theme constants

### Acceptance Criteria
- [x] Dark minimal aesthetic consistent across all current UI (HUD, priority panel, main menu)
- [x] `ui_theme.gd` is the single source of truth for UI colors and StyleBoxes
- [x] HUD has at most 2–3 visible info elements when collapsed
- [x] Priority panel collapsed by default

### What NOT to Do in This Phase
- Do not add UI for features that don't exist yet (rooms, soldiers, enemies)
- Do not use Godot's default gray/blue theme anywhere
- Do not add animations that block gameplay or take more than 250ms
- Do not add tooltips or help text yet
- Never define a color directly inside a `.tscn` file or `set_modulate` call — source from `ui_theme.gd`

---

## Phase 6 — Rooms & Colony Growth (mostly done)

**Goal:** The colony expands structurally. Workers build rooms that produce colony outputs automatically.

### Design Summary
The player never places a finished room. They place a Room Plan Marker in cleared tunnel space. This creates a BUILD job. Workers claim it, deliver food to the site, and the room appears once the build cost is paid. Rooms then produce colony outputs on timers from JSON config.

### Features
- [x] Room Plan Marker: right-click empty tunnel; `B` cycles type, `1`–`5` selects directly (no UI panel yet)
- [x] BUILD job added to queue with `room_type`, `build_cost`, `location`
- [x] Worker BUILD state: pathfind to site, deliver food per tick, progress visual updates
- [x] Room appears when `build_cost` food delivered (from config JSON)
- [x] 6 room types with config JSON in `data/rooms/`:
  - [x] **Queen Chamber** — placed at world-gen; protected tiles; queen HP tracked in colony_state
  - [x] **Nursery** — hatches worker every `hatch_interval` for `hatch_food_cost` food (respects `max_workers` cap)
  - [x] **Food Storage** — raises `colony_state.max_food` by config bonus
  - [x] **Soldier Barracks** — trains a soldier every `training_interval` when soldiers priority is non-low (Phase 7 wire-up)
  - [x] **Mushroom Farm** — passive food income on timer
  - [x] **Guard Post** — soldiers within `effect_radius` (default 10 tiles) gain `detection_radius_bonus` (default +5)
- [x] `room_manager.gd` — tracks placed and under-construction rooms
- [x] Under-construction visual: purple progress-tinted Panel
- [x] Debug mode skips build time — `debug_instant_build` flag in `colony_config.json`
- [x] Room selection UI panel — bottom-center HUD picker, syncs with keyboard 1–5/B

### Files Changed
- [x] `scripts/core/room_manager.gd` — new file
- [x] `scripts/core/job_queue.gd` — add TYPE_BUILD constant
- [x] `scripts/ants/worker_ant.gd` — BUILD working state
- [ ] Per-room scripts (`nursery.gd`, etc.) — handled centrally in `room_manager.gd` instead
- [x] `data/rooms/*_config.json` — build_cost, timer, output per room

### Test Checklist
- [x] Place Room Plan Marker → blueprint appears; BUILD job in queue
- [x] Worker claims BUILD job; carries food to site; progress increments
- [x] Nursery completes → hatches worker after timer; worker count increases until cap
- [x] Food Storage raises max food shown in HUD
- [x] Debug mode: room appears instantly when `debug_instant_build: true` in colony_config
- [x] Cannot place Room Plan Marker on dirt or stone tile

### Acceptance Criteria
- [x] All 6 room types placeable
- [x] Rooms built by workers over time; never instant
- [x] Each room has a config JSON file
- [x] `room_manager.gd` tracks all room states correctly
- [x] Guard Post effect implemented — boosts nearby soldier detection radius

### What NOT to Do in This Phase
- Do not add soldier ants yet — Barracks can be placed but trains nothing until Phase 7
- Do not add enemies
- Do not hardcode room stats — all values from config JSON

---

## Phase 7 — Combat & Enemies ✓

**Goal:** The colony faces threats. Soldiers defend autonomously; the player directs them with markers and priorities.

### Design Summary
Soldiers are trained by the Barracks (Phase 6). They patrol near the queen by default. Enemies spawn from world edges. Soldiers auto-engage based on `defense` priority. The player can redirect soldiers with Rally Markers (middle-click on a tunnel tile).

### Features
- [x] Soldier ant type with FSM: `IDLE_PATROL → ENGAGE → RETURN → MOVE_TO_RALLY → AT_RALLY`
- [x] Soldiers auto-engage enemies within detection radius; radius scales with `defense` priority (low: adjacent only; normal: 1×; high: 1.5×; emergency: 3×)
- [x] **Rally Marker** (middle-click on tunnel): soldiers path to it and hold position
- [ ] **Raid Rally Marker** (right-click enemy territory): pushed to Phase 10 (multiplayer) — single-player has no enemy queen yet
- [x] Spider enemy: spawns from world edges on timer; walks toward queen via greedy step
- [x] Beetle enemy: slower, higher HP
- [x] HP bars above all soldiers and enemies (ColorRect-based, scales with current HP)
- [x] `enemy_spawner.gd` + `data/enemies/*_config.json` + `data/colony/enemy_spawn_config.json`
- [x] Queen death → game over screen with Restart / Main Menu options
- [x] Soldier Barracks trains one soldier per `training_interval` when soldiers priority is non-low

### Files Changed
- [x] `scripts/ants/soldier_ant.gd` + `scenes/ants/soldier_ant.tscn`
- [x] `scripts/enemies/enemy_base.gd`, `spider.gd`, `beetle.gd`
- [x] `scenes/enemies/spider.tscn`, `beetle.tscn`
- [x] `scripts/core/enemy_spawner.gd`
- [x] `scripts/core/job_queue.gd` — add TYPE_RALLY (defense category)
- [x] `scripts/core/room_manager.gd` — Barracks training tick + soldier_spawn_requested signal
- [x] `scripts/main.gd` — soldier spawning, enemy spawner setup, rally markers, game-over wiring
- [x] `scripts/ui/game_over_screen.gd` + `scenes/ui/game_over_screen.tscn`
- [x] `data/enemies/spider_config.json`, `beetle_config.json`
- [x] `data/colony/enemy_spawn_config.json`
- [x] `data/ants/soldier_config.json`

### Test Checklist
- [ ] Enemies spawn from world edges on timer
- [ ] Enemies walk toward queen; queen takes damage on contact
- [ ] Soldier on `normal` defense patrols near barracks; engages enemy within radius
- [ ] Middle-click in tunnel → Rally Marker placed; soldiers pathfind to it
- [ ] Set defense to `emergency` → all soldiers rush nearest enemy immediately
- [ ] HP bars visible and decrease correctly
- [ ] Queen dies → game over screen with Restart / Main Menu
- [ ] No framerate drops with 15 soldiers + 10 enemies

### Acceptance Criteria
- [x] Soldiers defend without explicit orders when `defense` priority is non-low
- [x] Player can redirect soldiers with Rally Markers
- [x] Two enemy types functional
- [x] Game over triggers on queen death

### What NOT to Do in This Phase
- Do not add A* for enemies — straight-line approach only
- Do not add multiplayer code
- Do not rewrite the room system

---

## Phase 8 — Full Marker Set & Upgrades (mostly done)

**Goal:** Complete the marker vocabulary. Add efficiency upgrades.

### New Markers in This Phase

| Marker | Input | Effect |
|---|---|---|
| Repair | Shift+left-click on damaged room | Worker repairs the room (1 food per tick) |
| Emergency | Shift+right-click on dirt | High-priority dig; auto-clears after 30s |
| Patrol Zone | (deferred — Rally Marker covers most use cases) | — |
| Fortify | (deferred — Rally Marker covers most use cases) | — |

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

### Features
- [x] Repair Marker — shift+left-click damaged room; worker delivers food to repair (1 food / 12 HP per tick)
- [x] Emergency Marker — shift+right-click on dirt; +500 score bonus drops all ants on it; auto-clears after 30s
- [ ] Patrol Zone — deferred (Rally Marker covers held-position use case)
- [ ] Fortify — deferred (Rally Marker covers held-position use case)
- [x] Upgrade panel in HUD with `U` toggle; 5 upgrade types purchased with food
- [x] All upgrade levels and costs in `data/upgrades/upgrades_config.json`
- [x] Room HP system: rooms start at 60 HP; enemies adjacent damage them on attack cooldown; reach 0 HP → room destroyed

### Files Changed
- [x] `scripts/core/job_queue.gd` — TYPE_RALLY/TYPE_REPAIR/TYPE_EMERGENCY constants; emergency_bonus in scoring; cancel_job_at()
- [x] `scripts/ants/worker_ant.gd` — REPAIR state + `_do_repair()`; effective dig duration / carry capacity from upgrades
- [x] `scripts/ants/soldier_ant.gd` — `_get_effective_damage()` from upgrades
- [x] `scripts/core/room_manager.gd` — room HP, damage_room_at, apply_repair_work, room_destroyed signal
- [x] `scripts/core/upgrade_manager.gd` — purchase/levels/effect-getters; autoload via GameManager
- [x] `scripts/ui/upgrades_panel.gd` + `scenes/ui/upgrades_panel.tscn`
- [x] `scripts/enemies/enemy_base.gd` — adjacent-room damage priority
- [x] `data/upgrades/upgrades_config.json` — 5 upgrades with cost/effect ladders

### Test Checklist
- [x] Repair Marker on damaged room → worker repairs; marker removed when full HP
- [x] Emergency Marker → all idle workers immediately re-score toward it; auto-clears after 30s
- [ ] Patrol Zone → deferred
- [ ] Fortify → deferred
- [x] Dig Speed upgrade noticeably speeds up workers
- [x] Upgrade costs correctly deducted from food count

### Acceptance Criteria
- [x] Repair + Emergency markers functional
- [x] Upgrade system reads from JSON; applies multipliers correctly
- [x] Priority system interacts correctly with new marker types
- [ ] Patrol/Fortify deferred — not blocking

### What NOT to Do in This Phase
- Do not add multiplayer networking
- Do not add new room types
- Do not add new enemy types

---

## Phase 9 — Advanced Colony AI & Seeded World Scale

**Goal:** Make the colony feel self-organizing at large scale. Establish deterministic seeded generation required for multiplayer.

### Features
- [ ] **Seeded world generation**: same seed → same terrain, food positions, stone veins, chamber layout on every machine; seed displayed in lobby and saved with save file
- [ ] **Dynamic job clustering**: ants group on nearby dig/build jobs; diminishing returns prevent all ants piling onto one tile
- [ ] **Emergency auto-escalation**: low food, queen damage, or critical room damage temporarily raises the relevant priority to `emergency`; restores previous level when crisis ends; never permanently overrides player-set priorities
- [ ] **Path optimization**: when `food` priority is high, colony can auto-queue tunnel expansion toward known food sources
- [ ] **Room auto-maintenance**: when `repair` priority is above normal, workers generate REPAIR jobs for damaged structures without Repair Markers
- [ ] **Pheromone trails**: high-traffic paths gain temporary movement speed bonuses, encouraging natural highways

### Files Likely Changed
- [ ] `scripts/core/world_generator.gd` — add seed parameter; make generation fully deterministic
- [ ] `scripts/core/job_clusterer.gd` — new file
- [ ] `scripts/core/pheromone_map.gd` — new file
- [ ] `scripts/core/colony_state.gd` — auto-escalation logic
- [ ] `data/world/world_generation_config.json`
- [ ] `data/colony/automation_config.json`

### Test Checklist
- [ ] Same seed → identical terrain after restart
- [ ] Different seeds → meaningfully different maps
- [ ] Nearby dig/build jobs attract small groups; other jobs still get workers
- [ ] Low food auto-escalates food priority; later restores previous level
- [ ] Pheromone paths speed up repeated ant traffic

### Acceptance Criteria
- [ ] Seeded generation is deterministic; ready for multiplayer
- [ ] Advanced automation flows through priorities, markers, and the job queue — no direct world mutation
- [ ] Performance stable on 120×80 map with 30+ ants

### What NOT to Do in This Phase
- Do not add online networking yet
- Do not let auto-expansion ignore queen/room protection rules
- Do not let emergency auto-escalation permanently overwrite player-set priorities

---

## Phase 10 — Local Multiplayer Prototype

**Goal:** Two colonies on one screen. Validate PvP mechanics before networking.

### Features
- [ ] Split-screen: Player 1 controls left colony, Player 2 controls right colony
- [ ] Shared TileMap — both colonies dig in the same world
- [ ] Shared seeded map from Phase 9 generator
- [ ] Seed selection UI for local matches
- [ ] Victory condition: destroy enemy queen
- [ ] No networking — both players on same keyboard or controllers
- [ ] All game-state mutations go through `GameManager` command functions with `colony_id` parameter

### Files Likely Changed
- [ ] `scenes/multiplayer/local_multiplayer.tscn`
- [ ] `scripts/multiplayer/local_multiplayer_manager.gd`
- [ ] `scripts/core/game_manager.gd` — extend for two-colony state; `colony_id` on all colony calls

### Test Checklist
- [ ] Both colonies start on opposite sides of TileMap
- [ ] Each player controls their own colony independently
- [ ] Soldiers from Colony A attack Colony B's ants
- [ ] Queen death ends game and declares winner
- [ ] No shared resource bugs (food counters separate per colony)

### Acceptance Criteria
- [ ] Two-player local game works end-to-end
- [ ] Win condition functional
- [ ] No cross-contamination of colony state

### What NOT to Do in This Phase
- Do not add network code
- Do not add Steam
- Do not add new game mechanics not present in Phases 1–8

---

## Phase 11 — Online Multiplayer

**Goal:** Two players over network. Server is authoritative.

### Features
- [ ] Godot high-level multiplayer (ENet)
- [ ] Dedicated server mode (headless)
- [ ] Server selects or validates the map seed; all clients generate the same map from it
- [ ] Clients send command packets only: `place_marker`, `set_priority`, `approve_room_plan`, `send_raid`
- [ ] Server validates and applies all state changes
- [ ] Basic lobby: host game, join via IP
- [ ] Latency compensation: client-side prediction for ant movement only

### Client Command Packets (not game results)
- `place_marker(type, tile_pos, priority_level, colony_id)`
- `set_priority(category, level, colony_id)`
- `approve_room_plan(room_type, tile_pos, colony_id)`
- `cancel_marker(marker_id, colony_id)`
- `purchase_upgrade(upgrade_id, colony_id)`

### Files Likely Changed
- [ ] `scripts/multiplayer/network_manager.gd`
- [ ] `scripts/multiplayer/server.gd`
- [ ] `scripts/multiplayer/client.gd`
- [ ] `scripts/multiplayer/command_packets.gd`
- [ ] `scenes/multiplayer/lobby.tscn`

### Test Checklist
- [ ] Host on LAN, second machine joins by IP
- [ ] Both players see identical game state
- [ ] Server rejects invalid `place_marker` (e.g., on stone tile)
- [ ] Disconnect handled gracefully
- [ ] Server runs headless without crash

### Acceptance Criteria
- [ ] Online 1v1 completes without desyncs
- [ ] Server rejects invalid commands
- [ ] Disconnect handled

### What NOT to Do in This Phase
- Do not add Steam lobbies yet (Phase 12)
- Do not trust any client data for game-state decisions
- Do not add new gameplay features

---

## Phase 12 — Polish & Steam

**Goal:** Ship-ready. Steam integration, full audio, real art, stable performance.

### Features
- [ ] Steamworks GDNative/GDExtension integration
- [ ] Steam lobbies (host + join)
- [ ] 5 achievements (e.g., "First Queen Kill", "100 Ants Raised", "Emergency Resolved")
- [ ] Full SFX pass: dig, gather, hatch, combat hit, death, victory
- [ ] Background music tracks with crossfade
- [ ] Animated ant sprites (replace placeholder art)
- [ ] Performance profiling: stable 60fps with 200 ants + 20 enemies
- [ ] Final UI polish pass

### Acceptance Criteria
- [ ] Builds and runs on Steam
- [ ] Achievements appear in Steam profile
- [ ] Zero placeholder textures in final build
- [ ] Stable 60fps in stress test (200 ants + 20 enemies)

### What NOT to Do in This Phase
- Do not add new gameplay systems
- Do not redesign multiplayer architecture
