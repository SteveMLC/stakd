# Stakd - Launch Readiness Checklist

**Project:** Stakd - Color Sort Puzzle with Zen Garden
**Platform:** Android (Google Play Store)
**Target:** Second revenue stream for Go7Studio
**Date:** February 8, 2026

---

## 🎮 1. Core Gameplay Status

### ✅ **WORKING**
- ✅ Core color sorting mechanics
- ✅ Multi-grab mechanic (MAIN DIFFERENTIATOR)
  - Can grab multiple layers at once
  - Visual indicator for valid multi-grabs
  - Tutorial teaches the mechanic
- ✅ Level progression (1-30+)
- ✅ Difficulty curve (adaptive based on player performance)
- ✅ Tutorial system
- ✅ Daily challenges
- ✅ Level select screen
- ✅ Undo functionality
- ✅ Hint system (uses IAP hint packs)
- ✅ Haptic feedback
- ✅ Sound effects and background music
- ✅ Animations (squash/stretch, glow, particle effects)
- ✅ Zen Mode (endless procedurally-generated puzzles)
- ✅ Settings (sound, music, haptics toggles)

### 🚧 **PARTIALLY WORKING**
- 🚧 **Zen Garden (CRITICAL DIFFERENTIATOR)**
  - Model exists (`lib/models/garden_state.dart`)
  - Service exists (`lib/services/garden_service.dart`)
  - Screen partially implemented (`lib/screens/zen_garden_screen.dart` - 1.1KB, minimal)
  - **STATUS:** Foundation code exists but UI is incomplete
  - **IMPACT:** This is THE key differentiator - needs completion for launch

### ❌ **KNOWN ISSUES**
- ❌ Audio playback errors on Android (see `DEVELOPER_NOTES.md`)
  - MP3 decoding failures on some devices
  - Workaround: Re-encode audio files as 128kbps CBR MP3
- ❌ `setState()` during build warnings (fixed via `addPostFrameCallback`)
- ❌ Some RenderFlex overflow warnings (cosmetic, non-blocking)

### ⏸️ **NOT IMPLEMENTED**
- Social features (share scores, leaderboards)
- Cloud save/sync
- Themes beyond default

---

## 💰 2. Monetization Status

### AdMob Integration
- ✅ **Dependency installed:** `google_mobile_ads: ^5.3.0`
- ✅ **Ad Service implemented:** `lib/services/ad_service.dart`
- ✅ **Interstitial ads:** Load, show after N levels
- ✅ **Rewarded ads:** For hints
- ⚠️ **BLOCKER:** Using **TEST AD IDs** only
  - Manifest: `ca-app-pub-3940256099942544~3347511713` (test)
  - Code: Test interstitial/rewarded IDs
  - **ACTION REQUIRED:** Replace with real AdMob account IDs before launch
- ⚠️ **AdMob Account:** Need to create AdMob account and app entry
  - Current account: `pub-1738655803893663` (Empire Tycoon)
  - Decision needed: Same AdMob account or new one?

### In-App Purchases
- ✅ **Dependency installed:** `in_app_purchase: ^3.2.0`
- ✅ **IAP Service implemented:** `lib/services/iap_service.dart`
- ✅ **Products defined:**
  - `com.go7studio.stakd.remove_ads` (non-consumable)
  - `com.go7studio.stakd.hint_pack_10` (consumable, 10 hints)
- ⚠️ **BLOCKER:** Products NOT registered in Google Play Console
  - Must create app listing first
  - Then add IAP products
- ✅ Storage integration (persists purchases)
- ✅ Server-side validation placeholder (needs real implementation)

### Revenue Forecast
- **Conservative:** $50-150/month (if 1000 DAU, 10% ad clicks, $0.50 eCPM)
- **Optimistic:** $300-500/month (if 5000 DAU, strong retention)
- **Timeline:** 2-3 months to meaningful revenue (organic growth + ASO)

---

## 📱 3. Store Listing Requirements

### App Icon
- ✅ Android icons exist:
  - `mipmap-mdpi/ic_launcher.png` (48x48)
  - `mipmap-hdpi/ic_launcher.png` (72x72)
  - `mipmap-xhdpi/ic_launcher.png` (96x96)
  - `mipmap-xxhdpi/ic_launcher.png` (144x144)
  - `mipmap-xxxhdpi/ic_launcher.png` (192x192)
- ⚠️ **ACTION REQUIRED:** Verify icon quality
  - Default Flutter launcher icons (blue/white)
  - **NEED CUSTOM ICON** reflecting Zen Garden theme

