# Bhasha User Guide

## First setup

1. Open Bhasha.
2. Create a subscription key at `dashboard.sarvam.ai`.
3. Paste the key into Bhasha and verify it.
4. Choose the language you know and the language you want.
5. Complete onboarding.

The default pair is Kannada → English. The Sarvam key is encrypted in Android
secure storage and is never included in the app source code.

## Translate everything visible on a screen

### Setup

1. Open **Bhasha → Settings**.
2. Save your Sarvam API key.
3. Turn on **Double-tap screen translation**.
4. Read the disclosure and tap **Agree & enable**.
5. Grant overlay permission and turn on the floating bubble.

### Use

1. Open WhatsApp or another app with readable text.
2. Double-tap the floating Bhasha bubble.
3. Approve Android's screen-capture prompt if Bhasha asks for one.
4. Wait while Bhasha reads the visible text and Sarvam translates it.
5. Read the white labels placed over the original text.
6. Tap anywhere to close the translated screen.

Where Android Accessibility can read the screen, Bhasha uses it and captures
nothing at all. Otherwise it captures one frame per double tap and does not
save it. Sarvam performs all reading and translation.

## Translate inside Bhasha

1. Open the Bhasha home screen.
2. Choose source and target languages.
3. Type or paste text.
4. Tap **Translate**.
5. Review or copy the Sarvam result.

When auto-detect is enabled, Bhasha asks Sarvam to identify the source language
before translating. If detection fails, it uses the saved source language.

## Translate editable text in any app

### Setup

1. Open **Bhasha → Settings → One-Tap Translation**.
2. Grant **Overlay Permission**.
3. Enable **Bhasha Accessibility** in Android Settings.
4. Set the One-Tap Action to **Translate**.
5. Turn on **Floating bubble active**.

### Use

1. Open an editable field in WhatsApp, Messages, email, Notes, or another app.
2. Type text and keep the field focused.
3. Tap the floating `T`.
4. Wait for Bhasha to replace the editable text with the translation.

Choose Grammar instead of Translate to correct the focused text with Sarvam.

## Translate existing text across apps

This is different from translating text you are typing. Bhasha shows its own
temporary action beside text you explicitly long-press; it never edits the
original content.

### Enable it

1. Open **Bhasha → Settings → One-Tap Translation**.
2. Turn on **Contextual translate across apps**.
3. Read the disclosure explaining accessibility and Sarvam data use.
4. Tap **Agree & enable**.
5. Enable Bhasha Accessibility if prompted.

The feature is off by default and can be turned off at any time.

### Use it

1. Open a messaging or social app.
2. Long-press the text message you want to translate.
3. Tap the Bhasha **Translate** chip.
4. Review the **Translated by Sarvam** card.
5. Select:
   - **Copy** to copy the result.
   - **Insert in reply** to place it in an exposed editable composer.
   - **Close** to dismiss it.

The chip may appear below, across the edge of, or above the selected message so
it does not cover the app's composer or nearby text.

### When the chip will disappear

Bhasha removes the contextual action when:

- You scroll.
- You leave the source screen or app.
- The selected message moves and cannot be matched safely.
- You disable contextual translation.
- Android disables the accessibility service.

Bhasha does not guess which message to translate.

## Supported languages

Kannada, English, Hindi, Tamil, Telugu, Malayalam, Marathi, Bengali, Gujarati,
Punjabi, Odia, Assamese, Urdu, Nepali, Konkani, Kashmiri, Sindhi, Sanskrit,
Santali, Manipuri, Bodo, Maithili, and Dogri.

## Privacy

- Opening or scrolling an app does not send anything to Sarvam.
- Only the message you explicitly select and translate is transmitted.
- Bhasha does not save chat text, contact names, screenshots, or translation
  history.
- For double-tap screen translation, a screenshot is sent to Sarvam Vision only
  when the accessibility tree cannot read the screen.
- The Sarvam subscription key stays in secure storage.
- Insert in reply always requires a separate tap.
- You can turn off contextual translation or Android Accessibility at any time.

## Troubleshooting

### The contextual Translate chip does not appear

- Confirm **Contextual translate across apps** is enabled in Bhasha Settings.
- Confirm Bhasha Accessibility is enabled in Android Settings.
- Long-press a normal text message, not an image-only message, sticker, or voice
  note.
- Password fields, image-only content, stickers, and voice notes are excluded.
- Some apps do not expose message text to Android Accessibility.

### Double-tap screen translation does not start

- Save your Sarvam API key in Bhasha Settings.
- Enable **Double-tap screen translation** and the floating bubble.
- Tap twice quickly without moving the bubble.
- Approve the Android capture prompt.
- Secure banking, media, or password screens may intentionally capture blank.

### Translation says a Sarvam key is missing or invalid

- Open Bhasha Settings.
- Paste a valid subscription key from `dashboard.sarvam.ai`.
- Use the key verification control before returning to WhatsApp.

### The message moved

Scroll or incoming messages can invalidate the temporary anchor. Long-press the
message again; Bhasha intentionally refuses to translate an ambiguous row.

### Insert in reply does not work

- Make sure the source app's editable composer is visible.
- Close any attachment, emoji, or search panel.
- Tap **Insert in reply** again.

### The general floating bubble is missing

- Grant Display over other apps permission.
- Turn **Floating bubble active** off and back on.
- Check vendor battery/background restrictions for Bhasha.

### The custom keyboard buttons do not translate

The keyboard is currently scaffolding. Use the in-app workspace, general
floating bubble, or contextual Translate action.
