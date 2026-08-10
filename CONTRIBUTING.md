# Contributing to LetterLoom

Thank you for helping improve LetterLoom. Contributions should be focused, reproducible, and respectful of the existing game experience.

## Before you start

1. Fork the repository on GitHub.
2. Clone your fork and enter the repository:

   ```bash
   git clone https://github.com/Sulaymaanabubakr/LetterLoom.git
   cd LetterLoom
   ```

3. Install dependencies:

   ```bash
   flutter pub get
   ```

   Website contributors should also run `npm ci` inside `website/`.

## Branches

Create a branch from the default branch. Use a short descriptive name such as `fix/blank-tile-score`, `feature/room-history`, or `docs/setup-guide`. Do not commit credentials, generated build output, signing files, or local runtime configuration.

## Local development

Run the app with `flutter run`. Solo play does not require backend configuration. Online multiplayer requires the Supabase values described in the README and a project with the checked-in migrations and functions applied.

## Code style

Follow the existing Dart and Flutter structure. Keep game rules in the game engine, persistence concerns in `storage/`, and UI-specific behavior in the relevant feature. Prefer small, readable changes and avoid unrelated formatting or refactoring. For website changes, follow the existing TypeScript, React, and Next.js conventions.

## Tests

Before submitting a change, run the checks relevant to it:

```bash
flutter test
flutter analyze lib test
```

Website changes should also run:

```bash
cd website
npm run lint
npm run build
```

Add or update tests when changing scoring, placement validation, AI decisions, serialization, multiplayer state, or other behavior that can be verified automatically. UI changes should include a clear manual verification note and screenshots when useful.

## Pull requests

Open a pull request against the default branch and include:

- what changed;
- why the change is needed;
- tests and manual checks performed;
- screenshots for UI changes;
- any Supabase migration, function, or configuration steps required.

Keep each pull request focused and update documentation when setup or behavior changes. Maintainers may request narrower scope, additional tests, or clarification before review. Passing checks do not guarantee acceptance; maintainers also review compatibility, security, data handling, and fit with the project.

## Bugs and features

Use the GitHub issue templates. Bug reports should include the app version, platform, reproducible steps, expected result, actual result, and relevant logs or screenshots. Feature requests should describe the problem, proposed behavior, and alternatives considered. Do not include private personal information.
