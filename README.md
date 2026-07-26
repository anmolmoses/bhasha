# Bhasha

Bhasha is an Android writing assistant built with Flutter and native Kotlin. It can translate text, correct grammar, and turn speech into a message in the language you choose, using your own Sarvam API key.

Its primary experience is a draggable, system-wide floating bubble. From another app, tap the bubble to process the focused text field, or hold it to speak.

## What Bhasha does

### In the Flutter app

- Translate text between 35 supported languages.
- Automatically detect the source language when enabled.
- Correct grammar, spelling, and punctuation.
- Copy translated or corrected text to the clipboard.
- Configure default source and target languages.
- Store the Sarvam API key securely on the device.
- Configure and control the Android floating assistant.

### From the floating assistant

The bubble can be assigned one of two actions in **Settings → One-Tap Action**:

1. **Translate**

   Reads text from the currently focused editable field, translates it using the configured language pair, and replaces the original text.

2. **Grammar**

   Reads the focused text, corrects it in the configured target language, and replaces the original text.

Holding the bubble records speech and appends the result to the focused field, whichever action is selected.

## Current implementation status

| Surface | Status |
| --- | --- |
| In-app translation | Implemented |
| In-app grammar correction | Implemented |
| One-tap overlay translation | Implemented |
| One-tap overlay grammar correction | Implemented |
| Hold-to-speak voice translation | Implemented |
| Custom Android keyboard/IME | Scaffolded |
| Keyboard Translate and Grammar actions | Not yet connected to Sarvam |

The custom keyboard is registered with Android and includes a QWERTY layout and action toolbar, but its Translate and Grammar handlers are currently placeholders. The floating assistant is the complete system-wide workflow.

## Requirements

- Flutter SDK with Dart 3 support
- Android SDK 35
- Android 7.0 (API 24) or newer
- An Android device or emulator
- A Sarvam API key

Bhasha is currently Android-only. The overlay, accessibility service, microphone capture, and IME are implemented in native Kotlin.

## Getting started

```sh
git clone https://github.com/anmolmoses/bhasha.git
cd bhasha
flutter pub get
flutter run
```

To validate an Android debug build:

```sh
flutter build apk --debug
```

On first launch:

1. Choose the default source and target languages.
2. Add a Sarvam API key.
3. Finish onboarding.
4. Open **Settings** to configure the floating assistant.

## Setting up the floating assistant

Android does not allow apps to enable overlay or accessibility access silently. Both permissions must be granted manually by the user.

1. Open Bhasha and go to **Settings**.
2. Under **One-Tap Translation**, grant **Overlay Permission**.
3. Grant access to the **Bhasha Accessibility Service**.
4. Choose Translate or Grammar as the **One-Tap Action**.
5. Turn on **Floating bubble active**.

### Translate or correct text in another app

1. Open an editable field in an app such as Messages, WhatsApp, email, or Notes.
2. Type or edit some text and keep the field focused.
3. Tap the Bhasha bubble.
4. Wait for the processed text to replace the original content.

Some apps expose editable text differently to Android accessibility services. Automatic reading or replacement may therefore vary by app.

### Speak a message in another app

1. Open an editable field in an app such as WhatsApp, Messages, or email, and tap into it.
2. **Press and hold** the Bhasha bubble. It turns red and shows "Listening…".
3. Speak in whichever language you like — the app detects it, you do not select it.
4. Release the button.
5. What you said is transcribed, translated into the **target language** set in Bhasha, and appended to the message box.

Notes:

- Recording stops automatically at 28 seconds, because Sarvam's speech endpoint rejects anything over 30. The status pill counts down from 20 seconds so a long message is never lost silently.
- Speech already in the target language is inserted as transcribed, with no translation round trip.
- Dictated text is **appended** to whatever is already in the field, so holding the bubble never destroys something you typed.
- The recording is written to the app cache and deleted as soon as the request finishes, whether it succeeded or failed.

## Sarvam integration

