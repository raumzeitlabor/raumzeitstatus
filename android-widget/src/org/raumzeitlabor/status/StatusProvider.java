/*
 * vim:ts=4:sw=4:expandtab
 */
package org.raumzeitlabor.status;

import java.io.InputStream;
import java.text.SimpleDateFormat;
import java.util.Date;

import android.app.PendingIntent;
import android.app.Service;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.res.Resources;
import android.os.IBinder;
import android.os.AsyncTask;
import android.text.format.Time;
import android.util.Log;
import android.widget.RemoteViews;
import android.widget.Toast;

import org.apache.http.HttpResponse;
import org.apache.http.StatusLine;
import org.apache.http.client.methods.HttpGet;

import org.raumzeitlabor.status.AndroidHttpClient;

public class StatusProvider extends AppWidgetProvider {
    private static final String TAG = "rzlstatus";

    @Override
    public void onUpdate(Context context, AppWidgetManager manager, int[] ids) {
        Log.d(TAG, "onUpdate");

        context.startService(new Intent(context, UpdateService.class));
    }

    public static class UpdateService extends Service {
        private AndroidHttpClient client = AndroidHttpClient.newInstance("");
        private RemoteViews update;
        private ComponentName thisWidget;

        public void onStart(Intent intent, int startId) {
            Log.d(TAG, "Service start");
            update = new RemoteViews(getPackageName(), R.layout.rzlstatus);
            thisWidget = new ComponentName(UpdateService.this, StatusProvider.class);
            new UpdateWidgetTask().execute((Void)null);
        }

        class UpdateWidgetTask extends AsyncTask<Void, Void, Character> {
            @Override
            protected Character doInBackground(Void... param) {
                Log.d(TAG, "Getting update from status.raumzeitlabor.de");

                HttpGet request = new HttpGet("http://status.raumzeitlabor.de/api/simple");
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
                }
            }

            @Override
            protected void onPostExecute(Character result) {
                Log.d(TAG, "result: " + result);
                /* TODO: check if the status changed at all */

                int resource;
                switch (result) {
                    case '1': resource = R.drawable.auf; break;
                    case '0': resource = R.drawable.zu; break;
                    default:  resource = R.drawable.unklar;
                }

                Log.d(TAG, "Pushing update");
                update.setImageViewResource(R.id.statusimage, resource);
                String time = new SimpleDateFormat("HH:mm").format(new Date());
                update.setTextViewText(R.id.lastupdate, time);
                AppWidgetManager manager = AppWidgetManager.getInstance(UpdateService.this);
                manager.updateAppWidget(thisWidget, update);
            }
        }

        public IBinder onBind(Intent intent) {
            // We don't need to bind to this service
            return null;
        }
    }
}
