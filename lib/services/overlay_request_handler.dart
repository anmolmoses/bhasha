import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../constants/languages.dart';
import '../l10n/parent_strings.dart';
import '../models/conversation_context.dart';
import '../models/sarvam_error.dart';
import '../models/screen_ocr_error.dart';
import '../models/screen_text_block.dart';
import 'parent_profile_service.dart';
import 'platform_service.dart';
import 'sarvam_service.dart';
import 'sarvam_vision_service.dart';
import 'storage_service.dart';
import 'tts_player.dart';

/// Handles bubble actions coming from the native overlay.
///
/// Every request is served by Sarvam. There is no fallback provider: if the
/// Sarvam key is missing or rejected, the action fails with a message telling
/// the parent what to fix.
class OverlayRequestHandler {
  static final OverlayRequestHandler _instance =
      OverlayRequestHandler._internal();
  factory OverlayRequestHandler() => _instance;
  OverlayRequestHandler._internal();

  final _platform = PlatformService();
  final _storage = StorageService();
  final _profileService = ParentProfileService();

  /// Short tail of hold-to-speak turns. In-memory only, so message contents
  /// never touch disk; used to keep names and facts consistent between what
  /// the parent dictated and what grammar correction later rewrites.
  final ConversationContext _context = ConversationContext();

  SarvamService _sarvam = SarvamService.shared;
  SarvamVisionService _vision = SarvamVisionService();

  Future<void> Function(String text, String languageCode)? _speakOverride;

  bool _initialized = false;

  /// Test seam: swaps in a client backed by a mock transport.
  void overrideServiceForTesting(SarvamService service) {
    _sarvam = service;
  }

  /// Test seam for the OCR-only Sarvam Vision client.
  void overrideVisionServiceForTesting(SarvamVisionService service) {
    _vision = service;
  }

  /// Test seam: replaces (or with null, restores) the Bulbul playback path.
  void overrideSpeakForTesting(
    Future<void> Function(String text, String languageCode)? speak,
  ) {
    _speakOverride = speak;
  }

  void init() {
    if (_initialized) return;
    _platform.registerMethodHandler(
      'processOverlayAction',
      handleProcessOverlayAction,
    );
    _initialized = true;
  }

  @visibleForTesting
  Future<dynamic> handleProcessOverlayAction(MethodCall call) async {
    final arguments = Map<String, dynamic>.from(call.arguments as Map);
    final action = arguments['action']?.toString();
    final text = (arguments['text'] ?? '').toString();
    final audioPath = arguments['audioPath']?.toString();
    final imageBase64 = (arguments['imageBase64'] ?? '').toString();
    final sourcePackage = arguments['sourcePackage']?.toString();

    if (action == null) {
      throw PlatformException(
        code: 'invalid_arguments',
        message: 'Action is required',
      );
    }

    await _adoptOverlayLanguageChoice(arguments);
    await _ensureApiKey();

    try {
      switch (action) {
        case 'translate':
          _requireText(text);
          return await _handleTranslate(text, action: action);
        case 'translate_message':
          _requireText(text);
          if (sourcePackage == null ||
              sourcePackage.isEmpty ||
              sourcePackage == 'com.yourapp.bhasha' ||
              sourcePackage == 'android' ||
              sourcePackage == 'com.android.systemui' ||
              sourcePackage == 'com.android.settings') {
            throw PlatformException(
              code: 'unsupported_source',
              message: 'That app cannot be used for contextual translation.',
            );
          }
          return await _handleTranslate(
            text,
            action: action,
            sourcePackage: sourcePackage,
          );
        case 'translate_screen_blocks':
          final rawBlocks = arguments['blocks'];
          if (rawBlocks is! List || rawBlocks.isEmpty) {
            throw PlatformException(
              code: 'no_screen_text',
              message: 'No readable text was found on this screen.',
            );
          }
          return await _handleScreenBlocks(rawBlocks);
        case 'screen_translate':
          if (imageBase64.trim().isEmpty) {
            throw PlatformException(
              code: 'invalid_capture',
              message: 'The screen capture was empty. Please try again.',
            );
          }
          return await _handleScreenTranslate(imageBase64);
        case 'grammar':
          _requireText(text);
          return await _handleGrammar(text);
        case 'voice_translate':
          return await _handleVoiceTranslate(audioPath);
        default:
          throw PlatformException(
            code: 'unknown_action',
            message: 'Unsupported action: $action',
          );
      }
    } on SarvamException catch (e) {
      // Surface the parent-facing message - in the parent's language - never
      // the raw detail.
      throw PlatformException(
        code: e.kind.name,
        message: ParentStrings.localize(e.parentMessage),
      );
    } on ScreenOcrException catch (e) {
      throw PlatformException(
        code: e.kind.name,
        message: ParentStrings.localize(e.parentMessage),
      );
    }
  }

