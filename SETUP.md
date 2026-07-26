# Bhasha Setup Guide

## Requirements

- Flutter SDK compatible with the checked-in project
- Android SDK and platform tools
- JDK compatible with the Android Gradle plugin
- Android 7.0 (API 24) or newer
- A Sarvam API key, unless a subscription key is supplied by the app

## Local project setup

```sh
cd /Users/anmolmoses/work/personal/bhasha
flutter pub get
flutter doctor
```

If Flutter has not created `android/local.properties`, add local paths without
committing the file:

```properties
sdk.dir=/absolute/path/to/Android/sdk
flutter.sdk=/absolute/path/to/flutter
```

Validate the project:

```sh
flutter analyze
flutter test
flutter build apk --debug
```

## Sarvam configuration

Bhasha stores a user-entered API key in Android secure storage. The key is not
logged. Translation, grammar checking, and language detection requests are
handled by `lib/services/sarvam_service.dart`.

The application may also receive a managed subscription key through its
existing subscription flow. Do not hard-code secrets in Dart, Kotlin,
documentation, or build output.

## Android integrations

### Double-tap screen translation

Screen translation is off by default and has a separate disclosure. Save the
Sarvam key, enable **Double-tap screen translation**, then enable the
floating overlay.

Every double tap starts `ScreenCapturePermissionActivity`, which displays
Android's MediaProjection consent prompt. `ScreenCaptureService` then:

- hides Bhasha overlays before capture;
- collects one frame through `ImageReader`;
- compresses the frame to an in-memory JPEG;
- stops MediaProjection immediately;
- sends the image to Sarvam Vision for OCR and normalized rectangles;
- sends only the extracted strings to Sarvam Mayura;
- draws translated labels through `ScreenTranslationOverlayController`.

The screenshot is not saved by Bhasha. Apps using `FLAG_SECURE` may produce a
blank capture and cannot be translated by this mode.

### Contextual translation across apps

The contextual feature requires the Bhasha accessibility service and is off by
default. Enabling it shows a separate disclosure before Android accessibility
settings are opened.

At runtime the native adapter:

- uses a dedicated resource-ID adapter for consumer WhatsApp;
- falls back to visible, non-editable, non-password accessibility text in
  other eligible apps;
- reacts to an explicit long-press on a supported text message;
- anchors a temporary Translate chip near that message;
- sends only the selected text to Flutter/Sarvam after the chip is tapped;
- offers Copy, Insert in reply, Close, and Retry;
- dismisses the contextual UI on scrolling, leaving the source app, or stale
  content.

Raw message text is not persisted in the contextual anchor. The anchor keeps a
hash and geometry so the selected node can be revalidated before translation.

### Floating overlay

The floating button requires Android's **Display over other apps** permission.
It operates on the currently focused editable field through the accessibility
service. The contextual UI temporarily hides this general bubble to
avoid overlapping controls.

### Custom keyboard

The IME must be enabled and selected by the user in Android keyboard settings.
The `BIND_INPUT_METHOD` permission is declared on the service, not requested by
the application. Likewise, `BIND_ACCESSIBILITY_SERVICE` belongs on the
accessibility service declaration.

## Permission model

- `INTERNET`: Sarvam translation and screen-OCR requests.
- `FOREGROUND_SERVICE_MEDIA_PROJECTION`: one-shot screen capture after consent.
- `SYSTEM_ALERT_WINDOW`: optional general floating button.
- Accessibility service: optional field replacement and contextual
  translation, enabled manually in system settings.
- Input method service: optional Bhasha keyboard, enabled manually in system
  settings.
- Foreground service: keeps the enabled floating overlay available.
- Android screen-capture consent: granted manually for each screen action.

Android does not allow Bhasha to silently grant any special access.

## Build and package

```sh
flutter build apk --debug
```

Output:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Installing is a separate, explicit action:

```sh
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Do not run the install command when only preparing a build artifact.

## Troubleshooting

### Contextual chip does not appear

- Confirm **Contextual translate across apps** is enabled in Bhasha.
- Confirm Bhasha is enabled under Android Accessibility.
- Open an eligible app and long-press visible text.
- Media-only, deleted, unsupported, or non-message nodes intentionally do not
  produce a chip.

### Sarvam request fails

- Verify the API key or managed subscription is present and valid.
- Confirm internet access.
- Use Retry on the contextual error card, or open Bhasha for settings.

### Double-tap screen translation fails

- Confirm the Sarvam API key is saved.
- Confirm **Double-tap screen translation** is enabled.
- Approve Android's capture prompt.
- Verify Sarvam accepts the subscription key and has credits.
- Try a normal app screen; secure or blank screens cannot be OCR'd.

### Android build fails

- Run `flutter doctor -v`.
- Verify SDK and Flutter paths in `android/local.properties`.
- Run `flutter clean && flutter pub get`.
- Treat SDK, Gradle, plugin-test, and Kotlin metadata errors separately from
  application compile failures.

## Relevant implementation files

- `lib/services/sarvam_service.dart`
- `lib/services/sarvam_vision_service.dart`
- `lib/services/overlay_request_handler.dart`
- `lib/services/platform_service.dart`
- `android/app/src/main/kotlin/com/yourapp/bhasha/BhashaAccessibilityService.kt`
- `android/app/src/main/kotlin/com/yourapp/bhasha/WhatsAppUiAdapter.kt`
- `android/app/src/main/kotlin/com/yourapp/bhasha/ContextualMessageOverlayController.kt`
- `android/app/src/main/kotlin/com/yourapp/bhasha/BhashaApplication.kt`
- `android/app/src/main/kotlin/com/yourapp/bhasha/ScreenCapturePermissionActivity.kt`
- `android/app/src/main/kotlin/com/yourapp/bhasha/ScreenCaptureService.kt`
- `android/app/src/main/kotlin/com/yourapp/bhasha/ScreenTranslationOverlayController.kt`
- `android/app/src/main/AndroidManifest.xml`
