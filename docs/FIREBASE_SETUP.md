# Firebase Setup for Stakd Leaderboards

This guide walks you through setting up Firebase for the global leaderboards feature.

## Prerequisites

- A Google account
- Flutter SDK installed
- Firebase CLI installed (`npm install -g firebase-tools`)

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add Project"
3. Name it "stakd" or similar
4. Enable Google Analytics (optional)
5. Create the project

## Step 2: Add Android App

1. In Firebase Console, click "Add app" → Android
2. Enter package name: `com.go7studio.stakd`
3. Enter app nickname: "Stakd"
4. Download `google-services.json`
5. Place it in `android/app/google-services.json`

## Step 3: Add iOS App (Optional)

1. In Firebase Console, click "Add app" → iOS
2. Enter bundle ID: `com.go7studio.stakd`
3. Download `GoogleService-Info.plist`
4. Place it in `ios/Runner/GoogleService-Info.plist`

## Step 4: Enable Firestore

1. In Firebase Console, go to "Firestore Database"
2. Click "Create database"
3. Choose "Start in production mode"
4. Select a region (us-central1 recommended)

## Step 5: Set Firestore Security Rules

In Firebase Console → Firestore → Rules, set:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Leaderboards - public read, authenticated write
    match /leaderboards/{type}/{subPath=**} {
      allow read: if true;
      allow write: if request.resource.data.keys().hasAll(['name', 'timestamp'])
                   && request.resource.data.name is string
                   && request.resource.data.name.size() <= 20
                   && request.resource.data.name.size() >= 2;
    }
  }
}
```

## Step 6: Create Firestore Indexes

For optimal query performance, create these indexes in Firebase Console → Firestore → Indexes:

### Daily Challenge Index
- Collection: `leaderboards/daily/{date}/entries`
- Fields: `score` (Ascending)

### Weekly Stars Index
- Collection: `leaderboards/weekly_stars/{weekId}/entries`
- Fields: `stars` (Descending)

### All-Time Stars Index
- Collection: `leaderboards/alltime_stars/entries`
- Fields: `stars` (Descending)

### Best Combo Index
- Collection: `leaderboards/best_combo/entries`
- Fields: `combo` (Descending)

## Firestore Data Structure

```
leaderboards/
  daily/
    {YYYY-MM-DD}/
      entries/
        {playerId}: {
          name: string,
          score: int (seconds),
          timestamp: int (epoch ms)
        }
  weekly_stars/
    {YYYY-WNN}/
      entries/
        {playerId}: {
          name: string,
          stars: int,
          timestamp: int (epoch ms)
        }
  alltime_stars/
    entries/
      {playerId}: {
        name: string,
        stars: int,
        timestamp: int (epoch ms)
      }
  best_combo/
    entries/
      {playerId}: {
        name: string,
        combo: int,
        timestamp: int (epoch ms)
      }
```

## Testing

1. Run the app: `flutter run`
2. Complete a daily challenge
3. Check Firebase Console → Firestore to see the entry
4. Open Leaderboards screen to verify data loads

## Troubleshooting

### "Firebase not initialized" error
- Ensure `google-services.json` is in `android/app/`
- Run `flutter clean && flutter pub get`

### "Permission denied" error
- Check Firestore rules allow writes
- Verify the data structure matches the rules

### Leaderboard not updating
- Check network connectivity
- Look for errors in debug console
- Verify Firebase project is active

## Notes

- Player IDs are generated locally using UUID v4
- Data is cached locally for offline viewing
- Submissions are queued when offline and sent when back online
- Daily leaderboards reset at midnight UTC
- Weekly leaderboards reset Monday midnight UTC
