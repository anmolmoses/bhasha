# Sarvam Buildathon: Bhasha Voice

## Product thesis

**Speak Kannada. Understand English. Reply confidently without leaving WhatsApp.**

Bhasha already solves one proven job for a real user: a parent can type Kannada, tap the floating bubble, and replace it with English inside WhatsApp. The buildathon version should deepen that successful behavior into a two-way, voice-first communication bridge.

This is not another translation app and it is not a general-purpose assistant. The user stays inside WhatsApp or another app they already understand. Bhasha appears only when asked, through the existing floating bubble.

### Primary user

An Indian parent who is comfortable speaking Kannada, can use familiar WhatsApp interactions, but struggles to type long messages, understand English messages, or discover translation features hidden inside other apps.

### Primary job to be done

> When I receive or need to send an English message, help me understand and reply using Kannada without leaving the app, copying text, navigating unfamiliar menus, or asking my child for help.

### Primary buildathon capability

**Voice Experience**

Translation, screen understanding, memory, and text-to-speech support this one voice experience. Dubbing and document intelligence are not part of the hackathon MVP.

---

## The complete experience

### 1. Speak a reply

1. The parent focuses the WhatsApp message field.
2. They press and hold the Bhasha bubble.
3. The bubble visibly and audibly enters listening mode.
4. They speak naturally in Kannada or Kannada-English.
5. They release the bubble.
6. Bhasha transcribes the speech, preserves names, dates, numbers, and corrections, and creates a concise English message.
7. The English message replaces the current WhatsApp text field.
8. The parent reviews it and presses WhatsApp's Send button.

Example:

> "ನಾನು Tuesday ಬರುತ್ತೇನೆ... ಇಲ್ಲ Wednesday morning ಬರುತ್ತೇನೆ. ಹತ್ತು ಗಂಟೆಗೆ."

Expected result:

> "I’ll come on Wednesday morning at 10."

The app must never send a message automatically. The parent remains in control.

### 2. Understand an incoming message

1. The parent taps the bubble while viewing an English message.
2. Bhasha gets the selected or most relevant visible message using the accessibility service. There is no screenshot path: the app does not declare the screenshot capability, so no screen pixels ever leave the device.
3. It translates the message into simple, conversational Kannada.
4. Bulbul reads the Kannada aloud at the parent's saved pace.
5. The overlay shows a short Kannada transcript and three large actions: **Stop**, **Ask**, and **Reply**.

### 3. Ask a follow-up

While the incoming message is being explained, the parent can tap **Ask** or interrupt playback and speak:

- "ಅವರು ಎಷ್ಟು ಹಣ ಕೇಳಿದ್ದಾರೆ?" — How much money are they asking for?
- "ಯಾವ ದಿನ ಬರಬೇಕು?" — Which day should I come?
- "ನಾನು ಏನು reply ಮಾಡಬೇಕು?" — What should I reply?

The answer is grounded only in the current message or screen context. It is spoken in concise Kannada and displayed as text.

### 4. Reply from the same context

The parent taps **Reply**, speaks Kannada, and receives an English draft in the focused field. Conversation context is used only to resolve references such as "that day", "the same amount", or "tell them yes".

---

## Why this can win

### JTBD completion

The changed state is not "a translation was generated." The changed state is:

- the parent understood an incoming message;
- clarified anything confusing;
- produced an appropriate English reply;
- and returned to a ready-to-send WhatsApp draft without leaving WhatsApp.

The demo must complete this end-to-end flow without judge intervention.

### Memory and context

Persist only useful, user-approved preferences:

- preferred input and output languages;
- preferred Kannada voice and playback pace;
- preferred tone: simple, warm, formal, or direct;
- explicitly saved names and pronunciations;
- explicitly saved family, place, medicine, and organization terms.

Maintain current-message and current-conversation context only for the active session. Do not persist full WhatsApp content by default.

