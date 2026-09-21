package com.kazu.school_planner

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService

/// ［月］ビューのマス（42個）
class TsuzuriMonthService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        TsuzuriGridFactory(applicationContext, "mon_cells")
}

/// 月ビュー・週ビューで共通のマスの作り方
internal class TsuzuriGridFactory(
    private val context: Context,
    private val key: String
) : RemoteViewsService.RemoteViewsFactory {

    private val chipIds = intArrayOf(
        R.id.cell_e1, R.id.cell_e2, R.id.cell_e3,
        R.id.cell_e4, R.id.cell_e5, R.id.cell_e6
    )

    private var cells: List<List<String>> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString(key, "") ?: ""
        cells = if (raw.isEmpty()) {
            emptyList()
        } else {
            raw.split("\n").map { it.split("\t") }.filter { it.size >= 5 }
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
        val holiday = f[3] == "1"
        val count = f[4].toIntOrNull() ?: 0

        val v = RemoteViews(context.packageName, R.layout.tsuzuri_month_cell)

        // 日にち
        v.setTextViewText(R.id.cell_day, f[0])
        val dayColor = when {
            !inMonth -> context.getColor(R.color.tsuzuri_w_sub)
            today -> Color.WHITE
            holiday -> 0xFFD32F2F.toInt()
            else -> context.getColor(R.color.tsuzuri_w_text)
        }
        v.setTextColor(R.id.cell_day, dayColor)
        v.setInt(
            R.id.cell_day,
            "setBackgroundResource",
            if (today) R.drawable.tsuzuri_widget_today else 0
        )

        // 予定の帯
        for (i in chipIds.indices) {
            val at = 5 + i * 2
            if (i >= count || at + 1 >= f.size) {
                v.setViewVisibility(chipIds[i], View.GONE)
                continue
            }
            val color = f[at].toLongOrNull()?.toInt() ?: 0
            v.setViewVisibility(chipIds[i], View.VISIBLE)
            v.setTextViewText(chipIds[i], f[at + 1])
            if (color == 0) {
                // 「他◯件」
                v.setInt(chipIds[i], "setBackgroundColor", Color.TRANSPARENT)
                v.setTextColor(chipIds[i], context.getColor(R.color.tsuzuri_w_sub))
            } else {
                v.setInt(chipIds[i], "setBackgroundColor", color)
                v.setTextColor(chipIds[i], Color.WHITE)
            }
        }

        v.setOnClickFillInIntent(R.id.cell_root, Intent())
        return v
    }
}