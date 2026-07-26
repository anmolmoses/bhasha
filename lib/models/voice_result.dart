/// Overlay-visible state of the voice flow.
///
/// The native bubble mirrors these exactly, so the names are part of the
/// MethodChannel contract.
enum VoiceFlowState {
  idle,
  listening,
  processing,
  speaking,
  success,
  error;

  String get wire => name;
}

/// Legal transitions. Enforced in one place so the overlay can never get
/// stuck showing "listening" after a failure.
const Map<VoiceFlowState, Set<VoiceFlowState>> kVoiceTransitions = {
  VoiceFlowState.idle: {VoiceFlowState.listening, VoiceFlowState.processing},
  VoiceFlowState.listening: {
    VoiceFlowState.processing,
    VoiceFlowState.idle,
    VoiceFlowState.error,
  },
  VoiceFlowState.processing: {
    VoiceFlowState.speaking,
    VoiceFlowState.success,
    VoiceFlowState.error,
    VoiceFlowState.idle,
  },
  VoiceFlowState.speaking: {
    VoiceFlowState.idle,
    VoiceFlowState.success,
    VoiceFlowState.error,
    VoiceFlowState.processing,
  },
  VoiceFlowState.success: {VoiceFlowState.idle, VoiceFlowState.listening},
  VoiceFlowState.error: {VoiceFlowState.idle, VoiceFlowState.listening},
};

bool canTransition(VoiceFlowState from, VoiceFlowState to) =>
    kVoiceTransitions[from]?.contains(to) ?? false;

/// Result of a spoken reply: what the parent said, and what will be written
/// into the focused field.
class VoiceReplyResult {
  const VoiceReplyResult({
    required this.draft,
    required this.sourceTranscript,
    this.clarificationQuestion,
    this.latency,
  });

  /// The English text to place in the field. Empty when a clarification is
  /// needed instead.
  final String draft;

  /// What Saaras heard, kept only for this session's evidence display.
  final String sourceTranscript;

  /// Set when one critical fact was genuinely ambiguous. When present the
  /// field must not be modified.
  final String? clarificationQuestion;

  final Duration? latency;

  bool get needsClarification =>
      clarificationQuestion != null && clarificationQuestion!.trim().isNotEmpty;
}

/// Result of reading an incoming message to the parent.
class IncomingMessageResult {
  const IncomingMessageResult({
    required this.originalText,
    required this.kannadaText,
    this.latency,
  });

  final String originalText;
  final String kannadaText;
  final Duration? latency;
}
