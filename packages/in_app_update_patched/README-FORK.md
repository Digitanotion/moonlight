# Why this is forked

This is a local copy of the `in_app_update` pub.dev package (v4.2.5),
wired into the app via a `dependency_overrides` entry in the top-level
`pubspec.yaml` — every `import 'package:in_app_update/in_app_update.dart'`
elsewhere in the app keeps working unchanged, it just resolves here
instead of pub.dev.

The **only** deliberate change from upstream: Google Play's
`InstallStateUpdatedListener` callback (Android-side, in
`InAppUpdatePlugin.kt`) already receives an `InstallState` object with
real `bytesDownloaded()`/`totalBytesToDownload()` methods, but the
upstream plugin only forwards the bare status int to Dart, discarding
those two numbers. This fork forwards all three (as a small Map) so the
Dart side (`installUpdateListener`, now `Stream<InstallProgress>`
instead of `Stream<InstallStatus>`) can show a real download-progress
percentage instead of only "downloading vs. downloaded".

`checkForUpdate`, `performImmediateUpdate`, `startFlexibleUpdate`, and
`completeFlexibleUpdate` are all byte-for-byte identical to upstream.

## Upgrading

If pub.dev ships a newer `in_app_update` with fixes we want, re-copy its
`android/`, `ios/`, `lib/`, and `pubspec.yaml` here and re-apply the same
`addState`/`installUpdateListener` change (diff against this fork's git
history to find it quickly).
