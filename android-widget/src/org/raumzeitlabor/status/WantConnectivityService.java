/*
 * vim:ts=4:sw=4:expandtab
 */
package org.raumzeitlabor.status;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.IBinder;
import android.os.Handler;
import android.util.Log;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.net.NetworkInfo.State;
import android.content.IntentFilter;
import android.content.BroadcastReceiver;

import java.util.ArrayList;

public class WantConnectivityService extends Service {
    private static final String TAG = "rzlstatus/WCS";
    private BroadcastReceiver mReceiver;
    private ArrayList<Integer> widgetIds = new ArrayList<Integer>();

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onCreate() {
        Log.d(TAG, "Creating WantConnectivityService");

        mReceiver = new NetworkChangeReceiver();

        IntentFilter filter = new IntentFilter();
        filter.addAction(ConnectivityManager.CONNECTIVITY_ACTION);
        registerReceiver(mReceiver, filter);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        int widgetId = intent.getIntExtra("widgetId", -1);
        if (widgetId == -1) {
            Log.e(TAG, "No widget ID passed");
            return START_STICKY;
        }
        if (!widgetIds.contains(widgetId)) {
            Log.d(TAG, "widgetId " + widgetId + " is new, adding to list");
            widgetIds.add(widgetId);
        }
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        Log.d(TAG, "Destroying WantConnectivityService");
        unregisterReceiver(mReceiver);
    }

    public class NetworkChangeReceiver extends BroadcastReceiver {
        private final Handler mHandler = new Handler();

        @Override
        public void onReceive(Context context, Intent intent) {
            Log.d(TAG, "Broadcast! action = " + intent.getAction());
            if (!intent.getAction().equals(ConnectivityManager.CONNECTIVITY_ACTION)) {
                Log.d(TAG, "Broadcast does not match CONNECTIVITY_ACTION");
                return;
            }

            Bundle extras = intent.getExtras();
            Log.d(TAG, "no connectivity = " + extras.getBoolean(ConnectivityManager.EXTRA_NO_CONNECTIVITY, false));
            Log.d(TAG, "failover = " + extras.getBoolean(ConnectivityManager.EXTRA_IS_FAILOVER, false));
            NetworkInfo info = (NetworkInfo)extras.get(ConnectivityManager.EXTRA_NETWORK_INFO);

            if (info.getState() != State.CONNECTED) {
                Log.d(TAG, "NOT connected yet, waiting...");
                return;
            }

            mHandler.postDelayed(new Runnable() {
                @Override
                public void run() {
                    for (Integer id : widgetIds) {
                        Log.d(TAG, "Should update widget with id " + id);
                        sendBroadcast(StatusProvider.intentForWidget(id, ".UPDATE"));
                    }

                    WantConnectivityService.this.stopSelf();
                }
            }, 10000);
        }
    }
}
