package com.ramjankhan.greenifyx

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Home-screen widget: streak, spendable Eco Points and habit streak. Tapping it opens the app. */
class GreenifyWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.greenify_widget).apply {
                setTextViewText(R.id.gx_streak, "🔥 ${widgetData.getInt("gx_streak", 0)}")
                setTextViewText(R.id.gx_streak_label, widgetData.getString("gx_label_streak", "day streak"))
                setTextViewText(R.id.gx_points, "${widgetData.getInt("gx_points", 0)}")
                setTextViewText(R.id.gx_points_label, widgetData.getString("gx_label_points", "Eco Points"))
                setTextViewText(R.id.gx_habit, "✅ ${widgetData.getInt("gx_habit", 0)}")
                setOnClickPendingIntent(R.id.gx_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
