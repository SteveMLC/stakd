# STAKD — What's Missing & What Would Make It Great

**Date:** February 18, 2026  
**Based on:** Full codebase audit of all 68 Dart files

---

## 1. WHAT THE GAME IS MISSING

### 1A. No Tutorial/Onboarding Flow
**Status:** `TutorialService` exists with steps (selectStack, moveLayer, stackClear, undo) but it's basic.  
**Missing:**
- No first-time detection + auto-trigger on fresh install
- No animated hand/finger pointing at targets
- No explanation of multi-grab, power-ups, or zen mode
- No "try it yourself" sandboxed tutorial level
- Competitor benchmark: Color Sort, Ball Sort all have animated hand tutorials on first 3 levels

**Fix:** Create `lib/screens/tutorial_screen.dart` — a guided 4-step overlay that triggers on first launch. Use `StorageService` to persist `tutorial_completed` flag. Show animated hand SVG pointing at target stack, dim non-target elements.

### 1B. No Achievement Definitions
**Status:** `Achievement` model is solid, `AchievementService` exists — but **there are ZERO achievements defined anywhere**. No achievement list, no triggers, no checking logic.  
**Missing:**
- No actual achievements to earn
- No achievement gallery/screen to view progress
- No pop-up when achievements unlock

**Fix:** Create `lib/data/achievement_definitions.dart` with 20-30 achievements across categories (first clear, 10 clears, 50 clears, speed runs, perfect clears, zen milestones, daily streak, power-up usage, theme collection). Wire evaluation into game completion callback.

### 1C. No Notifications / Re-engagement
**Status:** Zero push notification support.  
**Missing:**
- "Your daily reward is ready!" reminder
- "Continue your streak — Day 4 waiting!" 
- "New daily challenge available!"

**Fix:** Add `firebase_messaging` or `flutter_local_notifications`. Schedule local notifications for daily reward reset (midnight), streak at-risk (if claimed yesterday, remind at 8 PM today), and daily challenge.

### 1D. No Social / Sharing
**Status:** `LeaderboardService` exists with Firebase, `LeaderboardScreen` built.  
**Missing:**
- No share button after completing a puzzle ("Share your score!")
- No screenshot sharing of zen garden
- No "challenge a friend" mechanic
- No weekly/monthly leaderboard rotation

**Fix:** Add share button to `CompletionOverlay`. Use `share_plus` package. For zen garden, add "📸 Share Garden" button to `ZenGardenScreen` that screenshots and shares.

