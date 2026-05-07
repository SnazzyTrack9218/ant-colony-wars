# TODO — Ant Colony Wars

Update this file every time a task is completed, started, or discovered.
Always read this file before starting any work session.

---

## NOW — Phase 3: Ant Autonomy & World Quality

Read `docs/AUTONOMY_DESIGN.md` before writing any ant or job code.

### Immediate Bugs to Fix
- [ ] Ants still visually clip or appear to pass through walls — investigate tween position vs tile boundary alignment
- [ ] Worker stuck in WORKING state when dest becomes unreachable mid-dig (another ant digs wrong direction) — add timeout/retry

### Phase 3 Tasks
- [ ] **Auto-explore**: idle workers with no jobs wander to unexplored areas and extend tunnel network organically
- [ ] **Auto-gather**: workers automatically seek nearby food sources without explicit markers (food sources discovered during exploration)
- [ ] **Procedural food**: remove static food sources; replace with randomly placed food items generated at world-gen time
- [ ] **World gen v2**: replace hand-coded layout with procedural generator (random rock formations, stone veins, cave pockets)
- [ ] **Bigger world**: increase to 120×80 tiles; verify camera/zoom still covers it or add scrolling
- [ ] **Chunk-dirty tracking**: only re-score jobs near tiles that actually changed (performance prep for large worlds)
- [ ] **Worker sprite animation**: placeholder is static amber square — add basic 2-frame walk cycle using AssetLoader

---

## NEXT — Phase 4: Main Menu & Settings

- [ ] Main menu scene (`scenes/ui/main_menu.tscn`) — New Game, Settings, Quit
- [ ] Settings panel — master volume, SFX volume, music volume, resolution, fullscreen toggle
- [ ] Keybinds panel — rebindable actions stored in `data/settings/keybinds.json`
- [ ] SFX hooks: dig complete, food gathered, ant spawned, queen damaged
- [ ] Background music: loop track, crossfade between peace/alert states
- [ ] Save/load settings to `user://settings.json`
- [ ] Compact in-game HUD: collapse priority panel to icons, show on hover/toggle
- [ ] Visual feedback on marker placement (flash, sound, particle)
- [ ] `scripts/core/audio_manager.gd` autoload — plays/stops sounds; never load audio inline

---

## NEXT — Phase 5: Rooms & Colony Growth

- [ ] Room Plan Marker: player opens menu, selects type, places blueprint in empty tunnel
- [ ] BUILD job type added to job_queue
- [ ] Worker BUILD state: path to site, deliver 1 food per trip, progress bar
- [ ] Room appears when build_cost paid
- [ ] 6 room types with `data/rooms/*_config.json`: Queen Chamber, Nursery, Food Storage, Barracks, Mushroom Farm, Guard Post
- [ ] Nursery timer → hatch egg → `GameManager.spawn_worker()`
- [ ] Food Storage raises `colony_state.max_food`
- [ ] `scripts/core/room_manager.gd` tracks placed/under-construction rooms

---

## NEXT — Phase 6: Combat & Enemies

- [ ] Spider enemy: spawns from world edges on timer, walks toward queen
- [ ] Beetle enemy: slower, higher HP
- [ ] Soldier ant FSM: IDLE_PATROL → ENGAGE → RETURN
- [ ] Soldier auto-engages enemies within detection radius based on `defense` priority
- [ ] Rally Marker (right-click): soldiers path to it and hold position
- [ ] HP bars on ants and enemies
- [ ] Queen death → game over screen
- [ ] `scripts/core/enemy_spawner.gd` + `data/enemies/*_config.json`

---

## MULTIPLAYER PREP (woven into all phases)

- [ ] All game-state mutations go through `GameManager` command functions (no direct node mutation from UI)
- [ ] Every command is serializable: `place_marker(type, pos)`, `set_priority(cat, level)`, `cancel_marker(id)`
- [ ] World state snapshotable to Dictionary for future RPC sync
- [ ] Tile changes go through a `WorldState` layer, not directly via `_tile_map.set_cell`
- [ ] No hardcoded player index — `colony_id` param on all colony-specific calls

---

## BLOCKED

Nothing blocked.

---

## NEEDS TESTING

- Dig destination: place marker deep in dirt → ant digs autonomously, no pre-queued path tiles
- Multiple dig markers placed → multiple ants each own one destination
- `_find_next_dig_tile` correctness when tunnel has branches
- Emergency priority: ant in MOVING state releases job and re-scores within one process tick
- Priority panel: +/- buttons cycle all 8 categories cleanly
- Food max: ants switch to digging when food = 200

---

## DONE

- Phase 0 setup files created (2026-05-07)
- Phase 0.5 asset pipeline and placeholder generator complete (2026-05-07)
- Design docs: CONTEXT.md, ROADMAP.md, AUTONOMY_DESIGN.md (2026-05-07)
- Project on GitHub: https://github.com/SnazzyTrack9218/ant-colony-wars (2026-05-07)
- Phase 1: game_manager, colony_state, job_queue, worker_ant, main, hud (2026-05-07)
- Fixed JobType enum circular reference crashing ant FSM (2026-05-07)
- Fixed window size and camera: fullscreen 1280×720, zoom=1 (2026-05-07)
- Bumped starting workers to 5 (2026-05-07)
- Ants skip gather when food maxed; re-evaluate before re-adding food job (2026-05-07)
- Phase 2: priority system, full 5-term job score, emergency re-score, priority panel (2026-05-07)
- Dig redesign: single destination marker, ant self-navigates and digs autonomously (2026-05-07)
- Removed pre-path BFS from main.gd; adjacency check prevents remote mining (2026-05-07)
