# TODO — Ant Colony Wars

Update this file every time a task is completed, started, or discovered.
Always read this file before starting any work session.

---

## NOW — Phase 0.5: Asset Pipeline (Final Step)

- [x] `pip install -r requirements.txt`
- [x] `python process_assets.py --dry-run` — confirmed clean
- [x] Asset pipeline tested end-to-end (grid crop, BG removal, export)
- [x] `python process_assets.py --check` — all 5 categories show "coverage OK"
- [x] `python tools/generate_placeholders.py` — all 20 placeholder PNGs generated
- [x] ASSET_GUIDE.md updated with placeholder-first workflow
- [ ] Open Godot, confirm 20 assets import with no errors in FileSystem panel
- [ ] Phase 0.5 complete → move to Phase 1

---

## NEXT — Phase 1: Single-Player Colony Prototype

Read `docs/AUTONOMY_DESIGN.md` before writing any ant or job code.

The player is the colony brain. Ants are autonomous. Nothing moves because the player said so.

### TileMap & World
- [ ] Create `scenes/main/main.tscn` — TileMap with `dirt_tile`, `tunnel_tile`, `stone_tile` tile types
- [ ] Queen Chamber tile type — Dig Markers cannot be placed on it

### Core Systems
- [ ] Create `scripts/core/game_manager.gd` — autoload; holds global state; emits signals on change
- [ ] Create `scripts/core/colony_state.gd` — food count, basic priorities dictionary (all `normal`)
- [ ] Create `scripts/core/job_queue.gd` — `add_job()`, `claim_job(ant)`, `release_job(job)`, `get_unclaimed_jobs()`
- [ ] Register `GameManager` as autoload in `project.godot`

### Worker Ant
- [ ] Create `scenes/ants/worker_ant.tscn` — worker ant scene with placeholder sprite
- [ ] Create `scripts/ants/worker_ant.gd` — 4-state FSM: `IDLE → MOVING → WORKING → IDLE_WANDER`
- [ ] IDLE: score unclaimed DIG and GATHER jobs; claim best; transition to MOVING
- [ ] Score formula (Phase 1 simplified): `priority_weight + (10.0 / (distance + 1.0))`
- [ ] MOVING: BFS pathfind to job tile; if no path, unclaim and return to IDLE
- [ ] WORKING (DIG): brief pause → tile becomes tunnel_tile → marker removed → return to IDLE
- [ ] WORKING (GATHER): carry food back to colony → food counter increments → return to IDLE
- [ ] IDLE_WANDER: random short walk near queen; after arrival, re-enter IDLE scoring
- [ ] Workers flee toward queen if enemy is within melee range (Phase 1 stub — no enemies yet, just the rule)

### Marker Input
- [ ] Left-click dirt tile → Dig Marker placed (colored tile overlay) + DIG job added to queue
- [ ] Left-click food tile → GATHER job added to queue (auto-gather also fires when workers are idle)
- [ ] Cannot place Dig Marker on Queen Chamber tile

### HUD
- [ ] Create `scenes/ui/hud.tscn` + `scripts/ui/hud.gd` — food counter label
- [ ] HUD reads from signal emitted by `colony_state.gd`; HUD does not read game state directly

### Phase 1 Acceptance Test
- [ ] Press F5 — no errors
- [ ] Place Dig Marker → worker walks to it and digs → no crash
- [ ] Idle worker auto-finds food and carries it back → food counter increments
- [ ] Place 3 markers → all 3 get dug in sequence or parallel
- [ ] No direct ant control anywhere in the code

---

## AFTER PHASE 1 — Phase 2: Priority System & Job Score

- [ ] Add 8 priority categories to `colony_state.gd`
- [ ] Add priority level cycling (low/normal/high/emergency) with weight multipliers from JSON
- [ ] Extend job score formula with danger, resource urgency, solo bonus terms
- [ ] Create Priority Panel HUD component
- [ ] Changing priority to `emergency` forces all ants to re-score on next tick
- [ ] Create `data/colony/priority_weights.json`

---

## BLOCKED

Nothing is blocked right now.

---

## NEEDS TESTING

- `AssetLoader` fallback: does it print warnings (not errors) for all missing assets?
- `AssetLoader.reload_manifest()`: confirm it clears cache and re-reads the JSON

---

## DONE

- Phase 0 setup files created (2026-05-07)
- Phase 0.5 asset pipeline and placeholder generator complete (2026-05-07)
- Design docs updated: CONTEXT.md, ROADMAP.md, AUTONOMY_DESIGN.md (2026-05-07)
- Project organized and pushed to GitHub: https://github.com/SnazzyTrack9218/ant-colony-wars (2026-05-07)
