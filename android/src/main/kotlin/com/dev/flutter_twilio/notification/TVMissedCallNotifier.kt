package com.dev.flutter_twilio.notification

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.dev.flutter_twilio.R

object TVMissedCallNotifier {

    private const val NOTIFICATION_ID = 0xCAFE02

    fun show(context: Context, fromNumber: String) {
        TVNotificationChannels.register(context)
        val mgr = context.getSystemService(NotificationManager::class.java) ?: return

        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                )
                putExtra("com.dev.flutter_twilio.action", "missed_call")
                putExtra("com.dev.flutter_twilio.from", fromNumber)
            }

        val tapPi = PendingIntent.getActivity(
            context,
            3,
            launchIntent ?: Intent(),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            else PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val builder = NotificationCompat.Builder(context, TVNotificationChannels.MISSED_CALL_ID)
            .setSmallIcon(android.R.drawable.sym_call_missed)
            .setContentTitle(context.getString(R.string.flutter_twilio_missed_call_title))
            .setContentText(context.getString(R.string.flutter_twilio_missed_call_text, fromNumber))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_MISSED_CALL)
            .setAutoCancel(true)
            .setContentIntent(tapPi)

        mgr.notify(NOTIFICATION_ID, builder.build())
    }
}
