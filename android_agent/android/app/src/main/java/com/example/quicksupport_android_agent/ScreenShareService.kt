package com.example.quicksupport_android_agent

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

class ScreenShareService : Service() {
    companion object { var onReady: ((String?) -> Unit)? = null }
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val callback = onReady
        onReady = null
        try {
            val manager = getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= 26) {
                manager.createNotificationChannel(NotificationChannel("screen_share", "Berbagi layar", NotificationManager.IMPORTANCE_LOW))
            }
            val openApp = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "screen_share") else Notification.Builder(this)
            val notification = builder.setSmallIcon(android.R.drawable.ic_menu_view)
                .setContentTitle("QuickSupport sedang berbagi layar")
                .setContentText("Buka aplikasi untuk menghentikan sesi")
                .setContentIntent(openApp).setOngoing(true).build()
            if (Build.VERSION.SDK_INT >= 29) startForeground(1001, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
            else startForeground(1001, notification)
            callback?.invoke(null)
        } catch (error: Exception) { callback?.invoke(error.message ?: "Unable to start screen sharing"); stopSelf() }
        return START_NOT_STICKY
    }
}
