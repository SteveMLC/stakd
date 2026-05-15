#!/usr/bin/env python3
"""Local FLUX.1-schnell icon generator for Warehouse Sort.

Usage:
    python3 generate_icons.py [subject_key]

If subject_key is omitted, runs all defined power-up + UI icons.
Outputs PNG files to assets/icons_generated/.

Why local: M4 Pro 48GB can run Flux Schnell at 1024x1024 in ~20s/image
on MPS without any API costs or upload friction. The cached model is
~31GB at ~/.cache/huggingface/hub/models--black-forest-labs--FLUX.1-schnell.
"""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

import torch
from diffusers import FluxPipeline
from PIL import Image

# ---------------------------------------------------------------------------
# Style families — different vibes for different icon roles.
#
#   industrial: power-up icons (tools / mascots) — vector, navy bg, gritty
#   cartoon_crate: gameplay color crates — playful sticker style, bright,
#                  light bg, "crate bursting with cargo" energy
#
# Every prompt is paired with a style family so generations stay coherent
# within their role but DIFFER across roles. Same crate-wood vocabulary
# everywhere would make the game read flat (Steve's 2026-05-15 note).
# ---------------------------------------------------------------------------

STYLES: dict[str, tuple[str, str]] = {
    "industrial": (
        # prefix
        "Industrial warehouse vector game icon, ",
        # suffix
        ", flat design with subtle gradients and brushed-metal highlights, "
        "hazard yellow and brushed steel palette with hot orange accents, "
        "slightly grungy distressed texture, deep navy background, "
        "centered composition, square 1:1 aspect ratio, "
        "clean silhouette, sharp edges, no text, no letters, "
        "high contrast, mobile game UI icon"
    ),
    "cartoon_crate": (
        # prefix — DEPRECATED 2026-05-15: pushed Flux too far toward
        # children's-book sticker, lost the warehouse_sort game-asset
        # vocabulary. Kept here for reference; use `warehouse_burst`
        # instead for color crates.
        "Cute cartoon mobile game sticker, ",
        # suffix
        ", playful and silly, bright cheerful colors, "
        "bold thick black outlines like a Pixar Animation Studios sticker, "
        "soft pastel highlights and rounded shapes, "
        "subtle drop shadow under the crate, "
        "plain cream off-white background, "
        "centered composition, square 1:1 aspect ratio, "
        "no text, no letters, no logos, "
        "candy-bright saturated palette, looks like a 3D cartoon icon"
    ),
    "warehouse_burst": (
        # prefix
        "Mobile warehouse game crate icon, ",
        # suffix — locks the structural language to the same wooden-plank
        # + steel-reinforced crate vocabulary as the wrinkle set
        # (frozen/fragile/priority/oversized) so all crates read as a
        # coherent family. Color identity comes from PAINTING the wood
        # + the CARGO bursting out, not from switching container type.
        ", wooden shipping crate with vertical plank construction, "
        "steel L-bracket corner reinforcement and rivets, "
        "open top with cargo bursting and overflowing out, "
        "slightly weathered painted wood surface, "
        "warm soft lighting from above, soft drop shadow underneath, "
        "muted cream warehouse floor background with subtle vignette, "
        "centered composition, square 1:1 aspect ratio, "
        "vivid saturated cargo colors against the painted crate body, "
        "no text, no letters, no logos, "
        "mobile game asset icon style"
    ),
}


