# Bhasha Setup Guide

This guide will help you set up and run the Bhasha language assistant app.

## Prerequisites

1. **Flutter SDK** (version 3.0 or higher)

   - Download from: https://flutter.dev/docs/get-started/install
   - Add Flutter to your PATH

2. **Android Studio** or **Android SDK**

   - Required for Android development
   - Install Android SDK and command-line tools
   - Android 7.0 (API 24) or newer on the device

3. **Sarvam API Key**
   - Sign up at: https://dashboard.sarvam.ai
   - Create an API key in the API keys section (it starts with "sk_")
   - You'll need this to enable translation, grammar checking, speech, playback, and screen OCR
   - Bhasha sends it to Sarvam in the `api-subscription-key` header and nowhere else

## Installation Steps

### 1. Clone and Setup

```bash
cd /path/to/bhasha
flutter pub get
flutter doctor
```

### 2. Configure Android Local Properties

If Flutter has not created `android/local.properties`, add local paths without committing the file:

```properties
sdk.dir=/absolute/path/to/Android/sdk
flutter.sdk=/absolute/path/to/flutter
```

### 3. Validate and Run

```bash
flutter analyze
flutter test
flutter run
```

Or use your IDE:

- **VS Code**: Press F5
- **Android Studio**: Click the Run button

## First-Time Setup

When you launch the app for the first time:

1. **Welcome Screen**: Review the app features
2. **Language Selection**: Choose your source language (e.g., Kannada) and target language (e.g., English)
3. **API Key**: Enter your Sarvam API key
   - The key is stored securely on your device and is never logged
   - It's never transmitted except to Sarvam's API
   - Bhasha verifies the key with Sarvam when you save it
4. **Get Started**: Complete the onboarding

## Setting Up the Floating Assistant

1. Go to Settings
2. Under "One-Tap Translation", grant the overlay permission when prompted
3. Enable the Bhasha Accessibility Service
4. Choose "Translate" or "Grammar" as the One-Tap Action
5. Turn on "Floating bubble active"
6. The bubble will appear over all apps: tap it to process the focused text field, press and hold it to speak, or double-tap it to translate the visible screen

The custom keyboard (IME) is registered with Android but its Translate and Grammar buttons are placeholders; use the floating bubble.

## Android Integrations

### Double-tap screen translation

Screen translation is off by default and has a separate disclosure. Save the Sarvam key, enable **Double-tap screen translation** in Settings, then enable the floating overlay.

On a double tap, Bhasha first tries to read the visible text straight from the accessibility tree — exact text and bounds, no screen capture, and a result in about a second. Only when the tree yields nothing readable does the capture path run: `ScreenCapturePermissionActivity` shows Android's MediaProjection consent prompt, then `ScreenCaptureService`:

- hides Bhasha overlays before capture;
- collects one frame through `ImageReader`;
- compresses the frame to an in-memory JPEG;
- stops MediaProjection immediately;
- sends the image to Sarvam Vision for OCR and normalized rectangles;
- sends only the extracted strings to Sarvam translation (Mayura for its
  original language set, Sarvam Translate for Konkani and expanded languages);
- converts Kannada-to-Konkani results to Kannada script with Sarvam transliteration;
- draws translated labels through `ScreenTranslationOverlayController`.

The screenshot is not saved by Bhasha. The Sarvam Vision job takes roughly 10–25 seconds. Apps using `FLAG_SECURE` may produce a blank capture and cannot be translated by this mode.

### Contextual translation across apps (scaffolded)

Settings has a **Contextual translate across apps** toggle with its own disclosure, and the codebase contains the WhatsApp and generic messaging UI adapters plus the `translate_message` handler. The long-press trigger is not wired yet: the accessibility service does not subscribe to long-press events, so long-pressing a message does not produce a Translate chip in this build. `WHATSAPP_CONTEXTUAL_TRANSLATE.html` documents the intended design.

### Floating overlay

The floating button requires Android's **Display over other apps** permission. It operates on the currently focused editable field through the accessibility service.

### Custom keyboard

The IME must be enabled and selected by the user in Android keyboard settings. The `BIND_INPUT_METHOD` permission is declared on the service, not requested by the application. Likewise, `BIND_ACCESSIBILITY_SERVICE` belongs on the accessibility service declaration.

## Features

### Translation

- Translate text between the 23 supported languages
- Results are spoken aloud with Bulbul TTS in the saved voice and pace
- Copy results to clipboard

### Grammar Checking

- One-tap grammar and spelling correction in the focused field
- Corrections respect the saved reply tone and approved-names glossary
- Undo restores the original text for a few seconds after replacement

### Hold-to-Speak

- Press and hold the bubble, speak in any supported language, release
- The transcribed, translated result is appended to the focused field
- Recording is capped at 28 seconds; temporary audio is deleted after each request

### Double-Tap Screen Translation

- Double-tap the bubble to translate everything visible on screen
- Accessibility-first, with Sarvam Vision OCR as the capture fallback
- Translated labels are drawn over the original text; tap anywhere to dismiss

### Supported Languages

Sarvam's 22 Indian languages plus English (23 total):

- Kannada, English, Hindi, Tamil, Telugu, Malayalam, Marathi, Bengali
- Gujarati, Punjabi, Odia, Assamese, Urdu, Nepali, Konkani, Kashmiri
- Sindhi, Sanskrit, Santali, Manipuri, Bodo, Maithili, Dogri

