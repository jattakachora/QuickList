package com.quicklist

import android.os.Handler
import android.os.Looper

class PopupBridgeActivity : MainActivity() {
    private val uiHandler = Handler(Looper.getMainLooper())

    override fun onPostResume() {
        super.onPostResume()
        // Immediately return user focus to the previous app while popup overlay stays visible.
        uiHandler.postDelayed({ moveTaskToBack(true) }, 120L)
    }

    override fun onPause() {
        super.onPause()
        overridePendingTransition(0, 0)
    }
}
