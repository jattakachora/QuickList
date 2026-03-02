package com.quicklist

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class TaskerPluginFireReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != TaskerPluginConstants.ACTION_FIRE_SETTING) {
            return
        }

        val pluginBundle = intent.getBundleExtra(TaskerPluginConstants.EXTRA_BUNDLE)
        val listId = pluginBundle?.getString(MainActivity.EXTRA_LIST_ID)?.trim().orEmpty()
        val listName = pluginBundle?.getString(MainActivity.EXTRA_LIST_NAME)?.trim().orEmpty()
        if (listId.isBlank() && listName.isBlank()) {
            return
        }

        TaskerOverlayStarter.start(
            context = context,
            listId = listId.ifBlank { null },
            listName = listName.ifBlank { null },
        )
    }
}
