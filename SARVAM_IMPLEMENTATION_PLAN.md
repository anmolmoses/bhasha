# Bhasha Voice — Sarvam Implementation Plan

Companion to `SARVAM_BUILDATHON.md`. That document is the **product and acceptance
source of truth**; this one is the **engineering plan**: which Sarvam APIs we call,
what replaces OpenAI, what the architecture has to change, and in what order we build.

- **Status:** planning only. No feature code written yet.
- **API facts verified against:** `docs.sarvam.ai`, 26 July 2026. Every endpoint,
  field name, model id, and limit below was read from the live docs, not recalled.
- **Scope change from `SARVAM_BUILDATHON.md`:** that spec permitted OpenAI to stay
  as a legacy provider. **This plan removes OpenAI entirely.** Sarvam becomes the
  only inference provider in the app.

---

## 1. Scope change: full OpenAI removal

`SARVAM_BUILDATHON.md` §"API key and privacy" says OpenAI "may remain available as
legacy functionality." That is superseded. Target end state:

- `lib/services/openai_service.dart` is **deleted**.
- The OpenAI API key field, its secure-storage entry, and its onboarding copy are removed.
- One key, one provider, one place to fail: the Sarvam key.

This removes a whole class of demo risk (wrong key pasted, silent fallback to the
wrong provider) and makes the "Sarvam is load-bearing" claim literally true.

### 1.1 What OpenAI does today, and what replaces it

`openai_service.dart` (369 lines) exposes four capabilities. Three port cleanly.
One does not.

| # | Current OpenAI capability | Used by | Sarvam replacement | Port difficulty |
|---|---|---|---|---|
| 1 | `translate()` — GPT prompt, free-text translation | Bubble "translate" action, `OverlayRequestHandler._handleTranslate` | `POST /translate` (Mayura) | **Clean.** Purpose-built; better colloquial output than a generic prompt. |
| 2 | `detectLanguage()` — GPT prompt returning a language name | Auto-detect path in `_handleTranslate` | `POST /text-lid` | **Clean, and an upgrade.** Returns a structured `language_code` + `script_code` instead of a free-text language name we currently have to string-match. |
| 3 | `checkGrammar()` — GPT prompt, corrected text | Bubble "grammar" action | `POST /v1/chat/completions` (`sarvam-105b`) | **Clean.** Same shape (system + user → text), OpenAI-compatible response envelope. |
| 4 | `suggestXReplies()` — **vision** call over a base64 screenshot | Bubble "x_replies" action, `BhashaAccessibilityService.takeScreenshotBase64` | **No direct equivalent.** See §1.2. | **Blocked.** |

### 1.2 The one real gap: no vision model

Sarvam's chat completion API documents `sarvam-30b` (64K) and `sarvam-105b` (128K).
**Neither documents image input.** There is no multimodal endpoint in the Sarvam API
surface. So the screenshot → reply-suggestions feature cannot be ported as-is.

Three options, in the order I'd recommend them:

1. **Re-implement on accessibility text, drop the screenshot.** Read the visible post
   text via `BhashaAccessibilityService` node traversal, send *text* to
   `/v1/chat/completions`. Keeps the feature, removes the vision dependency, and is
   strictly more private (no screen pixels leave the device). It also reuses the exact
   conservative extractor `SARVAM_BUILDATHON.md` §"Suggested native changes" already
   asks us to build for the incoming-message flow — so it is close to free.
2. **Cut the feature for the buildathon.** X-replies is not in the MVP scope
   (`SARVAM_BUILDATHON.md` §"Must ship" does not list it). Removing it deletes the
   screenshot path, `takeScreenshotBase64`, and the `x_replies` settings block.
3. **Keep OpenAI solely for this one feature.** Contradicts the instruction to replace
   OpenAI. Not recommended.

**Recommendation: option 1**, with option 2 as the fallback if time runs short.
Either way the screenshot path stops being load-bearing, which is a privacy win.

> **Decision needed from you.** Everything else in this plan is unblocked.

---

## 2. Sarvam API reference — everything we will call

All endpoints share:

- **Base URL:** `https://api.sarvam.ai`
- **Auth header:** `api-subscription-key: <KEY>`
  (chat completions additionally accepts `Authorization: Bearer <KEY>`)

