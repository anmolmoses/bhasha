package com.yourapp.bhasha

import android.graphics.Rect

/**
 * Ephemeral geometry used to re-find a WhatsApp message after the long-press.
 *
 * Raw message text is deliberately not retained here. The fingerprint only
 * lives in memory and is discarded when the contextual overlay closes.
 */
data class MessageAnchor(
    val packageName: String,
    val sourceLabel: String,
    val windowId: Int,
    val rowBounds: Rect,
    val textBounds: Rect,
    val textFingerprint: String,
    val observedAtMillis: Long,
    val isOutgoing: Boolean,
)

data class ResolvedMessage(
    val anchor: MessageAnchor,
    val text: String,
)

/**
 * One on-screen run of text and where it sits, read from the accessibility
 * tree rather than OCR.
 *
 * Sarvam Vision cannot segment a screen drawn over a photo background (a
 * WhatsApp chat wallpaper): it reports the whole conversation as a single
 * picture region and captions it. Reading the nodes directly gives exact
 * bounds, the real text, and no screenshot round trip.
 */
data class ScreenTextNode(
    val text: String,
    val bounds: Rect,
)
