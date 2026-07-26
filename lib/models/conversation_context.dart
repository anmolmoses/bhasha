/// In-memory only, bounded, and never written to disk.
///
/// This holds the one message the parent explicitly asked Bhasha to look at,
/// plus a short tail of follow-up turns so "that day" or "the same amount" can
/// resolve. It is cleared whenever a new message is captured or the flow ends.
class ConversationContext {
  ConversationContext({this.maxTurns = 6});

  /// Follow-up turns retained. Older turns are dropped, not persisted.
  final int maxTurns;

  String? _sourceMessage;
  String? _kannadaExplanation;
  final List<ContextTurn> _turns = [];

  /// The English message currently under discussion, exactly as captured.
  String? get sourceMessage => _sourceMessage;

  /// The Kannada rendering that was read aloud.
  String? get kannadaExplanation => _kannadaExplanation;

  List<ContextTurn> get turns => List.unmodifiable(_turns);

  bool get hasMessage =>
      _sourceMessage != null && _sourceMessage!.trim().isNotEmpty;

  /// Starts a fresh context. Any previous message and turns are dropped.
  void captureMessage(String message, {String? kannadaExplanation}) {
    _sourceMessage = message.trim();
    _kannadaExplanation = kannadaExplanation;
    _turns.clear();
  }

  void setKannadaExplanation(String explanation) {
    _kannadaExplanation = explanation;
  }

  void addTurn(ContextTurn turn) {
    _turns.add(turn);
    while (_turns.length > maxTurns) {
      _turns.removeAt(0);
    }
  }

  void clear() {
    _sourceMessage = null;
    _kannadaExplanation = null;
    _turns.clear();
  }

  /// Renders the grounding block for a prompt.
  ///
  /// Returns an empty string when no message is captured, so callers can
  /// refuse to answer rather than letting the model invent context.
  String groundingBlock() {
    if (!hasMessage) return '';
    final buffer = StringBuffer()
      ..writeln('MESSAGE (the only source of truth):')
      ..writeln(_sourceMessage);
    if (_turns.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Earlier in this conversation:');
      for (final turn in _turns) {
        buffer.writeln('Parent asked: ${turn.question}');
        buffer.writeln('Bhasha answered: ${turn.answer}');
      }
    }
    return buffer.toString().trim();
  }
}

class ContextTurn {
  const ContextTurn({required this.question, required this.answer});

  final String question;
  final String answer;
}
