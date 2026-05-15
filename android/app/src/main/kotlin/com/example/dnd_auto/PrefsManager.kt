package com.example.dnd_auto

import android.content.Context
import android.content.SharedPreferences

class PrefsManager(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun getSelectedApps(): Set<String> =
        prefs.getStringSet(KEY_SELECTED_APPS, emptySet()) ?: emptySet()

    fun setSelectedApps(packages: Set<String>) {
        prefs.edit().putStringSet(KEY_SELECTED_APPS, packages).apply()
    }

    fun removeSelectedApp(packageName: String) {
        val updated = getSelectedApps().toMutableSet()
        updated.remove(packageName)
        setSelectedApps(updated)
    }

    fun isServiceEnabled(): Boolean = prefs.getBoolean(KEY_SERVICE_ENABLED, false)

    fun setServiceEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_SERVICE_ENABLED, enabled).apply()
    }

    fun isFocusModeSuggested(): Boolean = prefs.getBoolean(KEY_FOCUS_MODE_SUGGESTED, false)

    fun setFocusModeSuggested(suggested: Boolean) {
        prefs.edit().putBoolean(KEY_FOCUS_MODE_SUGGESTED, suggested).apply()
    }

    fun getLastForegroundPackage(): String? = prefs.getString(KEY_LAST_FOREGROUND_PACKAGE, null)

    fun setLastForegroundPackage(packageName: String?) {
        prefs.edit().putString(KEY_LAST_FOREGROUND_PACKAGE, packageName).apply()
    }

    fun getPausedReason(): String? = prefs.getString(KEY_PAUSED_REASON, null)

    fun setPausedReason(reason: String?) {
        prefs.edit().putString(KEY_PAUSED_REASON, reason).apply()
    }

    companion object {
        private const val PREFS_NAME = "auto_dnd_prefs"
        private const val KEY_SELECTED_APPS = "selected_apps"
        private const val KEY_SERVICE_ENABLED = "service_enabled"
        private const val KEY_FOCUS_MODE_SUGGESTED = "focus_mode_suggested"
        private const val KEY_LAST_FOREGROUND_PACKAGE = "last_foreground_package"
        private const val KEY_PAUSED_REASON = "paused_reason"
    }
}