  void _requireText(String text) {
    if (text.trim().isEmpty) {
      throw PlatformException(
        code: 'invalid_arguments',
        message:
            ParentStrings.localize('Tap in a text field with some text first.'),
      );
    }
  }

  /// Takes on the language the parent picked from the bubble's chip.
  ///
  /// The bubble owns that choice while they are inside another app, and sends
  /// it with every request. Writing it back here keeps the in-app Settings
  /// screen showing what the bubble is actually using, so the two surfaces
  /// never disagree.
  Future<void> _adoptOverlayLanguageChoice(
    Map<String, dynamic> arguments,
  ) async {
    final source = arguments['sourceLanguage']?.toString();
    if (source != null &&
        Languages.isSupported(source) &&
        source != _storage.getSourceLanguage()) {
      await _storage.saveSourceLanguage(source);
    }

    final target = arguments['targetLanguage']?.toString();
    if (target != null &&
        Languages.isSupported(target) &&
        target != _storage.getTargetLanguage()) {
      await _storage.saveTargetLanguage(target);
    }

    final autoFlip = arguments['autoFlip'];
    if (autoFlip is bool && autoFlip != _storage.getAutoFlip()) {
      await _storage.saveAutoFlip(autoFlip);
    }
  }

  /// The parent's two working languages.
  ///
  /// With auto-flip on the pair has no fixed direction: whichever side the text
  /// is *not* in is the side it goes to. That is what stops a parent leaving
  /// WhatsApp to reverse the direction between one message and the next.
  LanguagePair _languagePair() {
    final targetName = _storage.getTargetLanguage();
    final targetCode = Languages.codeFor(targetName);
    if (targetCode == null) {
      throw PlatformException(
        code: 'unsupported_language',
        message:
            '$targetName is not supported. Pick another language in Settings.',
      );
    }
    final sourceCode =
        Languages.codeFor(_storage.getSourceLanguage()) ??
        Languages.defaultSourceCode;

    return LanguagePair(
      sourceCode: sourceCode,
      targetCode: targetCode,
      // A pair of one language has no other side to flip to.
      autoFlip:
          _storage.getAutoFlip() &&
          !Languages.sameLanguage(sourceCode, targetCode),
    );
  }

  /// Best-effort language identification. Returns null rather than failing the
  /// whole action, so a detection outage degrades to the saved direction.
  Future<String?> _detectLanguage(String text) async {
    try {
      final detected = await _sarvam.identifyLanguage(text);
      return detected.languageCode;
    } on SarvamException {
      return null;
    }
  }

  Future<Map<String, dynamic>> _handleTranslate(
    String text, {
    required String action,
    String? sourcePackage,
  }) async {
    final pair = _languagePair();
    final autoDetect = _storage.getAutoDetect();

    // Auto-flip has to know what it is looking at, so it detects even when the
    // parent left auto-detect off.
    final detected = (pair.autoFlip || autoDetect)
        ? await _detectLanguage(text)
        : null;

    final sourceCode =
        detected ?? Languages.codeFor(_storage.getSourceLanguage());
    // Mayura accepts `auto`, which is a better default than guessing wrong.
    final resolvedSource = sourceCode ?? 'auto';
    final targetCode = pair.resolveTarget(detected);

    final translated = await _sarvam.translate(
      input: text,
      sourceLanguageCode: resolvedSource,
      targetLanguageCode: targetCode,
    );

    _maybeSpeak(translated, targetCode);

    return {
      'action': action,
      'success': true,
      'resultText': translated,
      'originalText': text,
      'sourceLang': resolvedSource,
      'targetLang': targetCode,
      if (sourcePackage != null) 'sourcePackage': sourcePackage,
    };
  }

