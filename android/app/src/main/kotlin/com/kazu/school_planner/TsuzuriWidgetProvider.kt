package com.kazu.school_planner

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/// ホーム画面ウィジェット（つづりが作った文字を表示するだけ）
class TsuzuriWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        // 17時以降は明日を出す
        val cal = Calendar.getInstance()
        val showTomorrow = cal.get(Calendar.HOUR_OF_DAY) >= 17
        if (showTomorrow) cal.add(Calendar.DAY_OF_MONTH, 1)
        val target = SimpleDateFormat("yyyy-MM-dd", Locale.JAPAN).format(cal.time)

        var title = "つづり"
        var body = "アプリを開くと、ここに時間割が出ます"
        for (i in 0 until 7) {
            if (widgetData.getString("day${i}_date", null) == target) {
                val head = if (showTomorrow) "明日 " else "今日 "
                title = head + (widgetData.getString("day${i}_title", "") ?: "")
                body = widgetData.getString("day${i}_body", "") ?: ""
                break
            }
        }

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.tsuzuri_widget)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_body, body)
            val open = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.widget_root, open)
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}