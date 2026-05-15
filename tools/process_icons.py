#!/usr/bin/env python3
"""Post-process Flux-generated icons for in-app delivery.

Pipeline per icon:
    source.png  →  rembg (transparent bg)  →  Pillow resize → cwebp encode

Output layout:
    assets/icons_generated/
        <key>.png             # 768² source w/ navy bg (from generate_icons.py)
        nobg/<key>.png        # 768² source w/ transparent bg (for review)
        webp/192/<key>.webp   # production thumbnail for power-ups
        webp/256/<key>.webp   # production thumbnail for crate faces
        webp/768/<key>.webp   # production size for hero illustrations

Usage:
    python3 process_icons.py              # process every *.png at root
    python3 process_icons.py dynamite_crate priority_crate
    python3 process_icons.py --keep-bg truck_illustration

The --keep-bg flag preserves the original navy background — useful for
illustrations meant to sit on a deep surface (like the completion overlay
receipt frame) rather than float over arbitrary UI.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Iterable

from PIL import Image
from rembg import remove, new_session

REPO_ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = REPO_ROOT / "assets" / "icons_generated"
NOBG_DIR = SOURCE_DIR / "nobg"
WEBP_DIR = SOURCE_DIR / "webp"
WEBP_SIZES = (192, 256, 768)  # the three delivery tiers

# rembg model — 'isnet-general-use' is the current state of the art for
# general subjects (better than the default 'u2net' on illustrative art).
REMBG_MODEL = "isnet-general-use"

# Per-key overrides — if a key is in this set, we skip rembg and keep
# the original Flux background. Use for hero illustrations that need
# the navy backdrop intact.
KEEP_BG_KEYS = {
    # (none yet — add e.g. 'completion_truck' if we ship a full-scene
    #  illustration that needs its painted backdrop)
}


def strip_background(src_path: Path, dst_path: Path, session) -> None:
    """Run rembg on `src_path`, write transparent PNG to `dst_path`."""
    with src_path.open("rb") as f:
        input_bytes = f.read()
    output_bytes = remove(input_bytes, session=session)
    dst_path.parent.mkdir(parents=True, exist_ok=True)
    dst_path.write_bytes(output_bytes)


def to_webp(src_path: Path, dst_path: Path, size: int, quality: int = 85) -> None:
    """Resize `src_path` PNG to fit within `size×size` (preserving aspect
    ratio for landscape/portrait sources like district backgrounds + the
    Play Store banner), encode as WebP at `dst_path`. Square sources
    end up exactly `size×size`; non-square sources downscale by the
    longer edge so the other edge is < size.
    """
    img = Image.open(src_path)
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    # LANCZOS is the high-quality downscaler. Bilinear/bicubic produce
    # blurrier edges on hard-line icon art.
    scale = size / max(img.width, img.height)
    if scale < 1.0:
        new_size = (int(img.width * scale), int(img.height * scale))
        resized = img.resize(new_size, Image.LANCZOS)
    else:
        # Source is already <= target — copy at native dimensions.
        resized = img
    dst_path.parent.mkdir(parents=True, exist_ok=True)
    resized.save(dst_path, "WEBP", quality=quality, method=6)


def process_one(key: str, keep_bg: bool, session) -> dict:
    """Process a single icon. Returns timing report."""
    src_path = SOURCE_DIR / f"{key}.png"
    if not src_path.exists():
        print(f"  ✗ MISSING: {src_path}")
        return {"key": key, "ok": False}

    t0 = time.time()
    timings = {"key": key, "ok": True}

    # Step 1: background removal (unless overridden)
    if keep_bg or key in KEEP_BG_KEYS:
        # Copy source as-is into nobg/ folder (consistent path for webp step)
        nobg_path = NOBG_DIR / f"{key}.png"
        nobg_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src_path, nobg_path)
        timings["bg"] = "kept"
    else:
        t_bg = time.time()
        nobg_path = NOBG_DIR / f"{key}.png"
        strip_background(src_path, nobg_path, session)
        timings["bg"] = f"{time.time() - t_bg:.2f}s"

    # Step 2: multi-size WebP delivery
    t_webp = time.time()
    for size in WEBP_SIZES:
        webp_path = WEBP_DIR / str(size) / f"{key}.webp"
        to_webp(nobg_path, webp_path, size)
    timings["webp"] = f"{time.time() - t_webp:.2f}s"

    timings["total"] = f"{time.time() - t0:.2f}s"
    print(
        f"  ✓ {key:25} bg={timings['bg']:>7}  "
        f"webp(3 sizes)={timings['webp']:>6}  total={timings['total']}",
        flush=True,
    )
    return timings


def discover_keys() -> list[str]:
    """Return every *.png stem at SOURCE_DIR root (skip subdirs)."""
    return sorted(
        p.stem for p in SOURCE_DIR.glob("*.png") if p.is_file()
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("keys", nargs="*", help="Icon keys to process (omit for all)")
    parser.add_argument(
        "--keep-bg",
        action="store_true",
        help="Skip rembg — preserve original Flux background",
    )
    args = parser.parse_args(argv)

    keys = args.keys if args.keys else discover_keys()
    if not keys:
        print(f"No PNGs found at {SOURCE_DIR}/*.png")
        return 1

    print(f"Processing {len(keys)} icon(s) → nobg/, webp/{{192,256,768}}/")
    print(f"Source dir: {SOURCE_DIR}")
    print(f"rembg model: {REMBG_MODEL}")
    print(f"WebP sizes: {WEBP_SIZES}")
    print()

    # Initialize rembg session once (loads ONNX model — ~200 MB)
    print("Initializing rembg session...", flush=True)
    t0 = time.time()
    session = new_session(REMBG_MODEL)
    print(f"  rembg ready in {time.time() - t0:.1f}s\n", flush=True)

    t_start = time.time()
    results = []
    for key in keys:
        results.append(process_one(key, args.keep_bg, session))

    ok = sum(1 for r in results if r["ok"])
    print(f"\nDone: {ok}/{len(results)} in {time.time() - t_start:.1f}s")
    print(f"\nWebP delivery folder: {WEBP_DIR}")
    print("Wire from pubspec.yaml as e.g. 'assets/icons_generated/webp/192/'")
    return 0 if ok == len(results) else 2


if __name__ == "__main__":
    sys.exit(main())
