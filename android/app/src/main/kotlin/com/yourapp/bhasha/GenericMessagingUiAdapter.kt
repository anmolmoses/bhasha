package com.yourapp.bhasha

import android.graphics.Rect
import android.os.Bundle
import android.view.accessibility.AccessibilityNodeInfo
import java.security.MessageDigest
import kotlin.math.abs

/**
 * Conservative fallback for apps without a dedicated UI adapter.
 *
 * It never takes screenshots. It only accepts visible, non-editable,
 * non-password text exposed by Android Accessibility after an explicit
 * long-press. Dedicated adapters such as WhatsApp remain more precise.
 */
object GenericMessagingUiAdapter {
    private const val MAX_TEXT_LENGTH = 8_000
    private const val MAX_VISITED_NODES = 600

    private val blockedPackages = setOf(
        "android",
        "com.android.systemui",
        "com.android.settings",
        "com.google.android.permissioncontroller",
        "com.android.permissioncontroller",
        "com.google.android.packageinstaller",
    )

    fun isEligiblePackage(packageName: String, ownPackageName: String): Boolean =
        packageName.isNotBlank() &&
            packageName != ownPackageName &&
            packageName !in blockedPackages

    fun resolveLongPressedText(
        source: AccessibilityNodeInfo?,
        packageName: String,
        sourceLabel: String,
        screenWidth: Int,
    ): ResolvedMessage? {
        if (source == null) return null

        val candidate = bestTextCandidate(source) ?: return null
        val sourceBounds = Rect().also(source::getBoundsInScreen)
        val rowBounds = sourceBounds
            .takeUnless(Rect::isEmpty)
            ?.takeIf { it.contains(candidate.bounds) }
            ?: candidate.bounds

        return ResolvedMessage(
            anchor = MessageAnchor(
                packageName = packageName,
                sourceLabel = sourceLabel,
                windowId = source.windowId,
                rowBounds = Rect(rowBounds),
                textBounds = Rect(candidate.bounds),
                textFingerprint = fingerprint(candidate.text),
                observedAtMillis = System.currentTimeMillis(),
                isOutgoing = rowBounds.centerX() > screenWidth / 2,
            ),
            text = candidate.text,
        )
    }

    fun resolveAnchor(
        root: AccessibilityNodeInfo,
        anchor: MessageAnchor,
        tolerancePx: Int,
    ): ResolvedMessage? {
        if (root.packageName?.toString() != anchor.packageName) return null

        var best: TextCandidate? = null
        var bestDistance = Int.MAX_VALUE
        walk(root) { node ->
            val text = eligibleText(node) ?: return@walk
            if (fingerprint(text) != anchor.textFingerprint) return@walk

            val bounds = Rect().also(node::getBoundsInScreen)
            if (bounds.isEmpty) return@walk
            val distance =
                abs(bounds.centerX() - anchor.textBounds.centerX()) +
                    abs(bounds.centerY() - anchor.textBounds.centerY())
            if (distance < bestDistance) {
                best = TextCandidate(text, bounds)
                bestDistance = distance
            }
        }

        val candidate = best ?: return null
        if (bestDistance > tolerancePx) return null
        return ResolvedMessage(
            anchor = anchor.copy(
                rowBounds = Rect(candidate.bounds),
                textBounds = Rect(candidate.bounds),
                observedAtMillis = System.currentTimeMillis(),
            ),
            text = candidate.text,
        )
    }

    /**
     * Every visible run of text on screen with its bounds, for apps that have
     * no dedicated adapter. Leaf nodes only, so a container's concatenated
     * label is not overlaid on top of the rows it already covers.
     */
    fun visibleTextNodes(root: AccessibilityNodeInfo): List<ScreenTextNode> {
        val found = mutableListOf<ScreenTextNode>()
        walk(root) { node ->
            if (node.childCount > 0) return@walk
            val text = eligibleText(node) ?: return@walk
            if (!node.isVisibleToUser || node.isPassword) return@walk
            val bounds = Rect().also(node::getBoundsInScreen)
            if (!bounds.isEmpty) found += ScreenTextNode(text, bounds)
        }
        return found
    }

    fun visibleTextBounds(root: AccessibilityNodeInfo): List<Rect> {
        val bounds = mutableListOf<Rect>()
        walk(root) { node ->
            if (eligibleText(node) == null) return@walk
            val rect = Rect().also(node::getBoundsInScreen)
            if (!rect.isEmpty) bounds += rect
        }
        return bounds
    }

    fun composerBounds(root: AccessibilityNodeInfo): Rect? {
        var best: Rect? = null
        walk(root) { node ->
            if (!isSafeEditable(node)) return@walk
            val bounds = Rect().also(node::getBoundsInScreen)
            if (!bounds.isEmpty && (best == null || bounds.bottom > best!!.bottom)) {
                best = bounds
            }
        }
        return best
    }

    fun setComposerText(root: AccessibilityNodeInfo, text: String): Boolean {
        var focused: AccessibilityNodeInfo? = null
        var lowest: AccessibilityNodeInfo? = null
        var lowestBottom = Int.MIN_VALUE

        walk(root) { node ->
            if (!isSafeEditable(node)) return@walk
            val copy = AccessibilityNodeInfo.obtain(node)
            if (node.isFocused) {
                focused?.recycle()
                focused = copy
                return@walk
            }
            val bounds = Rect().also(node::getBoundsInScreen)
            if (bounds.bottom > lowestBottom) {
                lowest?.recycle()
                lowest = copy
                lowestBottom = bounds.bottom
            } else {
                copy.recycle()
            }
        }

        val composer = focused ?: lowest
        if (focused != null && lowest !== focused) lowest?.recycle()
        if (composer == null) return false

        return try {
            val arguments = Bundle().apply {
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

    private fun bestTextCandidate(root: AccessibilityNodeInfo): TextCandidate? {
        var best: TextCandidate? = null
        walk(root) { node ->
            val text = eligibleText(node) ?: return@walk
            val bounds = Rect().also(node::getBoundsInScreen)
            if (bounds.isEmpty) return@walk
            if (best == null || text.length > best!!.text.length) {
                best = TextCandidate(text, bounds)
            }
        }
        return best
    }

    private fun eligibleText(node: AccessibilityNodeInfo): String? {
        if (!node.isVisibleToUser || node.isEditable || node.isPassword) {
            return null
        }
        val text = node.text?.toString()?.trim().orEmpty()
        return text.takeIf { it.isNotEmpty() && it.length <= MAX_TEXT_LENGTH }
    }

    private fun isSafeEditable(node: AccessibilityNodeInfo): Boolean =
        node.isVisibleToUser && node.isEditable && !node.isPassword

    private fun walk(
        root: AccessibilityNodeInfo,
        visit: (AccessibilityNodeInfo) -> Unit,
    ) {
        var visited = 0

        fun traverse(node: AccessibilityNodeInfo) {
            if (visited++ >= MAX_VISITED_NODES) return
            visit(node)
            for (index in 0 until node.childCount) {
                val child = node.getChild(index) ?: continue
                try {
                    traverse(child)
                } finally {
                    child.recycle()
                }
            }
        }

        traverse(root)
    }

    private fun fingerprint(text: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(text.toByteArray(Charsets.UTF_8))
        return digest.joinToString(separator = "") { "%02x".format(it) }
    }

    private data class TextCandidate(
        val text: String,
        val bounds: Rect,
    )
}
