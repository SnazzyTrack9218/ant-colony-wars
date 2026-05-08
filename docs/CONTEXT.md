# Ant Colony Wars â€” Context File for AI Agents

Read this file before writing any code. Update it whenever a system's status changes.

---

## What Is This Game

Ant Colony Wars is a 2D side-view ant farm strategy game built in Godot 4.6.
The player is the **colony brain** â€” they never directly control individual ants.
Instead, they place markers, set priorities, approve room plans, and issue colony-level orders.
Ants always act autonomously based on job scoring and colony priorities.
The game supports 1v1 multiplayer (online and local), but multiplayer is built only after single-player works.

---

## Core Loop

```
Set Priorities â†’ Place Markers â†’ Ants Auto-Work â†’ Colony Grows â†’ Soldiers Defend/Raid â†’ Destroy Enemy Queen â†’ Win
```

1. **Set colony priorities** â€” adjust the Priority Panel to tell the colony what matters most
2. **Place Dig Markers** on dirt tiles â†’ workers autonomously pathfind, claim jobs, and dig
3. **Place Room Plan Markers** in cleared tunnel space â†’ workers auto-build rooms over time
4. **Food accumulates** â€” workers auto-seek food sources or follow Gather Markers
5. **Nursery hatches eggs** â†’ new worker ants join the colony
6. **Train soldiers** in the Barracks (training happens automatically when `soldiers` priority is set)
7. **Soldiers defend autonomously** based on `defense` priority and proximity to threats
8. **Place Raid Rally Marker** in enemy territory â†’ soldiers push toward enemy queen
9. **Enemy queen destroyed** â†’ win

---

## The Marker System

The player never directly changes the world. Every action goes through a marker:

| Marker | Input | Who Claims | Effect |
|---|---|---|---|
| **Dig Marker** | Left-click any dirt tile | Worker | BFS from tunnel network to target; Dig Markers + DIG jobs queued for every tile along the shortest path |
| **Gather Marker** | Left-click food source | Worker | Hauls food to storage |
| **Room Plan Marker** | Click empty tunnel, choose type | Worker | Builds room over time |
| **Rally Marker** | Right-click location | Soldier | Soldiers move there; engage enemies en route |
| **Raid Rally Marker** | Right-click enemy territory | Soldier | Soldiers push toward enemy queen |
| **Repair Marker** | Left-click damaged structure | Worker | Repairs structure |
| **Emergency Marker** | Shift+right-click | Any ant | Overrides normal priorities; all idle ants respond |

Full rules and examples: [`docs/AUTONOMY_DESIGN.md`](AUTONOMY_DESIGN.md)

---

## Priority System

Colony priorities control how strongly ants are attracted to each job category.

| Category | Controls |
|---|---|
| `food` | Food gathering and hauling |
| `digging` | Dig Marker execution |
| `building` | Room Plan Marker execution |
| `nursery` | Egg care from Nursery room |
| `soldiers` | Soldier training in Barracks |
| `defense` | Soldier patrol and threat response |
| `raid` | Soldiers pushing into enemy territory |
| `repair` | Repairing damaged rooms and walls |

| Level | Weight | Behavior |
|---|---|---|
| `low` | 0.5Ã— | Only when nothing higher is available |
| `normal` | 1.0Ã— | Default |
| `high` | 1.5Ã— | Preferred over normal tasks |
| `emergency` | 2.5Ã— | Ants drop current job and re-score immediately |

---

## Job Score System

When an ant enters IDLE, it scores every unclaimed job and claims the highest:

```
job_score = priority_weight(job.category)
          + (10.0 / (distance + 1.0))
          - (danger_level * 5.0)
          + (resource_urgency * 3.0)
          + (solo_bonus * 2.0)
```

- Jobs with no reachable BFS path score 0 and are never claimed.
- Workers and soldiers score only the job types they can execute.
- Keep the formula simple â€” do not add terms without a gameplay reason.

Full details: [`docs/AUTONOMY_DESIGN.md`](AUTONOMY_DESIGN.md)

---

## Current Rules (Do Not Break These)

