# TODO â€” Ant Colony Wars

Update this file every time a task is completed, started, or discovered.
Always read this file before starting any work session.

---

## NOW — Phase 7: Combat & Enemies

Read `docs/AUTONOMY_DESIGN.md` before writing any ant or job code.

### Immediate Bugs to Fix
- [x] Ants still visually clip or appear to pass through walls - sprite now fits inside tile; logical tile commits on tween completion; interrupted movement snaps to tile center
- [x] Worker stuck in WORKING state when dest becomes unreachable mid-dig - dig timer now revalidates destination/frontier and retries or completes safely
- [x] Claimed dig marker abandoned when a new marker is placed - DIG jobs now remember active/last frontier tiles so claimed routes stay sticky
- [x] Stack overflow in idle job selection - removed recursive auto-job retry; worker now tries claim/gather/explore in a bounded sequence
- [x] World generated a free upward shaft from queen to surface - starting surface shaft is now config-gated and off by default
- [x] Low-food colonies did not seek buried food unless food priority was high/emergency - workers now route-dig toward known food when stores are below the configured food ratio

### Phase 3 Tasks
- [x] **Auto-explore**: idle workers with no jobs queue nearby tunnel-frontier DIG jobs and extend tunnel network organically
- [x] **Auto-gather**: workers automatically seek food sources without explicit player markers by queuing GATHER jobs during idle scoring
- [x] **Procedural food**: remove static food sources; replace with randomly placed food items generated at world-gen time
- [x] **World gen v2**: replace hand-coded layout with procedural generator (random rock formations, stone veins, cave pockets)
- [x] **Bigger world**: increase to 120Ã—80 tiles; verify camera/zoom still covers it or add scrolling
- [x] **No pre-dug food tunnels**: generated food stays buried; workers must dig their own route
- [x] **No default surface shaft**: start with a queen-side hall only unless config enables a shaft
- [ ] **Survival autopilot pass**: colony should find food, create useful tunnels, and avoid starvation with no player input
- [ ] **Food scouting memory**: replace omniscient known-food list with discovered food memory, stale target cleanup, and distance/amount scoring
- [ ] **Job budget controller**: cap auto-created jobs by category so dig/food/build/repair jobs do not fight each other
- [ ] **Useful exploration bias**: exploration should spread across promising frontiers instead of drifting one direction
- [ ] **Chunk-dirty tracking**: only re-score jobs near tiles that actually changed (performance prep for large worlds)
- [ ] **Worker sprite animation**: placeholder is static amber square â€” add basic 2-frame walk cycle using AssetLoader

---

## CURRENT â€” Phase 4: Main Menu & Settings

- [x] Main menu scene (`scenes/ui/main_menu.tscn`) — New Game, Settings, Quit
- [x] Settings panel — master volume, SFX volume, music volume, resolution, fullscreen toggle
- [x] Keybinds panel — rebindable actions stored in `data/settings/keybinds.json` (config exists; UI editing later)
- [x] SFX hooks: dig complete, food gathered, ant spawned, queen damaged
- [x] Background music: loop track stub during gameplay
- [x] Save/load settings to `user://settings.json`
- [x] Compact in-game HUD: collapse priority panel to dots, expand on hover
- [x] Visual feedback on marker placement (pulse + SFX)
- [x] `scripts/core/audio_manager.gd` autoload — plays/stops sounds; never load audio inline

---

## CURRENT â€” Phase 5: UI Visual Design Language

- [x] `scripts/ui/ui_theme.gd` â€” color constants + StyleBox factory; single source of truth for all UI colors
- [x] Apply shared theme helpers across current UI scripts
- [x] HUD: food count only (top-left), worker count (top-right) â€” nothing else visible by default
- [x] Priority panel: 8 color dots collapsed; button toggles expanded panel
- [x] Dig marker: replace solid `ColorRect` with thin 1px outlined square + 250ms pulse tween on placement
- [x] Main menu: `BG_DARK` background, `PANEL_SURFACE` card, flat buttons styled from `ui_theme.gd`
- [x] Enforce font sizes: 11px muted / 13px primary / 16px headers for compact UI surfaces
- [x] Audit all `.tscn` files: zero per-node color overrides in current UI scenes

