"""
Pipeline coordinator.
Orchestrates one category's worth of sprite processing:
  open → remove background → crop → resize → export
"""

from dataclasses import dataclass
from pathlib import Path
from typing import List

from PIL import Image

from .config     import load_config, get_file_config, parse_bg_color, resolve_outputs
from .bg_remover import process_background
from .cropper    import crop_single, crop_grid, crop_auto
from .exporter   import export_sprite, check_manifest_coverage

MANIFEST_PATH = Path("data/ASSET_MANIFEST.json")


# ── summary ────────────────────────────────────────────────────────────────────

@dataclass
class ProcessSummary:
    processed: int = 0
    skipped:   int = 0
    exported:  int = 0
    warnings:  int = 0

    def merge(self, other: "ProcessSummary") -> None:
        self.processed += other.processed
        self.skipped   += other.skipped
        self.exported  += other.exported
        self.warnings  += other.warnings


# ── main entry point ───────────────────────────────────────────────────────────

def run_category(
    category:    str,
    inbox:       Path,
    output:      Path,
    config_path: Path,
    dry_run:     bool = False,
    force:       bool = False,
    verbose:     bool = False,
) -> ProcessSummary:
    summary     = ProcessSummary()
    full_config = load_config(config_path)
    # Use a dict keyed by lowercased name to deduplicate on case-insensitive filesystems
    seen: dict = {}
    for p in list(inbox.glob("*.png")) + list(inbox.glob("*.PNG")):
        seen[p.name.lower()] = p
    png_files = sorted(seen.values(), key=lambda p: p.name.lower())

    print(f"\n[{category}]  {len(png_files)} file(s) in {inbox}")

    for src in png_files:
        cfg     = get_file_config(full_config, category, src.name)
        outputs = resolve_outputs(cfg, src.stem, src.name)

        # Skip if all outputs already exist and --force not set
        all_exist = all((output / o).exists() for o in outputs)
        if not force and all_exist:
            summary.skipped += len(outputs)
            if verbose:
                print(f"  skip   {src.name}  (use --force to redo)")
            continue

        summary.processed += 1

        # ── open ──────────────────────────────────────────────────────────────
        try:
            img = Image.open(src)
        except Exception as e:
            print(f"  ERROR  {src.name}: cannot open — {e}")
            summary.warnings += 1
            continue

        # ── background removal ────────────────────────────────────────────────
        bg        = parse_bg_color(cfg.get("background", "auto"))
        tolerance = int(cfg.get("bg_tolerance", 30))
        trim      = bool(cfg.get("trim", True))
        img       = process_background(img, bg, tolerance=tolerance, trim=trim)

        # ── crop ──────────────────────────────────────────────────────────────
        mode    = cfg.get("mode", "single")
        sprites = _crop(img, mode, cfg)

        # ── export ────────────────────────────────────────────────────────────
        raw_size    = cfg.get("output_size")
        output_size = tuple(raw_size) if raw_size else None

        for i, sprite in enumerate(sprites):
            if i < len(outputs):
                out_name = outputs[i]
            else:
                out_name = f"{src.stem}_{i:02d}.png"
                print(f"  WARN   {src.name}: more sprites than 'outputs' defined → {out_name}")
                summary.warnings += 1

            out_path = output / out_name
            ok = export_sprite(sprite, out_path, output_size=output_size, dry_run=dry_run)

            if ok:
                summary.exported += 1
                if verbose or dry_run:
                    tag = "would write" if dry_run else "exported"
                    print(f"  {tag:<12} {src.name} -> {out_name}  ({sprite.size[0]}x{sprite.size[1]})")
            else:
                summary.warnings += 1

    # ── manifest gap check ────────────────────────────────────────────────────
    if not dry_run:
        missing = check_manifest_coverage(output, category, MANIFEST_PATH)
        if missing:
            print(f"  NOTE   still missing from manifest: {', '.join(missing)}")

    return summary


# ── internal ──────────────────────────────────────────────────────────────────

def _crop(img: Image.Image, mode: str, cfg: dict) -> List[Image.Image]:
    if mode == "grid":
        cols = int(cfg.get("columns", 1))
        rows = int(cfg.get("rows", 1))
        return crop_grid(img, cols, rows)
    if mode == "auto":
        return crop_auto(img)
    return crop_single(img)
