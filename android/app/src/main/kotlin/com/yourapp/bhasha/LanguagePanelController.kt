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
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/**
 * The language picker the bubble's chip opens, drawn over whatever app the
 * parent is in.
 *
 * This exists so that changing language never means leaving WhatsApp. The
 * bubble's own tap, double tap and long press are all spoken for, so the chip
 * is a separate view with its own touch target rather than a fourth gesture.
 */
object LanguagePanelController {
    private const val ACCENT = "#6D5CE7"
    private const val INK = "#0F172A"
    private const val MUTED = "#64748B"

    private var windowManager: WindowManager? = null
    private var panelView: View? = null

    fun isVisible(): Boolean = panelView != null

    fun toggle(context: Context) {
        if (isVisible()) dismiss() else show(context)
    }

    fun show(context: Context) {
        dismiss()

        val catalog = BhashaChannel.languageCatalog()
        if (catalog.isEmpty()) {
            // Only reachable if native preferences were cleared under a running
            // bubble. Sending them to the app re-syncs the catalog on launch.
            ScreenTranslationOverlayController.showMessage(
                context,
                "Open Bhasha once to load the language list.",
            )
            return
        }

        val manager =
            context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val density = context.resources.displayMetrics.density
        val screenHeight = context.resources.displayMetrics.heightPixels

        val root = FrameLayout(context).apply {
            setBackgroundColor(Color.argb(120, 15, 23, 42))
            isClickable = true
            setOnClickListener { dismiss() }
        }

        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 24 * density
                setColor(Color.WHITE)
            }
            elevation = 16 * density
            setPadding(
                (20 * density).toInt(),
                (20 * density).toInt(),
                (20 * density).toInt(),
                (12 * density).toInt(),
            )
            // Swallow taps so the scrim behind does not close the panel while
            // the parent is reading the list.
            isClickable = true
        }

        val pair = BhashaChannel.languagePair()
        card.addView(titleView(context, density))
        card.addView(autoFlipRow(context, density, pair))
        card.addView(divider(context, density))
        card.addView(listHeader(context, density, pair))
        card.addView(languageList(context, density, screenHeight, catalog, pair))

        root.addView(
            card,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                gravity = Gravity.CENTER
                leftMargin = (20 * density).toInt()
                rightMargin = (20 * density).toInt()
            },
        )

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            // Not focusable: touch still works, and leaving focus alone keeps
            // the keyboard in the app underneath from being torn down.
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
        panelView = root
    }

    private fun titleView(context: Context, density: Float): View =
        TextView(context).apply {
            text = "Bhasha languages"
            setTextColor(Color.parseColor(INK))
            textSize = 17f
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            setPadding(0, 0, 0, (14 * density).toInt())
        }

    private fun autoFlipRow(
        context: Context,
        density: Float,
        pair: LanguagePair,
    ): View {
        val row = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            // Full width, so the whole row is the touch target rather than
            // just the run of text inside it.
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 16 * density
                setColor(
                    if (pair.autoFlip) {
                        Color.parseColor("#EEEBFF")
                    } else {
                        Color.parseColor("#F1F5F9")
                    },
                )
            }
            setPadding(
                (16 * density).toInt(),
                (14 * density).toInt(),
                (16 * density).toInt(),
                (14 * density).toInt(),
            )
            isClickable = true
            setOnClickListener {
                BhashaChannel.setAutoFlip(!pair.autoFlip)
                OverlayService.refreshLanguageChip()
                // Redraw in place, on the next frame rather than inside this
                // view's own click dispatch, so the parent sees the mode change
                // without hunting for the chip again.
                it.post { show(context) }
            }
        }

        row.addView(
            TextView(context).apply {
                text = if (pair.autoFlip) {
                    "✓  ${pair.sourceName} ⇄ ${pair.targetName}"
                } else {
                    "○  ${pair.sourceName} ⇄ ${pair.targetName}"
                }
                setTextColor(
                    Color.parseColor(if (pair.autoFlip) ACCENT else INK),
                )
                textSize = 15f
                typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            },
        )
        row.addView(
            TextView(context).apply {
                text = if (pair.autoFlip) {
                    "Automatic. Whatever you write goes to the other language."
                } else {
                    "Tap to let Bhasha pick the direction for you."
                }
                setTextColor(Color.parseColor(MUTED))
                textSize = 12f
                setPadding(0, (4 * density).toInt(), 0, 0)
            },
        )
        return row
    }

    private fun divider(context: Context, density: Float): View =
        View(context).apply {
            setBackgroundColor(Color.parseColor("#E2E8F0"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                (1 * density).toInt(),
            ).apply {
                topMargin = (16 * density).toInt()
                bottomMargin = (12 * density).toInt()
            }
        }

    private fun listHeader(
        context: Context,
        density: Float,
        pair: LanguagePair,
    ): View = TextView(context).apply {
        text = if (pair.autoFlip) {
            "PAIR ${pair.sourceName.uppercase()} WITH"
        } else {
            "ALWAYS TRANSLATE INTO"
        }
        setTextColor(Color.parseColor(MUTED))
        textSize = 11f
        letterSpacing = 0.08f
        typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
        setPadding(0, 0, 0, (8 * density).toInt())
    }

    private fun languageList(
        context: Context,
        density: Float,
        screenHeight: Int,
        catalog: List<LanguageOption>,
        pair: LanguagePair,
    ): View {
        val list = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }

        catalog.forEach { option ->
            val selected = option.name.equals(pair.targetName, ignoreCase = true)
            val isOtherSide =
                option.name.equals(pair.sourceName, ignoreCase = true)
            list.addView(
                TextView(context).apply {
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                    )
                    text = when {
                        selected -> "✓  ${option.name}"
                        isOtherSide -> "     ${option.name}  ·  your language"
                        else -> "     ${option.name}"
                    }
                    setTextColor(
                        Color.parseColor(if (selected) ACCENT else INK),
                    )
                    textSize = 15f
                    typeface = Typeface.create(
                        if (selected) "sans-serif-medium" else "sans-serif",
                        if (selected) Typeface.BOLD else Typeface.NORMAL,
                    )
                    setPadding(
                        (8 * density).toInt(),
                        (13 * density).toInt(),
                        (8 * density).toInt(),
                        (13 * density).toInt(),
                    )
                    isClickable = true
                    setOnClickListener {
                        // Picking the language you already write in would leave
                        // a pair with only one side, which can never flip.
                        if (isOtherSide) {
                            BhashaChannel.setSourceLanguage(pair.targetName)
                        }
                        BhashaChannel.setTargetLanguage(option.name)
                        OverlayService.refreshLanguageChip()
                        dismiss()
                        OverlayService.announceLanguage()
                    }
                },
            )
        }

        return ScrollView(context).apply {
            isVerticalScrollBarEnabled = true
            addView(list)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                // The catalog always overflows, so cap it rather than let the
                // card grow past the screen.
                (screenHeight * 0.42f).toInt(),
            )
        }
    }

    fun dismiss() {
        val view = panelView ?: return
        try {
            windowManager?.removeView(view)
        } catch (_: IllegalArgumentException) {
            // Already detached by Android.
        }
        panelView = null
        windowManager = null
    }
}
