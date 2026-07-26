# Bhasha Quick Start

Bhasha is an Android translation and grammar assistant powered by Sarvam AI.

## Developer setup

```sh
cd /Users/anmolmoses/work/personal/bhasha
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is written to:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## First launch

1. Open Bhasha and complete onboarding.
2. Add a Sarvam API key, or use the configured subscription key.
3. Choose the source and target languages.
5. Open Settings and enable only the integrations you want.

## Double-tap screen translation

1. Save your Sarvam API key.
2. Enable **Double-tap screen translation** and accept its disclosure.
3. Enable the floating bubble.
4. Open WhatsApp or any other app with visible text.
5. Double-tap the floating bubble and approve Android's capture prompt.
6. Read the white Sarvam translation labels and tap anywhere to close.

Bhasha reads the screen through Accessibility where it can, and falls back to
one in-memory screenshot for Sarvam Vision OCR. Extracted text—not the
screenshot—is sent to Sarvam for translation.

## Contextual translation across apps

1. In Settings, turn on **Contextual translate across apps**.
2. Read and accept the disclosure.
3. Enable the Bhasha accessibility service when Android opens its settings.
4. Open a messaging or social app.
5. Long-press a text message and tap **भ Translate**.
6. Copy the Sarvam translation or insert it into the reply composer.

This feature is opt-in. Bhasha detects compatible accessible text locally.
The selected message is sent to Sarvam only after you tap Translate. Bhasha
does not send the whole conversation.

## General floating button

1. Select Floating Button mode.
2. Grant **Display over other apps** permission.
3. Enable the overlay bubble.
4. Focus an editable text field in an app and single-tap the bubble.

The general bubble translates or corrects the focused field. It remains
available independently of the contextual feature.

## Custom keyboard

1. Select Custom Keyboard mode.
2. Open Android keyboard settings.
3. Enable **Bhasha Keyboard** and select it as the active keyboard.

Android requires the user to grant overlay, accessibility, and keyboard access
from system settings. Bhasha cannot silently enable them.

## Troubleshooting

- No contextual Translate chip: confirm the toggle and accessibility service
  are enabled, then long-press visible text exposed by the source app.
- No floating button: grant **Display over other apps** and enable the bubble.
- Double tap opens Bhasha instead: save your Sarvam key and enable
  **Double-tap screen translation**.
- No screen result: approve Android capture, use a non-secure screen with
  readable text, and verify both API keys.
- Translation fails: verify the Sarvam key/subscription and internet access.
- Build fails: run `flutter doctor`, verify `android/local.properties`, then
  retry `flutter clean && flutter pub get`.

See `SETUP.md`, `USER_GUIDE.md`, and `WHATSAPP_CONTEXTUAL_TRANSLATE.html` for
the full behavior and implementation notes.
