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
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/// スケジュールウィジェット（予定を日付順に並べる。スクロールできる）
class TsuzuriScheduleWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val today = SimpleDateFormat("M月d日(E)", Locale.JAPAN)
            .format(Calendar.getInstance().time)

        // 行をタップしたときに、つづりを開くための入れもの
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags = flags or PendingIntent.FLAG_MUTABLE
        }
        val template = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java), flags
        )

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.tsuzuri_schedule_widget)
            views.setTextViewText(R.id.schedule_title, today)

            val service = Intent(context, TsuzuriScheduleService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.schedule_list, service)
            views.setEmptyView(R.id.schedule_list, R.id.schedule_empty)

            views.setOnClickPendingIntent(
                R.id.schedule_header,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            )
            views.setPendingIntentTemplate(R.id.schedule_list, template)

            appWidgetManager.updateAppWidget(id, views)
        }
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.schedule_list)
    }
}