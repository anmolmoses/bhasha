package com.yourapp.bhasha

import android.content.Context

/**
 * Parent-facing strings for the overlay, in the parent's own language.
 *
 * Keyed off the language the parent picked in Bhasha (the saved source
 * language), not the device locale: the declared user reads Kannada on a
 * phone that is very likely set to English. Only Kannada is translated;
 * every other language falls back to English rather than a mixed UI.
 *
 * The saved value is read from Flutter's SharedPreferences file directly so
 * the overlay never needs a Dart round trip just to pick a toast language.
 */
object OverlayStrings {

    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val SOURCE_LANGUAGE_KEY = "flutter.source_language"

    private fun parentReadsKannada(context: Context): Boolean {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        // Kannada is also the default when nothing has been saved yet.
        return (prefs.getString(SOURCE_LANGUAGE_KEY, "Kannada") ?: "Kannada") == "Kannada"
    }

    fun get(context: Context, key: String): String {
        val table = if (parentReadsKannada(context)) KANNADA else ENGLISH
        return table[key] ?: ENGLISH[key] ?: key
    }

    private val ENGLISH = mapOf(
        "notification_idle" to "Tap to translate · hold to speak",
        "notification_idle_no_voice" to "Tap to translate",
        "notification_listening" to "Listening…",
        "listening_speak_now" to "Listening… speak now",
        "listening_elapsed" to "Listening… %ds",
        "listening_remaining" to "Listening… %ds left",
        "translating_speech" to "Translating what you said…",
        "translating" to "Translating…",
        "checking_grammar" to "Checking grammar…",
        "added_to_message" to "✓ Added to your message",
        "tap_message_box" to "✗ Tap in the message box first",
        "translated" to "✓ Translated!",
        "grammar_checked" to "✓ Grammar checked!",
        "couldnt_replace" to "✗ Couldn't replace text",
        "translation_failed" to "Translation failed",
        "grammar_failed" to "Grammar check failed",
        "voice_failed" to "Could not translate what you said",
        "undo" to "Undo",
        "restored" to "✓ Text restored",
        "restore_failed" to "✗ Could not restore the text",
        "no_text_found" to "No text found. Tap in a text field, or hold to speak.",
        "hold_while_speaking" to "Hold the button while you speak",
        "limit_reached" to "That's the 30-second limit — translating what I heard",
        "enable_accessibility" to "⚠️ Enable accessibility service in Settings → Bhasha",
        "allow_microphone" to "Allow the microphone in Bhasha, then hold again",
        "mic_failed" to "✗ Could not start the microphone",
        "hold_to_speak_disabled" to "Hold to speak is off in Bhasha Settings",
        "bubble_dismissed" to "Floating button dismissed",
        "cancelled" to "Cancelled"
    )

