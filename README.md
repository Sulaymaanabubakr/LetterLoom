# LetterLoom

LetterLoom is an open-source Flutter word-strategy game for solo play and online matches. Build words on a 15×15 board, manage a seven-tile rack, score across premium squares, and play against a computer opponent or another player online.

## Project status

LetterLoom is under active development. The repository contains the Flutter application, automated tests, bundled word data, Supabase migrations and Edge Functions for online multiplayer, and an accompanying Next.js website. The current app version is `1.0.0+1`.

Solo games work without a network connection. Online multiplayer is implemented through Supabase anonymous authentication, protected Edge Functions, Realtime room updates, and persisted game state; it requires a configured Supabase project and is disabled when the required runtime values are absent. Mobile push notifications are an optional integration that also requires Firebase configuration and server-side credentials.

## Features

- Solo games against a computer opponent, with `Easy`, `Medium`, and `Hard` difficulty levels.
- Online two-player rooms: create or join a room with a six-character code, manage rooms, synchronize turns, enforce a 120-second turn countdown, and receive room updates.
- A 15×15 board with centre, double-letter, triple-letter, double-word, and triple-word squares.
- Live word placement validation for first-move centre coverage, straight-line placement, gaps, connectivity, cross-words, blank tiles, and bingo bonuses, with immediate legal/invalid feedback while tiles are being placed.
- Standard tile scores and distributions, including two blank tiles and a 50-point seven-tile bonus.
- A bundled ENABLE1 word list for offline exact word validation and AI prefix search.
- Background-isolate AI search so computer turns do not block the main UI.
- Local JSON persistence for in-progress games, settings, and statistics, including continue/resume support.
- 2–4-player multiplayer rooms with avatars, scores, Agora voice chat, active-speaker indicators, and private racks/tile bags separated from public room state in the Supabase schema.
- Settings for music, sound effects, haptics, and animation speed, plus statistics by difficulty.

## Screenshots

The repository includes real iPhone store screenshots:

![LetterLoom home screen](assets/store/Screenshot%20iPhone%2017%20Pro%2009-08-2026%20at%2011.15.17.png)
![Difficulty selection](assets/store/Screenshot%20iPhone%2017%20Pro%2009-08-2026%20at%2011.15.28.png)
![Solo game board](assets/store/Screenshot%20iPhone%2017%20Pro%2009-08-2026%20at%2011.15.35.png)

## Technology

- Flutter and Dart for the mobile and desktop application.
- Riverpod for application state management.
- `path_provider` and JSON serialization for local persistence.
- `audioplayers` for bundled music.
- Supabase Flutter, Postgres migrations, Realtime, anonymous Auth, and Edge Functions for online multiplayer.
- Firebase Core and Firebase Cloud Messaging for optional push notifications.
- Next.js, React, and TypeScript for the website in `website/`.

## Architecture

The application is organized around a local game engine and feature modules:

```text
lib/
├── ai/                  Computer move search and isolate entry point
├── core/                Audio, haptics, push, Supabase bootstrap, and UI utilities
├── dictionary/          Bundled word-list loading and lookup
├── features/            Home, game, multiplayer, settings, statistics, and help screens
├── game_engine/         Board configuration, tile distribution, validation, and scoring
├── models/              Board, tile, game, move, settings, and statistics models
├── storage/             Local game, settings, and statistics persistence
└── theme/               Material theme and visual styling
supabase/
├── functions/           Multiplayer and notification Edge Functions
└── migrations/          Multiplayer, private-state, realtime, and push-device schema
website/                 Next.js public website
test/                    Dart unit, persistence, AI, rules, and widget tests
```

The rules validator is the source of truth for legal moves and scores. The dictionary service loads `assets/dictionary/enable1.txt` into an exact-match set and sorted prefix-search list. The AI receives serialized board, rack, difficulty, and dictionary data and returns a legal placement, pass, or exchange. The multiplayer repository calls the Supabase Edge Functions for room creation, joining, state initialization, turn synchronization, and timeout handling.

## Requirements

- Flutter `3.44.6` or a compatible Flutter SDK using Dart `3.12.2` or later within the constraint in `pubspec.yaml`.
- Android Studio and an Android SDK for Android development.
- Xcode for iOS development and signing.
- A connected device or emulator/simulator for interactive runs.
- Node.js and npm only when working on the separate `website/` project.
- Supabase CLI `2.106.0` or a compatible version only when working on the online backend.

