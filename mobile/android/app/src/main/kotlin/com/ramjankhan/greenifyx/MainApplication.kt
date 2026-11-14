package com.ramjankhan.greenifyx

import android.app.Application
import android.os.Bundle
import android.util.Log
import com.hiennv.flutter_callkit_incoming.CallkitEventCallback
import com.hiennv.flutter_callkit_incoming.FlutterCallkitIncomingPlugin
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

/**
 * Declining a call from the lock screen must reach the server even when the app
 * isn't running, so the caller stops hearing it ring. The ring push carries the
 * API address and a one-time decline token for exactly this.
 */
class MainApplication : Application() {

    private val callEvents = object : CallkitEventCallback {
        override fun onCallEvent(event: CallkitEventCallback.CallEvent, callData: Bundle) {
            if (event != CallkitEventCallback.CallEvent.DECLINE) return
            @Suppress("UNCHECKED_CAST", "DEPRECATION")
            val extra = callData.getSerializable("EXTRA_CALLKIT_EXTRA") as? HashMap<String, Any?> ?: return
            val callId = callData.getString("EXTRA_CALLKIT_ID") ?: return
            val api = extra["api"]?.toString().orEmpty()
            val token = extra["declineToken"]?.toString().orEmpty()
            if (api.isEmpty() || token.isEmpty()) return
            Thread {
                try {
                    val conn = URL("$api/calls/decline").openConnection() as HttpURLConnection
                    conn.requestMethod = "POST"
                    conn.setRequestProperty("Content-Type", "application/json")
                    conn.connectTimeout = 8000
                    conn.readTimeout = 8000
                    conn.doOutput = true
                    OutputStreamWriter(conn.outputStream).use {
                        it.write(JSONObject(mapOf("callId" to callId, "token" to token)).toString())
                    }
                    Log.d("GreenifyXCall", "decline sent: ${conn.responseCode}")
                    conn.disconnect()
                } catch (e: Exception) {
                    Log.e("GreenifyXCall", "decline failed: ${e.message}")
                }
            }.start()
        }
    }

    override fun onCreate() {
        super.onCreate()
        FlutterCallkitIncomingPlugin.registerEventCallback(callEvents)
    }
}
