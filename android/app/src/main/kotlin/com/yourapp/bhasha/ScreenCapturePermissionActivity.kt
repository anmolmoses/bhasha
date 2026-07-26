package com.yourapp.bhasha

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Bundle

/**
 * Tiny transparent activity required because Android only grants a
 * MediaProjection token from a user-visible system consent dialog.
 */
class ScreenCapturePermissionActivity : Activity() {
    private lateinit var projectionManager: MediaProjectionManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        projectionManager =
            getSystemService(Context.MEDIA_PROJECTION_SERVICE) as
                MediaProjectionManager
        if (savedInstanceState == null) {
            OverlayService.setCaptureUiHidden(true)
            @Suppress("DEPRECATION")
            startActivityForResult(
                projectionManager.createScreenCaptureIntent(),
                REQUEST_CAPTURE,
            )
        }
    }

    @Deprecated("Deprecated by Android; retained for the MediaProjection flow.")
    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CAPTURE &&
            resultCode == RESULT_OK &&
            data != null
        ) {
            ScreenCaptureService.start(this, resultCode, data)
        } else {
            OverlayService.onScreenCaptureError("Screen capture was cancelled.")
        }
        finish()
    }

    companion object {
        private const val REQUEST_CAPTURE = 7104
    }
}
