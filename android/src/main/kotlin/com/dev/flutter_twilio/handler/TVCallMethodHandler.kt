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

        val fromValue = from ?: ""
        Log.d(TAG, "place: from='$fromValue' to='$to' extras=$extra")

        val params = HashMap<String, String>(extra)
        val ok = TVCallManager.makeCall(ctx, token, to, fromValue, params)
        if (!ok) {
            throw FlutterTwilioError.of(
                "connection_error",
                "Voice.connect returned null — unable to start outgoing call",
            )
        }
    }

    fun answer() {
        val ctx = state.context
            ?: throw FlutterTwilioError.of("not_initialized", "Plugin not attached to Flutter engine")
        if (TVCallManager.activeCallInvite == null) {
            throw FlutterTwilioError.of("no_active_call", "No pending call invite to answer")
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
