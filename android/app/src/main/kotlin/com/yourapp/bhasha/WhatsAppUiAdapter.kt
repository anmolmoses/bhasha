package com.yourapp.bhasha

import android.graphics.Rect
import android.view.accessibility.AccessibilityNodeInfo
import java.security.MessageDigest
import kotlin.math.abs

/**
 * All WhatsApp-specific hierarchy knowledge is isolated here so a WhatsApp
 * update can disable this adapter without affecting the general Bhasha bubble.
 */
object WhatsAppUiAdapter {
    const val PACKAGE_NAME = "com.whatsapp"

    private const val CONVERSATION_ROOT_ID =
        "com.whatsapp:id/conversation_root_layout"
    private const val MESSAGE_ROW_ID = "com.whatsapp:id/main_layout"
    private const val MESSAGE_TEXT_ID = "com.whatsapp:id/message_text"
    private const val COMPOSER_ID = "com.whatsapp:id/entry"
    private const val FOOTER_ID = "com.whatsapp:id/footer"
    private const val OUTGOING_STATUS_ID = "com.whatsapp:id/status"

    fun isWhatsAppPackage(packageName: CharSequence?): Boolean =
        packageName?.toString() == PACKAGE_NAME

    fun isConversation(root: AccessibilityNodeInfo): Boolean =
        hasNode(root, CONVERSATION_ROOT_ID)

    fun resolveLongPressedMessage(
        source: AccessibilityNodeInfo?,
        screenWidth: Int,
    ): ResolvedMessage? {
        if (source == null) return null

        // WhatsApp versions differ on which node emits TYPE_VIEW_LONG_CLICKED.
        // Some emit from inside main_layout; current builds emit from the
        // outer RecyclerView row that contains main_layout.
        val row = findAncestorByViewId(source, MESSAGE_ROW_ID)
            ?: findDescendantByViewId(source, MESSAGE_ROW_ID)
            ?: return null
        try {
            return resolvedMessageFromRow(row, screenWidth)
        } finally {
            row.recycle()
        }
    }

    fun resolveAnchor(
        root: AccessibilityNodeInfo,
        anchor: MessageAnchor,
        screenWidth: Int,
        tolerancePx: Int,
    ): ResolvedMessage? {
        if (root.packageName?.toString() != anchor.packageName) return null

        val textNodes = root.findAccessibilityNodeInfosByViewId(MESSAGE_TEXT_ID)
        var best: ResolvedMessage? = null
        var bestDistance = Int.MAX_VALUE

        for (textNode in textNodes) {
            val text = textNode.text?.toString()?.trim().orEmpty()
            if (text.isEmpty() || fingerprint(text) != anchor.textFingerprint) {
                textNode.recycle()
                continue
            }

            val row = findAncestorByViewId(textNode, MESSAGE_ROW_ID)
            textNode.recycle()
            if (row == null) continue

            try {
                if (row.windowId != anchor.windowId) continue
                val candidate = resolvedMessageFromRow(row, screenWidth) ?: continue
                val distance =
                    abs(candidate.anchor.rowBounds.centerX() - anchor.rowBounds.centerX()) +
                        abs(candidate.anchor.rowBounds.centerY() - anchor.rowBounds.centerY())
                if (distance < bestDistance) {
                    best = candidate
                    bestDistance = distance
                }
            } finally {
                row.recycle()
            }
        }

        return best?.takeIf { bestDistance <= tolerancePx }
    }

    fun messageRowBounds(root: AccessibilityNodeInfo): List<Rect> {
        val rows = root.findAccessibilityNodeInfosByViewId(MESSAGE_ROW_ID)
        return rows.mapNotNull { row ->
            try {
                val bounds = Rect()
                row.getBoundsInScreen(bounds)
                bounds.takeUnless { it.isEmpty }
            } finally {
                row.recycle()
            }
        }
    }

    fun footerBounds(root: AccessibilityNodeInfo): Rect? =
        firstBounds(root, FOOTER_ID)

