# Privacy Policy Template for Stakd

**IMPORTANT:** This is a template/guide. Generate the actual policy using a privacy policy generator, then host it at `https://go7studio.com/privacy/stakd`

---

## Required Sections for Google Play Store

### 1. Information We Collect

**Must disclose:**
- ✅ **Device identifiers** (Advertising ID via AdMob)
- ✅ **Purchase history** (via Google Play Billing)
- ✅ **Game progress** (stored locally via SharedPreferences)
- ❌ **NO personal information** (name, email, location, contacts)
- ❌ **NO account creation required**

**Example language:**
```
Stakd collects the following information:

• Device Advertising ID: Used to serve personalized advertisements through Google AdMob
• Purchase History: Stored by Google Play to validate in-app purchases (ad removal, hint packs)
• Game Progress: Saved locally on your device (levels completed, Zen Garden state, settings)

We do NOT collect:
• Personal information (name, email address, phone number)
• Location data
• Photos, contacts, or other sensitive data
• Device information beyond the Advertising ID
```

### 2. How We Use Information

**Must explain:**
- Advertising ID → Serve ads via AdMob
- Purchase data → Unlock IAP entitlements
- Game progress → Persist state across sessions

**Example language:**
```
We use collected information for:

• Displaying relevant advertisements (AdMob)
• Processing in-app purchases
• Saving your game progress locally
• Improving game performance and user experience

We do NOT sell or share your data with third parties beyond Google's advertising services.
```

### 3. Third-Party Services

**Must list:**
- Google AdMob (ads)
- Google Play Services (IAP, analytics)

**Example language:**
```
Stakd integrates the following third-party services:

• Google AdMob: Displays advertisements. AdMob may collect device identifiers and usage data.
  Privacy Policy: https://policies.google.com/privacy

• Google Play Services: Handles in-app purchases and basic analytics.
  Privacy Policy: https://policies.google.com/privacy

These services have their own privacy policies. We encourage you to review them.
```

### 4. Children's Privacy (COPPA Compliance)

**Must include if rated Everyone:**

**Example language:**
```
Stakd is not directed at children under 13. We do not knowingly collect personal information from children. The game uses age-appropriate advertising filters provided by AdMob.

If you believe your child has provided information to us, please contact support@go7studio.com and we will delete it promptly.
```

### 5. Data Security

**Example language:**
```
Your game progress is stored locally on your device. In-app purchases are processed securely through Google Play.

We implement industry-standard security measures, but no method of transmission or storage is 100% secure. Use the app at your own discretion.
```

### 6. Your Rights (GDPR/CCPA)

**Example language:**
```
You have the right to:

• Opt out of personalized advertising (via device settings or in-app settings)
• Request deletion of your data (uninstalling the app deletes local data)
• Access information we collect (contact support@go7studio.com)

For EU users: We comply with GDPR. AdMob provides consent mechanisms for personalized ads.

For California users: We comply with CCPA. We do not sell personal information.
```

### 7. Changes to Privacy Policy

**Example language:**
```
We may update this Privacy Policy from time to time. Changes will be posted at this URL with an updated "Last Modified" date. Continued use of Stakd after changes constitutes acceptance.
```

### 8. Contact Information

**Example language:**
```
If you have questions about this Privacy Policy, contact us:

Email: support@go7studio.com
Developer: Go7Studio
Website: https://go7studio.com
```

---

## Privacy Policy Generators (Recommended)

### Option 1: Termly (Free Tier)
- **URL:** https://termly.io/products/privacy-policy-generator/
- **Pros:** Comprehensive, GDPR/CCPA compliant, free for small apps
- **Cons:** Upsells premium features
- **Process:**
  1. Select "Mobile App"
  2. Enter "Stakd" as app name
  3. Select "Advertising" and "In-app purchases"
  4. Choose "Google AdMob" and "Google Play Services"
  5. Select "No account creation"
  6. Generate policy
  7. Download HTML/Markdown

### Option 2: Free Privacy Policy (100% Free)
- **URL:** https://www.freeprivacypolicy.com/free-privacy-policy-generator/
- **Pros:** Completely free, no signup
- **Cons:** Less customization
- **Process:** Similar to Termly