---

## CURRENT â€” Phase 6: Rooms & Colony Growth

- [x] Room Plan Marker: right-click empty tunnel to place selected room blueprint; `B` cycles room type, `1`-`5` selects directly
- [x] BUILD job type added to job_queue
- [x] Worker BUILD state: path to site, deliver 1 food per build tick, progress visual updates
- [x] Room appears when build_cost paid
- [x] 6 room types with `data/rooms/*_config.json`: Queen Chamber, Nursery, Food Storage, Barracks, Mushroom Farm, Guard Post
- [x] Nursery timer â†’ hatch egg â†’ worker spawn request handled by main scene
- [x] Food Storage raises `colony_state.max_food`
- [x] `scripts/core/room_manager.gd` tracks placed/under-construction rooms
- [x] Mushroom Farm adds passive food over time
- [ ] Room selection UI panel instead of keyboard shortcuts
- [ ] Barracks soldier training waits for Phase 7 soldier ants

---

## CURRENT — Phase 7: Combat & Enemies

- [x] Spider enemy: spawns from world edges on timer, walks toward queen
- [x] Beetle enemy: slower, higher HP
- [x] Soldier ant FSM: IDLE_PATROL → ENGAGE → RETURN → MOVE_TO_RALLY → AT_RALLY
- [x] Soldier auto-engages enemies within detection radius based on `defense` priority
- [x] Rally Marker (middle-click on tunnel): soldiers path to it and hold position
- [x] HP bars on soldiers and enemies
- [x] Queen death → game over screen with Restart / Main Menu
- [x] `scripts/core/enemy_spawner.gd` + `data/enemies/*_config.json`
- [x] `data/ants/soldier_config.json` + `data/colony/enemy_spawn_config.json`
- [x] Soldier Barracks trains one soldier per `training_interval` when soldiers priority is non-low
- [ ] Worker flee behavior on enemy proximity (deferred)
- [ ] Raid Rally Marker (deferred to multiplayer phase — no enemy queen yet)

---

## NEXT — Phase 8: Full Marker Set & Upgrades

- [ ] Repair Marker — left-click damaged room/wall; worker repairs and removes marker
- [ ] Emergency Marker — shift+right-click; all idle ants re-score toward location
- [ ] Patrol Zone — drag on tunnel area; soldiers loop between endpoints
- [ ] Fortify — left-click tunnel entrance; soldier stands guard
- [ ] Upgrade panel in HUD; 5 upgrade types purchased with food
- [ ] All upgrade levels and costs in `data/upgrades/upgrades_config.json`

---

## MULTIPLAYER PREP (woven into all phases)

- [ ] All game-state mutations go through `GameManager` command functions (no direct node mutation from UI)
- [ ] Every command is serializable: `place_marker(type, pos)`, `set_priority(cat, level)`, `cancel_marker(id)`
- [ ] World state snapshotable to Dictionary for future RPC sync
- [ ] Tile changes go through a `WorldState` layer, not directly via `_tile_map.set_cell`
- [ ] No hardcoded player index â€” `colony_id` param on all colony-specific calls

---

## BLOCKED

Nothing blocked.

---

## NEEDS TESTING

