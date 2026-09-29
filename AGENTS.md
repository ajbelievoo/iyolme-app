# Shortzz / Believoo Flutter App — Agent Notes

## Recent Fixes Applied

### Security
- Removed leaked signing secrets from git (`key.properties.txt`, SSH/signing keys) and added them to `.gitignore`.
- Moved hardcoded API key and base URL into `.env` via `flutter_dotenv`.
- Moved Google Maps API key and AdMob App ID out of `AndroidManifest.xml` into `local.properties` / `build.gradle` placeholders.
- Disabled cleartext traffic in `AndroidManifest.xml`.
- Created `.env.example` and `android/local.properties.example` for reference.

### Code Quality
- Enabled lint rules: `avoid_print`, `prefer_const_constructors`, etc.
- Replaced all `print(...)` calls in `lib/` with `Loggers.info(...)`.
- Removed unused/commented imports.
- Fixed several memory leaks by cancelling `Timer` and `StreamSubscription` instances in `onClose()`.
- Improved error logging in `BaseController` instead of silently swallowing errors.

### Build / Config
- Enabled ProGuard/R8 shrinking and resource shrinking for release builds.
- Re-enabled Gradle daemon, parallel builds, and caching for faster builds.
- Added GitHub Actions CI workflow (`.github/workflows/flutter.yml`).

### UX / Cleanup
- Removed hardcoded translation overrides from `main.dart` (configure branding via backend/localization instead).
- Removed the 5-minute background-restart logic in `main.dart`.
- Resolved or clarified TODO comments across the codebase.
- Added a starter design-token file at `lib/utilities/design_tokens.dart`.
- Expanded `test/widget_test.dart` with a few unit tests.

## Manual Steps Still Required

1. **Rotate exposed secrets**
   - Keystore passwords in `android/key.properties` (create from `key.properties.example`).
   - Google Maps API key and AdMob App ID.
   - Firebase project restrictions/API keys.
   - Any server API keys that were exposed in `google-services.json` or `const_res.dart` history.

2. **Package name alignment** — DECIDED: canonical package is **`com.vidmite.app`** (Android applicationId already matches; backend `google_package_name` needs `com.iyolme.app` → `com.vidmite.app`).
   - Regenerate `google-services.json` (Android) and `GoogleService-Info.plist` (iOS bundle `com.retrytech.bubbly` → `com.vidmite.app`) from the Firebase console.
   - Token redeem minimum: **1000 tokens** (app dialog enforces; backend must enforce same gate).
   - Streak rewards: approved — backend grants bonus scratch cards via pending-cards at day 3/7/30 streaks (server can compute streak from `tbl_reward_history` claims).

3. **Run Flutter tooling**
   ```bash
   flutter pub get
   dart fix --apply
   flutter analyze
   flutter test
   flutter build apk --release
   ```

4. **Create real `.env` and `android/local.properties`**
   ```bash
   cp .env.example .env
   cp android/local.properties.example android/local.properties
   ```
   Fill in the actual values and never commit these files.

## Known Large Refactors Outstanding

- Split the ~4000-line `livestream_screen_controller.dart` into focused controllers.
- Standardize state management: remove `setState` usage from GetX controllers.
- Decouple tightly coupled controllers (e.g., `DashboardScreenController` direct `Get.find` chains).
- Implement pagination for large lists.
- Optimize video player reuse/caching for reels.
- Add comprehensive widget/integration tests.

## Recovery Notes (Sep 2026)

- Disk recovery corrupt files: `pubspec.yaml`, `android/app/build.gradle`, `android/app/google-services.json`, `base/manifest/AndroidManifest.xml`, 16 `.dart` files, `optimize_images.dart`, 3 webrtc java files, `SafeCameraXHandler.java`.
- Corrupt `.dart` sources were recovered from `build/app/intermediates/flutter/debug/flutter_assets/kernel_blob.bin` via `scripts/extract_kernel_sources.dart` (embedded kernel sources). Recovered set kept in `scripts/kernel_recovered/`.
- `google-services.json` rebuilt from `build/app/generated/res/processReleaseGoogleServices/values/values.xml` (project hitune-live-box).
- `pubspec.yaml` rebuilt from `pubspec.lock` direct deps (name: shortzz, version 1.0.1+42).
- Toolchain now: Flutter 3.47.5 / Dart 3.13.4, Gradle 8.14.3, AGP 8.11.1, Kotlin 2.2.20, JDK 21 (`flutter config --jdk-dir`).
- Release APK: `build/app/outputs/flutter-apk/app-release.apk` (com.vidmite.app, v1.0.1+42, hitunekey).

## Build Size Notes (Sep 2026)

- Fat release APK was ~190MB (3 ABIs bundled). Gradle `ndk.abiFilters` does NOT work here — the Flutter Gradle plugin overrides it. To shrink APKs use the Flutter flag instead:
  - Direct APK (ARM only, drops x86_64 ~30MB): `flutter build apk --release --target-platform android-arm,android-arm64`
  - Per-ABI APKs: `flutter build apk --release --split-per-abi`
  - Play Store (best): `flutter build appbundle` — Play delivers ~60-70MB per device
- `CustomImage` now sets `memCacheWidth/memCacheHeight` — images decode at display size, not full resolution (RAM fix).
- Backend work pending is tracked in `BACKEND_TASKS.md` (sell endpoint, history endpoint, token redeem, dummy-live migration to Cloud Function, FCM on pending cards, server-side daily limit).
- `ScratchCollectController` is lazy (not in `InitialBinding`) — created on first reel/vault use, and `onInit` skips API calls when logged out.