### 2.1 Speech to Text — Saaras

`POST /speech-to-text` · `multipart/form-data`

> **Use `/speech-to-text`, not `/speech-to-text-translate`.** The latter is the legacy
> `saaras:v2.5` endpoint. Saaras v3 exposes translation through the `mode` field on the
> main endpoint.

| Field | Required | Value |
|---|---|---|
| `file` | yes | Audio binary |
| `model` | yes | `saaras:v3` |
| `mode` | no (default `transcribe`) | `transcribe` \| `translate` \| `verbatim` \| `translit` \| `codemix` |
| `language_code` | no | `kn-IN` for Kannada; omit to auto-detect |

**Response:** `{ "request_id": string, "transcript": string, "language_code": string }`

**Modes we use:**

| Mode | Where | Why |
|---|---|---|
| `translate` | Hold-to-speak reply | Kannada/code-mixed speech → English in one hop. Fewer round trips, less latency, no intermediate translation loss. |
| `codemix` | Ask (follow-up questions) | We need the *Kannada* question text to ground the answer, with English words kept in Latin script. |
| `transcribe` | Evidence screen / debugging | Native-script transcript for showing the parent what was heard. |

**Formats:** WAV, MP3, AAC, AIFF, OGG, OPUS, FLAC, MP4, AMR, WMA, WebM, raw PCM.
Preferred: **16 kHz mono 16-bit WAV**.

**⚠️ Hard limit: 30 seconds per REST request.** This is a product constraint, not just
a technical one — see §6.1.

### 2.2 Streaming Speech to Text (should-have)

`WSS /speech-to-text/ws`

- Audio sent base64-encoded; `wav` or raw PCM (`pcm_s16le` / `pcm_l16` / `pcm_raw`).
- 16 kHz recommended, 8 kHz supported; sample rate must match between connect and send.
- With `vad_signals=true`, emits `speech_start` / `speech_end` events plus `transcript`.
- Docs warn "long-lived sockets will occasionally drop" and recommend reconnect-with-backoff.

**⚠️ The docs do not state the full `wss://` hostname or how the key is passed on the
raw socket handshake** — both are shown only through the Python/JS SDKs, which we
cannot use from Dart. Treat streaming as a **should-have behind a flag**, built only
after the REST path is demo-proven. See §6.2.

### 2.3 Translation — Mayura

`POST /translate` · JSON

| Field | Required | Value |
|---|---|---|
| `input` | yes | ≤ **1000 chars** (`mayura:v1`); 2000 for `sarvam-translate:v1` |
| `source_language_code` | yes | `auto` \| `kn-IN` \| `en-IN` \| … |
| `target_language_code` | yes | as above, excluding `auto` |
| `model` | no | `mayura:v1` \| `sarvam-translate:v1` |
| `mode` | no | `formal` \| `modern-colloquial` \| `classic-colloquial` \| `code-mixed` |
| `output_script` | no | `roman` \| `fully-native` \| `spoken-form-in-native` \| `null` |
| `numerals_format` | no | `international` \| `native` |
| `speaker_gender` | no | `Male` \| `Female` |

**Response:** `{ "request_id": string, "translated_text": string, "source_language_code": string }`

**Our settings:** `model=mayura:v1`, `mode=modern-colloquial`,
`numerals_format=international`.

The numerals choice is deliberate and matters for the demo: it keeps `10:30` and
`₹500` as digits rather than rendering them in Kannada numerals, which parents read
noticeably slower and which would undercut the entity-preservation claim.

### 2.4 Text to Speech — Bulbul

`POST /text-to-speech` · JSON

