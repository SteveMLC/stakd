# Stakd - Launch Action Plan

**Goal:** Get Stakd from current state (55/100 readiness) to Play Store submission (90/100+)
**Timeline:** 2-3 weeks (16-24 hours total effort)
**Priority:** Second revenue stream for Go7Studio

---

## Week 1: Fix Critical Blockers (12-14 hours)

### Day 1-2: Development Environment Setup (2-3 hours)

**Task 1.1: Install Android SDK**
```bash
# Download Android Studio
# URL: https://developer.android.com/studio

# Install via Homebrew (macOS)
brew install --cask android-studio

# Launch Android Studio
# Tools > SDK Manager > Install:
# - Android SDK Platform 34 (latest)
# - Android SDK Build-Tools
# - Android Emulator
# - Android SDK Platform-Tools

# Configure Flutter
flutter config --android-sdk /Users/venomspike/Library/Android/sdk

# Verify
flutter doctor
```

**Expected outcome:** `flutter doctor` shows Android toolchain ✅

**Task 1.2: Create Release Keystore**
```bash
cd ~/
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload

# IMPORTANT: Save password securely (1Password, etc.)
# Store keystore in safe location (NOT in git repo)

# Create key.properties
cat > /Users/venomspike/.openclaw/workspace/projects/stakd/android/key.properties << EOF
storePassword=YOUR_PASSWORD_HERE
keyPassword=YOUR_PASSWORD_HERE
keyAlias=upload
storeFile=/Users/venomspike/upload-keystore.jks
EOF

# Add key.properties to .gitignore
echo "android/key.properties" >> /Users/venomspike/.openclaw/workspace/projects/stakd/.gitignore
```

**Expected outcome:** Keystore created, key.properties configured

**Task 1.3: Configure Gradle for Signing**

Edit `/Users/venomspike/.openclaw/workspace/projects/stakd/android/app/build.gradle.kts`:

