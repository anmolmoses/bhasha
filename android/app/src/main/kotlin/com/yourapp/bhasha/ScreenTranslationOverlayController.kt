package com.yourapp.bhasha

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import kotlin.math.max

data class TranslatedScreenBlock(
    val translatedText: String,
    val x: Float,
    val y: Float,
    val width: Float,
    val height: Float,
)

/**
 * Draws paper-white translated labels over the source text positions.
 *
 * The result is intentionally modal: tapping anywhere, including the Close
 * chip, dismisses it and returns control to the underlying app.
 */
object ScreenTranslationOverlayController {
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null

    fun isVisible(): Boolean = overlayView != null

    /**
     * Reports a screen-translation outcome as an overlay chip.
     *
     * Toasts are not usable here: Android suppresses them for an app whose
     * notifications the user has turned off, which silently hid every screen
     * translation failure.
     */
    fun showMessage(context: Context, message: String) {
        dismiss()

        val manager =
            context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val density = context.resources.displayMetrics.density

        val root = FrameLayout(context).apply {
            setBackgroundColor(Color.TRANSPARENT)
            isClickable = true
            setOnClickListener { dismiss() }
        }

        val chip = TextView(context).apply {
            text = message
            setTextColor(Color.WHITE)
            textSize = 14f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            gravity = Gravity.CENTER
            maxLines = 4
            setPadding(
                (20 * density).toInt(),
                (14 * density).toInt(),
                (20 * density).toInt(),
                (14 * density).toInt(),
            )
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 20 * density
                setColor(Color.parseColor("#2D3748"))
            }
            elevation = 12 * density
        }
        root.addView(
            chip,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                topMargin = (96 * density).toInt()
                leftMargin = (24 * density).toInt()
                rightMargin = (24 * density).toInt()
            },
        )

        val params =
            WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                },
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    setFitInsetsTypes(0)
                }
            }

        manager.addView(root, params)
        windowManager = manager
        overlayView = root

        // Long enough to read a full sentence, and tappable to dismiss sooner.
        root.postDelayed({ if (overlayView === root) dismiss() }, 5000L)
    }

    fun show(
        context: Context,
        blocks: List<TranslatedScreenBlock>,
    ) {
        dismiss()
        if (blocks.isEmpty()) return

        val manager =
            context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val bounds =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                manager.currentWindowMetrics.bounds
            } else {
                @Suppress("DEPRECATION")
                android.graphics.Rect(
                    0,
                    0,
                    context.resources.displayMetrics.widthPixels,
                    context.resources.displayMetrics.heightPixels,
                )
            }
        val screenWidth = bounds.width()
        val screenHeight = bounds.height()
        val density = context.resources.displayMetrics.density

        val root = FrameLayout(context).apply {
            // A light scrim separates the translation layer from the app
            // underneath, so the white cards read as one surface.
            setBackgroundColor(Color.argb(92, 15, 23, 42))
            isClickable = true
            contentDescription =
                "Translated screen. Tap anywhere to close translations."
            setOnClickListener { dismiss() }
        }

        val labels = mutableListOf<View>()

        blocks.forEach { block ->
            val left = (block.x.coerceIn(0f, 1000f) / 1000f * screenWidth).toInt()
            val top = (block.y.coerceIn(0f, 1000f) / 1000f * screenHeight).toInt()
            val requestedWidth =
                (block.width.coerceIn(1f, 1000f) / 1000f * screenWidth).toInt()
            val requestedHeight =
                (block.height.coerceIn(1f, 1000f) / 1000f * screenHeight).toInt()
            // English usually needs more room than the Indic source, so a
            // narrow bubble is allowed to widen rather than wrap to a column.
            val minReadableWidth =
                if (block.translatedText.length > 24) {
                    (screenWidth * 0.55f).toInt()
                } else {
                    (96 * density).toInt()
                }
            val horizontalMargin = (8 * density).toInt()
            val safeWidth =
                max(requestedWidth, minReadableWidth)
                    .coerceAtMost(screenWidth - left - horizontalMargin)
            val safeHeight =
                max(requestedHeight, (30 * density).toInt())
                    .coerceAtMost(screenHeight - top)
            if (safeWidth <= 0 || safeHeight <= 0) return@forEach

            val label = TextView(context).apply {
                text = block.translatedText
                setTextColor(Color.parseColor("#0F172A"))
                // One size for every label: mirroring each source box's height
                // made the overlay look ransom-noted.
                textSize = 14f
                typeface = Typeface.create("sans-serif", Typeface.NORMAL)
                gravity = Gravity.CENTER_VERTICAL
                setLineSpacing(0f, 1.15f)
                // A translation is often longer than its source, so the label
                // grows downward instead of clipping the sentence.
                minimumHeight = safeHeight
                maxLines = 8
                ellipsize = android.text.TextUtils.TruncateAt.END
                setPadding(
                    (12 * density).toInt(),
                    (8 * density).toInt(),
                    (12 * density).toInt(),
                    (8 * density).toInt(),
                )
                background = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = 12 * density
                    setColor(Color.WHITE)
                }
                elevation = 6 * density
            }
            root.addView(
                label,
                FrameLayout.LayoutParams(
                    safeWidth,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                ).apply {
                    // A widened label must slide back inside the screen
                    // instead of running off the right edge.
                    leftMargin =
                        left.coerceAtMost(screenWidth - safeWidth)
                            .coerceAtLeast(0)
                    topMargin = top
                },
            )
            labels += label
        }

        val closeChip = TextView(context).apply {
            text = "✓ Screen translated  ·  Close"
            setTextColor(Color.WHITE)
            textSize = 13f
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(
                (16 * density).toInt(),
                (10 * density).toInt(),
                (16 * density).toInt(),
                (10 * density).toInt(),
            )
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 24 * density
                setColor(Color.parseColor("#6D5CE7"))
            }
            elevation = 12 * density
            setOnClickListener { dismiss() }
        }
        root.addView(
            closeChip,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                topMargin = (44 * density).toInt()
            },
        )

        val params =
            WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                },
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                // Without this the window is inset by the status and
                // navigation bars, so every label lands one status-bar height
                // below the text it belongs to. Block bounds come from
                // getBoundsInScreen, which is full-display coordinates.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    setFitInsetsTypes(0)
                }
            }

        manager.addView(root, params)
        windowManager = manager
        overlayView = root

        root.post {
            // Block bounds are full-display coordinates, but the window may
            // still be inset by the status bar despite the flags above.
            // Measuring where the root actually landed and subtracting that
            // origin aligns the cards on any OEM inset behaviour.
            val origin = IntArray(2).also(root::getLocationOnScreen)

            // Cards are sized from their translated text, which can be taller
            // than the source line, so a grown card would cover the one below
            // it. Resolve that only once real heights are known.
            val gap = (3 * density).toInt()
            var previousBottom = 0
            labels
                .sortedBy { (it.layoutParams as FrameLayout.LayoutParams).topMargin }
                .forEach { label ->
                    val params = label.layoutParams as FrameLayout.LayoutParams
                    params.leftMargin =
                        (params.leftMargin - origin[0]).coerceAtLeast(0)
                    val alignedTop = params.topMargin - origin[1]
                    params.topMargin = max(alignedTop, previousBottom + gap)
                    label.layoutParams = params
                    previousBottom = params.topMargin + label.height
                }
        }
    }

    fun dismiss() {
        val view = overlayView ?: return
        try {
            windowManager?.removeView(view)
        } catch (_: IllegalArgumentException) {
            // Already detached by Android.
        }
        overlayView = null
        windowManager = null
    }
}
