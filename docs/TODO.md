# TODO — Ant Colony Wars

Update this file every time a task is completed, started, or discovered.
Always read this file before starting any work session.

---

## NOW — Phase 1: Single-Player Colony Prototype

Read `docs/AUTONOMY_DESIGN.md` before writing any ant or job code.

### Core Systems ✓
- [x] Create `scripts/core/game_manager.gd` — autoload; food signals; ant count tracking
- [x] Create `scripts/core/colony_state.gd` — food, max_food, priorities dict
- [x] Create `scripts/core/job_queue.gd` — JobType, Job class, claim/release/complete/score
- [x] Register `GameManager` as autoload in `project.godot`
- [x] Create `data/ants/worker_config.json` — move_speed, dig_duration
- [x] Create `data/colony/colony_config.json` — world size, queen pos, starting workers

### Worker Ant ✓
- [x] Create `scenes/ants/worker_ant.tscn` — Node2D + Sprite2D
- [x] Create `scripts/ants/worker_ant.gd` — 4-state FSM + BFS pathfinding
- [x] IDLE: score unclaimed jobs; claim best; transition to MOVING
- [x] MOVING: step along path with tweens; unclaim if no path
- [x] WORKING (DIG): wait dig_duration → change tile to tunnel → complete job
- [x] WORKING (GATHER): add food → re-add gather job → IDLE
- [x] IDLE_WANDER: random neighbor walk → retry IDLE after delay

### World & Main Scene ✓
- [x] Create `scenes/main/main.tscn` — TileMapLayer, Ants, markers, Camera2D, HUD
- [x] Create `scripts/main.gd` — world setup, tileset in code, food sources, input
- [x] TileSet set up in code using AssetLoader (dirt, tunnel, stone, queen tiles)
- [x] Left-click dirt tile → Dig Marker placed + DIG job added to queue
- [x] Cannot place Dig Marker on queen chamber tiles (protected set)
- [x] Camera centered over queen chamber at startup

### HUD ✓
- [x] Create `scenes/ui/hud.tscn` — CanvasLayer with Food + Worker labels
- [x] Create `scripts/ui/hud.gd` — connects to GameManager signals

### Still Needed Before Phase 1 is Done
- [ ] Open Godot 4.6, import project — confirm no errors in FileSystem panel
- [ ] Assign worker ant sprite in Sprite2D (use AssetLoader in worker_ant.gd _ready, or assign texture in main.gd after spawning)
- [ ] Press F5 — confirm workers appear, move, dig
- [ ] Place 3 dig markers — all 3 get dug
- [ ] Idle worker auto-finds food, food counter increments
- [ ] No null-reference errors in Output

### Known Gap to Fix
- [x] Worker ant Sprite2D — `_ready()` assigns `AssetLoader.get_ant_sprite("worker")`

---

## NEXT — Phase 2: Priority System & Job Score

- [ ] Add priority level cycling (low/normal/high/emergency) to colony_state
- [ ] Extend job_queue._score_job with danger, resource_urgency, solo_bonus terms
- [ ] Create `scripts/ui/priority_panel.gd` + `scenes/ui/priority_panel.tscn`
- [ ] Changing priority to `emergency` forces all ants to re-score on next tick
- [ ] Create `data/colony/priority_weights.json`
- [ ] Verify: set food priority to high → workers prefer GATHER over DIG

---

## BLOCKED

Nothing blocked.

---

## NEEDS TESTING (Phase 1)

- Worker FSM: does it get stuck if all jobs are claimed?
- BFS: unreachable tile — does worker gracefully wander instead of looping?
- Gather job re-add: is it duplicated if two workers finish gather at same time?
  (job_queue.add_job has duplicate guard — should be safe)
- AssetLoader fallback: workers should show amber placeholder if sprite file missing

---

## DONE

- Phase 0 setup files created (2026-05-07)
- Phase 0.5 asset pipeline and placeholder generator complete (2026-05-07)
- Design docs updated: CONTEXT.md, ROADMAP.md, AUTONOMY_DESIGN.md (2026-05-07)
- Project pushed to GitHub: https://github.com/SnazzyTrack9218/ant-colony-wars (2026-05-07)
- Phase 1 core scripts written: game_manager, colony_state, job_queue, worker_ant, main, hud (2026-05-07)
