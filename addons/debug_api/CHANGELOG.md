# Changelog

All notable changes to **Debug API for Godot** are documented in this file.
Versions follow [Semantic Versioning](https://semver.org/).

## [1.0.0] — 2026-05-06

First production-ready release. The API is now stable; future minor versions
will only add features without breaking existing code.

### Added

#### Built-in monitor system
- `DebugMonitors.gd` — registry of ~50 ready-to-use metrics organised in 12
  categories (`performance`, `memory`, `objects`, `rendering`, `physics`,
  `audio`, `display`, `system`, `time`, `input`, `scene`, `network`).
- 8 named presets: `minimal`, `essential`, `performance`, `memory`,
  `rendering`, `system`, `display`, `full`.
- Sliding FPS-history sampler feeding `fps_avg` / `fps_min` / `fps_max`.
- `DebugAPI.enable_monitor`, `enable_monitors`, `enable_monitor_category`,
  `enable_monitor_preset`, `enable_all_monitors` and their `disable_*`
  counterparts. `register_custom_monitor` for runtime extension.

#### Installation modes
- Editor plugin (`plugin.cfg` + `plugin.gd`) that auto-registers the
  `DebugAPI` autoload.
- Manual autoload, drop-in `DebugBootstrap` node, or pure-instance via
  `preload(...)` — four parallel modes that all work in production.
- Auto-load of `res://debug_settings.tres` /
  `res://addons/debug_api/debug_settings.tres` / `user://debug_settings.tres`
  on `_ready`. Drop a settings resource and ship — no code required.

#### Inspector-driven configuration
- `DebugSettings.gd` resource with grouped `@export`s covering monitors,
  layout, hotkeys, themes, style, export and behaviour.
- `DebugBootstrap.gd` — drag-and-drop Node that reads a `DebugSettings`
  resource (or a `quick_preset` enum) and bootstraps the API for projects
  that don't want autoloads.

#### Themes & layout
- `DebugThemes.gd` — built-in themes: `Default`, `Dark`, `Light`, `Neon`,
  `Retro`, `Minimal`, `Solarized`. Apply at runtime with
  `DebugAPI.apply_theme(name)`.
- 8 anchor presets on `DebugPanel`: `ANCHOR_TOP_LEFT`, `ANCHOR_TOP_RIGHT`,
  `ANCHOR_BOTTOM_LEFT`, `ANCHOR_BOTTOM_RIGHT`, `ANCHOR_TOP_CENTER`,
  `ANCHOR_BOTTOM_CENTER`, `ANCHOR_CENTER`, `ANCHOR_FREE`. Re-anchors on
  viewport resize and content reflow.
- Optional title bar, collapsible sections, scrollable panel
  (`max_height`), inner padding, corner radius, custom font support
  (FontFile / SystemFont).

#### Hotkeys & input
- Per-panel `toggle_key` + `toggle_action` (InputMap action takes priority).
- Global `global_toggle_key` / `global_toggle_action` /
  `export_hotkey` / `export_action` on `DebugAPI`.
- `KEY_NONE` disables a hotkey explicitly.

#### Export & persistence
- `export_debug_data(path, format)` with TXT / JSON / CSV. Auto-detection
  by file extension.
- Auto-export on interval: `auto_export_path`, `auto_export_format`,
  `auto_export_interval`.
- `DebugAPI.save_settings(settings, path)` /
  `DebugAPI.load_settings(path)` (static helpers around
  `ResourceSaver`/`ResourceLoader`).
- `DebugAPI.snapshot_settings()` — build a `DebugSettings` reflecting the
  current API state for round-trip persistence.

#### Performance optimisations
- **Smart-diff** in every text-style widget: skips `Label.text` writes
  when the value is unchanged.
- **Per-widget `update_interval`**: built-in monitors are tagged
  appropriately (60 s for static GPU/system info, 0.5–5 s for display
  metadata, per-frame for live counters). Configurable at runtime via
  `DebugAPI.set_monitor_update_interval(id, seconds)`.
- **Hidden widgets skipped** in `update_display` (collapsed sections,
  hidden panels).
- **Stale getter detection**: invalid Callables dim the widget row and
  recover when the source returns. Manual cleanup via `prune_stale_widgets`.
- **Pause** — `DebugAPI.paused = true` halts `_process` on the API and
  every panel; cheap on/off switch.

#### Compatibility
- Verified Godot 4.0+ APIs only (no 4.4+-only features).
- Headless-safe: `DisplayServer` returns zeros without crashing; display
  monitors degrade gracefully.
- Forward+ / Mobile / Compatibility renderers all supported.
- Thread-safety documented: API is main-thread only.

#### Examples
- `DebugExample.gd` — custom panel + auto-monitors coexisting.
- `AutoMonitorsExample.gd` — minimal auto-monitor demo.
- `BootstrapExample.gd` — no-autoload setup.
- `AdvancedConfigExample.gd` — full-config showcase (themes, hotkeys,
  JSON export, scrollable panel, collapsible sections, custom monitor).

### Changed
- File layout moved to `res://addons/debug_api/`.
- Public widget API on `DebugPanel` is unchanged in signature, but every
  widget now lives in `DebugWidgets.gd` with smart-diff + stale handling.
- `DebugPanel.add_monitor(monitor)` dispatcher reads `update_interval`
  from monitor metadata and applies it to the widget automatically.
- `_default_config` enriched with new keys: `anchor`, `edge_margin`,
  `panel_padding`, `border_width`, `corner_radius`, `click_through`,
  `show_title`, `title_text`, `collapsible_sections`, `max_height`,
  `font` and the full theme colour set.

### Removed (breaking)
- **`class_name DebugAPI`** — Godot 4.4+ rejects an autoload that shares
  its name with a global script class. The autoload owns the name now;
  use `preload("res://addons/debug_api/DebugAPI.gd")` for non-autoload
  contexts.
- **`DebugPanel.vis: bool`** — was a confusing alias of `Control.visible`.
  Use `panel.visible = ...` directly.

### Migration notes (pre-1.0 → 1.0)

```gdscript
# Old (pre-1.0)
var api = DebugAPI.new()
add_child(api)
api.create_panel(...)

# New (v1.0, autoload)
DebugAPI.create_panel(...)

# New (v1.0, pure instance)
const DebugAPIScript = preload("res://addons/debug_api/DebugAPI.gd")
var api := DebugAPIScript.new()
add_child(api)
api.create_panel(...)
```

```gdscript
# Old
panel.vis = false

# New
panel.visible = false
```

The widget creation API (`add_text_widget`, `add_progress_widget`, …) is
unchanged — existing custom panels keep working as-is.
