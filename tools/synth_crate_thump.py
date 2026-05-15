#!/usr/bin/env python3
"""Synthesize a warehouse-cardboard-crate-landing thump.

Design:
  - 18ms attack click (white noise burst + 1.2kHz sine) — the surface-strike transient
  - 220ms low body: damped sine at ~85Hz (cardboard cavity resonance) + 130Hz secondary
  - Mid-band thwap at 350Hz for ~80ms (the dust kick / paper crinkle)
  - Subtle stereo width: tiny pre-delay (~3ms) between L/R channels
  - Overall ~280ms decay to silence so it doesn't linger past the next move
"""

import numpy as np
from pathlib import Path
import wave
import struct
import subprocess

SR = 44100
DUR = 0.30  # seconds
N = int(SR * DUR)
t = np.linspace(0, DUR, N, endpoint=False)

# --- Attack click: 18ms broadband transient ---
attack_len = int(0.018 * SR)
attack_env = np.exp(-np.linspace(0, 12, attack_len))
attack_noise = (np.random.uniform(-1, 1, attack_len)) * attack_env
attack_tone = np.sin(2 * np.pi * 1200 * np.arange(attack_len) / SR) * attack_env * 0.6
attack = (attack_noise * 0.55 + attack_tone) * 0.85

# --- Low body: damped sine at 85Hz + 130Hz, 220ms decay ---
body_len = int(0.22 * SR)
body_env = np.exp(-np.linspace(0, 5.5, body_len))
body_85 = np.sin(2 * np.pi * 85 * np.arange(body_len) / SR) * body_env
body_130 = np.sin(2 * np.pi * 130 * np.arange(body_len) / SR) * body_env * 0.45
body = (body_85 + body_130) * 0.9

# --- Mid thwap: 350Hz damped, 80ms ---
mid_len = int(0.08 * SR)
mid_env = np.exp(-np.linspace(0, 8, mid_len))
mid = np.sin(2 * np.pi * 350 * np.arange(mid_len) / SR) * mid_env * 0.35

# --- Layer everything onto a zero canvas ---
mono = np.zeros(N, dtype=np.float64)
mono[:attack_len] += attack
mono[:body_len] += body
mono[:mid_len] += mid

# Soft saturation to glue the layers (gentle tanh)
mono = np.tanh(mono * 1.2) * 0.85

# Normalize peak
peak = np.max(np.abs(mono))
if peak > 0:
    mono = mono / peak * 0.92

# --- Stereo widen: 3ms pre-delay on R channel ---
delay = int(0.003 * SR)
left = mono.copy()
right = np.concatenate([np.zeros(delay), mono[:-delay]])

# Mix to int16 stereo
stereo = np.stack([left, right], axis=1)
stereo_int = np.clip(stereo * 32767, -32768, 32767).astype(np.int16)

# Write WAV
wav_path = "/tmp/crate_thump_synth.wav"
with wave.open(wav_path, "wb") as wf:
    wf.setnchannels(2)
    wf.setsampwidth(2)
    wf.setframerate(SR)
    wf.writeframes(stereo_int.tobytes())

# Convert to MP3 via ffmpeg (high quality, small file)
mp3_path = "/tmp/crate_thump_synth.mp3"
subprocess.run(
    ["ffmpeg", "-y", "-i", wav_path, "-codec:a", "libmp3lame",
     "-qscale:a", "2", mp3_path],
    check=True, capture_output=True,
)

print(f"Wrote {wav_path} and {mp3_path}")
print(f"Duration: {DUR*1000:.0f}ms, sample rate: {SR}Hz, stereo")