### Option 3: App Privacy Policy Generator (App-Specific)
- **URL:** https://app-privacy-policy-generator.nisrulz.com/
- **Pros:** Made for mobile apps, includes AdMob templates
- **Cons:** Basic, may need manual editing

---

## Hosting Options

### Option 1: Go7Studio Website (Recommended)
- **URL:** `https://go7studio.com/privacy/stakd`
- **Pros:** Professional, easy to update
- **Process:**
  1. Create `privacy/stakd.html` on website
  2. Copy generated policy
  3. Style to match go7studio.com
  4. Link in Play Store listing

### Option 2: GitHub Pages (Free)
- **URL:** `https://go7studio.github.io/stakd-privacy`
- **Pros:** Free, version-controlled
- **Cons:** Separate domain from main brand

### Option 3: Google Sites (Quick & Dirty)
- **URL:** Custom Google Site
- **Pros:** Free, fast setup
- **Cons:** Looks generic

---

## Google Play Console Requirements

When filling out the "Data Safety" section in Play Console:

### Data Collected
- [x] Device or other IDs
  - **Purpose:** Advertising
  - **Data handling:** Shared with Google AdMob

- [x] Purchase history
  - **Purpose:** App functionality (unlock IAP features)
  - **Data handling:** Processed through Google Play

- [ ] Location (NOT collected)
- [ ] Personal info (NOT collected)
- [ ] Photos and videos (NOT collected)
- [ ] Files and docs (NOT collected)

### Security Practices
- [x] Data is encrypted in transit (Google Play standard)
- [ ] Users can request data deletion (local data only—uninstall)
- [x] Data collection is optional (can play without IAP, can disable personalized ads)

---

## AdMob-Specific Disclosures

### Personalized Ads
If using personalized ads (default):
```
Stakd uses Google AdMob to display personalized advertisements based on your interests. You can opt out of personalized ads in your device settings (Android: Settings > Google > Ads > Opt out of Ads Personalization).
```

### Ad Frequency Disclosure (Optional but Transparent)
```
Stakd displays interstitial ads approximately once every 3-5 levels. Rewarded video ads are available optionally for hints. You can remove all ads permanently via in-app purchase.
```

---

## Sample "Data Safety" Answers (Play Console)

**Does your app collect or share user data?**
→ Yes

**What data does your app collect?**
→ Device or other IDs (for advertising)
→ Purchase history (for in-app purchases)

**Is all of the user data collected by your app encrypted in transit?**
→ Yes (via Google Play Services)

**Do you provide a way for users to request that their data is deleted?**
→ No (data is stored locally; uninstalling deletes it)

**Privacy Policy URL:**
→ https://go7studio.com/privacy/stakd

---

## Testing Privacy Policy Compliance

Before submitting to Play Store:

1. ✅ **Check all links work** (privacy policy URL loads)
2. ✅ **Verify AdMob disclosures** (mentions Advertising ID, personalized ads)
3. ✅ **Test opt-out flow** (device settings → disable personalized ads → verify ads still show but generic)
4. ✅ **Read Google's Data Safety guidelines:** https://support.google.com/googleplay/android-developer/answer/10787469
5. ✅ **Check COPPA compliance** (if rated Everyone)
6. ✅ **Ensure contact email works** (support@go7studio.com)

---

## Post-Launch Updates

If you add any of these later, UPDATE privacy policy:
- Analytics (Firebase, Mixpanel)
- Crash reporting (Crashlytics)
- Social features (leaderboards, sharing)
- Push notifications
- Account creation
- Cloud save

**Always notify users of privacy policy changes via in-app notice or update notes.**

---

## Quick Checklist

```
[ ] Generate privacy policy (Termly, FPP, or manual)
[ ] Review all sections for accuracy
[ ] Host at https://go7studio.com/privacy/stakd
[ ] Verify URL loads publicly (not password-protected)
[ ] Add URL to Play Console "Data Safety" section
[ ] Fill out Data Safety questionnaire
[ ] Cross-reference with AdMob policies
[ ] Ensure support@go7studio.com is monitored
[ ] Test on multiple devices (privacy policy link in-app if added)
[ ] Keep copy in project repo for version control
```

---

**Last Updated:** February 8, 2026
**Next Review:** Before Play Store submission
