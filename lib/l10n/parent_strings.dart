import '../services/storage_service.dart';

/// Kannada renderings of every parent-facing string.
///
/// The target user is defined by not reading English comfortably, so the
/// messages shown at the moment something goes wrong are exactly the ones
/// that must not be in English. Localization is keyed off the parent's own
/// language (the saved source language), not the device locale: a parent on a
/// hand-me-down phone set to English still gets Kannada errors.
///
/// Only Kannada is translated for now - it is the declared user's language.
/// Every other language falls back to the English original rather than a
/// half-translated mix.
class ParentStrings {
  ParentStrings._();

  static bool get useKannada =>
      StorageService().getSourceLanguage() == 'Kannada';

  /// Returns the Kannada rendering of [english] when the parent's language is
  /// Kannada and a translation exists; the original otherwise.
  static String localize(String english) =>
      useKannada ? (kannada[english] ?? english) : english;

  /// Keyed by the exact English string, so a copy edit that forgets this table
  /// fails visibly (the English shows through) instead of silently drifting.
  static const Map<String, String> kannada = {
    // SarvamException.parentMessage strings.
    'Bhasha could not read that. Please try again.':
        'Bhasha ಗೆ ಅದನ್ನು ಓದಲು ಆಗಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
    'Bhasha could not translate that. Please try again.':
        'Bhasha ಗೆ ಅದನ್ನು ಅನುವಾದಿಸಲು ಆಗಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
    'Bhasha could not speak that. Please try again.':
        'Bhasha ಗೆ ಅದನ್ನು ಓದಿ ಹೇಳಲು ಆಗಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
    'Bhasha could not finish that. Please try again.':
        'Bhasha ಗೆ ಅದನ್ನು ಮುಗಿಸಲು ಆಗಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
    'Bhasha could not process that. Please try again.':
        'Bhasha ಗೆ ಅದನ್ನು ಪ್ರಕ್ರಿಯೆಗೊಳಿಸಲು ಆಗಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
    'Bhasha got an unexpected reply. Please try again.':
        'Bhasha ಗೆ ಅನಿರೀಕ್ಷಿತ ಉತ್ತರ ಬಂದಿದೆ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
    'Your Sarvam key was not accepted. Check it in Settings.':
        'ನಿಮ್ಮ Sarvam ಕೀ ಸ್ವೀಕೃತವಾಗಲಿಲ್ಲ. Settings ನಲ್ಲಿ ಪರಿಶೀಲಿಸಿ.',
    'That was too long. Please try a shorter message.':
        'ಅದು ತುಂಬಾ ಉದ್ದವಾಗಿತ್ತು. ದಯವಿಟ್ಟು ಚಿಕ್ಕ ಸಂದೇಶ ಪ್ರಯತ್ನಿಸಿ.',
    'Too many requests just now. Wait a moment and retry.':
        'ಈಗ ತುಂಬಾ ವಿನಂತಿಗಳಿವೆ. ಸ್ವಲ್ಪ ಕಾದು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
    'Sarvam is having trouble. Please try again.':
        'Sarvam ನಲ್ಲಿ ತೊಂದರೆ ಇದೆ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
    'Something went wrong. Please try again.':
        'ಏನೋ ತಪ್ಪಾಗಿದೆ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
    'Add your Sarvam key in Bhasha settings first.':
        'ಮೊದಲು Bhasha settings ನಲ್ಲಿ ನಿಮ್ಮ Sarvam ಕೀ ಸೇರಿಸಿ.',
    'No internet. Your text has not been changed.':
        'ಇಂಟರ್ನೆಟ್ ಇಲ್ಲ. ನಿಮ್ಮ ಪಠ್ಯ ಬದಲಾಗಿಲ್ಲ.',
    'That took too long. Your text has not been changed.':
        'ಅದು ತುಂಬಾ ಸಮಯ ತೆಗೆದುಕೊಂಡಿತು. ನಿಮ್ಮ ಪಠ್ಯ ಬದಲಾಗಿಲ್ಲ.',
    'Cancelled.': 'ರದ್ದುಗೊಳಿಸಲಾಗಿದೆ.',
    'I did not hear anything. Hold the button and speak.':
        'ನನಗೆ ಏನೂ ಕೇಳಿಸಲಿಲ್ಲ. ಗುಂಡಿ ಹಿಡಿದು ಮಾತನಾಡಿ.',
    'I could not find a message to read. Select the message and try again.':
        'ಓದಲು ಸಂದೇಶ ಸಿಗಲಿಲ್ಲ. ಸಂದೇಶ ಆಯ್ಕೆ ಮಾಡಿ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
    'This app does not allow Bhasha to change the text here.':
        'ಈ ಆ್ಯಪ್ ಇಲ್ಲಿ ಪಠ್ಯ ಬದಲಾಯಿಸಲು Bhasha ಗೆ ಅವಕಾಶ ನೀಡುವುದಿಲ್ಲ.',
    'Nothing to read aloud.': 'ಓದಿ ಹೇಳಲು ಏನೂ ಇಲ್ಲ.',

    // Overlay handler request-validation strings.
    'Tap in a text field with some text first.':
        'ಮೊದಲು ಪಠ್ಯ ಇರುವ ಕ್ಷೇತ್ರದಲ್ಲಿ ಟ್ಯಾಪ್ ಮಾಡಿ.',
    'No recording was captured. Hold the button and speak.':
        'ಧ್ವನಿ ದಾಖಲಾಗಲಿಲ್ಲ. ಗುಂಡಿ ಹಿಡಿದು ಮಾತನಾಡಿ.',
    'Hold to speak is turned off in Bhasha Settings.':
        'Bhasha Settings ನಲ್ಲಿ ಮಾತನಾಡಲು ಹಿಡಿದುಕೊಳ್ಳುವ ಆಯ್ಕೆಯನ್ನು ಆಫ್ ಮಾಡಲಾಗಿದೆ.',
    'Add your Sarvam API key in Bhasha settings before using the bubble.':
        'ಬಬಲ್ ಬಳಸುವ ಮೊದಲು Bhasha settings ನಲ್ಲಿ ನಿಮ್ಮ Sarvam API ಕೀ ಸೇರಿಸಿ.',
  };
}
