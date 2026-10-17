# Publishing NearWord on Google Play

Version: **1.0.0 (build 1)** – first release (`version: 1.0.0+1` in `pubspec.yaml`).
Package name: `com.weetech.nearword` (cannot be changed after the first upload).

## 1. Files
- `dist/NearWord-1.0.0+1.aab` – upload this to Play Console (signed with the upload key).
- `android/upload-keystore.jks` + `android/key.properties` – **your upload key. Back both up** (they are git-ignored). Keep Play App Signing ON (default); if you lose the upload key you can ask Google to reset it.
- `docs/PRIVACY_POLICY.md` – privacy policy (URL used in the app and the store form):
  https://github.com/Nikilsuthar/nearword/blob/main/docs/PRIVACY_POLICY.md

## 2. Real ads (do this before the production build)
The AAB in `dist/` still shows **Google test ads**. Create in AdMob (apps.admob.com): one Android app, then one **Banner**, one **Interstitial**, one **Rewarded** ad unit. Then build:

```
flutter build appbundle --release ^
  --dart-define=NEARWORD_RTDB_URL=https://nearword-battle-1405-default-rtdb.firebaseio.com ^
  --dart-define=ADMOB_BANNER=ca-app-pub-XXXX/BBBB ^
  --dart-define=ADMOB_INTERSTITIAL=ca-app-pub-XXXX/IIII ^
  --dart-define=ADMOB_REWARDED=ca-app-pub-XXXX/RRRR ^
  -PADMOB_APP_ID=ca-app-pub-XXXX~AAAA
```
(`^` is the Windows line continuation; on bash use `\`.) Never tap your own live ads – use a test device in AdMob.
Also create an AdMob **consent message** (Privacy & messaging → GDPR, and "US states" if you want) – `safe_ads` shows it automatically.

## 3. Ads in the app (all through the `safe_ads` package)
| Type | Where | Rule |
|---|---|---|
| Banner | bottom of Home/Rank/Friends/Me (below the navigation bar) and Categories | collapses to nothing if not loaded or "ads removed" |
| Interstitial | when you leave the result screen / start the next puzzle | only between games, never during a guess; package cooldown and frequency caps |
| Rewarded | "Free · ad" in the hint sheet, "double coins" on the result, unlock a category | only when the player taps it |
No ads on the game screen while guessing, none during battles.

## 4. Play Console answers
**App content → Privacy policy:** paste the URL above.

**App access:** All functionality is available without login or special access.

**Ads:** *Yes, my app contains ads.*

**Content rating (IARC questionnaire):** Category *Game (not social casino)*. Violence: No. Sexual content: No. Profanity: No. Controlled substances: No. Gambling / simulated gambling: **No** (in-app coins are virtual, cannot be bought or cashed out). User-generated content / user interaction: **Users can interact** only through room codes and nicknames (no free chat). Shares location: No. Digital purchases: No. Expected result: Everyone / PEGI 3.

**Target audience and content:** Age groups **13+** (select 13–15, 16–17, 18+). Not "designed for children", so Families Policy does not apply. Appeals to children: No.

**Data safety:**
- Collects data: **Yes**. Shared with third parties: **Yes** (Google AdMob).
- Encrypted in transit: **Yes**. Users can request deletion: **Yes** (email contact in policy).
- Data types:
  - *Device or other IDs* → **Advertising ID**: collected, shared, purpose **Advertising or marketing**; optional: no (required by ads SDK).
  - *App activity → App interactions* (and *Other user-generated content*: nickname): collected for **App functionality** (leaderboard and rooms) and **Analytics/Advertising** via AdMob; shared with Google (ads).
  - *App info and performance → Crash logs / Diagnostics*: collected by the Google ads SDK, purposes **Analytics**; shared.
  - *Approximate location* (derived from IP by AdMob): collected + shared for **Advertising**.
  - *Personal info*: nickname only, entered by user, shown to other players, purpose App functionality.
  - Not collected: name, email, phone, address, contacts, photos, precise location, financial info, health.

**Advertising ID declaration:** *Yes*, the app uses the advertising ID – purposes **Advertising or marketing** (and Analytics). (The manifest already contains `com.google.android.gms.permission.AD_ID`.)

**Government apps:** No. **Financial features:** None. **Health:** None. **News app:** No. **COVID-19:** No.

**Store listing**
- App name: *NearWord – Word Guessing Game* (max 30 chars: "NearWord: Guess by Meaning")
- Short description (80): *Guess the secret word by meaning. Daily puzzle, friends battles, Hindi + English.*
- Full description: *NearWord ranks every guess by how close its MEANING is to a hidden word. Rank 1 wins! Play the daily word and climb the leaderboard, practise with Quick play or themed Categories, and challenge friends in live rooms and challenges with coin stakes. Choose Easy, Medium or Hard, English or हिंदी, Regular or India word style. Free to play with ads.*
- Category: *Word* · Tags: word, puzzle, brain · Contact email: nikhilsuthar301@gmail.com
- Assets still needed (you must supply): 512×512 icon (`assets/icon` / `tools/make_icon.py`), 1024×500 feature graphic, 2–8 phone screenshots.

## 5. Release checklist
1. Internal testing track first (upload the AAB, add testers' Gmail IDs).
2. New personal developer accounts must run **closed testing with ≥12 testers for 14 days** before Production access.
3. Rebuild with real AdMob ids (step 2), bump `version: 1.0.1+2` for every new upload (build number must always increase).
4. Firebase: if you want locked-down rules, enable Authentication → Anonymous and deploy `database.rules.secure.json`.
