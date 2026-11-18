package com.tubitak2204.biyoodak

import android.content.Context
import android.content.SharedPreferences
import java.util.Calendar

/** Ekran süresi sayaçları (yalnızca cihazda saklanır). */
object ScreenState {
    fun prefs(c: Context): SharedPreferences =
        c.getSharedPreferences("biyo_screen", Context.MODE_PRIVATE)

    fun dayKey(ms: Long): String {
        val cal = Calendar.getInstance().apply { timeInMillis = ms }
        return "${cal.get(Calendar.YEAR)}-${cal.get(Calendar.DAY_OF_YEAR)}"
    }

    /** Gece penceresi (22:00-06:00) — gece yarısından sonrası önceki akşama yazılır. */
    fun nightKey(ms: Long): String? {
        val cal = Calendar.getInstance().apply { timeInMillis = ms }
        val h = cal.get(Calendar.HOUR_OF_DAY)
        if (h in 6..21) return null
        if (h < 6) cal.add(Calendar.DAY_OF_YEAR, -1)
        return "${cal.get(Calendar.YEAR)}-${cal.get(Calendar.DAY_OF_YEAR)}"
    }

    /** En son gece penceresinin anahtarı (devam eden ya da biten). */
    fun lastNightKey(now: Long): String {
        nightKey(now)?.let { return it }
        val cal = Calendar.getInstance().apply { timeInMillis = now }
        cal.add(Calendar.DAY_OF_YEAR, -1)
        return "${cal.get(Calendar.YEAR)}-${cal.get(Calendar.DAY_OF_YEAR)}"
    }

    fun addUsage(c: Context, fromMs: Long, toMs: Long) {
        if (toMs <= fromMs) return
        val p = prefs(c)
        val e = p.edit()
        var t = fromMs
        // Dakika dakika dağıt (gün ve gece sınırlarını doğru böler)
        while (t < toMs) {
            val step = minOf(60_000L, toMs - t)
            val d = "day_" + dayKey(t)
            e.putLong(d, p.getLong(d, 0L) + step)
            nightKey(t)?.let { n ->
                val k = "night_$n"
                e.putLong(k, p.getLong(k, 0L) + step)
            }
            t += step
        }
        e.apply()
    }

    fun addLatency(c: Context, ms: Long) {
        if (ms <= 0 || ms > 6 * 3600_000L) return
        val p = prefs(c)
        val list = (p.getString("latencies", "") ?: "").split(",").filter { it.isNotBlank() }.toMutableList()
        list.add(ms.toString())
        while (list.size > 20) list.removeAt(0)
        p.edit().putString("latencies", list.joinToString(",")).apply()
    }

    fun stats(c: Context): Map<String, Any> {
        val p = prefs(c)
        val now = System.currentTimeMillis()
        val pendingFrom = p.getLong("countFrom", 0L)
        var today = p.getLong("day_" + dayKey(now), 0L)
        var night = p.getLong("night_" + lastNightKey(now), 0L)
        var use = p.getLong("useMs", 0L)
        if (pendingFrom in 1 until now) {
            val extra = now - pendingFrom
            today += extra
            if (nightKey(now) != null) night += extra
            use += extra
        }
        val lat = (p.getString("latencies", "") ?: "").split(",").filter { it.isNotBlank() }.map { it.toLong() }
        return mapOf(
            "enabled" to p.getBoolean("enabled", false),
            "todayMin" to (today / 60_000L).toInt(),
            "nightMin" to (night / 60_000L).toInt(),
            "currentUseMin" to (use / 60_000L).toInt(),
            "alertsSent" to p.getInt("alertsSent", 0),
            "latencies" to lat,
        )
    }
}
