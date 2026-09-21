package com.kazu.school_planner

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService

/// 月ビューウィジェットのマス（42個）
class TsuzuriMonthService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        TsuzuriMonthFactory(applicationContext)
}

private class TsuzuriMonthFactory(private val context: Context) :
    RemoteViewsService.RemoteViewsFactory {

    private var cells: List<List<String>> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("mon_cells", "") ?: ""
        cells = if (raw.isEmpty()) {
            emptyList()
        } else {
            raw.split("\n").map { it.split("\t") }.filter { it.size >= 6 }
        }
    }

    override fun onDestroy() {}

    override fun getCount(): Int = cells.size

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewAt(position: Int): RemoteViews {
        val f = cells[position]
        val inMonth = f[1] == "1"
        val today = f[2] == "1"
        val marks = f[3].toIntOrNull() ?: 0
        val holiday = f[5] == "1"

        val v = RemoteViews(context.packageName, R.layout.tsuzuri_month_cell)
        v.setTextViewText(R.id.cell_day, f[0])

        val textColor = when {
            !inMonth -> context.getColor(R.color.tsuzuri_w_sub)
            today -> Color.WHITE
            holiday -> 0xFFD32F2F.toInt()
            else -> context.getColor(R.color.tsuzuri_w_text)
        }
        v.setTextColor(R.id.cell_day, textColor)
        v.setInt(
            R.id.cell_day,
            "setBackgroundResource",
            if (today) R.drawable.tsuzuri_widget_today else 0
        )

        if (inMonth && marks > 0) {
            v.setViewVisibility(R.id.cell_dots, View.VISIBLE)
            v.setTextViewText(R.id.cell_dots, "●".repeat(marks))
            v.setTextColor(R.id.cell_dots, f[4].toLongOrNull()?.toInt() ?: Color.GRAY)
        } else {
            v.setViewVisibility(R.id.cell_dots, View.INVISIBLE)
        }

        v.setOnClickFillInIntent(R.id.cell_root, Intent())
        return v
    }
}