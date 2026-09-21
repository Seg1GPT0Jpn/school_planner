package com.kazu.school_planner

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService

/// スケジュールウィジェットの中身（1行ずつ作る）
class TsuzuriScheduleService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        TsuzuriScheduleFactory(applicationContext)
}

private class TsuzuriScheduleFactory(private val context: Context) :
    RemoteViewsService.RemoteViewsFactory {

    private var lines: List<List<String>> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("sch_lines", "") ?: ""
        lines = if (raw.isEmpty()) {
            emptyList()
        } else {
            raw.split("\n").map { it.split("\t") }.filter { it.size >= 5 }
        }
    }

    override fun onDestroy() {}

    override fun getCount(): Int = lines.size

    // 日付の見出しと、予定の行の2種類
    override fun getViewTypeCount(): Int = 2

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewAt(position: Int): RemoteViews {
        val f = lines[position]
        if (f[0] == "h") {
            val v = RemoteViews(context.packageName, R.layout.tsuzuri_schedule_header)
            v.setTextViewText(R.id.sh_date, f[1])
            v.setTextColor(
                R.id.sh_date,
                context.getColor(
                    if (f[4] == "1") R.color.tsuzuri_w_accent else R.color.tsuzuri_w_header
                )
            )
            v.setOnClickFillInIntent(R.id.sh_root, Intent())
            return v
        }
        val v = RemoteViews(context.packageName, R.layout.tsuzuri_schedule_item)
        v.setTextViewText(R.id.si_title, f[2])
        v.setTextViewText(R.id.si_time, f[1])
        v.setTextColor(R.id.si_dot, f[3].toLongOrNull()?.toInt() ?: Color.GRAY)
        v.setOnClickFillInIntent(R.id.si_root, Intent())
        return v
    }
}