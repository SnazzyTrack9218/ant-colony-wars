"""
Sprite cropping for the asset pipeline.

Modes:
  single — image is one sprite; return as-is (trimming handled by bg_remover)
  grid   — uniform N×M grid; crop each cell, skip blank cells
  auto   — detect sprites by finding non-transparent regions separated by gaps
"""

from PIL import Image
import numpy as np
from typing import List, Tuple


def crop_single(img: Image.Image) -> List[Image.Image]:
    """Return the image as a one-element list."""
    return [img]


def crop_grid(img: Image.Image, columns: int, rows: int) -> List[Image.Image]:
    """
    Divide the image into a columns×rows grid.
    Returns sprites in row-major order (left→right, top→bottom).
    Blank (fully transparent) cells are skipped.
    """
    if columns < 1 or rows < 1:
        print(f"  WARN  crop_grid: invalid grid {columns}×{rows}, treating as single")
        return crop_single(img)

    w, h  = img.size
    sw, sh = w // columns, h // rows
    sprites = []

    for row in range(rows):
        for col in range(columns):
            box    = (col * sw, row * sh, (col + 1) * sw, (row + 1) * sh)
            sprite = img.crop(box)
            if not _is_blank(sprite):
                sprites.append(sprite)

    return sprites if sprites else [img]


def crop_auto(img: Image.Image) -> List[Image.Image]:
    """
    Detect individual sprites by locating non-transparent regions separated
    by fully-transparent row or column gaps.

    Works best after the background has already been removed.
    Falls back to single-sprite if no clear separators are found.
    """
    if img.mode != "RGBA":
        img = img.convert("RGBA")

    alpha = np.array(img)[:, :, 3]
    row_filled = np.any(alpha > 0, axis=1)   # True for rows with any content
    col_filled = np.any(alpha > 0, axis=0)   # True for cols with any content

    row_groups = _find_groups(row_filled)
    col_groups = _find_groups(col_filled)

    # Only one contiguous block → single sprite
    if len(row_groups) == 1 and len(col_groups) == 1:
        return [img]

    sprites = []
    for r0, r1 in row_groups:
        for c0, c1 in col_groups:
            sprite = img.crop((c0, r0, c1 + 1, r1 + 1))
            if not _is_blank(sprite):
                sprites.append(sprite)

    return sprites if sprites else [img]


# ── helpers ────────────────────────────────────────────────────────────────────

def _find_groups(mask: np.ndarray) -> List[Tuple[int, int]]:
    """Return (start, end) index pairs for each contiguous True run in mask."""
    groups: List[Tuple[int, int]] = []
    in_group = False
    start = 0
    for i, val in enumerate(mask):
        if val and not in_group:
            in_group = True
            start = i
        elif not val and in_group:
            in_group = False
            groups.append((start, i - 1))
    if in_group:
        groups.append((start, len(mask) - 1))
    return groups


def _is_blank(img: Image.Image) -> bool:
    """Return True if the image has no visible (alpha > 0) pixels."""
    if img.mode != "RGBA":
        return False
    return not np.any(np.array(img)[:, :, 3] > 0)
