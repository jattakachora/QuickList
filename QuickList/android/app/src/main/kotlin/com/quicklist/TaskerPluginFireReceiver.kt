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
        val listName = pluginBundle?.getString(MainActivity.EXTRA_LIST_NAME)?.trim().orEmpty()
        if (listName.isBlank()) {
            return
        }

        val launchIntent = Intent(context, PopupBridgeActivity::class.java).apply {
            action = MainActivity.ACTION_SHOW_POPUP_INTERNAL
            putExtra(MainActivity.EXTRA_LIST_NAME, listName)
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION
            )
        }
        context.startActivity(launchIntent)
    }
}
