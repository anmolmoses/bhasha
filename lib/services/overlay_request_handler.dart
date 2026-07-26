import 'package:flutter/services.dart';

import 'openai_service.dart';
import 'platform_service.dart';
import 'storage_service.dart';

class OverlayRequestHandler {
  static final OverlayRequestHandler _instance =
      OverlayRequestHandler._internal();
  factory OverlayRequestHandler() => _instance;
  OverlayRequestHandler._internal();

  final _platform = PlatformService();
  final _storage = StorageService();
  final _openai = OpenAIService();

  bool _initialized = false;

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
    final screenshotBase64 = (arguments['screenshotBase64'] ?? '').toString();

    if (action == null) {
      throw PlatformException(
        code: 'invalid_arguments',
        message: 'Action is required',
      );
    }

    await _ensureApiKey();

    switch (action) {
      case 'translate':
        if (text.trim().isEmpty) {
          throw PlatformException(
            code: 'invalid_arguments',
            message: 'Text is required',
          );
        }
        return _handleTranslate(text);
      case 'grammar':
        if (text.trim().isEmpty) {
          throw PlatformException(
            code: 'invalid_arguments',
            message: 'Text is required',
          );
        }
        return _handleGrammar(text);
      case 'x_replies':
        if (screenshotBase64.trim().isEmpty) {
          throw PlatformException(
            code: 'invalid_arguments',
            message: 'Screenshot is required for X replies',
          );
        }
        return _handleXReplies(screenshotBase64);
      default:
        throw PlatformException(
          code: 'unknown_action',
          message: 'Unsupported action: $action',
        );
    }
  }

  Future<Map<String, dynamic>> _handleTranslate(String text) async {
    String sourceLang = _storage.getSourceLanguage();
    final targetLang = _storage.getTargetLanguage();
    final autoDetect = _storage.getAutoDetect();

    if (autoDetect) {
      try {
        sourceLang = await _openai.detectLanguage(text);
      } catch (e) {
        // Fall back silently if detection fails; keep stored language.
      }
    }

    final result = await _openai.translate(
      text: text,
      sourceLang: sourceLang,
      targetLang: targetLang,
    );

    return {
      'action': 'translate',
      'success': true,
      'resultText': result.translatedText,
      'originalText': result.originalText,
      'sourceLang': result.sourceLang,
      'targetLang': result.targetLang,
    };
  }

  Future<Map<String, dynamic>> _handleGrammar(String text) async {
    final language = _storage.getTargetLanguage();
    final result = await _openai.checkGrammar(
      text: text,
      language: language,
    );

    return {
      'action': 'grammar',
      'success': true,
      'resultText': result.correctedText,
      'originalText': result.originalText,
      'language': result.language,
      'hasCorrections': result.hasCorrections,
    };
  }

  Future<Map<String, dynamic>> _handleXReplies(String screenshotBase64) async {
    final style = _storage.getXReplyStyle();
    final replies = await _openai.suggestXReplies(
      screenshotBase64: screenshotBase64,
      tone: style.tone,
      length: style.length,
      replyCount: style.replyCount,
      includeEmojis: style.includeEmojis,
      customInstructions: style.customInstructions,
    );

    return {
      'action': 'x_replies',
      'success': true,
      'replies': replies,
      'resultText': replies.join('\n'),
    };
  }

  Future<void> _ensureApiKey() async {
    if (_openai.hasValidApiKey) return;

    final apiKey = await _storage.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw PlatformException(
        code: 'missing_api_key',
        message: 'Add your API key in Bhasha settings before using overlay.',
      );
    }
    _openai.setApiKey(apiKey);
  }
}
