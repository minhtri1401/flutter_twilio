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
        emitTwilioError(error, fallbackMessage = "Call connect failure")
    }

    override fun onCallReconnecting(call: Call, error: CallException) {
        Log.d(TAG, "onCallReconnecting: ${call.sid}")
        // A reconnecting event from Twilio is the canonical connection_error
        // signal (signaling / transport interruption). Surface it as both an
        // error and a RECONNECTING event so Dart can branch either way.
        emitTwilioError(error, fallbackMessage = "Call reconnecting", preferConnectionError = true)
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
            emitTwilioError(error, fallbackMessage = "Call disconnected with error")
        }
        emitter.emit(CallEventType.DISCONNECTED)
        emitter.emit(CallEventType.CALL_ENDED)
    }

    /**
     * Maps a Twilio [CallException] into the Dart error taxonomy:
     *  * access-token related codes (20101, 20104, 20157) → `invalid_token`
     *  * signaling range (53xxx) → `connection_error`
     *  * everything else → `twilio_sdk_error`
     *
     * Set [preferConnectionError] to surface non-coded / ambiguous transport
     * errors (e.g. from `onCallReconnecting`) as `connection_error` regardless
     * of error code.
     */
    private fun emitTwilioError(
        error: CallException,
        fallbackMessage: String,
        preferConnectionError: Boolean = false,
    ) {
        val twilioCode = error.errorCode
        val code = when {
            twilioCode in com.dev.flutter_twilio.FlutterTwilioError.TOKEN_ERROR_CODES -> "invalid_token"
            com.dev.flutter_twilio.FlutterTwilioError.isSignalingError(twilioCode) -> "connection_error"
            preferConnectionError -> "connection_error"
            else -> "twilio_sdk_error"
        }
        emitter.emitError(
            code = code,
            message = error.message ?: fallbackMessage,
            details = mapOf(
                "twilioCode" to twilioCode,
                "twilioDomain" to "com.twilio.voice",
            ),
        )
    }
}
