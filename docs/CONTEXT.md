# Ant Colony Wars — Context File for AI Agents

Read this file before writing any code. Update it whenever a system's status changes.

---

## What Is This Game

Ant Colony Wars is a 2D side-view ant farm strategy game built in Godot 4.6.
Each player controls one underground ant colony. Players do not directly control individual ants.
Instead, they dig tunnels, build rooms, set priorities, gather food, hatch ants, raise soldiers, and raid the enemy queen to win.
The game supports 1v1 multiplayer (online and local), but multiplayer is built only after single-player works.

---

## Core Loop

1. **Place Dig Markers** on dirt tiles → worker ants pathfind to them and dig autonomously
2. **Expand tunnels** to reach food sources and create space for rooms
3. **Build rooms** in cleared tunnel space (nursery, food storage, barracks)
4. **Gather food** — workers auto-seek food, or player places Gather Markers on food sources
5. **Hatch eggs** in the nursery → new worker ants added to the colony
6. **Train soldiers** in the barracks
7. **Direct soldiers** with Rally and Fortify Markers to defend the nest
8. **Raid the enemy** — place a Raid Rally Marker in enemy territory, soldiers push toward their queen
9. **Destroy the enemy queen** → win

### The Marker System (Core Interaction Model)
The player never directly changes the game world. Every action goes through a marker:
- **Left-click dirt tile** → Dig Marker (worker digs it)
- **Left-click food source** → Gather Marker (worker collects it)
- **Right-click location** → Rally Marker (soldiers move there)
- **Shift+click** → High priority marker
- **Ctrl+click** → Low priority marker

Ants are always autonomous. The player's job is to place the right markers in the right places.

---

## Current Rules (Do Not Break These)

1. Build one feature at a time. Do not start the next system before the current one is tested.
2. Use placeholder art until the game mechanic works. Do not wait for real art.
3. Do not over-engineer. Three similar lines is better than a premature abstraction.
4. Do not add multiplayer code before single-player is stable.
5. Server must be authoritative. Clients only send commands. Never trust client state.
6. All assets go through `AssetLoader`. Never call `load("res://...")` in scene scripts directly.
7. Keep scripts under 1000 lines. Split by responsibility if a file grows too large.
8. Data-driven design: game stats (HP, damage, cost, timer) live in JSON config files under `data/`, not hardcoded.
9. Use `snake_case` for all file names, variable names, and function names.
10. Use signals for communication between nodes. Do not call parent/sibling nodes directly.

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
- Clients send command packets: `dig_tile`, `place_room`, `set_priority`, `send_raid`
- Server validates every command before applying it
- Clients predict ant movement locally (visual only) but server corrects on mismatch
- Never call `rpc()` from client to directly mutate enemy colony state
- Headless server build must run without crash

Do not implement any of this until Phase 6.

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
    ASSET_GUIDE.md
    PLACEHOLDER_ASSETS.md
    PROJECT_STRUCTURE.md
    TODO.md
```

---

## Current Development Phase

**Phase 0 — Project Setup**

---

## Systems Already Built

- `scripts/assets/asset_loader.gd` — AssetLoader autoload (placeholder fallback)
- `data/ASSET_MANIFEST.json` — asset path registry
- All planning docs
- Full folder scaffold

---

## Systems Not Built Yet

- TileMap / world grid
- Worker ant scene and movement
- Food resource system
- Colony state (GameManager)
- Room placement and room types
- Enemy spawning and combat
- Ant FSM and job queue
- HUD / UI panels
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
11. **Letting the player directly remove or change tiles** — all world changes must be triggered by a marker and executed by an ant. There is no "click to instantly dig." This is the core design rule.
12. **Bypassing the job queue** — ants must claim jobs from `job_queue.gd`. Do not assign targets to ants directly from UI or world scripts.
