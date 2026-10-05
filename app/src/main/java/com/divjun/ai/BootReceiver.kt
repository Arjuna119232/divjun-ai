package com.divjun.ai

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            // Reschedule any periodic syncs or notifications
            SyncService.schedulePeriodicSync(context)
            Log.d("DIVJUN", "BootReceiver: scheduled periodic sync")
        }
    }
}