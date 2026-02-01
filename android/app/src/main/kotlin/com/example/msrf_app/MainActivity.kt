package com.example.msrf_app

import android.os.Debug
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.msrf_app/memory"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getMemoryUsage") {
                val memoryBytes = getMemoryUsage()
                result.success(memoryBytes)
            } else {
                result.notImplemented()
            }
        }
    }

    /// Get current memory usage (PSS - Proportional Set Size) in bytes
    /// PSS is the most accurate memory metric for Android apps
    private fun getMemoryUsage(): Long {
        val memInfo = Debug.MemoryInfo()
        Debug.getMemoryInfo(memInfo)
        // getTotalPss() returns memory in KB, convert to bytes
        return memInfo.totalPss.toLong() * 1024
    }
}
