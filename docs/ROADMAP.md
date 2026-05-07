# Ant Colony Wars — Development Roadmap

Build one phase at a time. Do not start the next phase until acceptance criteria for the current phase pass.

---

## Phase 0 — Project Setup

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
- All 8 planning docs are in `docs/` or `data/`

### What NOT to Do in This Phase
- Do not create any game scenes (.tscn files)
- Do not write any game logic
- Do not add real art files yet
- Do not configure networking or multiplayer

---

## Phase 0.5 — Asset Pipeline Tool

**Goal:** One command converts any dropped sprite sheet into correctly named, background-removed PNGs in the right Godot asset folders.

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
- **Dry-run**: `--dry-run` previews what would be written without touching any files
- **Force re-process**: `--force` re-runs even if output already exists
- **Manifest gap report**: `--check` lists which manifest-expected files are still missing
- **Skip existing**: outputs are skipped unless `--force` is set, so re-running is fast

### Files
```
process_assets.py              <- CLI entry point (python process_assets.py)
requirements.txt               <- Pillow, numpy
tools/
  pipeline/
    config.py                  <- config loading + merge logic
    bg_remover.py              <- background detection and removal
    cropper.py                 <- single / grid / auto crop modes
    exporter.py                <- output writing + manifest coverage check
    processor.py               <- pipeline orchestrator per category
assets_inbox/
  pipeline_config.json         <- per-file processing rules
  ants/                        <- drop sprite sheets here
  enemies/
  rooms/
  tiles/
  ui/
```

### Config Quick Reference

```json
{
  "_defaults":   { "background": "auto", "bg_tolerance": 30, "trim": true },
  "ants": {
    "_category_defaults": { "bg_tolerance": 25 },
    "ant_sheet.png": {
      "mode": "grid", "columns": 4, "rows": 1,
      "background": "#FF00FF",
      "outputs": ["worker_ant.png", "soldier_ant.png", "queen_ant.png", "egg.png"]
    }
  },
  "tiles": {
    "_category_defaults": { "output_size": [16, 16] }
  }
}
```

| Key             | Values                            | Default  |
|-----------------|-----------------------------------|----------|
| `mode`          | `single` / `grid` / `auto`        | `single` |
| `background`    | `"auto"` / `"#RRGGBB"` / `"none"` | `"auto"` |
| `bg_tolerance`  | 0–255 (per-channel sum)           | `30`     |
| `trim`          | `true` / `false`                  | `true`   |
| `output_size`   | `[w, h]` or `null`                | `null`   |
| `outputs`       | list of output filenames (grid)   | auto-named |
| `output`        | single output filename (single)   | original name |

### Test Checklist
- [ ] `pip install -r requirements.txt` — no errors
- [ ] `python process_assets.py --dry-run` — runs without crash on empty inbox
- [ ] Drop a PNG with a solid white BG into `assets_inbox/ants/worker_ant.png`
- [ ] Run `python process_assets.py --category ants` — BG removed, output in `assets/sprites/ants/`
- [ ] Drop a 4-cell sprite sheet, configure grid mode → 4 separate PNGs exported
- [ ] `--force` re-exports an existing output
- [ ] `--check` reports which manifest entries are still missing

### Acceptance Criteria
- Single command processes all categories
- Background removed correctly from solid-color sheets
- Grid cropping produces correct number of sprites
- Output files land in correct Godot asset folders
- No crash on empty inbox or missing config

