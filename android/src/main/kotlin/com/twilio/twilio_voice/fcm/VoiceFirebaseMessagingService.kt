package com.twilio.twilio_voice.fcm

import android.content.Intent
import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.twilio.twilio_voice.service.TVCallManager
import com.twilio.voice.CallException
import com.twilio.voice.CallInvite
import com.twilio.voice.CancelledCallInvite
import com.twilio.voice.MessageListener
import com.twilio.voice.Voice

class VoiceFirebaseMessagingService : FirebaseMessagingService(), MessageListener {

    companion object {
        private const val TAG = "VoiceFirebaseMessagingService"

        const val ACTION_NEW_TOKEN = "ACTION_NEW_TOKEN"
        const val EXTRA_FCM_TOKEN = "token"
    }

    override fun onNewToken(token: String) {
        val intent = Intent(ACTION_NEW_TOKEN).also {
            it.putExtra(EXTRA_FCM_TOKEN, token)
        }
        sendBroadcast(intent)
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        Log.d(TAG, "Received onMessageReceived()")
        Log.d(TAG, "Bundle data: " + remoteMessage.data)
        Log.d(TAG, "From: " + remoteMessage.from)
        if (remoteMessage.data.isNotEmpty()) {
            val valid = Voice.handleMessage(this, remoteMessage.data, this)
            if (!valid) {
                Log.d(TAG, "onMessageReceived: The message was not a valid Twilio Voice SDK payload, continuing...")
            }
        }
    }

    // region MessageListener
    override fun onCallInvite(callInvite: CallInvite) {
        Log.d(
            TAG,
            "onCallInvite: {\n\t" +
                    "CallSid: ${callInvite.callSid}, \n\t" +
                    "From: ${callInvite.from}, \n\t" +
                    "To: ${callInvite.to}, \n\t" +
                    "Parameters: ${callInvite.customParameters.entries.joinToString { "${it.key}:${it.value}" }},\n\t" +
                    "}"
        )
        // TVCallManager stores the invite and notifies the plugin via TVCallManagerListener.
        // If the plugin isn't ready yet, the listener setter replays this invite when the plugin attaches.
        TVCallManager.handleCallInvite(callInvite)
    }

    override fun onCancelledCallInvite(cancelledCallInvite: CancelledCallInvite, callException: CallException?) {
        Log.d(TAG, "onCancelledCallInvite: ${cancelledCallInvite.callSid}", callException)
        TVCallManager.handleCancelledCallInvite(cancelledCallInvite)
    }
    // endregion
}
