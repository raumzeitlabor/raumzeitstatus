/*
 * vim:ts=4:sw=4:expandtab
 */
package org.raumzeitlabor.status;

import android.os.Bundle;
import android.app.Activity;
import android.appwidget.AppWidgetManager;
import android.preference.Preference;
import android.preference.PreferenceActivity;
import android.preference.Preference.OnPreferenceClickListener;
import android.content.Intent;
import android.util.Log;

public class Configure extends PreferenceActivity {
    private static final String TAG = "rzlstatus";
    int mAppWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID;

    @Override
    public void onCreate(Bundle icicle) {
        super.onCreate(icicle);

        /* Find the widget id from the intent. */
        Bundle extras = getIntent().getExtras();
        if (extras != null) {
            mAppWidgetId = extras.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID,
                    AppWidgetManager.INVALID_APPWIDGET_ID);
        }

        /* If they gave us an intent without the widget id, just bail. */
        if (mAppWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish();
            return;
        }

        /* Set up the PreferenceActivity for the specific widget */
        getPreferenceManager().setSharedPreferencesName("widget_" + mAppWidgetId);

        addPreferencesFromResource(R.xml.preferences);
    }

    @Override
    protected void onPause() {
        super.onPause();

        Log.d(TAG, "onPause, updating widget");

        Intent i = StatusProvider.intentForWidget(mAppWidgetId, ".RELOAD");
        sendBroadcast(i);
    }
}
