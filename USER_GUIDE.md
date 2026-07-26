# Bhasha User Guide

## Introduction

Bhasha is your personal language assistant that helps you translate text between languages and check grammar/spelling. It's designed specifically for users who know one language well (like Kannada) but struggle to express it in another (like English).

The default pair is Kannada ⇄ English. The Sarvam key is encrypted in Android
secure storage and is never included in the app source code.

## Change language without leaving the app you are in

You do not have to go back to Bhasha to switch languages.

### Auto-flip does most of it for you

Your two languages are a pair, not a fixed direction. Bhasha listens to what
you actually wrote or said and gives you the other one:

- Type Kannada in the WhatsApp box, tap the bubble, get English.
- Type English in the same box, tap the bubble, get Kannada.
- Hold the bubble and speak either language, get the other one.

Nothing to switch, nothing to remember. A message in some third language still
comes back in your target language, because that is the one you read.

To pin a single direction instead, turn off **Settings → Auto-flip between
these two**.

### The chip under the bubble

A small chip sits under the floating bubble and always shows where you stand:

- `KN⇄EN` means auto-flip is on between Kannada and English.
- `→EN` means everything goes into English, whatever you write.

Tap the chip and a language list opens on top of whatever app you are in.
Pick a language, and it takes effect on your very next tap. Tap outside the
list to close it without changing anything.

The chip hides itself while you are recording speech, and while Bhasha is
taking a screenshot for screen translation.

Screen translation (double tap) always shows the screen in your target
language. There is no direction to flip there, because the text is someone
else's.

## Getting Started

### First Launch

1. **Welcome Screen**: Learn about Bhasha features
2. **Choose Languages**:
   - Source Language: The language you're comfortable with (e.g., Kannada)
   - Target Language: The language you want to translate to (e.g., English)
3. **Enter API Key**: Paste your Sarvam API key
4. **Complete Setup**: Tap "Get Started"

### Getting a Sarvam API Key

1. Visit https://dashboard.sarvam.ai
2. Sign up or log in
3. Go to the API Keys section
4. Create a new API key
5. Copy the key (it starts with "sk_")
6. Paste it in the app

Bhasha checks the key with Sarvam when you save it, so a typo is caught immediately. The app sends the key to Sarvam in the `api-subscription-key` request header; it is never sent anywhere else.

**Important**: Keep your API key private. Don't share it with anyone.

## Choosing How to Use Bhasha

### 1. Floating Bubble (Recommended)

**What it is**: A small button that floats on top of all your apps.

**How to set it up**:

1. Open Bhasha app
2. Go to Settings (gear icon)
3. Under "One-Tap Translation", grant the Overlay permission and enable the Bhasha Accessibility Service
4. Choose "Translate" or "Grammar" as the One-Tap Action
5. Toggle "Floating bubble active" to ON

**Using the floating bubble**:

- Drag it anywhere on screen
- Tap into a text field in any app (WhatsApp, Messages, email, Notes)
- Type your text, keep the field focused, and tap the bubble
- Bhasha reads the field, translates or corrects it, and replaces the text right there — no copying or pasting
- The result is also spoken aloud in your saved voice, so you can hear it as well as read it
- An **Undo** pill appears for a few seconds after the text is replaced; tap it to bring your original text back

**Speaking instead of typing**:

- Press and hold the bubble instead of tapping it
- It turns red and shows "Listening…"
- Speak in any supported language — you do not have to tell Bhasha which one
- Let go, and your words appear in the message box in your chosen target language
- Recording stops on its own after 28 seconds, so nothing is lost
- Whatever you had already typed stays; the spoken part is added to the end

The first time you hold the button, Android asks for microphone permission. Bhasha opens itself to show that prompt; grant it, then hold the button again.

If your language is Kannada, Bhasha's messages — the status pill, notices, and errors — appear in Kannada.

**Best for**: Quick translations while using other apps

### 2. Custom Keyboard Mode (Not Ready Yet)

