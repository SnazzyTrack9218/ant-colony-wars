# Ant Colony Wars — Project Structure

All paths are relative to the Godot project root (`res://`).

---

## Full Folder Tree

```
res://
│
├── project.godot              <- Godot project config. Autoloads registered here.
├── icon.svg                   <- Default project icon (replace in Phase 7)
│
├── scenes/                    <- All .tscn scene files
│   ├── main/                  <- Root game scene, world TileMap
│   ├── ants/                  <- Worker, soldier, queen ant scenes
│   ├── rooms/                 <- Room node scenes (nursery, food_storage, etc.)
│   ├── enemies/               <- Enemy scenes (spider, beetle, termite)
│   ├── ui/                    <- HUD, menus, priority panel, settings
│   └── multiplayer/           <- Lobby scene, split-screen scene
│
├── scripts/                   <- All .gd GDScript source files
│   ├── core/                  <- game_manager.gd, colony_state.gd, job_queue.gd, enemy_spawner.gd
│   ├── ants/                  <- worker_ant.gd, soldier_ant.gd, ant_fsm.gd
│   ├── rooms/                 <- room_manager.gd, nursery.gd, food_storage.gd
│   ├── enemies/               <- spider.gd, beetle.gd, termite.gd
│   ├── ui/                    <- hud.gd, priority_panel.gd, lobby_ui.gd, settings_menu.gd
│   ├── multiplayer/           <- network_manager.gd, server.gd, client.gd, command_packets.gd
│   └── assets/                <- asset_loader.gd  ← AUTOLOAD SINGLETON
│
├── assets/                    <- All binary art and audio files
│   ├── sprites/
│   │   ├── ants/              <- worker_ant.png, soldier_ant.png, queen_ant.png, egg.png
│   │   ├── rooms/             <- nursery.png, food_storage.png, queen_chamber.png, etc.
│   │   ├── tiles/             <- dirt_tile.png, tunnel_tile.png, stone_tile.png
│   │   ├── enemies/           <- spider_enemy.png, beetle_enemy.png, termite_enemy.png
│   │   └── ui/                <- food_icon.png, worker_icon.png, soldier_icon.png, egg_icon.png
│   ├── audio/
│   │   ├── sfx/               <- dig.wav, hatch.wav, combat.wav, victory.wav
│   │   └── music/             <- colony_theme.ogg
│   └── fonts/                 <- main_font.ttf
│
├── data/                      <- JSON config and manifest files (no binary files here)
│   ├── ASSET_MANIFEST.json    <- Maps asset names to file paths (read by AssetLoader)
│   ├── rooms/                 <- nursery_config.json, food_storage_config.json, etc.
│   └── enemies/               <- spider_config.json, beetle_config.json, etc.
│
└── docs/                      <- Planning and reference documents
	├── ROADMAP.md             <- Phase-by-phase development plan
	├── CONTEXT.md             <- Living context doc for AI agents and developers
	├── ASSET_GUIDE.md         <- How to add and name assets
	├── PLACEHOLDER_ASSETS.md  <- How the placeholder fallback system works
	├── PROJECT_STRUCTURE.md   <- This file
	└── TODO.md                <- Current task board
```

---

## Key Design Decisions

### Why `data/` is separate from `assets/`
`data/` contains JSON text files that control game behaviour (stats, costs, timers, asset paths).
`assets/` contains binary files (images, audio) that Godot imports at build time.
Separating them makes it easy to read config files at runtime without scanning the assets folder.

### Why `scripts/assets/` is its own subfolder
The asset loader is a cross-cutting concern used by every other system.
Keeping it isolated in `scripts/assets/` prevents circular imports and makes it easy to find.

### Why scenes and scripts are in separate top-level folders
This mirrors the Godot convention and makes it simple to know where to look:
- Changing a node tree → edit `scenes/`
- Changing behaviour → edit `scripts/`

### Autoloads registered in `project.godot`
Currently registered:
- `AssetLoader` → `res://scripts/assets/asset_loader.gd`

Future autoloads (added in their respective phases):
- `GameManager` → `res://scripts/core/game_manager.gd`  (Phase 1)
- `NetworkManager` → `res://scripts/multiplayer/network_manager.gd` (Phase 6)

### `.godot/` is auto-generated
The `.godot/` folder (shader cache, editor state, imported assets) is created by Godot at runtime.
It is listed in `.gitignore` and must never be committed.
Godot recreates it automatically on the next launch after a fresh clone.

---

## File Naming Quick Reference

| Type           | Convention         | Example                     |
|----------------|--------------------|-----------------------------|
| Scene files    | `snake_case.tscn`  | `worker_ant.tscn`           |
| Script files   | `snake_case.gd`    | `worker_ant.gd`             |
| Sprite files   | `snake_case.png`   | `worker_ant.png`            |
| Config files   | `snake_case_config.json` | `nursery_config.json` |
| Doc files      | `UPPER_CASE.md`    | `ROADMAP.md`                |