| Field | Required | Value |
|---|---|---|
| `text` | yes | ≤ **2500 chars** |
| `target_language_code` | yes | `kn-IN` for Kannada |
| `model` | yes | `bulbul:v3` (or `bulbul:v2`) |
| `speaker` | yes | v3 voices — female: Ritu, Priya, Neha, Pooja, Simran, Kavya, Ishita, Shreya, Roopa, Tanya, Shruti, Suhani, Kavitha, Rupali · male: Shubh, Aditya, Rahul, Rohan, Amit, Dev, Ratan, Varun, Manan, Sumit, Kabir, Aayan, Ashutosh, Advait, Anand, Tarun, Sunny, Mani, Gokul, Vijay, Mohit, Rehan, Soham |
| `pace` | no | `0.5`–`2.0` ← the parent-facing pace control |
| `speech_sample_rate` | no | 8000 / 16000 / 24000 / 32000 / 44100 / 48000 (default 24000) |
| `speech_codec` | no | `wav` \| `mp3` \| `linear16` \| `mulaw` \| `alaw` \| `opus` \| `flac` \| `aac` |
| `dict_id` | no | pronunciation dictionary — see §2.6 |

**Response:** `{ "request_id": string, "audios": [ "<base64 WAV>" ] }`

Note `audios` is an **array of base64 strings, not raw binary** — decode and
concatenate in playback order.

### 2.5 Chat Completion

`POST /v1/chat/completions` · JSON · OpenAI-compatible envelope

| Field | Value |
|---|---|
| `model` | `sarvam-105b` (128K) \| `sarvam-30b` (64K) |
| `messages` | `[{role: system\|user\|assistant\|tool, content}]` |
| `temperature` | 0–2, default 0.2 |
| `max_tokens` | default 2048 |
| `response_format` | `text` \| `json_object` \| `json_schema` |
| `reasoning_effort` | `low` \| `medium` \| `high` |
| `stream` | bool |
| `tools` | function calling |

**Response:** `{ id, object, created, model, choices[0].message.content, usage }`

**We use `sarvam-105b`** with `response_format: json_object` for the rewrite and
follow-up calls — structured output removes the fragile "parse prose into a draft"
step. `sarvam-30b` is the fallback if latency is a problem on demo wifi.

### 2.6 Pronunciation dictionary

`bulbul:v3` only. Pass `dict_id` on the TTS request; works across REST, HTTP stream,
and WebSocket.

```json
{ "pronunciations": { "kn-IN": { "WORD": "pronunciation" } } }
```

| Limit | Value |
|---|---|
| Dictionaries per user | 10 |
| Words per dictionary | 100 |
| File size | 1 MB |
| Dictionaries per request | 1 |
| Languages | hi, en, ta, te, kn, ml, mr, gu, pa, od, bn (`-IN`) |

Matching is **exact only**. This maps directly onto the "explicitly saved names and
pronunciations" memory requirement.

**⚠️ Unverified:** the docs describe *using* a `dict_id` but I did not confirm the
endpoint that **creates/updates** a dictionary. Must be confirmed before we commit to
building glossary → dictionary sync. Fallback if no public create API exists: apply
glossary terms as prompt-level spelling constraints (already planned for the text
path) and skip TTS-level pronunciation. This is why pronunciation-dictionary work is
scheduled last.

### 2.7 Language identification

`POST /text-lid` · JSON · `input` ≤ 1000 chars

**Response:** `{ request_id, language_code, script_code }`
(`script_code` ∈ Latn, Deva, Beng, Gujr, **Knda**, Mlym, Orya, Guru, Taml, Telu)

Replaces `OpenAIService.detectLanguage()`. `script_code` is a genuine upgrade: it lets
us tell romanized Kannada ("naanu barthini") from native-script Kannada and route
transliteration accordingly.

### 2.8 Transliteration (optional)

`POST /transliterate` · `input` ≤ 1000 chars ·
fields `source_language_code`, `target_language_code`, `spoken_form`,
`numerals_format`, `spoken_form_numerals_language`

**Response:** `{ request_id, transliterated_text, source_language_code }`

Not required for the MVP. Useful later if a parent types romanized Kannada.

---

## 3. Feature → API mapping