Bhasha registers a custom keyboard with Android, but its Translate and Grammar buttons are placeholders and are not yet connected to Sarvam. Use the floating bubble instead; it is the complete workflow.

## Translate Everything Visible on a Screen

Double-tap the bubble to read and translate the whole screen — useful when a message arrives in a language you can't read.

### Setup (do once)

1. Open **Bhasha → Settings**.
2. Turn on **Double-tap screen translation**.
3. Read the disclosure and tap **Agree & enable**.

### Use

1. Open WhatsApp or another app with readable text.
2. **Double-tap** the floating Bhasha bubble.
3. Approve Android's screen-capture prompt if Bhasha asks for one.
4. Wait while Bhasha reads the visible text and Sarvam translates it.
5. Read the white labels placed over the original text.
6. Tap anywhere to close the translated screen.

Where Android Accessibility can read the screen, Bhasha uses it, captures nothing at all, and the result appears in about a second — this is what happens in a WhatsApp chat. Otherwise it captures one frame per double tap (never saved to disk) and sends it to Sarvam Vision, which usually takes 10–25 seconds. Sarvam performs all reading and translation.

### Contextual long-press translation (not ready yet)

Settings also has a **Contextual translate across apps** toggle with its own disclosure. The long-press flow it describes is not wired up yet in this build — long-pressing a message does not show a Translate button. Use double-tap screen translation to read incoming messages instead.

## Using Translation

### In the App

1. Open Bhasha
2. Select source and target languages
3. Type or paste your text
4. Tap "Translate"
5. Listen to the spoken result, or copy it if needed

**Example**:

- Source (Kannada): "ನನಗೆ ಅರ್ಥವಾಗುತ್ತಿಲ್ಲ"
- Target (English): "I don't understand"

When auto-detect is enabled, Bhasha asks Sarvam to identify the source language before translating. If detection fails, it uses the saved source language.

### With the Floating Bubble

1. Type your text in any app and keep the field focused
2. Tap the bubble
3. Your text is replaced with the translation — done
4. Tap **Undo** if you want your original text back

## Using Grammar Check

Set the One-Tap Action to "Grammar" in Settings. Then, in any app:

1. Type your text and keep the field focused
2. Tap the bubble
3. The corrected text replaces the original

**Example**:

- Original: "I goes to school everyday"
- Corrected: "I go to school every day"

Grammar fixes use what Bhasha remembers about you — your saved reply tone and approved names — and recent things you said by voice, so corrections stay in your words.

### Tips for Better Results

1. **Be specific**: Clearer text gets better translations
2. **Short sentences**: Break long paragraphs into sentences
3. **Context matters**: Add context for ambiguous words
4. **Check results**: AI isn't perfect, review the output

## Managing Settings

### Languages

**Change Source Language**:

1. Settings > Default Languages
2. Tap "Source Language"
3. Select from the 23 supported languages

**Change Target Language**:

1. Settings > Default Languages
2. Tap "Target Language"
3. Select your preferred language

**Auto-detect Language**:

- Enable in Settings to automatically detect source language

### Voice and Memory

Bhasha remembers your preferences across restarts:

- The voice that reads results aloud, and how fast it speaks
- Your reply tone (simple, warm, formal, or direct)
- Names you have approved, so they are spelled your way every time

These survive closing and reopening the app.

### API Key

**Update API Key**:

1. Settings > Sarvam API key
2. Enter new key
3. Tap Save — Bhasha verifies it with Sarvam before accepting it

**Security**: Keys are encrypted and stored only on your device

## Common Use Cases

### For Parents (Like Your Use Case!)

**Scenario**: You want to write a message to your child's teacher in English.

**Solution**:

1. Tap into the message box and write in Kannada (or your language) — or press and hold the bubble and just say it
2. Tap the bubble to translate
3. Check the English text (Bhasha reads it out too)
4. Send the message

### WhatsApp Messages

1. Open WhatsApp and tap into the message box
2. Type in your language, or press and hold the bubble and speak
3. Tap the bubble to translate typed text
4. To read an English message you received, double-tap the bubble and read the Kannada labels drawn over the chat
5. Review and press Send — Bhasha never sends anything for you

