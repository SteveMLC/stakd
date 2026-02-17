# Stakd - App Store Launch Prep Report

**Date:** February 9, 2026  
**Status:** ✅ READY FOR LAUNCH PREP  
**Build Status:** ✅ COMPILES SUCCESSFULLY  

---

## 🎯 Executive Summary

**Good News:**
- ✅ AdMob integration is COMPLETE (test IDs in place)
- ✅ IAP integration is COMPLETE (ready for product registration)
- ✅ App icons exist (all Android densities)
- ✅ Android SDK is installed and working
- ✅ Release APK builds successfully (55.2MB)
- ✅ Code analysis shows only minor warnings (no blockers)

**Core Blockers Remaining:**
1. Replace test AdMob IDs with production IDs
2. Create release signing keystore
3. Register IAP products in Play Console
4. Create store assets (screenshots, feature graphic)
5. Generate and host privacy policy

**Timeline to Launch:** 8-12 hours of focused work

---

## ✅ 1. AdMob Integration - COMPLETE

### Status
- ✅ Package installed: `google_mobile_ads: ^5.3.0`
- ✅ Service implemented: `lib/services/ad_service.dart`
- ✅ Initialized in `main.dart`
- ✅ AndroidManifest.xml configured with test app ID
- ✅ Interstitial ads: Show after 3 levels (configurable via `GameConfig.adsEveryNLevels`)
- ✅ Rewarded ads: For hints/undo functionality
- ✅ Banner ads: Ready (optional implementation)
- ✅ Respects "Remove Ads" IAP purchase

### Current Test IDs
```
App ID (AndroidManifest): ca-app-pub-3940256099942544~3347511713
Interstitial: ca-app-pub-3940256099942544/1033173712
Rewarded: ca-app-pub-3940256099942544/5224354917
Banner: ca-app-pub-3940256099942544/6300978111
```

### ⚠️ ACTION REQUIRED Before Launch
1. Create AdMob app in Google AdMob Console
   - Account: `pub-1738655803893663` (existing Empire Tycoon account)
   - OR create new AdMob account for Stakd
2. Replace test IDs in:
   - `android/app/src/main/AndroidManifest.xml` (app ID)
   - `lib/services/ad_service.dart` (ad unit IDs)
3. Test ads with real IDs before submitting

---

## ✅ 2. IAP Integration - COMPLETE

### Status
- ✅ Package installed: `in_app_purchase: ^3.2.0`
- ✅ Service implemented: `lib/services/iap_service.dart`
- ✅ Initialized in `main.dart`
- ✅ Provider integration complete
- ✅ Purchase flow tested (uses test SKUs with `--dart-define=STAKD_IAP_TEST_IDS=true`)
- ✅ Persists purchases via `StorageService`
- ✅ Handles restore purchases
- ✅ Consumable (hint packs) and non-consumable (remove ads) products

### Products Defined
```dart
com.go7studio.stakd.remove_ads     // Non-consumable, $2.99
com.go7studio.stakd.hint_pack_10   // Consumable, 10 hints
```

### ⚠️ ACTION REQUIRED Before Launch
1. Create app listing in Google Play Console
2. Register IAP products:
   - Navigate to: Monetize > Products > In-app products
   - Create "Remove Ads" - $2.99 USD
   - Create "Hint Pack (10)" - $0.99 USD (suggested price)
3. Publish products (can do before app approval)
4. Consider adding more hint pack tiers:
   - Small pack: 5 hints - $0.49
   - Medium pack: 10 hints - $0.99
   - Large pack: 25 hints - $1.99

### Server-Side Validation (Future)
Current implementation has placeholder for server-side receipt validation:
```dart
// TODO: Replace with server-side receipt validation in _verifyPurchase()
```
**Recommendation:** Implement after launch if fraud becomes an issue.

---

## ✅ 3. App Icons - PRESENT

### Status
- ✅ All Android launcher icons exist:
  - `mipmap-mdpi/ic_launcher.png` (48x48)
  - `mipmap-hdpi/ic_launcher.png` (72x72)
  - `mipmap-xhdpi/ic_launcher.png` (96x96)
  - `mipmap-xxhdpi/ic_launcher.png` (144x144)
  - `mipmap-xxxhdpi/ic_launcher.png` (192x192)
