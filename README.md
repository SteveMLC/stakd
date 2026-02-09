# Stakd: Color Sort Puzzle

A satisfying color sorting puzzle game built with Flutter.

## 🎮 Game Concept

Stack colored layers into matching piles in this zen-like puzzle game. Features multiple difficulty levels, relaxing sounds, and beautiful animations.

## 🎨 App Icon

The Stakd app icon features vibrant stacked layers representing the core game mechanic, designed with a modern, playful, zen aesthetic.

### Icon Specifications
- **Size:** 1024x1024 pixels (source)
- **Design:** 5 colorful stacked layers
- **Colors:** Purple → Blue → Teal → Green → Yellow (gradient)
- **Style:** Rounded corners, subtle shadows, zen circle background
- **Platforms:** Android (adaptive icons included)

### Regenerating Icons

If you need to regenerate the app icons:

1. **Generate the base icon:**
   ```bash
   flutter test test/generate_icon_test.dart
   ```
   This creates `assets/icon/app_icon.png` (1024x1024)

2. **Generate platform-specific icons:**
   ```bash
   flutter pub run flutter_launcher_icons
   ```
   This creates:
   - Android launcher icons (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi)
   - Android adaptive icons (API 26+)
   - Background color in `android/app/src/main/res/values/colors.xml`

### Icon Configuration

Icon generation is configured in `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#F5F5F5"
  adaptive_icon_foreground: "assets/icon/app_icon.png"
```

### Customizing the Icon

To modify the icon design, edit `test/generate_icon_test.dart`:

- **Colors:** Modify the `colors` array (lines 29-35)
- **Layer count:** Change loop range (line 47)
- **Layer dimensions:** Adjust `layerWidth`, `layerHeight`, `layerSpacing` (lines 42-44)
- **Style:** Modify gradients, shadows, corner radius

After making changes, re-run both generation commands above.

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.8.0 or higher
- Android Studio / Xcode
- Dart 3.8.0 or higher

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd stakd
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

### Building for Release

**Android:**
```bash
flutter build appbundle
# Output: build/app/outputs/bundle/release/app-release.aab
```

**Android APK:**
```bash
flutter build apk --split-per-abi
# Output: build/app/outputs/flutter-apk/
```

## 📱 Features

- Multiple difficulty levels (Easy, Medium, Hard, Expert)
- Zen mode for relaxation
- Beautiful particle effects
- Satisfying sound feedback
- Theme customization
- Ad-supported (AdMob)
- In-app purchases (remove ads, unlock themes)

## 🛠️ Development

### Project Structure
```
lib/
├── main.dart                 # App entry point
├── screens/                  # Game screens
├── widgets/                  # Reusable widgets
├── providers/                # State management
├── models/                   # Game logic
└── utils/                    # Helpers

assets/
├── sounds/                   # Audio files
├── images/                   # Game graphics
└── icon/                     # App icon source
```

### Testing
```bash
flutter test
```

### Code Style
```bash
flutter analyze
```

## 📦 Dependencies

- `provider` - State management
- `google_mobile_ads` - Monetization
- `audioplayers` - Sound effects
- `shared_preferences` - Local storage
- `in_app_purchase` - Premium features
- `flutter_launcher_icons` - Icon generation

## 📄 License

All rights reserved.

## 🤝 Contributing

This is a private project. Contact the maintainer for contribution guidelines.

---

**Built with ❤️ using Flutter**
