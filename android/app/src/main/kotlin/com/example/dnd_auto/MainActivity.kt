package com.example.dnd_auto

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "auto_dnd/methods"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                val prefsManager = PrefsManager(this)
                val appRepository = AppRepository(this)
                val dndManager = DndManager(this)

                when (call.method) {
                    "getStatus" -> {
                        result.success(
                            mapOf(
                                "hasUsageAccess" to PermissionUtils.hasUsageAccess(this),
                                "hasNotificationPolicyAccess" to PermissionUtils.hasNotificationPolicyAccess(this),
                                "serviceEnabled" to prefsManager.isServiceEnabled(),
                                "dndEnabled" to dndManager.isDndEnabled(),
                                "dndEnabledByUs" to prefsManager.isDndEnabledByUs(),
                                "selectedApps" to sanitizeSelectedApps(prefsManager, appRepository),
                                "foregroundPackageName" to prefsManager.getLastForegroundPackage(),
                                "foregroundAppName" to prefsManager.getLastForegroundPackage()
                                    ?.let { appRepository.getAppInfo(it)?.appName },
                                "pausedReason" to prefsManager.getPausedReason(),
                            ),
                        )
                    }

                    "getInstalledApps" -> {
                        result.success(appRepository.getLaunchableApps().map { it.toMap() })
                    }

                    "saveSelectedApps" -> {
                        val packages = (call.argument<List<String>>("packages") ?: emptyList())
                            .filter(appRepository::isInstalled)
                            .toSet()
                        prefsManager.setSelectedApps(packages)
                        result.success(null)
                    }

                    "removeSelectedApp" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName != null) {
                            prefsManager.removeSelectedApp(packageName)
                        }
                        result.success(null)
                    }

                    "startMonitoring" -> {
                        if (!PermissionUtils.hasUsageAccess(this) ||
                            !PermissionUtils.hasNotificationPolicyAccess(this)
                        ) {
                            result.error(
                                "permissions_missing",
                                "Usage access and DND access are required.",
                                null,
                            )
                        } else {
                            prefsManager.setServiceEnabled(true)
                            MonitorService.startService(this)
                            result.success(null)
                        }
                    }

                    "stopMonitoring" -> {
                        prefsManager.setServiceEnabled(false)
                        if (prefsManager.isDndEnabledByUs() &&
                            PermissionUtils.hasNotificationPolicyAccess(this)
                        ) {
                            dndManager.disableDnd()
                            prefsManager.setDndEnabledByUs(false)
                        }
                        MonitorService.stopService(this)
                        result.success(null)
                    }

                    "openUsageAccessSettings" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }

                    "openDndAccessSettings" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
                        result.success(null)
                    }

                    "openBatteryOptimizationSettings" -> {
                        openBatteryOptimizationSettings()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun sanitizeSelectedApps(
        prefsManager: PrefsManager,
        appRepository: AppRepository,
    ): List<Map<String, Any?>> {
        val selected = prefsManager.getSelectedApps()
        val installed = selected.filter(appRepository::isInstalled)
        if (installed.toSet() != selected) {
            prefsManager.setSelectedApps(installed.toSet())
        }

        return installed.mapNotNull { packageName ->
            appRepository.getAppInfo(packageName)?.toMap()
        }.sortedBy {
            (it["appName"] as? String)?.lowercase()
        }
    }

    private fun openBatteryOptimizationSettings() {
        val powerManager = getSystemService(PowerManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !powerManager.isIgnoringBatteryOptimizations(packageName)
        ) {
            startActivity(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                },
            )
            return
        }

        startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
    }

    private fun AppInfo.toMap(): Map<String, Any?> {
        return mapOf(
            "packageName" to packageName,
            "appName" to appName,
            "iconBytes" to iconBytes,
        )
    }
}
