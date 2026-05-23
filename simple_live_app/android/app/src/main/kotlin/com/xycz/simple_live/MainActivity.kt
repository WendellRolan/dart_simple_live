package com.xycz.simple_live

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "simple_live/background_playback",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    startService()
                    result.success(null)
                }

                "stop" -> {
                    stopService(Intent(this, BackgroundPlaybackService::class.java))
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun startService() {
        val intent = Intent(this, BackgroundPlaybackService::class.java)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
}
