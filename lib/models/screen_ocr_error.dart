enum ScreenOcrErrorKind {
  missingKey,
  unauthorized,
  rateLimited,
  invalidResponse,
  network,
  timeout,
  server,
}

/// Failure raised by the Sarvam Vision screen-reading pipeline.
///
/// Kept separate from [SarvamException] because screen OCR runs as a
/// multi-step job: the parent-facing wording has to describe reading the
/// screen, not translating text.
class ScreenOcrException implements Exception {
  const ScreenOcrException(this.kind, this.parentMessage);

  final ScreenOcrErrorKind kind;
  final String parentMessage;

  @override
  String toString() => parentMessage;
}
