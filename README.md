# NearWord

Guess the secret word **by meaning**. Every word you try gets a rank – how close
its meaning is to the hidden word (rank 1 = the secret). Built with Flutter,
GetX and Hive. Inspired by the "semantic guessing" idea behind Contexto, with
its own modes, UI and multiplayer.

## Features

| Mode | What it does |
| --- | --- |
| **Daily puzzle** | One word per day, the same for everyone. Streaks + bonus coins. |
| **Quick play** | Endless random words. |
| **Categories** | Themed pools (animals, food, sports, music, space …). Some are premium (coins or rewarded ad). |
| **Challenge a friend** | Share a 6-character code; your friend plays the *same* secret word. |
| **Battle** | Up to 8 players race to the same word. Live scoreboard shows **who is nearest**; first solver wins. Online rooms or *Practice vs bots*. |
| **Radar view** | Every guess drawn as a dot – the closer the meaning, the nearer the centre. |
| Extras | Hints, achievements, stats, haptics, dark/light theme, share cards, AdMob (banner / interstitial / rewarded) with UMP consent. |

### Real, random rankings (no per-puzzle files)

`tools/build_embeddings.py` compresses GloVe (`glove-wiki-gigaword-100`) into
`assets/data/` (≈4.4 MB: 40k words × 100 dims, int8). On the phone,
`SemanticEngine` ranks the whole vocabulary by cosine similarity to the secret,
so **any** word can be the answer and rankings are computed live, offline.

A puzzle id fully determines its secret (`daily-2026-10-13`, `rnd-ABC123`,
`cat-animals-ABC123`, `battle-K7Q2X`), which is how daily words, friend
challenges and battle rooms stay in sync with no server-side word storage.

Regenerate the data (needs `pip install gensim nltk numpy`):

```bash
# 1. download once (about 180 MB, from huggingface.co/fse/glove-wiki-gigaword-100)
# 2. python -c "import nltk; nltk.download('wordnet', download_dir='wn')"
python tools/build_embeddings.py --model path/to/glove-wiki-gigaword-100.model --nltk-data wn
```

## Run

```bash
flutter pub get
flutter run            # Android / iOS device
flutter test
```

Targets Flutter 3.27 / Dart 3.6 (AGP 8.9, Gradle 8.11, Kotlin 2.1).

## Online battles (free, 2 minutes)

Battles use the **Firebase Realtime Database REST API** – no SDK or
`google-services.json` required.

1. [Firebase console](https://console.firebase.google.com) → create project →
   *Build → Realtime Database → Create database*.
2. Enter the database URL on each phone in **Settings > Online battles** (then
   tap *Test*), or bake it into
   [`lib/core/constants/backend_config.dart`](lib/core/constants/backend_config.dart).
3. Paste [`database.rules.json`](database.rules.json) into the **Rules** tab.

Until a URL is set, *Practice vs bots* works fully offline.

How it works: each player writes only their own row (`best` rank, guesses,
solved). Every client sorts the same data with `BattleRanking`, so everyone sees
the same live standings. The round ends on timeout, when everyone is done, or
30 s after the first solver.

## Ads

`lib/core/constants/ad_ids.dart` ships Google **test** IDs. Before release set
`useTestIds = false`, fill in your unit IDs and replace the app ID in
`AndroidManifest.xml` / `Info.plist`.

## CI

A ready-to-use GitHub Actions workflow (analyze, test, build APK) is in
[`ci/ci.yml`](ci/ci.yml). To enable it, copy it to `.github/workflows/ci.yml`
(pushing workflow files needs a token with the `workflow` scope).

## Layout

```
lib/
  core/        constants, theme, services (engine, ads, consent, storage, settings), widgets
  data/        models + repositories (puzzles, stats)
  features/    splash, home, game, categories, result, stats, settings, hints, battle
tools/         build_embeddings.py
assets/data/   vocab, int8 vectors, secrets, categories
```
