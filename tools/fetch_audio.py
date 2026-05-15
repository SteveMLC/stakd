#!/usr/bin/env python3
"""Fetch warehouse_sort SFX from the curated manifest at
docs/audio-sources.md — Mixkit + Freesound CC0 sounds Steve picked
manually on 2026-05-13 (better than the ElevenLabs regen pass).

Mixkit pages embed the MP3 inside <audio><source src=...> OR via
data-audio-src on the play button. Pull the page HTML, regex the
CDN URL, download the MP3.

Output: /tmp/wh_audio_fetch/*.mp3
"""

from __future__ import annotations

import re
import sys
import urllib.request
from pathlib import Path

OUT = Path("/tmp/wh_audio_fetch")
OUT.mkdir(parents=True, exist_ok=True)

UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 "
    "(KHTML, like Gecko) Version/17.0 Safari/605.1.15"
)

# Mapping: slot filename -> Mixkit page URL (from docs/audio-sources.md)
SLOTS: dict[str, str] = {
    "tap": "https://mixkit.co/free-sound-effects/select-click/",
    "slide": "https://mixkit.co/free-sound-effects/fast-whoosh-transition/",
    "clear": "https://mixkit.co/free-sound-effects/achievement-bell/",
    "win": "https://mixkit.co/free-sound-effects/successful-horns-fanfare/",
    "error": "https://mixkit.co/free-sound-effects/losing-piano/",
    "coin": "https://mixkit.co/free-sound-effects/winning-a-coin-video-game/",
    "levelup": "https://mixkit.co/free-sound-effects/game-level-completed/",
    "powerup": "https://mixkit.co/free-sound-effects/quick-metal-transition-sweep/",
    "crate_thump": "https://mixkit.co/free-sound-effects/hard-pop-click/",
    "klaxon": "https://mixkit.co/free-sound-effects/basketball-buzzer/",
    "crate_pickup": "https://mixkit.co/free-sound-effects/modern-click-box-check/",
    "star_1": "https://mixkit.co/free-sound-effects/relaxing-bell-chime/",
    "star_2": "https://mixkit.co/free-sound-effects/cooking-bell-ding/",
    "star_3": "https://mixkit.co/free-sound-effects/fairy-arcade-sparkle/",
    "power_sort_bomb": "https://mixkit.co/free-sound-effects/arcade-game-explosion/",
    "streak_milestone": "https://mixkit.co/free-sound-effects/quick-positive-video-game-notification-interface/",
}

MP3_PATTERNS = [
    re.compile(r'https://assets\.mixkit\.co/[^"\']+\.mp3'),
    re.compile(r'https://[a-zA-Z0-9./_-]+\.mp3'),
]


def fetch_one(slot: str, page_url: str) -> bool:
    print(f"[{slot:18}] ← {page_url}", flush=True)
    req = urllib.request.Request(page_url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            html = r.read().decode("utf-8", errors="ignore")
    except Exception as e:
        print(f"  ✗ page fetch failed: {e}")
        return False

    mp3_url = None
    for pat in MP3_PATTERNS:
        m = pat.search(html)
        if m:
            mp3_url = m.group(0)
            break

    if not mp3_url:
        print(f"  ✗ no MP3 URL found in page")
        return False
    print(f"    → {mp3_url}")

    try:
        dl_req = urllib.request.Request(mp3_url, headers={"User-Agent": UA})
        with urllib.request.urlopen(dl_req, timeout=30) as r:
            data = r.read()
    except Exception as e:
        print(f"  ✗ MP3 fetch failed: {e}")
        return False

    out_path = OUT / f"{slot}.mp3"
    out_path.write_bytes(data)
    size = out_path.stat().st_size
    if size < 1000:
        print(f"  ✗ download too small ({size}b)")
        return False
    print(f"  ✓ {out_path} ({size:,} bytes)")
    return True


def main() -> int:
    successes, failures = [], []
    for slot, url in SLOTS.items():
        if fetch_one(slot, url):
            successes.append(slot)
        else:
            failures.append(slot)
    print(f"\nDone. {len(successes)}/{len(SLOTS)} fetched.")
    if failures:
        print(f"Failed: {', '.join(failures)}")
    print(f"\nFiles in {OUT}:")
    for p in sorted(OUT.glob("*.mp3")):
        print(f"  {p.stat().st_size:>10,}  {p.name}")
    return 0 if not failures else 2


if __name__ == "__main__":
    sys.exit(main())
