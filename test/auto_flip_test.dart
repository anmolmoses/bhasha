import 'dart:convert';
import 'dart:io';

import 'package:bhasha/constants/languages.dart';
import 'package:bhasha/services/overlay_request_handler.dart';
import 'package:bhasha/services/sarvam_service.dart';
import 'package:bhasha/services/storage_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cover for switching language without leaving the app you are in.
///
/// Two halves: auto-flip, which removes the need to switch at all when the
/// parent works between the same two languages, and the overlay override,
/// which is how a pick made from the bubble's chip reaches Dart at all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> withPrefs({
    String source = 'Kannada',
    String target = 'English',
    bool autoFlip = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      'source_language': source,
      'target_language': target,
      'auto_flip_language_pair': autoFlip,
      'auto_detect_language': false,
    });
    FlutterSecureStorage.setMockInitialValues({
      'sarvam_api_key': 'sarvam-test-key',
    });
    await StorageService().init();
  }

  /// A Sarvam client that reports [detected] from /text-lid and records the
  /// direction every /translate call asked for.
  SarvamService sarvamDetecting(
    String detected, {
    required List<String> directions,
    List<String>? paths,
  }) {
    final client = MockClient((request) async {
      paths?.add(request.url.path);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final payload = switch (request.url.path) {
        SarvamService.languageIdPath => {
            'language_code': detected,
            'script_code': 'Latn',
          },
        SarvamService.translatePath => () {
            directions.add(
              '${body['source_language_code']}>${body['target_language_code']}',
            );
            return {'translated_text': 'translated'};
          }(),
        SarvamService.chatPath => {
            'choices': [
              {
                'message': {'content': 'corrected'},
              },
            ],
          },
        _ => <String, dynamic>{},
      };
      return http.Response(jsonEncode(payload), 200, headers: {
        'content-type': 'application/json; charset=utf-8',
      });
    });
    return SarvamService(client: client, keyProvider: () async => 'test-key');
  }

  Future<Map<String, dynamic>> translate(
    String text, {
    Map<String, dynamic> extra = const {},
  }) async {
    final result = await OverlayRequestHandler().handleProcessOverlayAction(
      MethodCall('processOverlayAction', {
        'action': 'translate',
        'text': text,
        ...extra,
      }),
    );
    return result as Map<String, dynamic>;
  }

  group('resolveTarget', () {
    const pair = LanguagePair(
      sourceCode: 'kn-IN',
      targetCode: 'en-IN',
      autoFlip: true,
    );

    test('text already in the target language goes back the other way', () {
      expect(pair.resolveTarget('en-IN'), 'kn-IN');
    });

    test('text in the source language goes to the target', () {
      expect(pair.resolveTarget('kn-IN'), 'en-IN');
    });

    test('a language outside the pair still goes to the reading language', () {
      expect(pair.resolveTarget('hi-IN'), 'en-IN');
    });

    test('an undetected language keeps the saved direction', () {
      expect(pair.resolveTarget(null), 'en-IN');
    });

    test('casing from Sarvam does not defeat the flip', () {
      expect(pair.resolveTarget('EN-in'), 'kn-IN');
    });

    test('a fixed direction never flips', () {
      const fixed = LanguagePair(
        sourceCode: 'kn-IN',
        targetCode: 'en-IN',
        autoFlip: false,
      );
      expect(fixed.resolveTarget('en-IN'), 'en-IN');
    });
  });

  group('tap to translate', () {
    test('English in a Kannada/English pair comes back as Kannada', () async {
      await withPrefs();
      final directions = <String>[];
      OverlayRequestHandler()
          .overrideServiceForTesting(sarvamDetecting('en-IN', directions: directions));

      await translate('I will come tomorrow');

      expect(directions, ['en-IN>kn-IN'],
          reason: 'the parent should not open Settings to reverse direction');
    });

    test('Kannada in the same pair comes back as English', () async {
      await withPrefs();
      final directions = <String>[];
      OverlayRequestHandler()
          .overrideServiceForTesting(sarvamDetecting('kn-IN', directions: directions));

      await translate('ನಾಳೆ ಬರುತ್ತೇನೆ');

      expect(directions, ['kn-IN>en-IN']);
    });

    test('a pair of one language cannot flip and keeps its direction',
        () async {
      await withPrefs(source: 'English', target: 'English');
      final directions = <String>[];
      OverlayRequestHandler()
          .overrideServiceForTesting(sarvamDetecting('en-IN', directions: directions));

      await translate('hello');

      expect(directions, ['en-IN>en-IN']);
    });

    test('auto-flip off keeps the fixed direction and skips detection',
        () async {
      await withPrefs(autoFlip: false);
      final directions = <String>[];
      final paths = <String>[];
      OverlayRequestHandler().overrideServiceForTesting(
        sarvamDetecting('en-IN', directions: directions, paths: paths),
      );

      await translate('I will come tomorrow');

      expect(directions, ['kn-IN>en-IN']);
      expect(paths, [SarvamService.translatePath],
          reason: 'a fixed direction must not pay for a detection round trip');
    });

    test('a detection outage falls back to the saved direction', () async {
      await withPrefs();
      final client = MockClient((request) async {
        if (request.url.path == SarvamService.languageIdPath) {
          return http.Response('nope', 500);
        }
        return http.Response(
          jsonEncode({'translated_text': 'translated'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      OverlayRequestHandler().overrideServiceForTesting(
        SarvamService(client: client, keyProvider: () async => 'test-key'),
      );

      final result = await translate('anything');

      expect(result['targetLang'], 'en-IN');
    });
  });

  group('hold to speak', () {
    /// Saaras reports the spoken language for free, so auto-flip costs the
    /// voice path no extra round trip.
    Future<Map<String, dynamic>> speak(
      String spokenLanguage, {
      required List<String> directions,
    }) async {
      final tempDir = Directory.systemTemp.createTempSync('bhasha_flip');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final audio = File('${tempDir.path}/clip.wav')
        ..writeAsBytesSync(Uint8List(8192));

      final client = MockClient((request) async {
        if (request.url.path == SarvamService.sttPath) {
          return http.Response(
            jsonEncode({
              'transcript': 'spoken words',
              'language_code': spokenLanguage,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        directions.add(
          '${body['source_language_code']}>${body['target_language_code']}',
        );
        return http.Response(
          jsonEncode({'translated_text': 'translated'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      OverlayRequestHandler().overrideServiceForTesting(
        SarvamService(client: client, keyProvider: () async => 'test-key'),
      );

      final result = await OverlayRequestHandler().handleProcessOverlayAction(
        MethodCall('processOverlayAction', {
          'action': 'voice_translate',
          'text': '',
          'audioPath': audio.path,
        }),
      );
      return result as Map<String, dynamic>;
    }

    test('speaking the target language flips to the other side', () async {
      await withPrefs();
      final directions = <String>[];

      final result = await speak('en-IN', directions: directions);

      expect(directions, ['en-IN>kn-IN']);
      expect(result['targetLang'], 'kn-IN');
    });

    test('speaking the source language still reaches the target', () async {
      await withPrefs();
      final directions = <String>[];

      final result = await speak('kn-IN', directions: directions);

      expect(directions, ['kn-IN>en-IN']);
      expect(result['targetLang'], 'en-IN');
    });
  });

  group('grammar', () {
    test('corrects in the language actually typed, not the target', () async {
      await withPrefs();
      late String systemPrompt;
      final client = MockClient((request) async {
        if (request.url.path == SarvamService.languageIdPath) {
          return http.Response(
            jsonEncode({'language_code': 'kn-IN', 'script_code': 'Knda'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        systemPrompt =
            (body['messages'] as List).first['content'] as String;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'corrected'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      OverlayRequestHandler().overrideServiceForTesting(
        SarvamService(client: client, keyProvider: () async => 'test-key'),
      );

      final result = await OverlayRequestHandler().handleProcessOverlayAction(
        MethodCall('processOverlayAction', {
          'action': 'grammar',
          'text': 'ನಾಳೆ ಬರುತ್ತೇನೆ',
        }),
      ) as Map<String, dynamic>;

      expect(systemPrompt, contains('Kannada'));
      expect(result['language'], 'Kannada');
    });
  });

  group('the choice made from the bubble chip', () {
    test('overrides the saved target and is persisted for the app', () async {
      await withPrefs(autoFlip: false);
      final directions = <String>[];
      OverlayRequestHandler()
          .overrideServiceForTesting(sarvamDetecting('kn-IN', directions: directions));

      await translate('ನಾಳೆ ಬರುತ್ತೇನೆ', extra: {
        'targetLanguage': 'Hindi',
        'sourceLanguage': 'Kannada',
        'autoFlip': false,
      });

      expect(directions, ['kn-IN>hi-IN']);
      expect(StorageService().getTargetLanguage(), 'Hindi',
          reason: 'Settings must show what the bubble is actually using');
    });

    test('turning auto-flip on from the chip takes effect immediately',
        () async {
      await withPrefs(autoFlip: false);
      final directions = <String>[];
      OverlayRequestHandler()
          .overrideServiceForTesting(sarvamDetecting('en-IN', directions: directions));

      await translate('hello', extra: {'autoFlip': true});

      expect(directions, ['en-IN>kn-IN']);
      expect(StorageService().getAutoFlip(), isTrue);
    });

    test('a language the build does not support is ignored, not saved',
        () async {
      await withPrefs(autoFlip: false);
      final directions = <String>[];
      OverlayRequestHandler()
          .overrideServiceForTesting(sarvamDetecting('kn-IN', directions: directions));

      await translate('ನಾಳೆ', extra: {'targetLanguage': 'Klingon'});

      expect(StorageService().getTargetLanguage(), 'English');
      expect(directions, ['kn-IN>en-IN']);
    });

    test('an absent override leaves the saved pair alone', () async {
      await withPrefs(autoFlip: false);
      final directions = <String>[];
      OverlayRequestHandler()
          .overrideServiceForTesting(sarvamDetecting('kn-IN', directions: directions));

      await translate('ನಾಳೆ');

      expect(StorageService().getTargetLanguage(), 'English');
      expect(StorageService().getSourceLanguage(), 'Kannada');
    });
  });

  group('chip labels', () {
    test('every language has a short label that fits the chip', () {
      for (final language in Languages.all) {
        expect(language.shortLabel.length, lessThanOrEqualTo(3),
            reason: '${language.name} would overflow the bubble chip');
        expect(language.shortLabel, language.shortLabel.toUpperCase());
      }
    });
  });
}
