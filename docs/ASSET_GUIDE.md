# Ant Colony Wars — Asset Guide

How to add, name, and organize art files for this project.

---

## Placeholder-First Workflow (Default)

**The game ships with generated placeholder art and must work completely with it.**
Real art is added gradually by replacing individual files. No code ever changes.

### How placeholders are generated

```
python tools/generate_placeholders.py
```

This creates all 20 required sprites in the correct folders using Pillow.
Re-run it any time to reset all art back to placeholders.

### Placeholder visual design

| Category | Shape | Color coding |
|----------|-------|--------------|
| Worker ant | 3-segment ant body | Amber / orange-brown |
| Soldier ant | 3-segment ant body | Dark red |
| Queen ant | 3-segment ant body + crown dots | Gold |
| Egg | Small oval | Cream / pale yellow |
| Dirt tile | 16×16 textured square | Brown with specks |
| Tunnel tile | 16×16 square | Near-black (empty space) |
| Stone tile | 16×16 square | Grey with crack lines |
| Rooms | 64×64 filled rectangle | Distinct color + label text |
| Enemies | 32×32 bug silhouette | Reds/browns (threatening) |
| UI icons | 32×32 colored square | Label text inside |

### How to replace one placeholder with real art

1. Create your PNG with the exact filename from the table below
2. Drop it into the correct folder
3. Open Godot — it auto-imports on startup
4. Run the game — the placeholder disappears, real art loads

No manifest edits. No code changes. The filename is the only contract.

---

## Required Assets and Where They Live

### Ants — `assets/sprites/ants/`

| Filename | Placeholder | Replace when |
|---|---|---|
| `worker_ant.png` | Amber 3-segment ant | Phase 7 art pass |
| `soldier_ant.png` | Dark red 3-segment ant | Phase 7 art pass |
| `queen_ant.png` | Gold 3-segment ant + crown | Phase 7 art pass |
| `egg.png` | Cream oval | Phase 7 art pass |

### Tiles — `assets/sprites/tiles/`

| Filename | Placeholder | Replace when |
|---|---|---|
| `dirt_tile.png` | Brown textured 16×16 | Phase 7 art pass |
| `tunnel_tile.png` | Near-black 16×16 | Phase 7 art pass |
| `stone_tile.png` | Grey 16×16 with cracks | Phase 7 art pass |

**Tile size must be exactly 16×16 to match the TileMap tile size.**

### Rooms — `assets/sprites/rooms/`

| Filename | Placeholder | Replace when |
|---|---|---|
| `queen_chamber.png` | Gold rect "QUEEN" | Phase 2 or Phase 7 |
| `nursery.png` | Green rect "NURSERY" | Phase 2 or Phase 7 |
| `food_storage.png` | Orange rect "FOOD" | Phase 2 or Phase 7 |
| `soldier_barracks.png` | Dark red rect "BARRACKS" | Phase 3 or Phase 7 |
| `mushroom_farm.png` | Purple rect "SHROOM" | Phase 2 or Phase 7 |
| `guard_post.png` | Grey rect "GUARD" | Phase 3 or Phase 7 |

### Enemies — `assets/sprites/enemies/`

| Filename | Placeholder | Replace when |
|---|---|---|
| `spider_enemy.png` | Dark red 8-legged shape | Phase 3 or Phase 7 |
| `beetle_enemy.png` | Dark brown oval with shell | Phase 3 or Phase 7 |
| `termite_enemy.png` | Brown elongated body | Phase 3 or Phase 7 |

### UI Icons — `assets/sprites/ui/`

UI layout is code-driven (Label nodes, Control nodes). These icon files are in the
manifest for HUD sprites only. The main UI does not depend on them.

| Filename | Placeholder |
|---|---|
| `food_icon.png` | Green square "FOOD" |
| `worker_icon.png` | Amber square "WRK" |
| `soldier_icon.png` | Red square "SOL" |
| `egg_icon.png` | Cream square "EGG" |

---

## Required Asset Folders

```
assets/sprites/ants/      <- ant sprites
assets/sprites/rooms/     <- room sprites
assets/sprites/tiles/     <- tile sprites (16x16 only)
assets/sprites/enemies/   <- enemy sprites
assets/sprites/ui/        <- HUD icon sprites
assets/audio/sfx/         <- short sound effects (.wav or .ogg)
assets/audio/music/       <- background music tracks (.ogg)
assets/fonts/             <- font files (.ttf or .otf)
```

Do not create subfolders inside sprite category folders.

---

## File Naming Rules

- `snake_case` only. No spaces, no hyphens, no capital letters.
- Suffix by type as shown in the tables above.

| Bad example | Problem |
|---|---|
| `WorkerAnt.png` | Wrong case |
| `worker ant.png` | Has a space |
| `worker_ant_v2.png` | Version suffix — replace the file instead |
| `ant_worker.png` | Wrong word order |

---

## Supported Image Formats

- **PNG** — preferred. Supports transparency (RGBA).
- **SVG** — accepted. Godot rasterises on import.
- Do not use `.jpg` — lossy, breaks transparency.

---

## Sprite Size Recommendations

| Category | Size | Hard requirement? |
|---|---|---|
| Ants | 32×32 | No — scale in scene |
| Tiles | **16×16** | **Yes** — must match TileMap |
| Rooms | 64×64 | No — scale in scene |
| Enemies | 32×32 | No — scale in scene |
| UI icons | 32×32 | No — scaled by Control nodes |

---

## How to Add a New Ant Type

1. Add PNG to `assets/sprites/ants/{name}_ant.png`
2. Add to `data/ASSET_MANIFEST.json`:
   ```json
   "ants": { "scout": "res://assets/sprites/ants/scout_ant.png" }
   ```
3. Load in code with `AssetLoader.get_ant_sprite("scout")`
4. Create `scenes/ants/scout_ant.tscn` and `scripts/ants/scout_ant.gd`
5. Add a placeholder entry to `tools/generate_placeholders.py` so it regenerates correctly

---

## How to Add a New Room Type

1. Add PNG to `assets/sprites/rooms/{name}.png`
2. Add to `data/ASSET_MANIFEST.json` under `"rooms"`
3. Create `data/rooms/{name}_config.json` with build cost and stats
4. Create `scripts/rooms/{name}.gd` and `scenes/rooms/{name}.tscn`
5. Register in `scripts/rooms/room_manager.gd`

---

## How to Add a New Enemy Type

1. Add PNG to `assets/sprites/enemies/{name}_enemy.png`
2. Add to `data/ASSET_MANIFEST.json` under `"enemies"`
3. Create `data/enemies/{name}_config.json` with HP, damage, speed
4. Create `scripts/enemies/{name}.gd` and `scenes/enemies/{name}.tscn`
5. Register in `scripts/core/enemy_spawner.gd`

---

## Keeping Assets Organized

- One file per asset. No sprite sheets until animation is needed (Phase 7).
- No version suffixes. Replace the file directly.
- No subfolders inside category folders.
- When removing an asset: delete the file AND its manifest entry at the same time.
- All textures load through `AssetLoader` — never call `load("res://...")` in scene scripts.
