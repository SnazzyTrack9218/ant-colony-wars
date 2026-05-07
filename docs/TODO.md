# TODO — Ant Colony Wars

Update this file every time a task is completed, started, or discovered.
Always read this file before starting any work session.

---

## NOW — Phase 1: Single-Player Colony Prototype

Read `docs/AUTONOMY_DESIGN.md` before writing any ant or job code.

Current implementation work has moved into Phase 2. Phase 1 still needs in-editor Godot validation.

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
- [x] WORKING (GATHER): add food → enter IDLE to re-score all jobs → re-add food job after 1 frame
- [x] IDLE_WANDER: random neighbor walk → retry IDLE after delay
- [x] Skip GATHER jobs when colony food is at max (`_valid_job_types()`)
- [x] 5 starting workers (4 gather, 1+ available for digging)

### World & Main Scene ✓
- [x] Create `scenes/main/main.tscn` — TileMapLayer, Ants, markers, Camera2D, HUD
- [x] Create `scripts/main.gd` — world setup, tileset in code, food sources, input
- [x] TileSet set up in code using AssetLoader (dirt, tunnel, stone, queen tiles)
- [x] Left-click dirt tile → BFS from existing tunnel network finds shortest path to target → Dig Markers + DIG jobs queued for every tile along path
- [x] Cannot place Dig Marker on queen chamber tiles (protected set)
- [x] Camera centered over queen chamber at startup

### HUD ✓
- [x] Create `scenes/ui/hud.tscn` — CanvasLayer with Food + Worker labels
- [x] Create `scripts/ui/hud.gd` — connects to GameManager signals

### Still Needed Before Phase 1 is Done
- [ ] Open Godot 4.6, import project — confirm no errors in FileSystem panel
- [ ] Press F5 — 5 workers appear, move autonomously
- [ ] Click deep dirt tile — verify orange markers appear along full tunnel path to target
- [ ] Multiple free ants converge on dig path; tiles dug progressively
- [ ] Food counter increments as workers gather
- [ ] Fill food to max (200) → all ants switch to digging instead
- [ ] No null-reference errors in Output

### Bugs Fixed
- [x] Worker ant Sprite2D — `_ready()` assigns `AssetLoader.get_ant_sprite("worker")`
- [x] `JobType` enum circular reference — inner class referencing outer class enum caused silent parse failure; replaced with plain int constants `TYPE_DIG = 0`, `TYPE_GATHER = 1`
- [x] Ants always re-grabbed same food job — food job now re-added 1 frame after ant enters IDLE, giving it a chance to score dig jobs first
- [x] Ants ignored dig jobs when food available — `_valid_job_types()` returns only `[TYPE_DIG]` when food is at max
- [x] Click-per-tile digging — replaced with auto-path dig (multi-source BFS from whole tunnel network to target; all intermediate tiles queued)

---

## NEXT — Phase 2: Priority System & Job Score

- [x] Add priority level cycling (low/normal/high/emergency) to colony_state
- [x] Extend job_queue._score_job with danger, resource_urgency, solo_bonus terms
- [x] Create `scripts/ui/priority_panel.gd` + `scenes/ui/priority_panel.tscn`
- [x] Changing priority to `emergency` forces moving/wandering workers to re-score on next tick
- [x] Create `data/colony/priority_weights.json`

## NEXT - Phase 2 Validation

- [ ] Open Godot 4.6, import project and confirm Priority Panel appears in top-right HUD
- [ ] Press +/- buttons for each category and confirm levels cycle low/normal/high/emergency
- [ ] Set food priority to high and confirm workers prefer GATHER over DIG
- [ ] Set digging priority to emergency and confirm moving/wandering workers release lower-priority jobs and re-score
- [ ] Confirm `colony_state.get_priority_weight("food")` reads from `data/colony/priority_weights.json`
- [ ] No parse errors or null-reference errors in Output
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

## NEEDS TESTING (Phase 2)

- Priority Panel scene imports cleanly and appears inside HUD
- Priority buttons update `GameManager.colony.priorities`
- Emergency priority interruption does not leave duplicate or stuck claimed jobs
- Scored jobs ignore unreachable targets with score 0

---

## DONE

- Phase 0 setup files created (2026-05-07)
- Phase 0.5 asset pipeline and placeholder generator complete (2026-05-07)
- Design docs updated: CONTEXT.md, ROADMAP.md, AUTONOMY_DESIGN.md (2026-05-07)
- Project pushed to GitHub: https://github.com/SnazzyTrack9218/ant-colony-wars (2026-05-07)
- Phase 1 core scripts written: game_manager, colony_state, job_queue, worker_ant, main, hud (2026-05-07)
- Fixed JobType enum circular reference crashing ant FSM (2026-05-07)
- Fixed window size and camera (fullscreen 1280×720, zoom=1, world fits viewport) (2026-05-07)
- Auto-path dig: click any dirt tile, BFS queues all tiles from tunnel to target (2026-05-07)
- Ants skip gather when food maxed; re-evaluate jobs before re-adding food source (2026-05-07)
- Bumped starting workers to 5 so dig jobs get coverage alongside food gathering (2026-05-07)
- Phase 2 priority state, job scoring, priority panel, and emergency re-score implementation added (2026-05-07)
