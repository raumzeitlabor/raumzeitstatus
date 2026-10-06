package org.raumzeitlabor.status;

import android.appwidget.AppWidgetManager;
import android.content.ComponentName;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.MenuItem;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.Toolbar;
import androidx.preference.ListPreference;
import androidx.preference.PreferenceFragmentCompat;

public class Configure extends AppCompatActivity {
    private static final String TAG = "rzlstatus";
    public static final String PREF_NAME_PREFIX = "widget_";

    private int mAppWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        Bundle extras = getIntent().getExtras();
        if (extras != null) {
            mAppWidgetId = extras.getInt(
                    AppWidgetManager.EXTRA_APPWIDGET_ID,
                    AppWidgetManager.INVALID_APPWIDGET_ID);

            if (extras.getBoolean("action_pin", false)) {
                AppWidgetManager manager = AppWidgetManager.getInstance(this);
                if (manager.isRequestPinAppWidgetSupported()) {
                    manager.requestPinAppWidget(
                            new ComponentName(this, StatusProvider.class),
                            null,
                            null
                    );
                    finish();
                    return;
                }
            }
        }

        // CRITICAL FOR WIDGETS:
        // Always set RESULT_OK with EXTRA_APPWIDGET_ID so the launcher host
        // never deletes or unpins the widget when exiting settings!
        Intent resultValue = new Intent();
        resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, mAppWidgetId);
        setResult(RESULT_OK, resultValue);

        setContentView(R.layout.activity_configure);

        Toolbar toolbar = findViewById(R.id.toolbar);
        setSupportActionBar(toolbar);
        if (getSupportActionBar() != null) {
            getSupportActionBar().setDisplayHomeAsUpEnabled(true);
            getSupportActionBar().setTitle(R.string.configuration_title);
        }

        if (savedInstanceState == null) {
            getSupportFragmentManager()
                    .beginTransaction()
                    .replace(R.id.settings_container, PrefsFragment.newInstance(mAppWidgetId))
                    .commit();
        }
    }

    @Override
    public boolean onOptionsItemSelected(@NonNull MenuItem item) {
        if (item.getItemId() == android.R.id.home) {
            getOnBackPressedDispatcher().onBackPressed();
            return true;
        }
        return super.onOptionsItemSelected(item);
    }

    @Override
    protected void onPause() {
        super.onPause();
        Log.d(TAG, "Configure onPause, reloading schedule for widget " + mAppWidgetId);
        if (mAppWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
            StatusProvider.scheduleUpdates(this, mAppWidgetId);
        } else {
            AppWidgetManager manager = AppWidgetManager.getInstance(this);
            int[] ids = manager.getAppWidgetIds(new ComponentName(this, StatusProvider.class));
            for (int id : ids) {
                StatusProvider.scheduleUpdates(this, id);
            }
        }
    }

    public static class PrefsFragment extends PreferenceFragmentCompat {
        private static final String ARG_WIDGET_ID = "arg_widget_id";

        public static PrefsFragment newInstance(int widgetId) {
            PrefsFragment fragment = new PrefsFragment();
            Bundle args = new Bundle();
            args.putInt(ARG_WIDGET_ID, widgetId);
            fragment.setArguments(args);
            return fragment;
        }

        @Override
        public void onCreatePreferences(Bundle savedInstanceState, String rootKey) {
            int widgetId = getArguments() != null
                    ? getArguments().getInt(ARG_WIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
                    : AppWidgetManager.INVALID_APPWIDGET_ID;

            if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                getPreferenceManager().setSharedPreferencesName(PREF_NAME_PREFIX + widgetId);
            }
            setPreferencesFromResource(R.xml.preferences, rootKey);

            ListPreference intervalPref = findPreference("refreshInterval");
            if (intervalPref != null) {
                intervalPref.setSummaryProvider(ListPreference.SimpleSummaryProvider.getInstance());
            }
        }
    }
}
