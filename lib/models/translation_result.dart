class TranslationResult {
  final String originalText;
  final String translatedText;
  final String sourceLang;
  final String targetLang;
  final DateTime timestamp;

  TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.sourceLang,
    required this.targetLang,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'originalText': originalText,
        'translatedText': translatedText,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
        'timestamp': timestamp.toIso8601String(),
      };

  factory TranslationResult.fromJson(Map<String, dynamic> json) =>
      TranslationResult(
        originalText: json['originalText'] as String,
        translatedText: json['translatedText'] as String,
        sourceLang: json['sourceLang'] as String,
        targetLang: json['targetLang'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
