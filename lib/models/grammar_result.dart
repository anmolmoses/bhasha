class GrammarResult {
  final String originalText;
  final String correctedText;
  final String language;
  final List<String> corrections;
  final DateTime timestamp;

  GrammarResult({
    required this.originalText,
    required this.correctedText,
    required this.language,
    required this.corrections,
    required this.timestamp,
  });

  bool get hasCorrections => originalText != correctedText;

  Map<String, dynamic> toJson() => {
        'originalText': originalText,
        'correctedText': correctedText,
        'language': language,
        'corrections': corrections,
        'timestamp': timestamp.toIso8601String(),
      };

  factory GrammarResult.fromJson(Map<String, dynamic> json) => GrammarResult(
        originalText: json['originalText'] as String,
        correctedText: json['correctedText'] as String,
        language: json['language'] as String,
        corrections: List<String>.from(json['corrections'] as List),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
