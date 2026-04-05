package com.blindsocial.app

import com.ryanheise.audioservice.AudioServiceActivity
import android.content.Intent
import android.app.Activity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var mediaProjectionPermissionResultCode: Int = Activity.RESULT_CANCELED
    private var mediaProjectionPermissionResultData: Intent? = null

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        // LiveKit screen recording request code is typically handled by the plugin,
        // but if we need to pass the result to the service, the plugin usually does it automatically
        // as long as the service is correctly registered in AndroidManifest.xml
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.blindsocial.app/foreground")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startNativeService" -> {
                        val serviceIntent = Intent(this, NativeScreenShareService::class.java)
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(true)
                    }
                    "stopNativeService" -> {
                        val serviceIntent = Intent(this, NativeScreenShareService::class.java)
                        stopService(serviceIntent)
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
}
