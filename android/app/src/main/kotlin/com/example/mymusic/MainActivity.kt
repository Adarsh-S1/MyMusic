package com.example.mymusic

import android.content.Context
import android.media.MediaScannerConnection
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.chaquo.python.Python

class MainActivity : FlutterActivity() {
    private val MEDIA_SCANNER_CHANNEL = "com.ytgroove/media_scanner"
    private val PYTHON_CHANNEL = "com.example.mymusic/python"

    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return AudioServicePlugin.getFlutterEngine(context)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ─── Media scanner channel ──────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_SCANNER_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "scanFile") {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        MediaScannerConnection.scanFile(
                            this, arrayOf(path), null
                        ) { _, uri -> result.success(uri?.toString()) }
                    } else {
                        result.error("INVALID_PATH", "Path is null", null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // ─── Python Async Channel ──────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PYTHON_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "execute") {
                    val functionName = call.argument<String>("function")
                    val args = call.argument<List<Any>>("args") ?: emptyList()
                    
                    Thread {
                        try {
                            val py = Python.getInstance()
                            val module = py.getModule("ytdlp_wrapper")
                            val pyResult = module.callAttr(functionName!!, *args.toTypedArray())
                            val jsonString = pyResult.toString()
                            runOnUiThread { result.success(jsonString) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("PYTHON_ERROR", e.message, null) }
                        }
                    }.start()
                } else {
                    result.notImplemented()
                }
            }
    }
}