# Per-prompt structure: (style_family, subject_phrase)
PROMPTS: dict[str, tuple[str, str]] = {
    # ---- Power-ups (industrial vector vocabulary — already shipped) ----
    "dynamite_crate": ("industrial",
        "a small wooden shipping crate with a stick of dynamite taped to "
        "the front, lit fuse sparking, hazard stripes on the crate"),
    "reroute_shipment": ("industrial",
        "a yellow forklift truck with curved directional arrows above it "
        "showing it changing direction, motion lines"),
    "bay_crane": ("industrial",
        "a steel overhead industrial bay crane with a magnetic claw "
        "lifting a glowing crate, chains and pulleys visible"),
    "foreman_advice": ("industrial",
        "a hard-hat construction foreman bust with a glowing lightbulb "
        "above his head, pointing finger, clipboard in hand"),

    # ---- Wrinkle crates (industrial vocabulary; may regen with more
    # personality after color crates are settled) -----------------------
    "frozen_crate": ("industrial",
        "a wooden shipping crate covered in frost and icicles, blue-white "
        "ice glaze, vapor rising from the top"),
    "priority_crate": ("industrial",
        "a wooden shipping crate stamped with a red exclamation mark and "
        "a countdown timer, urgent priority shipping label"),
    "fragile_crate": ("industrial",
        "a wooden shipping crate with FRAGILE hazard tape across the front, "
        "broken glass shards leaking from one corner"),
    "oversized_crate": ("industrial",
        "an oversized double-tall wooden shipping crate, much larger than "
        "standard, with heavy-duty steel reinforcement bands"),

    # ---- Color crates (cartoon family — the gameplay sort tokens) -----
    # Each one is a DIFFERENT type of cargo bursting out of its crate so
    # the puzzle board reads colorful + playful rather than 8 brown
    # boxes in different tints. Dominant color drives instant recognition;
    # cargo type drives flavor.
    "crate_red_fireworks": ("warehouse_burst",
        "a wooden shipping crate painted bright cherry-red, "
        "fireworks rockets and sparklers bursting out of the open top, "
        "colorful sparks and stars flying upward, lit fuses, festive"),
    "crate_blue_electronics": ("warehouse_burst",
        "a bright royal-blue open shipping crate bursting with circuit "
        "boards, computer chips, glowing screens, electrical lightning "
        "bolts flying out, tech parts overflowing"),
    "crate_green_produce": ("warehouse_burst",
        "a bright apple-green open shipping crate bursting with fresh "
        "produce, carrots and leafy lettuce and broccoli spilling out, "
        "happy organic vegetables"),
    "crate_yellow_gold": ("warehouse_burst",
        "a bright sunshine-yellow open shipping crate bursting with "
        "shiny gold coins and gold bars, sparkles and dollar signs, "
        "treasure overflowing"),
    "crate_purple_potions": ("warehouse_burst",
        "a bright royal-purple open shipping crate bursting with glowing "
        "magical potion bottles, swirling purple smoke, sparkles, "
        "mysterious labels"),
    "crate_cyan_ice": ("warehouse_burst",
        "a bright icy-cyan open shipping crate bursting with ice cubes "
        "and frozen fish and snowflakes, cold vapor rising, frost "
        "around the edges"),
    "crate_pink_candy": ("warehouse_burst",
        "a bright bubblegum-pink open shipping crate bursting with "
        "candy, lollipops, gumballs, cupcakes, jellybeans, "
        "sweets overflowing"),
    "crate_orange_sports": ("warehouse_burst",
        "a bright pumpkin-orange open shipping crate bursting with "
        "sports balls — basketball, soccer ball, baseball, "
        "spilling out playfully"),
}


def build_prompt(subject_key_or_subject) -> str:
    """Build the full prompt for a subject key (with style family) or
    a raw subject phrase (legacy industrial-default path).

    Accepts either a key into PROMPTS dict or a raw subject string;
    raw strings default to the industrial style for backwards-compat
    with `process_icons.py` and the mflux wrapper.
    """
    if isinstance(subject_key_or_subject, tuple):
        style, subject = subject_key_or_subject
    elif subject_key_or_subject in PROMPTS:
        style, subject = PROMPTS[subject_key_or_subject]
    else:
        style, subject = "industrial", subject_key_or_subject
    prefix, suffix = STYLES[style]
    return prefix + subject + suffix


