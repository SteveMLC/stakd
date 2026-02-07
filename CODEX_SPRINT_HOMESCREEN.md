# STAKD Home Screen Restructure

## 🎯 Mission
Make Zen Mode the PRIMARY entry point. Rename "Play" to "Level Challenge". Create clear visual hierarchy.

## Current Layout (WRONG)
```
Play (primary)           ← This leads to boring level progression
Daily Challenge          ← Good
Select Level             ← Redundant with Play
Zen Mode                 ← BURIED! Should be primary
Settings
```

## New Layout (CORRECT)
```
ZEN MODE (big, primary)  ← Entry to endless flow state
━━━━━━━━━━━━━━━━━━━━━━━━
[Daily] [Level Challenge] ← Secondary row (smaller, side by side)
━━━━━━━━━━━━━━━━━━━━━━━━
⚙️ Settings              ← Small at bottom
```

---

## Phase 1: Restructure home_screen.dart

### 1.1 New Button Layout

Replace the current button column with:

```dart
Widget _buildButtons(BuildContext context) {
  return Column(
    children: [
      // PRIMARY: ZEN MODE (large button)
      _buildZenModeButton(context),
      
      const SizedBox(height: 24),
      
      // SECONDARY ROW: Daily + Levels
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: _buildDailyButton(context),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildLevelChallengeButton(context),
          ),
        ],
      ),
      
      const SizedBox(height: 24),
      
      // TERTIARY: Settings (small)
      _buildSettingsButton(context),
    ],
  );
}
```

### 1.2 Primary Zen Mode Button

```dart
Widget _buildZenModeButton(BuildContext context) {
  return GestureDetector(
    onTap: () => _showZenDifficultySheet(context),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            GameColors.accent,
            GameColors.accent.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: GameColors.accent.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.spa, size: 32, color: Colors.white),
          const SizedBox(width: 12),
          const Text(
            'ZEN MODE',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    ),
  );
}
```

### 1.3 Zen Difficulty Bottom Sheet

When user taps Zen Mode, show bottom sheet picker:

```dart
void _showZenDifficultySheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GameColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: GameColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          const Text(
            'Choose Your Vibe',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: GameColors.text,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Zen mode adapts to your pace',
            style: TextStyle(color: GameColors.textMuted),
          ),
          
          const SizedBox(height: 24),
          
          // Difficulty options
          _buildDifficultyOption(
            context,
            difficulty: 'easy',
            title: 'Relaxed',
            subtitle: '4 colors • Quick puzzles',
            icon: Icons.wb_sunny,
            color: Colors.amber,
          ),
          const SizedBox(height: 12),
          _buildDifficultyOption(
            context,
            difficulty: 'medium',
            title: 'Focused',
            subtitle: '5 colors • Thoughtful pace',
            icon: Icons.self_improvement,
            color: GameColors.palette[1],
          ),
          const SizedBox(height: 12),
          _buildDifficultyOption(
            context,
            difficulty: 'hard',
            title: 'Challenge',
            subtitle: '6 colors • Real puzzles',
            icon: Icons.flash_on,
            color: GameColors.accent,
          ),
          const SizedBox(height: 12),
          _buildDifficultyOption(
            context,
            difficulty: 'ultra',
            title: 'ULTRA',
            subtitle: '7 colors • For masters',
            icon: Icons.whatshot,
            color: GameColors.palette[4],
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

Widget _buildDifficultyOption(
  BuildContext context, {
  required String difficulty,
  required String title,
  required String subtitle,
  required IconData icon,
  required Color color,
}) {
  return GestureDetector(
    onTap: () {
      Navigator.of(context).pop();
      _startZenMode(context, difficulty);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: GameColors.empty,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: GameColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: color),
        ],
      ),
    ),
  );
}
```

### 1.4 Secondary Buttons Row

```dart
Widget _buildDailyButton(BuildContext context) {
  return GestureDetector(
    onTap: () => _openDailyChallenge(context),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: GameColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GameColors.textMuted.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.calendar_today, color: GameColors.accent),
          const SizedBox(height: 8),
          const Text(
            'Daily',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: GameColors.text,
            ),
          ),
          if (_dailyStreak > 0) ...[
            const SizedBox(height: 4),
            Text(
              '🔥 $_dailyStreak',
              style: const TextStyle(
                fontSize: 12,
                color: GameColors.accent,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _buildLevelChallengeButton(BuildContext context) {
  final storage = StorageService();
  final level = storage.getHighestLevel();
  
  return GestureDetector(
    onTap: () => _openLevelSelect(context),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: GameColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GameColors.textMuted.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.flag, color: GameColors.palette[1]),
          const SizedBox(height: 8),
          const Text(
            'Level Challenge',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: GameColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lv $level',
            style: const TextStyle(
              fontSize: 12,
              color: GameColors.textMuted,
            ),
          ),
        ],
      ),
    ),
  );
}
```

---

## Phase 2: Remove Redundant "Play" Button

The old "Play" button just went to the current level. Now:
- "Level Challenge" serves this purpose
- Zen Mode is primary
- Daily Challenge is prominent

DELETE the old `_startGame` function that auto-starts at current level.

---

## Phase 3: Update Level Select Title

In `level_select_screen.dart`, update the app bar:

```dart
AppBar(
  title: const Text('Level Challenge'),
  // ...
)
```

---

## Phase 4: Remove Old Zen Mode Screen Entry

The old `_openZenMode` went directly to a screen. Now it shows the bottom sheet picker first.

---

## Testing

- [ ] Home screen shows Zen Mode as big primary button
- [ ] Tapping Zen Mode opens difficulty picker bottom sheet
- [ ] Daily and Level Challenge are side-by-side secondary buttons
- [ ] Level Challenge replaces old "Play" naming
- [ ] Settings is small at bottom
- [ ] Visual hierarchy is clear

---

## Git

```bash
git add -A && git commit -m "feat: home screen restructure - Zen Mode primary, Level Challenge naming" && git push origin main
```

## When Complete

```bash
openclaw gateway wake --text "Done: Stakd home screen restructured - Zen Mode is now primary entry point" --mode now
```
