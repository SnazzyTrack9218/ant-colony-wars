"""
Background removal for the asset pipeline.

Strategies:
  auto   — samples the 4 corners to guess the background color, then removes it
  color  — removes a specific (R, G, B) color within a tolerance
  none   — skips removal (image is already transparent or needs no change)
"""

from PIL import Image
import numpy as np
from typing import Optional, Tuple


RgbColor = Tuple[int, int, int]


def detect_bg_color(img: Image.Image) -> RgbColor:
    """
    Sample small patches from all 4 corners and return the most common color.
    Works well for sprite sheets with a uniform background.
    """
    rgb = img.convert("RGB")
    arr = np.array(rgb)
    h, w = arr.shape[:2]

    # Sample up to 4×4 pixels in each corner
    s = max(1, min(4, w // 8, h // 8))
    corners = [
        arr[:s,    :s   ],
        arr[:s,    w-s: ],
        arr[h-s:,  :s   ],
        arr[h-s:,  w-s: ],
    ]
    pixels = np.concatenate([c.reshape(-1, 3) for c in corners], axis=0)
    colors, counts = np.unique(pixels, axis=0, return_counts=True)
    return tuple(int(v) for v in colors[np.argmax(counts)])


def remove_color(
    img: Image.Image,
    color: RgbColor,
    tolerance: int = 30,
) -> Image.Image:
    """
    Set pixels that match `color` (within `tolerance` per-channel sum) to transparent.
    Returns an RGBA image.
    """
    rgba = img.convert("RGBA")
    arr  = np.array(rgba, dtype=np.int32)
    r, g, b = color

    dist = (
        np.abs(arr[:, :, 0] - r) +
        np.abs(arr[:, :, 1] - g) +
        np.abs(arr[:, :, 2] - b)
    )
    mask = dist <= (tolerance * 3)
    arr[mask, 3] = 0
    return Image.fromarray(arr.astype(np.uint8))


def trim_transparent(img: Image.Image) -> Image.Image:
    """Crop to the bounding box of all non-transparent pixels."""
    if img.mode != "RGBA":
        return img
    bbox = img.getbbox()
    return img.crop(bbox) if bbox else img


def process_background(
    img: Image.Image,
    bg,           # "auto" | (R,G,B) | None
    tolerance: int = 30,
    trim: bool = True,
) -> Image.Image:
    """
    Full BG pipeline: detect or use provided color, remove it, then trim.
    """
    if bg is None:
        result = img.convert("RGBA")
    elif bg == "auto":
        color  = detect_bg_color(img)
        result = remove_color(img, color, tolerance)
    else:
        result = remove_color(img, bg, tolerance)

    if trim:
        result = trim_transparent(result)
    return result