Bhasha sends requests directly from the device to the Sarvam API. Sarvam is the only inference provider; there is no fallback. It currently uses:

- `/speech-to-text` (`saaras:v3`) for hold-to-speak transcription
- `/translate` (`mayura:v1`) for translation
- `/text-lid` for source-language detection
- `/v1/chat/completions` (`sarvam-105b`) for grammar correction

Sarvam API usage is billed to the account associated with the API key. The key is not included in the repository.

## Privacy and permissions

### Local data

- The Sarvam API key is stored with `flutter_secure_storage`.
- Language and style preferences are stored locally with `shared_preferences`.
- Secrets should never be committed to the repository.

### Android permissions and services

| Permission or service | Why it is needed |
| --- | --- |
| Internet | Send requests to the Sarvam API |
| Display over other apps | Show the draggable floating assistant |
| Foreground service | Keep the overlay available outside Bhasha |
| Accessibility service | Read and replace text in the focused editable field |
| Microphone | Record speech while the bubble is held down |
| Microphone foreground service | Capture audio from the overlay service on Android 14 and newer |
| Input method service | Register the custom Bhasha keyboard |

The accessibility service is used when the user taps or holds the floating bubble; it is not intended to continuously collect typed text. Bhasha does not request the accessibility screenshot capability, so no screen pixels ever leave the device. Text selected for processing, and speech recorded while the bubble is held, are sent to Sarvam.

## Architecture

```text
Flutter
├── Screens and widgets
├── Secure key and preference storage
├── Sarvam request and response handling
└── Platform service and overlay request handler
             │
             │ MethodChannel
             ▼
Native Android (Kotlin)
├── MainActivity
├── OverlayService
├── BhashaAccessibilityService
├── VoiceCaptureManager
└── CustomKeyboardIME
```

Flutter owns the app UI, settings, storage coordination, and Sarvam requests. Kotlin owns Android-specific permissions, services, overlays, accessibility operations, microphone capture, and IME behavior.

## Repository layout

```text
lib/
├── constants/     Supported languages
├── models/        Translation, grammar, mode, voice, and profile models
├── screens/       Onboarding, home, and settings
├── services/      Sarvam, storage, platform-channel, and overlay coordination
├── theme/         Material 3 theme
└── widgets/       Reusable UI components

android/app/src/main/
├── AndroidManifest.xml
├── kotlin/com/yourapp/bhasha/
│   ├── MainActivity.kt
│   ├── OverlayService.kt
│   ├── BhashaAccessibilityService.kt
│   ├── VoiceCaptureManager.kt
│   └── CustomKeyboardIME.kt
└── res/           Keyboard, accessibility, and Android UI resources
```

## Development

Run the standard checks from the repository root:

```sh
flutter pub get
flutter analyze
flutter test
```

`test/` covers Sarvam response parsing, typed errors, request-size chunking, the language table, and the voice-translate path.

For changes to Kotlin, the Android manifest, platform channels, overlay behavior, accessibility behavior, or the IME, also run:

```sh
flutter build apk --debug
```

## Known limitations

- Android is the only supported platform.
- Overlay and accessibility access require manual approval in Android settings.
- One-tap text replacement depends on the target app exposing an editable accessibility node.
- Hold-to-speak is capped at 28 seconds, because Sarvam's REST speech endpoint rejects audio over 30.
- The custom keyboard's AI actions are not implemented yet.
- The release build currently uses debug signing and is not configured for Play Store distribution.

## Additional documentation

- [Sarvam Buildathon plan and end-to-end build prompt](SARVAM_BUILDATHON.md)
- [Setup guide](SETUP.md)
- [Quick start](QUICKSTART.md)
- [User guide](USER_GUIDE.md)
- [One-tap feature notes](ONE_TAP_FEATURE_SUMMARY.md)
- [Simple guide for parents](SIMPLE_GUIDE_FOR_PARENTS.md)
- [Implementation summary](IMPLEMENTATION_SUMMARY.md)