| Product flow (`SARVAM_BUILDATHON.md`) | API calls, in order |
|---|---|
| **1. Speak a reply** (hold → English draft) | `/speech-to-text` `mode=translate` → `/v1/chat/completions` (rewrite: tone, self-correction, entity preservation) → native `ACTION_SET_TEXT` |
| **2. Understand incoming message** (tap → Kannada audio) | accessibility text capture → `/translate` `kn-IN`, `modern-colloquial` → `/text-to-speech` `bulbul:v3` → native playback |
| **3. Ask a follow-up** | `/speech-to-text` `mode=codemix` → `/v1/chat/completions` (grounded, message-only) → `/text-to-speech` |
| **4. Reply from context** | `/speech-to-text` `mode=translate` → `/v1/chat/completions` (context resolves "that day") → native `ACTION_SET_TEXT` |
| **Legacy: text translate** (existing bubble tap) | `/text-lid` (when auto-detect on) → `/translate` |
| **Legacy: grammar check** | `/v1/chat/completions` |
| **Legacy: X replies** | **blocked — see §1.2** |
| **Key connection check** | cheapest call: `/translate` with a 2-char input |

---

## 4. Architecture

### 4.1 The blocking problem: the Flutter engine dies when backgrounded

This is the single most important finding from reading the code, and it must be fixed
before any Sarvam call matters.

`MainActivity.kt:18` holds the channel in a static:

```kotlin
private var methodChannelRef: MethodChannel? = null   // set in configureFlutterEngine
```

and `MainActivity.kt:190-195` clears it in `onDestroy()`. `OverlayService` reaches
Dart only through `MainActivity.processOverlayAction(...)`, which returns this when the
ref is null:

> "Bhasha is not ready. Open the app once to initialize."

So the moment the parent is actually **inside WhatsApp** — the entire premise of the
product — Android is free to destroy `MainActivity`, and every Sarvam call the plan
depends on fails. The existing tap-to-translate flow works today only while the
activity happens to still be alive.

**Fix:** move to a **cached, activity-independent `FlutterEngine`**.

- Create the engine in a custom `Application.onCreate()` (or lazily on first overlay start).
- Execute the Dart entrypoint on it and register it in `FlutterEngineCache` under a
  stable id.
- `OverlayService` talks to **that** engine's `MethodChannel`. It never depends on
  `MainActivity`.
- `MainActivity` attaches to the same cached engine via `provideFlutterEngine()`, so UI
  and overlay share one Dart isolate, one `StorageService`, one profile cache.

This keeps the responsibility boundary `SARVAM_BUILDATHON.md` mandates — networking
stays in Dart — while making it survive backgrounding. It is a deliberate lifecycle
change and will be documented in the README as required by the spec.

### 4.2 Responsibility boundary (unchanged from spec)

| Native Kotlin | Flutter Dart |
|---|---|
| Bubble gestures, six visual states | Sarvam clients + response parsing |
| Mic permission, capture, 16 kHz WAV encode | Orchestration, prompts, typed errors |
| Accessibility discovery, `ACTION_SET_TEXT` | Bounded conversation context |
| Undo buffer (previous field value) | Secure key + profile storage |
| Audio playback lifecycle, haptics | Settings, glossary, evidence UI |

**Why playback is native:** the audio must keep playing and stay interruptible while
Flutter's UI is not on screen. Doing it in Dart would add a plugin whose lifecycle is
tied to the very activity we just stopped depending on.

### 4.3 MethodChannel contract

Keep the existing channel name `com.yourapp.bhasha/native`. No new channels.

**Native → Dart** (extends existing `processOverlayAction`):

| `action` | Args | Returns |
|---|---|---|
| `voice_reply` | `audioPath` | `resultText`, `transcript`, `latencyMs`, `clarification?` |
| `explain_incoming` | `text` | `kannadaText`, `audios[]`, `latencyMs` |
| `ask_followup` | `audioPath` | `answerText`, `audios[]`, `latencyMs` |
| `contextual_reply` | `audioPath` | `resultText`, `transcript`, `latencyMs`, `clarification?` |
| `translate` / `grammar` | `text` | *(existing, re-pointed at Sarvam)* |

**Dart → Native:** `setVoiceState(state)`, `playAudio(base64[])`, `stopPlayback()`,
`replaceFocusedText(text)`, `undoReplace()`, `readVisibleMessage()`, `deleteTempFile(path)`.

### 4.4 Files

**Delete:** `lib/services/openai_service.dart`

**New (Dart):**
```
lib/models/    sarvam_error.dart · parent_profile.dart · voice_result.dart · conversation_context.dart
lib/services/  sarvam_service.dart · voice_orchestrator.dart · voice_prompts.dart
               parent_profile_service.dart · demo_metrics_service.dart
lib/screens/   demo_evidence_screen.dart
lib/widgets/   voice_settings_card.dart · saved_terms_editor.dart
```

