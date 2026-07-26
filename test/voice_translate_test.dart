import 'dart:convert';
import 'dart:io';

import 'package:bhasha/l10n/parent_strings.dart';
import 'package:bhasha/services/overlay_request_handler.dart';
import 'package:bhasha/services/sarvam_service.dart';
import 'package:bhasha/services/storage_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// End-to-end cover for hold-to-speak: audio path in from the bubble, a
/// message in the parent's selected language out.
///
/// The channel is driven the way the native side drives it, so a mismatch
/// between the Kotlin action name and the Dart switch fails here rather than on
/// a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'com.yourapp.bhasha/native';
  const codec = StandardMethodCodec();
  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  late Directory tempDir;
  late File audio;
  late List<(String, String)> spokenAloud;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('bhasha_voice');
    // Large enough to clear the "nothing was recorded" guard.
    audio = File('${tempDir.path}/clip.wav')..writeAsBytesSync(Uint8List(8192));

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      if (call.method == 'read') return 'test-key';
      return null;
    });

    SharedPreferences.setMockInitialValues({'target_language': 'Kannada'});
    await StorageService().init();
    OverlayRequestHandler().init();
    // Bulbul playback needs a real audio device; stub it out here and assert
    // against the recorded calls instead.
    spokenAloud = [];
    OverlayRequestHandler().overrideSpeakForTesting(
      (text, languageCode) async => spokenAloud.add((text, languageCode)),
    );
  });

  tearDown(() {
    OverlayRequestHandler().overrideSpeakForTesting(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
    tempDir.deleteSync(recursive: true);
  });

  /// A Sarvam client that answers speech-to-text and translate from canned
  /// bodies and records which endpoints were actually reached.
  SarvamService sarvamReturning({
    required String transcript,
    required String detectedLanguage,
    String translated = 'ನಾಳೆ ಬರುತ್ತೇನೆ',
    List<String>? paths,
  }) {
    final client = MockClient((request) async {
      paths?.add(request.url.path);
      final body = switch (request.url.path) {
        SarvamService.sttPath => {
            'transcript': transcript,
            'language_code': detectedLanguage,
          },
        SarvamService.translatePath => {
            'translated_text': translated,
            'source_language_code': detectedLanguage,
          },
        _ => <String, dynamic>{},
      };
      return http.Response(jsonEncode(body), 200, headers: {
        'content-type': 'application/json; charset=utf-8',
      });
    });
    return SarvamService(client: client, keyProvider: () async => 'test-key');
  }

  /// Sends the same MethodCall the overlay sends when the button is released.
  Future<Object?> holdToSpeak({String? audioPath}) async {
    final message = codec.encodeMethodCall(MethodCall('processOverlayAction', {
      'action': 'voice_translate',
      'text': '',
      'audioPath': audioPath,
    }));

    ByteData? reply;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(channelName, message, (r) => reply = r);
    return codec.decodeEnvelope(reply!);
  }

  test('English speech becomes the selected language in the composer',
      () async {
    final paths = <String>[];
    OverlayRequestHandler().overrideServiceForTesting(sarvamReturning(
      transcript: 'I will come tomorrow',
      detectedLanguage: 'en-IN',
      translated: 'ನಾಳೆ ಬರುತ್ತೇನೆ',
      paths: paths,
    ));

    final result = await holdToSpeak(audioPath: audio.path) as Map;

    expect(result['resultText'], 'ನಾಳೆ ಬರುತ್ತೇನೆ');
    expect(result['transcript'], 'I will come tomorrow');
    expect(result['sourceLang'], 'en-IN');
    expect(result['targetLang'], 'kn-IN');
    expect(paths, [SarvamService.sttPath, SarvamService.translatePath]);
    expect(spokenAloud, [('ನಾಳೆ ಬರುತ್ತೇನೆ', 'kn-IN')],
        reason: 'the inserted reply is also read aloud in the target language');
  });

  test('turning the speak-aloud switch off silences playback', () async {
    SharedPreferences.setMockInitialValues({
      'target_language': 'Kannada',
      'speak_translations_enabled': false,
    });
    await StorageService().init();

    OverlayRequestHandler().overrideServiceForTesting(sarvamReturning(
      transcript: 'I will come tomorrow',
      detectedLanguage: 'en-IN',
    ));

    await holdToSpeak(audioPath: audio.path);

    expect(spokenAloud, isEmpty);
  });

  test('speech already in the target language skips the translate round trip',
      () async {
    final paths = <String>[];
    OverlayRequestHandler().overrideServiceForTesting(sarvamReturning(
      transcript: 'ನಾಳೆ ಬರುತ್ತೇನೆ',
      detectedLanguage: 'kn-IN',
      paths: paths,
    ));

    final result = await holdToSpeak(audioPath: audio.path) as Map;

    expect(result['resultText'], 'ನಾಳೆ ಬರುತ್ತೇನೆ');
    expect(result['translated'], isFalse);
    expect(paths, [SarvamService.sttPath],
        reason: 'no reason to translate Kannada into Kannada');
  });

  test('an unrecognised spoken language falls back to auto rather than a 400',
      () async {
    late String sentSource;
    final client = MockClient((request) async {
      if (request.url.path == SarvamService.translatePath) {
        sentSource =
            (jsonDecode(request.body) as Map)['source_language_code'] as String;
        return http.Response(
          jsonEncode(
              {'translated_text': 'ಸರಿ', 'source_language_code': 'auto'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(
        jsonEncode({'transcript': 'ok', 'language_code': 'unknown'}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    OverlayRequestHandler().overrideServiceForTesting(
      SarvamService(client: client, keyProvider: () async => 'test-key'),
    );

    await holdToSpeak(audioPath: audio.path);

    expect(sentSource, 'auto');
  });

  test('a released button with no recording fails with a parent-facing message',
      () async {
    OverlayRequestHandler().overrideServiceForTesting(sarvamReturning(
      transcript: 'unused',
      detectedLanguage: 'en-IN',
    ));

    // The parent's language defaults to Kannada, so the failure must arrive
    // in Kannada - an English error is unreadable to the declared user.
    await expectLater(
      holdToSpeak(audioPath: null),
      throwsA(isA<PlatformException>()
          .having((e) => e.code, 'code', 'invalid_arguments')
          .having(
            (e) => e.message,
            'message',
            ParentStrings
                .kannada['No recording was captured. Hold the button and speak.'],
          )),
    );
  });

  test('silence surfaces as a typed error, not a raw exception', () async {
    OverlayRequestHandler().overrideServiceForTesting(sarvamReturning(
      transcript: '   ',
      detectedLanguage: 'en-IN',
    ));

    await expectLater(
      holdToSpeak(audioPath: audio.path),
      throwsA(isA<PlatformException>()
          .having((e) => e.code, 'code', 'noSpeechDetected')
          .having(
            (e) => e.message,
            'message',
            ParentStrings
                .kannada['I did not hear anything. Hold the button and speak.'],
          )),
    );
  });
}
