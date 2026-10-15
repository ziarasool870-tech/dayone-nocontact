package com.dayone.nocontact

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.concurrent.TimeUnit

/**
 * Day One home-screen widget: live no-contact streak counter.
 *
 * Reads `streak_start_ms` (written by Flutter via HomeWidget.saveWidgetData)
 * and renders the day count. The theme key `widget_theme` ("cream" or
 * "midnight") picks the layout; "midnight" is a Pro-only choice made in the
 * app's settings, so free users always see the cream theme.
 */
class DayOneWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val startMs: Long = try {
            widgetData.getLong("streak_start_ms", 0L)
        } catch (_: ClassCastException) {
            widgetData.getInt("streak_start_ms", 0).toLong()
        }
        // Display-day: the start day itself counts as Day 1, matching the app.
        val days = if (startMs > 0L) {
            TimeUnit.MILLISECONDS.toDays(
                System.currentTimeMillis() - startMs.coerceAtMost(System.currentTimeMillis())
            ).toInt().coerceAtLeast(0) + 1
        } else {
            0
        }
        val theme = widgetData.getString("widget_theme", "cream") ?: "cream"
        val layoutRes = if (theme == "midnight") {
            R.layout.dayone_widget_midnight
        } else {
            R.layout.dayone_widget
        }

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, layoutRes).apply {
                setTextViewText(R.id.widget_days, days.toString())
                // Tap the widget to open the app.
                val launch = Intent(context, MainActivity::class.java)
                val pending = PendingIntent.getActivity(
                    context,
                    0,
                    launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                setOnClickPendingIntent(R.id.widget_root, pending)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