**New (Kotlin):** `BhashaApplication.kt` (engine cache), `VoiceCaptureManager.kt` (mic + WAV)

**Modified (Kotlin):** `OverlayService.kt` (hold gesture, six states, playback),
`MainActivity.kt` (shared engine), `BhashaAccessibilityService.kt` (message extractor,
undo buffer), `AndroidManifest.xml` (`RECORD_AUDIO`, `FOREGROUND_SERVICE_MICROPHONE`,
`foregroundServiceType="microphone|specialUse"`)

> `targetSdk` is **35**, so `FOREGROUND_SERVICE_MICROPHONE` is mandatory alongside the
> `microphone` foreground-service type — mic capture from a service silently fails
> without it on Android 14+.

---

## 5. Build order

Sequenced so the non-negotiable demo path exists earliest and every later phase is
independently droppable.

| Phase | Work | Exit criteria |
|---|---|---|
| **0 · Foundation** | Cached `FlutterEngine`; delete `openai_service.dart`; Sarvam key in secure storage + connection check; `SarvamService` with typed errors | Overlay reaches Dart with `MainActivity` destroyed; key check passes |
| **1 · Vertical slice** ⭐ | `RECORD_AUDIO`; `VoiceCaptureManager` (16 kHz WAV, 30 s cap); hold-to-record; `mode=translate`; chat rewrite; `ACTION_SET_TEXT`; undo | Hold → speak Kannada → release → English lands in WhatsApp field |
| **2 · Incoming** | Conservative message extractor; Mayura → Kannada; Bulbul; playback + immediate stop | Tap → hear accurate Kannada; stop is instant |
| **3 · Context** | Bounded in-memory context; Ask + Reply; grounded answers; one clarification | Follow-up answered only from captured message |
| **4 · Memory & UX** | `ParentProfile` persistence; parent-friendly settings; glossary editor; privacy notice; temp-file cleanup | Voice/pace/tone/glossary survive relaunch |
| **5 · Evidence** | Three scenarios; metrics; real-vs-simulated labelling | Evidence screen shows honest results |
| **6 · Verify** | `dart format` · `flutter analyze` · `flutter test` · `flutter build apk --debug` | All green; APK installs |
| **7 · Should-have** | Streaming STT; share-intent voice notes; pronunciation dictionary | Only if 0–6 are done |

⭐ Phase 1 is the non-negotiable demo. If everything after it is cut, the demo still lands.

---

## 6. Constraints and risks

### 6.1 30-second STT ceiling — a product constraint

REST `/speech-to-text` rejects audio over 30 s. Consequences:

- `VoiceCaptureManager` **hard-stops at ~28 s** with haptic + visual warning. We must
  never let the parent speak for 40 s and then lose it — that is the worst possible
  failure for this user.
- The bubble should show elapsed time past ~20 s.
- Longer audio would need the Batch API (async job: initiate → upload → start → poll →
  download), which is unusable for an interactive flow. Out of scope.
- Realistically fine: a WhatsApp reply is 5–15 s of speech.

### 6.2 Streaming is a should-have, not a plan

The `wss://` hostname and raw-socket auth are not documented outside the SDKs. We
build REST first and treat streaming as an enhancement gated behind a flag, per
`SARVAM_BUILDATHON.md` ("provide a REST upload fallback"). No demo capability depends
on it.

### 6.3 Character limits force chunking

Mayura 1000 / Bulbul 2500. A long forwarded WhatsApp message will exceed 1000. Split
on sentence boundaries, translate per chunk, rejoin. Unit-tested.

### 6.4 Language-code inconsistency

Odia appears as `od-IN` in `/translate` and `/transliterate` but `or-IN` in the TTS
docs. Irrelevant for Kannada (`kn-IN` everywhere) but the language constant table must
be per-endpoint, not global, so this doesn't bite later.

### 6.5 Other risks

