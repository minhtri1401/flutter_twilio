package com.dev.flutter_twilio

import android.util.Log
import com.dev.flutter_twilio.generated.CallEventType
import com.dev.flutter_twilio.service.TVCallManager
import com.twilio.voice.Call
import com.twilio.voice.CallException
import com.twilio.voice.CallInvite
import com.twilio.voice.CancelledCallInvite

/**
 * Translates [TVCallManager] callbacks into typed Pigeon events.
 *
 * Snapshots of the current [com.dev.flutter_twilio.generated.ActiveCallDto] are
 * attached to every event so Dart consumers don't have to call
 * `getActiveCall()` reactively.
 */
internal class TVCallEventsReceiver(
    private val state: TVPluginState,
    private val emitter: TVEventEmitter,
) : TVCallManager.TVCallManagerListener {

    companion object {
        private const val TAG = "TVCallEventsReceiver"
    }

    override fun onCallInviteReceived(callInvite: CallInvite) {
        Log.d(TAG, "onCallInviteReceived: ${callInvite.callSid}")
        val snapshot = ActiveCallSnapshotter.snapshot()
        emitter.emit(CallEventType.INCOMING, snapshot)
        emitter.emit(CallEventType.RINGING, snapshot)
    }

    override fun onCancelledCallInviteReceived(cancelledCallInvite: CancelledCallInvite) {
        Log.d(TAG, "onCancelledCallInviteReceived: ${cancelledCallInvite.callSid}")
        emitter.emit(CallEventType.CALL_ENDED)
    }

    override fun onCallRinging(call: Call) {
        Log.d(TAG, "onCallRinging: ${call.sid}")
        emitter.emit(CallEventType.RINGING, ActiveCallSnapshotter.snapshot())
    }

    override fun onCallConnected(call: Call) {
        Log.d(TAG, "onCallConnected: ${call.sid}")
        emitter.emit(CallEventType.CONNECTED, ActiveCallSnapshotter.snapshot())
    }

    override fun onCallConnectFailure(call: Call, error: CallException) {
        Log.e(TAG, "onCallConnectFailure: ${error.errorCode} ${error.message}")
        emitter.emitError(
            code = "twilio_sdk_error",
            message = error.message ?: "Call connect failure",
            details = mapOf(
                "twilioCode" to error.errorCode,
                "twilioDomain" to "com.twilio.voice",
            ),
        )
    }

    override fun onCallReconnecting(call: Call, error: CallException) {
        Log.d(TAG, "onCallReconnecting: ${call.sid}")
        emitter.emit(CallEventType.RECONNECTING, ActiveCallSnapshotter.snapshot())
    }

    override fun onCallReconnected(call: Call) {
        Log.d(TAG, "onCallReconnected: ${call.sid}")
        emitter.emit(CallEventType.RECONNECTED, ActiveCallSnapshotter.snapshot())
    }

    override fun onCallDisconnected(call: Call, error: CallException?) {
        Log.d(TAG, "onCallDisconnected: ${call.sid}")
        state.isMuted = false
        state.isHolding = false
        state.isSpeakerOn = false
        state.isBluetoothOn = false
        if (error != null) {
            emitter.emitError(
                code = "twilio_sdk_error",
                message = error.message ?: "Call disconnected with error",
                details = mapOf(
                    "twilioCode" to error.errorCode,
                    "twilioDomain" to "com.twilio.voice",
                ),
            )
        }
        emitter.emit(CallEventType.DISCONNECTED)
        emitter.emit(CallEventType.CALL_ENDED)
    }
}
