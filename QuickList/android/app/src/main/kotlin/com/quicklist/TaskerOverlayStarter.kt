package com.quicklist

import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import flutter.overlay.window.flutter_overlay_window.OverlayService

object TaskerOverlayStarter {
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val PREF_TARGET_LIST = "flutter.overlay_target_list_name"

    fun start(context: Context, listName: String) {
        if (!Settings.canDrawOverlays(context)) {
            return
        }

        val normalized = listName.trim()
        if (normalized.isBlank()) {
            return
        }

        // Keep target list in the same shared preferences file used by Flutter shared_preferences.
        context
            .getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(PREF_TARGET_LIST, normalized)
            .apply()

        // Force refresh any currently running overlay instance.
        val closeIntent = Intent(context, OverlayService::class.java).apply {
            putExtra(OverlayService.INTENT_EXTRA_IS_CLOSE_WINDOW, true)
        }
        context.startService(closeIntent)

        val showIntent = Intent(context, OverlayService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(showIntent)
        } else {
            context.startService(showIntent)
        }
    }
}
