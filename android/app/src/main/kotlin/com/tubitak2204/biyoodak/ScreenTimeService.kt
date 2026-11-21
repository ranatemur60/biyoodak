package com.tubitak2204.biyoodak

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.KeyguardManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import java.util.Calendar

/**
 * Akıllı Mola Bildirimleri: Ekranın açık kaldığı sürekli kullanım süresini
 * arka planda izler. 30, 45 ve 60. dakikalarda uyarı verir; ekran
 * 30 dakika kapalı kalırsa sayaç sıfırlanır; kapalı geçen süre sayılmaz.
 */
class ScreenTimeService : Service() {
    companion object {
        const val EXTRA_POSTED_AT = "biyo_notif_posted_at"
        private const val CH_ONGOING = "biyo_takip"
        private const val CH_ALERT = "biyo_mola"
        private const val ID_ONGOING = 1001
        private const val TICK_MS = 20_000L
        private const val MAX_GAP_MS = 90_000L

        /** Kullanıcının deneyebilmesi için hemen bir örnek mola bildirimi gönderir. */
        fun sendTest(c: Context) {
            createChannels(c)
            val name = ScreenState.prefs(c).getString("name", "") ?: ""
            val hi = if (name.isNotBlank()) "$name, " else ""
            val n = NotificationCompat.Builder(c, CH_ALERT)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("Mola bildirimi deneme 🔔")
                .setContentText("${hi}bildirimler çalışıyor. 30, 45 ve 60. dakikada böyle uyarılar gelecek.")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(
                    PendingIntent.getActivity(
                        c, 99, Intent(c, MainActivity::class.java),
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )
                .build()
            try {
                (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(2999, n)
            } catch (_: SecurityException) {
            }
        }

        fun createChannels(c: Context) {
            if (Build.VERSION.SDK_INT < 26) return
            val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(
                NotificationChannel(CH_ONGOING, "Ekran süresi takibi", NotificationManager.IMPORTANCE_MIN)
            )
            nm.createNotificationChannel(
                NotificationChannel(CH_ALERT, "Akıllı Mola Bildirimleri", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "30, 45 ve 60 dakikalık ekran kullanımında uyarılar"
                }
            )
        }

        fun start(c: Context) {
            val i = Intent(c, ScreenTimeService::class.java)
            try {
                ContextCompat.startForegroundService(c, i)
            } catch (_: Exception) {
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var registered = false

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(c: Context, i: Intent) {
            when (i.action) {
                Intent.ACTION_SCREEN_ON, Intent.ACTION_USER_PRESENT -> onScreenOn()
                Intent.ACTION_SCREEN_OFF -> onScreenOff()
            }
        }
    }

    private val ticker = object : Runnable {
        override fun run() {
            tick()
            handler.postDelayed(this, TICK_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannels()
        val n = NotificationCompat.Builder(this, CH_ONGOING)
            .setSmallIcon(android.R.drawable.ic_menu_recent_history)
            .setContentTitle("NeuroVibe")
            .setContentText("Ekran süresi takibi açık · Akıllı Mola Bildirimleri")
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setContentIntent(openAppIntent(0, 0))
            .build()
        val type = if (Build.VERSION.SDK_INT >= 34) ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE else 0
        ServiceCompat.startForeground(this, ID_ONGOING, n, type)
        if (!registered) {
            val f = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(Intent.ACTION_USER_PRESENT)
            }
            ContextCompat.registerReceiver(this, receiver, f, ContextCompat.RECEIVER_NOT_EXPORTED)
            registered = true
        }
        // Servis sistem tarafından kapatılıp yeniden başlatıldıysa eski sayaç
        // açık kalmış olabilir: o anı ekranın kapandığı an kabul et.
        val stale = prefs().getLong("countFrom", 0L)
        if (stale > 0L) {
            prefs().edit().putLong("countFrom", 0L).putLong("lastOff", stale).apply()
        }
        if (isInUse()) onScreenOn() else onScreenOff()
        handler.post(ticker)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        handler.removeCallbacks(ticker)
        flush()
        ScreenState.prefs(this).edit().putLong("countFrom", 0L).apply()
        if (registered) {
            try {
                unregisterReceiver(receiver)
            } catch (_: Exception) {
            }
            registered = false
        }
        super.onDestroy()
    }

    private fun prefs() = ScreenState.prefs(this)

    /** Telefon şu an kullanılıyor mu: ekran açık VE kilit ekranı geçilmiş. */
    private fun isInUse(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return pm.isInteractive && !km.isKeyguardLocked
    }

    private fun onScreenOn() {
        // Kilit ekranında beklerken (bildirime bakmak vb.) sayılmaz;
        // kilit açılınca (USER_PRESENT) sayım başlar.
        if (!isInUse()) return
        val p = prefs()
        if (p.getLong("countFrom", 0L) > 0L) return // zaten sayıyor
        val now = System.currentTimeMillis()
        val off = p.getLong("lastOff", 0L)
        val resetMs = p.getInt("resetMin", 30) * 60_000L
        val e = p.edit()
        val today = ScreenState.dayKey(now)
        if ((off > 0 && now - off >= resetMs) || p.getString("useDay", "") != today) {
            // Telefon 30 dk kapalı kaldı (mola) ya da yeni gün başladı: sıfırla
            e.putLong("useMs", 0L).putInt("alertsSent", 0).putString("useDay", today)
        }
        e.putLong("countFrom", now).apply()
    }

    private fun onScreenOff() {
        val p = prefs()
        val from = p.getLong("countFrom", 0L)
        val stop = flush()
        if (from > 0L || p.getLong("lastOff", 0L) == 0L) {
            p.edit().putLong("countFrom", 0L).putLong("lastOff", stop).apply()
        }
    }

    /**
     * Sayılan süreyi kalıcı sayaçlara ekler ve sayımın bittiği anı döndürür.
     * İki sayım arasında 90 sn'den uzun boşluk varsa telefon uykudaydı ya da
     * uygulama durdurulmuştu: o süre kullanım sayılmaz.
     */
    private fun flush(): Long {
        val p = prefs()
        val from = p.getLong("countFrom", 0L)
        val now = System.currentTimeMillis()
        if (from <= 0L) return now
        if (now - from > MAX_GAP_MS || now < from) {
            p.edit().putLong("countFrom", now).apply()
            return from
        }
        ScreenState.addUsage(this, from, now)
        p.edit().putLong("useMs", p.getLong("useMs", 0L) + (now - from)).putLong("countFrom", now).apply()
        return now
    }

    private fun tick() {
        val p = prefs()
        val counting = p.getLong("countFrom", 0L) > 0L
        val inUse = isInUse()
        // Ekran olayı kaçırıldıysa gerçek duruma göre düzelt.
        if (counting && !inUse) {
            onScreenOff()
            return
        }
        if (!counting) {
            if (inUse) onScreenOn()
            return
        }
        val gapStart = p.getLong("countFrom", 0L)
        if (System.currentTimeMillis() - gapStart > MAX_GAP_MS) {
            // Uzun boşluk: telefon kullanılmıyordu. Mola sayılıp yeniden başlar.
            p.edit().putLong("countFrom", 0L).putLong("lastOff", gapStart).apply()
            onScreenOn()
            return
        }
        flush()
        val use = p.getLong("useMs", 0L)
        val th = (p.getString("thresholds", "30,45,60") ?: "30,45,60").split(",").mapNotNull { it.trim().toIntOrNull() }
        val sent = p.getInt("alertsSent", 0)
        if (sent < th.size && use >= th[sent] * 60_000L) {
            notifyLevel(sent, th[sent])
            p.edit().putInt("alertsSent", sent + 1).apply()
        }
    }

    private fun isNight(): Boolean {
        val h = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        return h >= 22 || h < 6
    }

    private fun notifyLevel(level: Int, minutes: Int) {
        val name = prefs().getString("name", "") ?: ""
        val hi = if (name.isNotBlank()) "$name, " else ""
        val student = prefs().getBoolean("student", false)
        val exam = prefs().getString("exam", "") ?: ""
        val examLine = if (exam.isNotBlank()) " $exam hazırlığında her saat değerli." else ""
        val (title, body) = if (student) {
            when (level) {
                0 -> "$minutes dakikadır telefondasın 📚" to "${hi}bu yaklaşık 1 ders saati demek. Kitabına dönmeye ne dersin?"
                1 -> "$minutes dakika oldu ⏱️" to "${hi}bu sürede bir Pomodoro bloğu yapabilirdin: 25 dk ders + 5 dk mola. Hemen başlayalım mı?"
                else -> "$minutes dakika doldu! 🛑" to "${hi}telefonu kenara koy ve 30 dakika ders çalış.$examLine"
            }
        } else {
            when (level) {
                0 -> "$minutes dakikadır ekrandasın 👀" to "${hi}gözlerini 20 saniye boyunca 6 metre uzağa odakla (20-20-20 kuralı)."
                1 -> "$minutes dakika oldu ⏳" to "${hi}kalk, bir bardak su iç ve biraz esne. Kısa bir mola odağını tazeler."
                else -> "$minutes dakika doldu! 🛑" to "${hi}artık telefonu bırakma zamanı. Hadi telefonu kapatıp 30 dakikalık bir mola verelim; sayaç sonra sıfırlanır."
            }
        }
        val nightNote = if (student) " Yarın okul var 🌙 Gece ekran ışığı uykunu bozar, uykusuzluk da ertesi günkü dikkati düşürür."
            else " Gece ekran ışığı melatonini baskılayıp uykuya geçişi zorlaştırabilir."
        val text = if (isNight()) "$body$nightNote" else body
        val now = System.currentTimeMillis()
        val n = NotificationCompat.Builder(this, CH_ALERT)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setWhen(now)
            .setContentIntent(openAppIntent(level + 1, now))
            .build()
        try {
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(2000 + level, n)
        } catch (_: SecurityException) {
        }
    }

    private fun openAppIntent(req: Int, postedAt: Long): PendingIntent {
        val i = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            if (postedAt > 0) putExtra(EXTRA_POSTED_AT, postedAt)
        }
        return PendingIntent.getActivity(
            this, req, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun createChannels() = createChannels(this)
}
