package com.example.dnd_auto

import android.app.NotificationManager
import android.content.Context

class DndManager(context: Context) {
    private val notificationManager = context.getSystemService(NotificationManager::class.java)

    fun enableDndAllowingMedia() {
        val existingPolicy = notificationManager.notificationPolicy
        val policy = NotificationManager.Policy(
            NotificationManager.Policy.PRIORITY_CATEGORY_MEDIA,
            NotificationManager.Policy.PRIORITY_SENDERS_ANY,
            NotificationManager.Policy.PRIORITY_SENDERS_ANY,
            existingPolicy.suppressedVisualEffects,
        )
        notificationManager.notificationPolicy = policy
        notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
    }

    fun disableDnd() {
        notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
    }

    fun isDndEnabled(): Boolean {
        return notificationManager.currentInterruptionFilter !=
            NotificationManager.INTERRUPTION_FILTER_ALL
    }
}
