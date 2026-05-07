"""
Config loading for the asset pipeline.

Config file: assets_inbox/pipeline_config.json

Merge order (later keys win):
  DEFAULTS  <-  _defaults  <-  {category}._category_defaults  <-  {category}.{filename}
"""

import json
from pathlib import Path
from typing import Any, Dict, Optional, Tuple, Union

# ── defaults applied to every file unless overridden ──────────────────────────

DEFAULTS: Dict[str, Any] = {
    "mode":         "single",   # single | grid | auto
    "background":   "auto",     # "auto" | "#RRGGBB" | [R,G,B] | "none"
    "bg_tolerance": 30,         # 0-255 per channel sum tolerance
    "trim":         True,       # trim transparent edges after BG removal
    "output_size":  None,       # [w, h] to resize output, or null
}


# ── loaders ────────────────────────────────────────────────────────────────────

def load_config(config_path: Path) -> Dict:
    """Load pipeline_config.json. Returns empty dict if file is missing or invalid."""
    if not config_path.exists():
        return {}
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        print(f"WARNING: Could not parse {config_path}: {e}")
        return {}


def get_file_config(full_config: Dict, category: str, filename: str) -> Dict:
    """Return the merged config for a specific file in a specific category."""
    cfg = dict(DEFAULTS)
    cfg.update({k: v for k, v in full_config.get("_defaults", {}).items()
                if not k.startswith("_")})

    cat = full_config.get(category, {})
    cfg.update({k: v for k, v in cat.get("_category_defaults", {}).items()
                if not k.startswith("_")})

    file_cfg = cat.get(filename, {})
    cfg.update({k: v for k, v in file_cfg.items() if not k.startswith("_")})

    return cfg


# ── helpers ────────────────────────────────────────────────────────────────────

BgValue = Union[str, Tuple[int, int, int], None]


def parse_bg_color(value: Any) -> BgValue:
    """
    Normalise a background config value.
    Returns:
      "auto"        — auto-detect from image corners
      (R, G, B)     — remove this specific color
      None          — skip background removal
    """
    if value is None or value == "none":
        return None
    if value == "auto":
        return "auto"
    if isinstance(value, str) and value.startswith("#"):
        h = value.lstrip("#")
        if len(h) == 6:
            return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))
    if isinstance(value, (list, tuple)) and len(value) >= 3:
        return (int(value[0]), int(value[1]), int(value[2]))
    print(f"WARNING: unrecognised background value '{value}', defaulting to auto")
    return "auto"


def resolve_outputs(cfg: Dict, source_stem: str, source_name: str) -> list:
    """
    Determine the list of output filenames for a source file.
    - grid mode  → uses 'outputs' list, or auto-generates {stem}_00.png etc.
    - single/auto → uses 'output' key, or keeps original filename.
    """
    mode = cfg.get("mode", "single")
    if mode == "grid":
        cols = cfg.get("columns", 1)
        rows = cfg.get("rows", 1)
        count = cols * rows
        default_names = [f"{source_stem}_{i:02d}.png" for i in range(count)]
        return cfg.get("outputs", default_names)
    return [cfg.get("output", source_name)]
