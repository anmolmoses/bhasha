package com.yourapp.bhasha

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/**
 * The single MethodChannel between Kotlin and Dart.
 *
 * Bound to the process-scoped engine in [BhashaApplication], not to an
 * activity, so [processOverlayAction] keeps working while the parent is inside
 * WhatsApp and MainActivity has been destroyed.
 *
 * A few actions are nicer with a live Activity (an overlay-permission request
 * can then deliver its result to onActivityResult). Those use the bound
 * activity when there is one and fall back to a NEW_TASK intent when there is
 * not, rather than refusing to work.
 */
object BhashaChannel {

    private const val NATIVE_PREFS = "bhasha_native_preferences"
    private const val SCREEN_TRANSLATION_ENABLED = "screen_translation_enabled"
    private const val CONTEXTUAL_ENABLED = "whatsapp_contextual_enabled"


    const val CHANNEL = "com.yourapp.bhasha/native"
    const val OVERLAY_PERMISSION_REQUEST = 1001
    const val MIC_PERMISSION_REQUEST = 1002

    private var channel: MethodChannel? = null
    private var appContext: Context? = null
    private var activityRef: WeakReference<Activity>? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val activity: Activity?
        get() = activityRef?.get()?.takeUnless { it.isFinishing || it.isDestroyed }

