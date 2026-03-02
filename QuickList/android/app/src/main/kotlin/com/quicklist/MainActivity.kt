package com.quicklist

import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

open class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "com.quicklist/tasker"
        const val ACTION_SHOW_POPUP = "com.quicklist.SHOW_POPUP"
        const val ACTION_SHOW_POPUP_INTERNAL = "com.quicklist.SHOW_POPUP_INTERNAL"
        const val EXTRA_LIST_NAME = "list_name"
        const val EXTRA_LIST_ID = "list_id"
    }

    private var methodChannel: MethodChannel? = null
    private var isDartBridgeReady: Boolean = false
    private val pendingPayloads = mutableListOf<Map<String, String>>()

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
                val listId = args?.get("list_id")?.toString()
                if (!action.isNullOrBlank()) {
                    val reply = Intent(action).apply {
                        setPackage(packageName)
                        if (!listName.isNullOrBlank()) {
                            putExtra(EXTRA_LIST_NAME, listName)
                        }
                        if (!listId.isNullOrBlank()) {
                            putExtra(EXTRA_LIST_ID, listId)
                        }
                    }
                    sendBroadcast(reply)
                }
                result.success(null)
                return@setMethodCallHandler
            }
            if (call.method == "taskerBridgeReady") {
                isDartBridgeReady = true
                flushPendingPayloads()
                result.success(null)
                return@setMethodCallHandler
            }
            if (call.method == "moveTaskToBack") {
                moveTaskToBack(true)
                result.success(null)
                return@setMethodCallHandler
            }
            if (call.method == "updateAvailableLists") {
                val args = call.arguments as? Map<*, *>
                val rawEntries = args?.get("list_entries") as? List<*>
                val entriesJson = JSONArray()
                rawEntries?.forEach { raw ->
                    val map = raw as? Map<*, *> ?: return@forEach
                    val id = map["id"]?.toString()?.trim().orEmpty()
                    val name = map["name"]?.toString()?.trim().orEmpty()
                    if (id.isNotBlank() && name.isNotBlank()) {
                        entriesJson.put(
                            JSONObject()
                                .put("id", id)
                                .put("name", name)
                        )
                    }
                }
                persistTaskerListCache(entriesJson.toString())
                result.success(null)
                return@setMethodCallHandler
            }
            result.notImplemented()
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val isTaskerAction = intent.action == ACTION_SHOW_POPUP || intent.action == ACTION_SHOW_POPUP_INTERNAL
        if (!isTaskerAction) return

        val listId = intent.getStringExtra(EXTRA_LIST_ID)?.trim().orEmpty()
        val listName = intent.getStringExtra(EXTRA_LIST_NAME)?.trim().orEmpty()
        if (listId.isBlank() && listName.isBlank()) return

        val payload = buildMap {
            if (listId.isNotBlank()) put(EXTRA_LIST_ID, listId)
            if (listName.isNotBlank()) put(EXTRA_LIST_NAME, listName)
        }
        if (methodChannel == null || !isDartBridgeReady) {
            pendingPayloads.add(payload)
        } else {
            sendPayloadToFlutter(payload)
        }
    }

    private fun sendPayloadToFlutter(payload: Map<String, String>) {
        methodChannel?.invokeMethod("taskerShowPopup", payload)
    }

    private fun flushPendingPayloads() {
        if (methodChannel == null || !isDartBridgeReady || pendingPayloads.isEmpty()) {
            return
        }
        val queued = pendingPayloads.toList()
        pendingPayloads.clear()
        queued.forEach { payload ->
            sendPayloadToFlutter(payload)
        }
    }

    private fun persistTaskerListCache(entriesJson: String) {
        val prefs: SharedPreferences =
            getSharedPreferences(TaskerPluginConstants.PREFS_NAME, MODE_PRIVATE)
        prefs.edit().putString(TaskerPluginConstants.PREFS_LISTS_JSON, entriesJson).apply()
    }
}