/*
 * vim:ts=4:sw=4:expandtab
 */
package org.raumzeitlabor.status;

import android.app.Activity;
import android.appwidget.AppWidgetManager;
import android.content.Context;
import android.content.Intent;
import android.graphics.Rect;
import android.os.Bundle;
import android.util.Log;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public class MenuPopup extends Activity {
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

        setContentView(R.layout.quickaction);

        Rect bounds = (Rect) extras.get("bounds");
        Log.d(TAG, "start with bounds = " + bounds);

        WindowManager.LayoutParams p = (WindowManager.LayoutParams) getWindow().getAttributes();
        p.gravity = Gravity.LEFT | Gravity.TOP;
        p.x = (bounds.left + bounds.right) / 2;
        p.y = bounds.top;
        getWindow().setAttributes(p);

        findViewById(R.id.refresh).setOnClickListener(new OnClickListener() {
            public void onClick(View v) {
                Intent i = StatusProvider.intentForWidget(mAppWidgetId, ".UPDATE");
                sendBroadcast(i);
                finish();
            }
        });
        findViewById(R.id.settings).setOnClickListener(new OnClickListener() {
            public void onClick(View v) {
                Intent i = new Intent(MenuPopup.this, Configure.class);
                i.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, mAppWidgetId);
                startActivity(i);
                finish();
            }
        });
        if (getIntent().hasExtra("result")) {
            try {
                JSONObject result = new JSONObject(getIntent().getStringExtra("result"));
                StringBuilder people = new StringBuilder();
                people.append("Anwesend: ");
                JSONArray peopledetails = result.getJSONObject("details").getJSONArray("laboranten");
                for (int i = 0; i < peopledetails.length(); i++) {
                    if (i > 0)
                        people.append(", ");
                    people.append(peopledetails.get(i));
                }
                people.append("\nGeräte: ");
                people.append(result.getJSONObject("details").getInt("geraete"));
                ((TextView) findViewById(R.id.statustext)).setText(people.toString());
            } catch (JSONException e) {
                e.printStackTrace();
            }
        }
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        // If we've received a touch notification that the user has touched
        // outside the app, finish the activity.
        WindowManager.LayoutParams p = (WindowManager.LayoutParams) getWindow().getAttributes();
        if (event.getX() < p.x - 30 ||
                event.getY() < p.y - 30 ||
                event.getX() > p.x + p.width + 30 ||
                event.getY() > p.y + p.height + 30) {
            finish();
            return false;
        }

        // Delegate everything else to Activity.
        return super.onTouchEvent(event);
    }
}
