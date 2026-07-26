import 'dart:convert';

/// How the English draft should read. The parent picks this once; every
/// rewrite prompt carries it.
enum ReplyTone {
  simple,
  warm,
  formal,
  direct;

  static ReplyTone fromJson(String? value) => ReplyTone.values.firstWhere(
        (t) => t.name == value,
        orElse: () => ReplyTone.simple,
      );

  /// Instruction fragment injected into the rewrite prompt.
  String get promptHint => switch (this) {
        ReplyTone.simple =>
          'Use plain, everyday words a busy person reads fast.',
        ReplyTone.warm => 'Sound friendly and personal, but stay brief.',
        ReplyTone.formal => 'Sound respectful and professional.',
        ReplyTone.direct => 'Be short and matter-of-fact. No pleasantries.',
      };

  String get label => switch (this) {
        ReplyTone.simple => 'Simple',
        ReplyTone.warm => 'Warm',
        ReplyTone.formal => 'Formal',
        ReplyTone.direct => 'Direct',
      };
}

/// A term the parent explicitly approved: a name, medicine, place, or
/// organisation that models otherwise mangle.
class GlossaryEntry {
  const GlossaryEntry({
    required this.source,
    required this.target,
    this.pronunciation,
  });

  /// How it is said/written in the parent's language.
  final String source;

  /// The exact spelling that must appear in the English draft.
  final String target;

  /// Optional hint for Bulbul when reading the term aloud.
  final String? pronunciation;

  Map<String, dynamic> toJson() => {
        'source': source,
        'target': target,
        if (pronunciation != null && pronunciation!.isNotEmpty)
          'pronunciation': pronunciation,
      };

  factory GlossaryEntry.fromJson(Map<String, dynamic> json) => GlossaryEntry(
        source: json['source'] as String? ?? '',
        target: json['target'] as String? ?? '',
        pronunciation: json['pronunciation'] as String?,
      );

  bool get isValid => source.trim().isNotEmpty && target.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is GlossaryEntry &&
      other.source == source &&
      other.target == target &&
      other.pronunciation == pronunciation;

  @override
  int get hashCode => Object.hash(source, target, pronunciation);
}

/// The only thing Bhasha persists about the parent. Message contents are
/// deliberately absent.
class ParentProfile {
  const ParentProfile({
    this.inputLanguageCode = 'kn-IN',
    this.replyLanguageCode = 'en-IN',
    this.voiceSpeaker = defaultSpeaker,
    this.pace = 1.0,
    this.tone = ReplyTone.simple,
    this.glossary = const [],
    this.hasSeenPrivacyNotice = false,
  });

  static const String defaultSpeaker = 'Kavya';

  /// Curated subset of documented `bulbul:v3` speakers, kept short so the
  /// settings screen stays scannable for an older user.
  static const List<String> selectableSpeakers = [
    'Kavya',
    'Priya',
    'Shreya',
    'Ritu',
    'Kavitha',
    'Anand',
    'Vijay',
    'Rahul',
  ];

  final String inputLanguageCode;
  final String replyLanguageCode;
  final String voiceSpeaker;

  /// Bulbul `pace`, clamped to the documented 0.5-2.0 range.
  final double pace;
  final ReplyTone tone;
  final List<GlossaryEntry> glossary;
  final bool hasSeenPrivacyNotice;

  ParentProfile copyWith({
    String? inputLanguageCode,
    String? replyLanguageCode,
    String? voiceSpeaker,
    double? pace,
    ReplyTone? tone,
    List<GlossaryEntry>? glossary,
    bool? hasSeenPrivacyNotice,
  }) =>
      ParentProfile(
        inputLanguageCode: inputLanguageCode ?? this.inputLanguageCode,
        replyLanguageCode: replyLanguageCode ?? this.replyLanguageCode,
        voiceSpeaker: voiceSpeaker ?? this.voiceSpeaker,
        pace: pace ?? this.pace,
        tone: tone ?? this.tone,
        glossary: glossary ?? this.glossary,
        hasSeenPrivacyNotice: hasSeenPrivacyNotice ?? this.hasSeenPrivacyNotice,
      );

  Map<String, dynamic> toJson() => {
        'inputLanguageCode': inputLanguageCode,
        'replyLanguageCode': replyLanguageCode,
        'voiceSpeaker': voiceSpeaker,
        'pace': pace,
        'tone': tone.name,
        'glossary': glossary.map((g) => g.toJson()).toList(),
        'hasSeenPrivacyNotice': hasSeenPrivacyNotice,
      };

  factory ParentProfile.fromJson(Map<String, dynamic> json) => ParentProfile(
        inputLanguageCode: json['inputLanguageCode'] as String? ?? 'kn-IN',
        replyLanguageCode: json['replyLanguageCode'] as String? ?? 'en-IN',
        voiceSpeaker: json['voiceSpeaker'] as String? ?? defaultSpeaker,
        pace: (json['pace'] as num?)?.toDouble().clamp(0.5, 2.0) ?? 1.0,
        tone: ReplyTone.fromJson(json['tone'] as String?),
        glossary: (json['glossary'] as List?)
                ?.whereType<Map>()
                .map((g) => GlossaryEntry.fromJson(
                      Map<String, dynamic>.from(g),
                    ))
                .where((g) => g.isValid)
                .toList() ??
            const [],
        hasSeenPrivacyNotice: json['hasSeenPrivacyNotice'] as bool? ?? false,
      );

  String encode() => jsonEncode(toJson());

  static ParentProfile decode(String? raw) {
    if (raw == null || raw.isEmpty) return const ParentProfile();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const ParentProfile();
      return ParentProfile.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException {
      return const ParentProfile();
    }
  }

  /// Glossary rendered for a prompt. Empty string when nothing is saved, so
  /// the prompt does not carry a dangling header.
  String get glossaryPromptBlock {
    final valid = glossary.where((g) => g.isValid).toList();
    if (valid.isEmpty) return '';
    final lines =
        valid.map((g) => '- "${g.source}" must be written as "${g.target}"');
    return 'Known names and terms:\n${lines.join('\n')}';
  }

  @override
  bool operator ==(Object other) =>
      other is ParentProfile &&
      other.inputLanguageCode == inputLanguageCode &&
      other.replyLanguageCode == replyLanguageCode &&
      other.voiceSpeaker == voiceSpeaker &&
      other.pace == pace &&
      other.tone == tone &&
      other.hasSeenPrivacyNotice == hasSeenPrivacyNotice &&
      _listEquals(other.glossary, glossary);

  @override
  int get hashCode => Object.hash(
        inputLanguageCode,
        replyLanguageCode,
        voiceSpeaker,
        pace,
        tone,
        hasSeenPrivacyNotice,
        Object.hashAll(glossary),
      );

  static bool _listEquals(List<GlossaryEntry> a, List<GlossaryEntry> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
