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
