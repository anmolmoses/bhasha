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
        val text = focusedNode?.text?.toString()
        focusedNode?.recycle()
        rootNode.recycle()
        return text
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
                focusedNode.text?.length ?: 0
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
            val existing = focusedNode.text?.toString().orEmpty()
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
                child.recycle()
                return result
            }
            child.recycle()
        }

        return null
    }
}