- Dig destination: place marker deep in dirt â†’ ant digs autonomously, no pre-queued path tiles
- Multiple dig markers placed â†’ multiple ants each own one destination
- `_find_next_dig_tile` correctness when tunnel has branches
- Emergency priority: ant in MOVING state releases job and re-scores within one process tick
- Priority panel: +/- buttons cycle all 8 categories cleanly
- Food max: ants switch to digging when food = 200
- Auto-explore: with no unclaimed work, idle workers queue and dig nearby tunnel-frontier dirt without player markers
- Sticky dig markers: worker en route to marker A should not abandon it when marker B is placed
- Auto-gather: workers create GATHER jobs from food sources during idle scoring without main.gd pre-seeding jobs
- Seeded world generation: same `world_seed` should create identical terrain, cave pockets, stone veins, and food positions after restart
- Bigger map camera: 120Ã—80 world should be centered and zoomed out enough to fit the viewport
- Camera movement: WASD/arrow keys should pan around the 120Ã—80 map and stay clamped to world bounds
- Underground food: generated food sources should be embedded in dirt with reachable tunnel stand tiles, never placed in the sky
- No free surface shaft: default world generation should not carve a tunnel from queen to surface
- Survival autopilot: start with 0 food and normal priorities -> workers should dig toward buried food and begin gathering without player input
- Job conflict control: food route jobs should outrank random exploration while food is low, without causing queue spam or frame drops

---

## DONE

- Phase 0 setup files created (2026-05-07)
- Phase 0.5 asset pipeline and placeholder generator complete (2026-05-07)
- Design docs: CONTEXT.md, ROADMAP.md, AUTONOMY_DESIGN.md (2026-05-07)
- Project on GitHub: https://github.com/SnazzyTrack9218/ant-colony-wars (2026-05-07)
- Phase 1: game_manager, colony_state, job_queue, worker_ant, main, hud (2026-05-07)
- Fixed JobType enum circular reference crashing ant FSM (2026-05-07)
- Fixed window size and camera: fullscreen 1280Ã—720, zoom=1 (2026-05-07)
- Bumped starting workers to 5 (2026-05-07)
- Ants skip gather when food maxed; re-evaluate before re-adding food job (2026-05-07)
- Phase 2: priority system, full 5-term job score, emergency re-score, priority panel (2026-05-07)
- Dig redesign: single destination marker, ant self-navigates and digs autonomously (2026-05-07)
- Removed pre-path BFS from main.gd; adjacency check prevents remote mining (2026-05-07)
- Phase 3 started: idle workers now auto-queue nearby frontier DIG jobs when no work is available (2026-05-07)
- Fixed Phase 3 movement/dig bugs: tile-position tween alignment, sprite fit, and dig revalidation after timer (2026-05-07)
- Fixed claimed dig marker route abandonment when another marker is placed (2026-05-07)
- Phase 3 auto-gather started: workers now queue GATHER jobs from food sources during idle scoring (2026-05-07)
- Moved worker tuning for food amount, wander delay, sprite size, auto-gather, and auto-explore into `data/ants/worker_config.json` (2026-05-07)
- Fixed stack overflow from recursive worker idle auto-job retry (2026-05-07)
- Phase 3 world generation v2 started: deterministic seeded generator now creates 120Ã—80 terrain, stone veins, cave pockets, and food positions from `data/world/world_generation_config.json` (2026-05-07)
- Added WASD/arrow camera panning from `data/camera/camera_config.json`, and moved generated food into buried underground dirt pockets (2026-05-07)
- Phase 4 started: main menu, settings overlay, settings persistence, keybind config, and audio manager stub added (2026-05-07)
- Added WASD/arrow camera panning from `data/camera/camera_config.json`, and moved generated food into buried underground dirt pockets (2026-05-07)
- Removed generated tunnels to food and disabled the default surface shaft; workers now create food-route dig jobs when food is low or food priority is high/emergency (2026-05-07)
- Phase 4 completed: SFX event hooks, looping music stub, compact priority panel, and pulsing dig marker feedback (2026-05-07)
- Phase 5 completed: shared UI theme script applied to menus, HUD, priority panel, and dig markers (2026-05-07)
- Phase 6 completed: room configs, room manager, BUILD jobs, worker building, room visuals, storage/nursery/farm effects (2026-05-07)
- Phase 7 completed: soldier ant FSM with engage/return/rally, spider/beetle enemies, enemy spawner, HP bars, Soldier Barracks training, middle-click rally markers, queen-death game over screen (2026-05-07)
