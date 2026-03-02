package com.quicklist

import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

open class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "com.quicklist/tasker"
        const val ACTION_SHOW_POPUP = "com.quicklist.SHOW_POPUP"
        const val ACTION_SHOW_POPUP_INTERNAL = "com.quicklist.SHOW_POPUP_INTERNAL"
        const val EXTRA_LIST_NAME = "list_name"
    }

    private var methodChannel: MethodChannel? = null
    private var pendingPayload: Map<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "sendTaskerReply") {
                val args = call.arguments as? Map<*, *>
                val action = args?.get("action")?.toString()
                val listName = args?.get("list_name")?.toString()
                if (!action.isNullOrBlank()) {
                    val reply = Intent(action).apply {
                        setPackage(packageName)
                        if (!listName.isNullOrBlank()) {
                            putExtra(EXTRA_LIST_NAME, listName)
                        }
                    }
                    sendBroadcast(reply)
                }
                result.success(null)
                return@setMethodCallHandler
            }
            if (call.method == "updateAvailableLists") {
                val args = call.arguments as? Map<*, *>
                val rawLists = args?.get("list_names") as? List<*>
                val listNames = rawLists
                    ?.mapNotNull { it?.toString()?.trim() }
                    ?.filter { it.isNotBlank() }
                    ?.distinct()
                    ?: emptyList()

                persistTaskerListCache(listNames)
                result.success(null)
                return@setMethodCallHandler
            }
            result.notImplemented()
        }
        pendingPayload?.let {
            sendPayloadToFlutter(it)
            pendingPayload = null
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val isTaskerAction = intent.action == ACTION_SHOW_POPUP || intent.action == ACTION_SHOW_POPUP_INTERNAL
        if (!isTaskerAction) return

        val listName = intent.getStringExtra(EXTRA_LIST_NAME)?.trim().orEmpty()
        if (listName.isBlank()) return

        val payload = mapOf(EXTRA_LIST_NAME to listName)
        if (methodChannel == null) {
            pendingPayload = payload
        } else {
            sendPayloadToFlutter(payload)
        }
    }

    private fun sendPayloadToFlutter(payload: Map<String, String>) {
        methodChannel?.invokeMethod("taskerShowPopup", payload)
    }

    private fun persistTaskerListCache(listNames: List<String>) {
        val prefs: SharedPreferences =
            getSharedPreferences(TaskerPluginConstants.PREFS_NAME, MODE_PRIVATE)
        val json = JSONArray(listNames).toString()
        prefs.edit().putString(TaskerPluginConstants.PREFS_LISTS_JSON, json).apply()
    }
}