1. Build one feature at a time. Do not start the next system before the current one is tested.
2. Use placeholder art until the game mechanic works. Do not wait for real art.
3. Do not over-engineer. Three similar lines is better than a premature abstraction.
4. Do not add multiplayer code before single-player is stable.
5. Server must be authoritative. Clients only send commands (intent). Never trust client state.
6. All assets go through `AssetLoader`. Never call `load("res://...")` in scene scripts directly.
7. Keep scripts under 1000 lines. Split by responsibility if a file grows too large.
8. Data-driven design: game stats (HP, damage, cost, timer) live in JSON config files under `data/`, not hardcoded.
9. Use `snake_case` for all file names, variable names, and function names.
10. Use signals for communication between nodes. Do not call parent/sibling nodes directly.
11. **The player never directly moves an ant, digs a tile, or builds a room.** All world changes are triggered by markers and executed by ants. This is the core design rule.
12. **Ants must claim jobs from `job_queue.gd`.** Do not assign targets to ants directly from UI or world scripts.
13. **Priority weights must come from `colony_state.priorities`.** Never hardcode a priority value in an ant script.
14. **Rooms do not appear instantly.** All room construction flows through BUILD jobs and worker delivery. Debug mode only exception.
15. **All game-state mutations go through `GameManager` command functions.** No direct node mutation from UI or world scripts. Every command must be serializable (name + params as Dictionary) for future RPC.
16. **No hardcoded `colony_id = 0`.** Every colony-specific function accepts a `colony_id` parameter, even in single-player. This makes two-colony multiplayer a configuration change, not a rewrite.
17. **Tile changes go through a `WorldState` layer, not directly via `_tile_map.set_cell`.** Validate position, bounds, and protection rules in one place. (Implement this layer before Phase 9.)

---

## Coding Style

- Language: GDScript only
- Naming: `snake_case` for files, variables, functions; `PascalCase` for class names and scene nodes
- Max file length: ~1000 lines. If a script exceeds this, split it.
- Autoloads (singletons): `AssetLoader`, `SettingsManager`, `AudioManager`, `GameManager` — global systems only
- Signals for all inter-node communication
- Config data: JSON files in `data/` â€” never hardcode numbers that a designer might tune
- No circular dependencies between scripts
- Comments only when the WHY is non-obvious

**Example file layout for a new system:**
```
scripts/rooms/nursery.gd       <- logic
data/rooms/nursery_config.json <- tunable stats
scenes/rooms/nursery.tscn      <- node tree
```

---

## Multiplayer Rules

