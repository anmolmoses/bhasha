# Quick Start Guide

Get Bhasha up and running in 5 minutes!

## Prerequisites Checklist

- [ ] Flutter SDK installed (run `flutter --version` to check)
- [ ] Android device or emulator ready
- [ ] OpenAI API key (get from platform.openai.com)

## Setup Commands

```bash
# 1. Navigate to project
cd /Users/anmolmoses/Documents/anmol/bhasha

# 2. Install dependencies
flutter pub get

# 3. Create local.properties file
cat > android/local.properties << EOF
sdk.dir=$HOME/Library/Android/sdk
flutter.sdk=$(which flutter | sed 's:/bin/flutter::')
EOF

# 4. Check everything is ready
flutter doctor

# 5. Connect device or start emulator
flutter devices

# 6. Run the app
flutter run
```

## Post-Installation

Once the app launches:

1. **Onboarding**: Follow the 3-step setup
2. **API Key**: Paste your OpenAI API key
3. **Languages**: Select Kannada → English (or your preferred pair)
4. **Mode**: Choose Floating Button or Keyboard mode
5. **Test**: Try translating some text!

## Common Issues

### "Command not found: flutter"

- Flutter not in PATH
- Install from: https://flutter.dev/docs/get-started/install

### "No devices found"

- Start Android emulator or connect physical device
- Enable USB debugging on phone

### "Gradle build failed"

- Open `android/` folder in Android Studio
- Let it download dependencies
- Try running again

### "API Error"

- Verify API key is correct
- Check you have credits on OpenAI account
- Ensure internet connection is working

## Testing the App

### Test Translation

1. Open app
2. Go to Translate tab
3. Type: "ನಾನು ಚೆನ್ನಾಗಿದ್ದೇನೆ" (Kannada)
4. Tap Translate
5. Should output: "I am fine" (English)

### Test Grammar Check

1. Go to Grammar Check tab
2. Type: "I is going to school"
3. Tap Check Grammar
4. Should output: "I am going to school"

### Test Floating Button

1. Go to Settings
2. Select Floating Button mode
3. Grant overlay permission
4. Toggle floating button ON
5. Go to any app (like Notes)
6. Tap the floating "T" button
7. Translate some text

## Next Steps

- Read USER_GUIDE.md for detailed usage instructions
- Read SETUP.md for advanced configuration
- Customize languages in Settings
- Explore both modes to find what works best

## Support

- Check documentation: README.md, USER_GUIDE.md, SETUP.md
- Review code in `lib/` folder
- Test thoroughly before giving to your parents

## For Your Parents

Once set up, show them:

1. How to open the app
2. How to tap the floating button (if using that mode)
3. How to paste text and tap Translate
4. How to copy the result

Practice with them a few times so they're comfortable!

---

**Pro Tip**: Start with Floating Button mode - it's easier for first-time users.
