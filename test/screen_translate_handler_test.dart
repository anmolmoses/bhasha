import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:bhasha/services/overlay_request_handler.dart';
import 'package:bhasha/services/sarvam_service.dart';
import 'package:bhasha/services/sarvam_vision_service.dart';
import 'package:bhasha/services/storage_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds the output archive Sarvam Vision returns: a per-page metadata JSON
/// alongside the rendered document.
List<int> _outputArchive(Map<String, dynamic> page) {
  final json = utf8.encode(jsonEncode(page));
  final archive = Archive()
    ..addFile(ArchiveFile('document.md', 3, utf8.encode('hi\n')))
    ..addFile(ArchiveFile('metadata/page_001.json', json.length, json));
  return ZipEncoder().encode(archive)!;
}

/// Drives the six-step job pipeline, recording what each step received.
class _VisionBackend {
  final List<String> steps = [];
  Map<String, dynamic>? createBody;
  List<int>? uploadedBytes;
  int statusCalls = 0;

  _VisionBackend({required this.page});

  final Map<String, dynamic> page;

  /// Number of `Running` replies before the job reports `Completed`.
  static const runningPolls = 1;

  http.Client client() => MockClient((request) async {
        final path = request.url.path;

        if (path == SarvamVisionService.jobPath) {
          steps.add('create');
          expect(request.headers['api-subscription-key'], 'sarvam-test-key');
          createBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _json({'job_id': 'job-1'});
        }
        if (path == SarvamVisionService.uploadPath) {
          steps.add('upload-urls');
          return _json({
            'upload_urls': {
              'pages.zip': {'file_url': 'https://blob.test/in?sig=x'},
            },
          });
        }
        if (request.url.host == 'blob.test' && request.method == 'PUT') {
          steps.add('put');
          expect(request.headers['x-ms-blob-type'], 'BlockBlob');
          uploadedBytes = request.bodyBytes;
          return http.Response('', 201);
        }
        if (path.endsWith('/start')) {
          steps.add('start');
          return _json({'job_state': 'Pending'});
        }
        if (path.endsWith('/status')) {
          statusCalls++;
          steps.add('status');
          return _json({
            'job_state': statusCalls > runningPolls ? 'Completed' : 'Running',
          });
        }
        if (path.endsWith('/download-files')) {
          steps.add('download-urls');
          return _json({
            'download_urls': {
              'document.zip': {'file_url': 'https://blob.test/out?sig=y'},
            },
          });
        }
        if (request.url.host == 'blob.test') {
          steps.add('fetch-zip');
          return http.Response.bytes(_outputArchive(page), 200);
        }
        fail('unexpected request: ${request.method} ${request.url}');
      });

  static http.Response _json(Map<String, dynamic> body) => http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
}

