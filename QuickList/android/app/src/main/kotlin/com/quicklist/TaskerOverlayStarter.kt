package com.quicklist

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import flutter.overlay.window.flutter_overlay_window.OverlayService

object TaskerOverlayStarter {
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val RAW_PREF_TARGET_LIST = "overlay_target_list_name"
    private const val PREF_TARGET_LIST = "flutter.overlay_target_list_name"
    private const val RAW_PREF_TARGET_LIST_ID = "overlay_target_list_id"
    private const val PREF_TARGET_LIST_ID = "flutter.overlay_target_list_id"
    private const val RAW_PREF_TARGET_TRIGGER_CLOCK = "overlay_target_trigger_clock"
    private const val PREF_TARGET_TRIGGER_CLOCK = "flutter.overlay_target_trigger_clock"
    private const val SHOW_DELAY_MS = 180L

    fun start(context: Context, listId: String?, listName: String?) {
        if (!Settings.canDrawOverlays(context)) {
            return
        }

        val normalizedId = listId?.trim().orEmpty()
        val normalizedName = listName?.trim().orEmpty()
        if (normalizedId.isBlank() && normalizedName.isBlank()) {
            return
        }

        val wrote = context
            .getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .edit()
            .apply {
                val triggerClock = System.currentTimeMillis()
                putLong(PREF_TARGET_TRIGGER_CLOCK, triggerClock)
                putLong(RAW_PREF_TARGET_TRIGGER_CLOCK, triggerClock)
                if (normalizedName.isNotBlank()) {
                    putString(PREF_TARGET_LIST, normalizedName)
                    putString(RAW_PREF_TARGET_LIST, normalizedName)
                } else {
                    remove(PREF_TARGET_LIST)
                    remove(RAW_PREF_TARGET_LIST)
                }
                if (normalizedId.isNotBlank()) {
                    putString(PREF_TARGET_LIST_ID, normalizedId)
                    putString(RAW_PREF_TARGET_LIST_ID, normalizedId)
                } else {
                    remove(PREF_TARGET_LIST_ID)
                    remove(RAW_PREF_TARGET_LIST_ID)
                }
            }
            .commit()
        if (!wrote) {
            return
        }

        if (OverlayService.isRunning) {
            val closeIntent = Intent(context, OverlayService::class.java).apply {
                putExtra(OverlayService.INTENT_EXTRA_IS_CLOSE_WINDOW, true)
            }
            context.startService(closeIntent)
            Handler(Looper.getMainLooper()).postDelayed(
                { startOverlayService(context) },
                SHOW_DELAY_MS
            )
        } else {
            startOverlayService(context)
        }
    }

    private fun startOverlayService(context: Context) {
        val showIntent = Intent(context, OverlayService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(showIntent)
        } else {
            context.startService(showIntent)
        }
    }
}