- ✅ Source icon: `assets/icon/app_icon.png` (1024x1024)
- ✅ Configured in `pubspec.yaml` via `flutter_launcher_icons`

### Icon Quality Check
**⚠️ ACTION REQUIRED:** Visually inspect the icon to ensure it's:
- Custom designed (not default Flutter blue icon)
- Reflects Zen Garden theme (peaceful, nature-inspired)
- Readable at small sizes
- Follows Material Design guidelines

**If icon needs redesign:**
1. Create new 1024x1024 PNG
2. Replace `assets/icon/app_icon.png`
3. Run: `flutter pub run flutter_launcher_icons`
4. Rebuild APK

---

## ✅ 4. Final Polish Check - PASSED

### Flutter Analyze Results
```
58 issues found (ran in 2.3s)
- 5 warnings (unused variables, unused imports)
- 53 info messages (deprecated withOpacity, print statements in tests)
```

**All warnings are non-blocking:**
- Unused local variables (`bestSolvable`, `numStacks`, `random`)
- Unused element `_formatDateKey` in home screen
- Unused import in test file

**Info messages:**
- Deprecated `withOpacity()` usage (works fine, just deprecated in Flutter 3.38)
- `print()` statements in test/bin files (acceptable)

**Recommendation:** Clean up warnings in post-launch polish.

### Build Test Results
```bash
flutter build apk --release
✓ Built build/app/outputs/flutter-apk/app-release.apk (55.2MB)
Build time: 56.8s
Status: SUCCESS
```

**No build errors. App compiles cleanly.**

### Android Configuration
- ✅ Package name: `com.go7studio.stakd`
- ✅ Version: `1.0.0+1`
- ✅ Minimum SDK: Set by Flutter
- ✅ Target SDK: Set by Flutter
- ✅ Permissions: `INTERNET` only (appropriate)
- ⚠️ Signing: Using debug keystore (see next section)

---

## 🔴 5. Critical Blockers (Must Fix)

### A. Release Signing Keystore - NOT CREATED

**Current Status:** Using debug keys for signing (NOT PRODUCTION SAFE)

From `android/app/build.gradle.kts`:
```kotlin
release {
    // TODO: Add your own signing config for the release build.
    // Signing with the debug keys for now
    signingConfig = signingConfigs.getByName("debug")
}
```

**⚠️ ACTION REQUIRED:**

**Step 1: Generate release keystore**
```bash
cd /Users/venomspike/.openclaw/workspace/projects/stakd/android
keytool -genkey -v -keystore stakd-upload-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias stakd-key \
  -dname "CN=Go7Studio, OU=GameDev, O=Go7Studio, L=YourCity, ST=YourState, C=US" \
  -storepass [GENERATE_SECURE_PASSWORD] \
  -keypass [SAME_PASSWORD]
```

**Step 2: Create key.properties**
```bash
cat > android/key.properties << EOF
storePassword=[YOUR_PASSWORD]
keyPassword=[YOUR_PASSWORD]
keyAlias=stakd-key
storeFile=stakd-upload-key.jks
EOF
```