  /// Hold-to-speak: recorded audio in, a message in the parent's chosen
  /// language out.
  ///
  /// The spoken language is never asked for. Saaras returns the language it
  /// heard, so the parent can speak English or Kannada into the same button and
  /// still get the target language they picked in Settings.
  Future<Map<String, dynamic>> _handleVoiceTranslate(String? audioPath) async {
    if (audioPath == null || audioPath.trim().isEmpty) {
      throw PlatformException(
        code: 'invalid_arguments',
        message: ParentStrings.localize(
          'No recording was captured. Hold the button and speak.',
        ),
      );
    }

    final pair = _languagePair();

    // `transcribe` keeps the words in the language they were spoken in.
    // `translate` would force everything to English, which is wrong the moment
    // the parent picks any other target language.
    final heard = await _sarvam.speechToText(
      audioFile: File(audioPath),
      mode: SaarasMode.transcribe,
    );
    final spoken = heard.transcript.trim();
    final sourceCode = _resolveSpokenLanguage(heard.languageCode);

    // Saaras already told us what was spoken, so auto-flip costs nothing here:
    // speak English and get Kannada, speak Kannada and get English, from the
    // same button and without touching a setting.
    final targetCode = pair.resolveTarget(sourceCode);

    // Already in the target language: don't pay for a round trip that would
    // only paraphrase what they said.
    if (sourceCode == targetCode) {
      _rememberTurn(spoken, spoken);
      _maybeSpeak(spoken, targetCode);
      return {
        'action': 'voice_translate',
        'success': true,
        'resultText': spoken,
        'transcript': spoken,
        'sourceLang': sourceCode,
        'targetLang': targetCode,
        'translated': false,
      };
    }

    final translated = await _sarvam.translate(
      input: spoken,
      sourceLanguageCode: sourceCode,
      targetLanguageCode: targetCode,
    );

    _rememberTurn(spoken, translated);
    _maybeSpeak(translated, targetCode);

    return {
      'action': 'voice_translate',
      'success': true,
      'resultText': translated,
      'transcript': spoken,
      'sourceLang': sourceCode,
      'targetLang': targetCode,
      'translated': true,
    };
  }

  /// Maps what Saaras reports back onto a code Mayura accepts.
  ///
  /// Saaras can return `unknown`, or a language Mayura does not take. Sending
  /// `auto` in those cases is better than sending a code that 400s.
  String _resolveSpokenLanguage(String reported) {
    final code = reported.trim();
    if (code.isEmpty || code.toLowerCase() == 'unknown') return 'auto';
    final known = Languages.all.any(
      (language) => language.code.toLowerCase() == code.toLowerCase(),
    );
    return known ? code : 'auto';
  }

  Future<Map<String, dynamic>> _handleGrammar(String text) async {
    // Grammar has no direction to flip, but it does have a language, and
    // assuming the target one is wrong the moment a parent writes in the other
    // half of their pair. Read what they actually typed instead.
    var language = _storage.getTargetLanguage();
    if (_storage.getAutoFlip()) {
      final detected = await _detectLanguage(text);
      if (detected != null) language = Languages.nameFor(detected);
    }
    final profile = _profileService.profile;

    final systemPrompt = StringBuffer()
      ..writeln(
        'You correct grammar, spelling, and punctuation in $language text.',
      )
      ..writeln(
        'Return ONLY the corrected text. No explanations, no quotes, no '
        'commentary. If the text is already correct, return it unchanged.',
      )
      ..writeln('Never change names, numbers, dates, times, or amounts.')
      ..writeln(profile.tone.promptHint);

    final glossary = profile.glossaryPromptBlock;
    if (glossary.isNotEmpty) {
      systemPrompt
        ..writeln()
        ..writeln(glossary);
    }

    final dictated = _recentDictationBlock();
    if (dictated.isNotEmpty) {
      systemPrompt
        ..writeln()
        ..writeln(dictated);
    }

    final corrected = await _sarvam.chat(
      messages: [
        ChatMessage.system(systemPrompt.toString().trim()),
        ChatMessage.user(text),
      ],
      temperature: 0.0,
    );

    return {
      'action': 'grammar',
      'success': true,
      'resultText': corrected,
      'originalText': text,
      'language': language,
      'hasCorrections': corrected.trim() != text.trim(),
    };
  }

