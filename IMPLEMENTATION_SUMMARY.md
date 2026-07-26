# Implementation Summary: Historical Snapshot

> This document describes the original OpenAI-era implementation. The current
> app uses Sarvam for language work, OpenAI only for opt-in screen OCR, and
> adds universal double-tap screen translation plus contextual translation. See
> `README.md`, `WHATSAPP_CONTEXTUAL_TRANSLATE.html`, and `USER_GUIDE.md`.

## Project Overview

Bhasha is an Android app built with Flutter and native Kotlin that helps users translate text, correct grammar, and speak messages using the Sarvam API. It is designed for users who are comfortable in one language (Kannada) but need help expressing themselves in another (English). Sarvam is the only inference provider; the earlier OpenAI integration was removed.

## What Has Been Implemented

### 1. Flutter Project Setup

- Complete Flutter project structure
- Dependencies configured (shared_preferences, flutter_secure_storage, http)
- Android-specific configuration (build.gradle, settings.gradle, AndroidManifest.xml)
- Analysis options for linting
- .gitignore for clean repository

### 2. Storage Service

**File**: `lib/services/storage_service.dart`

- Secure Sarvam API key storage using flutter_secure_storage (Android Keystore-backed)
- Removes any legacy OpenAI key left by earlier installs
- User preferences storage (languages, settings)
- First-time setup detection
- Auto-detect language toggle

### 3. Sarvam Integration

**File**: `lib/services/sarvam_service.dart`

- `/speech-to-text` (`saaras:v3`) for hold-to-speak transcription
- `/translate` (`mayura:v1`) for translation
- `/text-lid` for source-language detection
- `/v1/chat/completions` (`sarvam-105b`) for grammar correction and rewriting
- `/text-to-speech` (`bulbul:v3`) for spoken playback of results
- Requests authenticate with the `api-subscription-key` header
- Typed errors, timeouts, request-size chunking, and key verification round trip

### 4. Overlay Request Handling

**File**: `lib/services/overlay_request_handler.dart`

- Routes bubble actions (`translate`, `grammar`, `voice_translate`) from Kotlin to Sarvam
- Skips the translation round trip when speech is already in the target language
- Builds grammar prompts from the saved parent profile and recent voice context

### 5. Parent Profile Memory

**File**: `lib/services/parent_profile_service.dart`

- Persists the parent's voice speaker, speaking pace, reply tone, and approved-names glossary under the `parent_profile_v1` key
- Survives app restarts and shapes grammar/rewrite prompts
- Recent voice turns are held in a bounded in-memory conversation context; full message history is never persisted

### 6. Platform Service

**File**: `lib/services/platform_service.dart`

- Bridge between Flutter and native Android code
- Method channels for overlay service control
- Bidirectional communication support

### 7. Data Models

**Files**: `lib/models/`

- `translation_result.dart`, `grammar_result.dart` - Result models
- `parent_profile.dart` - Voice speaker, pace, tone, glossary
- `conversation_context.dart` - Bounded in-memory voice context
- `voice_result.dart`, `sarvam_error.dart` - Voice pipeline and typed errors
- `app_mode.dart` - Mode enum

### 8. User Interface

- **Onboarding** (`lib/screens/onboarding_screen.dart`): language selection and Sarvam key entry with verification
- **Home** (`lib/screens/home_screen.dart`): in-app translation with spoken playback and copy-to-clipboard
- **Settings** (`lib/screens/settings_screen.dart`): overlay permissions, one-tap action (Translate/Grammar), default languages, API key management, clear-all-data
- Reusable widgets in `lib/widgets/` (API key input, language picker, cards, buttons)

### 9. Native Android Integration

**Files**: `android/app/src/main/kotlin/com/yourapp/bhasha/`

- **MainActivity.kt** - Method channel setup, permission checks, service lifecycle
- **OverlayService.kt** - Foreground service, draggable bubble, tap and press-and-hold gestures, status pill, Undo pill after replacement, Kannada parent-facing strings
- **BhashaAccessibilityService.kt** - Reads and replaces text in the focused editable field
- **VoiceCaptureManager.kt** - Microphone capture lifecycle for hold-to-speak
- **BhashaChannel.kt / BhashaApplication.kt** - Channel and app wiring
- **CustomKeyboardIME.kt** - Scaffolded IME (see limitations)

**XML resources**: `accessibility_service_config.xml`, `method.xml`, `qwerty.xml`, `keyboard_view.xml`

### 10. Language Support

**File**: `lib/constants/languages.dart`

- 23 languages: Sarvam's 22 Indian languages plus English
- Kannada, English, Hindi, Tamil, Telugu, Malayalam, Marathi, Bengali, Gujarati, Punjabi, Odia, Assamese, Urdu, Nepali, Konkani, Kashmiri, Sindhi, Sanskrit, Santali, Manipuri, Bodo, Maithili, Dogri
- Each entry carries the BCP-47 code Sarvam accepts; unsupported names resolve to null so callers fail explicitly instead of sending a bad code

## Key Features

### 1. System-Wide Floating Bubble

- One tap reads the focused field, processes it with Sarvam, and replaces the text in place
- Press and hold to speak; the translated result is appended to the field
- An Undo pill restores the original text for a few seconds after replacement
- No copying, pasting, or app switching

### 2. Voice

- Hold-to-speak with automatic language detection (no source selection needed)
- 28-second recording cap with countdown (Sarvam's REST endpoint rejects audio over 30 seconds)
- Spoken playback of results via Bulbul in the parent's saved voice and pace

### 3. Memory

- Voice speaker, pace, reply tone, and approved-names glossary persist across restarts
- Bounded in-memory conversation context grounds grammar fixes

### 4. Security & Privacy

- API key stored securely; sent only to Sarvam
- Recorded audio deleted immediately after each request
- No translation history stored
- No accessibility screenshot capability; no screen pixels leave the device
- Parent-facing overlay strings render in Kannada for Kannada-language parents

## Architecture

```
Flutter
├── Screens and widgets
├── Secure key, preference, and parent-profile storage
├── Sarvam request and response handling
└── Platform service and overlay request handler
             │ MethodChannel
             ▼
Native Android (Kotlin)
├── MainActivity
├── OverlayService (bubble, gestures, undo, status pill)
├── BhashaAccessibilityService (read/replace focused field)
├── VoiceCaptureManager (microphone)
└── CustomKeyboardIME (scaffolded)
```

## Testing

`test/` covers Sarvam response parsing, typed errors, request-size chunking, the language table, and the voice-translate path.

```bash
flutter analyze
flutter test
flutter build apk --debug
```

## Known Limitations

1. **Internet required**: All processing calls the Sarvam API
2. **Android only**: iOS is not supported
3. **Accessibility variance**: One-tap replacement depends on the target app exposing an editable node
4. **Keyboard stub**: The custom keyboard's Translate and Grammar actions are placeholders, not connected to Sarvam
5. **Debug signing**: The release build is not configured for Play Store distribution
6. **No history**: Translations are not saved (by design for privacy)

## Costs

Sarvam API usage is billed to the account associated with the key. Monitor usage on https://dashboard.sarvam.ai.

## Credits

- **Flutter**: Google's UI toolkit
- **Sarvam AI**: Saaras (speech-to-text), Mayura (translation), Bulbul (text-to-speech), and sarvam-105b (chat) models
- **Material Design**: Google's design system

## License

See LICENSE file for details.
