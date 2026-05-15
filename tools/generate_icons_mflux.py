#!/usr/bin/env python3
"""MLX-native FLUX.1-schnell icon generator for Warehouse Sort.

Faster, memory-safer Mac-native sibling of `generate_icons.py`.
Calls the `mflux-generate` CLI (Apple Silicon MLX backend) instead of
PyTorch+MPS. Same PROMPTS dict / style language as the diffusers version.

Why this exists:
- mflux runs ~3-5x faster than diffusers+MPS on M-series chips because
  MLX is Apple's native ML framework (vs PyTorch's MPS shim).
- 4-bit quantization (`-q 4`) drops memory footprint from ~22 GB to ~8 GB,
  so the Mac stays responsive without needing CPU offload.
- The mflux CLI is a thin wrapper: every generation is a fresh process,
  so there's no daemon memory leak across batches.

Usage:
    python3 generate_icons_mflux.py [subject_key]
    python3 generate_icons_mflux.py fragile_crate oversized_crate

The mflux binary is at /opt/homebrew/bin/mflux-generate.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

# Reuse the same prompt catalog + style language as the diffusers version,
# so generations from either backend share one visual vocabulary.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_icons import PROMPTS, build_prompt  # noqa: E402

MFLUX_BIN = "/opt/homebrew/bin/mflux-generate"
REPO_ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = REPO_ROOT / "assets" / "icons_generated"


def generate_one(
    key: str,
    subject: str,
    width: int = 768,
    height: int = 768,
    steps: int = 4,
    quantize: int = 4,
    seed: int = 42,
) -> Path:
    prompt = build_prompt(subject)
    out_path = OUT_DIR / f"{key}.png"
    print(f"\n[mflux] {key} → {out_path}", flush=True)
    print(f"  prompt: {prompt[:90]}...", flush=True)

    cmd = [
        MFLUX_BIN,
        "--model", "schnell",   # built-in model alias (not --base-model)
        "--quantize", str(quantize),
        "--prompt", prompt,
        "--steps", str(steps),
        "--guidance", "0",  # Schnell expects guidance=0
        "--width", str(width),
        "--height", str(height),
        "--seed", str(seed),
        "--output", str(out_path),
    ]
    t0 = time.time()
    result = subprocess.run(cmd, capture_output=True, text=True)
    elapsed = time.time() - t0
    if result.returncode != 0:
        print(f"  ✗ failed in {elapsed:.1f}s")
        print(f"  stderr: {result.stderr[:500]}")
        return None
    print(f"  ✓ done in {elapsed:.1f}s", flush=True)
    return out_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "subject_keys",
        nargs="*",
        help="One or more PROMPTS keys. Omit to do all.",
    )
    parser.add_argument("--width", type=int, default=768)
    parser.add_argument("--height", type=int, default=768)
    parser.add_argument("--steps", type=int, default=4)
    parser.add_argument(
        "--quantize",
        type=int,
        default=4,
        choices=[3, 4, 5, 6, 8],
        help="4-bit is the safe default on 48GB; 6-bit slightly better quality",
    )
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    if args.subject_keys:
        bad = [k for k in args.subject_keys if k not in PROMPTS]
        if bad:
            print(f"ERROR: unknown subject_key(s): {bad}")
            print(f"Available: {', '.join(PROMPTS.keys())}")
            return 1
        keys = args.subject_keys
    else:
        keys = list(PROMPTS.keys())

    t_start = time.time()
    failed = []
    for key in keys:
        result = generate_one(
            key,
            PROMPTS[key],
            width=args.width,
            height=args.height,
            steps=args.steps,
            quantize=args.quantize,
            seed=args.seed,
        )
        if result is None:
            failed.append(key)

    total = time.time() - t_start
    print(
        f"\nGenerated {len(keys) - len(failed)}/{len(keys)} icons "
        f"in {total:.1f}s (avg {total / max(1, len(keys)):.1f}s each)"
    )
    if failed:
        print(f"FAILED: {failed}")
        return 2
    print(f"Output: {OUT_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
