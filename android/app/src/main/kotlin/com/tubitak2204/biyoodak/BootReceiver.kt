package com.tubitak2204.biyoodak

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Telefon yeniden başlatıldığında takip açıksa servisi yeniden başlatır. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent) {
        if (i.action == Intent.ACTION_BOOT_COMPLETED &&
            ScreenState.prefs(c).getBoolean("enabled", false)
        ) {
            ScreenState.prefs(c).edit().putLong("countFrom", 0L).apply()
            ScreenTimeService.start(c)
        }
    }
}
