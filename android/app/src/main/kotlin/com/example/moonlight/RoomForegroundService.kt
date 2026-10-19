package com.app.moonlightstream

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Keeps a club audio / video room running while the user is in other apps:
 * Android only lets an app keep using the mic (and keeps it alive) in the
 * background while it shows an ongoing notification from a foreground
 * service like this one.
 */
class RoomForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "club_room_live"
        private const val NOTIFICATION_ID = 41207

        fun start(context: Context, title: String, text: String, mic: Boolean) {
            val intent = Intent(context, RoomForegroundService::class.java)
                .putExtra("title", title)
                .putExtra("text", text)
                .putExtra("mic", mic)
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, RoomForegroundService::class.java))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra("title") ?: "Club room"
        val text = intent?.getStringExtra("text") ?: "You're in a live room · tap to return"
        val wantsMic = intent?.getBooleanExtra("mic", false) ?: false

        ensureChannel()
        val notification = buildNotification(title, text)

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                var type = ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                val micGranted = ContextCompat.checkSelfPermission(
                    this, Manifest.permission.RECORD_AUDIO
                ) == PackageManager.PERMISSION_GRANTED
                if (wantsMic && micGranted && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                }
                startForeground(NOTIFICATION_ID, notification, type)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            // Not allowed right now (e.g. started from the background):
            // the room still works while the app is open.
            stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // App swiped away from recents → the room is over for this user.
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    private fun buildNotification(title: String, text: String): Notification {
        val open = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        }
        val pending = PendingIntent.getActivity(
            this, 0, open,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(pending)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Live club rooms", NotificationManager.IMPORTANCE_LOW)
                .apply {
                    description = "Shown while you're in a club audio or video room"
                    setShowBadge(false)
                }
        )
    }
}
