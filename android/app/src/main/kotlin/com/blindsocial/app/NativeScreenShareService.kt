package com.blindsocial.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class NativeScreenShareService : Service() {

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Blind Social Ekran Paylaşımı")
            .setContentText("Sistem Sesi ve Ekranınız odaya aktarılıyor.")
            // App'inizin iconuna göre güncelleyebilirsiniz. ic_launcher kullanılıyor varsayıyoruz.
            .setSmallIcon(resources.getIdentifier("ic_launcher", "mipmap", packageName))
            .setOngoing(true)
            .build()

        // NOT: Kullanıcı isteği doğrultusunda Android 14 MediaProjection hizmeti Foreground Service olarak
        // native Kotlin üzerinden yönetilecektir.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Blind Social Ekran Paylaşımı Kanalı",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(serviceChannel)
        }
    }

    companion object {
        const val CHANNEL_ID = "NativeScreenShareServiceChannel"
        const val NOTIFICATION_ID = 1001
    }
}
