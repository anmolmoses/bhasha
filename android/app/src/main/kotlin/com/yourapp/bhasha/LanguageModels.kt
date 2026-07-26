package com.yourapp.bhasha

/** One entry of the language list Dart pushes down for the overlay picker. */
data class LanguageOption(
    val code: String,
    val name: String,
    /** Fits the bubble's chip, where the full name will not: `KN`, `KOK`. */
    val shortLabel: String,
)

/**
 * The two languages the parent works between.
 *
 * With [autoFlip] on there is no fixed direction: Dart translates whatever was
 * written into the side it is not already in.
 */
data class LanguagePair(
    val sourceName: String,
    val targetName: String,
    val autoFlip: Boolean,
) {
    /** True before the app has ever pushed its settings down. */
    val isUnset: Boolean
        get() = sourceName.isEmpty() || targetName.isEmpty()
}
