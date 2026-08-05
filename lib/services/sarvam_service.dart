import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/sarvam_error.dart';
import 'storage_service.dart';

/// Output modes supported by `saaras:v3` on `/speech-to-text`.
///
/// `/speech-to-text-translate` is the legacy (`saaras:v2.5`) endpoint and is
/// deliberately not used here.
enum SaarasMode {
  transcribe,
  translate,
  verbatim,
  translit,
  codemix;

  String get wire => name;
}

/// Translation registers accepted by the `/translate` endpoint.
enum MayuraMode {
  formal,
  modernColloquial,
  classicColloquial,
  codeMixed;

  String get wire => switch (this) {
        MayuraMode.formal => 'formal',
        MayuraMode.modernColloquial => 'modern-colloquial',
        MayuraMode.classicColloquial => 'classic-colloquial',
        MayuraMode.codeMixed => 'code-mixed',
      };
}

class SttResult {
  const SttResult({
    required this.transcript,
    required this.languageCode,
    this.requestId,
  });

  final String transcript;
  final String languageCode;
  final String? requestId;

  factory SttResult.fromJson(Map<String, dynamic> json) {
    final transcript = json['transcript'];
    if (transcript is! String) {
      throw const SarvamException(
        SarvamErrorKind.malformedResponse,
        parentMessage: 'Bhasha could not read that. Please try again.',
        debugDetail: 'speech-to-text response missing string "transcript"',
      );
    }
    return SttResult(
      transcript: transcript,
      languageCode: json['language_code'] as String? ?? 'unknown',
      requestId: json['request_id'] as String?,
    );
  }
}

class TranslationResponse {
  const TranslationResponse({
    required this.translatedText,
    required this.sourceLanguageCode,
    this.requestId,
  });

  final String translatedText;
  final String sourceLanguageCode;
  final String? requestId;

  factory TranslationResponse.fromJson(Map<String, dynamic> json) {
    final text = json['translated_text'];
    if (text is! String) {
      throw const SarvamException(
        SarvamErrorKind.malformedResponse,
        parentMessage: 'Bhasha could not translate that. Please try again.',
        debugDetail: 'translate response missing string "translated_text"',
      );
    }
    return TranslationResponse(
      translatedText: text,
      sourceLanguageCode: json['source_language_code'] as String? ?? 'unknown',
      requestId: json['request_id'] as String?,
    );
  }
}

class TtsAudio {
  const TtsAudio({required this.wavBase64Chunks, this.requestId});

  /// Each entry is a complete base64-encoded WAV payload, in playback order.
  final List<String> wavBase64Chunks;
  final String? requestId;

  bool get isEmpty => wavBase64Chunks.isEmpty;

  factory TtsAudio.fromJson(Map<String, dynamic> json) {
    final audios = json['audios'];
    if (audios is! List || audios.isEmpty) {
      throw const SarvamException(
        SarvamErrorKind.malformedResponse,
        parentMessage: 'Bhasha could not speak that. Please try again.',
        debugDetail: 'text-to-speech response missing non-empty "audios"',
      );
    }
    return TtsAudio(
      wavBase64Chunks: audios.whereType<String>().toList(growable: false),
      requestId: json['request_id'] as String?,
    );
  }
}

class LanguageIdResult {
  const LanguageIdResult({
    required this.languageCode,
    required this.scriptCode,
    this.requestId,
  });

  /// e.g. `kn-IN`. Null when Sarvam could not identify the language.
  final String? languageCode;

  /// e.g. `Knda` for Kannada script, `Latn` for romanised input.
  final String? scriptCode;
  final String? requestId;

  bool get isRomanised => scriptCode?.toLowerCase() == 'latn';

  factory LanguageIdResult.fromJson(Map<String, dynamic> json) =>
      LanguageIdResult(
        languageCode: json['language_code'] as String?,
        scriptCode: json['script_code'] as String?,
        requestId: json['request_id'] as String?,
      );
}

class ChatMessage {
  const ChatMessage.system(this.content) : role = 'system';
  const ChatMessage.user(this.content) : role = 'user';
  const ChatMessage.assistant(this.content) : role = 'assistant';

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// Thin, typed client over the four Sarvam APIs this feature depends on.
///
/// Every method takes the API key from [keyProvider] so the key is never held
/// in a long-lived field, and never appears in logs or error detail.
class SarvamService {
  SarvamService({
    http.Client? client,
    required Future<String?> Function() keyProvider,
    this.timeout = const Duration(seconds: 30),
  })  : _client = client ?? http.Client(),
        _keyProvider = keyProvider;

