# Ant Colony Wars — Context File for AI Agents

Read this file before writing any code. Update it whenever a system's status changes.

---

## What Is This Game

Ant Colony Wars is a 2D side-view ant farm strategy game built in Godot 4.6.
The player is the **colony brain** — they never directly control individual ants.
Instead, they place markers, set priorities, approve room plans, and issue colony-level orders.
Ants always act autonomously based on job scoring and colony priorities.
The game supports 1v1 multiplayer (online and local), but multiplayer is built only after single-player works.

---

## Core Loop

```
Set Priorities → Place Markers → Ants Auto-Work → Colony Grows → Soldiers Defend/Raid → Destroy Enemy Queen → Win
```

1. **Set colony priorities** — adjust the Priority Panel to tell the colony what matters most
2. **Place Dig Markers** on dirt tiles → workers autonomously pathfind, claim jobs, and dig
3. **Place Room Plan Markers** in cleared tunnel space → workers auto-build rooms over time
4. **Food accumulates** — workers auto-seek food sources or follow Gather Markers
5. **Nursery hatches eggs** → new worker ants join the colony
6. **Train soldiers** in the Barracks (training happens automatically when `soldiers` priority is set)
7. **Soldiers defend autonomously** based on `defense` priority and proximity to threats
8. **Place Raid Rally Marker** in enemy territory → soldiers push toward enemy queen
9. **Enemy queen destroyed** → win

---

## The Marker System

The player never directly changes the world. Every action goes through a marker:

| Marker | Input | Who Claims | Effect |
|---|---|---|---|
| **Dig Marker** | Left-click dirt tile | Worker | Digs tile → tunnel tile |
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
| `low` | 0.5× | Only when nothing higher is available |
| `normal` | 1.0× | Default |
| `high` | 1.5× | Preferred over normal tasks |
| `emergency` | 2.5× | Ants drop current job and re-score immediately |

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
- Keep the formula simple — do not add terms without a gameplay reason.

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

---

## Coding Style

- Language: GDScript only
- Naming: `snake_case` for files, variables, functions; `PascalCase` for class names and scene nodes
- Max file length: ~1000 lines. If a script exceeds this, split it.
- Autoloads (singletons): `AssetLoader`, `GameManager` — global systems only
- Signals for all inter-node communication
- Config data: JSON files in `data/` — never hardcode numbers that a designer might tune
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
- Server is authoritative for all game state
- Clients send command packets: `place_marker`, `set_priority`, `approve_room_plan`, `send_raid`
- Server validates every command before applying it
- Clients predict ant movement locally (visual only) but server corrects on mismatch
- Never call `rpc()` from client to directly mutate enemy colony state
- Headless server build must run without crash

Do not implement any of this until Phase 7.

---

## Asset Rules

- All 20 required sprites exist as **generated placeholders** — the game runs fully without any real art
- Re-generate placeholders any time with `python tools/generate_placeholders.py`
- All textures load through `AssetLoader` (autoload singleton) — never call `load("res://...")` directly
- `AssetLoader` reads `data/ASSET_MANIFEST.json` at startup; missing files fall back to solid-color placeholders
- To replace a placeholder with real art: drop a same-named PNG in the same folder — Godot auto-imports, no code changes
- Never add `.import` files to version control — Godot regenerates them
- Naming: `snake_case`, suffix by type — `worker_ant.png`, `dirt_tile.png`, `spider_enemy.png`
- Tile sprites must be exactly 16×16 to match TileMap tile size

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

**Phase 0.5 — Asset Pipeline & Placeholders** (complete, pending Godot import verification)

---

## Systems Already Built

- `scripts/assets/asset_loader.gd` — AssetLoader autoload (placeholder fallback)
- `data/ASSET_MANIFEST.json` — asset path registry
- `tools/generate_placeholders.py` — generates all 20 placeholder PNGs
- `process_assets.py` + `tools/pipeline/` — sprite sheet processing pipeline
- All 20 placeholder PNGs in `assets/sprites/`
- All planning docs

---

## Systems Not Built Yet

- TileMap / world grid
- Worker ant scene and FSM
- Job queue and job scoring
- Colony state and priority system
- Food resource system
- Room placement (Room Plan Markers)
- Enemy spawning and combat
- Soldier ant FSM
- HUD / Priority Panel UI
- Upgrades system
- Local multiplayer
- Online multiplayer
- Steam integration

---

## Common Mistakes to Avoid

1. **Loading textures directly in scene scripts** — always use `AssetLoader`.
2. **Hardcoding stats** — put HP, damage, costs, timers in JSON config files.
3. **Adding multiplayer before single-player works** — follow the phase order.
4. **Putting game logic in UI scripts** — UI scripts only update display; logic lives in core scripts.
5. **Making scripts longer than 1000 lines** — split by responsibility.
6. **Using global variables instead of signals** — decouple nodes with signals.
7. **Trusting client state in multiplayer** — server validates everything.
8. **Adding new features mid-phase** — finish the current phase first.
9. **Skipping config JSON files** — even a simple timer value should be in JSON.
10. **Committing `.godot/` folder contents** — that folder is auto-generated, keep it in .gitignore.
11. **Letting the player directly remove or change tiles** — all world changes must be triggered by a marker and executed by an ant. There is no "click to instantly dig."
12. **Bypassing the job queue** — ants must claim jobs from `job_queue.gd`. Do not assign targets to ants directly.
13. **Hardcoding priority weights** — always read from `colony_state.priorities`.
14. **Making rooms appear instantly** — rooms must be built by workers over time. No instant placement outside debug mode.
15. **Calling `ant.move_to()` from outside the ant FSM** — movement decisions belong to the ant, not the caller.
