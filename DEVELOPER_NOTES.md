# Stakd – Developer Notes & Troubleshooting

Reference for developers working on the Stakd codebase. Documents known issues, errors, and solutions.

---

## 1. Audio Playback Errors (Android)

### Symptom
```
I/flutter: AudioPlayers Exception: AudioPlayerException(
     AssetSource(path: sounds/tap.mp3, mimeType: null),
     PlatformException(AndroidAudioError, Failed to set source. For troubleshooting, see: 
     https://github.com/bluefireteam/audioplayers/blob/main/troubleshooting.md, 
     MEDIA_ERROR_UNKNOWN {what:1}, MEDIA_ERROR_SYSTEM, null))
E/MediaPlayerNative: error (1, -2147483648)
```

### Required sound files (not missing – present in `assets/sounds/`)

| File       | Purpose           | Used by            |
|-----------|-------------------|--------------------|
| `tap.mp3` | Stack selection   | `AudioService.playTap()` |
| `slide.mp3` | Layer movement  | `AudioService.playSlide()` |
| `clear.mp3` | Stack complete  | `AudioService.playClear()`, combo |
| `win.mp3` | Level complete    | `AudioService.playWin()` |
| `error.mp3` | Invalid move    | `AudioService.playError()` |
| `music.mp3` | Background music | `AudioService.startMusic()` |

All files are present and referenced in `lib/services/audio_service.dart` via `GameSound` enum. See `assets/sounds/SOUNDS_CREDITS.md` for sources.

### Possible causes
- **Asset path format**: audioplayers may expect `assets/sounds/tap.mp3` instead of `sounds/tap.mp3`. Check `AssetSource` usage in `lib/services/audio_service.dart`.
- **Android MediaPlayer / codec**: Some devices fail to decode certain MP3s. Try:
  - Re-encoding as 128kbps CBR MP3
  - Using different sample rate (e.g. 48kHz)
  - Testing on another device/emulator
- **Corrupted or empty files**: Verify each file plays in a media player. Regenerate from sources in SOUNDS_CREDITS.md if needed.
- **pubspec.yaml**: `assets/sounds/` must list the folder; individual files are included automatically.

### Quick check
Run `flutter pub get` and confirm assets bundle:

```bash
flutter pub get
# Inspect asset bundle (files should appear)
```

---

## 2. `setState()` / `markNeedsBuild()` During Build

### Symptom
```
EXCEPTION CAUGHT BY FOUNDATION LIBRARY
setState() or markNeedsBuild() called during build.
This _InheritedProviderScope<GameState?> widget cannot be marked as needing to build...

#4 GameState.initGame (package:stakd/models/game_state.dart:100:5)
#5 _GameScreenState._loadLevel (package:stakd/screens/game_screen.dart:203:31)
#6 _GameScreenState.initState (package:stakd/screens/game_screen.dart:48:5)
```

### Cause
`_loadLevel()` is called from `initState()` and triggers `GameState.initGame()` → `notifyListeners()`, which schedules a rebuild while the tree is still building.

### Fix
Defer level loading until after the first frame:

```dart
@override
void initState() {
  super.initState();
  _currentLevel = widget.level;
  _checkTutorial();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadLevel();
  });
}
```

Or use `didChangeDependencies()` / `mounted` guards before calling code that uses `notifyListeners()`.

---

## 3. RenderFlex Overflow

### Symptom
```
Another exception was thrown: A RenderFlex overflowed by 2.0 pixels on the bottom.
```

### Cause
A `Column` or `Row` is trying to lay out more children than the available space.

### Likely locations
- Game board layout (e.g. `lib/widgets/game_board.dart`)
- Screens with fixed heights (e.g. home, settings, daily challenge)

### Fix
- Wrap content in `SingleChildScrollView` or `ListView`
- Use `Expanded` / `Flexible` where appropriate
- Reduce padding/margins or font sizes
- Use `FittedBox` to scale content down

---

## 4. Other Terminal Warnings

| Warning | Action |
|---------|--------|
| `OnBackInvokedCallback is not enabled` | Add `android:enableOnBackInvokedCallback="true"` in `AndroidManifest.xml` for predictive back |
| `FilePhenotypeFlags` (GMS) | Google Play Services config; usually ignorable |
| `DynamiteModule` / AdMob | Expected for ads; test IDs are in use |

---

## 5. Asset References

### Audio paths (current)
- **Code**: `sounds/tap.mp3`, `sounds/music.mp3`, etc. (`lib/services/audio_service.dart`)
- **pubspec**: `assets/sounds/` (folder)
- **Bundle key**: typically `assets/sounds/<filename>`

If audio still fails, try `AssetSource('assets/sounds/tap.mp3')` in `audio_service.dart`.

---

## 6. Useful Commands

```bash
# Analyze
flutter analyze

# Run on Android
flutter run

# Run on Chrome (if web supported)
flutter run -d chrome

# Clean and rebuild
flutter clean && flutter pub get
```

---

*Last updated: February 2025*
