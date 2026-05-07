"""
Output writing and manifest coverage checking for the asset pipeline.
"""

import json
from pathlib import Path
from typing import List, Optional, Tuple

from PIL import Image


def export_sprite(
    img: Image.Image,
    output_path: Path,
    output_size: Optional[Tuple[int, int]] = None,
    dry_run: bool = False,
) -> bool:
    """
    Save a sprite as PNG.  Returns True on success.
    If output_size is given, resizes using nearest-neighbour (pixel art friendly).
    Does nothing when dry_run is True.
    """
    if output_size:
        img = img.resize(output_size, Image.NEAREST)

    if dry_run:
        return True

    try:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        img.save(str(output_path), "PNG")
        return True
    except Exception as e:
        print(f"  ERROR: could not write {output_path}: {e}")
        return False


def check_manifest_coverage(
    output_dir: Path,
    category: str,
    manifest_path: Path,
) -> List[str]:
    """
    Return the list of filenames that ASSET_MANIFEST.json expects for `category`
    but that are not present in `output_dir`.
    """
    if not manifest_path.exists():
        return []

    try:
        with open(manifest_path, "r", encoding="utf-8") as f:
            manifest = json.load(f)
    except Exception:
        return []

    missing = []
    for _name, path_str in manifest.get(category, {}).items():
        filename = Path(path_str).name
        if not (output_dir / filename).exists():
            missing.append(filename)
    return missing
