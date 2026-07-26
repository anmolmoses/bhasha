class XReplyStyle {
  const XReplyStyle({
    required this.tone,
    required this.length,
    required this.replyCount,
    required this.includeEmojis,
    required this.customInstructions,
  });

  final String tone;
  final String length;
  final int replyCount;
  final bool includeEmojis;
  final String customInstructions;

  bool get hasCustomInstructions => customInstructions.trim().isNotEmpty;
}
