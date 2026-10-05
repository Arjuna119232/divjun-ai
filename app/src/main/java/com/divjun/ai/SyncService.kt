package com.divjun.ai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

class SyncService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Keep service alive for foreground sync
        val notification = createNotification()
        startForeground(1001, notification)
        return START_STICKY
    }

    private fun createNotification(): Notification {
        val channelId = "divjun_sync_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "DIVJUN Sync",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Background sync for AI tools data"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("DIVJUN AI")
            .setContentText("Syncing AI tools data\u2026")
            .setSmallIcon(R.drawable.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    companion object {
        fun schedulePeriodicSync(context: Context) {
            val workRequest = PeriodicWorkRequest.Builder(SyncWorker::class.java, 24, TimeUnit.HOURS)
                .setInitialDelay(1, TimeUnit.HOURS)
                .addTag("divjun_periodic_sync")
                .build()
            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(
                    "divjun_periodic_sync",
                    ExistingPeriodicWorkPolicy.KEEP,
                    workRequest
                )
        }
    }
}

class SyncWorker(
    context: Context,
    params: WorkerParameters
) : Worker(context, params) {
    override fun doWork(): Result {
        // Fetch latest AI tools data, model lists, etc.
        // This runs in background every 24 hours
        try {
            // In a real app, you'd fetch from a server
            // For now, just return success
            return Result.success()
        } catch (e: Exception) {
            return Result.retry()
        }
    }
}