  /// App-facing constructor. Reads the key from secure storage on every call
  /// so a key edited in settings takes effect without restarting anything.
  factory SarvamService.withStoredKey({http.Client? client}) => SarvamService(
        client: client,
        keyProvider: () => StorageService().getSarvamApiKey(),
      );

  /// Shared instance used by the overlay pipeline and screens.
  static final SarvamService shared = SarvamService.withStoredKey();

  static const String baseUrl = 'https://api.sarvam.ai';
  static const String sttPath = '/speech-to-text';
  static const String translatePath = '/translate';
  static const String transliteratePath = '/transliterate';
  static const String ttsPath = '/text-to-speech';
  static const String chatPath = '/v1/chat/completions';
  static const String languageIdPath = '/text-lid';

  static const String sttModel = 'saaras:v3';
  static const String translateModel = 'mayura:v1';
  static const String expandedTranslateModel = 'sarvam-translate:v1';
  static const String ttsModel = 'bulbul:v3';
  static const String chatModel = 'sarvam-105b';

  /// Documented request ceilings. Exceeding them is a client-side error, not a
  /// round trip we should waste.
  static const int maxTranslateChars = 1000;
  static const int maxTtsChars = 2500;
  static const int maxLanguageIdChars = 1000;
  static const Duration maxRestAudioDuration = Duration(seconds: 30);

  /// Mayura is retained for its colloquial output on the original 11-language
  /// set. Sarvam Translate covers all 22 scheduled Indian languages.
  static const Set<String> _mayuraLanguageCodes = {
    'bn-IN',
    'en-IN',
    'gu-IN',
    'hi-IN',
    'kn-IN',
    'ml-IN',
    'mr-IN',
    'od-IN',
    'pa-IN',
    'ta-IN',
    'te-IN',
  };

  final http.Client _client;
  final Future<String?> Function() _keyProvider;
  final Duration timeout;

  Future<Map<String, String>> _authHeaders({bool json = false}) async {
    final key = await _keyProvider();
    if (key == null || key.trim().isEmpty) {
      throw SarvamException.missingKey;
    }
    return {
      'api-subscription-key': key.trim(),
      if (json) 'Content-Type': 'application/json',
    };
  }

  /// Transcribes or directly translates recorded speech.
  ///
  /// The REST endpoint accepts at most 30 seconds of audio; callers must cap
  /// recording length rather than relying on the server to reject it.
  Future<SttResult> speechToText({
    required File audioFile,
    SaarasMode mode = SaarasMode.translate,
    String? languageCode,
  }) async {
    if (!await audioFile.exists()) {
      throw SarvamException.noSpeech;
    }
    final length = await audioFile.length();
    // A 16 kHz mono 16-bit WAV header alone is 44 bytes; anything this small
    // carries no speech.
    if (length < 2048) {
      throw SarvamException.noSpeech;
    }

    final headers = await _authHeaders();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$sttPath'))
      ..headers.addAll(headers)
      ..fields['model'] = sttModel
      ..fields['mode'] = mode.wire;
    if (languageCode != null) {
      request.fields['language_code'] = languageCode;
    }
    request.files.add(
      await http.MultipartFile.fromPath('file', audioFile.path),
    );

    final json = await _sendMultipart(request, 'speech-to-text');
    final result = SttResult.fromJson(json);
    if (result.transcript.trim().isEmpty) {
      throw SarvamException.noSpeech;
    }
    return result;
  }

  /// Translation through Mayura for its original language set, or Sarvam
  /// Translate whenever either side needs the expanded 22-language coverage.
  ///
  /// Input longer than [maxTranslateChars] is split on sentence boundaries and
  /// rejoined, because Mayura rejects oversized input outright.
  Future<String> translate({
    required String input,
    required String sourceLanguageCode,
    required String targetLanguageCode,
    MayuraMode mode = MayuraMode.modernColloquial,
  }) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    final useMayura = (sourceLanguageCode == 'auto' ||
            _mayuraLanguageCodes.contains(sourceLanguageCode)) &&
        _mayuraLanguageCodes.contains(targetLanguageCode);
    final model = useMayura ? translateModel : expandedTranslateModel;
    // Sarvam Translate currently supports formal mode only. Mayura keeps the
    // existing product default for conversational Kannada/English pairs.
    final requestMode = useMayura ? mode.wire : MayuraMode.formal.wire;

