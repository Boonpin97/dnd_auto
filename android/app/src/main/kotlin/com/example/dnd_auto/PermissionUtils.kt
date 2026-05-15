package com.example.dnd_auto

import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.Context

object PermissionUtils {
    fun hasUsageAccess(context: Context): Boolean {
        val manager = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = manager.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            context.applicationInfo.uid,
            context.packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun hasNotificationPolicyAccess(context: Context): Boolean {
        val notificationManager = context.getSystemService(NotificationManager::class.java)
        return notificationManager.isNotificationPolicyAccessGranted
    }
}
