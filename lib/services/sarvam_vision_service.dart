import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/screen_ocr_error.dart';
import '../models/screen_text_block.dart';
import 'storage_service.dart';

typedef SarvamKeyProvider = Future<String?> Function();

/// Screenshot OCR and geometry extraction via Sarvam Vision.
///
/// Sarvam exposes Sarvam Vision only through the asynchronous Document
/// Digitization job API — there is no single-shot vision endpoint and the chat
/// models do not accept images. One double tap therefore costs six round
/// trips: create job, request an upload URL, PUT the image, start, poll to a
/// terminal state, then request and fetch the output archive. Measured
/// end-to-end latency on a real screenshot is roughly 10-25s.
///
/// Translation never runs through this client; [OverlayRequestHandler] sends
/// the extracted block text to Sarvam Translate after this call succeeds.
class SarvamVisionService {
  SarvamVisionService({
    http.Client? client,
    SarvamKeyProvider? keyProvider,
    this.pollInterval = const Duration(milliseconds: 1500),
    this.jobTimeout = const Duration(seconds: 90),
  })  : _client = client ?? http.Client(),
        _keyProvider =
            keyProvider ?? (() => StorageService().getSarvamApiKey());

  static const baseUrl = 'https://api.sarvam.ai';
  static const jobPath = '/doc-digitization/job/v1';
  static const uploadPath = '$jobPath/upload-files';

  /// The uploaded archive entry. Sarvam accepts only a PDF or a ZIP here, so a
  /// single screenshot is wrapped in a one-entry ZIP.
  static const uploadFileName = 'pages.zip';
  static const pageFileName = 'page_001.jpg';

  /// `json` is advertised in the docs but rejected by the live API, which
  /// accepts only `html` and `md`. Both always ship the per-page metadata
  /// JSON we actually read, and `md` is the smaller download.
  static const outputFormat = 'md';

  /// Sarvam's layout tag for a picture region. On a phone screenshot these are
  /// icons and wallpaper, and the model *captions* them in prose rather than
  /// transcribing text, so they must never reach the overlay.
  static const imageLayoutTag = 'image';

  static const maxBlocks = 40;

  final http.Client _client;
  final SarvamKeyProvider _keyProvider;
  final Duration pollInterval;
  final Duration jobTimeout;

  /// Reads [jpegBase64] and returns the text blocks found on it.
  ///
  /// [languageCode] is the BCP-47 code of the language on screen; Sarvam
  /// Vision uses it to pick the right script decoder.
  Future<List<ScreenTextBlock>> recognizeScreen(
    String jpegBase64, {
    required String languageCode,
  }) async {
    final apiKey = (await _keyProvider())?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw const ScreenOcrException(
        ScreenOcrErrorKind.missingKey,
        'Add your Sarvam API key in Bhasha settings before double-tapping.',
      );
    }
    if (jpegBase64.trim().isEmpty) {
      throw const ScreenOcrException(
        ScreenOcrErrorKind.invalidResponse,
        'The screen capture was empty. Please try again.',
      );
    }

    final Uint8List jpeg;
    try {
      jpeg = base64Decode(jpegBase64.trim());
    } on FormatException {
      throw const ScreenOcrException(
        ScreenOcrErrorKind.invalidResponse,
        'The screen capture was unreadable. Please try again.',
      );
    }

    final jobId = await _createJob(apiKey, languageCode);
    final uploadUrl = await _requestUploadUrl(apiKey, jobId);
    await _uploadArchive(uploadUrl, _zipScreenshot(jpeg));
    await _startJob(apiKey, jobId);
    await _awaitCompletion(apiKey, jobId);
    final archive = await _downloadOutput(apiKey, jobId);

