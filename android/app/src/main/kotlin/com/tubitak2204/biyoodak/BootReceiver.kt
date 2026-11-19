package com.tubitak2204.biyoodak

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Telefon yeniden başlatıldığında veya uygulama güncellendiğinde takip açıksa servisi yeniden başlatır. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent) {
        if ((i.action == Intent.ACTION_BOOT_COMPLETED || i.action == Intent.ACTION_MY_PACKAGE_REPLACED) &&
            ScreenState.prefs(c).getBoolean("enabled", false)
        ) {
            ScreenState.prefs(c).edit().putLong("countFrom", 0L).apply()
            ScreenTimeService.start(c)
        }
    }
}