    /**
     * Every visible message bubble in the open conversation, with its exact
     * on-screen bounds. Used by double-tap screen translation, which cannot
     * rely on OCR here because the chat wallpaper defeats layout detection.
     */
    fun visibleMessageTextNodes(
        root: AccessibilityNodeInfo,
    ): List<ScreenTextNode> {
        val nodes = root.findAccessibilityNodeInfosByViewId(MESSAGE_TEXT_ID)
        return nodes.mapNotNull { node ->
            try {
                val text = node.text?.toString()?.trim().orEmpty()
                if (text.isEmpty() || !node.isVisibleToUser) return@mapNotNull null
                val bounds = Rect()
                node.getBoundsInScreen(bounds)
                if (bounds.isEmpty) return@mapNotNull null
                ScreenTextNode(text, bounds)
            } finally {
                node.recycle()
            }
        }
    }

    fun setComposerText(root: AccessibilityNodeInfo, text: String): Boolean {
        val nodes = root.findAccessibilityNodeInfosByViewId(COMPOSER_ID)
        val composer = nodes.firstOrNull { it.isEditable }
        nodes.filter { it !== composer }.forEach { it.recycle() }
        if (composer == null) return false

        return try {
            val arguments = android.os.Bundle().apply {
                putCharSequence(
                    AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                    text,
                )
            }
            composer.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
        } finally {
            composer.recycle()
        }
    }

    private fun resolvedMessageFromRow(
        row: AccessibilityNodeInfo,
        screenWidth: Int,
    ): ResolvedMessage? {
        val textNodes = row.findAccessibilityNodeInfosByViewId(MESSAGE_TEXT_ID)
        val textNode = textNodes.firstOrNull {
            !it.text?.toString()?.trim().isNullOrEmpty()
        }
        textNodes.filter { it !== textNode }.forEach { it.recycle() }
        if (textNode == null) return null

        return try {
            val text = textNode.text?.toString()?.trim().orEmpty()
            if (text.isEmpty()) return null

            val rowBounds = Rect()
            val textBounds = Rect()
            row.getBoundsInScreen(rowBounds)
            textNode.getBoundsInScreen(textBounds)
            if (rowBounds.isEmpty || textBounds.isEmpty || !row.isVisibleToUser) {
                return null
            }

            val outgoing = hasNode(row, OUTGOING_STATUS_ID) ||
                rowBounds.centerX() > screenWidth / 2
            ResolvedMessage(
                anchor = MessageAnchor(
                    packageName = PACKAGE_NAME,
                    sourceLabel = "WhatsApp",
                    windowId = row.windowId,
                    rowBounds = Rect(rowBounds),
                    textBounds = Rect(textBounds),
                    textFingerprint = fingerprint(text),
                    observedAtMillis = System.currentTimeMillis(),
                    isOutgoing = outgoing,
                ),
                text = text,
            )
        } finally {
            textNode.recycle()
        }
    }

    private fun findAncestorByViewId(
        start: AccessibilityNodeInfo,
        viewId: String,
    ): AccessibilityNodeInfo? {
        var current: AccessibilityNodeInfo? = AccessibilityNodeInfo.obtain(start)
        while (current != null) {
            if (current.viewIdResourceName == viewId) return current
            val parent = current.parent
            current.recycle()
            current = parent
        }
        return null
    }

    private fun findDescendantByViewId(
        root: AccessibilityNodeInfo,
        viewId: String,
    ): AccessibilityNodeInfo? {
        val nodes = root.findAccessibilityNodeInfosByViewId(viewId)
        val first = nodes.firstOrNull()
        nodes.drop(1).forEach { it.recycle() }
        return first
    }

    private fun hasNode(root: AccessibilityNodeInfo, viewId: String): Boolean {
        val nodes = root.findAccessibilityNodeInfosByViewId(viewId)
        val found = nodes.isNotEmpty()
        nodes.forEach { it.recycle() }
        return found
    }

    private fun firstBounds(
        root: AccessibilityNodeInfo,
        viewId: String,
    ): Rect? {
        val nodes = root.findAccessibilityNodeInfosByViewId(viewId)
        val first = nodes.firstOrNull()
        val bounds = first?.let {
            Rect().also(it::getBoundsInScreen).takeUnless(Rect::isEmpty)
        }
        nodes.forEach { it.recycle() }
        return bounds
    }

    private fun fingerprint(text: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(text.toByteArray(Charsets.UTF_8))
        return digest.joinToString(separator = "") { "%02x".format(it) }
    }
}
