package com.dev.flutter_twilio.ui

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.dev.flutter_twilio.notification.TVIncomingCallNotifier
import com.dev.flutter_twilio.service.TVCallManager

class IncomingCallActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_ACCEPT = "com.dev.flutter_twilio.ACCEPT"
        const val ACTION_DECLINE = "com.dev.flutter_twilio.DECLINE"
    }

    override fun onReceive(context: Context, intent: Intent) {
        TVIncomingCallNotifier.cancel(context)
        when (intent.action) {
            ACTION_ACCEPT -> {
                TVCallManager.acceptPendingInvite(context)
                if (TVCallManager.shouldBringAppToForegroundOnAnswer()) {
                    bringAppToForeground(context)
                }
            }
            ACTION_DECLINE -> {
                TVCallManager.rejectPendingInvite(context)
            }
        }
    }

    private fun bringAppToForeground(context: Context) {
        val intent = context.packageManager
            .getLaunchIntentForPackage(context.packageName) ?: return
        intent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                Intent.FLAG_ACTIVITY_SINGLE_TOP,
        )
        intent.putExtra("com.dev.flutter_twilio.action", "answered")
        context.startActivity(intent)
    }
}
