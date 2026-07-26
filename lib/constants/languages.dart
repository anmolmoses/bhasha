/// Languages Bhasha can actually process.
///
/// This list is deliberately limited to what Sarvam supports. The previous
/// list carried 35 languages (Spanish, Japanese, Finnish...) that no Sarvam
/// endpoint accepts; offering them only produced failed requests.
class SarvamLanguage {
  const SarvamLanguage(this.name, this.code);

  /// Display name shown in pickers and persisted in preferences.
  final String name;

  /// BCP-47 code sent to Sarvam.
  final String code;

  /// Compact label for the overlay chip, where a full name will not fit:
  /// `kn-IN` becomes `KN`, `kok-IN` becomes `KOK`.
  String get shortLabel => code.split('-').first.toUpperCase();
}

class Languages {
  /// Sarvam's 22 Indian languages plus English.
  ///
  /// Kannada and English lead the list because they are this product's
  /// default pair.
  static const List<SarvamLanguage> all = [
    SarvamLanguage('Kannada', 'kn-IN'),
    SarvamLanguage('English', 'en-IN'),
    SarvamLanguage('Hindi', 'hi-IN'),
    SarvamLanguage('Tamil', 'ta-IN'),
    SarvamLanguage('Telugu', 'te-IN'),
    SarvamLanguage('Malayalam', 'ml-IN'),
    SarvamLanguage('Marathi', 'mr-IN'),
    SarvamLanguage('Bengali', 'bn-IN'),
    SarvamLanguage('Gujarati', 'gu-IN'),
    SarvamLanguage('Punjabi', 'pa-IN'),
    SarvamLanguage('Odia', 'od-IN'),
    SarvamLanguage('Assamese', 'as-IN'),
    SarvamLanguage('Urdu', 'ur-IN'),
    SarvamLanguage('Nepali', 'ne-IN'),
    SarvamLanguage('Konkani', 'kok-IN'),
    SarvamLanguage('Kashmiri', 'ks-IN'),
    SarvamLanguage('Sindhi', 'sd-IN'),
    SarvamLanguage('Sanskrit', 'sa-IN'),
    SarvamLanguage('Santali', 'sat-IN'),
    SarvamLanguage('Manipuri', 'mni-IN'),
    SarvamLanguage('Bodo', 'brx-IN'),
    SarvamLanguage('Maithili', 'mai-IN'),
    SarvamLanguage('Dogri', 'doi-IN'),
  ];

  static const String defaultSourceName = 'Kannada';
  static const String defaultTargetName = 'English';
  static const String defaultSourceCode = 'kn-IN';
  static const String defaultTargetCode = 'en-IN';

  static List<String> get supported =>
      all.map((l) => l.name).toList(growable: false);

  /// Maps a stored display name to a Sarvam language code.
  ///
  /// Returns null for names that are no longer supported, so callers can fall
  /// back explicitly rather than sending an invalid code and getting a 400.
  static String? codeFor(String name) {
    for (final language in all) {
      if (language.name.toLowerCase() == name.toLowerCase()) {
        return language.code;
      }
    }
    return null;
  }

  /// Reverse lookup, used when Sarvam's language identification returns a code
  /// we need to show the parent.
  static String nameFor(String code) {
    for (final language in all) {
      if (language.code.toLowerCase() == code.toLowerCase()) {
        return language.name;
      }
    }
    return code;
  }

  static bool isSupported(String name) => codeFor(name) != null;

  /// True when both codes name the same language, whatever their casing.
  static bool sameLanguage(String a, String b) =>
      a.toLowerCase() == b.toLowerCase();

  static String getDisplayName(String language) => language;
}