Prove cross-session memory by closing and reopening the app, then correctly reusing a saved name, pronunciation, pace, and tone.

### Creativity

The novelty is the interaction model: a voice layer that lives over the app the parent already knows. It avoids a new chatbot, keyboard switching, copy/paste, language menus, and hidden operating-system translation gestures.

### Impact

The user gains independence in a repeated daily task. The full argument — beneficiary, frequency, baseline, and the one metric that moves — is in the [Impact case](#impact-case) section below.

### Delight

- one familiar floating control;
- large touch targets;
- clear listening, processing, speaking, success, and error states;
- subtle haptic feedback;
- an optional Kannada audio cue when listening begins;
- no technical terminology;
- no automatic sending;
- a visible undo action after replacing text.

---

## Impact case

### Beneficiary

A specific person, not a demographic: a Kannada-speaking parent in Bengaluru in her fifties. She types and reads Kannada comfortably and uses WhatsApp daily, but her child's school runs English-only WhatsApp groups, and her bank, apartment association, and local services all message her in English. She is the family's default recipient of these messages and, today, cannot act on them alone.

### Frequency

Our working estimate is **5–15 English messages per day** that she cannot confidently read or answer: school group announcements, fee and form reminders, bank and delivery notifications, and society notices. This is an assumption to validate with real usage logging, not measured data — it is drawn from observing one family's WhatsApp inbox, and the first week of real use should replace it with a real count. Even at the low end, that is an every-single-day job, which is what makes the impact compound.

### Current baseline

What this costs today:

- She waits hours for her child or a relative to be free to translate — the message's useful window often closes first.
- Consent forms, fee deadlines, and RSVP-style messages get missed or answered late.
- Some replies are simply never sent; the message dies unanswered.
- The do-it-yourself alternative is a ten-step copy-paste loop across two apps, and the reply still isn't in her own words.
- Every message reinforces dependence: the person the school hears from is the child, not the parent.

### The one metric that moves

**Share of English messages answered same-hour by the parent themselves.**

Baseline today: roughly **~20%** (our own observation of one household — an assumption to validate, not a study). The demo argues for a plausible improvement path of **5–10 percentage points** in the first weeks of real use, because Bhasha removes exactly the two blockers behind the other 80%: understanding cost (spoken Kannada playback, one tap) and production cost (hold-to-speak, English draft in the field, parent presses Send).

We deliberately track one metric rather than five. Time-to-draft, entity preservation, and app switches avoided are supporting evidence worth narrating in the demo, but the claim the demo makes is: messages this parent used to leave for someone else, she now answers herself, in the hour they arrive.

### Demo evidence map

Each rubric parameter is carried by a specific moment in the three-minute demo:

| Rubric parameter | Demo moment |
| --- | --- |
| JTBD completion | Hold-to-speak reply inside WhatsApp: focus field, hold, speak Kannada, release, English draft appears, parent presses Send — no app switch, no helper |
| Voice Experience | Code-mixed Kannada-English speech ("ನಾನು Wednesday morning ಬರುತ್ತೇನೆ") transcribed and translated correctly, plus results spoken aloud with Bulbul in the saved voice and pace |
| Memory | Kill and reopen the app: voice speaker, pace, tone, and an approved name from the glossary survive the restart and shape the next grammar fix |
| Delight | The Undo pill restores the parent's original text after a replacement; status and error copy is honest and rendered in Kannada |
| Creativity | The system-wide floating bubble: the assistant lives inside WhatsApp with zero app-switching, instead of being another app to learn |

---

## Sarvam architecture

### Required Sarvam capabilities

1. **Saaras v3 Speech to Text**
   - Kannada and Kannada-English input.
   - Use `mode=translate` when direct English output is suitable.
   - Use `mode=transcribe` or `mode=codemix` when intent analysis or a Kannada transcript is needed.
   - Prefer streaming when it is reliable in the existing app lifecycle; provide a REST upload fallback.

2. **Mayura translation**
   - Use for conversational WhatsApp translation.
   - Prefer modern-colloquial or classic-colloquial output rather than formal output.
   - Preserve international numerals.

3. **Sarvam Chat Completion**
   - Convert rambling speech into a concise draft without inventing information.
   - Resolve spoken corrections.
   - Answer follow-up questions using only supplied message context.
   - Ask one short clarification when a critical fact is genuinely ambiguous.

4. **Bulbul v3 Text to Speech**
   - Read Kannada explanations and questions.
   - Use a consistent saved voice.
   - Expose a parent-friendly pace control.
   - Use a pronunciation dictionary for explicitly saved terms when supported.

### Responsibility boundary

Keep the current project boundary:

```text
Native Android (Kotlin)
├── overlay gestures and visual states
├── microphone permission and audio capture
├── accessibility text discovery and focused-field replacement
├── haptics and audio playback lifecycle
└── MethodChannel messages
                │
                ▼
Flutter / Dart
├── Sarvam API client and response parsing
├── orchestration and conversation state
├── preferences, glossary, and secure API-key storage
├── settings and evidence UI
└── typed models and tests
```

Do not perform network requests on the Android UI thread. Do not log API keys, raw audio, screenshots, or message contents.

### Suggested new Dart structure

```text
lib/
├── models/
│   ├── parent_profile.dart
│   ├── voice_request.dart
│   ├── voice_result.dart
│   └── conversation_context.dart
├── services/
│   ├── sarvam_service.dart
│   ├── voice_orchestrator.dart
│   ├── parent_profile_service.dart
│   └── demo_metrics_service.dart
├── screens/
│   └── demo_evidence_screen.dart
└── widgets/
    ├── voice_settings_card.dart
    └── saved_terms_editor.dart
```

Adapt this structure if the existing code suggests a smaller or cleaner change.

### Suggested native changes

- Extend `OverlayService.kt` with press-and-hold detection and explicit states:
  `idle`, `listening`, `processing`, `speaking`, `success`, and `error`.
- Add a focused `VoiceCaptureManager.kt` if audio capture makes `OverlayService.kt` too large.
- Extend `MainActivity.kt` and the existing channel instead of creating inconsistent channel names.
- Extend `BhashaAccessibilityService.kt` with a conservative visible-message extractor that:
  - prioritizes selected text;
  - otherwise returns the most relevant readable node near the focused conversation;
  - never continuously monitors or stores messages;
  - returns a clear failure when no reliable message is available.
- Preserve the existing `ACTION_SET_TEXT` path and add undo by retaining the immediately replaced field value in memory for a short period.
- Update `AndroidManifest.xml` for microphone permission and any foreground-service microphone declaration required by the actual target SDK.

### API key and privacy

- Add a separate Sarvam API key field.
- Store it with `flutter_secure_storage`.
- Never commit a real key.
- Make Sarvam the load-bearing provider for the buildathon voice flow.
- Existing OpenAI functionality may remain as a legacy feature, but it must not silently handle the buildathon voice flow.
- Explain before first use that selected text or recorded audio is sent to Sarvam.
- Process only after an explicit hold, tap, or share action.
- Delete temporary audio immediately after a successful or failed request.

---

## Scope

### Must ship

- Sarvam key setup and connection check.
- Kannada as the default parent language and English as the default reply language.
- Hold bubble to record speech.
- Release to process speech.
- English result inserted into the focused field.
- Self-correction, names, dates, times, numbers, and code-mixing preserved.
- Incoming English message translated and read in Kannada.
- Stop or interrupt speech playback.
- One grounded spoken follow-up.
- Reply from the current context.
- Saved voice, pace, tone, and approved glossary terms.
- Undo after text replacement.
- Clear permission, offline, timeout, rate-limit, and unsupported-field errors.
- Three-case demo evidence screen.
- Unit tests for parsing, prompt construction, state transitions, memory, and entity preservation.
- Debug APK build on a real Android-capable environment.

### Should ship

- Streaming partial transcript.
- Share-intent handling for an incoming WhatsApp audio file.
- Kannada transcript plus spoken Kannada for a shared voice note.
- Lightweight local latency and task-success metrics.
- A rehearsal/demo mode that uses real Sarvam calls but preloads the three scenarios.

### Do not build during the hackathon

- YouTube downloading.
- Automatic WhatsApp message sending.
- Continuous screen or microphone monitoring.
- Scam detection, medical diagnosis, or financial advice.
- A broad autonomous assistant.
- Video dubbing.
- New iOS support.
- A backend unless a platform restriction makes it unavoidable.

---

## Six-hour build sequence

### 0:00–0:40 — Establish the vertical slice

- Add secure Sarvam key storage and a minimal `SarvamService`.
- Prove one Kannada audio sample can become English text.
- Add typed errors and redact sensitive logs.

### 0:40–2:15 — Voice-to-field workflow

- Add microphone permission.
- Implement press-and-hold recording in the bubble.
- Send audio through Saaras.
- Process the result and replace the focused text field.
- Add listening, processing, success, error, cancel, and undo states.
- Test in WhatsApp on a physical Android device.

This vertical slice is the non-negotiable demo.

### 2:15–3:30 — Incoming message understanding

- Reuse accessibility infrastructure to capture explicitly requested context.
- Translate to simple Kannada.
- Generate Kannada speech with Bulbul.
- Implement playback, stop, and interruption.

### 3:30–4:25 — Context and follow-up

- Store bounded in-memory conversation context.
- Add **Ask** and **Reply** actions.
- Ground all answers in the captured message.
- Ask for clarification instead of inventing critical details.

### 4:25–5:10 — Memory and parent UX

- Persist voice, pace, tone, and approved glossary entries.
- Add large, parent-friendly settings.
- Add explicit privacy text and temporary-file cleanup.

### 5:10–5:40 — Evidence and resilience

- Add three repeatable scenarios and metrics.
- Exercise noise, code-mixing, corrections, entities, interruptions, and relaunch memory.
- Add graceful network and unsupported-app fallbacks.

### 5:40–6:00 — Build and rehearse

- Run formatter, analyzer, tests, and debug APK build.
- Install on the demo phone.
- Run the complete demo twice.
- Preserve a short local fallback recording only for explaining a network failure; never present it as a live result.

---

## Three-minute demo

### 0:00–0:30 — Context

> "My mother can speak and type Kannada, but many WhatsApp conversations require English. Translation exists, but finding it means leaving the app or remembering hidden gestures. Bhasha gives her one voice bubble inside the app she already knows."

### 0:30–1:00 — Manual workflow

Briefly show the old workflow: copy, leave WhatsApp, open translator, paste, translate, copy, return, and paste.

### 1:00–2:35 — Live experience

1. Open an English WhatsApp message containing a date, time, amount, and name.
2. Tap the bubble and hear a concise Kannada explanation.
3. Interrupt and ask one Kannada follow-up.
4. Hold the bubble and speak a Kannada-English reply with a self-correction.
5. Release and show the correct English draft inside WhatsApp.
6. Show that the app remembered the parent's voice pace and a saved name.

### 2:35–3:00 — Evidence

Show the three-case evidence screen:

- three of three tasks completed without help;
- all critical entities preserved;
- self-corrections applied;
- median and worst-case latency;
- zero app switches.

End with:

> "Bhasha does not teach my mother another app. It gives her independence inside the one she already uses."

---

## Acceptance checklist

- [ ] No real API key exists in Git history or logs.
- [ ] A parent can hold, speak Kannada, release, and get English in a focused WhatsApp field.
- [ ] The flow handles Kannada-English code-mixing.
- [ ] "Tuesday—no, Wednesday" produces Wednesday only.
- [ ] Names, phone numbers, dates, times, and amounts are preserved.
- [ ] Incoming English can be heard in simple Kannada.
- [ ] Playback can be interrupted immediately.
- [ ] A follow-up answer is grounded in the current message.
- [ ] A reply can reference the current message context.
- [ ] The app never sends on the parent's behalf.
- [ ] Undo restores the previous field text.
- [ ] Voice, pace, tone, and approved glossary survive an app restart.
- [ ] Full message history is not retained by default.
- [ ] Temporary audio is deleted.
- [ ] Permissions have non-technical explanations and recovery paths.
- [ ] A network failure never destroys existing text.
- [ ] Three repeatable demo cases pass.
- [ ] `dart format` succeeds.
- [ ] `flutter analyze` succeeds.
- [ ] `flutter test` succeeds.
- [ ] `flutter build apk --debug` succeeds.

---

# One prompt to build the complete feature

Copy everything inside the following prompt into a capable coding agent while it is opened at the root of this repository.

```text
You are the senior product engineer responsible for implementing the Sarvam Buildathon version of Bhasha end to end in this repository. Do not stop after analyzing, proposing architecture, scaffolding, or writing TODOs. Inspect the current code, implement the complete working vertical slice, test it proportionately, and update the documentation. Continue autonomously through reasonable implementation decisions. Ask for user input only when a missing credential, unavailable physical device, or irreversible product decision truly prevents progress.

PRODUCT

Build “Bhasha Voice,” a parent-first, system-wide voice bridge whose primary job is:

“When I receive or need to send an English message, help me understand and reply using Kannada without leaving WhatsApp, copying text, navigating unfamiliar menus, or asking my child for help.”

The user already loves the existing flow where Kannada text in a focused field becomes English after tapping the floating bubble. Preserve that functionality. Extend it so the complete experience is:

1. Focus a WhatsApp text field.
2. Press and hold the Bhasha bubble.
3. Speak naturally in Kannada or Kannada-English.
4. Release the bubble.
5. Use Sarvam to transcribe/translate the audio, preserve intent and critical entities, apply spoken self-corrections, and create a concise English draft.
6. Replace the focused field with that draft.
7. Let the user review and manually press Send. Never send automatically.

Also implement:

1. An explicit tap/read action for an incoming English message or visible selected text.
2. Translate it into simple conversational Kannada and read it aloud with Sarvam Bulbul.
3. Show large Stop, Ask, and Reply actions.
4. Let the user interrupt playback immediately.
5. Let the user ask one or more spoken Kannada follow-up questions grounded only in the captured message.
6. Let the user speak a contextual Kannada reply and place the English result in the focused field.

Read SARVAM_BUILDATHON.md and AGENTS.md completely before editing. Treat SARVAM_BUILDATHON.md as the product specification and this prompt as the execution contract. Inspect all existing Flutter and Kotlin integration code before choosing implementation details. Preserve unrelated user work and the current Flutter/native responsibility boundary.

SARVAM MUST BE LOAD-BEARING

Use the official Sarvam APIs for the buildathon flow:

- Saaras v3 for Kannada/Kannada-English speech recognition. Use mode=translate for direct speech-to-English where appropriate; use transcribe or codemix when a source transcript is needed. Prefer real-time streaming if it is robust in the current process lifecycle, but implement a REST audio-upload fallback so the demo still works.
- Mayura for conversational Kannada/English translation using an appropriate colloquial mode and international numerals.
- Sarvam Chat Completion for intent-preserving rewriting, spoken correction resolution, short grounded follow-ups, and at most one concise clarification when a critical fact is ambiguous.
- Bulbul v3 for Kannada speech output with a saved voice and parent-friendly pace.
- Use a Bulbul pronunciation dictionary for explicitly approved saved terms if practical with the public API.

Use current official Sarvam documentation and model identifiers. Do not invent endpoints or response fields. Centralize endpoint configuration and parsing. Create typed request/result/error models. Implement timeouts, 401/403, 413/422, 429, server-error, offline, cancellation, and malformed-response handling. Never silently fall back to OpenAI for this feature. Existing OpenAI features may remain available as legacy functionality.

SECRETS AND PRIVACY

- Add a distinct Sarvam API key input and connection check.
- Store the key only in flutter_secure_storage.
- Never hardcode, print, screenshot, commit, or expose a real key.
- Do not log message contents, raw audio, screenshots, authorization headers, or model responses in production.
- Explain before first use that explicitly selected text/audio will be sent to Sarvam.
- Record/process only after an explicit hold, tap, Ask, Reply, or share action.
- Delete temporary audio after success, cancellation, or failure.
- Do not persist full WhatsApp messages or conversation history by default.
- Persist only approved parent preferences and glossary entries.
- Keep active message/conversation context bounded and in memory.

EXISTING EXTENSION POINTS

The repository currently has:

- Flutter UI, storage, OpenAI services, and overlay request coordination.
- MainActivity.kt with the existing MethodChannel.
- OverlayService.kt with the floating bubble and actions.
- BhashaAccessibilityService.kt with focused editable-field discovery and ACTION_SET_TEXT replacement.
- A scaffolded CustomKeyboardIME.kt.

Reuse these pieces. Do not create competing method-channel names or duplicate services without a strong reason.

Native Android/Kotlin should own:

- bubble gestures and overlay state;
- microphone permission and recording lifecycle;
- haptics;
- accessibility node discovery and focused-field replacement;
- immediate undo state;
- audio playback lifecycle when that is more reliable outside the Flutter activity;
- lifecycle-safe MethodChannel events.

Flutter/Dart should own:

- Sarvam HTTP/WebSocket API clients;
- orchestration, prompts, response validation, and typed errors;
- current conversation context;
- secure key and profile storage;
- settings, glossary, privacy UI, and demo evidence;
- unit-testable state transitions.

If the current engine lifecycle makes Dart networking unreliable while the app is backgrounded, fix the lifecycle deliberately or move only the minimum required request orchestration into a lifecycle-safe component. Do not block the Android UI thread. Document the chosen lifecycle behavior.

INTERACTION DETAILS

Implement an unambiguous bubble gesture model that does not break existing actions:

- Press and hold: start voice reply recording.
- Release: stop and process.
- Drag: move the bubble without accidentally recording.
- Short tap: open the compact incoming-message actions or run the configured existing action.
- Provide an accessible alternative in settings if a gesture is difficult.

Use explicit visual states: idle, listening, processing, speaking, success, and error. Add subtle haptics and an optional short Kannada audio cue for start/stop. All overlay targets must be large enough for older users. Avoid tiny icons without labels.

The voice-reply pipeline must:

- preserve names, dates, times, amounts, addresses, phone numbers, medicine names, and negation;
- understand Kannada-English code-mixing;
- resolve self-corrections such as “Tuesday—no, Wednesday” to the final intended value;
- remove filler without changing intent;
- use the saved tone;
- never invent a missing critical detail;
- ask one short Kannada clarification when required;
- show the final English draft before the user sends it;
- keep the old field value and expose Undo for at least the immediate result.

The incoming-message pipeline must:

- prefer explicitly selected accessibility text;
- otherwise conservatively choose the most relevant visible readable message;
- fail clearly rather than reading the wrong conversation, since there is no screenshot fallback;
- translate into simple conversational Kannada;
- speak and display the result;
- support immediate stop/interruption;
- answer follow-ups only from the captured text, saying that the information is absent when necessary.

MEMORY

Create a typed ParentProfile and storage service. Persist:

- input language, default Kannada;
- reply language, default English;
- selected Bulbul voice;
- playback pace;
- tone: simple, warm, formal, or direct;
- explicitly approved glossary entries with source spelling, target spelling, and optional pronunciation.

Add a simple parent-friendly settings UI for these values. Full message history must remain ephemeral. Prove persistence with tests and the demo evidence screen.

WHATSAPP VOICE NOTES

After the core vertical slice passes, implement Android share-intent support for a user-shared audio file when time permits:

- accept content URIs safely;
- validate type and size;
- copy to a temporary app-owned file;
- transcribe with Saaras;
- translate to Kannada;
- display and speak the result;
- delete the temporary copy.

This is a should-have, not a reason to leave the hold-to-speak core unfinished.

Do not download YouTube videos, automatically send WhatsApp messages, continuously monitor the screen or microphone, add medical/financial advice, build video dubbing, add iOS, or introduce a backend unless a demonstrated platform restriction requires it.

DEMO EVIDENCE

Add a developer/demo evidence screen that runs or records three repeatable, real end-to-end scenarios:

1. Appointment message with a name, weekday, date, and time.
2. Vendor/service message with a person, amount, phone number, and location.
3. Family/community message containing Kannada-English code-mixing and a spoken self-correction.

For each case record only non-sensitive test data and:

- whether the task completed without help;
- expected versus preserved critical entities;
- whether the self-correction was applied;
- end-to-end latency;
- whether the draft reached the focused field;
- whether playback interruption worked.

Show aggregate completion rate, entity preservation, correction success, median latency, worst-case latency, and app switches avoided. Do not fabricate results. Label simulated/unit-test evidence separately from real-device results.

TESTING

Add unit tests for:

- Sarvam response parsing and typed errors;
- prompt construction and context grounding;
- entity preservation validation;
- self-correction examples;
- voice-flow state transitions and cancellation;
- ParentProfile serialization and persistence;
- bounded conversation context;
- temporary-file cleanup abstractions where practical.

Use dependency injection or lightweight interfaces so Sarvam calls are mockable. Do not make unit tests depend on a live paid API.

Verify formatting and static analysis. Run, in order where available:

1. dart format .
2. flutter pub get
3. flutter analyze
4. flutter test
5. flutter build apk --debug

For native changes, inspect Android manifest and target-SDK requirements, especially RECORD_AUDIO and foreground-service microphone permissions/types. Test on a physical Android device if one is connected. Validate at least WhatsApp and one simple text editor. Report exact commands and exact failures caused by unavailable Flutter/Android tooling or lack of a device; do not claim success without evidence.

DOCUMENTATION

Update README.md and relevant setup/user docs with:

- the parent-first voice workflow;
- Sarvam key setup;
- microphone, overlay, and accessibility permission explanations;
- gestures and accessible alternatives;
- privacy and temporary-data behavior;
- current limitations;
- the three-minute demo instructions.

Keep SARVAM_BUILDATHON.md as the product and acceptance source of truth. Mark checklist items only when verified.

DEFINITION OF DONE

The task is not done until all feasible items below are implemented and verified:

- A parent can focus WhatsApp, hold the bubble, speak Kannada/Kannada-English, release, and receive an accurate English draft in the field.
- Code-mixing and “Tuesday—no, Wednesday” work.
- Critical entities are preserved.
- An explicit incoming English message can be translated and heard in Kannada.
- Speech playback can be interrupted.
- A Kannada follow-up is answered only from the active message.
- A contextual Kannada reply becomes an English field draft.
- The app never sends automatically.
- Undo restores the immediately previous field value.
- Voice, pace, tone, and approved glossary entries survive relaunch.
- Secrets and sensitive content are not logged or committed.
- Temporary audio is deleted.
- Failures are recoverable and never destroy existing field text.
- Three honest demo scenarios and metrics are visible.
- Tests and available build checks pass.
- Documentation matches the implemented behavior.

Begin by reading the repository and producing a short internal implementation order, then immediately implement the vertical slice. Keep working through compile errors, test failures, Android lifecycle issues, and integration gaps until the definition of done is met or a genuine external blocker remains. At handoff, lead with what works, list verification evidence, identify any external blocker precisely, and provide the shortest real-device demo procedure.
```