## Local development

Install the Flutter dependencies from the repository root:

```bash
flutter pub get
```

Run the app with a connected device or emulator:

```bash
flutter run
```

To enable online multiplayer, create an untracked `dart_defines.json` in the repository root:

```json
{
  "SUPABASE_URL": "https://your-project-ref.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "your-publishable-or-anon-key"
}
```

Then run:

```bash
flutter run --dart-define-from-file=dart_defines.json
```

For the maintained local development configuration, use the guarded command
instead. It refuses to start an unconfigured build, which prevents a Google
identity from being presented as an online LetterLoom account without a
Supabase session:

```bash
./tool/run_android.sh
```

Do not put a Supabase secret/service-role key in this file or in the Flutter client. The file is ignored by Git. Anonymous Sign-Ins must be enabled in the Supabase project for multiplayer sessions.

The Firebase files used by mobile push notifications are intentionally ignored (`google-services.json`, `GoogleService-Info.plist`, and the server service-account JSON). They are not required for solo or online board play, but must be provisioned separately for push notifications.

### Supabase backend

The checked-in migrations create multiplayer rooms, participants, private racks and tile bags, move history, Realtime configuration, turn countdown fields, and push-device registration. From the repository root, authenticate the Supabase CLI, link the intended project, and apply migrations:

```bash
supabase link --project-ref <your-project-ref>
supabase db push --linked
```

Deploy the Edge Functions when online backend code changes:

```bash
supabase functions deploy create-multiplayer-game
supabase functions deploy join-multiplayer-game
supabase functions deploy list-multiplayer-games
supabase functions deploy manage-multiplayer-room
supabase functions deploy multiplayer-game-state
```

The push-notification helper additionally expects the server-side `FIREBASE_SERVICE_ACCOUNT_JSON` secret. Never commit that value.

### Website

The website is a separate npm project:

```bash
cd website
npm ci
npm run dev
```

For a production website build:

```bash
npm run lint
npm run build
npm run start
```

## Android and iOS

Run on Android with `flutter run` after installing an emulator or connecting a device. The Android application id is `com.letter.loom` and its configured target SDK is 36.

Run on iOS with `flutter run` after opening the iOS project on a macOS machine with Xcode configured. The iOS project currently targets iOS 15.0 and uses bundle identifier `com.letter.loom`. Apple signing, Firebase configuration, and provisioning are environment-specific and are not committed.

Build commands represented by the Flutter project configuration include:

```bash
flutter build apk --release
flutter build appbundle --release
flutter build ipa --release
```

Release signing files and runtime configuration are local-only. Verify signing, entitlements, Firebase setup, Supabase configuration, and store metadata in the target platform before distributing an artifact.

## Tests and linting

Run the automated Dart and Flutter tests:

```bash
flutter test
```

Analyze the application and test source:

```bash
flutter analyze lib test
```

The website has its own lint command and should be checked from `website/`:

```bash
npm run lint
```

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Keep changes focused, preserve existing gameplay and online-play behavior unless the change is intentional and tested, and include tests for changes to rules, scoring, persistence, AI, or multiplayer state handling.

## Bugs and feature requests

Use the repository issue templates for [bug reports](https://github.com/Sulaymaanabubakr/LetterLoom/issues/new?template=bug_report.yml) and [feature requests](https://github.com/Sulaymaanabubakr/LetterLoom/issues/new?template=feature_request.yml). Include reproducible technical details, not private account or device information.

## Security

Please read [SECURITY.md](SECURITY.md). Do not post exploitable vulnerability details in a normal public issue. A private GitHub Security Advisory is preferred where repository settings support it.

## License

LetterLoom's original source code is licensed under the [MIT License](LICENSE). The MIT license does not cover the bundled dictionary, music, fonts, branding, screenshots, or other third-party materials. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for their attribution and licensing information.

## Acknowledgements

- The bundled word list and audio tracks are credited separately in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and in the app's About screen.
- LetterLoom uses the open-source Flutter, Dart, Riverpod, Supabase, Firebase, Next.js, React, and other packages listed in `pubspec.yaml` and `website/package.json`.