    final chunks = _splitForLimit(trimmed, maxTranslateChars);
    final out = <String>[];
    for (final chunk in chunks) {
      final json = await _postJson(
        translatePath,
        {
          'input': chunk,
          'source_language_code': sourceLanguageCode,
          'target_language_code': targetLanguageCode,
          'model': model,
          'mode': requestMode,
          // Keep 10:30 and Rs 500 readable as digits rather than Kannada
          // numerals, which parents read more slowly.
          'numerals_format': 'international',
        },
        'translate',
      );
      var translated = TranslationResponse.fromJson(json).translatedText;

      // Sarvam Translate supports Konkani but currently emits it in
      // Devanagari and does not accept output_script. Parents using the
      // Kannada -> Konkani pair expect Konkani written in Kannada script, so
      // preserve the translated pronunciation and convert only its script.
      if (sourceLanguageCode == 'kn-IN' && targetLanguageCode == 'kok-IN') {
        translated = await _konkaniInKannadaScript(translated);
      }
      out.add(translated);
    }
    return out.join(' ');
  }

  Future<String> _konkaniInKannadaScript(String devanagariKonkani) async {
    final json = await _postJson(
      transliteratePath,
      {
        'input': devanagariKonkani,
        // The transliteration API does not expose kok-IN. The translated text
        // is Devanagari, so hi-IN identifies its input script while kn-IN
        // selects Kannada as the output script.
        'source_language_code': 'hi-IN',
        'target_language_code': 'kn-IN',
        'numerals_format': 'international',
      },
      'transliterate-konkani-kannada',
    );
    final text = json['transliterated_text'];
    if (text is! String || text.trim().isEmpty) {
      throw const SarvamException(
        SarvamErrorKind.malformedResponse,
        parentMessage:
            'Bhasha could not write that in Kannada. Please try again.',
        debugDetail:
            'transliterate response missing string "transliterated_text"',
      );
    }
    return text.trim();
  }

  /// Kannada (or other Indic) speech synthesis via Bulbul.
  Future<TtsAudio> textToSpeech({
    required String text,
    required String targetLanguageCode,
    required String speaker,
    double pace = 1.0,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const SarvamException(
        SarvamErrorKind.invalidRequest,
        parentMessage: 'Nothing to read aloud.',
        debugDetail: 'empty tts text',
      );
    }

    final chunks = _splitForLimit(trimmed, maxTtsChars);
    final audio = <String>[];
    String? requestId;
    for (final chunk in chunks) {
      final json = await _postJson(
        ttsPath,
        {
          'text': chunk,
          'target_language_code': targetLanguageCode,
          'model': ttsModel,
          // Bulbul rejects 'Kavya' but accepts 'kavya': speaker ids are
          // lowercase on the wire even though we display them capitalised.
          'speaker': speaker.toLowerCase(),
          'pace': pace.clamp(0.5, 2.0),
        },
        'text-to-speech',
      );
      final part = TtsAudio.fromJson(json);
      audio.addAll(part.wavBase64Chunks);
      requestId ??= part.requestId;
    }
    return TtsAudio(wavBase64Chunks: audio, requestId: requestId);
  }

