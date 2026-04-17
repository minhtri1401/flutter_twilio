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
        try {
            audio.setSpeaker(onSpeaker)
        } catch (e: IllegalStateException) {
            throw FlutterTwilioError.of(
                "audio_session_error",
                "Failed to toggle speaker routing: ${e.message}",
                mapOf("nativeMessage" to e.message),
            )
        } catch (e: SecurityException) {
            throw FlutterTwilioError.of(
                "audio_session_error",
                "Audio routing change was rejected: ${e.message}",
                mapOf("nativeMessage" to e.message),
            )
        } catch (e: RuntimeException) {
            // AudioManager can throw a handful of undocumented RuntimeExceptions
            // when the audio session is in a bad state; classify them all as
            // audio_session_error rather than leaking them as `unknown`.
            throw FlutterTwilioError.of(
                "audio_session_error",
                "AudioManager rejected setSpeaker($onSpeaker): ${e.message}",
                mapOf("nativeMessage" to e.message),
            )
        }
        state.isSpeakerOn = onSpeaker
    }
}
