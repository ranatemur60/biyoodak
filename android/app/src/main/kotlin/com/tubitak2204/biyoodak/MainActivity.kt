package com.tubitak2204.biyoodak

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.net.Uri
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
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
                        val student = call.argument<Boolean>("student") ?: false
                        val exam = call.argument<String>("exam") ?: ""
                        val sp = ScreenState.prefs(this)
                        val wasOn = sp.getBoolean("enabled", false)
                        val ed = sp.edit()
                        // Takip yeni açılıyorsa sayaç sıfırdan başlar.
                        if (!wasOn) ed.putLong("useMs", 0L).putInt("alertsSent", 0)
                        ed
                            .putBoolean("enabled", true)
                            .putString("thresholds", th.joinToString(","))
                            .putInt("resetMin", reset)
                            .putString("name", name)
                            .putBoolean("student", student)
                            .putString("exam", exam)
                            .apply()
                        ScreenTimeService.start(this)
                        result.success(true)
                    }
                    "stop" -> {
                        ScreenState.prefs(this).edit().putBoolean("enabled", false).apply()
                        stopService(Intent(this, ScreenTimeService::class.java))
                        result.success(true)
                    }
                    "stats" -> {
                        val m = ScreenState.stats(this).toMutableMap()
                        m["notifAllowed"] = NotificationManagerCompat.from(this).areNotificationsEnabled()
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        m["batteryOk"] = Build.VERSION.SDK_INT < 23 || pm.isIgnoringBatteryOptimizations(packageName)
                        result.success(m)
                    }
                    "test" -> {
                        ScreenTimeService.sendTest(this)
                        result.success(true)
                    }
                    "openNotifSettings" -> {
                        try {
                            val i = if (Build.VERSION.SDK_INT >= 26) {
                                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            } else {
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                            }
                            startActivity(i)
                        } catch (_: Exception) {
                        }
                        result.success(true)
                    }
                    "requestBattery" -> {
                        // Özel izin gerektirmeyen ayar ekranı: pil optimizasyonu listesi
                        try {
                            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                        } catch (_: Exception) {
                            try {
                                startActivity(
                                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                                )
                            } catch (_: Exception) {
                            }
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (ScreenState.prefs(this).getBoolean("enabled", false)) ScreenTimeService.start(this)
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
