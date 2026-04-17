package com.dev.flutter_twilio.handler

import com.dev.flutter_twilio.FlutterTwilioError
import com.dev.flutter_twilio.TVEventEmitter
import com.dev.flutter_twilio.TVPluginState
import com.dev.flutter_twilio.service.TVCallManager

class TVAudioMethodHandler(
    private val state: TVPluginState,
    @Suppress("unused") private val emitter: TVEventEmitter,
) {
    companion object {
        private const val TAG = "TVAudioMethodHandler"
    }

    fun setSpeaker(onSpeaker: Boolean) {
        if (!TVCallManager.hasActiveCall()) {
            throw FlutterTwilioError.of(
                "no_active_call",
                "No active call to toggle speaker routing",
            )
        }
        val audio = TVCallManager.audioManager
            ?: throw FlutterTwilioError.of(
                "audio_session_error",
                "Audio manager not initialized",
            )
        audio.setSpeaker(onSpeaker)
        state.isSpeakerOn = onSpeaker
    }
}
