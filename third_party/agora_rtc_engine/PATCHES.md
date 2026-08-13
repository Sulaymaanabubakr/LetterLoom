# LetterLoom Agora fork

Base package: `agora_rtc_engine` 6.5.4.

The Android SDK release bundled by Agora publishes `iris-rtc` and
`agora-special-full` AARs that both declare the legacy manifest package
`io.agora.rtc`. Android Gradle Plugin 9 rejects that duplicate namespace before
manifest merging. The fork keeps both native artifacts and rewrites only the
stale `package` attribute in `agora-special-full` to a unique plugin namespace
in the resolved Gradle cache artifact before Android processing.

This is intentionally source-controlled so clean machines and CI receive the
same deterministic fix. Remove this fork when Agora publishes an Android SDK
release whose AAR manifests no longer collide, then return the dependency to
the upstream pub.dev package.

The fork also raises the plugin's stale fallback `compileSdkVersion` from 31
to 36, matching this app's compile SDK and the AndroidX metadata requirements
of the bundled Agora dependencies.
