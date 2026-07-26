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
    private const val LANGUAGE_CATALOG = "language_catalog"
    private const val LANGUAGE_SOURCE = "language_source"
    private const val LANGUAGE_TARGET = "language_target"
    private const val LANGUAGE_AUTO_FLIP = "language_auto_flip"


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

        // The pair rides along with every request: it is how a choice made from
        // the overlay chip reaches Dart, which has no other way to hear about
        // it while the app itself is not running.
        val pair = languagePair()

        mainHandler.post {
            target.invokeMethod(
                "processOverlayAction",
                hashMapOf(
                    "action" to action,
                    "text" to text,
                    "audioPath" to audioPath,
                    "imageBase64" to imageBase64,
                    "blocks" to blocks,
                    "sourceLanguage" to pair.sourceName.ifEmpty { null },
                    "targetLanguage" to pair.targetName.ifEmpty { null },
                    "autoFlip" to pair.autoFlip,
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

    // -----------------------------------------------------------------------
    // Language pair, owned by the bubble while the parent is in another app
    // -----------------------------------------------------------------------

    /**
     * The languages the overlay can offer, pushed down from Dart because
     * [Languages] lives there and duplicating 23 entries in Kotlin would rot.
     *
     * Empty until the app has run once, which cannot happen before the bubble
     * exists: only the app can start it.
     */
    fun languageCatalog(): List<LanguageOption> =
        prefs()?.getString(LANGUAGE_CATALOG, null)
            ?.lineSequence()
            ?.mapNotNull { line ->
                val parts = line.split('|')
                if (parts.size < 3) return@mapNotNull null
                LanguageOption(
                    code = parts[0],
                    name = parts[1],
                    shortLabel = parts[2],
                )
            }
            ?.toList()
            .orEmpty()

    fun languagePair(): LanguagePair {
        val prefs = prefs()
        return LanguagePair(
            sourceName = prefs?.getString(LANGUAGE_SOURCE, null).orEmpty(),
            targetName = prefs?.getString(LANGUAGE_TARGET, null).orEmpty(),
            autoFlip = prefs?.getBoolean(LANGUAGE_AUTO_FLIP, true) ?: true,
        )
    }

    /**
     * Records a choice made from the overlay chip. Dart is not told directly:
     * it may have no isolate alive right now, so the value rides along with the
     * next [processOverlayAction] instead, where it cannot be lost.
     */
    fun setTargetLanguage(name: String) {
        prefs()?.edit()?.putString(LANGUAGE_TARGET, name)?.apply()
    }

    fun setSourceLanguage(name: String) {
        prefs()?.edit()?.putString(LANGUAGE_SOURCE, name)?.apply()
    }

    fun setAutoFlip(enabled: Boolean) {
        prefs()?.edit()?.putBoolean(LANGUAGE_AUTO_FLIP, enabled)?.apply()
    }

    private fun syncLanguageSettings(
        call: io.flutter.plugin.common.MethodCall,
    ): Boolean {
        val editor = prefs()?.edit() ?: return false
        call.argument<List<String>>("catalog")?.let { catalog ->
            editor.putString(LANGUAGE_CATALOG, catalog.joinToString("\n"))
        }
        call.argument<String>("sourceLanguage")?.let {
            editor.putString(LANGUAGE_SOURCE, it)
        }
        call.argument<String>("targetLanguage")?.let {
            editor.putString(LANGUAGE_TARGET, it)
        }
        call.argument<Boolean>("autoFlip")?.let {
            editor.putBoolean(LANGUAGE_AUTO_FLIP, it)
        }
        editor.apply()
        OverlayService.refreshLanguageChip()
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
            "syncLanguageSettings" -> result.success(syncLanguageSettings(call))
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
