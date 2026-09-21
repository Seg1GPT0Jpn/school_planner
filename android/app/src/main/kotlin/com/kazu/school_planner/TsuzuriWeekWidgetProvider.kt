package com.kazu.school_planner

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/// カレンダーの［週］ビューウィジェット
class TsuzuriWeekWidgetProvider : HomeWidgetProvider() {

    private val weekdayIds =
        intArrayOf(R.id.wd0, R.id.wd1, R.id.wd2, R.id.wd3, R.id.wd4, R.id.wd5, R.id.wd6)

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val title = widgetData.getString("wk_title", "") ?: ""
        val weekdays = (widgetData.getString("wk_weekdays", "") ?: "").split("\t")

        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags = flags or PendingIntent.FLAG_MUTABLE
        }
        val template = PendingIntent.getActivity(
            context, 2, Intent(context, MainActivity::class.java), flags
        )

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.tsuzuri_week_widget)
            views.setTextViewText(R.id.week_title, title)

            for (i in weekdayIds.indices) {
                val name = weekdays.getOrNull(i) ?: ""
                views.setTextViewText(weekdayIds[i], name)
                val color = when (name) {
                    "日" -> 0xFFD32F2F.toInt()
                    "土" -> 0xFF1976D2.toInt()
                    else -> context.getColor(R.color.tsuzuri_w_sub)
                }
                views.setTextColor(weekdayIds[i], color)
            }

            val service = Intent(context, TsuzuriWeekService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.week_grid, service)

            views.setOnClickPendingIntent(
                R.id.week_header,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            )
            views.setPendingIntentTemplate(R.id.week_grid, template)

            appWidgetManager.updateAppWidget(id, views)
        }
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.week_grid)
    }
}