    return _parseBlocks(archive);
  }

  /// Wraps the screenshot in the flat single-image ZIP the API expects.
  List<int> _zipScreenshot(Uint8List jpeg) {
    final archive = Archive()
      ..addFile(ArchiveFile(pageFileName, jpeg.length, jpeg));
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw const ScreenOcrException(
        ScreenOcrErrorKind.invalidResponse,
        'Bhasha could not package the screen capture. Please try again.',
      );
    }
    return encoded;
  }

  Future<String> _createJob(String apiKey, String languageCode) async {
    final json = await _postJson(
      apiKey,
      Uri.parse('$baseUrl$jobPath'),
      {
        'job_parameters': {
          'language': languageCode,
          'output_format': outputFormat,
        },
      },
    );
    final jobId = json['job_id'];
    if (jobId is! String || jobId.isEmpty) {
      throw const ScreenOcrException(
        ScreenOcrErrorKind.invalidResponse,
        'Sarvam could not start reading the screen. Please try again.',
      );
    }
    return jobId;
  }

  Future<String> _requestUploadUrl(String apiKey, String jobId) async {
    final json = await _postJson(
      apiKey,
      Uri.parse('$baseUrl$uploadPath'),
      {
        'job_id': jobId,
        'files': [uploadFileName],
      },
    );
    final urls = json['upload_urls'];
    if (urls is! Map || urls.isEmpty) {
      throw const ScreenOcrException(
        ScreenOcrErrorKind.invalidResponse,
        'Sarvam did not accept the screen capture. Please try again.',
      );
    }
    final entry = urls.values.first;
    final url = entry is Map ? entry['file_url'] : null;
    if (url is! String || url.isEmpty) {
      throw const ScreenOcrException(
        ScreenOcrErrorKind.invalidResponse,
        'Sarvam did not accept the screen capture. Please try again.',
      );
    }
    return url;
  }

  /// The presigned target is Azure Blob Storage, which requires the blob-type
  /// header on PUT and is not authenticated with the Sarvam key.
  Future<void> _uploadArchive(String uploadUrl, List<int> zipBytes) async {
    final response = await _guard(
      () => _client.put(
        Uri.parse(uploadUrl),
        headers: const {
          'x-ms-blob-type': 'BlockBlob',
          'content-type': 'application/zip',
        },
        body: zipBytes,
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _exceptionForStatus(response.statusCode);
    }
  }

  Future<void> _startJob(String apiKey, String jobId) async {
    await _postJson(
      apiKey,
      Uri.parse('$baseUrl$jobPath/$jobId/start'),
      const {},
    );
  }

  /// Polls until the job reaches a terminal state.
  ///
  /// `PartiallyCompleted` is treated as success: a single screenshot is one
  /// page, and any output at all is better than failing the double tap.
  Future<void> _awaitCompletion(String apiKey, String jobId) async {
    final deadline = DateTime.now().add(jobTimeout);
    final uri = Uri.parse('$baseUrl$jobPath/$jobId/status');

    while (DateTime.now().isBefore(deadline)) {
      final response = await _guard(
        () => _client.get(uri, headers: _headers(apiKey)),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _exceptionForStatus(response.statusCode);
      }
      final state = _decode(response)['job_state']?.toString();
      switch (state) {
        case 'Completed':
        case 'PartiallyCompleted':
          return;
        case 'Failed':
          throw const ScreenOcrException(
            ScreenOcrErrorKind.server,
            'Sarvam could not read this screen. Please try again.',
          );
      }
      await Future<void>.delayed(pollInterval);
    }

    throw const ScreenOcrException(
      ScreenOcrErrorKind.timeout,
      'Reading the screen took too long. Please try again.',
    );
  }

  Future<Archive> _downloadOutput(String apiKey, String jobId) async {
    final json = await _postJson(
      apiKey,
      Uri.parse('$baseUrl$jobPath/$jobId/download-files'),
      const {},
    );
    final urls = json['download_urls'];
    final entry = urls is Map && urls.isNotEmpty ? urls.values.first : null;
    final url = entry is Map ? entry['file_url'] : null;
    if (url is! String || url.isEmpty) {
      throw const ScreenOcrException(
        ScreenOcrErrorKind.invalidResponse,
        'Sarvam returned no screen text. Please try again.',
      );
    }

    final response = await _guard(() => _client.get(Uri.parse(url)));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _exceptionForStatus(response.statusCode);
    }
    try {
      return ZipDecoder().decodeBytes(response.bodyBytes);
    } catch (_) {
      throw const ScreenOcrException(
        ScreenOcrErrorKind.invalidResponse,
        'Sarvam returned an unreadable screen-text archive.',
      );
    }
  }

  /// Reads `metadata/page_001.json` out of the output archive.
  ///
  /// Coordinates arrive as absolute pixels on the uploaded screenshot, so they
  /// are rescaled to the 0-1000 canvas the overlay draws against.
  List<ScreenTextBlock> _parseBlocks(Archive archive) {
    ArchiveFile? metadata;
    for (final file in archive.files) {
      if (file.isFile && file.name.toLowerCase().endsWith('.json')) {
        metadata = file;
        break;
      }
    }
    if (metadata == null) {
      throw const ScreenOcrException(
        ScreenOcrErrorKind.invalidResponse,
        'Sarvam returned no screen text. Please try again.',
      );
    }

    final Map<String, dynamic> page;
    try {
      page = jsonDecode(utf8.decode(metadata.content as List<int>))
          as Map<String, dynamic>;
    } catch (_) {
      throw const ScreenOcrException(
        ScreenOcrErrorKind.invalidResponse,
        'Sarvam returned unreadable screen text. Please try again.',
      );
    }

    final pageWidth = (page['image_width'] as num?)?.toDouble() ?? 0;
    final pageHeight = (page['image_height'] as num?)?.toDouble() ?? 0;
    if (pageWidth <= 0 || pageHeight <= 0) {
      throw const ScreenOcrException(
        ScreenOcrErrorKind.invalidResponse,
        'Sarvam returned screen text without a usable layout.',
      );
    }

    final rawBlocks = page['blocks'];
    if (rawBlocks is! List) return const [];

    final blocks = <ScreenTextBlock>[];
    final seen = <String>{};
    for (final raw in rawBlocks.whereType<Map>()) {
      // Picture regions come back as prose captions, not transcriptions.
      if (raw['layout_tag']?.toString().toLowerCase() == imageLayoutTag) {
        continue;
      }
      final text = cleanBlockText((raw['text'] ?? '').toString());
      if (text.isEmpty || isNoise(text)) continue;

      final coordinates = raw['coordinates'];
      if (coordinates is! Map) continue;
      double at(String key) => (coordinates[key] as num?)?.toDouble() ?? 0;
      final x1 = at('x1');
      final y1 = at('y1');
      final width = at('x2') - x1;
      final height = at('y2') - y1;
      if (width <= 0 || height <= 0) continue;

      // The Android status bar sits in every capture and never carries
      // anything worth translating.
      if (at('y2') <= pageHeight * 0.05 && _looksLikeStatusBar(text)) continue;

      // The same label can be reported by overlapping regions.
      if (!seen.add(text.toLowerCase())) continue;

      double scaled(double value, double extent) =>
          (value / extent * 1000).clamp(0, 1000).toDouble();

      blocks.add(
        ScreenTextBlock(
          text: text,
          x: scaled(x1, pageWidth),
          y: scaled(y1, pageHeight),
          width: scaled(width, pageWidth),
          height: scaled(height, pageHeight),
        ),
      );
      if (blocks.length >= maxBlocks) break;
    }
    return List.unmodifiable(blocks);
  }

  /// Strips the Markdown scaffolding Sarvam Vision emits around list rows and
  /// headings. Left in place it shows up literally on the overlay as
  /// `- Wallpapers & Style` or `**Connecting and Sharing**:`.
  static String cleanBlockText(String raw) {
    var text = raw.trim();
    // Leading heading hashes, list bullets, and blockquote markers.
    text = text.replaceAll(RegExp(r'^\s*(?:[#>]+|[-*•·]\s)\s*'), '');
    // Emphasis and inline-code fences, which never survive as styling here.
    text = text.replaceAll(RegExp(r'(\*\*|__|`)'), '');
    // Table pipes and trailing label colons.
    text = text.replaceAll('|', ' ').replaceAll(RegExp(r'\s*:\s*$'), '');
    // Collapse the newlines a wrapped row arrives with.
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  /// True for blocks that carry no translatable content.
  static bool isNoise(String text) {
    // Icons, chevrons, badge counts, timestamps: nothing to translate.
    if (!RegExp(r'\p{L}', unicode: true).hasMatch(text)) return true;

    // A lone glyph that survived the letter check (a "T" avatar, an "X").
    if (text.runes.length <= 1) return true;

    // Opaque identifiers such as `I1539534560058`.
    if (!text.contains(' ')) {
      final digits = RegExp(r'\d').allMatches(text).length;
      if (text.length >= 8 && digits / text.length > 0.6) return true;
    }
    return false;
  }

  /// Matches the clock/battery/signal strip Android draws on every capture.
  static bool _looksLikeStatusBar(String text) =>
      RegExp(r'\d{1,2}:\d{2}').hasMatch(text) ||
      RegExp(r'\d{1,3}\s*%').hasMatch(text) ||
      RegExp(r'\b(?:LTE|5G|4G|VoLTE|KB/S|MB/S|Wi-?Fi)\b', caseSensitive: false)
          .hasMatch(text);

  Map<String, String> _headers(String apiKey) => {
        'api-subscription-key': apiKey,
        'content-type': 'application/json',
      };

  Future<Map<String, dynamic>> _postJson(
    String apiKey,
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    final response = await _guard(
      () => _client.post(
        uri,
        headers: _headers(apiKey),
        body: jsonEncode(body),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _log('${uri.path} failed with HTTP ${response.statusCode}');
      throw _exceptionForStatus(response.statusCode);
    }
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Falls through to the shared failure below.
    }
    throw const ScreenOcrException(
      ScreenOcrErrorKind.invalidResponse,
      'Sarvam returned an unexpected reply while reading the screen.',
    );
  }

  Future<http.Response> _guard(Future<http.Response> Function() send) async {
    try {
      return await send().timeout(const Duration(seconds: 45));
    } on http.ClientException {
      throw const ScreenOcrException(
        ScreenOcrErrorKind.network,
        'Could not reach Sarvam to read the screen. Check your connection.',
      );
    } on TimeoutException {
      throw const ScreenOcrException(
        ScreenOcrErrorKind.timeout,
        'Reading the screen took too long. Please try again.',
      );
    }
  }

  ScreenOcrException _exceptionForStatus(int statusCode) {
    // Sarvam returns 403 (not 401) for a bad key.
    if (statusCode == 401 || statusCode == 403) {
      return const ScreenOcrException(
        ScreenOcrErrorKind.unauthorized,
        'Your Sarvam API key was rejected. Check it in Bhasha settings.',
      );
    }
    if (statusCode == 429) {
      return const ScreenOcrException(
        ScreenOcrErrorKind.rateLimited,
        'Sarvam is busy or out of credits. Please try again shortly.',
      );
    }
    return const ScreenOcrException(
      ScreenOcrErrorKind.server,
      'Sarvam screen reading is unavailable right now. Please try again.',
    );
  }

  /// Debug-only. Never receives keys or screenshot content.
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[sarvam-vision] $message');
    }
  }
}
