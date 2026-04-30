package com.dev.flutter_twilio.handler

import com.dev.flutter_twilio.FlutterTwilioError
import com.dev.flutter_twilio.TVEventEmitter
import com.dev.flutter_twilio.TVPluginState
import com.dev.flutter_twilio.audio.TVAudioRouter
import com.dev.flutter_twilio.generated.AudioRoute
import com.dev.flutter_twilio.generated.AudioRouteInfo
import com.dev.flutter_twilio.generated.CallEventType
import com.dev.flutter_twilio.generated.FlutterError
import com.dev.flutter_twilio.service.TVCallManager

class TVAudioMethodHandler(
    private val state: TVPluginState,
    private val emitter: TVEventEmitter,
    private val router: TVAudioRouter,
) {
    companion object {
        private const val TAG = "TVAudioMethodHandler"
    }

    fun setAudioRoute(route: AudioRoute) {
        if (!TVCallManager.hasActiveCall()) {
            throw FlutterTwilioError.of(
                "no_active_call",
                "No active call to change audio route",
            )
        }
        try {
            router.set(route)
        } catch (e: FlutterError) {
            throw e
        } catch (t: Throwable) {
            throw FlutterTwilioError.audioRouteFailed(t.message ?: "audio route failed")
        }
        val current = router.current()
        state.isSpeakerOn = current == AudioRoute.SPEAKER
        state.isBluetoothOn = current == AudioRoute.BLUETOOTH
        emitter.emit(CallEventType.AUDIO_ROUTE_CHANGED, audioRoute = current)
    }

    fun getAudioRoute(): AudioRoute = router.current()

    fun listAudioRoutes(): List<AudioRouteInfo> = router.list()

    /** Deprecated — kept for the deprecation cycle. Forwards to setAudioRoute. */
    fun setSpeakerLegacy(onSpeaker: Boolean) {
        setAudioRoute(if (onSpeaker) AudioRoute.SPEAKER else AudioRoute.EARPIECE)
        emitter.emit(if (onSpeaker) CallEventType.SPEAKER_ON else CallEventType.SPEAKER_OFF)
    }
}
