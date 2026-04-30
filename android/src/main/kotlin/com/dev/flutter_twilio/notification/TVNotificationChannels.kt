package com.dev.flutter_twilio.notification

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import com.dev.flutter_twilio.R

object TVNotificationChannels {

    const val INCOMING_CALL_ID = "flutter_twilio.incoming_call"
    const val MISSED_CALL_ID = "flutter_twilio.missed_call"

    fun register(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = context.getSystemService(NotificationManager::class.java) ?: return

        if (mgr.getNotificationChannel(INCOMING_CALL_ID) == null) {
            val incoming = NotificationChannel(
                INCOMING_CALL_ID,
                context.getString(R.string.flutter_twilio_channel_incoming_name),
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = context.getString(R.string.flutter_twilio_channel_incoming_desc)
                enableVibration(true)
                setBypassDnd(true)
                setShowBadge(true)
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
            }
            mgr.createNotificationChannel(incoming)
        }

        if (mgr.getNotificationChannel(MISSED_CALL_ID) == null) {
            val missed = NotificationChannel(
                MISSED_CALL_ID,
                context.getString(R.string.flutter_twilio_channel_missed_name),
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = context.getString(R.string.flutter_twilio_channel_missed_desc)
                setShowBadge(true)
            }
            mgr.createNotificationChannel(missed)
        }
    }
}