  /// Translates blocks the accessibility tree already resolved, so no OCR runs.
  Future<Map<String, dynamic>> _handleScreenBlocks(
    List<dynamic> rawBlocks,
  ) async {
    final blocks = <ScreenTextBlock>[];
    final seen = <String>{};
    for (final raw in rawBlocks.whereType<Map>()) {
      final text = SarvamVisionService.cleanBlockText(
        (raw['text'] ?? '').toString(),
      );
      if (text.isEmpty || SarvamVisionService.isNoise(text)) continue;
      if (!seen.add(text.toLowerCase())) continue;

      double at(String key) => (raw[key] as num?)?.toDouble() ?? 0;
      final width = at('width');
      final height = at('height');
      if (width <= 0 || height <= 0) continue;

      blocks.add(
        ScreenTextBlock(
          text: text,
          x: at('x').clamp(0, 1000).toDouble(),
          y: at('y').clamp(0, 1000).toDouble(),
          width: width.clamp(0, 1000).toDouble(),
          height: height.clamp(0, 1000).toDouble(),
        ),
      );
      if (blocks.length >= SarvamVisionService.maxBlocks) break;
    }

    if (blocks.isEmpty) {
      throw PlatformException(
        code: 'no_screen_text',
        message: 'No readable text was found on this screen.',
      );
    }
    return _translateBlocks(blocks);
  }

  Future<Map<String, dynamic>> _handleScreenTranslate(
    String imageBase64,
  ) async {
    final sourceName = _storage.getSourceLanguage();
    final targetName = _storage.getTargetLanguage();
    if (Languages.codeFor(targetName) == null) {
      throw PlatformException(
        code: 'unsupported_language',
        message:
            '$targetName is not supported. Pick another language in Settings.',
      );
    }

    // Sarvam Vision needs a concrete script to decode, so it always gets the
    // saved source language even when auto-detect is on.
    final ocrLanguage =
        Languages.codeFor(sourceName) ?? Languages.defaultSourceCode;

    final blocks = await _vision.recognizeScreen(
      imageBase64,
      languageCode: ocrLanguage,
    );
    if (blocks.isEmpty) {
      // Sarvam Vision reads a screen with a photo background (a WhatsApp chat
      // wallpaper, for example) as one picture region and captions it instead
      // of transcribing it, which leaves nothing to overlay.
      throw PlatformException(
        code: 'no_screen_text',
        message: 'Sarvam Vision could not separate text on this screen. It '
            'works best on screens with a plain background.',
      );
    }
    return _translateBlocks(blocks);
  }

  /// Translates every block and returns the payload the overlay draws.
  Future<Map<String, dynamic>> _translateBlocks(
    List<ScreenTextBlock> blocks,
  ) async {
    final sourceName = _storage.getSourceLanguage();
    final targetName = _storage.getTargetLanguage();
    final targetCode = Languages.codeFor(targetName);
    if (targetCode == null) {
      throw PlatformException(
        code: 'unsupported_language',
        message:
            '$targetName is not supported. Pick another language in Settings.',
      );
    }
    final sourceCode = _storage.getAutoDetect()
        ? 'auto'
        : (Languages.codeFor(sourceName) ?? Languages.defaultSourceCode);

    final translated = <Map<String, dynamic>>[];
    const parallelRequests = 4;
    for (var start = 0; start < blocks.length; start += parallelRequests) {
      final batch = blocks.skip(start).take(parallelRequests).toList();
      final results = await Future.wait(
        batch.map(
          (block) => _translateScreenBlock(
            block,
            sourceCode: sourceCode,
            targetCode: targetCode,
          ),
        ),
      );
      translated.addAll(results);
    }

    return {
      'action': 'screen_translate',
      'success': true,
      'sourceLang': sourceCode,
      'targetLang': targetCode,
      'blocks': translated,
    };
  }

