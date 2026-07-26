# AGENTS.md

## Project Overview

Bhasha is a Flutter Android app for translation and grammar checking using the Sarvam API. It has two main Android integration surfaces:

- A system-wide floating overlay button.
- A custom Android keyboard/IME.

Keep Flutter responsible for the app UI, settings, API-key flow, and service coordination. Keep Android-specific behavior in the native Kotlin layer.

## Repository Layout

- `lib/main.dart` - Flutter entrypoint.
- `lib/screens/` - Main app screens, onboarding, home, and settings.
- `lib/widgets/` - Reusable Flutter UI components.
- `lib/services/` - Storage, Sarvam API calls, platform-channel wrappers, and overlay request handling.
- `lib/models/` - Data models and app mode enums.
- `lib/theme/` - App theme.
- `lib/constants/` - Static app constants such as languages.
- `android/app/src/main/kotlin/com/yourapp/bhasha/` - Native Android services and activity integration.
- `android/app/src/main/AndroidManifest.xml` - Android permissions and service declarations.
- `assets/` - Flutter assets.

## Development Commands

Run these from the repository root:

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

For Android-only build validation:

```sh
flutter build apk --debug
```

## Coding Guidelines

- Follow the existing Flutter structure and Material 3 style.
- Prefer small, focused widgets over large screen-level methods when UI grows.
- Keep API-key material in secure storage; do not log secrets.
- Keep Sarvam request and response parsing in `lib/services/sarvam_service.dart` (and `sarvam_vision_service.dart` for screen OCR) unless a broader service split is needed.
- Use method channels through the existing platform service layer rather than adding direct platform calls from screens.
- Preserve the existing lint posture in `analysis_options.yaml`.
- Use concise comments only where platform behavior or permission flow is not obvious.

## Native Android Guidelines

- Keep overlay, accessibility, IME, and activity behavior in Kotlin files under `android/app/src/main/kotlin/com/yourapp/bhasha/`.
- Update `AndroidManifest.xml` whenever adding or changing permissions, services, intent filters, or exported components.
- Be explicit about Android permission limitations. Overlay and keyboard behavior require user-granted system settings; normal apps cannot silently enable them.
- Avoid blocking the UI thread in Kotlin services. Use background work for network or slow operations.
- Keep package names, channel names, and manifest declarations consistent across Flutter and Kotlin.

## Testing And Verification

Before handing off code changes, run at least:

```sh
flutter analyze
```

Run `flutter test` when Dart logic changes. Run a debug APK build or `flutter run` when changing native Android code, manifest entries, platform channels, overlay behavior, or IME behavior.

For UI changes, verify on a small Android viewport as well as a typical phone viewport. Watch for text overflow, permission-flow dead ends, and controls that are too small to tap.

## Documentation

Existing docs include:

- `README.md` - General setup and feature overview.
- `SETUP.md` - Setup details.
- `QUICKSTART.md` - Quick start flow.
- `USER_GUIDE.md` - User-facing guide.
- `PROJECT_STATUS.md` and `IMPLEMENTATION_SUMMARY.md` - Implementation state and history.
- `ONE_TAP_FEATURE_SUMMARY.md` - One-tap feature notes.
- `SIMPLE_GUIDE_FOR_PARENTS.md` - Simplified user explanation.

Update docs when user-facing setup, permissions, app modes, or feature behavior changes.

## Agent Notes

- Do not overwrite user changes in this repository.
- Keep changes scoped to the requested behavior.
- If Android tooling fails, report the exact command and failure. Do not assume the app logic is broken when the failure is an SDK, emulator, signing, or local properties issue.
- Do not commit, branch, or push unless explicitly asked.
