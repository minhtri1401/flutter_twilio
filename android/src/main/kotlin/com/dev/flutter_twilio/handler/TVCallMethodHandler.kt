package com.dev.flutter_twilio.handler

import android.util.Log
import com.dev.flutter_twilio.FlutterTwilioError
import com.dev.flutter_twilio.TVEventEmitter
import com.dev.flutter_twilio.TVPluginState
import com.dev.flutter_twilio.service.TVCallManager
import com.dev.flutter_twilio.types.ContextExtension.hasMicrophoneAccess

/**
 * Plain Kotlin handler exposing typed methods for the Pigeon [VoiceHostApi].
 *
 * All preconditions (initialized token, mic permission, active call) are
 * validated up front; failures throw a [FlutterError] produced by
 * [FlutterTwilioError] so the plugin's Pigeon callback converts them into a
 * structured error on the Dart side.
 */
class TVCallMethodHandler(
    private val state: TVPluginState,
    @Suppress("unused") private val emitter: TVEventEmitter,
) {
    companion object {
        private const val TAG = "TVCallMethodHandler"
    }

    fun place(to: String, from: String?, extra: Map<String, String>) {
        if (to.isBlank()) {
            throw FlutterTwilioError.of(
                "invalid_argument",
                "Destination 'to' must not be empty",
            )
        }
        val token = state.accessToken
            ?: throw FlutterTwilioError.of("not_initialized", "Access token not set")
        val ctx = state.context
            ?: throw FlutterTwilioError.of("not_initialized", "Plugin not attached to Flutter engine")
        if (!ctx.hasMicrophoneAccess()) {
            throw FlutterTwilioError.of(
                "missing_permission",
                "RECORD_AUDIO permission is required to place calls",
                mapOf("permission" to "RECORD_AUDIO"),
            )
        }
        if (TVCallManager.hasActiveCall()) {
            throw FlutterTwilioError.of(
                "call_already_active",
                "Another call is already active.",
            )
        }

        val fromValue = from ?: ""
        Log.d(TAG, "place: from='$fromValue' to='$to' extras=$extra")

        val params = HashMap<String, String>(extra)
        // TVCallManager.makeCall throws CallException on Twilio SDK failure;
        // FlutterTwilioPlugin.guard maps that to a twilio_sdk_error.
        TVCallManager.makeCall(ctx, token, to, fromValue, params)
    }

    fun answer() {
        val ctx = state.context
            ?: throw FlutterTwilioError.of("not_initialized", "Plugin not attached to Flutter engine")
        if (TVCallManager.activeCallInvite == null) {
            throw FlutterTwilioError.of("no_active_call", "No pending call invite to answer")
        }
        // There is already an active connected call distinct from the pending invite.
        if (TVCallManager.activeCall != null) {
            throw FlutterTwilioError.of(
                "call_already_active",
                "Another call is already active.",
            )
        }
        val ok = TVCallManager.acceptCall(ctx)
        if (!ok) {
            throw FlutterTwilioError.of("connection_error", "Failed to accept incoming call")
        }
    }

    fun reject() {
        val ctx = state.context
            ?: throw FlutterTwilioError.of("not_initialized", "Plugin not attached to Flutter engine")
        if (TVCallManager.activeCallInvite == null) {
            throw FlutterTwilioError.of("no_active_call", "No pending call invite to reject")
        }
        val ok = TVCallManager.rejectCall(ctx)
        if (!ok) {
            throw FlutterTwilioError.of("connection_error", "Failed to reject incoming call")
        }
    }

    fun hangUp() {
        requireActive()
        val ok = TVCallManager.hangUp()
        if (!ok) {
            throw FlutterTwilioError.of("no_active_call", "No active call to hang up")
        }
    }

    fun setMuted(muted: Boolean) {
        requireActive()
        TVCallManager.toggleMute(muted)
        state.isMuted = muted
    }

    fun setOnHold(onHold: Boolean) {
        requireActive()
        TVCallManager.toggleHold(onHold)
        state.isHolding = onHold
    }

    fun sendDigits(digits: String) {
        if (digits.isEmpty()) {
            throw FlutterTwilioError.of(
                "invalid_argument",
                "digits must not be empty",
            )
        }
        // Only DTMF digits (0-9, *, #, A-D, plus optional pauses ",") are valid.
        val allowed = Regex("^[0-9*#A-Da-d,]+$")
        if (!allowed.matches(digits)) {
            throw FlutterTwilioError.of(
                "invalid_argument",
                "digits contains invalid DTMF characters: '$digits'",
            )
        }
        requireActive()
        TVCallManager.sendDigits(digits)
    }

    fun getActiveCall(): TVCallManager? = if (TVCallManager.hasActiveCall()) TVCallManager else null

    private fun requireActive() {
        if (!TVCallManager.hasActiveCall()) {
            throw FlutterTwilioError.of("no_active_call", "No active call")
        }
    }
}
