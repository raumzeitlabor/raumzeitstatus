/*
 * vim:ts=4:sw=4:expandtab
 */
package org.raumzeitlabor.status;

import java.io.InputStream;
import java.text.SimpleDateFormat;
import java.util.Date;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.app.Service;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.res.Resources;
import android.os.Bundle;
import android.os.IBinder;
import android.os.AsyncTask;
import android.os.SystemClock;
import android.text.format.Time;
import android.util.Log;
import android.widget.RemoteViews;
import android.widget.Toast;
import android.net.Uri;
import android.content.SharedPreferences;

import org.apache.http.HttpResponse;
import org.apache.http.StatusLine;
import org.apache.http.client.methods.HttpGet;

import org.raumzeitlabor.status.AndroidHttpClient;

public class StatusProvider extends AppWidgetProvider {
    private static final String TAG = "rzlstatus";
    private static final String URI_SCHEME = "rzlstatus";
    private static final String INTENT_PREFIX = "org.raumzeitlabor.status";
    private boolean firstUpdate = true;

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
        AlarmManager amgr = (AlarmManager)context.getSystemService(Context.ALARM_SERVICE);
        for (int appWidgetId : appWidgetIds) {
            Log.d(TAG, "Cancelling alarm for widget id " + appWidgetId);
            Intent i = intentForWidget(appWidgetId, ".UPDATE");
            PendingIntent pi = PendingIntent.getBroadcast(context, 0, i, 0);
            amgr.cancel(pi);
            Log.d(TAG, "Deleting SharedPreferences for widget id " + appWidgetId);
            SharedPreferences prefs = context.getSharedPreferences("widget_" + appWidgetId, Context.MODE_PRIVATE);
            SharedPreferences.Editor editor = prefs.edit();
            editor.clear();
            editor.commit();
        }
    }

    @Override
    public void onUpdate(Context context, AppWidgetManager manager, int[] appWidgetIds) {
        Log.d(TAG, "onUpdate");

        AlarmManager amgr = (AlarmManager)context.getSystemService(Context.ALARM_SERVICE);
        for (int appWidgetId : appWidgetIds) {
            /* To make clicking work before the first answer from server, we
             * perform an update of the RemoteView on the first call of onUpdate() */
            if (firstUpdate) {
                Intent i = intentForWidget(appWidgetId, ".CLICK");
                PendingIntent pendingIntent = PendingIntent.getBroadcast(context, 0, i, 0);
                RemoteViews update = new RemoteViews(context.getPackageName(), R.layout.rzlstatus);
                update.setTextViewText(R.id.lastupdate, "--:--");
                update.setOnClickPendingIntent(R.id.framelayout, pendingIntent);
                update.setOnClickPendingIntent(R.id.statusimage, pendingIntent);
                update.setOnClickPendingIntent(R.id.lastupdate, pendingIntent);
                manager.updateAppWidget(appWidgetId, update);
            }
            initTimer(context, appWidgetId, amgr);
        }

        if (firstUpdate)
            firstUpdate = false;
    }

    private void initTimer(Context context, int appWidgetId, AlarmManager amgr) {
        if (amgr == null) {
            amgr = (AlarmManager)context.getSystemService(Context.ALARM_SERVICE);
        }
        SharedPreferences prefs = context.getSharedPreferences("widget_" + appWidgetId, Context.MODE_PRIVATE);
        Log.d(TAG, "Setting up alarm for widget id " + appWidgetId);

        Intent i = intentForWidget(appWidgetId, ".UPDATE");
        PendingIntent pi = PendingIntent.getBroadcast(context, 0, i, 0);
        amgr.cancel(pi);
        if (prefs.getBoolean("autoRefresh", true)) {
            String intervalStr = prefs.getString("refreshInterval", "900000");
            int interval = Integer.valueOf(intervalStr);
            Log.d(TAG, "interval = " + interval);
            amgr.setInexactRepeating(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                SystemClock.elapsedRealtime() + interval,
                interval,
                pi);
            context.sendBroadcast(i);
        } else {
            Log.d(TAG, "autoRefresh disabled");
        }
    }

    @Override
    /** We override onReceive to work around a bug in the AppWidget API:
    onDelete is never called.
    See http://groups.google.com/group/android-developers/browse_thread/thread/365d1ed3aac30916/e405ca19df2170e2?pli=1 */
    public void onReceive(Context context, Intent intent) {
        final String action = intent.getAction();
        Bundle extras = intent.getExtras();
        if (AppWidgetManager.ACTION_APPWIDGET_DELETED.equals(action)) {
            final int appWidgetId = extras.getInt(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID);
            if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                this.onDeleted(context, new int[] { appWidgetId });
            }
        } else if (action.startsWith(INTENT_PREFIX)) {
            /* Extract the widgetId, which is the last part of the URI */
            Uri uri = intent.getData();
            String lastSegment = uri.getLastPathSegment();
            int widgetId = Integer.valueOf(lastSegment);
            Log.d(TAG, "id = " + widgetId);

            if (action.equals(INTENT_PREFIX + ".RELOAD")) {
                initTimer(context, widgetId, null);
                return;
            }

            if (action.equals(INTENT_PREFIX + ".UPDATE")) {
                UpdateWidgetTask task = new UpdateWidgetTask();
                task.setContext(context);
                task.setWidgetId(widgetId);
                task.execute((Void)null);
                return;
            }

            if (action.equals(INTENT_PREFIX + ".CLICK")) {
                Log.d(TAG, "bounds = " + intent.getSourceBounds());
                Intent i = new Intent(context, MenuPopup.class);
                i.putExtra("bounds", intent.getSourceBounds());
                i.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId);
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(i);
                return;
            }
        } else {
            super.onReceive(context, intent);
        }
    }

    class UpdateWidgetTask extends AsyncTask<Void, Void, Character> {
        private Context context = null;
        private Integer widgetId = null;

        public void setContext(Context context) {
            this.context = context;
        }

        public void setWidgetId(int widgetId) {
            this.widgetId = widgetId;
        }

        @Override
        protected Character doInBackground(Void... param) {
            Log.d(TAG, "Getting update from status.raumzeitlabor.de");

            HttpGet request = new HttpGet("http://s.rzl.so/api/simple");
            request.addHeader("Pragma", "no-cache");
            request.addHeader("Cache-Control", "no-cache");
            AndroidHttpClient client = AndroidHttpClient.newInstance("");
            try {
                HttpResponse response = client.execute(request);
                StatusLine statusLine = response.getStatusLine();
                if (statusLine.getStatusCode() != 200) {
                    Log.e(TAG, "HTTP Error: " + statusLine);
                    throw new Exception("HTTP Error");
                }
                InputStream stream = response.getEntity().getContent();
                int firstByte = stream.read();
                if (firstByte == -1)
                    throw new Exception("Cannot read reply");
                return (char)firstByte;
            } catch (Exception e) {
                e.printStackTrace();
                return '?';
            } finally {
                client.close();
            }
        }

        @Override
        protected void onPostExecute(Character result) {
            Log.d(TAG, "result: " + result);

            int resource;
            switch (result) {
                case '1': resource = R.drawable.auf; break;
                case '0': resource = R.drawable.zu; break;
                default:  resource = R.drawable.unklar;
            }

            String time = new SimpleDateFormat("HH:mm").format(new Date());
            Intent i = intentForWidget(widgetId, ".CLICK");
            PendingIntent pendingIntent = PendingIntent.getBroadcast(context, 0, i, 0);

            Log.d(TAG, "Pushing update");
            RemoteViews update = new RemoteViews(context.getPackageName(), R.layout.rzlstatus);
            update.setImageViewResource(R.id.statusimage, resource);
            update.setTextViewText(R.id.lastupdate, time);
            update.setOnClickPendingIntent(R.id.framelayout, pendingIntent);
            update.setOnClickPendingIntent(R.id.statusimage, pendingIntent);
            update.setOnClickPendingIntent(R.id.lastupdate, pendingIntent);
            AppWidgetManager manager = AppWidgetManager.getInstance(context);
            manager.updateAppWidget(widgetId, update);
        }
    }

}