  /// Chat completion used for rewriting, correction resolution, and grounded
  /// follow-up answers.
  Future<String> chat({
    required List<ChatMessage> messages,
    double temperature = 0.2,
    int maxTokens = 512,
  }) async {
    final json = await _postJson(
      chatPath,
      {
        'model': chatModel,
        'messages': messages.map((m) => m.toJson()).toList(),
        'temperature': temperature,
        'max_tokens': maxTokens,
      },
      'chat-completions',
    );

    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const SarvamException(
        SarvamErrorKind.malformedResponse,
        parentMessage: 'Bhasha could not finish that. Please try again.',
        debugDetail: 'chat response missing non-empty "choices"',
      );
    }
    final content = (choices.first as Map?)?['message']?['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const SarvamException(
        SarvamErrorKind.malformedResponse,
        parentMessage: 'Bhasha could not finish that. Please try again.',
        debugDetail: 'chat response missing choices[0].message.content',
      );
    }
    return content.trim();
  }

  /// Identifies the language and script of [input].
  ///
  /// Replaces the previous prompt-based language guess: this returns a
  /// structured code plus the script, so romanised Kannada can be told apart
  /// from native-script Kannada.
  Future<LanguageIdResult> identifyLanguage(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const LanguageIdResult(languageCode: null, scriptCode: null);
    }
    final json = await _postJson(
      languageIdPath,
      {
        'input': trimmed.length > maxLanguageIdChars
            ? trimmed.substring(0, maxLanguageIdChars)
            : trimmed,
      },
      'text-lid',
    );
    return LanguageIdResult.fromJson(json);
  }

  /// Cheap round trip used by the settings screen to validate a pasted key.
  Future<bool> verifyKey() async {
    await translate(
      input: 'ok',
      sourceLanguageCode: 'en-IN',
      targetLanguageCode: 'kn-IN',
    );
    return true;
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
    String label,
  ) async {
    final headers = await _authHeaders(json: true);
    return _guard(label, () async {
      final response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(timeout);
      return _decode(response, label);
    });
  }

  Future<Map<String, dynamic>> _sendMultipart(
    http.MultipartRequest request,
    String label,
  ) async {
    return _guard(label, () async {
      final streamed = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      return _decode(response, label);
    });
  }

  Future<Map<String, dynamic>> _guard(
    String label,
    Future<Map<String, dynamic>> Function() action,
  ) async {
    try {
      return await action();
    } on SarvamException {
      rethrow;
    } on TimeoutException {
      _log('$label timed out after ${timeout.inSeconds}s');
      throw SarvamException.timeout;
    } on SocketException {
      _log('$label failed: no network');
      throw SarvamException.offline;
    } on http.ClientException catch (e) {
      _log('$label transport failure: ${e.message}');
      throw SarvamException.offline;
    }
  }

  Map<String, dynamic> _decode(http.Response response, String label) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Sarvam explains *why* a 4xx happened in the body. Without it a 400 is
      // undebuggable, so surface it - debug builds only, and truncated, since
      // an error body can echo the submitted text back.
      final reason = _describeError(response.body);
      _log('$label failed with HTTP ${response.statusCode}'
          '${reason.isEmpty ? '' : ': $reason'}');
      throw SarvamException.fromStatus(
        response.statusCode,
        debugDetail: '$label HTTP ${response.statusCode}'
            '${reason.isEmpty ? '' : ' - $reason'}',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw SarvamException(
        SarvamErrorKind.malformedResponse,
        parentMessage: 'Bhasha got an unexpected reply. Please try again.',
        debugDetail: '$label returned non-JSON body',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw SarvamException(
        SarvamErrorKind.malformedResponse,
        parentMessage: 'Bhasha got an unexpected reply. Please try again.',
        debugDetail: '$label returned ${decoded.runtimeType}, expected object',
      );
    }
    return decoded;
  }

  /// Splits on sentence boundaries first, then hard-wraps anything still over
  /// [limit]. Visible for testing.
  @visibleForTesting
  static List<String> splitForLimit(String text, int limit) =>
      _splitForLimit(text, limit);

  static List<String> _splitForLimit(String text, int limit) {
    if (text.length <= limit) return [text];

    final sentences = text.split(RegExp(r'(?<=[.!?।])\s+'));
    final chunks = <String>[];
    var current = StringBuffer();

    void flush() {
      if (current.isNotEmpty) {
        chunks.add(current.toString().trim());
        current = StringBuffer();
      }
    }

    for (final sentence in sentences) {
      if (sentence.length > limit) {
        flush();
        for (var i = 0; i < sentence.length; i += limit) {
          chunks.add(
            sentence.substring(i, (i + limit).clamp(0, sentence.length)),
          );
        }
        continue;
      }
      if (current.length + sentence.length + 1 > limit) {
        flush();
      }
      if (current.isNotEmpty) current.write(' ');
      current.write(sentence);
    }
    flush();
    return chunks.where((c) => c.isNotEmpty).toList(growable: false);
  }

  /// Pulls a short human-readable reason out of a Sarvam error body.
  ///
  /// Returns an empty string in release builds so error text never reaches
  /// production logs.
  @visibleForTesting
  static String describeError(String body) => _describeError(body);

  static String _describeError(String body) {
    if (!kDebugMode || body.isEmpty) return '';
    String reason = body;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        reason = switch (error) {
          Map() => (error['message'] ?? error['reason'] ?? error).toString(),
          String() => error,
          _ => (decoded['message'] ?? decoded['detail'] ?? body).toString(),
        };
      }
    } on FormatException {
      // Non-JSON body: fall through and use it verbatim.
    }
    reason = reason.replaceAll(RegExp(r'\s+'), ' ').trim();
    return reason.length > 300 ? '${reason.substring(0, 300)}...' : reason;
  }

  /// Debug-only. Never receives keys, audio, screenshots, or message text.
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[sarvam] $message');
    }
  }

  void dispose() => _client.close();
}
