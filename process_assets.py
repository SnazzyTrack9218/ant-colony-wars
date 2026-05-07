#!/usr/bin/env python3
"""
Ant Colony Wars — Asset Pipeline
=================================
Crops sprite sheets, removes backgrounds, renames, and exports sprites.

Input  : assets_inbox/{category}/*.png
Output : assets/sprites/{category}/*.png

Usage:
  python process_assets.py                     # process all categories
  python process_assets.py --category ants     # process one category
  python process_assets.py --dry-run           # preview without writing files
  python process_assets.py --force             # re-process existing outputs
  python process_assets.py --verbose           # print per-sprite detail
  python process_assets.py --check             # report manifest gaps only

Setup (one time):
  pip install -r requirements.txt
"""

import argparse
import sys
from pathlib import Path

# ── paths ──────────────────────────────────────────────────────────────────────

INBOX_ROOT  = Path("assets_inbox")
OUTPUT_ROOT = Path("assets/sprites")
CONFIG_PATH = Path("assets_inbox/pipeline_config.json")
CATEGORIES  = ["ants", "enemies", "rooms", "tiles", "ui"]


# ── CLI ────────────────────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Ant Colony Wars asset pipeline.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument(
        "--category",
        choices=CATEGORIES + ["all"],
        default="all",
        help="Category to process (default: all)",
    )
    p.add_argument("--dry-run",  action="store_true", help="Preview without writing files")
    p.add_argument("--force",    action="store_true", help="Re-process even if output exists")
    p.add_argument("--verbose",  action="store_true", help="Print per-sprite detail")
    p.add_argument("--check",    action="store_true", help="Only report manifest coverage gaps")
    return p.parse_args()


# ── entry point ────────────────────────────────────────────────────────────────

def main() -> None:
    _check_dependencies()
    args = parse_args()

    # Late import so dependency check runs first
    from tools.pipeline.processor import run_category, ProcessSummary
    from tools.pipeline.exporter  import check_manifest_coverage

    if not INBOX_ROOT.exists():
        print(f"ERROR: inbox folder not found: {INBOX_ROOT}")
        print("  Create assets_inbox/ and drop sprite sheets inside category sub-folders.")
        sys.exit(1)

    categories = CATEGORIES if args.category == "all" else [args.category]
    total = ProcessSummary()

    for cat in categories:
        inbox  = INBOX_ROOT  / cat
        output = OUTPUT_ROOT / cat

        if args.check:
            missing = check_manifest_coverage(output, cat, Path("data/ASSET_MANIFEST.json"))
            if missing:
                print(f"[{cat}] missing from manifest: {', '.join(missing)}")
            else:
                print(f"[{cat}] manifest coverage OK")
            continue

        if not inbox.exists():
            print(f"[{cat}] skipped — {inbox} not found")
            continue

        files = list(inbox.glob("*.png")) + list(inbox.glob("*.PNG"))
        if not files:
            print(f"[{cat}] no PNG files in {inbox}")
            continue

        summary = run_category(
            category    = cat,
            inbox       = inbox,
            output      = output,
            config_path = CONFIG_PATH,
            dry_run     = args.dry_run,
            force       = args.force,
            verbose     = args.verbose,
        )
        total.merge(summary)

    if not args.check:
        _print_summary(total, dry_run=args.dry_run)


def _print_summary(total, dry_run: bool) -> None:
    print()
    print("-- Summary " + "-" * 33)
    print(f"  Processed : {total.processed}")
    print(f"  Skipped   : {total.skipped}  (use --force to re-process)")
    print(f"  Exported  : {total.exported}")
    print(f"  Warnings  : {total.warnings}")
    if dry_run:
        print("  (dry-run -- no files written)")
    print("-" * 44)


def _check_dependencies() -> None:
    missing = []
    try:
        import PIL  # noqa: F401
    except ImportError:
        missing.append("Pillow")
    try:
        import numpy  # noqa: F401
    except ImportError:
        missing.append("numpy")
    if missing:
        print("ERROR: missing Python packages:", ", ".join(missing))
        print("  Run:  pip install -r requirements.txt")
        sys.exit(1)


if __name__ == "__main__":
    main()