  Future<Map<String, dynamic>> _translateScreenBlock(
    ScreenTextBlock block, {
    required String sourceCode,
    required String targetCode,
  }) async {
    final translated = await _sarvam.translate(
      input: block.text,
      sourceLanguageCode: sourceCode,
      targetLanguageCode: targetCode,
    );
    return block.toJson(
      translatedText: _matchSourcePunctuation(block.text, translated),
    );
  }

  /// Drops the sentence-ending period Mayura adds to short UI labels, so a
  /// button reading "Search" is not overlaid as "Search.".
  @visibleForTesting
  static String matchSourcePunctuation(String source, String translated) =>
      _matchSourcePunctuation(source, translated);

  static String _matchSourcePunctuation(String source, String translated) {
    final trimmed = translated.trim();
    if (!trimmed.endsWith('.')) return trimmed;
    if (RegExp(r'[.!?।]$').hasMatch(source.trim())) return trimmed;
    return trimmed.substring(0, trimmed.length - 1).trimRight();
  }

  /// Recent hold-to-speak turns, rendered so grammar correction keeps the
  /// spellings and facts the parent already dictated.
  String _recentDictationBlock() {
    final turns = _context.turns;
    if (turns.isEmpty) return '';
    final buffer = StringBuffer()
      ..writeln('The parent recently dictated (keep these spellings and facts '
          'exactly when they appear):');
    for (final turn in turns) {
      buffer.writeln('- Said: "${turn.question}" -> written: "${turn.answer}"');
    }
    return buffer.toString().trim();
  }

  void _rememberTurn(String transcript, String written) {
    if (transcript.trim().isEmpty) return;
    _context.addTurn(ContextTurn(question: transcript, answer: written));
  }

  /// Reads the result aloud with the parent's saved Bulbul voice.
  ///
  /// Fire-and-forget on purpose: the text is already in the composer, so a
  /// playback problem must never surface as a failed action.
  void _maybeSpeak(String text, String languageCode) {
    if (text.trim().isEmpty) return;
    if (!_storage.getSpeakAloud()) return;
    final speak = _speakOverride ?? _speak;
    unawaited(speak(text, languageCode));
  }

  Future<void> _speak(String text, String languageCode) async {
    try {
      final profile = _profileService.profile;
      final audio = await _sarvam.textToSpeech(
        text: text,
        targetLanguageCode: languageCode,
        speaker: profile.voiceSpeaker,
        pace: profile.pace,
      );
      await TtsPlayer().play(audio);
    } catch (_) {
      // Best-effort by design; see _maybeSpeak.
    }
  }

  Future<void> _ensureApiKey() async {
    if (await _storage.hasSarvamApiKey()) return;
    throw PlatformException(
      code: 'missing_api_key',
      message: ParentStrings.localize(
        'Add your Sarvam API key in Bhasha settings before using the bubble.',
      ),
    );
  }
}

/// The two languages the parent works between, and whether the direction is
/// fixed or resolved per message.
@visibleForTesting
class LanguagePair {
  const LanguagePair({
    required this.sourceCode,
    required this.targetCode,
    required this.autoFlip,
  });

  final String sourceCode;
  final String targetCode;
  final bool autoFlip;

  /// Which side [detectedCode] should be translated into.
  ///
  /// Text already in the target language goes back to the other side. Anything
  /// outside the pair — a Hindi message in a Kannada/English pair — still goes
  /// to the target, because that is the language the parent reads.
  String resolveTarget(String? detectedCode) {
    if (!autoFlip || detectedCode == null) return targetCode;
    return Languages.sameLanguage(detectedCode, targetCode)
        ? sourceCode
        : targetCode;
  }
}
