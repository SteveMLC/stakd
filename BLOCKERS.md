# Stakd Launch Blockers - Quick Reference

**Total Time to Fix:** 8-10 hours  
**Current Status:** 75/100 → Need 90/100 to launch

---

## 🔴 Critical (Must Fix)

| # | Blocker | Time | Files/Steps |
|---|---------|------|-------------|
| 1 | **Release Keystore** | 30m | Generate JKS, create key.properties, update build.gradle.kts |
| 2 | **AdMob Production IDs** | 15m | Create app in admob.google.com, replace 2 files |
| 3 | **IAP Products** | 15m | Register in Play Console after app draft created |
| 4 | **Screenshots** | 3h | Capture 8 screens (1080x1920), add to listing |
| 5 | **Feature Graphic** | 2h | Design 1024x500 banner in Canva/Figma |
| 6 | **Privacy Policy** | 1h | Generate + host at go7studio.com/privacy/stakd |
| 7 | **Play Console Listing** | 1h | Create draft, add assets, configure settings |

**Total:** 7.5-8.5 hours

---

## 🟡 High Priority (Recommended)

| # | Item | Time | Notes |
|---|------|------|-------|
| 8 | **App Icon Review** | 0-3h | Inspect quality, redesign if placeholder |
| 9 | **Audio Re-encoding** | 1-2h | Fix MP3 errors (optional, can defer) |

---

## ✅ Already Complete

- ✅ AdMob integration (code)
- ✅ IAP integration (code)
- ✅ App icons (all densities)
- ✅ Android SDK setup
- ✅ Release build (compiles successfully)
- ✅ Zen Garden (fully implemented!)
- ✅ Code quality (flutter analyze clean)

---

## 📋 Critical Path Checklist

```
[ ] 1. Generate release keystore (30m)
[ ] 2. Create AdMob app + get production IDs (15m)
[ ] 3. Replace AdMob test IDs in code (5m)
[ ] 4. Generate privacy policy (30m)
[ ] 5. Host privacy policy at go7studio.com (30m)
[ ] 6. Capture 8 screenshots (2-3h)
[ ] 7. Design feature graphic (2h)
[ ] 8. Create Play Console app draft (30m)
[ ] 9. Add store assets to listing (30m)
[ ] 10. Register IAP products (15m)
[ ] 11. Build signed AAB: flutter build appbundle --release (5m)
[ ] 12. Upload AAB to Play Console (10m)
[ ] 13. Submit for review (5m)
```

**Then:** Wait 3-7 days for Google review → Launch!

---

## 🎯 Recommended Timeline

| Day | Tasks | Hours |
|-----|-------|-------|
| **Day 1** | Keystore, AdMob, privacy policy | 2h |
| **Day 2** | Screenshots | 3h |
| **Day 3** | Feature graphic, Play Console | 3h |
| **Day 4** | Build, upload, submit | 1h |
| **+1 week** | Google review | - |
| **Launch!** | 🎉 | - |

---

## 📞 Quick Commands

### Generate Keystore
```bash
cd /Users/venomspike/.openclaw/workspace/projects/stakd/android
keytool -genkey -v -keystore stakd-upload-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias stakd-key
```

### Build Signed Release
```bash
cd /Users/venomspike/.openclaw/workspace/projects/stakd
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Test Current Build
```bash
cd /Users/venomspike/.openclaw/workspace/projects/stakd
flutter build apk --release
# Already works! APK: build/app/outputs/flutter-apk/app-release.apk (55.2MB)
```

---

## 🔍 Files to Edit

**For AdMob Production IDs:**
1. `android/app/src/main/AndroidManifest.xml` (line 30)
2. `lib/services/ad_service.dart` (lines 17-21)

**For Release Signing:**
1. Create: `android/key.properties`
2. Edit: `android/app/build.gradle.kts`
3. Update: `.gitignore`

**For IAP Products:**
- Register in Play Console (no code changes)

---

**See full details:** `LAUNCH_CHECKLIST_UPDATED.md`  
**Quick start guide:** `LAUNCH_QUICK_START.md`  
**Task report:** `SUBAGENT_REPORT.md`
