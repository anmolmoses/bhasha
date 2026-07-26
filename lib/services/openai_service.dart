import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/grammar_result.dart';
import '../models/translation_result.dart';

class OpenAIService {
  static final OpenAIService _instance = OpenAIService._internal();
  factory OpenAIService() => _instance;
  OpenAIService._internal();

  // Using the new Responses API (recommended for new projects)
  static const String _baseUrl = 'https://api.openai.com/v1/responses';

  // GPT-5-mini - OpenAI's latest efficient model with excellent multilingual capabilities
  static const String _model = 'gpt-5-mini-2025-08-07';

  String? _apiKey;

  bool get hasValidApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  /// Sends a request to OpenAI's Responses API
  Future<String> _sendRequest({
    required String systemPrompt,
    required String userMessage,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('API key not set');
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'instructions': systemPrompt,
          'input': userMessage,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Extract text from the response output
        final output = data['output'] as List?;
        if (output != null && output.isNotEmpty) {
          final message = output.firstWhere(
            (item) => item['type'] == 'message',
            orElse: () => null,
          );
          if (message != null) {
            final content = message['content'] as List?;
            if (content != null && content.isNotEmpty) {
              final textContent = content.firstWhere(
                (item) => item['type'] == 'output_text',
                orElse: () => null,
              );
              if (textContent != null) {
                return textContent['text'].toString().trim();
              }
            }
          }
        }
        throw Exception('Unexpected response format');
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
        throw Exception('OpenAI API Error: $errorMessage');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Request failed: $e');
    }
  }

  /// Fallback to Chat Completions API if Responses API fails
  Future<String> _sendChatCompletionRequest({
    required String systemPrompt,
    required String userMessage,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('API key not set');
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userMessage},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
        throw Exception('OpenAI API Error: $errorMessage');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Request failed: $e');
    }
  }

  Future<TranslationResult> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    if (text.trim().isEmpty) {
      throw Exception('Text cannot be empty');
    }

    final systemPrompt = '''You are a professional translation assistant.
Translate the following text from $sourceLang to $targetLang.
Only return the translated text without any explanations, notes, or additional commentary.
Maintain the tone and style of the original text.''';

    try {
      // Try Responses API first, fallback to Chat Completions
      String translatedText;
      try {
        translatedText = await _sendRequest(
          systemPrompt: systemPrompt,
          userMessage: text,
        );
      } catch (e) {
        // Fallback to Chat Completions API
        translatedText = await _sendChatCompletionRequest(
          systemPrompt: systemPrompt,
          userMessage: text,
        );
      }

      return TranslationResult(
        originalText: text,
        translatedText: translatedText,
        sourceLang: sourceLang,
        targetLang: targetLang,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to translate: $e');
    }
  }

  Future<GrammarResult> checkGrammar({
    required String text,
    required String language,
  }) async {
    if (text.trim().isEmpty) {
      throw Exception('Text cannot be empty');
    }

    final systemPrompt =
        '''You are a professional grammar and spelling checker for $language text.
Analyze the following text and correct any grammar, spelling, or punctuation errors.
Return ONLY the corrected text without any explanations, notes, or additional commentary.
If the text has no errors, return it as is.''';

    try {
      // Try Responses API first, fallback to Chat Completions
      String correctedText;
      try {
        correctedText = await _sendRequest(
          systemPrompt: systemPrompt,
          userMessage: text,
        );
      } catch (e) {
        // Fallback to Chat Completions API
        correctedText = await _sendChatCompletionRequest(
          systemPrompt: systemPrompt,
          userMessage: text,
        );
      }

      // Identify corrections (simplified - just checks if text changed)
      final corrections = <String>[];
      if (correctedText != text) {
        corrections.add('Text has been corrected');
      }

      return GrammarResult(
        originalText: text,
        correctedText: correctedText,
        language: language,
        corrections: corrections,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to check grammar: $e');
    }
  }

  Future<List<String>> suggestXReplies({
    required String screenshotBase64,
    required String tone,
    required String length,
    required int replyCount,
    required bool includeEmojis,
    required String customInstructions,
  }) async {
    if (screenshotBase64.trim().isEmpty) {
      throw Exception('Screenshot cannot be empty');
    }

    final safeReplyCount = replyCount.clamp(1, 6);
    final emojiInstruction = includeEmojis
        ? 'Use emojis only when they feel natural.'
        : 'Do not use emojis.';
    final customStyle = customInstructions.trim().isEmpty
        ? 'No extra style instructions.'
        : customInstructions.trim();

    final systemPrompt = '''You write useful replies for posts on X.
Read the screenshot and infer the main post the user is likely viewing.
Create $safeReplyCount reply options.
Style:
- Tone: $tone
- Length: $length
- $emojiInstruction
- Custom instructions: $customStyle

Rules:
- Return only a JSON array of strings.
- Each reply must be paste-ready.
- Do not include numbering, explanations, hashtags unless requested, or quotation marks inside the replies unless they are needed.''';

    try {
      final rawText = await _sendVisionRequest(
        systemPrompt: systemPrompt,
        screenshotBase64: screenshotBase64,
      );
      return _parseReplyList(rawText).take(safeReplyCount).toList();
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to suggest replies: $e');
    }
  }

  Future<String> _sendVisionRequest({
    required String systemPrompt,
    required String screenshotBase64,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('API key not set');
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'instructions': systemPrompt,
          'input': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'input_text',
                  'text':
                      'Suggest replies for the X post visible in this screenshot.',
                },
                {
                  'type': 'input_image',
                  'image_url': 'data:image/png;base64,$screenshotBase64',
                },
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final output = data['output'] as List?;
        if (output != null && output.isNotEmpty) {
          for (final item in output) {
            if (item is! Map || item['type'] != 'message') continue;
            final content = item['content'] as List?;
            if (content == null) continue;
            for (final contentItem in content) {
              if (contentItem is Map && contentItem['type'] == 'output_text') {
                return contentItem['text'].toString().trim();
              }
            }
          }
        }
        throw Exception('Unexpected response format');
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
        throw Exception('OpenAI API Error: $errorMessage');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Request failed: $e');
    }
  }

  List<String> _parseReplyList(String rawText) {
    final trimmed = rawText.trim();
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded
            .map((item) => item.toString().trim())
            .where((reply) => reply.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // Fall through to line parsing for imperfect model output.
    }

    return trimmed
        .split('\n')
        .map((line) => line
            .replaceFirst(RegExp(r'^\s*[-*\d.)]+\s*'), '')
            .trim()
            .replaceAll(RegExp(r'^"|"$'), ''))
        .where((reply) => reply.isNotEmpty)
        .toList();
  }

  // Detect language (optional feature)
  Future<String> detectLanguage(String text) async {
    final systemPrompt =
        'Detect the language of the following text. Return only the language name in English, nothing else.';

    try {
      try {
        return await _sendRequest(
          systemPrompt: systemPrompt,
          userMessage: text,
        );
      } catch (e) {
        // Fallback to Chat Completions API
        return await _sendChatCompletionRequest(
          systemPrompt: systemPrompt,
          userMessage: text,
        );
      }
    } catch (e) {
      throw Exception('Failed to detect language: $e');
    }
  }
}
