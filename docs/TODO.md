# TODO — Ant Colony Wars

Update this file every time a task is completed, started, or discovered.
Always read this file before starting any work session.

---

## NOW — Phase 0.5: Asset Pipeline Tool

- [x] `pip install -r requirements.txt`
- [x] `python process_assets.py --dry-run` — confirmed clean
- [x] Asset pipeline tested end-to-end (grid crop, BG removal, export)
- [x] `python process_assets.py --check` — all 5 categories show "coverage OK"
- [x] `python tools/generate_placeholders.py` — all 20 placeholder PNGs generated
- [x] ASSET_GUIDE.md updated with placeholder-first workflow
- [ ] Open Godot, confirm 20 assets import with no errors in FileSystem panel
- [ ] Phase 0.5 complete → move to Phase 1

---

## DONE — Phase 0: Project Setup

- [x] Create all planning docs (ROADMAP, CONTEXT, ASSET_GUIDE, PLACEHOLDER_ASSETS, PROJECT_STRUCTURE, TODO)
- [x] Create all asset and source folders
- [x] Create `data/ASSET_MANIFEST.json`
- [x] Create `scripts/assets/asset_loader.gd`
- [x] Register `AssetLoader` as autoload in `project.godot`
- [x] Asset pipeline tool created (process_assets.py + tools/pipeline/)
- [ ] Open Godot 4.6 and confirm zero import errors
- [ ] Press F5 — confirm no crash, Output shows "AssetLoader: manifest loaded"
- [ ] Confirm per-asset warnings appear for all 16 missing sprite files

---

## NEXT — Phase 1: Single-Player Colony Prototype

- [ ] Create `scenes/main/main.tscn` — TileMap with `dirt_tile` and `tunnel_tile` types
- [ ] Create `scripts/core/job_queue.gd` — stores pending marker jobs; ants claim from here
- [ ] Left-click dirt tile → places Dig Marker (visual + job added to queue)
- [ ] Cannot place Dig Marker on Queen Chamber tile
- [ ] Create `scenes/ants/worker_ant.tscn` — worker ant with placeholder sprite
- [ ] Create `scripts/ants/worker_ant.gd` — 3-state FSM: IDLE → MOVING → DIGGING → IDLE
- [ ] BFS pathfinding in worker: finds route to claimed job tile, skips if no route
- [ ] Worker arrives at Dig Marker → brief pause → tile becomes `tunnel_tile` → marker removed
- [ ] Workers idle-seek food tiles on surface → carry food back → food counter increments
- [ ] Create `scripts/core/game_manager.gd` — autoload, holds `food: int`
- [ ] Create `scripts/core/colony_state.gd` — food, ant count
- [ ] Create `scenes/ui/hud.tscn` + `scripts/ui/hud.gd` — food counter label
- [ ] Register `GameManager` as autoload in `project.godot`
- [ ] Phase 1 acceptance test: place marker → ant walks to it and digs → no crashes

---

## BLOCKED

Nothing is blocked right now.

---

## NEEDS TESTING

- `AssetLoader` fallback: does it print warnings (not errors) for all 16 missing assets?
- `AssetLoader.reload_manifest()`: confirm it clears cache and re-reads the JSON

---

## DONE

- Phase 0 setup files created (2026-05-07)
