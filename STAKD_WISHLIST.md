# Stakd — Wishlist / Tabled Features

## Firebase / Online Features (Tabled Feb 2026)
- **Leaderboard** — Global/friend leaderboards via Firestore. May or may not implement. Currently stubbed locally.
- **Referral board** — Similar to Empire Tycoon's referral system. Could reuse the social sharing playbook (`memory/systems/social-sharing-playbook.md`). TBD on whether this makes sense for a puzzle game.
- **Cloud save** — Sync progress across devices via Firebase Auth + Firestore.

When ready to re-add Firebase:
1. Create Firebase project for Stakd
2. Register Android app, download `google-services.json` to `android/app/`
3. Re-add `firebase_core` + `cloud_firestore` to pubspec.yaml
4. Re-add google-services plugin to Gradle files
5. Un-stub LeaderboardService
