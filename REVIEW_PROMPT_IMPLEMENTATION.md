# Review Prompt Implementation

## Overview
Implemented a smart review prompt system for Stakd that shows users a friendly dialog asking them to review the app on the Play Store when certain engagement milestones are reached.

## Trigger Conditions
The review prompt will show when **ANY** of these conditions are met:
1. **Level 10 completed** for the first time
2. **5th game session** (tracked on app start)
3. **100 total moves** made across all games

## Cooldown System
- Once shown, the prompt won't appear again for **7 days**
- If user reviews, it never shows again
- If user declines, cooldown period starts

## User Flow
1. Modal appears: "Enjoying Stakd? 😊"
2. Two options:
   - **"Yes! 💚"** → Opens Play Store review page
   - **"Not really 😕"** → Shows "Thanks for the feedback!" toast

## Implementation Details

### Files Created

#### `lib/services/review_service.dart`
- Singleton service for tracking review metrics
- Uses SharedPreferences for persistence
- Methods:
  - `shouldShowReviewPrompt()` - Checks all trigger conditions
  - `markReviewPromptShown()` - Starts cooldown period
  - `markReviewed()` - User reviewed, never show again
  - `incrementSessionCount()` - Called on app start
  - `markLevel10Completed()` - Called when level 10 is completed

#### `lib/widgets/review_prompt_dialog.dart`
- Beautiful modal dialog matching game's dark theme
- Animated entrance (scale + fade)
- Integrates with url_launcher to open Play Store
- Non-dismissible (user must make a choice)

### Files Modified

#### `lib/main.dart`
- Initialize ReviewService with SharedPreferences
- Increment session count on app start

#### `lib/screens/game_screen.dart`
- Import review service and dialog
- Track level 10 completion in `_onLevelComplete()`
- Check and show review prompt in `_nextLevel()` after ads
- Fixed async BuildContext usage

## Testing Checklist

To test the review prompt:

1. **Level 10 trigger:**
   - Play through to level 10
   - Complete it
   - Should see prompt after celebration overlay

2. **Session count trigger:**
   - Open and close app 5 times
   - Play any level to completion
   - Should see prompt

3. **Move count trigger:**
   - Make 100+ moves across multiple games
   - Complete a level
   - Should see prompt

4. **Cooldown test:**
   - Decline prompt ("Not really")
   - Complete another level immediately
   - Should NOT see prompt
   - Wait 7 days (or manually modify SharedPreferences)
   - Should see prompt again

5. **Review completion:**
   - Accept prompt ("Yes!")
   - Complete more levels
   - Should NEVER see prompt again

## Debug Commands

To manually test triggers:

```dart
// In Flutter DevTools console or debug code:

// Reset all review data
await ReviewService().resetReviewData();

// Check current stats
print(ReviewService().getStats());

// Force session count to 5
final prefs = await SharedPreferences.getInstance();
await prefs.setInt('review_session_count', 5);
```

## Store Configuration

Play Store URL:
```
https://play.google.com/store/apps/details?id=com.go7studio.stakd
```

Uses `url_launcher` package (already in dependencies).

## Design Notes

- Dialog uses GameColors.surface and GameColors.accent
- Matches existing CelebrationOverlay animation style
- Emoji-based CTAs for friendly, approachable tone
- Non-intrusive timing (after level complete, not mid-game)

## Analytics Recommendations (Future)

Consider tracking:
- Review prompt shown count
- Accept vs decline rate
- Which trigger condition fired most often
- Time from app install to review prompt

This data can help optimize trigger thresholds.
