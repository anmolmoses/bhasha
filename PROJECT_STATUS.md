# Project Status

## Last Updated

July 26, 2026

## Summary

Bhasha is a Flutter + native Kotlin Android app built on the Sarvam API. Sarvam is the only inference provider; the earlier OpenAI integration has been removed. The core product is a system-wide floating bubble: tap it to translate or grammar-correct the focused text field in any app, hold it to speak and have the transcribed, translated result inserted for you, or double-tap it to translate everything visible on screen.

## What Works

### Overlay translate and grammar

- A draggable floating bubble runs as a foreground service and works over any app.
- Tap the bubble and the accessibility service reads the focused editable field, sends the text to Sarvam, and replaces it in place — no copying, no app switching.
- The one-tap action is configurable in Settings: **Translate** (`/translate`, `mayura:v1`) or **Grammar** (`/v1/chat/completions`, `sarvam-105b`).
- Grammar prompts are shaped by the saved parent profile (tone, approved names) and recent voice turns.

### Hold-to-speak voice translation

- Press and hold the bubble to record; release to process.
- Audio goes to `/speech-to-text` (`saaras:v3`); if the speech is not already in the target language, the transcript is translated with Mayura.
- The result is appended to the focused field, so held recordings never destroy typed text.
- Recording is capped at 28 seconds (Sarvam's REST speech endpoint rejects audio over 30) with a visible countdown.
- Temporary audio files are deleted as soon as the request finishes, success or failure.

### Spoken playback (Bulbul TTS)

- Results are spoken aloud with `/text-to-speech` (`bulbul:v3`), both in-app and after overlay actions.
- Playback uses the parent's saved voice speaker and pace.

### Undo

- After the bubble replaces text in a field, an Undo pill appears for a few seconds and restores the original text if tapped.

### Parent profile memory

- `lib/services/parent_profile_service.dart` persists the parent's voice speaker, speaking pace, reply tone, and approved-names glossary under the `parent_profile_v1` key. These survive app restarts and shape grammar and rewrite prompts.
- Recent voice turns are kept in a bounded in-memory conversation context that grounds grammar fixes. Full message history is never persisted.

### Kannada parent-facing strings

- Overlay toasts, the status pill, and error messages render in Kannada when the parent's language is Kannada.

### Double-tap screen translation

- Double-tap the bubble to translate everything visible on screen; the result is drawn as labels over the original text, and tapping anywhere dismisses it.
- Off by default. Enabling it in Settings shows an explicit disclosure, and the OCR fallback additionally requires Android's own screen-capture prompt.
- Two read paths, preferring the first: the accessibility tree (exact text and bounds, no screen capture, ~1 second — the only path that works on a WhatsApp chat, whose wallpaper defeats the document model), and Sarvam Vision OCR (`/doc-digitization/job/v1`) when the tree yields nothing readable. The OCR job takes roughly 10–25 seconds and the single captured frame stays in memory, never written to disk.

### App fundamentals

- Onboarding: language pair selection and Sarvam key entry, with a live key verification round trip.
- The Sarvam API key is stored with `flutter_secure_storage` (Android Keystore-backed); language and profile preferences use `shared_preferences`.
- 23 supported languages: Sarvam's 22 Indian languages plus English (`lib/constants/languages.dart`).
- Typed Sarvam errors, request-size handling, and unit tests in `test/` for response parsing, errors, the language table, and the voice-translate path.

## What Is Scaffolded

- **Custom keyboard (IME)**: `CustomKeyboardIME.kt` is registered with Android and includes a QWERTY layout and a toolbar with Translate and Grammar buttons, but those handlers are placeholder stubs — they are not connected to Sarvam. The floating bubble is the complete workflow.
- **Contextual long-press message translation**: the Settings toggle, consent dialog, `translate_message` handler, and the WhatsApp/generic UI adapters exist, but the accessibility service does not yet subscribe to long-press events, so the "long-press a message → Translate button" flow is not wired end to end.

## Deliberately Out of Scope on This Branch

- Automatic message sending (the parent always presses Send themselves).
- Continuous screen or microphone monitoring. Screen translation runs only on an explicit double-tap; the app does not declare the accessibility screenshot capability, and the MediaProjection fallback captures a single frame after Android's own consent prompt.
- iOS support.
- Any backend — requests go directly from the device to Sarvam.

## Known Limitations

- Android only.
- Overlay and accessibility access require manual approval in Android settings.
- One-tap replacement depends on the target app exposing an editable accessibility node; behavior varies by app.
- Hold-to-speak is capped at 28 seconds.
- The screen-translation OCR fallback runs as an asynchronous Sarvam Vision job and takes roughly 10–25 seconds; Sarvam Vision is a document model and struggles with screens drawn over photo backgrounds.
- The custom keyboard's AI actions are not implemented.
- The release build uses debug signing and is not configured for Play Store distribution.

## How to Run

```bash
flutter pub get
flutter run
```

On first launch, complete onboarding with a Sarvam API key from https://dashboard.sarvam.ai, then enable the overlay and accessibility permissions from Settings.

## Verification

```bash
flutter analyze
flutter test
flutter build apk --debug
```

## Support Resources

- **Technical setup**: SETUP.md
- **For parents**: USER_GUIDE.md and SIMPLE_GUIDE_FOR_PARENTS.md
- **Quick help**: QUICKSTART.md
- **Overview**: README.md
- **Buildathon spec**: SARVAM_BUILDATHON.md
- **Demo script**: THREE_MINUTE_DEMO.md
