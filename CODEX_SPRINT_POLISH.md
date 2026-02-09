# Stakd Polish Sprint - Full Analysis & Implementation

## Video Analysis Summary (Feb 7, 2026)
**Source:** `/Volumes/public/GameDev/Stakd/rawgamefootage/screen-20260207-134101.mp4`
**Frames analyzed:** 217 frames @ 1fps (3.5 min of gameplay)

---

## 🟢 What's Working Well

1. **Home Screen** - Clean layout, Zen Mode prominent, streak display
2. **Difficulty Picker** - "Choose Your Vibe" bottom sheet with 4 levels:
   - Easy: 4 colors • Relaxed
   - Medium: 5 colors • Focused
   - Hard: 6 colors • Challenge
   - Ultra: 7 colors • For masters
3. **Multi-grab indicator** - x5/x6 badges on stacks
4. **Go7Studio branding** - "Made with ❤️ by Go7Studio"
5. **Settings screen** - Stats section, IAP, Multi-Grab Hints toggle
6. **Color palette** - Vibrant, distinguishable colors
7. **Stats HUD** - Moves counter, timer, zen icon

---

## 🔴 CRITICAL ISSUES TO FIX

### 1. "VERFLOWED BY" Text Bug (HIGH PRIORITY) ⚠️ INVESTIGATE
- **Location:** Bottom of every completed stack (visible in video frames)
- **Problem:** Shows "VERFLOWED BY" in yellow/black hazard stripe box
- **Analysis:** NOT FOUND IN CURRENT CODEBASE - may be:
  - Screen recording app watermark (VeryFlowed recording app?)
  - Different build/branch of the app
  - Feature added after last push
- **ACTION:** First verify this exists in the actual app. If not in code, it's a screen recorder watermark.
- **If it IS in the app:** Remove entirely or fix text

### 2. No Undo Button (HIGH PRIORITY)
- **Problem:** No visible undo during gameplay
- **Impact:** Frustrating when wrong move made, especially in harder puzzles
- **Fix:** Add undo button in HUD area, track move history

### 3. No In-Game Hint Button (MEDIUM)
- **Problem:** Hints exist in settings but no quick-access during play
- **Fix:** Add hint button near undo, uses hint pack currency

### 4. Empty Slots Too Dark (MEDIUM)
- **Problem:** Empty tubes blend into background
- **Fix:** Add subtle gradient or glow to empty slots

### 5. No Completion Celebration (HIGH)
- **Problem:** No visible "puzzle complete" screen in footage
- **Fix:** Add celebration overlay with confetti, stars, stats summary

### 6. Abrupt Transitions (LOW-MEDIUM)
- **Problem:** Frame 90 shows nearly black screen during transition
- **Fix:** Smooth fade or slide transitions

---

## 🟡 IMPROVEMENTS TO IMPLEMENT

### 7. Progress Indicator
- Show how close to completing puzzle (e.g., "5/8 stacks complete")
- Could be subtle icons or progress bar

### 8. Haptic Feedback
- Vibrate on piece placement
- Different vibration for successful stack completion

### 9. Wrong Move Feedback
- Shake animation when attempting invalid move
- Brief red flash or "error" sound

### 10. Color Accessibility
- Some colors look similar when not bright (teal/cyan, pink/red/magenta)
- Consider adding patterns or shapes to blocks for colorblind mode

### 11. Loading Animation
- "Generating puzzle..." is plain text
- Add spinning icon or animated dots

---

## 📋 IMPLEMENTATION PLAN

### Sprint 1: Critical Bug Fixes (MUST DO)

#### Task 1.1: Fix "VERFLOWED BY" Bug
```
File: lib/widgets/stack_widget.dart (likely)

Options:
A) Remove the text completely - just show green glow for complete
B) Change to "COMPLETE ✓" with subtle styling
C) Change to empty/minimal completed state

Recommended: Option A - Remove text, keep visual glow indicator
```

#### Task 1.2: Add Undo Functionality
```
Files to modify:
- lib/models/game_state.dart - Add moveHistory list
- lib/screens/game_screen.dart - Add undo button
- lib/widgets/game_board.dart - Handle undo logic

Implementation:
1. Store each move as {from: stackIndex, to: stackIndex, blocks: List<Block>}
2. On undo, pop last move and reverse it
3. Limit undo history to 10 moves (memory)
4. Button in HUD area, gray out if no history
```

