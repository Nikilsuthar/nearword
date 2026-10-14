# NearWord

A word-guessing game: every guess is ranked by **meaning** (GloVe embeddings, computed on the phone). Rank 1 is the secret word. Flutter + GetX, Hindi + English.

## Features
- **Daily word** with a Firebase **daily leaderboard** per word style and level. Words come from a seeded fixed shuffle, so they never repeat.
- **Levels** Easy / Medium / Hard (Settings) built from a 100k vocabulary of common words; used by Quick play, Categories, Daily, Rooms and Challenges.
- **Word style**: Regular or India (everyday Indian words), asked on first launch and changeable in Settings.
- **Battles**: live rooms (share a 5-letter code) and challenges. Creator picks level, timer and **coin stake**.
  Winner takes the pot; if nobody solves it in time the nearest player gets 50% of the pot and the others get 50% of their stake back.
- **Hindi / English** UI, light + dark theme, responsive layouts with SafeArea.
- **Ads** handled by the [`safe_ads`](https://pub.dev/packages/safe_ads) package (banner, interstitial, rewarded, consent).

## Run
```
flutter pub get
flutter run --dart-define=NEARWORD_RTDB_URL=https://<project>-default-rtdb.firebaseio.com
```
Without the URL the app works offline (practice battles only; no daily board or online rooms).

## Firebase
- `database.rules.json` – open mode (works with no sign-in). Deploy: `firebase deploy --only database`.
- `database.rules.secure.json` – requires anonymous Firebase Auth. Enable Authentication ("Get started" + Anonymous), pass `--dart-define=NEARWORD_FB_API_KEY=...`, then deploy this file instead.
- Coins are stored on the device (client-side), so treat stakes as for-fun.

## Data
`python tools/build_embeddings.py` rebuilds `assets/data/*` (vocab, vectors, tiers, categories).

## Tests
`flutter test` (unit, controller, widget flows in light and dark). `NEARWORD_RTDB_URL=... flutter test test/rtdb_live_test.dart` runs against a real database. `ci/ci.yml` is the CI workflow (move to `.github/workflows/`).
