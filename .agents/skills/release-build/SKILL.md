---
name: release-build
description: Build LetterLoom release artifacts safely, including automatic Android version-code increments and post-build verification.
---

# LetterLoom release builds

- Before every `flutter build appbundle --release` or Play Store release build, read the current `version:` in `pubspec.yaml` and increment the build number after `+`.
- Preserve the marketing version unless the user requests a version-name change. For example, `1.0.3+9` becomes `1.0.3+10`.
- Run `flutter analyze` and `flutter test` before the release build.
- Build the release artifact only after the increment, always using the local public runtime configuration: `flutter build appbundle --release --dart-define-from-file=dart_defines.local.json`.
- Verify the output artifact exists, reports the new version code, and contains the configured Supabase project URL. Never build a release with plain `flutter build appbundle --release`.
- Never upload or publish the artifact unless the user explicitly asks for Play Store submission.
