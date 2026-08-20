package com.app.moonlightstream

import android.app.Application
import android.os.Bundle
import android.util.Log
import com.hiennv.flutter_callkit_incoming.CallkitEventCallback
import com.hiennv.flutter_callkit_incoming.FlutterCallkitIncomingPlugin

private const val TAG = "MoonlightMainApplication"

// This class is what makes flutter_callkit_incoming's PhoneAccount/Telecom
// registration actually happen — without a custom Application class
// registering its event callback, Android has no PhoneAccount to route
// incoming calls to, which is exactly what "createConnectionFailed" /
// "onCreateIncomingConnectionFailed" means (confirmed by "Moonlight" not
// appearing at all under Settings -> Apps -> Default apps -> Calling
// accounts on the test device).
class MainApplication : Application() {

    private val callkitEventCallback = object : CallkitEventCallback {
        override fun onCallEvent(event: CallkitEventCallback.CallEvent, callData: Bundle) {
            // We don't need to do anything native-side here — our Dart
            // code already listens via FlutterCallkitIncoming.onEvent in
            // CallKitService.startListening() and handles Accept/Decline/
            // Timeout there. This native callback existing at all (even
            // as just a log line) is what's required for the plugin to
            // correctly register itself with Android's Telecom system.
            when (event) {
                CallkitEventCallback.CallEvent.ACCEPT -> Log.d(TAG, "Native onCallEvent: ACCEPT")
                CallkitEventCallback.CallEvent.DECLINE -> Log.d(TAG, "Native onCallEvent: DECLINE")
                else -> Log.d(TAG, "Native onCallEvent: $event")
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        FlutterCallkitIncomingPlugin.registerEventCallback(callkitEventCallback)
    }
}