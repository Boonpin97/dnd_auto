package com.example.dnd_auto

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import java.io.ByteArrayOutputStream

class AppRepository(private val context: Context) {
    private val packageManager = context.packageManager

    fun getLaunchableApps(): List<AppInfo> {
        val launcherIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        return packageManager.queryIntentActivities(launcherIntent, 0)
            .map { resolveInfo ->
                val packageName = resolveInfo.activityInfo.packageName
                val appName = resolveInfo.loadLabel(packageManager).toString()
                val icon = resolveInfo.loadIcon(packageManager)?.toPngBytes()
                AppInfo(packageName = packageName, appName = appName, iconBytes = icon)
            }
            .distinctBy { it.packageName }
            .sortedBy { it.appName.lowercase() }
    }

    fun getAppInfo(packageName: String): AppInfo? {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            AppInfo(
                packageName = packageName,
                appName = packageManager.getApplicationLabel(appInfo).toString(),
                iconBytes = packageManager.getApplicationIcon(appInfo).toPngBytes(),
            )
        } catch (_: Exception) {
            null
        }
    }

    fun isInstalled(packageName: String): Boolean {
        return try {
            packageManager.getApplicationInfo(packageName, 0)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun Drawable.toPngBytes(): ByteArray? {
        val bitmap = when (this) {
            is BitmapDrawable -> bitmap
            else -> {
                val width = intrinsicWidth.takeIf { it > 0 } ?: 96
                val height = intrinsicHeight.takeIf { it > 0 } ?: 96
                Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also { bitmap ->
                    val canvas = Canvas(bitmap)
                    setBounds(0, 0, canvas.width, canvas.height)
                    draw(canvas)
                }
            }
        }

        return ByteArrayOutputStream().use { stream ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        }
    }
}
