package com.yourapp.bhasha

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.util.Base64
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import java.io.ByteArrayOutputStream
import java.util.concurrent.atomic.AtomicBoolean

class ScreenCaptureService : Service() {
    private val completed = AtomicBoolean(false)
    private lateinit var mainHandler: Handler
    private var captureThread: HandlerThread? = null
    private var captureHandler: Handler? = null
    private var projection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        mainHandler = Handler(mainLooper)
        createNotificationChannel()
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        startCaptureForeground()
        val resultCode = intent?.getIntExtra(EXTRA_RESULT_CODE, 0) ?: 0
        val resultData =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent?.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent?.getParcelableExtra(EXTRA_RESULT_DATA)
            }
        if (resultCode == 0 || resultData == null) {
            fail("Android did not grant screen capture.")
            return START_NOT_STICKY
        }

        try {
            capture(resultCode, resultData)
        } catch (_: Exception) {
            fail("Could not capture this screen. Please try again.")
        }
        return START_NOT_STICKY
    }

    private fun startCaptureForeground() {
        val notification = createNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun capture(resultCode: Int, resultData: Intent) {
        val manager =
            getSystemService(Context.MEDIA_PROJECTION_SERVICE) as
                MediaProjectionManager
        projection = manager.getMediaProjection(resultCode, resultData)

        captureThread = HandlerThread("BhashaScreenCapture").also { it.start() }
        captureHandler = Handler(captureThread!!.looper)
        projection?.registerCallback(
            object : MediaProjection.Callback() {
                override fun onStop() {
                    if (!completed.get()) {
                        fail("Screen capture ended before a frame was available.")
                    }
                }
            },
            captureHandler,
        )

        val windowManager =
            getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val bounds =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                windowManager.currentWindowMetrics.bounds
            } else {
                @Suppress("DEPRECATION")
                android.graphics.Rect(
                    0,
                    0,
                    resources.displayMetrics.widthPixels,
                    resources.displayMetrics.heightPixels,
                )
            }
        val width = bounds.width()
        val height = bounds.height()
        val densityDpi = resources.displayMetrics.densityDpi

        imageReader =
            ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
        imageReader?.setOnImageAvailableListener(
            { reader ->
                if (completed.get()) return@setOnImageAvailableListener
                val image = reader.acquireLatestImage()
                    ?: return@setOnImageAvailableListener
                try {
                    val plane = image.planes.first()
                    val pixelStride = plane.pixelStride
                    val rowStride = plane.rowStride
                    val rowPadding = rowStride - pixelStride * width
                    val paddedWidth = width + rowPadding / pixelStride
                    val padded =
                        Bitmap.createBitmap(
                            paddedWidth,
                            height,
                            Bitmap.Config.ARGB_8888,
                        )
                    padded.copyPixelsFromBuffer(plane.buffer)
                    val cropped = Bitmap.createBitmap(padded, 0, 0, width, height)
                    val output = ByteArrayOutputStream()
                    cropped.compress(Bitmap.CompressFormat.JPEG, 84, output)
                    cropped.recycle()
                    padded.recycle()
                    val base64 =
                        Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
                    output.close()
                    succeed(base64)
                } catch (_: Exception) {
                    fail("Could not read the captured screen.")
                } finally {
                    image.close()
                }
            },
            captureHandler,
        )

        virtualDisplay =
            projection?.createVirtualDisplay(
                "BhashaOneShotScreen",
                width,
                height,
                densityDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                imageReader?.surface,
                null,
                captureHandler,
            )

        mainHandler.postDelayed(
            {
                if (!completed.get()) {
                    fail("Screen capture timed out. Please try again.")
                }
            },
            CAPTURE_TIMEOUT_MS,
        )
    }

    private fun succeed(jpegBase64: String) {
        if (!completed.compareAndSet(false, true)) return
        cleanup()
        mainHandler.post {
            OverlayService.onScreenCaptureReady(jpegBase64)
            stopSelf()
        }
    }

    private fun fail(message: String) {
        if (!completed.compareAndSet(false, true)) return
        cleanup()
        mainHandler.post {
            OverlayService.onScreenCaptureError(message)
            stopSelf()
        }
    }

    private fun cleanup() {
        imageReader?.setOnImageAvailableListener(null, null)
        virtualDisplay?.release()
        imageReader?.close()
        projection?.stop()
        captureThread?.quitSafely()
        imageReader = null
        virtualDisplay = null
        projection = null
        captureThread = null
        captureHandler = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    override fun onDestroy() {
        if (!completed.get()) {
            completed.set(true)
            cleanup()
        }
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel =
            NotificationChannel(
                CHANNEL_ID,
                "Bhasha screen capture",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Shown during a one-time screen translation capture"
            }
        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    private fun createNotification(): Notification {
        val openApp = Intent(this, MainActivity::class.java)
        val pendingIntent =
            PendingIntent.getActivity(
                this,
                0,
                openApp,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setContentTitle("Bhasha is reading this screen")
            .setContentText("One screenshot only; nothing is saved.")
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "BhashaScreenCaptureChannel"
        private const val NOTIFICATION_ID = 7105
        private const val EXTRA_RESULT_CODE = "resultCode"
        private const val EXTRA_RESULT_DATA = "resultData"
        private const val CAPTURE_TIMEOUT_MS = 7_000L

        fun start(
            context: Context,
            resultCode: Int,
            resultData: Intent,
        ) {
            val intent =
                Intent(context, ScreenCaptureService::class.java).apply {
                    putExtra(EXTRA_RESULT_CODE, resultCode)
                    putExtra(EXTRA_RESULT_DATA, resultData)
                }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}
