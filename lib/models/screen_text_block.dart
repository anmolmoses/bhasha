class ScreenTextBlock {
  const ScreenTextBlock({
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final String text;

  /// Coordinates normalized to a 0-1000 canvas by the OCR model.
  final double x;
  final double y;
  final double width;
  final double height;

  factory ScreenTextBlock.fromJson(Map<String, dynamic> json) {
    double coordinate(String key) {
      final value = json[key];
      if (value is num) {
        return value.toDouble().clamp(0, 1000).toDouble();
      }
      return double.parse(value.toString()).clamp(0, 1000).toDouble();
    }

    return ScreenTextBlock(
      text: (json['text'] ?? '').toString().trim(),
      x: coordinate('x'),
      y: coordinate('y'),
      width: coordinate('width'),
      height: coordinate('height'),
    );
  }

  Map<String, dynamic> toJson({String? translatedText}) => {
        'originalText': text,
        if (translatedText != null) 'translatedText': translatedText,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };
}