### What NOT to Do in This Phase
- Do not build any game code
- Do not hand-edit output sprites — fix the source and re-run the pipeline
- Do not commit `assets_inbox/` to git — it's a working folder, not source of truth
- Do not add animation support yet (that's Phase 7)

---

## Phase 1 — Single-Player Colony Prototype

**Goal:** A playable bare-bones colony driven by markers. Player places markers; ants execute them.

### How the Marker System Works
The player never directly removes or changes tiles. Instead:
1. Player left-clicks a dirt tile → a **Dig Marker** is placed on it
2. An idle worker ant picks up the job, pathfinds to the marker using simple BFS grid navigation
3. Ant arrives, plays a brief dig pause, the tile changes from `dirt_tile` to `tunnel_tile`
4. Marker is consumed; ant returns to IDLE and looks for the next job
5. Multiple markers can exist at once — ants pick the nearest available one

This is the **core interaction model for the entire game**. Every player action from Phase 1 onward is a marker placement. Ants always act autonomously.

### Features
- TileMap with `dirt_tile` and `tunnel_tile` tile types
- Left-click a dirt tile → place a Dig Marker (visual indicator on tile)
- Worker ant scene with a simple 3-state FSM: `IDLE → MOVING → DIGGING → IDLE`
- Basic BFS pathfinding so worker can navigate around existing walls to reach marker
- Food resource counter (int, visible in HUD)
- Food tiles on the surface: worker ants auto-gather food and carry it back (no marker needed for this in Phase 1 — workers seek food when idle)
- Queen Chamber — one special tile that cannot have a Dig Marker placed on it
- Single scene: `scenes/main/main.tscn`

### Files Likely Changed
- `scenes/main/main.tscn` — root scene with TileMap
- `scenes/ants/worker_ant.tscn` — worker ant scene with FSM
- `scenes/ui/hud.tscn` — food counter label
- `scripts/core/game_manager.gd` — autoload, holds global state (food count)
- `scripts/core/colony_state.gd` — colony data (food, ant count)
- `scripts/core/job_queue.gd` — list of pending marker jobs; ants claim jobs from here
- `scripts/ants/worker_ant.gd` — FSM + BFS pathfinding
- `scripts/ui/hud.gd` — updates food label
- `project.godot` — add GameManager autoload

### Test Checklist
- [ ] Open main.tscn, press F5
- [ ] Left-click a dirt tile — a Dig Marker visual appears on it
- [ ] Worker ant walks from its current position to the marked tile (navigates around walls)
- [ ] Tile becomes a tunnel after ant arrives and waits briefly
- [ ] Dig Marker disappears after dig completes
- [ ] Place 3 markers — 3 ants (or same ant in sequence) dig all 3
- [ ] Idle worker walks toward food tile, picks it up, food counter increments
- [ ] Cannot place Dig Marker on Queen Chamber tile
- [ ] No null-reference errors in Output

### Acceptance Criteria
- Player places dig markers; ants autonomously execute them
- Worker FSM cycles correctly without getting stuck
- BFS pathfinding finds a route or skips the job if no route exists
- Food counter increments when food is gathered
- Queen chamber is protected from markers
- Zero errors on F5

### What NOT to Do in This Phase
- Do not let the player remove tiles directly — all digging must go through a marker and an ant
- No priority levels on markers yet (all markers equal priority)
- No soldier ants
- No room placement system
- No enemy spawning
- No split-screen or multiplayer code
- Do not add more than one ant type
- Do not build full A* yet — simple BFS is enough

---

## Phase 2 — Rooms & Upgrades

**Goal:** Player can place rooms. Rooms do things (hatch eggs, store food).

### Features
- Room placement: click an empty tunnel area to place a room type
- Room types: Nursery, Food Storage, Queen Chamber (move to proper room), Soldier Barracks (stub)
- Nursery hatches one egg on a timer → adds worker ant
- Food Storage increases max food capacity
- Each room type has a JSON config file in `data/rooms/`
- Room sprites loaded via AssetLoader

### Files Likely Changed
- `scripts/rooms/room_manager.gd` — tracks placed rooms
- `scripts/rooms/nursery.gd` — egg hatch timer
- `scripts/rooms/food_storage.gd` — capacity modifier
- `scenes/rooms/nursery.tscn`
- `scenes/rooms/food_storage.tscn`
- `data/rooms/nursery_config.json`
- `data/rooms/food_storage_config.json`
- `data/rooms/queen_chamber_config.json`

### Test Checklist
- [ ] Click an empty tunnel tile to open room placement menu
- [ ] Place a Nursery — egg hatches after timer, ant count increases
- [ ] Place Food Storage — max food shown in HUD increases
- [ ] Room sprites load (placeholder or real)
- [ ] Room configs load from JSON without error

### Acceptance Criteria
- 3 room types placed and functional
- Each room has a config JSON file
- Hatch timer produces a new worker ant

### What NOT to Do in This Phase
- No combat
- No enemies
- No multiplayer
- Do not hardcode room stats — they must come from config JSON

---

## Phase 3 — Combat & Enemies

**Goal:** Soldiers defend the nest. Enemies attack. Player directs soldiers with Rally Markers.

### How Combat Markers Work
The marker system from Phase 1 extends to combat:
- Player right-clicks a location (tunnel, enemy, or surface) → places a **Rally Marker**
- Idle soldiers pathfind to the Rally Marker
- If an enemy is in melee range while moving, soldiers attack it
- Rally Markers are consumed after soldiers arrive or after a short timeout

### Features
- Soldier ant type (higher damage, lower speed, higher HP than worker)
- **Rally Marker**: player right-clicks to direct soldiers to a location or toward enemies
- Spider and Beetle enemy types that spawn from world edges on a timer
- Enemies walk in a straight line toward the queen (no pathfinding needed for enemies yet)
- Melee collision: ants and enemies deal damage on overlap via Area2D
- HP bars above all ants and enemies
- Soldier Barracks room (Phase 2 stub) now produces soldiers over time
- Queen death → game over screen

### Files Likely Changed
- `scripts/ants/soldier_ant.gd`
- `scenes/ants/soldier_ant.tscn`
- `scripts/enemies/spider.gd`
- `scripts/enemies/beetle.gd`
- `scenes/enemies/spider.tscn`
- `scenes/enemies/beetle.tscn`
- `scripts/core/enemy_spawner.gd`
- `scripts/core/job_queue.gd` — add `RALLY` job type
- `data/enemies/spider_config.json`
- `data/enemies/beetle_config.json`

### Test Checklist
- [ ] Enemies spawn from world edges on a timer
- [ ] Enemies move toward queen
- [ ] Right-click inside tunnel → Rally Marker placed, soldiers pathfind to it
- [ ] Soldiers attack enemies that get within melee range during movement
- [ ] HP bars visible and decrease correctly
- [ ] Dead ants/enemies are removed from scene; no orphaned nodes
- [ ] Queen dies → game over screen appears

### Acceptance Criteria
- Two enemy types functional
- Player can direct soldiers with Rally Markers
- Soldiers can kill enemies and protect the queen
- Game over triggers on queen death
- No framerate drops with 20 ants + 10 enemies active

### What NOT to Do in This Phase
- No A* pathfinding for enemies — straight-line movement only
- No multiplayer
- Do not rewrite room system from Phase 2
- Do not add more than two enemy types

---

## Phase 4 — Marker Upgrades & Priorities

**Goal:** Upgrade the marker system. Add priority levels, new marker types, and efficiency upgrades.

### Context
Phase 1 introduced a flat marker system (all markers equal, two types: Dig and auto-gather food).
Phase 4 makes the marker system powerful enough to feel like a real RTS colony manager.

### New Marker Types
| Marker | Input | Ant Behavior |
|---|---|---|
| **Dig** (existing) | Left-click dirt tile | Worker digs tile |
| **Gather** | Left-click food source | Worker carries food to nearest storage |
| **Haul** | Left-click item on ground | Worker carries item to storage |
| **Patrol Zone** | Drag on tunnel | Soldiers loop between zone endpoints |
| **Fortify** | Left-click tunnel entrance | Soldier stands guard, attacks anything entering |
| **Raid Rally** | Right-click enemy colony area | Soldiers pathfind toward enemy queen |

### Priority System
- Every marker now has a priority: **High / Normal / Low**
- Shift+click places a High priority marker; Ctrl+click places Low priority
- Workers always claim the highest-priority available job first
- Priority badge displayed on marker visual
- Priority panel in HUD shows job queue breakdown by type and priority

### Efficiency Upgrades (purchased with food)
- **Dig Speed +** — workers dig faster (config: `dig_duration` in `worker_config.json`)
- **Carry Capacity +** — workers carry more food per trip
- **Ant Limit +** — raises max colony ant cap
- **Faster Hatch** — nursery hatch timer shorter
- Upgrades stored in `data/upgrades/upgrades_config.json`; each level multiplies the base stat

### Files Likely Changed
- `scripts/core/job_queue.gd` — priority queue logic, new job types
- `scripts/ants/worker_ant.gd` — handle new job types
- `scripts/ants/soldier_ant.gd` — handle PATROL and FORTIFY jobs
- `scripts/ui/priority_panel.gd` — priority panel, upgrade buttons
- `scenes/ui/priority_panel.tscn`
- `data/upgrades/upgrades_config.json`
- `data/ants/worker_config.json` — base stats for upgrades to modify

### Test Checklist
- [ ] Shift+click marker → placed as High priority, claimed before Normal markers
- [ ] Place Gather marker on food tile → worker carries food to storage
- [ ] Place Patrol Zone on a tunnel → soldiers loop back and forth
- [ ] Place Fortify marker on entrance → soldier stands guard, attacks entering enemies
- [ ] Place Raid Rally in enemy territory → soldiers pathfind toward enemy queen
- [ ] Purchase Dig Speed upgrade → worker digs noticeably faster
- [ ] 15+ ants running priority FSM with no performance issues or stuck states

### Acceptance Criteria
- All 6 marker types work correctly
- Priority ordering is respected (High before Normal before Low)
- At least 3 efficiency upgrades functional
- No stuck ants or infinite loops in FSM

### What NOT to Do in This Phase
- No multiplayer networking
- Do not add new room types — focus is on the marker and upgrade systems
- Do not build A* pathfinding — BFS from Phase 1 is still enough here

---

## Phase 5 — Local Multiplayer Prototype

**Goal:** Two colonies on one screen. Validate PvP mechanics before networking.

### Features
- Split-screen: Player 1 controls left colony, Player 2 controls right colony
- Shared TileMap — both colonies dig in the same world
- Victory condition: destroy enemy queen
- Basic raid: player can send a group of soldiers toward enemy territory
- No networking — both players on same keyboard

### Files Likely Changed
- `scenes/multiplayer/local_multiplayer.tscn`
- `scripts/multiplayer/local_multiplayer_manager.gd`
- `scripts/core/game_manager.gd` — extend for two-colony state

### Test Checklist
- [ ] Both colonies start on opposite sides of TileMap
- [ ] Each player controls their own colony independently
- [ ] Soldiers from Colony A can attack Colony B's ants
- [ ] Queen death ends the game and declares winner
- [ ] No shared resource bugs (food counter separate per colony)

### Acceptance Criteria
- Two-player local game works end-to-end
- One clear win condition functional
- No cross-contamination of colony state

### What NOT to Do in This Phase
- No network code
- No Steam
- Do not add new game mechanics not present in Phase 1–4

---

## Phase 6 — Online Multiplayer

**Goal:** Two players over network. Server is authoritative.

### Features
- Godot high-level multiplayer (ENet)
- Dedicated server mode (headless)
- Clients send command packets only (dig_tile, place_room, set_priority, send_raid)
- Server validates and applies all state changes
- Basic lobby: host game, join via IP
- Latency compensation: client-side prediction for ant movement only

### Files Likely Changed
- `scripts/multiplayer/network_manager.gd`
- `scripts/multiplayer/server.gd`
- `scripts/multiplayer/client.gd`
- `scripts/multiplayer/command_packets.gd`
- `scenes/multiplayer/lobby.tscn`
- `scripts/ui/lobby_ui.gd`

### Test Checklist
- [ ] Host a game on LAN, second machine joins by IP
- [ ] Both players see identical game state
- [ ] Cheat test: client cannot remove enemy queen directly — must go through server
- [ ] Disconnect handling: game pauses, notifies player
- [ ] Server runs headless without crash

### Acceptance Criteria
- Online 1v1 game completes without desyncs
- Server rejects invalid commands
- Disconnect handled gracefully

### What NOT to Do in This Phase
- No Steam lobbies yet (Phase 7)
- Do not trust any data from clients for game state decisions
- Do not add new gameplay features

---

## Phase 7 — Steam Polish

**Goal:** Ship-ready. Steam integration, polish, performance.

### Features
- Steamworks GDNative/GDExtension integration
- Steam lobbies (host + join)
- 5 achievements (e.g., "First Queen Kill", "100 Ants Raised")
- Sound effects for dig, hatch, combat, victory
- Background music tracks
- Animated ant sprites (replace placeholder art)
- Performance profiling: stable 60fps with 200 ants
- Settings menu: resolution, volume, key rebinding

### Files Likely Changed
- `scripts/core/steam_manager.gd`
- `assets/audio/sfx/` — all SFX files
- `assets/audio/music/` — all music files
- `assets/sprites/ants/` — animated sprites
- `scenes/ui/settings_menu.tscn`
- `scripts/ui/settings_menu.gd`

### Test Checklist
- [ ] Steam overlay opens in-game
- [ ] Achievement unlocks correctly on trigger
- [ ] Lobby creation and join works through Steam
- [ ] Audio plays on dig, hatch, combat
- [ ] 200 ants + 20 enemies = 60fps on mid-range GPU
- [ ] All placeholder art replaced

### Acceptance Criteria
- Builds and runs on Steam
- Achievements appear in Steam profile
- Zero placeholder textures in final build
- Stable 60fps in stress test

### What NOT to Do in This Phase
- Do not add new gameplay systems
- Do not redesign multiplayer architecture
