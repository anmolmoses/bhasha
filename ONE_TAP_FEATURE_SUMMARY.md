# One-Tap, Voice, and Screen Translation

Bhasha's floating bubble carries three working gestures — tap, hold, and double-tap — plus a designed-but-not-yet-wired contextual long-press flow. Sarvam performs every translation, and Sarvam Vision performs OCR when the double-tap screen mode cannot read the screen through Accessibility.

## 1. Focused-field one-tap translation

The original simplification: **one button tap** instead of 8+ steps.

### Before (Complex - 9 steps)

1. User types text
2. Selects and copies text
3. Taps floating button
4. Taps "use clipboard"
5. Taps "translate"
6. Waits for result
7. Taps "copy"
8. Closes dialog
9. Deletes original text and pastes

### After (Simple - 2 steps)

1. User types text and keeps the field focused
2. **Taps floating button** → Done!

Bhasha reads that field, sends the requested operation (Translate or Grammar) to Sarvam, replaces the editable text with the result, speaks it aloud with Bulbul, and shows an Undo pill for a few seconds. This flow requires both overlay access and the Bhasha accessibility service.

There is also a zero-typing path: press and hold the button, speak, and release — the translated speech is appended to the field.

### How it works

```
1. User types in WhatsApp/Messages/etc
2. Taps floating "T" button
   ↓
3. OverlayService.performOverlayAction()
   ↓
4. BhashaAccessibilityService reads the focused field
   ↓
5. Request sent to Flutter over the method channel
   ↓
6. OverlayRequestHandler → SarvamService (translate or grammar)
   ↓
7. Result returned to native
   ↓
8. BhashaAccessibilityService replaces the field text
   ↓
9. Success toast, spoken playback (Bulbul), and a short-lived Undo pill
```

## 2. Double-tap screen translation

1. Double-tap the general bubble without dragging it.
2. Approve Android's MediaProjection prompt if the capture path is needed.
3. Bhasha reads the accessibility tree, or captures one frame in memory.
4. That read returns source text plus 0–1000 bounding rectangles.
5. Sarvam Mayura translates each block.
6. Native Kotlin draws white replacement labels; tap anywhere to close.

The accessibility path uploads nothing and answers in about a second. The Sarvam Vision fallback uploads one screenshot as a digitization job (roughly 10–25 seconds); translation always runs on extracted strings, never on pixels. The feature is off by default with its own in-app disclosure.

## 3. Contextual translation across apps (not yet wired)

The designed flow — long-press a message in a messaging app, tap a **Translate** chip beside it, read the Sarvam result — is not functional in this build. What exists:

- The Settings toggle and consent disclosure.
- The `translate_message` handler in `lib/services/overlay_request_handler.dart`, which rejects system packages and Bhasha itself.
- `WhatsAppUiAdapter.kt` (package `com.whatsapp`, known conversation/message/composer view IDs) and `GenericMessagingUiAdapter.kt` (visible, non-editable, non-password text only), whose long-press resolvers currently have no caller.

The missing piece is the trigger: the accessibility service subscribes only to focus and text-change events, not long-presses, and no chip overlay controller exists. See `WHATSAPP_CONTEXTUAL_TRANSLATE.html` for the intended design.

## Technical Implementation

### Components

1. **BhashaAccessibilityService.kt**

   - Reads text from focused input fields and writes results back
   - Collects visible screen text nodes for double-tap screen translation

2. **OverlayService.kt**

   - Single floating button showing "T" (or "G" when the one-tap action is Grammar)
   - One tap triggers `performOverlayAction()`; a double tap triggers `performScreenTranslation()` (single taps wait out the double-tap window)
   - Press-and-hold records speech for voice translation
   - Shows an Undo pill for a few seconds after replacing text, restoring the original
   - Shows toast and status-pill feedback — in Kannada when the parent's language is Kannada

3. **ScreenCaptureService.kt / ScreenCapturePermissionActivity.kt / ScreenTranslationOverlayController.kt**

   - MediaProjection consent, single-frame in-memory capture, and the translated-label overlay

4. **MainActivity.kt**

   - `checkAccessibilityPermission()` / `requestAccessibilityPermission()`
   - Method channels for Flutter communication

5. **Settings UI**
   - "One-Tap Translation" card with "Enable accessibility" button and One-Tap Action selector
   - "Double-tap screen translation" toggle with disclosure
   - "Contextual translate across apps" toggle with disclosure (flow not yet wired)

### Permissions

Declared in AndroidManifest.xml: the accessibility service binding, overlay permission, microphone permission for hold-to-speak, and the MediaProjection foreground-service type for the screen-capture fallback.

