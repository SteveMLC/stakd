# Stakd Launch - Quick Start Guide

**TL;DR:** AdMob ✅ | IAP ✅ | Build ✅ | Icons ✅ → Just need store assets + signing

---

## 🎯 Critical Path to Launch (8-10 hours)

### 1. Release Signing (30 min)
```bash
cd /Users/venomspike/.openclaw/workspace/projects/stakd/android

# Generate keystore (SAVE THE PASSWORD!)
keytool -genkey -v -keystore stakd-upload-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias stakd-key

# Create key.properties
cat > key.properties << EOF
storePassword=YOUR_PASSWORD_HERE
keyPassword=YOUR_PASSWORD_HERE
keyAlias=stakd-key
storeFile=stakd-upload-key.jks
EOF

# Add to .gitignore
echo "android/key.properties" >> .gitignore
echo "android/*.jks" >> .gitignore
```

**Then update:** `android/app/build.gradle.kts` (see full checklist for code)

---

### 2. AdMob Production IDs (15 min)
1. Go to https://admob.google.com/
2. Create app: "Stakd - Color Sort Puzzle"
3. Create ad units:
   - Interstitial (game over)
   - Rewarded (hints)
4. Copy IDs
5. Replace in:
   - `android/app/src/main/AndroidManifest.xml` line 30
   - `lib/services/ad_service.dart` lines 17-21

---

### 3. Screenshots (2-3 hours)
Run app and capture:
1. Game board (multi-grab in action)
2. Zen Garden screen
3. Level select
4. Daily challenge
5. Zen Mode
6. Settings
7. Tutorial
8. IAP screen

**Dimensions:** 1080x1920 (portrait)

---

### 4. Feature Graphic (2-3 hours)
Create 1024x500px banner in Canva/Figma:
- "Stakd" title
- Zen Garden visual
- Tagline: "Sort, Stack, Grow Your Garden"

---

### 5. Privacy Policy (1 hour)
1. Generate at https://www.freeprivacypolicy.com/
2. Host at https://go7studio.com/privacy/stakd
3. Include: AdMob (Advertising ID), IAP (Purchase history)

---

### 6. Play Console Setup (1 hour)
1. Create app draft
2. Add store listing (title, description, screenshots, graphic)
3. Add privacy policy URL
4. Register IAP products:
   - `com.go7studio.stakd.remove_ads` ($2.99)
   - `com.go7studio.stakd.hint_pack_10` ($0.99)
5. Complete content rating questionnaire

---

### 7. Build & Upload (30 min)
```bash
flutter build appbundle --release
# Upload build/app/outputs/bundle/release/app-release.aab to Play Console
```

---

## 🚀 Launch Decision: Zen Garden?

**Option A: Launch With Zen Garden (Recommended)**
- Time: +6-8 hours
- Impact: Key differentiator present from day 1
- Risk: Delays launch by 1-2 days

**Option B: Launch Without, Add in v1.1**
- Time: No delay
- Impact: Missing main differentiator
- Risk: Lower retention/engagement initially

**Recommendation:** Review `zen_garden_screen.dart` - if it's functional but needs polish, launch with it. If completely broken, defer to v1.1.

---

## ✅ What's Already Done

- ✅ AdMob integration (test IDs work)
- ✅ IAP integration (ready for product registration)
- ✅ App icons (all densities)
- ✅ Android SDK installed
- ✅ Release build compiles (55.2MB APK)
- ✅ Code analysis clean (58 minor issues, no blockers)

---

## 📊 Current Status

**Launch Readiness:** 75/100  
**Code Readiness:** 100/100  
**Store Readiness:** 30/100  

**Missing:**
- Store assets (screenshots, graphic)
- Privacy policy
- Release signing
- Production AdMob/IAP IDs

**Time to 90/100:** 8-10 focused hours

---

## 🎯 Recommended Timeline

**Today (Feb 9):**
- Review checklist
- Verify app icon quality
- Decide on Zen Garden

**Tomorrow (Feb 10):**
- Create keystore
- Register AdMob app
- Generate privacy policy

**Feb 11-12:**
- Capture screenshots
- Create feature graphic
- Play Console setup

**Feb 13:**
- Build signed AAB
- Upload to Play Console
- Submit for review

**Feb 20-27:**
- Google review (3-7 days)
- Launch! 🎉

---

## 📞 Questions for Steve

1. **AdMob account:** Use existing Empire Tycoon account or create new?
2. **Zen Garden:** Launch with it or defer to v1.1?
3. **App icon:** Current icon good or needs redesign?
4. **IAP pricing:** $2.99 for Remove Ads, $0.99 for 10 hints?
5. **Beta testing:** Internal testing first or go straight to production?

---

**Full details:** See `LAUNCH_CHECKLIST_UPDATED.md`  
**Subagent:** walt | **Date:** Feb 9, 2026