def load_pipeline(safe_mode: bool = True) -> FluxPipeline:
    """Load FLUX.1-schnell pipeline.

    safe_mode=True (default): use model CPU offload so the Mac stays
    responsive during generation. ~30s slower per image but ~half the
    active GPU memory footprint. Pick this when running alongside the
    Flutter sim + browser + IDE.

    safe_mode=False: hot-load entire pipeline to MPS in fp16. Fastest
    (~15s per icon) but spikes ~22GB during load and can hang the
    desktop for the load phase.
    """
    print(
        f"Loading FLUX.1-schnell pipeline "
        f"({'safe / cpu-offload' if safe_mode else 'hot / MPS-resident'})...",
        flush=True,
    )
    t0 = time.time()
    pipe = FluxPipeline.from_pretrained(
        "black-forest-labs/FLUX.1-schnell",
        torch_dtype=torch.float16,
    )
    if safe_mode:
        # CPU-offload: model lives on CPU, layers move to MPS just-in-time.
        # Mac stays usable during gen at the cost of ~2x per-image latency.
        pipe.enable_model_cpu_offload()
    else:
        pipe.to("mps")
        pipe.enable_attention_slicing()
    print(f"Pipeline loaded in {time.time() - t0:.1f}s", flush=True)
    return pipe


def generate_one(
    pipe: FluxPipeline,
    key: str,
    subject: str,
    out_dir: Path,
    width: int = 1024,
    height: int = 1024,
    steps: int = 4,
    seed: int = 0,
) -> Path:
    prompt = build_prompt(subject) if isinstance(subject, str) else build_prompt(PROMPTS[key])
    source_path = out_dir / f"{key}.png"
    thumb_dir = out_dir / "192"
    thumb_dir.mkdir(parents=True, exist_ok=True)
    thumb_path = thumb_dir / f"{key}.png"

    print(f"\n[gen] {key} → {source_path} (+ 192² thumb)", flush=True)
    print(f"  prompt: {prompt[:100]}...", flush=True)
    t0 = time.time()
    generator = torch.Generator(device="cpu").manual_seed(seed)
    image = pipe(
        prompt=prompt,
        width=width,
        height=height,
        num_inference_steps=steps,
        guidance_scale=0.0,  # Schnell uses 0
        generator=generator,
    ).images[0]
    image.save(source_path)
    # Downscaled production variant — what we wire into pubspec.yaml.
    # 192² covers the largest in-app surface (power-up button at 64dp
    # ≈ 192px on 3x retina) without blowing up app bundle size.
    thumb = image.resize((192, 192), Image.LANCZOS)
    thumb.save(thumb_path)
    print(f"  done in {time.time() - t0:.1f}s", flush=True)
    return source_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "subject_key",
        nargs="?",
        help=(
            "One of: " + ", ".join(PROMPTS.keys()) +
            ". Omit to generate all."
        ),
    )
    parser.add_argument("--width", type=int, default=768)
    parser.add_argument("--height", type=int, default=768)
    parser.add_argument("--steps", type=int, default=4, help="Flux Schnell wants 4")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument(
        "--fast",
        action="store_true",
        help="Skip CPU offload — faster but may briefly lock the desktop",
    )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    out_dir = repo_root / "assets" / "icons_generated"
    out_dir.mkdir(parents=True, exist_ok=True)

    if args.subject_key and args.subject_key not in PROMPTS:
        print(f"ERROR: unknown subject_key '{args.subject_key}'.")
        print(f"Available: {', '.join(PROMPTS.keys())}")
        return 1

    keys = [args.subject_key] if args.subject_key else list(PROMPTS.keys())
    pipe = load_pipeline(safe_mode=not args.fast)

    t_start = time.time()
    for key in keys:
        # PROMPTS values are now (style, subject) tuples; pass the
        # subject for legacy compatibility with generate_one's signature.
        _style, subject = PROMPTS[key]
        generate_one(
            pipe,
            key,
            subject,
            out_dir,
            width=args.width,
            height=args.height,
            steps=args.steps,
            seed=args.seed,
        )
    print(
        f"\nGenerated {len(keys)} icon(s) in "
        f"{time.time() - t_start:.1f}s total. Output: {out_dir}",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
