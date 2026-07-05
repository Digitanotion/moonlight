package com.app.moonlightstream

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.app.moonlightstream/pip"
    private var methodChannel: MethodChannel? = null
    private var isVideoPlaying = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Pre-configure PiP params immediately so Android knows this
        // activity supports PiP before the user even opens a video.
        updatePipParams(videoPlaying = false)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, CHANNEL
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setVideoPlaying" -> {
                        isVideoPlaying = call.argument<Boolean>("playing") ?: false
                        // Update PiP params every time play state changes.
                        // On API 31+, setAutoEnterEnabled(true) means Android
                        // automatically enters PiP when the app is backgrounded
                        // — no onUserLeaveHint needed.
                        updatePipParams(videoPlaying = isVideoPlaying)
                        result.success(null)
                    }
                    "enterPip" -> {
                        enterPip()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun buildPipParams(videoPlaying: Boolean): PictureInPictureParams? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(9, 16))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder
                .setSeamlessResizeEnabled(true)
                .setAutoEnterEnabled(videoPlaying) // KEY: auto-enter on minimize
        }
        return builder.build()
    }

    private fun updatePipParams(videoPlaying: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val params = buildPipParams(videoPlaying) ?: return
            setPictureInPictureParams(params)
        }
    }

    // Fallback for older Android — home button press.
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (isVideoPlaying) enterPip()
    }

    private fun enterPip() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val params = buildPipParams(isVideoPlaying) ?: return
            enterPictureInPictureMode(params)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            @Suppress("DEPRECATION")
            enterPictureInPictureMode()
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        methodChannel?.invokeMethod(
            "onPipModeChanged",
            mapOf("active" to isInPictureInPictureMode)
        )
        if (!isInPictureInPictureMode) {
            isVideoPlaying = false
            updatePipParams(videoPlaying = false)
        }
    }
}