Map<String, dynamic> _block(
  String text, {
  required double x1,
  required double y1,
  required double x2,
  required double y2,
  String layoutTag = 'paragraph',
}) =>
    {
      'text': text,
      'layout_tag': layoutTag,
      'coordinates': {'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _filterTests();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'source_language': 'Kannada',
      'target_language': 'English',
      'auto_detect_language': false,
    });
    FlutterSecureStorage.setMockInitialValues({
      'sarvam_api_key': 'sarvam-test-key',
    });
    await StorageService().init();
  });

  test('screen_translate runs the Sarvam Vision job then translates each block',
      () async {
    final backend = _VisionBackend(
      page: {
        'image_width': 1000,
        'image_height': 2000,
        'blocks': [
          _block('ನಮಸ್ಕಾರ', x1: 100, y1: 200, x2: 400, y2: 340),
          _block('ಹೇಗಿದ್ದೀರಿ?', x1: 100, y1: 400, x2: 520, y2: 540),
        ],
      },
    );
    final sarvamInputs = <String>[];
    final vision = SarvamVisionService(
      client: backend.client(),
      keyProvider: () async => 'sarvam-test-key',
      pollInterval: Duration.zero,
    );
    final sarvam = SarvamService(
      client: MockClient((request) async {
        expect(request.url.host, 'api.sarvam.ai');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final input = body['input'] as String;
        sarvamInputs.add(input);
        return http.Response(
          jsonEncode({
            'translated_text': input == 'ನಮಸ್ಕಾರ' ? 'Hello' : 'How are you?',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      keyProvider: () async => 'sarvam-test-key',
    );
    final handler = OverlayRequestHandler()
      ..overrideVisionServiceForTesting(vision)
      ..overrideServiceForTesting(sarvam);

    final result = await handler.handleProcessOverlayAction(
      MethodCall('processOverlayAction', {
        'action': 'screen_translate',
        'imageBase64': base64Encode(utf8.encode('fake-jpeg-bytes')),
      }),
    ) as Map<String, dynamic>;

    expect(
      backend.steps,
      ['create', 'upload-urls', 'put', 'start', 'status', 'status',
          'download-urls', 'fetch-zip'],
    );
    // The screenshot must reach Sarvam as a ZIP, not a bare image.
    expect(backend.uploadedBytes, isNotNull);
    final uploaded = ZipDecoder().decodeBytes(backend.uploadedBytes!);
    expect(uploaded.files.single.name, SarvamVisionService.pageFileName);

    expect(backend.createBody?['job_parameters'], {
      'language': 'kn-IN',
      'output_format': 'md',
    });
    expect(sarvamInputs, containsAll(<String>['ನಮಸ್ಕಾರ', 'ಹೇಗಿದ್ದೀರಿ?']));
    expect(result['sourceLang'], 'kn-IN');
    expect(result['targetLang'], 'en-IN');

    final blocks = result['blocks'] as List<dynamic>;
    expect(blocks, hasLength(2));
    final first = blocks.first as Map;
    expect(first['translatedText'], 'Hello');
    // Pixels rescaled onto the overlay's 0-1000 canvas.
    expect(first['x'], 100);
    expect(first['y'], 100);
    expect(first['width'], 300);
    expect(first['height'], 70);
    expect((blocks.last as Map)['translatedText'], 'How are you?');
  });

  test('screen_translate drops picture regions, the status bar, and noise',
      () async {
    final backend = _VisionBackend(
      page: {
        'image_width': 1000,
        'image_height': 1000,
        'blocks': [
          _block(
            'The image shows a green chat wallpaper with a person.',
            x1: 0,
            y1: 0,
            x2: 1000,
            y2: 900,
            layoutTag: 'image',
          ),
          // Android's clock/battery strip, always present in a capture.
          _block('14:19 LTE2 5G 100%', x1: 100, y1: 5, x2: 900, y2: 40),
          // A chevron and an opaque account id.
          _block('>', x1: 900, y1: 200, x2: 940, y2: 240),
          _block('I1539534560058', x1: 200, y1: 300, x2: 600, y2: 340),
          _block('ನಮಸ್ಕಾರ', x1: 10, y1: 100, x2: 210, y2: 160),
        ],
      },
    );
    final sarvamInputs = <String>[];
    final handler = OverlayRequestHandler()
      ..overrideVisionServiceForTesting(
        SarvamVisionService(
          client: backend.client(),
          keyProvider: () async => 'sarvam-test-key',
          pollInterval: Duration.zero,
        ),
      )
      ..overrideServiceForTesting(
        SarvamService(
          client: MockClient((request) async {
            sarvamInputs
                .add((jsonDecode(request.body) as Map)['input'] as String);
            return http.Response(
              jsonEncode({'translated_text': 'Hello'}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
          keyProvider: () async => 'sarvam-test-key',
        ),
      );

    final result = await handler.handleProcessOverlayAction(
      MethodCall('processOverlayAction', {
        'action': 'screen_translate',
        'imageBase64': base64Encode(utf8.encode('fake-jpeg-bytes')),
      }),
    ) as Map<String, dynamic>;

    expect(sarvamInputs, ['ನಮಸ್ಕಾರ']);
    expect(result['blocks'], hasLength(1));
  });

  test('screen_translate surfaces a rejected key as a parent-facing message',
      () async {
    final handler = OverlayRequestHandler()
      ..overrideVisionServiceForTesting(
        SarvamVisionService(
          client: MockClient((_) async => http.Response('forbidden', 403)),
          keyProvider: () async => 'sarvam-test-key',
          pollInterval: Duration.zero,
        ),
      );

    await expectLater(
      handler.handleProcessOverlayAction(
        MethodCall('processOverlayAction', {
          'action': 'screen_translate',
          'imageBase64': base64Encode(utf8.encode('fake-jpeg-bytes')),
        }),
      ),
      throwsA(
        isA<PlatformException>()
            .having((e) => e.code, 'code', 'unauthorized')
            .having(
              (e) => e.message,
              'message',
              contains('Sarvam API key was rejected'),
            ),
      ),
    );
  });

  test('screen_translate rejects an empty capture before calling Sarvam',
      () async {
    final handler = OverlayRequestHandler();

    await expectLater(
      handler.handleProcessOverlayAction(
        const MethodCall('processOverlayAction', {
          'action': 'screen_translate',
          'imageBase64': '',
        }),
      ),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'invalid_capture',
        ),
      ),
    );
  });
}

void _filterTests() {
  group('block cleanup', () {
    test('strips Markdown scaffolding Sarvam Vision emits', () {
      expect(
        SarvamVisionService.cleanBlockText('- Wallpapers & Style'),
        'Wallpapers & Style',
      );
      expect(
        SarvamVisionService.cleanBlockText('**Connecting and Sharing**:'),
        'Connecting and Sharing',
      );
      expect(SarvamVisionService.cleanBlockText('## Settings'), 'Settings');
      expect(
        SarvamVisionService.cleanBlockText('Home screen\n& lock screen'),
        'Home screen & lock screen',
      );
    });

    test('rejects blocks with nothing to translate', () {
      expect(SarvamVisionService.isNoise('>'), isTrue);
      expect(SarvamVisionService.isNoise('100%'), isTrue);
      expect(SarvamVisionService.isNoise('19:32'), isTrue);
      expect(SarvamVisionService.isNoise('T'), isTrue);
      expect(SarvamVisionService.isNoise('📶'), isTrue);
      // An opaque account identifier.
      expect(SarvamVisionService.isNoise('I1539534560058'), isTrue);
    });

    test('keeps real labels, including short ones and Kannada', () {
      expect(SarvamVisionService.isNoise('Wi-Fi'), isFalse);
      expect(SarvamVisionService.isNoise('Search'), isFalse);
      expect(SarvamVisionService.isNoise('ನಮಸ್ಕಾರ'), isFalse);
      expect(SarvamVisionService.isNoise('Galaxy Watch4'), isFalse);
    });

    test('drops a period the translator added to a label', () {
      expect(
        OverlayRequestHandler.matchSourcePunctuation('Search', 'Search.'),
        'Search',
      );
      // A real sentence keeps its punctuation.
      expect(
        OverlayRequestHandler.matchSourcePunctuation(
          'ಹೇಗಿದ್ದೀರಿ.',
          'How are you.',
        ),
        'How are you.',
      );
    });
  });
}
