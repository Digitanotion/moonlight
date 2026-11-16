package com.app.moonlightstream

import android.app.ActivityManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject

/**
 * Rings for an incoming call the instant its push arrives — before Flutter
 * starts.
 *
 * Booting Flutter in the background just to post the "X is calling"
 * notification takes seconds and ~100+ MB; on busy low-RAM phones Android's
 * low-memory killer stopped the app mid-start and the call never rang. This
 * receiver is plain Android code: it posts the same ringing notification in
 * a few milliseconds, then Flutter takes over as before.
 *
 * Shares everything with the Flutter side (NotificationService):
 *  - the same channel (incoming_call_ring_v2, system ringtone, looping via
 *    FLAG_INSISTENT — the system rings, so the phone freezing the app can't
 *    silence it),
 *  - the same notification id (Java hash of the session uuid — the Dart side
 *    computes it the same way), so the two never show twice and Flutter's
 *    existing dismiss calls clear this one too,
 *  - the same tap/Accept/Decline intents flutter_local_notifications uses,
 *    so the app's existing handlers open/answer the call unchanged.
 *
 * Only call pushes are touched; every other push passes through untouched
 * (this receiver never consumes or aborts the broadcast). It does nothing
 * while the app is on screen — the in-app banner rings there.
 */
class IncomingCallPushReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val type = intent.getStringExtra("type") ?: return
        val session = intent.getStringExtra("session_uuid")
        if (session.isNullOrEmpty()) return

        try {
            when {
                type == "video_call_incoming" -> {
                    if (!appIsOnScreen()) ring(context, intent, session)
                }
                // Caller cancelled / call ended / declined elsewhere: stop
                // ringing even if Flutter never got to start.
                type.startsWith("video_call_") ->
                    NotificationManagerCompat.from(context).cancel(notificationId(session))
            }
        } catch (e: Exception) {
            Log.e(TAG, "incoming-call push failed: ${e.message}")
        }
    }

    private fun ring(context: Context, intent: Intent, session: String) {
        ensureChannel(context)
        val id = notificationId(session)
        val caller = intent.getStringExtra("caller_name")?.takeIf { it.isNotBlank() } ?: "Someone"
        val audio = intent.getStringExtra("call_kind") == "audio"

        val payload = JSONObject().put("session_uuid", session)
        apiBaseUrl(context)?.let { payload.put("api_base_url", it) }
        val payloadStr = payload.toString()

        val open = PendingIntent.getActivity(
            context, id, launchIntent(context, "SELECT_NOTIFICATION", id, payloadStr),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle("$caller is calling")
            .setContentText(if (audio) "Incoming audio call" else "Incoming video call")
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(open)
            .setFullScreenIntent(open, true)
            // Ring no longer than the server's 45s ring timeout.
            .setTimeoutAfter(RING_TIMEOUT_MS)

        // Accept/Decline need the API address the app saved on its last run.
        if (payload.has("api_base_url")) {
            builder.addAction(0, "Decline", actionIntent(context, id, "DECLINE_CALL", payloadStr))
            builder.addAction(0, "Accept", actionIntent(context, id, "ACCEPT_CALL", payloadStr))
        }

        val notification = builder.build()
        notification.flags = notification.flags or android.app.Notification.FLAG_INSISTENT
        NotificationManagerCompat.from(context).notify(id, notification)
    }

    /** Same launch intent flutter_local_notifications builds for a tap. */
    private fun launchIntent(context: Context, action: String, id: Int, payload: String): Intent {
        val i = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        i.action = action
        i.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        i.putExtra("notificationId", id)
        i.putExtra("payload", payload)
        return i
    }

    /** Same intent flutter_local_notifications builds for a foreground action. */
    private fun actionIntent(context: Context, id: Int, actionId: String, payload: String): PendingIntent {
        val i = launchIntent(context, "SELECT_FOREGROUND_NOTIFICATION", id, payload)
        i.putExtra("actionId", actionId)
        i.putExtra("cancelNotification", true)
        return PendingIntent.getActivity(
            context, id * 31 + actionId.hashCode(), i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        // Must match NotificationService._createIncomingCallChannel —
        // whichever side creates it first fixes its settings.
        val channel = NotificationChannel(CHANNEL_ID, "Incoming calls", NotificationManager.IMPORTANCE_MAX)
        channel.description = "Rings for incoming calls when Moonlight is not open."
        channel.enableVibration(true)
        channel.setSound(
            Uri.parse("android.resource://${context.packageName}/raw/ringtone_default"),
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        nm.createNotificationChannel(channel)
    }

    private fun apiBaseUrl(context: Context): String? =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.call_api_base_url", null)
            ?.takeIf { it.isNotBlank() }

    private fun appIsOnScreen(): Boolean {
        val info = ActivityManager.RunningAppProcessInfo()
        ActivityManager.getMyMemoryState(info)
        return info.importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
    }

    companion object {
        private const val TAG = "IncomingCallPush"
        const val CHANNEL_ID = "incoming_call_ring_v2"
        private const val RING_TIMEOUT_MS = 50_000L

        /** Java String.hashCode — the Dart side computes the identical value. */
        fun notificationId(session: String): Int = session.hashCode()
    }
}
