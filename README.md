# Ant Colony Wars

A 2D side-view ant farm strategy game built in Godot 4.6.

Each player controls one underground ant colony. Dig tunnels, build rooms, hatch ants, raise soldiers, and destroy the enemy queen to win.

---

## Current Development Phase

**Phase 0.5 — Asset Pipeline & Placeholders**

All 20 required game sprites exist as generated placeholders. The game structure is in place. Gameplay begins in Phase 1.

See [`docs/ROADMAP.md`](docs/ROADMAP.md) for the full phase plan.

---

## Quick Start

**Requirements**
- [Godot 4.6](https://godotengine.org/download)
- Python 3.8+ with Pillow and numpy (for asset tools only)

**Run the game**
1. Open Godot 4.6
2. Import this project folder
3. Press F5

**Install asset pipeline tools (one time)**
```
pip install -r requirements.txt
```

---

## Project Structure

```
scenes/          Godot scene files (.tscn)
scripts/         GDScript source files (.gd)
assets/sprites/  All game sprites (PNG, RGBA)
data/            JSON config files and asset manifest
docs/            Planning and reference documents
tools/           Python dev tools (asset pipeline, placeholder generator)
assets_inbox/    Drop sprite sheets here to process with the pipeline
addons/          Godot plugins (debug_api)
```

Full structure: [`docs/PROJECT_STRUCTURE.md`](docs/PROJECT_STRUCTURE.md)

---

## Asset Pipeline

Drop sprite sheets into `assets_inbox/{category}/`, configure `assets_inbox/pipeline_config.json`, then run:

```
python process_assets.py
python process_assets.py --dry-run    # preview
python process_assets.py --check      # check manifest gaps
```

Regenerate all placeholder art:
```
python tools/generate_placeholders.py
```

Replace any placeholder with real art by dropping a same-named PNG in `assets/sprites/{category}/`. Godot auto-imports on next startup.

Full guide: [`docs/ASSET_GUIDE.md`](docs/ASSET_GUIDE.md)

---

## AI Agent Workflow

Before writing any code, agents should read:
1. [`docs/CONTEXT.md`](docs/CONTEXT.md) — game overview, rules, coding style
2. [`docs/ROADMAP.md`](docs/ROADMAP.md) — phase-by-phase plan
3. [`docs/TODO.md`](docs/TODO.md) — current tasks

Then make **one feature only**, update `TODO.md`, and update `CONTEXT.md` if a system changed.

---

## Core Game Loop

1. Place **Dig Markers** on dirt → worker ants pathfind and dig autonomously
2. Build rooms in cleared tunnel space (nursery, barracks, food storage)
3. Gather food; hatch eggs → new worker ants
4. Train soldiers in the barracks
5. Direct soldiers with **Rally Markers** to defend the nest
6. Place a **Raid Rally** in enemy territory → soldiers push toward enemy queen
7. Destroy enemy queen → win

---

## Addons

- [`addons/debug_api/`](addons/debug_api/) — in-game debug overlay by [@ArugerDev](https://github.com/ArugerDev) (MIT)
