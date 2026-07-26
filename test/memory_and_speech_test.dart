import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bhasha/l10n/parent_strings.dart';
import 'package:bhasha/models/parent_profile.dart';
import 'package:bhasha/models/sarvam_error.dart';
import 'package:bhasha/services/overlay_request_handler.dart';
import 'package:bhasha/services/parent_profile_service.dart';
import 'package:bhasha/services/sarvam_service.dart';
import 'package:bhasha/services/storage_service.dart';
import 'package:bhasha/services/tts_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Covers the memory layer (the parent profile that must survive a restart,
/// and the dictation context that grounds grammar fixes), the Kannada
/// rendering of every parent-facing failure, and the WAV-header maths the
/// playback timeout leans on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'com.yourapp.bhasha/native';
  const codec = StandardMethodCodec();
  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  group('parent profile persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ParentProfileService().resetCacheForTesting();
    });

    test('voice, pace, tone, and glossary survive a restart', () async {
      final service = ParentProfileService();
      await service.load();
      await service.update((p) => p.copyWith(
            voiceSpeaker: 'Anand',
            pace: 1.4,
            tone: ReplyTone.warm,
          ));
      await service.addGlossaryEntry(
        const GlossaryEntry(source: 'ಅಭಿಜ್ಞಾ', target: 'Abhijna'),
      );

      // Simulate the process dying and the app coming back.
      service.resetCacheForTesting();
      final reloaded = await service.load();

      expect(reloaded.voiceSpeaker, 'Anand');
      expect(reloaded.pace, 1.4);
      expect(reloaded.tone, ReplyTone.warm);
      expect(reloaded.glossary, [
        const GlossaryEntry(source: 'ಅಭಿಜ್ಞಾ', target: 'Abhijna'),
      ]);
    });

    test('re-adding a glossary term replaces it instead of duplicating',
        () async {
      final service = ParentProfileService();
      await service.load();
      await service.addGlossaryEntry(
        const GlossaryEntry(source: 'ಅಭಿಜ್ಞಾ', target: 'Abhijnaa'),
      );
      await service.addGlossaryEntry(
        const GlossaryEntry(source: 'ಅಭಿಜ್ಞಾ', target: 'Abhijna'),
      );

      expect(service.profile.glossary.length, 1);
      expect(service.profile.glossary.single.target, 'Abhijna');

      await service.removeGlossaryEntry('ಅಭಿಜ್ಞಾ');
      expect(service.profile.glossary, isEmpty);
    });

    test('a corrupt stored blob falls back to defaults, not a crash', () async {
      SharedPreferences.setMockInitialValues(
        {'parent_profile_v1': 'not json {'},
      );
      final service = ParentProfileService();
      service.resetCacheForTesting();
      final profile = await service.load();
      expect(profile, const ParentProfile());
    });
  });

  group('grammar correction uses the profile and recent dictation', () {
    late Directory tempDir;
    late File audio;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('bhasha_memory');
      audio =
          File('${tempDir.path}/clip.wav')..writeAsBytesSync(Uint8List(8192));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, (call) async {
        if (call.method == 'read') return 'test-key';
        return null;
      });

      SharedPreferences.setMockInitialValues({'target_language': 'English'});
      await StorageService().init();
      ParentProfileService().resetCacheForTesting();
      await ParentProfileService().load();
      OverlayRequestHandler().init();
      OverlayRequestHandler().overrideSpeakForTesting((_, __) async {});
    });

    tearDown(() {
      OverlayRequestHandler().overrideSpeakForTesting(null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, null);
      tempDir.deleteSync(recursive: true);
    });

    Future<Object?> sendAction(Map<String, Object?> arguments) async {
      final message = codec.encodeMethodCall(
        MethodCall('processOverlayAction', arguments),
      );
      ByteData? reply;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(channelName, message, (r) => reply = r);
      return codec.decodeEnvelope(reply!);
    }

    test('tone, glossary, and a dictated name all reach the prompt', () async {
      await ParentProfileService().update(
        (p) => p.copyWith(tone: ReplyTone.formal),
      );
      await ParentProfileService().addGlossaryEntry(
        const GlossaryEntry(source: 'ಅಭಿಜ್ಞಾ', target: 'Abhijna'),
      );

      String? systemPrompt;
      final client = MockClient((request) async {
        final body = switch (request.url.path) {
          SarvamService.sttPath => {
              'transcript': 'Abhijna ನಾಳೆ ಶಾಲೆಗೆ ಬರುವುದಿಲ್ಲ',
              'language_code': 'kn-IN',
            },
          SarvamService.translatePath => {
              'translated_text': 'Abhijna will not come to school tomorrow',
              'source_language_code': 'kn-IN',
            },
          SarvamService.chatPath => () {
              final messages =
                  (jsonDecode(request.body) as Map)['messages'] as List;
              systemPrompt = (messages.first as Map)['content'] as String;
              return {
                'choices': [
                  {
                    'message': {'content': 'Abhijna will not attend tomorrow.'}
                  }
                ],
              };
            }(),
          _ => <String, dynamic>{},
        };
        return http.Response(jsonEncode(body), 200, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      });
      OverlayRequestHandler().overrideServiceForTesting(
        SarvamService(client: client, keyProvider: () async => 'test-key'),
      );

      // A hold-to-speak turn first, so grammar has dictation to stay
      // consistent with.
      await sendAction({
        'action': 'voice_translate',
        'text': '',
        'audioPath': audio.path,
      });

      await sendAction({
        'action': 'grammar',
        'text': 'Abhijna not coming tomorow school',
      });

      expect(systemPrompt, isNotNull);
      expect(systemPrompt, contains(ReplyTone.formal.promptHint),
          reason: 'the saved tone must shape every correction');
      expect(systemPrompt, contains('"ಅಭಿಜ್ಞಾ" must be written as "Abhijna"'),
          reason: 'the approved glossary spelling must be enforced');
      expect(systemPrompt,
          contains('Abhijna will not come to school tomorrow'),
          reason: 'what the parent just dictated grounds the correction');
    });
  });

  group('parent-facing strings are readable by the parent', () {
    test('every canned SarvamException has a Kannada rendering', () {
      const canned = [
        SarvamException.missingKey,
        SarvamException.offline,
        SarvamException.timeout,
        SarvamException.cancelled,
        SarvamException.noSpeech,
        SarvamException.noReadableMessage,
        SarvamException.unsupportedField,
      ];
      for (final e in canned) {
        expect(ParentStrings.kannada, contains(e.parentMessage),
            reason: '"${e.parentMessage}" has no Kannada translation');
      }
    });

    test('every HTTP status maps to a translated message', () {
      for (final status in [400, 401, 403, 413, 422, 429, 500, 418]) {
        final e = SarvamException.fromStatus(status);
        expect(ParentStrings.kannada, contains(e.parentMessage),
            reason: 'status $status produces an untranslated message');
      }
    });

    test('localization keys off the saved parent language', () async {
      SharedPreferences.setMockInitialValues({'source_language': 'Kannada'});
      await StorageService().init();
      expect(
        ParentStrings.localize('No internet. Your text has not been changed.'),
        'ಇಂಟರ್ನೆಟ್ ಇಲ್ಲ. ನಿಮ್ಮ ಪಠ್ಯ ಬದಲಾಗಿಲ್ಲ.',
      );

      SharedPreferences.setMockInitialValues({'source_language': 'Hindi'});
      await StorageService().init();
      expect(
        ParentStrings.localize('No internet. Your text has not been changed.'),
        'No internet. Your text has not been changed.',
        reason: 'untranslated languages fall back to English, never a mix',
      );
    });
  });

  group('bulbul wire format', () {
    test('the speaker id goes out lowercase, whatever the profile shows', () async {
      // Sarvam rejects 'Kavya' with HTTP 400 but accepts 'kavya'; seen on a
      // real device, so pinned here.
      String? sentSpeaker;
      final client = MockClient((request) async {
        sentSpeaker = (jsonDecode(request.body) as Map)['speaker'] as String?;
        return http.Response(
          jsonEncode({'audios': ['UklGRg==']}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service =
          SarvamService(client: client, keyProvider: () async => 'test-key');

      await service.textToSpeech(
        text: 'ನಾಳೆ ಬರುತ್ತೇನೆ',
        targetLanguageCode: 'kn-IN',
        speaker: 'Kavya',
      );

      expect(sentSpeaker, 'kavya');
    });

    test('a stored speaker that is no longer offered falls back', () {
      final profile = ParentProfile.fromJson({'voiceSpeaker': 'Kavitha'});
      expect(profile.voiceSpeaker, ParentProfile.defaultSpeaker);
    });
  });

  group('wav duration parsing', () {
    Uint8List wavOf({required int byteRate, required int dataBytes}) {
      final bytes = Uint8List(44 + dataBytes);
      final data = ByteData.sublistView(bytes);
      data.setUint32(0, 0x52494646); // RIFF
      data.setUint32(8, 0x57415645); // WAVE
      data.setUint32(28, byteRate, Endian.little);
      return bytes;
    }

    test('reads the clip length from the header', () {
      // 32 kB/s with 64 kB of samples: exactly two seconds.
      final wav = wavOf(byteRate: 32000, dataBytes: 64000);
      expect(TtsPlayer.wavDuration(wav), const Duration(seconds: 2));
    });

    test('garbage input falls back to the 30-second ceiling', () {
      expect(TtsPlayer.wavDuration(Uint8List(10)),
          const Duration(seconds: 30));
      expect(TtsPlayer.wavDuration(Uint8List(100)),
          const Duration(seconds: 30),
          reason: 'no RIFF magic');
      expect(
          TtsPlayer.wavDuration(wavOf(byteRate: 0, dataBytes: 1000)),
          const Duration(seconds: 30),
          reason: 'a zero byte rate must not divide');
    });
  });
}