    private val KANNADA = mapOf(
        "notification_idle" to "ಅನುವಾದಕ್ಕೆ ಟ್ಯಾಪ್ ಮಾಡಿ · ಮಾತನಾಡಲು ಹಿಡಿದುಕೊಳ್ಳಿ",
        "notification_idle_no_voice" to "ಅನುವಾದಕ್ಕೆ ಟ್ಯಾಪ್ ಮಾಡಿ",
        "notification_listening" to "ಕೇಳುತ್ತಿದ್ದೇನೆ…",
        "listening_speak_now" to "ಕೇಳುತ್ತಿದ್ದೇನೆ… ಈಗ ಮಾತನಾಡಿ",
        "listening_elapsed" to "ಕೇಳುತ್ತಿದ್ದೇನೆ… %d ಸೆ",
        "listening_remaining" to "ಕೇಳುತ್ತಿದ್ದೇನೆ… %d ಸೆ ಉಳಿದಿದೆ",
        "translating_speech" to "ನೀವು ಹೇಳಿದ್ದನ್ನು ಅನುವಾದಿಸುತ್ತಿದ್ದೇನೆ…",
        "translating" to "ಅನುವಾದಿಸುತ್ತಿದ್ದೇನೆ…",
        "checking_grammar" to "ವ್ಯಾಕರಣ ಪರಿಶೀಲಿಸುತ್ತಿದ್ದೇನೆ…",
        "added_to_message" to "✓ ನಿಮ್ಮ ಸಂದೇಶಕ್ಕೆ ಸೇರಿಸಲಾಗಿದೆ",
        "tap_message_box" to "✗ ಮೊದಲು ಸಂದೇಶ ಪೆಟ್ಟಿಗೆಯಲ್ಲಿ ಟ್ಯಾಪ್ ಮಾಡಿ",
        "translated" to "✓ ಅನುವಾದವಾಗಿದೆ!",
        "grammar_checked" to "✓ ವ್ಯಾಕರಣ ಸರಿಪಡಿಸಲಾಗಿದೆ!",
        "couldnt_replace" to "✗ ಪಠ್ಯ ಬದಲಾಯಿಸಲು ಆಗಲಿಲ್ಲ",
        "translation_failed" to "ಅನುವಾದ ವಿಫಲವಾಗಿದೆ",
        "grammar_failed" to "ವ್ಯಾಕರಣ ಪರಿಶೀಲನೆ ವಿಫಲವಾಗಿದೆ",
        "voice_failed" to "ನೀವು ಹೇಳಿದ್ದನ್ನು ಅನುವಾದಿಸಲು ಆಗಲಿಲ್ಲ",
        "undo" to "ರದ್ದುಮಾಡಿ",
        "restored" to "✓ ಹಿಂದಿನ ಪಠ್ಯ ಮರಳಿದೆ",
        "restore_failed" to "✗ ಪಠ್ಯವನ್ನು ಮರಳಿಸಲು ಆಗಲಿಲ್ಲ",
        "no_text_found" to "ಪಠ್ಯ ಸಿಗಲಿಲ್ಲ. ಪಠ್ಯ ಕ್ಷೇತ್ರದಲ್ಲಿ ಟ್ಯಾಪ್ ಮಾಡಿ, ಅಥವಾ ಮಾತನಾಡಲು ಹಿಡಿದುಕೊಳ್ಳಿ.",
        "hold_while_speaking" to "ಮಾತನಾಡುವಾಗ ಗುಂಡಿಯನ್ನು ಹಿಡಿದುಕೊಳ್ಳಿ",
        "limit_reached" to "30 ಸೆಕೆಂಡ್ ಮಿತಿ ಮುಗಿಯಿತು — ಕೇಳಿದ್ದನ್ನು ಅನುವಾದಿಸುತ್ತಿದ್ದೇನೆ",
        "enable_accessibility" to "⚠️ Settings → Bhasha ನಲ್ಲಿ ಆಕ್ಸೆಸಿಬಿಲಿಟಿ ಸೇವೆಯನ್ನು ಆನ್ ಮಾಡಿ",
        "allow_microphone" to "Bhasha ದಲ್ಲಿ ಮೈಕ್ರೊಫೋನ್‌ಗೆ ಅನುಮತಿ ನೀಡಿ, ನಂತರ ಮತ್ತೆ ಹಿಡಿದುಕೊಳ್ಳಿ",
        "mic_failed" to "✗ ಮೈಕ್ರೊಫೋನ್ ಪ್ರಾರಂಭಿಸಲು ಆಗಲಿಲ್ಲ",
        "hold_to_speak_disabled" to "Bhasha Settings ನಲ್ಲಿ ಮಾತನಾಡಲು ಹಿಡಿದುಕೊಳ್ಳುವ ಆಯ್ಕೆ ಆಫ್ ಆಗಿದೆ",
        "bubble_dismissed" to "ತೇಲುವ ಗುಂಡಿಯನ್ನು ತೆಗೆದುಹಾಕಲಾಗಿದೆ",
        "cancelled" to "ರದ್ದುಗೊಳಿಸಲಾಗಿದೆ"
    )
}
