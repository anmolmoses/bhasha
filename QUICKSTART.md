# Quick Start Guide

Get Bhasha up and running in 5 minutes!

## Prerequisites Checklist

- [ ] Flutter SDK installed (run `flutter --version` to check)
- [ ] Android device or emulator ready
- [ ] Sarvam API key (get from dashboard.sarvam.ai)

## Setup Commands

```bash
# 1. Navigate to project
cd /path/to/bhasha

# 2. Install dependencies and validate
flutter pub get
flutter analyze
flutter test

# 3. Run the app
flutter run
```

To build the debug APK instead:

```bash
flutter build apk --debug
# written to build/app/outputs/flutter-apk/app-debug.apk
```

## Post-Installation

Once the app launches:

1. **Onboarding**: Follow the setup steps
2. **Languages**: Select Kannada → English (or your preferred pair)
3. **API Key**: Paste your Sarvam API key (starts with "sk_") — the app verifies it with Sarvam
4. **Floating assistant**: In Settings, grant the overlay permission, enable the Bhasha Accessibility Service, and turn on the bubble
5. **Test**: Try translating some text!

Android requires the user to grant overlay, accessibility, screen-capture, and keyboard access from system settings. Bhasha cannot silently enable them.

## Common Issues

### "Command not found: flutter"

- Flutter not in PATH
- Install from: https://flutter.dev/docs/get-started/install

### "No devices found"

- Start Android emulator or connect physical device
- Enable USB debugging on phone

### "Gradle build failed"

- Run `flutter doctor` and verify `android/local.properties`
- Retry `flutter clean && flutter pub get`
- Open `android/` folder in Android Studio and let it download dependencies

### "API Error"

- Verify API key is correct
- Check your credits on dashboard.sarvam.ai
- Ensure internet connection is working

## Testing the App

### Test Translation

1. Open app
2. Type: "ನಾನು ಚೆನ್ನಾಗಿದ್ದೇನೆ" (Kannada)
3. Tap Translate
4. Should output: "I am fine" (English), and read it aloud

### Test the Floating Bubble

1. Go to Settings
2. Grant overlay permission and enable the accessibility service
3. Turn on "Floating bubble active"
4. Go to any app with a text field (like Notes or WhatsApp)
5. Type some Kannada, keep the field focused, and tap the bubble
6. The text is replaced with English in place — tap **Undo** if you want the original back

### Test Hold-to-Speak

1. Tap into a text field in any app
2. Press and hold the bubble — it turns red and shows "Listening…"
3. Speak in Kannada (or mix in English words)
4. Release — the English text is appended to the field

### Test Grammar Check

1. In Settings, set One-Tap Action to "Grammar"
2. In any app, type: "I is going to school"
3. Tap the bubble
4. Should be replaced with: "I am going to school"

### Test Double-Tap Screen Translation

1. In Settings, enable **Double-tap screen translation** and accept its disclosure
2. Open WhatsApp or any other app with visible text
3. Double-tap the floating bubble and approve Android's capture prompt if asked
4. Read the white Sarvam translation labels and tap anywhere to close

Bhasha reads the screen through Accessibility where it can (about a second, no capture). Otherwise it takes one in-memory screenshot for Sarvam Vision OCR, which takes roughly 10–25 seconds. Extracted text — not the screenshot — is sent to Sarvam for translation, and the frame is never saved.

Troubleshooting the double tap:

- Double tap does nothing or opens Bhasha: enable **Double-tap screen translation** in Settings first.
- No screen result: approve Android capture, use a non-secure screen with readable text, and verify the Sarvam key.
- Tap twice quickly without moving the bubble.

Note: Settings also shows a **Contextual translate across apps** toggle. Its long-press flow is not wired up in this build; use double-tap screen translation to read messages.

## Next Steps

- Read USER_GUIDE.md for detailed usage instructions
- Read SETUP.md for advanced configuration
- Customize languages, voice, pace, and tone in Settings

## Support

- Check documentation: README.md, USER_GUIDE.md, SETUP.md
- Review code in `lib/` folder
- Test thoroughly before giving to your parents

## For Your Parents

Once set up, show them:

1. How to tap into a message box
2. How to tap the bubble to translate what they typed
3. How to press and hold the bubble to speak a message
4. How to double-tap the bubble to read a screen they can't understand
5. How to tap Undo if the replacement isn't right

Practice with them a few times so they're comfortable!

---

**Pro Tip**: The hold-to-speak flow is often easiest for first-time users — no typing at all.
