package com.example.dnd_auto

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

class MonitorService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var prefsManager: PrefsManager
    private lateinit var focusModeManager: FocusModeManager
    private lateinit var appRepository: AppRepository

    private val pollTask = object : Runnable {
        override fun run() {
            performMonitoringTick()
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        prefsManager = PrefsManager(this)
        focusModeManager = FocusModeManager(this)
        appRepository = AppRepository(this)
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification("Monitoring foreground app..."))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        prefsManager.setServiceEnabled(true)
        handler.removeCallbacks(pollTask)
        handler.post(pollTask)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(pollTask)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun performMonitoringTick() {
        val hasUsageAccess = PermissionUtils.hasUsageAccess(this)

        if (!hasUsageAccess) {
            prefsManager.setPausedReason("Usage access missing")
            prefsManager.setFocusModeSuggested(false)
            updateNotification("Monitoring paused: ${prefsManager.getPausedReason()}")
            return
        }

        prefsManager.setPausedReason(null)
        val selectedApps = prefsManager.getSelectedApps()
            .filter { appRepository.isInstalled(it) }
            .toSet()
        if (selectedApps != prefsManager.getSelectedApps()) {
            prefsManager.setSelectedApps(selectedApps)
        }

        val foregroundApp = getForegroundAppPackage()
        prefsManager.setLastForegroundPackage(foregroundApp)

        if (foregroundApp != null && selectedApps.contains(foregroundApp)) {
            prefsManager.setFocusModeSuggested(true)
            updateNotification("Focus Mode recommended for ${appRepository.getAppInfo(foregroundApp)?.appName ?: foregroundApp}")
            return
        }

        prefsManager.setFocusModeSuggested(false)

        updateNotification(
            foregroundApp?.let {
                "Foreground: ${appRepository.getAppInfo(it)?.appName ?: it}"
            } ?: "Monitoring foreground app...",
        )
    }

    private fun getForegroundAppPackage(): String? {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val time = System.currentTimeMillis()
        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            time - 5000,
            time,
        )
        return stats?.maxByOrNull { it.lastTimeUsed }?.packageName
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Auto Focus Monitoring",
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.description = "Foreground app monitoring for Auto Focus"
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(contentText: String): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            focusModeManager.buildFocusModeSettingsIntent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Auto Focus Active")
            .setContentText(contentText)
            .setSmallIcon(R.drawable.ic_auto_dnd_stat)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun updateNotification(contentText: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildNotification(contentText))
    }

    companion object {
        private const val CHANNEL_ID = "auto_focus_monitor"
        private const val NOTIFICATION_ID = 1001
        private const val POLL_INTERVAL_MS = 1_000L

        fun startService(context: Context) {
            val intent = Intent(context, MonitorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            context.stopService(Intent(context, MonitorService::class.java))
        }
    }
}