### Key Files

- `android/app/src/main/kotlin/com/yourapp/bhasha/BhashaAccessibilityService.kt`
- `android/app/src/main/kotlin/com/yourapp/bhasha/OverlayService.kt`
- `android/app/src/main/kotlin/com/yourapp/bhasha/VoiceCaptureManager.kt`
- `android/app/src/main/kotlin/com/yourapp/bhasha/ScreenCaptureService.kt`
- `android/app/src/main/kotlin/com/yourapp/bhasha/ScreenTranslationOverlayController.kt`
- `android/app/src/main/res/xml/accessibility_service_config.xml`
- `android/app/src/main/res/values/strings.xml`
- `lib/services/overlay_request_handler.dart`
- `lib/services/sarvam_vision_service.dart`
- `SIMPLE_GUIDE_FOR_PARENTS.md`

## Setup Steps for Users

### One-Time Setup

1. Open Bhasha app
2. Go to Settings
3. Turn ON "Floating bubble active"
4. Tap "Enable accessibility"
5. In Android settings, enable Bhasha accessibility service
6. Optionally enable "Double-tap screen translation" and accept its disclosure

### Daily Use

1. Open any app (WhatsApp, Messages, Email)
2. Tap in text field and type in Kannada
3. Tap the blue "T" button
4. Text automatically translates to English — and is read aloud
5. Tap Undo within a few seconds if you want the original back

Or skip typing: press and hold the button, speak, release. Or double-tap to read the whole screen.

## User Experience Improvements

- **Reduced from 9 steps to 2 steps** (77% reduction!)
- No copying/pasting required
- No manual text deletion required
- Instant feedback with toasts, spoken playback, and haptics
- Undo makes the replacement reversible
- Feedback appears in Kannada for Kannada-language parents
- Incoming screens can be read without leaving the app
- Works in ANY app system-wide

## Safety & Privacy

- Accessibility service only reads/writes when the user taps, holds, or double-taps the button
- No background monitoring; the accessibility screenshot capability is not requested
- Screen pixels leave the device only on the double-tap OCR fallback: one in-memory frame, after the in-app disclosure and Android's own capture prompt, never written to disk
- Text and speech are only sent to Sarvam (user's own API key)
- Service description clearly explains usage
- Can be disabled anytime in Android settings

## Testing Checklist

- [ ] Accessibility permission granted
- [ ] Floating button appears
- [ ] Button is draggable
- [ ] Tap button with text in field → translates and speaks the result
- [ ] Undo pill restores the original text
- [ ] Hold button, speak, release → English appended to field
- [ ] Double-tap → translated labels drawn over the screen; tap dismisses
- [ ] Double-tap without the setting enabled → prompted to enable it in Settings
- [ ] Tap button without text → shows error message
- [ ] Tap button without accessibility → prompts to enable
- [ ] Toast messages display correctly (Kannada when parent language is Kannada)
- [ ] Works in WhatsApp
- [ ] Works in Messages
- [ ] Works in Email apps
- [ ] Works in Notes

## Known Limitations

1. Requires accessibility service permission (user must grant manually)
2. One-tap only works with editable text fields; the field must be focused first
3. The screen-OCR fallback is slow (async Sarvam Vision job) and cannot read `FLAG_SECURE` or photo-background screens
4. The contextual long-press flow is not wired end to end
5. Android-specific feature (iOS would need different implementation)

## Verification

The Dart request-handler tests cover Sarvam routing, source-package metadata, the Sarvam Vision job pipeline, geometry preservation, and rejection of unsupported packages. Native changes must also pass Android lint and a debug APK build before handoff.

## For Developers

### To modify one-tap behavior:

- Edit `OverlayService.kt` → `performOverlayAction()` (native side)
- Edit `lib/services/overlay_request_handler.dart` (Sarvam calls and prompts)

### To modify screen translation:

- Edit `OverlayService.kt` → `performScreenTranslation()` and `translateScreenViaAccessibility()`
- Edit `lib/services/sarvam_vision_service.dart` (OCR job pipeline)

### To customize button appearance:

- Edit `createCircleBackground()` for colors
- Modify the label in `idleButtonLabel()`

## Documentation

- **For parents**: See `SIMPLE_GUIDE_FOR_PARENTS.md`
- **For developers**: See `IMPLEMENTATION_SUMMARY.md`
- **Quick start**: See `QUICKSTART.md`

---

**Result**: Elderly users can now translate with ONE tap instead of NINE steps! 🎉
