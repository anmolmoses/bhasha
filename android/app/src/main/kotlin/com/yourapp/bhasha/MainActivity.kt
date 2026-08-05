package com.yourapp.bhasha

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Renders the Bhasha UI on the process-scoped engine created by
 * [BhashaApplication].
 *
 * This activity no longer owns the MethodChannel. Destroying it must not take
 * the Dart side down with it, because that is the normal state while the
 * parent is using the bubble inside another app.
 */
class MainActivity : FlutterActivity() {

    /** Attach to the shared engine rather than building a throwaway one. */
    override fun getCachedEngineId(): String = BhashaApplication.ENGINE_ID

    /** The engine outlives this activity by design. */
    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // No-op when the Application already attached it; present so the UI
        // still works if this activity is ever hosted on a fresh engine.
        BhashaChannel.attachTo(flutterEngine, this)
    }

    override fun onResume() {
        super.onResume()
        // Lets permission requests use startActivityForResult while we are up.
        BhashaChannel.bindActivity(this)
        maybeRequestMicPermission(intent)
    }

    /** The bubble sends the parent here when they hold it without RECORD_AUDIO. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        maybeRequestMicPermission(intent)
    }

    private fun maybeRequestMicPermission(intent: Intent?) {
        if (intent?.getBooleanExtra(EXTRA_REQUEST_MIC_PERMISSION, false) != true) return
        // Consume it, so rotating the screen does not re-prompt.
        intent.removeExtra(EXTRA_REQUEST_MIC_PERMISSION)
        if (!BhashaChannel.isHoldToSpeakEnabled()) return

        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) return

        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            BhashaChannel.MIC_PERMISSION_REQUEST
        )
    }

    override fun onDestroy() {
        BhashaChannel.unbindActivity(this)
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == BhashaChannel.OVERLAY_PERMISSION_REQUEST) {
            BhashaChannel.onOverlayPermissionResult()
        }
    }

    companion object {
        const val EXTRA_REQUEST_MIC_PERMISSION = "bhasha.request_mic_permission"
    }
}
