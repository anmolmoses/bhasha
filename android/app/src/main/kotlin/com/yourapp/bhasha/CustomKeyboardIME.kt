package com.yourapp.bhasha

import android.inputmethodservice.InputMethodService
import android.inputmethodservice.Keyboard
import android.inputmethodservice.KeyboardView
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import android.widget.Button
import android.widget.LinearLayout
import android.widget.Toast

class CustomKeyboardIME : InputMethodService(), KeyboardView.OnKeyboardActionListener {

    private var keyboardView: KeyboardView? = null
    private var keyboard: Keyboard? = null
    private var translationButton: Button? = null
    private var grammarButton: Button? = null
    private var capsLock = false

    override fun onCreateInputView(): View {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }

        // Create toolbar with action buttons
        val toolbar = createToolbar()
        layout.addView(toolbar)

        // Create keyboard view
        keyboardView = layoutInflater.inflate(
            R.layout.keyboard_view,
            null
        ) as? KeyboardView ?: KeyboardView(this, null)

        keyboard = Keyboard(this, R.xml.qwerty)
        keyboardView?.apply {
            this.keyboard = this@CustomKeyboardIME.keyboard
            setOnKeyboardActionListener(this@CustomKeyboardIME)
            isPreviewEnabled = false
        }

        layout.addView(keyboardView)

        return layout
    }

    private fun createToolbar(): View {
        val toolbar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(16, 8, 16, 8)
            setBackgroundColor(0xFFEEEEEE.toInt())
        }

        translationButton = Button(this).apply {
            text = "Translate"
            setOnClickListener {
                handleTranslation()
            }
        }

        grammarButton = Button(this).apply {
            text = "Grammar"
            setOnClickListener {
                handleGrammarCheck()
            }
        }

        toolbar.addView(translationButton)
        toolbar.addView(grammarButton)

        return toolbar
    }

    private fun handleTranslation() {
        val ic = currentInputConnection ?: return
        val selectedText = ic.getSelectedText(0)

        if (selectedText != null && selectedText.isNotEmpty()) {
            // Translate selected text
            Toast.makeText(this, "Translating: $selectedText", Toast.LENGTH_SHORT).show()
            // TODO: Call Flutter method channel to translate
            // For now, just show a toast
        } else {
            // Get text before cursor
            val textBeforeCursor = ic.getTextBeforeCursor(1000, 0)
            if (textBeforeCursor != null && textBeforeCursor.isNotEmpty()) {
                Toast.makeText(this, "Translating current text", Toast.LENGTH_SHORT).show()
                // TODO: Call Flutter method channel to translate
            } else {
                Toast.makeText(this, "No text to translate", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun handleGrammarCheck() {
        val ic = currentInputConnection ?: return
        val selectedText = ic.getSelectedText(0)

        if (selectedText != null && selectedText.isNotEmpty()) {
            // Check grammar of selected text
            Toast.makeText(this, "Checking grammar: $selectedText", Toast.LENGTH_SHORT).show()
            // TODO: Call Flutter method channel to check grammar
        } else {
            // Get text before cursor
            val textBeforeCursor = ic.getTextBeforeCursor(1000, 0)
            if (textBeforeCursor != null && textBeforeCursor.isNotEmpty()) {
                Toast.makeText(this, "Checking grammar", Toast.LENGTH_SHORT).show()
                // TODO: Call Flutter method channel to check grammar
            } else {
                Toast.makeText(this, "No text to check", Toast.LENGTH_SHORT).show()
            }
        }
    }

    override fun onKey(primaryCode: Int, keyCodes: IntArray?) {
        val ic = currentInputConnection ?: return

        when (primaryCode) {
            Keyboard.KEYCODE_DELETE -> {
                ic.deleteSurroundingText(1, 0)
            }
            Keyboard.KEYCODE_SHIFT -> {
                capsLock = !capsLock
                keyboard?.isShifted = capsLock
                keyboardView?.invalidateAllKeys()
            }
            Keyboard.KEYCODE_DONE -> {
                ic.sendKeyEvent(
                    KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_ENTER)
                )
            }
            else -> {
                var code = primaryCode.toChar()
                if (Character.isLetter(code) && capsLock) {
                    code = Character.toUpperCase(code)
                }
                ic.commitText(code.toString(), 1)
            }
        }
    }

    override fun onPress(primaryCode: Int) {}
    override fun onRelease(primaryCode: Int) {}
    override fun onText(text: CharSequence?) {
        currentInputConnection?.commitText(text, 1)
    }
    override fun swipeLeft() {}
    override fun swipeRight() {}
    override fun swipeDown() {}
    override fun swipeUp() {}
}
