package com.example.exm1

import android.app.PictureInPictureParams
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val pictureInPictureChannel = "video_player/pip"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            pictureInPictureChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> enterPictureInPicture(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun enterPictureInPicture(
        result: MethodChannel.Result
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.error(
                "PIP_UNSUPPORTED",
                "Picture-in-picture requires Android 8.0 or newer.",
                null
            )
            return
        }

        try {
            val parameters = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .build()
            result.success(enterPictureInPictureMode(parameters))
        } catch (exception: IllegalStateException) {
            result.error(
                "PIP_FAILED",
                exception.message ?: "Unable to enter picture-in-picture mode.",
                null
            )
        }
    }
}
