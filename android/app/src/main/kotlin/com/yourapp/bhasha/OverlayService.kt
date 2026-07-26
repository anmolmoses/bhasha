package com.yourapp.bhasha

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.*
import android.widget.*
import android.content.ClipData
import android.content.ClipboardManager
import androidx.core.app.NotificationCompat

class OverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var processingBubble: View? = null
    private var repliesPanel: View? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        private const val CHANNEL_ID = "BhashaOverlayChannel"
        private const val NOTIFICATION_ID = 1
        private var currentActionType: String = "translate"

        fun updateActionType(actionType: String) {
            currentActionType = actionType
        }

        fun getCurrentActionType(): String {
            return currentActionType
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        createFloatingButton()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Bhasha Quick Translate",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Tap the button to instantly translate text"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Bhasha Active")
            .setContentText("Tap floating button for instant translation")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun createFloatingButton() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val displayMetrics = resources.displayMetrics
        val screenHeight = displayMetrics.heightPixels

        // Create simple floating button with icon
        val buttonText = when (getCurrentActionType()) {
            "grammar" -> "G"
            "x_replies" -> "R"
            else -> "T"
        }
        val button = Button(this).apply {
            text = buttonText  // T for Translate, G for Grammar
            textSize = 24f
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            setTextColor(Color.WHITE)
            background = createCircleBackground()
            stateListAnimator = null
            elevation = 12f
            setPadding(0, 0, 0, 0)
        }

        val size = (56 * displayMetrics.density).toInt()
        val params = WindowManager.LayoutParams(
            size,
            size,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = 20
            y = 200
        }

        // Make draggable with dismiss zone
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        val dismissZoneHeight = screenHeight * 0.15  // Bottom 15% of screen

        button.setOnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    params.x = initialX + (initialTouchX - event.rawX).toInt()
                    params.y = initialY + (event.rawY - initialTouchY).toInt()

                    // Visual feedback when in dismiss zone
                    val isInDismissZone = event.rawY > (screenHeight - dismissZoneHeight)
                    if (isInDismissZone) {
                        view.alpha = 0.5f
                        view.scaleX = 0.8f
                        view.scaleY = 0.8f
                    } else {
                        view.alpha = 1f
                        view.scaleX = 1f
                        view.scaleY = 1f
                    }

                    windowManager?.updateViewLayout(button, params)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    // Reset visual state
                    view.alpha = 1f
                    view.scaleX = 1f
                    view.scaleY = 1f

                    val deltaX = kotlin.math.abs(event.rawX - initialTouchX)
                    val deltaY = kotlin.math.abs(event.rawY - initialTouchY)

                    // Check if dropped in dismiss zone
                    if (event.rawY > (screenHeight - dismissZoneHeight)) {
                        // Dismiss the floating button
                        showToast("Floating button dismissed")
                        stopSelf()
                    } else if (deltaX < 10 && deltaY < 10) {
                        // It's a click, not a drag
                        performOverlayAction()
                    }
                    true
                }
                else -> false
            }
        }

        windowManager?.addView(button, params)
        floatingView = button
    }

    private fun createCircleBackground(): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            colors = intArrayOf(
                Color.parseColor("#5E72E4"),  // Blue gradient
                Color.parseColor("#825EE4")
            )
            gradientType = GradientDrawable.LINEAR_GRADIENT
        }
    }

    /**
     * ONE-CLICK ACTION WORKFLOW
     * 1. Get text from focused input field (via accessibility service)
     * 2. Send to Flutter for processing (translation or grammar check)
     * 3. Replace text back in the input field
     * 4. Show success toast
     */
    private fun performOverlayAction() {
        val accessibilityService = BhashaAccessibilityService.getInstance()

        if (accessibilityService == null) {
            showToast("⚠️ Enable accessibility service in Settings → Bhasha")
            openAccessibilitySettings()
            return
        }

        val actionType = getCurrentActionType()
        if (actionType == "x_replies") {
            performXReplySuggestion(accessibilityService)
            return
        }

        // Step 1: Get text from focused field
        val originalText = accessibilityService.getTextFromFocusedField()

        if (originalText.isNullOrEmpty()) {
            showToast("No text found. Tap in a text field first.")
            return
        }

        // Show loading state
        showProcessingBubble(actionType)

        // Step 2: Send to Flutter for processing
        MainActivity.processOverlayAction(
            action = actionType,
            text = originalText
        ) { success, data, error ->
            mainHandler.post {
                hideProcessingBubble()

                if (success && data != null) {
                    val resultText = data["resultText"] as? String
                    if (resultText != null) {
                        // Step 3: Replace text in field
                        val replaced = accessibilityService.replaceTextInFocusedField(resultText)
                        if (replaced) {
                            val successMsg = if (actionType == "grammar") "✓ Grammar checked!" else "✓ Translated!"
                            showToast(successMsg)
                        } else {
                            showToast("✗ Couldn't replace text")
                        }
                    } else {
                        val failMsg = if (actionType == "grammar") "✗ Grammar check failed" else "✗ Translation failed"
                        showToast(failMsg)
                    }
                } else {
                    val failMsg = if (actionType == "grammar") "Grammar check failed" else "Translation failed"
                    showToast("✗ ${error ?: failMsg}")
                }
            }
        }
    }

    private fun performXReplySuggestion(accessibilityService: BhashaAccessibilityService) {
        hideRepliesPanel()
        showProcessingBubble("x_replies")
        accessibilityService.takeScreenshotBase64 { screenshotBase64, screenshotError ->
            if (screenshotBase64 == null) {
                mainHandler.post {
                    hideProcessingBubble()
                    showToast("✗ ${screenshotError ?: "Could not capture screen"}")
                }
                return@takeScreenshotBase64
            }

            MainActivity.processOverlayAction(
                action = "x_replies",
                text = "",
                screenshotBase64 = screenshotBase64
            ) { success, data, error ->
                mainHandler.post {
                    hideProcessingBubble()
                    if (success && data != null) {
                        val replies = (data["replies"] as? List<*>)?.mapNotNull {
                            it as? String
                        }.orEmpty()
                        if (replies.isNotEmpty()) {
                            showRepliesPanel(replies)
                        } else {
                            showToast("✗ No replies generated")
                        }
                    } else {
                        showToast("✗ ${error ?: "Reply suggestions failed"}")
                    }
                }
            }
        }
    }

    private fun openAccessibilitySettings() {
        try {
            val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback - open main settings
            val intent = Intent(android.provider.Settings.ACTION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        }
    }

    private fun showToast(message: String) {
        mainHandler.post {
            Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
        }
    }

    private fun showProcessingBubble(actionType: String = "translate") {
        if (processingBubble != null) return

        val bubble = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 48f
                setColor(Color.parseColor("#2D3748"))
            }
            elevation = 8f
            setPadding(32, 24, 32, 24)
        }

        val progressBar = ProgressBar(this).apply {
            val size = (24 * resources.displayMetrics.density).toInt()
            layoutParams = LinearLayout.LayoutParams(size, size)
            indeterminateTintList = android.content.res.ColorStateList.valueOf(Color.WHITE)
        }

        val messageText = when (actionType) {
            "grammar" -> "Checking grammar..."
            "x_replies" -> "Reading post..."
            else -> "Translating..."
        }
        val text = TextView(this).apply {
            text = messageText
            setTextColor(Color.WHITE)
            textSize = 14f
            typeface = Typeface.create("sans-serif", Typeface.NORMAL)
            setPadding(24, 0, 0, 0)
        }

        bubble.addView(progressBar)
        bubble.addView(text)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = 180
            y = 200
        }

        windowManager?.addView(bubble, params)
        processingBubble = bubble
    }

    private fun hideProcessingBubble() {
        processingBubble?.let {
            windowManager?.removeView(it)
            processingBubble = null
        }
    }

    private fun showRepliesPanel(replies: List<String>) {
        hideRepliesPanel()

        val displayMetrics = resources.displayMetrics
        val panelWidth = (displayMetrics.widthPixels * 0.9f).toInt()
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 28f
                setColor(Color.WHITE)
                setStroke(2, Color.parseColor("#E2E8F0"))
            }
            elevation = 14f
            setPadding(28, 24, 28, 20)
        }

        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val title = TextView(this).apply {
            text = "Suggested replies"
            setTextColor(Color.parseColor("#1A202C"))
            textSize = 16f
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        val close = TextView(this).apply {
            text = "Close"
            setTextColor(Color.parseColor("#5E72E4"))
            textSize = 14f
            setPadding(18, 8, 0, 8)
            setOnClickListener { hideRepliesPanel() }
        }
        header.addView(title)
        header.addView(close)
        panel.addView(header)

        replies.forEachIndexed { index, reply ->
            val item = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(0, 18, 0, 0)
            }
            val replyText = TextView(this).apply {
                text = reply
                setTextColor(Color.parseColor("#2D3748"))
                textSize = 14f
                setLineSpacing(2f, 1.05f)
            }
            val copyButton = Button(this).apply {
                text = "Copy ${index + 1}"
                textSize = 13f
                setTextColor(Color.WHITE)
                background = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = 18f
                    setColor(Color.parseColor("#5E72E4"))
                }
                setOnClickListener {
                    copyToClipboard(reply)
                    showToast("Copied reply")
                }
            }
            item.addView(replyText)
            item.addView(copyButton)
            panel.addView(item)
        }

        val params = WindowManager.LayoutParams(
            panelWidth,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            x = 0
            y = 48
        }

        windowManager?.addView(panel, params)
        repliesPanel = panel
    }

    private fun hideRepliesPanel() {
        repliesPanel?.let {
            windowManager?.removeView(it)
            repliesPanel = null
        }
    }

    private fun copyToClipboard(text: String) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("Bhasha X reply", text))
    }

    override fun onDestroy() {
        super.onDestroy()
        floatingView?.let {
            windowManager?.removeView(it)
        }
        hideProcessingBubble()
        hideRepliesPanel()
    }
}