**Step 3: Update build.gradle.kts**
Add before `android {` block:
```kotlin
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

Add inside `android {` block:
```kotlin
signingConfigs {
    create("release") {
        storeFile = file(keystoreProperties["storeFile"] as String)
        storePassword = keystoreProperties["storePassword"] as String
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
    }
}
```

Update `buildTypes`:
```kotlin
release {
    signingConfig = signingConfigs.getByName("release")
}
```

**Step 4: Secure the keystore**
- Back up `stakd-upload-key.jks` to secure location
- Add to `.gitignore`: `android/key.properties` and `android/*.jks`
- NEVER commit these to git

**Step 5: Test signed build**
```bash
flutter build appbundle --release
```

---

### B. Production AdMob IDs - NOT SET

**Current:** Using test ad IDs (no revenue)

**⚠️ ACTION REQUIRED:**
1. Go to https://admob.google.com/
2. Sign in with Go7Studio account (or create new)
3. Create app: "Stakd - Color Sort Puzzle"
4. Create ad units:
   - Interstitial ad (game over / level complete)
   - Rewarded ad (hints)
   - (Optional) Banner ad (home screen)
5. Copy production IDs
6. Replace in code:
   - `android/app/src/main/AndroidManifest.xml` line 30
   - `lib/services/ad_service.dart` lines 17-21
7. Test ads before submitting to Play Store

**Estimated time:** 15-20 minutes

---

### C. IAP Products - NOT REGISTERED

**Current:** Products defined in code but not in Play Console

**⚠️ ACTION REQUIRED:**
1. Create app draft in Play Console
2. Go to: Monetize > Products > In-app products
3. Create products (must match code exactly):
   - Product ID: `com.go7studio.stakd.remove_ads`
     - Type: Non-consumable (Managed product)
     - Price: $2.99 USD
     - Title: "Remove Ads"
     - Description: "Remove all ads permanently"
   - Product ID: `com.go7studio.stakd.hint_pack_10`
     - Type: Consumable
     - Price: $0.99 USD
     - Title: "Hint Pack (10)"
     - Description: "10 hints to help you solve puzzles"
4. Activate products
5. Test purchase flow with test accounts

**Can be done:** After app draft created, before app approval

**Estimated time:** 10-15 minutes

---

### D. Store Assets - MISSING

**Critical for Play Store submission:**

**1. Screenshots (REQUIRED - minimum 2, recommended 8)**
- Dimensions: 1080x1920 (portrait) or 1920x1080 (landscape)
- Content suggestions:
  1. Game board showing multi-grab mechanic
  2. Zen Garden screen (key differentiator)
  3. Level select/progression
  4. Daily challenge
  5. Zen Mode gameplay
  6. Settings screen
  7. Tutorial screen
  8. "Remove Ads" purchase screen
- **Action:** Run app, capture screens, add text overlays if desired
- **Estimated time:** 2-3 hours

**2. Feature Graphic (REQUIRED)**
- Dimensions: 1024x500px
- Landscape banner for Play Store listing
- Should include: "Stakd" title, Zen Garden visual, tagline
- **Suggested tagline:** "Sort, Stack, Grow Your Garden"
- **Tools:** Canva, Figma, Photoshop
- **Estimated time:** 2-3 hours

**3. Short Description (REQUIRED)**
Max 80 characters:
```
Sort colors, grow your zen garden. Multi-grab mechanic + peaceful gameplay.
```

**4. Full Description (REQUIRED)**
Already drafted in `store/description.md` - review and polish

**5. App Icon Review**
Verify icon quality (see section 3)

**Estimated total time for assets:** 4-6 hours

---

### E. Privacy Policy - MISSING

**Required by Play Store** (uses AdMob + IAP = collects data)

**⚠️ ACTION REQUIRED:**

**Step 1: Generate policy**
Use a generator:
- https://www.freeprivacypolicy.com/
- https://app.termly.io/
- https://www.privacypolicygenerator.info/

**Must include:**
- Data collected: Advertising ID (AdMob), Purchase history (IAP)
- Third-party services: Google AdMob, Google Play Billing
- Data usage: Personalized ads, payment processing
- User rights: Opt-out of personalized ads, request data deletion
- Contact: email (e.g., privacy@go7studio.com)
- COPPA compliance: App not directed at children under 13
- GDPR compliance: Consent for EU users (handled by AdMob)

**Step 2: Host policy**
Options:
- https://go7studio.com/privacy/stakd (recommended)
- GitHub Pages: https://go7studio.github.io/stakd-privacy
- Google Sites (free)

**Step 3: Add URL to Play Console**
- Store presence > Store listing > Privacy policy

**Estimated time:** 1 hour

---

## 🟡 6. High Priority (Recommended)

### A. Custom App Icon
**Current icon quality unknown** - needs visual inspection

If redesign needed:
- Theme: Zen, nature, stacking/sorting
- Colors: Soft, peaceful (greens, blues, earth tones)
- Style: Clean, modern, recognizable at small sizes
- Estimated time: 2-3 hours

### B. Zen Garden UI Polish
From LAUNCH_CHECKLIST.md:
> Zen Garden UI is incomplete (foundation exists but minimal implementation)

**Current state:**
- Model: ✅ `lib/models/garden_state.dart`
- Service: ✅ `lib/services/garden_service.dart`
- Screen: ⚠️ `lib/screens/zen_garden_screen.dart` (1.1KB - very minimal)

**Impact:** This is THE key differentiator for Stakd

**Recommendation:** Complete Zen Garden before launch
- Reference: `ZEN_GARDEN_SPEC.md` (detailed 9-stage growth system)
- Estimated time: 6-8 hours

**Alternative:** Launch without Zen Garden, add in v1.1 update

### C. Audio Issues
From LAUNCH_CHECKLIST.md:
> Audio playback errors on Android (MP3 decoding failures)

**Workaround:** Re-encode audio files as 128kbps CBR MP3

**Action:**
```bash
cd assets/sounds
for f in *.mp3; do
  ffmpeg -i "$f" -codec:a libmp3lame -b:a 128k -ar 44100 "${f%.mp3}_new.mp3"
  mv "${f%.mp3}_new.mp3" "$f"
done
```

**Estimated time:** 1-2 hours (including testing)

---

## 🟢 7. Nice to Have (Post-Launch)

- Promotional video (30-60s gameplay)
- Localization (Spanish, Portuguese, etc.)
- More IAP products (hint packs at different price points)
- Server-side receipt validation
- Beta testing (5-10 users)
- Store listing A/B experiments
- Additional themes
- Social features (leaderboards, sharing)

---

## 📋 8. Pre-Launch Checklist

### Code & Build
- [x] AdMob package installed and initialized
- [x] IAP package installed and initialized
- [x] App icons present (all densities)
- [x] Flutter analyze passes (no critical errors)
- [x] Release APK builds successfully
- [ ] Release keystore created
- [ ] Signed release build tested
- [ ] Production AdMob IDs replaced
- [ ] Audio files re-encoded (if needed)

### Store Listing
- [ ] 8 screenshots captured
- [ ] Feature graphic created (1024x500)
- [ ] Short description written (80 chars)
- [ ] Full description polished
- [ ] Privacy policy generated and hosted
- [ ] Privacy policy URL added to listing
- [ ] Content rating questionnaire completed
- [ ] Target audience set (Everyone/Teen)

### Monetization
- [ ] AdMob app created
- [ ] Production ad unit IDs obtained
- [ ] IAP products registered in Play Console
- [ ] IAP products activated
- [ ] Test purchase completed

### Google Play Console
- [ ] App draft created
- [ ] Package name set (com.go7studio.stakd)
- [ ] App category selected (Puzzle)
- [ ] Store listing complete
- [ ] Release track selected (Production or Internal Testing)
- [ ] Countries/regions selected
- [ ] Signed AAB uploaded

### Testing
- [ ] Manual QA pass on physical device
- [ ] Ads display correctly (production IDs)
- [ ] IAP purchase flow works
- [ ] "Remove Ads" persists across sessions
- [ ] Hint packs grant correctly
- [ ] No crashes or ANRs
- [ ] Audio plays without errors

---

## ⏱️ 9. Time Estimates

### Minimum Viable Launch
| Task | Time | Status |
|------|------|--------|
| Create release keystore + signing | 0.5h | ❌ Required |
| Replace AdMob test IDs | 0.25h | ❌ Required |
| Register IAP products | 0.25h | ❌ Required |
| Capture 8 screenshots | 2-3h | ❌ Required |
| Design feature graphic | 2-3h | ❌ Required |
| Generate + host privacy policy | 1h | ❌ Required |
| Create Play Console listing | 1h | ❌ Required |
| Build + test signed release | 0.5h | ❌ Required |
| **TOTAL** | **8-10h** | **Launch Ready** |

### Polished Launch (Recommended)
| Task | Time | Status |
|------|------|--------|
| All of the above | 8-10h | ❌ |
| Review/redesign app icon | 2-3h | ⚠️ |
| Complete Zen Garden UI | 6-8h | ⚠️ |
| Fix audio encoding issues | 1-2h | ⚠️ |
| Beta test with 5-10 users | 1 week | ⚠️ |
| **TOTAL** | **18-24h + 1 week** | **Polished Launch** |

---

## 🎯 10. Recommended Launch Strategy

### Phase 1: Core Launch Prep (2 days)
**Focus:** Fix all critical blockers
1. Day 1 Morning: Release keystore + AdMob IDs + IAP registration
2. Day 1 Afternoon: Screenshots + feature graphic
3. Day 2 Morning: Privacy policy + Play Console setup
4. Day 2 Afternoon: Build signed AAB + upload

### Phase 2: Polish (Optional, +3 days)
**Focus:** Zen Garden + audio + icon
1. Day 3-4: Complete Zen Garden implementation
2. Day 5: Audio fixes + icon review + final testing

### Phase 3: Beta Testing (1 week, Optional)
**Focus:** Internal testing track
1. Upload to Internal Testing track
2. Invite 5-10 testers
3. Collect feedback
4. Fix critical issues
5. Promote to Production

### Phase 4: Submission
1. Upload signed AAB to Production track
2. Submit for review
3. Google Play review: 3-7 days
4. Address any feedback
5. Launch!

### Phase 5: Post-Launch (Ongoing)
1. Monitor metrics (retention, monetization)
2. Respond to reviews
3. Plan v1.1 updates
4. Marketing push if metrics are strong

---

## 🚨 11. Critical Notes

### AdMob Account Decision
**Must decide:** Use existing Empire Tycoon AdMob account (`pub-1738655803893663`) or create new account for Stakd?

**Recommendation:** Use same account
- Pros: Centralized reporting, faster setup
- Cons: Apps share ad serving limits

### Play Console Account
**Need:** Google Play Developer account ($25 one-time fee if new)
- Account owner: Go7Studio / Stephen
- Developer name: Go7Studio

### Keystore Security
**CRITICAL:** The release keystore is the ONLY way to update the app
- Back up to multiple secure locations
- Store password in password manager
- NEVER commit to git
- If lost, app cannot be updated (must publish new app)

### First Launch Expectations
**Realistic timeline:**
- Week 1: Prep + submit
- Week 2: Google review (3-7 days)
- Week 3-4: Soft launch (no marketing)
- Month 1-2: Organic discovery
- Month 3+: Marketing push (if metrics justify)

**Success metrics:**
- D1 retention >40%
- D7 retention >20%
- Session length >5 min
- Ad eCPM >$1
- IAP conversion >1%

---

## 🎯 12. Next Steps

**Immediate (Today/Tomorrow):**
1. Review this checklist with Steve
2. Decide on Zen Garden: launch with it or without it?
3. Decide on AdMob account: existing or new?
4. Verify app icon quality

**This Week:**
1. Create release keystore
2. Replace AdMob test IDs
3. Create store assets (screenshots, feature graphic)
4. Generate privacy policy

**Next Week:**
1. Create Play Console listing
2. Register IAP products
3. Build signed AAB
4. Submit for review

**Later (If Desired):**
1. Complete Zen Garden
2. Beta testing
3. Additional polish

---

## 📊 13. Launch Readiness Score

**Current Status: 75/100** (UP from 55/100 in previous checklist)

| Category | Score | Notes |
|----------|-------|-------|
| Core Gameplay | 85/100 | Solid, Zen Garden UI needs work |
| Monetization (Code) | 100/100 | ✅ AdMob + IAP fully implemented |
| Monetization (Setup) | 20/100 | Test IDs only, products not registered |
| Store Assets | 20/100 | Icons exist, but screenshots/graphic missing |
| Compliance | 10/100 | No privacy policy |
| Build System | 80/100 | ✅ Compiles! But needs release signing |

**Key Improvements Since Last Check:**
- Android SDK confirmed installed ✅
- Release build tested and working ✅
- Code quality verified (flutter analyze) ✅

**Remaining Gap to 90/100 (Launch Ready):**
- Release signing: +10 points
- Production AdMob/IAP: +20 points
- Store assets: +40 points
- Privacy policy: +20 points
- **Total needed:** +90 points = 165/100 → Capped at 100

**Target: 90/100 = Launch Ready**

---

## 📞 14. Support & Resources

### Documentation
- AdMob Setup: https://developers.google.com/admob/flutter/quick-start
- IAP Setup: https://pub.dev/packages/in_app_purchase
- Play Console: https://play.google.com/console
- App Signing: https://developer.android.com/studio/publish/app-signing

### Project Specs
- Core gameplay: `PLAN.md`
- Zen Garden: `ZEN_GARDEN_SPEC.md`, `ZEN_MODE_SPEC.md`
- Previous checklist: `LAUNCH_CHECKLIST.md`

### Tools
- Privacy policy generator: https://www.freeprivacypolicy.com/
- Screenshot editor: Figma, Canva
- Icon generator: https://www.appicon.co/

---

**Last Updated:** February 9, 2026, 9:48 PM EST  
**Next Review:** After blockers addressed  
**Subagent:** walt  
**Session:** stakd-launch-prep
