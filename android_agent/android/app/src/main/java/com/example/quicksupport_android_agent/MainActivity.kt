package com.example.quicksupport_android_agent

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.content.ComponentName
import android.os.Build
import java.security.SecureRandom
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "quicksupport.accessibility",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSettings" -> {
                    val prefs = getSharedPreferences("quicksupport", MODE_PRIVATE)
                    val token = prefs.getString("token", null) ?: ByteArray(32).also {
                        SecureRandom().nextBytes(it)
                    }.joinToString("") { "%02x".format(it) }.also {
                        prefs.edit().putString("token", it).commit()
                    }
                    result.success(mapOf("token" to token, "server" to prefs.getString("server", "")))
                }
                "saveServer" -> {
                    val server = call.argument<String>("server") ?: ""
                    getSharedPreferences("quicksupport", MODE_PRIVATE).edit().putString("server", server).apply()
                    result.success(null)
                }
                "startScreenService" -> {
                    ScreenShareService.onReady = { error ->
                        if (error == null) result.success(null)
                        else result.error("SCREEN_SERVICE", error, null)
                    }
                    val intent = Intent(this, ScreenShareService::class.java)
                    try {
                        if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                    } catch (error: Exception) {
                        ScreenShareService.onReady = null
                        result.error("SCREEN_SERVICE", error.message, null)
                    }
                }
                "stopScreenService" -> {
                    stopService(Intent(this, ScreenShareService::class.java))
                    result.success(null)
                }
                "handleAction" -> {
                    val arguments = call.arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
                    try {
                        RemoteControlAccessibilityService.handleRemoteAction(arguments)
                        result.success(true)
                    } catch (error: UnsupportedOperationException) {
                        result.error("UNSUPPORTED_ACTION", error.message, null)
                    } catch (error: IllegalStateException) {
                        result.error("ACTION_UNAVAILABLE", error.message, null)
                    }
                }
                "isServiceEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val accessibilityManager = getSystemService(AccessibilityManager::class.java)
            as? AccessibilityManager ?: return false

        val targetService = ComponentName(this, RemoteControlAccessibilityService::class.java)
        val enabledServices = accessibilityManager.getEnabledAccessibilityServiceList(
            AccessibilityServiceInfo.FEEDBACK_ALL_MASK,
        )

        return enabledServices.any { ComponentName.unflattenFromString(it.id) == targetService }
    }
}
