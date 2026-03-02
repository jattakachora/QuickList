package com.quicklist

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class TaskerBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != MainActivity.ACTION_SHOW_POPUP) {
            return
        }

        val listName = intent.getStringExtra(MainActivity.EXTRA_LIST_NAME)?.trim().orEmpty()
        if (listName.isBlank()) {
            return
        }

        TaskerOverlayStarter.start(context, listName)
    }
}
