package org.raumzeitlabor.status;

import android.appwidget.AppWidgetManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import org.json.JSONArray;
import org.json.JSONObject;

public class MenuPopup extends AppCompatActivity {
    private static final String TAG = "rzlstatus";
    private int mAppWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        Bundle extras = getIntent().getExtras();
        if (extras != null) {
            mAppWidgetId = extras.getInt(
                    AppWidgetManager.EXTRA_APPWIDGET_ID,
                    AppWidgetManager.INVALID_APPWIDGET_ID);
        }

        if (mAppWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish();
            return;
        }

        setContentView(R.layout.quickaction);

        findViewById(R.id.refresh).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                StatusProvider.enqueueImmediateRefresh(MenuPopup.this, mAppWidgetId);
                Toast.makeText(MenuPopup.this, "Status wird aktualisiert...", Toast.LENGTH_SHORT).show();
                finish();
            }
        });

        findViewById(R.id.settings).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent i = new Intent(MenuPopup.this, Configure.class);
                i.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, mAppWidgetId);
                startActivity(i);
                finish();
            }
        });

        updateStatusText();
    }

    private void updateStatusText() {
        TextView textView = findViewById(R.id.statustext);
        SharedPreferences prefs = getSharedPreferences(Configure.PREF_NAME_PREFIX + mAppWidgetId, Context.MODE_PRIVATE);
        String cachedJson = prefs.getString("cached_result", null);
        String cachedTime = prefs.getString("cached_time", "--:--");

        StringBuilder text = new StringBuilder();

        if (cachedJson != null) {
            try {
                JSONObject json = new JSONObject(cachedJson);
                String status = json.optString("status", "?");
                if ("1".equals(status)) {
                    text.append("Status: Offen\n");
                } else if ("0".equals(status)) {
                    text.append("Status: Zu\n");
                } else {
                    text.append("Status: Unbekannt\n");
                }

                JSONObject details = json.optJSONObject("details");
                if (details != null) {
                    JSONArray laboranten = details.optJSONArray("laboranten");
                    if (laboranten != null && laboranten.length() > 0) {
                        text.append("Anwesend: ");
                        for (int i = 0; i < laboranten.length(); i++) {
                            if (i > 0) text.append(", ");
                            text.append(laboranten.getString(i));
                        }
                        text.append("\n");
                    }
                    if (details.has("geraete")) {
                        text.append("Geräte: ").append(details.optInt("geraete", 0)).append("\n");
                    }
                }
            } catch (Exception e) {
                Log.e(TAG, "Error parsing cached status JSON", e);
            }
        }

        text.append("Letztes Update: ").append(cachedTime);
        textView.setText(text.toString());
    }
}
