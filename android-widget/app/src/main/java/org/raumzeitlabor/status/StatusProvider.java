package org.raumzeitlabor.status;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.util.Log;
import android.widget.RemoteViews;

import androidx.work.Constraints;
import androidx.work.Data;
import androidx.work.ExistingPeriodicWorkPolicy;
import androidx.work.ExistingWorkPolicy;
import androidx.work.NetworkType;
import androidx.work.OneTimeWorkRequest;
import androidx.work.PeriodicWorkRequest;
import androidx.work.WorkManager;

import java.util.concurrent.TimeUnit;

public class StatusProvider extends AppWidgetProvider {
    private static final String TAG = "rzlstatus";
    private static final String URI_SCHEME = "rzlstatus";
    private static final String INTENT_PREFIX = "org.raumzeitlabor.status";

    public static Intent intentForWidget(int appWidgetId, String specificIntent) {
        Intent i = new Intent();
        i.setAction(INTENT_PREFIX + specificIntent);
        i.setData(Uri.withAppendedPath(Uri.parse(URI_SCHEME + "://widget/id/"),
                String.valueOf(appWidgetId)));
        return i;
    }

    @Override
    public void onDeleted(Context context, int[] appWidgetIds) {
        Log.d(TAG, "onDeleted");
        WorkManager workManager = WorkManager.getInstance(context);
        for (int appWidgetId : appWidgetIds) {
            workManager.cancelUniqueWork("widget_periodic_" + appWidgetId);
            SharedPreferences prefs = context.getSharedPreferences(Configure.PREF_NAME_PREFIX + appWidgetId, Context.MODE_PRIVATE);
            prefs.edit().clear().apply();
        }
    }

    @Override
    public void onUpdate(Context context, AppWidgetManager manager, int[] appWidgetIds) {
        Log.d(TAG, "onUpdate");
        for (int appWidgetId : appWidgetIds) {
            updateInitialView(context, manager, appWidgetId);
            scheduleUpdates(context, appWidgetId);
            enqueueImmediateRefresh(context, appWidgetId);
        }
    }

    private void updateInitialView(Context context, AppWidgetManager manager, int appWidgetId) {
        SharedPreferences prefs = context.getSharedPreferences(Configure.PREF_NAME_PREFIX + appWidgetId, Context.MODE_PRIVATE);
        String lastTime = prefs.getString("cached_time", "--:--");
        int drawableRes = prefs.getInt("cached_drawable", R.drawable.unklar);

        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.rzlstatus);
        views.setImageViewResource(R.id.statusimage, drawableRes);
        views.setTextViewText(R.id.lastupdate, lastTime);

        Intent menuIntent = new Intent(context, MenuPopup.class);
        menuIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId);
        PendingIntent pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                menuIntent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        views.setOnClickPendingIntent(R.id.framelayout, pendingIntent);
        views.setOnClickPendingIntent(R.id.statusimage, pendingIntent);
        views.setOnClickPendingIntent(R.id.lastupdate, pendingIntent);

        manager.updateAppWidget(appWidgetId, views);
    }

    public static void scheduleUpdates(Context context, int appWidgetId) {
        WorkManager workManager = WorkManager.getInstance(context);
        String uniqueWorkName = "widget_periodic_" + appWidgetId;

        SharedPreferences prefs = context.getSharedPreferences(Configure.PREF_NAME_PREFIX + appWidgetId, Context.MODE_PRIVATE);
        boolean autoRefresh = prefs.getBoolean("autoRefresh", true);

        if (!autoRefresh) {
            Log.d(TAG, "Auto-refresh disabled for widget " + appWidgetId);
            workManager.cancelUniqueWork(uniqueWorkName);
            return;
        }

        String intervalStr = prefs.getString("refreshInterval", "900000");
        long intervalMillis;
        try {
            intervalMillis = Long.parseLong(intervalStr);
        } catch (NumberFormatException e) {
            intervalMillis = 900000L;
        }

        if (intervalMillis < PeriodicWorkRequest.MIN_PERIODIC_INTERVAL_MILLIS) {
            intervalMillis = PeriodicWorkRequest.MIN_PERIODIC_INTERVAL_MILLIS;
        }

        Constraints constraints = new Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build();

        Data inputData = new Data.Builder()
                .putInt(StatusUpdateWorker.KEY_WIDGET_ID, appWidgetId)
                .build();

        PeriodicWorkRequest request = new PeriodicWorkRequest.Builder(
                StatusUpdateWorker.class,
                intervalMillis,
                TimeUnit.MILLISECONDS)
                .setConstraints(constraints)
                .setInputData(inputData)
                .build();

        workManager.enqueueUniquePeriodicWork(
                uniqueWorkName,
                ExistingPeriodicWorkPolicy.UPDATE,
                request
        );
        Log.d(TAG, "Scheduled periodic work for widget " + appWidgetId + " at interval " + intervalMillis + "ms");
    }

    public static void enqueueImmediateRefresh(Context context, int appWidgetId) {
        WorkManager workManager = WorkManager.getInstance(context);
        Constraints constraints = new Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build();

        Data inputData = new Data.Builder()
                .putInt(StatusUpdateWorker.KEY_WIDGET_ID, appWidgetId)
                .build();

        OneTimeWorkRequest request = new OneTimeWorkRequest.Builder(StatusUpdateWorker.class)
                .setConstraints(constraints)
                .setInputData(inputData)
                .build();

        String uniqueWorkName = "widget_refresh_" + appWidgetId;
        workManager.enqueueUniqueWork(uniqueWorkName, ExistingWorkPolicy.REPLACE, request);
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        final String action = intent.getAction();
        if (action != null && action.startsWith(INTENT_PREFIX)) {
            Uri uri = intent.getData();
            int widgetId = AppWidgetManager.INVALID_APPWIDGET_ID;
            if (uri != null) {
                String lastSegment = uri.getLastPathSegment();
                if (lastSegment != null) {
                    try {
                        widgetId = Integer.parseInt(lastSegment);
                    } catch (NumberFormatException ignored) {}
                }
            }

            if (action.equals(INTENT_PREFIX + ".UPDATE")) {
                if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    enqueueImmediateRefresh(context, widgetId);
                } else {
                    AppWidgetManager manager = AppWidgetManager.getInstance(context);
                    int[] ids = manager.getAppWidgetIds(new ComponentName(context, StatusProvider.class));
                    for (int id : ids) {
                        enqueueImmediateRefresh(context, id);
                    }
                }
                return;
            }

            if (action.equals(INTENT_PREFIX + ".RELOAD")) {
                if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    scheduleUpdates(context, widgetId);
                }
                return;
            }
        }

        super.onReceive(context, intent);
    }
}
