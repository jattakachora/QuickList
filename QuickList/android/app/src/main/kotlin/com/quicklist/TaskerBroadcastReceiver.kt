package com.quicklist

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class TaskerBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != MainActivity.ACTION_SHOW_POPUP) {
            return
        }

        val listId = intent.getStringExtra(MainActivity.EXTRA_LIST_ID)?.trim().orEmpty()
        val listName = intent.getStringExtra(MainActivity.EXTRA_LIST_NAME)?.trim().orEmpty()
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
