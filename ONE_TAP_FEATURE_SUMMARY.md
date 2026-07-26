# One-Tap and Contextual Translation

Bhasha now provides three Android translation surfaces. Sarvam performs every
translation, and Sarvam Vision performs OCR when the double-tap screen mode
cannot read the screen through Accessibility.

## 1. Focused-field one-tap translation

The general floating bubble works across supported apps:

1. Focus an editable text field.
2. Tap the Bhasha bubble.
3. Bhasha reads that field, sends the requested operation to Sarvam, and
   replaces the editable text with the result.

This flow requires both overlay access and the Bhasha accessibility service.

## 2. Double-tap screen translation

1. Double-tap the general bubble without dragging it.
2. Approve Android's one-time MediaProjection prompt.
3. Bhasha reads the accessibility tree, or captures one frame in memory.
4. That read returns source text plus 0–1000 bounding rectangles.
5. Sarvam Mayura translates each block.
6. Native Kotlin draws white replacement labels; tap anywhere to close.

The accessibility path uploads nothing. The Sarvam Vision fallback uploads one
screenshot as a digitization job; translation always runs on extracted strings.

## 3. Contextual translation across apps

The contextual flow is designed for reading visible accessible text without
changing the original:

1. Open a messaging, social, or content app.
2. Long-press a supported text message.
3. Tap **भ Translate** beside the message.
4. Read the Sarvam result.
5. Choose Copy, Insert in reply, or Close.

The Insert action places the translated text in a compatible exposed composer.
It does not send the message automatically.

## Detection and placement

Native Kotlin code owns Android UI inspection and overlays. A dedicated
WhatsApp adapter recognizes package `com.whatsapp` and known conversation,
message, composer, and footer view IDs. A generic adapter accepts visible,
non-editable, non-password text from other eligible apps. The overlay
controller positions the chip beside the selected content while avoiding known
obstacles.

The chip is dismissed when the source view scrolls, its app is left, a
normal click changes context, or the selected message can no longer be
revalidated.

## Sarvam request path

```text
Explicit text long-press
  -> BhashaAccessibilityService
  -> ContextualMessageOverlayController
  -> cached Flutter engine method channel
  -> OverlayRequestHandler action "translate_message"
  -> SarvamService.translate
  -> native result card
```

The cached Flutter engine allows the request path to remain available while
the main Bhasha activity is in the background.

## Consent and privacy

- Contextual translation is disabled by default.
- Enabling it requires an explicit in-app disclosure.
- Android system surfaces, Bhasha itself, editable text, and password fields
  are excluded from generic detection.
- Only a supported selected text message is sent to Sarvam, and only after the
  user taps Translate.
- The full conversation is not sent.
- Raw selected text is not stored in the native anchor or logged.
- The feature can be disabled in Bhasha Settings at any time.

## Failure behavior

Unsupported or media-only content does not show a Translate chip. Sarvam or
network failures show a contextual error card with Retry, Open Bhasha, and
Close. The existing general floating bubble remains available as a fallback.

## Verification

The Dart request-handler tests cover Sarvam routing, subscription-key use,
source-package metadata, the Sarvam Vision job pipeline, geometry preservation, and
rejection of unsupported packages. Native changes must also pass Android lint
and a debug APK build before handoff.
