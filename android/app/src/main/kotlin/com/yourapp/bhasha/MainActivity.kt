package com.yourapp.bhasha

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.content.Context
import android.text.TextUtils
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper

class MainActivity: FlutterActivity() {
    companion object {
        private var methodChannelRef: MethodChannel? = null

        fun processOverlayAction(
            action: String,
            text: String,
            callback: (success: Boolean, data: Map<String, Any?>?, error: String?) -> Unit
        ) {
            val channel = methodChannelRef
            if (channel == null) {
                callback(false, null, "Bhasha is not ready. Open the app once to initialize.")
                return
            }

            Handler(Looper.getMainLooper()).post {
                channel.invokeMethod(
                    "processOverlayAction",
                    hashMapOf(
                        "action" to action,
                        "text" to text
                    ),
                    object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            val map = (result as? Map<*, *>)?.mapNotNull { entry ->
                                val key = entry.key as? String ?: return@mapNotNull null
                                key to entry.value
                            }?.toMap()
                            callback(true, map, null)
                        }

                        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                            callback(false, null, errorMessage ?: "Something went wrong ($errorCode)")
                        }

                        override fun notImplemented() {
                            callback(false, null, "Process overlay action not implemented.")
                        }
                    }
                )
            }
        }
    }

    private val CHANNEL = "com.yourapp.bhasha/native"
    private val OVERLAY_PERMISSION_REQUEST = 1001
    private lateinit var methodChannel: MethodChannel

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannelRef = methodChannel

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startOverlayService" -> {
                    if (checkOverlayPermission()) {
                        startOverlayService()
                        result.success(true)
                    } else {
                        requestOverlayPermission()
                        result.success(false)
                    }
                }
                "stopOverlayService" -> {
                    stopOverlayService()
                    result.success(true)
                }
                "checkOverlayPermission" -> {
                    result.success(checkOverlayPermission())
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(null)
                }
                "openKeyboardSettings" -> {
                    openKeyboardSettings()
                    result.success(true)
                }
                "checkAccessibilityPermission" -> {
                    result.success(checkAccessibilityPermission())
                }
                "requestAccessibilityPermission" -> {
                    requestAccessibilityPermission()
                    result.success(null)
                }
                "updateFloatingActionType" -> {
                    val actionType = call.argument<String>("actionType") ?: "translate"
                    OverlayService.updateActionType(actionType)
                    result.success(true)
                }
                "translateText" -> {
                    val text = call.argument<String>("text")
                    val sourceLang = call.argument<String>("sourceLang")
                    val targetLang = call.argument<String>("targetLang")
                    // This will be called from native code and sent back to Flutter
                    result.success("Translation handled by Flutter")
                }
                "checkGrammar" -> {
                    val text = call.argument<String>("text")
                    val language = call.argument<String>("language")
                    // This will be called from native code and sent back to Flutter
                    result.success("Grammar check handled by Flutter")
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun checkOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST)
        }
    }

    private fun startOverlayService() {
        val intent = Intent(this, OverlayService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopOverlayService() {
        val intent = Intent(this, OverlayService::class.java)
        stopService(intent)
    }

    private fun openKeyboardSettings() {
        val intent = Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)
        startActivity(intent)
    }

    private fun checkAccessibilityPermission(): Boolean {
        val service = "${packageName}/${BhashaAccessibilityService::class.java.name}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        )
        return enabledServices?.contains(service) == true
    }

    private fun requestAccessibilityPermission() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        startActivity(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OVERLAY_PERMISSION_REQUEST) {
            if (checkOverlayPermission()) {
                startOverlayService()
            }
        }
    }

    override fun onDestroy() {
        if (::methodChannel.isInitialized && methodChannelRef == methodChannel) {
            methodChannelRef = null
        }
        super.onDestroy()
    }
}
