package com.yourapp.bhasha

import android.Manifest
import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.*
import android.widget.*
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.io.File

class OverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var floatingView: Button? = null
    private var statusBubble: View? = null
    private var statusText: TextView? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val voiceCapture by lazy { VoiceCaptureManager(this) }
    private var holdRunnable: Runnable? = null
    private var gestureConsumed = false

    companion object {
        private const val CHANNEL_ID = "BhashaOverlayChannel"
        private const val NOTIFICATION_ID = 1

        /** How long the button must be held before capture starts. */
        private const val HOLD_THRESHOLD_MS = 350L

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
        startAsOverlayService()
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
                description = "Tap to translate, hold to speak"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(text: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Bhasha Active")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    /**
     * The service runs as `specialUse` normally and adds the `microphone` type
     * only while recording.
     *
     * It has to be done in this order: declaring the microphone type up front
     * would make `startForeground` throw on a device where the parent has not
     * granted RECORD_AUDIO yet, killing the bubble before they ever reach the
     * permission prompt.
     */
    private fun startAsOverlayService() {
        val notification = createNotification("Tap to translate · hold to speak")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun addMicrophoneServiceType() {
        val notification = createNotification("Listening…")
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE ->
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ->
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                )
            else -> startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createFloatingButton() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val displayMetrics = resources.displayMetrics
        val screenHeight = displayMetrics.heightPixels

        val button = Button(this).apply {
            text = idleButtonLabel()
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
        val dragSlop = 10 * displayMetrics.density

        button.setOnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    gestureConsumed = false
                    scheduleHold()
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val movedX = kotlin.math.abs(event.rawX - initialTouchX)
                    val movedY = kotlin.math.abs(event.rawY - initialTouchY)

                    // While recording the button stays put: small hand movements
                    // during speech must not turn into a drag or a dismiss.
                    if (voiceCapture.isRecording) return@setOnTouchListener true

                    if (movedX > dragSlop || movedY > dragSlop) {
                        cancelHold()
                    }

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
                    cancelHold()

                    // Reset visual state
                    view.alpha = 1f
                    view.scaleX = 1f
                    view.scaleY = 1f

                    if (voiceCapture.isRecording) {
                        finishVoiceCapture()
                        return@setOnTouchListener true
                    }
                    if (gestureConsumed) return@setOnTouchListener true

                    val deltaX = kotlin.math.abs(event.rawX - initialTouchX)
                    val deltaY = kotlin.math.abs(event.rawY - initialTouchY)

                    // Check if dropped in dismiss zone
                    if (event.rawY > (screenHeight - dismissZoneHeight)) {
                        // Dismiss the floating button
                        showToast("Floating button dismissed")
                        stopSelf()
                    } else if (deltaX < dragSlop && deltaY < dragSlop) {
                        // It's a click, not a drag
                        performOverlayAction()
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    cancelHold()
                    if (voiceCapture.isRecording) {
                        abortVoiceCapture("Cancelled")
                    }
                    true
                }
                else -> false
            }
        }

        windowManager?.addView(button, params)
        floatingView = button
    }

    private fun idleButtonLabel(): String = when (getCurrentActionType()) {
        "grammar" -> "G"
        else -> "T"
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

    private fun createRecordingBackground(): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            colors = intArrayOf(
                Color.parseColor("#F5365C"),  // Red: recording
                Color.parseColor("#F56036")
            )
            gradientType = GradientDrawable.LINEAR_GRADIENT
        }
    }

    // ---------------------------------------------------------------------
    // Hold to speak
    // ---------------------------------------------------------------------

    private fun scheduleHold() {
        cancelHold()
        val runnable = Runnable { beginVoiceCapture() }
        holdRunnable = runnable
        mainHandler.postDelayed(runnable, HOLD_THRESHOLD_MS)
    }

    private fun cancelHold() {
        holdRunnable?.let { mainHandler.removeCallbacks(it) }
        holdRunnable = null
    }

    /**
     * HOLD-TO-SPEAK WORKFLOW
     * 1. Record the parent's voice while the button is held
     * 2. Send the audio to Dart, which transcribes it and translates it into
     *    the language selected in the Bhasha app
     * 3. Insert the translation into the focused composer
     */
    private fun beginVoiceCapture() {
        holdRunnable = null

        if (BhashaAccessibilityService.getInstance() == null) {
            gestureConsumed = true
            showToast("⚠️ Enable accessibility service in Settings → Bhasha")
            openAccessibilitySettings()
            return
        }

        if (!hasMicPermission()) {
            gestureConsumed = true
            showToast("Allow the microphone in Bhasha, then hold again")
            openAppForMicPermission()
            return
        }

        val started = voiceCapture.start(object : VoiceCaptureManager.Listener {
            override fun onElapsed(millis: Long) {
                updateRecordingStatus(millis)
            }

            override fun onMaxDurationReached() {
                // Never silently discard speech: stop and translate what we have.
                showToast("That's the 30-second limit — translating what I heard")
                finishVoiceCapture()
            }
        })

        if (!started) {
            gestureConsumed = true
            showToast("✗ Could not start the microphone")
            return
        }

        addMicrophoneServiceType()
        vibrate(30)
        floatingView?.apply {
            text = "●"
            background = createRecordingBackground()
        }
        showStatus("Listening… speak now", spinner = false)
    }

    private fun updateRecordingStatus(millis: Long) {
        val remaining = ((VoiceCaptureManager.MAX_DURATION_MS - millis) / 1000).coerceAtLeast(0)
        val message = if (millis >= VoiceCaptureManager.WARN_AFTER_MS) {
            "Listening… ${remaining}s left"
        } else {
            "Listening… ${millis / 1000}s"
        }
        statusText?.text = message
    }

    private fun finishVoiceCapture() {
        val audio = voiceCapture.stop()
        restoreIdleButton()
        vibrate(20)

        if (audio == null) {
            hideStatus()
            showToast("Hold the button while you speak")
            return
        }

        // Rebuild rather than retitle: the listening pill has no spinner, and
        // the parent needs to see that something is now in flight.
        hideStatus()
        showStatus("Translating what you said…", spinner = true)
        BhashaChannel.processOverlayAction(
            action = "voice_translate",
            text = "",
            audioPath = audio.path
        ) { success, data, error ->
            mainHandler.post {
                // Delete on every path — success, failure, and malformed reply
                // alike. Recorded speech must never outlive the request.
                deleteQuietly(audio)
                hideStatus()

                val resultText = data?.get("resultText") as? String
                if (success && !resultText.isNullOrBlank()) {
                    val accessibilityService = BhashaAccessibilityService.getInstance()
                    val inserted =
                        accessibilityService?.insertTextInFocusedField(resultText) == true
                    if (inserted) {
                        showToast("✓ Added to your message")
                    } else {
                        showToast("✗ Tap in the message box first")
                    }
                } else {
                    showToast("✗ ${error ?: "Could not translate what you said"}")
                }
            }
        }
    }

    private fun abortVoiceCapture(reason: String) {
        voiceCapture.cancel()
        restoreIdleButton()
        hideStatus()
        showToast(reason)
    }

    private fun restoreIdleButton() {
        startAsOverlayService()
        floatingView?.apply {
            text = idleButtonLabel()
            background = createCircleBackground()
        }
    }

    private fun hasMicPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    /**
     * A service cannot show a runtime-permission dialog, so send the parent to
     * the app, which asks for the microphone on resume.
     */
    private fun openAppForMicPermission() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra(MainActivity.EXTRA_REQUEST_MIC_PERMISSION, true)
        }
        startActivity(intent)
    }

    private fun deleteQuietly(file: File) {
        try {
            if (file.exists()) file.delete()
        } catch (e: SecurityException) {
            // Cache files are cleaned up by the system if this ever fails.
        }
    }

    private fun vibrate(millis: Long) {
        val vibrator = ContextCompat.getSystemService(this, Vibrator::class.java) ?: return
        if (!vibrator.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(
                VibrationEffect.createOneShot(millis, VibrationEffect.DEFAULT_AMPLITUDE)
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(millis)
        }
    }

    // ---------------------------------------------------------------------
    // Tap to translate the field
    // ---------------------------------------------------------------------

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

        // Step 1: Get text from focused field
        val originalText = accessibilityService.getTextFromFocusedField()

        if (originalText.isNullOrEmpty()) {
            showToast("No text found. Tap in a text field, or hold to speak.")
            return
        }

        // Show loading state
        showStatus(
            if (actionType == "grammar") "Checking grammar…" else "Translating…",
            spinner = true
        )

        // Step 2: Send to Flutter for processing.
        // Routed through the process-scoped engine, so this works even though
        // MainActivity is almost certainly destroyed by now.
        BhashaChannel.processOverlayAction(
            action = actionType,
            text = originalText
        ) { success, data, error ->
            mainHandler.post {
                hideStatus()

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

    // ---------------------------------------------------------------------
    // Status pill
    // ---------------------------------------------------------------------

    /** Shows, or updates in place, the pill next to the bubble. */
    private fun showStatus(message: String, spinner: Boolean) {
        if (statusBubble != null) {
            statusText?.text = message
            return
        }

        val bubble = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 48f
                setColor(Color.parseColor("#2D3748"))
            }
            elevation = 8f
            setPadding(32, 24, 32, 24)
        }

        if (spinner) {
            val progressBar = ProgressBar(this).apply {
                val size = (24 * resources.displayMetrics.density).toInt()
                layoutParams = LinearLayout.LayoutParams(size, size)
                indeterminateTintList = android.content.res.ColorStateList.valueOf(Color.WHITE)
            }
            bubble.addView(progressBar)
        }

        val text = TextView(this).apply {
            this.text = message
            setTextColor(Color.WHITE)
            textSize = 14f
            typeface = Typeface.create("sans-serif", Typeface.NORMAL)
            setPadding(if (spinner) 24 else 0, 0, 0, 0)
        }

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
        statusBubble = bubble
        statusText = text
    }

    private fun hideStatus() {
        statusBubble?.let {
            windowManager?.removeView(it)
        }
        statusBubble = null
        statusText = null
    }

    override fun onDestroy() {
        super.onDestroy()
        cancelHold()
        if (voiceCapture.isRecording) {
            voiceCapture.cancel()
        }
        floatingView?.let {
            windowManager?.removeView(it)
        }
        floatingView = null
        hideStatus()
    }
}
