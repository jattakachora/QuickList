package com.quicklist

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject

class TaskerPluginConfigActivity : Activity() {
    private data class ListEntry(
        val id: String,
        val name: String,
    )

    private lateinit var listSpinner: Spinner
    private var availableEntries: List<ListEntry> = emptyList()
    private var selectedIndex: Int = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        setContentView(buildContentView())
        prefillFromIncomingIntent(intent)
    }

    private fun buildContentView(): ScrollView {
        val spacingMd = dp(16)
        val spacingLg = dp(24)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), statusBarInsetPx() + dp(20), dp(20), dp(20))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
        }

        val title = TextView(this).apply {
            text = "QuickList Tasker Action"
            textSize = 30f
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
        }

        val help = TextView(this).apply {
            text = "Pick a QuickList list to show as popup."
            textSize = 18f
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = spacingMd
            }
        }

        val label = TextView(this).apply {
            text = "List"
            textSize = 16f
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = spacingLg
            }
        }

        availableEntries = readAvailableLists()
        listSpinner = Spinner(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = dp(6)
            }
        }

        val names = if (availableEntries.isEmpty()) {
            listOf("No lists available - open QuickList app first")
        } else {
            availableEntries.map { it.name }
        }

        val adapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_item,
            names,
        ).apply {
            setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        }
        listSpinner.adapter = adapter
        listSpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(
                parent: AdapterView<*>?,
                view: View?,
                position: Int,
                id: Long,
            ) {
                selectedIndex = position
            }

            override fun onNothingSelected(parent: AdapterView<*>?) = Unit
        }

        val saveButton = Button(this).apply {
            text = "Save"
            layoutParams = LinearLayout.LayoutParams(
                0,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                1f,
            )
            setOnClickListener { onSavePressed() }
        }

        val cancelButton = Button(this).apply {
            text = "Cancel"
            layoutParams = LinearLayout.LayoutParams(
                0,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                1f,
            ).apply {
                marginEnd = dp(10)
            }
            setOnClickListener { finish() }
        }

        val buttonRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = spacingLg
            }
            addView(cancelButton)
            addView(saveButton)
        }

        root.addView(title)
        root.addView(help)
        root.addView(label)
        root.addView(listSpinner)
        root.addView(buttonRow)

        return ScrollView(this).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            isFillViewport = true
            addView(root)
        }
    }

    private fun prefillFromIncomingIntent(intent: Intent?) {
        val bundle = intent?.getBundleExtra(TaskerPluginConstants.EXTRA_BUNDLE)
        val existingId = bundle?.getString(MainActivity.EXTRA_LIST_ID).orEmpty()
        val existingName = bundle?.getString(MainActivity.EXTRA_LIST_NAME).orEmpty()

        if (availableEntries.isEmpty()) {
            return
        }

        val idMatch = availableEntries.indexOfFirst { it.id == existingId }
        val nameMatch = availableEntries.indexOfFirst { it.name == existingName }
        val index = when {
            idMatch >= 0 -> idMatch
            nameMatch >= 0 -> nameMatch
            else -> 0
        }
        selectedIndex = index
        listSpinner.setSelection(index)
    }

    private fun onSavePressed() {
        if (availableEntries.isEmpty()) {
            Toast.makeText(this, "Open QuickList app and create a list first", Toast.LENGTH_SHORT).show()
            return
        }

        val entry = availableEntries.getOrNull(selectedIndex)
        if (entry == null || entry.id.isBlank() || entry.name.isBlank()) {
            Toast.makeText(this, "Select a list", Toast.LENGTH_SHORT).show()
            return
        }

        val pluginBundle = Bundle().apply {
            putString(MainActivity.EXTRA_LIST_ID, entry.id)
            putString(MainActivity.EXTRA_LIST_NAME, entry.name)
        }
        val resultIntent = Intent().apply {
            putExtra(TaskerPluginConstants.EXTRA_BUNDLE, pluginBundle)
            putExtra(TaskerPluginConstants.EXTRA_STRING_BLURB, "Show list: ${entry.name}")
        }

        setResult(RESULT_OK, resultIntent)
        finish()
    }

    private fun readAvailableLists(): List<ListEntry> {
        val prefs = getSharedPreferences(TaskerPluginConstants.PREFS_NAME, MODE_PRIVATE)
        val rawJson = prefs.getString(TaskerPluginConstants.PREFS_LISTS_JSON, null).orEmpty()
        if (rawJson.isBlank()) {
            return emptyList()
        }

        return try {
            val array = JSONArray(rawJson)
            buildList {
                for (index in 0 until array.length()) {
                    val value = array.opt(index)
                    when (value) {
                        is JSONObject -> {
                            val id = value.optString("id").trim()
                            val name = value.optString("name").trim()
                            if (id.isNotBlank() && name.isNotBlank()) {
                                add(ListEntry(id = id, name = name))
                            }
                        }
                        is String -> {
                            val name = value.trim()
                            if (name.isNotBlank()) {
                                add(ListEntry(id = name.lowercase(), name = name))
                            }
                        }
                    }
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics,
        ).toInt()
    }

    private fun statusBarInsetPx(): Int {
        val id = resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (id > 0) resources.getDimensionPixelSize(id) else 0
    }
}