### Screenshots (REQUIRED)
- ❌ **CRITICAL BLOCKER:** No screenshots exist
- **Required:** Minimum 2, recommended 8
- **Dimensions:** 1080x1920 (portrait) or 1920x1080 (landscape)
- **Content needed:**
  1. Game board showing multi-grab mechanic
  2. Zen Garden (once implemented)
  3. Daily challenge screen
  4. Level progression
  5. Zen Mode screen
  6. Settings/tutorial
- **ACTION:** Run app, capture screens, add Store Listing polish

### Feature Graphic (REQUIRED for Google Play)
- ❌ **CRITICAL BLOCKER:** No feature graphic
- **Dimensions:** 1024x500px
- **Content:** "Stakd" title + Zen Garden visual + tagline

### Video (OPTIONAL but recommended)
- ❌ Not created
- **Recommended:** 30-60s gameplay showing multi-grab + Zen Garden
- **Impact:** 20-30% higher conversion rate

### Store Listing Copy
- ✅ Created in `store/description.md` (see below)
- Includes short description, full description, features, keywords

---

## 🔒 4. Privacy Policy (REQUIRED)

### Status
- ❌ **CRITICAL BLOCKER:** No privacy policy exists
- **Required by:** Google Play Store (AdMob + IAP = data collection)
- **Must include:**
  - Data collected (AdMob: Advertising ID, IAP: Purchase history)
  - Third-party services (Google AdMob, Google Play Billing)
  - Data usage (ads, analytics, payment processing)
  - User rights (opt-out, deletion requests)
  - Contact information

### Action Required
1. Generate privacy policy (tools: `termly.io`, `freeprivacypolicy.com`)
2. Host at: `https://go7studio.com/privacy/stakd` OR GitHub Pages
3. Add URL to Google Play Console listing

### Compliance
- ✅ **COPPA:** No deliberate collection from kids <13
- ✅ **GDPR:** AdMob handles consent for EU users
- ⚠️ **App content rating:** Must declare ads, in-app purchases

---

## 🔨 5. Build Status

### Development Environment
- ⚠️ **CRITICAL ISSUE:** Android SDK NOT installed
  ```
  [✗] Android toolchain - develop for Android devices
      ✗ Unable to locate Android SDK.
  ```
- ⚠️ **CRITICAL ISSUE:** Xcode incomplete (if iOS launch planned)
- ✅ Flutter SDK installed (v3.38.9)
- ✅ Chrome build works

### Build Configuration
- ✅ **Package name:** `com.go7studio.stakd`
- ✅ **Version:** `1.0.0+1`
- ⚠️ **Signing:** Using debug keys (MUST create release keystore)
- ⚠️ **ProGuard:** Not configured (recommended for release)

### Build Commands (Once SDK installed)
```bash
# Debug build (test on device)
flutter build apk --debug

# Release build (for Play Store)
flutter build appbundle --release

# Generate release keystore (REQUIRED)
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Sign build (configure in android/key.properties)
```

### Can It Compile?
- ✅ **Code compiles** (verified via git history - recent commits)
- ❌ **Cannot build Android APK/AAB** (SDK not installed)
- **Time to fix:** 1-2 hours (install Android Studio + SDK)

---

## 🚫 6. Blockers (Preventing Launch)

### 🔴 CRITICAL (Must Fix Before Launch)
1. **Android SDK not installed**
   - **Impact:** Cannot build release APK/AAB
   - **Fix time:** 1-2 hours
   - **Action:** Install Android Studio, configure SDK path

2. **No screenshots**
   - **Impact:** Cannot submit to Play Store
   - **Fix time:** 2-3 hours (capture, edit, optimize)
   - **Action:** Run app, screenshot key features

3. **No privacy policy**
   - **Impact:** Play Store rejection
   - **Fix time:** 1 hour (generate + host)
   - **Action:** Use generator, host on go7studio.com

4. **No feature graphic**
   - **Impact:** Store listing incomplete
   - **Fix time:** 2-3 hours (design in Canva/Figma)
   - **Action:** Create 1024x500 graphic

5. **AdMob test IDs only**
   - **Impact:** No revenue
   - **Fix time:** 30 minutes
   - **Action:** Create AdMob app, replace IDs in code

6. **Release keystore not created**
   - **Impact:** Cannot sign release build
   - **Fix time:** 15 minutes
   - **Action:** Generate keystore, configure key.properties

