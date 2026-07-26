/// Typed failure modes for every Sarvam call.
///
/// The overlay shows [SarvamException.parentMessage] directly to a parent who
/// is not technical, so those strings must stay plain and actionable. The
/// [kind] is what code branches on.
enum SarvamErrorKind {
  /// No Sarvam key saved yet.
  missingKey,

  /// 401/403 - key rejected.
  unauthorized,

  /// 429 - too many requests.
  rateLimited,

  /// 413/422 - audio or text rejected as too large/unprocessable.
  payloadTooLarge,

  /// 400 - request was malformed or unsupported by the API.
  invalidRequest,

  /// 5xx.
  serverError,

  /// No usable network connection.
  offline,

  /// Request exceeded our client deadline.
  timeout,

  /// User released/cancelled before completion.
  cancelled,

  /// 2xx but the body did not match the documented schema.
  malformedResponse,

  /// Audio captured, but empty/too short to be speech.
  noSpeechDetected,

  /// The screen had no message we could confidently read.
  noReadableMessage,

  /// Focused field could not accept replacement text.
  unsupportedField,
}

class SarvamException implements Exception {
  const SarvamException(
    this.kind, {
    required this.parentMessage,
    this.statusCode,
    this.debugDetail,
  });

  final SarvamErrorKind kind;

  /// Short, non-technical, shown on the overlay.
  final String parentMessage;

  final int? statusCode;

  /// Never contains the API key, audio, or message contents.
  final String? debugDetail;

  /// True when retrying the identical request could plausibly succeed.
  bool get isRetryable =>
      kind == SarvamErrorKind.offline ||
      kind == SarvamErrorKind.timeout ||
      kind == SarvamErrorKind.rateLimited ||
      kind == SarvamErrorKind.serverError;

  /// True when the parent must fix something in settings before retrying.
  bool get needsSetup =>
      kind == SarvamErrorKind.missingKey ||
      kind == SarvamErrorKind.unauthorized;

  factory SarvamException.fromStatus(int status, {String? debugDetail}) {
    switch (status) {
      case 400:
        return SarvamException(
          SarvamErrorKind.invalidRequest,
          parentMessage: 'Bhasha could not process that. Please try again.',
          statusCode: status,
          debugDetail: debugDetail,
        );
      case 401:
      case 403:
        return SarvamException(
          SarvamErrorKind.unauthorized,
          parentMessage:
              'Your Sarvam key was not accepted. Check it in Settings.',
          statusCode: status,
          debugDetail: debugDetail,
        );
      case 413:
      case 422:
        return SarvamException(
          SarvamErrorKind.payloadTooLarge,
          parentMessage: 'That was too long. Please try a shorter message.',
          statusCode: status,
          debugDetail: debugDetail,
        );
      case 429:
        return SarvamException(
          SarvamErrorKind.rateLimited,
          parentMessage: 'Too many requests just now. Wait a moment and retry.',
          statusCode: status,
          debugDetail: debugDetail,
        );
      default:
        if (status >= 500) {
          return SarvamException(
            SarvamErrorKind.serverError,
            parentMessage: 'Sarvam is having trouble. Please try again.',
            statusCode: status,
            debugDetail: debugDetail,
          );
        }
        return SarvamException(
          SarvamErrorKind.invalidRequest,
          parentMessage: 'Something went wrong. Please try again.',
          statusCode: status,
          debugDetail: debugDetail,
        );
    }
  }

  static const missingKey = SarvamException(
    SarvamErrorKind.missingKey,
    parentMessage: 'Add your Sarvam key in Bhasha settings first.',
  );

  static const offline = SarvamException(
    SarvamErrorKind.offline,
    parentMessage: 'No internet. Your text has not been changed.',
  );

  static const timeout = SarvamException(
    SarvamErrorKind.timeout,
    parentMessage: 'That took too long. Your text has not been changed.',
  );

  static const cancelled = SarvamException(
    SarvamErrorKind.cancelled,
    parentMessage: 'Cancelled.',
  );

  static const noSpeech = SarvamException(
    SarvamErrorKind.noSpeechDetected,
    parentMessage: 'I did not hear anything. Hold the button and speak.',
  );

  static const noReadableMessage = SarvamException(
    SarvamErrorKind.noReadableMessage,
    parentMessage:
        'I could not find a message to read. Select the message and try again.',
  );

  static const unsupportedField = SarvamException(
    SarvamErrorKind.unsupportedField,
    parentMessage: 'This app does not allow Bhasha to change the text here.',
  );

  @override
  String toString() =>
      'SarvamException(${kind.name}, status: $statusCode, detail: $debugDetail)';
}
