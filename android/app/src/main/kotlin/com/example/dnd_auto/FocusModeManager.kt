package com.example.dnd_auto

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.provider.Settings

class FocusModeManager(private val context: Context) {
    fun openFocusModeSettings(activity: Activity) {
        activity.startActivity(buildFocusModeSettingsIntent())
    }

    fun buildFocusModeSettingsIntent(): Intent {
        val packageManager = context.packageManager
        val candidates = listOf(
            Intent(ACTION_DIGITAL_WELLBEING_SETTINGS),
            Intent(Settings.ACTION_SETTINGS),
        )

        return candidates.firstOrNull { intent ->
            intent.resolveActivity(packageManager) != null
        } ?: Intent(Settings.ACTION_SETTINGS)
    }

    companion object {
        private const val ACTION_DIGITAL_WELLBEING_SETTINGS =
            "android.settings.DIGITAL_WELLBEING_SETTINGS"
    }
}