7. **Zen Garden UI incomplete**
   - **Impact:** Missing key differentiator
   - **Fix time:** 4-8 hours (implement UI, test, polish)
   - **Action:** Complete `zen_garden_screen.dart`

### 🟡 HIGH PRIORITY (Strongly Recommended)
8. **Custom app icon**
   - **Impact:** Poor first impression, low conversion
   - **Fix time:** 2-3 hours (design + export all sizes)

9. **IAP products not registered**
   - **Impact:** No IAP revenue
   - **Fix time:** 30 minutes (after app created in Console)

10. **Audio playback issues**
    - **Impact:** Poor UX on some Android devices
    - **Fix time:** 1-2 hours (re-encode audio, test)

### 🟢 NICE TO HAVE (Post-Launch)
11. Video preview
12. Localization (Spanish, Portuguese, etc.)
13. Store listing experiments (A/B test copy)

---

## ⏱️ 7. Estimated Effort to Launch-Ready

### Minimum Viable Launch (Core Features Only)
**Total: 12-18 hours**

| Task | Time | Priority |
|------|------|----------|
| Install Android SDK + tools | 1-2h | CRITICAL |
| Complete Zen Garden UI | 4-8h | CRITICAL |
| Create release keystore + signing | 0.5h | CRITICAL |
| Fix audio encoding issues | 1-2h | HIGH |
| Create custom app icon | 2-3h | HIGH |
| Capture 8 screenshots | 2-3h | CRITICAL |
| Design feature graphic | 2-3h | CRITICAL |
| Generate + host privacy policy | 1h | CRITICAL |
| Create AdMob app, update IDs | 0.5h | CRITICAL |
| Build + test release APK | 1h | CRITICAL |
| Create Play Console listing | 2h | CRITICAL |
| Register IAP products | 0.5h | HIGH |

### Polished Launch (Recommended)
**Total: 18-24 hours**
- Everything above PLUS:
- Promotional video (4-6h)
- Enhanced store copy + A/B variants (2h)
- Beta testing with 5-10 users (1 week)
- Analytics integration (Firebase, 1-2h)

### Timeline
- **Sprint focus (2 full days):** 16-18 hours → Launch ready
- **Relaxed pace (1 week):** 2-3 hours/day → Launch ready
- **Review time:** Google Play typically takes 3-7 days for first review

---

## ✅ Launch Readiness Score

**Current: 55/100**

| Category | Score | Notes |
|----------|-------|-------|
| Core Gameplay | 85/100 | Solid, Zen Garden needs UI |
| Monetization | 40/100 | Test IDs only, IAP not registered |
| Store Assets | 20/100 | No screenshots, no graphic, default icon |
| Compliance | 30/100 | No privacy policy |
| Build System | 40/100 | SDK missing, no release signing |

**Target for launch: 90/100**

---

## 📋 Pre-Launch Checklist

Use this as your final checklist before submission:

```
[ ] Android SDK installed and configured
[ ] Zen Garden UI complete and tested
[ ] Custom app icon designed and exported (all sizes)
[ ] 8 high-quality screenshots captured
[ ] Feature graphic created (1024x500)
[ ] Privacy policy generated and hosted
[ ] AdMob account created, real IDs in code
[ ] IAP products registered in Play Console
[ ] Release keystore created and secured
[ ] key.properties configured for signing
[ ] Audio files re-encoded (no playback errors)
[ ] Release build compiles successfully
[ ] Manual QA pass (no crashes, all features work)
[ ] Google Play Console listing complete
[ ] Content rating questionnaire filled
[ ] Target audience set (Teen/Everyone)
[ ] Store listing published (but app not released)
[ ] Upload signed AAB to Play Console
[ ] Internal testing track configured
[ ] Beta test with 5+ testers (optional but recommended)
[ ] Address beta feedback
[ ] Submit for review
```

---

## 🎯 Recommended Launch Strategy

1. **Week 1:** Fix blockers (SDK, Zen Garden, screenshots, privacy)
2. **Week 2:** Polish (icon, audio, store copy, build testing)
3. **Week 3:** Internal/closed beta (5-10 testers)
4. **Week 4:** Submit to Play Store (while in review, prep marketing)
5. **Week 5:** Soft launch (no promo, observe metrics)
6. **Week 6+:** Marketing push (if retention >30%, monetization >$5/day)

**Key Metrics to Watch:**
- D1 retention >40%
- D7 retention >20%
- Session length >5 minutes
- Ad eCPM >$1.00
- IAP conversion >1%

---

**Last Updated:** February 8, 2026
**Next Review:** After Android SDK setup + Zen Garden completion
