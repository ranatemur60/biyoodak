package com.tubitak2204.biyoodak

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "biyoodak/screen")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val th = (call.argument<List<Int>>("thresholds") ?: listOf(30, 45, 60))
                        val reset = call.argument<Int>("resetMin") ?: 30
                        val name = call.argument<String>("name") ?: ""
                        ScreenState.prefs(this).edit()
                            .putBoolean("enabled", true)
                            .putString("thresholds", th.joinToString(","))
                            .putInt("resetMin", reset)
                            .putString("name", name)
                            .apply()
                        ScreenTimeService.start(this)
                        result.success(true)
                    }
                    "stop" -> {
                        ScreenState.prefs(this).edit().putBoolean("enabled", false).apply()
                        stopService(Intent(this, ScreenTimeService::class.java))
                        result.success(true)
                    }
                    "stats" -> result.success(ScreenState.stats(this))
                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= 33 &&
                            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                            != PackageManager.PERMISSION_GRANTED
                        ) {
                            ActivityCompat.requestPermissions(
                                this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 42
                            )
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleNotificationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleNotificationIntent(intent)
    }

    /** Bildirim tepki analizi: bildirimin gönderilmesinden açılmasına kadar geçen süre. */
    private fun handleNotificationIntent(i: Intent?) {
        val posted = i?.getLongExtra(ScreenTimeService.EXTRA_POSTED_AT, 0L) ?: 0L
        if (posted > 0) {
            ScreenState.addLatency(this, System.currentTimeMillis() - posted)
            i?.removeExtra(ScreenTimeService.EXTRA_POSTED_AT)
        }
    }
}
