package com.app.moonlightstream

import android.app.Activity
import android.graphics.PixelFormat
import android.graphics.SurfaceTexture
import android.media.AudioAttributes
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import android.os.SystemClock
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * Full-screen gift animations ("gift FX"): plays a transparent video in a
 * see-through native view laid over the whole app. The view never takes
 * touches, so the live underneath keeps working.
 *
 * The videos are "side-by-side alpha" MP4s — the left half is the picture,
 * the right half is its transparency as grey (H.264 has no alpha channel).
 * MediaPlayer decodes into an OES texture; a small GL shader joins the two
 * halves into one transparent picture and draws it into a SurfaceView on
 * top of the window. The display hardware combines that layer with the app,
 * so the app's own window is not redrawn for every video frame (a
 * TextureView was, which made the live stutter while a gift played).
 * (Drawing into a Flutter texture instead showed nothing on phones where
 * Flutter renders with Vulkan.) The video's own sound plays too.
 *
 * Dart → native: play {path, volume} → {textureId, width, height}
 *                stop {textureId}
 * native → Dart: "event" {textureId, type: firstFrame|completed|error}
 */
object GiftFxChannel {
    private const val NAME = "com.app.moonlightstream/gift_fx"
    private const val TAG = "GiftFx"
    private val players = HashMap<Long, Player>()
    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var nextId = 1L