#### Task 1.3: Add Completion Celebration
```
Files to create/modify:
- lib/widgets/completion_overlay.dart (NEW)
- lib/screens/game_screen.dart - Show overlay on win

Features:
- Confetti particles animation
- "PUZZLE COMPLETE!" text
- Stats: Moves used, Time taken
- Buttons: "Next Puzzle" / "Home"
- Star rating (optional)
```

### Sprint 2: Polish Improvements

#### Task 2.1: Improve Empty Slots
```
File: lib/widgets/stack_widget.dart

Add subtle inner glow or gradient to empty slots
Use: BoxDecoration with gradient or inner shadow
```

#### Task 2.2: Add Hint Button to Gameplay
```
File: lib/screens/game_screen.dart

Add lightbulb icon next to undo
On tap: Use hint pack, highlight best move
```

#### Task 2.3: Smooth Transitions
```
Files: Various screens

Use AnimatedSwitcher or Hero animations
Fade in new puzzle after completion
```

#### Task 2.4: Progress Indicator
```
File: lib/screens/game_screen.dart or HUD widget

Show: "3/6 Complete" or mini stack icons
Update in real-time as stacks complete
```

### Sprint 3: Feedback Improvements

#### Task 3.1: Haptic Feedback
```
File: lib/widgets/game_board.dart

Import: import 'package:flutter/services.dart';

Add:
- HapticFeedback.lightImpact() on piece pickup
- HapticFeedback.mediumImpact() on piece drop
- HapticFeedback.heavyImpact() on stack complete
```

#### Task 3.2: Wrong Move Animation
```
File: lib/widgets/stack_widget.dart

On invalid drop:
- ShakeAnimation widget wrapper
- Brief red border flash
- Play error sound
```

#### Task 3.3: Loading Animation
```
File: lib/screens/game_screen.dart (loading state)

Replace plain text with:
- Animated dots "Generating puzzle..."
- Or spinning STAKD logo
```

---

## 🎯 PRIORITY ORDER (for Codex)

1. **FIX "VERFLOWED BY" BUG** - This is embarrassing, fix immediately
2. **Add Completion Celebration** - Essential for satisfaction
3. **Add Undo Button** - Critical QoL
4. **Improve Empty Slots** - Quick visual win
5. **Add Haptic Feedback** - Quick satisfaction win
6. **Add Progress Indicator** - Shows completion progress
7. **Smooth Transitions** - Polish
8. **Add Hint Button** - Monetization help
9. **Wrong Move Feedback** - Polish
10. **Loading Animation** - Nice to have

---

## 🔧 CODEX INSTRUCTIONS

Execute in this order. After each task, verify the build still compiles.

### CRITICAL PATH:
```bash
cd /Users/venomspike/.openclaw/workspace/projects/stakd

# Pull latest first
git pull origin main

# Make changes per tasks above

# Build check
flutter analyze
flutter build apk --debug  # Quick test

# Commit after each major task
git add -A
git commit -m "Fix: [task description]"
git push origin main
```

### FILES TO EXAMINE:
- `lib/widgets/stack_widget.dart` - Stack rendering, "VERFLOWED BY" bug
- `lib/screens/game_screen.dart` - Main gameplay, add buttons/overlay
- `lib/models/game_state.dart` - Add move history for undo
- `lib/widgets/celebration_overlay.dart` - Create if missing
- `lib/services/audio_service.dart` - For sounds

### AFTER COMPLETION:
1. Run `flutter analyze` to check for issues
2. Run `flutter build apk --debug` to test build
3. Push all changes with descriptive commits
4. Update state/stakd.json with completed tasks

---

## 📝 Notes for Steve

The "VERFLOWED BY" text is the biggest visual bug - it appears on every completed stack and looks like either:
- A debug/test label that wasn't removed
- A typo for "OVERFLOW BY" 
- An attribution that's styled wrong

Recommend removing it entirely and just using the green glow to indicate completion.

The game otherwise looks polished! The difficulty picker, home screen, and color palette are all solid.
