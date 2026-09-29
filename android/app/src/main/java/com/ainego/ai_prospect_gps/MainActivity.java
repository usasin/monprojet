package com.ainego.ai_prospect_gps;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.os.Build;
import android.os.Bundle;

import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
    private static final String REMINDER_CHANNEL_ID = "prospecto_reminders";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                REMINDER_CHANNEL_ID,
                "Relances Prospecto",
                NotificationManager.IMPORTANCE_HIGH
            );
            channel.setDescription("Rappels de visites et de relances commerciales");
            channel.enableVibration(true);
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) manager.createNotificationChannel(channel);
        }
    }
}
