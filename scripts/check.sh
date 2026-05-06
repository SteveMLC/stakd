#!/usr/bin/env bash
# SortBloom build/test gate: run analyze + unit tests fast.
# Use this before commits or as part of an iteration loop.

set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

echo "==> flutter analyze"
flutter analyze --no-fatal-infos --no-fatal-warnings

echo "==> flutter test (unit, fast)"
# generate_icon_test is a one-shot icon generator and writes to disk;
# skip it from the gate so CI stays clean.
flutter test test/level_generator_test.dart test/widget_test.dart

echo "All checks passed."
