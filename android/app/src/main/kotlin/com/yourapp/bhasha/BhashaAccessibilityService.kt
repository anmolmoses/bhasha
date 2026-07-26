package com.yourapp.bhasha

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class BhashaAccessibilityService : AccessibilityService() {

    companion object {
        private var instance: BhashaAccessibilityService? = null

        fun getInstance(): BhashaAccessibilityService? = instance

        fun isServiceEnabled(): Boolean = instance != null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // We don't need to handle events, just provide the service for text manipulation
    }

    override fun onInterrupt() {
        // Required override
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
    }

    /**
     * Get text from the currently focused input field
     */
    fun getTextFromFocusedField(): String? {
        val rootNode = rootInActiveWindow ?: return null
        val focusedNode = findFocusedEditText(rootNode)
        val text = focusedNode?.let { typedTextOf(it) }
        focusedNode?.recycle()
        rootNode.recycle()
        return text
    }

    /**
     * What the user actually typed, with placeholder text filtered out.
     *
     * An empty field reports its hint through `getText()` - WhatsApp's composer
     * returns "Message" - so reading the node naively makes the placeholder look
     * like real content. Dictation then appends to it ("Message ನಾಳೆ ಬರುತ್ತೇನೆ")
     * and tap-to-translate happily translates the word "Message".
     *
     * `isShowingHintText` is the documented signal, but it only holds for fields
     * that leave hint handling to the framework. WhatsApp still leaked "Message"
     * through with that check in place, so the placeholder is also matched
     * against the labels the node itself publishes - `hintText` and
     * `contentDescription`.
     *
     * The cost of the equality checks is that typing the placeholder word and
     * nothing else ("Message") reads as an empty field, so a dictated phrase
     * replaces it instead of being appended. That is a visible, one-word,
     * recoverable loss in a case that essentially does not occur, weighed
     * against a placeholder that leaks into every voice message.
     *
     * All three signals arrived in API 26. Below that Android offers no way to
     * tell a hint from typed text, so the raw value stands rather than risking
     * dropping something the parent wrote.
     */
    private fun typedTextOf(node: AccessibilityNodeInfo): String {
        val raw = node.text?.toString().orEmpty()
        if (raw.isBlank()) return ""
        if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.O) return raw

        if (node.isShowingHintText) return ""
        if (looksLikePlaceholder(raw, node.hintText)) return ""
        if (looksLikePlaceholder(raw, node.contentDescription)) return ""

        return raw
    }

    /**
     * Whether the field's content is indistinguishable from the label the node
     * publishes for it, which is what an empty composer reports.
     */
    private fun looksLikePlaceholder(text: String, label: CharSequence?): Boolean {
        val candidate = label?.toString()?.trim().orEmpty()
        return candidate.isNotEmpty() && candidate == text.trim()
    }

    /**
     * Replace text in the currently focused input field
     */
    fun replaceTextInFocusedField(newText: String): Boolean {
        val rootNode = rootInActiveWindow ?: return false
        val focusedNode = findFocusedEditText(rootNode)

        val success = if (focusedNode != null) {
            // Select all text
            val arguments = android.os.Bundle()
            arguments.putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, 0)
            arguments.putInt(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT,
                typedTextOf(focusedNode).length
            )
            focusedNode.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, arguments)

            // Set new text
            val setTextArguments = android.os.Bundle()
            setTextArguments.putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                newText
            )
            focusedNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, setTextArguments)
        } else {
            false
        }

        focusedNode?.recycle()
        rootNode.recycle()
        return success
    }

    /**
     * Appends [newText] to the focused input field and leaves the cursor at the
     * end.
     *
     * Dictation appends rather than replaces on purpose: the parent may have
     * already typed part of the message, and losing it to a voice action they
     * are still learning to trust would be unrecoverable.
     */
    fun insertTextInFocusedField(newText: String): Boolean {
        val rootNode = rootInActiveWindow ?: return false
        val focusedNode = findFocusedEditText(rootNode)

        val success = if (focusedNode != null) {
            val existing = typedTextOf(focusedNode)
            val combined = if (existing.isBlank()) {
                newText
            } else {
                "${existing.trimEnd()} $newText"
            }

            val setTextArguments = android.os.Bundle()
            setTextArguments.putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                combined
            )
            val wrote = focusedNode.performAction(
                AccessibilityNodeInfo.ACTION_SET_TEXT,
                setTextArguments
            )

            if (wrote) {
                // Put the caret after what we just added so the parent can keep
                // typing without hunting for the end of the line.
                val caret = android.os.Bundle()
                caret.putInt(
                    AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT,
                    combined.length
                )
                caret.putInt(
                    AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT,
                    combined.length
                )
                focusedNode.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, caret)
            }
            wrote
        } else {
            false
        }

        focusedNode?.recycle()
        rootNode.recycle()
        return success
    }

    private fun findFocusedEditText(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        // First check if current node is focused and editable
        if (node.isFocused && node.isEditable) {
            return node
        }

        // Try to find focused node
        val focusedNode = node.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
        if (focusedNode != null && focusedNode.isEditable) {
            return focusedNode
        }

        // Recursively search children
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val result = findFocusedEditText(child)
            if (result != null) {
                // The child may be the match itself. Recycling it here would
                // hand the caller a node whose text is no longer readable.
                if (result !== child) child.recycle()
                return result
            }
            child.recycle()
        }

        return null
    }
}
