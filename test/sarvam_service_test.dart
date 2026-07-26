import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bhasha/constants/languages.dart';
import 'package:bhasha/models/sarvam_error.dart';
import 'package:bhasha/services/sarvam_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Builds a service whose transport is a canned response, so no test ever
/// touches the live (paid) API.
SarvamService serviceReturning(
  String body, {
  int status = 200,
  String? key = 'test-key',
  void Function(http.Request request)? onRequest,
}) {
  final client = MockClient((request) async {
    onRequest?.call(request);
    return http.Response(body, status, headers: {
      'content-type': 'application/json',
    });
  });
  return SarvamService(client: client, keyProvider: () async => key);
}

void main() {
  group('endpoint configuration', () {
    test('uses the documented base URL and paths', () {
      expect(SarvamService.baseUrl, 'https://api.sarvam.ai');
      expect(SarvamService.sttPath, '/speech-to-text');
      expect(SarvamService.translatePath, '/translate');
      expect(SarvamService.ttsPath, '/text-to-speech');
      expect(SarvamService.chatPath, '/v1/chat/completions');
      expect(SarvamService.languageIdPath, '/text-lid');
    });

    test('pins the documented model identifiers', () {
      expect(SarvamService.sttModel, 'saaras:v3');
      expect(SarvamService.translateModel, 'mayura:v1');
      expect(SarvamService.ttsModel, 'bulbul:v3');
    });

    test('sends the api-subscription-key header, never a bearer token',
        () async {
      late http.Request captured;
      final service = serviceReturning(
        jsonEncode({'translated_text': 'ok', 'source_language_code': 'en-IN'}),
        onRequest: (r) => captured = r,
      );

      await service.translate(
        input: 'hello',
        sourceLanguageCode: 'en-IN',
        targetLanguageCode: 'kn-IN',
      );

      expect(captured.headers['api-subscription-key'], 'test-key');
      expect(captured.headers.containsKey('Authorization'), isFalse);
    });

    test('translate sends colloquial mode and international numerals',
        () async {
      late http.Request captured;
      final service = serviceReturning(
        jsonEncode({'translated_text': 'ok', 'source_language_code': 'en-IN'}),
        onRequest: (r) => captured = r,
      );

      await service.translate(
        input: 'meet at 10:30',
        sourceLanguageCode: 'en-IN',
        targetLanguageCode: 'kn-IN',
      );

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['mode'], 'modern-colloquial');
      expect(body['numerals_format'], 'international');
      expect(body['model'], 'mayura:v1');
    });
  });

  group('response parsing', () {
    test('parses a speech-to-text transcript', () {
      final result = SttResult.fromJson({
        'request_id': 'abc',
        'transcript': 'I will come on Wednesday',
        'language_code': 'kn-IN',
      });
      expect(result.transcript, 'I will come on Wednesday');
      expect(result.languageCode, 'kn-IN');
    });

    test('throws malformedResponse when transcript is missing', () {
      expect(
        () => SttResult.fromJson({'request_id': 'abc'}),
        throwsA(isA<SarvamException>().having(
          (e) => e.kind,
          'kind',
          SarvamErrorKind.malformedResponse,
        )),
      );
    });

    test('parses text-to-speech base64 audio array', () {
      final audio = TtsAudio.fromJson({
        'request_id': 'abc',
        'audios': ['UklGRg==', 'UklGRh=='],
      });
      expect(audio.wavBase64Chunks, hasLength(2));
      expect(audio.isEmpty, isFalse);
    });

    test('throws when audios is empty', () {
      expect(
        () => TtsAudio.fromJson({'audios': <String>[]}),
        throwsA(isA<SarvamException>().having(
          (e) => e.kind,
          'kind',
          SarvamErrorKind.malformedResponse,
        )),
      );
    });

    test('parses language identification including script', () {
      final result = LanguageIdResult.fromJson({
        'language_code': 'kn-IN',
        'script_code': 'Latn',
      });
      expect(result.languageCode, 'kn-IN');
      expect(result.isRomanised, isTrue);
    });

    test('extracts chat content from the OpenAI-shaped envelope', () async {
      final service = serviceReturning(jsonEncode({
        'choices': [
          {
            'message': {'role': 'assistant', 'content': '  Corrected text  '},
          }
        ],
      }));

      final reply = await service.chat(
        messages: [const ChatMessage.user('fix this')],
      );
      expect(reply, 'Corrected text');
    });

    test('rejects a 200 response that is not JSON', () async {
      final service = serviceReturning('<html>gateway</html>');
      expect(
        () => service.translate(
          input: 'hi',
          sourceLanguageCode: 'en-IN',
          targetLanguageCode: 'kn-IN',
        ),
        throwsA(isA<SarvamException>().having(
          (e) => e.kind,
          'kind',
          SarvamErrorKind.malformedResponse,
        )),
      );
    });
  });

  group('typed errors', () {
    Future<void> expectKind(int status, SarvamErrorKind kind) async {
      final service = serviceReturning('{"error":"x"}', status: status);
      await expectLater(
        service.translate(
          input: 'hi',
          sourceLanguageCode: 'en-IN',
          targetLanguageCode: 'kn-IN',
        ),
        throwsA(isA<SarvamException>().having((e) => e.kind, 'kind', kind)),
      );
    }

    test('401 and 403 map to unauthorized', () async {
      await expectKind(401, SarvamErrorKind.unauthorized);
      await expectKind(403, SarvamErrorKind.unauthorized);
    });

    test('413 and 422 map to payloadTooLarge', () async {
      await expectKind(413, SarvamErrorKind.payloadTooLarge);
      await expectKind(422, SarvamErrorKind.payloadTooLarge);
    });

    test('429 maps to rateLimited and is retryable', () async {
      await expectKind(429, SarvamErrorKind.rateLimited);
      expect(SarvamException.fromStatus(429).isRetryable, isTrue);
    });

    test('5xx maps to serverError', () async {
      await expectKind(500, SarvamErrorKind.serverError);
      await expectKind(503, SarvamErrorKind.serverError);
    });

    test('a missing key fails before any network call', () async {
      final service = serviceReturning('{}', key: null);
      await expectLater(
        service.translate(
          input: 'hi',
          sourceLanguageCode: 'en-IN',
          targetLanguageCode: 'kn-IN',
        ),
        throwsA(isA<SarvamException>().having(
          (e) => e.kind,
          'kind',
          SarvamErrorKind.missingKey,
        )),
      );
    });

    test('unauthorized and missingKey are flagged as needing setup', () {
      expect(SarvamException.missingKey.needsSetup, isTrue);
      expect(SarvamException.fromStatus(401).needsSetup, isTrue);
      expect(SarvamException.fromStatus(500).needsSetup, isFalse);
    });

    test('error detail never carries the API key', () {
      final error =
          SarvamException.fromStatus(401, debugDetail: 'translate HTTP 401');
      expect(error.toString(), isNot(contains('test-key')));
      expect(error.debugDetail, isNot(contains('test-key')));
    });
  });

  group('request size limits', () {
    test('pins the documented ceilings', () {
      expect(SarvamService.maxTranslateChars, 1000);
      expect(SarvamService.maxTtsChars, 2500);
      expect(SarvamService.maxRestAudioDuration, const Duration(seconds: 30));
    });

    test('short text is not split', () {
      expect(SarvamService.splitForLimit('hello there', 1000), ['hello there']);
    });

    test('long text splits on sentence boundaries within the limit', () {
      final text = List.filled(40, 'This is a sentence.').join(' ');
      final chunks = SarvamService.splitForLimit(text, 100);

      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(100));
      }
      // No content is dropped while chunking.
      expect(
        chunks.join(' ').replaceAll(RegExp(r'\s+'), ' '),
        text.replaceAll(RegExp(r'\s+'), ' '),
      );
    });

    test('a single oversized sentence is hard-wrapped rather than dropped', () {
      final text = 'a' * 250;
      final chunks = SarvamService.splitForLimit(text, 100);
      expect(chunks, hasLength(3));
      expect(chunks.join().length, 250);
    });
  });

  group('language table', () {
    test('defaults to the Kannada to English pair', () {
      expect(Languages.codeFor(Languages.defaultSourceName), 'kn-IN');
      expect(Languages.codeFor(Languages.defaultTargetName), 'en-IN');
    });

    test('maps display names to BCP-47 codes case-insensitively', () {
      expect(Languages.codeFor('Kannada'), 'kn-IN');
      expect(Languages.codeFor('kannada'), 'kn-IN');
      expect(Languages.codeFor('Hindi'), 'hi-IN');
    });

    test('rejects languages Sarvam does not support', () {
      // These shipped in the OpenAI build's 35-language list.
      for (final unsupported in ['Spanish', 'Japanese', 'Finnish', 'Korean']) {
        expect(Languages.codeFor(unsupported), isNull,
            reason: '$unsupported is not a Sarvam language');
        expect(Languages.isSupported(unsupported), isFalse);
      }
    });

    test('every listed language has a well-formed code', () {
      for (final language in Languages.all) {
        expect(language.code, matches(RegExp(r'^[a-z]{2,3}-IN$')),
            reason: '${language.name} has code ${language.code}');
      }
    });

    test('reverse lookup returns the display name', () {
      expect(Languages.nameFor('kn-IN'), 'Kannada');
      expect(Languages.nameFor('zz-IN'), 'zz-IN');
    });
  });

  group('speech to text upload', () {
    late Directory tempDir;

    setUp(() => tempDir = Directory.systemTemp.createTempSync('bhasha_stt'));
    tearDown(() => tempDir.deleteSync(recursive: true));

    /// A WAV-shaped file of [bytes] length. Contents are zeroed so the
    /// multipart body stays readable in assertions.
    File fakeWav(String name, int bytes) {
      final file = File('${tempDir.path}/$name')
        ..writeAsBytesSync(Uint8List(bytes));
      return file;
    }

    test('posts multipart audio to /speech-to-text with the pinned model',
        () async {
      late http.Request captured;
      final service = serviceReturning(
        jsonEncode({'transcript': 'hello', 'language_code': 'en-IN'}),
        onRequest: (r) => captured = r,
      );

      await service.speechToText(
        audioFile: fakeWav('clip.wav', 4096),
        mode: SaarasMode.transcribe,
      );

      expect(captured.url.path, '/speech-to-text');
      expect(captured.method, 'POST');
      expect(captured.headers['api-subscription-key'], 'test-key');
      expect(captured.body, contains('saaras:v3'));
      expect(captured.body, contains('transcribe'));
    });

    test('omits language_code so Saaras detects what was spoken', () async {
      late http.Request captured;
      final service = serviceReturning(
        jsonEncode({'transcript': 'hello', 'language_code': 'en-IN'}),
        onRequest: (r) => captured = r,
      );

      await service.speechToText(audioFile: fakeWav('clip.wav', 4096));

      expect(captured.body, isNot(contains('language_code')));
    });

    test('returns the language Saaras heard, not the one we guessed', () async {
      final service = serviceReturning(
        jsonEncode({'transcript': 'ನಾನು ಬರುತ್ತೇನೆ', 'language_code': 'kn-IN'}),
      );

      final result = await service.speechToText(
        audioFile: fakeWav('clip.wav', 4096),
      );

      expect(result.languageCode, 'kn-IN');
      expect(result.transcript, 'ನಾನು ಬರುತ್ತೇನೆ');
    });

    test('a header-only recording fails before any network call', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      });
      final service =
          SarvamService(client: client, keyProvider: () async => 'test-key');

      await expectLater(
        service.speechToText(audioFile: fakeWav('silent.wav', 44)),
        throwsA(isA<SarvamException>()
            .having((e) => e.kind, 'kind', SarvamErrorKind.noSpeechDetected)),
      );
      expect(called, isFalse, reason: 'no round trip for an empty recording');
    });

    test('a missing recording reports no speech rather than crashing', () {
      final service = serviceReturning('{}');
      expect(
        service.speechToText(audioFile: File('${tempDir.path}/gone.wav')),
        throwsA(isA<SarvamException>()
            .having((e) => e.kind, 'kind', SarvamErrorKind.noSpeechDetected)),
      );
    });

    test('a blank transcript is treated as nothing heard', () {
      final service = serviceReturning(
        jsonEncode({'transcript': '   ', 'language_code': 'en-IN'}),
      );
      expect(
        service.speechToText(audioFile: fakeWav('clip.wav', 4096)),
        throwsA(isA<SarvamException>()
            .having((e) => e.kind, 'kind', SarvamErrorKind.noSpeechDetected)),
      );
    });

    test('the client-side audio ceiling stays under the documented 30s', () {
      expect(
          SarvamService.maxRestAudioDuration.inSeconds, lessThanOrEqualTo(30));
    });
  });
}