### Email Writing

1. Write email in your comfortable language
2. Tap the bubble to translate it to English
3. Use grammar check to ensure correctness
4. Send with confidence

### Learning

Use Bhasha to:

- See how phrases translate
- Hear how the result sounds
- Learn correct grammar
- Improve your English over time

## Supported Languages

Bhasha supports the 22 Indian languages Sarvam covers, plus English — 23 in total:

- Kannada, English, Hindi, Tamil, Telugu, Malayalam
- Marathi, Bengali, Gujarati, Punjabi, Odia, Assamese
- Urdu, Nepali, Konkani, Kashmiri, Sindhi, Sanskrit
- Santali, Manipuri, Bodo, Maithili, Dogri

Languages outside this list (such as Spanish or Japanese) are not offered, because Sarvam does not process them.

## Tips & Tricks

1. **Quick Access**: Keep the floating bubble on for instant access
2. **Offline Note**: App needs internet for translation
3. **Undo is there**: If a replacement looks wrong, tap Undo within a few seconds
4. **Multiple Languages**: Change languages anytime
5. **Grammar First**: For English text, check grammar before sending

## Troubleshooting

### "No internet connection"

- Check your WiFi or mobile data
- Try opening a web browser to verify

### "API Error"

- Check if your API key is correct
- Verify your Sarvam account has credits
- Try again in a few seconds

### "Permission denied"

- Go to Android Settings > Apps > Bhasha
- Grant required permissions

### Floating bubble disappeared

- Go to Settings
- Toggle "Floating bubble active" off and on
- Check vendor battery/background restrictions for Bhasha

### Bubble does nothing in an app

- Make sure a text field is focused (the cursor is blinking)
- Some apps expose text fields differently to Android accessibility services, so reading or replacement can vary by app

### Double-tap screen translation does not start

- Save your Sarvam API key in Bhasha Settings
- Enable **Double-tap screen translation** and the floating bubble
- Tap twice quickly without moving the bubble
- Approve the Android capture prompt
- Secure banking, media, or password screens may intentionally capture blank

### Screen translation says no text was found

- Sarvam Vision reads plain, document-like screens best; a photo or wallpaper background can defeat it
- In chat apps, Bhasha reads the text directly instead of capturing the screen, so this usually only happens on unusual screens

### Translation seems wrong

- Try rephrasing your source text
- Add more context
- Break into smaller sentences
- Remember AI can make mistakes
- Tap Undo to get your original text back

### The custom keyboard buttons do not translate

The keyboard is currently scaffolding. Use the floating bubble instead.

## Privacy

- Your API key stays on your device, encrypted
- No data is stored or sent to Bhasha servers
- Opening or scrolling an app sends nothing anywhere; text and recorded speech go only to Sarvam, and only when you tap, hold, or double-tap the bubble
- For double-tap screen translation, a screenshot is sent to Sarvam Vision only when the accessibility tree cannot read the screen; the single captured frame is never saved
- Voice recordings are deleted from the device as soon as the request finishes
- No chat text, contact names, screenshots, or translation history is kept; only your saved preferences and approved names persist
- You can delete all data anytime in Settings

## Costs

- App is free to use
- Sarvam API usage is billed to the account associated with your key
- Monitor usage and credits at https://dashboard.sarvam.ai

## Best Practices

1. **Start Simple**: Try translating in the app first, then turn on the bubble
2. **Learn Gradually**: Use it daily, you'll improve
3. **Review Results**: Always read the translation before sending
4. **Keep Key Safe**: Store API key securely
5. **Update Regularly**: Keep app updated for best performance

## Support

If you need help:

1. Re-read this guide
2. Check SETUP.md for technical issues
3. Ask family member to help with setup
4. Contact app developer

## Feedback

Your experience matters! Share:

- What works well
- What's confusing
- Feature requests
- Language-specific issues

---

**Made with ❤️ to help bridge language barriers**
