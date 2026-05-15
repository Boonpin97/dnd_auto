package com.example.dnd_auto

import android.app.NotificationManager
import android.content.Context

class DndManager(context: Context) {
    private val notificationManager = context.getSystemService(NotificationManager::class.java)

    fun enableDnd() {
        notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
    }

    fun disableDnd() {
        notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
    }

    fun isDndEnabled(): Boolean {
        return notificationManager.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALL
    }
}