| Risk | Mitigation |
|---|---|
| No vision model (§1.2) | Decision needed; recommend accessibility-text rewrite |
| `dict_id` creation API unconfirmed (§2.6) | Scheduled last; prompt-level glossary fallback |
| Demo wifi latency | `sarvam-30b` fallback; latency shown honestly on evidence screen |
| Accessibility reads wrong message | Prefer selected text; **fail loudly** rather than read the wrong chat |
| Network failure destroys field text | Never clear the field before a success response; undo buffer always populated first |

---

## 7. Privacy

- Sarvam key in `flutter_secure_storage` only. Never logged, never committed.
- Audio, screenshots, message text, auth headers, model responses: **never logged** in release.
- Recording only after an explicit hold / tap / Ask / Reply.
- Temp audio deleted in a `finally` — on success, failure, and cancellation alike.
- No message history persisted. Conversation context is in-memory and bounded (~6 turns).
- Only approved preferences and glossary entries persist.
- First-use notice explaining what leaves the device, before the first Sarvam call.
- Dropping the screenshot path (§1.2 option 1) means **no screen pixels ever leave the device.**

---

## 8. Test plan

Unit tests, no live API — `http.Client` injected and mocked.

| Area | Cases |
|---|---|
| Response parsing | Valid/malformed for all 5 endpoints; missing `transcript`; empty `audios`; non-JSON body |
| Typed errors | 401/403 → `unauthorized`; 413/422 → `payloadTooLarge`; 429 → `rateLimited`; 5xx; socket → `offline`; timeout |
| Prompt construction | Tone injected; glossary block present/absent; grounding block empty when no message captured |
| Entity preservation | Names, weekdays, dates, times, `₹` amounts, 10-digit phones survive rewrite |
| Self-correction | "Tuesday — no, Wednesday" → Wednesday only; "five hundred… actually six hundred" → 600 |
| State machine | Legal/illegal transitions; cancel from every state; error never strands `listening` |
| Memory | `ParentProfile` round-trip; unknown fields tolerated; survives simulated restart |
| Context | Bounded at N turns; cleared on new capture; grounding refuses when empty |
| Chunking | 1000/2500-char splitting on sentence boundaries |

---

## 9. Open decisions

1. **X-replies (§1.2)** — rewrite on accessibility text *(recommended)*, cut, or keep OpenAI for it alone?
2. **Sarvam API key** — needed for any live verification. Not in the repo, correctly.
3. **Physical Android device** — `adb devices` is currently empty. The APK will build,
   but no on-device claim (WhatsApp field replacement, mic capture, playback
   interruption) can be verified without one.

---

## 10. Current environment

| Item | State |
|---|---|
| Flutter | ✅ 3.41.1 / Dart 3.11.0 (`~/development/flutter`, not on `PATH`) |
| Android SDK | ✅ `~/Library/Android/sdk`, `compileSdk`/`targetSdk` 35 |
| JDK | ✅ OpenJDK 21.0.11 |
| Baseline `flutter analyze` | ✅ 0 errors, 66 pre-existing info warnings (`withOpacity` deprecations) |
| `test/` directory | ❌ does not exist — no tests in the repo today |
| Physical device | ❌ none connected |
| Sarvam API key | ❌ not provided |

---

## 11. Sources

- [Saaras model](https://docs.sarvam.ai/api/getting-started/models/saaras.md) ·
  [STT REST](https://docs.sarvam.ai/api/api-guides-tutorials/speech-to-text/rest-api.md) ·
  [STT streaming](https://docs.sarvam.ai/api/api-guides-tutorials/speech-to-text/streaming-api.md)
- [Translate](https://docs.sarvam.ai/api-reference/text/translate-text.md) ·
  [Transliterate](https://docs.sarvam.ai/api/api-guides-tutorials/text-processing/transliteration.md) ·
  [Language ID](https://docs.sarvam.ai/api-reference/text/identify-language.md)
- [TTS REST](https://docs.sarvam.ai/api/api-guides-tutorials/text-to-speech/rest-api.md) ·
  [Pronunciation dictionary](https://docs.sarvam.ai/api/api-guides-tutorials/text-to-speech/pronunciation-dictionary.md)
- [Chat completion](https://docs.sarvam.ai/api/api-guides-tutorials/chat-completion/overview.md) ·
  [Chat API reference](https://docs.sarvam.ai/api-reference/chat/chat-completions.md)
