package org.raumzeitlabor.status;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.util.Log;
import android.widget.RemoteViews;

import androidx.annotation.NonNull;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

public class StatusUpdateWorker extends Worker {
    private static final String TAG = "rzlstatus/Worker";
    public static final String KEY_WIDGET_ID = "widget_id";
    public static final String API_URL = "https://s.rzl.so/api/full.json";

    public StatusUpdateWorker(@NonNull Context context, @NonNull WorkerParameters workerParams) {
        super(context, workerParams);
    }

    @NonNull
    @Override
    public Result doWork() {
        Context context = getApplicationContext();
        int targetWidgetId = getInputData().getInt(KEY_WIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID);

        AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
        int[] widgetIds;
        if (targetWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
            widgetIds = new int[]{targetWidgetId};
        } else {
            ComponentName thisWidget = new ComponentName(context, StatusProvider.class);
            widgetIds = appWidgetManager.getAppWidgetIds(thisWidget);
        }

        if (widgetIds == null || widgetIds.length == 0) {
            return Result.success();
        }

        JSONObject result = fetchStatus();
        char statusCode = '!';
        if (result != null) {
            String statusStr = result.optString("status", "!");
            if (!statusStr.isEmpty()) {
                statusCode = statusStr.charAt(0);
            }
        }

        int drawableRes;
        switch (statusCode) {
            case '1':
                drawableRes = R.drawable.auf;
                break;
            case '0':
                drawableRes = R.drawable.zu;
                break;
            default:
                drawableRes = R.drawable.unklar;
                break;
        }

        String time = new SimpleDateFormat("HH:mm", Locale.getDefault()).format(new Date());

        for (int widgetId : widgetIds) {
            SharedPreferences prefs = context.getSharedPreferences(Configure.PREF_NAME_PREFIX + widgetId, Context.MODE_PRIVATE);
            if (result != null) {
                prefs.edit()
                        .putString("cached_result", result.toString())
                        .putString("cached_time", time)
                        .putInt("cached_drawable", drawableRes)
                        .apply();
            }

            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.rzlstatus);
            views.setImageViewResource(R.id.statusimage, drawableRes);
            views.setTextViewText(R.id.lastupdate, time);

            Intent menuIntent = new Intent(context, MenuPopup.class);
            menuIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId);
            PendingIntent pendingIntent = PendingIntent.getActivity(
                    context,
                    widgetId,
                    menuIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );

            views.setOnClickPendingIntent(R.id.framelayout, pendingIntent);
            views.setOnClickPendingIntent(R.id.statusimage, pendingIntent);
            views.setOnClickPendingIntent(R.id.lastupdate, pendingIntent);

            appWidgetManager.updateAppWidget(widgetId, views);
        }

        return result != null ? Result.success() : Result.retry();
    }

    private JSONObject fetchStatus() {
        HttpURLConnection conn = null;
        try {
            URL url = new URL(API_URL);
            conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            conn.setConnectTimeout(10000);
            conn.setReadTimeout(10000);
            conn.setRequestProperty("User-Agent", "RaumZeitStatus-Android");
            conn.setRequestProperty("Cache-Control", "no-cache");
            conn.setRequestProperty("Pragma", "no-cache");

            int responseCode = conn.getResponseCode();
            if (responseCode != HttpURLConnection.HTTP_OK) {
                Log.e(TAG, "HTTP error: " + responseCode);
                return null;
            }

            try (InputStream in = conn.getInputStream();
                 BufferedReader reader = new BufferedReader(new InputStreamReader(in, StandardCharsets.UTF_8))) {
                StringBuilder sb = new StringBuilder();
                String line;
                while ((line = reader.readLine()) != null) {
                    sb.append(line);
                }
                return new JSONObject(sb.toString());
            }
        } catch (Exception e) {
            Log.e(TAG, "Failed to fetch status: " + e.getMessage(), e);
            return null;
        } finally {
            if (conn != null) {
                conn.disconnect();
            }
        }
    }
}
