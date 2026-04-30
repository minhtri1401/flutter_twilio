package com.dev.flutter_twilio.notification

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.dev.flutter_twilio.R
import com.dev.flutter_twilio.ui.IncomingCallActionReceiver

object TVIncomingCallNotifier {

    private const val NOTIFICATION_ID = 0xCAFE01

    fun show(context: Context, callSid: String, fromNumber: String) {
        TVNotificationChannels.register(context)
        val mgr = context.getSystemService(NotificationManager::class.java) ?: return

        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
                putExtra("com.dev.flutter_twilio.action", "incoming_call")
                putExtra("com.dev.flutter_twilio.callSid", callSid)
            }

        val tapPi = PendingIntent.getActivity(
            context,
            0,
            launchIntent ?: Intent(),
            pendingIntentFlags(),
        )

        val acceptPi = PendingIntent.getBroadcast(
            context,
            1,
            Intent(context, IncomingCallActionReceiver::class.java).apply {
                action = IncomingCallActionReceiver.ACTION_ACCEPT
                putExtra("callSid", callSid)
            },
            pendingIntentFlags(),
        )

        val declinePi = PendingIntent.getBroadcast(
            context,
            2,
            Intent(context, IncomingCallActionReceiver::class.java).apply {
                action = IncomingCallActionReceiver.ACTION_DECLINE
                putExtra("callSid", callSid)
            },
            pendingIntentFlags(),
        )

        val builder = NotificationCompat.Builder(context, TVNotificationChannels.INCOMING_CALL_ID)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle(context.getString(R.string.flutter_twilio_incoming_call_title))
            .setContentText(context.getString(R.string.flutter_twilio_incoming_call_text, fromNumber))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(tapPi)
            .setFullScreenIntent(tapPi, true)
            .addAction(0, context.getString(R.string.flutter_twilio_action_accept), acceptPi)
            .addAction(0, context.getString(R.string.flutter_twilio_action_decline), declinePi)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            if (!mgr.canUseFullScreenIntent()) {
                Log.w(
                    "TVIncomingCallNotifier",
                    "USE_FULL_SCREEN_INTENT not granted; posting heads-up notification only"
                )
            }
        }

        mgr.notify(NOTIFICATION_ID, builder.build())
    }

    fun cancel(context: Context) {
        val mgr = context.getSystemService(NotificationManager::class.java) ?: return
        mgr.cancel(NOTIFICATION_ID)
    }

    private fun pendingIntentFlags(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else
            PendingIntent.FLAG_UPDATE_CURRENT
}
