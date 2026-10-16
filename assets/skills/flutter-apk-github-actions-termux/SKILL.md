---
name: flutter-apk-github-actions-termux
description: Build a Flutter (Dart) Android APK from Termux with NO local Flutter, NO laptop — Flutter project built entirely in GitHub Actions, android/ folder generated in CI, idempotent Android patch script, release APK auto-published. Use when the user asks for a Flutter/React-Native-style mobile app but only has Termux, or any "build APK in cloud" Flutter task.
---

# Flutter APK from Termux via GitHub Actions (no local Flutter)

Proven 13 Okt 2026 (KARTA KUBAR, Flutter 3.x stable, first build 5m16s, success).

## Core idea

The phone writes text only. **Never commit `android/`** — generate it in CI:

```yaml
- uses: subosito/flutter-action@v2
  with: { channel: stable, cache: true }
- run: |
    flutter create --org id.kartakubar --project-name app --platforms=android /tmp/scaffold
    cp -r /tmp/scaffold/android .
- run: bash tool/patch_android.sh   # idempotent branding/permissions
- run: flutter pub get
- run: flutter build apk --release
```

This kills the two classic blockers: you never need a local Flutter SDK, and you
never need to ship the binary `gradle-wrapper.jar` (the scaffold brings it).

## Repo layout (in `$HOME/<app>`, never `/storage`)

```
pubspec.yaml            name: karta_kubar   (valid dart id)
lib/main.dart  lib/core/...  lib/features/...  lib/shared/...
assets/{images,fonts,data}/   tool/patch_android.sh
.github/workflows/build.yml   .github/notes/release.md
```

`.gitignore` MUST ignore: `android/ ios/ linux/ macos/ windows/ web/ build/
.dart_tool/ *.keystore *.jks *.p12 key.properties`.

## Two non-obvious decisions that make it clean

1. **`--project-name app --org id.kartakubar`** → generated android's
   `applicationId`/`namespace` = `id.kartakubar.app` (clean, no underscore).
   The repo `pubspec.yaml` keeps `name: karta_kubar`. The Android module is
   **name-agnostic** — the Dart package name and the Android applicationId do
   NOT have to match. So you get a tidy package id without renaming anything.
2. **Default release signing = debug keystore.** Flutter's generated
   `android/app/build.gradle(.kts)` sets `signingConfig = signingConfigs.debug`
   for the release build type → `flutter build apk --release` produces an
   **installable** APK out of the box. Swap in a real keystore only at release
   phase (keystore in `$HOME`, NEVER committed; use GH secrets).

## tool/patch_android.sh (idempotent — test sed on a MOCK first!)

Generated `android/app/build.gradle.kts` (newer Flutter) vs `.gradle` (older) —
handle both. Insert permissions BEFORE `<application`:

```bash
M="android/app/src/main/AndroidManifest.xml"
sed -i 's/android:label="[^"]*"/android:label="KARTA KUBAR"/' "$M"
sed -i 's#<application#<uses-permission android:name="android.permission.CAMERA"/>\n    <application#' "$M"
```

Guard every step with `grep -q ... || exit 1` and `set -euo pipefail`.
Test the seds against a hand-written mock manifest locally (Termux `sed` works)
— cheap insurance against a 6-minute CI round-trip per typo.

## Workflow must-haves

- `permissions: contents: write` at top — else `softprops/action-gh-release`
  cannot publish (new repos default token to read-only contents).
- `actions/setup-java@v4` distribution temurin, java-version 17 (matches AGP).
- `body_path: .github/notes/release.md` — concise release notes, no file tables.
- upload-artifact path: `build/app/outputs/flutter-apk/app-release.apk`.

## Verify + deliver (from Termux)

```bash
gh run list --limit 1                    # completed / success
gh release view --json tagName,name,assets
gh release download <tag> -p app-release.apk -O /storage/emulated/0/Download/<App>-<v>.apk
am start -a android.intent.action.VIEW \
  -d "file:///storage/emulated/0/Download/<App>-<v>.apk" \
  -t application/vnd.android.package-archive
```

## Pitfalls

- A minimal Flutter **universal** release APK is ~40 MB (3 ABIs). Normal. To
  shrink: `flutter build apk --split-per-abi` or ship an AAB.
- Do NOT copy `pubspec.lock` from the scaffold — it belongs to the scaffold.
- First build ~5–6 min (downloads Flutter SDK + Gradle). Later builds cache.
- If CI fails, read the log via `gh run view <id> --log-failed`; usual suspects:
  bad pubspec constraint, sed pattern miss, missing `<application` anchor.
- iOS is NOT buildable from Termux (needs macOS). Android APK is the delivery;
  iOS via Codemagic / macOS runner later.
