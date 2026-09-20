package com.kazu.school_planner

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/// ホーム画面ウィジェット（つづりが作った内容を表示するだけ）
class TsuzuriWidgetProvider : HomeWidgetProvider() {

    // 時間割の行（最大6時限）
    private val rowIds = intArrayOf(R.id.row1, R.id.row2, R.id.row3, R.id.row4, R.id.row5, R.id.row6)
    private val periodIds = intArrayOf(R.id.period1, R.id.period2, R.id.period3, R.id.period4, R.id.period5, R.id.period6)
    private val dotIds = intArrayOf(R.id.dot1, R.id.dot2, R.id.dot3, R.id.dot4, R.id.dot5, R.id.dot6)
    private val subjectIds = intArrayOf(R.id.subject1, R.id.subject2, R.id.subject3, R.id.subject4, R.id.subject5, R.id.subject6)
    private val testIds = intArrayOf(R.id.test1, R.id.test2, R.id.test3, R.id.test4, R.id.test5, R.id.test6)

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

        // その日のデータを探す
        var found = -1
        for (i in 0 until 7) {
            if (widgetData.getString("day${i}_date", null) == target) {
                found = i
                break
            }
        }

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.tsuzuri_widget)
            views.setTextViewText(R.id.widget_badge, if (showTomorrow) "明日" else "今日")

            if (found < 0) {
                views.setTextViewText(R.id.widget_title, "")
                showMessage(views, "つづりを開くと、ここに時間割が出ます")
                hideRows(views, 0)
                views.setViewVisibility(R.id.widget_extra, View.GONE)
            } else {
                val title = widgetData.getString("day${found}_title", "") ?: ""
                val message = widgetData.getString("day${found}_message", "") ?: ""
                val lessons = widgetData.getString("day${found}_lessons", "") ?: ""
                val extra = widgetData.getString("day${found}_extra", "") ?: ""
                views.setTextViewText(R.id.widget_title, title)

                if (message.isNotEmpty()) {
                    showMessage(views, message)
                } else {
                    views.setViewVisibility(R.id.widget_message, View.GONE)
                }

                // 時間割
                val lines = if (lessons.isEmpty()) emptyList() else lessons.split("\n")
                var n = 0
                for (line in lines) {
                    if (n >= rowIds.size) break
                    val f = line.split("\t")
                    if (f.size < 5) continue
                    val cancelled = f[4] == "1"
                    views.setViewVisibility(rowIds[n], View.VISIBLE)
                    views.setTextViewText(periodIds[n], f[0])
                    views.setTextColor(dotIds[n], f[3].toLong().toInt())
                    views.setTextViewText(subjectIds[n], f[1])
                    views.setTextColor(
                        subjectIds[n],
                        context.getColor(if (cancelled) R.color.tsuzuri_w_sub else R.color.tsuzuri_w_text)
                    )
                    if (f[2].isEmpty()) {
                        views.setViewVisibility(testIds[n], View.GONE)
                    } else {
                        views.setViewVisibility(testIds[n], View.VISIBLE)
                        views.setTextViewText(testIds[n], "📝 " + f[2])
                    }
                    n++
                }
                hideRows(views, n)

                // 模試・予定
                if (extra.isEmpty()) {
                    views.setViewVisibility(R.id.widget_extra, View.GONE)
                    views.setViewVisibility(R.id.widget_divider, View.GONE)
                } else {
                    views.setViewVisibility(R.id.widget_extra, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_divider, if (n > 0) View.VISIBLE else View.GONE)
                    views.setTextViewText(R.id.widget_extra, extra)
                }
            }

            // タップでつづりを開く
            val open = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.widget_root, open)
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun showMessage(views: RemoteViews, text: String) {
        views.setViewVisibility(R.id.widget_message, View.VISIBLE)
        views.setTextViewText(R.id.widget_message, text)
    }

    /// from 行目から後ろの行を隠す
    private fun hideRows(views: RemoteViews, from: Int) {
        for (k in from until rowIds.size) views.setViewVisibility(rowIds[k], View.GONE)
        if (from == 0) views.setViewVisibility(R.id.widget_divider, View.GONE)
    }
}