    /** Idempotent: MainActivity.configureFlutterEngine reaches the same engine. */
    fun attachTo(engine: FlutterEngine, context: Context) {
        if (channel != null) return
        appContext = context.applicationContext
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result -> handle(call.method, call, result) }
        }
    }

    fun bindActivity(activity: Activity) {
        activityRef = WeakReference(activity)
    }

    fun unbindActivity(activity: Activity) {
        if (activityRef?.get() === activity) {
            activityRef = null
        }
    }

    /**
     * Called when the parent returns from the overlay-permission screen.
     * Starts the bubble immediately if they granted it, so they do not have to
     * find the toggle again.
     */
    fun onOverlayPermissionResult() {
        if (canDrawOverlays()) {
            startOverlayService()
        }
    }

    /**
     * Asks Dart to run a bubble action. Safe to call with no activity alive.
     *
     * [audioPath] carries recorded speech for the hold-to-speak flow. Dart
     * reads the file directly rather than marshalling audio over the channel,
     * which would copy several hundred kilobytes for no benefit.
     */
    fun processOverlayAction(
        action: String,
        text: String,
        audioPath: String? = null,
        imageBase64: String? = null,
        blocks: List<Map<String, Any?>>? = null,
        callback: (success: Boolean, data: Map<String, Any?>?, error: String?) -> Unit
    ) {
        val target = channel
        if (target == null) {
            callback(false, null, "Bhasha is still starting. Try again in a moment.")
            return
        }

        mainHandler.post {
            target.invokeMethod(
                "processOverlayAction",
                hashMapOf(
                    "action" to action,
                    "text" to text,
                    "audioPath" to audioPath,
                    "imageBase64" to imageBase64,
                    "blocks" to blocks,
                ),
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        val map = (result as? Map<*, *>)?.mapNotNull { entry ->
                            val key = entry.key as? String ?: return@mapNotNull null
                            key to entry.value
                        }?.toMap()
                        callback(true, map, null)
                    }

                    override fun error(
                        errorCode: String,
                        errorMessage: String?,
                        errorDetails: Any?
                    ) {
                        callback(false, null, errorMessage ?: "Something went wrong ($errorCode)")
                    }

                    override fun notImplemented() {
                        callback(false, null, "Bhasha is still starting. Try again in a moment.")
                    }
                }
            )
        }
    }

    /** Screenshot OCR through Sarvam Vision, then translation. */
    fun processScreenTranslation(
        imageBase64: String,
        callback: (success: Boolean, data: Map<String, Any?>?, error: String?) -> Unit
    ) = processOverlayAction(
        action = "screen_translate",
        text = "",
        imageBase64 = imageBase64,
        callback = callback,
    )

    /**
     * Translates text already read from the accessibility tree, skipping OCR.
     * [blocks] carry text plus 0-1000 normalised geometry.
     */
    fun processScreenTextBlocks(
        blocks: List<Map<String, Any?>>,
        callback: (success: Boolean, data: Map<String, Any?>?, error: String?) -> Unit
    ) = processOverlayAction(
        action = "translate_screen_blocks",
        text = "",
        blocks = blocks,
        callback = callback,
    )

    /**
     * Screen translation is opt-in and read from native prefs, because the
     * overlay has to know the setting without waiting on the Dart isolate.
     */
    fun isScreenTranslationEnabled(): Boolean =
        prefs()?.getBoolean(SCREEN_TRANSLATION_ENABLED, false) ?: false

    private fun setScreenTranslationEnabled(enabled: Boolean): Boolean {
        prefs()?.edit()?.putBoolean(SCREEN_TRANSLATION_ENABLED, enabled)?.apply()
            ?: return false
        return true
    }

    fun isContextualTranslateEnabled(): Boolean =
        prefs()?.getBoolean(CONTEXTUAL_ENABLED, false) ?: false

    private fun setContextualTranslateEnabled(enabled: Boolean): Boolean {
        prefs()?.edit()?.putBoolean(CONTEXTUAL_ENABLED, enabled)?.apply()
            ?: return false
        return true
    }

    private fun prefs(): android.content.SharedPreferences? =
        appContext?.getSharedPreferences(NATIVE_PREFS, Context.MODE_PRIVATE)

    private fun handle(
        method: String,
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result
    ) {
        when (method) {
            "startOverlayService" -> {
                if (canDrawOverlays()) {
                    startOverlayService()
                    result.success(true)
                } else {
                    requestOverlayPermission()
                    result.success(false)
                }
            }
            "stopOverlayService" -> {
                appContext?.stopService(Intent(appContext, OverlayService::class.java))
                result.success(true)
            }
            "checkOverlayPermission" -> result.success(canDrawOverlays())
            "requestOverlayPermission" -> {
                requestOverlayPermission()
                result.success(null)
            }
            "openKeyboardSettings" -> {
                launchSettings(Settings.ACTION_INPUT_METHOD_SETTINGS)
                result.success(true)
            }
            "checkMicPermission" -> result.success(hasMicPermission())
            "requestMicPermission" -> {
                requestMicPermission()
                result.success(null)
            }
            "checkAccessibilityPermission" -> result.success(isAccessibilityEnabled())
            "requestAccessibilityPermission" -> {
                launchSettings(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                result.success(null)
            }
            "checkScreenTranslationEnabled" ->
                result.success(isScreenTranslationEnabled())
            "setScreenTranslationEnabled" -> result.success(
                setScreenTranslationEnabled(
                    call.argument<Boolean>("enabled") ?: false
                )
            )
            "checkContextualTranslateEnabled" ->
                result.success(isContextualTranslateEnabled())
            "setContextualTranslateEnabled" -> result.success(
                setContextualTranslateEnabled(
                    call.argument<Boolean>("enabled") ?: false
                )
            )
            "updateFloatingActionType" -> {
                OverlayService.updateActionType(
                    call.argument<String>("actionType") ?: "translate"
                )
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun hasMicPermission(): Boolean {
        val context = appContext ?: return false
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Only an Activity can show the runtime prompt. With none alive we bring
     * the app forward and let it ask on resume, rather than failing silently.
     */
    private fun requestMicPermission() {
        if (hasMicPermission()) return
        val host = activity
        if (host != null) {
            ActivityCompat.requestPermissions(
                host,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                MIC_PERMISSION_REQUEST
            )
            return
        }
        val context = appContext ?: return
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra(MainActivity.EXTRA_REQUEST_MIC_PERMISSION, true)
        }
        context.startActivity(intent)
    }

    private fun canDrawOverlays(): Boolean {
        val context = appContext ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }

    private fun startOverlayService() {
        val context = appContext ?: return
        val intent = Intent(context, OverlayService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val context = appContext ?: return
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${context.packageName}")
        )

        // With an activity we get the result callback; without one we can still
        // send the parent to the right settings page.
        val host = activity
        if (host != null) {
            host.startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST)
        } else {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        }
    }

    private fun launchSettings(action: String) {
        val context = appContext ?: return
        val intent = Intent(action)
        val host = activity
        if (host != null) {
            host.startActivity(intent)
        } else {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val context = appContext ?: return false
        val service = "${context.packageName}/${BhashaAccessibilityService::class.java.name}"
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        )
        return enabled?.contains(service) == true
    }
}
