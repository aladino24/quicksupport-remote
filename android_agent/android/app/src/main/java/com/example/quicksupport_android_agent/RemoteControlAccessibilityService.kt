package com.example.quicksupport_android_agent

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.media.AudioManager
import android.os.Bundle
import android.os.Build
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class RemoteControlAccessibilityService : AccessibilityService() {
    companion object {
        @Volatile
        private var instance: RemoteControlAccessibilityService? = null

        fun handleRemoteAction(raw: Map<*, *>) {
            val service = instance ?: throw IllegalStateException("Accessibility service is not connected")
            service.handleAction(raw)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        if (Build.VERSION.SDK_INT >= 33) {
            serviceInfo = serviceInfo.apply {
                flags = flags or AccessibilityServiceInfo.FLAG_INPUT_METHOD_EDITOR
            }
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        if (instance === this) {
            instance = null
        }
        super.onDestroy()
    }

    private fun handleAction(raw: Map<*, *>) {
        val action = (raw["action"] as? String) ?: "none"
        val x = (raw["x"] as? Number)?.toFloat() ?: 0f
        val y = (raw["y"] as? Number)?.toFloat() ?: 0f
        val startX = (raw["startX"] as? Number)?.toFloat() ?: x
        val startY = (raw["startY"] as? Number)?.toFloat() ?: y
        val endX = (raw["endX"] as? Number)?.toFloat() ?: x
        val endY = (raw["endY"] as? Number)?.toFloat() ?: y
        val delta = (raw["delta"] as? Number)?.toInt() ?: 0
        val direction = (raw["direction"] as? String) ?: "down"
        val key = (raw["key"] as? String) ?: ""

        when (action) {
            "tap" -> tapAt(x, y)
            "doubleTap" -> {
                tapAt(x, y)
                tapAt(x, y)
            }
            "long_press" -> longPressAt(x, y)
            "drag" -> dragPath(startX, startY, endX, endY, 180L)
            "swipe" -> swipeFrom(startX, startY, endX, endY, 180L)
            "scroll" -> scroll(direction, delta)
            "back" -> performGlobalAction(GLOBAL_ACTION_BACK)
            "home" -> performGlobalAction(GLOBAL_ACTION_HOME)
            "recent" -> performGlobalAction(GLOBAL_ACTION_RECENTS)
            "rotate", "power" -> throw UnsupportedOperationException(
                "The $action action requires device control APIs not implemented by this service",
            )
            "volume_up" -> adjustVolume(1)
            "volume_down" -> adjustVolume(-1)
            "keyPress" -> injectKey(key)
            "textInput" -> injectText(key)
            "combo" -> handleCombo(raw)
            else -> Unit
        }
    }

    private fun tapAt(x: Float, y: Float) {
        dispatchGesture(
            GestureDescription.Builder()
                .addStroke(
                    GestureDescription.StrokeDescription(
                        movePath(x, y),
                        0L,
                        30L,
                    )
                )
                .build(),
            object : AccessibilityService.GestureResultCallback() {},
            null,
        )
    }

    private fun longPressAt(x: Float, y: Float) {
        dispatchGesture(
            GestureDescription.Builder()
                .addStroke(
                    GestureDescription.StrokeDescription(
                        movePath(x, y),
                        0L,
                        800L,
                    )
                )
                .build(),
            object : AccessibilityService.GestureResultCallback() {},
            null,
        )
    }

    private fun dragPath(startX: Float, startY: Float, endX: Float, endY: Float, durationMs: Long) {
        val path = Path().apply {
            moveTo(startX, startY)
            lineTo(endX, endY)
        }

        dispatchGesture(
            GestureDescription.Builder()
                .addStroke(
                    GestureDescription.StrokeDescription(
                        path,
                        0L,
                        durationMs,
                    )
                )
                .build(),
            object : AccessibilityService.GestureResultCallback() {},
            null,
        )
    }

    private fun swipeFrom(startX: Float, startY: Float, endX: Float, endY: Float, durationMs: Long) {
        val path = Path().apply {
            moveTo(startX, startY)
            lineTo(endX, endY)
        }

        dispatchGesture(
            GestureDescription.Builder()
                .addStroke(
                    GestureDescription.StrokeDescription(
                        path,
                        0L,
                        durationMs,
                    )
                )
                .build(),
            object : AccessibilityService.GestureResultCallback() {},
            null,
        )
    }

    private fun scroll(direction: String, delta: Int) {
        val action = if (direction == "up" || delta < 0) {
            AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
        } else {
            AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
        }
        rootInActiveWindow?.let { scrollNode(it, action) }
    }

    private fun scrollNode(node: AccessibilityNodeInfo, action: Int): Boolean {
        if (node.isScrollable && node.performAction(action)) return true
        for (index in 0 until node.childCount) {
            val child = node.getChild(index) ?: continue
            if (scrollNode(child, action)) return true
        }
        return false
    }

    private fun handleCombo(raw: Map<*, *>) {
        val combo = (raw["combo"] as? String)?.lowercase() ?: ""
        when (combo) {
            "ctrl+c" -> findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                ?.performAction(AccessibilityNodeInfo.ACTION_COPY)
            "ctrl+v" -> findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                ?.performAction(AccessibilityNodeInfo.ACTION_PASTE)
            else -> Unit
        }
    }

    private fun adjustVolume(direction: Int) {
        val audioManager = getSystemService(AudioManager::class.java) as? AudioManager ?: return
        if (direction > 0) {
            audioManager.adjustStreamVolume(
                AudioManager.STREAM_MUSIC,
                AudioManager.ADJUST_RAISE,
                AudioManager.FLAG_SHOW_UI,
            )
            return
        }

        audioManager.adjustStreamVolume(
            AudioManager.STREAM_MUSIC,
            AudioManager.ADJUST_LOWER,
            AudioManager.FLAG_SHOW_UI,
        )
    }

    private fun injectKey(key: String) {
        val normalized = key.trim()
        if (normalized.isEmpty()) return

        val code = when (normalized.lowercase()) {
            "backspace", "delete" -> KeyEvent.KEYCODE_DEL
            "enter", "return" -> KeyEvent.KEYCODE_ENTER
            "space" -> KeyEvent.KEYCODE_SPACE
            "tab" -> KeyEvent.KEYCODE_TAB
            "escape" -> KeyEvent.KEYCODE_ESCAPE
            else -> KeyEvent.KEYCODE_UNKNOWN
        }

        if (code != KeyEvent.KEYCODE_UNKNOWN) {
            if (Build.VERSION.SDK_INT < 33) {
                throw UnsupportedOperationException("Special key input requires Android 13 or later")
            }
            val connection = inputMethod?.currentInputConnection
                ?: throw IllegalStateException("No editable field is connected")
            connection.sendKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, code))
            connection.sendKeyEvent(KeyEvent(KeyEvent.ACTION_UP, code))
            return
        }

        if (normalized.length == 1) {
            injectText(normalized)
        }
    }

    private fun injectText(text: String) {
        if (text.isBlank()) return

        val root = rootInActiveWindow ?: return
        val target = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            ?: root.findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY)
            ?: root

        val existingText = target.text ?: ""
        val updatedText = if (existingText.isEmpty()) text else existingText.toString() + text
        val args = Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, updatedText)
        }

        target.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    private fun movePath(x: Float, y: Float): Path = Path().apply {
        moveTo(x, y)
    }
}