## Permission Model

- **INTERNET**: Sarvam translation, speech, playback, and screen-OCR requests
- **SYSTEM_ALERT_WINDOW**: the floating bubble overlay
- **Accessibility service**: read and replace text in the focused field, and read visible text for screen translation; enabled manually in system settings
- **RECORD_AUDIO**: hold-to-speak (requested only when **Hold to speak** is enabled)
- **Foreground service**: keeps the bubble available outside Bhasha
- **FOREGROUND_SERVICE_MEDIA_PROJECTION**: one-shot screen capture after Android's consent prompt, granted per capture
- **BIND_INPUT_METHOD**: the custom keyboard (optional; scaffolded)

Android does not allow Bhasha to silently grant any special access.

## Build and Package

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

## Troubleshooting

### App won't build

- Run `flutter doctor -v`
- Verify SDK and Flutter paths in `android/local.properties`
- Clear build cache: `flutter clean && flutter pub get`
- Treat SDK, Gradle, plugin-test, and Kotlin metadata errors separately from application compile failures

### Floating bubble not appearing

- Check overlay permission is granted
- Go to Settings > Apps > Bhasha > Permissions
- Enable "Display over other apps"

### Bubble taps do nothing

- Ensure the Bhasha Accessibility Service is enabled in Android settings
- Make sure a text field is focused in the target app
- Some apps expose editable text differently; behavior varies by app

### Double-tap screen translation fails

- Confirm the Sarvam API key is saved
- Confirm **Double-tap screen translation** is enabled
- Approve Android's capture prompt
- Verify Sarvam accepts the subscription key and has credits
- Try a normal app screen; secure or blank screens cannot be OCR'd

### Translation not working

- Verify your API key is correct
- Check internet connection
- Ensure you have credits on your Sarvam account
- Check the key on the Sarvam dashboard

### Build errors with Kotlin/Gradle

- Ensure you have a JDK compatible with the Android Gradle plugin
- Update Android Studio to latest version
- Sync Gradle files

## Development

### Project Structure

```
lib/
  ├── main.dart              # App entry point
  ├── models/                # Data models, parent profile, conversation context, screen blocks
  ├── screens/               # UI screens
  ├── services/              # Sarvam clients (text + vision), storage, profile, platform bridge
  ├── widgets/               # Reusable UI components
  └── constants/             # Supported languages

android/
  └── app/src/main/kotlin/   # Native Android code
      ├── MainActivity.kt
      ├── OverlayService.kt
      ├── BhashaAccessibilityService.kt
      ├── VoiceCaptureManager.kt
      ├── ScreenCapturePermissionActivity.kt
      ├── ScreenCaptureService.kt
      ├── ScreenTranslationOverlayController.kt
      ├── WhatsAppUiAdapter.kt / GenericMessagingUiAdapter.kt
      └── CustomKeyboardIME.kt
```

### Relevant implementation files

- `lib/services/sarvam_service.dart`
- `lib/services/sarvam_vision_service.dart`
- `lib/services/overlay_request_handler.dart`
- `lib/services/platform_service.dart`
- `android/app/src/main/kotlin/com/yourapp/bhasha/BhashaAccessibilityService.kt`
- `android/app/src/main/kotlin/com/yourapp/bhasha/WhatsAppUiAdapter.kt`
- `android/app/src/main/kotlin/com/yourapp/bhasha/BhashaApplication.kt`
- `android/app/src/main/kotlin/com/yourapp/bhasha/ScreenCapturePermissionActivity.kt`
- `android/app/src/main/kotlin/com/yourapp/bhasha/ScreenCaptureService.kt`
- `android/app/src/main/kotlin/com/yourapp/bhasha/ScreenTranslationOverlayController.kt`
- `android/app/src/main/AndroidManifest.xml`

### Adding New Languages

Bhasha's language list is deliberately limited to what Sarvam supports. Edit `lib/constants/languages.dart` and add a `SarvamLanguage` entry with the BCP-47 code Sarvam accepts:

```dart
static const List<SarvamLanguage> all = [
  SarvamLanguage('Kannada', 'kn-IN'),
  // ... add here only if Sarvam supports the code
];
```

### Modifying Prompts

Sarvam request and response handling lives in `lib/services/sarvam_service.dart` (and `lib/services/sarvam_vision_service.dart` for screen OCR). Grammar and rewrite prompt construction lives in `lib/services/overlay_request_handler.dart` and `lib/services/voice_prompts.dart`.

## API Costs

Sarvam API usage is billed to the account associated with your key. Monitor usage and credits on the Sarvam dashboard: https://dashboard.sarvam.ai

## Privacy & Security

- API keys are stored encrypted on device; do not hard-code secrets in Dart, Kotlin, documentation, or build output
- No data is sent to any server except Sarvam, and only when you act (tap, hold, double-tap, translate)
- The screen-capture fallback sends one in-memory frame per double tap and never writes it to disk
- Recorded audio is deleted from the device as soon as each request finishes
- Translation history is not saved; only saved preferences and the approved-names glossary persist
- App works offline for UI (requires internet for API calls)

## Support

For issues or questions:

1. Check this documentation
2. Review Flutter and Android documentation
3. Check the Sarvam API documentation
4. File issues in the project repository

## License

See LICENSE file for details.
