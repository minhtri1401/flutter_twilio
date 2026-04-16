package com.twilio.twilio_voice

import android.util.Log
import com.twilio.twilio_voice.service.TVCallManager
import com.twilio.twilio_voice.types.CallDirection
import com.twilio.voice.Call
import com.twilio.voice.CallException
import com.twilio.voice.CallInvite
import com.twilio.voice.CancelledCallInvite
import org.json.JSONObject

internal class TVCallEventsReceiver(
    private val state: TVPluginState,
    private val emitter: TVEventEmitter
) : TVCallManager.TVCallManagerListener {

    companion object { private const val TAG = "TVCallEventsReceiver" }

    override fun onCallInviteReceived(callInvite: CallInvite) {
        Log.d(TAG, "onCallInviteReceived: ${callInvite.callSid}")
        val from = callInvite.from ?: ""
        val to = callInvite.to
        val params = JSONObject().apply {
            callInvite.customParameters.forEach { (k, v) -> put(k, v) }
        }.toString()
        emitter.logEvents("", arrayOf("Incoming", from, to, CallDirection.INCOMING.label, params))
        emitter.logEvents("", arrayOf("Ringing", from, to, CallDirection.INCOMING.label, params))
    }

    override fun onCancelledCallInviteReceived(cancelledCallInvite: CancelledCallInvite) {
        Log.d(TAG, "onCancelledCallInviteReceived: ${cancelledCallInvite.callSid}")
        emitter.logEvent("", "Call Ended")
    }

    override fun onCallRinging(call: Call) {
        Log.d(TAG, "onCallRinging: ${call.sid}")
        emitter.logEvents("", arrayOf("Ringing", call.from ?: "", call.to ?: "", CallDirection.OUTGOING.label))
    }

    override fun onCallConnected(call: Call) {
        Log.d(TAG, "onCallConnected: ${call.sid}")
        emitter.logEvents("", arrayOf("Connected", call.from ?: "", call.to ?: "", TVCallManager.callDirection.label))
    }

    override fun onCallConnectFailure(call: Call, error: CallException) {
        Log.e(TAG, "onCallConnectFailure: ${error.errorCode} ${error.message}")
        emitter.logEvent("Call Error: ${error.errorCode}, ${error.message}")
    }

    override fun onCallReconnecting(call: Call, error: CallException) {
        Log.d(TAG, "onCallReconnecting: ${call.sid}")
        emitter.logEvent("", "Reconnecting")
    }

    override fun onCallReconnected(call: Call) {
        Log.d(TAG, "onCallReconnected: ${call.sid}")
        emitter.logEvent("", "Reconnected")
    }

    override fun onCallDisconnected(call: Call, error: CallException?) {
        Log.d(TAG, "onCallDisconnected: ${call.sid}")
        state.isMuted = false
        state.isHolding = false
        state.isSpeakerOn = false
        state.isBluetoothOn = false
        if (error != null) emitter.logEvent("Call Error: ${error.errorCode}, ${error.message}")
        emitter.logEvent("", "Call Ended")
    }
}
