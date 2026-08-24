package com.app.moonlightstream.ringtone_native

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Plays the incoming-call ringtone natively, on its own audio stream
 * (AudioAttributes.USAGE_NOTIFICATION_RINGTONE) — deliberately NOT through
 * Flutter's own audio engine (audioplayers/video_player share that
 * engine's session; using it for this reliably broke the app's video feed
 * playback, even after calling stop()).
 *
 * Implemented as a real FlutterPlugin — NOT an ad-hoc MethodChannel set up
 * only inside MainActivity — specifically so it's also reachable from the
 * separate, headless FlutterEngine that firebase_messaging spins up to run
 * the app's background message handler. That handler is the ONLY place an
 * incoming call is known about at all while the app is genuinely
 * backgrounded/locked; a channel scoped to MainActivity's engine would
 * silently no-op (MissingPluginException) from there.
 *
 * Player state lives in the companion object (a true JVM static), NOT on
 * the plugin instance — Flutter creates a SEPARATE plugin instance per
 * engine, so the background engine's instance and the main app's instance
 * are two different objects. Ringing is very often started by one engine
 * (background, when the call first arrives) and stopped by the other
 * (main app, once the user opens it and resolves the call) — instance
 * fields would silently miss that; the companion object is shared across
 * both within the same Android process.
 */
class RingtoneNativePlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.app.moonlightstream/ringtone")
        channel.setMethodCallHandler(this)
        Player.appContext = binding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "play" -> {
                Player.play()
                result.success(null)
            }
            "stop" -> {
                Player.stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        // Deliberately NOT stopping the ringtone here — the headless
        // background engine detaches (tearing this instance down) shortly
        // after its Dart callback returns, which is routinely BEFORE the
        // user has resolved the call. Player is a shared singleton
        // precisely so playback survives that and is stopped later by
        // whichever engine (this one again, or the main app's) actually
        // resolves the call — or by the safety timeout below.
    }

    private object Player {
        private const val TAG = "RingtoneNativePlugin"

        // Matches the backend's VIDEO_CALL_RING_TIMEOUT_SECONDS (~45s)
        // plus margin — pure safety net for the case where nothing ever
        // explicitly calls stop(). Runs on a Handler tied to the
        // process's main looper, not to any particular Dart isolate, so
        // it fires reliably regardless of what happens on the Dart side.
        private const val RING_SAFETY_TIMEOUT_MS = 60_000L

        lateinit var appContext: Context
        private var mediaPlayer: MediaPlayer? = null
        private val mainHandler = Handler(Looper.getMainLooper())
        private var pendingTimeout: Runnable? = null

        fun play() {
            if (mediaPlayer?.isPlaying == true) return
            stop() // release any stale instance first

            try {
                val resId = appContext.resources.getIdentifier(
                    "ringtone_default", "raw", appContext.packageName
                )
                if (resId == 0) {
                    Log.e(TAG, "ringtone_default raw resource not found")
                    return
                }
                val afd = appContext.resources.openRawResourceFd(resId) ?: return
                mediaPlayer = MediaPlayer().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    afd.close()
                    isLooping = true
                    prepare()
                    start()
                }

                val timeoutRunnable = Runnable {
                    Log.d(TAG, "Ring safety timeout reached — auto-stopping")
                    stop()
                }
                pendingTimeout = timeoutRunnable
                mainHandler.postDelayed(timeoutRunnable, RING_SAFETY_TIMEOUT_MS)
            } catch (e: Exception) {
                Log.e(TAG, "play() failed: ${e.message}")
            }
        }

        fun stop() {
            pendingTimeout?.let { mainHandler.removeCallbacks(it) }
            pendingTimeout = null

            mediaPlayer?.apply {
                try {
                    if (isPlaying) stop()
                } catch (e: Exception) {
                    Log.e(TAG, "stop() failed: ${e.message}")
                }
                release()
            }
            mediaPlayer = null
        }
    }
}