    fun register(activity: Activity, messenger: BinaryMessenger) {
        val ch = MethodChannel(messenger, NAME)
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("bad_args", "path missing", null); return@setMethodCallHandler
                    }
                    val volume = (call.argument<Double>("volume") ?: 1.0).toFloat()
                    // Phone already overheating: skip the animation rather
                    // than add load (the system may close the app when hot).
                    if (tooHot(activity)) {
                        result.error("too_hot", "device is overheating", null); return@setMethodCallHandler
                    }
                    try {
                        val p = Player(activity, nextId++, path, volume)
                        players[p.id] = p
                        result.success(mapOf("textureId" to p.id, "width" to p.outW, "height" to p.outH))
                        p.start()
                    } catch (e: Throwable) {
                        Log.e(TAG, "play failed", e)
                        result.error("play_failed", e.message, null)
                    }
                }
                "stop" -> {
                    val id = (call.argument<Number>("textureId") ?: -1).toLong()
                    players.remove(id)?.release()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun tooHot(activity: Activity): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val pm = activity.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return false
        return pm.currentThermalStatus >= PowerManager.THERMAL_STATUS_SEVERE
    }

    private fun emit(id: Long, type: String) = main.post {
        channel?.invokeMethod("event", mapOf("textureId" to id, "type" to type))
    }

    private class Player(
        private val activity: Activity,
        val id: Long,
        private val path: String,
        private val volume: Float,
    ) : SurfaceHolder.Callback {
        val outW: Int
        val outH: Int
        private val videoW: Int
        private val videoH: Int

        private val thread = HandlerThread("gift-fx-gl").apply { start() }
        private val gl = Handler(thread.looper)
        @Volatile private var released = false
        private var firstFrameSent = false
        private var view: SurfaceView? = null
        private var shownAt = 0L // first frame time, for the fade-in
        private var viewW = 0
        private var viewH = 0

        private var display: EGLDisplay = EGL14.EGL_NO_DISPLAY
        private var context: EGLContext = EGL14.EGL_NO_CONTEXT
        private var config: EGLConfig? = null
        private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE
        private var targetSurface: Surface? = null
        private var program = 0
        private var oesTex = 0
        private var videoTexture: SurfaceTexture? = null
        private var videoSurface: Surface? = null
        private var player: MediaPlayer? = null
        private val texMatrix = FloatArray(16)

        init {
            val r = MediaMetadataRetriever()
            try {
                r.setDataSource(path)
                videoW = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toInt() ?: 0
                videoH = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toInt() ?: 0
            } finally {
                r.release()
            }
            if (videoW <= 0 || videoH <= 0) throw IllegalStateException("not a video: $path")
            outW = videoW / 2
            outH = videoH
        }

        /** Adds the see-through view over the app; playback starts when its surface is ready. */
        fun start() = main.post {
            if (released) return@post
            val root = activity.findViewById<ViewGroup>(android.R.id.content) ?: run {
                emit(id, "error"); return@post
            }
            val tv = SurfaceView(activity).apply {
                setZOrderOnTop(true)
                holder.setFormat(PixelFormat.TRANSLUCENT)
                isClickable = false
                isFocusable = false
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
                holder.addCallback(this@Player)
            }
            view = tv
            root.addView(tv, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT,
            ))
        }

        private var started = false

        override fun surfaceCreated(holder: SurfaceHolder) {}

        override fun surfaceChanged(holder: SurfaceHolder, format: Int, w: Int, h: Int) {
            viewW = w; viewH = h
            val target = holder.surface
            if (started) {
                // Back from the background: draw into the new surface.
                gl.post {
                    if (released || eglSurface != EGL14.EGL_NO_SURFACE) return@post
                    try {
                        targetSurface = target
                        createEglSurface()
                    } catch (e: Throwable) {
                        Log.e(TAG, "surface restore failed", e)
                    }
                }
                return
            }
            started = true
            gl.post {
                if (released) return@post
                try {
                    setUpGl(target)
                    setUpPlayer()
                } catch (e: Throwable) {
                    Log.e(TAG, "start failed", e)
                    emit(id, "error")
                }
            }
        }

        override fun surfaceDestroyed(holder: SurfaceHolder) {
            // The surface must not be drawn to once this returns: let the GL
            // thread drop it first (unless release() already cleaned up).
            if (released || !thread.isAlive) return
            val done = java.util.concurrent.CountDownLatch(1)
            if (gl.post { destroyEglSurface(); done.countDown() }) {
                done.await(500, java.util.concurrent.TimeUnit.MILLISECONDS)
            }
        }

        // ── GL ──────────────────────────────────────────────────────────
        private fun setUpGl(target: Surface) {
            targetSurface = target
            display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
            val v = IntArray(2)
            EGL14.eglInitialize(display, v, 0, v, 1)
            val attribs = intArrayOf(
                EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8, EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT, EGL14.EGL_NONE,
            )
            val configs = arrayOfNulls<EGLConfig>(1)
            val n = IntArray(1)
            EGL14.eglChooseConfig(display, attribs, 0, configs, 0, 1, n, 0)
            config = configs[0] ?: throw IllegalStateException("no EGL config")
            context = EGL14.eglCreateContext(
                display, config, EGL14.EGL_NO_CONTEXT,
                intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0,
            )
            createEglSurface()

            program = buildProgram()
            val tex = IntArray(1)
            GLES20.glGenTextures(1, tex, 0)
            oesTex = tex[0]
            GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTex)
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)

            videoTexture = SurfaceTexture(oesTex).apply {
                setDefaultBufferSize(videoW, videoH)
                setOnFrameAvailableListener({ drawFrame() }, gl)
            }
            videoSurface = Surface(videoTexture)
            clearToTransparent()
        }

        private fun createEglSurface() {
            eglSurface = EGL14.eglCreateWindowSurface(
                display, config, targetSurface, intArrayOf(EGL14.EGL_NONE), 0,
            )
            EGL14.eglMakeCurrent(display, eglSurface, eglSurface, context)
        }

        private fun destroyEglSurface() {
            if (eglSurface == EGL14.EGL_NO_SURFACE) return
            EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, context)
            EGL14.eglDestroySurface(display, eglSurface)
            eglSurface = EGL14.EGL_NO_SURFACE
        }

        private fun clearToTransparent() {
            GLES20.glClearColor(0f, 0f, 0f, 0f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
            EGL14.eglSwapBuffers(display, eglSurface)
        }

        /**
         * Where the video goes on screen (GL coordinates, origin bottom-left).
         * Portrait animations fill the width; wide ones are 1.5× the width,
         * cropped at the sides so the subject stays big. Centred.
         */
        private fun setViewport() {
            val w = if (outH >= outW) viewW.toFloat() else viewW * 1.5f
            val h = w * outH / outW
            GLES20.glViewport(
                ((viewW - w) / 2f).toInt(), ((viewH - h) / 2f).toInt(), w.toInt(), h.toInt(),
            )
        }

        private fun drawFrame() {
            if (released) return
            val st = videoTexture ?: return
            try {
                st.updateTexImage()
                st.getTransformMatrix(texMatrix)
                if (shownAt == 0L) shownAt = SystemClock.uptimeMillis()
                val fadeIn = ((SystemClock.uptimeMillis() - shownAt) / 180f).coerceAtMost(1f)
                render(fadeIn)
                if (!firstFrameSent) {
                    firstFrameSent = true
                    emit(id, "firstFrame")
                }
            } catch (e: Throwable) {
                Log.e(TAG, "draw failed", e)
            }
        }

        /** Draws the current video frame at [fade] (0 = clear, 1 = full). */
        private fun render(fade: Float) {
            if (eglSurface == EGL14.EGL_NO_SURFACE) return
            GLES20.glViewport(0, 0, viewW, viewH)
            GLES20.glClearColor(0f, 0f, 0f, 0f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
            setViewport()
            GLES20.glUseProgram(program)
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
            GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTex)
            GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "uTex"), 0)
            GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uFade"), fade)
            GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(program, "uSt"), 1, false, texMatrix, 0)
            val aPos = GLES20.glGetAttribLocation(program, "aPos")
            val aUv = GLES20.glGetAttribLocation(program, "aUv")
            QUAD.position(0)
            GLES20.glVertexAttribPointer(aPos, 2, GLES20.GL_FLOAT, false, 16, QUAD)
            GLES20.glEnableVertexAttribArray(aPos)
            QUAD.position(2)
            GLES20.glVertexAttribPointer(aUv, 2, GLES20.GL_FLOAT, false, 16, QUAD)
            GLES20.glEnableVertexAttribArray(aUv)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
            EGL14.eglSwapBuffers(display, eglSurface)
        }

        private fun buildProgram(): Int {
            fun shader(type: Int, src: String): Int {
                val s = GLES20.glCreateShader(type)
                GLES20.glShaderSource(s, src)
                GLES20.glCompileShader(s)
                val ok = IntArray(1)
                GLES20.glGetShaderiv(s, GLES20.GL_COMPILE_STATUS, ok, 0)
                if (ok[0] == 0) throw IllegalStateException(GLES20.glGetShaderInfoLog(s))
                return s
            }
            val p = GLES20.glCreateProgram()
            GLES20.glAttachShader(p, shader(GLES20.GL_VERTEX_SHADER, VERTEX))
            GLES20.glAttachShader(p, shader(GLES20.GL_FRAGMENT_SHADER, FRAGMENT))
            GLES20.glLinkProgram(p)
            return p
        }

        // ── Playback ────────────────────────────────────────────────────
        private fun setUpPlayer() {
            player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
                        .build(),
                )
                setDataSource(path)
                setSurface(videoSurface)
                setVolume(volume, volume)
                setOnPreparedListener { it.start() }
                setOnCompletionListener { emit(id, "completed") }
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "player error $what/$extra")
                    emit(id, "error")
                    true
                }
                prepareAsync()
            }
        }

        fun release() {
            if (released) return
            released = true
            gl.post {
                try { player?.stop() } catch (_: Throwable) {}
                // Fade the last frame out (~200 ms) instead of cutting it.
                if (firstFrameSent) {
                    try {
                        for (i in 4 downTo 0) {
                            render(i / 5f)
                            Thread.sleep(40)
                        }
                    } catch (_: Throwable) {}
                }
                try { player?.release() } catch (_: Throwable) {}
                player = null
                videoSurface?.release()
                videoTexture?.release()
                if (display != EGL14.EGL_NO_DISPLAY) {
                    destroyEglSurface()
                    EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
                    EGL14.eglDestroyContext(display, context)
                    EGL14.eglTerminate(display)
                }
                targetSurface = null // owned by the SurfaceView
                thread.quitSafely()
            }
            // Remove the view once the GL thread has faded out and let go.
            gl.post {
                main.post {
                    val v = view ?: return@post
                    view = null
                    (v.parent as? ViewGroup)?.removeView(v)
                }
            }
        }
    }

    // x, y, u, v — full-screen quad.
    private val QUAD: FloatBuffer = ByteBuffer.allocateDirect(16 * 4)
        .order(ByteOrder.nativeOrder()).asFloatBuffer().apply {
            put(floatArrayOf(
                -1f, -1f, 0f, 0f,
                1f, -1f, 1f, 0f,
                -1f, 1f, 0f, 1f,
                1f, 1f, 1f, 1f,
            ))
        }

    private const val VERTEX = """
        attribute vec2 aPos;
        attribute vec2 aUv;
        uniform mat4 uSt;
        varying vec2 vColor;
        varying vec2 vAlpha;
        void main() {
            gl_Position = vec4(aPos, 0.0, 1.0);
            // Left half = picture, right half = transparency.
            vColor = (uSt * vec4(aUv.x * 0.5, aUv.y, 0.0, 1.0)).xy;
            vAlpha = (uSt * vec4(0.5 + aUv.x * 0.5, aUv.y, 0.0, 1.0)).xy;
        }
    """

    private const val FRAGMENT = """
        #extension GL_OES_EGL_image_external : require
        precision mediump float;
        uniform samplerExternalOES uTex;
        uniform float uFade;
        varying vec2 vColor;
        varying vec2 vAlpha;
        void main() {
            vec3 c = texture2D(uTex, vColor).rgb;
            float a = texture2D(uTex, vAlpha).r;
            // Video-range edges: treat near-black as fully clear.
            a = clamp((a - 0.04) / 0.92, 0.0, 1.0) * uFade;
            gl_FragColor = vec4(c * a, a); // premultiplied
        }
    """
}
