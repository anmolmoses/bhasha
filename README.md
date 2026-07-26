# Bhasha

Bhasha is an Android writing assistant built with Flutter and native Kotlin. It can translate text, correct grammar, and suggest replies for posts on X using your own OpenAI API key.

Its primary experience is a draggable, system-wide floating bubble. From another app, tap the bubble to process the focused text field or capture the visible screen for reply suggestions.

## What Bhasha does

### In the Flutter app

- Translate text between 35 supported languages.
- Automatically detect the source language when enabled.
- Correct grammar, spelling, and punctuation.
- Copy translated or corrected text to the clipboard.
- Configure default source and target languages.
- Store the OpenAI API key securely on the device.
- Configure and control the Android floating assistant.

### From the floating assistant

The bubble can be assigned one of three actions in **Settings → One-Tap Action**:

1. **Translate**

   Reads text from the currently focused editable field, translates it using the configured language pair, and replaces the original text.

2. **Grammar**

   Reads the focused text, corrects it in the configured target language, and replaces the original text.

3. **X Replies**

   Captures the visible screen, asks OpenAI to infer the post being viewed, and displays copyable reply suggestions in an overlay.

X reply suggestions can be customized by:

- Tone: Warm, Smart, Funny, or Direct
- Length: Very short, Short, Medium, or Detailed
- Number of suggestions
- Emoji preference
- Custom style instructions

## Current implementation status

| Surface | Status |
| --- | --- |
| In-app translation | Implemented |
| In-app grammar correction | Implemented |
| One-tap overlay translation | Implemented |
| One-tap overlay grammar correction | Implemented |
| Screenshot-based X reply suggestions | Implemented |
| Custom Android keyboard/IME | Scaffolded |
| Keyboard Translate and Grammar actions | Not yet connected to OpenAI |

The custom keyboard is registered with Android and includes a QWERTY layout and action toolbar, but its Translate and Grammar handlers are currently placeholders. The floating assistant is the complete system-wide workflow.

## Requirements

- Flutter SDK with Dart 3 support
- Android SDK 35
- Android 7.0 (API 24) or newer
- Android 11 (API 30) or newer for X reply screenshot capture
- An Android device or emulator
- An OpenAI API key with available API usage

Bhasha is currently Android-only. The overlay, accessibility service, screen capture, and IME are implemented in native Kotlin.

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
2. Add an OpenAI API key.
3. Finish onboarding.
4. Open **Settings** to configure the floating assistant.

## Setting up the floating assistant

Android does not allow apps to enable overlay or accessibility access silently. Both permissions must be granted manually by the user.

1. Open Bhasha and go to **Settings**.
2. Under **One-Tap Translation**, grant **Overlay Permission**.
3. Grant access to the **Bhasha Accessibility Service**.
4. Choose Translate, Grammar, or X Replies as the **One-Tap Action**.
5. Turn on **Floating bubble active**.

### Translate or correct text in another app

1. Open an editable field in an app such as Messages, WhatsApp, email, or Notes.
2. Type or edit some text and keep the field focused.
3. Tap the Bhasha bubble.
4. Wait for the processed text to replace the original content.

Some apps expose editable text differently to Android accessibility services. Automatic reading or replacement may therefore vary by app.

### Generate replies for a post on X

1. In Bhasha settings, select **X Replies** as the one-tap action.
2. Configure the reply tone, length, count, emoji preference, and optional instructions.
3. Open a post on X.
4. Tap the floating bubble.
5. Tap a generated suggestion to copy it.

The X Replies action requires Android 11 or newer. It processes the visible screenshot through the enabled accessibility service, so review the screen for sensitive information before using it.

## OpenAI integration

Bhasha sends requests directly from the device to the OpenAI API. It currently uses:

- The Responses API for translation, grammar correction, language detection, and screenshot-based reply suggestions
- `gpt-5-mini-2025-08-07`
- A Chat Completions fallback for text-only requests

OpenAI API usage is billed to the account associated with the API key. The key is not included in the repository.

## Privacy and permissions

### Local data

- The OpenAI API key is stored with `flutter_secure_storage`.
- Language and style preferences are stored locally with `shared_preferences`.
- Secrets should never be committed to the repository.

### Android permissions and services

| Permission or service | Why it is needed |
| --- | --- |
| Internet | Send requests to the OpenAI API |
| Display over other apps | Show the draggable floating assistant |
| Foreground service | Keep the overlay available outside Bhasha |
| Accessibility service | Read and replace text in the focused editable field |
| Input method service | Register the custom Bhasha keyboard |
| Accessibility screenshot capability | Capture the visible screen for X reply suggestions on Android 11 or newer |

The accessibility service is used when the user taps the floating bubble; it is not intended to continuously collect typed text. Translation, grammar, and screenshot content selected for processing is sent to OpenAI.

## Architecture

```text
Flutter
├── Screens and widgets
├── Secure key and preference storage
├── OpenAI request and response handling
└── Platform service and overlay request handler
             │
             │ MethodChannel
             ▼
Native Android (Kotlin)
├── MainActivity
├── OverlayService
├── BhashaAccessibilityService
└── CustomKeyboardIME
```

Flutter owns the app UI, settings, storage coordination, and OpenAI requests. Kotlin owns Android-specific permissions, services, overlays, accessibility operations, screen capture, and IME behavior.

## Repository layout

```text
lib/
├── constants/     Supported languages
├── models/        Translation, grammar, mode, and reply-style models
├── screens/       Onboarding, home, and settings
├── services/      OpenAI, storage, platform-channel, and overlay coordination
├── theme/         Material 3 theme
└── widgets/       Reusable UI components

android/app/src/main/
├── AndroidManifest.xml
├── kotlin/com/yourapp/bhasha/
│   ├── MainActivity.kt
│   ├── OverlayService.kt
│   ├── BhashaAccessibilityService.kt
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

The repository does not currently contain a `test/` directory, so add tests before expecting `flutter test` to run a suite.

For changes to Kotlin, the Android manifest, platform channels, overlay behavior, accessibility behavior, or the IME, also run:

```sh
flutter build apk --debug
```

## Known limitations

- Android is the only supported platform.
- Overlay and accessibility access require manual approval in Android settings.
- One-tap text replacement depends on the target app exposing an editable accessibility node.
- X reply suggestions require Android 11 or newer and send the captured image to OpenAI.
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