- Architecture: Godot ENet high-level multiplayer API
- Server is authoritative for all game state; clients never invent world state
- Clients send command packets only â€” `place_marker`, `set_priority`, `approve_room_plan`, `send_raid`, `purchase_upgrade` â€” never final state
- Server validates every command before applying it
- Clients predict ant movement locally (visual only); server corrects on mismatch
- Never call `rpc()` from client to directly mutate enemy colony state
- World generation is seeded and deterministic â€” same seed must produce the same map on every machine
- All colony-specific calls carry a `colony_id` parameter (see Current Rules #16)
- Headless server build must run without crash

Do not implement networking until Phase 10. Do implement `colony_id` params and command-function routing in single-player so Phase 9 local multiplayer is an easy extension, not a rewrite.

---

## Asset Rules

- All 20 required sprites exist as **generated placeholders** â€” the game runs fully without any real art
- Re-generate placeholders any time with `python tools/generate_placeholders.py`
- All textures load through `AssetLoader` (autoload singleton) â€” never call `load("res://...")` directly
- `AssetLoader` reads `data/ASSET_MANIFEST.json` at startup; missing files fall back to solid-color placeholders
- To replace a placeholder with real art: drop a same-named PNG in the same folder â€” Godot auto-imports, no code changes
- Never add `.import` files to version control â€” Godot regenerates them
- Naming: `snake_case`, suffix by type â€” `worker_ant.png`, `dirt_tile.png`, `spider_enemy.png`
- Tile sprites must be exactly 16Ã—16 to match TileMap tile size

---

## Folder Structure

```
res://
  scenes/
    main/        <- root scene and world
    ants/        <- ant node scenes
    rooms/       <- room node scenes
    enemies/     <- enemy node scenes
    ui/          <- HUD, menus, panels
    multiplayer/ <- lobby, split-screen scenes
  scripts/
    core/        <- GameManager, ColonyState, JobQueue, EnemySpawner
    ants/        <- worker_ant.gd, soldier_ant.gd, ant_fsm.gd
    rooms/       <- room_manager.gd, nursery.gd, food_storage.gd
    enemies/     <- spider.gd, beetle.gd
    ui/          <- hud.gd, priority_panel.gd, settings_menu.gd
    multiplayer/ <- network_manager.gd, server.gd, client.gd
    assets/      <- asset_loader.gd (autoload)
  assets/
    sprites/
      ants/      <- worker_ant.png, soldier_ant.png, queen_ant.png, egg.png
      rooms/     <- nursery.png, food_storage.png, etc.
      tiles/     <- dirt_tile.png, tunnel_tile.png, stone_tile.png
      enemies/   <- spider_enemy.png, beetle_enemy.png, termite_enemy.png
      ui/        <- food_icon.png, worker_icon.png, etc.
    audio/
      sfx/       <- dig.wav, hatch.wav, combat.wav
      music/     <- colony_theme.ogg
    fonts/       <- main_font.ttf
  data/
    ASSET_MANIFEST.json   <- asset path registry
    rooms/                <- nursery_config.json, food_storage_config.json, etc.
    enemies/              <- spider_config.json, beetle_config.json
  docs/
    ROADMAP.md
    CONTEXT.md            <- this file
    AUTONOMY_DESIGN.md    <- ant autonomy, priority system, job scoring
    ASSET_GUIDE.md
    PLACEHOLDER_ASSETS.md
    PROJECT_STRUCTURE.md
    TODO.md
```

---

## Current Development Phase

**Phase 8 — Full Marker Set & Upgrades** (just landed; Phases 1–7 complete; Patrol/Fortify deferred)

---

## Systems Already Built

Phases 0â€“2 complete. Phase 3 in progress.

- `scripts/assets/asset_loader.gd` â€” AssetLoader autoload (placeholder fallback)
- `data/ASSET_MANIFEST.json` â€” asset path registry
- `tools/generate_placeholders.py` â€” generates all 20 placeholder PNGs
- `process_assets.py` + `tools/pipeline/` â€” sprite sheet processing pipeline
- All 20 placeholder PNGs in `assets/sprites/`
- `scripts/core/game_manager.gd` â€” autoload; food signals; ant count tracking
- `scripts/core/settings_manager.gd` - autoload; loads defaults, saves `user://settings.json`, applies volume/fullscreen/resolution settings
- `scripts/core/audio_manager.gd` - autoload; central SFX/music player stub for future audio hooks
- `scripts/core/colony_state.gd` â€” food, max_food, ant_count, priorities dict; cycle_priority; resource_urgency
- `scripts/core/job_queue.gd` â€” plain int TYPE_DIG/TYPE_GATHER constants (not enum â€” inner-class enum causes circular parse failure), Job class, per-job data dictionary, 5-term scored claim/release/complete
- `scripts/core/world_generator.gd` â€” deterministic seeded world generator; creates dirt, stone veins, cave pockets, starting tunnel/queen chamber, and procedural food positions from JSON config
- `scripts/ants/worker_ant.gd` â€” 4-state FSM (IDLE/MOVING/WORKING/IDLE_WANDER) + BFS; single-destination dig self-navigation (`_move_toward_dig_dest`, `_find_next_dig_tile`); claimed DIG jobs store active/last frontier tiles so new markers do not redirect ants; 5 starting workers; skips GATHER when food maxed; re-evaluates all jobs before re-adding food source; emergency re-score via signal; auto-gather queues GATHER jobs during idle scoring; auto-explore queues nearby frontier DIG jobs when no work is available; movement snaps to tile centers and dig work revalidates after timer
- `scripts/main.gd` â€” world setup, tileset, input, worker spawning, food sources; single-marker dig (no pre-queued path tiles)
- `scripts/ui/hud.gd` â€” food counter and worker count labels
- `scripts/ui/priority_panel.gd` â€” HUD priority controls for all 8 categories (built in code)
- `scripts/ui/main_menu.gd` - New Game / Settings / Quit entry point
- `scripts/ui/settings_menu.gd` - settings overlay for volume, fullscreen, and resolution
- `scenes/main/main.tscn` â€” root scene; TileMapLayer, Ants, markers, Camera2D, HUD
- `scenes/ants/worker_ant.tscn` â€” worker ant node with Sprite2D
- `scenes/ui/hud.tscn` â€” CanvasLayer with food/ant labels
- `scenes/ui/priority_panel.tscn` â€” priority panel scene
- `scenes/ui/main_menu.tscn` - launch scene
- `scenes/ui/settings_menu.tscn` - settings overlay scene
- `data/ants/worker_config.json` â€” move_speed, dig_duration, food_per_gather, wander_delay, sprite_max_size, auto_gather_enabled, auto_explore_enabled
- `data/colony/colony_config.json` â€” world size, queen position, starting workers
- `data/colony/priority_weights.json` â€” low/normal/high/emergency priority multipliers
- `data/world/world_generation_config.json` â€” world seed, stone/cave generation settings, and procedural food placement rules
- `data/camera/camera_config.json` â€” camera zoom and WASD/arrow-key pan speed
- `data/settings/default_settings.json` - default volume/display settings
- `data/settings/keybinds.json` - initial camera and marker keybind config
- All planning docs

---

## Systems Not Built Yet

- Auto-explore Godot validation: idle workers should expand nearby tunnel-frontier dirt when no jobs are available (Phase 3)
- Auto-gather Godot validation: workers should create GATHER jobs from food sources during idle scoring without explicit player markers (Phase 3)
- Procedural world generator Godot validation: same seed should create identical 120Ã—80 terrain and food positions after restart (Phase 3)
- Worker sprite animation â€” static placeholder, no walk cycle (Phase 3 / Phase 11)
- Main menu, settings, keybinds, SFX, music (Phase 4)
- `audio_manager.gd` autoload (Phase 4)
- Dark minimal UI visual design language â€” `ui_theme.gd`, dot-row priority panel, outlined dig markers (Phase 5)
- Room placement and BUILD jobs (Phase 6)
- Room types: Nursery, Food Storage, Barracks, Mushroom Farm, Guard Post (Phase 6)
- `room_manager.gd` (Phase 6)
- Soldier ant FSM (Phase 7)
- Enemy spawning and combat (Phase 7)
- HP bars (Phase 7)
- Repair, Emergency, Patrol, Fortify markers (Phase 8)
- Upgrade system (Phase 8)
- Seeded deterministic world generation (Phase 9)
- Pheromone trails and job clustering (Phase 9)
- Local multiplayer (Phase 10)
- Online multiplayer with authoritative server (Phase 11)
- Steam integration (Phase 12)

---

## Common Mistakes to Avoid

1. **Loading textures directly in scene scripts** â€” always use `AssetLoader`.
2. **Hardcoding stats** â€” put HP, damage, costs, timers in JSON config files.
3. **Adding multiplayer before single-player works** â€” follow the phase order.
4. **Putting game logic in UI scripts** â€” UI scripts only update display; logic lives in core scripts.
5. **Making scripts longer than 1000 lines** â€” split by responsibility.
6. **Using global variables instead of signals** â€” decouple nodes with signals.
7. **Trusting client state in multiplayer** â€” server validates everything.
8. **Adding new features mid-phase** â€” finish the current phase first.
9. **Skipping config JSON files** â€” even a simple timer value should be in JSON.
10. **Committing `.godot/` folder contents** â€” that folder is auto-generated, keep it in .gitignore.
11. **Letting the player directly remove or change tiles** â€” all world changes must be triggered by a marker and executed by an ant. There is no "click to instantly dig."
12. **Bypassing the job queue** â€” ants must claim jobs from `job_queue.gd`. Do not assign targets to ants directly.
13. **Hardcoding priority weights** â€” always read from `colony_state.priorities`.
14. **Making rooms appear instantly** â€” rooms must be built by workers over time. No instant placement outside debug mode.
15. **Calling `ant.move_to()` from outside the ant FSM** â€” movement decisions belong to the ant, not the caller.
16. **Re-adding a persistent job before `_enter_idle()`** â€” if a gather job is re-added before the ant scores, the ant sees it at distance 0 and immediately re-claims it, starving all other job types. Always enter idle first, re-add the job one frame later.
17. **Using inner-class enums that reference the outer class** â€” `class_name Foo` with `enum Bar` and `class Inner: var x: Foo.Bar` causes a GDScript circular parse failure. Use plain `const` integers instead.
18. **Mutating the TileMap directly from any script** â€” all tile changes must go through a validation layer before calling `set_cell`. This is already needed for multiplayer command validation; build it right the first time.
19. **Hardcoding `colony_id = 0`** â€” every colony-specific function must accept a `colony_id` parameter. Passing `0` is fine in single-player; skipping the param entirely blocks multiplayer without a rewrite.