### 1E. No Seasonal/Event Content
**Status:** Nothing time-limited.  
**Missing:**
- No seasonal themes (Halloween, Christmas, Valentine's)
- No limited-time challenges
- No special zen garden elements for events

**Fix:** Add `event_service.dart` with date-based event detection. Create 3-4 seasonal themes with special block palettes. Add event-exclusive daily challenges with bonus rewards.

### 1F. Level Challenge Depth
**Status:** `LevelSelectScreen` + `LevelGenerator` exist. Levels are procedurally generated.  
**Missing:**
- No hand-crafted "signature" levels
- No difficulty curve visualization
- No level ratings / community difficulty feedback
- No "mastery" system (replay levels for 3 stars)

**The star system exists but levels are generated — hard to replay specific ones.**

---

## 2. VISUAL POLISH GAPS

### 2A. Theme Store is Bare
**Status:** `ThemeStoreScreen` exists, `GameTheme` model supports it, but only 1 theme (default) is fully defined.  
**What's needed:**
- 5-8 purchasable themes: Neon, Pastel, Earth Tones, Ocean, Sunset, Monochrome, Candy
- Each theme needs: background gradient, block palette (8 colors), block gradients, accent color
- Theme preview animations in store
- "Try before you buy" with 1 free level per theme

**Files:** `lib/models/theme_data.dart` — add theme definitions. `lib/screens/theme_store_screen.dart` — add preview + purchase flow with `CurrencyService`.

### 2B. No Screen Transitions
**Missing:**
- No hero animations between screens
- Home → Game has no transition beyond MaterialPageRoute
- Level complete → next level has no smooth transition

**Fix:** Use `PageRouteBuilder` with `SlideTransition` or `FadeTransition` for key navigation paths. Add shared element transitions for the play button → game board.

### 2C. Celebration Overlay Could Be Richer
**Status:** `CelebrationOverlay` + `ConfettiOverlay` exist.  
**Missing:**
- No particle variation (only confetti, no stars, no sparkles)
- No unique celebration for 3-star completion
- No "new best!" animation for beating par
- No haptic pattern variation (single buzz vs celebration pattern)

### 2D. Empty Slot Visual
**Status:** Empty slots are just colored rectangles.  
**Improvement:** Add subtle animated shimmer/pulse to empty slots to draw attention. Add a faint "ghost" of what color would match there.

---

## 3. MONETIZATION GAPS

### 3A. Ad Strategy
**Status:** `AdService` implemented with banner, interstitial, and rewarded ads. BUT using **test ad unit IDs**.  
**Missing:**
- Production AdMob IDs (BLOCKER for real revenue)
- No rewarded ad integration for: extra hints, extra undo, power-up refill, continue after fail
- Interstitial frequency not tuned (shows every N levels, but N not optimized)
- No ad-free tracking analytics (how many users would pay to remove?)

**Fix:** Replace test IDs. Add rewarded ad option to: fail screen ("Watch ad to get 3 more moves"), hint depletion ("Watch ad for free hint"), power-up shop ("Watch ad for free power-up").

### 3B. IAP Strategy
**Status:** `IapService` has: Remove Ads, Hint Pack (10), Power-Up Packs (5/20/50).  
**Missing:**
- No pricing visible in code (needs Play Store configuration)
- No "starter bundle" (Remove Ads + 500 coins + 5 hints at discount)
- No subscription option (unlimited hints + daily bonus coins)
- No "premium pass" for exclusive themes/content
- Coins can't buy power-ups directly? (only via IAP packs)

**Fix:** Add starter bundle IAP. Allow coin → power-up conversion (e.g., 100 coins = 1 power-up). Add a monthly pass option ($1.99/mo: ad-free + 3 daily power-ups + exclusive theme).

### 3C. Currency Economy Not Balanced
**Status:** `CurrencyService` tracks coins. Daily rewards give 50-500 coins.  
**Missing:**
- No coins earned from gameplay (completing levels, getting stars)
- Only earning path is daily rewards
- Theme prices not defined (all themes have `price = 0` except they should have prices)
- Power-ups can't be bought with coins
- No coin sink besides themes (which are all free)

**Fix:** Award coins for: puzzle completion (10-50 based on stars), streak bonus, zen milestones. Set theme prices: 200-2000 coins. Allow power-up purchase: 50 coins each. This creates: earn → spend → need more → play more / watch ads / IAP.

---

## 4. RETENTION & ENGAGEMENT

### 4A. Daily Challenge Needs More Depth
**Status:** `DailyChallenge` model + service exist. One challenge per day.  
**Improvement:**
- Add 3 difficulty tiers per day (Easy/Medium/Hard) with scaled rewards
- Add weekly challenge (special constraint: no undo, limited moves)
- Show community completion % ("42% of players solved this!")
- Add time-attack variant

### 4B. Streak System Underutilized
**Status:** Daily streak tracked, badge shown.  
**Missing:**
- No escalating multiplier (streak × base reward)
- No milestone rewards (7-day = special theme, 30-day = exclusive power-up)
- No "streak freeze" purchasable with coins
- Streak resets silently — no "save your streak!" push

### 4C. No Session Goals
**Missing:**
- "Solve 5 more puzzles to earn a bonus!"
- "Play 3 levels in a row for a combo bonus!"
- No "quests" or "missions" system
- Zen mode has no goals beyond personal satisfaction

**Fix:** Add `lib/services/mission_service.dart` with 3 rotating daily missions: "Clear 3 levels without hints", "Get 3 stars on any level", "Solve 10 zen puzzles". Reward 50-200 coins each.

### 4D. No Progression Persistence for Zen
**Status:** Zen garden resets every session ("sand mandala" philosophy).  
**Problem:** Players invest time growing the garden then lose it. This is zen... but also frustrating.  
**Compromise:** Add a "Garden Journal" that captures screenshots of your best gardens. Even if the garden resets, the memory persists. Show garden stage milestones achieved across all sessions.

---

## 5. COMPETITIVE ANALYSIS

| Feature | Color Sort / Ball Sort | I Love Hue | Stakd |
|---------|----------------------|-------------|-------|
| Tutorial | ✅ Animated hand, 3 guided levels | ✅ Gentle intro | ⚠️ Basic overlay |
| Daily Challenge | ✅ With leaderboard | ✅ Daily palette | ✅ Exists |
| Rewarded Ads | ✅ Hints, undo, continue | ✅ Skip levels | ❌ Not wired |
| Themes | ✅ 5-10 purchasable | ✅ Beautiful palettes | ❌ Only 1 |
| Social Sharing | ✅ Share completion | ✅ Share palette | ❌ None |
| Achievements | ✅ 30+ achievements | ✅ Collection system | ❌ Model only, 0 defined |
| Push Notifications | ✅ Daily remind | ✅ New content | ❌ None |
| Seasonal Events | ✅ Holiday themes | ✅ Limited palettes | ❌ None |
| Star Rating | ✅ 3-star system | N/A | ✅ Exists |
| Power-ups | ✅ 3-5 types | N/A | ✅ 4 types |
| Zen Mode | ❌ | ❌ | ✅ **UNIQUE advantage** |
| Growing Garden | ❌ | ❌ | ✅ **UNIQUE advantage** |
| Ambient Audio | ❌ | ✅ | ✅ |

**Stakd's unique selling points are zen mode and the growing garden.** No competitor has this. But the table features (achievements, themes, social, notifications) are expected baseline in 2026.

---

## 6. PRIORITY RANKED LIST

| # | Improvement | Impact | Effort | Priority |
|---|------------|--------|--------|----------|
| 1 | **Wire rewarded ads** (hints, undo, continue) | 🔥🔥🔥 | Low (2h) | **DO NOW** |
| 2 | **Production AdMob IDs** | 🔥🔥🔥 | Low (30m) | **DO NOW** |
| 3 | **Add coin rewards for gameplay** (level complete, stars) | 🔥🔥🔥 | Low (1h) | **DO NOW** |
| 4 | **Define 20+ achievements** | 🔥🔥🔥 | Med (3h) | **DO NOW** |
| 5 | **Add 5-8 purchasable themes** with prices | 🔥🔥 | Med (3h) | Soon |
| 6 | **Tutorial upgrade** (animated hand, auto-trigger) | 🔥🔥 | Med (3h) | Soon |
| 7 | **Power-ups purchasable with coins** | 🔥🔥 | Low (1h) | Soon |
| 8 | **Daily missions** (3 rotating goals) | 🔥🔥 | Med (4h) | Soon |
| 9 | **Share button** (completion + zen garden screenshot) | 🔥🔥 | Low (2h) | Soon |
| 10 | **Streak multiplier + milestone rewards** | 🔥🔥 | Low (2h) | Soon |
| 11 | **Rewarded ad for free daily power-up** | 🔥🔥 | Low (1h) | Soon |
| 12 | **Screen transitions** (hero animations) | 🔥 | Med (3h) | Later |
| 13 | **Push notifications** (daily reward, streak) | 🔥 | Med (3h) | Later |
| 14 | **Starter bundle IAP** | 🔥 | Low (2h) | Later |
| 15 | **Seasonal themes** (4 per year) | 🔥 | Med (4h each) | Later |
| 16 | **Daily challenge tiers** (Easy/Med/Hard) | 🔥 | Med (3h) | Later |
| 17 | **Garden Journal** (screenshot memories) | 🔥 | Med (3h) | Later |
| 18 | **Monthly subscription pass** | 🔥 | High (8h) | Later |
| 19 | **Community completion %** for challenges | 💡 | High (6h) | Eventually |
| 20 | **Streak freeze** purchasable item | 💡 | Low (1h) | Eventually |

---

## Quick Wins Summary (< 2 hours each, high impact)

1. ✅ Rewarded ads for hints/undo/continue — **immediate revenue**
2. ✅ Coin rewards on level complete (10 × stars earned)
3. ✅ Power-ups buyable with coins (50 coins each)
4. ✅ Streak multiplier (streak day × base coin reward)
5. ✅ Share button on completion overlay

These 5 changes create the core economy loop: **play → earn coins → spend on themes/power-ups → run out → play more / watch ads / buy IAP**.

---

*Report generated: 2026-02-18*
*Status: Ready for prioritization and execution*
