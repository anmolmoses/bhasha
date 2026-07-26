package com.yourapp.bhasha

import android.accessibilityservice.AccessibilityService
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.os.Build
import android.util.Base64
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

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

    fun takeScreenshotBase64(callback: (String?, String?) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            callback(null, "Screenshot capture requires Android 11 or newer.")
            return
        }

        val executor = Executors.newSingleThreadExecutor()
        takeScreenshot(
            Display.DEFAULT_DISPLAY,
            executor,
            object : TakeScreenshotCallback {
                override fun onSuccess(screenshot: ScreenshotResult) {
                    try {
                        val hardwareBitmap = Bitmap.wrapHardwareBuffer(
                            screenshot.hardwareBuffer,
                            screenshot.colorSpace
                        )
                        if (hardwareBitmap == null) {
                            callback(null, "Could not read screenshot.")
                            return
                        }

                        val bitmap = hardwareBitmap.copy(Bitmap.Config.ARGB_8888, false)
                        screenshot.hardwareBuffer.close()
                        val output = ByteArrayOutputStream()
                        bitmap.compress(Bitmap.CompressFormat.PNG, 88, output)
                        bitmap.recycle()
                        val encoded = Base64.encodeToString(
                            output.toByteArray(),
                            Base64.NO_WRAP
                        )
                        callback(encoded, null)
                    } catch (e: Exception) {
                        callback(null, e.message ?: "Screenshot capture failed.")
                    } finally {
                        executor.shutdown()
                    }
                }

                override fun onFailure(errorCode: Int) {
                    executor.shutdown()
                    callback(null, "Screenshot capture failed with code $errorCode.")
                }
            }
        )
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
