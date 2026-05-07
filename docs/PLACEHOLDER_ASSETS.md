# Placeholder Asset System

The game must run even when zero real art files are present.
This is enforced by `scripts/assets/asset_loader.gd`.

---

## Why Placeholders Exist

- Development begins before art is ready
- Game mechanics can be tested immediately with colored shapes
- Missing files must never crash the game
- Real art is dropped in later without any code changes

---

## Placeholder Colors by Category

Each asset category renders a distinct color so you can tell them apart at a glance.

| Category | Color       | Hex approx | Appearance         |
|----------|-------------|------------|--------------------|
| Ants     | Amber       | `#CC8019`  | Orange-brown square |
| Rooms    | Blue        | `#4D99E6`  | Medium blue square  |
| Tiles    | Brown       | `#735933`  | Dark brown square   |
| Enemies  | Red         | `#E63333`  | Bright red square   |
| UI Icons | Light grey  | `#D9D9D9`  | Near-white square   |

All placeholders are 32×32 solid-color squares.
A category with no matching color entry renders as magenta — which makes it immediately obvious something is wrong.

---

## The Fallback Chain

When you call `AssetLoader.get_ant_sprite("worker")`, the loader does the following:

1. Looks up `"ants" → "worker"` in the manifest dictionary
2. Gets the path: `res://assets/sprites/ants/worker_ant.png`
3. Calls `ResourceLoader.exists(path)` — checks whether the file was imported
4. **If the file exists:** loads and returns the real `Texture2D`
5. **If the file is missing:** prints a warning and returns the amber placeholder

The warning message looks like this in the Godot Output panel:
```
AssetLoader: Missing file 'res://assets/sprites/ants/worker_ant.png' — placeholder used for ants/worker.
```

---

## What Triggers a Warning (Not a Crash)

| Situation                                   | Result                              |
|---------------------------------------------|-------------------------------------|
| `ASSET_MANIFEST.json` is missing            | Warning; all textures use placeholders |
| Category key not in manifest                | Warning; placeholder for that category |
| Asset name not in category                  | Warning; placeholder for that category |
| PNG file not in folder / not yet imported   | Warning; placeholder for that category |
| File exists but is not a valid Texture2D    | Warning; placeholder for that category |

The game continues running in every case above.

---

## How to Suppress a Warning

Drop the correctly named PNG into the correct folder and restart Godot (or press the reimport button in the FileSystem panel). The warning for that specific asset will not appear on the next run.

No code changes are needed. The manifest path and loader are unchanged.

---

## Placeholder System Is Not a Permanent Solution

By Phase 7, all placeholder art must be replaced with real sprites.
The acceptance criteria for Phase 7 explicitly require zero placeholder textures in the final build.
Use `AssetLoader.reload_manifest()` during development to hot-reload art without restarting Godot.
