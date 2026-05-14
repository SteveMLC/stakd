# Warehouse Sort

Sort crates, ship orders, grow your warehouse empire. A casual sort-puzzle game with a tycoon-style progression meta-loop, built with Flutter.

## Game concept

- **Puzzle layer:** Tap-to-select / tap-to-place sort puzzles. Fill horizontal bays with same-color crates. Includes Frozen crates (tap twice to thaw).
- **Meta layer:** Each shipment earns cash and XP. Cash buys business tier upgrades (Local Warehouse → Regional Hub) and cosmetic skins. XP fills your Warehouse Level, which unlocks new mechanics every few hours of play.
- **Retention hooks:** Daily Contract (shared seed, ×3 cash), 7-day streak with cosmetic rewards, and four power-ups (Dynamite Crate, Re-Route Shipment, Bay Crane, Foreman's Advice).

## Bundle identifiers

- Package: `warehouse_sort`
- Android applicationId / namespace: `com.go7studio.warehousesort`
- Display name: `Warehouse Sort`

## Tech stack

- Flutter 3.8+ / Dart 3.8+
- `provider` for state, `shared_preferences` for persistence
- AdMob (`google_mobile_ads`) + in-app purchases (`in_app_purchase`)

## Getting started

```bash
flutter pub get
flutter run
```

Web dev loop (with hot reload):

```bash
bash scripts/dev_web.sh start
```

Type check + lint:

```bash
bash scripts/check.sh
```

## Building for release

**Android App Bundle (for Play Store):**
```bash
flutter build appbundle
# Output: build/app/outputs/bundle/release/app-release.aab
```

**Android APK (for testing):**
```bash
flutter build apk --split-per-abi
# Output: build/app/outputs/flutter-apk/
```

## Project structure

```
lib/
├── engine/        # Move validation, board controller
├── models/        # GameState, Layer, GameStack
├── progression/   # Warehouse leveling, XP curves
├── services/      # Audio, AdMob, IAP, Achievements, Currency, etc.
├── screens/       # Home, Game, Settings, Level Select, Daily, etc.
├── widgets/       # Board, bays, particles, overlays, power-up bar
├── utils/         # Constants, sizing helpers
├── app.dart       # MaterialApp + provider tree
└── main.dart      # Service bootstrap
```

## History

Warehouse Sort was rebranded from "SortBloom" (formerly "Stakd") on 2026-05-13. Git history preserves the full evolution from the original sort-puzzle MVP to today's tycoon-puzzle hybrid.