```kotlin
// Add before android { block
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = java.util.Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing config ...
    
    // Add signing configs BEFORE buildTypes
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Add ProGuard for optimization
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

**Expected outcome:** `flutter build appbundle --release` succeeds

---

### Day 3-5: Complete Zen Garden UI (6-8 hours)

**Current Status:**
- Model exists ✅ (`lib/models/garden_state.dart`)
- Service exists ✅ (`lib/services/garden_service.dart`)
- Screen stub exists ⚠️ (`lib/screens/zen_garden_screen.dart` - minimal)

**Task 2.1: Implement Zen Garden Screen UI**

Required elements:
1. **Garden Canvas**
   - Visual representation of garden stage (0-9)
   - Background that evolves with stage
   - Animated elements (swaying bamboo, rippling water)

2. **Progress Indicator**
   - Show current stage name ("Empty Canvas" → "Infinite")
   - Progress bar to next stage
   - Puzzle count display

3. **Unlocked Elements Grid**
   - Show all unlocked garden elements
   - Icon/thumbnail for each
   - Unlock animation when new element appears

4. **Back to Game Button**

**Visual Design Strategy:**
- **Stage 0 (Empty Canvas):** Gray/barren landscape, single small plant
- **Stage 1-3:** Grass appears, small stones, first flowers
- **Stage 4-6:** Bamboo, water features, cherry blossoms
- **Stage 7-9:** Full garden with koi pond, stone paths, lanterns, seasonal effects

**Implementation Approach:**
```dart
// Pseudocode structure
class ZenGardenScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<GardenState>(
      builder: (context, garden, child) {
        return Scaffold(
          body: Stack(
            children: [
              // Background gradient based on stage
              _buildBackground(garden.currentStage),
              
              // Garden elements (layered)
              _buildGardenElements(garden),
              
              // Overlay UI
              _buildOverlay(garden),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildGardenElements(GardenState garden) {
    // Render unlocked elements based on garden.unlockedElements
    // Animate elements gently (sway, glow, ripple)
  }
}
```

**Assets Needed:**
- Garden element icons (use Flutter built-in Icons or simple shapes)
- Background gradients (programmatic via `LinearGradient`)
- Consider using `flutter_svg` for scalable garden assets if time allows

**Time estimate:** 4-6 hours

**Task 2.2: Integrate Garden with Zen Mode**

Current code shows garden is used as background in Zen Mode (`zen_mode_screen.dart`):
```dart
// Verify this integration works
// Garden should visibly grow as puzzles are solved in Zen Mode
```

**Test checklist:**
- [ ] Solve 5 puzzles in Zen Mode → Garden progresses to Stage 1
- [ ] New elements appear in garden
- [ ] Progress bar updates
- [ ] Garden persists after closing app

**Time estimate:** 1-2 hours

---

### Day 6: Audio & Polish (2-3 hours)

**Task 3.1: Fix Audio Playback Issues**

Issue: MP3 decoding failures on Android (see `DEVELOPER_NOTES.md`)

**Solution:**
```bash
cd /Users/venomspike/.openclaw/workspace/projects/stakd/assets/sounds

# Re-encode all MP3s as 128kbps CBR
for file in *.mp3; do
  ffmpeg -i "$file" -codec:a libmp3lame -b:a 128k -ar 48000 "${file%.mp3}_new.mp3"
  mv "${file%.mp3}_new.mp3" "$file"
done

# Or use online converter: https://audio.online-convert.com/convert-to-mp3
```

**Alternative:** Switch to OGG Vorbis (better Android compatibility)
```bash
for file in *.mp3; do
  ffmpeg -i "$file" -codec:a libvorbis -qscale:a 5 "${file%.mp3}.ogg"
done

# Update audio_service.dart to use .ogg files
```

**Test:** Run on Android emulator, verify all sounds play without errors

**Time estimate:** 1-2 hours

**Task 3.2: UI Polish Pass**

Quick fixes:
- [ ] Fix RenderFlex overflow warnings (wrap in `SingleChildScrollView`)
- [ ] Add loading state to Zen Mode puzzle generation
- [ ] Ensure all buttons have haptic feedback
- [ ] Test on different screen sizes (tablet, small phone)

**Time estimate:** 1 hour

---

## Week 2: Store Assets & Monetization (8-10 hours)

### Day 7-8: Create Store Assets (6-8 hours)

**Task 4.1: Design Custom App Icon (2-3 hours)**

**Concept:** Zen Garden theme (not generic color tubes)

**Design options:**
1. **Minimalist Garden:** Bamboo stalks + colored stones
2. **Hybrid:** Color-sorted tubes + bamboo leaves background
3. **Zen Circle:** Enso circle with color gradient inside

**Tools:**
- Figma (free): https://figma.com
- Canva (free templates): https://canva.com
- Icon generator: https://www.appicon.co/

**Deliverables:**
- 1024x1024 master icon (PNG, transparent if applicable)
- Android adaptive icon (foreground + background)

**Export script:**
```bash
# Use Android Asset Studio
# https://romannurik.github.io/AndroidAssetStudio/icons-launcher.html

# Or manual export:
# - mipmap-mdpi: 48x48
# - mipmap-hdpi: 72x72
# - mipmap-xhdpi: 96x96
# - mipmap-xxhdpi: 144x144
# - mipmap-xxxhdpi: 192x192
```

**Time estimate:** 2-3 hours

---

**Task 4.2: Capture Screenshots (2-3 hours)**

**Setup:**
1. Build app in release mode
2. Run on emulator (1080x1920 resolution)
3. Set up game state for best visuals

**Screenshot list (8 total):**

1. **Zen Garden (Stage 5+)** ← Hero shot
   - Caption: "Your Puzzle, Your Garden"
   - Show evolved garden with multiple elements

2. **Multi-Grab Mechanic**
   - Caption: "Grab Multiple Layers at Once"
   - Annotate with arrows/highlights

3. **Game Board Mid-Puzzle**
   - Caption: "Relaxing Color Sorting Gameplay"
   - Show juicy animations/effects

4. **Zen Mode Screen**
   - Caption: "Endless Puzzles, Infinite Zen"
   - Show counter/difficulty

5. **Daily Challenge**
   - Caption: "New Challenge Every Day"
   - Show calendar/reward

6. **Level Complete Celebration**
   - Caption: "Satisfying Animations & Haptics"
   - Show particle effects

7. **Garden Progress**
   - Caption: "Watch Your Garden Grow"
   - Show progression stages 0 → 5

8. **Settings Screen**
   - Caption: "Customize Your Experience"
   - Show toggles (sound, haptics, etc.)

**Tools:**
```bash
# Capture via emulator
# Android Studio > Emulator > Screenshot button

# Or via ADB
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png

# Add captions in Figma/Canva
# Template size: 1080x1920
# Font: Clean, readable (Poppins, Inter, Roboto)
# Colors: Match game palette
```

**Time estimate:** 2-3 hours

---

**Task 4.3: Design Feature Graphic (2 hours)**

**Dimensions:** 1024x500px
**Required for:** Google Play Store

**Content:**
- App name: "Stakd"
- Tagline: "Zen Garden Puzzle" or "Sort Colors, Grow Your Garden"
- Visual: Split-screen → game board + Zen garden
- Style: Match app's color palette

**Tools:**
- Canva template: Search "Google Play feature graphic"
- Figma

**Example layout:**
```
┌─────────────────────────────────────┐
│                                     │
│   STAKD                             │
│   Zen Garden Puzzle                 │
│                                     │
│   [Game Board] | [Zen Garden]       │
│                                     │
└─────────────────────────────────────┘
```

**Time estimate:** 2 hours

---

### Day 9: Monetization Setup (2 hours)

**Task 5.1: Create AdMob App & Get Real IDs**

1. **Go to AdMob Console:** https://apps.admob.com/
2. **Sign in** with Go7Studio account
3. **Add App:**
   - Platform: Android
   - App name: Stakd
   - Package name: `com.go7studio.stakd`
   - Is this app on Google Play? Not yet
4. **Create Ad Units:**
   - **Interstitial:** "Stakd - Interstitial"
     - Get ad unit ID (e.g., `ca-app-pub-XXXX/YYYY`)
   - **Rewarded:** "Stakd - Rewarded Hints"
     - Get ad unit ID

5. **Update Code:**

**File:** `android/app/src/main/AndroidManifest.xml`
```xml
<!-- Replace test ID with YOUR app ID -->
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXX~YYYYYYYYYY"/>
```

**File:** `lib/services/ad_service.dart`
```dart
// Replace test IDs
static const String _interstitialAdUnitId =
    'ca-app-pub-XXXXXXXXXXXX/YYYYYYYYYY'; // YOUR REAL ID

static const String _rewardedAdUnitId =
    'ca-app-pub-XXXXXXXXXXXX/ZZZZZZZZZZ'; // YOUR REAL ID
```

**Time estimate:** 30 minutes

---

**Task 5.2: Test Ads in Release Build**

```bash
# Build release APK
flutter build apk --release

# Install on real device
adb install build/app/outputs/flutter-apk/app-release.apk

# Play through 5 levels
# Verify interstitial ad shows
# Verify rewarded ad works for hints
```

**Expected outcome:** Ads load and display correctly

**Time estimate:** 30 minutes

---

**Task 5.3: Configure IAP Products (Note: Can only do after app created in Play Console)**

**Placeholder:** Document product IDs for later setup

**Products to create in Play Console:**
1. **Remove Ads**
   - Product ID: `com.go7studio.stakd.remove_ads`
   - Type: Non-consumable
   - Price: $2.99

2. **Hint Pack (10 hints)**
   - Product ID: `com.go7studio.stakd.hint_pack_10`
   - Type: Consumable
   - Price: $0.99

**Time estimate:** 30 minutes (after Play Console access)

---

## Week 3: Compliance & Submission (4-6 hours)

### Day 10: Privacy Policy (1-2 hours)

**Task 6.1: Generate Privacy Policy**

```bash
# Use Termly Privacy Policy Generator
# URL: https://termly.io/products/privacy-policy-generator/

# Or use template from PRIVACY_POLICY_TEMPLATE.md
```

**Required disclosures:**
- Device Advertising ID (AdMob)
- Purchase history (Google Play Billing)
- Local game progress storage
- No personal information collected
- Third-party services (AdMob, Google Play)
- COPPA compliance
- GDPR/CCPA rights

**Time estimate:** 30 minutes (using generator)

**Task 6.2: Host Privacy Policy**

**Option A: Add to go7studio.com**
```bash
# Create page at https://go7studio.com/privacy/stakd
# Copy generated privacy policy HTML
# Style to match go7studio.com theme
```

**Option B: GitHub Pages**
```bash
# Create repo: stakd-privacy
# Add index.html with policy
# Enable GitHub Pages
# URL: https://go7studio.github.io/stakd-privacy
```

**Time estimate:** 30 minutes

---

### Day 11-12: Play Console Setup & Submission (3-4 hours)

**Task 7.1: Create Play Console Listing**

**Prerequisites:**
- Google Play Developer account ($25 one-time fee if not already paid)
- Release-signed AAB
- All store assets ready

**Process:**
1. **Go to Play Console:** https://play.google.com/console
2. **Create App:**
   - App name: Stakd
   - Default language: English (US)
   - App/Game: Game
   - Free/Paid: Free

3. **Store Listing:**
   - Short description (from `store/description.md`)
   - Full description (from `store/description.md`)
   - App icon (1024x1024)
   - Feature graphic (1024x500)
   - Screenshots (8 images, 1080x1920)
   - Category: Puzzle
   - Tags: Puzzle, Brain Games, Casual, Relaxing

4. **Content Rating:**
   - Fill out questionnaire
   - Expected: Everyone or PEGI 3
   - Disclose: Ads, in-app purchases

5. **App Content:**
   - Privacy policy URL
   - Ads: Yes (via AdMob)
   - Target audience: Ages 13+
   - Declare no sensitive permissions

6. **Data Safety:**
   - Collects: Device IDs (advertising), Purchase history
   - Security: Encrypted in transit
   - Purpose: Advertising, app functionality

**Time estimate:** 2-3 hours

---

**Task 7.2: Build & Upload Release AAB**

```bash
cd /Users/venomspike/.openclaw/workspace/projects/stakd

# Clean build
flutter clean
flutter pub get

# Build release AAB (Android App Bundle)
flutter build appbundle --release

# Output location:
# build/app/outputs/bundle/release/app-release.aab

# Verify signing
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

**Upload to Play Console:**
1. Production > Create new release
2. Upload AAB
3. Release name: 1.0.0 (Initial Launch)
4. Release notes:
   ```
   🌸 Welcome to Stakd!
   
   • Sort colors, grow your Zen garden
   • Multi-grab mechanic for strategic play
   • Endless Zen Mode with infinite puzzles
   • Daily challenges
   • Beautiful animations & soothing music
   
   Relax, sort, and watch your sanctuary bloom.
   ```

**Time estimate:** 1 hour

---

**Task 7.3: Internal Testing (Optional but Recommended)**

**Setup:**
1. Create internal testing track
2. Add 5-10 testers (use email addresses)
3. Distribute test link
4. Gather feedback for 3-7 days

**Test focus:**
- Crashes
- Ad frequency comfort
- Zen Garden visual progression
- Tutorial clarity
- Audio issues on various devices

**Time estimate:** 3-7 days (async)

---

**Task 7.4: Submit for Review**

**Final checklist:**
```
[ ] Store listing complete (all fields filled)
[ ] 8 screenshots uploaded
[ ] Feature graphic uploaded
[ ] App icon uploaded
[ ] Privacy policy URL added and working
[ ] Content rating received
[ ] Data safety declaration complete
[ ] Release AAB uploaded and signed correctly
[ ] Release notes added
[ ] Pricing set (Free)
[ ] Countries selected (Worldwide or specific)
[ ] Review "App content" for compliance
```

**Submit:**
- Click "Send for Review"
- **Expected review time:** 3-7 days (first submission often slower)

**Time estimate:** 30 minutes

---

## Post-Submission: While Waiting for Approval

### Marketing Prep (3-5 hours)

**Task 8.1: Create Social Media Assets**

1. **TikTok/Instagram Reels (3-5 clips):**
   - Multi-grab mechanic demo (15s)
   - Zen Garden evolution timelapse (30s)
   - "Most satisfying puzzle game" (20s)
   - Daily challenge completion (15s)

2. **Twitter/X Announcement:**
   ```
   🌸 Stakd is LIVE on Google Play!
   
   The color sort puzzle that grows with you:
   ✓ Multi-grab mechanic
   ✓ Zen Garden meta-progression
   ✓ Endless mode
   
   Free to play 👉 [link]
   
   #indiegame #puzzlegame #mobilegaming
   ```

3. **Reddit Posts:**
   - r/AndroidGaming
   - r/incremental_games (Zen Garden progression)
   - r/iosgaming (when iOS launches)

**Time estimate:** 2-3 hours

---

**Task 8.2: Set Up Analytics (Optional)**

If not done already:
```bash
# Add Firebase Analytics
flutter pub add firebase_core firebase_analytics

# Configure Firebase (create project at console.firebase.google.com)
# Track: puzzle_solved, level_completed, garden_stage_up, ad_shown, iap_purchased
```

**Time estimate:** 1-2 hours

---

## Contingency Plans

### If Review Rejected (Common Reasons)

**Reason 1: Privacy Policy Issues**
- **Fix:** Ensure policy explicitly mentions AdMob data collection
- **Timeline:** 1 hour to revise + resubmit

**Reason 2: Content Rating Mismatch**
- **Fix:** Retake questionnaire, be explicit about ads
- **Timeline:** 30 minutes

**Reason 3: Metadata Violations**
- **Fix:** Remove any trademarked terms, excessive claims
- **Timeline:** 1 hour

**Reason 4: Permissions Declaration**
- **Fix:** Review AndroidManifest.xml, remove unnecessary permissions
- **Timeline:** 1 hour

---

## Success Metrics (Post-Launch)

**Week 1:**
- [ ] 100+ organic installs
- [ ] No critical crashes (crash-free rate >99%)
- [ ] Rating >4.0★
- [ ] First revenue from ads ($5-20)

**Month 1:**
- [ ] 1000+ total installs
- [ ] D1 retention >35%
- [ ] D7 retention >15%
- [ ] Revenue >$100
- [ ] 10+ reviews (respond to ALL)

**Month 3:**
- [ ] 5000+ total installs
- [ ] D1 retention >40%
- [ ] D7 retention >20%
- [ ] Revenue >$300/month
- [ ] Rating stabilized >4.2★
- [ ] Decision point: Worth continued development?

---

## Budget Breakdown

**Required Costs:**
- Google Play Developer Account: $25 (one-time, if not already paid)
- Privacy Policy Generator (optional): $0 (use free tier)
- **Total:** $25

**Optional Costs:**
- Figma Pro (icons/graphics): $0 (free tier sufficient)
- Domain for privacy policy: $0 (use go7studio.com)
- Beta testing incentives: $0-50 (optional gift cards)
- Marketing (social ads): $0-100 (defer until metrics validate)

**Total Estimated Cost:** $25-175

---

## Risk Mitigation

**Risk:** Zen Garden UI takes longer than estimated (8+ hours)
**Mitigation:** Launch with simplified garden (text-based progress, upgrade visuals later)

**Risk:** Audio issues persist after re-encoding
**Mitigation:** Ship without sound, add as update (many players mute anyway)

**Risk:** AdMob account approval delayed
**Mitigation:** Launch with ads disabled, enable in update once approved

**Risk:** Low organic installs (< 50/day)
**Mitigation:** Cross-promote in Empire Tycoon (once launched), Reddit marketing

---

## Next Steps (Immediate)

**Priority 1 (Blockers):**
1. Install Android SDK (Day 1)
2. Create release keystore (Day 1)
3. Complete Zen Garden UI (Day 3-5)

**Priority 2 (Store Assets):**
4. Design app icon (Day 7)
5. Capture screenshots (Day 8)
6. Create feature graphic (Day 8)

**Priority 3 (Compliance):**
7. Generate privacy policy (Day 10)
8. Create Play Console listing (Day 11)

**Priority 4 (Launch):**
9. Build release AAB (Day 12)
10. Submit for review (Day 12)

---

**Timeline Summary:**
- **Week 1:** Dev environment + Zen Garden + audio = 12-14 hours
- **Week 2:** Store assets + monetization = 8-10 hours
- **Week 3:** Privacy policy + submission = 4-6 hours
- **Total:** 24-30 hours over 3 weeks
- **Review:** 3-7 days
- **Launch:** ~4 weeks from today

**Ready to start? Begin with Day 1: Android SDK setup. 🚀**

---

**Last Updated:** February 8, 2026
**Owner:** Go7Studio
**Project Manager:** Walt (AI Assistant)
