# Bhasha Setup Guide

This guide will help you set up and run the Bhasha language assistant app.

## Prerequisites

1. **Flutter SDK** (version 3.0 or higher)

   - Download from: https://flutter.dev/docs/get-started/install
   - Add Flutter to your PATH

2. **Android Studio** or **Android SDK**

   - Required for Android development
   - Install Android SDK and command-line tools

3. **OpenAI API Key**
   - Sign up at: https://platform.openai.com
   - Create an API key in the API keys section
   - You'll need this to enable translation and grammar checking

## Installation Steps

### 1. Clone and Setup

```bash
cd /path/to/bhasha
flutter pub get
```

### 2. Configure Android Local Properties

Create a file `android/local.properties` with your Flutter SDK path:

```properties
sdk.dir=/Users/YOUR_USERNAME/Library/Android/sdk
flutter.sdk=/path/to/your/flutter/sdk
```

### 3. Connect Android Device or Start Emulator

**Physical Device:**

```bash
# Enable USB debugging on your Android device
# Connect via USB
adb devices  # Verify device is connected
```

**Emulator:**

```bash
# Start from Android Studio or command line
flutter emulators
flutter emulators --launch <emulator_name>
```

### 4. Run the App

```bash
flutter run
```

Or use your IDE:

- **VS Code**: Press F5
- **Android Studio**: Click the Run button

## First-Time Setup

When you launch the app for the first time:

1. **Welcome Screen**: Review the app features
2. **Language Selection**: Choose your source language (e.g., Kannada) and target language (e.g., English)
3. **API Key**: Enter your OpenAI API key
   - The key is stored securely on your device
   - It's never transmitted except to OpenAI's API
4. **Get Started**: Complete the onboarding

## Choosing Your Mode

### Floating Button Mode

1. Go to Settings
2. Select "Floating Button" mode
3. Grant overlay permission when prompted
4. Enable the floating button toggle
5. The button will appear on all screens
6. Tap it to translate or check grammar

### Custom Keyboard Mode

1. Go to Settings
2. Select "Custom Keyboard" mode
3. Tap "Open Keyboard Settings"
4. Enable "Bhasha Keyboard"
5. Select it as your active input method
6. Use the keyboard in any app
7. Use the toolbar buttons for translation/grammar

## Features

### Translation

- Translate text between any supported languages
- Swap source and target languages with one tap
- Copy results to clipboard

### Grammar Checking

- Check grammar and spelling in any language
- Get corrected text instantly
- Works with your target language

### Supported Languages

- English, Kannada, Hindi, Spanish, French, German, Italian, Portuguese
- Russian, Chinese, Japanese, Korean, Arabic, Dutch, Swedish
- And 20+ more languages!

## Permissions

The app requires these permissions:

- **INTERNET**: To call OpenAI API
- **SYSTEM_ALERT_WINDOW**: For floating button overlay (optional)
- **BIND_INPUT_METHOD**: For custom keyboard (optional)

You only need overlay permission if using floating button mode.
You only need to enable the keyboard if using keyboard mode.

## Troubleshooting

### App won't build

- Ensure Flutter is properly installed: `flutter doctor`
- Clear build cache: `flutter clean && flutter pub get`
- Check Android SDK is installed

### Floating button not appearing

- Check overlay permission is granted
- Go to Settings > Apps > Bhasha > Permissions
- Enable "Display over other apps"

### Keyboard not showing

- Go to System Settings > Languages & input
- Enable Bhasha Keyboard under "Virtual keyboard"
- Select it as active keyboard

### Translation not working

- Verify your API key is correct
- Check internet connection
- Ensure you have OpenAI API credits
- Check API key permissions on OpenAI dashboard

### Build errors with Kotlin/Gradle

- Ensure you have JDK 8 or higher installed
- Update Android Studio to latest version
- Sync Gradle files

## Development

### Project Structure

```
lib/
  ├── main.dart              # App entry point
  ├── models/                # Data models
  ├── screens/               # UI screens
  ├── services/              # Business logic
  ├── widgets/               # Reusable UI components
  └── constants/             # App constants

android/
  └── app/src/main/kotlin/   # Native Android code
      ├── MainActivity.kt
      ├── OverlayService.kt
      └── CustomKeyboardIME.kt
```

### Adding New Languages

Edit `lib/constants/languages.dart` and add to the `supported` list:

```dart
static const List<String> supported = [
  'English',
  'YourNewLanguage',
  // ... more languages
];
```

### Modifying OpenAI Prompts

Edit `lib/services/openai_service.dart` to customize:

- Translation prompts
- Grammar checking prompts
- Model selection (GPT-3.5 vs GPT-4)

## API Costs

OpenAI API usage is pay-as-you-go:

- GPT-3.5-turbo: ~$0.002 per 1000 tokens
- GPT-4: Higher cost but better quality

Monitor usage on OpenAI dashboard.

## Privacy & Security

- API keys are stored encrypted on device
- No data is sent to any server except OpenAI
- Translation history is not saved
- App works offline for UI (requires internet for API calls)

## Support

For issues or questions:

1. Check this documentation
2. Review Flutter and Android documentation
3. Check OpenAI API documentation
4. File issues in the project repository

## License

See LICENSE file for details.
