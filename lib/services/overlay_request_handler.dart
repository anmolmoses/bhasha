import 'package:flutter/services.dart';

import '../constants/languages.dart';
import '../models/sarvam_error.dart';
import 'platform_service.dart';
import 'sarvam_service.dart';
import 'storage_service.dart';

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
  SarvamService _sarvam = SarvamService.shared;

  bool _initialized = false;

  /// Test seam: swaps in a client backed by a mock transport.
  void overrideServiceForTesting(SarvamService service) {
    _sarvam = service;
  }

  void init() {
    if (_initialized) return;
    _platform.registerMethodHandler(
      'processOverlayAction',
      _handleProcessOverlayAction,
    );
    _initialized = true;
  }

  Future<dynamic> _handleProcessOverlayAction(MethodCall call) async {
    final arguments = Map<String, dynamic>.from(call.arguments as Map);
    final action = arguments['action']?.toString();
    final text = (arguments['text'] ?? '').toString();

    if (action == null) {
      throw PlatformException(
        code: 'invalid_arguments',
        message: 'Action is required',
      );
    }

    await _ensureApiKey();

    try {
      switch (action) {
        case 'translate':
          _requireText(text);
          return await _handleTranslate(text);
        case 'grammar':
          _requireText(text);
          return await _handleGrammar(text);
        default:
          throw PlatformException(
            code: 'unknown_action',
            message: 'Unsupported action: $action',
          );
      }
    } on SarvamException catch (e) {
      // Surface the parent-facing message, never the raw detail.
      throw PlatformException(code: e.kind.name, message: e.parentMessage);
    }
  }

  void _requireText(String text) {
    if (text.trim().isEmpty) {
      throw PlatformException(
        code: 'invalid_arguments',
        message: 'Tap in a text field with some text first.',
      );
    }
  }

  Future<Map<String, dynamic>> _handleTranslate(String text) async {
    final sourceName = _storage.getSourceLanguage();
    final targetName = _storage.getTargetLanguage();
    final autoDetect = _storage.getAutoDetect();

    final targetCode = Languages.codeFor(targetName);
    if (targetCode == null) {
      throw PlatformException(
        code: 'unsupported_language',
        message:
            '$targetName is not supported. Pick another language in Settings.',
      );
    }

    var sourceCode = Languages.codeFor(sourceName);
    if (autoDetect) {
      try {
        final detected = await _sarvam.identifyLanguage(text);
        if (detected.languageCode != null) {
          sourceCode = detected.languageCode;
        }
      } on SarvamException {
        // Detection is best-effort; fall back to the saved language rather
        // than failing the whole translation.
      }
    }

    // Mayura accepts `auto`, which is a better default than guessing wrong.
    final resolvedSource = sourceCode ?? 'auto';

    final translated = await _sarvam.translate(
      input: text,
      sourceLanguageCode: resolvedSource,
      targetLanguageCode: targetCode,
    );

    return {
      'action': 'translate',
      'success': true,
      'resultText': translated,
      'originalText': text,
      'sourceLang': resolvedSource,
      'targetLang': targetCode,
    };
  }

  Future<Map<String, dynamic>> _handleGrammar(String text) async {
    final language = _storage.getTargetLanguage();

    final corrected = await _sarvam.chat(
      messages: [
        ChatMessage.system(
          'You correct grammar, spelling, and punctuation in $language text.\n'
          'Return ONLY the corrected text. No explanations, no quotes, no '
          'commentary. If the text is already correct, return it unchanged.\n'
          'Never change names, numbers, dates, times, or amounts.',
        ),
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

  Future<void> _ensureApiKey() async {
    if (await _storage.hasSarvamApiKey()) return;
    throw PlatformException(
      code: 'missing_api_key',
      message:
          'Add your Sarvam API key in Bhasha settings before using the bubble.',
    );
  }
}
